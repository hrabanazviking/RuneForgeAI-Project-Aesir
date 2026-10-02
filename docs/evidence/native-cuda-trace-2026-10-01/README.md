# Native CUDA timeline evidence — 2026-10-01

Actual owned native CUDA CLI captures, no production compute change. Binary
f3442a1e5915cb43ec4da8a0f885ff38710a02b6ef795515dbe1f72c36ceda2b;
registered weights dde5aa3fc5ffc17176b5e8bdc82f587b24b2678c6c66101bf7da77af9f7ccdff.
Nsight 2023.4.4.54, installed matching host importer, RTX 2060 Max-Q/sm_75,
context4096/F16 KV/greedy/repetition penalty1. Native service remained active.
Complete public unprofiled/profiled replies and counts match in both cases.

| Case | Actual kernels | Kernel window s | GPU active union s | Uncovered s | Packed projection kernel s |
|---|---:|---:|---:|---:|---:|
| 37 input / 32 output | 30224 | 1.198668 | 1.172955 | 0.025713 | 1.059902 |
| 1070 input / 128 output | 450082 | 16.125260 | 15.788066 | 0.337194 | 12.347699 |

Projection kernels account for about 90.4% / 78.2% of active GPU union time
respectively in these single captures. Actual names and timings are in the JSON
reports; projected kernel durations sum without observed kernel overlap here.
Long-input scores and attention together consume about 1.95 seconds. Matrix
prefill remains the highest-priority large-gain route; CPU idle gaps are small
inside the kernel window, so host launch removal alone cannot explain the gap.
These are whole-inference kernel windows, including prefill and generation;
per-Q/K/V/FFN and prefill/decode attribution remain unavailable.

Unprofiled/profiled process wall times are 6.232/9.490 seconds (short) and
20.717/29.139 seconds (long). Profiler overhead ratios are 1.523/1.407. This includes
model loading, initialization and tool teardown; none is a service speed score.
Non-launch cuMemCreate return101 probes and fallback are retained in the API
summary. All actual kernel-launch return values are zero and all correlations
match uniquely. No CUDA driver or permission changes were required.

Raw QDSTRM/report/SQLite/transcripts stay outside Git in the owned private local
artifact directories; reports contain their SHA-256 hashes and sizes. Initial
import/export and parser-admission failures are retained with hashes in
retained-failures.json. Twenty-three portable parser/transcript/process ownership
checks pass; provider14, numerical9 and repository/fixture gates also pass.
Initial pushed CI passed executable/evidence tests but rejected a machine-local
manual path. The manual is corrected to describe the installed relative component.
Exact corrected CI and publication receipt are recorded separately.

Operation/resource/privacy/identity boundaries: [manual](../../NATIVE_CUDA_TRACE.md).
No speed-lead, broader profile/device or full quality claim is earned here.
