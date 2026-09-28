# Bounded Qwen3 CPU viability

This is a viability measurement, not a reasoning or accuracy evaluation.
**Current result: generation unavailable.** The subsequent
[loader profile](loader-profile.md) reduced loading to 101.45 seconds, but
generation failed an allocation under the same 32 GiB address-space limit.
The original run documented below exhausted its 600-second process budget
while still inside `u:st_load_model`; generation never began in that run.
The post-reboot resume on 2026-09-28 found `main` clean at `55b73d8`, with
the first three delivery-integration steps complete and the smoke pending.
The isolated tools, tokenizer and configuration survived. The initial
fixture gate passed 143 native tests and all 26 declared probe outcomes;
real tokenizer acceptance again passed six fixture cases, eight Qwen
round trips and NFC.

## Reproduction and resource contract

Select the tools from [the operator guide](using-reasoning-model.org), then:

```sh
scripts/fetch-model --weights
just real-model-smoke
```

The explicit fetch downloaded and verified the 1,192,135,096-byte checkpoint
through the pinned HTTP facade. Sandbox DNS initially failed; the authorized
network retry succeeded. The smoke itself performs no network operations.
It checks all three cached artifact hashes before invoking the tokenizer or
loader. Missing files return 77; hash failures stop before inference.

- Interpreter: sw-MLPL 0.22.0, commit `cd3cd03f`, CPU build.
- Host: Intel Xeon W-2135 at 3.70 GHz, 12 logical CPUs, about 251 GiB RAM;
  Linux `7.2.4-arch1-2`. The interpreter was observed with one thread.
- Interpreter SHA-256: `b0087e9bdaf0a1f228c7b92c00eaf5e283134868b7eeba010afa7485e9c47e34`.
- Model revision: `da87bfb608c14b7cf20ba1ce41287e8de496c0cd`.
- Weight SHA-256: `cd2a512003e2f9f3cd3c32a9c3573f820bb28c940f73c57b1ddaa983d9223eba`.
- Config SHA-256: `504a6b58c4271583724e66584b6b7698aea18450209df6b2f7582df0e89cee59`.
- Tokenizer SHA-256: `c0382117ea329cdf097041132f6d735924b697924d6f6fc3945713e96ce87539`.
- Native hftok SHA-256: `815f3ec0efac3df883b04c92163681a3ae812190677fca45db598bc1ed85783b`.
- Template `base-smoke-v1`: literal bare text `The capital of France is`.
- Prompt ids: `[785, 6722, 315, 9625, 374]`.
- Greedy decoding; seed 42 recorded but unused; maximum two new tokens;
  EOS 151643, excluded from decoded output.
- Limit: 600 wall seconds, then TERM and a five-second KILL grace period;
  32 GiB virtual address space through Linux `ulimit -v`.
- Seven rotary positions allocated, after validating the pinned base
  config's 32,768-position limit and supported architecture semantics.

The driver retains the boxed-handle and empty-decode adapters. No CUDA
dispatch is requested or accepted. Header validation reports 310 tensors,
596,049,920 BF16 parameters, 1,192,099,840 payload bytes and tied embeddings.
The full file additionally contains the header and its eight-byte prefix.

## Observed result, 2026-09-28

| Measurement | Result |
|---|---|
| Whole-process elapsed time | 600 coarse wall seconds |
| Process exit status | 124 (deadline) |
| Last phase printed | `load` |
| Maximum sampled VmHWM | 14,830,820 KiB, about 14.14 GiB; lower bound on peak RSS |
| Completed whole-model load time | unavailable: loader did not return |
| Generation time, generated output, tokens/second | unavailable: generation never started |
| Accuracy or reasoning improvement | not evaluated |

The final output was:

```text
phase: load
process wall seconds (coarse): 600
sampled process VmHWM KiB: 14830820 (lower bound; 50 ms polling)
process exit status: 124
```

Hash/config/header acceptance does not establish inference viability. The
single-embedding synthetic benchmark did not predict the cost of whole-model
assembly. Existing R10 copying costs are a candidate explanation; this run
does not isolate the cause. No new missing primitive is claimed. Bulk
decoding remains supported, while practical whole-model loading is awkward
and real inference is unavailable within this budget.

## Implementation and checks

The wrapper handles artifact integrity and OS process budgets. The MLPL
driver owns tokenization, compatibility validation, loading and generation;
it calls the existing named loader and cached greedy loop. The new config
guard refuses mismatched dimensions, activation and rotary conventions.
Two native fixture tests cover acceptance, missing/mismatched fields and
context limits. Offline shell tests cover missing data, bad hashes, child
failure propagation and positive Linux memory sampling. The gate never
downloads artifacts or runs the real model.

The implementation guide tangles the guard and driver exactly. The operator
guide contains the commands and interpretation. Linux `/proc` can expose
host PIDs while shell `$!` contains a namespace PID; the wrapper reads its
own host PID with a shell builtin and follows the timeout's child for VmHWM
sampling. Samples are lower bounds on peak resident memory.

During setup, `/usr/bin/time` was absent, so the wrapper uses Linux VmHWM.
The first long attempt remained in loading but its reporting failed after
the running shell script was edited; that attempt is excluded from final
timing/status acceptance. The table above comes from a repeat with the
unchanged corrected wrapper, independently retested on offline fixtures.
These are warm-cache viability attempts, not cold-storage benchmarks.

## Follow-up: loader profiling delivered

The plan below was executed in [the loader profile](loader-profile.md).
Scoped temporary fields and role-stack operands improved authored fixtures
and completed real loading. The next boundary is resident-model copying
during generation; no real output or accuracy is available yet.

Profile the loader before attempting evaluation. Separate packed reads,
bulk conversion, finite checks, transposes, role-stack growth and callback
capture. Use authored scaled fixtures first and retain the tiny loaded/full
versus cached-forward goldens. In particular, test whether retaining the
large embedding while constructing layer stacks increases call/environment
copying; changing load order or scope is a library-level candidate, not a
proven remedy. Existing R10 probes establish size-dependent container costs
but do not by themselves diagnose this whole-model attempt.

Apply the feature-home rule: prefer a bounded MLPL change when expressible;
request core work only for fundamental value/tape/device semantics and attach
a minimal declared probe to any new request. Do not move the differentiable
model into a native extension. Keep siblings and installed tools read-only.
Repeat the same hashed checkpoint, prompt and process budgets after an
accepted change. Proceed to a small measured evaluation only after load and
generation complete. Toy GRPO remains an independent queued track.
