# Fallacy Finder evaluation harness

Measures how well the on-device model labels sentences, using the app's real engine code
(same chunking, prompt, guided-generation types and error handling as `FallacyFinderVM.swift`).
Runs on a Mac with macOS 26+ and Apple Intelligence enabled; the iOS Simulator uses the same host model.

## Data
- `eval_quiz.jsonl`: the 48 Critical Quiz stems with their expected fallacy.
- `eval_corpus.json`: the 14 paragraphs from `tools/FallacyFinderCorpus.md` with expected per-sentence labels (95 sentences).
- `eval_extra.jsonl`: 12 fresh cases added 2026-09-03 after a user-reported miss (loyalty appeals, relationship-based trust, harmless questions, "should always" advice). Run with `--quiz eval_extra.jsonl`.
- `eval_stereotypes.jsonl`: 48 stereotype generalizations and near-miss negatives added 2026-09-03 after "He is British, must must be strong" was labelled No fallacies (32 positives across nationality, profession, age, appearance, region, hobby, in many surface forms; 16 negatives with a real reason). Audited; no protected groups, because Apple's guardrail refuses those.
- `edge/*.jsonl`: 78 edge cases added 2026-09-03 after "You have a big dick" was labelled Tu Quoque: crude remarks and bare insults, non-argument text (greetings, commands, code, emoji, gibberish), harmful content that must never get a fallacy label, profanity inside real arguments and non-English text. Expected values may list alternatives (`None|DECLINED`); a sentence skipped by the explicit-language filter satisfies None or DECLINED.
- `variants/`: instruction texts that were tried. `hybrid2.txt` is what the app ships (baked into `FallacyFinderVM.swift`).
- `results-current.txt`: the latest run against the app's built-in instructions.

## Run
The engine under test is extracted from the app source every time, so the harness always measures exactly what ships.
```bash
cd tools/finder-eval
python3 extract-engine.py Engine.swift
swiftc -parse-as-library -O -o harness ../../Eristic/Models/FallacyDetailesModel.swift ../../Eristic/Models/FallacyAnalysisModel.swift Engine.swift main.swift
./harness --quiz eval_quiz.jsonl --corpus eval_corpus.json --chunk 5 --refine --nodowngrade     # what the app does
./harness --sentence "The doctor said this supplement is really good, so it must be." --chunk 5 --refine --nodowngrade
./harness --instructions variants/examples.txt --quiz eval_quiz.jsonl --corpus eval_corpus.json --chunk 5   # first pass only, another instruction text
```
Flags: `--chunk N` sentences per request, `--refine` run the family second pass, `--nodowngrade` never let the second pass turn a flagged sentence into None (the app's setting), `--nogate` skip cue-gated None sentences, `--ensemble a.txt,b.txt` majority-vote several instruction texts, `--seed N` chunk order.
Greedy sampling makes results repeatable within one OS/model version; rerun after every OS update.

## Results (macOS 26.6 host model, 143 sentences)
| Configuration | Overall | Clean-sentence recall |
|---|---|---|
| baseline: first sentence of each definition, chunk 10 | 62% | 48/51 |
| examples per fallacy (hybrid2), chunk 10 | 72% | 48/51 |
| same, chunk 5 | 74% | 49/51 |
| examples2 + family second pass, chunk 5 | 81% | 51/51 |
| + keep first-pass Circular, wider cues | 84% | 51/51 |
| + never downgrade flagged sentences to None | 86% | 50/51 |
| + cue-based routing overrides (loyalty -> emotion family, "trust everything he says" -> authority family) and downgrade allowed only when the label's defining cue is missing (SHIPPED, results-current.txt) | 86% | 51/51 |

On `eval_extra.jsonl` the shipped engine scores 9/12 (before the routing overrides: 5/12). "What do you mean you don't trust Bill? He is your brother! You should trust everything he says." now gives None / Appeal to Emotion / Appeal to Authority.

Things that did NOT help: a reasoning field before the label (69%), a pattern field (68%), chunks of 3 or 2 (71%, 65%),
majority-vote ensembles (no gain), cue text inside the enum raw values (69%), per-family enums that remove the fallback
to the first pass (78%). Weakest labels for the 3B model even now: Equivocation (2/6), Hasty Generalization (4/8).
An independent three-auditor check found no wrong labels in the eval set and 8 genuinely ambiguous quiz stems.

## Safeguards added 2026-09-03 (deterministic, in front of and after the model)
1. `ExplicitLanguageFilter` (Models/FallacyAnalysisModel.swift): sentences with sexually explicit terms or violent-threat phrases are never sent to the model and are shown as "not analyzed". Apple's guardrail was measured to be non-deterministic on such text (the same sentence declined once, labelled Ad Hominem five times). Plain profanity still goes through.
2. Bare-remark rule (ViewModels/FallacyRefineEngine.swift): an Ad Hominem or Tu Quoque verdict on a sentence with no argument marker (because, so, idea, plan, advice, urging, against, ...) becomes None. Both labels require a position being brushed aside.
3. False Dilemma rule: a False Dilemma verdict on a sentence with no either/or wording becomes None.
Known trade-off: a real Ad Hominem that also contains explicit language is skipped, not labelled.

Results with the safeguards (shipped): original 143 = 86% (123/143, zero false alarms on clean sentences); extra 12 = 9/12; edge 78 = 68/78. Remaining edge misses are profanity-laden arguments pulled to Ad Hominem, non-English text, sarcasm, and two-sentence arguments whose meaning is split across sentences.

## Stereotype check added 2026-09-03 (Hasty Generalization from a group label)
Before: the shipped engine found 5 of 32 stereotype sentences (37% on `eval_stereotypes.jsonl`). Cause: the first pass calls
"He is British, must be strong" None or Ad Hominem, and the second-pass cue words never routed that shape anywhere.
Fix (ViewModels/FallacyRefineEngine.swift): a sixth family, "stereotype", with a two-option constrained enum (Hasty
Generalization or None) so the model cannot answer with an out-of-family label; routed by a cue regex (must be / of course /
typical, all, every / plural "are all", "cannot" / "what else could he be") but only for sentences the first pass called
None, Ad Hominem, Straw Man, False Dilemma or Hasty Generalization; one sentence per request; no free-text reason (a fixed
explanation is shown). Two findings that shaped it: Apple's guardrail also screens the INSTRUCTIONS, so example stereotypes
in the prompt ("Politicians are all liars") get the whole request declined, and a prompt that mentions nationality, job,
age or looks gets many single stereotype sentences declined too. A neutral "category vs specific fact" framing with benign
examples passes. Sentences Apple still declines are reported as not analyzed, not given the first-pass label.

Results from app source after the change: original 143 = 86% (123/143, zero false alarms); stereotypes 41/48 (85%; 2 of
the 7 misses are Apple declines); extra 9/12; edge 68/78. Known weakness: the model is sensitive to punctuation on the
shortest forms ("He is British, must be strong" is caught without a full stop and missed with one).
