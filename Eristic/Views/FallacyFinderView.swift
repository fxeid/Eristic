//
//  FallacyFinderView.swift
//  Eristic
//
//  Created by Fady A Eid on 9/2/26.
//

import SwiftUI

// MARK: - FallacyFinderView
// Pushed from the hub, which already provides the NavigationView.
struct FallacyFinderView: View {
    // MARK: Properties
    @StateObject private var viewModel = FallacyFinderVM()
    @FocusState private var editorFocused: Bool
    
    // MARK: Body
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Unavailable card when the on-device model cannot run here
                if let message = unavailableMessage {
                    unavailableCard(message)
                }
                
                // Text input with placeholder and counter
                inputSection
                
                // Paste, Clear and Analyze
                buttonRow
                
                // Progress, results or error
                stateSection
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Fallacy Finder")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            // Cancel any in-flight analysis
            viewModel.cancel()
        }
    }
    
    // MARK: Derived state
    private var unavailableMessage: String? {
        if case .unavailable(let message) = viewModel.availability {
            return message
        }
        return nil
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
    
    private var canClear: Bool {
        if isAnalyzing || !viewModel.inputText.isEmpty {
            return true
        }
        if case .idle = viewModel.state {
            return false
        }
        return true
    }
    
    // MARK: Unavailable card
    private func unavailableCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title3)
            Text(message)
                .font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(6)
    }
    
    // MARK: Input
    private var inputSection: some View {
        VStack(alignment: .trailing, spacing: 4) {
            ZStack(alignment: .topLeading) {
                if viewModel.inputText.isEmpty {
                    Text("Paste or type an argument, a post, a speech...")
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $viewModel.inputText)
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
                    .focused($editorFocused)
                    .disabled(isAnalyzing)
            }
            .background(Color(.systemGray6))
            .cornerRadius(6)
            .onChange(of: viewModel.inputText) { _, newValue in
                // Enforce the input cap
                if newValue.count > viewModel.maxCharacters {
                    viewModel.inputText = String(newValue.prefix(viewModel.maxCharacters))
                }
            }
            
            Text("\(viewModel.inputText.count) / \(viewModel.maxCharacters)")
                .font(.caption)
                .foregroundColor(viewModel.inputText.count >= viewModel.maxCharacters ? .red : .gray)
        }
    }
    
    // MARK: Buttons
    private var buttonRow: some View {
        HStack {
            Button {
                viewModel.paste()
            } label: {
                hubButtonLabel("Paste", enabled: !isAnalyzing)
            }
            .disabled(isAnalyzing)
            
            Button {
                viewModel.clear()
            } label: {
                hubButtonLabel("Clear", enabled: canClear)
            }
            .disabled(!canClear)
            
            Button {
                editorFocused = false
                Task { await viewModel.analyze() }
            } label: {
                hubButtonLabel("Analyze", enabled: canAnalyze)
            }
            .disabled(!canAnalyze)
        }
    }
    
    // Same style as the hub buttons
    private func hubButtonLabel(_ title: String, enabled: Bool) -> some View {
        Text(title)
            .font(.title3)
            .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40)
            .foregroundColor(Color.white)
            .background(Color.blue)
            .cornerRadius(6)
            .opacity(enabled ? 1 : 0.5)
    }
    
    // MARK: State
    @ViewBuilder
    private var stateSection: some View {
        switch viewModel.state {
        case .idle:
            EmptyView()
        case .analyzing(let done, let total):
            HStack(spacing: 10) {
                ProgressView()
                Text("Analyzing chunk \(min(done + 1, max(total, 1))) of \(total)")
                    .font(.body)
                    .foregroundColor(.gray)
            }
            .padding(.top, 4)
        case .refining(let done, let total):
            HStack(spacing: 10) {
                ProgressView()
                Text(total > 0
                     ? "Double-checking flagged sentences \(min(done + 1, total)) of \(total)"
                     : "Double-checking flagged sentences")
                    .font(.body)
                    .foregroundColor(.gray)
            }
            .padding(.top, 4)
        case .result(let analysis):
            resultsSection(analysis)
        case .failed(let message):
            errorSection(message)
        }
    }
    
    // MARK: Results
    private func resultsSection(_ analysis: FallacyAnalysis) -> some View {
        let anyAnalyzed = analysis.sentences.contains { $0.analyzed }
        return VStack(alignment: .leading, spacing: 16) {
            if analysis.skippedSentenceCount > 0 {
                skippedNote(analysis)
            }
            
            // Coverage
            VStack(alignment: .leading, spacing: 10) {
                Text("Coverage").sectionHeader()
                if analysis.coverage.isEmpty {
                    Text("Nothing could be analyzed.")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                ForEach(analysis.coverage) { entry in
                    coverageRow(entry)
                }
            }
            
            // Findings, only when something was actually analyzed so
            // "No fallacies found" never appears for a fully declined text
            if anyAnalyzed {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Findings").sectionHeader()
                    if analysis.findings.isEmpty {
                        ReusableText(text: "No fallacies found", font: .body, color: .gray)
                    } else {
                        ForEach(analysis.findings) { finding in
                            findingRow(finding)
                            Divider()
                        }
                    }
                }
            }
            
            // Sentences the model never labeled
            if analysis.skippedSentenceCount > 0 {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Not analyzed").sectionHeader()
                    ForEach(analysis.sentences.filter { !$0.analyzed }) { sentence in
                        Text(sentence.text)
                            .italic()
                            .font(.body)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
    
    private func skippedNote(_ analysis: FallacyAnalysis) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .foregroundColor(.orange)
                .font(.title3)
            Text(skippedMessage(analysis))
                .font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(6)
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
    
    // One coverage row: title, percent and a bar sized to the percent
    private func coverageRow(_ entry: CoverageEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.title)
                    .font(.body)
                Spacer()
                Text("\(entry.percent)%")
                    .font(.body)
                    .bold()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                    Capsule()
                        .fill(entry.label == FallacyLabel.none ? Color.green : Color.red)
                        .frame(width: geo.size.width * CGFloat(entry.percent) / 100)
                }
            }
            .frame(height: 10)
        }
    }
    
    // One finding: the sentence, the tappable fallacy title, and the why
    private func findingRow(_ finding: AnalyzedSentence) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(finding.text)
                .italic()
                .font(.body)
            
            if let fallacy = finding.label.fallacy {
                NavigationLink(destination: FallacyDetailsView(exampleFallacy: fallacy)) {
                    Text(finding.label.title)
                        .bold()
                        .foregroundColor(.blue)
                }
            } else {
                Text(finding.label.title)
                    .bold()
                    .foregroundColor(.blue)
            }
            
            if !finding.why.isEmpty {
                Text(finding.why)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: Error
    private func errorSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "xmark.octagon.fill")
                    .foregroundColor(.red)
                    .font(.title3)
                Text(message)
                    .font(.body)
            }
            
            Button {
                Task { await viewModel.analyze() }
            } label: {
                hubButtonLabel("Retry", enabled: canAnalyze)
            }
            .disabled(!canAnalyze)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08))
        .cornerRadius(6)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        FallacyFinderView()
    }
}
