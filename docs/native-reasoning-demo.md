# Live native reasoning demo

A real pretrained model now answers problems through an extension-backed
path. MLPL sends a bounded request through the existing Rust HTTP dynamic
library to local Ollama, then extracts and checks the **final answer**.
No model weights or KV cache are copied through MLPL function arguments.
This uses Qwen3 8B Q6_K, not this project's Qwen3-0.6B-Base checkpoint.
Neither model has been GRPO-trained or distilled by this project.

The user authorized this inference-only offload on 2026-09-29 to meet the
afternoon demo deadline. No interpreter patches, new Rust implementation,
sibling changes, or installed-tool replacements were required.

## Run today

From the repository root on this host:

```sh
export MLPL=/disk1/tmp/reasoning-tools/build-49c15b3e/release/mlpl-repl
export MLPLUNIT=/disk1/tmp/reasoning-tools/mlplunit/bin/mlplunit
export MLPLFMT=/disk1/tmp/reasoning-tools/sw-mlpl-49c15b3e/scripts/mlpl-fmt.sh
just reasoning-demo
```

Prerequisites already verified here: local Ollama on port 11434, installed
`qwen3:8b-q6`, the pinned `demo-extensions` HTTP library, `curl`, and `jq`.
There are no downloads in this recipe. A Codex network sandbox may require
approval for localhost access; a normal host terminal can use the command
directly. The model stays loaded for 30 minutes after a request.

Rehearse shortly before presenting so model loading happens before the
live question. The initial direct API smoke took 75.4 s including loading;
a later full MLPL/extension run took 13.6 s. Latency varies with generated
length, loading and concurrent GPU use.

Suggested three-minute presentation:

1. State the boundary: MLPL prompts and verifies; a Rust HTTP extension
   connects to the local native GPU inference engine.
2. Run `just reasoning-demo`. It asks a shopping/change question, prints the
   answer, and checks the final box against 8. The reference answer is never
   included in the model request.
3. Run `DEMO_CASE=2 DEMO_THINK=0 just reasoning-demo` for probability without replacement.
   The independent calculation is `(3 choose 2 + 2 choose 2) / (5 choose 2)
   = 4/10 = 2/5`.
4. Show `ollama ps` for GPU residency. Explain that the saved thinking text
   is model-generated text, not proof of a faithful internal reasoning process.
5. Show the saved comparison results, including every failed or incomplete
   attempt. Do not call these five authored examples a general benchmark.

Other cases: `DEMO_CASE=1` sequential discounts (72), `3` congruences (77),
`4` combined work rates (6). `DEMO_THINK=0 just reasoning-demo` disables the
model's thinking mode. The full opt-in comparison is:

```sh
just reasoning-eval
```

The default output cap is now 3,072 tokens, within a 4,096-token context and
the unchanged 120-second request deadline. Set `DEMO_MAX_NEW=1536` to reproduce
the original cap. The runner accepts integer caps from 1 to 3072 and saves
the chosen cap in both requests and summaries. Warm the model before comparing
latencies; longer output and cold loading share the request deadline.

It makes ten sequential calls: all five cases with thinking off, then all
five with thinking on. Both modes use the same seed and maximum output
budget; their actual token consumption can differ. Raw requests, responses,
per-case grades, summaries, runtime metadata and the exact chat template
are saved in the printed `out/native-reasoning/run-*` directory. These
ignored files remain available for rehearsal; committed measurements below
provide the durable record.

## Measured readiness, 2026-09-29

The warm single-case MLPL/extension run produced `\boxed{8}`, correctly
graded by MLPL: 531 generated tokens, 13.5849 s total reported by Ollama,
40.502 tokens/s during generation, no truncation. MLPL wall time was
13.5978 s. Evidence: `out/native-reasoning/run-Y2lwmFhW/`.

Ollama's residency endpoint reported 7,458,144,384 bytes both total and in
VRAM (100% GPU), context 4096. `nvidia-smi` reported 7,278 MiB total GPU use,
including desktop processes, of 16,311 MiB available. These establish the
native backend's GPU residency, not MLPL CUDA dispatch.

## Provenance and controls

The complete comparison (`run-AGzKBw9M`) used the same five authored cases,
seed 42 and 1,536-token limit in both modes:

| Mode | Correct / attempted | Truncated | Generated tokens | MLPL wall time |
|---|---:|---:|---:|---:|
| Thinking off | 5 / 5 | 0 | 1,432 | 42.17 s |
| Thinking on | 2 / 5 | 3 | 6,787 | 184.47 s |

The probability, remainder and rate questions truncated in thinking mode
before a complete final answer. All failures remain in the denominator.
This is evidence about this model/prompt/budget combination, not proof that
thinking is intrinsically worse. Saved attempts and provenance are committed
under `docs/results/`; the [literate report](reasoning-results.org) replays
the grading without a model or network.

With the new 3,072-token cap, both modes complete 5/5 correctly: direct
39.16 s / 1,432 tokens, thinking 204.74 s / 7,602 tokens. All three
truncations disappear; thinking ties accuracy at 5.23 times the wall time.
This is development-set diagnosis, not evidence of a held-out reasoning gain.

The follow-up retained all ten attempts in `native-budget-3072-2026-09-29`
records. The generated thinking text matches the original attempts; the
original final-content fragments are prefixes of the completed answers.

| Item | Pin / setting |
|---|---|
| MLPL | 0.22.0, `49c15b3e659ecc32603e10312a5197039b636397` |
| Interpreter binary SHA-256 | `d34ae2bfde1fa89c2af1b34053352d52a563dae8152b5c8425f83818a3dcaba0` |
| Ollama server | 0.24.0 |
| Model | `qwen3:8b-q6`, 8,190,735,360 parameters, Q6_K |
| Ollama manifest digest | `ee7613f19f946db6f549469bd24a6c77e48c591232ea97fdb7ec1f508a7e0dde` |
| GGUF SHA-256 | `cb042ccd76795a8830d6be6bd4165245847cc68e41797b13bd61aed4c2cfbce6` |
| Rust HTTP library SHA-256 | `360ce46da300d9ce3bda4db6d2f46c9c737a696cea9df3a1af7f9a99d1164e74` |
| Prompt template / dataset | `boxed-v1` / `authored-demo-v1` |
| Seed / sampling | 42; temperature 0.6; top-p 0.95; top-k 20; repeat penalty 1 |
| Context / generation cap | 4096 / 3072 tokens including thinking (original comparison: 1536) |
| Transport bounds | 120 s, 1 MiB response, zero redirects, localhost only in the driver |

The GGUF digest was independently measured on
`/disk1/tmp/qwen3-8b-q6/Qwen3-8B-Q6_K.gguf`; it matches the content-addressed
parent model reported by Ollama. Each run checks the installed manifest
and parent digest, records the runtime version, and saves/hashes the exact
installed chat template. It does not rehash the server's protected blob.
A seed aids reproducibility but is not a guarantee of bit-identical output
across runtimes, GPU configurations or repeated runs.

The adapter follows Ollama's [chat API](https://docs.ollama.com/api/chat)
and [thinking controls](https://docs.ollama.com/capabilities/thinking).
It builds escaped JSON in MLPL, receives final and thinking text separately,
and grades only a complete final response with boxed-only extraction.
HTTP errors, malformed responses, empty final answers and token-budget
truncation cannot become correct answers. Five offline native tests pin
these boundaries. The native ABI returns HTTP bytes as a numeric array on
this build; the adapter accepts that form and boxed packed bytes.

## Why 32 GiB when the GPU has 16 GiB?

The reference smoke's 32 GiB limit is Linux `RLIMIT_AS`: **CPU process
virtual address space**, independent of GPU VRAM. It was a containment
budget on a host with about 251 GiB RAM, not a model requirement. The
selected interpreter was CPU-only. Its f64 arrays expand the BF16 weight
payload from about 1.19 GB to about 4.77 GB before temporary copies.
Repeated model-argument and container copies multiply that allocation.
The GPU was not being used by those attempts.

A newly shipped core fix, `55c65f2f`, journals only names written by a
function instead of copying unrelated globals. We built the already-shipped
upstream code in isolation; no core enhancements were made here. On
`49c15b3e`, the scalar-call probe passes (1.11 ms small, 1.25 ms large,
10 ms threshold), and all original 148 tests pass. However the unchanged
real smoke still fails a 1,244,659,712-byte generation allocation:
102.890 s loading, 114 s process wall time, status 134, sampled VmHWM
33,011,188 KiB. Core-file limit was zero. No token was produced.

Simply raising that CPU ceiling would not establish acceptable demo
latency. The native workaround keeps a quantized model resident in the GPU
and exchanges only small text/JSON messages through the extension.

## Future performance work

Keep the pure-MLPL forward/cache tests as the reference. The remaining core
work is shared immutable/COW array storage, cheap record and partial reads,
and argument/frame binding that preserves scope and tape semantics without
payload-sized copies. Acceptance needs nested record/partial calls,
shadowing, recoverable errors, global writes, gradients, and measured
memory scaling. R3 batched matmul and R12 CUDA distribution remain separate.
These are follow-up improvements, not prerequisites for this demo.

If an in-process Rust inference dynamic library is later required, give it
typed generational session/model handles and bounded load/generate/close
operations, retain weights and KV buffers entirely inside native memory,
return only token ids/text/metrics, reject stale handles, and test lifecycle,
limits and CPU/GPU provenance. Reuse a proven native inference engine; do
not copy the model algorithm into an untested extension under a deadline.
This remains inference-only until a separately designed backward contract
exists. The current Rust extension is transport; computation happens in
Ollama's native backend, not inside that `.so`.

## Measuring reasoning quality

Today's authored problems establish demo readiness only. To measure
quality, freeze a held-out set before tuning (for example a published math
evaluation set), use verified reference answers, and score attempted
problems including timeouts, malformed outputs and truncations. Compare
thinking off/on and any self-consistency policy on the same problems;
report accuracy alongside tokens, wall time and cost, with several explicit
seeds and uncertainty on aggregate results. Match both per-request limits
and total sampling budgets, and retain raw attempts.

Check intermediate mathematics on an independently reviewed subset,
perturb numbers and wording, and include counterexamples to detect brittle
pattern matching. Final-answer correctness is the primary measurable
outcome; eloquent explanations, long thinking traces, or one successful
example do not prove reliable or faithful reasoning. No held-out accuracy,
training gain, or native-MLPL reasoning score is claimed here.

## Frozen held-out pilot

`just reasoning-pilot` runs six preregistered MATH-500 ids with seeds 42 and
43 in both modes (24 calls). The [frozen protocol](heldout-pilot-protocol.md)
was committed before inference. The runner verifies local dataset and
selection hashes, warms the model, alternates mode order, and retains
failures. Both modes have the same maximum token allowance; actual cost is
reported separately. This is an external pretrained evaluation, not training.

It requires the pinned local dataset (`just fetch-math500` on a new host).
The pilot itself performs no downloads and refuses changed protocol or data
hashes. Keep its run directory to enable independent local regrading later.

The [research report](reasoning-results.html) separates its primary verifier
scores from manual review. A multiple-choice normalization false negative
was discovered during the pilot and fixed in choice-v2; no original
score or answer is replaced. The post-hoc replay corrects four grades:
6/6 versus 5/6 at seed 42, and 6/6 versus 6/6 at seed 43.
Downloaded questions and raw answers remain
local, while numeric paired measurements and evidence hashes are published.

To independently regrade the retained local run without inference:

```sh
MLPL=/disk1/tmp/reasoning-tools/build-49c15b3e/release/mlpl-repl \
  scripts/replay-heldout-pilot out/native-reasoning/run-s69Yj0sQ
```

Report export replays public aggregate calculations only. Local raw replay
requires the pinned data and retained run directory; it is not in `just check`.
The replay validates frozen v1 grades and writes separate `choice-v2-pairs.jsonl`
and `choice-v2-summary.json` files in the retained run directory. It does not
replace the original metrics or call the model.
