# Original dynamic context and rational coefficient primitive

Date:2026-10-21. Pre-code child contract of
TASK_hailo10h_dynamic_scaling_semantics.md. Qualification:
HAILO10H_DYNAMIC_CACHE_BASIS_AUDIT.md. Publish before native edits.

## Scope and exact API

Add standalone smidr/dynamic_rotary_context.mojo. It imports no graph, cache,
source adapter, external implementation or numerical runtime. Its actual consumer
is the isolated native coefficient probe; future graph integration is explicitly
pending. It computes integer context selection and exact rational exponents,
not numerical frequencies, rotations, model values or device instructions.

DynamicRotaryContext(Copyable,Movable) has reference:Int, selected:Int, limit:Int.
Require1<=reference<=selected<=limit, with positive signed Int limit. Limit is a
caller index bound, not hardware capacity or trained context. Validate all fields
on every consuming call. initial_dynamic_context(reference,limit) returns the
validated reference-selected state. Caller inputs and outputs are independent
field values; there is no global mutable state or borrowed backing storage.

select_dynamic_context(state,max_position) returns a new DynamicRotaryContext.
Require0<=max_position<limit before adding1. Let L=max_position+1. The selected
context is reference if L<reference, otherwise max(old selected,L). This original
integer interval specification matches the qualified hysteresis table. It is
not a universal rule for all architectures. Equality at the baseline after
growth retains the peak. A fresh session starts with initial state; do not infer
a session reset or sequence length from a tensor count, query count, cache
capacity or nested source original-context field. The maximum index is a caller
precondition; future position-source integration must independently validate it.

DynamicRotaryCoefficients(Copyable,Movable) owns context:DynamicRotaryContext,
width:Int,pair_index:Int,theta_num:Int,theta_den:Int,gain_num:Int,gain_den:Int,
delta_num:Int,delta_den:Int. dynamic_rotary_coefficients(context,width,pair_index)
requires even width>=2 and0<=pair_index<width/2. At pair0 set both exponent
numerators0 and denominators1. Other pairs use theta_num=gain_num=-2*pair_index,
theta_den=width,gain_den=width-2. delta_num=selected-reference and
delta_den=reference. These deliberately unreduced integer ratios are canonical
for this descriptor. validate_dynamic_rotary_coefficients rederives every field
and snapshot constraint. Reject mutated/noncanonical denominators or numerators.
Validate index bounds before multiplication/subtraction; all calculations fit
signed Int even at its largest supported domain. No element-count product,
list, allocation proportional to width/context or string work is introduced.

## Mathematical and ownership boundary

The descriptor means theta^(theta_num/theta_den) multiplied by
[1+factor*(delta_num/delta_den)]^(gain_num/gain_den), for positive finite
theta and factor supplied later by a qualified source binding. Pair0 is exactly1
and bypasses all powers, including width2. No native floating conversion,
narrowing, theta/factor synthesis or assertion about hardware rounding occurs.
This coefficient schedule preserves the real formula without forming a large
intermediate scaled base or inventing a width2 division. Domain qualification of
actual source theta/factor words remains in the future integration contract.

The selected context is not a cache-wide basis tag. Context changes need not
change every pair; width2/pair0 is the explicit counterexample. No key or value
is transformed, relabeled, compacted or admitted by this module. NoPE layers
should have no rotary consumer at future integration, not fake identity metadata.
Source origins/defaults/raw/nested/custom/legacy and unresolved fields are not
projected or dropped here. Existing default/linear policy and graph entrypoints
continue to refuse unimplemented dynamic integration; broad support remains work.

No new semantic operation, recipe map, tensor domain, lifetime, cache allocation,
storage charge, schema or source-model eligibility rule is added in this slice.
Descriptors are constant-size caller-owned compiler arithmetic. Full source/
semantic/recipe/expanded/cache/matrix/storage integration must publish exact
factor/context-history/cache-basis/domain/lifetime/acceptance rules before code.
Hailo numerical widths/encoding/packing/placement/configuration and original
program upload/activation/results remain open. Never invent opcodes.

## Independent acceptance

Freeze64 accepted compiler controls and197 source identities remains in force.
Do not modify existing production files or tests for this standalone slice.
Build a new native CLI probe and verify original context tables, all576 qualified
public observations, exhaustive small context/index domains, upper signed Int
boundaries and malformed state. Compare exact exponent/delta ratios against
independent Python Fraction identities, including width2/pair0, large widths,
out-of-range/odd/negative dimensions and changed descriptor fields. Verify copied
state, changed input isolation, deterministic refusal followed by valid recovery.
No host frequency array, model/layer/attention forward or device operation.
Preserve preliminary failures and build/source/test identities. Verify no existing
source hash changed, publish exact results and remote heads, sync main, then
continue the full dynamic integration and numerical Hailo gaps automatically.
