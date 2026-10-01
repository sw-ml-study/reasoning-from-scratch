#!/bin/sh
# Fixture-only acceptance for unattended session continuation; no model or GPU.
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work/scripts" "$work/out/book-full500-prepared"
cp "$repo/scripts/continue-book-full500" "$work/scripts/"
cat > "$work/scripts/run-book-full500" <<'STUB'
#!/bin/sh
set -eu
[ ! -f out/require-released ] || [ -f out/released ] || exit 9
n=0
[ ! -f out/calls ] || n=$(cat out/calls)
n=$((n+1))
printf '%s\n' "$n" > out/calls
case "$(cat out/mode)" in
  failure) exit 7 ;;
  malformed) printf '{}\n' > out/book-full500-prepared/last-summary.json; exit 0 ;;
  zero) calls=0; complete=0 ;;
  *) calls=1; complete=0; [ "$n" -lt 2 ] || complete=1 ;;
esac
printf '{"run_id":"book-full500-v1","complete":%s,"session_calls":%s,"charged_prior_ms":0,"session_elapsed_ms":1}\n' "$complete" "$calls" > out/book-full500-prepared/last-summary.json
STUB
chmod +x "$work/scripts/run-book-full500"
cd "$work"
printf 'normal\n' > out/mode
scripts/continue-book-full500 > out/normal.log
[ "$(cat out/calls)" = 2 ]
scripts/continue-book-full500 > out/replay.log
[ "$(cat out/calls)" = 2 ]
rm out/book-full500-prepared/last-summary.json out/calls
printf 'zero\n' > out/mode
scripts/continue-book-full500 > out/zero.log
[ "$(cat out/calls)" = 1 ]
rm out/book-full500-prepared/last-summary.json out/calls
printf 'failure\n' > out/mode
if scripts/continue-book-full500 > out/failure.log 2>&1; then echo 'failure retried or hidden' >&2; exit 1; fi
[ "$(cat out/calls)" = 1 ]
rm out/calls
printf 'malformed\n' > out/mode
if scripts/continue-book-full500 > out/malformed.log 2>&1; then echo 'malformed summary accepted' >&2; exit 1; fi
[ "$(cat out/calls)" = 1 ]
rm out/book-full500-prepared/last-summary.json out/calls
touch out/book-full500-control/STOP
scripts/continue-book-full500 > out/stopped.log
[ ! -f out/calls ]
rm out/book-full500-control/STOP
printf '{"run_id":"book-full500-v1","complete":0,"session_calls":1,"charged_prior_ms":172800000,"session_elapsed_ms":1}\n' > out/book-full500-prepared/last-summary.json
scripts/continue-book-full500 > out/budget.log
[ ! -f out/calls ]
# A competing controller must fail before inspecting/dispatching a session.
if (flock -n 9; scripts/continue-book-full500 > out/lock.log 2>&1) 9>out/book-full500-control/lock; then echo 'controller lock ignored' >&2; exit 1; fi
[ ! -f out/calls ]
rm out/book-full500-prepared/last-summary.json
printf 'normal\n' > out/mode
mkdir -p out/book-full500-v1-store
touch out/require-released
(flock -x 8; touch out/held; sleep 1; touch out/released) 8>out/book-full500-v1-store/.lock &
holder=$!
while [ ! -f out/held ]; do sleep 0.01; done
scripts/continue-book-full500 > out/wait.log
wait "$holder"
[ "$(cat out/calls)" = 2 ]
printf 'PASS full500 continuation: completion, replay, no progress, failure, malformed summary, stop, budget, lock\n'
