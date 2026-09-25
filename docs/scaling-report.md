# Inference-time scaling report

Update 2026-09-25: [upstream revalidation](upstream-revalidation.md) accepts
bulk unpack and the moved Linux tokenizer. The prerequisite table below is
the September 22 snapshot. Real-model measurements are still unavailable;
the named-tensor loader is next.

Recorded 2026-09-22 on Arch Linux. Saga 4's MLPL methods are implemented and
fixture-tested. **Real-model MATH-500 accuracy, inference throughput, peak
memory and scaling improvements are unavailable.** No checkpoint tensors
were loaded and no real evaluation was attempted in this saga.

## Delivered evidence

| Method | Evidence in this repository | What it does not establish |
|---|---|---|
| Temperature and nucleus sampling | Ten native tests; analytic distributions, explicit seeds, exact cached/full-forward sampled-id agreement on tiny weights | Real-model sampling quality or accuracy |
| Chain-of-thought and self-consistency | Twelve tests; versioned prompts, normalized boxed voting, ties, abstentions; all sixteen four-vote binary patterns preserve early/full winners | That generated reasoning is correct or voting improves accuracy |
| Response scoring | Ten tests; stable log probabilities, answer masks, entropy, explicit heuristic; teacher-forced tiny scores match separate prefix forwards | Calibrated correctness, training gradients or real-model memory use |
| Best-of-N and self-refinement | Nine tests; deterministic callbacks, bounded seed plans, first-maximum ties, nonworse revision acceptance, failure context and replay | Learned criticism, useful revisions or improved math performance |

These 41 scaling tests are part of the full **124-test** fixture suite.
The gate also checks 25 declared probe outcomes and reproduces 20 library
sources from the literate document. Expected failures in the probe catalog
are passing checks of known limitations, not delivered capabilities.

Contracts: [sampling](sampling.md), [self-consistency](self-consistency.md),
[scoring](scoring.md), and [self-refinement](self-refinement.md).
Self-consistency groups exact normalized answer strings. Best-of-N ranks
scores instead of voting. Refinement accepts equal-score replacements;
best-of-N retains the first tied maximum. These distinctions are intentional.

## Reference comparison, not a reproduction result

The approximate published values below are carried from the repository's
[chapter map](book-map.md), which records the book's reported results.
They are not new measurements or independently rechecked numbers. Different
prompts, scorers and generation budgets prevent assuming exact comparability.

| Method on Qwen3-0.6B base | Published MATH-500 accuracy, approximately | This implementation |
|---|---|---|
| Greedy base, 2048 new tokens | 15% | Unavailable |
| Sampling without voting | 18% | Unavailable |
| Chain-of-thought, temperature 0.9 / top-p 0.9 | 41% | Unavailable |
| CoT self-consistency, N=3 / 5 / 10 | 42% / 48% / 52% | Unavailable |
| One refinement round, depending on scorer | 21%–25% | Unavailable |
| Best-of-N | No number recorded in the chapter map | Unavailable |

Our prompts are independently worded. The explicit likelihood/entropy/format
heuristic is not the book's described brevity heuristic. Future results must
name the actual scorer and parameters; they must not be labeled an exact
replication of that scorer. There is no zero-percent placeholder for an
unattempted run, and fixture success is not a substitute for accuracy.

## Rechecked prerequisites and provenance

| Item | Observation |
|---|---|
| Interpreter | Isolated CPU release sw-MLPL 0.22.0, `6d7846605f27adbadaf17b662b2a984285ec15a3` |
| Adjacent source and remote HEAD | Both at that same revision when checked for this report |
| Test runner | mlplunit `a06191f800f40a23ebc1890eada3f505b1adab60` |
| Bulk bf16 probe | Exit 1: `unsupported: unknown function: unpack`; scalar reads still return 1, -1, 50 |
| CUDA smoke runner | Exit 77: selected CPU binary explicitly warns of fallback |
| CUDA build prerequisite | Prior same-revision build failed on toolkit 13.4 with cudarc 0.19.7; that dependency remains in the adjacent CLI lockfile. Build was not repeated for this report |
| Tokenizer parity runner | Exit 77: adjacent `demo-extensions/extensions/hftok` absent |
| Other adjacent repositories | `demo-mlpl-libraries` and `demo-ml-utils` absent; vendored header fixtures still work |
| Real model hash / evaluated examples | Unavailable / none; no real-model run exists |

Reproduce the prerequisite checks with the explicit [Linux tools](linux-toolchain.md):

```sh
just upstream
"$MLPL" --source-dir "$PWD" probes/unpack-bulk.mlpl
scripts/run-cuda-probe
scripts/run-tokenizer-parity
```

The nonzero statuses above are intentional diagnostic outcomes. No sibling
repository or stable installed tool was modified. No new download, CUDA
rebuild or repeated large benchmark was needed to confirm these conditions.

## Resume real measurements

1. **sw-MLPL R11:** ship and validate bulk byte-to-array decoding against
   [the bf16 acceptance cases](bf16-handoff.md). This repository then needs
   a tested named-tensor loader and real-model smoke; header validation alone
   is insufficient. The native-reader E3 fallback remains contingent on an
   explicit core decline, which has not been observed.
2. **demo-extensions E1:** supply a Linux hftok artifact and pass the real
   vocabulary/NFC parity checks. Fixture BPE is not accepted as a production
   tokenizer. Download/checksum integration is tracked separately as E2.
3. **sw-MLPL R12, for GPU results:** obtain a supported CUDA build and prove
   dispatch plus operation parity. A CPU baseline can precede GPU support
   if measured throughput makes a bounded run practical. R3 batched matmul
   and R10 container copying remain performance constraints.
4. **This repository:** add the real responder/scorer adapters and opt-in
   evaluation recipes. Start with a declared fixed slice and budget, then
   run larger evaluations only if feasible. Fixtures remain the only inputs
   to `just check`.

Each future row must retain the interpreter commit, checkpoint hash,
dataset identity and example ids, prompt/template version, per-generation
seeds, temperature, top-p, sampler version, token/stop budgets, method budget
(N or rounds), voting/tie policy, scorer identity and coefficients, and
verifier mode. Record sample count, correct count, abstentions/failures,
wall time and measured memory where available. Use the same slice and
explicit method settings for comparisons; do not infer accuracy from a
confidence score or select candidates using held-out answers.

## Demo and next work

With the Linux tool overrides, run:

```sh
just generation-demo
just scoring-demo
just refinement-demo
```

The first two demonstrate synthetic-model generation/scoring and exact
scoring math. The last demonstrates scripted selection and revision.
Together with the verifier demo, these are useful demonstrations of working
MLPL components. They do not demonstrate learned reasoning.

Saga 4 closes with implemented fixture methods and an explicit unavailable
real-model report. Saga 5 starts independently with analytic toy GRPO math,
then a trainable tiny policy on a synthetic verifiable task. That future
training step must demonstrate a measured reward change before claiming
learning. See [the saga queue](sagas.md) for its starting contract.
