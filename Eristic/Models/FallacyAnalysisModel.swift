//
//  FallacyAnalysisModel.swift
//  Eristic
//
//  Created by Fady A Eid on 9/2/26.
//

import Foundation
import NaturalLanguage

// Pure Foundation + NaturalLanguage types for the Fallacy Finder.
// No SwiftUI / UIKit / FoundationModels imports, so this file can be
// compiled and tested on macOS with plain swiftc.

// MARK: - FallacyLabel
// The label assigned to one sentence: none, or one of the 12 fallacies.
// Always keyed by FallaciesList id, never by title.
enum FallacyLabel: CaseIterable, Hashable {
    case none
    case strawMan
    case adHominem
    case falseDilemma
    case appealToIgnorance
    case slipperySlope
    case circularReasoning
    case hastyGeneralization
    case appealToAuthority
    case redHerring
    case equivocation
    case appealToEmotion
    case tuQuoque
    
    // The FallaciesList id for this label, nil for none
    var fallacyId: Int? {
        switch self {
        case .none: return nil
        case .strawMan: return 1
        case .adHominem: return 2
        case .falseDilemma: return 3
        case .appealToIgnorance: return 4
        case .slipperySlope: return 5
        case .circularReasoning: return 6
        case .hastyGeneralization: return 7
        case .appealToAuthority: return 8
        case .redHerring: return 9
        case .equivocation: return 10
        case .appealToEmotion: return 11
        case .tuQuoque: return 12
        }
    }
    
    // Look a label up by FallaciesList id
    init?(fallacyId: Int) {
        guard let match = FallacyLabel.allCases.first(where: { $0.fallacyId == fallacyId }) else {
            return nil
        }
        self = match
    }
    
    // The matching Fallacy from FallaciesList, nil for none
    var fallacy: Fallacy? {
        guard let id = fallacyId else { return nil }
        return FallaciesList.fallacies.first(where: { $0.id == id })
    }
    
    // Display title, resolved via FallaciesList
    var title: String {
        guard let id = fallacyId else { return "No fallacies" }
        return fallacy?.title ?? "Fallacy \(id)"
    }
}

// MARK: - SkipReason
// Why a sentence was not analyzed
enum SkipReason: Hashable {
    case declined // Apple's on-device safety rules declined the chunk
    case unlabeled // The model returned no verdict for the sentence
    case explicit // Sexually explicit or violent language; never sent to the model
}

// MARK: - AnalyzedSentence
// One sentence of the input with the verdict the model gave it
struct AnalyzedSentence: Identifiable {
    let index: Int // Global sentence index, 0..n-1
    let text: String // The sentence text
    var label: FallacyLabel // The fallacy found, or none
    var why: String // Short reason from the model
    var analyzed: Bool // false when the sentence was never labeled
    var skipReason: SkipReason? = nil // Why analyzed is false, nil when analyzed
    
    var id: Int { index }
    
    // Character count ignoring whitespace, used for coverage percentages
    var characterCount: Int {
        text.filter { !$0.isWhitespace }.count
    }
}

// MARK: - CoverageEntry
// The share of the analyzed text carrying one label
struct CoverageEntry: Identifiable {
    let label: FallacyLabel
    let percent: Int // Integer percent; all entries sum to exactly 100
    let characterCount: Int // Non-whitespace characters carrying this label
    
    var id: FallacyLabel { label }
    var title: String { label.title }
}

// MARK: - FallacyAnalysis
// The complete result of analyzing one text
struct FallacyAnalysis {
    let sentences: [AnalyzedSentence] // Every sentence, in order
    let coverage: [CoverageEntry] // No fallacies first, then fallacies by descending percent
    let findings: [AnalyzedSentence] // Sentences whose label is not none
    let skippedSentenceCount: Int // Sentences that were not analyzed
    let declinedSentenceCount: Int // Not analyzed: declined by Apple's safety rules
    let unlabeledSentenceCount: Int // Not analyzed: the model returned no verdict
    let explicitSentenceCount: Int // Not analyzed: explicit or violent language
    
    init(sentences: [AnalyzedSentence]) {
        self.sentences = sentences
        self.coverage = CoverageCalculator.coverage(for: sentences)
        self.findings = sentences.filter { $0.analyzed && $0.label != FallacyLabel.none }
        let skipped = sentences.filter { !$0.analyzed }
        self.skippedSentenceCount = skipped.count
        self.declinedSentenceCount = skipped.filter { $0.skipReason == .declined }.count
        self.unlabeledSentenceCount = skipped.filter { $0.skipReason == .unlabeled }.count
        self.explicitSentenceCount = skipped.filter { $0.skipReason == .explicit }.count
    }
}

// MARK: - SentenceSplitter
// Splits text into trimmed, non-empty sentences with NaturalLanguage
enum SentenceSplitter {
    static func split(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }
        return sentences
    }
}

// MARK: - SentenceChunker
// Groups sentence indices into chunks of at most maxSentences sentences
// and at most maxCharacters characters. A single sentence longer than
// maxCharacters still gets its own chunk.
enum SentenceChunker {
    static func chunk(_ sentences: [String], maxSentences: Int = 10, maxCharacters: Int = 1200) -> [[Int]] {
        let sentenceLimit = max(1, maxSentences)
        let characterLimit = max(1, maxCharacters)
        
        var chunks: [[Int]] = []
        var current: [Int] = []
        var currentCharacters = 0
        
        for (index, sentence) in sentences.enumerated() {
            let length = sentence.count
            let wouldOverflow = current.count >= sentenceLimit || currentCharacters + length > characterLimit
            
            if !current.isEmpty && wouldOverflow {
                chunks.append(current)
                current = []
                currentCharacters = 0
            }
            
            current.append(index)
            currentCharacters += length
        }
        
        if !current.isEmpty {
            chunks.append(current)
        }
        return chunks
    }
}

// MARK: - CoverageCalculator
// Computes coverage percentages in Swift, never by the model.
// Percentages use the largest-remainder method so they sum to exactly 100.
enum CoverageCalculator {
    // Working row used while rounding
    private struct Row {
        let label: FallacyLabel
        let count: Int
        var percent: Int
        let remainder: Int
    }
    
    static func coverage(for sentences: [AnalyzedSentence]) -> [CoverageEntry] {
        // Sum non-whitespace characters per label, analyzed sentences only
        var counts: [FallacyLabel: Int] = [:]
        for sentence in sentences where sentence.analyzed {
            counts[sentence.label, default: 0] += sentence.characterCount
        }
        
        let total = counts.values.reduce(0, +)
        guard total > 0 else { return [] }
        
        // Base order: none first, then by fallacy id. Only labels with count > 0.
        var rows: [Row] = []
        for label in FallacyLabel.allCases {
            guard let count = counts[label], count > 0 else { continue }
            let scaled = count * 100
            rows.append(Row(label: label,
                            count: count,
                            percent: scaled / total,
                            remainder: scaled % total))
        }
        
        // Largest remainder: hand the leftover points to the biggest remainders
        var leftover = 100 - rows.reduce(0) { $0 + $1.percent }
        let byRemainder = rows.indices.sorted { a, b in
            if rows[a].remainder != rows[b].remainder { return rows[a].remainder > rows[b].remainder }
            if rows[a].count != rows[b].count { return rows[a].count > rows[b].count }
            return (rows[a].label.fallacyId ?? 0) < (rows[b].label.fallacyId ?? 0)
        }
        for rowIndex in byRemainder where leftover > 0 {
            rows[rowIndex].percent += 1
            leftover -= 1
        }
        
        // Display order: none first, then fallacies by descending percent
        let ordered = rows.sorted { a, b in
            let aIsNone = a.label == FallacyLabel.none
            let bIsNone = b.label == FallacyLabel.none
            if aIsNone != bIsNone { return aIsNone }
            if a.percent != b.percent { return a.percent > b.percent }
            if a.count != b.count { return a.count > b.count }
            return (a.label.fallacyId ?? 0) < (b.label.fallacyId ?? 0)
        }
        
        return ordered.map { CoverageEntry(label: $0.label, percent: $0.percent, characterCount: $0.count) }
    }
}

// MARK: - ExplicitLanguageFilter
// Safety net in front of the model: sentences with sexually explicit terms
// or violent-threat phrases are not analyzed at all. Apple's guardrail is not
// deterministic for this kind of text, and a fallacy label on it would be
// wrong in any case. Plain profanity (damn, crap, an intensifier) is allowed
// through, so arguments that merely swear are still analyzed. The list is
// deliberately small and is not a complete profanity dictionary.
enum ExplicitLanguageFilter {
    static let pattern: NSRegularExpression? = try? NSRegularExpression(pattern: #"\b(dick|cock|pussy|cunt|tits|boobs|blowjob|handjob|penis|vagina|orgasm|horny|fuck (you|me|him|her|them|us)|fucked|screw (you|me|him|her)|suck my|nice ass|your ass|kill (you|him|her|them|myself|yourself)|beat (you|him|her|them) (up|until)|burn .{0,40} down|shoot (you|him|her|them|up)|stab|murder|slaughter|purge the|cleanse the|no mercy|exterminate|end my life|want to die|hurt (you|him|her|them|myself))\b"#, options: [.caseInsensitive])
    
    static func isExplicit(_ sentence: String) -> Bool {
        guard let pattern else { return false }
        let range = NSRange(sentence.startIndex..., in: sentence)
        return pattern.firstMatch(in: sentence, options: [], range: range) != nil
    }
}
