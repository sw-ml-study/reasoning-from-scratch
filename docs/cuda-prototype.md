# Working MLPL / Rust / CUDA base-model prototype

On 2026-09-29, the pinned Qwen3-0.6B-Base checkpoint generated locally through
MLPL and a Rust Candle CUDA dynamic library. No HTTP service or Python is
involved. This is inference from pretrained base weights, not a model trained
by this project. No held-out book accuracy or speedup over PyTorch is claimed.

## Run on this host

```sh
MLPL=/disk1/tmp/reasoning-tools/build-49c15b3e/release/mlpl-repl just cuda-parity
MLPL=/disk1/tmp/reasoning-tools/build-49c15b3e/release/mlpl-repl just cuda-reasoning
```

The second command uses an authored water-tank problem. Set `CUDA_PROMPT` to
try another raw prompt. It allows 512 new tokens, context 4096, BF16 weights,
greedy decoding, EOS 151643, seed 42 (unused by greedy), and a 180-second wall
limit. It writes `out/cuda-reasoning.log`. The runner checks the provider hash
and fails on interpreter/native errors. The extension requires GPU access.
There is no 32 GiB host budget in this path: weights and KV cache stay native.

## Observed evidence

| Test | Result |
|---|---|
| Authored tiny model, GPU F32 versus MLPL F64 reference | maximum absolute logit difference 0.00000193084; tolerance 0.00001 |
| Cached versus full-sequence GPU logits | maximum absolute difference 0.00000190735 |
| Closed model handle | rejected |
| 17 × 23, step-by-step | correct boxed 391; explanation has an invalid place-value step |
| 120 − 35 + 18, word problem | correct boxed 103 and correct intermediate 85 |

The two complete transcripts are [multiplication](results/cuda-multiplication-v1.txt)
and [water tank](results/cuda-tank-v1.txt). The latter took 6.529 seconds to
load and 8.376 seconds to generate 185 tokens to EOS. Multiplication took
6.676 seconds to load and 8.801 seconds for 210 tokens. These are two authored
smokes, not a representative accuracy sample. During the multiplication run,
`nvidia-smi` showed 1,933 MiB device memory including desktop use; this is a
sample, not a peak-memory measurement. Reference parity uses a small positive
BF16 fixture converted to F32, not a real-model BF16/PyTorch equivalence test.

The rate observed is about 22–24 tokens/second. At that rate, 2,048 new tokens
would take about 86–93 seconds, before allowing for context-dependent slowdown.
The frozen 144-generation pilot could take tens of minutes to hours. Its
existing two-hour cap remains binding: an unfinished run must be reported as
incomplete. Hundreds of minutes in the book are entirely plausible for many
questions and repeated samples; native PyTorch already uses CUDA kernels.

## Boundary and reproducibility

`lib/cuda/cuda.mlpl` controls greedy decoding and stopping. The prototype
exports `open`, `forward`, `reset`, `close`, and `info`, each accepting one
record. `forward({handle, ids})` returns last-position logits and extends KV
state; reset before an unrelated prompt. Errors return native Result values.
Typed generational handles prevent use after close. Model files are local,
SHA-256 checked, and bounded to two GB. Each model owns one sequence state;
independent concurrent sessions are not delivered. Training is explicitly
unsupported by this prototype.

Prototype source is external at
`/disk1/tmp/reasoning-tools/qwen3-cuda-provider`; its source archive is
`/disk1/tmp/reasoning-tools/qwen3-cuda-provider-source.tar.gz`.
[Artifact hashes](results/cuda-prototype-v1-artifacts.sha256) cover source,
Cargo.lock, archive and binary. This local artifact is **not yet a released,
portable E6 dependency**: clean-clone users need its delivery in the extension
repository. Siblings were not modified and no Rust was added to this tree.
The source archive is a local handoff, not a downloadable publication asset.

Dependencies: Candle core/nn/transformers 0.11.0 with CUDA enabled on all three,
cudarc 0.19.10 (CUDA 13.4 support), and the read-only demo-extensions SDK at
4be5074b7c3673a278e186c803a67072c50547ff. Host toolkit 13.4.59, sm_120,
RTX 5060 Ti 16 GB. Build the external source with:

```sh
CUDA_ROOT=/opt/cuda CUDA_PATH=/opt/cuda CUDA_COMPUTE_CAP=120 \
PATH=/opt/cuda/bin:$PATH cargo build --release --locked --offline
```

The SDK path in Cargo.toml is host-specific. For a released artifact, E6 must
supply a portable dependency, public facade, root confinement, negative
lifecycle tests, and independent real-model/precision checks. The provider
currently validates absolute paths and hashes but does not implement a
separate approved-root confinement policy. No untrusted extension loading is
part of the demo.

The unchanged sw-MLPL 49c15b3e CUDA CLI also built in an isolated target with
`CUDARC_CUDA_VERSION=13020` and passed the matrix smoke without fallback.
That override selects its existing cudarc 0.19.7 bindings; it is a tested
local matrix workaround, not comprehensive training acceptance. The Qwen3
extension instead uses cudarc 0.19.10's actual 13.4 configuration and can run
from the existing CPU CLI because it owns device execution.

## Next acceptance

Pin a portable provider and real-model numerical/tokenizer evidence, then
commit the execution provenance and run the frozen direct/CoT/ten-sample
comparison. No selected book-pilot questions were generated in this step.
Measure paired gains and failure categories; do not tune on that held-out
selection. Training needs separate native loss/backward/update/save/reload
acceptance. Correct answers, valid explanations, and improved aggregate
accuracy are three different claims.
