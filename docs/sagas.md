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

## Complete with unavailable real-weight path: Saga 3, `model-and-generation`

| # | Step | Status |
|---|---|---|
| 1 | `qwen3-forward-tiny` | done: RMSNorm, RoPE, grouped-query attention, SwiGLU, seven property tests |
| 2 | `kv-cache-generation` | done: prefill and step, bit-identical to recomputation, greedy loop |
| 3 | `safetensors-header` | done: vendored reader, name mapping, whole-checkpoint validation against the real file |
| 4 | `arch-cuda-revalidation` | done: 83 tests and fixture gate pass on Arch CPU; CUDA 13.4 build blocker recorded |
| 5 | `bf16-tensor-decode` | done as unavailable: R11 absent at upstream HEAD 6d784660; no loader implemented |
| deferred | `real-model-smoke` | not run: requires R11 and the loader; GPU measurements also need R12 |
| deferred | `math500-baseline` | not run: requires real-model smoke and tokenization |

This satisfies the saga's explicit alternative exit: tiny-model algorithms
are proven and the real-model path has a precise filed blocker. It does not
mark decoding or evaluation as implemented. The [bf16 handoff](bf16-handoff.md)
records the reproduction, core acceptance cases, and resume conditions. E3
remains contingent on core declining R11; no decline has been observed.

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

Next session: archive the completed `model-and-generation` saga through
Agentrail, then initialize `inference-time-scaling` from Saga 4 in the plan.
Its first step is `sampling-primitives`: native mlplunit goldens for
temperature scaling, top-p with the crossing token retained and weights
renormalized, seeded categorical draws, and sampled decoding over tiny
weights. Use three- and ten-token distributions, explicit seeds, unique
`u:scaling_` functions, and the normal literate/catalog/check gate. Real-model
reports stay deferred; revisit the bf16 handoff when R11 ships.

## Queued: Saga 5, `grpo`

Rewards, advantages, sequence log-probabilities, the policy loss, a toy
training run, real-model gradient feasibility, bounded training, and the
chapter 7 stabilizers.

## Queued: Saga 6, `distillation`

Teacher-trace dataset (local Ollama generation preferred), answer-only SFT
loss and loop, bounded real-model run.

## Queued: Saga 7, `closeout`

Results tables, final ledger, library handoffs, README status.
