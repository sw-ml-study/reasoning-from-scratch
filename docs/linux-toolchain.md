# Arch Linux toolchain and revalidation

Measured 2026-09-22. The original September 16–19 measurements were on an
Apple M1 Max; they are historical, not forecasts for this host.

| Item | Observed |
|---|---|
| Host | Arch Linux x86_64; Xeon W-2135, 6 cores / 12 threads; about 251 GiB RAM |
| GPU | NVIDIA GeForce RTX 5060 Ti; 16,311 MiB reported VRAM |
| Driver / toolkit | 615.71.09 / CUDA 13.4 |
| Selected interpreter | CPU release build, sw-MLPL 0.22.0 at `6d7846605f27adbadaf17b662b2a984285ec15a3` |
| Native test runner | mlplunit at `a06191f800f40a23ebc1890eada3f505b1adab60` |
| Formatter | canonical upstream `scripts/mlpl-fmt.sh` at the same interpreter revision; batch Emacs |

## Isolated tools

Do not overwrite the installed tools or alter the adjacent development
checkouts. On this host the installed interpreter is build `b3b1be48` and
the adjacent build is `6de73bbe`, both version 0.20.0. Neither is a suitable
substitute for the 0.22.0 interface used here. In particular the installed
CLI treats the `--source-dir` argument as a script path. The probe runner
now rejects this CLI before recording misleading capability failures.

The following isolated checkouts were prepared under `/disk1/tmp`:

```sh
git clone https://github.com/sw-ml-study/sw-mlpl.git /disk1/tmp/reasoning-tools/sw-mlpl
git -C /disk1/tmp/reasoning-tools/sw-mlpl checkout 6d7846605f27adbadaf17b662b2a984285ec15a3
git clone https://github.com/softwarewrighter/mlplunit.git /disk1/tmp/reasoning-tools/mlplunit
git -C /disk1/tmp/reasoning-tools/mlplunit checkout a06191f800f40a23ebc1890eada3f505b1adab60
```

From this repository's root, build and select tools explicitly:

```sh
cargo build --manifest-path /disk1/tmp/reasoning-tools/sw-mlpl/components/cli/Cargo.toml \
  --target-dir /disk1/tmp/reasoning-tools/sw-mlpl/components/cli/target \
  -p mlpl-repl --release --locked
export MLPL=/disk1/tmp/reasoning-tools/sw-mlpl/components/cli/target/release/mlpl-repl
export MLPLUNIT=/disk1/tmp/reasoning-tools/mlplunit/bin/mlplunit
export MLPLFMT=/disk1/tmp/reasoning-tools/sw-mlpl/scripts/mlpl-fmt.sh
just tools
just check
```

These exports last for the shell session; a fresh shell must repeat them.
No network or build is performed by `just check`. Tool discovery prefers
the explicit override, then PATH, then the documented adjacent checkout.
`MLPLFMT` must be an absolute executable path. Keep the formatter with its
upstream checkout because it loads that checkout's Emacs mode.

## Results and limits

All 24 capability outcomes match the catalog on this CPU build. R11 remains
missing (`unknown function: unpack`); R3 still rejects rank-3 matmul. R10
still fails the 100 ms acceptance budget: 100 large-record lookups took
3,235 ms and 100 large-list reads took about 603–611 ms. These are single
informational runs, not stable benchmark claims.

The `[1,1024] x [1024,3072]` product averaged 67.9 ms; the vocabulary head
product averaged 890.6 ms. Eight tiny cached steps took 21.69 ms versus
21.63 ms for recomputation; the maximum score difference was exactly zero.
No real weights, dataset, or model evaluation was downloaded or run here.
`/usr/bin/time` is absent, so peak RSS is unavailable and the probe report's
wall clock uses coarse seconds; the timings above come from MLPL's clock.

The first fresh-clone test run passed 80 of 83 tests: three checkpoint tests
failed because `out/fixtures/tiny-checkpoint.safetensors` did not exist.
`scripts/run-tests` now generates this deterministic fixture before invoking
mlplunit, including focused test runs. The fixture remains ignored.
After that fix, `just check` passed: 83 native tests, all 24 expected probe
outcomes, 16 tangled library sources, canonical formatting, provenance and
catalog checks, and both fixture demos. No downloaded artifacts are needed.

## CUDA is unavailable to this interpreter build

The GPU and driver work outside the execution sandbox. `nvidia-smi` inside
the sandbox failed to communicate with the driver; the unrestricted check
succeeded. That sandbox failure does not establish a driver fault.

An isolated build of the same revision with `--features cuda --locked`
failed in `cudarc 0.19.7` with `Unsupported cuda toolkit version: 13.4`.
The dependency recognizes toolkit versions only through 13.2. No dependency
or toolkit version was falsified to force the build through. The CPU build
prints an explicit fallback warning for `device("cuda")`; a successful
numeric result from that block is therefore not evidence of GPU execution.
`just cuda-probe` runs `probes/cuda-matmul.mlpl`, checks a known matrix
product, and rejects the explicit CPU fallback warning. Its script exits 77
on the CPU build (Just reports a failed recipe); it is opt-in and excluded
from the 24-probe fixture catalog. Passing this small smoke is only the first
acceptance case, not proof that the full model executes on CUDA.

Before reporting CUDA inference, build upstream against a supported toolkit
or obtain an upstream dependency update, then validate actual CUDA dispatch
and CPU parity for the array operations used by Qwen3. This is a core/device
handoff, recorded as R12 in [the core requests](sw-mlpl-requests.md).

The Linux checkout also lacks `demo-extensions`, `demo-mlpl-libraries`, and
`demo-ml-utils`. The pinned vendored header reader works without these
siblings. Native tokenizer parity and checksum-download integration need
their extension artifacts before they can be revalidated on Linux.
