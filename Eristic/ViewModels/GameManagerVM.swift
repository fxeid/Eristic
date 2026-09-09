//
//  GameManagerVM.swift
//  Eristic
//
//  Created by Fady A Eid on 11/25/23.
//

import Foundation
import SwiftUI
import Combine

// One wrong answer in a run: what was asked, what was right, what was picked.
// The run-over screen groups these by the correct fallacy.
struct MissedQuestion: Identifiable {
    let id = UUID()
    let question: String
    let correctTitle: String
    let pickedTitle: String
}

// Why a run ended
enum EndReason {
    case threeStrikes   // three wrong answers
    case timeUp         // the sixty seconds ran out
    case finished       // every question was answered
}

// ViewModel managing the game state
class GameManagerVM: ObservableObject {

    // Static properties for managing game flow
    static var currentIndex = 0
    static let maxIncorrectAnswers = 3

    // Static method to create a game model based on the given index
    static func createGameModel(index: Int) -> Quiz {
        return Quiz(currentQuestionIndex: index, quizModel: quizData[index])
    }

    // The FallaciesList id behind a quiz option title, so answers can be
    // recorded per fallacy. Option titles match FallaciesList titles exactly.
    static func fallacyId(forTitle title: String) -> Int? {
        FallaciesList.fallacies.first(where: { $0.title == title })?.id
    }

    // Published properties for observing changes
    @Published var model = GameManagerVM.createGameModel(index: GameManagerVM.currentIndex)
    var stateModel: StateModel

    // Game-related variables
    @Published var score = 0
    var timer = Timer()
    var maxProgress = 60
    @Published var progress = 0
    @Published var incorrectAnswers = 0

    // Every wrong answer of the current run, in order; cleared by resetGame
    @Published var missed: [MissedQuestion] = []

    // Set wherever the run ends; nil while a run is in progress
    @Published var endReason: EndReason?

    // Seconds elapsed when the run ended, captured before the timer resets
    @Published private(set) var secondsAtEnd = 0

    // Seconds left in the run: the timer counts progress up from zero
    var secondsLeft: Int { maxProgress - progress }

    // Initialization with a StateModel instance
    init(stateModel: StateModel) {
        self.stateModel = stateModel
    }

    // Method to verify the selected answer
    func verifyAnswer(selectedOption: QuizOption) {
        // Reset all options' state
        for index in model.quizModel.optionsList.indices {
            model.quizModel.optionsList[index].isMatched = false
            model.quizModel.optionsList[index].isSelected = false
        }

        // Check the selected answer
        if let index = model.quizModel.optionsList.firstIndex(where: { $0.optionId == selectedOption.optionId }) {
            let correct = selectedOption.optionId == model.quizModel.answer
            recordAnswer(correct: correct)

            if correct {
                // If correct, update score and move to the next question
                model.quizModel.optionsList[index].isMatched = true
                model.quizModel.optionsList[index].isSelected = true
                score += 1
                saveHighScore()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    GameManagerVM.currentIndex += 1
                    if GameManagerVM.currentIndex < GameManagerVM.quizData.count {
                        self.model = GameManagerVM.createGameModel(index: GameManagerVM.currentIndex)
                    } else {
                        self.endRun(.finished)
                    }
                }
            } else {
                // If incorrect, handle the incorrect answer
                model.quizModel.optionsList[index].isMatched = false
                model.quizModel.optionsList[index].isSelected = true
                missed.append(MissedQuestion(question: model.quizModel.question,
                                             correctTitle: correctOptionTitle,
                                             pickedTitle: selectedOption.option))
                handleIncorrectAnswer()
            }
        }
    }

    // The title of the correct option for the current question
    private var correctOptionTitle: String {
        model.quizModel.optionsList.first(where: { $0.optionId == model.quizModel.answer })?.option ?? ""
    }

    // Record the answer against the fallacy the question was about. The
    // store is main-actor bound; answers arrive from a button on the main
    // thread, so the hop is immediate.
    private func recordAnswer(correct: Bool) {
        guard let fallacyId = GameManagerVM.fallacyId(forTitle: correctOptionTitle) else { return }
        Task { @MainActor in
            ProgressStore.shared.recordQuizAnswer(fallacyId: fallacyId, correct: correct)
        }
    }

    // End the run: remember why and when, then stop the clock
    private func endRun(_ reason: EndReason) {
        secondsAtEnd = progress
        endReason = reason
        model.quizCompleted = true
        reset()
    }
    
    // Method to handle incorrect answers
    func handleIncorrectAnswer() {
        incorrectAnswers += 1
        
        if incorrectAnswers == GameManagerVM.maxIncorrectAnswers {
            // End the game if the user answers three questions wrong
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.endRun(.threeStrikes)
                self.saveHighScore()
            }
        } else {
            // Move to the next question
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if GameManagerVM.currentIndex < GameManagerVM.quizData.count - 1 {
                    GameManagerVM.currentIndex += 1
                    self.model = GameManagerVM.createGameModel(index: GameManagerVM.currentIndex)
                } else {
                    // That was the last question
                    self.endRun(.finished)
                }
            }
        }
    }

    // Method to reset the game state
    func resetGame() {
        timer.invalidate()
        progress = 0
        incorrectAnswers = 0
        score = 0
        missed = []
        endReason = nil
        secondsAtEnd = 0
        GameManagerVM.currentIndex = 0

        model = GameManagerVM.createGameModel(index: GameManagerVM.currentIndex)
    }

    // Method to start the game timer
    func start() {
        timer.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { time in
            if self.progress == self.maxProgress {
                self.endRun(.timeUp)
            } else {
                self.progress += 1
            }
        })
    }
    
    // Method to reset the game timer
    func reset() {
        timer.invalidate()
        self.progress = 0
    }
    
    // Method to save the high score
    fileprivate func saveHighScore() {
        // The state model keeps the score only when it beats the current best
        stateModel.recordScore(self.score)
    }
}

#if DEBUG
// MARK: - Screenshot seed
// A finished run for the run-over screenshot (`-xeidScreen runover`): score
// 11, three strikes at 47 seconds, Equivocation missed twice and Red Herring
// once. Debug builds only; none of this exists in release.
extension GameManagerVM {
    static func debugRunOver(stateModel: StateModel = StateModel()) -> GameManagerVM {
        let vm = GameManagerVM(stateModel: stateModel)
        vm.score = 11
        vm.incorrectAnswers = 3
        vm.progress = 47
        vm.secondsAtEnd = 47
        vm.endReason = .threeStrikes
        vm.model.quizCompleted = true
        vm.missed = [
            MissedQuestion(question: "", correctTitle: "Equivocation", pickedTitle: "Straw Man"),
            MissedQuestion(question: "", correctTitle: "Red Herring", pickedTitle: "Tu Quoque"),
            MissedQuestion(question: "", correctTitle: "Equivocation", pickedTitle: "Straw Man"),
        ]
        return vm
    }
}
#endif

// Extension for static quiz data
extension GameManagerVM {
    static let quizData: [QuizModel] = {
        [
            // MARK: Questions Group 1:
            QuizModel(question: "Favor free college tuition? you want a lower education quality and inflated taxes.",
                      answer: "D",
                      optionsList: [
                        QuizOption(id: 5, optionId: "A", option: "Ad Hominem"),
                        QuizOption(id: 6, optionId: "B", option: "Appeal to Emotion"),
                        QuizOption(id: 7, optionId: "C", option: "Equivocation"),
                        QuizOption(id: 8, optionId: "D", option: "Straw Man")
                      ]),
            QuizModel(question: "You're just a conspiracy theorist. You don't know what you're talking about.",
                      answer: "B",
                      optionsList: [
                        QuizOption(id: 1, optionId: "A", option: "Tu Quoque"),
                        QuizOption(id: 2, optionId: "B", option: "Ad Hominem"),
                        QuizOption(id: 3, optionId: "C", option: "Slippery Slope"),
                        QuizOption(id: 4, optionId: "D", option: "Appeal to Ignorance")
                      ]),
            QuizModel(question: "We either love our country unconditionally or we're traitors.",
                      answer: "A",
                      optionsList: [
                        QuizOption(id: 9, optionId: "A", option: "False Dilemma"),
                        QuizOption(id: 10, optionId: "B", option: "Red Herring"),
                        QuizOption(id: 11, optionId: "C", option: "Equivocation"),
                        QuizOption(id: 12, optionId: "D", option: "Slippery Slope")
                      ]),
            QuizModel(question: "We can't see dark matter, so it doesn't exist.",
                      answer: "C",
                      optionsList: [
                        QuizOption(id: 13, optionId: "A", option: "Appeal to Emotion"),
                        QuizOption(id: 14, optionId: "B", option: "Ad Hominem"),
                        QuizOption(id: 17, optionId: "C", option: "Appeal to Ignorance"),
                        QuizOption(id: 18, optionId: "D", option: "Tu Quoque")
                      ]),
            QuizModel(question: "Don't lecture about cheating; you cheated years ago too.",
                      answer: "B",
                      optionsList: [
                        QuizOption(id: 19, optionId: "A", option: "Slippery Slope"),
                        QuizOption(id: 20, optionId: "B", option: "Tu Quoque"),
                        QuizOption(id: 21, optionId: "C", option: "Circular Reasoning"),
                        QuizOption(id: 18, optionId: "D", option: "False Dilemma")
                      ]),
            QuizModel(question: "Allow marijuana use? eveyone now will use cocaine and commit crimes.",
                      answer: "A",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Slippery Slope"),
                        QuizOption(id: 16, optionId: "B", option: "Equivocation"),
                        QuizOption(id: 17, optionId: "C", option: "Red Herring"),
                        QuizOption(id: 18, optionId: "D", option: "Appeal to Authority")
                      ]),
            QuizModel(question: "This law is just and fair because it's the law.",
                      answer: "D",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Appeal to Ignorance"),
                        QuizOption(id: 16, optionId: "B", option: "Tu Quoque"),
                        QuizOption(id: 17, optionId: "C", option: "Red Herring"),
                        QuizOption(id: 18, optionId: "D", option: "Circular Reasoning")
                      ]),
            QuizModel(question: "All teenagers are irresponsible. They only care about having fun.",
                      answer: "C",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "False Dilemma"),
                        QuizOption(id: 16, optionId: "B", option: "Circular Reasoning"),
                        QuizOption(id: 17, optionId: "C", option: "Hasty Generalization"),
                        QuizOption(id: 18, optionId: "D", option: "Slippery Slope")
                      ]),
            QuizModel(question: "My favorite influencer said this clothing line is trendy, so it must be.",
                      answer: "B",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Circular Reasoning"),
                        QuizOption(id: 16, optionId: "B", option: "Appeal to Authority"),
                        QuizOption(id: 17, optionId: "C", option: "Ad Hominem"),
                        QuizOption(id: 18, optionId: "D", option: "Equivocation")
                      ]),
            QuizModel(question: "Let's forget about human rights, the economy is way more important now.",
                      answer: "D",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "False Dilemma"),
                        QuizOption(id: 16, optionId: "B", option: "Circular Reasoning"),
                        QuizOption(id: 17, optionId: "C", option: "Tu Quoque"),
                        QuizOption(id: 18, optionId: "D", option: "Red Herring")
                      ]),
            QuizModel(question: "Celine Dion is a star, the Sun is a star, Celine Dion is the sun!",
                      answer: "C",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Red Herring"),
                        QuizOption(id: 16, optionId: "B", option: "Appeal to Emotion"),
                        QuizOption(id: 17, optionId: "C", option: "Equivocation"),
                        QuizOption(id: 18, optionId: "D", option: "Slippery Slope")
                      ]),
            QuizModel(question: "Don't be cruel! Donate to this animal shelter.",
                      answer: "B",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Ad Hominem"),
                        QuizOption(id: 16, optionId: "B", option: "Appeal to Emotion"),
                        QuizOption(id: 17, optionId: "C", option: "Circular Reasoning"),
                        QuizOption(id: 18, optionId: "D", option: "Appeal to Authority")
                      ]),

            // MARK: Questions Group 2:
            QuizModel(question: "Since we can't disprove time travel, it must be happening.",
                      answer: "A",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Appeal to Ignorance"),
                        QuizOption(id: 16, optionId: "B", option: "Equivocation"),
                        QuizOption(id: 17, optionId: "C", option: "Appeal to Emotion"),
                        QuizOption(id: 18, optionId: "D", option: "Slippery Slope")
                      ]),
            QuizModel(question: "Peace is the best strategy because Einstein said so.",
                      answer: "C",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Straw Man"),
                        QuizOption(id: 16, optionId: "B", option: "Circular Reasoning"),
                        QuizOption(id: 17, optionId: "C", option: "Appeal to Authority"),
                        QuizOption(id: 18, optionId: "D", option: "Equivocation")
                      ]),
            QuizModel(question: "'a Few' means up to 10! I only had a few beers!",
                      answer: "A",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Equivocation"),
                        QuizOption(id: 16, optionId: "B", option: "Ad Hominem"),
                        QuizOption(id: 17, optionId: "C", option: "Appeal to Emotion"),
                        QuizOption(id: 18, optionId: "D", option: "Circular Reasoning")
                      ]),
            QuizModel(question: "You can either accept my terms, or we have no deal at all.",
                      answer: "D",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Appeal to Emotion"),
                        QuizOption(id: 16, optionId: "B", option: "Slippery Slope"),
                        QuizOption(id: 17, optionId: "C", option: "Tu Quoque"),
                        QuizOption(id: 18, optionId: "D", option: "False Dilemma")
                      ]),
            QuizModel(question: "The president is destroying our country. We need to stand up and fight back!",
                      answer: "B",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Straw Man"),
                        QuizOption(id: 16, optionId: "B", option: "Appeal to Emotion"),
                        QuizOption(id: 17, optionId: "C", option: "Circular Reasoning"),
                        QuizOption(id: 18, optionId: "D", option: "Appeal to Authority")
                      ]),
            QuizModel(question: "If I fail tomorrow’s exam, I won't go to a good college.",
                      answer: "D",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "False Dilemma"),
                        QuizOption(id: 16, optionId: "B", option: "Ad Hominem"),
                        QuizOption(id: 17, optionId: "C", option: "Straw Man"),
                        QuizOption(id: 18, optionId: "D", option: "Slippery Slope")
                      ]),
            QuizModel(question: "He smokes 1 pack a day, but his uncle smoked 2 packs a day and lived to be 95.",
                      answer: "C",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Ad Hominem"),
                        QuizOption(id: 16, optionId: "B", option: "Appeal to Emotion"),
                        QuizOption(id: 17, optionId: "C", option: "Hasty Generalization"),
                        QuizOption(id: 18, optionId: "D", option: "Circular Reasoning")
                      ]),
            QuizModel(question: "Why listen to him about finance? He can't even manage his own budget.",
                      answer: "B",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Slippery Slope"),
                        QuizOption(id: 16, optionId: "B", option: "Ad Hominem"),
                        QuizOption(id: 17, optionId: "C", option: "Appeal to Emotion"),
                        QuizOption(id: 18, optionId: "D", option: "Equivocation")
                      ]),
            QuizModel(question: "This medication is effective because the label says it works.",
                      answer: "A",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Circular Reasoning"),
                        QuizOption(id: 16, optionId: "B", option: "Tu Quoque"),
                        QuizOption(id: 17, optionId: "C", option: "Red Herring"),
                        QuizOption(id: 18, optionId: "D", option: "Appeal to Emotion")
                      ]),
            QuizModel(question: "Yes, I made a mistake, but what about all the good things I've done in the past?",
                      answer: "C",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Slippery Slope"),
                        QuizOption(id: 16, optionId: "B", option: "Circular Reasoning"),
                        QuizOption(id: 17, optionId: "C", option: "Red Herring"),
                        QuizOption(id: 18, optionId: "D", option: "Appeal to Emotion")
                      ]),
            QuizModel(question: "Don't criticize my eating habits; I've seen you indulge in junk food before.",
                      answer: "A",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Tu Quoque"),
                        QuizOption(id: 16, optionId: "B", option: "Ad Hominem"),
                        QuizOption(id: 17, optionId: "C", option: "Slippery Slope"),
                        QuizOption(id: 18, optionId: "D", option: "False Dilemma")
                      ]),
            QuizModel(question: "Advocating for free speech is just a cover for promoting hate speech.",
                      answer: "C",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Appeal to Authority"),
                        QuizOption(id: 16, optionId: "B", option: "Tu Quoque"),
                        QuizOption(id: 17, optionId: "C", option: "Straw Man"),
                        QuizOption(id: 18, optionId: "D", option: "Equivocation")
                      ]),

            // MARK: Questions Group 3:
            QuizModel(question: "Her opinions are always right because she's the most informed.",
                      answer: "B",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Red Herring"),
                        QuizOption(id: 16, optionId: "B", option: "Circular Reasoning"),
                        QuizOption(id: 17, optionId: "C", option: "Ad Hominem"),
                        QuizOption(id: 18, optionId: "D", option: "Tu Quoque")
                      ]),
            QuizModel(question: "Stock market does better under Democratic presidents",
                      answer: "A",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Hasty Generalization"),
                        QuizOption(id: 16, optionId: "B", option: "Equivocation"),
                        QuizOption(id: 17, optionId: "C", option: "Straw Man"),
                        QuizOption(id: 18, optionId: "D", option: "Tu Quoque")
                      ]),
            QuizModel(question: "Don't take his political views seriously; he's just a liberal snowflake.",
                      answer: "B",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "False Dilemma"),
                        QuizOption(id: 16, optionId: "B", option: "Ad Hominem"),
                        QuizOption(id: 17, optionId: "C", option: "Hasty Generalization"),
                        QuizOption(id: 18, optionId: "D", option: "Straw Man")
                      ]),
            QuizModel(question: "You're urging me to be organized? Your desk is always a mess.",
                      answer: "C",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Straw Man"),
                        QuizOption(id: 16, optionId: "B", option: "Red Herring"),
                        QuizOption(id: 17, optionId: "C", option: "Tu Quoque"),
                        QuizOption(id: 18, optionId: "D", option: "Equivocation")
                      ]),
            QuizModel(question: "No one can explain the Bermuda Triangle, so it must be supernatural.",
                      answer: "D",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Tu Quoque"),
                        QuizOption(id: 16, optionId: "B", option: "False Dilemma"),
                        QuizOption(id: 17, optionId: "C", option: "Red Herring"),
                        QuizOption(id: 18, optionId: "D", option: "Appeal to Ignorance")
                      ]),
            QuizModel(question: "Supporting privacy rights is accused of aiding criminals hiding illegal activities.",
                      answer: "B",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Ad Hominem"),
                        QuizOption(id: 16, optionId: "B", option: "Straw Man"),
                        QuizOption(id: 17, optionId: "C", option: "Equivocation"),
                        QuizOption(id: 18, optionId: "D", option: "False Dilemma")
                      ]),
            QuizModel(question: "The priest said I should have faith. I have faith I'll be billionaire!",
                      answer: "D",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Red Herring"),
                        QuizOption(id: 16, optionId: "B", option: "Tu Quoque"),
                        QuizOption(id: 17, optionId: "C", option: "Appeal to Ignorance"),
                        QuizOption(id: 18, optionId: "D", option: "Equivocation")
                      ]),
            QuizModel(question: "The proposal may have flaws, but think about the potential benefits it could bring.",
                      answer: "A",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Red Herring"),
                        QuizOption(id: 16, optionId: "B", option: "Ad Hominem"),
                        QuizOption(id: 17, optionId: "C", option: "Straw Man"),
                        QuizOption(id: 18, optionId: "D", option: "Hasty Generalization")
                      ]),
            QuizModel(question: "You should take those vitamins because Brad Pitt said they are the best.",
                      answer: "C",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Tu Quoque"),
                        QuizOption(id: 16, optionId: "B", option: "Equivocation"),
                        QuizOption(id: 17, optionId: "C", option: "Appeal to Authority"),
                        QuizOption(id: 18, optionId: "D", option: "Straw Man")
                      ]),
            QuizModel(question: "Stop Climate Change Before It Changes You!",
                      answer: "B",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Tu Quoque"),
                        QuizOption(id: 16, optionId: "B", option: "Appeal to Emotion"),
                        QuizOption(id: 17, optionId: "C", option: "Red Herring"),
                        QuizOption(id: 18, optionId: "D", option: "False Dilemma")
                      ]),
            QuizModel(question: "If we lower voting age to 16, before you know it, babies will vote too!",
                      answer: "A",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Slippery Slope"),
                        QuizOption(id: 16, optionId: "B", option: "Equivocation"),
                        QuizOption(id: 17, optionId: "C", option: "Ad Hominem"),
                        QuizOption(id: 18, optionId: "D", option: "Tu Quoque")
                      ]),
            QuizModel(question: "You can either accept my terms, or we have no deal at all.",
                      answer: "D",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Red Herring"),
                        QuizOption(id: 16, optionId: "B", option: "Equivocation"),
                        QuizOption(id: 17, optionId: "C", option: "Straw Man"),
                        QuizOption(id: 18, optionId: "D", option: "False Dilemma")
                      ]),

            // MARK: Questions Group 4:
            QuizModel(question: "What is light can't be dark. Therefore, feathers can't be dark",
                      answer: "A",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Equivocation"),
                        QuizOption(id: 16, optionId: "B", option: "Tu Quoque"),
                        QuizOption(id: 17, optionId: "C", option: "Circular Reasoning"),
                        QuizOption(id: 18, optionId: "D", option: "Straw Man")
                      ]),
            QuizModel(question: "There must be objective rights and wrongs. If not, how can torturing humans ever be right?",
                      answer: "D",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "False Dilemma"),
                        QuizOption(id: 16, optionId: "B", option: "Appeal to Ignorance"),
                        QuizOption(id: 17, optionId: "C", option: "Tu Quoque"),
                        QuizOption(id: 18, optionId: "D", option: "Appeal to Emotion")
                      ]),
            QuizModel(question: "So kids should learn about world cultures? do you to teach our kids extreme ideas?",
                      answer: "A",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Straw Man"),
                        QuizOption(id: 16, optionId: "B", option: "Red Herring"),
                        QuizOption(id: 17, optionId: "C", option: "Ad Hominem"),
                        QuizOption(id: 18, optionId: "D", option: "Tu Quoque")
                      ]),
            QuizModel(question: "He is trustworthy because he always tells the truth.",
                      answer: "A",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Circular Reasoning"),
                        QuizOption(id: 16, optionId: "B", option: "Appeal to Ignorance"),
                        QuizOption(id: 17, optionId: "C", option: "Tu Quoque"),
                        QuizOption(id: 18, optionId: "D", option: "False Dilemma")
                      ]),
            QuizModel(question: "Yes, I failed the exam, but consider the unfair difficulty of the questions.",
                      answer: "C",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Straw Man"),
                        QuizOption(id: 16, optionId: "B", option: "False Dilemma"),
                        QuizOption(id: 17, optionId: "C", option: "Red Herring"),
                        QuizOption(id: 18, optionId: "D", option: "Tu Quoque")
                      ]),
            QuizModel(question: "If I eat this slice of pizza, I'll lose control and keep gaining weight.",
                      answer: "A",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Slippery Slope"),
                        QuizOption(id: 16, optionId: "B", option: "False Dilemma"),
                        QuizOption(id: 17, optionId: "C", option: "Circular Reasoning"),
                        QuizOption(id: 18, optionId: "D", option: "False Dilemma")
                      ]),
            QuizModel(question: "My fitness trainer says exercises will get rid of my neck pain.",
                      answer: "D",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Hasty Generalization"),
                        QuizOption(id: 16, optionId: "B", option: "Appeal to Ignorance"),
                        QuizOption(id: 17, optionId: "C", option: "Tu Quoque"),
                        QuizOption(id: 18, optionId: "D", option: "Appeal to Authority")
                      ]),
            QuizModel(question: "You're against gossip? I've heard you gossiping many times!",
                      answer: "A",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Tu Quoque"),
                        QuizOption(id: 16, optionId: "B", option: "Appeal to Ignorance"),
                        QuizOption(id: 17, optionId: "C", option: "Red Herring"),
                        QuizOption(id: 18, optionId: "D", option: "False Dilemma")
                      ]),
            QuizModel(question: "My dad would ever clean. Men are useless when it comes to doing chores.",
                      answer: "D",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Straw Man"),
                        QuizOption(id: 16, optionId: "B", option: "False Dilemma"),
                        QuizOption(id: 17, optionId: "C", option: "Tu Quoque"),
                        QuizOption(id: 18, optionId: "D", option: "Hasty Generalization")
                      ]),
            QuizModel(question: "You're either with the popular opinion, or you're against the people's will.",
                      answer: "D",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Circular Reasoning"),
                        QuizOption(id: 16, optionId: "B", option: "Straw Man"),
                        QuizOption(id: 17, optionId: "C", option: "Tu Quoque"),
                        QuizOption(id: 18, optionId: "D", option: "False Dilemma")
                      ]),
            QuizModel(question: "No proof ghosts aren't real, so they probably exist.",
                      answer: "A",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Appeal to Ignorance"),
                        QuizOption(id: 16, optionId: "B", option: "Red Herring"),
                        QuizOption(id: 17, optionId: "C", option: "Straw Man"),
                        QuizOption(id: 18, optionId: "D", option: "Hasty Generalization")
                      ]),
            QuizModel(question: "Why follow her diet advice? Look at her, she's not even in shape.",
                      answer: "D",
                      optionsList: [
                        QuizOption(id: 15, optionId: "A", option: "Straw Man"),
                        QuizOption(id: 16, optionId: "B", option: "False Dilemma"),
                        QuizOption(id: 17, optionId: "C", option: "Tu Quoque"),
                        QuizOption(id: 18, optionId: "D", option: "Ad Hominem")
                      ]),
        ]
    }()
}

// All 12 fallacies:
// Straw Man
// Ad Hominem
// False Dilemma
// Appeal to Ignorance
// Slippery Slope
// Circular Reasoning
// Hasty Generalization
// Appeal to Authority
// Red Herring
// Equivocation
// Appeal to Emotion
// Tu Quoque
