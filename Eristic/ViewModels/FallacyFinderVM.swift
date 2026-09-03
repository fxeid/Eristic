//
//  FallacyFinderVM.swift
//  Eristic
//
//  Created by Fady A Eid on 9/2/26.
//

import Foundation
import Combine
import UIKit
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - FinderAvailability
// Whether the on-device model can run on this device right now
enum FinderAvailability: Equatable {
    case available
    case unavailable(message: String)
}

// MARK: - FinderState
// The Fallacy Finder screen state
enum FinderState {
    case idle
    case analyzing(done: Int, total: Int)
    case refining(done: Int, total: Int)
    case result(FallacyAnalysis)
    case failed(String)
}

// MARK: - ChunkVerdict
// A verdict the model returned for one global sentence index
struct ChunkVerdict {
    let label: FallacyLabel
    let why: String
}

// MARK: - FallacyFinderVM
// ViewModel driving the Fallacy Finder. Runs only on-device with Apple's
// Foundation Models framework (iOS 26+, Apple Intelligence devices).
// No networking, no API keys. On older OS the VM reports unavailable.
@MainActor
final class FallacyFinderVM: ObservableObject {
    
    // Published properties for observing changes
    @Published var inputText: String = ""
    @Published var state: FinderState = .idle
    
    // Input cap enforced by the UI
    let maxCharacters = 4000
    
    // Chunk limits sent to the model. Five sentences per request measured
    // best (74% vs 72% at ten, 65% at two on the 143-sentence eval set).
    static let maxSentencesPerChunk = 5
    static let maxCharactersPerChunk = 1200
    
    // Message for devices that cannot run Apple Intelligence at all
    static let deviceNotEligibleMessage = "Fallacy Finder needs Apple Intelligence (iPhone 15 Pro or later) running iOS 26 or later."
    
    // The in-flight analysis, kept so the view can cancel it
    private var analysisTask: Task<Void, Never>?
    
    // MARK: Availability
    
    var availability: FinderAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible:
                    return .unavailable(message: Self.deviceNotEligibleMessage)
                case .appleIntelligenceNotEnabled:
                    return .unavailable(message: "Apple Intelligence is turned off. Turn it on in Settings > Apple Intelligence & Siri, then come back to Fallacy Finder.")
                case .modelNotReady:
                    return .unavailable(message: "The on-device model is still downloading or getting ready. Please try again shortly.")
                @unknown default:
                    return .unavailable(message: "Fallacy Finder is not available on this device right now.")
                }
            }
        }
        #endif
        return .unavailable(message: Self.deviceNotEligibleMessage)
    }
    
    // MARK: Actions
    
    // Analyze the current input text, chunk by chunk, sequentially.
    // The work runs inside a Task stored on the VM so the view can cancel it.
    func analyze() async {
        analysisTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            await self.runAnalysis()
        }
        analysisTask = task
        await task.value
    }
    
    // Cancel any in-flight analysis. A progress state is reset to idle so the
    // screen never stays on a spinner after the task is gone.
    func cancel() {
        analysisTask?.cancel()
        analysisTask = nil
        switch state {
        case .analyzing, .refining:
            state = .idle
        default:
            break
        }
    }
    
    // Replace the input with the clipboard contents, capped
    func paste() {
        guard let pasted = UIPasteboard.general.string else { return }
        inputText = String(pasted.prefix(maxCharacters))
        state = .idle
    }
    
    // Clear the input and any result
    func clear() {
        cancel()
        inputText = ""
        state = .idle
    }
    
    // MARK: Analysis
    
    private func runAnalysis() async {
        if case .unavailable(let message) = availability {
            state = .failed(message)
            return
        }
        
        let text = String(inputText.prefix(maxCharacters)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            state = .failed("Paste or type some text to analyze.")
            return
        }
        
        let sentences = SentenceSplitter.split(text)
        guard !sentences.isEmpty else {
            state = .failed("No sentences were found in the text.")
            return
        }
        
        // Sentences with explicit or violent language never reach the model;
        // they are reported as not analyzed. The rest is chunked as usual and
        // chunk indices are mapped back to global sentence indices.
        let explicit = Set(sentences.indices.filter { ExplicitLanguageFilter.isExplicit(sentences[$0]) })
        let analyzable = sentences.indices.filter { !explicit.contains($0) }
        let chunks = SentenceChunker.chunk(analyzable.map { sentences[$0] },
                                           maxSentences: Self.maxSentencesPerChunk,
                                           maxCharacters: Self.maxCharactersPerChunk)
            .map { $0.map { analyzable[$0] } }
        state = .analyzing(done: 0, total: chunks.count)
        
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            var verdicts: [Int: ChunkVerdict] = [:]
            var declined = Set<Int>()
            
            for (position, chunk) in chunks.enumerated() {
                if Task.isCancelled { return }
                
                let outcome = await OnDeviceFallacyEngine.process(indices: chunk, sentences: sentences, allowSplit: true)
                
                if Task.isCancelled { return }
                
                switch outcome {
                case .done(let chunkVerdicts, let chunkDeclined):
                    verdicts.merge(chunkVerdicts) { current, _ in current }
                    declined.formUnion(chunkDeclined)
                case .failed(let message):
                    state = .failed(message)
                    return
                }
                
                state = .analyzing(done: position + 1, total: chunks.count)
            }
            
            // Second pass: flagged sentences (and cue-matched None sentences)
            // are re-asked within their fallacy family with a focused prompt.
            // Measured on the eval set: 74% -> 86% with zero false alarms.
            state = .refining(done: 0, total: 0)
            let refined = await OnDeviceFallacyEngine.refine(sentences: sentences, firstPass: verdicts) { [weak self] done, total in
                // The closure runs inside the analysis task; after cancel() the
                // flag is already set, so a late progress report must not
                // overwrite the idle state
                guard let self, !Task.isCancelled else { return }
                self.state = .refining(done: done, total: total)
            }
            verdicts = refined.verdicts
            declined.formUnion(refined.declined)
            
            if Task.isCancelled { return }
            
            // Declined chunks and sentences the model never returned a
            // verdict for are marked not analyzed, so they stay out of
            // the percentages instead of counting as fallacy-free
            let analyzed = sentences.enumerated().map { index, sentenceText -> AnalyzedSentence in
                if explicit.contains(index) {
                    return AnalyzedSentence(index: index, text: sentenceText, label: FallacyLabel.none, why: "", analyzed: false, skipReason: .explicit)
                }
                if declined.contains(index) {
                    return AnalyzedSentence(index: index, text: sentenceText, label: FallacyLabel.none, why: "", analyzed: false, skipReason: .declined)
                }
                guard let verdict = verdicts[index] else {
                    return AnalyzedSentence(index: index, text: sentenceText, label: FallacyLabel.none, why: "", analyzed: false, skipReason: .unlabeled)
                }
                return AnalyzedSentence(index: index,
                                        text: sentenceText,
                                        label: verdict.label,
                                        why: verdict.why,
                                        analyzed: true)
            }
            
            state = .result(FallacyAnalysis(sentences: analyzed))
            return
        }
        #endif
        
        state = .failed(Self.deviceNotEligibleMessage)
    }
}

#if canImport(FoundationModels)

// MARK: - Guided generation types (iOS 26+)

// The label the model may pick. Raw values are the FallaciesList titles so
// the schema's allowed set matches the titles in the instructions exactly.
@available(iOS 26.0, *)
@Generable
enum FinderLabel: String {
    case noFallacy = "None"
    case strawMan = "Straw Man"
    case adHominem = "Ad Hominem"
    case falseDilemma = "False Dilemma"
    case appealToIgnorance = "Appeal to Ignorance"
    case slipperySlope = "Slippery Slope"
    case circularReasoning = "Circular Reasoning"
    case hastyGeneralization = "Hasty Generalization"
    case appealToAuthority = "Appeal to Authority"
    case redHerring = "Red Herring"
    case equivocation = "Equivocation"
    case appealToEmotion = "Appeal to Emotion"
    case tuQuoque = "Tu Quoque"
    
    // Map to the app's label, which is keyed by FallaciesList id
    var label: FallacyLabel {
        switch self {
        case .noFallacy: return FallacyLabel.none
        case .strawMan: return .strawMan
        case .adHominem: return .adHominem
        case .falseDilemma: return .falseDilemma
        case .appealToIgnorance: return .appealToIgnorance
        case .slipperySlope: return .slipperySlope
        case .circularReasoning: return .circularReasoning
        case .hastyGeneralization: return .hastyGeneralization
        case .appealToAuthority: return .appealToAuthority
        case .redHerring: return .redHerring
        case .equivocation: return .equivocation
        case .appealToEmotion: return .appealToEmotion
        case .tuQuoque: return .tuQuoque
        }
    }
}

@available(iOS 26.0, *)
@Generable(description: "The verdict for one numbered sentence")
struct SentenceVerdict {
    @Guide(description: "The sentence number exactly as given in the prompt")
    var index: Int
    
    @Guide(description: "The fallacy this sentence commits, or None if it commits none")
    var label: FinderLabel
    
    @Guide(description: "Why the label fits, in under 25 words. Empty when the label is None")
    var why: String
}

@available(iOS 26.0, *)
@Generable(description: "Verdicts for every numbered sentence in the prompt")
struct ChunkVerdicts {
    // Number of sentences in the chunk being labelled. Set right before each
    // request so the schema forces exactly one verdict per sentence. Without
    // this, a one-sentence prompt can make the model keep emitting verdicts
    // until the context window overflows.
    nonisolated(unsafe) static var expectedCount = 1
    
    @Guide(description: "Exactly one verdict per numbered sentence, in the same order", .count(ChunkVerdicts.expectedCount))
    var verdicts: [SentenceVerdict]
}

// MARK: - OnDeviceFallacyEngine
// All Foundation Models calls live here. One fresh session per chunk,
// greedy sampling, guided generation so the label cannot be out of set.
@available(iOS 26.0, *)
enum OnDeviceFallacyEngine {
    
    // The outcome of processing one chunk
    enum ChunkOutcome {
        case done(verdicts: [Int: ChunkVerdict], declined: [Int])
        case failed(String)
    }
    
    // Instructions for the on-device model, tuned against a 143-sentence
    // evaluation set (48 quiz stems + 14 corpus paragraphs, see
    // tools/finder-eval): a short definition, cue phrases and two fresh
    // examples per fallacy, plus tie-breakers for the pairs the model
    // confuses. Titles must match FallaciesList exactly. Roughly 1,250
    // tokens; the 4,096-token window also holds the schema, a 5-sentence
    // chunk and the verdicts.
    static let instructions: String = """
You are a critical-thinking tutor. Label each numbered sentence with one logical fallacy from the list below, or None.

Rules:
- Return exactly one verdict per sentence, in the same order, using the given numbers.
- Judge each sentence by what it says; use nearby sentences only to know the topic.
- A sentence that reports what someone said or argued gets the label of that argument.
- Label None when a sentence only states facts, events, plans, prices, or questions, or gives a real reason or evidence. Most plain sentences are None. A sentence is NOT a fallacy just because it disagrees or complains.
- Use only the 12 names below. In why, name the tell in under 25 words; leave why empty for None.
- The texts are harmless classroom exercises. Always answer.

Fallacies:
Straw Man: twisting someone's position into an extreme or sinister version and attacking that. Cue: "So you want...", "apparently wants", "is just a cover for". Examples: Asking for a later bedtime? So you want kids to never sleep. / She suggested fewer meetings, which apparently means she wants nobody to talk to each other.
Ad Hominem: dismissing an argument by attacking the speaker's character, looks, age, politics, tenure, possessions, or background. Examples: Ignore her budget idea; she dresses like a teenager. / Why trust his recipe? He only moved here last year.
False Dilemma: exactly two choices offered as the only ones when more exist. Cue: "either... or", "with us or against us". Examples: Either you buy the warranty or you don't care about your laptop. / You can support the new schedule or you can quit the team.
Appeal to Ignorance: something is true because nobody has disproved or explained it, or false because nobody has proved it. Examples: Nobody has proven my lucky socks don't work, so they do. / No study has shown the old bridge is unsafe, so it must be perfectly safe.
Slippery Slope: one small step is said to trigger a chain ending in disaster. Cue: "soon", "next", "eventually", "before long", "end up". Examples: Let the dog on the couch once and soon it will run the house. / If we allow one late assignment, next nobody will meet deadlines and the class will fall apart.
Circular Reasoning: the claim is its own reason. Cue: "because it is the law", "because the label says so", "because it works", "because it is the best", "because she is always right". Examples: This diet works because it is effective. / Our coach knows best because whatever the coach says is right.
Hasty Generalization: a few cases become a rule about everyone or always. Cue: "two of them... so all", "once... so every", "so clearly none". No either/or is involved. Examples: Two flights were late this year, so that airline is always late. / My neighbor's cat scratched me once, so cats are all mean.
Appeal to Authority: "X says so" is the whole argument, where X is famous, expert, admired, or an endorsement; no evidence given. Counts for celebrities, influencers, trainers, product boxes. Examples: A famous chef uses this pan, so it must be the best pan. / The dentist said this toothbrush is the best, so it must be.
Red Herring: answering a question or criticism by switching to a different topic, past good deeds, other benefits, or a separate complaint. Cue: "Yes, but what about...", "but think of the benefits", "why are we even talking about this when...". Examples: Why is the rent late? Well, the hallway lights have been broken for weeks. / Sure the report has errors, but look how nice the cover page is.
Equivocation: one word used in two different meanings inside the same argument. Only when the SAME word shifts meaning. Examples: Bats fly; a baseball bat is a bat; so baseball bats fly. / The sign said fine for parking, so parking here must be fine.
Appeal to Emotion: guilt, pity, fear, anger, or vivid imagery is offered instead of evidence. Cue: "how could you", "poor little", "think of the children", slogans. Examples: Only a heartless person would vote against the new playground. / Buy the extended plan, or imagine your family stranded on a dark road.
Tu Quoque: rejecting advice or criticism because the critic does the very same thing. Cue: "you too", "look who's talking", "your desk is a mess", "I've seen you do it". Examples: You tell me to save money? You bought a boat last year! / Don't lecture me about being late; you missed the last two meetings yourself.

Tie-breakers:
- The critic is told they do the same thing = Tu Quoque; any other attack on the person = Ad Hominem.
- A chain of escalating consequences = Slippery Slope, not Straw Man or False Dilemma.
- "Two cases, so all or never" = Hasty Generalization, never False Dilemma.
- "It is true because it says so or because it is" = Circular Reasoning; "a person or expert says so" = Appeal to Authority.
- "Yes, but..." followed by a different topic = Red Herring, not None.
- Feelings pushed instead of reasons = Appeal to Emotion, not None.

REMEMBER: one verdict per sentence, in order. Label None unless the sentence clearly matches one of the 12. DO NOT invent labels.
"""
    
    // Prompt for one chunk. Sentences are numbered chunk-locally from 0
    // (chunks hold at most 5 sentences, so numbers stay single-digit);
    // verdicts map back to global indices positionally through `indices`.
    static func makePrompt(indices: [Int], sentences: [String]) -> String {
        var lines = ["Label each numbered sentence."]
        for (local, global) in indices.enumerated() where sentences.indices.contains(global) {
            lines.append("[\(local)] \(sentences[global])")
        }
        return lines.joined(separator: "\n")
    }
    
    // Ask the model for one chunk and validate what comes back: local
    // numbers must belong to this chunk, duplicates are ignored. The
    // result is keyed by global sentence index.
    static func requestVerdicts(indices: [Int], sentences: [String]) async throws -> [Int: ChunkVerdict] {
        // A cancelled run must not keep the on-device model busy
        try Task.checkCancellation()
        
        let session = LanguageModelSession(instructions: instructions)
        let options = GenerationOptions(sampling: .greedy)
        let prompt = makePrompt(indices: indices, sentences: sentences)
        
        // Pin the verdict count to the number of sentences in this prompt
        let sentenceCount = indices.filter { sentences.indices.contains($0) }.count
        guard sentenceCount > 0 else { return [:] }
        ChunkVerdicts.expectedCount = sentenceCount
        
        let response = try await session.respond(to: prompt, generating: ChunkVerdicts.self, options: options)
        
        var verdicts: [Int: ChunkVerdict] = [:]
        for verdict in response.content.verdicts {
            guard indices.indices.contains(verdict.index) else { continue }
            let global = indices[verdict.index]
            guard verdicts[global] == nil else { continue }
            let why = verdict.why.trimmingCharacters(in: .whitespacesAndNewlines)
            verdicts[global] = ChunkVerdict(label: verdict.label.label, why: why)
        }
        return verdicts
    }
    
    // Process one chunk. On exceededContextWindowSize retry once split in
    // half; on guardrailViolation (or refusal) retry in halves down to single
    // sentences and decline only what still fails; every other error becomes
    // a friendly failure message.
    static func process(indices: [Int], sentences: [String], allowSplit: Bool) async -> ChunkOutcome {
        do {
            var verdicts = try await requestVerdicts(indices: indices, sentences: sentences)
            
            // Sentences the model left out, or returned under an invalid
            // number, are asked for once more in a fresh session. Whatever
            // is still missing stays absent and is reported as not analyzed.
            let missing = indices.filter { verdicts[$0] == nil }
            if !missing.isEmpty {
                let retry = try? await requestVerdicts(indices: missing, sentences: sentences)
                verdicts.merge(retry ?? [:]) { current, _ in current }
            }
            return .done(verdicts: verdicts, declined: [])
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize:
                guard allowSplit, indices.count > 1 else {
                    return .failed(message(for: error))
                }
                let middle = indices.count / 2
                let first = await process(indices: Array(indices[..<middle]), sentences: sentences, allowSplit: false)
                if Task.isCancelled { return .failed("The analysis was cancelled.") }
                let second = await process(indices: Array(indices[middle...]), sentences: sentences, allowSplit: false)
                return merge(first, second)
            case .guardrailViolation, .refusal:
                // Usually only one sentence trips the safety check. Retry the
                // chunk in halves down to single sentences so the rest of the
                // text is still analyzed; only the offending sentence is
                // declined. This split is independent of allowSplit: halves
                // are strictly smaller, so recursion always terminates.
                guard indices.count > 1 else {
                    return .done(verdicts: [:], declined: indices)
                }
                let middle = indices.count / 2
                let first = await process(indices: Array(indices[..<middle]), sentences: sentences, allowSplit: allowSplit)
                if Task.isCancelled { return .failed("The analysis was cancelled.") }
                let second = await process(indices: Array(indices[middle...]), sentences: sentences, allowSplit: allowSplit)
                return merge(first, second)
            default:
                return .failed(message(for: error))
            }
        } catch {
            if error is CancellationError {
                return .failed("The analysis was cancelled.")
            }
            return .failed(error.localizedDescription)
        }
    }
    
    // Combine the outcomes of the two halves of a split chunk
    static func merge(_ first: ChunkOutcome, _ second: ChunkOutcome) -> ChunkOutcome {
        switch (first, second) {
        case (.done(let firstVerdicts, let firstDeclined), .done(let secondVerdicts, let secondDeclined)):
            return .done(verdicts: firstVerdicts.merging(secondVerdicts) { current, _ in current },
                         declined: firstDeclined + secondDeclined)
        case (.failed(let message), _), (_, .failed(let message)):
            return .failed(message)
        }
    }
    
    // A friendly message for every GenerationError case
    static func message(for error: LanguageModelSession.GenerationError) -> String {
        switch error {
        case .exceededContextWindowSize:
            return "This part of the text is too long for the on-device model. Try a shorter passage or split it into paragraphs."
        case .assetsUnavailable:
            return "The on-device model isn't available right now. Make sure Apple Intelligence is set up, then try again."
        case .guardrailViolation:
            return "Apple's on-device safety rules declined part of the text."
        case .unsupportedGuide:
            return "Fallacy Finder asked the model for a format it doesn't support. Please update the app."
        case .unsupportedLanguageOrLocale:
            return "The on-device model doesn't support this language yet. Try text in English."
        case .decodingFailure:
            return "The model's answer couldn't be read. Try again or simplify the text."
        case .rateLimited:
            return "The on-device model is busy. Wait a moment and try again."
        case .concurrentRequests:
            return "Another analysis is still running. Wait for it to finish, then try again."
        case .refusal:
            return "The on-device model declined to analyze part of the text."
        @unknown default:
            return error.localizedDescription
        }
    }
}

#endif
