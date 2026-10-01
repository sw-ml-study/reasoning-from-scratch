# Live full500 progress and failure monitoring

The independent watchdog observes the running frozen experiment every **60
seconds**. MLPL validates immutable record envelopes, request identities and
state transitions without acquiring the writer's lock or reconciling the
journal. It reports completed calls, tokens, caps, errors, interruptions and
the age of an in-flight call. It never reads reference answers or changes
sampling, prompts, voting or mathematical grading.

Run `just book-full500-watch` with the documented interpreter override in a
persistent process. The local dashboard is
`out/book-full500-control/progress.html`; it reloads every minute and displays
its observation timestamp. `progress.json`, `progress-history.jsonl`,
`watch-probe.log` and `watch.log` in that directory provide machine-readable
progress and diagnostics. A second watchdog is rejected by an exclusive lock.
The dashboard refreshes locally; this does not schedule future chat messages.
Chat updates can be sent while the assistant session is active.

The watchdog confirms a suspect observation twice, two seconds apart, then
creates the controller's `STOP` file and terminates positively identified
experiment processes for any of these conditions:

- A backend error or interrupted attempt exists.
- An immutable envelope, filename, request identity or state is invalid, or
  the observer itself fails.
- The controller disappears before completion, or multiple calls are in flight.
- An in-flight call has lasted **600 seconds**.
- No call is in flight and no start/terminal record has appeared for **300 seconds**.

These are operational limits, not a proof that a slow mathematical answer is
wrong. The ten-minute threshold is conservative relative to observed call
latencies but can stop a valid unusually slow call. Such a stop remains an
interruption; there is no automatic retry or revised accuracy denominator.
Token caps and weak mathematical accuracy alone do not trigger a stop.
This user-authorized monitoring policy supplements the original run's
infrastructure controls without altering the frozen generation implementation.

The stop helper verifies the controller's command arguments and repository
working directory before signaling it. It also locates the native journal
owner and requires the exact pinned interpreter executable, repository working
directory and an open descriptor for this experiment's lock. It sends TERM,
then after five seconds sends KILL only to a still-matching native owner.
It never uses process-name-wide kill commands. Any unfinished call is retained
for explicit interruption accounting on a later, non-concurrent recovery.

After an alert, inspect `alert.txt` and `watch-probe.log`. Do not remove `STOP`
or restart automatically. Identify the fault, confirm workers are gone, then
reconcile once and decide whether resumption is justified. A reboot requires
explicit restart of the controller and watchdog; no system service is installed.

`just book-full500-progress` performs one read-only observation and never
signals workers; an unhealthy observation exits nonzero. It shares the
watchdog lock, so use the existing dashboard/log while continuous monitoring
is active. `just check` includes pure MLPL threshold tests and shell fixtures
for completion, dashboard output, observer failure, stop propagation and
protection of unrelated PIDs. Native model inference remains opt-in.

The optional `just book-full500-watch-native-check` uses the pinned interpreter
and store extension to hold an isolated, model-free test journal and verifies
that the scoped helper terminates that native owner. It never targets the live
benchmark store. [Native stop acceptance](results/full500-watch-native-stop.txt),
[shell acceptance](results/full500-watch-shell-tests.txt) and an immutable
[first live snapshot](results/full500-watch-first.json) retain the evidence.
Normal completion, budget exhaustion and a requested boundary stop are displayed
as such, rather than misreported as a disappeared-controller failure.
