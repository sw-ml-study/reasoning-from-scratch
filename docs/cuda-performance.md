# CUDA inference performance: measured costs and native selection

The dogfooding experiment finds a concrete implementation cost and removes
most of it through a native extension. On the same GPU, checkpoint, authored
prompt and uniform stream, sampled generation improves from **8.98 to 21.33
tokens/s (2.37×)** with exactly identical tokens. This is a measured comparison
against our MLPL selector, **not a speedup over the book's Python implementation**.
The original book-author-v2 scores and generation pins remain unchanged.

## Fixed-input sampler cost

The input is the full 151,936-entry BF16-model logit vector for the five-token
France prompt. Twelve repetitions, temperature 0.9/top-p 0.9. Mean milliseconds:

| Operation | MLPL | Native Rust through extension |
|---|---:|---:|
| Temperature and softmax |15.11| included below |
| Nucleus filtering |57.47| included below |
| Categorical selection |23.71| included below |
| Complete sampled selection |96.29|12.18|
| Greedy argmax |0.51| not isolated |

The native probability vector is exactly equal to the reference (maximum
absolute difference 0), and all twelve supplied-uniform selections match.
Five Rust unit tests additionally cover analytically known probabilities,
stable ties, crossing-token filtering, exact CDF boundaries and invalid input.
Native selection runs on CPU in Rust; this is not a GPU sampling kernel.

A separate eight-repeat primitive profile measures mean validation 8.16ms,
normalization 20.75ms, softmax 4.93ms, descending argsort 8.55ms, inverse argsort
12.99ms, gather 8.25ms and cumulative sum 2.87ms. These nested operations are
**not additive** to the full sampler: they are independent probes that reuse
some of the same work. The extra live arrays also differ from the production
call frame. Use them to locate costs, not construct a fictitious exact budget.

## Why the implementation costs time

`lib/scaling/scaling.mlpl` validates large vectors repeatedly, normalizes
probabilities again at multiple boundaries, sorts the full vocabulary, then
sorts the permutation a second time to restore vocabulary order. Each stage
creates intermediate arrays. The pinned interpreter's `DenseArray` derives
`Clone` on a `Vec<f64>`; record/Result reads and assignments also clone values.
Core ownership and boundary marshalling therefore matter in addition to the
mathematical work. Exact allocation/copy attribution is still required before
assigning a percentage to copying.

The Rust selector keeps the arithmetic order and validation semantics but
uses native loops and scatters probabilities into token-ID order, eliminating
the inverse argsort. The resident `step` combines forward and selection so
only one ID crosses back to MLPL. MLPL still owns the explicit random stream,
controls, token budget, EOS handling and experiment accounting.

Ownership of follow-up fixes is explicit:

| Owner | Finding and requested change |
|---|---|
| This consumer / MLPL libraries | Avoid repeated validation/normalization inside an already checked sampling operation; eliminate inverse sorting while preserving exact behavior |
| sw-MLPL core (R14) | Allocation/copy profile; borrowed/shared array storage or copy-on-write; measured contiguous-vector kernel improvements with alias/autograd tests |
| demo-extensions (E6) | Package the tested supplied-uniform selector/resident step; retain reference parity and diagnostics |
| Native Candle/provider | Trace kernel launches, allocation and synchronization to explain remaining stalls before enabling attention/cache optimizations |
| demo-ml-utils | Reuse coarse resident-provider contracts and timing/acceptance requirements; this package is not executing the measured hot path |

No sibling repository or installed tool was modified. Concrete requests are
in [R14](sw-mlpl-requests.md), [E6](demo-extensions-requests.md) and
[the library request](demo-mlpl-libraries-requests.md).

## Matched generation, including the actual MLPL adapter

`demos/cuda_profile_matched.mlpl` compares `u:cuda_decode` with
`u:cuda_decode_native` on one independently authored tank prompt. It resets
the cache each call, uses the same weights and seed 43, caps at 128 new tokens,
and alternates execution order. Four sampled pairs use temperature 0.9/top-p 0.9;
two greedy pairs use temperature 0. All twelve calls reach 128 tokens. Every
pair has exact token equality; these are capped performance traces, not an
accuracy experiment or proof of every generated reasoning step.

| Mode | Reference mean /128 tokens | Native mean /128 tokens | Ratio of summed times |
|---|---:|---:|---:|
| Sampled (4 pairs) |14.247s|6.000s|2.3745×|
| Greedy (2 pairs) |5.604s|5.059s|1.1079×|

Model load and tokenizer work are outside these timers; prefill, token
selection and MLPL loop overhead are included. The small greedy difference
is not strong evidence of a separate optimization given the observed jitter.
The sampled reduction is consistent with the independently measured sampler
cost. [Numeric records](results/cuda-profile-v3-matched.jsonl),
[summary](results/cuda-profile-v3-summary.json) and
[acceptance](results/cuda-profile-v3-acceptance.txt) are public.

## CUDA stage attribution and remaining uncertainty

The instrumented provider explicitly synchronizes input transfer and forward
completion before measuring final-logit conversion/host transfer. Three fixed
prefills (32,256,1024 copies of token 785) each precede 16 one-token decodes.
The 48 calls measure mean native forward 47.48ms, final-logit conversion/transfer
11.46ms and total outer call 60.09ms. Typical minima are 5.02ms forward and
0.323ms transfer, but maxima reach 99.35ms and 42.52ms respectively.

The calling thread consumes approximately the forward wall time (mean 47.15ms
CPU versus 47.48ms wall), consistent with active execution or spin waiting,
not simply being descheduled. CUDA event spans also contain the delays, but
**include host launch gaps**: they are not aggregate kernel time or occupancy.
A 610KiB vocabulary transfer is normally submillisecond; its occasional 40ms
latency cannot be explained merely by the payload size. The aggregate stage
mean is instrumentation/workload-specific and is not added to the independent
sampler timing to predict production latency.

Host inspection found no other compute application on the GPU; the display
and remote desktop remain active. Blocking context synchronization and the
single-stream event-tracking diagnostic did not remove long stalls. Their
small runs establish no reliable speedup, and defaults remain unchanged.
A kernel/driver trace is the next attribution step. The current Candle build
uses standard matmul attention rather than its optional CUDA flash-attention
feature. That is an optimization candidate, not a proven cause of all stalls.

The book's published total times do not give this component breakdown. A fair
Python-versus-MLPL comparison requires the same hardware, token workload,
precision, cache and sampling semantics. Our current evidence establishes an
implementation-specific improvement, not language superiority.

## Reproduce without Python

Set the tested interpreter and native provider paths; downloaded model assets
must already be present. Profiling is opt-in and excluded from `just check`.

```sh
export MLPL=/disk1/tmp/reasoning-tools/build-49c15b3e/release/mlpl-repl
just cuda-profile stages
just cuda-profile sampler
just cuda-profile primitives
just cuda-profile native-sample
just cuda-profile matched
just cuda-profile-report
```

`stages` writes the fixed vector to ignored `out/cuda-profile-logits.json`.
`matched` checks complete token equality before printing PASS. The report
recipe recomputes the committed numeric summaries using MLPL, including an
independent analytic statistics check. New live runs print measurements;
they never rewrite committed evidence. Experimental switches default off.

Source handoff: `/disk1/tmp/reasoning-tools/qwen3-cuda-provider-v3`;
archive `/disk1/tmp/reasoning-tools/qwen3-cuda-provider-v3-source.tar.gz`.
Archive SHA256:
`48c642d7a25ba712004a72145689897aeac638875bd76243779618cf7a87e5e0`.
Library SHA256:
`539ea87f7367e2ecb9e847232310097202d1f4318ab992c3aaf8cd3dae4ff56a`.
The archive contains source, SDK revision, Cargo.lock and build instructions.
Run `cargo build --release --locked --offline` with CUDA_ROOT/CUDA_PATH set to
`/opt/cuda`, CUDA_COMPUTE_CAP=120 and `/opt/cuda/bin` on PATH. The output is
`libmlpl_qwen3_cuda_profile.so`. Dependencies must be cached or fetched first.
The [provenance manifest](results/cuda-profile-v3-provenance.json) pins the
interpreter, hardware, checkpoint and measurement scope. Source publication
through the extension repository is still a separate delivery step.

## Before the full benchmark

The [full500 protocol](book-full500-protocol.md) fixes methods and exactly-once
attempt accounting. It is a design freeze, not a completed resumable runner
or a completed experiment. Implement/test crash recovery and pin all rendered
prompts before launch. Long-context acceptance and further CUDA attribution
remain useful before paying the full run cost. Native model training retains
its separate loss/backward/update/save/reload gate.
