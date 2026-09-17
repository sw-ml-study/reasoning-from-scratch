# Requests to `../sw-mlpl` (core)

This is the single list of what this repository asks of the language. Each
item names the probe that demonstrates the gap today, the semantics
requested, and the acceptance cases the probe will check once the change
ships. The ledger of measurements is [`sw-mlpl-blockers.md`](sw-mlpl-blockers.md);
the rule that decides what belongs in core is [`feature-homes.md`](feature-homes.md).
Nothing here authorizes a change from this repository. Status as of
2026-09-16: the upstream owner reports the autograd, dtype, and literal
items as in progress.

Verification protocol for every item: when the fix lands, `just
capabilities` reports DRIFT on the named probe; the reconciling step flips
the expectation in `catalog/probes.tsv`, re-pins the build commit in the
ledger, and removes the workaround where the plan allows.

## R1. Differentiable `sqrt`, `pow`, `rsqrt`

- Probes: `grad-sqrt`, `grad-pow`.
- Status: `sqrt` (and `sin`, `cos`, R5) shipped in upstream commit
  0dfa3eae on 2026-09-16 and the probes flipped to pass; `pow` and
  `rsqrt` remain open.
- Before the fix: "function 'sqrt' not supported inside grad()".
- Requested: backward rules `d sqrt(x) = 0.5 / sqrt(x)`, `d pow(x, n)` for
  a constant exponent, and an `rsqrt` builtin with `d rsqrt(x) = -0.5 *
  x^(-1.5)`, all elementwise with broadcasting.
- Acceptance: gradients match the analytic forms to 1e-9 on the probe
  vectors; `grad-sqrt-workaround` continues to pass so the two spellings
  agree.
- Used by: RMSNorm and attention scaling in `lib/qwen3/`.

## R2. Differentiable `softmax(a, axis)`

- Probe: `grad-softmax-axis`.
- Today: the eager two-argument form works; on the tape "softmax expects 1
  arguments, got 2".
- Requested: the axis form on the tape with the same backward as the
  one-argument form, for any rank.
- Acceptance: gradient of `reduce_add(softmax(x, 1) * mask)` on a `[2, 3]`
  input equals the one-argument row-wise result.
- Used by: attention over `[heads, T, T]` scores without per-head slicing.

## R3. Batched `matmul` over leading axes, and a correct error message

- Probe: `matmul-rank3`.
- Today: rank-3 operands fail with "index has 3 components but array has
  rank 2", which names the wrong problem.
- Requested: `matmul` on `[..., m, k] x [..., k, n]` with broadcasting of
  the leading axes, differentiable; until then, an error that says
  `matmul` accepts rank-2 operands only.
- Acceptance: `[2, 3, 4] x [2, 4, 3]` yields `[2, 3, 3]` equal to the
  per-slice products; gradient with respect to either operand matches the
  per-slice gradients.
- Used by: multi-head and grouped-query attention, removing a 16-iteration
  loop per layer.

## R4. Differentiable `transpose_axes`

- Probe: `grad-transpose-axes`.
- Today: "function 'transpose_axes' not supported inside grad()".
- Requested: backward is the inverse permutation.
- Acceptance: gradient of a weighted sum through `transpose_axes(x, [1, 0])`
  equals the transposed weights.
- Used by: head splitting and merging in attention.

## R5. Differentiable `sin` and `cos`

- Probe: `grad-sin-cos`.
- Status: shipped in upstream commit 0dfa3eae; the probe passes.

## R6. Scientific-notation literals

- Probe: `scientific-literal`.
- Status: shipped in upstream commit 2a774891 on 2026-09-16; the probe
  passes.
- Before the fix: `1e-4` lexed as `1`, `e`, `- 4` and failed with
  "undefined variable: e".
- Requested: `1e-4`, `2.5E+3`, `1e6` as numeric literals.
- Acceptance: `1e-4 == 0.0001` and `1e6 == 1000000`.
- Used by: every epsilon and learning rate in the plan.

## R7. `bf16` and `f16` dtypes with a bulk unpack to an array

- Probe: `reinterpret-bf16`.
- Today: accepted dtypes are `u8 i8 u16 i16 u32 i32 u64 i64 f32 f64`.
- Requested: `bf16` and `f16` in `reinterpret`, and a bulk
  `unpack(bytes, dtype)` returning an f64 array (subnormals, infinities,
  and NaN preserved).
- Acceptance: the byte pairs in `bf16-vectorized-decode` unpack to
  `[1, -1, 2, 0.5, 0, 50]`; a 155.6 M-value tensor unpacks without an
  intermediate f64 byte array.
- Used by: loading `model.safetensors` (1.19 GB bf16) in `lib/safetensors/`.

## R8. Optional: weight decay on `adam`

- No probe; the signature has no decay term.
- Requested: a decoupled weight-decay argument.
- Not blocking: the plan's hand-written Adam (Saga 5) implements clipping
  and decay as a library and remains the readable reference.

## R9. Distribution: an MLX-featured build and wider device dispatch

- Not a feature request. The current binary reports the `mlx` feature is
  not compiled in, and device dispatch covers nineteen operations without
  `gather_rows`, `take`, `concat`, or `rotate`.
- Why it matters: `matmul-throughput` measures 252 ms for the output-head
  product alone, which extrapolates to seconds per generated token on the
  CPU interpreter; real-model evaluation and training runs depend on a
  resident-tape backend.
- What this repository will supply: the user-array forward pass as an
  acceptance oracle, and a measured attempt recorded in Saga 3 step 4.

## Not requested

- Regular expressions (no remaining user; see `feature-homes.md`).
- `parse_json` for arrays of objects (JSONL is the input by design).
- String helpers and gradient clipping (libraries here).
- A pretrained-decoder surface in the Model DSL (this repository's array
  implementation is the deliverable; a native surface is a later upstream
  choice with this code as its oracle).
