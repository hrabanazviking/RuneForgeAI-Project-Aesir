# A-100 — Placement planner

Slice A-100 (Wave 12, Heterogeneous scheduling). Per-op
device assignment driven by the measured cost tables from
Parts III–IV, not by hand-waving. Acceptance: planner
decisions on standard fixtures match the measured optima.
**Verdict: PASS — all 12 standard fixtures land on their
measured optima** (suite cases planner.* in
tests/test_placement_planner_a100.mojo; standalone check
spikes/a100_planner/check.mojo, 12/12).

## What was built

`aesir_engine/core/placement_planner.mojo`: a pure planner
over the A-009 backend registry. It encodes the measured
tables as data (each row carries its source slice), decides
per op kind + shape + workload flags (overlap available,
power capped), and returns the device, the backend, the
named measured reason, an estimated latency ONLY where a
measured row matches the shape exactly (else -1, unknown),
and — for every NPU decision — the A-099 fallback (CPU,
FALLBACK_<NAME> on failure). Wired surfaces: the A-017
device policy remains the delegate for kinds with no
measured row (generic, transfer, unknown); `doctor` renders
the planner's fixture lines and JSON summary next to the
existing placement-policy section.

## Measured tables consumed (no re-measurement)

| Source | Filed fact the planner encodes |
|---|---|
| A-094 | NPU dispatch floor 93.0 us warm; GEMM sweep (7 rows, verbatim in `npu_gemm_latency_table()`); crossover between 32^3 (0.29x, LOSE) and 64^3 (1.88x); prefill projection GEMM M ≥ 64 FIT (99x vs oracle CPU at 128×1024×1024); decode GEMV NOT FIT (tile M=32); embedding lookup NOT FIT; elementwise/norm FUSION-ONLY |
| A-095 | Prefill projection dispatch exists behind the registry, exact parity, NEUTRAL-WITH-VALUE; NPU placement requires the proven-path context — presence alone never places (A-017) |
| A-096 | Overlap POSITIVE: NPU prefill inside the GPU decode shadow fully hidden (median benefit 4,198 µs over serial) |
| A-097 | Sampler NOT FIT: NPU argmax 104.8 vs CPU 19.9 µs (V=32768), 165.2 vs 76.7 µs (V=131072) — rows verbatim in `sampler_latency_table()` |
| A-098 | Prefill shape 128×1024×1024: GPU 67.5 µs / 51.20 GFLOP/s/W / 77.7 W pkg; CPU 632.5 µs / 5.34 / 79.4 W; NPU 2,258.2 µs / 5.39 / 22.1 W — rows verbatim in `prefill_power_table()` |
| A-086 | Vulkan first-class GPU, HIP probe-only — HIP is never a planner backend |
| A-099 | Every NPU decision names its CPU fallback; failures degrade with FALLBACK_<NAME> logged |
| A-017 | Accelerator-first policy; delegate for unmeasured kinds |

## Decision rules (in order)

1. Sampling → CPU (A-097 measured at both vocab sizes).
2. Embedding lookup → CPU; standalone elementwise → CPU
   (A-094 NOT FIT / FUSION-ONLY floor arithmetic).
3. Attention → GPU (A-017 class: KV memory-bound, not
   NPU-shaped; Vulkan attention road).
4. Decode GEMV (any GEMM-class request with M=1) → GPU
   (A-094 NOT FIT on NPU).
5. GEMM class below ~0.1M MACs → CPU (A-094 floor: 32^3
   measured NPU 93.0 µs vs CPU oracle 27.2 µs).
6. GEMM class at/above the floor: power-capped → NPU
   (A-098: 22.1 W package, net J/op beats CPU); overlap
   available → NPU (A-096); otherwise → GPU (A-098 latency
   + perf/W winner). GPU unplaceable → NPU in the FIT band
   (M ≥ 64) or past the crossover, else CPU spillover.
7. Anything else → A-017 policy delegate, reason prefixed
   `A017_POLICY_DELEGATE`.

## Standard fixtures (acceptance)

12 fixtures in `standard_fixtures()` (standard registry:
all present, Vulkan first-class; standard context: A-095
proven path): prefill_default → GPU/Vulkan; 
prefill_power_capped → NPU/XRT; prefill_overlap → NPU/XRT;
gemm_small_32 → CPU; decode_gemv → GPU/Vulkan;
sampling_vocab_131072 → CPU; attention_prefill →
GPU/Vulkan; embedding_lookup → CPU; elementwise_decode_row
→ CPU; embedding_projection_default → GPU/Vulkan;
prefill_below_m_band → GPU/Vulkan; transfer_default →
GPU/Vulkan (policy delegate). All 12 match.

Honesty cases proven alongside: unproven NPU context never
places the NPU (power-capped prefill falls to GPU); HIP
probe-only is never returned for any fixture; GPU-absent +
unproven spills a large GEMM to CPU; an empty registry
fails closed to NONE.

## Honesty bounds

- The planner decides and logs; it does not execute. No
  new device execution is claimed by this slice — every
  number above is a banked measurement from its source
  slice, encoded verbatim and pinned by the cost-table
  case (`planner.cost_tables_and_lines` fails if a filed
  number drifts).
- A-094's CPU column is the in-program oracle (naive,
  single-thread), an upper-bound comparator exactly as
  A-094 filed it; A-098's optimized-CPU row is the one
  used for the prefill optimum.
- Estimates are shape-exact or -1: the planner never
  interpolates a latency it did not measure.

## Suite (E-MASTER, this worktree)

612 passed / 2 failed / 2 skipped / 616 total (pin
re-pinned 610 -> 616 for the six new planner.* cases, all
PASS). Failures: the pre-existing J-022
gguf.tensor_directory_interface, plus ONE named
pre-existing intermittent, resilience.state_vault_rejects_
growth, which PASSED on its solo re-run
(spikes/a100_planner/rerun_state_vault.mojo;
hidden_files/a100/rerun_state_vault.log) -- green-to-
baseline. Log: hidden_files/a100_run_all.log; ledger:
hidden_files/A100_LEDGER.md. The suite ran solo
(ps-verified; team-25's suite had finished first).

## Next work

- A-101 (pipeline overlap) should consume `plan_op` for
  its prefill∥decode split; A-107 pins these fixtures as
  the placement regression battery in the full tier;
  A-108 judges default-on from the filed numbers.
