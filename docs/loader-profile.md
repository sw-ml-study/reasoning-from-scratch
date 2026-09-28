# Loader scope and copying profile

Measured on 2026-09-28 with the same isolated CPU interpreter `cd3cd03f`
and Xeon W-2135 host as [the initial smoke](real-model-smoke.md). No sibling
source, installed tool, checkpoint hash or decoding setting was changed.

## Reproduce the fixture profile

```sh
MLPL=/disk1/tmp/reasoning-tools/build-cd3cd03f/release/mlpl-repl just loader-profile
```

The opt-in recipe writes an authored BF16 checkpoint under ignored
`out/fixtures/`, then runs each mode in a fresh interpreter. Each process has
a 120-second wall limit and an 8 GiB address-space limit. The fixture uses
exact values `1 + (global_parameter_index mod 127) / 128`, four query heads,
two key/value heads, and nonsquare key and feed-forward projections. It does
not contain pretrained weights. The initial comparisons use four layers,
width 32, and vocabularies of 256 and 32,768. A larger shape uses 28 layers,
width 128, and vocabulary 256.

Native tests first established all-role/all-layer values and orientation on
a four-layer fixture, plus cache/full-forward agreement after truncating the
source file. Additional tests cover a NaN in the final projection and zero
and singleton layer stacks. Late payload errors must fail the whole load,
not become an error value hidden inside an otherwise successful model.

## Separate the costs

One original-loader run, using a 1,048,576-value embedding (8 MiB as f64):

| Operation | Milliseconds |
|---|---:|
| Packed read of authored BF16 bytes | 1.62 |
| Unpack | 12.65 |
| Finite-value check | 35.04 |
| Reshape and binding | 12.25 |
| Transpose and binding | 17.06 |
| Four-layer gate stack without retaining the embedding | 11.06 |
| Allocate and bind a partial holding that array | 3.67 |
| Invoke the partial to select one row | 21.32 |
| Complete fixture model load | 1,499.43 |

These are elapsed MLPL operations, including operand/binding copies; they
are not isolated native-kernel or cold-disk benchmarks. Individual runs
establish scale, not a statistical throughput guarantee.

Retaining an unused array in the caller changed 100 scalar user calls from
1.30 ms with 8,192 values to 116.43 ms with 1,048,576 values. A smaller,
independent [core probe](../probes/call-scope-scaling.mlpl) measured 0.40 ms
versus 106.93 ms while also checking return values and caller scope
restoration. Its declared acceptance bound is `max(10 ms, 8 * small_ms)`;
the measured bound was 10 ms, so the expected outcome is **fail**.

Read-only inspection of the pinned interpreter confirms the mechanism:
`eval_user_fn.rs` snapshots scope for every user call, and `env_scope.rs`
clones the variable tables. Thus a large unrelated named binding affects
small nested calls. This extends R10 beyond field lookup to call frames.
Temporary record fields and concat operands are not named scope bindings.

## MLPL changes and measured effect

The loader now evaluates embedding, normalization, rotary tables and the
resident callback directly into the returned record. It no longer binds the
embedding or the complete stack record as locals during subsequent calls.
Role assembly keeps each projection as a temporary concat operand while
recursing across the remaining layers. The recursion is bounded by the
trusted configuration (28 layers for this checkpoint). Concatenation still
copies data; this is not a zero-copy representation.

| Four-layer model | Original loader | Final scoped loader |
|---|---:|---:|
| Vocabulary 256, width 32 | 206.60 ms | 210.73 ms |
| Vocabulary 32,768, width 32 | 1,499.43 ms | 295.12 ms |

Temporary model fields alone measured 269.97 ms on the larger-vocabulary
fixture. Recursion adds small-case overhead but reduces growing-stack cost:

| 28 layers, width 128, vocabulary 256 | Temporary fields, iterative stack | Temporary fields, temporary stack operands |
|---|---:|---:|
| Gate stack, 917,504 values | 1,249.13 ms | 540.58 ms |
| Full model, 4,170,624 parameters | 10,250.92 ms | 7,245.67 ms |

Header/name/dtype/shape validation, finite-only weights, projection
orientation, tied output, resident inference and error propagation are
unchanged. Existing and new native loader tests pass. The opt-in profile
does not join `just check`; only the small semantics tests and declared
scalar-call capability probe do.

## Remaining core boundary

The MLPL changes avoid unnecessary named intermediates in loading, but a
caller can still retain a large model. Calls, record access, partial binding
and callback invocation still copy large values. The new probe and the
[R10 request](sw-mlpl-requests.md) specify the missing performance guarantee
while preserving function-scope behavior. This belongs in core value/frame
semantics, not an extension implementing the differentiable model.

Real-model acceptance requires a fresh bounded smoke with identical pinned
artifacts, `base-smoke-v1`, seed 42 (unused by greedy), two new tokens, EOS
151643, 600 wall seconds and 32 GiB virtual memory. A fixture speedup alone
does not establish real inference or reasoning quality.

## Real checkpoint repeat

The unchanged smoke driver and original resource/token limits were repeated
after the fixture-proven loader changes, reusing the verified cached weights.

| Measurement | Result |
|---|---|
| Completed loader call | 101,453.43 ms (101.45 s) |
| Phase reached | generation |
| Allocation error | `memory allocation of 1244659712 bytes failed` |
| Sampled VmHWM | 33,010,784 KiB, about 31.48 GiB; lower bound on peak RSS |
| Generated ids/text | unavailable; no result emitted |
| Generation time/throughput/accuracy | unavailable |
| Final process wall time/status | 194 coarse seconds / 137, including manual interruption of core dumping |

The interpreter reached its 32 GiB virtual-address-space constraint during
generation and attempted to abort. `/proc` showed `CoreDumping: 1`; the
process was then killed to stop dumping roughly 31.5 GiB of resident memory.
Status 137 is therefore **not** evidence of the kernel OOM killer, and 194
seconds is **not** a generation benchmark. The direct allocator error,
completed load clock and absence of generated results are the relevant facts.
After the process ended, the wrapper gained `ulimit -c 0`, with an offline
test that the limit reaches the child. The wall/address/token limits and
driver remain unchanged; no further real run was needed to establish this
already observed inference failure.

The loader is now viable within the original deadline. Real generation and
reasoning quality remain unavailable. Next isolate and reduce resident-model
copies in the generation call chain, using scaled fixtures and the R10 core
handoff before another real attempt. CUDA is still unvalidated. Toy GRPO
remains independent and queued; this step did not train the base checkpoint.
