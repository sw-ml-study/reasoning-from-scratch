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

## Complete: Saga 4, `inference-time-scaling`

Temperature and nucleus sampling, chain-of-thought, self-consistency,
scoring, and self-refinement are fixture-tested. Real-model measurements
are explicitly unavailable in [the scaling report](scaling-report.md).

Saga 3 is archived under `.agentrail-archive/model-and-generation-20260922T133630/`.

| # | Step | Status |
|---|---|---|
| 1 | `sampling-primitives` | done: ten native tests; temperature, top-p, categorical draws, cached sampled decoding |
| 2 | `cot-and-self-consistency` | done: versioned suffix, seeded voting, ties, abstentions, audit rows and safe early stop; twelve tests |
| 3 | `scoring` | done: stable token/answer scores, entropy, explicit heuristic, teacher-forced tiny scoring and narrated demo; ten tests |
| 4 | `self-refinement` | done: critique/revision prompts, bounded accept-if-not-worse loop, best-of-N, provenance and demo; nine tests |
| 5 | `scaling-report` | done: fixture evidence and reference comparison; real measurements unavailable; R11, CUDA fallback and absent tokenizer rechecked |

The [sampling contract](sampling.md) pins threshold boundaries, stable ties,
seed warmup, and decoding provenance. Cached sampled ids equal an independent
full-forward loop. The [self-consistency contract](self-consistency.md)
specifies exact normalized vote keys and a stopping bound that preserves
winners and ties. [Scoring](scoring.md) adds causal answer alignment and an
auditable heuristic. [Self-refinement](self-refinement.md) retains accepted
and rejected candidates with explicit seeds and scorer parameters. All 124
native tests pass. The report records unavailable real measurements and
resume conditions; it does not mark real evaluation as completed.

## Queued: Saga 5, `grpo`

Rewards, advantages, sequence log-probabilities, the policy loss, a toy
training run, real-model gradient feasibility, bounded training, and the
chapter 7 stabilizers.

After the delivery-integration work below, initialize Saga 5. Start with
`rl-math-on-toy`: native MLPL goldens for
boxed-only rewards, unbiased group advantages with epsilon (including
`[1,1,0,0]` and constant rewards), masked summed sequence log probabilities,
policy loss, clipped ratios, KL surrogate, entropy, ordered think-tag format
reward and moving averages. Cover shapes, finite values, empty groups and
degenerate variance before implementing `lib/rl/` functions. Verify gradients
on analytic toy cases before reusing eager scoring in a training tape.

The following `tiny-policy-grpo` step must train a small policy on a seeded
synthetic verifiable task and measure reward before and after updates,
retaining metrics and checkpoint provenance. No real weights or CUDA are
needed for these first steps. Keep real-model gradient feasibility and
training gated by the decoder, tokenizer and measured device/memory limits.

## Active: `upstream-delivery-integration`

The user requested a fresh check and continuation after moving the extension
checkout. Core unpack has also shipped, activating the decoder resume
conditions. Saga 4 is archived at
`.agentrail-archive/inference-time-scaling-20260925T081019/`.

| Step | Status |
|---|---|
| `upstream-revalidation` | done: isolated cd3cd03f CPU build, R11 acceptance, 129 native tests, 25 probe outcomes and packaged tokenizer parity |
| `named-tensor-loader` | next: MLPL loader over validated headers and core unpack, fixture tests and full-size synthetic decode measurement |
| tokenizer/download integration | pending: public facades, strict parity runner, pinned artifact digests and verified downloads |
| real-model smoke | deferred until loader/integration and feasibility checks pass; CPU first if practical, GPU requires R12 |

See [the revalidation report](upstream-revalidation.md). Toy GRPO remains
independent of the real-model path and retains the starting contract above.

## Queued: Saga 6, `distillation`

Teacher-trace dataset (local Ollama generation preferred), answer-only SFT
loss and loop, bounded real-model run.

## Queued: Saga 7, `closeout`

Results tables, final ledger, library handoffs, README status.
