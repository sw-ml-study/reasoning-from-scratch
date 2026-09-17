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
JSON I/O, and process control.

## Summary

| Layer | What it does | Where |
|---|---|---|
| verifier and harness | boxed-answer extraction, LaTeX normalization, bounded expression equivalence, MATH-500 loop | `lib/verify/`, `lib/eval/` |
| tokenizer | `tokenizer.json` import, byte-level BPE, control tokens, chat templates | `lib/tokenizer/` |
| model | bf16 safetensors decoding, Qwen3 forward pass (RMSNorm, RoPE, grouped-query attention, SwiGLU), KV cache | `lib/safetensors/`, `lib/qwen3/`, `lib/generate/` |
| scaling | temperature, top-p, self-consistency, scoring, self-refinement | `lib/scaling/` |
| training | GRPO rewards, advantages, clipped and KL objectives, distillation loss and loops | `lib/rl/`, `lib/distill/` |

The book and its Apache-2.0 companion code are references only: no code or
prose is copied, and the project is independently implemented under the MIT
license. See [`docs/licensing.md`](docs/licensing.md) for the policy and
the reasoning behind it.

## Status

Planning is complete; implementation has not started. This session
established the repository foundation: peer-identical license files, the
Agentrail process, the [delivery plan](docs/plan.md), the
[saga queue](docs/sagas.md), the [architecture](docs/architecture.md), the
[book-to-component map](docs/book-map.md), the
[verifier contract](docs/verifier-contract.md), the
[data and model layout](docs/data-and-models.md), and a measured
[sw-MLPL capability ledger](docs/sw-mlpl-blockers.md) listing the autograd,
tokenizer, byte-decoding, and JSON gaps with their workarounds and upstream
requests, plus single-operation timings that place CPU decoding of the 0.6B
model at seconds per token, which makes bounded, measured real-model runs
and an MLX build the decisive questions for later sagas.

Saga 1 (verifier and evaluation harness, no model needed) is active; its
next step is `capability-probes`. Nothing yet generates text.

## Build and check

Prerequisites: a built sw-MLPL interpreter (`../sw-mlpl/target/release/mlpl-repl`
or `MLPL=/abs/path`), the mlplunit runner (`MLPLUNIT=/abs/path` or the
adjacent `softwarewrighter/mlplunit` checkout), `just`, and batch Emacs for
the canonical formatter used by the style check.

```sh
just            # list recipes
just tools      # print the selected interpreter and runner
just tests      # native mlplunit suites under tests/
just mlpl-style # module comments, docstrings, canonical formatting
just sources    # no Python, nothing byte-identical to the reference clone
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
