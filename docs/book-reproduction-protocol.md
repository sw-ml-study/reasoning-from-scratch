# Book-matched base-model pilot v1 (frozen design; execution unavailable)

Frozen on 2026-09-29 before any selected answer generation. The intended
backend is sw-MLPL with the existing Rust Candle/cudarc CUDA foundation and
a validated resident Qwen3 provider. No Ollama or HTTP-model substitution.
This is a small reproduction pilot, not the author's full MATH-500 result.

## Data and exclusion

Use MATH-500 JSONL SHA-256
`35dc41080a3680858b27fa7e0533d2d547825316fc5dafe5d316f4ccc5a06132`.
Exclude every id in the frozen six-case native-heldout-v1 selection (including
the development retry). Rank remaining ids by SHA-256 of UTF-8
`book-base-v1:` followed by unique id, without newline; take the first 12.
No filtering on difficulty, answers or observed behavior. Authored demo
questions are a separate corpus and are not added. The committed selection
contains ids/ranks and hashes of exact UTF-8 question/reference strings;
downloaded text remains local. This is held out from this project's prompt
experiments, not a claim of absence from pretraining data.

## Model and execution gate

Qwen3-0.6B-Base weights SHA-256
`cd2a512003e2f9f3cd3c32a9c3573f820bb28c940f73c57b1ddaa983d9223eba`,
config `504a6b58c4271583724e66584b6b7698aea18450209df6b2f7582df0e89cee59`,
tokenizer `c0382117ea329cdf097041132f6d735924b697924d6f6fc3945713e96ce87539`.
Use BF16 weights, explicit CUDA placement, unquantized execution and no chat
or thinking template. Record actual accumulation dtype. EOS is 151643;
context 4096, output cap 2048, with prompt length validated before evaluation.

Before any selected inference, commit a separate execution record pinning
Rust/backend/facade/interpreter revisions and hashes, tokenizer identity,
CUDA toolkit/driver, dtype, RNG algorithm and its seed mapping, prompt hashes,
verifier version, device residency and the exact commands. Require the
existing GPU demo checks, authored tiny cached/full-forward parity and a
short real-checkpoint generation check on a non-evaluation prompt. Missing
support blocks execution, not a switch to another model. Any changed design
requires a new protocol version committed before running selected cases.

## Fixed methods and counts

- Direct: existing `boxed-v1` raw base prompt, greedy argmax, 12 calls.
- CoT: identical prompt plus two newlines and `Explain step by step.`,
  greedy argmax, 12 calls.
- CoT + self-consistency: same CoT prompt, temperature 0.9 and top-p 0.9,
  no top-k or repetition penalty, ten fresh candidates per case, 120 calls.
  Sample seeds 42 through 51 for each case, reset KV state for every candidate.
  Record seed 42 as unused for greedy calls. MLPL owns sampling and voting.
- All 144 calls share checkpoint/tokenizer/context/output cap. Rotate the
  three method groups by selection index modulo three. Within sampling,
  process seeds ascending. Warm once on a non-evaluation prompt.
- Primary verifier is choice-v2. Accept only complete, nonempty boxed final
  answers; errors and truncations are incorrect attempts. Vote on normalized
  extracted answers from completed candidates only. A tied plurality or no
  eligible candidates is an abstention/incorrect final result. Never use the
  reference to select a candidate. Report eligible-candidate counts.
- 120 seconds maximum per call and a two-hour job budget. No retries replace
  failures. If the job ends before all scheduled calls, label the experiment
  incomplete, report attempted/planned counts, and withhold a complete-set
  accuracy comparison. Do not present omitted calls as observed failures.

The maximum allowance is 294,912 generated tokens; actual cost matters.
Voting intentionally receives ten times the per-case candidate allowance;
report that cost rather than describing this as equal-compute evaluation.
A lower-budget comparison can be a later, separately frozen experiment.

## Predeclared analysis

For each method: correct/12, Wilson 95% interval, completed incorrect,
truncated, error and abstention counts, generated tokens, wall time, and
measured GPU/process memory. Compare CoT against direct, and voting against
CoT, with paired per-problem wins/losses/ties. Show correctness-versus-cost.
A positive pilot has more paired gains than losses, but twelve problems
cannot establish broad significance. A tie, regression or ceiling is a valid
result. Confirm any promising method on a fresh frozen set before claiming
robust gains; the published book figures remain separately attributed.

Retain request/input ids, outputs, seed, completion reason, grades and hashes
locally; publish numeric evidence without downloaded question/solution text.
Review verifier failures separately without silently rewriting primary scores.
No weights are updated: this tests inference-time methods, not GRPO, ICRL or
distillation. Later learning must reuse demo-ml-utils' frozen-parameter and
held-out controls where applicable and validate native gradients separately.

## Current status

No selected inference has run. Existing CUDA demos/native training code and
MLPL adaptation controls are available; today's selected binaries are CPU-only,
and the documented CUDA 13.4 dependency pairing plus general Qwen3 provider
remain unvalidated. See [ecosystem inspection](ecosystem-reuse.md),
[backend integration](rust-cuda-backend.md), core R12 and extension E6.

## Selection regeneration

Run from the repository root after verifying the dataset hash; the following
prints the manifest and does not generate model answers:

```sh
perl <<'PERL'
use strict; use warnings; use JSON::PP; use Digest::SHA qw(sha256_hex); use Encode qw(encode_utf8);
my $j=JSON::PP->new->utf8->canonical; my %excluded;
open my $old,'<','docs/results/heldout-pilot-v1-selection.jsonl' or die $!;
while (<$old>) { $excluded{$j->decode($_)->{id}}=1; }
open my $data,'<','data/math500/test.jsonl' or die $!; my @rows;
while (<$data>) { my $r=$j->decode($_); next if $excluded{$r->{unique_id}}; push @rows,{id=>$r->{unique_id},rank=>sha256_hex('book-base-v1:'.$r->{unique_id}),problem_sha256=>sha256_hex(encode_utf8($r->{problem})),reference_sha256=>sha256_hex(encode_utf8($r->{answer}))}; }
@rows=sort {$a->{rank} cmp $b->{rank}} @rows;
print $j->encode($_)."\n" for @rows[0..11];
PERL
```
