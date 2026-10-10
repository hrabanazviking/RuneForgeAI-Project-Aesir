# Strategy5 owned small-attention trace integration — 2026-10-10

AES500-016 physically captured public37 and public1070 with the opt-in strategy5
trace collector. Both profiled CSVs matched their unprofiled complete F32 logits
byte-for-byte, and both passed the source-bound full-session checker.

## Bound identities

- Device: NVIDIA GeForce RTX 2060 with Max-Q Design, compute7.5, 6,017,515,520
  reported bytes.
- Model SHA-256:
  `dde5aa3fc5ffc17176b5e8bdc82f587b24b2678c6c66101bf7da77af9f7ccdff`.
- Trace collector binary SHA-256:
  `ffd40e06f5ea32eb435dde2946ad27a3dd76722cb51349f4fb971179b9dc54e9`.
- Accepted strategy5 source CSV/report/binary SHA-256:
  `0dcc24b233b8ff094ac0486fcad7734fcd53ba0eba0c9f2e684a2c2316cd4d2d`,
  `22395c06b4cc62444ff063ba439cfcef89f3922c5ff0daabb284f56e23932a27`,
  `3afd548ad0ef71952ae590aa13c06a6ebc08fff4355eacfee293af7998b82660`.
- Nsight Systems: 2023.4.4.54. The installed Debian target/host tools are split
  across package directories; a private temporary tool layout exposed the matched
  host importer to the unchanged target CLI. Successful reports were exported to
  SQLite before checking.

## Results

| Case | Input IDs | Small tile plan | Owned child ranges / kernels | Pre-session init APIs | Unprofiled = profiled logits |
|---|---:|---|---:|---:|---|
| public37 | 37 | 1×b32, 1×b4, 1 scalar | 56 / 56 | 42 | Yes |
| public1070 | 1070 | 33×b32, 3×b4, 1 scalar | 1008 / 1008 | 42 | Yes |

Every full tile generates 28 `attend_small` calls, one per model layer. Each call
owns one nested range and one successful launch correlation; the earlier
one-child-per-tile interpretation was corrected after inspecting actual CUDA
activity. Children follow full b32 tiles then final b4. Small kernels matched the
compiled mangled-name prefix, exact `(24,4|32,1)` grid and `(128,1,1)` block. GPU
intervals are preserved whole when they extend beyond their CPU child ranges.

In both Nsight reports, 42 same-process CUDA context/stream/memory initialization
API calls ended before the owned prefill range and some began before the analysis
interval. The bounded initializer allowlist records these separately. Calls,
kernels, memcpy/memset rows, NVTX ownership, process identity, all source outputs
and final artifact hashes still pass the checker; kernels and the owned session
remain inside the analyzed capture interval.

The two source-bound summaries are [case1.json](case1.json) and
[case3.json](case3.json). All full CSVs, Nsight reports/SQLite, process logs and
failed captures/checker reports remain in a private untracked task artifact
directory; its machine-local path is intentionally not part of Git.

## Limits

These correctness and attribution receipts are restricted to this exact model,
RTX 2060 Max-Q and public37/public1070 workloads. GPU durations and recorded
resource values are diagnostic only. No speed, occupancy, spills, provider lead,
general device/model behavior, production strategy selection or controls-plus-
tracing claim is made. Hosted CI remains a separate release gate.
