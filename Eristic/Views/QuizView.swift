//
//  QuizView.swift
//  Eristic
//
//  Created by Fady A Eid on 11/27/23.
//

import SwiftUI

// MARK: - QuizView
// The quiz screen. While a run is on it shows the score and lives in the top
// bar, the question card with the timer ring, and four option rows filling
// the rest. When the run ends the same screen fades to the run-over summary.
struct QuizView: View {
    // MARK: Properties
    @StateObject var gameManagerVM: GameManagerVM

    // MARK: Body
    var body: some View {
        ZStack {
            if gameManagerVM.model.quizCompleted {
                QuizCompletedView(gameManagerVM: gameManagerVM)
                    .transition(XeidMotion.riseIn)
            } else {
                QuizRunView(gameManagerVM: gameManagerVM)
                    .transition(.opacity)
            }
        }
        .animation(XeidMotion.standard, value: gameManagerVM.model.quizCompleted)
        .onAppear {
            // Start the quiz on view appear. Coming back from a screen pushed
            // off the run-over list must not restart the clock.
            if !gameManagerVM.model.quizCompleted {
                gameManagerVM.start()
            }
        }
        .onDisappear {
            if gameManagerVM.model.quizCompleted {
                // The run-over screen pushes fallacy details and the drill,
                // and comes back to the same summary, so the model is left
                // alone. The question index is process state, so it goes
                // back to the start for the next run here.
                GameManagerVM.currentIndex = 0
            } else {
                // Backing out of a run resets it
                gameManagerVM.resetGame()
            }
        }
    }
}

// MARK: - QuizRunView
// The live run: top bar, question card, option rows
private struct QuizRunView: View {
    @ObservedObject var gameManagerVM: GameManagerVM

    private var question: String { gameManagerVM.model.quizModel.question }

    // Remaining share of the run for the timer ring
    private var remainingFraction: Double {
        guard gameManagerVM.maxProgress > 0 else { return 0 }
        return Double(gameManagerVM.secondsLeft) / Double(gameManagerVM.maxProgress)
    }

    var body: some View {
        XeidScreen {
            XeidTopBar {
                XeidBackButton()
            } center: {
                XeidBarLabel(text: "Score \(gameManagerVM.score)")
                    .accessibilityLabel("Score \(gameManagerVM.score)")
            } trailing: {
                QuizLives(lost: gameManagerVM.incorrectAnswers)
            }

            questionCard

            OptionsGridView(gameManagerVM: gameManagerVM)
        }
    }

    // MARK: Question card
    // 356pt white card between two hairlines: eyebrow at the top, the
    // statement in the middle, the timer row at the bottom
    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            XeidEyebrow(text: "Name the fallacy", dot: XeidColor.magenta)

            Spacer(minLength: 20)

            // The statement fades in and rises with each new question
            ZStack(alignment: .leading) {
                Text("\u{201C}\(question)\u{201D}")
                    .xeidText(34, weight: .light, lineHeight: 1.24, tracking: -0.035, relativeTo: .largeTitle)
                    .fixedSize(horizontal: false, vertical: true)
                    .id(gameManagerVM.model.currentQuestionIndex)
                    .transition(XeidMotion.riseIn)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(XeidMotion.standard, value: gameManagerVM.model.currentQuestionIndex)

            Spacer(minLength: 20)

            HStack(spacing: 14) {
                QuizTimerRing(secondsLeft: gameManagerVM.secondsLeft, fraction: remainingFraction)
                Text("Seconds left in this run")
                    .xeidEyebrow(XeidColor.secondary, wide: false)
                    .lineSpacing(XeidFont.lineSpacing(12, lineHeight: 1.35))
            }
        }
        .padding(EdgeInsets(top: 30, leading: 24, bottom: 26, trailing: 24))
        .frame(maxWidth: .infinity, minHeight: 356, alignment: .leading)
        .background(XeidColor.cell)
        .overlay(alignment: .top) { XeidHairline() }
        .overlay(alignment: .bottom) { XeidHairline() }
    }
}

// MARK: - QuizLives
// Three 5pt dots: remaining lives blue, lost ones a hollow muted ring
private struct QuizLives: View {
    let lost: Int

    private var remaining: Int { max(0, GameManagerVM.maxIncorrectAnswers - lost) }

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<GameManagerVM.maxIncorrectAnswers, id: \.self) { index in
                if index < remaining {
                    XeidDot(color: XeidColor.blue)
                } else {
                    Circle()
                        .strokeBorder(XeidColor.muted, lineWidth: 1)
                        .frame(width: 5, height: 5)
                }
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(remaining) of \(GameManagerVM.maxIncorrectAnswers) lives left")
    }
}

// MARK: - QuizTimerRing
// 38pt ring: hairline track, blue arc for the time left drawn from twelve
// o'clock, the seconds left centred. Each tick animates linearly over the
// second it represents.
private struct QuizTimerRing: View {
    let secondsLeft: Int
    let fraction: Double

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(XeidColor.hairline, lineWidth: 1.5)
            Circle()
                .inset(by: 0.75)
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(XeidColor.blue, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: fraction)
            Text("\(secondsLeft)")
                .font(XeidFont.inter(15, relativeTo: .subheadline))
                .foregroundColor(XeidColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75) // 15pt floors at 11.25, the HIG minimum
        }
        .frame(width: 38, height: 38)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(secondsLeft) seconds left")
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        QuizView(gameManagerVM: GameManagerVM(stateModel: StateModel()))
    }
}
