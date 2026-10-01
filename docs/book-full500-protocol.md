# Full MATH-500 inference protocol

Protocol `book-full500-v1`, frozen design on 2026-09-30. Execution is **not
started**. The tested [resumable runner](book-full500-runner.md) now prepares
500 cases, 1000 prompt hashes and 2500 immutable request identities. Its
execution manifest must be committed before generating benchmark answers.
The first-ten `book-author-v2` primary results remain immutable.

## Inputs and controls

Use all 500 records of the author's JSON in original order, including every
subject and difficulty. Dataset SHA-256:
`a9eccff7e25ecaf3952614e5b92fe081b4f0549c68ae6a387b96e131df9ddf41`.
Use author revision `1c0b9b17f80d335a9e7f73ca4738486bfa49fa9f` and the
existing attributed `fixtures/prompts/book-author.json` without modification.

Use Qwen3-0.6B-Base with the same model/config/tokenizer hashes as
[the first-ten protocol](book-author-protocol.md). BF16, context 4096,
2048 new tokens, EOS 151643; reset KV per independent response. Direct and
CoT are greedy. Three-vote CoT uses temperature 0.9, top-p 0.9 and MLPL seeds
43, 44, 45 per question. Record greedy seed 42 as unused. Preserve the MLPL
uniform stream, stable token ties, crossing-token nucleus rule, raw extracted
answer keys and first-observed plurality ties. Grade only after selection.
A capped output remains eligible for extraction and grading.

There are 500 direct, 500 greedy CoT and 1500 sampled calls: 2500 attempts,
producing 1500 method outcomes. Rotate method groups by case index as in
the first-ten experiment. No reference answer enters generation or voting.

The native selection candidate must pass fixed-logit/supplied-uniform and
matched-token acceptance before use. Pin provider source/archive/binary,
interpreter binary and source commit, tokenizer extension, every generation
source, all 1000 rendered direct/CoT prompts and hardware/driver/toolkit in
the execution manifest. A changed backend or control creates a new run ID.
The existing v2 benchmark runner and records are not repointed or overwritten.

## Resumption and exactly-once accounting

Assign each planned call the immutable key `(run_id, case_index, slot)`,
where slots are direct, greedy-CoT and sampled-1/2/3. Commit a complete
planned-key manifest before execution. Before dispatch, durably record a
started attempt with its prompt/token/control hashes. Write the response
and terminal outcome as one checksummed immutable record with atomic no-replace publication.
Never use the presence of a successful grade as the definition of completion.

On restart, reconcile the durable journal and terminal files:

- A valid terminal record is consumed once and never regenerated.
- A started record without a terminal result is explicitly interrupted.
  It remains in the accounting; it is not silently dropped or regenerated.
- An unstarted planned key may run. Duplicate, unexpected or hash-mismatched
  records abort reconciliation before another model call.
- A deliberate retry needs a separate recorded attempt identity and an
  explicit protocol amendment. The original failure remains visible.

This is exactly-once **accounting**, not an impossible guarantee that a model
call cannot finish immediately before a crash loses its result. Without all
three successful sampled responses, the voted method records a failed group;
it does not vote only over surviving successful samples. Every planned case
remains in its method denominator. A partial run is labeled incomplete;
completed-success-only accuracy is never presented as full-set accuracy.

Implementation prerequisite: the pinned MLPL `write_atomic` provides rename
atomicity but does not sync file contents or the directory to durable storage.
Use a tested generic persistence service with those sync boundaries before
acknowledging a started or terminal record. See [E7](demo-extensions-requests.md).
The isolated durable-store extension passes process-crash injection at file
sync, publication and directory sync. Runner replay, corruption, duplication
and interrupted/error denominator fixtures pass. No full500 answers have
been generated; physical power-loss behavior is not experimentally tested.

## Quality and runtime reporting

Report answer accuracy, paired gains/losses, truncations, interruptions,
backend errors, tokens, load/prefill/decode/selection/grading time, and sampled
host/GPU memory. Separate grader coverage review from primary scores.
Known unsupported examples include equivalent nonlinear polynomial forms
and trigonometric identities; authored linear and numeric fixtures are
covered. Do not infer that an unsupported equivalence is a mathematical
model error. Retain the strict primary metric and separately report any
independently adjudicated equivalence disagreements.

The old ten-case total extrapolates to roughly 32 hours, which is a planning
estimate rather than a prediction for the full distribution. Native selection
has a matched microbenchmark, not a measured full500 runtime. Reserve up to
48 hours of cumulative active execution, stopping cleanly between calls at
an operator-selected wall budget. Do not impose a 120-second per-call cap;
record token/context stops explicitly. Re-estimate cost from measured token
counts and throughput before launch, with the runtime estimate committed
in the execution manifest. No full500 ETA or Python speed ratio is claimed
until matched workload and hardware evidence exists.

Native loss/backward/optimizer/save/reload and GRPO/distillation training
remain separate acceptance work; this protocol is inference-only.
