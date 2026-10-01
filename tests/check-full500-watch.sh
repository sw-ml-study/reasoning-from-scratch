#!/bin/sh
# Watchdog orchestration and process-scope fixtures; never touches a real model or store.
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
controller=
unrelated=
trap 'if [ -n "$controller" ]; then kill "$controller" 2>/dev/null || true; fi; if [ -n "$unrelated" ]; then kill "$unrelated" 2>/dev/null || true; fi; rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work/scripts" "$work/out/book-full500-control" "$work/out/book-full500-v1-store"
cp "$repo/scripts/watch-book-full500" "$repo/scripts/stop-book-full500" "$work/scripts/"
cat > "$work/scripts/run-mlpl-demo" <<'STUB'
#!/bin/sh
set -eu
status=$(cat out/mock-status)
[ "$status" != observer_error ] || exit 2
printf '{"status":"%s","accounting":{"successes":12,"pending":2488,"errors":0,"interrupted":0},"tokens":345,"capped":1,"inflight":1,"call_age_seconds":10}\n' "$status" > "$WATCH_REPORT"
STUB
cat > "$work/scripts/continue-book-full500" <<'STUB'
#!/bin/sh
trap 'echo stopped > out/stopped; exit 0' TERM
while :; do sleep 1; done
STUB
chmod +x "$work/scripts/"*
cd "$work"
sleep 120 &
unrelated=$!
printf '%s\n' "$unrelated" > out/book-full500-control/pid
printf 'running\n' > out/mock-status
scripts/watch-book-full500 --once > out/healthy.log
[ ! -f out/book-full500-control/STOP ]
grep -q 'Successful calls: 12 / 2500' out/book-full500-control/progress.html
# An unrelated PID is never signaled, even when explicitly recorded as the controller.
scripts/stop-book-full500 > out/unrelated.log
kill -0 "$unrelated"
rm out/book-full500-control/STOP
scripts/continue-book-full500 &
controller=$!
printf '%s\n' "$controller" > out/book-full500-control/pid
printf 'backend_error\n' > out/mock-status
if scripts/watch-book-full500 > out/error.log; then echo 'error did not stop monitoring' >&2; exit 1; fi
[ -f out/book-full500-control/STOP ]
[ -f out/stopped ]
wait "$controller"
controller=
kill -0 "$unrelated"
grep -q 'ALERT backend_error' out/book-full500-control/alert.txt
# Corrupt/failed observation must be visible rather than leaving a healthy dashboard.
printf 'observer_error\n' > out/mock-status
if scripts/watch-book-full500 --once > out/observer.log; then echo 'observer failure hidden' >&2; exit 1; fi
grep -q 'observer_error' out/book-full500-control/progress.html
printf 'complete\n' > out/mock-status
scripts/watch-book-full500 --once > out/complete.log
printf 'PASS watchdog dashboard, complete/error paths, stop propagation and unrelated-PID protection\n'
