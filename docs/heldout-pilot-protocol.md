# Frozen native reasoning pilot v1

Frozen on 2026-09-29 before generating any selected answer. This is a small
paired integration pilot, not a claim that reasoning improves broad accuracy.
The model is externally pretrained Qwen3 8B Q6_K; no weights are updated.

## Selection and separation

Use the pinned local MATH-500 JSONL with SHA-256
`35dc41080a3680858b27fa7e0533d2d547825316fc5dafe5d316f4ccc5a06132`.
For each unique id compute SHA-256 of the UTF-8 string
`native-heldout-v1:` followed by the id, without a newline. Sort by that
hash ascending and select the first six. No difficulty filtering or
replacement follows inspection. The [selection manifest](results/heldout-pilot-v1-selection.jsonl)
records the ids, ranking hashes and hashes of the exact problem and reference
strings (without trailing newlines). References are used only for grading.

These examples were not used in the five-case prompt/budget development.
MATH-500 is public: overlap with the external model's training is unknown.
This is a holdout from our development, not a contamination-free benchmark.
Questions and references stay in ignored `data/`; raw local requests and
responses stay in ignored `out/`. Committed results contain ids, scores,
resource measurements and evidence hashes, not downloaded dataset text.

## Fixed experiment

- Six selected problems, two seeds (42 and 43), both thinking modes: 24 calls.
- Each pair uses the same seed, `boxed-v1` prompt, model and runtime.
- Model/runtime/hash pins are those in [the native runbook](native-reasoning-demo.md).
- Output cap 3072, context 4096, temperature 0.6, top-p 0.95, top-k 20,
  repeat penalty 1; no sampling-parameter tuning after seeing these answers.
- Within each problem run both seeds; alternate the first mode by problem
  index plus seed offset. Both modes receive 12 calls and a maximum allowance
  of 36,864 generated tokens. Actual token consumption is reported separately.
- Warm the model with an empty request before measurement. HTTP deadline
  remains 120 seconds per call; response bound 1 MiB; no automatic retries.
  At most 48 minutes of request deadlines, plus setup and local overhead.
- Save requests before sending them; retain responses and errors for every
  call. A failed attempt counts as incorrect, never as a dropped example.
- Normal stop, nonempty final content and a correct boxed answer are all
  required. Grade final content only. Keep errors, truncations, completed
  incorrect answers and parseability separate.

## Analysis fixed before inference

Report each seed separately over six problems: accuracy, 95% Wilson score
intervals (z=1.959963984540054), paired wins/losses, incomplete/error counts,
generated tokens, and measured wall time. Intervals are descriptive binomial
uncertainty for this small selection, not proof of representative sampling.
Do not pool repeated seeds as twelve independent problems. Summarize the
number of problem ids whose average correctness improves, ties or worsens.
No significance or general-quality claim follows a six-problem pilot.

The unchanged MLPL verifier supplies the primary score. Review completed
mismatches for extraction limitations; report any review separately without
silently changing the primary metric. On transport failure, token counts
may be unavailable: measured latency remains reportable but token totals
are only the known portion of cost. No post-hoc reruns replace failures.

A reasoning benefit requires more paired gains than regressions, followed
by confirmation on new frozen data and a cost comparison. All-correct
results, a tie, or a loss are valid outcomes. Prompt/budget changes belong
to a new experiment and consume this set as development data.
