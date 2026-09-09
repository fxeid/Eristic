//
//  CardView.swift
//  Eristic
//
//  Created by Fady A Eid on 11/27/23.
//

import SwiftUI

// MARK: - FlashCard
// One flash card: an argument and the fallacious response to it, tied to a
// FallaciesList id. `id` is the card's position in the full deck.
struct FlashCard: Identifiable, Hashable {
    let id: Int
    let fallacyId: Int
    let argument: String
    let response: String

    var title: String {
        FallaciesList.fallacies.first { $0.id == fallacyId }?.title ?? ""
    }
}

// MARK: - Card size
// The swipe engine proposes a fixed 320 x 450 to its content. The deck screen
// measures the card area and hands the real size down through the
// environment so the card fills it; the engine keeps its centre.
private struct FlashCardSizeKey: EnvironmentKey {
    static let defaultValue = CGSize(width: 320, height: 450)
}

extension EnvironmentValues {
    var flashCardSize: CGSize {
        get { self[FlashCardSizeKey.self] }
        set { self[FlashCardSizeKey.self] = newValue }
    }
}

// MARK: - CardView
// White, hairline, radius 16. The top half carries the fallacy mark and the
// argument; the seam is the one gradient in the app; the bottom half sits on
// the surface colour with the response.
struct CardView: View {
    let card: FlashCard

    @Environment(\.flashCardSize) private var size

    var body: some View {
        VStack(spacing: 0) {
            // Top half: the argument
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 11) {
                    XeidSymbol(glyph: .fallacy(id: card.fallacyId), size: 42)
                    Text(card.title)
                        .xeidEyebrow(XeidColor.secondary)
                }
                .padding(.bottom, 9)

                XeidEyebrow(text: "The argument", dot: XeidColor.blue)

                Text(card.argument)
                    .font(XeidFont.inter(22, weight: .light, relativeTo: .title2))
                    .tracking(-0.02 * 22)
                    .lineSpacing(22 * 0.19)
                    .foregroundColor(XeidColor.ink)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.7)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            // The seam
            Rectangle()
                .fill(XeidColor.seam)
                .frame(height: 3)
                .accessibilityHidden(true)

            // Bottom half: the response
            VStack(alignment: .leading, spacing: 15) {
                XeidEyebrow(text: "The response", dot: XeidColor.magenta)

                Text(card.response)
                    .font(XeidFont.inter(22, weight: .light, relativeTo: .title2))
                    .tracking(-0.02 * 22)
                    .lineSpacing(22 * 0.19)
                    .foregroundColor(XeidColor.ink)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.7)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(XeidColor.surface)
        }
        .frame(width: size.width, height: size.height)
        .background(XeidColor.cell)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(XeidColor.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview
#Preview {
    CardView(card: FlashCard(id: 1, fallacyId: 1,
                             argument: "We should invest more in improving public schools.",
                             response: "So, you're saying we should completely abandon private schools?"))
        .environment(\.flashCardSize, CGSize(width: 358, height: 620))
        .padding(22)
        .background(XeidColor.surface)
}
