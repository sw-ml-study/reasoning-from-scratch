# CUDA stall attribution

The fixed-stage trace locates most elapsed time outside kernel execution.
It does **not** establish a particular driver bug or a model-quality problem.
Native selection's accepted 2.37× improvement is unchanged; this diagnostic
step adopts no additional optimization and changes no primary scores.

## Measurements

Nsight Systems CLI 2026.5.1.161, CUDA hardware tracing, the pinned v3 provider,
same BF16 checkpoint and RTX 5060 Ti as [the performance study](cuda-performance.md).
The workload is three prefills of 32, 256 and 1024 copies of token 785, each
followed by sixteen one-token decodes. SQLite analysis identifies the 48
decodes from the ordered 607744-byte device-to-host transfers, excluding
prefills and the final separate logit-vector request.

| Mean per decode window | ms |
|---|---:|
| Elapsed window between completed vocabulary-transfer API calls | 57.2118 |
| Sum of CUDA kernel spans | 4.6600 |
| CUDA driver launch APIs | 26.7575 |
| CUDA allocation/free APIs | 1.3482 |
| Device-to-host API | 9.6738 |
| Device-to-host GPU span | 9.0346 |

**These columns overlap; do not add them.** The windows include intervening
MLPL bookkeeping. Kernel spans describe elapsed kernel activity, not measured
SM occupancy or utilization. Tracing adds overhead; these numbers are not a
production-throughput estimate. The 814–817 kernels per decode occupy one traced
stream; kernel-span sums range from 3.06 to 6.69 ms. The device-to-host GPU
span reaches 44.21 ms for the same 594 KiB payload. Nested CUDA runtime launch
wrappers are excluded from the driver launch sum to avoid double counting.
[Per-decode numeric evidence](results/cuda-trace-v3-decodes.jsonl) is public.

The full kernel window runs from 7.915837 to 11.294230 seconds of the trace.
GPU context-switch records show one restored context, owned by the inference
process, from 6.469335 to 11.492951 seconds. There is **no observed switch to
another process during that window**. This does not support attributing these
stalls to desktop compute-context preemption. It does not exclude interference
on separate engines or establish a global absence of contention.
[Context records](results/cuda-trace-v3-contexts.json) preserve the observation.

A separate trace captured OS runtime calls and allocation events. CPU context
switches were unavailable with the host's `perf_event_paranoid=2`; Nsight
explicitly reports missing scheduling data. No host security policy, desktop
process, driver parameter or GPU clock setting was changed. Read-only telemetry
observed normal operating SM/memory clocks during inference, PCIe Gen2 x8,
and zero PCIe correctable/nonfatal error counters. This is not a controlled
clock or PCIe experiment and does not identify the root cause.

## Isolate the layer before changing it

A Rust/Candle diagnostic performs 800 affine kernels on 1024 F32 values, then
copies a checked 151936-entry F32 vector to the CPU. It reads no model, runs no
attention, and does not invoke MLPL. Across 512 iterations, forward spans reach
93.63 ms and transfer spans reach 36.48 ms. Eight forward stalls above 20 ms
occur after iteration 20. Stalls therefore recur beyond startup even without
MLPL or Qwen-specific code. Candle/cudarc allocation and driver operations
remain in this probe; it does not isolate the driver from those libraries.
[All 512 records](results/cuda-trace-driver-probe.jsonl) are retained.

An isolated explicit nonblocking-stream variant also retains long stalls:
maximum forward 144.83 ms. It is a diagnostic result, not an adopted speedup.
The unmatched mean timings are not used to claim a regression or improvement.
[Default-stream data](results/cuda-trace-v3-untraced.jsonl) and
[nonblocking-stream data](results/cuda-trace-v4-nonblocking.jsonl) are available.

The concrete next optimization experiments are:

1. Compare a reused pinned host buffer with the current pageable vocabulary
   transfer, using identical values and a standalone transfer probe.
2. Compare allocation-free repeated launches with the Candle probe, then
   evaluate graph replay or fewer/fused kernels. Preserve dtype, accumulation
   order and supplied-uniform token acceptance before adoption.
3. If delays persist in the minimal probe, gather permitted host scheduling
   and driver-stack evidence; distinguish busy waits from useful CPU work.
   Do not infer that a Python wrapper would avoid the same native path.

These are extension/provider work orders, not reasons to rewrite MLPL core.
The measured MLPL sampling/copy work orders remain independently valid.

## Reproduce and inspect

Download the Linux x86_64 CLI from [NVIDIA](https://developer.nvidia.com/nsight-systems/get-started)
and extract it into an isolated directory; do not replace installed tools.
The tested Debian archive was extracted with `ar` and `bsdtar` on Arch Linux.
Set `NSYS` to its `target-linux-x64/nsys` executable. GPU access is required.
NVIDIA documents the switches in its [user guide](https://docs.nvidia.com/nsight-systems/UserGuide/).

```sh
export MLPL=/disk1/tmp/reasoning-tools/build-49c15b3e/release/mlpl-repl
export NSYS=/disk1/tmp/reasoning-tools/nsight-cli/opt/nvidia/nsight-systems-cli/2026.5.1/target-linux-x64/nsys
just cuda-trace my-trace
scripts/analyze-cuda-trace out/my-trace.sqlite
just cuda-profile long
```

The trace recipe refuses existing output names. `analyze-cuda-trace` uses
SQLite, rejects a mismatched vocabulary-transfer count, and emits JSONL.
Its fixture test checks window mapping, kernel sums and exclusion of nested
runtime launch calls. This small test is part of `just check`; real GPU runs
are opt-in. SQLite CLI is required for this offline fixture and analysis.

Raw traces remain under ignored `out/`; [artifact hashes](results/cuda-trace-artifacts.sha256)
pin both Nsight captures, the isolated tool archive and diagnostic native
source/binaries. The v4 source archive is
`/disk1/tmp/reasoning-tools/qwen3-cuda-provider-v4-source.tar.gz`.
It contains the source, locked dependencies, build notes and model-free probe;
no Rust or external ML source is added to this consumer repository. The
published v3 provider binary and source archive remain unchanged.

## Full-benchmark durability requirement

The [full500 protocol](book-full500-protocol.md) requires durable started and
terminal records. Inspection of the pinned interpreter's `fs_atomic.rs`
shows `std::fs::write` followed by `std::fs::rename`, without file or directory
`sync_all`. This provides atomic visibility on the same filesystem, not a
power-loss durability guarantee. The runner needs a generic synchronized
journal/atomic-commit service (or an explicitly tested flush mechanism)
before claiming reboot-safe exactly-once accounting. See the extension
work order and capability ledger. Full500 execution has not started.

## Long-context selector acceptance

The pinned v3 reference/native pair produces exactly the same **2048 sampled
token IDs** after a synthetic 1024-token prefill, within context 4096. Seed 43,
temperature 0.9, top-p 0.9; EOS is deliberately disabled to exercise the full
output budget. Both calls stop at the token cap, not a deadline. Reference
wall time is 275.170s; native wall time 154.164s (1.78× for this single pair).
These are post-load decode-loop timings, including prefill, not a repeated
throughput study or a reasoning-accuracy test. CPU clocks, driver jitter and
execution order are uncontrolled; the two methods run sequentially.

The [two timing rows](results/cuda-long-acceptance.jsonl),
[acceptance summary](results/cuda-long-acceptance-summary.json) and
[source/raw-response hashes](results/cuda-long-acceptance.sha256) are retained.
The live MLPL driver asserts exact sequence equality. Earlier fixed-logit
probability/uniform tests and the 128-token repeated pairs remain separate
evidence; one long pair does not prove parity for every prompt and seed.
