# Original source activation selection and mathematical lowering

Date:2026-10-21. Exact design4a66acb published on both branches before code.
Fixed target remains broad ordinary source-model support through original Mojo
compilation and Hailo-only LLM execution.

## Owned mathematical integration

DecoderActivationPolicy owns one mathematical identifier per layer, provenance
and a bounded work budget. Exact charge is128*layers+provenance.UTF8+sum(kind.UTF8),
checked before policy copies or source-selector list allocation. New source
projection validates the complete original architecture, maps silu→silu,
gelu→gelu_erf and relu→relu, and retains the original raw configuration, default
origins, unknown fields and unresolved modifiers. Other selectors remain
implementation work and are never silently aliased or made permanent model
eligibility restrictions.

New typed/source-scalar builder overloads place each selected activation after
its actual gate projection/bias and before gate/up multiplication. They preserve
source32/64 words, independent K/V widths, NoPE choices, source output selection
and source storage. Legacy SiLU graph names and lowering remain unchanged.
GELU uses five finite-real operations for0.5*x*(1+erf(x/sqrt(2))); the algebraic
inverse sqrt two, integer one and rational half have exact mathematical meanings.
ReLU uses maximum_zero. These operation names are compiler IR, never Hailo opcodes
or a claim about device transcendental arithmetic or precision.

Plan and downstream cache/matrix/storage guards check exactly one selected gate
activation/layer, source projection/bias roles, shape/products, actual inputs,
consumer/producer identity, accounting and last uses. Expanded/storage validation
owns and compares policy snapshots, rederives all selected activation recipes
including unchanged SiLU, checks local/global maps, domains, metadata and lifetimes,
and rejects omitted/duplicated/bypassed/mutated operations. No extra cache or
in-place alias is introduced. Explicit activation JSON uses schema4 with complete
input mappings alongside scalar/bias descriptors; legacy output is unchanged.

## Acceptance

Forty-six entrypoints rebuild warning-free under one unchanged source snapshot.
Twenty-one suites pass140 methods/4124 native child calls. The new suite's
nine methods/503 calls comprise135 accepted and368 expected refusals.
All selected per-layer activations, bias ordering, independent source K/V widths,
source defaults/origins, source32/64 words and exact work/overflow boundaries pass.
Eight complete frozen GGUF outputs, two complete ordinary graphs and two complete
consumer outputs match after normalizing only explicit activation/schema/input-map
metadata. Source, recipe and global lifetimes and hypothetical storage are
independently rederived. Exact source/binary/oracle/run identities, all commands,
logs, ownership traces and negative artifacts are in
 docs/evidence/decoder-activation-2026-10-21/.

Owned-input tests mutate caller selector lists, provenance/work, bias/decoder
policies, geometry and scalars after construction and prove unchanged graphs.
Recipe snapshots remain independent of subsequent source-plan mutations. Forty
in-process refusal/recovery cycles across two scalar paths check fresh graph
construction and actual descriptor cleanup. Tiny scalar oracles evaluate only
one activation primitive at a time, never projection/layer/attention/model
forwards. Previously qualified136 external functional primitive outputs remain
under the published pre-code design; external libraries are not dependencies.

Negative/preliminary evidence remains preserved: an early test expected fields
not yet serialized and one fixture omitted its explicit head declaration. The
first complete focused run passed all nine new methods but Python unittest also
collected an imported legacy TestCase and refused its duplicate evidence path.
The final test imports that module without exposing its TestCase for discovery.
A preliminary native harness used a reserved identifier, corrected before final
build. No failed/preliminary run is counted as final acceptance. Fresh final
source/binary hashes must all match; no source changes during final rebuild.

## Remaining fixed-target gates

This verifies mathematical/source compiler support only. Complete ordinary
activation variants/scaling/window/cache/training/architecture adaptation,
immutable source identity, actual device numerical precision/packing/placement,
CCW/register/configuration generation, original program delivery/activation/
results/cleanup remain open. Memory size, host graph or isolated primitive math
cannot establish hardware fit or source-model execution. No DFC, outside model
compiler/machine, user conversion, vendor-precompiled prerequisite, inference
proxy or CPU/CUDA/cloud LLM inference was introduced. Missing coverage remains
implementation work toward the unchanged broad target.

Whole-repository consistency remains failing:baseline19315/current20098;
all783 new diagnostics concern retained receipt paths, with no new nonreceipt
issue after Markdown line normalization. Ledger census110 verified/155 IDs,
no duplicate IDs. Targeted local acceptance passes; no historical-master or
whole-repository/hosted-CI pass is claimed.
