#!/bin/sh
# No weights or GPU: amendments may change only the documented grader paths.
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
cd "$work"
mkdir -p lib/verify scripts
printf 'generation\n' > generation
printf 'old\n' > lib/verify/number.mlpl
sha256sum generation lib/verify/number.mlpl > old
printf 'new\n' > lib/verify/number.mlpl
cp "$repo/scripts/check-grading-amendment" scripts/check-grading-amendment
sha256sum generation lib/verify/number.mlpl scripts/check-grading-amendment > new
sh scripts/check-grading-amendment old new >/dev/null
cp new valid
printf 'changed generation\n' > generation
sha256sum generation lib/verify/number.mlpl scripts/check-grading-amendment > new
if sh scripts/check-grading-amendment old new >/dev/null 2>&1; then exit 1; fi
cp valid new
if sh scripts/check-grading-amendment old new >/dev/null 2>&1; then exit 1; fi
printf 'generation\n' > generation
cat valid >> new
if sh scripts/check-grading-amendment old new >/dev/null 2>&1; then exit 1; fi
sed '/generation/d' valid > new
if sh scripts/check-grading-amendment old new >/dev/null 2>&1; then exit 1; fi
printf 'PASS grading amendment: scoped changes, generation drift, hash mismatch, duplicates, omissions\n'
