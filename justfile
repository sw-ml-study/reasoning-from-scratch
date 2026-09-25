set shell := ["sh", "-cu"]

# Show available repository tasks.
default:
    @just --list

# Check canonical formatting and module comments for tracked MLPL source.
mlpl-style:
    ./scripts/check-mlpl-style

# Run native mlplunit tests; arguments select paths, tags, or filters.
tests *args:
    ./scripts/run-tests {{args}}

# Enforce the no-copied-code and no-Python provenance policy.
sources:
    ./scripts/check-sources

# Print the selected sw-MLPL interpreter and mlplunit runner.
tools:
    ./scripts/select-mlpl
    ./scripts/select-mlplunit
    ./scripts/select-mlplfmt

# Grade every MATH-500 reference answer against itself (needs fetch-math500).
math500-self-grade:
    ./scripts/run-math500-self-grade

# Download the Qwen3-0.6B-Base tokenizer and config (opt-in, not in check).
fetch-model:
    ./scripts/fetch-model

# Download the MATH-500 evaluation set into ignored data/ (opt-in, not in check).
fetch-math500:
    ./scripts/fetch-math500

# Compare the MLPL reference tokenizer with the native extension (opt-in).
tokenizer-parity:
    ./scripts/run-tokenizer-parity

# Prove docs/reasoning.org tangles back to every committed library source.
tangle:
    ./scripts/check-tangle

# Narrated cached generation on the tiny model.
generation-demo:
    ./scripts/run-generation-demo

# Narrated probabilities, answer masking, entropy and tiny-model scoring.
scoring-demo:
    ./scripts/run-scoring-demo

# Narrated best-of-N and bounded refinement over scripted responses.
refinement-demo:
    ./scripts/run-refinement-demo

# Narrated verifier and harness walk-through over committed fixtures.
verifier-demo:
    ./scripts/run-verifier-demo

# Print the upstream commits, interpreter build, and extension/library signals.
upstream:
    ./scripts/check-upstream

# Run the capability probes and compare with the declared expectations.
capabilities:
    ./scripts/run-capability-probes

# Opt-in CUDA matrix smoke; rejects CPU fallback (not part of the fixture gate).
cuda-probe:
    ./scripts/run-cuda-probe

# Measure bounded synthetic bulk decoding (opt-in; no real weights).
unpack-benchmark:
    ./scripts/run-unpack-benchmark

# Run the complete precommit gate.
check:
    ./scripts/check
