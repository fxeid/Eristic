//
//  FallacyDetailsView.swift
//  Eristic
//
//  Created by Fady A Eid on 11/20/23.
//

import SwiftUI

// MARK: - FallacyDetailsView
// One fallacy at a time: a header with its number, title and mark, then all
// seven sections of the model in a scroll. Swiping left or right moves
// through FallaciesList in order; the bottom row drills the current one or
// steps to the next. Opening a page is recorded as the last fallacy seen.
struct FallacyDetailsView: View {
    // MARK: Properties
    let exampleFallacy: Fallacy

    @State private var currentId: Int

    init(exampleFallacy: Fallacy) {
        self.exampleFallacy = exampleFallacy
        _currentId = State(initialValue: exampleFallacy.id)
    }

    private var fallacies: [Fallacy] { FallaciesList.fallacies }

    private var counter: String {
        String(format: "%02d / %02d", currentId, fallacies.count)
    }

    // MARK: Body
    var body: some View {
        XeidScreen {
            XeidTopBar {
                XeidBackButton()
            } trailing: {
                XeidBarLabel(text: counter, wide: false)
            }

            TabView(selection: $currentId) {
                ForEach(fallacies) { fallacy in
                    FallacyDetailPage(fallacy: fallacy)
                        .tag(fallacy.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Button row with a top hairline
            VStack(spacing: 0) {
                XeidHairline()
                HStack(spacing: 10) {
                    NavigationLink {
                        CardsStackView(fallacyIds: [currentId])
                    } label: {
                        Text("Drill this one")
                    }
                    .buttonStyle(XeidOutlinePillButtonStyle())

                    Button("Next fallacy", action: next)
                        .buttonStyle(XeidPrimaryPillButtonStyle())
                }
                .padding(.top, 16)
                .padding(.horizontal, 22)
                .padding(.bottom, 2)
            }
        }
        .onAppear { record(currentId) }
        .onChange(of: currentId) { _, id in record(id) }
    }

    // MARK: Actions
    // Steps to the next fallacy in list order, wrapping round at the end
    private func next() {
        guard let index = fallacies.firstIndex(where: { $0.id == currentId }) else { return }
        let nextId = fallacies[(index + 1) % fallacies.count].id
        withAnimation(XeidMotion.standard) {
            currentId = nextId
        }
    }

    private func record(_ id: Int) {
        ProgressStore.shared.recordFallacyOpened(id: id)
    }
}

// MARK: - FallacyDetailPage
// The fixed header and the scrolling sections for one fallacy
private struct FallacyDetailPage: View {
    let fallacy: Fallacy

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    section("Definition", dot: XeidColor.blue) {
                        bodyText(fallacy.definition)
                    }
                    section("Example", dot: XeidColor.blue, gap: 15) {
                        dialogue
                    }
                    section("Why it is a fallacy", dot: XeidColor.magenta) {
                        bodyText(fallacy.whyFallacy)
                    }
                    section("How to identify", dot: XeidColor.blue) {
                        bodyText(fallacy.tipsToIdentify)
                    }
                    section("How to avoid", dot: XeidColor.blue) {
                        bodyText(fallacy.howToAvoid)
                    }
                    section("Consequences", dot: XeidColor.blue) {
                        bodyText(fallacy.consequences)
                    }
                    section("Countering", dot: XeidColor.magenta) {
                        bodyText(fallacy.counteringTips)
                    }
                }
            }
        }
    }

    // MARK: Header
    // Magenta-dot eyebrow "FALLACY 01", the title 34/300, the mark 74 on the
    // right, bottoms aligned
    private var header: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                XeidEyebrow(text: String(format: "Fallacy %02d", fallacy.id), dot: XeidColor.magenta)
                Text(fallacy.title)
                    .xeidDisplay()
                    .padding(.top, 15)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            XeidSymbol(glyph: .fallacy(id: fallacy.id), size: 74)
                .padding(.bottom, 2)
        }
        .padding(.top, 4)
        .padding(.horizontal, 22)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Sections
    private func section<Content: View>(_ title: String,
                                        dot: Color,
                                        gap: CGFloat = 13,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            XeidHairline()
            VStack(alignment: .leading, spacing: gap) {
                XeidEyebrow(text: title, dot: dot)
                content()
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // Body copy verbatim from the model, minus the emoji and diamond bullets
    private func bodyText(_ text: String) -> some View {
        Text(FallacyCopy.clean(text))
            .font(XeidFont.inter(19, relativeTo: .title3))
            .lineSpacing(19 * 0.24)
            .foregroundColor(XeidColor.ink)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    // The example dialogue: each exchange opens with the argument (blue) and
    // continues with the replies (magenta)
    private var dialogue: some View {
        let exchanges = FallacyCopy.exchanges(fallacy.examples)
        return VStack(alignment: .leading, spacing: 18) {
            ForEach(exchanges.indices, id: \.self) { exchangeIndex in
                VStack(alignment: .leading, spacing: 11) {
                    ForEach(exchanges[exchangeIndex].indices, id: \.self) { lineIndex in
                        DialogueLine(text: exchanges[exchangeIndex][lineIndex],
                                     color: lineIndex == 0 ? XeidColor.blue : XeidColor.magenta)
                    }
                }
            }
        }
    }
}

// MARK: - DialogueLine
// One spoken line: 2pt left border and a speaker glyph in the line's colour
private struct DialogueLine: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            XeidInlineGlyph(glyph: .speaker, size: 22, color: color)
                .padding(.top, 3)
            Text(text)
                .font(XeidFont.inter(19, relativeTo: .title3))
                .lineSpacing(19 * 0.24)
                .foregroundColor(XeidColor.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            Rectangle().fill(color).frame(width: 2)
        }
    }
}

// MARK: - FallacyCopy
// The model's strings carry emoji speakers and small blue diamond bullets.
// The redesign draws its own marks, so those characters are stripped when
// rendered; the words and line breaks stay exactly as written.
enum FallacyCopy {
    // Emoji, their joiners and modifiers, and the diamond bullet
    private static func isDecoration(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x200D, 0xFE0E, 0xFE0F: return true          // joiner, variation selectors
        case 0x1F3FB...0x1F3FF: return true               // skin tones
        case 0x2640, 0x2642: return true                  // gender signs
        default: break
        }
        if scalar.properties.isEmojiPresentation { return true }
        return scalar.properties.isEmoji && scalar.value > 0x238C
    }

    private static func isSpeaker(_ scalar: Unicode.Scalar) -> Bool {
        scalar.properties.isEmojiPresentation || (scalar.properties.isEmoji && scalar.value > 0x238C)
    }

    // One line with its decorations removed and its spacing tidied
    private static func tidy(_ line: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in line.unicodeScalars where !isDecoration(scalar) {
            scalars.append(scalar)
        }
        var result = String(scalars)
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        result = result.trimmingCharacters(in: .whitespaces)
        // A quote that opened before its speaker: "' If we allow" -> "'If we allow"
        if result.hasPrefix("' ") {
            result = "'" + result.dropFirst(2)
        }
        return result
    }

    // Body copy: every line tidied, blank lines kept, no more than one in a row
    static func clean(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n").map(tidy)
        var output: [String] = []
        for line in lines {
            if line.isEmpty, output.last?.isEmpty ?? true { continue }
            output.append(line)
        }
        while output.last?.isEmpty == true { output.removeLast() }
        return output.joined(separator: "\n")
    }

    // The examples string as exchanges: blank lines separate exchanges, each
    // speaker starts a line (even mid-line, where two speakers share one)
    static func exchanges(_ examples: String) -> [[String]] {
        let blocks = examples.components(separatedBy: "\n\n")
        return blocks.compactMap { block -> [String]? in
            var lines: [String] = []
            for raw in block.components(separatedBy: "\n") {
                lines.append(contentsOf: splitAtSpeakers(raw))
            }
            let cleaned = lines.map(tidy).filter { !$0.isEmpty }
            return cleaned.isEmpty ? nil : cleaned
        }
    }

    // Splits "A said 'x' B said 'y'" at each speaker emoji after some text
    private static func splitAtSpeakers(_ line: String) -> [String] {
        var segments: [String] = []
        var current = String.UnicodeScalarView()
        var previousWasSpeaker = false

        for scalar in line.unicodeScalars {
            if isSpeaker(scalar), !previousWasSpeaker {
                let text = String(current).trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    segments.append(String(current))
                    current = String.UnicodeScalarView()
                }
            }
            current.append(scalar)
            previousWasSpeaker = isSpeaker(scalar) || isDecoration(scalar)
        }
        segments.append(String(current))
        return segments
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        FallacyDetailsView(exampleFallacy: FallaciesList.fallacies[0])
    }
}
