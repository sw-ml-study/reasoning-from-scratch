# sw-MLPL capability ledger

Every row below cites an executable probe under `probes/` and the result it
observed. `catalog/probes.tsv` declares the expected pass/fail of each probe;
`just capabilities` (also run by `just check`) fails when an observation
drifts from the declaration, so an upstream change surfaces as a gate
failure that must be reconciled here in the same step. Per-run output,
wall time, and peak resident memory land in `out/probes/`.

## Current host revalidation, 2026-09-25

CPU build `cd3cd03fd4eb66d1a33390a40f27c28e8a55e435` replaces the previous
pin. Bulk `unpack` (R11) is now **supported**: the existing probe changed
from fail to pass, five new native acceptance tests pass, and one million
f32 and bf16 values decode correctly in single runs of 12.49 ms and 19.21 ms.
These are decode-only timings, not complete tensor load or peak-RSS claims.
All other 24 probe outcomes are unchanged; the full suite has 129 tests.

The moved extension at `4be5074` passes six fixture cases, eight real-Qwen
goldens/round trips and an NFC check. The tokenizer implementation gap is
resolved; facade integration and 12,000-prompt throughput remain pending.
CUDA dependency cudarc 0.19.7 is unchanged; the new CPU build still produces
an explicit fallback and the CUDA runner exits 77. R3 and R10 remain open.
See [reproduction and limits](upstream-revalidation.md). The loader is next;
no real-model inference or training has been established.

## Historical host revalidation, 2026-09-22

All 24 catalog outcomes were reproduced on Arch Linux x86_64 using a CPU
release build of sw-MLPL 0.22.0 at `6d784660`. This is the current validation
pin; the per-operation Apple measurements below retain their original pin
and are not Linux predictions. The installed 0.20.0 build (`b3b1be48`) is
incompatible with the required CLI, so use explicit tool overrides from
[Linux setup](linux-toolchain.md).

| Need | Classification | Current evidence / affected steps |
|---|---|---|
| Bulk bf16 unpack (R11) | missing | `unpack-bulk` still reports unknown function; real tensor loading remains blocked |
| Batched matmul (R3) | missing | `matmul-rank3` still rejects rank-3 operands; real attention throughput remains constrained |
| Constant-cost container access (R10) | missing | 100 large-record lookups: 3,235 ms; 100 large-list reads: 603–611 ms; same probes and acceptance budgets |
| CUDA build on this host (R12) | missing | `--features cuda --locked` fails in cudarc 0.19.7 on toolkit 13.4; CPU `device("cuda")` explicitly falls back |
| Native tokenizer on Linux | unavailable | extension checkout/artifact absent; prior Apple fixture parity does not validate this host |
| Fresh-clone checkpoint tests | supported | the test entry point now generates the ignored synthetic fixture before running native tests |

The host is a Xeon W-2135 with about 251 GiB RAM and an RTX 5060 Ti with
16 GB VRAM. The GPU driver works outside the sandbox. No real model or
training throughput has been measured on it. CPU-only informational runs
measured 67.9 ms for the FFN projection and 890.6 ms for the output head;
tiny cached generation remained exactly equal to full recomputation.
CUDA acceptance requires a successful supported build, confirmed device
dispatch, and parity for Qwen3's array operations; details and the failed
build command are in [Linux setup](linux-toolchain.md).

The subsequent bf16 decoding step reconfirmed R11 on the same build and
checked that upstream HEAD had not advanced. Its outcome is **unavailable**,
not a delivered loader. See [the core handoff](bf16-handoff.md) for exact
acceptance cases and resume conditions. Real-model smoke/baseline are
deferred; fixture-based scaling can proceed independently.

## Sampling primitives, measured on Arch build 6d784660

`sampling-array-ops` confirms stable descending grade, inverse permutation
through a whole-array gather, running sums, deterministic uniforms, and
finite-value masks. These are **supported** and used by `lib/scaling/`.
The fixture gate now checks 25 probe outcomes and 93 native tests.

Raw seeded random startup is **awkward**: using the first variate for each
seed 1–256 selected token 0 in all 256 draws from weights `[1,2,1]`.
The sampling library discards 16 startup values once per stream; its fixed
seed-sweep frequencies then satisfy the `[0.25,0.5,0.25]` golden within 0.1.
This is a library workaround, not a new core blocker or a general PRNG
quality claim. See [sampling](sampling.md) for the replay contract.

Ten sampling tests also establish exact cached/full-forward sampled-id
agreement, boundary/error handling, and analytic distribution goldens.
No real-model inference or new accuracy result is claimed.

## Self-consistency, validated on Arch build 6d784660

The versioned reasoning suffix, seed-plan validation, normalized boxed voting,
first-occurrence ties, abstention audit, and safe early stopping are
**supported** in MLPL over the existing text and array primitives. No new
core or extension capability is needed. Twelve native tests include all
sixteen four-vote binary patterns, comparing early/full winners and ties.
The gate now covers 105 native tests, 25 probe outcomes, and 18 tangled
library sources. See [the contract](self-consistency.md).

Evidence is from stub responders only: vote agreement is not correctness,
and there is no measured MATH-500 improvement. R11 and the real-model/GPU
constraints above are unchanged.

## Scoring, validated on Arch build 6d784660

Stable row-wise log-softmax, aligned token gathers, binary answer masks,
entropy with zero-mass handling, and explicit heuristic coefficients are
**supported** by existing MLPL primitives. Ten native tests prove analytic
goldens, underflow-safe log scores, validation/range errors, and teacher-forced
answer alignment against independent tiny-model prefix forwards. No new
upstream capability is required for these eager inference functions; training
tape behavior is not established by this step.

The gate now covers 115 native tests, 25 expected probe outcomes and 19
tangled library sources, plus the narrated `just scoring-demo`. See
[the scoring contract](scoring.md). Real-model memory, throughput and
accuracy remain unmeasured and the existing R11/R12 blockers are unchanged.

## Self-refinement, validated on Arch build 6d784660

Bounded critique/revision loops, accept-if-not-worse decisions, and stable
best-of-N selection are **supported** in MLPL with existing callback, text,
array and JSON primitives. Nine native tests cover callback contracts,
explicit seed budgets, scorer provenance, replay, rejection isolation,
negative scores, ties, heuristic integration and stage-specific errors.
No new core or extension capability is required for these fixture methods.

The gate now covers 124 native tests, 25 expected probe outcomes and 20
tangled library sources. `just refinement-demo` shows scripted correction
and regression decisions with audit rows. See [the contract](self-refinement.md).
This is not evidence of learned reasoning or real-model improvement; R11,
R12 and the other real-model constraints above remain unchanged.

## Scaling report closeout, 2026-09-22

The [scaling report](scaling-report.md) separates 41 scaling tests from
unavailable real-model metrics. Adjacent source and a fresh read of remote
HEAD both remain `6d7846605f27adbadaf17b662b2a984285ec15a3`. On the selected
CPU build, `unpack-bulk` still exits 1 with unknown function; the CUDA runner
exits 77 after explicit CPU fallback; tokenizer parity exits 77 because
the Linux extension is absent. The adjacent CLI lockfile still contains
cudarc 0.19.7; the earlier CUDA 13.4 build failure was not rerun.

No new capability request is required. R11 and the named-tensor loader
remain prerequisites for any real inference; R12 is required for GPU claims,
not necessarily a bounded CPU evaluation. Production tokenizer parity is
also unresolved. Real accuracy, throughput and peak memory remain
**unavailable**. Toy GRPO math is the next independent work; eager scoring
tests do not establish its autograd behavior.

## Historical Apple measurements

Measured against:

```text
mlpl-repl 0.22.0
Commit: 1ce43dc2
MLX feature: not compiled into this binary
Previous pins: 1b4d29e5, then 0dfa3eae (sqrt, sin, cos backward rules),
2a774891 (scientific-notation literals), 8a1fe24a (pow with a constant integer
exponent), 3250cea9 (lenient unknown string escapes), fdb5e675 (actionable
rank-3 matmul error), 363391a6 (axis softmax on the tape), 1abe8f10
(transpose_axes backward), a34cc230 (bf16 and f16 dtypes), 1ce43dc2
Machine: Apple M1 Max, 10 cores, 64 GB
```

Claims pin the build commit, never the version string. The home of each gap
(core, library, extension, none) follows [`feature-homes.md`](feature-homes.md);
the asks are in [`sw-mlpl-requests.md`](sw-mlpl-requests.md),
[`demo-extensions-requests.md`](demo-extensions-requests.md), and
[`demo-mlpl-libraries-requests.md`](demo-mlpl-libraries-requests.md).

Classification: **supported**, **awkward** (expressible with a documented
workaround), **missing** (a step is blocked or must stop with an honest
"unavailable" result).

## Autograd coverage for the transformer forward pass

| Need | Status | Probe and observation | Home and workaround |
|---|---|---|---|
| `sqrt` inside `grad` | supported since 0dfa3eae | `grad-sqrt`: gradient of `reduce_add(sqrt(w))` at `[1, 4, 9]` is `[0.5, 0.25, 0.1667]` | shipped upstream (RS1); the `exp(0.5 * log(x))` spelling remains as a cross-check |
| `pow` inside `grad` | supported since 8a1fe24a | `grad-pow`: gradient of `reduce_add(pow(w, 2))` at `[1, 2, 3]` is `[2, 4, 6]` | shipped upstream for constant integer exponents (RS1); a variable exponent still needs `exp(k * log(x))` |
| `sin`, `cos` inside `grad` | supported since 0dfa3eae | `grad-sin-cos`: gradient of `sin(w) + cos(w)` matches `cos(w) - sin(w)` | shipped upstream (RS1) |
| `softmax(a, axis)` inside `grad` | supported since 363391a6 | `grad-softmax-axis`: the axis form now differentiates | shipped upstream (RS2) |
| rank-3 `matmul` | missing, error message fixed | `matmul-rank3`: rejected with an actionable message since fdb5e675 (RS4, first half) | core: the batched operation itself is still open; loop over heads with rank-2 `matmul` |
| `transpose_axes` inside `grad` | supported since 1abe8f10 | `grad-transpose-axes`: the general permutation now differentiates | shipped upstream (RS3) |
| square-root workaround | supported | `grad-sqrt-workaround`: gradient of `exp(0.5 * log(x))` matches `0.5 / sqrt(x)` to 1e-9 | library |
| `mean`, axis `reduce`, `gather_rows`, `take`, axis `concat`, rank-2 `transpose`, SiLU as `x * sigmoid(x)`, log-softmax gather, RMSNorm via the exp-log spelling | supported | `grad-core-ops`: every gradient matches its analytic form (RMSNorm against central finite differences) within 1e-7 | none needed |
| `param` leaf reassigned to a data array | supported | `param-data-gradient`: the reassigned leaf receives the expected gradient | core behaviour; pretrained weights load into `param` leaves |

## Optimizer and training control

| Need | Status | Probe and observation | Home and workaround |
|---|---|---|---|
| gradient-norm clipping | missing | `grad-clip-builtin`: `clip_grad_norm` is an unknown function; `adam` takes the loss and hides gradients | library: hand-written Adam over per-parameter `grad` results (Saga 5) |
| weight decay | missing | no probe; `adam` signature has no decay term (documentation) | library: the hand-written Adam adds decoupled decay |
| frozen reference copy of a model for KL | awkward | no probe; `clone_model` is Model-DSL only (documentation) | keep reference weights as plain arrays and compute their log-probabilities eagerly |

## Bytes, weights, and checkpoints

| Need | Status | Probe and observation | Home and workaround |
|---|---|---|---|
| `bf16` / `f16` dtype | supported since a34cc230 | `reinterpret-bf16`: both dtypes are now accepted | shipped upstream (RS6); the vectorized decode below remains as a cross-check |
| vectorized bf16 decode | supported | `bf16-vectorized-decode`: byte pairs for 1, -1, 2, 0.5, 0, 50 decode exactly with `shr`, `band`, `pow` on f64 byte arrays | library; subnormal, infinity, and NaN masks still to add; 8x transient memory per tensor |
| large-array checkpoint round-trip | supported | `native-roundtrip-10mb`: 1,250,000 f64 values (10,000,019 bytes) through `to_native`, `write_bytes`, `read_bytes`, `parse_native` in 134 ms, peak 381 MB | library: one `MLPB` file per tensor with `write_atomic` |
| f64-only array storage | awkward | `matmul-throughput` peak resident memory 3.7 GB while holding one `[1024, 151936]` array and its products | acceptable on 64 GB; narrower storage is an upstream choice tied to MLX |
| bounded byte reads, header parsing, JSON budgets | supported | proven in `../demo-ml-utils` (documentation, not re-probed here) | vendor by pinned revision or re-derive |
| filesystem sandbox | supported, must plan for | all probes run with `--source-dir` at the repository root and read or write only under `out/` | keep `models/` and `data/` inside the tree |

## Tokenizer, text, and data

| Need | Status | Probe and observation | Home and workaround |
|---|---|---|---|
| large JSON object parse | supported | `parse-json-150k`: a 6,450,002-byte object with 150,000 keys parses in 83 ms, peak 239 MB | confirmed on the real file: the 151,643-entry vocabulary parses in 242 ms and the 151,387-entry merge list in 274 ms |
| whole `tokenizer.json` in one parse | missing by design | measured 2026-09-18: the document fails at byte 271 with "mixed or nested array", because `added_tokens` is an array of objects | the import locates each section by anchor and parses the vocabulary, merges, and added tokens separately |
| composing large tables across call boundaries | awkward | measured 2026-09-18: passing a record holding the 151,643-entry vocabulary through one function call costs about 135 ms, and the full import that builds and returns the composite record takes 17.4 s although its parse phases sum to 0.6 s | do the import once and keep a native cache: writing it takes 107 ms for 5.5 MB and reading it back takes 173 ms, which is the path every run uses |
| character-by-character scanning in MLPL | awkward | measured 2026-09-18: the generic JSON-array-to-JSON-Lines scanner costs 15.5 ms at 400 characters and 135 ms at 1,600, so its cost grows with the square of the input | keep it for small inputs with an explicit budget; targeted `str_find` scanning replaced it for the added-token section and runs in 53 ms |
| JSON arrays of objects | missing by design | `json-array-of-objects`: "mixed or nested array" | none; datasets are JSONL |
| JSONL line parsing | supported | `jsonl-lines`: two records with escaped LaTeX parse through `str_split` and `parse_json` | library |
| string helpers | missing | `str-helpers`: `str_replace` is an unknown function | library: `lib/text/` over `str_find`, `str_slice`, `str_len` |
| iterate a string list with `for` | missing | `for-string-list`: rejected | library idiom: `while` with `list_get` |
| scientific-notation literals | supported since 2a774891 | `scientific-literal`: `1e-4` evaluates to `0.0001` | shipped upstream (RS5); earlier builds lexed it as `1`, `e`, `- 4` |
| regular expressions | not needed | no probe | scanners in `lib/text/`; pre-tokenization lives in the tokenizer extension |
| `tokenizer.json` import | delivered as an extension | `just tokenizer-parity` on 2026-09-18: the native `hftok` extension encodes all six fixture expectations to ids identical to the MLPL reference, and faster. It refuses the real Qwen3 vocabulary because that file declares an NFC normalizer | the MLPL reference ignores the declared normalizer, which is a divergence recorded in the verifier of tokenizer behaviour; for ASCII mathematics NFC is the identity |

## Generation and sampling

| Need | Status | Probe and observation | Home and workaround |
|---|---|---|---|
| seeded categorical sampling | supported | documentation: `sample(logits, temperature, seed)`, `top_k` | top-p is a library over `grade_down`, `running_sum`, `random` |
| KV cache for a user-array model | awkward | documentation: `gen_state` is Model-DSL only | library: record of per-layer arrays grown with `concat` |
| row-wise softmax for attention scores | supported | `softmax-rowwise`: each row sums to 1 within 1e-9 | none needed |

## Tokenizer import (measured 2026-09-18, build 363391a6)

| Quantity | Value |
|---|---|
| document | 6,244,779 characters, read in 6 ms |
| vocabulary | 151,643 entries, parsed in 242 ms |
| merges | 151,387 entries, parsed in 274 ms |
| added and control tokens | 22, scanned in 53 ms |
| full import including composition | 17.4 s |
| native cache | 5,467,486 bytes, written in 107 ms |
| load from cache | 173 ms |
| peak resident memory | 942 MB |

The base tokenizer has no `<think>` token: it is absent from both the
vocabulary and the added tokens, which matches the reference and means the
format-reward work in Saga 5 must either add the tokens or use the reasoning
tokenizer.

## Tokenizer encoding (measured 2026-09-18)

The reference encoder is correct and unusably slow on a production
vocabulary, for one reason: every symbol and every candidate pair needs a
vocabulary lookup, and a lookup on a 151,643-field record costs 34 ms.

| Operation | Tiny fixture (10 tokens) | Real vocabulary (151,643 tokens) |
|---|---|---|
| one vocabulary lookup | 0.0026 ms | 34 ms |
| encode `hello` | under 1 ms | 2.7 s |
| encode `hello world` | under 1 ms | 5.9 s |
| encode eight short goldens | instant | 25 s total |
| decode one token | instant | about 310 ms |
| verify the merge invariant | 3 merges, instant | 38 sampled merges, 6.9 s |

The ids are right: `hello` encodes to 14990 and a leading-space `the` to 279,
both matching their vocabulary entries. Extrapolating, one MATH problem of
about fifty pre-tokens would take roughly two minutes, and the
twelve-thousand-prompt training corpus is out of reach entirely. This is the
measured evidence behind the decision recorded in `feature-homes.md`: the
reference encoder proves the algorithm, and the native extension in
`../demo-extensions` is the production path.

## Forward pass (measured 2026-09-18, tiny configuration)

| Quantity | Value |
|---|---|
| full forward, 4 tokens, 2 layers, width 16 | 1.39 ms |
| full forward, 8 tokens | 2.3 ms |
| one attention layer, 8 tokens, 4 heads | 0.52 ms |
| one per-head slice at this size | 0.007 ms |

At the tiny size a head slice is cheap because the array is small; the cost
of slicing follows the array's size, so the same loop over a
`[T, 16, 128]` tensor in the real model is where request R3 bites. The
forward pass is otherwise whole-array throughout.

## Cached generation (measured 2026-09-18, tiny configuration)

| Quantity | Value |
|---|---|
| eight cached steps after a three-token prompt | 14.4 ms |
| eight full recomputations of the growing sequence | 13.6 ms |
| cached tokens per second | about 555 |

The cached scores are bit-identical to recomputation, so the cache is
correct. It is not yet faster. Reading the stacked per-layer cache copies it,
which is the same cost recorded under R10, and at width 16 with two layers
the arithmetic it saves does not pay that back. The saving grows with both
sequence length and model width, so this comparison should be repeated at the
real configuration; it is not evidence that caching is useless, only that at
this size it buys nothing.

## Performance (measured by `matmul-throughput`)

| Operation | Time |
|---|---|
| `[1,1024] x [1024,3072]` | 6.9 ms (mean of 10) |
| `[1,1024] x [1024,151936]` (weights already oriented, no transpose) | 252 ms (mean of 3) |

Extrapolation, to be replaced by a measurement in Saga 3: per decoded
token the 0.6B model performs 28 layers of roughly seven such projections
plus attention, so on the order of 1.5 to 2.5 seconds per token on the f64
CPU interpreter, before the per-head attention loop. A 512-token response
is on the order of 15 to 20 minutes; a full MATH-500 pass at 2,048 tokens
is out of reach on the CPU interpreter. Bounded slices, opt-in recipes, and
tiny configurations carry every saga; the MLX build is the upstream lever.

## Not yet measured

These matter for later sagas and have no probe yet. Each is measured by
the step that first needs it, never assumed.

- Encode throughput of the MLPL reference tokenizer and of the extension
  on the 12,000-prompt corpus (Saga 2 step 4).
- Load time and resident memory for all 0.6B tensors as f64 arrays, and
  the transient cost of the vectorized bf16 decode on the 155.6 M-value
  embedding (Saga 3 step 1).
- A full forward pass at width 1,024 with 28 layers: tokens per second with
  and without the KV cache (Saga 3 step 4).
- Tape memory and time for `grad` through the 28-layer forward over a
  512-token rollout, with and without low-rank adapters (Saga 5 step 3).
- Whether the MLX backend (`device("mlx")`) can run the user-array forward
  at all, which requires a build with the `mlx` feature and dispatch for
  `gather_rows`, `take`, `concat`, and `rotate` (blocked until upstream
  ships such a build; Saga 3 step 4 records the attempt).

## Requests

The asks derived from these measurements live in one document per
repository: [`sw-mlpl-requests.md`](sw-mlpl-requests.md) for core and
[`demo-extensions-requests.md`](demo-extensions-requests.md) for Rust
extensions. Libraries built here (gradient clipping, string helpers, text
scanners, the expression evaluator, top-p sampling, JSONL reading, bf16
decoding, the KV cache, checkpoints) are not requested anywhere.
