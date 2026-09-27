#!/bin/sh
# Extension discovery is deterministic and invalid overrides never silently fall back.
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
cat > "$work/bin/uname" <<'EOF'
#!/bin/sh
case "$1" in -s) echo Linux ;; -m) echo x86_64 ;; *) exit 1 ;; esac
EOF
chmod +x "$work/bin/uname"
PATH="$work/bin:$PATH"
export PATH
mkdir -p "$work/extensions/hftok/native/x86_64-unknown-linux-gnu" "$work/target/debug"
touch "$work/extensions/hftok/native/x86_64-unknown-linux-gnu/libmlpl_extension_hftok.so" "$work/target/debug/libmlpl_extension_hftok.so"
actual=$(EXTENSIONS_ROOT="$work" "$repo/scripts/select-extension" hftok)
[ "$actual" = "$work/extensions/hftok/native/x86_64-unknown-linux-gnu/libmlpl_extension_hftok.so" ]
actual=$(HFTOK_LIBRARY="$work/target/debug/libmlpl_extension_hftok.so" "$repo/scripts/select-extension" hftok)
[ "$actual" = "$work/target/debug/libmlpl_extension_hftok.so" ]
if HFTOK_LIBRARY="$work/missing" "$repo/scripts/select-extension" hftok >/dev/null 2>&1; then
    echo 'missing override accepted' >&2; exit 1
fi
if HFTOK_LIBRARY=relative "$repo/scripts/select-extension" hftok >/dev/null 2>&1; then
    echo 'relative override accepted' >&2; exit 1
fi
if EXTENSIONS_ROOT="$work/missing" "$repo/scripts/select-extension" http >/dev/null 2>&1; then
    echo 'missing package accepted' >&2; exit 1
fi
echo 'PASS extension discovery'
if TOKENIZER_PATH="$work/absent-tokenizer" "$repo/scripts/run-tokenizer-parity" >/dev/null 2>&1; then
    echo 'missing real data passed parity' >&2; exit 1
else
    [ "$?" -eq 77 ]
fi
