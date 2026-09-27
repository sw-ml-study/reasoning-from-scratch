# Data, models, and local layout

Nothing large is committed. The gate runs on committed fixtures only; real
weights and datasets are opt-in and live in ignored directories.

```text
models/qwen3-0.6b-base/   model.safetensors, tokenizer.json, config.json
models/qwen3-0.6b/        optional reasoning variant for comparison runs
data/math500/             math500 test set as JSONL (the JSON parser rejects arrays of objects)
data/math-train/          12,000-problem training split minus MATH-500
data/distill/             teacher traces (downloaded or generated locally)
out/                      generated evaluations, metrics CSV, checkpoints
```

## Model facts used by the implementation

Measured from the published `config.json` on 2026-09-16:

| Field | Value |
|---|---|
| vocabulary | 151,936 |
| hidden size | 1,024 |
| layers | 28 |
| attention heads / key-value heads | 16 / 8 |
| head dimension | 128 |
| feed-forward size | 3,072 |
| activation | SiLU (SwiGLU gate/up/down) |
| RMSNorm epsilon | 1e-6 |
| RoPE base | 1,000,000 |
| tied word embeddings | yes (no separate output-head tensor in the file) |
| dtype on disk | bfloat16 |
| end-of-text / eos id | 151643 |

Chat-control ids that matter later: `<|im_start|>` 151644, `<|im_end|>`
151645, `<think>` 151667, `</think>` 151668. The base model is prompted
without a chat template; the reasoning variant wraps the prompt in the chat
template and ends turns with `<|im_end|>`.

Weight tensor names follow the Hugging Face layout: `model.embed_tokens`,
`model.layers.N.self_attn.{q,k,v,o}_proj`, `model.layers.N.self_attn.{q,k}_norm`,
`model.layers.N.input_layernorm`, `model.layers.N.post_attention_layernorm`,
`model.layers.N.mlp.{gate,up,down}_proj`, and `model.norm`. Projections have
no bias.

## Sizes that drive feasibility decisions

| Quantity | Value |
|---|---|
| parameters | about 0.6 billion (596 M) |
| weights on disk (bf16) | 1.19 GB |
| weights as f64 arrays in the interpreter | about 4.8 GB |
| embedding / output matrix alone | 151,936 x 1,024 = 155.6 M values |
| one layer's projections | 2 x 1024x2048 + 2 x 1024x1024 + 3 x 1024x3072 = 15.7 M values |
| development machine | Apple M1 Max, 10 cores, 64 GB unified memory |

The interpreter stores every array as f64, so the full model fits in memory
with room for activations, but each intermediate the size of the embedding
matrix costs another 1.2 GB. Saga 3 measures load time, resident memory, and
tokens per second before any evaluation is attempted; those numbers decide
whether the MLX path or a compiled path must be requested upstream.

## Loading datasets in MLPL

`lib/eval/data.mlpl` (prefix `u:eval_`) is the only dataset entry point.
It validates JSONL text line by line under explicit budgets (`max_bytes`,
`max_records`, `max_line_bytes`), checks the record schema (`problem` and
`answer` strings required; `solution`, `subject`, `unique_id` optional
strings; `level` an optional number or string), and returns a dataset record
`{source, lines, count}` or a classified error `{kind, line, field, message}`
with kinds `io`, `budget`, `parse`, `type`, `missing_field`, and `index`.

Records are kept as validated JSONL lines and parsed on access with
`u:eval_record(dataset, i)`, because the language has string lists and
numeric arrays but no incremental list of records. `u:eval_slice` returns a
contiguous, clamped sub-dataset in the original order for bounded runs.

`parse_json` rejects arrays of objects by design, so JSON-array files (the
12,000-problem training split is published that way) go through
`u:eval_split_json_array`, an interpreted character scanner bounded by a
1 MiB default budget. For the full training split, the fetch recipe will
convert the array to JSONL outside MLPL or raise the budget deliberately;
that decision is measured in the step that adds the recipe.

The committed fixtures under `fixtures/math/` are five hand-authored
problems in both forms plus four adversarial files (missing field, duplicate
key, wrong type, non-object line).

## Getting the artifacts

```sh
just fetch-math500     # evaluation set, 446,564 bytes of JSONL
just fetch-model       # pinned tokenizer + configuration
scripts/fetch-model --weights # also fetch 1.19 GB safetensors, explicitly opt-in
just fetch-math-train  # 12,000-problem training split (later step)
```

The model and MATH-500 recipes use the pinned public HTTP extension facade.
They print provenance, verify byte length and SHA-256 from
[`catalog/artifacts.jsonl`](../catalog/artifacts.jsonl), and reuse a matching
cached file. A replacement is installed only after verification. Transfers
have explicit resource limits; see [integration details](extension-integration.md).
Neither downloads nor real inference run inside `just check`. The training
split recipe remains unavailable. Follow the [Org/Babel usage guide](using-reasoning-model.org)
for tested commands and the outstanding real-model viability check.
