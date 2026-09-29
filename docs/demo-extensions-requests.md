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
