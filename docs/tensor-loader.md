# Named-tensor loading and tied Qwen assembly

`lib/safetensors/load.mlpl` implements chapter 2 checkpoint loading in MLPL.
It consumes validated safetensors directories and uses core packed reads and
bulk unpack. Nine native tests use authored tiny payloads; no real checkpoint
has been loaded and no real-model accuracy is reported.

## Interface

| Function | Result |
|---|---|
| `u:st_read_tensor(header, name, expected_shape, dtype)` | Decoded array in the file's stored shape |
| `u:st_read_projection(header, config, layer, role, dtype)` | Array oriented for the forward pass |
| `u:st_load_model(path, config, dtype, options)` | Resident model compatible with the existing Qwen and cached-generation functions |

All three return Results. Headers must come from `u:st_open`; configuration
must be a valid Qwen configuration. Header budgets are passed through
`options` unchanged. Supported weight dtypes are **BF16 and F32**. The decoder
preserves finite values, subnormals and signed zero. NaN and either infinity
are rejected as model weights, even though core unpack can represent them.

A named read checks the stored dtype and exact shape. Offsets are relative to
the data region, so the file read starts at `8 + header_length + entry.start`
and spans exactly `entry.end - entry.start` bytes. `read_bytes_packed` keeps
input storage packed; `unpack` returns f64 numeric values, which are reshaped.
There is no scalar read per element or expanded numeric array of input bytes.
The new `packed-range-read` probe pins offset, length and EOF behavior.

File size is checked against the validated header, and short reads are
rejected. This catches truncation but is not a content identity check or an
atomic snapshot: the caller must keep the file immutable during loading and
verify its artifact hash separately. Unsupported dtypes, absent names, shape
mismatches and nonfinite weights fail rather than becoming partial models.

## Model assembly and orientation

Whole-model header validation occurs before payload reads. Every attention
and MLP matrix is transposed from the published output-by-input layout into
the positions-by-width multiplication convention here. Embeddings retain
`[vocab, emb]`; normalization gains retain their vector shape.

Each role is stacked across layers. The returned partial `layer_weights`
callback selects resident arrays; it does not open files during inference.
The model also contains the embedding, final gain, RoPE tables and a
`checkpoint` validation summary. The summary is structural metadata, not a
checkpoint hash or an accuracy record.

**Only tied output embeddings are supported**, matching Qwen3-0.6B and the
current forward contract. A separate `lm_head.weight` produces `untied_head`;
it is not silently ignored. The existing generic header validator may inspect
other checkpoint layouts, but this assembly API is narrower.

The tiny loaded model matches cached versus full-prefix logits within 1e-10.
Tests also overwrite the source file after loading and confirm unchanged
logits, proving inference uses resident data. Distinct layer payloads and
nonsquare projections catch ordering/orientation mistakes.

## Full embedding-size synthetic measurement

Opt-in, outside `just check`, using the [current CPU tools](linux-toolchain.md):

```sh
just unpack-embedding-benchmark
```

This creates a temporary sparse zero-filled bf16 file, reads 310,641,664
packed bytes, decodes **155,320,832 values**, validates shape and zero values,
and removes the temporary file. It needs several GiB of available RAM.
No weights are downloaded. It uses no sudo and installs no tools.

One run on Arch with interpreter `cd3cd03f`, 2026-09-25:

| Measurement | Observed |
|---|---|
| Packed read | 171.03 ms |
| Bulk decode | 1,266.53 ms |
| Process wall time, including validation/startup | 6 coarse seconds |
| Maximum sampled process VmHWM | 6,377,172 KiB, about 6.08 GiB |

The wrapper polls Linux `/proc/PID/status` every 50 ms. This high-water
sample is a **lower bound** on peak RSS; `/usr/bin/time` is absent. The sample
includes reading, decoding and validation, not just retained output. Sparse
zero input does not measure checkpoint disk throughput. This is one run,
not a stable benchmark or a whole-model memory forecast.

R10 remains relevant: record selection, callback captures and growing role
stacks may copy large arrays. Eager assembly and full-model inference need
separate memory/time measurement. The synthetic result clears the bulk
primitive feasibility check; it does not prove practical real-model speed.

## Checks and next work

```sh
just tests tests/test_safetensors_loader.mlpl
just check
```

Nine loader tests cover exact spans and values, F32 support, shape/dtype/name
errors, malformed directories, stale-file truncation, finite policy,
projection orientation, resident tied assembly, cache parity and refusal of
untied heads. The full suite has 138 tests, 26 probe outcomes and 21 tangled
library sources.

Next integrate the delivered tokenizer facade and checksum-verified downloads
with pinned artifacts and strict real-golden failure handling. After that,
run an opt-in bounded real-model smoke on CPU if feasible. CUDA remains
blocked by R12 and is not required to test this loader on CPU.
