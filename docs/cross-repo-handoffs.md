# Cross-repository handoffs

Sibling repositories are read-only from here. Requests are recorded as work
orders that the other repository's agent revalidates before its own saga
begins. One document per repository:

- [`sw-mlpl-requests.md`](sw-mlpl-requests.md): core language requests
  (autograd rules, tensor primitives, dtypes, literals, distribution), each
  tied to a probe in `catalog/probes.tsv`.
- [`demo-extensions-requests.md`](demo-extensions-requests.md): Rust
  extension work orders (tokenizer, large downloads, a bf16 fallback).
- [`demo-mlpl-libraries-requests.md`](demo-mlpl-libraries-requests.md):
  reusable MLPL library candidates (text helpers, JSONL reader, the
  safetensors header reader, checkpoint helpers); none triggered yet.

The decision rule for which repository owns a capability is in
[`feature-homes.md`](feature-homes.md); the measurements behind every
request are in [`sw-mlpl-blockers.md`](sw-mlpl-blockers.md).
