# Larger CTA row sharing — 2026-10-02

Final128 numerical/bit gates pass; only selected shapes improve. A separate
128-row/32-column/precision0 kernel uses eight warps/256 threads, sharing padded
F16 inputs across more output rows. Every warp retains original16-row packed
split-weight/MMA chronological accumulation. Existing core module stays verbatim;
new sibling/wrapper is appended. Ceil-divided guarded input initialization handles
batch4 with more row warps than tokens. Maximum shared19008 bytes, no added global
workspace/device buffer/production dispatch.

Initial256 fails its first physical launch with CUDA_ERROR_LAUNCH_OUT_OF_RESOURCES.
Exact source/binary/partial CSV/process/unsuccessful JSON remain; no256 numerical
or timing acceptance exists. Final kernel/wrapper/collector/checker admit128 only.
An actual256 request with a nonexistent model path refuses before model load and
without a CUDA backend announcement. No fallback, toolchain change or inferred
register/occupancy cause. Initial128 diagnostic stays separate from final proof.

Final128 passes all144 synthetic Q4/Q5/Q6 tails,12 invalid spans,1622640 real input/
unowned guards,1658880 native/new/original F32 outputs and2100 selected independent
Float64 dots under unchanged .002-scaled/.0002-RMS. Every new/original bit matches,
including signed zero. Original real Q4/Q6 coverage is distinct from synthetic Q5.
All840 rotating ten-sample three-owner records with three actual calls each remain.
All seven target/legacy/header/master/normal/check builds finish before final GPU;
pinned gguf0.19.0/NumPy2.4.4 oracle follows and rehashes model/CSV.

Original64/new128 median elapsed ratios from the SAME capture; below1 means slower:

| Batch | Q | K | V | Output | Gate | Up | Down |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 4 | 1.0952 | 0.9161 | 0.9657 | 1.1114 | 0.9762 | 0.9924 | 1.1781 |
| 8 | 1.0041 | 0.7644 | 1.0611 | 1.0052 | 0.8133 | 0.8235 | 1.2227 |
| 16 | 0.9584 | 0.7572 | 0.9797 | 0.9399 | 0.7506 | 0.7698 | 1.1220 |
| 32 | 0.9537 | 0.8035 | 1.0000 | 0.9437 | 0.7690 | 0.7603 | 1.1041 |

Batch32 gate/up/down are0.7690/0.7603/1.1041. Do not choose larger rows
for gate/up from a winning down result. All batch4 shapes still lose to native
four-token work. Primitive timings exclude allocation/export/oracle, include
launch/synchronize and use warmed weights. No favorable subset replaces complete
samples; profiler durations are not scores. One final session is not a provider
lead or repeated-session certificate.

Sixteen portable contracts pass, preserving header alias/legacy schemas and
binding128-only geometry/complete original F32 bits/rotation/mutation/interruption/
exclusive failures. Every failed or incomplete report has passed=False and no
usable ratios. Master190 passes/zero fails/one skip. Normal binary f3442a1e remains
active/authenticated ready/prefill4/cpuoffload0. Broader real-F32/full-model/
decode/replay/control/context/device/concurrency/soak/provider gates stay open.
Narrow batch32 down-only ordinary actual-F32/captured and complete-model gates are next before any optional fixture selection. Exact push/CI receipts are separate.
[Operation](../../NATIVE_TURING_LARGE_ROWS.md).
