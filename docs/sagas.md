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
| `named-tensor-loader` | done: packed BF16/F32 reads, resident tied-model assembly, nine native tests and full embedding-size synthetic measurement |
| tokenizer/download integration | done: pinned external facades, strict parity and verified downloads; boxed-handle/empty-decode workarounds, corpus throughput unavailable |
| real-model smoke | done as unavailable: pinned weights verified; 600-second CPU deadline during loading, 14.14 GiB sampled peak; no generation |
| loader-copy-profile | done: scoped fields/stacks, 148 tests, scalar-call probe; real load 101.45 s, generation allocation failure under 32 GiB |
| afternoon-demo-readiness | delivered: native extension/GPU demo, ten recorded attempts, offline replay, Org/HTML report and scalar training illustration |
| report-readable-type | delivered: larger body, source/result blocks, tables and navigation; regenerated standalone HTML |
| reasoning-budget-report | delivered: configurable output budget, all-attempt follow-up, method-focused report and explicit reasoning-benefit milestones |
| native-reasoning-heldout | delivered: frozen six-problem, two-seed paired pilot with retained failures, uncertainty and cost; report distinguishes verifier false negatives |
| verifier-choice-equivalence | delivered: narrow choice-v2 normalization with positive/negative tests; 24 saved attempts replayed, four corrected grades; frozen primary scores retained |
| reasoning-fresh-holdout | next: user-prioritized book reproduction; validate native Qwen3-0.6B-Base execution and base prompts, then freeze direct/CoT/voting evaluation; no further broad 8B toggle benchmark |
| native-output-budget | delivered: configurable bounded development retry; the truncated case completes correctly in 3,158 tokens / 88.01 s with full GPU residency; longer HTTP deadline requested as E5 |
| resident-inference-copy-profile | deferred by user: document future core efficiency work; do not let it block native inference |

See [the revalidation report](upstream-revalidation.md). Toy GRPO remains
independent of the real-model path and retains the starting contract above.
The [loader report](tensor-loader.md) records 138 tests, 26 probe outcomes,
21 tangled libraries and a 1.27 s synthetic embedding decode. The later
[real attempt](real-model-smoke.md) measures partial loading memory, but
whole-model assembly was initially unavailable. The
[scope refactor](loader-profile.md) now completes loading, with generation
still unavailable under the declared memory limit.

The [integration report](extension-integration.md) records 143 tests, 26
fixture probes and 23 tangled sources, plus opt-in native parity and small
verified transfers. Two user-requested Org/Babel documents are separate:
[usage](using-reasoning-model.org) and [implementation](reasoning.org).
Both now include the bounded attempt, exact commands, observed acceptance
and timeout, and the annotated driver. No generated real-model example is
claimed for that reference path. The later user-authorized native workaround
now generates actual answers, documented in the [live demo](native-reasoning-demo.md)
and [Org research report](reasoning-results.org) with [publishable HTML](reasoning-results.html).
The current gate has 155 native tests, 27 probe outcomes and 29 tangled
sources (25 libraries, three drivers and one fixture builder), plus offline
research replay. Thinking off/on scored 5/5 and 2/5 on five authored demo
cases; three thinking-mode attempts truncated. No held-out quality or LLM
training improvement is claimed. The scalar SGD example is independently
checked against an analytic recurrence. Next, measure a frozen held-out
native-backend pilot; retain independent queued toy GRPO work.

## Queued: Saga 6, `distillation`

Teacher-trace dataset through a native Rust/CUDA provider, with the teacher
checkpoint and sampling pinned separately; answer-only SFT loss and loop,
bounded real-model run. This follows the user's no-Ollama target.

## Queued: Saga 7, `closeout`

Results tables, final ledger, library handoffs, README status.

## Book reproduction, current handoff

Step 012 freezes a 12-case disjoint base-model protocol but does not run it:
the user clarified Rust CUDA rather than Ollama, and requested ecosystem
reuse. The pinned audit includes CUDA demos, demo-ml-utils, reusable libraries
and extension ABI; three utility runners pass locally. Existing native
training machinery is real but limited; CUDA build pairing and the general
Qwen3 provider still require validation. Next step reuses/revalidates this
foundation before any book evaluation. Core copying optimization remains
deferred. See `ecosystem-reuse.md`, `rust-cuda-backend.md` and E6.

Step 013 now delivers an isolated CUDA CLI matrix pass, an external Rust
Qwen3 provider prototype, MLPL greedy generation with fixture tests, optional
GPU parity/lifecycle checks, and two preserved real base-model transcripts.
The water-tank explanation is correct; multiplication has a correct answer
but flawed reasoning. See `cuda-prototype.md`. The next step delivers
provider acceptance/provenance and the frozen direct/CoT/voting pilot.
Portable E6 delivery and real-model numerical equivalence remain outstanding;
training is separate. Core copying optimization remains deferred.

Step 014 execution preparation: real-model MLPL/CUDA numerical comparison,
real tokenizer goldens, seeded native decoding and tie-abstaining vote tests
pass; the complete 12-call authored smoke runs successfully. Execution and
prompt hashes are frozen before any selected generation. Next: execute the
144-call pilot under its existing two-hour cap, then publish complete or
explicitly incomplete accounting. Sibling provider publication is awaiting
user authorization; the pinned local backend is usable independently.

User clarification during step 014 makes book recreation the acceptance
criterion. The strict custom pilot was stopped after 12 recorded outcomes
(one further request interrupted); do not present it as author parity. The
active v2 demonstration uses author-ordered first ten cases, exact short
prompt data, fallback extraction, raw-string voting and first-appearance ties,
all implemented independently in MLPL. A five-call authored smoke passes in
30 seconds. Numeric/symbolic grading and RNG differences remain explicit.

Step 014 now completes all fifty author-v2 calls: 3/10 direct, 4/10 greedy
CoT, 6/10 three-sample voting, with no backend errors. The job takes 38 min
22 sec, and four responses reach the token cap. CoT has two paired gains
and one loss; voting adds three gains and one loss relative to CoT. Selected
trace review verifies two reasoning gains and distinguishes repetition,
answer-format loss and sampling regression. All primary scores are retained.
The public numeric records, MLPL analysis, source/prompt hashes and readable
Org/HTML report are the handoff; private raw evidence remains ignored.

Step 015, `book-methods-literate-publication`, delivers the requested article
organized around the book methods, MLPL/Rust implementation and measured
results. Its five offline blocks demonstrate production sampling,
extraction/voting/verification, numeric result replay, group advantages and
an analytic-checked gradient update. The publication excludes development
history and preserves all underlying experimental evidence. The gate covers
185 native tests, 47 exact tangles and these five reproducible blocks.

Step 016, `book-scale-readiness`, profiles native and sampling costs, closes
targeted grading gaps and freezes a resumable full 500-case protocol before
paying that inference cost. Core resident-copy work is deferred in the queue.
Provider publication still awaits sibling-write authorization; native
language-model training needs separate acceptance.

Step 016 delivers the dogfooding performance evidence and native selection
adapter. The fixed full-vocabulary sampler costs 96.29ms in MLPL versus 12.18ms
through the Rust extension; four matched 128-token sampled pairs improve from
14.247s to 6.000s (2.3745x) with exact token equality. Two greedy pairs also
match. Three adapter tests and one authored grading-coverage test bring the
fixture total to 189. Six report blocks and 54 exact tangles cover the new
methods, profiler drivers and MLPL numeric analysis. CUDA stage measurements
retain substantial unexplained stalls; generic driver wall time is not
misreported as kernel occupancy. Core/library/extension work orders record
ownership and acceptance rather than blaming implementation language.

The full500 method/accounting protocol is frozen in
[book-full500-protocol.md](book-full500-protocol.md), but execution has not
started and its resumable runner is not yet implemented. The following work
combines CUDA attribution, long-context acceptance and the tested
resumable runner before committing to full500 execution cost. Native training
and provider publication remain separate deliverables.

Step 017, `cuda-kernel-trace-acceptance`, adds Nsight kernel/driver and GPU
context-switch attribution. Forty-eight fixed decode windows average 57.21ms,
with 4.66ms summed kernel spans, 26.76ms driver launch APIs, 1.35ms allocation/
free APIs and 9.67ms device-to-host APIs (overlapping, not additive). No other
process context switch is observed during the kernel window. A model-free
Rust/Candle probe reproduces recurring stalls. Nonblocking-stream diagnostics
are not adopted. Raw traces and isolated diagnostic sources are hash-pinned;
numeric evidence, SQLite extraction and its offline fixture are published.

This focused diagnostic step was inserted before the broader runner step.
Step 018 retains remaining optimization experiments, crash-safe full500
implementation and pre-execution manifest/prompt pins. Inspection found that
MLPL atomic rename does not sync durable storage; E7 specifies the generic
persistence service and crash tests. Full500 has not started. Core resident
copy profiling is now step 019; native training remains a separate gate.

The step017 long-context acceptance also passes: a synthetic1024-token
prefill plus2048 sampled output tokens yields exact reference/native token
identity at context4096. Wall times275.170s and154.164s are one sequential
pair, not a quality result. The gate now includes55 exact tangles and the
SQLite trace fixture; native MLPL test count remains189.

Step 018 delivers the durable full500 runner and frozen preparation: 500 cases,
1000 prompt hashes and 2500 immutable request keys, with no benchmark generation.
Five journal tests and one timed-decoder test bring the native MLPL suite to
195; the literate source has 60 exact tangles. Native crash-boundary tests and
runner replay/interruption/error/duplicate/corruption acceptance pass. The
10-call authored CUDA smoke takes 30.9s with no backend errors (six short caps).
The isolated transport probe measures about 2.1x median improvement for a toy
captured graph, not a model speedup; pinned buffers do not reliably remove stalls.

Next: execute/resume the frozen full500 experiment, retaining all denominators
and reporting incomplete results honestly. Planning range 15.3–24.6h is an
estimate; the cumulative budget is 48h. Stable-cache CUDA graph work, native
package publication and language-model training remain separate deliverables.
