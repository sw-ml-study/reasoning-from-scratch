# Bounded self-refinement and best-of-N

`lib/scaling/refinement.mlpl` implements chapter 5's selection and revision
methods entirely in MLPL. Tests and the narrated demo use authored callbacks;
no learned reasoning or real-model accuracy improvement is claimed.

## Callback and provenance contract

Both runners take `(problem, responder, scorer, seeds, options)` and return
Results. The problem must be nonblank text. The callbacks are:

- `responder(prompt, seed, decoding)` returns plain nonblank text. It must
  honor the explicit seed and decoding controls; the runner does not enforce
  a token budget on arbitrary callbacks.
- `scorer(problem, response, scorer_config)` returns a finite scalar, with
  higher meaning better. It must be deterministic for fixed inputs. It
  receives the original problem, never the critique or revision prompt.

Thrown callback errors, returned Results, wrong types, blank generations,
and nonfinite scores abort the run. Errors identify the stage, index and
candidate's generation seed. No partial run is returned as success.

Options require the [shared build/model/decoding provenance](self-consistency.md),
a nonblank `scorer` version/id, and a `scorer_config` record. These are retained
in the result. `early_stop`, if present, must be zero: neither runner skips
planned generations. The initial prompt uses `boxed-cot-v1`; critique and
revision wording are owned here and versioned as `boxed-refinement-v1`.
Build and model identifiers are caller-supplied, not independently verified.

An adapter can return `u:scaling_heuristic(...)?.score` from the existing
[scoring API](scoring.md), recording all coefficients in `scorer_config`.
Teacher-forced mean answer likelihood can likewise be adapted when a model
and tokenizer are available. A higher heuristic score is not proof that an
answer is correct. Selecting on held-out reference answers would be an
oracle experiment, not a deployable inference method.

## Best-of-N

`u:scaling_best_of_n` takes a nonempty vector of distinct integer seeds in
`[0, 2^53-1]`. Every candidate sees the same initial reasoning prompt and
shared decoding settings. Every candidate is scored. The first candidate
initializes the winner, even if all scores are negative. A strict improvement
replaces it; equal scores retain the first occurrence.

The result retains the winning response, score, index and seed, every score,
all maximum-score indices, used seeds, provenance and JSONL candidate rows.
A row's `selected` means it became the incumbent at that point, not that it
necessarily won the final run. Scores never become self-consistency votes.

## Self-refinement

`u:scaling_refine` takes an odd-length seed plan:

```text
[initial, critique_0, revision_0, critique_1, revision_1, ...]
```

Seeds must be distinct and satisfy the same integer bounds. The plan fixes
exactly `1 + 2R` generation calls and `1 + R` scoring calls for R rounds.
One seed is valid: generate and score the initial answer, with no revision.
No hidden retries or random choices occur.

Each round asks for a critique of the current incumbent, then a complete
replacement using that incumbent and critique. It scores the replacement
against the original problem. A score greater than or equal to the current
score accepts the revision, including equal-score text changes. A worse
score retains the incumbent. Rejected responses never feed the next round.
There is no convergence claim or automatic stop on equal scores.

Results contain the final response and score, round/acceptance counts, used
seeds, provenance, and an initial JSONL row followed by one row per round.
Round rows retain the critique, both generation seeds, candidate, candidate
score, acceptance decision and resulting incumbent. This allows prompts and
decisions to be reconstructed from the original problem and template version.
Text sections are ordinary prompt context, not a security boundary.

## Demo and verification

With the [Linux tool overrides](linux-toolchain.md):

```sh
just refinement-demo
just tests tests/test_scaling_refinement.mlpl
just check
```

The demo compares three scripted answers, accepts one scripted correction,
and rejects a scripted regression. Nine native tests cover prompt arguments,
seed budgets, stable ties, negative scores, the heuristic adapter, replay,
rejected-candidate isolation, invalid provenance and callback failures in
initial, critique, revision and scoring phases. The full suite has 124 tests,
25 expected probe outcomes and 20 tangled library sources.

Real runs remain gated by [the bf16 handoff](bf16-handoff.md). The
[scaling report](scaling-report.md) distinguishes implemented fixture methods
from unavailable real-model measurements. Toy GRPO math follows next.
