# Requests to `../demo-extensions` (Rust extensions)

Work orders for capabilities that need native code, a file format, or
throughput the interpreter cannot reach, and that never need
differentiation (the rule is in [`feature-homes.md`](feature-homes.md)).
Each is consumed here through `load_extension` with all values crossing the
boundary as arrays, records, strings, packed bytes, or opaque handles.
Nothing here authorizes a change from this repository; the extension agent
revalidates each order against the artifacts named before its own saga
begins.

## E1. Hugging Face tokenizer extension (`hftok`)

**Current consumer result, 2026-09-25:** the moved Linux checkout at
`4be5074` supplies the packaged binary and public facade. With interpreter
`cd3cd03f`, six fixture cases, eight real-Qwen goldens/round trips and NFC
pass. The previous NFC gap below is resolved. Public-facade integration,
strict acceptance runner updates and corpus throughput remain consumer work;
see [the revalidation report](upstream-revalidation.md).

**State on 2026-09-18, second look: built and passing fixture parity.** The
library loads, and it encodes all six committed fixture expectations to ids
identical to the MLPL reference, faster than the reference. Four things a
consumer hit, in the order they were hit, none of them blocking the fixture
result:

1. **Name-based loading does not find it.** `load_extension("hftok")` looks
   for `libhftok.dylib`, but the crate builds `libmlpl_extension_hftok.dylib`.
   Loading by explicit path works and is what the parity runner now does;
   setting the crate's library name to `hftok` would make the documented
   name form work too.
2. **No public facade yet.** The extension registers the private namespace
   `_hftok`, and there is no `module.mlpl`, so a consumer must call
   `_hftok:load_path` and `_hftok:encode` directly. The convention in the
   ABI documentation is that a facade re-exposes these publicly.
3. **`load` takes a record, `load_path` a string.** Worth stating in the
   work order rather than discovering; the parity runner uses `load_path`
   with an absolute path.
4. **Return shapes are bare, not Results.** `load_extension` returns a
   string on success but a Result on failure, `load_path` returns a native
   handle, and `encode` returns an array. A consumer therefore branches on
   `type_of` rather than `is_ok`, which is worth documenting since every
   other fallible surface in this ecosystem is Result-shaped.

**The one substantive gap: the real Qwen3 vocabulary is refused** with
`unsupported normalizer NFC; a normalizer would rewrite text before
encoding`. The published file declares `"normalizer": {"type": "NFC"}`.
Refusing rather than silently ignoring it is the right call, and the MLPL
reference should be held to the same standard: it ignores the normalizer
today, which is a divergence this repository will document. For the
prompts this project encodes, which are ASCII mathematics, NFC
normalization is the identity, so a reasonable resolution is to accept NFC
and apply it, or to accept it with a documented no-op for input that is
already normalized. Until then `fixtures/tokenizer/qwen3-goldens.jsonl`
cannot be checked against the extension.

**Previous state, 2026-09-18 morning: started, not yet loadable.** The directory
`extensions/hftok/` exists with `Cargo.toml`, `src/lib.rs`,
`src/tokenizer_file.rs`, `src/file_source.rs`, and a contract test, but no
`extension.toml` manifest and no built library, so `load_extension("hftok")`
reports it missing. This repository's parity step therefore stops with an
honest unavailable result and the reference encoder remains the path for
bounded slices. Rerun `just tokenizer-parity` once the manifest and a built
library exist.

**Everything needed to check the work is now published here:**

| Artifact | What it pins |
|---|---|
| `fixtures/tokenizer/tiny-tokenizer.json` | a hand-authored byte-level BPE tokenizer, ten tokens and three merges |
| `fixtures/tokenizer/tiny-expected.jsonl` | six expected id sequences with the reason each holds |
| `fixtures/tokenizer/qwen3-goldens.jsonl` | eight real-vocabulary encodings produced and round-tripped by the reference encoder |
| `lib/tokenizer/bpe.mlpl` | the readable algorithm, including the pre-tokenizer divergences |
| `docs/reasoning.org` | prose for every function, tangling back to the sources |

The real-vocabulary goldens are the sharpest target. They include
`hello` to `[14990]`, `hello world` to `[14990, 1879]`, `42` to `[19, 17]`
because digits are separate pre-tokens, and a lone newline to `[198]`. Each
was verified by decoding it back to its input.

**One invariant the extension may rely on**, verified across all 151,387
merges of the Qwen3 vocabulary: the vocabulary id of the token a merge
produces is exactly the merge rank plus 256. The reference encoder uses it
instead of building a rank table, and checks it rather than assuming it.

Trigger: satisfied. Saga 2 step 1 parsed a real `tokenizer.json` and
published the fixtures above.

Requested public surface (private namespace `_hftok`, public facade
`hftok`):

- `hftok:load(path) -> handle`: read a `tokenizer.json` beneath the
  configured sandbox root; validate model type BPE with the byte-level
  pre-tokenizer and decoder; return an opaque handle; `err` on anything
  else.
- `hftok:encode(handle, text) -> integer array`: byte-level BPE with the
  file's own pre-tokenization pattern, merges, and added tokens; control
  tokens of the form `<|...|>` and the think tags map to their ids.
- `hftok:decode(handle, ids) -> string`: inverse, keeping control tokens
  visible.
- `hftok:token_to_id(handle, token) -> integer or err`, and
  `hftok:info(handle) -> record` with vocabulary size, the ids of the
  end-of-text, turn-start, turn-end, and think tokens, and the pattern
  string.

Chat templating stays in MLPL (`lib/tokenizer/template.mlpl`); the
extension never sees roles or prompts.

Acceptance:

1. Every case in `tests/test_tokenizer_reference.mlpl` (the MLPL reference
   encoder on the synthetic fixture) produces identical ids through the
   extension.
2. On the real Qwen3 vocabulary, the prompt/id pairs in
   `fixtures/tokenizer/qwen3-goldens.jsonl` round-trip exactly.
3. Encoding the 12,000 training prompts completes within the budget stated
   in `docs/plan.md` Saga 2 step 4, measured and recorded.
4. Malformed files, unsupported model types, and stale handles are `err`
   results, never panics.

## E2. Bounded large-artifact download — DELIVERED 2026-09-18

Shipped as `u:http_download(url, expected_bytes, sha256, root, path,
chunk_bytes, timeout_ms)` in the `http-client` extension, together with a
native streaming SHA-256 primitive. Thank you: this is exactly the shape
that was asked for.

**Planned consumption.** Saga 3 step 4 needs the weights, and the fetch
scripts here currently use `curl` with a byte-size check only. They will move
to `u:http_download` so the transfer is checksum-verified inside the sandbox
rather than trusted from outside it. The artifacts:

| Artifact | Bytes |
|---|---|
| `Qwen/Qwen3-0.6B-Base/model.safetensors` | 1,192,135,096 |
| `Qwen/Qwen3-0.6B-Base/tokenizer.json` | 7,031,645 |

One question for that step rather than a request: what `chunk_bytes` and
`timeout_ms` are sensible for a 1.19 GB transfer, and does the extension
report progress or only a final result? A long silent download is
indistinguishable from a hang. If progress reporting does not exist, this
repository will simply document the expected duration rather than ask for
it.

## E3. Contingent: a native safetensors tensor reader

2026-09-25: core R11 has shipped and passed consumer acceptance. The fallback
is not needed; proceed with an MLPL loader over core `unpack`.

**Not requested yet. Raise only if `sw-mlpl` declines request R11.**

Rechecked 2026-09-22: R11 is still missing at upstream HEAD `6d784660`, but
no decline has been observed. The bf16 step recorded an unavailable result
and chose to wait for core; E3 remains inactive. Acceptance and resumption
are pinned in [the decoder handoff](bf16-handoff.md).

The `bf16` dtype shipped upstream, but the bulk decode did not:
`reinterpret(bytes, "bf16")` returns a typed byte view with no length and no
arithmetic, and the only way to read values is one scalar at a time. The
Qwen3-0.6B embedding alone holds 155,320,832 values, so scalar reads are not
a path. That is filed upstream as R11, `unpack(bytes, dtype) -> array`, and
it belongs in core by the rule in `feature-homes.md`: it completes a dtype
that already lives there, and it is an array primitive.

If core declines it, the fallback is an extension here:
`sten:read_tensor(path, name) -> array` reading one named tensor from a
safetensors file and returning it already decoded, with the Hugging Face
name mapping left to MLPL. Decoding needs no differentiation, so an
extension is a legitimate home. The vectorized MLPL decode pinned by
`probes/bf16-vectorized-decode.mlpl` stays the parity reference either way.

This repository will report which way it went after Saga 3 step 1.

## Not requested

- Regular expressions: no remaining user in this repository.
- HTTP for small files: `http-client` V1 already covers responses under
  1 MiB.

## Consumer integration update, 2026-09-27

Pinned `4be5074`: public HTTP download and public tokenizer load work on
host `cd3cd03f`. Strict parity passes through the adapters described in
[the integration report](extension-integration.md). Six fixture and eight
real golden checks fail on mismatch; verified config and MATH-500 transfers
and verified reuse succeeded. D1 artifact digests and D2 consumer integration
are implemented here. Corpus throughput remains unavailable: the 12,000
training prompts are absent.

Two facade/boundary findings need follow-up:

- Core R13 rejects a bare native handle as an MLPL function argument.
  The consumer boxes handles and calls native encode/decode/close until
  the generic binder supports the public facade. See the core request.
- Direct `_hftok:decode(handle, [])` returns `invalid extension argument`
  rather than empty text on this host/library pair. Opt-in reproduction:
  `scripts/run-extension-demo hftok probes/tokenizer-empty-decode.mlpl`.
  Expected: exit 0 and empty text; observed: exit 1. Investigate empty-array
  ABI marshaling with core before assigning the bug to tokenizer code.
  Acceptance: empty encoded ids round-trip to empty text; nonempty and
  malformed ids retain their current behavior. The consumer currently
  handles the empty sequence locally, without claiming native empty decode
  passed. This does not block ordinary nonempty prompts.

Both probes require native artifacts and are outside the fixture gate.
No sibling modifications or external messages were sent.

## E4. Inference-only offload, user-authorized 2026-09-29

No new extension is required for today's working demo. The existing Rust
HTTP dynamic library posts bounded requests to local Ollama; model weights,
KV state and inference stay in its native GPU backend. MLPL keeps prompts,
explicit settings, answer verification and attempt accounting. See the
[live contract](native-reasoning-demo.md) and [research report](reasoning-results.org).
This is deliberately separate from the differentiable MLPL reference model.

A future in-process extension, if needed, should expose bounded
load/generate/close operations over typed generational handles, keep weight
and cache buffers native, reject stale/wrong handles, and return only small
text/token/metric results. Test lifecycle, cancellation, memory budgets,
malformed arguments and real GPU residency. Reuse a tested inference engine;
do not turn the extension into an untested model rewrite. No backward/tape
support is implied. This is a documented future option, not a new request
sent to the sibling owner. Siblings and installed tools remain unchanged.

## E5. Bounded long-running HTTP requests (missing, 2026-09-29)

The current HTTP `request` implementation caps `timeout_ms` at 120,000
(`http-client/src/client.rs`). At the measured roughly 35–38 tokens/s,
8,192 generated tokens can take over three minutes. Required semantics:
permit an explicit overall deadline up to 600,000 ms while retaining the
response-byte and redirect bounds, cancellation and typed failures.
Do not change the default or permit unbounded deadlines.

Opt-in acceptance probe: `scripts/run-extension-demo http
probes/http-long-timeout.mlpl`. It expects a quick local version GET to
succeed with a 600,000 ms deadline; the pinned extension currently rejects
that request before inference. Acceptance cases: 120,000 and 600,000 accepted;
zero, negative, fractional and 600,001 rejected; slow-response timeout and
size-limit failures still bounded. This affects `native-output-budget` and
future longer reasoning evaluations, not the immutable pilot.

Short-term workaround: `scripts/run-native-budget` uses bounded curl
transport (600 seconds maximum, 1 MiB body maximum, no redirects or retries).
MLPL still owns prompt construction, sampling parameters, completion rules
and final-answer grading. This is an explicit shell-transport workaround,
not a claim that the Rust extension now supports longer requests. No sibling
repository or installed tool was modified, and no external message was sent.

## E6. Rust CUDA ML backend — required for book reproduction

**Priority:** replaces further Ollama/HTTP work as the target architecture,
per the user's explicit clarification on 2026-09-29. E4/E5 remain descriptions
of the historical demo, not prerequisites for this backend.

Implement a resident CUDA model/tensor extension using Rust ML crates,
reusing sw-MLPL's existing Candle/cudarc foundation and the provider contract
in demo-ml-utils. First revalidate the existing CUDA demos on a supported
toolkit/dependency pair (R12); then fill the Qwen3-specific coverage gap.
Do not duplicate tensor/autograd machinery already implemented there.
See [the pinned ecosystem review](ecosystem-reuse.md).
Complete specification and acceptance sequence:
[rust-cuda-backend.md](rust-cuda-backend.md).

Input: local pinned `Qwen3-0.6B-Base` BF16 safetensors, config and tokenizer
identities from [data-and-models.md](data-and-models.md) and
[real-model-smoke.md](real-model-smoke.md). Load without service calls,
quantization or chat templates. Preserve model/KV buffers behind handles;
return last-position logits so MLPL controls seeded decoding and voting.
Require explicit device/dtype metadata, bounded contexts, lifecycle errors,
cache isolation, finite logits, tiny cached/full parity and real short-token
acceptance. Ship a release artifact, public facade, lockfile and GPU evidence.

A separate training acceptance milestone must prove loss/backward/update
and checkpoint behavior on an authored toy before real GRPO. A Rust-owned
autograd graph is allowed; wiring into MLPL core `grad` is not a prerequisite.
Do not label an inference-only artifact trainable. Test incorrect checkpoint
hashes/shapes, invalid token ids, overflow contexts, unavailable CUDA,
stale/wrong handles, resource release, and gradient/loss goldens. Explicitly
report unsupported GPU kernels or dtypes rather than falling back silently.

Current observation: no such package/artifact exists in the inspected sibling
extension tree. Consumer evaluation is unavailable until delivery and parity
checks. This work order is local; sibling policy prohibits implementing the
Rust package from this checkout. Core efficiency work remains deferred.

### E6 local implementation handoff, 2026-09-29

A working external prototype is available at
`/disk1/tmp/reasoning-tools/qwen3-cuda-provider`, with source archive
`/disk1/tmp/reasoning-tools/qwen3-cuda-provider-source.tar.gz` and hashes in
`docs/results/cuda-prototype-v1-artifacts.sha256`. See
[the runnable consumer and evidence](cuda-prototype.md). It uses the current
SDK, Candle 0.11.0 and cudarc 0.19.10 CUDA 13.4, and has demonstrated tiny
reference/cache parity and BF16 base generation through MLPL. This is concrete
implementation input for the extension owner, not just another API proposal.

Delivery still needs a portable SDK dependency/build record, public facade,
path confinement and expanded negative/lifecycle acceptance. Preserve the
record-boxed handle boundary. Keep inference separate from training: current
`info` explicitly reports training false. Sibling source was not changed.

### E6 accepted local v2 evidence and publication boundary, 2026-09-30

The tested v2 source is at
`/disk1/tmp/reasoning-tools/qwen3-cuda-provider-v2`, with a source archive at
`/disk1/tmp/reasoning-tools/qwen3-cuda-provider-v2-source.tar.gz`.
Its SDK dependency now pins git revision
`4be5074b7c3673a278e186c803a67072c50547ff` instead of an absolute sibling
path. Canonical model-root confinement is implemented. The separate native
artifact has SHA-256
`da6811a7eef300843b0e29c14623d45c3047e946667721d43ccd99a334a708bd`;
v1 remains intact for its recorded development smokes.

Independent real-checkpoint validation compares all 151,936 last-position
logits on a five-token prompt: CUDA F32 vs MLPL F64 maximum difference
7.1162e-6; BF16 vs F64 0.367154; BF16 cached/full 0.3125. All paths select
the same greedy token. See `results/cuda-real-precision-v2.txt`. This is
inference acceptance on the tested prompt, not general gradient acceptance.

The consumer now runs the book-aligned first-ten experiment through this
provider. Publication into the sibling is still pending authorization under
its read-only policy; the source/build inputs are concrete and reviewable.
No installation into stable user tools is needed. Remaining delivery work
includes the public facade and expanded negative/lifecycle test matrix.

Before scaling the experiment, profile resident forward separately from
vocabulary transfer and MLPL nucleus selection. A sampled 2,048-token answer
has already taken 267.55 seconds, versus roughly two minutes for greedy
answers of that length. These are different responses, so the difference is
not an isolated sampler benchmark. If selection/transfer dominates, use a
generic native selection operation checked against the MLPL reference at
fixed logits and supplied uniforms. Preserve temperature, top-p, crossing
token, stable tie and explicit-RNG semantics; do not change the completed
experiment's settings or scores. Keep core-interpreter optimization deferred.

### E6 native selection and stage profiling handoff, 2026-09-30

The consumer now supplies an isolated v3 implementation of `sample`,
`distribution`, `step` (resident forward plus token selection), and `profile`
(synchronized native stages). Source/build/hash handoff and acceptance are in
[cuda-performance.md](cuda-performance.md). The `step` request contains the
boxed model handle, input IDs, temperature, top-p and a **supplied MLPL uniform**;
the result is one token ID. No native RNG or answer-aware selection is added.

The sampler retains f64 arithmetic, stable lower-ID token ties, the crossing
nucleus token, vocabulary-order categorical CDF and exact boundary ownership.
It scatters sorted probabilities back by ID instead of sorting the inverse
permutation. Consumer fixture tests retain seed, budget, EOS and error
contracts. Real-logit probability arrays and matched generation must agree
before any production run is switched; v2's primary generation pins stay fixed.

Remaining provider work: profile CUDA kernel/driver/allocator time with an
actual kernel trace. Event spans include host launch gaps; wall time is not
GPU kernel occupancy. Investigate unfused attention, KV expansion, temporary
allocations and synchronization independently, with fixed token/context
lengths and host/GPU contention recorded. Neither blocking synchronization
nor disabling allocation event tracking has established a stall remedy in
these bounded probes; keep defaults unchanged. Shipping a single-stream
optimization requires enforcing tensor/stream lifetime isolation, not merely
assuming it. Publish the provider through demo-extensions only after the
consumer's parity and native tests, with the portable pinned build inputs.
