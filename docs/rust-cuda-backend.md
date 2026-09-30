# Rust CUDA backend for the book reproduction

## Required architecture

User clarification, 2026-09-29: replace Python orchestration with sw-MLPL
and use Rust CUDA-related ML crates. Ollama is not the target backend.
Existing Ollama measurements remain historical external-baseline evidence;
there is no new Ollama work in the reproduction plan.

| Book role | This project's target |
|---|---|
| Python experiment/model-method code | MLPL libraries and Org/Babel drivers |
| PyTorch tensor execution and device storage | Rust ML extension with CUDA kernels and resident tensors |
| Pretrained starting checkpoint | The pinned Qwen3-0.6B-Base safetensors, not post-trained Qwen3 or 8B |
| Generation and inference-time scaling | MLPL decoding/sampling/voting over native forward execution |
| Autograd/optimizer execution | Extension-owned graph and explicit backward/update API, with MLPL controlling the training loop |

This does not require an HTTP service, a chat template, GGUF conversion or
quantization. Start with BF16 weights and record compute/accumulation dtypes.
Any precision change is a separately declared experiment, not an implicit fix.
Keep the MLPL reference model and tiny goldens as an independent contract.

## Candidate and compatibility gate

**Reuse first:** the [ecosystem inspection](ecosystem-reuse.md) found an
existing Candle/cudarc implementation in sw-MLPL and the native causal-model
contract in demo-ml-utils. This is not a new framework selection or a
greenfield autodiff project. Revalidate those foundations and extend only
the missing Qwen3 provider surface. The current build issue is the recorded
CUDA 13.4 pairing (R12); existing demos were accepted with CUDA 13.2.

Existing foundation: [Candle](https://github.com/huggingface/candle), whose
upstream tree includes CUDA tensor support and a
[Qwen3 implementation](https://github.com/huggingface/candle/blob/main/candle-transformers/src/models/qwen3.rs).
[cudarc](https://github.com/chelsea0x3b/cudarc) is a lower-level CUDA binding
option, not a substitute for an ML/autograd framework on its own.
These sources do not establish a working current Qwen3 build. The extension
owner must pin crate revisions/Cargo.lock, license notices, CUDA toolkit,
driver and build architecture, and validate the RTX 5060 Ti before promising
inference or backward support. Do not copy the Python companion model.

Acceptance starts with a small CUDA allocation and matrix multiplication,
then a tiny authored Qwen3 model against the existing MLPL goldens. Check
cached versus uncached logits, tied embeddings, QK normalization, RoPE,
masking, EOS, and cache reset between unrelated samples. Real checkpoint
shape/loading acceptance comes next, followed by deterministic first-token
and short-generation evidence. CUDA must be explicit: no silent CPU fallback.

## Proposed extension boundary (E6; not yet delivered)

Use the existing SDK's typed generational handles, boxed in records at the
MLPL boundary where required by the host. The names below specify semantics,
not a released ABI:

- `open`: confined local model/config paths plus expected SHA-256 hashes,
  `cuda:0`, BF16 and a bounded context; returns a resident model handle and
  actual device/dtype/model metadata. No downloads.
- `session`: independent KV state and context bounds for that model.
- `prefill` / `decode`: input token ids and a session; return last-position
  logits and small timing/memory metadata. Avoid copying all weights or KV
  arrays into MLPL. Transfer one vocabulary vector initially; measure its
  cost before proposing any sampling offload.
- `reset` / `close`: clear sequence state and release resources; stale,
  wrong-type and double-closed handles fail predictably.
- Later training milestone: teacher-forced forward and masked token loss,
  trainable parameters, gradient reset, backward, gradient inspection,
  clipping/update and checkpoint save/load. The Rust graph owns its tensor
  lifetimes. MLPL chooses batches, rewards, advantages, loss coefficients
  and update schedule. An inference-only Qwen3 implementation does not
  automatically satisfy this milestone.

MLPL retains tokenizer integration, prompt formatting, explicit seeded
sampling, stopping rules, verifier, voting, reward calculations and analysis.
Use the existing hftok extension for the pinned tokenizer; validate base
prompt ids and EOS 151643, with no chat/thinking wrapper. No reference answer
may enter the generation API. A native training graph can be differentiated
without participating in the interpreter's existing `grad` tape; do not
imply automatic differentiation across an opaque foreign call.

## Delivery gates and current blocker

1. Extension owner ships a versioned CUDA artifact/facade, fixtures and
   build/provenance record, with no interpreter optimization prerequisite.
2. This repository validates lifecycle, tiny-model parity, pinned real
   weights/tokenizer and raw base generation. Only then pin the artifact
   hash and freeze an execution record before evaluation.
3. Run the disjoint [book reproduction pilot](book-reproduction-protocol.md).
   Publish all attempts and cost; never invent scores while the backend is
   unavailable.
4. Validate a tiny native gradient/update against an analytic golden,
   checkpoint round-trip and a decreasing authored loss before GRPO or
   distillation training. Then measure real-model training memory separately.

Current blocker: no general Qwen3 CUDA provider is present among the inspected
extension packages; sw-MLPL's CUDA foundation and limited LoRA path do exist.
demo-ml-utils' Qwen runners are explicitly gated on the missing native provider.
The base weights, tokenizer and method fixtures are present here. First reuse
and validate the existing CUDA stack; do not rebuild its autodiff from scratch.
Repository policy keeps siblings read-only
and Rust implementation in `demo-extensions`; E6 is its actionable work
order. No request was sent externally and no sibling was modified. This
is an integration dependency, not evidence of insufficient model capacity
or an established GPU-memory impossibility.
