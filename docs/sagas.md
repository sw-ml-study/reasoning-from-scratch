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
| 2 | `capability-probes` | pending |
| 3 | `math-data-loader` | pending |
| 4 | `boxed-extraction-and-normalization` | pending |
| 5 | `expression-equivalence` | pending |
| 6 | `evaluation-harness` | pending |

Acceptance: `just check` runs a complete, tested verifier and evaluation
harness without any model, and the capability ledger contains only measured
claims.

## Queued: Saga 2, `tokenizer`

Import `tokenizer.json`, implement byte-level BPE encode and decode with
special tokens and chat templates in MLPL, and measure throughput on the
training corpus.

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
