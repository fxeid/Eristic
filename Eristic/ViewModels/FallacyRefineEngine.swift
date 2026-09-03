//
//  FallacyRefineEngine.swift
//  Eristic
//
//  Created by Fady A Eid on 9/3/26.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels

// MARK: - Guided generation types for the second pass (iOS 26+)

@available(iOS 26.0, *)
@Generable(description: "One refined verdict for one numbered sentence")
struct RefinedVerdict {
    @Guide(description: "The sentence number exactly as given in the prompt")
    var index: Int
    @Guide(description: "The fallacy this sentence commits, chosen only from the options listed in the instructions, or None")
    var label: FinderLabel
    @Guide(description: "Why the label fits, in under 25 words. Empty when the label is None")
    var why: String
}
@available(iOS 26.0, *)
@Generable(description: "Refined verdicts for every numbered sentence in the prompt")
struct RefinedVerdicts {
    nonisolated(unsafe) static var expectedCount = 1
    @Guide(description: "Exactly one verdict per numbered sentence, in the same order", .count(RefinedVerdicts.expectedCount))
    var verdicts: [RefinedVerdict]
}

// MARK: - FallacyFamily
// A group of fallacies the model tends to confuse, with a focused prompt
// listing only those options, and cue words that route None sentences here.
@available(iOS 26.0, *)
@Generable(description: "Hasty Generalization when a trait is assumed from a group label or a few cases, otherwise None")
enum StereotypeLabel: String {
    case noFallacy = "None"
    case hastyGeneralization = "Hasty Generalization"
    var label: FallacyLabel { self == .noFallacy ? FallacyLabel.none : .hastyGeneralization }
}
@available(iOS 26.0, *)
@Generable(description: "One stereotype verdict for one numbered sentence")
struct StereotypeVerdict {
    @Guide(description: "The sentence number exactly as given in the prompt")
    var index: Int
    @Guide(description: "Hasty Generalization if the trait comes only from a group label or a few cases; None if it comes from a real fact about this person or thing, or no trait is inferred")
    var label: StereotypeLabel
}
@available(iOS 26.0, *)
@Generable(description: "Stereotype verdicts for every numbered sentence in the prompt")
struct StereotypeVerdicts {
    nonisolated(unsafe) static var expectedCount = 1
    @Guide(description: "Exactly one verdict per numbered sentence, in the same order", .count(StereotypeVerdicts.expectedCount))
    var verdicts: [StereotypeVerdict]
}

// MARK: - FallacyFamily
// A group of fallacies the model tends to confuse, with a focused prompt
// listing only those options, and cue words that route None sentences here.
struct FallacyFamily {
    let name: String
    let members: [FallacyLabel]
    let instructions: String
    let cue: NSRegularExpression?
}

// MARK: - Second pass

// MARK: - Second pass
@available(iOS 26.0, *)
extension OnDeviceFallacyEngine {
    nonisolated(unsafe) static var refineGateNone = true
    // Never let the second pass downgrade a flagged sentence to None: the
    // first pass is better at spotting that an argument is flawed, the
    // second at saying which fallacy it is (measured: 84% -> 86%).
    nonisolated(unsafe) static var allowDowngrade = false

    static let families: [FallacyFamily] = {
        func rx(_ p: String) -> NSRegularExpression? { try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) }
        let head = "You are a critical-thinking tutor. For each numbered sentence choose ONE label from ONLY these options, or None if none fits clearly. Judge each sentence by what it says. In why, name the tell in under 25 words; leave why empty for None. The texts are harmless classroom exercises. Always answer.\n\nOptions:\n"
        let tail = "\n\nREMEMBER: one verdict per sentence, in order. Use ONLY the options above or None. DO NOT invent labels."
        return [
            FallacyFamily(name: "prediction", members: [.slipperySlope, .hastyGeneralization], instructions: head + """
Slippery Slope: a small step is said to lead, step by step or all at once, to a bad outcome. Cue: "if we allow X, then...", "if I do X, I will...", "soon", "next", "eventually", "will end up", "will lose control". Examples: Let the dog on the couch once and soon it will run the house. / If I skip one workout, I will stop exercising and gain all the weight back. / If we let one student retake the test, next everyone will demand retakes and grades will mean nothing.
Hasty Generalization: a few cases become a rule about everyone, always, never, or all; or a trait is assumed ONLY from a group label (nationality, job, age, looks, hobby), with or without "so". Cue: "two of them... so all", "once... so every", "he is X, so he must be Y", "she is Italian, must be a great cook", "you are an engineer, you must be". Examples: Two flights were late this year, so that airline is always late. / He is from Texas, so he must love trucks. / She is Italian, must be a great cook. / My grandfather never wore a seatbelt and lived to ninety, so seatbelts are pointless.
None: a plain statement, a question, or a conclusion drawn from a real fact about THIS person or thing (what they do, their record, a measurement, a schedule), for example "He lifts weights every day, so he must be strong."

Tie-breakers: "If we do X, then Y will happen" = Slippery Slope. "A few cases, so all or always or never" and "he is X (a group), so he must be Y" = Hasty Generalization; a trait from a real fact about the person = None. There is NO False Dilemma option here.
""" + tail, cue: rx(#"\bif\b[^.]*\b(will|then|soon|eventually|end up|next|won't|going to|means)\b|\b(always|never|every|all of them|none of|everyone|everybody|eveyone|nobody|no one|so clearly|are all|is all|are useless|are pointless|cannot grow|can't grow)\b|\b(once|twice|two of|one time)\b[^.]*\b(so|now|then)\b|\b(now|soon|next)\b[^.]*\bwill\b"#)),
            FallacyFamily(name: "distortion", members: [.strawMan, .falseDilemma], instructions: head + """
Straw Man: restating someone's position as something more extreme or sinister than what they said, then attacking that version. Cue: "So you want...", "apparently wants", "the real proposal here is", "is accused of", "would never support a plan to". Examples: Asking for a later bedtime? So you want kids to never sleep. / She suggested fewer meetings, which apparently means she wants nobody to talk to each other. / Favor a shorter commute? You just want everyone to stop working.
False Dilemma: ONLY when the sentence itself offers exactly two options as the only possible ones. Cue: "either... or", "with us or against us", "you have two choices". Examples: Either you buy the warranty or you don't care about your laptop. / You can support the new schedule or you can quit the team.
None: a plain statement, a question, or a fair summary of what someone actually said.

Tie-breakers: exaggerating what the other person proposed = Straw Man; exactly two options offered = False Dilemma; if neither fits, None.
""" + tail, cue: rx(#"\b(so you want|you want|apparently|the real proposal|is accused of|either|or you|with us or against|two choices|only two)\b"#)),
            FallacyFamily(name: "person", members: [.adHominem, .tuQuoque], instructions: head + """
Ad Hominem: dismissing an argument by attacking the speaker's character, looks, age, politics, tenure, possessions, or background. Examples: Ignore her budget idea; she dresses like a teenager. / Why trust his recipe? He only moved here last year.
Tu Quoque: rejecting advice or criticism because the critic does the very same thing. Cue: "you too", "look who's talking", "I've seen you do it", "you did the same". Examples: You tell me to save money? You bought a boat last year! / Don't lecture me about being late; you missed the last two meetings yourself.
None: a plain statement, a question such as "What do you mean you don't trust him?", or a fair point about the argument itself. A question that merely asks is NOT an attack. An insult, compliment, or crude remark on its own, with no argument, idea, or advice being dismissed, is None (for example "You are an idiot." or "Nice haircut."). Ad Hominem and Tu Quoque both need an argument or position that is being brushed aside.

Tie-breaker: the critic is told they do the same thing = Tu Quoque; any other attack on the person = Ad Hominem.
""" + tail, cue: rx(#"\b(you too|look who|yourself|your own|one to talk|can't even|you did the same|seen you)\b"#)),
            FallacyFamily(name: "evidence", members: [.appealToAuthority, .circularReasoning, .appealToIgnorance], instructions: head + """
Appeal to Authority: "X says so" is the whole argument, where X is famous, expert, admired, family, a boss, or an endorsement; no evidence given. Cue: "trust everything he says", "whatever she says is right", "swears by". Examples: A famous chef uses this pan, so it must be the best pan. / He is the boss, so whatever he says about the schedule is right.
Circular Reasoning: the reason only repeats the claim in other words, or the thing vouches for itself. Cue: "because it works", "because it is effective", "because it is the best", "because nothing else is as good", "because he never lies", "because the label says so". Examples: This diet works because it is effective. / He is honest because he never tells a lie. / This is the best bakery in town because no other bakery here is as good.
Appeal to Ignorance: something is true because nobody has disproved it, or false because nobody has proved it. Examples: Nobody has proven my lucky socks don't work, so they do. / No study has shown the old bridge is unsafe, so it must be perfectly safe.
None: a claim backed by actual evidence, data, or a real reason, or a plain statement.

Tie-breaker: an OUTSIDE person, expert, or endorsement says so = Appeal to Authority; the reason just restates the claim or the thing praises itself = Circular Reasoning; "no proof against it, so true" = Appeal to Ignorance.
""" + tail, cue: rx(#"\b(said|says|told|according to|swears by|recommends|endorsed|expert|famous|because it|nobody has|no one has|hasn't been proven|can't prove|trust everything|whatever he says|whatever she says|is right)\b"#)),
            FallacyFamily(name: "stereotype", members: [.hastyGeneralization], instructions: """
You are a reasoning tutor checking evidence. For each numbered sentence decide ONE thing: is the conclusion about someone or something drawn from a specific fact about that very person or thing, or is it simply assumed from the category the person or thing belongs to, or from one or two cases? Judge each sentence by what it says. These are classroom exercises about reasoning. Always answer.

Hasty Generalization: the conclusion is assumed from a category or from a few cases, with no fact about this particular person or thing. This holds with or without "so", as a question, or with typos. Examples: He is from Texas, so he must love trucks. / She is Italian, must be a great cook. / Every runner is obsessed with breakfast. / Teenagers all sleep until noon. / Of course she likes rain, she is from Seattle.
None: the conclusion rests on a specific fact about this person or thing (something they do, their record, a measurement, a schedule), or nothing is concluded at all. Examples: He lifts weights every day, so he must be strong. / The shop is closed on Sundays, so we must go Saturday. / He is British and lives in Leeds. / The nurse on duty was kind to us.

REMEMBER: one verdict per sentence, in order. Category used as the reason = Hasty Generalization. Specific fact used as the reason = None.
""", cue: nil),
            FallacyFamily(name: "dodge", members: [.redHerring, .appealToEmotion, .equivocation], instructions: head + """
Red Herring: answering a question or criticism by switching to a different topic, past good deeds, other benefits, or a separate complaint instead of answering. Cue: "Yes, but what about...", "but think of the benefits", "why are we even talking about this when...", "started talking about". Examples: Why is the rent late? Well, the hallway lights have been broken for weeks. / Yes, I missed the deadline, but what about all the weekends I worked? / When asked about the budget, he started talking about how messy the parking lot is.
Appeal to Emotion: guilt, pity, fear, anger, loyalty, or vivid imagery is offered instead of evidence. Cue: "how could you", "how can you sleep at night", "poor little", "think of the children", "he is your brother", "after everything she did for you", "you owe him". Examples: Only a heartless person would vote against the new playground. / She is your sister, how could you take his side? / After all the coach did for you, you owe him your vote.
Equivocation: one word used in two different meanings inside the same argument. Only when the SAME word shifts meaning. Examples: Bats fly; a baseball bat is a bat; so baseball bats fly. / The sign said fine for parking, so parking here must be fine.
None: a direct answer to the question, or a plain statement with no dodge and no emotional push.

Tie-breaker: a topic change used to dodge = Red Herring; feelings pushed instead of reasons = Appeal to Emotion; one word with two meanings = Equivocation.
""" + tail, cue: rx(#"\b(yes,? but|but what about|what about|why are we even|think about|think of|imagine|how could you|heartless|poor|started talking about|look how|your brother|your sister|your mother|your father|is family|after everything|after all|you owe)\b"#)),
        ]
    }()

    // Strong cues that decide the family regardless of the first-pass label
    static let loyaltyCue = try? NSRegularExpression(pattern: #"\b(your (brother|sister|mother|father|mom|dad|son|daughter|family|own team)|is family|after everything|after all (he|she|they|we)|you owe)\b"#, options: [.caseInsensitive])
    static let authorityCue = try? NSRegularExpression(pattern: #"\b(trust everything|believe everything|whatever (he|she|they) says?|swears? by|is always right|knows best)\b"#, options: [.caseInsensitive])
    static let dilemmaCue = try? NSRegularExpression(pattern: #"\b(either|or you|or we|or else|with us or against|two choices|only two|no other option|nothing in between)\b"#, options: [.caseInsensitive])
    
    static func matches(_ rx: NSRegularExpression?, _ raw: String) -> Bool {
        let text = normalized(raw)
        return rx?.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) != nil
    }
    
    static func forcedFamily(for text: String) -> String? {
        // "Whatever he says is right" is about trusting the source even when
        // a family word is also present, so the authority cue is checked first
        if matches(authorityCue, text) { return "evidence" }
        if matches(loyaltyCue, text) { return "dodge" }
        return nil
    }
    
    // A downgrade to None is allowed only when the first-pass label's defining
    // cue is missing: a personal attack that is merely a question, or a False
    // Dilemma with no either/or in the sentence.
    // Words that show an argument, idea, or advice is in play; a personal
    // remark without any of them is a bare insult or compliment, not a fallacy
    static let argumentMarker = try? NSRegularExpression(pattern: #"\b(because|so|therefore|since|argument|opinion|idea|plan|proposal|advice|advis\w*|point|claim|suggest\w*|says?|said|think|believe|listen|ignore|trust|criti\w*|lecture|lectur\w*|urg\w*|against|complain\w*|preach\w*|nag\w*|judg\w*|blam\w*|accus\w*|hypocrit\w*|scold\w*|remind\w*|warn\w*|tell me|telling me|don't|doesn't|can't|shouldn't|why|about|wrong|right|always|never)\b"#, options: [.caseInsensitive])
    
    static func downgradeAllowed(first: FallacyLabel, text: String) -> Bool {
        switch first {
        case .adHominem, .tuQuoque:
            return text.trimmingCharacters(in: .whitespaces).hasSuffix("?") || !matches(argumentMarker, text)
        case .falseDilemma: return !matches(dilemmaCue, text)
        default: return false
        }
    }

    // "X is <group>, must be <trait>" and similar stereotype shapes: a trait
    // assumed from group membership is a Hasty Generalization, whatever the
    // first pass called it (often None or Ad Hominem)
    static let stereotypeCue = try? NSRegularExpression(pattern: #"\b(must|has to|have to|bound to|got to|gotta|probably|surely|obviously|naturally)( must)?( never| always)? (be|love|like|hate|know|want|eat|drink|drive|speak|play|have)\b|\bof course (he|she|they|you|it|that|those) (is|are|was|were|must|can't|cannot|never|always)\b|\b(typical|all|every|most|no) [a-z]+s? (is|are|was|were|love|hate|can't|cannot|never|always)\b|\b[a-z]+s (are all|are always|are never|are just|are so|can't|cannot|never|always)\b|\bwhat else (could|would|can) (he|she|they|you|it) be\b"#, options: [.caseInsensitive])

    static func family(for label: FallacyLabel) -> FallacyFamily? {
        families.first { $0.members.contains(label) }
    }
    static func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{2019}", with: "'").replacingOccurrences(of: "\u{2018}", with: "'")
    }
    static func family(matching raw: String) -> FallacyFamily? {
        let text = normalized(raw)
        let range = NSRange(text.startIndex..., in: text)
        return families.first { $0.cue?.firstMatch(in: text, options: [], range: range) != nil }
    }

    // Second pass: re-ask each flagged sentence within its fallacy family with
    // a short focused prompt (2-3 options + None). None sentences that match a
    // family's cue words are checked too. Runs after the first pass; the view
    // can cancel between batches.
    struct RefineOutcome {
        var verdicts: [Int: ChunkVerdict]
        var declined: Set<Int>
    }
    
    static func refine(sentences: [String], firstPass: [Int: ChunkVerdict], progress: (@MainActor (Int, Int) -> Void)? = nil) async -> RefineOutcome {
        var result = firstPass
        var declined = Set<Int>()
        // group sentence indices by family
        var groups: [String: [Int]] = [:]
        let claimLabels: [FallacyLabel] = [.slipperySlope, .falseDilemma, .strawMan, .hastyGeneralization]
        for (i, v) in firstPass {
            // Strong cues override the label-based routing: loyalty pressure
            // belongs to the emotion/dodge family and "trust whatever X says"
            // to the evidence family, whatever the first pass called them.
            if let forced = forcedFamily(for: sentences[i]) {
                groups[forced, default: []].append(i)
                continue
            }
            // The stereotype check only takes sentences whose first-pass label
            // is one the model confuses with a stereotype; other labels keep
            // their own family even when the sentence contains "must be".
            let stereotypeCandidates: [FallacyLabel] = [FallacyLabel.none, .adHominem, .strawMan, .falseDilemma, .hastyGeneralization]
            if stereotypeCandidates.contains(v.label), matches(stereotypeCue, sentences[i]) {
                groups["stereotype", default: []].append(i)
                continue
            }
            if claimLabels.contains(v.label) {
                // Route by cue words: predictions and generalizations go to the
                // prediction family, everything else to distortion. If the cue
                // pattern is unavailable, fall back to the label's own family.
                if let pred = families.first(where: { $0.name == "prediction" }), let cue = pred.cue {
                    let text = normalized(sentences[i])
                    let range = NSRange(text.startIndex..., in: text)
                    let isPrediction = cue.firstMatch(in: text, options: [], range: range) != nil
                    groups[isPrediction ? "prediction" : "distortion", default: []].append(i)
                } else if let f = family(for: v.label) {
                    groups[f.name, default: []].append(i)
                }
            } else if v.label == .adHominem || v.label == .tuQuoque, !matches(argumentMarker, sentences[i]) {
                // A personal remark with no argument, idea, or advice in play is a
                // bare insult, compliment, or crude comment, not a fallacy: both
                // labels require a position that is being brushed aside
                result[i] = ChunkVerdict(label: FallacyLabel.none, why: "")
                continue
            } else if v.label == .falseDilemma, !matches(dilemmaCue, sentences[i]) {
                // False Dilemma presents exactly two options; without any
                // either/or wording in the sentence the label is a false alarm
                result[i] = ChunkVerdict(label: FallacyLabel.none, why: "")
                continue
            } else if v.label == .circularReasoning {
                continue // first pass is more reliable than the family pass for this label
            } else if v.label != FallacyLabel.none, let f = family(for: v.label) { groups[f.name, default: []].append(i) }
            else if v.label == FallacyLabel.none, refineGateNone, let f = family(matching: sentences[i]) { groups[f.name, default: []].append(i) }
        }
        // Batches of at most 5 sentences per family, so progress can be reported
        var batches: [(family: FallacyFamily, indices: [Int])] = []
        for fam in families {
            guard let idxs = groups[fam.name]?.sorted(), !idxs.isEmpty else { continue }
            // The stereotype check runs one sentence per request: several
            // stereotypes in one prompt read as unsafe content to the guardrail
            let size = fam.name == "stereotype" ? 1 : 5
            for start in stride(from: 0, to: idxs.count, by: size) {
                batches.append((fam, Array(idxs[start..<min(start + size, idxs.count)])))
            }
        }
        if Task.isCancelled { return RefineOutcome(verdicts: result, declined: declined) }
        await progress?(0, batches.count)
        
        for (position, entry) in batches.enumerated() {
            if Task.isCancelled { return RefineOutcome(verdicts: result, declined: declined) }
            let fam = entry.family
            let batch = entry.indices
            do {
                var lines = ["Label each numbered sentence."]
                for (local, global) in batch.enumerated() { lines.append("[\(local)] \(sentences[global])") }
                let session = LanguageModelSession(instructions: fam.instructions)
                if fam.name == "stereotype" {
                    StereotypeVerdicts.expectedCount = batch.count
                    let r = try await session.respond(to: lines.joined(separator: "\n"), generating: StereotypeVerdicts.self, options: GenerationOptions(sampling: .greedy))
                    var seen = Set<Int>()
                    for v in r.content.verdicts where batch.indices.contains(v.index) && !seen.contains(v.index) {
                        seen.insert(v.index)
                        let why = v.label == .hastyGeneralization ? "Assumes a trait from a group label or a few cases instead of evidence about this person." : ""
                        result[batch[v.index]] = ChunkVerdict(label: v.label.label, why: why)
                    }
                    await progress?(position + 1, batches.count)
                    continue
                }
                RefinedVerdicts.expectedCount = batch.count
                let r = try await session.respond(to: lines.joined(separator: "\n"), generating: RefinedVerdicts.self, options: GenerationOptions(sampling: .greedy))
                for v in r.content.verdicts {
                    guard batch.indices.contains(v.index) else { continue }
                    let global = batch[v.index]
                    let newLabel = v.label.label
                    // Accept only labels inside the family (or None). A label from
                    // outside the family means the model disagreed with the routing;
                    // the first-pass verdict is kept in that case.
                    if newLabel == FallacyLabel.none, !allowDowngrade, let first = firstPass[global]?.label, first != FallacyLabel.none, !downgradeAllowed(first: first, text: sentences[global]) { continue }
                    if newLabel == FallacyLabel.none || fam.members.contains(newLabel) {
                        result[global] = ChunkVerdict(label: newLabel, why: v.why.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
            } catch let error as LanguageModelSession.GenerationError {
                // For the stereotype check a declined sentence is reported as
                // not analyzed: its first-pass label is unreliable by design.
                // Other families keep the first-pass verdicts for that batch.
                if fam.name == "stereotype" {
                    switch error {
                    case .guardrailViolation, .refusal:
                        for global in batch { result[global] = nil; declined.insert(global) }
                    default:
                        break
                    }
                }
            } catch {
                // A failed second pass keeps the first-pass verdicts for that batch
            }
            if Task.isCancelled { return RefineOutcome(verdicts: result, declined: declined) }
            await progress?(position + 1, batches.count)
        }
        return RefineOutcome(verdicts: result, declined: declined)
    }
}

#endif
