# A-102 - Spillover policy

**Verdict: PASS.** An oversized real model (8B-class, 4.91 GB of
tensor payload) placed per the spillover policy under a 1 GiB
accelerator capacity: the accelerator prefix (embed + blk.0..4,
973,963,264 bytes, 6 layers) on the GPU, the remaining 28 layers
(3,938,935,040 bytes) spilled to the CPU path - every layer
logged with its placement and reason, the log reproducible
byte-for-byte (digest 3486865965604444507 on both computations).
The first GPU-placed layer's 295,501,824-byte span was copied
into a real Vulkan buffer on the Radeon 8060S and read back
through the device mapping with an exact checksum match.

## The policy (core/spillover_policy.mojo)

Built on the banked A-076 GpuPressureGovernor (identical routing
arithmetic and ledgers, reused), the A-017 accelerator-first
order, and the A-064 residency accounting discipline. The whole
layer stack is decided before any allocation exists:

1. **Accelerator-first** - layers in stack order; every layer
   that fits the accelerator room (GPU cap AND live effective
   room, A-076 semantics) is placed on the accelerator.
2. **Capacity spill** - a spillable layer that no longer fits
   goes to the CPU path inside the bounded spill ledger, logged
   `reason=CAPACITY_SPILL`. On the unified pool the spilled
   placement is the same physical pages (A-008 zero-copy rule).
3. **Atomic MEM-003 refusal** - a non-spillable layer that does
   not fit, or a spill past the cap, refuses the WHOLE plan
   before any placement: the plan is simulated on a scratch
   governor, so a refusal moves no ledger and places nothing.
4. **Evidence-gated assist** - the accelerator-first law's one
   other lawful CPU placement: a layer marked assist-eligible
   sits on the CPU only when it carries measured evidence
   (`reason=ASSIST_MEASURED`, A-070 pattern), charged to the
   same bounded CPU budget. An unproven claim is ignored.
5. **Logged + reproducible** - the plan is a pure function of
   (layers, config, availability figures); the log header names
   the exact inputs, and an FNV-1a digest anchors the log text.

**A-100 integration point (honest dependency):** the A-100
placement planner (team-27) was building in parallel and had
NOT landed on banked main at A-102 build time. This slice does
not duplicate the planner's cost-table work: the planner, when
it banks, hands an ordered layer stack + capacity figures to
`plan_spillover` and consumes the PlacementPlan unchanged.

## The run (tests/bench_spillover_a102.mojo)

Fixture, A-049 fixture class (largest obtainable, sha-pinned,
real tensors): `Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf`,
sha256 `7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c`
(the A-067/A-081 pin; verified by the runner before and after),
4,920,739,232 bytes, 292 tensors, 32 layers. Layer byte sizes
were summed from the loader's own tensor byte math
(`GGUFSeer._tensor_byte_size`, the A-064 discipline) and sum
exactly to the loader payload total 4,912,898,304 bytes.

Device evidence: Vulkan device vendor 4098 (0x1002), type 1,
RADV identity confirmed (llvmpipe refused by the same check in
the in-suite device case). Live pool at run time: avail
127,842,103,296 of total 130,454,048,768 bytes.

Placement excerpt (full 34-layer log in hidden_files/a102_bench.log):

```
spillover-plan v1 layers=34 avail=127842103296 total=130454048768 gpu_cap=1073741824 spill_cap=17179869184 reserve=0
layer 0 name=embed bytes=295501824 place=GPU reason=ACCELERATOR_FIRST
layer 1 name=blk.0 bytes=138936320 place=GPU reason=ACCELERATOR_FIRST
...
layer 5 name=blk.4 bytes=122716160 place=GPU reason=ACCELERATOR_FIRST
layer 6 name=blk.5 bytes=122716160 place=CPU_SPILL reason=CAPACITY_SPILL
...
layer 33 name=output bytes=430956800 place=CPU_SPILL reason=CAPACITY_SPILL
totals gpu_bytes=973963264 cpu_spill_bytes=3938935040 cpu_assist_bytes=0 gpu_layers=6 cpu_layers=28
```

- Split shape: strict prefix - no GPU placement after the first
  spill (bench-asserted).
- Reproducibility: second computation, byte-identical log,
  digest 3486865965604444507 both times.
- Execution: GPU layer `embed`, span 295,501,824 bytes, copied
  to a RADV Vulkan buffer and read back - FNV-1a checksum
  3509279304991363980, source == device; buffer freed, shim live
  bytes back at baseline. CPU layer `blk.5`, span 122,716,160
  bytes, host checksum 1228005872102039465.
- Roomy control: capacity 16 GiB places all 34 layers on the
  accelerator (digest 3342200304612901917) - spill is a pressure
  behaviour, never the default.
- Bench wall 42.26 s, peak RSS 538,864 KiB (mmap streaming, not
  full residency).

## Suite

Seven in-suite cases (sched.spillover_* in
tests/test_spillover_policy_a102.mojo) prove the decision table,
the atomic refusal, the bounded spill ledger, the assist
evidence gate, log reproducibility, and real-device execution;
run_all re-pinned 610 -> 617 on this branch (the union total
reconciles at banking with A-100/A-101). Full-suite counts are
filed in hidden_files/A102_LEDGER.md from the run log.
