# Original Mojo dynamic context and rational coefficients

Date:2026-10-21. Pre-code contract247134c:
HAILO10H_DYNAMIC_CONTEXT_DESIGN.md. Parent dynamic source integration remains open.

## Implemented boundary

Standalone smidr/dynamic_rotary_context.mojo owns validated reference/selected/
limit context values, bounded maximum-position selection and canonical rational
frequency coefficients. Selection is constant-space integer arithmetic; current
context can retain an earlier peak or reset below the baseline. Coefficients
schedule theta and gain exponents and an exact selected-context delta ratio.
Pair zero uses zero exponents with denominator1, including rotary width2.
No singular division, float narrowing, width/context-sized allocation or device
opcode is introduced. This is an original compiler arithmetic primitive.

The only current consumer is tests/hailo_dynamic_rotary_context.mojo. No existing
production consumer imports it. It does not admit source dynamic scaling, convert
theta/factor words, produce numerical frequencies, modify a key/cache or assert
that retained keys all use the selected context. It is not a source-model
execution, cache-equivalence, memory-fit or Hailo arithmetic result.

## Independent acceptance

tests/test_hailo_dynamic_rotary_context.py passes4 methods/122 native child calls:
91 accepted and31 expected refusals. One new native entrypoint builds with zero
diagnostics. Exact input/source/binary/log/negative identities are retained under
evidence/dynamic-context-2026-10-21/; binary and full syscall trace stay outside Git.

- 1159 context/index cases cover exhaustive small domains and signed64 limits.
- 576 observations match the independently qualified public frequency-state
  table. External Float32 frequency constants remain separate from native integer
  acceptance; no external implementation is invoked by the native test suite.
- 695 coefficient cases match independent Fraction identities, including width2,
  pair0, largest even signed64 width and large selected-context deltas.
- 31 terminal refusals include11 independently mutated fields. Eleven owned-copy
  probes each perform11 invalid-then-valid internal cycles:121 recovery cycles.
  Caller changes do not alias copied context/coefficient values.
- A separate native isolation trace has zero network connects, ioctls, source
  payload opens, external inference library opens or Hailo/CUDA device opens.

All197 existing Mojo source hashes and64 frozen control binaries/modes are
unchanged. Existing161-method/6387-call integration evidence remains historical
and unchanged; it was not relabeled as a new combined regression run. The two
new Mojo files and new independent Python test have exact recorded identities.
No existing source/graph/schema/output changed. No master or E-REAL was run.

Initial compilation refused an implicit return copy; explicit ownership transfer
fixed it. The next build warned about an unused loop index; the index is now
anonymous. Original sources/logs and the warning build binary are preserved with
identities. The accepted final build has an empty diagnostic log.

## Required next integration

Continue TASK_hailo10h_dynamic_scaling_semantics.md. Before production integration,
publish exact owned source/policy/API rules for configured versus original versus
retained contexts, source32/64 scalar/factor words, raw/default/null/legacy/custom
origins, partial widths, NoPE, and actual invocation position indices. Bind the
selected context once per invocation and retain provenance for keys inserted
under earlier contexts. Preserve the distinction between source insertion-basis
history and an explicitly requested fixed-vector rephasing operation. Rephasing
does not prove full-prefix decoder equivalence. Do not silently reinterpret old
keys, derive context from cache capacity, discard source fields, or impose a
permanent full-prefix-only target restriction.

That contract must define source/semantic/recipe/expanded/cache/matrix/storage
consumers, source/global maps, domains, lifetimes, exact descriptor/storage charges,
mutations, complete frozen outputs and recovery acceptance before edits. Current
default/linear source support remains unchanged; dynamic and other variants,
architectures/formats/operations remain implementation work toward broad support.
Actual Hailo widths/packing/placement/register/CCW configuration, original program
delivery/activation/results/cleanup and source-model execution remain open.

Whole-repository consistency remains failing:baseline23295/current23296;
all1 added diagnostics concern retained receipt paths, with no new
nonreceipt issue after Markdown line normalization. Ledger114 verified/159 unique
IDs; nine historical strict-schema diagnostics unchanged. No whole-repository
or hosted-CI pass is claimed.
