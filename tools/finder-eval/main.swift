import Foundation

struct QuizItem: Decodable { let text: String; let expected: String }
struct CorpusExpected: Decodable { let n: Int; let starts: String; let label: String; let chars: Int }
struct CorpusParagraph: Decodable { let paragraph: String; let text: String; let expected: [CorpusExpected] }

func labelName(_ l: FallacyLabel) -> String { l == FallacyLabel.none ? "None" : l.title }

@main
struct Harness {
    static func main() async {
        var args = Array(CommandLine.arguments.dropFirst())
        var instructionsPath: String? = nil, quizPath: String? = nil, corpusPath: String? = nil, single: String? = nil
        var seed = 1
        var chunkSize = 10
        var ensemble: [String] = []
        var refine = false
        while !args.isEmpty {
            let a = args.removeFirst()
            switch a {
            case "--instructions": instructionsPath = args.removeFirst()
            case "--quiz": quizPath = args.removeFirst()
            case "--corpus": corpusPath = args.removeFirst()
            case "--sentence": single = args.removeFirst()
            case "--seed": seed = Int(args.removeFirst()) ?? 1
            case "--chunk": chunkSize = Int(args.removeFirst()) ?? 10
            case "--refine": refine = true
            case "--nogate": OnDeviceFallacyEngine.refineGateNone = false
            case "--nodowngrade": OnDeviceFallacyEngine.allowDowngrade = false
            case "--ensemble": ensemble = args.removeFirst().split(separator: ",").map(String.init)
            
            default: print("unknown arg \(a)"); return
            }
        }
        if let p = instructionsPath, let text = try? String(contentsOfFile: p, encoding: .utf8) {
            OnDeviceFallacyEngine.instructions = text
        }
        print("instructions chars: \(OnDeviceFallacyEngine.instructions.count) chunk=\(chunkSize) refine=\(refine) gate=\(OnDeviceFallacyEngine.refineGateNone) ensemble=\(ensemble.count)")
        var total = 0, correct = 0
        var perLabelTotal: [String: Int] = [:], perLabelHit: [String: Int] = [:]
        var confusion: [String: Int] = [:]
        var noneTotal = 0, noneCorrect = 0, falseAlarms = 0

        func record(expected rawExpected: String, got: String, text: String) {
            // "A|B" means either outcome is acceptable; scored under the first name
            let alternatives = rawExpected.split(separator: "|").map { String($0) }
            let expected = alternatives.first ?? rawExpected
            total += 1
            perLabelTotal[expected, default: 0] += 1
            let ok = alternatives.contains(got) || (got == "SKIPPED" && (alternatives.contains("None") || alternatives.contains("DECLINED")))
            if ok { correct += 1; perLabelHit[expected, default: 0] += 1 }
            else { confusion["\(expected) -> \(got)", default: 0] += 1; print("  MISS [\(expected) -> \(got)] \(text.prefix(90))") }
            if got == "SKIPPED" { print("  SKIPPED (explicit) \(text.prefix(70))") }
            if expected == "None" { noneTotal += 1; if got == "None" { noneCorrect += 1 } else { falseAlarms += 1 } }
        }

        // Run a list of sentences through the real engine path and return label names by index
        func runOnce(_ sentences: [String]) async -> [Int: String] {
            var out: [Int: String] = [:]
            var firstPass: [Int: ChunkVerdict] = [:]
            let explicitIdx = Set(sentences.indices.filter { ExplicitLanguageFilter.isExplicit(sentences[$0]) })
            for i in explicitIdx { out[i] = "SKIPPED" }
            let analyzable = sentences.indices.filter { !explicitIdx.contains($0) }
            // Same chunking as the app: SentenceChunker over the analyzable subset, mapped back to global indices
            let subset = analyzable.map { sentences[$0] }
            let chunks = SentenceChunker.chunk(subset, maxSentences: chunkSize, maxCharacters: 1200).map { $0.map { analyzable[$0] } }
            for chunk in chunks {
                let outcome = await OnDeviceFallacyEngine.process(indices: chunk, sentences: sentences, allowSplit: true)
                switch outcome {
                case .done(let verdicts, let declined):
                    for (i, v) in verdicts { out[i] = labelName(v.label); firstPass[i] = v }
                    for i in declined { out[i] = "DECLINED" }
                    for i in chunk where out[i] == nil { out[i] = "UNLABELED" }
                case .failed(let msg):
                    for i in chunk { out[i] = "ERROR: \(msg)" }
                }
            }
            if refine {
                let outcome = await OnDeviceFallacyEngine.refine(sentences: sentences, firstPass: firstPass)
                for (i, v) in outcome.verdicts { out[i] = labelName(v.label) }
                for i in outcome.declined { out[i] = "DECLINED" }
            }
            return out
        }
        func run(_ sentences: [String]) async -> [Int: String] {
            if ensemble.isEmpty { return await runOnce(sentences) }
            var votes: [Int: [String]] = [:]
            for f in ensemble {
                if let t = try? String(contentsOfFile: f, encoding: .utf8) { OnDeviceFallacyEngine.instructions = t }
                let r = await runOnce(sentences)
                for (i, l) in r { votes[i, default: []].append(l) }
            }
            var out: [Int: String] = [:]
            for (i, ls) in votes {
                var counts: [String: Int] = [:]
                for l in ls { counts[l, default: 0] += 1 }
                let best = counts.max { a, b in a.value < b.value || (a.value == b.value && ls.firstIndex(of: a.key)! > ls.firstIndex(of: b.key)!) }!
                out[i] = best.key
            }
            return out
        }

        if let s = single {
            let sentences = SentenceSplitter.split(s)
            let r = await run(sentences)
            print("SINGLE: \(sentences.map { r[sentences.firstIndex(of: $0)!] ?? "?" })  for: \(s)")
        }

        if let qp = quizPath, let data = try? String(contentsOfFile: qp, encoding: .utf8) {
            var items = data.split(separator: "\n").compactMap { try? JSONDecoder().decode(QuizItem.self, from: Data($0.utf8)) }
            // deterministic shuffle so chunks mix labels
            var g = SystemRandomNumberGenerator(); _ = g
            var rng = seed
            items.sort { _, _ in rng = (rng &* 1103515245 &+ 12345) & 0x7fffffff; return rng % 2 == 0 }
            let sentences = items.map { $0.text }
            print("QUIZ: \(items.count) stems")
            let r = await run(sentences)
            for (i, item) in items.enumerated() { record(expected: item.expected, got: r[i] ?? "?", text: item.text) }
        }

        if let cp = corpusPath, let data = try? Data(contentsOf: URL(fileURLWithPath: cp)),
           let paras = try? JSONDecoder().decode([CorpusParagraph].self, from: data) {
            for p in paras {
                let sentences = SentenceSplitter.split(p.text)
                guard sentences.count == p.expected.count else {
                    print("CORPUS \(p.paragraph): split \(sentences.count) != expected \(p.expected.count), skipped"); continue
                }
                print("CORPUS \(p.paragraph)")
                let r = await run(sentences)
                for e in p.expected { record(expected: e.label, got: r[e.n - 1] ?? "?", text: sentences[e.n - 1]) }
            }
        }

        if total > 0 {
            print("\n=== RESULTS ===")
            print("overall: \(correct)/\(total) = \(Int(Double(correct) * 100 / Double(total)))%")
            print("none recall: \(noneCorrect)/\(noneTotal), false alarms on clean sentences: \(falseAlarms)")
            for (label, n) in perLabelTotal.sorted(by: { $0.key < $1.key }) where label != "None" {
                print("  \(label): \(perLabelHit[label] ?? 0)/\(n)")
            }
            print("top confusions:")
            for (k, v) in confusion.sorted(by: { $0.value > $1.value }).prefix(12) { print("  \(v)x \(k)") }
        }
    }
}
