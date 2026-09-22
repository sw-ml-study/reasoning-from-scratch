#!/bin/sh
# Host-tool discovery must honor explicit paths and reject incompatible CLIs.
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
printf '#!/bin/sh\nexit 0\n' > "$work/formatter"
chmod +x "$work/formatter"
cp "$work/formatter" "$work/bin/mlpl-fmt"
actual=$(MLPLFMT="$work/formatter" "$repo/scripts/select-mlplfmt")
[ "$actual" = "$work/formatter" ]
actual=$(unset MLPLFMT; PATH="$work/bin:$PATH" "$repo/scripts/select-mlplfmt")
[ "$actual" = "$work/bin/mlpl-fmt" ]
if MLPLFMT=relative "$repo/scripts/select-mlplfmt" >"$work/error" 2>&1; then
    echo 'relative formatter override was accepted' >&2; exit 1
fi
if MLPLFMT="$work/absent" "$repo/scripts/select-mlplfmt" >"$work/error" 2>&1; then
    echo 'missing formatter override was silently ignored' >&2; exit 1
fi
printf '#!/bin/sh\necho "old CLI: no sandbox option"\n' > "$work/old-mlpl"
chmod +x "$work/old-mlpl"
if MLPL="$work/old-mlpl" "$repo/scripts/run-capability-probes" >"$work/error" 2>&1; then
    echo 'incompatible interpreter was accepted' >&2; exit 1
fi
grep -q 'incompatible interpreter' "$work/error"
echo 'PASS tooling checks'
