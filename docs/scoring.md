# Likelihood, entropy, and response scoring

`lib/scaling/scoring.mlpl` implements deterministic scoring for chapter 5's
inference methods. Tests use authored distributions and the synthetic tiny
Qwen3 model; no real-model accuracy is reported. All algorithms are MLPL.

## API and numerical contract

Public operations return Results. Logits must be finite, with nonempty
vocabulary and time axes. Logarithms and entropy use natural units (nats).

| Function | Result |
|---|---|
| `u:scaling_log_probs(logits)` | Stable log probabilities for a vocabulary vector |
| `u:scaling_probs(logits)` | Probabilities for the same vector |
| `u:scaling_token_scores(logits, ids)` | Selected probabilities and log probabilities for aligned rows |
| `u:scaling_sequence_score(logits, ids)` | Selected token values, count, sum and mean log probability |
| `u:scaling_answer_score(logits, ids, answer_mask)` | Same summary restricted to binary-masked rows |
| `u:scaling_entropy(weights)` | Shannon entropy of nonnegative relative weights with positive mass |
| `u:scaling_heuristic(mean_logp, entropy, format_ok, weights)` | Versioned score, features and coefficients |
| `u:scaling_completion_score(config, model, prompt_ids, answer_ids)` | Teacher-forced answer-only score from the Qwen3 forward pass |

Scores use the raw model distribution at temperature one, without nucleus
filtering. They are not sampling-policy log probabilities unless that policy
uses the same distribution. Sampling and voting semantics are unchanged.

For each row `z`, set `s = z - max(z)`, then compute
`logp = s - log(sum(exp(s)))`. For `[0,-1000]`, log probabilities remain
`[0,-1000]` even though the second probability underflows to zero.
Finite inputs can still produce an unrepresentable difference or aggregate;
the API returns `score_range` instead of an accidental NaN or infinity.

## Alignment and answer masking

Low-level sequence APIs take a `[positions,vocabulary]` matrix and one
target id per row. **Row t must predict ids[t].** They apply no implicit
shift. Ids are finite integers within the vocabulary.

The answer mask has the same length and contains only zeros and ones. Only
selected rows enter the sum or denominator; noncontiguous masks work.
An all-zero mask returns `empty_answer`, not a misleading zero mean.
Excluded prompt terms cannot overflow the answer sum because selection
precedes aggregation.

The completion API concatenates prompt and answer, uses all but the final
token as model inputs, and all but the first token as targets. The first
answer is predicted at row `prompt_length-1`; preceding rows are masked out.
Prompt and answer must both be nonempty valid id vectors, and model input
length must fit the RoPE context. Every supplied answer token is scored,
including a stop token if the caller includes one.

This convenience path materializes the full logit matrix. Real-model memory
and throughput are unmeasured. These are eager inference checks, not evidence
of gradients through the scoring functions.

## Entropy and heuristic

Entropy normalizes relative weights and evaluates `-sum(p * log(p))` only
over positive entries. `[1,1]` has entropy `log(2)`; `[0,3,0]` has zero.
Next-token uncertainty is `u:scaling_entropy(u:scaling_probs(logits)?)`.

Heuristic version `likelihood-entropy-format-v1` uses:

```text
score = weights.likelihood * mean_logp
      - weights.entropy    * entropy
      + weights.format     * format_ok
```

All three coefficients are explicit, finite, and nonnegative. Mean log
probability must be nonpositive, entropy nonnegative, and format_ok zero or
one. The caller determines the format indicator and uncertainty measurement.
Results retain the features and coefficients. Higher scores rank candidates;
they are neither calibrated correctness probabilities nor verification
rewards. There are no fitted defaults or claimed accuracy improvements.

## Demonstration and checks

With [Linux tool overrides](linux-toolchain.md):

```sh
just scoring-demo
just tests tests/test_scaling_scoring.mlpl
just check
```

The narrated demo shows underflow-safe log scores, prompt exclusion, entropy,
candidate ranking, and tiny-model answer scores. It downloads nothing and
runs in the fixture gate.

Ten native tests cover analytic goldens, numerical extremes, masks, invalid
shapes/ids, empty answers, entropy, coefficient validation, and causal
alignment against independent prefix forward calls. See README for current
full-suite totals. [Self-refinement](self-refinement.md) composes scalar
scorer callbacks with bounded revision and best-of-N selection.
Real weights remain subject to [the bf16 handoff](bf16-handoff.md).
