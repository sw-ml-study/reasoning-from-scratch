# Verifier contract

The verifier decides whether a generated answer matches a reference answer.
It must be deterministic, total (never raise), and written in MLPL string
and array operations only. It replaces a Python symbolic-algebra dependency
with a bounded expression evaluator, so its behavior is specified here and
its divergences from the reference implementation are listed explicitly.

## Implementation map

| Stage | Module | Prefix |
|---|---|---|
| character scanning (classes, search, trim, replace, braces, numbers) | `lib/text/text.mlpl` | `u:text_` |
| last boxed group and candidate selection | `lib/verify/extract.mlpl` | `u:verify_` |
| the thirteen ordered rules | `lib/verify/normalize.mlpl` | `u:verify_` |
| expression equivalence and grading | `lib/verify/grade.mlpl` (pending) | `u:verify_` |

The language has no regular expressions and none is requested; the scanners
are the replacement. `lib/verify/` files need `lib/text/text.mlpl` included
first, because a nested `include` cannot climb out of its own directory.

## Pipeline

```text
generated text
  -> last_boxed(text)           last "\boxed{...}" group, brace-matched
  -> final_candidate(text, mode) boxed group, else last number, else text
  -> normalize(candidate)        ordered clean-up rules (below)
  -> parts(normalized)           tuple/list splitting on top-level commas
  -> equivalent(part, ref_part)  string equality, else evaluated equality
  -> grade(candidate, reference) all parts equivalent, same count, in order
```

`final_candidate` modes: `boxed_only` (used as the RL reward: an unboxed
answer earns nothing), `number_only`, and `number_then_full` (used for
evaluation and voting).

Numbers recognized by the fallback: an optional minus sign, then either an
integer fraction `a/b`, or digits with an optional decimal part and an
optional exponent. The *last* match wins.

## Normalization rules, in order

1. Empty input stays empty. Chat-control tokens of the form `<|...|>` are
   removed. Surrounding whitespace is trimmed.
2. A leading single-letter multiple-choice label followed by `.` or `:` is
   dropped.
3. Degree markers (`^{\circ}`, `^\circ`, the degree sign) are removed.
4. If the entire string is a `\text{...}` wrapper, unwrap it. A `\text{}`
   that covers only part of the string is left in place; rule 13 then
   removes its braces, so `a\text{b}c` normalizes to `a\textbc`. This
   matches the reference implementation.
5. Display and inline math delimiters `\(`, `\)`, `\[`, `\]` are removed.
6. `\left` and `\right` are removed; thin-space commands are removed;
   `\cdot` and the Unicode middle dot and times sign become `*`;
   `\dfrac` and `\tfrac` become `\frac`.
7. Unicode superscript digits and signs become `**` exponents when attached
   to a preceding operand.
8. `\%` becomes `%`; then every `$` and `%` is deleted.
9. `\sqrt{a}` and `\sqrt a` become `sqrt(a)`.
10. Non-nested `\frac{a}{b}` and `\frac a b` become `(a)/(b)`.
11. `^` becomes `**`; a mixed number `n a/b` becomes `n+a/b`.
12. Thousands separators (a comma followed by exactly three digits and then
    a non-digit or the end) are removed.
13. All braces are deleted, the result is trimmed and lower-cased.

## Equivalence

1. If the two normalized strings are identical, they are equivalent.
2. Otherwise both are parsed by the bounded expression evaluator
   (`lib/verify/expr.mlpl`). The grammar covers integers, decimals with an
   optional trailing point, fractions, `+ - * /`, `**`, unary signs,
   parentheses, `sqrt(...)`, `pi`, `e`, and implicit multiplication between
   a number and a parenthesized group or a call. Input longer than 2,000
   characters does not parse.
3. Values are exact rationals (`lib/verify/number.mlpl`) wherever every
   operation stays rational, **including decimals**: `0.75` is the rational
   three quarters, not a float. Exactness is lost only when a numerator or
   denominator would exceed the exact-integer limit, or when the value comes
   from `pi`, `e`, or the square root of a non-square. Two exact values are
   equivalent when their cross-products are equal; otherwise they are
   compared numerically within 1e-9 relative to the larger magnitude.
4. A free symbol makes an expression non-numeric. Two non-numeric parts are
   equivalent only when their normalized text matches once every space is
   removed, so `x+1` matches `x + 1` but not `1+x`.

## Differences from the reference implementation

The reference uses a general symbolic algebra system. This implementation
does not, and the difference is confined to one behavior:

- **Symbolic rearrangement is not recognized.** The reference equates
  `2x + 3x` with `5x`; this contract requires matching text. Every test in
  `tests/test_verify_grade.mlpl` pins that choice.

Everything else matches, including the case that motivated the original
concern: because decimals are parsed as exact rationals rather than floats,
`0.5` equals `1/2` and `0.3333333333` does **not** equal `1/3`, exactly as
the reference behaves. An earlier draft of this contract predicted a
floating-point tolerance divergence here; the implementation avoided it.

## Evidence

`just math500-self-grade` (opt-in, needs `just fetch-math500`) grades all
500 MATH-500 reference answers against themselves and against a constant
wrong answer. Measured on 2026-09-17 against interpreter build 3250cea9:
500 of 500 self-matched, 0 false positives, 15.7 seconds.

## Acceptance cases

The suite in `tests/test_verify*.mlpl` covers at least these categories,
each with positive, negative, and boundary inputs authored in this
repository:

- last-boxed extraction: single, multiple (last wins), whitespace between
  the command and the brace, nested braces, missing brace, unbalanced braces;
- candidate fallback: boxed present, bare number at the end of text, no
  number at all, each of the three modes;
- normalization: every rule above in isolation and two composed cases;
- equivalence: identical strings, integer versus fraction, decimal versus
  fraction, different fractions, expression with `sqrt`, expression with
  `*`, thousands separator, degree marker, wrapped text;
- tuples: same order, swapped order, different length, single-element
  parenthesized value kept whole, empty part keeps the whole string;
- totality: empty string, missing candidate, missing reference;
- MATH-500 self-consistency (opt-in, needs the downloaded set): every
  reference answer grades as correct against itself, and a constant wrong
  answer grades as correct against none.
