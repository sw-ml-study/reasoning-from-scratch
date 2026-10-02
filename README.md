# reasoning-from-scratch

A reasoning language model built step by step in
[sw-MLPL](../sw-mlpl), following the method sequence of Sebastian Raschka's
*Build a Reasoning Model (From Scratch)* (Manning, 2026) without Python and
without any external machine-learning library in the reference implementation.
A working native Rust/CUDA inference prototype now runs the exact base
checkpoint, with MLPL controlling decoding. [Run the demo](docs/cuda-prototype.md):
a checked 185-token water-tank explanation takes about 8.4 seconds after loading.
The independent MLPL reference remains available; core optimization is deferred.

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

The project is independently implemented under the MIT license: no companion
implementation or book prose is copied. The author's short experimental
prompt strings are preserved as attributed data so the experiment is
comparable. See [`docs/licensing.md`](docs/licensing.md) for the policy.

## Status

The numeric grader now rejects overflow/NaN safely and bounds integer-power
work. Regrading the saved full500 prefix preserves all 641 previously reported
eligible grades. [Diagnosis, book comparison and versioned recovery](docs/grading-overflow.md).

Run `just book-full500-status` in another terminal for progress percentage,
projected ETA and provisional reasoning results every ten minutes. Add `60`
for minute updates or `--once` for one report. Ctrl-C stops only this viewer.

[Full500 is complete](docs/book-full500-results.md): all 2500 calls succeeded
on all 500 questions. Direct answers score **14.4%**, greedy chain-of-thought
**42.6%**, and three-sample voting **39.8%**. CoT adds 28.2 percentage points;
voting falls 2.8 points below greedy CoT. There are 127 token-capped calls,
zero backend errors and zero interruptions. Generation call time totals
18.86 hours; charged sessions total 20.33 hours. A same-hardware Python
speed comparison remains unavailable.

The [literate Org/HTML report](docs/reasoning-results.html) publishes final
paired outcomes, tokens, timing boundaries, memory and book comparisons.
Seven offline MLPL blocks reproduce its calculations. The monitor reports
completion; no worker restart is necessary. Native optimization and
language-model training remain separate next steps.

[CUDA tracing](docs/cuda-tracing.md) now separates kernel spans from driver
launch and transfer delays: 48 decode windows average 57.21 ms, with 4.66 ms
of summed kernel spans. These timings overlap. A standalone Rust/Candle
probe also reproduces recurring stalls; no new speedup or driver root cause
is claimed. A [toy graph experiment](docs/cuda-transport.md) halves median launch-sequence
time; applying it to the model still requires stable cache storage and parity. SQLite CLI is required by the new offline trace-accounting check.
Native selection also matches all 2,048 sampled tokens in a longer-context
pair, taking 154.2s versus 275.2s for reference selection. This is synthetic
acceptance evidence, separate from reasoning accuracy.

**The target is a book reproduction in MLPL with Rust/CUDA.** The exact
Qwen3-0.6B-Base checkpoint runs in-process through a native extension;
MLPL controls dataset preparation, prompting, decoding, extraction, voting,
grading and reporting. No Python or Ollama participates in this experiment.
Run the short authored demo with the documented interpreter override:

```sh
export MLPL=/disk1/tmp/reasoning-tools/build-49c15b3e/release/mlpl-repl
just cuda-reasoning
```

The [book-aligned comparison](docs/book-author-protocol.md) uses the author's
first ten MATH-500 records, canonical prompts and three methods: direct,
CoT and three-sample self-consistency. Prompt and implementation hashes were
committed before generation. All 50 calls completed in 38 minutes 22 seconds, with no backend errors.
Correct answers: **3/10 direct, 4/10 greedy CoT, 6/10 three-sample voting**.
This is a measured reasoning benefit on the fixed demonstration slice, not
a full 500-case result.

**Performance dogfooding identifies and reduces a concrete cost.**
The full-vocabulary MLPL sampler takes 96.29 ms/token versus 12.18 ms through
Rust. The resident native-selection adapter produces exactly the same
128-token sampled traces at **21.33 versus 8.98 tokens/s (2.37×)** in four
matched pairs. This is a speedup over our reference selector, not a measured
Python comparison. [Profiles and owner-specific fixes](docs/cuda-performance.md)
include remaining CUDA stalls and the [full500 protocol](docs/book-full500-protocol.md).
Run `just cuda-profile stages`, then `sampler`, `primitives`, `native-sample`
and `matched`; use `just cuda-profile-report` for offline numeric analysis.

Read the [publishable HTML report](docs/reasoning-results.html) or its
[Org/ob-mlpl source](docs/reasoning-results.org) for methods, paired results,
actual runtimes, analysis of generated reasoning, comparisons with the book
and planned work. The article explains the working implementation without
a development-history narrative. `just research-refresh` executes seven
offline MLPL blocks: sampling, extraction/voting/verification, measured-result
analysis, paired performance, relative rewards and an analytic-checked gradient update.
`just research-html` exports without inference.

Independent real-checkpoint numerical checks now compare a layer-streamed
MLPL F64 reference against native CUDA: F32 maximum logit difference
7.1162e-6, BF16 0.367154, and the same argmax. Tiny forward/cache checks and
real tokenizer goldens also pass. See [provider and validation details](docs/cuda-prototype.md).
The CUDA CLI build works on this host; resident GPU inference avoids the
pure-MLPL whole-model copying limitation. The historical 32 GiB budget was
CPU virtual address space, not the 16 GiB GPU's VRAM.

The native provider remains a pinned external prototype. Publishing its
source to the extension sibling awaits explicit authorization under the
read-only sibling policy. General symbolic grader parity, full 500-case
scale and real language-model training remain separate milestones. This is
pretrained base-model inference; no Qwen3 weights have been trained here.

The fixture suite has 189 native tests; `just check` also checks
provenance, style, exact literate tangles and offline report replay. Tests
never download weights or run the real model. The MLPL reference remains
available for algorithmic validation; interpreter efficiency work is deferred
in favor of measured native offload. See the [ecosystem integration](docs/ecosystem-reuse.md)
and [capability ledger](docs/sw-mlpl-blockers.md).

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
