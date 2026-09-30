# MLPL / Rust / CUDA base-model execution

The pinned Qwen3-0.6B-Base checkpoint runs locally through MLPL and a Rust
Candle CUDA dynamic library. MLPL controls prompts, token selection,
stopping, extraction, voting, grading and reporting. Weights and KV cache
remain in the native provider. There is no Python, Ollama or HTTP service in
this path, and no Qwen3 weight update has been performed here.

The [book-aligned experiment](book-author-protocol.md) and
[literate results report](reasoning-results.html) describe the current
comparison. Earlier authored examples below are fast development demos,
not a substitute for that comparison.

## Run on this host

```sh
export MLPL=/disk1/tmp/reasoning-tools/build-49c15b3e/release/mlpl-repl
just cuda-parity       # tiny independent forward/cache check
just cuda-real-parity  # opt-in real F64/F32/BF16 numerical comparison
just cuda-reasoning    # short authored water-tank demonstration
just book-author      # one-shot first-ten direct/CoT/three-vote experiment
just book-author-report # offline metrics from committed public records
```

GPU recipes require GPU access. `cuda-reasoning` accepts `CUDA_PROMPT` for
another raw prompt. It allows 512 new tokens, context 4096, BF16 weights,
greedy decoding, EOS 151643, seed 42 (unused), and a 180-second wall limit.
The frozen book run allows 2048 new tokens per call, fifty calls and a
three-hour job budget. It refuses to overwrite an existing attempt log.

There is no 32 GiB host-address-space cap in the native path. That older
limit bounded pure-MLPL CPU execution; it did not describe GPU VRAM.
Do not infer training-memory feasibility from an inference measurement.

## Independently checked numerical evidence

| Test | Observed result |
|---|---|
| Tiny GPU F32 vs MLPL F64 reference | maximum absolute logit difference 0.00000193084; threshold 0.00001 |
| Tiny cached vs full GPU forward | maximum difference 0.00000190735 |
| Closed native model handle | rejected |
| Real checkpoint CUDA F32 vs independent MLPL F64 | maximum 0.00000711613; RMS 0.00000145842 |
| Real checkpoint CUDA BF16 vs MLPL F64 | maximum 0.367154; RMS 0.0902633 |
| Real BF16 cached vs full prompt | maximum 0.3125 |
| Real greedy argmax, every tested precision path | token 12095, “Paris” |

The real test compares all 151,936 last-position logits on the five-token
prompt “The capital of France is”. Independent MLPL F64 execution streams
one layer at a time and takes 134.922 seconds. This avoids whole-model
copying for validation. It is one real-prompt acceptance test, not proof of
identical long generations or sampling streams. BF16 thresholds are 0.5;
F32 threshold is 0.005. See [the recorded log](results/cuda-real-precision-v2.txt).
Tokenizer checks pass six fixture cases, eight real cases and NFC.

## Fast authored demonstrations

The [water-tank transcript](results/cuda-tank-v1.txt) contains valid steps
120−35=85 and 85+18=103, followed by the correct boxed answer. Loading took
6.529 seconds and 185 generated tokens took 8.376 seconds. The separate
[multiplication transcript](results/cuda-multiplication-v1.txt) answers 17×23
correctly but contains an invalid explanatory step. Both are retained:
answer correctness and validity of the explanation are separate checks.

Short greedy generation measured 22–24 tokens/second. Sampled generation
has extra vocabulary processing in MLPL; a 64-token sampling smoke took
7.188 seconds. Long responses in the book experiment can take minutes.
Use the measured method-specific table in the report, not a short-prompt
extrapolation. PyTorch already calls native CUDA kernels; no 100× speedup
is claimed.

## Provider boundary and pinned builds

The provider exports `open`, `forward`, `reset`, `close`, and `info`, each
accepting one record. `forward({handle, ids})` extends resident KV state and
returns last-position logits. Reset before an unrelated prompt. Native
success arrays and Result errors are adapted to MLPL's callback contract;
handles cross it inside records. Each model owns one sequence state.
`info` explicitly reports training unsupported.

| Version | Used for | Native artifact |
|---|---|---|
| v1 | Recorded authored demonstrations and tiny parity | `/disk1/tmp/reasoning-tools/qwen3-cuda-provider/target/release/libmlpl_qwen3_cuda_prototype.so` |
| v2 / 0.2.0 | Real numerical acceptance and book-author-v2 | `/disk1/tmp/reasoning-tools/qwen3-cuda-provider-v2/native/libmlpl_qwen3_cuda_prototype.so` |

The v2 artifact SHA-256 is
`da6811a7eef300843b0e29c14623d45c3047e946667721d43ccd99a334a708bd`.
Its source directory is `/disk1/tmp/reasoning-tools/qwen3-cuda-provider-v2`,
and the portable source archive is
`/disk1/tmp/reasoning-tools/qwen3-cuda-provider-v2-source.tar.gz`.
V2 pins the SDK at git revision `4be5074b7c3673a278e186c803a67072c50547ff`
and confines canonical model-file paths to the supplied root. V1 remains
intact for its historical hash pins. No Rust was added to this consumer tree.

Dependencies are Candle core/nn/transformers 0.11.0 (CUDA enabled on all
three) and cudarc 0.19.10 with CUDA 13.4 support. Host: toolkit 13.4.59,
driver 615.71.09, sm_120, RTX 5060 Ti 16 GiB. Build from the external source:

```sh
CUDA_ROOT=/opt/cuda CUDA_PATH=/opt/cuda CUDA_COMPUTE_CAP=120 \
PATH=/opt/cuda/bin:$PATH cargo build --release --locked --offline
```

Offline building requires the pinned dependencies already in the Cargo
cache. The source/build and binary hashes are recorded in the
[backend execution manifest](results/book-cuda-v1-execution.json); the
[current experiment manifest](results/book-author-v2-execution.json) pins
that backend and its own MLPL sources/prompts. Both were committed before
their respective generation runs. Raw questions and responses remain ignored.

The separate unchanged sw-MLPL 49c15b3e CUDA CLI also passes a matrix smoke
using `CUDARC_CUDA_VERSION=13020` with its older cudarc bindings. That is a
local build workaround, not comprehensive GPU training acceptance. The
extension owns its CUDA context and can be called from the pinned CPU CLI.

## Remaining delivery and learning work

The provider is usable locally but is not yet a released extension dependency.
Its source/build handoff is concrete; publishing into the sibling repository
awaits authorization under the read-only sibling policy. A public facade and
expanded negative/lifecycle test matrix remain delivery work. See [E6](demo-extensions-requests.md).

Before full-scale evaluation, profile forward execution, vocabulary transfer
and sampling separately, then offload the dominant cost with parity checks.
Keep MLPL as the reference for the method. Native language-model training
requires independent loss/backward/update/save/reload acceptance; inference
success cannot stand in for it.
