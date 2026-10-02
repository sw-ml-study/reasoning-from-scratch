# Full500 execution progress

**Current status: completed.** See the [final 500-case results](book-full500-results.md).
The first-session snapshot below is retained as historical evidence only.

**Historical first-session snapshot; incomplete at that time.** The frozen `book-full500-v1` experiment had started.
This snapshot covers the first bounded session, beginning 2026-10-01 03:09 UTC.
Continuation runs the remaining unstarted requests with unchanged model,
provider, prompts, seeds and decoding limits. See the
[protocol](book-full500-protocol.md) and [runner](book-full500-runner.md).

| First-session measurement | Value |
|---|---:|
| Calls with successful terminal records | 38 / 2500 |
| Pending calls | 2462 |
| Backend errors / interruptions | 0 / 0 |
| Generated tokens | 16924 |
| Token-capped responses | 3 |
| Session elapsed | 930.392 seconds |
| Model/tokenizer loading | 6.327 seconds |
| Prefill steps including selection | 5.158 seconds |
| Decode steps including selection | 912.708 seconds |
| Throughput including session overhead | 18.2 tokens/second |
| Sampled GPU memory peak | 2403 MiB |
| Sampled host high-water mark | 1782728 KiB |

Decode accounts for about 98% of the measured session. Native selection is
included in the step times; it is not separately measured here. Host wall
spans include launch/transfer/wait overhead, so this does not establish 98%
GPU kernel utilization. Memory is sampled every two seconds and is approximate;
GPU figures cover the device, including other resident allocations. Fixture
checks ran on the CPU during part of the session. This is operational timing,
not a controlled same-hardware Python comparison.

| Method | Cases with all required responses | Correct answers recorded | Planned denominator |
|---|---:|---:|---:|
| Direct | 7 | 2 | 500 |
| Greedy chain of thought | 8 | 3 | 500 |
| Three-sample vote | 7 | 5 | 500 |

These counts are **incomplete accounting, not full-set accuracy**. Unfinished
cases remain pending, not mathematical failures. Every method retains the
500-case planned denominator. Full-set paired gains/losses remain unavailable
until every planned attempt has a terminal status. The prefix is small and
not representative enough to revise the quality conclusion or forecast a
precise full-run time. The 15.3–24.6 hour planning range remains an estimate;
the controller respects the 48-hour cumulative budget between calls.

The immutable public [session summary](results/book-full500-v1-progress-01.json)
and [method accounting](results/book-full500-v1-progress-01-methods.jsonl) were
produced by the frozen MLPL runner. Raw responses stay in the ignored durable
store. Source commit for this session: `5aa93cfcbf0e5f5b8d8623211298f5f8fed493b8`.
Later progress does not overwrite this snapshot.

The continuation controller is tested for completion, no progress, failed
sessions, malformed summaries, competing controllers, budget exhaustion,
boundary stopping and waiting for an already active worker. It stops rather
than retrying failures automatically. The next reporting step collects the
completed result or an explicitly budget-exhausted partial result. Native
language-model training and a matched Python timing comparison remain separate.

[Memory samples](results/book-full500-v1-progress-01-memory.txt) retain the
GPU CSV rows and host `VmHWM` readings used for the reported peaks.
