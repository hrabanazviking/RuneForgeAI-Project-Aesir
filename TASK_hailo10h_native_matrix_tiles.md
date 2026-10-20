# Native source-bound matrix contraction schedules

Date: 2026-10-20. Contract before implementation.
Owner scope: `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Parent: `TASK_hailo10h_source_compiler_plan.md`.

Consumer: the SMIÐR native numerical backend, consuming ordinary source models
through the existing semantic graph. Implement original owned tile schedules
for source-bound linear contractions, preserving input/output tensor IDs,
source matrix binding and logical output shape (including head splits).
Rows M come from input outer dimensions, contraction C from its last dimension,
outputs N from source matrix rows; source columns must equal C and output
element count/shape must agree. Aesir performs this internally, with no ONNX
conversion or outside model compiler prerequisite.

Use explicit positive M/N/C tile extents, input/weight/accumulator byte widths,
alignment, workspace bound and provenance. Check all dimension, ceiling-count,
tile-count, extent and workspace arithmetic. Enumerate individual rectangular
input/weight/output tile spans with partial final tiles and accumulation
start/final markers, without allocating a full M×N×C product tensor or
evaluating weights/activations on the CPU. Preserve source packed-kind binding;
actual packing/conversion, device arithmetic and numerical precision remain
separate backend work. Return owned values with no borrowed graph/file pointer.

Acceptance: independent exhaustive small-domain tile coverage of output and
contraction coordinates, exact first/final accumulation markers, source weight
bindings and reshape mapping; multiple layers/head splits and K/V dimension
differences; malformed source graph/weight/shape/operation, invalid policy,
overflow/workspace/index refusals and returned ownership. No full model/layer/
attention math, external compiler/runtime, device open/write/upload or inference
is part of this slice. Test oracles inspect structural arithmetic only.

This is an internal mathematical schedule, not an executable Hailo program or
hardware resource/precision certificate. Keep unknown numerical CCW/register
encoding, physical geometry/placement, packing, actual transport activation and
first arithmetic hardware result explicit. Publish the verified native slice
and continue those actual gaps automatically. Broad model support remains the
fixed target; this incremental operator coverage is not a permanent allowlist.
