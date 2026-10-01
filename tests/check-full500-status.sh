#!/bin/sh
# Terminal viewer fixtures: no interpreter, GPU, writer locks or process signals.
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work/scripts" "$work/out/book-full500-control"
cp "$repo/scripts/book-full500-status" "$work/scripts/"
cd "$work"
for arg in 0 -1 1.5 abc 86401; do
    if scripts/book-full500-status "$arg" > out/invalid.log 2>&1; then echo 'invalid cadence accepted' >&2; exit 1; fi
done
if scripts/book-full500-status --once > out/missing.log 2>&1; then echo 'missing snapshot accepted' >&2; exit 1; fi
now=$(date +%s)
jq -n --argjson now "$now" '{run_id:"book-full500-v1",unix_seconds:$now,status:"running",accounting:{planned_calls:2500,successes:250,errors:0,interrupted:0},tokens:12345,capped:3}' > out/book-full500-control/progress.json
jq -cn --argjson now "$now" '{run_id:"book-full500-v1",unix_seconds:($now-7200),accounting:{successes:100,errors:0,interrupted:0}}, {run_id:"book-full500-v1",unix_seconds:($now-3600),accounting:{successes:150,errors:0,interrupted:0}}' > out/book-full500-control/progress-history.jsonl
# The writer can be in the middle of appending the last line; ignore only that fragment.
printf '{"partial":' >> out/book-full500-control/progress-history.jsonl
mkdir -p out/book-full500-prepared
cat > out/book-full500-prepared/last-methods.jsonl <<'ROWS'
{"index":0,"method":2,"eligible":1,"correct":1}
{"index":0,"method":1,"eligible":1,"correct":1}
{"index":0,"method":0,"eligible":1,"correct":0}
{"index":1,"method":0,"eligible":1,"correct":1}
{"index":1,"method":1,"eligible":1,"correct":1}
{"index":1,"method":2,"eligible":1,"correct":0}
{"index":2,"method":0,"eligible":1,"correct":0}
{"index":2,"method":1,"eligible":1,"correct":1}
{"index":2,"method":2,"eligible":0,"correct":0}
ROWS
scripts/book-full500-status --once > out/healthy.log
grep -q '10.0% complete (250/2500 attempts)' out/healthy.log
grep -q '22.5 hours remaining' out/healthy.log
grep -q '100.0 calls/hour' out/healthy.log
grep -q 'same 2/500 cases' out/healthy.log
grep -q 'Direct: 1/2 (50%) | CoT: 2/2 (100%) | Vote: 1/2 (50%)' out/healthy.log
grep -q 'CoT vs direct: 1 gains, 0 losses' out/healthy.log
grep -q 'Vote vs CoT: 0 gains, 1 losses' out/healthy.log
echo ALERT > out/book-full500-control/alert.txt
scripts/book-full500-status --once > out/alert.log
grep -q 'ETA unavailable' out/alert.log
rm out/book-full500-control/alert.txt
jq '.unix_seconds -= 600' out/book-full500-control/progress.json > out/stale.json
mv out/stale.json out/book-full500-control/progress.json
scripts/book-full500-status --once > out/stale.log
grep -q 'STALE' out/stale.log
grep -q 'ETA unavailable' out/stale.log
jq --argjson now "$now" '.unix_seconds=$now | .accounting.errors=10 | .accounting.interrupted=5' out/book-full500-control/progress.json > out/failed.json
mv out/failed.json out/book-full500-control/progress.json
scripts/book-full500-status --once > out/failed.log
grep -q '10.6% complete (265/2500 attempts)' out/failed.log
grep -q 'ETA unavailable' out/failed.log
jq '.accounting.successes=2500 | .accounting.errors=0 | .accounting.interrupted=0 | .status="complete"' out/book-full500-control/progress.json > out/done.json
mv out/done.json out/book-full500-control/progress.json
scripts/book-full500-status --once > out/done.log
grep -q '100.0% complete' out/done.log
grep -q 'ETA: finished' out/done.log
status=0
timeout 2.2 scripts/book-full500-status 1 > out/continuous.log 2>&1 || status=$?
[ "$status" = 124 ]
[ "$(grep -c 'Full500:' out/continuous.log)" -ge 2 ]
grep -q 'Ctrl-C stops this viewer only' out/continuous.log
printf '{}\n' > out/book-full500-control/progress.json
if scripts/book-full500-status --once > out/bad.log 2>&1; then echo 'invalid snapshot accepted' >&2; exit 1; fi
[ ! -f out/book-full500-control/STOP ]
echo 'PASS terminal progress: percentage, trailing-hour ETA, partial append, stale/error/complete/missing states and cadence'
