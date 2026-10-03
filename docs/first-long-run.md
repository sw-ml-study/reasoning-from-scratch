# First long run: results, status and next steps

As of **2026-10-02**, the full MATH-500 inference experiment is complete.
Reasoning prompts substantially improve answer accuracy, but full feature
parity with the book's code is not achieved, and we have not demonstrated a
speedup over its Python implementation.

## Results

The experiment uses **Qwen3-0.6B-Base**, the book's starting model, with fixed
pretrained weights. MLPL controls generation, sampling, verification and
voting; Rust/CUDA provides native model execution on an RTX 5060 Ti 16 GiB.

| Method | Our correct answers | Our accuracy | Book's published accuracy |
|---|---:|---:|---:|
| Direct answers | 72/500 | 14.4% | 15.2% |
| Greedy chain-of-thought | 213/500 | **42.6%** | 40.6% |
| Three-sample CoT vote | 199/500 | 39.8% | 42.2% |

All **2500 calls across 500 questions completed**, with zero backend errors
or interruptions. There were **127 token-capped responses** (5.08% of calls).
Each method retains all 500 questions in its accuracy denominator.

Chain-of-thought improves accuracy by **28.2 percentage points** over direct
prompting: it gains 158 correct answers and loses 17. Voting gains 52 answers
and loses 66 relative to greedy CoT, finishing **2.8 points lower**. The book's
voting improvement is therefore not reproduced here. Greedy versus sampled
voting changes both decoding and aggregation; these totals do not isolate
the cause of the deficit.

This is evidence that asking the small base model for intermediate reasoning
helps answer accuracy. It is not yet a newly trained reasoning model, nor a
proof that every explanation is sound. Even greedy CoT misses 287 questions.
Our bounded grader can also miss equivalent symbolic answers that SymPy
would recognize, so measured accuracy is subject to that coverage limit.

## Feature parity with the book

| Area | Current status |
|---|---|
| Tokenization, Qwen3 forward execution and cached generation | Working at real-model scale through MLPL and native Rust/CUDA services |
| CoT prompting, temperature/top-p sampling and three-sample voting | Working; measured on all 500 questions |
| Evaluation, durable recovery and paired-result analysis | Working; all 2500 attempts accounted for and results published |
| Answer grading | Numeric, literal, tuple and bounded linear-symbolic support; not general SymPy parity |
| Scoring and refinement | MLPL modules and fixture tests exist; real-checkpoint refinement evaluation remains planned |
| GRPO and distillation | MLPL objectives and toy updates exist; native language-model backward/update/save/reload acceptance remains unfinished |

We have reproduced the main inference-time reasoning benefit on the book's
base model. We have **partial feature parity**, not end-to-end parity with
the book's evaluation, refinement and training work. No improved native
reasoning checkpoint has been trained in this experiment.

## Did we run faster?

**No speedup was demonstrated.** Our observed call-time totals are longer.

| Method | Our generation call time | Book's published time | Descriptive ratio |
|---|---:|---:|---:|
| Direct | 37.6 minutes | 10.1 minutes | 3.7× |
| Greedy CoT | 264.3 minutes | 84.5 minutes | 3.1× |
| Three-sample vote | 829.9 minutes | 211.6 minutes | 3.9× |

The book's published measurements use DGX Spark CUDA hardware; ours use an
RTX 5060 Ti. Hardware, generated outputs, RNG behavior and timing boundaries
are not matched. These ratios do not establish that Rust or MLPL itself is
3–4× slower than Python. Python already delegates tensor work to native CUDA
libraries. A controlled same-hardware comparison remains unavailable.

Our generation calls total **18.86 hours** and produce **1231978 tokens**.
Charged sessions total **20.33 hours**, including loading, grading and
conservatively charged recovery downtime. Calendar execution spans about
**30 hours 42 minutes**, including pauses. These are different measurements.

Decode steps, including native selection, account for **99.44% of generation
call wall time**. Those host-side spans include CUDA launches, transfers and
waits; they are not a measurement of GPU kernel utilization. Sampling time
is not separately isolated. Sampled peak memory is **2431 MiB device-wide**
and **1904460 KiB host process high-water memory** (about 1.82 GiB).

## Status and next steps

The benchmark and its reproducible Org/HTML publication are complete and
committed. The publication gate passes **200 native tests, 62 literate
tangles and seven offline MLPL calculations**, including exact HTML export.
No inference restart is needed, and there are no execution blockers for this
completed run.

1. **Reduce decode costs.** Profile resident copies, launches and
   synchronization; evaluate stable cache storage and graph replay. Require
   numerical and seeded-token parity before accepting a speed improvement.
2. **Explain the voting deficit.** Inspect sampled-candidate quality, ties,
   raw-answer string grouping, truncation and grader coverage. Label any
   changed selection rule as a separate experiment.
3. **Establish matched performance comparisons.** Fix hardware, inputs,
   generation controls and timing boundaries before claiming a speed advantage.
4. **Complete native training.** Establish backward/update/save/reload
   correctness, then measure held-out gains from GRPO and distillation.

The status viewer remains available, and now reports completion:

```sh
/disk1/github/sw-ml-study/reasoning-from-scratch/scripts/book-full500-status --once
```

Omit `--once` for ten-minute updates or replace it with `60` for minute updates.

## Evidence and further reading

- [Full500 results and artifact index](book-full500-results.md).
- [Detailed literate HTML](reasoning-results.html) and [Org source](reasoning-results.org).
- [Final numeric summary](results/book-full500-v1-final.json) and
  [provenance and measurement boundaries](results/book-full500-v1-final-provenance.json).
- [Book's pinned chapter 4 results](https://github.com/rasbt/reasoning-from-scratch/tree/1c0b9b17f80d335a9e7f73ca4738486bfa49fa9f/ch04/02_math500-inference-scaling-scripts).
- [Build a Reasoning Model (From Scratch)](https://www.manning.com/books/build-a-reasoning-model-from-scratch).
