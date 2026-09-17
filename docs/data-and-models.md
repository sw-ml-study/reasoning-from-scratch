# Data, models, and local layout

Nothing large is committed. The gate runs on committed fixtures only; real
weights and datasets are opt-in and live in ignored directories.

```text
models/qwen3-0.6b-base/   model.safetensors, tokenizer.json, config.json
models/qwen3-0.6b/        optional reasoning variant for comparison runs
data/math500/             math500 test set as JSON or JSONL
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

## Getting the artifacts

```sh
just fetch-model       # Qwen3-0.6B-Base safetensors + tokenizer (Apache-2.0)
just fetch-math500     # evaluation set
just fetch-math-train  # 12,000-problem training split
```

Each recipe delegates to `scripts/fetch-*`, uses `curl`, prints the license
of what it downloads, checks the byte size against the published size, and
refuses to overwrite an existing file. The recipes are introduced by the saga
step that first needs the artifact.
