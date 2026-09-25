# Delivered dependency revalidation — 2026-09-25

**Bulk unpack and the Linux tokenizer are available. The named-tensor loader
is next; real model inference and learned reasoning are not demonstrated.**

## Interpreter and fixture evidence

The adjacent sw-MLPL source is still `6d784660`, but a read of remote HEAD
returned `cd3cd03fd4eb66d1a33390a40f27c28e8a55e435`. The new source contains
bulk `unpack`, shipped in `b3180d9a`. An isolated detached worktree and release
build preserve the installed tools, adjacent checkout and previous build:

```sh
git -C /disk1/tmp/reasoning-tools/sw-mlpl fetch origin
git -C /disk1/tmp/reasoning-tools/sw-mlpl worktree add --detach \
  /disk1/tmp/reasoning-tools/sw-mlpl-cd3cd03f cd3cd03fd4eb66d1a33390a40f27c28e8a55e435
cargo build --manifest-path /disk1/tmp/reasoning-tools/sw-mlpl-cd3cd03f/components/cli/Cargo.toml \
  --target-dir /disk1/tmp/reasoning-tools/build-cd3cd03f -p mlpl-repl --release --locked
export MLPL=/disk1/tmp/reasoning-tools/build-cd3cd03f/release/mlpl-repl
export MLPLUNIT=/disk1/tmp/reasoning-tools/mlplunit/bin/mlplunit
export MLPLFMT=/disk1/tmp/reasoning-tools/sw-mlpl-cd3cd03f/scripts/mlpl-fmt.sh
just tests tests/test_unpack.mlpl
just capabilities
just check
```

The source worktree must be created only once. No sudo or sibling mutation
was used. The runner remains pinned to `a06191f800f40a23ebc1890eada3f505b1adab60`.

The original capability run reported exactly one drift: `unpack-bulk`
changed from expected failure to success. The catalog now marks it shipped.
All other 24 observations are unchanged, including open R3 batched matmul
and R10 container-access costs. Five native consumer tests first failed on
the old interpreter (four missing-function failures; the error test passed),
then all passed on the new build:

- Six authored bf16 values, rank-one output and an empty buffer.
- Minimum subnormal, maximum subnormal, minimum normal and maximum finite.
- Positive/negative zero, positive/negative infinity and NaN.
- Catchable malformed byte length, unknown dtype and non-byte argument.
- Exact bounded f32 pack/unpack round trip.

The full gate has **129 tests, 25 probe outcomes and 20 tangled libraries**.
No claim about new autograd behavior follows from the existing eager tests.

`just unpack-benchmark` is opt-in and uses synthetic buffers only. One run
measured a million f32 values at **12.49 ms** and a million bf16 values at
**19.21 ms**, validating the decoded values. Input creation/packing is outside
the measured interval. These are single runs, not stable benchmarks. The
155,320,832-value acceptance case, complete file-loading time and peak RSS
remain for the loader feasibility step.

## Moved Linux extensions

The adjacent checkout now exists at commit
`4be5074b7c3673a278e186c803a67072c50547ff`. Both packaged Linux libraries are
present and their SHA-256 values match its delivery documentation:

| Package | SHA-256 |
|---|---|
| hftok | `815f3ec0efac3df883b04c92163681a3ae812190677fca45db598bc1ed85783b` |
| http-client | `360ce46da300d9ce3bda4db6d2f46c9c737a696cea9df3a1af7f9a99d1164e74` |

The packaged hftok library loads on the new interpreter. Six authored fixture
encodings agree with our reference. Eight real-Qwen golden encodings and
round trips agree, and composed/decomposed Café encodes identically and
decodes to NFC. The existing real tokenizer file was copied from the sibling
into ignored `models/qwen3-0.6b-base/tokenizer.json`, without a download. Its
SHA-256 is `c0382117ea329cdf097041132f6d735924b697924d6f6fc3945713e96ce87539`;
the extension's delivery pins its model revision to
`da87bfb608c14b7cf20ba1ce41287e8de496c0cd`.

To explicitly choose the packaged binary instead of an arbitrary build:

```sh
export HFTOK_LIBRARY=/disk1/github/sw-ml-study/demo-extensions/extensions/hftok/native/x86_64-unknown-linux-gnu/libmlpl_extension_hftok.so
export REPO_ROOT="$PWD"
./scripts/run-mlpl-demo demos/tokenizer_parity.mlpl
```

The existing parity demo still uses private calls, has an obsolete facade
notice and does not fail the process on real-golden mismatches. This run's
printed counts were inspected, with an independent check of all eight
round trips and NFC. Updating discovery to prefer packaged artifacts,
using the public facade, enforcing all real-golden failures and measuring
12,000-prompt throughput are explicitly pending integration work. The
HTTP artifact was hash-checked; its download workflow was not rerun here.

## Remaining work and CUDA

R11 is no longer an upstream implementation blocker. Write the MLPL
named-tensor loader using validated safetensors plans, prove byte bounds,
dtypes, shapes, projection orientation and tied embeddings on tiny fixtures,
then measure full-size synthetic allocation before real weights. No E3
native-reader fallback is needed.

CUDA remains separate: the current lockfile still pins cudarc 0.19.7 and
its toolkit-version table stops at 13.2, while this host has toolkit 13.4.
The new CPU build produces an explicit fallback; `scripts/run-cuda-probe`
exits 77. A CUDA build was not repeated against this unchanged dependency.
The previously verified working driver does not resolve this build-time
version rejection. No sudo commands or driver changes are needed for the
CPU loader step. R12 requires upstream dependency/toolkit compatibility and
subsequent device-dispatch parity before GPU claims.
