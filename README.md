# reasoning-from-scratch

A reasoning language model built step by step in
[sw-MLPL](../sw-mlpl), following the method sequence of Sebastian Raschka's
*Build a Reasoning Model (From Scratch)* (Manning, 2026) without Python and
without any external machine-learning library in the reference implementation.
An explicitly labeled native inference workaround is now available for live
demonstrations while the reference implementation's performance is repaired.

The project starts from the pretrained Qwen3-0.6B base checkpoint and adds,
in order: text generation with a key/value cache, a math-answer verifier and
MATH-500 evaluation, inference-time scaling (chain-of-thought, sampling,
self-consistency, self-refinement), reinforcement learning with verifiable
rewards (GRPO and its stabilizers), and distillation from a stronger
teacher. Every one of those algorithms is `.mlpl` source in this repository.
The interpreter contributes only generic array kernels, autograd, byte and
JSON I/O, and process control; tokenization and downloading are native
services from `../demo-extensions` with MLPL reference or fallback paths.

## Summary

| Layer | What it does | Where |
|---|---|---|
| verifier and harness | boxed-answer extraction, LaTeX normalization, bounded expression equivalence, MATH-500 loop | `lib/verify/`, `lib/eval/` |
| tokenizer | `tokenizer.json` import, byte-level BPE, control tokens, chat templates | `lib/tokenizer/` |
| model | bf16 safetensors decoding, Qwen3 forward pass (RMSNorm, RoPE, grouped-query attention, SwiGLU), KV cache | `lib/safetensors/`, `lib/qwen3/`, `lib/generate/` |
| scaling | temperature, top-p, self-consistency, scoring, self-refinement | `lib/scaling/` |
| training | GRPO rewards, advantages, clipped and KL objectives, distillation loss and loops | `lib/rl/`, `lib/distill/` |

Read [`docs/how-base-becomes-reasoning.md`](docs/how-base-becomes-reasoning.md)
for what is trained, on what data, and through which mechanisms.

The book and its Apache-2.0 companion code are references only: no code or
prose is copied, and the project is independently implemented under the MIT
license. See [`docs/licensing.md`](docs/licensing.md) for the policy and
the reasoning behind it.

## Status

**Live demo:** `just reasoning-demo` runs pretrained Qwen3 8B Q6_K through
the existing Rust HTTP extension and local Ollama GPU backend, then grades
its final answer in MLPL. A warm complete run answered correctly in 13.6 s
at 40.5 tokens/s; Ollama reported 100% GPU residency, about 7 GiB on the
16 GiB RTX 5060 Ti. See [commands, provenance and limits](docs/native-reasoning-demo.md).
This is an inference-only external baseline, not the MLPL 0.6B model or
project-trained GRPO. `just reasoning-eval` compares thinking off/on over
five authored demo cases; these are not a held-out benchmark.

The [publishable HTML research report](docs/reasoning-results.html) and
[executable Org/ob-mlpl source](docs/reasoning-results.org) reproduce every
saved grade, explain the 5/5 versus 2/5 budget-limited result, compare methods
with the book's Python companion, and run an analytic six-step scalar
training example. `just research-refresh` replays its offline calculations;
`just research-html` only exports. Neither recipe runs model inference.

Revalidated on Arch Linux on 2026-09-29 with sw-MLPL 0.22.0, build
`49c15b3e`. The verifier, evaluation harness, reference tokenizer and
templates, tiny Qwen3 forward pass, and KV-cache generation are implemented.
The safetensors header reader validates tensor names, shapes, offsets, and
tied embeddings; the previous Apple run validated all 310 tensors in the
real checkpoint. The [named-tensor loader](docs/tensor-loader.md) now decodes
BF16/F32 weights and assembles a resident tied model on authored tiny files.
The pinned real checkpoint is now downloaded and validates all 310 tensors
on this host. After the original loading timeout, the
[loader profile](docs/loader-profile.md) reduced real loading to **101.45 s**.
Generation then failed an allocation under the same 32 GiB address-space
limit, at sampled peak RSS about 31.48 GiB. No real answer or accuracy result
is available from that reference path. The newer interpreter removes copying
of unrelated globals but still fails the same generation allocation limit
(102.89 s loading, status 134, 114 s total). The pretrained base checkpoint
has not been GRPO-trained here. The 32 GiB limit is a CPU virtual-address
budget, not GPU VRAM; these reference runs used no GPU.

The fixture suite has 155 native tests. A clean clone now generates its tiny
checkpoint fixture automatically. The implementation document reproduces all 25
library sources plus three drivers and a fixture builder (29 exact tangles).
Tiny cached generation matches full recomputation exactly
on both the original Apple machine and this Linux host.

Core request R11 (`unpack`) has shipped and passes finite/special-value,
malformed-buffer and full embedding-size synthetic checks. The loader passes
projection, finite-weight and cached-forward tests. [Verified downloads and
strict tokenizer parity](docs/extension-integration.md) are integrated;
bounded real-model CPU smoke now completes loading but exposes resident-model
copying during generation. That is the next performance boundary. See the
[upstream revalidation](docs/upstream-revalidation.md) and
[decoder handoff](docs/bf16-handoff.md). Saga 4 delivered [sampling primitives](docs/sampling.md):
temperature, nucleus filtering, seeded categorical draws, and sampled tiny
generation, with exact cached/full-forward agreement. It also delivers
[chain-of-thought prompting and self-consistency](docs/self-consistency.md):
seeded boxed-answer voting with explicit ties, abstentions, provenance, and
safe early stopping, tested with stub responders. [Scoring](docs/scoring.md)
now adds stable log probabilities, answer masking, entropy, and an explicit
ranking heuristic. `just scoring-demo` narrates these over fixtures and the
tiny model. [Self-refinement](docs/self-refinement.md) now adds critique/revision
prompts, bounded accept-if-not-worse rounds, and best-of-N with stable ties
and complete traces. `just refinement-demo` narrates scripted corrections
and regressions; it does not demonstrate learned reasoning. Saga 4 closes
with [the scaling report](docs/scaling-report.md): 41 scaling tests and
explicitly unavailable real-model measurements. Delivered dependencies are
being integrated before returning to the queued toy GRPO work.
Batched matmul and container-copy costs remain throughput constraints.
The moved Linux tokenizer package passes six fixture cases, eight real-Qwen
goldens and NFC. Public HTTP and tokenizer-load facades work; tokenizer
handle callbacks use documented R13 and empty-decode workarounds. Training
corpus throughput remains unavailable. Real-model scaling reports, GRPO, and
distillation are planned; none has real-model results.

The host has an RTX 5060 Ti with 16 GB VRAM. GPU execution of the MLPL
reference path is not validated: the previously tested CUDA build rejects CUDA 13.4
toolkit. Use the explicit CPU toolchain below for fixture checks. See
[Linux setup and measurements](docs/linux-toolchain.md), the
[saga queue](docs/sagas.md), and the [capability ledger](docs/sw-mlpl-blockers.md).

Two separate Emacs Org/Babel guides are maintained:
[how to use the model](docs/using-reasoning-model.org) and
[how it works](docs/reasoning.org). They document the bounded attempt;
the live native-backend demo is separately documented in both guides.

## Build and check

Prerequisites: a compatible sw-MLPL 0.22.0 interpreter (`MLPL=/abs/path`),
the mlplunit runner (`MLPLUNIT=/abs/path`), `just`, and batch Emacs with the
canonical upstream formatter (`MLPLFMT=/abs/path`). PATH and adjacent
checkouts are fallbacks. On this Arch host, use the explicit exports in
[Linux setup](docs/linux-toolchain.md); the installed interpreter is older.

```sh
just            # list recipes
just tools      # print the selected interpreter and runner
just tests      # native mlplunit suites under tests/
just mlpl-style # module comments, docstrings, canonical formatting
just sources    # no Python, nothing byte-identical to the reference clone
just capabilities  # run the probes and compare with catalog/probes.tsv
just upstream   # print upstream commits, interpreter build, extension and library signals
just fetch-math500  # opt-in download of the evaluation set into ignored data/
just math500-self-grade  # opt-in verifier check over all 500 reference answers
just check      # the complete precommit gate
```

`just check` runs on committed fixtures only. Downloading weights and data
and running the real model are opt-in recipes introduced by the steps that
need them; see [`docs/data-and-models.md`](docs/data-and-models.md).

## Development process

Work is divided into durable Agentrail steps. In each fresh session run
`agentrail next`, then `agentrail begin`; implement only that step; run
focused tests and `just check`; commit source and `.agentrail/` metadata;
and only then run `agentrail complete`. [`AGENTS.md`](AGENTS.md) contains
the full repository protocol, provenance rules, and completion gate.

## Acknowledgment

The method sequence, hyperparameters, and published results used for
comparison come from *Build a Reasoning Model (From Scratch)* by Sebastian
Raschka and its companion repository at
<https://github.com/rasbt/reasoning-from-scratch>. This project is an
independent implementation and is not affiliated with the author or
publisher.

Copyright (c) 2026 Michael A Wright. Distributed under the [MIT License](LICENSE).
