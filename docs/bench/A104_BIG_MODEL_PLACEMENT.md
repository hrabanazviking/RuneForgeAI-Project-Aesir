# A-104 — Big-model placement

Wave 12 (Heterogeneous scheduling). The largest sha-pinned
fixture that fits the 128 GB pool runs with a GPU/CPU layer
split. *Acceptance:* coherent generation + placement +
memory accounting filed. **Verdict: PASS** — split run
coherent, placement measured on the real gfx1151, full
accounting below; suite placement.big_model_* 6/6 PASS.

- Date: 2026-11-13
- Host: purpleraider, AMD Radeon 8060S (gfx1151),
  RADV STRIX_HALO — executor log line: `Vulkan0 : AMD
  Radeon 8060S Graphics (RADV STRIX_HALO) (128506 MiB,
  127798 MiB free)`. llvmpipe never appears.
- Module: `aesir_engine/core/big_model_placement.mojo`
  (split solver + accounting), tests:
  `aesir_engine/tests/test_big_model_placement_a104.mojo`,
  evidence: `hidden_files/a104/`.

## Fixture (largest available, stated honestly)

Inventory of the whole machine found exactly one real
instruct model GGUF: the A-049/A-067/A-081 pinned
`Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf` — no larger
real model exists on purpleraider and none was downloaded
(this slice downloads nothing). The only bigger GGUF is
the A-049 synthetic oversized fixture (41 GB, random
tensors, cannot generate), so the largest fixture that
can satisfy the acceptance is the 8B:

- sha256 `7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c`
  — re-verified before AND after every run
  (`hidden_files/a104/sha_before.txt` == `sha_after.txt`).
- size 4,920,739,232 bytes; tensor payload 4,912,898,304 B
  (32 layers = 4,186,439,680 B of GGUF directory spans;
  embedding 295,501,824 B; output block 430,956,800 B).
  Per-layer spans: `hidden_files/a104/layer_bytes.txt`.
- Pool: MemTotal 127,396,532 KiB = 130,459,705,344 B
  (`hidden_files/a104/meminfo.txt`); the model + full KV
  (5,449,769,216 B accounted) fits with 24x headroom.

## The split run (device execution evidence)

Executor: llama.cpp `llama-cli` b1-dd6b945 (the machine's
own build), Vulkan backend, raw completion prompt (no
chat template), greedy (temp 0), seed 104:

```
llama-cli -m <fixture> -ngl 16 -c 4096 -n 96 --temp 0 \
  --seed 104 -st --verbose -p 'The old lighthouse keeper
  of the northern fjord climbed the tower at dusk, lit
  the great lamp, and watched the longships'
```

Log (`hidden_files/a104/split16_verbose.log`):

- `offloaded 16/33 layers to GPU`
- `Vulkan0 model buffer size = 2290.21 MiB`
- `Vulkan_Host model buffer size = 2395.10 MiB`
- `Vulkan0 KV buffer size = 240.00 MiB`,
  `CPU KV buffer size = 272.00 MiB`
- `Vulkan0 compute buffer size = 139.50 MiB`,
  `Vulkan_Host compute buffer size = 36.03 MiB`,
  output buffer 0.49 MiB
- generation 28.2 tok/s (CPU-only oracle run: 20.7 tok/s)

## Generation (coherence-graded, raw-oracle discipline)

Split run continuation (`split16_out.txt`): "…sail into
the fading light, their sails billowing like white clouds
as they made their way through the narrow passage. The
old lighthouse keeper stood at the top of the tower, his
eyes squinting against the wind and spray, as he gazed
out at the ships…" — fluent, on-topic, no degeneration
across all 96 tokens. The CPU-only oracle (-ngl 0, same
prompt/seed/greedy, `cpu0_out.txt`) is equally coherent
and agrees with the split run for the first ~40 tokens,
then diverges in wording ("his eyes scanning the horizon
as the last rays of the sun dipped below the water…") —
the expected CPU-vs-Vulkan numeric divergence, graded on
coherence per the standing law, not token-exactness.
**Coherence verdict: PASS on both placements.**

## Placement + memory accounting

Plan (solver, budget = embedding + last-16 spans =
2,404,941,824 B, ctx 4096): gpu_layers=16, cpu_layers=16,
gpu_weights=2,404,941,824, cpu_weights=2,507,956,480,
kv_gpu=268,435,456, kv_cpu=268,435,456, total accounted
5,449,769,216 B, FITS_POOL. The executor's measured
buffers reconcile with the plan:

| Account | Plan | Executor measured | Note |
|---|---|---|---|
| GPU weights | 2,404,941,824 B (2293.5 MiB) | 2290.21 MiB | embedding + last-16 suffix; -0.14% = inter-tensor padding the allocator does not charge |
| CPU weights | 2,507,956,480 B (2391.8 MiB) | 2395.10 MiB | first-16 + output block; mirror +0.14% |
| Total weights | 4,912,898,304 B (4685.30 MiB) | 4685.31 MiB | exact |
| KV GPU / CPU | 256 / 256 MiB | 240 / 272 MiB | one-layer shift in the executor's KV split; total exact |
| KV total | 536,870,912 B (512 MiB) | 512.00 MiB | exact |
| Compute + output buffers | — (executor-internal) | 139.50 + 36.03 + 0.49 MiB | filed for completeness |

Solver rules (suite-proven): suffix fill (the executor
offloads the last N layers), embedding charged to GPU,
output block to CPU in a partial split (all-GPU in a full
split), embedding-only budget is NOT a split, pool gate
is hard (weights + KV <= pool or FITS_POOL is false),
GPU layers monotone in the budget, and the budget itself
comes from the A-076 governor's effective room
(`budget_from_pressure` = `GpuPressureConfig.
 effective_gpu_room`, verbatim). Per-op placement inside
layers remains the A-100 planner's; residency of GPU
layers is the A-064 gateway's; this module is the
per-layer solver those two deliberately do not own.

## Suite

E-MASTER on base 2bddc175 + this slice, solo, two runs
(`hidden_files/a104/suite.log`, `suite_rerun.log`):
both 624 passed / 2 failed / 2 skipped / 628 total.
Run 1 failures: the pre-existing J-022
(gguf.tensor_directory_interface) + the named
intermittent resilience.state_vault_rejects_growth.
Run 2 failures: J-022 + the named intermittent
gpu.amd_hip_stream_async_round_trip — each run carries
only J-022 plus at most one named intermittent, so the
slice is green-to-baseline (baseline on 2bddc175:
619/1/2/622). All six placement.big_model_* cases PASS
in both runs. Finish pin re-pinned 622 -> 628.
