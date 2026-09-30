# Book experiment demonstration v2

The objective is to recreate the book's work without Python: MLPL implements
its experiment tools and Rust/CUDA executes the model. This replaces the
strict custom pilot as the active demonstration. The old run remains
incomplete: twelve outcomes were saved, and a thirteenth call was interrupted
when the evaluation-contract mismatch was identified. It is not a comparison
against the book's published accuracy.

## Fixed experiment before generation

Use the first ten records, in order, from the author's MATH-500 JSON artifact
(SHA-256 `a9eccff7e25ecaf3952614e5b92fe081b4f0549c68ae6a387b96e131df9ddf41`).
This is the companion script's default demonstration size and ordering, not
a fresh held-out claim. No case is selected or removed based on outcomes.
The complete 500-case dataset remains the later scale target.

Use the same pinned Qwen3-0.6B-Base checkpoint and BF16 CUDA provider as the
validated backend. Context 4096, output cap 2048, EOS 151643. Reproduce the
short experimental prompt bytes as attributed data in
`fixtures/prompts/book-author.json`; append the CoT suffix after the answer
cue. All implementation code is independently written in MLPL.

Three methods, fifty calls total:

1. Base prompt, greedy, ten questions.
2. CoT prompt, greedy, ten questions.
3. CoT prompt, temperature 0.9, top-p 0.9, three samples per question.

Sampling uses seeds 43, 44, 45 (base seed 42 plus sample index plus one).
Greedy records unused seed 42. Reset KV per call, warm on a non-evaluation
prompt, and rotate method groups by case index modulo three. No early voting
stop or reference-based candidate selection. The full 2048-token allowance
applies to each call; the prior 120-second call cap is removed. A three-hour
outer safety budget produces an explicitly incomplete report if reached.

Extraction prefers the final box, then the final recognized number, then
full text. Score capped output too, as the author's generator/evaluator does.
Vote on exact extracted strings and resolve tied plurality by first
appearance. Normalize and grade only after candidate selection. Blank
extractions can receive votes but cannot be correct. Keep errors, output
limits, EOS counts, formatting compliance, tokens, elapsed time and memory.

The matching reference is the companion revision
`1c0b9b17f80d335a9e7f73ca4738486bfa49fa9f`, especially the
[chapter 3 evaluator](https://github.com/rasbt/reasoning-from-scratch/blob/1c0b9b17f80d335a9e7f73ca4738486bfa49fa9f/reasoning_from_scratch/ch03.py)
and [chapter 4 script](https://github.com/rasbt/reasoning-from-scratch/blob/1c0b9b17f80d335a9e7f73ca4738486bfa49fa9f/ch04/02_math500-inference-scaling-scripts/self_consistency_math500.py).
The script tie policy differs from the standalone voting helper's unresolved
tie result; this demonstration follows the script that generates the table.

## Explicit remaining differences

- Seed numbers match the author's schedule, but MLPL uses its pinned
  xorshift64 stream rather than PyTorch's RNG. Samples are distribution-matched,
  not bit-identical. BF16 arithmetic can also alter individual samples.
- MLPLs numeric/tuple and exact rational linear-symbolic verifier is independently implemented and does not
  provide all of SymPy's symbolic simplification. Unsupported equivalence is
  a grading-parity gap, not evidence that the model's reasoning is wrong.
  Reference coverage is checked without filtering cases. Linear rearrangements such as p-q versus -(q-p), polar-coordinate pi notation, and literal text labels have explicit fixtures. A complete
  symbolic-equivalence replacement remains required for full book parity.
- Ten cases and three votes are a demonstration, not the author's full
  500-case result. No speed comparison is valid without matching hardware,
  generated token counts, and execution settings.
- The native provider source has a pinned portable SDK dependency but its
  publication into the extension sibling still requires authorization.

## Reproducibility and analysis

MLPL prepares the dataset slice and prompts (`demos/prepare_book_author.mlpl`),
runs the experiment (`demos/book_author.mlpl`), extracts and votes
(`lib/eval/author.mlpl`), and analyzes numeric outcomes. Shell only launches,
checks hashes and samples hardware/process memory. Raw downloaded content
and generations remain ignored; published artifacts contain numeric metrics,
IDs, hashes and predeclared settings. Commit execution pins before inference.

Report correct/10 with descriptive Wilson intervals, paired gains/losses,
tokens and time by method, plus individual failure categories. Preserve
primary scores and separately review verifier disagreements. An incomplete
run has no complete-set accuracy claim. Demonstrate valid generated reasoning
with clearly identified examples, without promising zero failures.
