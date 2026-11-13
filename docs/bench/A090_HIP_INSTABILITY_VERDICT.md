# A-090 — HIP soak or instability verdict: VERDICT

Slice A-090 (Wave 10 closer). Roadmap acceptance: one-hour
decode soak on the HIP path if integrated; else the instability
evidence is filed as the verdict — soak log OR verdict doc, one
of the two, honestly.

Host: purpleraider, AMD Radeon 8060S (gfx1151). All numbers
below are read back from the banked evidence filed by A-082,
A-083 and A-085 (ledgers and bench logs in hidden_files/);
no new device run is claimed by this slice.

## VERDICT

**HIP is NOT integrated. The soak branch does not apply; the
instability verdict is filed instead.** No one-hour HIP decode
soak was run, and none is claimed. A soak could not have been
run honestly in any case: there is no HIP decode loop to soak
(see Finding 4). HIP remains PARKED, probe-only, exactly as
banked by A-085 and applied to the live registry by A-086
(`core/backend_registry.mojo`: Vulkan first-class, HIP
probe-only). This slice does not re-litigate A-085; it closes
Wave 10 by filing the instability evidence A-085's verdict
rests on, in one place, as the roadmap's else-branch requires.

## Why the soak branch does not apply

The roadmap conditions the soak on HIP being integrated
("if integrated"). Integration would mean, at minimum, a HIP
decode path the engine can select for real decode. The banked
state is the opposite: A-085 declared Vulkan the PRIMARY GPU
road and HIP parked probe-only; A-086 banked that verdict into
the registry, placement and selection. Filing a "soak log"
for a non-integrated path — e.g. looping a per-call GEMV bench
for an hour — would manufacture stability evidence for a
configuration no decode run can use, and is refused on
honesty grounds.

## The instability evidence

### 1. Per-call context-setup cost makes per-token decode untenable (A-082, A-083, A-085)

Every HIP call through the proven road (MAX
`DeviceContext(api="hip")`) pays fresh-context creation:

- Q8_0 GEMV (A-082, filed): per-call 16.93 / 13.41 / 13.22 ms
  at 512x4096 / 64x1024 / 37x320 — a flat ~13–17 ms floor at
  every shape. That is context-creation cost, not kernel cost
  (A-082's own filing). The resident loop (one context,
  weights resident) reaches 1.02 ms at 512x4096, proving the
  silicon is not the bottleneck — the lifecycle is.
- Q4_K GEMV (A-083, filed): end-to-end per-call medians
  7.14 / 2.01 / 2.99 / 3.87 / 6.99 ms across the five bench
  shapes; "~2–7 ms per fresh context" by its own ledger.
- Bake-off (A-085, two independent paired runs): HIP per-call
  Q4_K medians 5.20 / 1.76 / 2.89 / 3.69 / 6.92 ms vs Vulkan
  0.237 / 0.175 / 0.382 / 0.429 / 0.454 ms (Vulkan faster by
  21.9x / 10.0x / 7.6x / 8.6x at the shared shapes). Effective
  bandwidth at the large shape: HIP ~0.34 GB/s vs Vulkan
  ~20.8 GB/s (verify run ~0.31 vs ~18.6 GB/s) — "the gap is
  context setup, not silicon" (A-085).

A decode loop pays per-call cost per token. Vulkan's shared
persistent context (A-013/A-014) has no such floor: its
per-call numbers ARE its resident numbers. The floor is
decisive, and it is upstream-runtime behaviour the project
cannot fix in its own code today (A-085, code health).

### 2. GTT retention grows without bound under per-call contexts (A-083 probe; A-079 bisect family)

- Retention probe (hidden_files/a083_retention_probe.log):
  every buffer-bearing MAX DeviceContext retains exactly
  8,388,608 bytes (8 MiB) of GTT until process exit. Free
  GTT fell by exactly 10 x 8 MiB per 10 HipQ4kGemv calls
  across 120 calls, never plateauing.
- Attribution probe (hidden_files/a083_attr_probe.log): bare
  name-only contexts retain ~0.25 GB total for 10; vec_add and
  bare buffer+copy contexts each retain exactly 10 x 8 MiB
  per 10 after the first kernel context triggers the arena
  pin (the A-079 bisect family).
- Verdict filed by A-083 and carried here: MAX DeviceContext
  buffer-pool behaviour, pre-existing and shared with the
  A-029 MojoNative path — NOT an A-083 operand leak. But for
  a decode loop creating a context per token, retention by
  construction is unbounded growth within the process
  lifetime: at the measured Q4_K per-call rates, one hour of
  decode would pin GTT at 8 MiB per token-step context until
  exit. That is an instability property of the road, not of
  any one kernel.

### 3. Signal-pool leaks ride every HIP bench (A-082, A-083)

Bench logs end with SharedSignalPool leak warnings: 5,874
signals in the A-082 bench; 1,335 in the A-083 bench
(reproduced in A-085's verify run); 1,780 in the A-083
retention probe. Filed by A-085 as HIP-road lifecycle costs
Vulkan does not carry. Neither is an operand leak; both are
evidence the HIP runtime lifecycle is not soak-clean.

### 4. There is no HIP decode loop to soak (coverage, A-085)

HIP coverage is exactly two kernels: Q8_0 GEMV (A-082) and
Q4_K GEMV (A-083), both one-thread-per-row naive, honestly
filed as untuned by their own slices. There is no HIP
RMSNorm, RoPE, attention, full layer, prefill, or other
quant — the decode loop of record (A-066) is Vulkan. A
one-hour *decode* soak on the HIP path is therefore not
merely inadvisable; it is not runnable. Any "soak" staged
from the two GEMV benches would be a kernel loop, not decode,
and filing it as a decode soak would be a false claim.

### 5. HIP carries no stability evidence at all (contrast: Vulkan)

- Vulkan: one-hour-class soak (A-077: 4,590 steps in
  3,600 s, 0 errors, per the A-081 gate filing), GPU fuzz
  with 0 real divergences (A-078), device-lost recovery
  (A-079), equivalence gate (A-080). Buffer accounting exact
  in every no-leak case.
- HIP: no soak, no fuzz, no recovery evidence — this slice
  is where the roadmap sends that absence to be judged, and
  the judgement is: absence plus Findings 1–3 is an
  instability verdict, not a neutral gap.

### 6. Intermittents and crash-class artifacts on the HIP road

- `gpu.amd_hip_stream_async_round_trip` is a known
  pre-existing intermittent in the E-MASTER suite (filed
  across the A-072/A-075/A-076/A-078 ledgers; a MEM-004
  failure on A-072 attempt 1, passing on re-run). It is
  HIP-path flakiness on file, tolerated as an intermittent,
  and it weighs on the HIP side of the stability ledger.
- The zero-copy/HIPRTC crash class: the A-019 comgr-heap
  finding (fixed in-slice by retaining the HIPRTC program)
  and the 2026-11-12 seat crash artifact (SIGABRT of an
  ad-hoc ctypes probe driving `aesir_zc_hip_alloc_managed` /
  `aesir_zc_hip_transform`; explained and filed in
  docs/AESIR_Z13_PART_I_EVIDENCE.md, item 9) belong to the
  HIP-road lifecycle fragility family. Neither is an engine
  crash in a suite run; both are recorded so the road's
  history is not mistaken for clean.

## Re-open criteria — status at this filing

A-085 set four criteria, ALL required, then a fresh bake-off.
Status: **none met.**

1. Persistent-context HIP launcher with per-call overhead
   < 0.5 ms median at 64x1024 Q4_K — NOT MET (no such
   launcher exists; per-call is 2.99 ms at that shape).
2. 8 MiB/context GTT retention capped or released, no-leak
   invariant re-filed — NOT MET (retention stands as probed
   by A-083; no pool knob or toolchain fix on file).
3. HIP kernel coverage of at least the decode set (one
   K-quant GEMV + RMSNorm + attention) — NOT MET (Q4_K GEMV
   exists; no HIP RMSNorm or attention).
4. HIP soak + fuzz at A-077/A-078 standard with 0 real
   divergences — NOT MET (this filing is the verdict that
   replaces the soak until criteria 1–3 make one runnable).

Until all four are met and a fresh bake-off is run, HIP
stays probe-only. A-087 (ROCm reproducibility), A-088 (HIP
zero-copy measurement) and A-089 (HIP error semantics) may
supply re-open evidence; none of them, alone or together,
integrates HIP.

## Bugs

None discovered in engine code in scope. This is a
documentation/verdict slice: +0 E-MASTER cases, pin stays
600. The defects filed above are upstream MAX/ROCm runtime
lifecycle behaviours, already recorded by A-082/A-083/A-085;
the standing next-work item (persistent-context launcher or
MAX pool cap, from the A-083 ledger) remains the road to
re-open criterion 1 and is carried in CAMPAIGN_STATE.md.
