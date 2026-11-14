# A-108 - Part IV Gate (Wave 12 closer)

**Machine:** purpleraider (ASUS ROG Flow Z13, Ryzen AI Max+ 395,
Radeon 8060S gfx1151, XDNA 2 NPU, 128 GB unified LPDDR5X).
**Base:** banked main 9f75ab0d (105 of 216, A-001..A-105).
**Gate question (roadmap):** placement planner default-on or
honestly scoped to where it wins; Capability Ledger updated;
every Part IV experiment has a filed verdict.

## 1. Planner decision: HONESTLY SCOPED (not default-on)

The A-100 planner is a pure decision module. At this commit no
generation dispatch path calls `plan_op` - that is grep-provable
in the tree, so a default-on claim would be false. What the
banked evidence does prove, and what this gate makes the standing
scope, is that the planner is the decision authority for every
placement-consuming surface that exists:

- `doctor` renders its fixture lines and summary;
- A-103 failure re-planning re-decides every remaining step
  through `plan_op` on the survivor registry;
- the A-102 spillover, A-104 big-model and A-105 fairness
  policies are built on its measured tables and the A-076
  governor it encodes.

Where it wins, with the banked numbers:

| Scope | Winner | Evidence |
|---|---|---|
| Prefill projection, default | GPU/Vulkan | A-098: 67.5 us, 51.20 GFLOP/s/W at 128x1024x1024 |
| GPU kernels generally | Vulkan, never HIP | A-085 medians: Vulkan 0.175-0.454 ms vs HIP 1.76-5.20 ms per call; A-086 probe-only never placed |
| Prefill GEMM, power-capped or overlapped | NPU | A-094 band (M >= 64, >= ~0.1M MACs); A-096 overlap ~4.2 ms fully hidden; A-098 NPU 22.1 W vs GPU 77.7 W package |
| Sampling | CPU | A-097: 19.9 us vs NPU 104.8 us at V=32768 |
| Below-floor shapes (e.g. 32^3 GEMM) | CPU | A-094: NPU 0.29x at 32^3, 1.88x at 64^3 |
| Decode GEMV, embedding lookup | never NPU | A-094 NOT FIT (dispatch floor ~93.0 us; no arithmetic) |
| Any NPU failure | CPU fallback | A-099 contract, FALLBACK_<NAME> logged |

**Named road to default-on:** a future slice that wires
`plan_op` into the generation dispatch path and re-measures
end-to-end. Until that slice banks with numbers, the planner's
status is SCOPED, and every surface that claims placement
decisions routes through it or names why not.

## 2. Verdicts for every Part IV experiment (A-082..A-107)

Filed as data in `aesir_engine/core/part_iv_gate.mojo`
(`part_iv_verdicts()`, 26 rows, order-pinned by test) and in
CAPABILITY_LEDGER.md section 25 (Z13-P4-082..108):

- POSITIVE (16): A-082, A-083, A-084, A-086, A-087, A-089,
  A-091, A-092, A-093, A-096, A-099, A-101, A-102, A-103,
  A-104, A-105.
- NEGATIVE (3): A-088 (HIP managed memory does not beat
  Vulkan residency), A-090 (HIP not integrated; instability
  evidence is the verdict, no soak claimed), A-097 (NPU
  sampler loses to a CPU scan).
- SCOPED (5): A-085 (Vulkan primary / HIP parked), A-094
  (NPU fit band), A-095 (neutral-with-value offload), A-098
  (GPU wins the shape; NPU value is power + overlap), A-100
  (planner scope per section 1 of this doc).
- IN_FLIGHT (2): A-106 (team-27) and A-107 (team-25) were
  building in parallel at gate time and had NOT landed on
  banked main. They are filed IN_FLIGHT with no result
  claimed; their verdicts are owed at their banking, and
  the keeper re-checks this gate record when they bank.

No unexplained rows: the gate tests fail if any row lacks a
verdict class, a headline, or an evidence pointer, or if the
in-flight set differs from {A-106, A-107}.

## 3. Capability Ledger

Section 25 (Z13-P4-*) added to CAPABILITY_LEDGER.md,
deliberately outside the section-3 AES-* population, exactly
as sections 23 and 24 did for Parts II and III.

## 4. Go / No-Go

Part V correctness work: **GO**, under the unchanged oracle
discipline - raw prompts only, teacher-forcing rank + logit
gap, near-tie band rank <= 2 with sub-logit gap, comparator
artifacts as a verdict class, IQ graded on coherence, and no
accelerator claim without device-execution evidence.
