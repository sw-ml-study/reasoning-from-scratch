# Full MATH-500 results

**Complete, 2026-10-02.** All 2500 planned calls succeeded, covering 500 direct
answers, 500 greedy chain-of-thought answers and 1500 sampled CoT responses.
No backend errors, interruptions or pending calls remain. The last scoring
snapshot was written at 02:51:51 PDT; the completion notification was sent at
02:52:47 PDT. Power recovery verification found all 5153 journal envelopes
intact and all frozen source/prompt pins valid. No regeneration was required.

| Method | Correct | Accuracy |
|---|---:|---:|
| Direct | 72/500 | 14.4% |
| Greedy CoT | 213/500 | 42.6% |
| Three-sample CoT voting | 199/500 | 39.8% |

CoT gains 158 answers and loses 17 against direct prompting: **+28.2 percentage
points**. Voting gains 52 and loses 66 against greedy CoT: **−2.8 points**.
This reproduces a substantial inference-time reasoning benefit on the book's
small base model; it does not reproduce the author's voting improvement.
The weights remain pretrained and fixed, and the verifier is a bounded subset
of general symbolic equivalence. Answer accuracy is not a complete audit of
intermediate reasoning. There are still 287 incorrect greedy-CoT answers.

Generation produces 1231978 tokens with 127 token-capped calls (5.08%). Call
wall time totals 18.86 hours, charged session time 20.33 hours, and calendar
span about 30h42m including pauses. Decode steps including native selection
account for 99.44% of call wall time; these host spans include CUDA waiting,
not just kernels. Sampled peak GPU memory is 2431 MiB device-wide and host
high-water memory is 1904460 KiB. There is no demonstrated speedup over the
book: its DGX Spark timings are lower, but hardware, output lengths and timing
boundaries are not matched.

The [literate report](reasoning-results.html) contains full tables, book
comparisons, interpretation and an executable offline MLPL replay. Its
[source](reasoning-results.org) can be refreshed with `just research-refresh`.
The new replay checks ordered complete records and recomputes all three
accuracies, paired gains/losses, method tokens, caps and call timing.

Published evidence:

- [Final provenance and measurement boundaries](results/book-full500-v1-final-provenance.json).
- [Final runner summary](results/book-full500-v1-final.json).
- [1500 selected method outcomes](results/book-full500-v1-final-methods.jsonl).
- [2500 numeric call measurements](results/book-full500-v1-call-metrics.jsonl).
- [Session accounting](results/book-full500-v1-session-metrics.jsonl).
- [Sampled memory peaks](results/book-full500-v1-memory.json).
- [Execution manifest](results/book-full500-v1-execution.json) and
  [explicit grading amendment](results/book-full500-v1-grading-v2.sha256).

Original manifests and early snapshots are immutable provenance, not current
status. Raw questions, generated text, token IDs and model files remain ignored.
The final report uses grading `bounded-v2`; generation controls remain those
frozen before execution. Seeds, model/interpreter/provider hashes, templates
and decoding parameters are recorded in the execution manifest and its pins.

Next: profile resident decode copies/launches with numerical and seeded-token
parity, diagnose voting's candidate/selection failures, and establish matched
performance measurements. Native GRPO/distillation training remains separate.
No blockers remain for this completed benchmark. Broader verifier coverage,
matched Python timing and native model training remain explicit limitations.
