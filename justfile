set shell := ["sh", "-cu"]

# Show available repository tasks.
default:
    @just --list

# Opt-in CUDA kernel/driver/context trace; NSYS selects an isolated CLI.
cuda-trace name="cuda-trace-live":
    ./scripts/run-cuda-trace {{name}}

# Retry the previously truncated case with a larger bounded development budget (opt-in).
reasoning-budget:
    ./scripts/run-native-budget

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

# Measure a full embedding-size synthetic allocation (opt-in; several GiB RAM).
unpack-embedding-benchmark:
    ./scripts/run-unpack-embedding-benchmark

# Run the complete precommit gate.
check:
    ./scripts/check

# Opt-in bounded real Qwen CPU smoke; fetch-model --weights must run first.
real-model-smoke:
    ./scripts/run-real-model-smoke

# Opt-in authored-fixture stage and call-scope timing; no real weights.
loader-profile:
    ./scripts/run-loader-profile

# Live pretrained Qwen3 8B answer through the Rust HTTP extension and local GPU backend.
reasoning-demo:
    ./scripts/run-native-reasoning one

# Five authored cases, thinking off/on; opt-in, not a held-out benchmark.
reasoning-eval:
    ./scripts/run-native-reasoning eval

# Frozen six-problem MATH-500 pilot, two seeds and two modes; opt-in local data.
reasoning-pilot:
    ./scripts/run-native-reasoning pilot

# Export the standalone research HTML without inference or Babel execution.
research-html:
    ./scripts/export-reasoning-report

# Replay eight offline ob-mlpl calculations and refresh the publication.
research-refresh:
    ./scripts/export-reasoning-report --refresh

# Run the pinned in-process Rust CUDA prototype on the real base checkpoint.
cuda-reasoning:
    ./scripts/run-cuda-reasoning

# Validate native GPU logits and cache against the tiny MLPL reference (opt-in).
cuda-parity:
    ./scripts/run-cuda-parity

# Independent real-checkpoint MLPL versus CUDA validation (slow, opt-in).
cuda-real-parity:
    ./scripts/run-cuda-real-parity

# Frozen 12-case, 144-generation book pilot; requires committed execution pins.
book-cuda:
    ./scripts/run-book-cuda

# Authored integration smoke, never counted in the frozen pilot.
book-cuda-smoke:
    ./scripts/run-book-cuda --smoke

# Book-compatible first-ten demonstration (50 calls), with frozen execution pins.
book-author:
    ./scripts/run-book-author

# Five-call authored integration smoke for the book-compatible MLPL tooling.
book-author-smoke:
    ./scripts/run-book-author --smoke

# Recompute the published first-ten metrics in MLPL without model inference.
book-author-report:
    mkdir -p out
    ./scripts/run-mlpl-demo demos/book_author_report.mlpl

# Fixed-input CUDA/selection profiling; opt-in, never part of the fixture gate.
cuda-profile mode="stages":
    ./scripts/run-cuda-profile {{mode}}

# Recompute paired performance summaries from public numeric evidence.
cuda-profile-report:
    ./scripts/run-mlpl-demo demos/cuda_profile_report.mlpl

# Render all author-ordered prompts and immutable request identities; no inference.
book-full500-prepare:
    ./scripts/prepare-book-full500

# Resume the frozen full500 experiment (default: a 15-minute session, stops between calls).
book-full500 *args:
    ./scripts/run-book-full500 {{args}}

# Opt-in native persistence/recovery fixtures; no GPU or downloaded dataset.
book-full500-store-check:
    ./scripts/check-full500-store

# Continue the frozen experiment unattended in bounded sessions (opt-in).
book-full500-continue:
    ./scripts/continue-book-full500

# Observe live progress every minute and stop verified experiment processes on failure.
book-full500-watch:
    ./scripts/watch-book-full500

# Read-only live check: alerts, but never signals a worker.
book-full500-progress:
    ./scripts/watch-book-full500 --once

# Optional model-free native stop acceptance; requires the pinned durable-store extension.
book-full500-watch-native-check:
    ./scripts/check-watch-native-stop

# Read-only terminal progress, ETA and provisional reasoning results; default every 10 minutes.
book-full500-status *args:
    ./scripts/book-full500-status {{args}}
