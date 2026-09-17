# Licensing and provenance policy

This repository is Copyright (c) 2026 Michael A Wright and is distributed
under the [MIT License](../LICENSE), byte-for-byte identical to the peer
repositories (`../demo-mlpl-libraries`, `../demo-ml-microscope`,
`../demo-ml-utils`). `scripts/check-structure` enforces the identity.

## The book and its companion code are references, not sources

The project follows the method sequence of Sebastian Raschka's
*Build a Reasoning Model (From Scratch)* (Manning, 2026, ISBN 9781633434677)
and uses the companion repository
<https://github.com/rasbt/reasoning-from-scratch> (a local clone lives at
`~/github/rasbt/reasoning-from-scratch`) as a behavioral reference.

Rules that every step must respect:

1. **No code is copied** from the companion repository, in any language.
   Every `.mlpl` file here is written from the method description, the
   published formulas, and this repository's own specifications.
2. **No prose is copied** from the book PDF (kept locally under the ignored
   `work/` directory). Documentation paraphrases methods, cites chapter
   numbers, and records published hyperparameters and result tables as
   facts. Prompt templates are written in this project's own words; only the
   structural elements the method depends on (a boxed final answer, think
   tags, a critique followed by a revision) are preserved.
3. **Behavioral test values are allowed.** Expected input/output pairs such
   as "an answer of `0.5` matches a reference of `1/2`" describe the method's
   contract, not its implementation, and are used as language-neutral
   acceptance cases with attribution in the test file comment.
4. `scripts/check-sources` rejects tracked Python or notebook files and any
   tracked file whose bytes are identical to a file in the reference clone.

## Why the project stays MIT and is not dual-licensed

The companion code is Apache-2.0 (Copyright 2025-2026 Sebastian Raschka, no
NOTICE file). Apache-2.0 obligations (retaining the license text, marking
modified files, carrying notices) attach to derivative works, meaning copies
or ports of substantial portions of the code. An independent implementation
in a different language, written from the method description and verified
only against published behavior, is not a derivative work of that code, so
no Apache obligation attaches and no dual license is required.

That conclusion holds only while rule 1 holds. If a future step ever needs to
port a specific routine from the reference implementation rather than
re-derive it, that step must stop, record the request in
[`docs/sw-mlpl-blockers.md`](sw-mlpl-blockers.md) or the saga summary, and
obtain an explicit licensing decision before proceeding. Attribution to the
book and its author is given in the README as a courtesy, not as a license
requirement.

## Third-party artifacts are downloaded, never committed

| Artifact | Source | License | Local location |
|---|---|---|---|
| Qwen3-0.6B-Base weights (`model.safetensors`, bf16, 1.19 GB), `tokenizer.json` (7.0 MB), `config.json` | <https://huggingface.co/Qwen/Qwen3-0.6B-Base> | Apache-2.0 | ignored `models/qwen3-0.6b-base/` |
| Qwen3-0.6B reasoning variant (optional reference model) | <https://huggingface.co/Qwen/Qwen3-0.6B> | Apache-2.0 | ignored `models/qwen3-0.6b/` |
| MATH-500 evaluation set (500 problems) | <https://huggingface.co/datasets/HuggingFaceH4/MATH-500> (derived from OpenAI PRM800K / Hendrycks MATH) | per dataset card; verify at download time | ignored `data/math500/` |
| MATH training split minus MATH-500 (12,000 problems) | <https://github.com/rasbt/math_full_minus_math500> | Apache-2.0 (derived from Hendrycks MATH) | ignored `data/math-train/` |
| Teacher reasoning traces (optional) | <https://huggingface.co/datasets/rasbt/math_distill> | not confirmed on 2026-09-16; must be verified before use | ignored `data/distill/` |

Download scripts print the license of what they fetch and never run inside
`just check`. Tiny deterministic fixtures authored in this repository (a few
hand-written problems, a synthetic tokenizer, a synthetic safetensors file)
are the only test data committed.
