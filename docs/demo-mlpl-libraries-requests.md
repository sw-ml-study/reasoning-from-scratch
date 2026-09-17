# Requests to `../demo-mlpl-libraries` (reusable MLPL libraries)

That repository publishes domain-neutral MLPL modules under a frozen
library contract: one entry file, an exclusive `u:<name>_` prefix, module
comments and docstrings, mlplunit tests, a catalog entry, and a
pinned-revision, hash-locked installer. Consumers vendor a revision; they
never include an adjacent working tree at run time.

Status as of 2026-09-16: no request is triggered. The rule in
[`feature-homes.md`](feature-homes.md) puts anything expressible in MLPL in
this repository first, and promotes it only after unrelated consumers exist.
The items below are the concrete candidates, in the order they are likely
to become real, so the library agent can see what is coming.

## Consumption planned here (no request needed)

- `result` 0.1.0 (`u:result_ensure`, `u:result_context`, `u:result_zip`)
  fits the loader and verifier error paths. Saga 1 step 5 decides whether
  to vendor it by pinned revision or keep the two helpers it needs local;
  vendoring exercises the installer from a second consumer, which is
  evidence that repository wants.

## L1. Text helpers — DELIVERED 2026-09-16, not yet consumed

Shipped as `text` 0.1.0 in that repository's catalog, entry
`lib/text/text.mlpl`, prefix `u:text_`.

**Prefix collision to resolve before vendoring.** This repository's own
`lib/text/text.mlpl` already owns `u:text_` locally with nineteen
functions. Because `include` splices every file into one global namespace,
vendoring the library means *replacing* the local module, not adding it. A
future step must compare the two surfaces function by function, keep any
local scanner the library lacks (the number-token recognizer and the
control-token remover are specific to this work), and only then swap and
delete the local copy. Until that comparison is done, this repository keeps
its own module and the library stays unconsumed.

### Original request

- What: `trim`, `starts_with`, `ends_with`, `contains`, bounded
  `replace_all`, `pad_left`, `split_lines`, character-class tests (digit,
  letter, whitespace), and `is_empty`, over the existing `str_*` builtins.
- Why a library: pure MLPL, a few lines each, domain-neutral, and already
  reinvented ad hoc (`../demo-ml-utils` carries its own `u:drift_contains`).
- Trigger: this repository lands `lib/text/` in Saga 1 step 6 and
  `../demo-ml-utils` or `../demo-extensions` facades need the same
  helpers. Three consumers is the promotion bar.
- Acceptance: byte-exact behaviour on Unicode input (character-indexed like
  the builtins), totality (no hard errors on empty input), and the
  probe-pinned absence of native helpers (`str-helpers`) so the library
  can retire when core ships them.

## L2. JSONL reader

- What: `read_jsonl(path, opts) -> ok(list of records) | err`, line
  splitting, per-line `parse_json` with budgets, line-numbered errors, and
  a bounded `take_first(n)`.
- Why a library: `parse_json` rejects arrays of objects by design
  (`json-array-of-objects`), so every dataset consumer needs this idiom.
- Trigger: `lib/eval/data.mlpl` here (Saga 1 step 5) plus one more
  consumer.

## L3. Bounded safetensors header reader (promotion from `../demo-ml-utils`)

- What: the eight-byte prefix read, header budget, `file_size` check, and
  JSON header validation that `../demo-ml-utils` already proved, as a
  library with the `fs.read-bounded.v1` capability.
- Why: this repository needs exactly that reader in Saga 3 step 1 and
  should vendor it rather than re-derive it; `demo-ml-utils` remains the
  algorithmic owner of decoding and cataloging.
- Trigger: Saga 3 step 1 here. The request is really to `demo-ml-utils`
  (to publish) and `demo-mlpl-libraries` (to host); both are read-only from
  here.

## L4. Per-tensor `MLPB` checkpoint helpers (later)

- What: save and load a record of named arrays as one `to_native` file per
  tensor under a directory, with an index file, atomic writes, and a size
  and hash manifest (`native-roundtrip-10mb` measures the primitive).
- Trigger: Saga 5 step 2 here plus a second training consumer.

## L5. Bounded arithmetic expression evaluator (later, maybe never)

- What: the parser and exact-rational evaluator from
  [`verifier-contract.md`](verifier-contract.md).
- Why it may stay here: it is math-verifier-specific until another
  repository needs symbolic-free numeric equivalence.

## Not requested

- A tokenizer: that is native work (`demo-extensions-requests.md`).
- Anything on the autograd tape (`sw-mlpl-requests.md`).
