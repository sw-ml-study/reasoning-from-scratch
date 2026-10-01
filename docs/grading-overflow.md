# Bounded numeric grading and the book comparison

The MLPL grader rejects nonfinite arithmetic as unavailable numerical evidence.
It cannot hang in Euclid on an oversized integer, and cannot award a match
because a comparison involved NaN. Exact rational arithmetic remains bounded
by binary64's exact-integer range; this is not arbitrary-precision SymPy parity.
Literal equality remains available before numeric parsing.

## Diagnosis from saved evidence

At 1087 successful calls (43.48% of 2500), the greedy CoT response for
zero-based case 217, ordinal 1086, reached its 2048-token limit. Extraction
selected a 1844-digit integer: one followed by 1843 zeros. The question asks
for the smallest positive multiple of 450 using only digits zero and one.
Since 450 = 9 × 50, the answer must end in two zeros and have a digit sum
divisible by nine. The smallest such number is **11111111100**. The generated
number has digit sum one, so it is incorrect regardless of its length.

The saved text shows the model choosing the wrong form and repeatedly emitting
zeros. This is generation degeneration, not a number computed by the CUDA
runtime. The sampled response for the same question instead lists multiples
until its token cap; it also fails to finish. These traces establish the
observed behavior, not its unique model/backend cause. Token-by-token comparison
with an independent implementation would be needed to attribute it to numeric
backend differences. No Python run was performed for this diagnosis.

The GPU finished and unloaded normally. The grader then accumulated the long
integer into floating infinity, passed it to GCD, and obtained NaN from modulo.
The old loop treated NaN as truthy indefinitely. A three-second isolated timeout
reproduced that arithmetic path; replay of the saved response identified the
same location. The independent watchdog stopped the stalled CPU process.
All 1087 completed responses remain available; no inference needs repeating.

## What the book does differently

The [pinned chapter 3 implementation](https://github.com/rasbt/reasoning-from-scratch/blob/1c0b9b17f80d335a9e7f73ca4738486bfa49fa9f/reasoning_from_scratch/ch03.py)
uses SymPy parsing and symbolic simplification, catches selected parser errors,
and rejects expressions over 2000 characters. Our 1844-digit candidate is below
that cutoff. [SymPy Integer](https://docs.sympy.org/latest/modules/core.html#sympy.core.numbers.Integer)
supports arbitrary-size integers, so this integer does not need floating
infinity. Source inspection therefore indicates that the author's grader would
compare it as a different integer and mark it incorrect, avoiding our GCD bug.
This is a source-based conclusion, not a measured execution of the author's
runtime. The cited grading functions do not impose a per-answer wall timeout;
their length guard is not a universal bound on symbolic work.

The experiment uses the book's Qwen3-0.6B-Base checkpoint and author prompt
controls. There is no evidence that the author saw this exact continuation or
that Python prevents repetition. Using the same model does not guarantee an
identical generated sequence across numerical implementations.

## Implemented safeguards

- Check finiteness and integer bounds before GCD; cap Euclid at 128 iterations.
- Use exponentiation by squaring with at most 54 iterations for supported
  integer exponents. Invalid exponents and overflowing powers stay unavailable.
- Reject nonfinite numeric literals and parsed subexpressions with `range`
  errors, including invalid intermediate values hidden by a later power of zero.
- Reject nonfinite operands in approximate equality and scale finite values
  before subtraction to avoid another overflow during comparison.
- Keep the 2000-character expression limit and existing generation token cap.

Some mathematically valid expressions remain unsupported, including values
outside the finite arithmetic range and powers whose intermediate reciprocal
overflows. They are not evidence of a correct numeric match. Three adversarial
native test groups cover the long integer, huge positive/negative exponents,
NaN/infinity, division by zero, negative square roots and erased intermediates.
The existing exact arithmetic and grading fixtures remain required.

## Regrading and recovery provenance

Read-only replay scores 652 complete method groups from the saved prefix;
641 overlap the last completed session report, with **zero changed grades**.
The new prefix has correct counts 38 direct, 99 greedy CoT and 99 three-vote,
over 217, 218 and 217 complete groups respectively. These are incomplete,
unequal cohorts, not final MATH-500 accuracies. The offending greedy answer
scores zero. Generation has 1087 successful terminal records, 520852 tokens,
50 caps, zero backend errors and zero interrupted calls at this checkpoint.

The original execution manifest, source pins, request identities and store
metadata are retained. `book-full500-v1-grading-v2.sha256` is an explicit
amendment: only the two numeric-grader files and runner validation plumbing may
differ. The validator rejects changed generation inputs, omissions and duplicate
pins. Each amended session logs its source commit, grading version and both
manifest hashes. Existing responses are regraded, never regenerated.

```sh
BOOK_GRADER_VERSION=bounded-v2 scripts/run-book-full500 --reconcile
BOOK_GRADER_VERSION=bounded-v2 scripts/continue-book-full500
```

Reconciliation must have exclusive store ownership. The interrupted session's
wall-time accounting conservatively includes downtime until reconciliation;
do not erase that charge. Clear a diagnosed STOP by archiving it before manual
continuation, then restart the watchdog after generation is visibly active.
The default v1 runner still rejects changed source pins. Do not rewrite frozen
execution files to make validation pass.

## Prevention and next measurements

The grader fix prevents this stall; it does not improve the model's answer.
A separate experiment can measure repetition detection with an explicit
`repetition` stop reason, constrained final-answer formats, or independently
verified refinement. Early stopping saves tokens but must still count an
unfinished or incorrect answer as a failure. Keep these controls out of the
current frozen generation protocol. Sampling already exists and did not solve
this particular question within the budget.

For book-level grading coverage, exact big-integer/rational arithmetic belongs
in a generic Rust extension work order, with MLPL retaining extraction and
grading decisions. A per-answer process timeout would bound future parser or
symbolic stalls independently of the outer watchdog. Neither capability is
claimed as delivered here. Subsequent book training experiments must measure
held-out improvement rather than promising no failures.
