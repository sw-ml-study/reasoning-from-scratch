# Cross-repository handoffs

This document is a work order for agents operating in sibling repositories.
It does not authorize changes from this repository. Each request should be
revalidated against artifacts produced here before its own saga begins.

## `../demo-extensions`: Hugging Face tokenizer extension

Trigger: Saga 2 step 1 of this repository has parsed a real
`tokenizer.json` and published the synthetic fixture
`fixtures/tokenizer/tiny-tokenizer.json` with its expected encodings.

Requested public surface (private namespace `_hftok`, public facade
`hftok`), all inputs and outputs restricted to boundary types:

- `hftok:load(path) -> handle`: read a `tokenizer.json` beneath the
  configured sandbox root; validate model type `BPE` with byte-level
  pre-tokenizer and decoder; return an opaque handle; `err` on anything
  else.
- `hftok:encode(handle, text) -> integer array`: byte-level BPE with the
  file's pre-tokenization pattern, merges, and added tokens; control tokens
  of the form `<|...|>` and the think tags map to their ids.
- `hftok:decode(handle, ids) -> string`: inverse, keeping control tokens
  visible.
- `hftok:token_to_id(handle, token) -> integer or err`, and
  `hftok:info(handle) -> record` with vocabulary size, the ids of the
  end-of-text, turn-start, turn-end, and think tokens, and the pattern
  string.

Chat templating stays in MLPL (`lib/tokenizer/template.mlpl`); the
extension never sees prompts' roles.

Acceptance the extension agent should meet:

1. Every case in `tests/test_tokenizer_reference.mlpl` (the MLPL reference
   encoder on the synthetic fixture) produces identical ids through the
   extension.
2. On the real Qwen3 vocabulary, a published list of prompt/id pairs in
   `fixtures/tokenizer/qwen3-goldens.jsonl` round-trips exactly.
3. Encoding the 12,000 training prompts completes within the budget stated
   in `docs/plan.md` Saga 2 step 4, measured and recorded.
4. Malformed files, unsupported model types, and stale handles are `err`
   results, never panics; the panic-containment contract of the ABI applies.

## `../demo-extensions`: bounded large-artifact download

Trigger: Saga 3 step 4 needs `model.safetensors` (1.19 GB) inside the
sandbox root. The `http-client` V1 limit is 1 MiB, so the already designed
large-download path (declared length and checksum, streamed chunks into a
temporary file under a granted root, verification, atomic rename) is what
this repository would consume. Until it ships, `scripts/fetch-*` use `curl`
and check byte sizes. No new design is requested here; this is a consumer
vote for the existing plan with a concrete first artifact and checksum.

## `../demo-mlpl-libraries`: candidates after three consumers

Not yet triggered. The bounded expression evaluator, the string scanners,
and the per-tensor `MLPB` checkpoint helpers are candidates once an
unrelated repository uses them. Promotion follows that repository's library
contract (unique prefix, module comment, docstrings, mlplunit tests, catalog
entry, pinned-revision install).

## `../sw-mlpl`: core requests

Recorded in [`sw-mlpl-blockers.md`](sw-mlpl-blockers.md) under "core"; the
upstream owner is already working the autograd and dtype items. This
repository supplies probes with declared expected results (Saga 1 step 3)
so each fix can be verified from here.
