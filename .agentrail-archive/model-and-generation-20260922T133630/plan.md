# Reasoning from scratch in sw-MLPL: delivery plan

## Outcome

Re-implement the full method sequence of *Build a Reasoning Model (From
Scratch)* (Raschka, Manning 2026) in the sw-MLPL language: generate text with
the pretrained Qwen3-0.6B base model, verify math answers, evaluate on
MATH-500, improve accuracy with inference-time scaling, train with GRPO, and
distill from a stronger teacher. No Python and no external ML library is
used at any point. The interpreter supplies generic array, autograd, byte,
JSON, and process primitives; every reasoning-specific algorithm is `.mlpl`
source in this repository, tested with mlplunit, and honest about what runs
on a toy model, what runs on the real model, and what is blocked upstream.

## Ground rules

- The book and its Apache-2.0 companion code are references only. No code
  or prose is copied; see [`licensing.md`](licensing.md). The project stays
  MIT, identical to its peers.
- Sibling repositories (`../sw-mlpl`, `../demo-ml-utils`,
  `../demo-mlpl-libraries`) are read-only. Upstream gaps go to
  [`sw-mlpl-blockers.md`](sw-mlpl-blockers.md) with probes.
- `just check` is the precommit gate and runs on committed fixtures only.
  Downloads, real-model inference, and training are opt-in recipes.
- Work follows Agentrail: one saga at a time, one step per session,
  durable `.agentrail/` state committed with the code.

## Evidence and current constraints (measured 2026-09-16)

- Interpreter: `mlpl-repl 0.22.0`, commit `1b4d29e5`, at
  `../sw-mlpl/target/release/mlpl-repl`; runner `mlplunit` at
  `~/github/softwarewrighter/mlplunit/bin/mlplunit`. The foundation smoke
  test and canonical style check pass through the peer scripts.
- Machine: Apple M1 Max, 10 cores, 64 GB unified memory.
- Model: Qwen3-0.6B-Base, Apache-2.0, `model.safetensors` 1.19 GB bf16,
  `tokenizer.json` 7.0 MB, tied embeddings, 28 layers, 16/8 heads, head
  dimension 128. In f64 arrays the weights occupy about 4.8 GB.
- Autograd probes: `exp`, `log`, `sigmoid`, `mean`, axis reductions,
  `gather_rows`, `take`, axis `concat`, `reshape`, rank-2 `transpose`, and
  rank-2 `matmul` differentiate; `sqrt`, `pow`, `transpose_axes`, rank-3
  `matmul`, and axis `softmax` do not. A `param` leaf reassigned to a data
  array still receives gradients, so pretrained weights can be leaves.
- Tokenizer import, regular expressions, bf16 decoding, gradient clipping,
  weight decay, JSON arrays of objects, and HTTP have no builtins; each has a
  documented MLPL workaround (byte-level BPE in MLPL, hand-written scanners,
  vectorized bit decoding, a hand-written Adam, JSONL input, curl recipes).
- Single-operation timings (a 1024x3072 matrix-vector product in 11.7 ms,
  the 151,936-row output head in about 0.6 s) extrapolate to seconds per
  generated token on the f64 CPU interpreter. The MLX backend is not compiled
  into the current binary and dispatches only nineteen operations. Real-model
  evaluation and training therefore depend on measurements in Saga 3 and
  Saga 5 and on upstream work; every algorithm is proven on tiny models
  first.
- The reference implementation reports about 15% MATH-500 accuracy for the
  base model, about 41% with a chain-of-thought suffix, about 47% after 50
  GRPO steps, and about 34% to 44% after distillation. These are targets
  for comparison, not requirements.

## Architecture rule

```text
reasoning-from-scratch (.mlpl semantics, tests, probes, docs)
          |
          +-- reusable domain-neutral helpers ----> demo-mlpl-libraries
          |   (vendored back by pinned revision)
          +-- binary-format readers already proven -> demo-ml-utils
          |   (vendored by pinned revision, not copied ad hoc)
          `-- proven language-wide blocker --------> sw-mlpl (request only)
```

Details: [`architecture.md`](architecture.md). Chapter mapping:
[`book-map.md`](book-map.md).

## Saga 1: foundation and verifier (no model required)

1. `foundation` (done in the planning session): license and README layout
   matching peers, Agentrail briefing and repository rules, architecture,
   book map, verifier contract, data and licensing policy, capability
   ledger, thin `just check` gate, toolchain smoke test.
2. `capability-probes`: executable probes under `probes/` with a declared
   expected-result table, run by `just capabilities` and by the gate, that
   pin the autograd gaps, the `reinterpret` dtype list, `parse_json` time
   and memory on a 7 MB synthetic document, and the interpreter build
   commit. Update the ledger from measurements only.
3. `math-data-loader`: JSONL loading of MATH-style records with parse
   budgets (arrays of objects are rejected by `parse_json`, so JSON arrays
   are converted to JSONL by the fetch recipe), schema validation, and a five-problem hand-authored
   fixture; `just fetch-math500` recipe that prints the license and checks
   the byte size; loader tests.
4. `boxed-extraction-and-normalization`: `lib/text/` scanners (find, brace
   matching, number recognition, character classes) and the ordered
   normalization pipeline from the verifier contract; tests per rule.
5. `expression-equivalence`: bounded expression parser and evaluator with
   exact rationals and float fallback, tuple splitting, `grade`; every
   acceptance category in the contract; opt-in MATH-500 self-grading
   (500 of 500 references grade against themselves).
6. `evaluation-harness`: prompt renderer (own wording, boxed final answer),
   an evaluation loop over an abstract responder function, JSONL records,
   accuracy and timing report, CSV metrics helper; tested with a stub
   responder; README status update and saga closeout.

7. `literate-org-document`: an Emacs org-mode literate and reproducible
   document (`docs/reasoning.org`) built with `ob-mlpl`, following the
   `../demo-coding-agent/docs/mlplcode.org` model: prose before every
   block, `:tangle` targets that regenerate the committed sources byte for
   byte, a tangle check in the gate, and runnable self-contained examples.

Exit: `just check` proves a complete, tested verifier and harness with no
model, the literate document tangles back to the committed sources, and the
ledger lists measured, not assumed, gaps.

## Saga 2: tokenizer

Home decision (see [`feature-homes.md`](feature-homes.md)): the production
encoder is a Rust extension built in `../demo-extensions` from the work
order in [`demo-extensions-requests.md`](demo-extensions-requests.md); this repository
owns an MLPL reference implementation on a synthetic fixture, the chat
templates, and the parity tests.

1. `tokenizer-json-import`: bounded `parse_json` of `tokenizer.json`
   (vocab, merges, added tokens, pre-tokenizer description) with measured
   time and memory, a hand-built synthetic tokenizer fixture with expected
   encodings, and the `just fetch-model` recipe; publish the fixture and
   the extension work order.
2. `bpe-reference-in-mlpl`: readable byte-to-unicode mapping, a
   pre-tokenization scanner, merge ranking, encode and decode, and control
   token splitting, tested on the synthetic fixture only; this is the
   oracle, not the production path.
3. `chat-templates-and-eos`: the base and reasoning templates, think-tag
   ids, and the end-of-sequence rule in MLPL over integer id arrays,
   independent of which encoder produced them.
4. `extension-parity-and-throughput`: load the tokenizer extension with
   `load_extension` when present, run the reference suite through it, run
   the real-vocabulary golden set, encode the 12,000 training prompts under
   a stated time budget, and record the numbers; if the extension is not yet
   delivered, this step stops with an honest "unavailable" result and the
   evaluation sagas proceed on cached ids produced by the reference encoder
   for bounded slices.

Exit: any prompt in the corpus encodes and decodes deterministically, with
the MLPL reference and the extension agreeing on every golden.

## Saga 3: model loading and generation

Resequenced on 2026-09-18. The original order began with weight loading,
which is blocked: the `bf16` dtype shipped upstream but the bulk decode did
not, and `reinterpret` returns a byte view with no length and no arithmetic,
so a 155-million-value tensor would need 155 million scalar reads. That is
filed as request R11. Everything else in this saga is unblocked, so the
forward pass and generation now come first, proven on a tiny configuration
with synthetic weights; the real model is loaded last.

A second measurement shapes every step: element access copies the container,
costing 0.97 ms on a million-element array, while whole-array arithmetic
stays fast at 1.28 ms for a `[1,1000] x [1000,1000]` product. The forward
pass is therefore written entirely in whole-array operations, and the one
place that cannot avoid indexing, per-head attention slicing, is exactly
what the missing batched `matmul` of R3 would remove.

1. `qwen3-forward-tiny`: RMSNorm, split-halves RoPE, grouped-query attention
   with QK-norm and causal masking, SwiGLU, the residual block, and the full
   forward at a tiny configuration with seeded synthetic weights. Property
   tests rather than golden numbers: normalization invariants, RoPE
   preserving vector norms, a prefix's logits unchanged when the sequence
   grows, attention rows summing to one, and shape agreement throughout.
2. `kv-cache-generation`: a per-layer key and value cache as an MLPL record,
   prefill then one token per step, equality with full recomputation, greedy
   decoding with a stop id and a token budget, and tokens per second.
3. `safetensors-header`: vendor `safetensors-header` from
   `../demo-mlpl-libraries` by pinned revision, parse the real file's header
   and tensor directory, validate dtypes, shapes, and offsets, map Hugging
   Face names, and handle tied embeddings. Header only; no tensor data.
4. `bf16-tensor-decode`: gated on R11. With `unpack` available, decode named
   tensors and check one against the vectorized MLPL decode. Without it,
   stop with an honest unavailable result and choose between waiting for
   core and requesting the contingent native reader, item E3.
5. `real-model-smoke`: opt-in. Move the fetch scripts onto the extension's
   checksum-verified download, load the weights, record load time, resident
   memory, and tokens per second against the book's CPU yardsticks.
6. `math500-baseline`: opt-in. Run the harness over a bounded slice, then
   the full set if throughput allows, with full provenance.

Exit: the forward pass and generation are proven exactly on a tiny model;
the real model is either measured end to end or blocked with a precise,
filed request.

## Saga 4: inference-time scaling

1. `sampling-primitives`: temperature scaling, nucleus filter with the
   "keep the token that crosses p" rule and renormalization, seeded
   categorical draw, sampled decoding; goldens on three- and ten-token
   distributions.
2. `cot-and-self-consistency`: prompt suffix, N seeded samples, majority
   vote on extracted short answers, tie reporting, first-occurrence tie
   break, early stop at a certain majority; tests with stub responders.
3. `scoring`: per-token probabilities and log-probabilities, mean answer
   log-probability, next-token entropy, heuristic score; goldens.
4. `self-refinement`: critique and revision prompt builders in this
   project's words, the accept-if-not-worse loop, best-of-N; tests with
   stub responders and scorers.
5. `scaling-report` (opt-in recipes): bounded MATH-500 runs for each method
   and a results table beside the published one.

Exit: every chapter 4 and 5 method is a tested MLPL function over the
generation layer.

## Saga 5: reinforcement learning with GRPO

1. `rl-math-on-toy`: rewards (boxed-only verification), group advantages
   with unbiased standard deviation and epsilon, summed sequence
   log-probability with prompt masking, policy loss, clipped objective,
   KL surrogate, entropy, format reward for ordered think tags, moving
   average; goldens for each (including the advantage of `[1, 1, 0, 0]`
   and the clipped-objective table).
2. `tiny-policy-grpo`: a small array language model with `param` leaves
   trained by GRPO on a synthetic verifiable task (for example, answer a
   two-digit sum in a box) until reward rises; establishes the training
   loop, seeding, CSV metrics, checkpoints via `to_native`, and the
   gradient-clipping workaround or its upstream request.
3. `real-model-gradient-feasibility` (opt-in): one summed log-probability
   with `grad` through the 0.6B forward for a short rollout; measure tape
   memory and time; if infeasible, implement low-rank adapters on the
   attention projections as the trainable leaves and measure again.
4. `grpo-training-run` (opt-in): bounded steps on the training split with
   G rollouts, checkpoints, metrics, and a MATH-500 slice evaluation.
5. `grpo-stabilizers`: old-policy snapshot with the clipped ratio, KL
   against a frozen reference, format reward with conditional weighting,
   metric plots as SVG; toy-model tests plus opt-in real runs.

Exit: GRPO is fully expressed and tested on a toy; the real-model path is
either measured working or blocked with a precise upstream request.

## Saga 6: distillation

1. `distill-dataset`: teacher traces either downloaded (license verified
   first) or generated locally through `llm_call` against an Ollama server
   (the book's own companion includes an Ollama generation path), formatted
   with think tags, tokenized with the reasoning template, filtered by
   length, split with a fixed seed; tests on a fixture.
2. `sft-loss-and-loop`: answer-only cross-entropy with prompt positions
   excluded, validation loss, training loop with seeded shuffling,
   per-epoch checkpoints, CSV metrics; tests on the tiny model.
3. `distill-run` (opt-in): bounded training on the real model or adapters
   and MATH-500 slice evaluation; results table.

Exit: distillation is a tested MLPL pipeline with a measured real-model
attempt.

## Saga 7: closeout

Consolidate results tables, finalize the capability ledger and upstream
request queue, promote any domain-neutral helpers (text scanners,
expression evaluator, safetensors reader) as a handoff to
`../demo-mlpl-libraries`, and update the README status.

## Cross-cutting gates

- Every executable behavior starts with native mlplunit coverage and a
  focused probe when it touches an unmeasured capability.
- Every `.mlpl` file has a module comment, every user function has a
  first-body docstring, and canonical formatting is checked before commit.
- Fixtures are tiny, synthetic, and authored here; downloads are opt-in.
- Documentation, catalog, ledger, and results change with the behavior they
  describe, in the same step. Once `docs/reasoning.org` exists, every saga
  that adds a library extends it and keeps `just check`'s tangle comparison
  passing, so the literate document can never describe code that no longer
  exists.
- Sibling repositories remain read-only; their work is a handoff.

## Risks and how the plan absorbs them

| Risk | Mitigation |
|---|---|
| Interpreter too slow for 0.6B inference (planning extrapolation: seconds per token) | measured in saga 3 step 4 before evaluation; bounded slices instead of full MATH-500 passes; ladder keeps every later saga testable on the tiny model; MLX build and dispatch-coverage request filed with numbers |
| Autograd tape for 28 unrolled blocks exceeds memory | saga 5 step 3 measures; adapters shrink trainable leaves; toy-model tests keep the algorithms verified |
| bf16 decode unsupported by `reinterpret` | vectorized integer decode is expressible; request filed |
| Tokenizer divergence from the published pre-tokenizer | the production encoder is a Rust extension in `../demo-extensions` using the file's own pattern; the MLPL reference is checked against it on goldens |
| Symbolic equivalence without a computer-algebra system | bounded evaluator with exact rationals; divergences pinned by tests |
| Teacher-trace license unknown | local Ollama generation is the primary path |

## Non-goals

- Pretraining, tokenizer training, or a chat interface.
- Batched generation before single-sequence throughput is measured.
- Writing Rust here or modifying any sibling repository; extensions are
  requested from `../demo-extensions` through work orders.
- Reproducing the book's full 500-step training runs; bounded runs with
  full provenance are the deliverable.
