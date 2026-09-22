# Saga queue

Only one saga is active at a time. Later sagas are initialized after the
preceding saga is completed and archived. Newly discovered work is inserted
with Agentrail commands, never by editing append-only `.agentrail/` state.
Full step prompts live in `.agentrail/steps/`; the outline is in
[`plan.md`](plan.md).

## Complete: Saga 1, `foundation-and-verifier`

Nine steps, archived under `.agentrail-archive/`. Delivered the repository
foundation, the core/library/extension decision rule and per-repository
request documents, twenty-one capability probes with drift detection, the
dataset loader, the text scanners, boxed extraction, the thirteen-rule
normalizer, exact-rational arithmetic, the bounded expression evaluator,
grading, the evaluation harness, a narrated demo, and the literate
`docs/reasoning.org` with a tangle check. Evidence: 45 tests, and all 500
MATH-500 reference answers grading against themselves with no false
positives.

## Complete: Saga 2, `tokenizer`

| # | Step | Status |
|---|---|---|
| 1 | `tokenizer-json-import` | done: sectioned import, fixtures, native cache; real file measured |
| 2 | `bpe-reference-in-mlpl` | done: byte alphabet, pre-tokenizer, merge loop; correct but 34 ms per vocabulary lookup |
| 3 | `chat-templates-and-eos` | done: inverse byte map, id-ordered line table, control splitting, both prompt conventions |
| 4 | `extension-parity-and-throughput` | done: unavailable result recorded; goldens and runner published for when `hftok` builds |

The production encoder is a Rust extension requested from
`../demo-extensions`; this repository owns the MLPL reference encoder on a
synthetic fixture, the chat templates, and the parity tests. Step 4 stops
with an honest unavailable result if the extension has not landed.

## Active: Saga 3, `model-and-generation`

| # | Step | Status |
|---|---|---|
| 1 | `qwen3-forward-tiny` | done: RMSNorm, RoPE, grouped-query attention, SwiGLU, seven property tests |
| 2 | `kv-cache-generation` | done: prefill and step, bit-identical to recomputation, greedy loop |
| 3 | `safetensors-header` | done: vendored reader, name mapping, whole-checkpoint validation against the real file |
| 4 | `arch-cuda-revalidation` | done: 83 tests and fixture gate pass on Arch CPU; CUDA 13.4 build blocker recorded |
| 5 | `bf16-tensor-decode` | next, gated on upstream R11, reconfirmed on build 6d784660 |
| 6 | `real-model-smoke` | planned, follows step 5; GPU measurements also need R12 |
| 7 | `math500-baseline` | planned, follows step 6 |

The Linux revalidation uses isolated tool checkouts and explicit overrides;
it does not modify sibling repositories or the installed tools. See
[setup and measurements](linux-toolchain.md). The tokenizer's original
unavailable result above was superseded on Apple by fixture parity, but
real-vocabulary NFC support remains unresolved and the extension is absent
on this Linux host.

Resequenced so the blocked work comes last. Loading real weights needs a
bulk decode from a typed byte buffer to an array, which did not ship with
the `bf16` dtype; the forward pass, generation, and header parsing need
nothing upstream and come first.

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
