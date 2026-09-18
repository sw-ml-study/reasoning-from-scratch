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

A second planning step settled where each missing capability lives
([`docs/feature-homes.md`](docs/feature-homes.md)): autograd, dtype, and
lexer gaps go to sw-MLPL core (in progress upstream); array-math and
string helpers are MLPL libraries here; the production tokenizer and large
downloads are Rust extensions requested from `../demo-extensions`, with MLPL
reference implementations kept as parity oracles. The asks themselves are
in [`docs/sw-mlpl-requests.md`](docs/sw-mlpl-requests.md) and
[`docs/demo-extensions-requests.md`](docs/demo-extensions-requests.md), and
[`docs/demo-mlpl-libraries-requests.md`](docs/demo-mlpl-libraries-requests.md).

The capability ledger is now executable: twenty-one probes under
`probes/` pin each measured fact against the interpreter build, and
`just capabilities` fails when an observation drifts from
`catalog/probes.tsv`. Measured on this machine: a 150,000-key JSON object
parses in 83 ms, a 10 MB array round-trips through native serialization in
134 ms, and the output-head product alone costs 252 ms per token.

The first library is in: `lib/eval/data.mlpl` loads and validates
MATH-style records from JSONL (and small JSON arrays) under explicit
budgets, with eight mlplunit tests over hand-authored fixtures, and
`just fetch-math500` downloads the evaluation set with a size check.
Upstream has already shipped differentiable `sqrt`, `sin`, and `cos`
(build 0dfa3eae); the probe suite caught the change and the ledger was
reconciled.

Boxed-answer extraction and the thirteen-rule normalization pipeline are
in as well, over hand-written character scanners that stand in for regular
expressions: 23 tests cover every rule in isolation plus composed cases.
Upstream has since shipped scientific-notation literals (build 2a774891),
which the probe suite caught and the ledger records.

The verifier is complete. Exact-rational arithmetic and a bounded
recursive-descent evaluator replace the symbolic algebra system the
reference uses, and grading compares tuples part by part in order. Across
44 tests plus an opt-in run over the real evaluation set, all 500 MATH-500
reference answers grade correct against themselves with no false positives.

The evaluation harness closes the loop: a versioned prompt template, a run
over any responder function, one JSONL record per problem, CSV metrics, and
provenance on every report. `just verifier-demo` walks the whole pipeline
over committed fixtures with a stand-in responder and no model.

Saga 1 is complete. [`docs/reasoning.org`](docs/reasoning.org) is a literate
reading of every library above, written for `ob-mlpl`: prose before each of
its 52 source blocks, three runnable self-contained examples, and a gate
check that tangles the document and compares all eight sources byte for
byte, so the prose can never describe code that no longer exists.

Saga 2 is under way. The tokenizer import reads a real six-megabyte
`tokenizer.json` by locating each section and parsing it separately, because
the whole document cannot be parsed in one call: it contains an array of
objects, which the JSON parser refuses by design. The 151,643-entry
vocabulary and 151,387-entry merge list parse in about half a second, and a
native binary cache brings a warm load down to 173 milliseconds. The
byte-level encoder is next. Nothing yet generates text.

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
