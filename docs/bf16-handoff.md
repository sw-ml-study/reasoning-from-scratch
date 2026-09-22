# bf16 tensor decoding: unavailable, awaiting R11

## Recorded outcome (2026-09-22)

Saga 3's decoding step took its specified unavailable branch. No production
tensor decoder was implemented, no real tensor data was loaded, and no model
accuracy or GPU inference claim follows from this step. Header validation,
load plans, and tiny-model generation remain usable.

The selected CPU interpreter is sw-MLPL 0.22.0 at
`6d7846605f27adbadaf17b662b2a984285ec15a3`, built on Arch. A fresh read of the
upstream remote HEAD returned that same revision. This confirms the request
is still absent at the checked upstream revision; it is not evidence that
upstream declined it.

Reproduce from the repository root with the isolated tools described in
[Linux setup](linux-toolchain.md):

```sh
export MLPL=/disk1/tmp/reasoning-tools/sw-mlpl/components/cli/target/release/mlpl-repl
"$MLPL" --source-dir "$PWD" probes/unpack-bulk.mlpl
```

Observed exit status: **1**. The diagnostic reports
`unsupported: unknown function: unpack`; scalar reads of the same buffer
return `1`, `-1`, and `50`. The catalog correctly expects failure for this
probe, so a passing fixture gate does not mean bulk decoding is available.

## Core handoff

Owner: sw-MLPL core, request **R11** in
[the core work orders](sw-mlpl-requests.md). This is a dtype-to-array
primitive, so the [home rule](feature-homes.md) places it in core. The request
is recorded in this repository; no sibling changes or external messages
were made.

Required interface: `unpack(bytes, dtype) -> array`, a flat f64 numeric array
decoded from packed bytes, with the same byte order and dtype spellings as
`pack`/`reinterpret`. For safetensors bf16, bytes are little-endian. The
caller owns reshape, tensor-name mapping, projection transposition, and
tied embeddings. Invalid dtype names and byte lengths that are not multiples
of the element width must produce recoverable errors, not partial output or
panics. There must be no interpreted call per element and no intermediate
f64 array containing every individual byte.

Acceptance cases for the upstream implementation and its consumer tests:

| Case | Required result |
|---|---|
| Existing six-value probe | `[1, -1, 2, 0.5, 0, 50]` exactly; rank one |
| Empty byte buffer | Empty rank-one array |
| bf16 `0x0000`, `0x8000` | Positive and negative zero, retaining sign |
| bf16 `0x0001`, `0x007f`, `0x0080` | `2^-133`, `127 * 2^-133`, `2^-126` respectively |
| bf16 `0x7f7f` | Largest finite bf16, `(2 - 2^-7) * 2^127` |
| bf16 `0x7f80`, `0xff80`, `0x7fc1` | Positive infinity, negative infinity, NaN classification preserved |
| One-byte bf16 input / unsupported dtype | Recoverable error |
| Million-value f32 pack/unpack | Same values within f32 precision, without a scalar loop |
| 155,320,832-value bf16 buffer (opt-in) | Record wall time and peak RSS; seconds rather than minutes; no expanded byte array |

Special values above are acceptance requirements, not claims that the
existing vectorized reference already handles them. The large acceptance
case stays outside `just check`; it needs no model download if generated
synthetically. Pin the interpreter revision in the measurement.

## Resume conditions and dependent work

When the six-value probe starts passing, first run the full capability gate
and reconcile the expectation and build pin. Then start a new decoding
step with native mlplunit tests before writing the loader. Cover named tensor
reads, truncated spans, unsupported dtypes, shape disagreement, special
values, projection orientation, and tied embeddings over authored fixtures.
Use the existing validated load plans; keep all reasoning/model semantics in
MLPL and extend the literate document with the implemented sources.

Real-model smoke and MATH-500 baseline remain deferred behind this loader.
CUDA build/dispatch (R12) and the native tokenizer are separate outstanding
dependencies; resolving R11 alone will not establish either one.

**Decision: wait for core.** E3, the native safetensors-reader fallback, is
not activated unless core explicitly declines R11. A slow scalar loop or a
new out-of-tree decoder is not substituted for the missing primitive.

Saga 3 can close with this explicit unavailable outcome, as allowed by its
exit criterion. The next saga is inference-time scaling: temperature and
nucleus sampling first, proven on three- and ten-token fixtures with explicit
seeds. Its toy/stub work does not require the real checkpoint. Retain this
handoff as the condition for returning to real-model work.
