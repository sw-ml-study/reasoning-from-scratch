# Verifier contract

The verifier decides whether a generated answer matches a reference answer.
It must be deterministic, total (never raise), and written in MLPL string
and array operations only. It replaces a Python symbolic-algebra dependency
with a bounded expression evaluator, so its behavior is specified here and
its divergences from the reference implementation are listed explicitly.

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
4. If the entire string is a `\text{...}` wrapper, unwrap it.
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
2. Otherwise both are parsed by the bounded expression evaluator. The
   grammar covers integers, decimals, fractions, `+ - * /`, `**`, unary
   minus, parentheses, `sqrt(...)`, `pi`, `e`, and implicit multiplication
   between a number and a parenthesized group or identifier. Inputs longer
   than 2,000 characters do not parse.
3. Values are computed as exact rationals whenever every operation stays
   rational (integer arithmetic within the f64 exact range, with
   numerator/denominator pairs); `sqrt` of a non-square and `pi` fall back to
   floating point. Two rational values are equivalent when equal; two
   floating values are equivalent when their absolute difference is below
   1e-9 relative to the larger magnitude, and never when either failed to
   parse.
4. Free symbols (`x`, `y`) make an expression non-numeric; two non-numeric
   expressions are equivalent only when their normalized strings are equal.

## Known divergences from the reference implementation

The reference uses a general symbolic simplifier, so it also equates
expressions such as `2x + 3x` and `5x`, and it treats a decimal against a
fraction as exact rational comparison (so `0.3333333333` and `1/3` are *not*
equal there). This contract:

- does not simplify symbolic expressions (documented as unsupported; both
  sides must normalize to the same string);
- compares decimals to fractions numerically with the tolerance above,
  which makes `0.3333333333` and `1/3` equivalent here. If a saga step needs
  parity on this case, it must tighten the rule to exact rationals only and
  record the change in the acceptance table.

Every divergence must have a test that pins the behavior this repository
chose, so a future change is visible.

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
