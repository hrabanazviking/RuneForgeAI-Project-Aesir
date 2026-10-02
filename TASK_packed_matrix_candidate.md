# SPD-01 — bounded packed matrix projection candidate

Established 2026-10-01. Authorized by Volmarr's repeated implement/verify/push
instruction. Mythic Engineering sequential roles; no new approval is needed.
Current measurement trace slice is c34ebf4, with portable-manual correction
a76b7c9. Exact remote CI runs separately; repair any failures before a validated
publication claim. Independent candidate work may proceed while remote builds run. The production executable is f3442a1e, unchanged.

## Problem, scope and outcome

Actual long-input CUDA trace assigns 12.35 of 15.79 active GPU seconds to packed
projections. Current four-token projection owns independent warp dots. Implement
an optional native SIMT matrix candidate with a two-dimensional output tile and
shared decoded weight/activation tiles, bounded to 4/8/16/32 token shapes. This is
an explicit primitive experiment reached by a physical probe, not a claim that
SPD-01 is integrated or that any candidate is faster before measurement.

Use original packed bytes, Float32 activations/accumulation, no Tensor-Core or
external inference. A 32-row/32-column staging tile uses at most 8448 shared bytes
per block at batch32. Every thread participates in both barriers, including tails.
Tokens are independent columns; no KV/session mutation belongs in this primitive.
Keep existing scalar/block/four projections unchanged and callable as references.
Native runtime policy and maximum four-token control polling stay unchanged.

The candidate's chronological-column reduction differs from the warp reference.
Predeclared primitive acceptance: finite outputs, absolute error <=0.002*(1+abs
(reference)) for every output and normalized RMS <=0.0002 against native reference.
Independent CPU Float64 dots from exercised real packed weight values must satisfy
those same budgets. Whole-model independent budgets remain 0.05/0.005 plus matching
argmax, but full-model integration is a separate slice and may not inherit primitive
success. Do not relax budgets or promote a slower/failed candidate.

## Owning files and verification

core/packed_matrix.mojo owns the experimental kernel and explicit span admission.
tests/test_packed_matrix.mojo owns synthetic Q4/Q5/Q6, tails/guards/nonfinite/error
and actual registered 3B tensor projections, complete output/timing export and a
mandatory final marker. Optional scripts/check_packed_matrix.py owns independent
real-weight CPU dot/evidence checking, never runtime inference. Update relevant
INTERFACE/README_AI, docs/NATIVE_MATRIX_CANDIDATE.md, evidence, roadmap/TODO/ledger
and DEVLOG. CI compiles the opt-in probe and checks portable admission tests; it
must not claim actual GPU execution.

Physically exercise the locked sm_75 runtime and real weights. Retain every output,
all failure artifacts, complete fixed-count timing repeats and exact input IDs or
activation formula. Pair baseline four-token launches versus equal candidate work,
separately report larger batches and workspace. No synthetic timing may establish
full-model speed. A failed/slower route is documented and not connected to default
inference. If promising, proceed to a separate integrated batch-four/full-model
slice; larger tile policy requires its own cancellation/control/buffer acceptance.
Rebuild/checksum the production launcher after Mojo edits, verify service readiness,
repository/fixture hygiene, and exact pushed CI before claiming publication pass.
