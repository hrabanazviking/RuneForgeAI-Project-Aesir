# SPD-01 — shared-column staging and row-tile tuning

Established2026-10-01. Volmarr authorizes repeated verified slices and pushes.
First matrix primitive passes full native-reference and selected independent
real-weight budgets, but batch4 loses all shapes. Native production binary
f3442a1e remains unchanged. The preceding slice is published separately; exact
CI remains a required publication gate, not permission to claim GPU execution.

## Reviewable outcome and boundaries

Retain the original32-row/32-column matrix shape as an explicit reference. Add
bounded16/8-row and64/128-column staging choices to the optional primitive.
Decode/share more columns per barrier and measure occupancy/shared memory rather
than assuming larger tiles are faster. Shapes stay4/8/16/32 tokens. Shared memory
must fit the observed sm_75 standard48KiB/block boundary; no opt-in resource or
privilege changes, Tensor-Core, precision change or full expanded model.

The column-chronological F32 accumulation order and fixed primitive error budgets
remain unchanged. Every shared load, tail, barrier and output span must stay
valid even when fewer outputs than threads exist. Original default32/32 is still
callable, and production inference does not import this candidate. No larger
prefill/control policy, model byte, service, corpus or provider default change.

## Files, physical gates and next decision

core/packed_matrix.mojo owns explicit compile-time tile parameters, admission and
shared-memory bounds. Existing physical exercise receives these parameters;
new tests/test_matrix_tile_tuning.mojo reaches each declared shape and records
TILE metadata. check_packed_matrix.py admits the new optional tile record while
preserving previous CSV evidence. Update relevant interfaces/manuals, six-or-more
portable evidence tests, CI compile, public evidence, roadmap/TODO/ledger and DEVLOG.

Serialize actual GPU candidates; preserve all raw outputs/timings/failures. For
each promoted primitive choice run the144 synthetic tails,12 invalid span gates,
all1,658,880 native-reference outputs and2100 selected independent Float64 dots.
Keep ten paired timing repeats and complete final marker. Exclude allocation and
printing. Do not turn a per-shape or larger-batch win into a whole-model claim.
Rebuild/checksum the production launcher, check live service readiness, publish
and verify exact CI. If a viable batch4 choice emerges, next scope its full-model
numerical/control integration; otherwise record rejection and proceed to the
pinned sm_75 Tensor-Core feasibility prerequisite. Never loosen budgets or
silently connect a slower shape.
