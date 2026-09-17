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

# Run the complete precommit gate.
check:
    ./scripts/check
