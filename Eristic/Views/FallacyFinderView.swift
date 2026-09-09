//
//  FallacyFinderView.swift
//  Eristic
//
//  Created by Fady A Eid on 9/2/26.
//

import SwiftUI

// MARK: - FallacyFinderView
// Pushed from the hub. Input first: a title block, the editor, and Paste /
// Analyze with the on-device footnote. Once a result arrives the same
// screen becomes the read-back: how many tells, coverage, the findings and
// what was not analyzed, with NEW TEXT in the top bar to start over.
struct FallacyFinderView: View {
    // MARK: Properties
    @StateObject private var viewModel = FallacyFinderVM()
    @FocusState private var editorFocused: Bool

    private let placeholder = "An argument, a post, a speech, a paragraph of a paper."

    #if DEBUG
    // A prebuilt result for the results screenshot (`-xeidScreen results`),
    // seeded into the view model on appear. Debug builds only.
    private let debugAnalysis: FallacyAnalysis?

    init(debugAnalysis: FallacyAnalysis? = nil) {
        self.debugAnalysis = debugAnalysis
    }
    #else
    init() {}
    #endif

    // MARK: Body
    var body: some View {
        XeidScreen {
            XeidTopBar {
                XeidBackButton()
            } trailing: {
                if hasResult {
                    Button {
                        viewModel.clear()
                    } label: {
                        XeidBarLabel(text: "New text", action: true, wide: false)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(XeidCellButtonStyle())
                }
            }

            // The editor stretches to the buttons on a tall screen; the
            // whole thing scrolls when the keyboard is up or the result is long
            GeometryReader { proxy in
                ScrollView {
                    Group {
                        switch viewModel.state {
                        case .result(let analysis):
                            results(analysis)
                        default:
                            inputScreen
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onChange(of: hasResult) { _, arrived in
            // Every completed scan counts on the profile; a seeded
            // screenshot result does not
            if arrived, !isDebugSeeded {
                ProgressStore.shared.recordTextScanned()
            }
        }
        .onAppear {
            #if DEBUG
            if let debugAnalysis {
                viewModel.state = .result(debugAnalysis)
            }
            #endif
        }
        .onDisappear {
            // Cancel any in-flight analysis
            viewModel.cancel()
        }
    }

    // MARK: Derived state
    private var isDebugSeeded: Bool {
        #if DEBUG
        return debugAnalysis != nil
        #else
        return false
        #endif
    }

    private var unavailableMessage: String? {
        if case .unavailable(let message) = viewModel.availability {
            return message
        }
        return nil
    }

    private var hasResult: Bool {
        if case .result = viewModel.state { return true }
        return false
    }

    private var hasFailed: Bool {
        if case .failed = viewModel.state { return true }
        return false
    }

    private var isAnalyzing: Bool {
        switch viewModel.state {
        case .analyzing, .refining:
            return true
        default:
            return false
        }
    }

    private var canAnalyze: Bool {
        unavailableMessage == nil
            && !isAnalyzing
            && !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Input screen
    private var inputScreen: some View {
        VStack(spacing: 0) {
            titleBlock(eyebrow: "Fallacy Finder", line: "Paste anything.", emphasis: "Read it back.")
                .padding(.bottom, 28)

            editorBlock
                .padding(.horizontal, 24)

            bottomBlock
        }
    }

    // Magenta-dot eyebrow over a two-line headline, the second line 400
    private func titleBlock(eyebrow: String, line: String, emphasis: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            XeidEyebrow(text: eyebrow, dot: XeidColor.magenta)
            VStack(alignment: .leading, spacing: 0) {
                Text(line)
                    .xeidTitle()
                Text(emphasis)
                    .xeidText(30, weight: .regular, lineHeight: 1.2, tracking: -0.035, relativeTo: .title)
            }
            .padding(.top, 15)
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 4, leading: 24, bottom: 0, trailing: 24))
    }

    // The editor and its helper row
    private var editorBlock: some View {
        VStack(spacing: 12) {
            editor

            HStack(alignment: .center, spacing: 12) {
                Text("Sentence by sentence, up to 4,000 characters")
                    .xeidCaption()
                Spacer(minLength: 0)
                // Verbatim so the cap reads "4000", not the locale's "4,000"
                Text(verbatim: "\(viewModel.inputText.count) / \(viewModel.maxCharacters)")
                    .font(XeidFont.eyebrow)
                    .tracking(0.1 * XeidFont.eyebrowSize)
                    .foregroundColor(XeidColor.secondary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // White, hairline, radius 14, 20pt padding. Grows with the text and
    // takes the free height; focused shows the blue border and ring.
    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if viewModel.inputText.isEmpty {
                Text(placeholder)
                    .xeidText(XeidFont.cardTitleSize, lineHeight: 1.45, color: XeidColor.secondary, relativeTo: .title3)
                    .allowsHitTesting(false)
            }
            TextField("", text: $viewModel.inputText, axis: .vertical)
                .lineLimit(6...)
                .font(XeidFont.inter(XeidFont.cardTitleSize, relativeTo: .title3))
                .foregroundColor(XeidColor.ink)
                .tint(XeidColor.blue)
                .focused($editorFocused)
                .disabled(isAnalyzing)
                .onChange(of: viewModel.inputText) { _, newValue in
                    // Enforce the input cap
                    if newValue.count > viewModel.maxCharacters {
                        viewModel.inputText = String(newValue.prefix(viewModel.maxCharacters))
                    }
                }
                .accessibilityLabel(placeholder)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(XeidColor.cell)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .strokeBorder(editorFocused ? XeidColor.blue : XeidColor.hairline, lineWidth: 1))
        .background {
            if editorFocused {
                RoundedRectangle(cornerRadius: 17)
                    .strokeBorder(XeidColor.blue.opacity(0.12), lineWidth: 3)
                    .padding(-3)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture { editorFocused = true }
    }

    // Status, Paste / Analyze, and the on-device footnote
    private var bottomBlock: some View {
        VStack(spacing: 16) {
            statusRow

            HStack(spacing: 10) {
                Button("Paste") {
                    viewModel.paste()
                }
                .buttonStyle(XeidOutlinePillButtonStyle())
                .frame(width: 118)
                .disabled(isAnalyzing)

                Button(hasFailed ? "Retry" : "Analyze") {
                    editorFocused = false
                    Task { await viewModel.analyze() }
                }
                .buttonStyle(XeidPrimaryPillButtonStyle())
                .disabled(!canAnalyze)
            }

            Text("Runs on Apple Intelligence, on this phone. Nothing is uploaded, and nothing is stored.")
                .xeidText(XeidFont.captionSize, lineHeight: 1.4, color: XeidColor.secondary, relativeTo: .callout)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(EdgeInsets(top: 24, leading: 24, bottom: 16, trailing: 24))
    }

    // Progress while analyzing, the failure or the availability message
    @ViewBuilder
    private var statusRow: some View {
        switch viewModel.state {
        case .analyzing(let done, let total):
            progressRow("Analyzing chunk \(min(done + 1, max(total, 1))) of \(total)")
        case .refining(let done, let total):
            progressRow(total > 0
                        ? "Double-checking flagged sentences \(min(done + 1, total)) of \(total)"
                        : "Double-checking flagged sentences")
        case .failed(let message):
            noticeRow(message)
        default:
            if let message = unavailableMessage {
                noticeRow(message)
            }
        }
    }

    private func progressRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(XeidColor.secondary)
                .frame(width: 16, height: 16)
            Text(text)
                .xeidSecondary()
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // The close mark in ink beside the message; no tint, no fill
    private func noticeRow(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            XeidSymbol(glyph: .close, size: 24, tone: .ink)
            Text(message)
                .xeidSecondary()
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Results
    private func results(_ analysis: FallacyAnalysis) -> some View {
        let anyAnalyzed = analysis.sentences.contains { $0.analyzed }
        let flagged = analysis.findings.count
        let topFinding = analysis.coverage.first(where: { $0.label != FallacyLabel.none })?.label

        return VStack(alignment: .leading, spacing: 0) {
            titleBlock(eyebrow: "\(analysis.sentences.count) \(analysis.sentences.count == 1 ? "sentence" : "sentences") \u{00B7} \(flagged) flagged",
                       line: headline(flagged: flagged).0,
                       emphasis: headline(flagged: flagged).1)
                .padding(.bottom, 22)

            if analysis.skippedSentenceCount > 0 {
                skippedNote(analysis)
            }

            // Coverage
            XeidEyebrow(text: "Coverage", color: XeidColor.secondary)
                .padding(EdgeInsets(top: 24, leading: 24, bottom: 16, trailing: 24))
            if analysis.coverage.isEmpty {
                Text("Nothing could be analyzed.")
                    .xeidBody(XeidColor.secondary)
                    .padding(.horizontal, 24)
            } else {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(analysis.coverage) { entry in
                        coverageRow(entry, highlighted: entry.label == topFinding)
                    }
                }
                .padding(.horizontal, 24)
            }

            // Findings, only when something was actually analyzed so
            // "No fallacies found" never appears for a fully declined text
            if anyAnalyzed {
                XeidEyebrow(text: "Findings", color: XeidColor.secondary)
                    .padding(EdgeInsets(top: 28, leading: 24, bottom: 14, trailing: 24))
                if analysis.findings.isEmpty {
                    Text("No fallacies found")
                        .xeidBody(XeidColor.secondary)
                        .padding(EdgeInsets(top: 20, leading: 24, bottom: 20, trailing: 24))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(XeidColor.cell)
                        .overlay(alignment: .top) { XeidHairline() }
                        .overlay(alignment: .bottom) { XeidHairline() }
                } else {
                    VStack(spacing: 0) {
                        ForEach(analysis.findings) { finding in
                            findingCard(finding)
                        }
                    }
                    .overlay(alignment: .bottom) { XeidHairline() }
                }
            }

            // Sentences the model never labeled
            if analysis.skippedSentenceCount > 0 {
                XeidEyebrow(text: "Not analyzed", color: XeidColor.secondary)
                    .padding(EdgeInsets(top: 28, leading: 24, bottom: 14, trailing: 24))
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(analysis.sentences.filter { !$0.analyzed }) { sentence in
                        Text(sentence.text)
                            .italic()
                            .xeidBody(XeidColor.secondary)
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer(minLength: 24)
        }
    }

    // "No tells in / this text.", "One tell in / this text.", "Three tells in / this paragraph."
    private func headline(flagged: Int) -> (String, String) {
        switch flagged {
        case 0: return ("No tells in", "this text.")
        case 1: return ("One tell in", "this text.")
        default: return ("\(numberWord(flagged)) tells in", "this paragraph.")
        }
    }

    private func numberWord(_ n: Int) -> String {
        let words = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve"]
        return words.indices.contains(n) ? words[n] : "\(n)"
    }

    // White row between hairlines: the hand mark in ink and the skip reasons
    private func skippedNote(_ analysis: FallacyAnalysis) -> some View {
        HStack(alignment: .top, spacing: 12) {
            XeidSymbol(glyph: .hand, size: 24, tone: .ink)
            Text(skippedMessage(analysis))
                .xeidSecondary(XeidColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(XeidColor.cell)
        .overlay(alignment: .top) { XeidHairline() }
        .overlay(alignment: .bottom) { XeidHairline() }
        .accessibilityElement(children: .combine)
    }

    // Distinguish sentences Apple's safety rules declined from sentences
    // the model simply never returned a label for
    private func skippedMessage(_ analysis: FallacyAnalysis) -> String {
        var reasons: [String] = []
        if analysis.explicitSentenceCount > 0 {
            reasons.append("\(sentenceCount(analysis.explicitSentenceCount)) contained explicit or violent language, which Fallacy Finder does not analyze")
        }
        if analysis.declinedSentenceCount > 0 {
            reasons.append("Apple's on-device safety rules declined \(sentenceCount(analysis.declinedSentenceCount))")
        }
        if analysis.unlabeledSentenceCount > 0 {
            reasons.append("the on-device model did not return a label for \(sentenceCount(analysis.unlabeledSentenceCount))")
        }
        let total = analysis.skippedSentenceCount
        let excluded = "\(sentenceCount(total)) \(total == 1 ? "was" : "were") not analyzed and excluded from the percentages."
        guard let first = reasons.first else { return excluded }
        let joined = ([first.prefix(1).uppercased() + first.dropFirst()] + reasons.dropFirst()).joined(separator: ", and ")
        return "\(joined). \(excluded)"
    }

    private func sentenceCount(_ count: Int) -> String {
        "\(count) \(count == 1 ? "sentence" : "sentences")"
    }

    // One coverage row: title, percent and a 3pt bar sized to the percent.
    // The top finding's bar is magenta, every other bar blue.
    private func coverageRow(_ entry: CoverageEntry, highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(entry.title)
                    .font(XeidFont.body)
                    .foregroundColor(XeidColor.ink)
                Spacer(minLength: 0)
                Text("\(entry.percent)%")
                    .font(XeidFont.body)
                    .foregroundColor(XeidColor.ink)
                    .monospacedDigit()
            }
            XeidProgressBar(fraction: Double(entry.percent) / 100,
                            fill: highlighted ? XeidColor.magenta : XeidColor.blue)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.title), \(entry.percent) percent")
    }

    // One finding: the sentence in quotes, the fallacy name with "open" to
    // its detail, and the model's why
    private func findingCard(_ finding: AnalyzedSentence) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("\u{201C}\(finding.text)\u{201D}")
                .xeidText(XeidFont.cardTitleSize, lineHeight: 1.45, tracking: -0.01, relativeTo: .title3)
                .fixedSize(horizontal: false, vertical: true)

            if let fallacy = finding.label.fallacy {
                NavigationLink {
                    FallacyDetailsView(exampleFallacy: fallacy)
                } label: {
                    FindingOpenRow(title: finding.label.title)
                }
                .buttonStyle(XeidCellButtonStyle())
            } else {
                Text(finding.label.title)
                    .font(XeidFont.inter(17, weight: .regular, relativeTo: .body))
                    .foregroundColor(XeidColor.ink)
            }

            if !finding.why.isEmpty {
                Text(finding.why)
                    .xeidText(17, lineHeight: 1.45, color: XeidColor.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(EdgeInsets(top: 20, leading: 24, bottom: 20, trailing: 24))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(XeidColor.cell)
        .overlay(alignment: .top) { XeidHairline() }
    }
}

// MARK: - FindingOpenRow
// The fallacy name 17/400 and "open" with a forward arrow; press shifts
// the name to secondary
private struct FindingOpenRow: View {
    let title: String

    @Environment(\.xeidPressed) private var pressed

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(XeidFont.inter(17, weight: .regular, relativeTo: .body))
                .foregroundColor(pressed ? XeidColor.secondary : XeidColor.ink)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Text("open")
                    .xeidCaption(pressed ? XeidColor.ink : XeidColor.secondary)
                XeidInlineGlyph(glyph: .forward, size: 15, color: pressed ? XeidColor.ink : XeidColor.secondary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Open \(title)")
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        FallacyFinderView()
    }
}
