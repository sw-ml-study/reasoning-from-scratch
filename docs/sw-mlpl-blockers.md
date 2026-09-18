# sw-MLPL capability ledger

Every row below cites an executable probe under `probes/` and the result it
observed. `catalog/probes.tsv` declares the expected pass/fail of each probe;
`just capabilities` (also run by `just check`) fails when an observation
drifts from the declaration, so an upstream change surfaces as a gate
failure that must be reconciled here in the same step. Per-run output,
wall time, and peak resident memory land in `out/probes/`.

Measured against:

```text
mlpl-repl 0.22.0
Commit: 1abe8f10
MLX feature: not compiled into this binary
Previous pins: 1b4d29e5, then 0dfa3eae (sqrt, sin, cos backward rules),
2a774891 (scientific-notation literals), 8a1fe24a (pow with a constant integer
exponent), 3250cea9 (lenient unknown string escapes), fdb5e675 (actionable
rank-3 matmul error), 363391a6 (axis softmax on the tape), 1abe8f10
(transpose_axes backward)
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
| `bf16` / `f16` dtype | missing | `reinterpret-bf16`: accepted dtypes are `u8 i8 u16 i16 u32 i32 u64 i64 f32 f64`; `bf16` and `f16` are "unknown dtype" | core (upstream in progress) |
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
| `tokenizer.json` import | missing | no builtin (documentation) | extension in `../demo-extensions`; MLPL reference on fixtures |

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
