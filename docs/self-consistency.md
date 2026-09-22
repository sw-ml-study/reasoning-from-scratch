# Chain-of-thought prompting and self-consistency

`lib/scaling/consistency.mlpl` implements the chapter 4 method over an
explicit text responder. The prompt wording and implementation are authored
here. Evidence comes from stub responders, not real-model accuracy runs.

## Calling the pipeline

`u:scaling_consistency(problem, responder, seeds, options)` returns a Result.
The callback receives `(prompt, seed, decoding)` and must return plain text.
It may wrap the existing sampled decoder and tokenizer when real weights
become available. The pipeline does not load a model or contact a service.

The seed plan is a nonempty vector of distinct integers in `[0, 2^53-1]`.
Its length is the sample budget, and its order determines callback order
and tie resolution. Duplicate seeds are rejected because repeating a
deterministic sample would inflate that answer's vote.

Required options are `build`, `model_hash`, and `decoding`. Build and model
hash are nonempty strings; their truthfulness is the caller's responsibility.
Fixtures use explicitly synthetic labels. The decoding record contains
`temperature`, `top_p`, `max_new`, `stop_id`, and a nonempty `sampler` version.
Temperature/top-p follow [the sampler contract](sampling.md); the budget
is a nonnegative integer, and the stop id an integer at least -1. The
responder validates the stop id against its vocabulary. Optional `early_stop`
is 0 (default) or 1.

`u:scaling_cot_prompt(problem)` reuses the boxed-answer evaluation template
and appends an instruction to show intermediate calculations, check the
result, and finish with a boxed answer. Its version is `boxed-cot-v1`;
provenance also records the base template version.

## What counts as a vote

Extract the last balanced `\boxed{...}` group, normalize it with the
existing verifier, and remove spaces, tabs, carriage returns, and newlines.
Equal normalized strings share a vote. For example, `\boxed{ 2 }` and
`\boxed{$2$}` agree. Equivalent values such as `0.5` and `\frac{1}{2}`
can remain separate keys. Voting does not use approximate numeric equality
or symbolic equivalence, which would make grouping ambiguous.

A missing box, malformed last box, or answer that normalizes to empty text
**abstains**. It still consumes a seed and one sample slot. Arbitrary nonempty
symbolic text can be a key: voting is not a check that an answer is correct.
If every response abstains, the result is successful with
`status="no_valid_answers"`, empty answer, zero votes, and no tie.

Callback exceptions and non-text returns (including Results) **abort** the
run with `kind="self_consistency_responder"`, index, and seed. These are
integration failures rather than uncertain model answers. A failed run
does not return the successful-run audit report.

## Winner, ties, and stopping

The most frequent key wins. Equal counts are reported as a tie and resolved
by first occurrence in the seed plan, not lexical or numeric order. The
report keeps every key and count in first-occurrence order. `tie_indices`
indexes all current leaders in that key list; even a unique leader has one
index. `majority` means strictly more than half of the **observed valid**
votes, while a plurality can win without a majority.

With early stopping enabled, let `L` be the leading count, `R` the largest
other count (zero if none), and `U` the number of unattempted slots. Stop
only when `L > R + U`. This also covers an unseen rival getting every
remaining vote. Equality is insufficient because a tie would still be
possible. Abstentions reduce `U` and may make an existing winner certain.

For five planned draws, three initial votes for one answer make it certain.
For four draws, votes `A,A,B` do not: the final vote could create `A:2,B:2`.
Counts and majority flags describe observed samples; early stopping preserves
the final winner and tie outcome, not final counts or vote proportions.

## Result and audit

The result contains answer, winning votes, all answers/counts, tie indices
and flag, observed majority, certainty flag, status, attempted/valid/rejected
counts, remaining budget, planned and used seeds, and the stop reason.
`early_stopped` is true only when unused slots remain.

`trace_jsonl` records one row per attempted response with index, seed, raw
text, normalized key, acceptance flag, and abstention reason. Run provenance
records build, model hash, both prompt versions, `normalized-boxed-v1` voting,
the complete decoding record, and the early-stop setting. These are returned
in memory; writing a report is the caller's choice.

## Validation

Twelve native tests cover prompt/version contracts, normalization, ties,
abstentions, all-invalid outcomes, callback failures, metadata validation,
seed plans, and certainty bounds. Exhaustive enumeration of all sixteen
four-vote binary patterns compares early and full runs' winners and tie
flags. A callback that fails on unused seeds proves early stop avoids calls.

With [Linux tool overrides](linux-toolchain.md), run
`just tests tests/test_scaling_consistency.mlpl` or `just check`.
The full fixture suite has 105 tests and 18 tangled library sources.
Real-model work remains subject to [the bf16 handoff](bf16-handoff.md).
Scoring and self-refinement are subsequent steps.
