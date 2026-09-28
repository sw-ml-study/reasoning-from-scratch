#!/bin/sh
# Exercise the real wrapper's missing-data, status propagation and Linux memory accounting without a model or network.
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/scripts" "$work/models/qwen3-0.6b-base" "$work/bin"
cp "$repo/scripts/run-real-model-smoke" "$work/scripts/"
status=0
"$work/scripts/run-real-model-smoke" > "$work/log" 2>&1 || status=$?
[ "$status" -eq 77 ] || { echo 'missing smoke data must return 77' >&2; exit 1; }
status=0
"$work/scripts/run-real-model-smoke" extra > "$work/log" 2>&1 || status=$?
[ "$status" -eq 2 ] || exit 1
for file in tokenizer.json config.json model.safetensors; do touch "$work/models/qwen3-0.6b-base/$file"; done
cat > "$work/bin/sha256sum" <<'EOF'
#!/bin/sh
exit "${FAKE_HASH_STATUS:-0}"
EOF
cat > "$work/scripts/select-mlpl" <<'EOF'
#!/bin/sh
echo /bin/true
EOF
cat > "$work/scripts/run-extension-demo" <<'EOF'
#!/bin/sh
sleep 0.2
exit 7
EOF
chmod +x "$work/bin/sha256sum" "$work/scripts/select-mlpl" "$work/scripts/run-extension-demo"
status=0
PATH="$work/bin:$PATH" "$work/scripts/run-real-model-smoke" > "$work/log" 2>&1 || status=$?
[ "$status" -eq 7 ] || { cat "$work/log"; exit 1; }
awk '/sampled process VmHWM KiB:/ {found=1; if ($5 <= 0) exit 1} END {if (!found) exit 1}' "$work/log"
status=0
FAKE_HASH_STATUS=1 PATH="$work/bin:$PATH" "$work/scripts/run-real-model-smoke" > "$work/log" 2>&1 || status=$?
[ "$status" -eq 1 ] || exit 1
if grep -q 'process exit status' "$work/log"; then echo 'inference ran despite hash failure' >&2; exit 1; fi
echo 'PASS smoke wrapper checks'
