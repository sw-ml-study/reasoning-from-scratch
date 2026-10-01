# Requests to `../sw-mlpl` (core)

Current update, 2026-09-29: R11 remains accepted. The R10 unrelated-global
frame-copy issue is fixed upstream in `55c65f2f` and passes on isolated
`49c15b3e` (1.11/1.25 ms small/large scalar-call probe). Container lookup
and model-argument copying remain costly; the unchanged CPU smoke still
fails generation under 32 GiB. R3 and R12 remain open. The user requested
native extension offload now, with further interpreter efficiency work
documented for later; the [live demo](native-reasoning-demo.md) follows that
direction. No core changes are requested as a prerequisite for the demo.

This is the single list of what this repository asks of the language. Each
item names the probe that demonstrates the gap today, the semantics
requested, and the acceptance cases the probe will check once the change
ships. The ledger of measurements is [`sw-mlpl-blockers.md`](sw-mlpl-blockers.md);
the rule that decides what belongs in core is [`feature-homes.md`](feature-homes.md).
Nothing here authorizes a change from this repository. Status as of
2026-09-16: the upstream owner reports the autograd, dtype, and literal
items as in progress.

## Current status, 2026-09-22

Arch CPU build `6d784660` reconfirms R11, R3, and R10 as open using the
existing probes. The autograd/dtype successes remain passing. R12 below is
a new device-build handoff: cudarc rejects this host's CUDA 13.4 toolkit.
GPU hardware availability alone has not unblocked real inference. See
[Linux setup](linux-toolchain.md) for the exact tools and measurements.

## Historical status summary, 2026-09-18

Upstream closed its `reasoning-from-scratch-numerics` saga having shipped
every autograd, dtype, and lexer item below, plus a crash fix for a scalar
combined with an empty array that this repository reported separately. Two
core asks remain open and are **not** in the upstream queue, so they are
restated here:

| Open ask | Why it matters | Where it bites |
|---|---|---|
| **R11, bulk `unpack(bytes, dtype)` to an array** | **blocks Saga 3 entirely**: the `bf16` dtype shipped but only scalar reads exist, so loading a 155-million-value tensor means 155 million interpreter calls | the weight loader cannot be written at all |
| R3, batched rank-3 `matmul` | only the error message shipped; the operation itself did not | attention must slice per head, and slicing a large array costs 0.93 ms, so the slicing alone would cost more than the arithmetic |
| R10, element access that scales with container size | now measured on numeric arrays too, not just records and lists | the forward pass must avoid element access entirely; where the missing batched `matmul` forces slicing, that is not possible |

Also queued upstream, not blocking: `pow` with a general constant exponent,
behind an autograd crate refactor. The remaining items on this page are
library or extension work and are tracked in their own documents.

Verification protocol for every item: when the fix lands, `just
capabilities` reports DRIFT on the named probe; the reconciling step flips
the expectation in `catalog/probes.tsv`, re-pins the build commit in the
ledger, and removes the workaround where the plan allows.

## R1. Differentiable `sqrt`, `pow`, `rsqrt`

- Probes: `grad-sqrt`, `grad-pow`.
- Status: `sqrt` (and `sin`, `cos`, R5) shipped in commit 0dfa3eae and
  `pow` with a constant integer exponent in commit 8a1fe24a, both on
  2026-09-16; both probes pass. Remaining: `rsqrt`, and `pow` with a
  variable exponent (no probe yet, no consumer in the plan).
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
- Status: shipped in upstream commit 363391a6 on 2026-09-17; the probe
  passes.
- Before the fix: the eager two-argument form worked; on the tape it failed
  with "softmax expects 1 arguments, got 2".
- Requested: the axis form on the tape with the same backward as the
  one-argument form, for any rank.
- Acceptance: gradient of `reduce_add(softmax(x, 1) * mask)` on a `[2, 3]`
  input equals the one-argument row-wise result.
- Used by: attention over `[heads, T, T]` scores without per-head slicing.

## R3. Batched `matmul` over leading axes, and a correct error message

- Probe: `matmul-rank3`.
- Status: the error message shipped in commit fdb5e675 on 2026-09-16;
  rank-3 operands are now rejected with an actionable message. The batched
  operation itself is still open and the probe still expects failure.
- Before that fix: rank-3 operands failed with "index has 3 components but
  array has rank 2", which named the wrong problem.
- **New evidence for priority, 2026-09-18.** Without batched `matmul`,
  grouped-query attention must slice per head, and slicing is not free:
  `take` on a million-element array costs 0.93 ms because element access
  copies (see R10). Qwen3-0.6B has sixteen query heads over twenty-eight
  layers; at three slices per head per layer that is on the order of 1,300
  slices per generated token, or more than a second of pure slicing before
  any arithmetic happens. By contrast a `[1,1000] x [1000,1000]` product
  takes 1.28 ms, so the arithmetic itself is not the problem. This moves R3
  from an ergonomic improvement to a throughput requirement.
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
- Status: shipped in upstream commit 1abe8f10 on 2026-09-18; the probe passes.
- Before the fix: "function 'transpose_axes' not supported inside grad()".
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

## R7. `bf16` and `f16` dtypes

- Probe: `reinterpret-bf16`.
- Status: shipped in upstream commit a34cc230 on 2026-09-18; the probe
  passes. The bulk unpack that was bundled into this item did not ship and is
  now R11 below, because measurement showed it is the blocking half.
- Before the fix: accepted dtypes were `u8 i8 u16 i16 u32 i32 u64 i64 f32 f64`.

## R11. Bulk `unpack(bytes, dtype)` returning an array — delivered

Accepted 2026-09-25 on `cd3cd03f`, shipped by `b3180d9a`. The probe, five
native tests and bounded million-value f32/bf16 runs pass. The 155-million
value load/RSS case is still deferred to loader feasibility. See
[current evidence](upstream-revalidation.md). The original request and
September 22 disposition below are historical.

Consumer disposition, 2026-09-22: the bf16 decoding step closed with an
explicit unavailable result after the probe failed and upstream HEAD was
confirmed unchanged. [The handoff](bf16-handoff.md) specifies finite and
special-value cases, malformed buffers, bulk-size acceptance, and the
conditions for resuming the loader. No core decline has been observed;
the E3 extension fallback remains inactive.

- Probe: `probes/unpack-bulk.mlpl`, reconfirmed missing on build `6d784660`
  on 2026-09-22. It now calls the requested raw-byte interface and wraps the
  returned array in `ok` before unwrapping, so a future correct implementation
  is not incorrectly rejected by the probe itself.
- Today: `reinterpret(bytes, "bf16")` returns a typed *byte view*, not an
  array. It has no length, does not take part in arithmetic, and there is no
  `unpack` or `to_array`. The only way to get values out is one scalar at a
  time with `read_bf16_le(bytes, offset)`, which does work and returns the
  right value.
- Why that blocks: the Qwen3-0.6B embedding matrix alone holds 155,320,832
  values and the whole model about 596 million. At one interpreter call per
  value, loading the embedding is tens of minutes at best. There is no
  workaround in MLPL, because the vectorized bit arithmetic that decodes
  bf16 needs the bytes *as an array* to begin with, and that is exactly what
  is missing.
- Requested: `unpack(bytes, dtype) -> array`, the inverse of the existing
  `pack(array, dtype)`, for every dtype `reinterpret` accepts. Shape is a
  flat rank-1 array of the decoded values; the caller reshapes. Errors when
  the buffer length is not a multiple of the dtype width.
- Acceptance: `unpack(pack(x, "f32"), "f32")` reproduces `x` within f32
  precision for a million-element array; `unpack` of the bf16 bytes for
  `[1, -1, 2, 0.5, 0, 50]` returns those values exactly; decoding a
  155-million-value tensor completes in seconds rather than minutes.
- Used by: `lib/safetensors/` in Saga 3, which is the gate to every
  real-model result in this project. Everything downstream of it, generation,
  evaluation, reinforcement learning, and distillation, waits on this one
  call.
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

## R10. Container element access that does not scale with container size

### Extension: user-call scope snapshots, measured 2026-09-28

Superseded in part on 2026-09-29: the snapshot mechanism below was replaced
upstream by an undo log of written names. Existing scope acceptance passes
on `49c15b3e`; record/list lookup probes still fail. A nested model argument
can still be evaluated, saved when shadowed, and rebound with payload-sized
copies. Future work should share immutable/COW arrays through records and
partials while preserving error restoration, recursion, global writes and
the gradient tape. Add nested-call peak-memory and alias-isolation tests,
then repeat cached/full parity before accepting it. This is deferred core
work; use the inference-only native extension workaround today.

The loader profile now isolates an additional cost on `cd3cd03f`:
`probes/call-scope-scaling.mlpl` makes 100 scalar calls while retaining an
unrelated caller array. With 16 values it takes 0.40 ms; with 1,048,576
values it takes 106.93 ms. The callee neither reads nor receives that array.
Read-only source inspection confirms scope-table cloning at each user call.
This is a core binding/value/frame issue under the feature-home rule.

- Required semantics: preserve return values, local shadowing, caller
  bindings, recoverable error restoration, global-write behavior and tape
  semantics without copying unrelated numeric payloads per call.
- Probe expectation on the pinned build: **fail**.
- Acceptance: 100 large-case scalar calls finish within
  `max(10 ms, 8 * small_case_ms)`; scalar sums and caller bindings remain
  unchanged. Retain existing scoping, recursion and differentiation tests;
  extend acceptance to arrays nested in records and bound partials.
- Affected work: real-model loading, resident layer callbacks, forward/cache
  execution, subsequent evaluation and training feasibility.
- Library workaround: keep large loader fields and role-stack operands
  temporary instead of binding them across nested calls. The measured
  fixture load falls from 1,499 ms to 295 ms, but this does not fix arbitrary
  calls while the full model is resident. See [the profile](loader-profile.md).

The existing field/list lookup request below remains open; the scalar-call
probe distinguishes frame copying from lookup itself. No Rust is written or
sibling repository modified by this consumer step.

- Probes: `record-lookup-scaling`, `list-index-scaling`.
- Today, measured on build 1ce43dc2:

| Access | Small container | Large container |
|---|---|---|
| `record_get` | 0.0026 ms at 2 fields | 10.4 ms at 150,000 fields; 34 ms on the real 151,643-entry vocabulary |
| `list_get` | negligible at 4 items | 10 ms at 303,282 items |
| `at` on a numeric array | 0.0017 ms at 4 elements | 0.97 ms at 1,000,000 elements |
| `take` of one row | — | 0.93 ms at 1,000,000 elements |

  Numeric arrays are affected too, which was not obvious from the first two
  probes and matters far more: it means the transformer forward pass must be
  written entirely in whole-array operations and must never index an element
  inside a loop. Whole-array arithmetic is genuinely fast by comparison, at
  1.28 ms for a `[1,1000] x [1000,1000]` product, so this is specifically a
  cost of *reaching into* a container rather than of computing with it.

  `record_get`, `has_field`, and `r.field` are equally affected, so records
  share one underlying lookup. The decisive observation is on lists: reading
  index 5 costs the same as reading index 50,000, so the cost follows the
  container's **size**, not the distance to the element. That is the signature
  of copying on access rather than of a linear scan, which suggests the fix is
  sharing rather than a different data structure.

- Requested: element access in time independent of container size, or at
  worst logarithmic. No change to semantics or ordering is needed;
  `record_keys` may keep returning sorted keys.
- Acceptance: each probe's 100 accesses on a 150,000-element container
  complete within 100 ms.
- Used by: the reference tokenizer. Encoding needs a vocabulary lookup per
  symbol and per candidate merge, so one word costs seconds; decoding needs
  one list read per token, so a 512-token response would take minutes. This
  does not block the project, because the production encoder is a native
  extension, but it is the difference between a reference implementation that
  can be run on real input and one that can only be read. It would also
  affect any later library that keeps a large table in MLPL.

## R12. CUDA 13.4 build compatibility and array-dispatch acceptance

- Home: core/device distribution; no Rust or sibling edits belong here.
- Environment: Arch Linux x86_64, RTX 5060 Ti (16 GB), driver 615.71.09,
  CUDA toolkit 13.4. The GPU is visible outside the execution sandbox.
- Evidence: building sw-MLPL `6d784660` with `cargo build -p mlpl-repl
  --release --features cuda --locked` in its CLI workspace fails in
  `cudarc 0.19.7` with `Unsupported cuda toolkit version: 13.4`.
- Required: a supported CUDA dependency/toolkit pairing for this host.
  The CPU build passes fixture tests but warns and falls back when CUDA is
  requested, so it is not a GPU workaround.
- Probe: `probes/cuda-matmul.mlpl` through `just cuda-probe`, expected exact
  product `[[19,22],[43,50]]` without fallback. The runner returns unavailable
  on the current CPU build. This opt-in probe is outside the fixture catalog.
- Acceptance: build the CUDA-enabled CLI; demonstrate real device dispatch
  without fallback and compare its matrix products, normalization, reshaping,
  gathers, slicing, concatenation, and softmax against CPU results before
  measuring Qwen3. Training additionally needs backward/tape acceptance.
- Affected steps: real-model smoke and throughput, baseline feasibility,
  and later real-model gradient feasibility. R11 remains the earlier gate
  to reading weights even after this build issue is resolved.
- Reproduction: [Linux toolchain record](linux-toolchain.md). Do not replace
  the installed user tools or change upstream dependencies from this repo.

## Not requested

- Regular expressions (no remaining user; see `feature-homes.md`).
- `parse_json` for arrays of objects (JSONL is the input by design).
- String helpers and gradient clipping (libraries here).
- A pretrained-decoder surface in the Model DSL (this repository's array
  implementation is the deliverable; a native surface is a later upstream
  choice with this code as its oracle).

## R13. Native handles as ordinary user-function arguments

Measured 2026-09-27 on `cd3cd03f`. `u:hftok_load(path)` returns a valid
native handle, but `u:hftok_encode(handle, text)` is rejected by generic
user-function argument binding before the extension is called. Direct
native calls work. Source inspection of remote HEAD `3e3748f4` still shows
that `eval_user_fn.rs` rejects handles; that newer build was not adopted.

Home: core value/function semantics, not tokenizer logic. Required behavior:
identity functions, ordinary public facade calls and partial application
must accept and preserve opaque handles without exposing their internals.
Stale/wrong-resource handles must still fail at their native owner.

Opt-in probe: `probes/native-handle-argument.mlpl`, run through
`scripts/run-extension-demo hftok probes/native-handle-argument.mlpl`.
Expected after fix: exit 0, forwarded handle encodes `abc` as `[6]`.
Observed: exit 1 with unsupported argument type. Acceptance includes direct
and partial facade encode/decode/close, callback use and stale-handle errors.
Affected work: tokenizer facade integration and real-model responder adapter.

Workaround: carry the handle in a record accepted by the evaluator, then
call the native encoder/decoder on `box.handle`. The strict parity runner
uses this explicit MLPL adapter. No upstream source was modified.

## R14. Vocabulary-scale array-copy and sampling cost (measured, 2026-09-30)

**Awkward, not a missing language capability.** The reasoning consumer's
151,936-logit profile measures roughly 95 ms/token in its MLPL sampler.
Reproduce with `just cuda-profile stages`, then `sampler` and `primitives`;
see [performance evidence](cuda-performance.md). The alternative Rust
implementation preserves the f64 distribution and supplied-uniform decisions.

Source inspection at build `49c15b3e` shows `DenseArray` derives `Clone` over
`Vec<f64>` (`components/array/crates/mlpl-array/src/dense.rs`). Record and
Result reads clone payloads in `components/eval/crates/mlpl-eval/src/eval.rs`;
assignment also clones values. The sampler passes several full vectors through
user functions, Results and generic operations. These copies are real source
behavior; their exact share of total time has not yet been allocation-profiled.
Do not attribute all 95 ms to a single core defect.

Requested core investigation: instrument allocations/bytes copied for the
committed primitive profile; introduce borrowed/shared immutable array storage
or copy-on-write only with aliasing/autograd regression coverage. Specialize
contiguous rank-one reductions/softmax where measurements justify it. Preserve
f64 arithmetic order, stable grading ties and categorical boundaries. Compare
identical fixed input vectors at sizes 128, 4096 and 151936, including memory,
then run the consumer's exact probability and supplied-uniform acceptance.

Library-side repeated validation/normalization and the second inverse argsort
are separate optimization opportunities; do not disguise them as core gaps.
The tested native extension is the immediate workaround. `demo-ml-utils`
provides useful provider/acceptance contracts but does not execute this hot
path; there is no evidence that its implementation causes these measurements.
