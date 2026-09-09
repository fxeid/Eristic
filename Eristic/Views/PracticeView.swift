//
//  PracticeView.swift
//  Eristic
//
//  Created by Fady A Eid on 9/3/26.
//

import SwiftUI

// MARK: - PracticeView
// The Practice tab root: the lockup, a "Practice" title and the two practice
// gates, Flash and Quiz, stacked in one column. The tab bar comes from
// RootView; the gates push onto its stack.
struct PracticeView: View {
    // MARK: Properties
    @StateObject private var stateModel = StateModel()
    @ObservedObject private var progress = ProgressStore.shared

    // "07 / 61 today": cards seen today, capped at the deck size
    private var flashEyebrow: String {
        let deck = CardsStackView.deckSize
        return String(format: "%02d / %d today", min(progress.cardsSeenToday, deck), deck)
    }

    // "Best 14": the best score on this device
    private var quizEyebrow: String {
        "Best \(stateModel.currentUserHighScore)"
    }

    // MARK: Body
    var body: some View {
        XeidScreen {
            XeidTopBar {
                XeidLockup()
            }

            // Title block
            Text("Practice")
                .xeidDisplay()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 4)
                .padding(.bottom, 26)

            // Gates, one column, collapsed hairlines
            XeidHairline()

            NavigationLink {
                CardsStackView()
            } label: {
                XeidGateCell(glyph: .flash,
                             title: "Flash",
                             line: "Sixty arguments. Sixty tells.",
                             eyebrow: flashEyebrow,
                             rightEdge: false,
                             bottomEdge: true)
            }
            .buttonStyle(XeidCellButtonStyle())
            .fixedSize(horizontal: false, vertical: true)

            NavigationLink {
                QuizView(gameManagerVM: GameManagerVM(stateModel: stateModel))
            } label: {
                XeidGateCell(glyph: .quiz,
                             title: "Quiz",
                             line: "Sixty seconds. Three lives.",
                             eyebrow: quizEyebrow,
                             rightEdge: false,
                             bottomEdge: true)
            }
            .buttonStyle(XeidCellButtonStyle())
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        PracticeView()
    }
}
