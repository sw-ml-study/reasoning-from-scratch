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

Trigger: Saga 2 step 1 has parsed a real `tokenizer.json` and published the
synthetic fixture `fixtures/tokenizer/tiny-tokenizer.json` with its expected
encodings.

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

## E2. Bounded large-artifact download over `http-client`

Trigger: Saga 3 step 4 needs `model.safetensors` (1.19 GB) inside the
sandbox root.

Today: the `http-client` extension V1 has a 1 MiB response limit and a
10-second timeout, so it cannot fetch the weights or the datasets. The
extension repository has already designed a bounded large-download path
(declared length and checksum, streamed chunks into a temporary file under
a granted root, verification, atomic rename) but has not built it.

Requested: that path, with this repository as the first consumer.
Concrete first artifacts and their published sizes:

| Artifact | Bytes |
|---|---|
| `Qwen/Qwen3-0.6B-Base/model.safetensors` | 1,192,135,096 |
| `Qwen/Qwen3-0.6B-Base/tokenizer.json` | 7,031,645 |

Acceptance: a checksum-verified file appears under `models/` with the
published size; a truncated or tampered transfer leaves no partial file.
Until it ships, `scripts/fetch-*` use `curl` and check byte sizes.

## E3. Fallback only: `unpack_bf16(bytes) -> array`

Requested only if `sw-mlpl` request R7 (`bf16` dtype) slips behind Saga 3.
Decoding needs no differentiation and returns an ordinary array, so an
extension is a legitimate home. The vectorized MLPL decode
(`bf16-vectorized-decode`) remains the reference for parity.

## Not requested

- Regular expressions: no remaining user in this repository.
- HTTP for small files: `http-client` V1 already covers responses under
  1 MiB.
