//
//  QuizCompletedView.swift
//  Eristic
//
//  Created by Fady A Eid on 11/26/23.
//

import Foundation
import SwiftUI

// MARK: - QuizCompletedView
// The run-over summary: final score against the best, why the run ended,
// the fallacies that tripped the player (each opens its detail), and the
// way back in or out.
struct QuizCompletedView: View {
    // MARK: Properties
    @ObservedObject var gameManagerVM: GameManagerVM
    @ObservedObject private var stateModel: StateModel
    @Environment(\.dismiss) private var dismiss

    init(gameManagerVM: GameManagerVM) {
        _gameManagerVM = ObservedObject(wrappedValue: gameManagerVM)
        _stateModel = ObservedObject(wrappedValue: gameManagerVM.stateModel)
    }

    // MARK: Derived state
    // The missed questions grouped by the fallacy that was the right answer,
    // most missed first, keeping the order they were first missed in
    private var tripped: [TrippedFallacy] {
        var order: [String] = []
        var counts: [String: Int] = [:]
        var lastPick: [String: String] = [:]
        for miss in gameManagerVM.missed {
            if counts[miss.correctTitle] == nil {
                order.append(miss.correctTitle)
            }
            counts[miss.correctTitle, default: 0] += 1
            lastPick[miss.correctTitle] = miss.pickedTitle
        }
        return order
            .map { TrippedFallacy(title: $0, count: counts[$0] ?? 0, lastPicked: lastPick[$0] ?? "") }
            .sorted { $0.count > $1.count }
    }

    // FallaciesList ids of everything missed, for the drill
    var missedFallacyIds: Set<Int> {
        Set(tripped.compactMap { $0.fallacy?.id })
    }

    // One sentence on why the run ended, from what actually happened
    private var summary: String {
        switch gameManagerVM.endReason {
        case .threeStrikes:
            return "Three wrong answers ended the run at \(gameManagerVM.secondsAtEnd) seconds."
        case .timeUp:
            let answers = gameManagerVM.score + gameManagerVM.incorrectAnswers
            return "Time ran out after \(answers) \(answers == 1 ? "answer" : "answers")."
        case .finished:
            return "You answered every question."
        case nil:
            return ""
        }
    }

    // MARK: Body
    var body: some View {
        XeidScreen {
            XeidTopBar {
                XeidBarLabel(text: "Run over")
            }

            // The tripped list stretches to the buttons on a tall screen and
            // the whole thing scrolls on a short one
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        scoreBlock
                        trippedList
                        buttons
                    }
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
            }
        }
    }

    // MARK: Score block
    private var scoreBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            XeidEyebrow(text: "Final score", dot: XeidColor.blue)

            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text("\(gameManagerVM.score)")
                    .xeidText(80, weight: .light, tracking: -0.04, relativeTo: .largeTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                // Shares the score's baseline; the row's own padding
                // carries the 10pt the drawing leaves under it
                Text("your best is \(stateModel.currentUserHighScore)")
                    .font(XeidFont.secondary)
                    .foregroundColor(XeidColor.secondary)
            }
            .padding(.top, 12)
            .accessibilityElement(children: .combine)

            if !summary.isEmpty {
                Text(summary)
                    .xeidText(XeidFont.cardTitleSize, lineHeight: 1.45, color: XeidColor.secondary, relativeTo: .title3)
                    .frame(maxWidth: 290, alignment: .leading)
                    .padding(.top, 24)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 20, leading: 24, bottom: 32, trailing: 24))
    }

    // MARK: Tripped list
    // White block with a top hairline: the eyebrow, one 78pt row per missed
    // fallacy, a closing hairline, then whatever height is left
    private var trippedList: some View {
        VStack(alignment: .leading, spacing: 0) {
            XeidEyebrow(text: "What tripped you")
                .padding(EdgeInsets(top: 20, leading: 24, bottom: 14, trailing: 24))

            if tripped.isEmpty {
                Text("Nothing tripped you.")
                    .xeidBody(XeidColor.secondary)
                    .padding(EdgeInsets(top: 16, leading: 24, bottom: 20, trailing: 24))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .top) { XeidHairline() }
            } else {
                ForEach(tripped) { item in
                    if let fallacy = item.fallacy {
                        NavigationLink {
                            FallacyDetailsView(exampleFallacy: fallacy)
                        } label: {
                            TrippedRow(item: item)
                        }
                        .buttonStyle(XeidCellButtonStyle())
                    } else {
                        TrippedRow(item: item)
                    }
                }
                // Closing hairline under the last row
                XeidHairline()
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(XeidColor.cell)
        .overlay(alignment: .top) { XeidHairline() }
    }

    // MARK: Buttons
    private var buttons: some View {
        VStack(spacing: 10) {
            Button("Play again") {
                // The run restarts a beat after the tap
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    gameManagerVM.resetGame()
                    gameManagerVM.start()
                }
            }
            .buttonStyle(XeidPrimaryPillButtonStyle())

            if !tripped.isEmpty {
                NavigationLink {
                    drillDestination
                } label: {
                    Text("Drill the ones you missed")
                }
                .buttonStyle(XeidOutlinePillButtonStyle())
            }

            Button("Back to hub") {
                dismiss()
            }
            .buttonStyle(XeidTextButtonStyle())
        }
        .padding(EdgeInsets(top: 20, leading: 24, bottom: 8, trailing: 24))
    }

    // MARK: Drill destination
    // The drill deals only the cards of the fallacies missed in this run
    private var drillDestination: some View {
        CardsStackView(fallacyIds: missedFallacyIds)
    }
}

// MARK: - TrippedFallacy
// One missed fallacy: how often, and what was picked the last time
private struct TrippedFallacy: Identifiable {
    let title: String
    let count: Int
    let lastPicked: String

    var id: String { title }

    var fallacy: Fallacy? {
        FallaciesList.fallacies.first(where: { $0.title == title })
    }

    // "missed twice — you answered Straw Man"
    var note: String {
        let times: String
        switch count {
        case 1: times = "once"
        case 2: times = "twice"
        default: times = "\(count) times"
        }
        return lastPicked.isEmpty ? "missed \(times)" : "missed \(times) \u{2014} you answered \(lastPicked)"
    }
}

// MARK: - TrippedRow
// 78pt row: the fallacy's symbol, its name and the miss note, a forward
// arrow. Press shifts the background to the surface colour.
private struct TrippedRow: View {
    let item: TrippedFallacy

    @Environment(\.xeidPressed) private var pressed

    var body: some View {
        HStack(spacing: 16) {
            XeidSymbol(glyph: XeidGlyph.fallacy(id: item.fallacy?.id ?? 0), size: 46)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(XeidFont.body)
                    .foregroundColor(XeidColor.ink)
                Text(item.note)
                    .xeidSecondary()
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if item.fallacy != nil {
                XeidInlineGlyph(glyph: .forward, size: 17, color: XeidColor.ink)
            }
        }
        .padding(EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24))
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .background(pressed ? XeidColor.surface : XeidColor.cell)
        .overlay(alignment: .top) { XeidHairline() }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview
#Preview {
    let vm = GameManagerVM(stateModel: StateModel())
    vm.score = 11
    vm.endReason = .threeStrikes
    vm.missed = [
        MissedQuestion(question: "", correctTitle: "Equivocation", pickedTitle: "Straw Man"),
        MissedQuestion(question: "", correctTitle: "Red Herring", pickedTitle: "Tu Quoque"),
        MissedQuestion(question: "", correctTitle: "Equivocation", pickedTitle: "Straw Man"),
    ]
    return NavigationStack {
        QuizCompletedView(gameManagerVM: vm)
    }
}
