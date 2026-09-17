# How the base model becomes a reasoning model

A plain-language account of what this project trains, on what data, and
through which mechanisms, with pointers to the components that implement
each part. Numbers quoted are the published results the plan compares
against; this repository's own measurements are recorded as they happen.

## The starting point

The base model is Qwen3-0.6B-Base: a 28-layer decoder that predicts the
next token and nothing else. It has read a great deal of mathematics during
pretraining, so it can often produce a correct answer, but it has no habit
of working before answering. Prompted with a competition problem it tends
to emit a short guess, and the published greedy accuracy on MATH-500 is
about 15%.

"Reasoning" is used here in the book's operational sense: the model emits
intermediate steps before its final answer, visibly or inside think tags.
A reasoning model is one that has been prompted or trained to do that
reliably enough to raise its accuracy on problems whose answers can be
checked.

## What is in the training data

Only math problems with checkable answers. Two datasets:

| Dataset | Records | Fields used | Used by |
|---|---|---|---|
| MATH training split minus MATH-500 | 12,000 | `problem`, `answer` | reinforcement learning (Saga 5) |
| Teacher traces for the same problems | about 6,700 after a 2,048-token length filter | `problem`, teacher think block, teacher final answer | distillation (Saga 6) |
| MATH-500 | 500 | `problem`, `answer` | evaluation only, never training |

The reference answer is a short expression such as `\frac{3}{4}` or a
tuple. The worked solutions in the training file are not used for
reinforcement learning at all: the only training signal there is whether
the model's own boxed answer verifies against the reference. There are no
human preference labels, no reward model, and no chat data. The reasoning
tokenizer's chat template and think tags are the only "instruction-style"
structure, and they appear only in the distillation and format-reward
variants.

## Three mechanisms

The book, and this project, apply three distinct techniques. Each is a
saga, and each is measurable on its own because the verifier and the
evaluation harness (Saga 1) exist before any of them.

### 1. Elicit reasoning at inference time (no training)

Nothing in the weights changes. The model is made to reason by how it is
asked and how its outputs are combined:

- A prompt suffix asks for step-by-step work. The base model complies
  often enough that this alone roughly doubles accuracy.
- Sampled decoding (temperature scaling, then nucleus filtering that keeps
  every token whose cumulative mass before it is below p) produces diverse
  candidate solutions instead of one greedy guess.
- Self-consistency samples N answers, extracts each boxed result, and
  takes the majority; ties are reported, then broken by first occurrence
  or by a score.
- Self-refinement scores a draft (a rule that rewards a boxed answer and
  brevity, or the model's own mean answer log-probability), asks the model
  to critique it, asks for a revision, and keeps the revision only if its
  score does not fall.

Published effect on the base model: chain-of-thought about 41%,
self-consistency with chain-of-thought at N = 10 about 52%. Reasoning here
is elicited and searched for, not learned.

Components: `lib/generate/` (sampling), `lib/scaling/` (voting, scoring,
refinement), Saga 4.

### 2. Learn reasoning from a verifier (GRPO)

Group Relative Policy Optimization is reinforcement learning with a
verifiable reward and no value network. One training step, for one
problem:

1. **Rollouts.** Sample G answers (4 to 8) from the current model with the
   prompt, temperature 0.8, nucleus 0.9, up to 512 new tokens, using the
   KV cache. The end-of-text token is kept in the sequence so the model
   does not unlearn stopping.
2. **Reward.** For each answer, the verifier extracts the last boxed
   expression, normalizes the LaTeX, and checks equivalence to the
   reference. Reward is 1 if the answer is boxed and correct, else 0. An
   unboxed correct answer earns nothing, which is the implicit format
   constraint.
3. **Advantages.** Subtract the group's mean reward from each reward and
   divide by the group's standard deviation plus a small epsilon. A group
   in which every answer agrees yields zero advantages and no gradient;
   the learning signal comes entirely from problems the model sometimes
   solves and sometimes does not.
4. **Sequence log-probability.** Run each answer back through the model
   with gradients enabled and sum the log-probabilities of the generated
   tokens only; prompt positions are masked. This is a sum, not a mean, so
   longer answers carry larger magnitudes.
5. **Loss.** Minus the mean over the group of advantage times sequence
   log-probability. The gradient raises the probability of every token in
   above-average answers and lowers it in below-average ones. The model is
   never shown a good step; longer and more careful answers simply verify
   more often, and response length grows on its own during training.
6. **Update.** Clip the gradient norm to 1 and take an Adam step at
   learning rate 1e-5. Move to the next problem.

Published result: after 50 such steps with G = 8, about 47% on MATH-500,
with average response length rising from about 80 to about 590 tokens.

Why it goes wrong, and the stabilizers the plan implements after the plain
objective works:

- **Drift and collapse.** Long runs with the plain objective peak early
  and decline. A clipped probability ratio between the current model and a
  snapshot taken before the rollouts (PPO-style; the book uses a very wide
  clip) bounds each update.
- **KL to the starting weights.** A penalty on the summed log-probability
  gap against a frozen copy of the initial model. The book shows that with
  a coefficient of 0.02 it can collapse training entirely, because the
  surrogate is not length-normalized and rollouts are off-policy; later
  runs disable it.
- **Format reward.** An extra reward for a well-ordered think block
  teaches the tag habit but is easily gamed (the model emits the tags and
  shortens its work); weighting it down or making it conditional on
  correctness fixes that.
- **Diagnostics.** Reward mean, response length, advantage standard
  deviation (zero means no signal), next-token entropy averaged over
  answer positions (near zero means collapse to determinism, very high
  means gibberish), and periodic evaluation accuracy.

Components: `lib/rl/` (rewards, advantages, log-probabilities, losses,
metrics, training loop), `lib/verify/` and `lib/eval/` (the reward
signal), Saga 5.

### 3. Copy reasoning from a teacher (distillation)

Supervised fine-tuning on a stronger model's traces:

1. Build each example as the chat-wrapped prompt, then the teacher's think
   block and final answer, then the end-of-turn token; record where the
   prompt ends.
2. Drop examples longer than 2,048 tokens; shuffle with a fixed seed; hold
   out 25 for validation. No correctness filtering is applied.
3. Loss is next-token cross-entropy over the answer tokens only (prompt
   positions excluded), which equals minus the sequence log-probability
   divided by the answer length.
4. Train for two to three epochs at learning rate 5e-6 to 1e-5, batch size
   one, gradient clipping 1, checkpoint per epoch.

The student copies the shape of the teacher's reasoning instead of
discovering it. Published results after three epochs: about 34% with
DeepSeek-R1 traces and about 44% with Qwen3-235B traces, the same-family
teacher working better.

Components: `lib/distill/` (dataset build, masked loss, training loop),
optional local teacher generation through `llm_call` to an Ollama server,
Saga 6.

## The parts that exist only to make those possible

| Part | Why it is needed | Home |
|---|---|---|
| Verifier | turns free text into a 0/1 reward and an accuracy number | `lib/verify/`, Saga 1 |
| Evaluation harness | runs any responder over MATH-500 slices with provenance | `lib/eval/`, Saga 1 |
| Tokenizer | text to ids and back; control tokens; chat templates | MLPL reference in `lib/tokenizer/`, production encoder as an extension, Saga 2 |
| Safetensors decoder | bf16 weights into `param` leaves | `lib/safetensors/`, Saga 3 |
| Qwen3 forward pass | RMSNorm, RoPE, grouped-query attention, SwiGLU, tied head, written as array functions so `grad` flows through them | `lib/qwen3/`, Saga 3 |
| KV cache | makes a 512-token rollout affordable | `lib/generate/`, Saga 3 |

In this repository every one of those is MLPL source; the interpreter
supplies matrix products, softmax, autograd, and byte I/O. The ladder in
[`architecture.md`](architecture.md) proves each mechanism on a tiny model
with exact numbers before the real model is touched, because the CPU
interpreter's measured throughput makes real-model runs bounded and
opt-in until an MLX build exists.

## Reading order

[`book-map.md`](book-map.md) maps chapters to components with the
published hyperparameters; [`verifier-contract.md`](verifier-contract.md)
specifies the reward function; [`plan.md`](plan.md) orders the work;
[`sw-mlpl-blockers.md`](sw-mlpl-blockers.md) records what the language
can and cannot do today.
