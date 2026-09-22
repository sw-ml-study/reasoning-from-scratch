# reasoning-from-scratch

A reasoning language model built step by step in
[sw-MLPL](../sw-mlpl), following the method sequence of Sebastian Raschka's
*Build a Reasoning Model (From Scratch)* (Manning, 2026) without Python and
without any external machine-learning library.

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

Revalidated on Arch Linux on 2026-09-22 with sw-MLPL 0.22.0, build
`6d784660`. The verifier, evaluation harness, reference tokenizer and
templates, tiny Qwen3 forward pass, and KV-cache generation are implemented.
The safetensors header reader validates tensor names, shapes, offsets, and
tied embeddings; the previous Apple run validated all 310 tensors in the
real checkpoint. Tensor data is not yet loaded and there is no real-model
accuracy result.

The fixture suite has 105 native tests. A clean clone now generates its tiny
checkpoint fixture automatically. The literate document reproduces all 18
library sources. Tiny cached generation matches full recomputation exactly
on both the original Apple machine and this Linux host.

The bf16 decoding step recorded an explicit unavailable outcome: core
request R11 (`unpack`) is still missing at upstream HEAD `6d784660`.
[The decoder handoff](docs/bf16-handoff.md) pins reproduction, acceptance,
and resume conditions. Saga 4 has delivered [sampling primitives](docs/sampling.md):
temperature, nucleus filtering, seeded categorical draws, and sampled tiny
generation, with exact cached/full-forward agreement. It also delivers
[chain-of-thought prompting and self-consistency](docs/self-consistency.md):
seeded boxed-answer voting with explicit ties, abstentions, provenance, and
safe early stopping, tested with stub responders. Scoring is next.
Real loading remains deferred. Batched matmul and container-copy costs remain
throughput constraints. The tokenizer extension passed synthetic parity on
Apple but refused the real vocabulary's NFC normalizer; that extension is
not installed in this Linux checkout. Remaining scaling methods, GRPO, and
distillation are planned; none has real-model results.

The host has an RTX 5060 Ti with 16 GB VRAM, but GPU execution is not yet
validated: the current upstream CUDA build rejects the installed CUDA 13.4
toolkit. Use the explicit CPU toolchain below for fixture checks. See
[Linux setup and measurements](docs/linux-toolchain.md), the
[saga queue](docs/sagas.md), and the [capability ledger](docs/sw-mlpl-blockers.md).

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
