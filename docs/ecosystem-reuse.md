# Existing MLPL ecosystem: inspected and reusable

Reviewed on 2026-09-29 before choosing a Qwen3 CUDA integration. Siblings
were not modified. The two absent repositories were cloned for read-only
inspection under `/disk1/tmp/reasoning-tools/`; no user tools were replaced.

| Repository and inspected revision | Existing capability | Reuse and limit |
|---|---|---|
| sw-MLPL `6d7846605f27adbadaf17b662b2a984285ec15a3` | Candle/cudarc CUDA tensor, forward, train and model crates; `demos/lora_finetune_cuda.mlpl` | Reuse device dispatch and native autograd/Adam. Demo is a restricted head-only LoRA architecture, not a general pretrained Qwen3 trainer |
| demo-ml-utils `e6d285d1f9903468441feb006cc4c5ad622b9133` | Artifact handling, low-rank adaptation, fixed-weight ICL controls, distilled frozen-policy ICRL, native causal-model provider specification | Reuse acceptance contracts, ablations, fingerprints and provider boundary; Qwen recipes currently exit 77, so historical MLX training figures are not present CUDA acceptance |
| demo-mlpl-libraries `573938385a39c999d67b28004f6cbce030fc61ec` | result, text, JSONL, safetensors-header and checkpoint libraries; revision/hash-locked installer | Reuse pinned modules with prefix/compatibility review; no CUDA model implementation in this catalog |
| demo-extensions `4be5074b7c3673a278e186c803a67072c50547ff` | Typed-handle dynamic-library SDK, tokenizer, digest, HTTP and other providers | Reuse ABI and tokenizer; no CUDA causal-model provider in inspected packages |

## Concrete local checks

With our selected MLPL build `49c15b3e`, these upstream utility runners
passed without changes:

- `scripts/run-low-rank-adapter`: rank-one/rank-two contracts, frozen base,
  factor updates, merged/factorized parity and held-out loss.
- `scripts/run-icl-controls`: order, distractor, contradiction, truncation,
  empty-context, leakage, frozen-state and resource-exhaustion controls.
- `scripts/run-icrl-rollout`: held-out reward-context adaptation with zero
  deployment updates, parameter fingerprints and reward ablations.

The ICRL teaching policy obtains reward 3/regret 1 on its held-out bandit;
empty or reward-ablated context gives reward 1/regret 3. It is a small
history-conditioned policy, not a transformer or evidence of Qwen3 reasoning.
The measured checks confirm reusable mechanisms and controls, not LLM scale.
Local logs are under `out/review-utils-*.log`; commands are reproducible with
`MLPL=/disk1/tmp/reasoning-tools/build-49c15b3e/release/mlpl-repl` and the pinned
review checkout path. Source inspection: `docs/rust-native-model-training.md`,
`docs/held-out-icrl-rollout.md`, and `docs/low-rank-adapter.md` in demo-ml-utils.

## CUDA: existing code versus current usable build

The sw-MLPL CUDA foundation records successful device/autograd/Adam tests on
this GPU with CUDA 13.2, Candle 0.9.2 and cudarc 0.19.7. The current host's
`/opt/cuda/bin/nvcc --version` reports CUDA 13.4.59. Our prior R12 build
record rejects toolkit 13.4 in cudarc 0.19.7. Do not discard the existing
CUDA implementation or describe native autodiff as absent everywhere.

The adjacent release CLI identifies itself as 0.20.0, commit `6de73bbe`.
A fresh matrix probe with that binary returned the correct numbers but
explicitly warned that CUDA was not compiled in and fell back to CPU.
That is **not GPU acceptance**. Our current 0.22.0 fixture binary is also
CPU-only. The first implementation task is a compatible isolated CUDA
build and rerun of existing GPU tests, then Qwen3 operation/model coverage.
No toolkit install, dependency patch or CUDA rebuild was performed in this
review. Reported historical GPU results are distinguished from today's check.

## Reuse order

1. Revalidate the existing Candle/cudarc CUDA stack using a supported
   toolkit/dependency pair, without replacing stable tools.
2. Extend the existing provider contract from demo-ml-utils with a raw
   Qwen3-0.6B-Base mode, pinned local weights, token-level forward/cache and
   MLPL-controlled sampling. Preserve its coarse resident-model boundary;
   no per-weight serialization in the training loop.
3. Reuse libraries for artifacts/provenance and utilities for adaptation
   controls. Keep this repository's book-specific verifier and evaluation.
4. Put only missing native capabilities in an extension work order. Reuse
   native training machinery where suitable; prove Qwen3 gradients separately
   from the existing head-only LoRA demo.

Useful upstream entry points:
[CUDA foundation](https://github.com/sw-ml-study/sw-mlpl/blob/6d7846605f27adbadaf17b662b2a984285ec15a3/docs/saga-cuda-foundation.md),
[native provider contract](https://github.com/sw-ml-study/demo-ml-utils/blob/e6d285d1f9903468441feb006cc4c5ad622b9133/docs/rust-native-model-training.md),
[library catalog](https://github.com/sw-ml-study/demo-mlpl-libraries/blob/573938385a39c999d67b28004f6cbce030fc61ec/catalog/libraries.toml).
