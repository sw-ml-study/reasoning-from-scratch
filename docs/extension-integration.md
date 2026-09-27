# Tokenizer and verified-download integration

Validated 2026-09-27 with sw-MLPL `cd3cd03f`, mlplunit `a06191f8`, and
`demo-extensions` `4be5074b7c3673a278e186c803a67072c50547ff`.

## Dependency loading

The extensions remain external, read-only dependencies; no Rust, binaries or
facade copies are vendored here. Their MIT-licensed public `module.mlpl`
files are read into the temporary demo program after SHA-256 verification:

| Facade | SHA-256 |
|---|---|
| hftok | `46be36fec408a402a2d7dd03d9b1976a5284e751e6d7ecef570e69fd095ba00d` |
| http-client | `c5d9d807fe5be286ef1b443958af89e91c208d11d1716064f719261305be2dd6` |

`scripts/select-extension` prefers an explicit absolute `HFTOK_LIBRARY` or
`HTTP_LIBRARY`; otherwise it selects only the packaged platform artifact
under `EXTENSIONS_ROOT` (default `../demo-extensions`). It never searches
arbitrary target/debug trees. Invalid overrides fail instead of falling
back. Unsupported platforms require an explicit override. A library SHA-256
is printed for each run; changing native artifacts is an explicit dependency
choice, not a claim of binary reproducibility. Facade drift requires review.

## Strict tokenizer acceptance and two workarounds

`just tokenizer-parity` requires the real tokenizer, returning status 77
when absent. `scripts/run-tokenizer-parity --fixture-only` is explicitly
labeled as incomplete real acceptance. Every golden must match both ids and
decoded text. Empty suites, malformed rows, callback failures, wrong ids and
wrong round trips are errors. `TOKENIZER_PATH` accepts an absolute override;
`TOKENIZER_GOLDENS` can select another JSONL suite beneath the repo sandbox.

The public load facade works. Bare native handles **cannot** be passed to
user-defined MLPL functions on this host, so public encode/decode/close
facades do not work. Boxed records can carry handles: the demo uses minimal
MLPL adapters that pass the record's handle to the native encoder/decoder.
This is the documented R13 workaround, not full public-facade acceptance.
Native decoding of an empty token vector also returns `invalid extension
argument`; the adapter returns the mathematically defined empty text locally.
It does not mask errors for nonempty ids. The extension/core handoffs contain
opt-in probes and the conditions for removing both workarounds.

Measured: six fixture id/round-trip cases pass through the adapter (five
native decodes and one local empty decode), eight real-Qwen golden round
trips pass, and composed/decomposed Café agrees under NFC. An intentionally
wrong real golden exits nonzero; missing real data returns 77. No 12,000
training-prompt corpus is present, so corpus throughput is **unavailable**.
These tiny timings are not training-corpus throughput evidence.

## Immutable artifact pins and verified transfers

[The manifest](../catalog/artifacts.jsonl) fixes revision, URL, size, SHA-256,
local destination and license provenance for tokenizer, configuration,
weights and MATH-500. Small-file hashes were measured from independent HTTPS
fetches at the pinned revisions. The 1.19 GB weight hash/size were read from
the pinned raw Git LFS pointer, without transferring weights. These are
content-integrity pins, not publisher signatures.

```sh
just fetch-model                  # tokenizer and config
scripts/fetch-model --weights      # additionally 1.19 GB; opt-in
just fetch-math500                 # 446,564 bytes; opt-in
```

All use `u:http_download` through the pinned public facade: 1 MiB chunks,
one-hour deadline, native streaming SHA-256, verified reuse, temporary-file
cleanup and publication only after length/hash agreement. The consumer also
checks the returned byte count and digest. Valid cached files are reused
without network; invalid cached files are replaced only after verification
of a fresh transfer. There is no progress callback; size and deadline are
printed before transfer. The sandbox may require network approval; no sudo
or driver changes are needed.

The dataset card at revision `6e4ed1a2a79af7d8630a6b768ec859cb5af4d3be`
declares no license field and points to the OpenAI PRM800K source (MIT).
The manifest preserves that distinction rather than inventing a dataset
license. Downloads stay ignored and are never redistributed.

Measured native HTTP results: tokenizer verified reuse; configuration and
MATH-500 successful fresh transfers with matching receipts; subsequent
MATH-500 reuse. Real model weights were **not downloaded** in this step.
HTTP security/error cases remain covered by the extension's own tests;
consumer tests exercise callback controls, manifest ambiguity and receipt
mismatches without network.

## Checks, next work and two literate documents

The fixture gate has 143 native tests, 26 probe outcomes, 23 tangled library
sources and shell discovery tests. It requires no network, real artifacts
or native extensions. Real parity and transfer checks remain opt-in.

The next step obtains the pinned weights and attempts bounded CPU smoke,
recording load memory/time, provenance and generated output before any
accuracy claim. CUDA remains R12; full public tokenizer facades remain R13.
Neither prevents using the tested CPU path and documented adapters.

Two separate Org/Babel documents serve different readers:

- [Using the model](using-reasoning-model.org): setup and runnable current
  commands, with real inference instructions to be completed when viable.
- [How it works](reasoning.org): annotated implementation blocks, checked to
  tangle exactly back to library sources.

The first end-to-end real-model smoke must update both documents with the
actual command, observed output and limits; it must not present fixture
success as learned reasoning.
