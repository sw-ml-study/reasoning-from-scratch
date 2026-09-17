# Architecture

## One sentence

Every algorithm in the reasoning pipeline (answer verification, tokenization,
the transformer forward pass, decoding, inference-time scaling, GRPO, and
distillation) is written in sw-MLPL; the interpreter, its Rust array kernels,
and its optional MLX backend supply only generic arithmetic, autograd, file
and byte I/O, JSON, and process control.

## Boundary rules

- **MLPL owns semantics.** Prompt rendering, boxed-answer extraction,
  normalization, equivalence, RMSNorm, RoPE, grouped-query attention, the
  KV cache, temperature and top-p sampling, majority voting, scoring,
  advantages, policy-gradient and KL terms, the distillation loss, and every
  training loop are `.mlpl` source in this repository.
- **The interpreter owns generic kernels.** `matmul`, `softmax`, `exp`,
  `log`, `grad`, `adam`, `read_bytes_packed`, `parse_json`, `to_native`,
  `write_atomic`, `random`, and `sample` are used as published. No Rust is
  written here and no native extension is added.
- **Siblings are read-only.** `../sw-mlpl`, `../demo-ml-utils`,
  `../demo-mlpl-libraries`, and the reference clone are never modified from
  this repository. Reusable MLPL helpers that already exist in
  `../demo-mlpl-libraries` or `../demo-ml-utils` (for example the bounded
  safetensors header reader) may be vendored by pinned revision with a hash
  lock, following the library contract those repositories publish.
- **Upstream work is requested, not simulated.** A gap in sw-MLPL is recorded
  in [`sw-mlpl-blockers.md`](sw-mlpl-blockers.md) with an executable probe,
  the required semantics, and acceptance cases. Until it ships, the affected
  step either uses a documented workaround or stops with an honest
  "unavailable" result.

## Component layers

```text
demos/          narrated, runnable lessons: one per book chapter
   |
lib/eval/       MATH data loading, evaluation harness, JSONL/CSV reports
lib/scaling/    chain-of-thought, self-consistency, scoring, self-refinement
lib/rl/         rollouts, rewards, advantages, GRPO loss, clip, KL, metrics
lib/distill/    dataset building, answer-only SFT loss, training loop
   |
lib/generate/   greedy and sampled decoding, KV-cache loop, stop rules
lib/qwen3/      config, RMSNorm, RoPE, GQA, SwiGLU, forward, LoRA hooks
lib/tokenizer/  tokenizer.json import, byte-level BPE, specials, chat template
lib/safetensors/ header parsing, bf16 decoding, name mapping, checkpoints
lib/verify/     boxed extraction, normalization, expression equivalence
lib/text/       string scanning helpers that stand in for regular expressions
   |
probes/         executable capability probes; expectations in catalog/probes.tsv
tests/          native mlplunit suites, one per library module
fixtures/       tiny synthetic tokenizer, safetensors, problem sets
```

Each `lib/<area>/` module has a unique `u:<area>_` function prefix, a
module-purpose comment, a first-expression docstring on every function,
canonical formatting, and a matching `tests/test_<area>*.mlpl` suite.

## The ladder principle

Every capability is proven three times before it is trusted:

1. **Exact on a toy.** Pure functions get golden inputs and outputs
   (advantages of `[1, 1, 0, 0]`, a three-token top-p filter, a two-layer
   model with sixteen-dimensional embeddings whose parameters are filled by
   a formula).
2. **Consistent with itself at scale.** Cached generation equals uncached
   generation; logits at a prefix do not change when the sequence grows; a
   decoded token sequence round-trips to its text.
3. **Plausible on the real model, measured.** Load time, resident memory,
   tokens per second, and accuracy on a bounded MATH-500 slice are recorded
   with the interpreter build commit before any claim is made.

Real-model runs are opt-in recipes and never part of `just check`.

## Two model representations

The book's model is a plain array program: embeddings, twenty-eight blocks,
a final norm, and the tied output projection. This repository implements it
as user functions over ordinary arrays with `param`-declared leaves, because
the Model DSL's `causal_attention` layer is single-head on the tape and has
no grouped-query, RoPE, or QK-norm variant, and because pretrained weights
must be assigned from decoded byte buffers rather than initialized by a
constructor. The KV cache is therefore a record of per-layer key and value
arrays managed in MLPL, not the DSL-only `gen_state` family.

If sw-MLPL later ships a native pretrained-decoder surface (tokenizer
import, safetensors model loading, LoRA, device-resident training), the
`lib/qwen3/` functions become the reference implementation that the native
path is checked against, not dead code.

## Determinism

Every sampled decision takes an explicit seed derived from
`(base_seed, sample_index)`. Evaluation records carry the interpreter build
commit, the model file hash, the prompt template version, and the decoding
parameters, so any accuracy figure in the documentation can be reproduced or
disowned.
