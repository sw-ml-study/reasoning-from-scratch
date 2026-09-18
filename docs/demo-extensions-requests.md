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

**State on 2026-09-18: started, not yet loadable.** The directory
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

**Not requested yet. Raise only if `sw-mlpl` declines request R11.**

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
