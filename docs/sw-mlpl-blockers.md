# sw-MLPL capability ledger

Measured against the adjacent development build on 2026-09-16:

```text
mlpl-repl 0.22.0
Commit: 1b4d29e5
Timestamp: 2026-09-16T11:08:06-0700
MLX feature: not compiled into this binary
```

Claims pin the build commit, never the version string (peer repositories
observed identical version strings with different behavior). Probe scripts
under `probes/` become the authority in Saga 1 step 2; until then the rows
cite throwaway probes run during planning plus source and documentation
inspection of `../sw-mlpl` (paths are relative to that repository). Nothing
here is an authorized upstream change; it is a request queue with evidence.

Classification: **supported**, **awkward** (expressible with a documented
workaround), **missing** (a step is blocked or must stop with an honest
"unavailable" result).

## Autograd coverage for the transformer forward pass

| Need | Status | Evidence | Workaround or request |
|---|---|---|---|
| `sqrt` inside `grad` (RMSNorm, attention scale) | missing | `grad(reduce_add(sqrt(w * w + 1)), w)` fails: function 'sqrt' not supported inside grad() | `exp(0.5 * log(x))` differentiates correctly (probed); request differentiable `sqrt`, `pow`, `rsqrt` |
| `pow`, `cos`, `sin` inside `grad` | missing | same error class | multiply explicitly; RoPE tables are parameter-free constants computed eagerly, so `cos`/`sin` never need the tape |
| `softmax(a, axis)` inside `grad` | missing | "softmax expects 1 arguments, got 2" inside `grad`; the 2-argument form works eagerly | 1-argument `softmax` on a rank-2 array is row-wise and differentiable, sufficient for per-head `[T, T]` scores |
| rank-3 `matmul` (batched over heads) | missing | `matmul` on `[2,3,4] x [2,4,3]` errors with "index has 3 components but array has rank 2" (message names the wrong problem); `matmul` is documented and implemented as 2-D only | loop over heads with rank-2 `matmul`; request batched matmul over leading axes and a clearer error |
| `transpose_axes` inside `grad` | missing | "function 'transpose_axes' not supported inside grad()" | keep per-head slices rank-2 and use `transpose`; request tape support |
| rank-3 `transpose` | awkward | reverses all axes (`[2,3,4]` becomes `[4,3,2]`) | acceptable only with per-head loops |
| `reduce(:add, a, axis)`, `mean`, `log`, `exp`, `sigmoid`, `gather_rows`, `take`, `concat(a, b, axis)`, `reshape`, rank-2 `transpose`, masks via `gt`/`eq` as constants | supported | all differentiated correctly in probes; tape op list in `components/autograd/crates/mlpl-autograd-tape/src/ops.rs` | RMSNorm, SiLU (`x * sigmoid(x)`), embedding lookup, KV concatenation, causal masking are expressible |
| `param` leaf reassigned to a data array (pretrained weights) | supported | `w = param[6]; w = [1, ...]` still receives a gradient | load decoded tensors into `param` leaves |
| user functions and `repeat` inside `grad` | supported | documented inlining and unrolling | a 28-block forward unrolls onto one tape; tape memory is unmeasured at this size (see performance) |
| `grad(expr, wrt)` takes one parameter name; `adam(loss, [p1, p2, ...], ...)` takes a list | supported | probed | per-parameter gradients need one `grad` call each |
| Model DSL `causal_attention` | supported but not this architecture | multi-head on tape (`docs/language-status.md`), no grouped-query, RoPE, QK-norm, gain RMSNorm, bias-free linear, or tied head (`docs/gaps-to-be-addressed.md`) | write the block as array functions; keep the DSL out of the model path |

## Optimizer and training control

| Need | Status | Evidence | Workaround or request |
|---|---|---|---|
| gradient-norm clipping before the Adam step | missing | `adam` computes and applies gradients internally; clipping listed as a gap in `docs/gaps-to-be-addressed.md` | hand-written Adam over `param` leaves using explicit `grad` calls (moments as ordinary arrays); request `clip_grad_norm` or an explicit-gradient `adam_step` |
| weight decay (AdamW) | missing | `adam` signature has no decay term | the hand-written Adam adds decoupled decay trivially |
| frozen reference copy of a model for KL | awkward | `clone_model` is Model-DSL only; arrays are values | keep reference weights as plain arrays and compute their log-probabilities eagerly (constants) |
| learning-rate schedules | supported | `cosine_schedule`, `linear_warmup`, lr may be an expression | not needed by the book's runs |

## Bytes, weights, and checkpoints

| Need | Status | Evidence | Workaround or request |
|---|---|---|---|
| bounded byte reads, header parsing, JSON budgets | supported | `read_bytes(path, offset, length)`, `file_size`, `parse_json` budgets, duplicate-key rejection; proven in `../demo-ml-utils/src/formats/safetensors_header.mlpl` | vendor by pinned revision or re-derive |
| packed byte buffers and typed views | supported | `read_bytes_packed`, `size_bytes`, `reinterpret(bytes, dtype)`, scalar `read_f32_le` etc. | bulk `unpack(bytes, dtype)` to an array is a queued upstream item, not shipped |
| `bf16` / `f16` dtype | missing | dtype vocabulary is `u8 i8 u16 i16 u32 i32 u64 i64 f32 f64` (`components/eval-types/crates/mlpl-bytes/src/dtype.rs`); `reinterpret(b, "bf16")` is an unknown dtype | vectorized decode on the f64 byte array: pair bytes into `u16`, then sign/exponent/mantissa via `shr`, `band`, `pow` (probed on two values); subnormal, infinity, and NaN masks required; costs 8x transient memory per tensor; request `bf16`/`f16` dtypes and bulk unpack |
| f64-only array storage | awkward | 4.8 GB for the weights alone | acceptable on 64 GB; request narrower storage or device residency if activations exceed budget |
| checkpoint save and load for plain arrays | supported | `to_native` / `parse_native` with `write_atomic` and `read_bytes` (f64, 2x on disk) | one file per tensor; `save_model` is JSON, Model-DSL only, and writes unsandboxed relative to the working directory, so it is not used |
| filesystem sandbox | supported, must plan for | all fs builtins resolve under `--source-dir`; absolute paths and escaping symlinks return `err` | keep `models/` and `data/` physically inside the repository tree |

## Tokenizer and text

| Need | Status | Evidence | Workaround or request |
|---|---|---|---|
| load a Hugging Face `tokenizer.json` | missing | `train_bpe` is the only constructor; merges cannot be injected; `load_tokenizer` is a plan-only name in `docs/SmolLM2-demo-plan.md` | implement byte-level BPE in MLPL over `parse_json` output; request a native import if throughput is inadequate |
| string-keyed lookup tables | awkward | records come only from `parse_json`; no `record_set`; `for` does not iterate string lists | pre-serialize merge ranks as a JSON object (one-time generator written in MLPL), parse once, look up with `record_get`; iterate with `while` and `list_get` |
| regular expressions | missing | no regex builtin | hand-written scanners in `lib/text/` |
| string primitives | supported | `str_slice`, `str_find`, `str_split` (empty separator yields characters), `str_join`, `str_concat`, `str_len`, `str_eq`, `tokenize_bytes`, `decode_bytes`, `to_number` | no `str_replace`, `starts_with`, `trim`, `lower`, `contains`, or character-code access; each is a few lines over the primitives; request the common ones |
| literal syntax | awkward | no hexadecimal literals, no scientific notation (`1e-8` fails), no index or slice syntax | write `0.00000001`; use `at`, `take`, `gather_rows`, `list_get` |
| JSON arrays of objects | missing | `parse_json("[{...}]")` returns `err("mixed or nested array")` | consume datasets as JSONL: `read_text`, split on newline, `parse_json` per line; MATH-500 is published as `test.jsonl` |
| 7 MB JSON parse (`tokenizer.json`) | to measure | budgets documented; time and memory unknown at this size | Saga 2 step 1 measures; fallback is a one-time conversion to `MLPB` |

## Generation and sampling

| Need | Status | Evidence | Workaround or request |
|---|---|---|---|
| seeded categorical sampling with temperature | supported | `sample(logits, temperature, seed)`; `top_k(logits, k)` | top-p is not a builtin: `grade_down`, `running_sum`, mask to `-inf` (`0 - 1/0`), then `sample` (primitives probed) |
| KV cache for a user-array model | awkward | `gen_state` family is Model-DSL only and needs bound names | MLPL record of per-layer `[kv_heads, T, d]` arrays grown with `concat` (quadratic copying in the interpreter) |
| log-softmax gather of chosen tokens | supported | `log(softmax(...)) * one_hot(...)` differentiates; `cross_entropy` is fused and differentiable | `log_softmax` exists only on the MLX dispatch path |
| stop tokens, token budgets | supported | `while`, `break` | none |

## Networking

| Need | Status | Evidence | Workaround or request |
|---|---|---|---|
| download weights and datasets | missing | no HTTP builtin; `fetch_dataset` is allow-listed | `curl` in `scripts/fetch-*` recipes |
| call a local LLM server | supported | `llm_call(url, prompt, model[, system])` against Ollama, CLI only, 120 s timeout, text only | usable as a distillation teacher for text, not for token-level targets |

## Performance (single-operation timings, this machine, f64 interpreter)

| Operation | Time |
|---|---|
| `[1,1024] x [1024,3072]` | 11.7 ms |
| `[32,1024] x [1024,1024]` | 51 ms |
| `[1,1024] x [1024,8192]` | 34.5 ms |
| `[1,1024] x [1024,151936]` with an in-loop `transpose` | 633 ms (the transpose dominates; pre-transpose once) |
| `randn([151936, 1024])` | 2.8 s |

Extrapolation, to be replaced by a measurement in Saga 3 step 4: one
decode step of the 0.6B model is about 1.2 GFLOP, which at the measured
0.5 to 1.3 GFLOP/s is roughly 2 to 3 seconds per token before attention,
RoPE, and per-head loop overhead. A 512-token response would take on the
order of 20 to 30 minutes; a full MATH-500 pass at 2,048 tokens is out of
reach on the CPU interpreter. The MLX backend (`device("mlx")`, resident
tape, f32 on device) is the plausible path but requires a build with the
`mlx` feature (not compiled in today), dispatches only nineteen ops (no
`gather_rows`, `take`, `concat`, `rotate`), and has no published evidence
beyond tiny models. Backward through 28 unrolled layers at width 1,024 on
the CPU tape has no evidence anywhere in the repository.

Consequences for the plan: every algorithm is delivered and tested on tiny
configurations; real-model runs are bounded, opt-in, and measured; the
throughput numbers, not assumptions, decide which upstream requests are
filed.

## Request queue (to be filed upstream by the owner, with probes)

1. `bf16` and `f16` dtypes plus a bulk `unpack(bytes, dtype)` to an array.
2. Batched `matmul` over leading axes, and a correct error message for the
   current rank-3 rejection.
3. Differentiable `sqrt`, `pow`, `rsqrt` (and `cos`/`sin`, lower priority).
4. Differentiable `softmax(a, axis)` and `transpose_axes`.
5. Gradient clipping or an explicit-gradient optimizer step; weight decay.
6. `parse_json` support for arrays of objects, or a JSONL reader.
7. String helpers: `str_replace`, `str_starts_with`, `str_ends_with`,
   `str_trim`, `str_contains`, character codes; scientific-notation literals.
8. Native `tokenizer.json` import (only with a throughput measurement
   showing the MLPL encoder is inadequate).
9. An MLX-featured `mlpl-repl` build on this host, device dispatch for the
   gather/concat/take family, and evidence that a width-1,024, 28-layer
   forward and backward fits the resident tape.
10. A pretrained-decoder surface (safetensors model load, grouped-query
    attention with RoPE and QK-norm, LoRA, device residency) as sketched in
    `docs/SmolLM2-demo-plan.md` and `../demo-ml-utils/docs/rust-native-model-training.md`;
    this repository's array implementation is the acceptance oracle.
