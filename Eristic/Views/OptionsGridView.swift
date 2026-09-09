//
//  OptionsGridView.swift
//  Eristic
//
//  Created by Fady A Eid on 11/26/23.
//

import Foundation
import SwiftUI

// MARK: - OptionsGridView
// The four answers as full-width rows that share whatever height is left
// under the question card, a hairline between each. A row is a letter badge
// and the fallacy name. Correct: badge filled blue, row white, label 400.
// Wrong: badge and text magenta, a 2pt magenta bar on the row's left edge.
// verifyAnswer stays the only entry point; the feedback the model sets is
// shown until the model moves on.
struct OptionsGridView: View {
    // ObservedObject to observe changes in game state
    @ObservedObject var gameManagerVM: GameManagerVM

    private var options: [QuizOption] { gameManagerVM.model.quizModel.optionsList }

    // While the feedback for an answer is showing, the rows do not take
    // another answer for the same question
    private var feedbackShowing: Bool { options.contains { $0.isSelected } }

    // Body of the view
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.optionId) { index, option in
                Button {
                    // Verify answer on tap
                    gameManagerVM.verifyAnswer(selectedOption: option)
                } label: {
                    OptionRow(option: option, last: index == options.count - 1)
                }
                .buttonStyle(XeidCellButtonStyle())
                .disabled(feedbackShowing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - OptionRow
// One answer row. Reads the press state from the cell button style and
// shifts its background only.
private struct OptionRow: View {
    let option: QuizOption
    let last: Bool

    @Environment(\.xeidPressed) private var pressed

    private var isCorrect: Bool { option.isSelected && option.isMatched }
    private var isWrong: Bool { option.isSelected && !option.isMatched }

    var body: some View {
        HStack(spacing: 18) {
            badge

            Text(option.option)
                .xeidText(XeidFont.cardTitleSize,
                          lineHeight: 1.25,
                          tracking: -0.015,
                          relativeTo: .title3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 60, maxHeight: .infinity, alignment: .leading)
        .background(isCorrect || pressed ? XeidColor.cell : Color.clear)
        .overlay(alignment: .leading) {
            if isWrong {
                Rectangle().fill(XeidColor.magenta).frame(width: 2)
            }
        }
        .overlay(alignment: .bottom) {
            if !last {
                XeidHairline()
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(option.optionId), \(option.option)")
        .accessibilityValue(isCorrect ? "Correct" : isWrong ? "Wrong" : "")
    }

    // 34pt letter badge: hairline circle at rest, filled blue when correct,
    // magenta outline when wrong
    private var badge: some View {
        Text(option.optionId)
            .font(XeidFont.inter(17, relativeTo: .body))
            .foregroundColor(isCorrect ? .white : isWrong ? XeidColor.magenta : XeidColor.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7) // 17pt floors at 11.9, the HIG minimum
            .frame(width: 34, height: 34)
            .background(Circle().fill(isCorrect ? XeidColor.blue : Color.clear))
            .overlay {
                if !isCorrect {
                    Circle().strokeBorder(isWrong ? XeidColor.magenta : XeidColor.hairline, lineWidth: 1)
                }
            }
    }
}

// MARK: - Preview
#Preview {
    OptionsGridView(gameManagerVM: GameManagerVM(stateModel: StateModel()))
        .background(XeidColor.surface)
}
