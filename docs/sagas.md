# Saga queue

Only one saga is active at a time. Later sagas are initialized after the
preceding saga is completed and archived. Newly discovered work is inserted
with Agentrail commands, never by editing append-only `.agentrail/` state.
Full step prompts live in `.agentrail/steps/`; the outline is in
[`plan.md`](plan.md).

## Active: Saga 1, `foundation-and-verifier`

| # | Step | Status |
|---|---|---|
| 1 | `foundation` | done in the planning session |
| 2 | `feature-home-triage` | done: core versus library versus extension rule and handoffs |
| 3 | `capability-probes` | done: 21 probes under `probes/`, declared in `catalog/probes.tsv`, run by `just capabilities` and the gate |
| 4 | `request-documents` | done: per-repository ask documents |
| 5 | `math-data-loader` | done: `lib/eval/data.mlpl`, fixtures, `just fetch-math500`; ledger reconciled to build 0dfa3eae |
| 6 | `boxed-extraction-and-normalization` | done: `lib/text/`, `lib/verify/extract.mlpl`, `lib/verify/normalize.mlpl`, 23 tests |
| 7 | `expression-equivalence` | done: exact rationals, bounded evaluator, grading; 500 of 500 MATH-500 answers self-grade |
| 8 | `evaluation-harness` | pending |
| 9 | `literate-org-document` | pending: `docs/reasoning.org` via `ob-mlpl`, tangle-verified |

Acceptance: `just check` runs a complete, tested verifier and evaluation
harness without any model, and the capability ledger contains only measured
claims.

## Queued: Saga 2, `tokenizer`

Import `tokenizer.json`, write the MLPL reference byte-level BPE on a
synthetic fixture, write the chat templates, hand the production encoder to
`../demo-extensions` as a Rust extension, and prove parity and throughput.

## Queued: Saga 3, `model-and-generation`

Decode bf16 safetensors, implement the Qwen3 forward pass and KV-cache
generation over plain arrays, prove it on a tiny configuration, then measure
the real model and run the MATH-500 baseline.

## Queued: Saga 4, `inference-time-scaling`

Temperature and nucleus sampling, chain-of-thought, self-consistency,
scoring, and self-refinement, with bounded real-model reports.

## Queued: Saga 5, `grpo`

Rewards, advantages, sequence log-probabilities, the policy loss, a toy
training run, real-model gradient feasibility, bounded training, and the
chapter 7 stabilizers.

## Queued: Saga 6, `distillation`

Teacher-trace dataset (local Ollama generation preferred), answer-only SFT
loss and loop, bounded real-model run.

## Queued: Saga 7, `closeout`

Results tables, final ledger, library handoffs, README status.
