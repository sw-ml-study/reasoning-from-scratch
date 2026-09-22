# Seeded sampling

`lib/scaling/scaling.mlpl` implements temperature probabilities, nucleus
filtering, categorical selection, and sampled decoding over the existing
Qwen3 KV cache. It follows chapter 4's method, independently implemented
here. All validation and sampling semantics are MLPL.

## Public contract

These functions return Results. Invalid arguments produce a `sampling_input`
error with `field` and `message`. Input vectors must be finite, nonempty,
numeric, and rank one.

| Function | Result |
|---|---|
| `u:scaling_temperature(logits, temperature)` | Softmax probabilities; finite temperature strictly greater than zero |
| `u:scaling_nucleus(weights, top_p)` | Renormalized weights in token-id order; `0 < top_p <= 1` |
| `u:scaling_pick(weights, uniform)` | Token id at a supplied variate in `[0,1)`; no randomness inside |
| `u:scaling_uniforms(seed, count)` | Seeded uniform stream; zero count returns an empty array |
| `u:scaling_draw(weights, seed)` | One seeded categorical token id |
| `u:scaling_decode(config, model, prompt_ids, max_new, stop_id, temperature, top_p, seed)` | Generated ids, count, stop reason, sampler version, and decoding parameters |

Weights may be unnormalized but must be nonnegative with positive mass.
Scaling relative to their maximum avoids overflow in their sum. NaN and
infinite inputs are rejected. Seeds are integers from zero through
`2^53-1`, the exact f64 integer range.

## Boundary rules

Nucleus filtering sorts probabilities descending, breaking ties by lower
token id. It keeps the smallest prefix reaching or exceeding `top_p`,
including the crossing token. An exact threshold does not add another
token. The output restores vocabulary order.

Weights `[2,6,2]` at `top_p=0.7` become `[0.25,0.75,0]`: token 1 supplies
0.6 of mass and token 0 crosses the threshold. Weights `[2,1,1]` at
`top_p=0.5` become `[1,0,0]`. A threshold of one retains the distribution;
a small positive threshold still retains its most likely token.

Categorical intervals are half-open. For `[1,2,1]`, variates in `[0,0.25)`
select id 0, `[0.25,0.75)` select id 1, and `[0.75,1)` select id 2.
Zero-mass entries are never selected. A cumulative-rounding shortfall falls
back to the last positive entry.

## Seed stream and replay

Sampler `temperature-top-p-v1` discards 16 startup values from
`random(seed, [count+16])`. Both standalone draws and model decoding use
this stream. On build `6d784660`, raw first variates for seeds 1–256 made
every categorical draw from `[1,2,1]` select token 0. The warmup avoids that
measured collapse. Tests check frequencies against `[0.25,0.5,0.25]` within
0.1 over those fixed seeds; this is a regression check, not proof of general
PRNG quality.

Decoding creates one stream for its entire budget. It does not restart the
generator per token or increment the seed. Increasing the budget preserves
preceding variates. Replay requires the same model, prompt, sampler version,
parameters, and interpreter build. This module reports no model accuracy.

## Cached decoding

Prompt ids are nonempty integers in the vocabulary; the budget is a
nonnegative integer. The stop id is `-1` (disabled) or a vocabulary id.
A zero budget returns an empty result without accessing the model. Stop
tokens terminate the run without being emitted.

The prompt and every token fed back must fit the configured RoPE context.
The final emitted token need not be fed back. The successful result records
seed, temperature, top-p, budget, stop id, and sampler version.

## Validation and limits

Ten native tests cover analytic temperature probabilities, three- and
ten-token nucleus goldens, ties and thresholds, categorical intervals,
seed replay/diversity, nonfinite and invalid arguments, extreme weights,
and zero-budget/stop/context handling. An independent full-forward loop
produces exactly the same sampled ids as cached decoding. The probe
`probes/sampling-array-ops.mlpl` pins the necessary array operations.

With the overrides from [Linux setup](linux-toolchain.md), run
`just tests tests/test_scaling.mlpl` or the full `just check` gate.
Evidence is limited to fixtures and the tiny model. Real loading remains
[blocked on R11](bf16-handoff.md); GPU inference and MATH-500 accuracy are
unmeasured. Self-consistency, scoring, and refinement follow in later steps.
