# Where a missing capability belongs

## Inference-only deadline exception, 2026-09-29

The user explicitly authorized native extension workarounds for expensive
MLPL execution, with interpreter efficiency improvements documented for
later. The live demo therefore uses the existing Rust HTTP dynamic library
to call local Ollama. Its native backend owns model storage, forward
execution, tokenization and decoding; MLPL owns prompts, sampling controls,
answer verification and experiment accounting. This is an inference-only
external pretrained baseline, not the differentiable MLPL model or a
project-trained model. No new Rust or sibling edits were needed.

The rules below still govern the reference implementation and training.
Do not claim that an HTTP call participates in the autograd tape. See the
[demo contract](native-reasoning-demo.md) for the current boundary and the
future in-process extension option.

This repository asks for nothing upstream and writes no Rust by default.
When a capability is missing, three homes exist, and the rule below decides
between them. The rule is applied in order; the first question that answers
"yes" decides.

## The rule

1. **Does the result have to sit on the autograd tape or the device
   dispatch path?** Then it is **sw-mlpl core**. Extension calls cross the
   boundary as plain values (numeric arrays, records, strings, packed bytes,
   opaque handles) and are invisible to `grad` and to `device("mlx")`, so a
   backward rule, a tensor primitive, a dtype, a lexer form, or a backend
   cannot live anywhere else.
2. **Can it be written as a bounded `.mlpl` function over existing
   primitives, fast enough for its use here?** Then it is an **MLPL
   library** in this repository (`lib/`), promoted to
   `../demo-mlpl-libraries` by pinned revision once it is domain-neutral and
   used by unrelated consumers.
3. **Otherwise**, if it needs native code, a file format, a network socket,
   or throughput the interpreter cannot reach, and its inputs and outputs fit
   the extension boundary types, it is a **Rust extension** built in
   `../demo-extensions` and loaded here with `load_extension`.

A tie-breaker for "is this relevant to an ML DSL": if a mainstream ML
framework ships the capability in its core tensor library, it is core; if the
framework ecosystem ships it as a separate package (tokenizers, regular
expressions, HTTP, databases), it is a library or an extension. Being
"ML-flavored" is not a reason to bake something into the language: gradient
clipping is ML, but it is three lines of array math.

Two consequences follow. The model itself (RMSNorm, RoPE, grouped-query
attention, SwiGLU, the losses) can never be an extension, because it must be
differentiated. And a capability may have two homes at once: an MLPL
reference implementation that proves semantics on fixtures, and an extension
that provides throughput, checked against each other by a parity test.

## Triage of the ledger (2026-09-16)

| Gap | Home | Owner and status | Reason |
|---|---|---|---|
| `sqrt`, `pow`, `sin`, `cos` backward rules | core | upstream, in progress | tape rule; RMSNorm and attention scale |
| `softmax(a, axis)` on the tape | core | upstream, in progress | tape rule over an axis argument |
| `transpose_axes` backward | core | upstream, in progress | tape rule for a general permutation |
| batched (rank-3) `matmul` and a correct error for it | core | upstream, in progress | tensor primitive; removes the per-head loop |
| scientific-notation literals | core | upstream, in progress | lexer; no other home possible |
| `bf16` / `f16` dtypes and bulk unpack | core | upstream, in progress | dtype; an extension `unpack_bf16(bytes)` returning an array is the fallback if core slips, since decoding needs no differentiation |
| weight decay | core (small) or library | upstream may add an `adam` flag; the hand-written Adam here already has it | optimizer builtins are core; the library form exists regardless |
| gradient-norm clipping | library | this repository, Saga 5 | array math over per-parameter `grad` results and a hand-written Adam step |
| string helpers (`trim`, `starts_with`, `ends_with`, `contains`, bounded `replace`) | library | this repository, `lib/text/`, Saga 1; promotion candidate L1 in `demo-mlpl-libraries-requests.md` | a few lines each over `str_find`, `str_slice`, `str_len` |
| boxed extraction, number recognition, LaTeX normalization | library | this repository, Saga 1 | character scanners; no regular expressions needed |
| bounded expression evaluator (the symbolic-library replacement) | library | this repository, Saga 1 | recursive descent over strings; later a candidate for `../demo-mlpl-libraries` |
| top-p filtering and seeded categorical draw | library | this repository, Saga 4 | `grade_down`, `running_sum`, `random`, `sample` |
| JSONL reading | library (by design) | this repository, Saga 1 | `parse_json` rejects arrays of objects on purpose; JSONL is the idiomatic input |
| regular expressions | not needed | none | the only two regex users in the method (number fallback, tokenizer pre-tokenization) are covered by the scanners and by the tokenizer extension; if a general regex ever becomes necessary it is an extension, never core |
| Hugging Face `tokenizer.json` import and byte-level BPE encode/decode | extension, with an MLPL reference | `../demo-extensions` builds the extension from the work order in `demo-extensions-requests.md`; this repository writes the MLPL reference on a synthetic fixture and the parity test (Saga 2) | a file format plus throughput over 12,000 prompts; no differentiation; strings and integer arrays cross the boundary |
| HTTP fetch of weights and datasets | extension, already exists | `../demo-extensions` `http-client` (V1: 1 MiB response limit, 10 s timeout) plus its designed but unbuilt bounded large-artifact download | until the large-download path ships, `scripts/fetch-*` use `curl`; the recipes switch to the extension when it can stream 1.2 GB to a checksum-verified file |
| KV cache for user-array models | library | this repository, Saga 3 | a record of per-layer arrays |
| checkpoints for plain arrays | library | this repository, Saga 5 | `to_native` per tensor with `write_atomic` |
| MLX-enabled interpreter build and dispatch coverage | distribution | upstream release decision | not a feature; the plan's tiny-first, bounded, measured real-model runs are the mitigation either way |

## What this changes in the plan

- Saga 2 keeps a pure-MLPL byte-level BPE as the *reference*: it runs on a
  synthetic tokenizer fixture, documents the algorithm readably, and is the
  oracle for the extension's parity test on real vocabulary. The production
  encoder used by evaluation and training is the extension.
- Saga 1 gains nothing new; its scanners were already libraries.
- Saga 5's hand-written Adam (with clipping and decay) stays a library even
  if core adds flags, because it is also the readable explanation of the
  optimizer.
- The README's claim is restated precisely: every reasoning algorithm is
  MLPL; tokenization and downloading are native services with MLPL
  reference or fallback paths.
