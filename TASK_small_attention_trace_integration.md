# AES500-016 — Strategy5 owned trace integration evidence

## Objective

Exercise the explicit strategy5 trace collector on public37 and public1070,
compare profiled and unprofiled complete outputs against the accepted strategy5
source, and attribute every small-attention kernel through the owned NVTX and
CUDA correlation contract.

## Acceptance

- Bind the accepted source CSV/report/binary, exact model, sm_75 trace binary,
  unprofiled/profiled CSVs, Nsight report and SQLite export by SHA-256.
- Require full vocab output bytes, IDs, cache state, counters and guards to match
  for both cases; keep durations diagnostic and unscored.
- Require 28 layer-owned child ranges and one successful launch/kernel correlation
  per layer for every full b32 and final b4 tile; require exact kernel identity,
  geometry, thread ownership and source order.
- Preserve all failed reports and raw artifacts outside Git. Publish compact,
  path-scrubbed acceptance summaries under
  `docs/evidence/small-attention-trace-integration-2026-10-10/`.
- Record allowlisted pre-session CUDA API rows separately with per-API return
  histograms. Permit status 0 generally and status 101 only for `cuMemCreate`
  before the owned range; status 101 is `CUDA_ERROR_INVALID_DEVICE`, and absent
  call arguments do not justify classifying it as benign. Other nonzero statuses
  reject. Launches, kernels and the complete owned session remain interval-checked.

## Evidence boundary

Accepted runs support only the declared model, device and two public cases.
They do not establish performance, occupancy, spills, provider lead, general
model/device behavior, CUDA fault recovery, controls-plus-tracing or production
runtime selection. Hosted CI is a separate release gate and is reported
independently of the local physical acceptance.
