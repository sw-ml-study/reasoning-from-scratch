# Book-to-component map

The book is *Build a Reasoning Model (From Scratch)* by Sebastian Raschka
(Manning, 2026). This page maps each chapter to the sw-MLPL components that
realize its method. It paraphrases; it does not reproduce the text. Numbers
are the book's published hyperparameters and result tables, recorded so the
project can compare its own measurements against them.

## Chapter 1: what "reasoning" means here

Reasoning is defined operationally: the model emits intermediate steps
before its final answer, visibly or inside think tags. Three families of
technique are layered on a conventionally pretrained model: inference-time
scaling (chapters 4 and 5), reinforcement learning with verifiable rewards
(chapters 6 and 7), and distillation (chapter 8). Everything starts from the
*base* Qwen3-0.6B checkpoint so that each technique's contribution is
measurable; the official reasoning variant is only a comparison point.

Component: none. This repository's non-goals match the book's: no
pretraining, no tokenizer training, no chat interface.

## Chapter 2: generating text with the pretrained model

Method: load the checkpoint and tokenizer, encode a prompt, run the
transformer, take the last position's logits, choose the argmax, append,
repeat until the end-of-text id or a token budget. A per-layer key/value
cache makes each step cost one position instead of the whole sequence.

| Component | Module |
|---|---|
| tokenizer.json import, byte-level BPE encode/decode, special tokens | `lib/tokenizer/` |
| safetensors header and bf16 tensor decoding, name mapping | `lib/safetensors/` |
| Qwen3 forward pass (RMSNorm, RoPE, GQA with QK-norm, SwiGLU, tied head) | `lib/qwen3/` |
| greedy loop, KV cache as an MLPL record, stop rules, timing stats | `lib/generate/` |

Reference speeds the book reports for the 0.6B model on an M4 CPU: about
5 tokens/s without a cache and about 28 tokens/s with one. Those are the
yardsticks for the interpreter feasibility measurement in saga 3.

## Chapter 3: evaluating with a math verifier

Method: a prompt template asks for the final result in a boxed expression;
the last boxed group is extracted (with a numeric fallback); the candidate
and the reference are normalized through an ordered list of LaTeX and
Unicode clean-ups; equivalence is exact string equality or symbolic
equality of the difference; tuples are compared part by part in order.
Evaluation runs over MATH-500 (500 problems with `problem`, `answer`,
`solution`, `level`, `subject`, `unique_id`) and writes one JSONL record
per problem.

| Component | Module |
|---|---|
| boxed extraction with brace matching, numeric fallback | `lib/verify/` |
| normalization pipeline | `lib/verify/` |
| bounded expression evaluator replacing the symbolic library | `lib/verify/` |
| MATH-500 loading, prompt rendering, evaluation loop, JSONL and accuracy | `lib/eval/` |

Published baselines (greedy, 2048 new tokens, full MATH-500): base model
about 15%, reasoning variant about 48% to 51%. The full contract is in
[`verifier-contract.md`](verifier-contract.md).

## Chapter 4: inference-time scaling by decoding

Method: a chain-of-thought suffix on the prompt; temperature scaling of the
logits before the softmax; nucleus (top-p) filtering that keeps every token
whose cumulative mass *before* it is below p (so the token that crosses p is
kept) and renormalizes; seeded multinomial sampling; self-consistency by
sampling N answers and taking the majority of the extracted short answers,
with ties reported rather than resolved (exercises add first-occurrence
tie-breaking and early stopping once a majority is certain).

| Component | Module |
|---|---|
| temperature, top-p filter, seeded categorical draw, sampled decoding | `lib/generate/` |
| chain-of-thought suffix, self-consistency vote, tie policy, early stop | `lib/scaling/` |

Published results on the base model (temperature 0.9, top-p 0.9): CoT
alone about 41%; self-consistency with CoT at N = 3 / 5 / 10 about 42% /
48% / 52%; sampling without voting does not help (about 18%).

## Chapter 5: inference-time scaling by self-refinement

Method: score a response either with a rule (bonus for a boxed answer,
smaller bonus for a bare number, plus a brevity term that decays with
character length) or with the model's own confidence (mean log-probability
of the answer tokens given the prompt); then iterate draft, critique,
revision for a fixed number of rounds, accepting a revision only when its
score does not fall.

| Component | Module |
|---|---|
| per-token probabilities and log-probabilities, mean answer log-prob | `lib/scaling/` |
| heuristic scorer, critique and revision prompt builders, refinement loop | `lib/scaling/` |

Published results: one round of refinement lifts the base model from 15% to
about 21% to 25% depending on the scorer; it helps the reasoning variant
more; it does not beat self-consistency on this task.

## Chapter 6: reinforcement learning with verifiable rewards (GRPO)

Method: for one training problem draw G rollouts with sampled decoding;
reward each 1 if its last boxed answer verifies and 0 otherwise; convert
rewards to group-relative advantages (subtract the group mean, divide by
the unbiased standard deviation plus a small epsilon); compute each
rollout's sequence log-probability as the *sum* of the generated tokens'
log-probabilities under the current weights; minimize the negative mean of
advantage times log-probability; step with Adam-style updates after
clipping the gradient norm to 1. Training data is the 12,000-problem MATH
split with MATH-500 removed, consumed one problem per step.

| Component | Module |
|---|---|
| rollout sampling that returns ids, prompt length, and text | `lib/rl/` |
| verifiable reward, advantages, sequence log-prob, policy loss | `lib/rl/` |
| training loop, CSV metrics, checkpoint save/load | `lib/rl/`, `lib/safetensors/` |

Published hyperparameters: G = 4 (chapter run) or 8 (published
checkpoints), 512 new tokens, temperature 0.8, top-p 0.9, learning rate
1e-5, 50 steps, epsilon 1e-4. Published result after 50 steps with G = 8:
about 47% on MATH-500.

## Chapter 7: making GRPO stable

Method: track reward mean, response length, advantage mean and standard
deviation, per-step entropy of the next-token distribution averaged over
answer positions, and periodic evaluation accuracy; add a PPO-style clipped
ratio between the current and a snapshot policy (the book uses a very wide
clip of 10); add a KL surrogate against a frozen reference (which the book
shows can collapse training at a coefficient of 0.02 and later disables);
add a format reward for a well-ordered think block, and show it can be
reward-hacked unless weighted down or made conditional on correctness.

| Component | Module |
|---|---|
| metrics, moving average, entropy | `lib/rl/` |
| old-policy snapshot, clipped objective, KL term, format reward | `lib/rl/` |
| plots from metrics CSV via `loss_curve` and `svg` | `lib/eval/` |

## Chapter 8: distillation

Method: build supervised examples from a stronger teacher's reasoning
traces (think block followed by the final answer), tokenized with the
reasoning tokenizer's chat template, filtered to at most 2,048 tokens,
shuffled with a fixed seed, with 25 held out; train the base weights with
answer-only cross-entropy (prompt positions excluded), learning rate 5e-6
to 1e-5, gradient clipping 1, two to three epochs, batch size one.

| Component | Module |
|---|---|
| dataset build, formatting, length filter, split | `lib/distill/` |
| answer-only loss, validation loss, training loop, checkpoints | `lib/distill/` |
| local teacher generation through `llm_call` to an Ollama server (optional) | `lib/distill/` |

Published results after three epochs: about 34% with DeepSeek-R1 traces,
about 44% with Qwen3-235B traces (same-family teacher works better).

## Appendices used

- C: the Qwen3 architecture and tokenizer wrapper (facts recorded in
  [`data-and-models.md`](data-and-models.md)).
- D: larger dense Qwen3 sizes share the code; only the config changes.
- E: batched generation with left padding and a key-padding mask; deferred
  here until single-sequence throughput is measured.
- F and G (other evaluation styles, chat interface): out of scope.

## Experiment-tool parity (2026-09-30)

The active [book demonstration](book-author-protocol.md) recreates experiment
behavior in MLPL, including dataset preparation and analysis. Prompt bytes
are experimental input data; implementation code remains independently
written. The earlier strict-box/EOS-only/tie-abstaining pilot is a separate,
incomplete baseline and must not be labeled the author's evaluation.
Remaining semantic gaps include general symbolic equivalence and framework
RNG identity. These must be measured or implemented rather than obscured by
changing the target to a custom reasoning demo.
