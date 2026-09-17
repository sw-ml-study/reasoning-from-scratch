# sw-MLPL capability ledger

Measured against the adjacent development build on 2026-09-16:

```text
mlpl-repl 0.22.0
Commit: 1b4d29e5
Timestamp: 2026-09-16T11:08:06-0700
```

Claims pin the build commit, never the version string (peer repositories
observed identical version strings with different behavior). Probe scripts
under `probes/` are the authority once saga 1 step 2 lands; until then the
rows below cite the throwaway probes run while planning. Nothing here is an
authorized upstream change; it is a request queue with evidence.

Classification: **supported**, **awkward** (expressible with a documented
workaround), **missing** (a step is blocked or must stop with an honest
"unavailable" result).

## Autograd coverage for the transformer forward pass

| Need | Status | Evidence | Workaround or request |
|---|---|---|---|
| `sqrt` inside `grad` (RMSNorm, attention scale) | missing | `grad(reduce_add(sqrt(w * w + 1)), w)` fails: function 'sqrt' not supported inside grad() | workaround `exp(0.5 * log(x))`, measured to differentiate correctly; request differentiable `sqrt`, `pow`, and an `rsqrt` |
| `pow` inside `grad` | missing | same error for `pow(w, 2)` | multiply explicitly or use exp/log |
| `softmax(a, axis)` inside `grad` | missing | "softmax expects 1 arguments, got 2" inside `grad`; the 2-argument form works eagerly | 1-argument `softmax` on a rank-2 array is row-wise and differentiable, sufficient for per-head `[T, T]` scores |
| rank-3 `matmul` (batched over heads) | missing | `matmul` on `[2,3,4] x [2,4,3]` errors with "index has 3 components but array has rank 2" (message names the wrong problem) | loop over heads with rank-2 `matmul`; request batched matmul over leading axes and a clearer error |
| `transpose_axes` inside `grad` | missing | "function 'transpose_axes' not supported inside grad()" | keep per-head slices rank-2 and use `transpose`; request tape support |
| rank-3 `transpose` | awkward | reverses all axes (`[2,3,4]` becomes `[4,3,2]`) | acceptable for `[heads, T, d]` only when combined with per-head loops |
| `reduce(:add, a, axis)`, `mean`, `log`, `exp`, `sigmoid`, `gather_rows`, `take`, `concat(a, b, axis)`, `reshape`, masks via `gt` as constants | supported | all differentiated correctly in probes | RMSNorm, SiLU, embedding lookup, KV concatenation, and causal masking are expressible |
| `param` leaf assigned a data array (pretrained weights) | supported | `w = param[6]; w = [1, ...]` still receives a gradient | load decoded tensors into `param` leaves |
| user functions inside `grad` | supported | documented inlining; `repeat` unrolls | a 28-block forward unrolls onto one tape; tape memory must be measured |

## Optimizer and training control

| Need | Status | Evidence | Workaround or request |
|---|---|---|---|
| gradient-norm clipping before the Adam step | missing (to confirm) | `adam(loss, params, ...)` takes the loss, not gradients; no clip argument documented | request either a clip parameter or an explicit `adam_step(params, grads, ...)`; interim: scale the loss by a factor derived from a separate `grad` call (doubles cost) |
| weight decay (AdamW) | missing (to confirm) | `adam` signature has no decay term | the book's runs use the default decay of zero-ish magnitude; document and proceed without it |
| frozen reference copy of a model for KL | awkward | arrays are values; copying a record of arrays is a deep copy | keep reference weights as plain arrays, not params |
| learning-rate schedules | supported | `cosine_schedule`, `linear_warmup` | not needed by the book's runs |

## Bytes, weights, and checkpoints

| Need | Status | Evidence | Workaround or request |
|---|---|---|---|
| bounded byte reads, header parsing, JSON budgets | supported | `read_bytes(path, offset, length)`, `file_size`, `parse_json` with `max_bytes`; proven in `../demo-ml-utils` | vendor or re-derive the header reader |
| packed byte buffers and typed reinterpretation | supported (dtype list to confirm) | `read_bytes_packed`, `size_bytes`, `reinterpret(bytes, "dtype")` in the changelog | saga 3 step 1 probes whether `bf16` is an accepted dtype |
| bf16 to f64 decoding of 155 M values | awkward | if `reinterpret` lacks `bf16`, decode with vectorized integer arithmetic on `u16` views (`floor`, `mod`, `pow`) | request `bf16` and `f16` in `reinterpret` |
| f64-only array storage | awkward | 4.8 GB for the weights alone | acceptable on 64 GB; request narrower storage or device residency if activations exceed budget |
| checkpoint save and load | supported | `to_native` / `parse_native` with `write_atomic` and `read_bytes` | adapters and full weights as `MLPB` files, size measured |

## Tokenizer and text

| Need | Status | Evidence | Workaround or request |
|---|---|---|---|
| load a Hugging Face `tokenizer.json` | missing | `train_bpe` is the only tokenizer constructor; no vocab/merges import documented | implement byte-level BPE in MLPL over `parse_json` output; request a native import if encode throughput is inadequate |
| regular expressions (pre-tokenization pattern, number fallback) | missing | no regex builtin | hand-written scanners in `lib/text/`; documented divergence from the reference pattern |
| string primitives | supported | `str_slice`, `str_find`, `str_split`, `str_join`, `str_concat`, `str_len`, `tokenize_bytes`, `decode_bytes`, `to_number` | character-indexed; byte-level work goes through `tokenize_bytes` |
| 7 MB JSON parse (`tokenizer.json`) | to measure | `parse_json` budgets documented; time and memory unknown at this size | saga 2 step 1 measures; fallback is a one-time conversion to `MLPB` |

## Generation and sampling

| Need | Status | Evidence | Workaround or request |
|---|---|---|---|
| seeded categorical sampling with temperature | supported | `sample(logits, temperature, seed)` | top-p needs its own draw: `grade_down`, `running_sum`, `random(seed, [1])` are all present |
| KV cache for a user-array model | awkward | `gen_state` family is Model-DSL only | MLPL record of per-layer `[kv_heads, T, d]` arrays grown with `concat` |
| log-softmax gather of chosen tokens | supported | `log(softmax(...)) * one_hot(...)` differentiates | numerically stabilized by `softmax` itself |

## Performance (unmeasured until saga 3)

Interpreter throughput for a 1024-wide, 28-layer forward pass at f64, the
cost of unrolling that pass onto the autograd tape for a 512-token rollout,
and the MLX backend's applicability to user-array code (not Model DSL
chains) are the open questions that decide whether GRPO and distillation
run on the real model here or only on toy models. Each is measured with a
recorded command before a request is filed.

## Request queue (to be filed upstream by the owner, with probes)

1. Differentiable `sqrt`, `pow`, `rsqrt`.
2. Differentiable `softmax(a, axis)` and `transpose_axes`.
3. Batched `matmul` over leading axes, and a correct error message for the
   current rank-3 rejection.
4. `bf16` / `f16` in `reinterpret` (if absent).
5. Gradient clipping or an explicit-gradient optimizer step; weight decay.
6. Native `tokenizer.json` import (only if the MLPL implementation is too
   slow for 12,000-prompt corpora).
7. A pretrained-decoder surface (safetensors model load, LoRA, device
   residency) as already sketched in `../sw-mlpl/docs/SmolLM2-demo-plan.md`;
   this repository's array implementation is the acceptance oracle.
