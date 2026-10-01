# Resumable book experiment in MLPL

The runner is implemented and the full input set is prepared: **500 cases,
1000 rendered prompts and 2500 immutable request identities**. No full500
model responses had been generated at the freeze. Execution started on
2026-10-01 at 03:09 UTC and is now running; final results remain pending. The published ten-case
scores remain unchanged. [Execution manifest](results/book-full500-v1-execution.json),
[planned keys](results/book-full500-v1-plan.jsonl) and
[prompt hashes](results/book-full500-v1-prompt-hashes.sha256) fix the experiment.

## Responsibilities

MLPL renders the author's attributed prompts, prepares token IDs and seeds,
rotates method groups, reconciles records, schedules unstarted calls, supplies
uniforms, extracts answers, votes, grades and computes all-case denominators.
The existing pinned v3 Rust/CUDA provider performs the forward/selection step.
A separate generic Rust extension provides locked, checksummed durable records.
Neither extension receives reference answers during generation or selection.

The store publishes immutable UTF8 records using a unique same-directory
temporary file, file sync, an atomic no-replace hard link, temporary-link
removal and directory sync. A SHA256 envelope checks record integrity on read.
The run directory has an exclusive nonblocking lock. This implementation
requires Linux local-filesystem locking/link/fsync semantics and storage that
honors flushes; process-crash tests are not physical power-cut tests.
The MLPL `write_atomic` builtin remains unchanged.

Each canonical `(run, case, slot)` has a started record and at most one
terminal record. The start is durably acknowledged **before** dispatch. A
complete response, token IDs, stop reason and timing occupy one atomic
terminal body. Restart consumes valid terminals once and seals unresolved
starts as interrupted. No automatic retry changes the original experiment.
Unexpected names, duplicate identities, hash mismatches, corrupt records and
terminal-before-start transitions abort reconciliation before generation.

Three-sample voting requires all three successful terminal responses. A
backend error or interruption cannot become a vote over only the survivors.
All 500 cases remain in every method denominator. Partial planned-case
scores are explicitly incomplete; full-set paired gains/losses are withheld
until every planned call has a terminal accounting status. Backend failures
remain distinguishable from incorrect mathematical answers.

## Acceptance evidence

Five native MLPL journal tests cover canonical planning, transitions,
interruption recovery, duplicates/hash mismatches, malformed terminals and
all-case denominators. The timed decoder's fixture preserves token identity
with the existing native adapter. Four Rust tests include lock contention,
immutable publication, corruption/symlink rejection and child-process aborts
at three persistence boundaries.

The native integration suite exercises partial progress, resume, zero-call
replay, unchanged terminal hashes, a crash after durable start, a provider
error, duplicate files and corruption. Its authored two-case responder yields
one interrupted and one error slot; voting keeps both cases in the denominator
and marks the incomplete sample group ineligible. This is a software fixture,
not a language-model quality result. See [recovery evidence](results/full500-recovery-fixture.json)
and [acceptance log](results/full500-store-acceptance.txt).

A CUDA smoke uses two authored arithmetic questions and a **64-token** cap:
all ten calls complete without backend errors in 30.89s including a 6.16s
load; 501 tokens are generated and six calls hit the cap. Its method counts
are 2/2 direct, 1/2 CoT, 1/2 vote. The short cap makes this a plumbing test,
not the book-quality comparison. [Summary](results/full500-cuda-smoke-summary.json)
and [method records](results/full500-cuda-smoke-methods.jsonl) retain the results.
Production retains the frozen 2048-token cap and earlier long-context parity.

## Run and resume

```sh
export MLPL=/disk1/tmp/reasoning-tools/build-49c15b3e/release/mlpl-repl
# On a fresh checkout with the pinned model/data/native artifacts available:
just book-full500-prepare
# Validate/reconcile all planned identities, without dispatching a model call:
just book-full500 --reconcile
# Run a session, normally stopping between calls after 15 minutes:
just book-full500
# A longer session, or a bounded number of new calls:
BOOK_WALL_MS=3600000 BOOK_MAX_CALLS=25 just book-full500
# Optional persistence fixtures; no GPU or downloaded questions:
just book-full500-store-check
```

Preparation refuses to overwrite an existing prepared manifest. Generation
requires committed execution pins and verifies all source/input/native hashes.
Run the same command to resume the same store. Changing the provider, source,
controls or prepared inputs requires a new execution/run identity, not editing
the existing store. The runner disables the optional external source facade
and verifies the actual interpreter/tokenizer binaries used.

Default store: ignored `out/book-full500-v1-store/`. Immutable records are the
source of truth. Session logs, sampled GPU memory/host high-water marks and
regenerable `last-summary.json`/`last-methods.jsonl` live under the prepared
directory. Losing a derived report does not lose completed attempts. SIGINT
or a reboot during a call leaves that call explicitly interrupted on resume.
Reference answers never decide whether an attempt is considered complete.

The 48-hour cumulative budget is checked **between calls**, so the final call
may overrun the target. Completed sessions record monotonic elapsed time. A
session without an end record is conservatively charged wall time through
recovery, including downtime, then sealed; this may exhaust the budget early.
There is no 120-second per-call cutoff. A separate 48-hour infrastructure
ceiling prevents an indefinitely running decoder from claiming success.
A stopped session can leave the experiment incomplete; report that status.

## Timing and remaining scope

The first-ten run produced 23484 tokens. Scaling only that token count by50
and dividing by measured native throughput13.28–21.33 tokens/s gives roughly
**15.3–24.6 hours**, before distribution differences and overhead. This is a
planning range, not a prediction. All2500 calls reaching2048 tokens would
require about107 hours at13.28 tokens/s, beyond the selected budget. We must
measure actual progress and preserve the denominator if the budget runs out.

The timed MLPL adapter reports first-step/prefill and subsequent native-step
time. Both include native selection; separate per-call sampling time is
**unavailable**, not silently reported as zero. Load and whole-session times
are separate. Resource sampling is approximate, not an allocation trace.
A same-hardware Python experiment still does not exist, so no Python speedup
ratio is claimed.

The [transport/graph probe](cuda-transport.md) motivates fewer host launches,
but is not adopted as a Qwen optimization. Native language-model training
and verifier coverage beyond bounded linear equivalence remain separate work.

The store source handoff is `/disk1/tmp/reasoning-tools/durable-store` and its
archive is `/disk1/tmp/reasoning-tools/durable-store-source.tar.gz`. Build with
`cargo test --release --locked --offline`, then `cargo build --release --locked
--offline`. [Native hashes](results/full500-native-artifacts.sha256) pin source
and library. Publication as an installable sibling extension remains separate;
no sibling or stable installed tool was modified.

## Unattended continuation

`just book-full500-continue` runs successive 15-minute sessions using the
unchanged frozen runner. It holds a controller lock, stops at completion or
the cumulative budget, and stops immediately on failed sessions, malformed
summaries or zero new calls. It does not automatically retry a failed session.
Fixture-only controller acceptance is part of `just check`.

Run in a persistent terminal or managed long-running process, from the repository
root with the documented `MLPL` set:

```sh
mkdir -p out/book-full500-control
just book-full500-continue > out/book-full500-control/controller.log 2>&1
```

The controller PID is recorded in `out/book-full500-control/pid`. Create
`out/book-full500-control/STOP` to request a stop after the current session;
remove that file only when intentionally resuming. Do not start a manual
runner or reconciliation while a session is live: the native store rejects
concurrent access. After a failed session, inspect its log before deciding
whether to reconcile and resume; interrupted calls retain their original
accounting. Reboot recovery is explicit, not an installed system service.

If a manually launched session already holds the native store lock, the
controller first waits up to 30 minutes for that session to finish. It releases
that lock before invoking MLPL. This initial wait is tested separately from
the controller lock; it never reconciles or modifies an active worker's journal.

## Periodic health supervision

The user-authorized [watchdog](book-full500-watchdog.md) independently checks
live immutable records every minute. It maintains a readable local dashboard
and stops verified experiment processes on confirmed backend errors, corruption
or conservative stall thresholds. Generation/source pins remain unchanged;
watchdog termination becomes explicit interruption accounting, never a retry.
