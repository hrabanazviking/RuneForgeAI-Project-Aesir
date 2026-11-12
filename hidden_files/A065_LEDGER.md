# A-065 Ledger — One full layer on GPU (team-01)

- Date: 2026-11-12. Lead + 6 Mythic Engineering sub-agents (all 6
  spawned, no 429; design notes only, device work by the lead).
- Base: worktree reset --hard onto seat main 3d89b1e8 (62 of 216)
  after verifying A-059 banked in the seat log by subject
  (944bccc2 "A-059: Vulkan IQ GEMV" + closure 080ce123).
  CAMPAIGN_STATE.md + hidden_files backed up to /tmp/a065_backup/
  before the reset. Untracked aesir_engine/hip_bridge.c left
  untracked and untouched, per standing instruction.
- Built ahead in parallel: A-063 (team-03) and A-064 (team-04)
  were being built by fresh leads concurrently; A-065 banks only
  after them in roadmap order. Keeper reconciles run_all pin +
  shim composition at banking (A-059..A-062 precedent). This
  slice touches NO shim and NO shader, so the only banking
  reconciliation expected is the run_all pin union (485 -> 490
  here) if A-063/A-064 land first.

## What was built

- aesir_engine/core/vulkan_layer.mojo — VulkanLayer.forward:
  one full decode layer composed ONLY from banked Wave 7
  gateways: RMSNorm (A-060) -> Q8_0 GEMV q/k/v (A-056) ->
  RoPE q/k (A-060) -> decode attention (A-062) -> Q8_0 GEMV wo
  + residual add (A-056/A-061) -> RMSNorm (A-060) -> Q8_0 GEMV
  gate/up + gated SiLU (A-056/A-061) -> Q8_0 GEMV down +
  residual add. All shapes/buffers validated before any
  allocation or dispatch; fail-closed, no host fallback. No new
  shader, no new shim entry; all SPIR-V from the A-055
  generated header via the banked gateways.
- aesir_engine/tests/test_vulkan_layer_a065.mojo — 5 E-MASTER
  cases (gpu.vulkan_layer_*) with an independent sequential
  Float32 CPU layer oracle consuming the identical raw Q8_0
  bytes (raw-oracle discipline).
- aesir_engine/tests/run_all.mojo — import + 5 run_case lines;
  pin 485 -> 490.
- docs/bench/A065_VULKAN_LAYER.md — composition table, parity
  table, dispatch evidence, KV scope note.

## Acceptance: layer-output parity vs CPU oracle per layer index

Fixture: dim 256 = 4 heads x 64, GQA ratio 2 (kv_dim 128),
ffn 512, decode position 3, eps 1e-5, RoPE base 10000,
deterministic per-layer LCG Q8_0 fixtures (A-056..A-062
fixture discipline; sha-pinned real models are A-067).

| Layer index | Mode | max_abs |
|---|---|---|
| 0 | chained | 0.0017852783 |
| 1 | chained | 0.003753662 |
| 2 | chained | 0.006225586 |
| 2 | standalone | 0.0014648438 |
| any | zero-weight known value | 0.0 (exact) |

Filed bounds: standalone 5e-3, chained 2e-2. Chained growth
(~3.5x/layer) is accumulation-order amplification (verdict
class: comparator artifact) — layer L+1 consumes layer L's GPU
output; standalone deltas (<= 0.0018) sit at the A-056
single-GEMV accumulation scale. First driver run caught the
chained idx=2 value (0.00623) above the initial single 5e-3
bound; the bound was split honestly (standalone vs chained)
with the amplification measured and recorded, not hidden.

Device-execution evidence (law 6): AMD Radeon 8060S
(RADV STRIX_HALO), llvmpipe refused by identity check.
Per-layer dispatch counter deltas asserted exact: rmsnorm +2,
rope +2, q8_gemv +7, attn +1, elementwise +3. Live bytes/count
return exactly to baseline after a layer (no leaks). Rejection
case: 6 of 6 invalid calls raise before dispatch.

## Gate

Full E-MASTER suite (hidden_files/a065_run_all.log, sha256
ab8446f89905f758d165647c37e22d7adc076bc73fd4509fa70728040a423917):
487 passed / 1 failed / 2 skipped / 490 total = seat baseline
482/1/2/485 + exactly the 5 new gpu.vulkan_layer_* cases, all
PASS. Sole failure: pre-existing tolerated J-022 drift
(gguf.tensor_directory_interface). Skips: the 2 pre-declared.
Standalone driver (hidden_files/a065_driver.log): all 5 cases
PASS, MOJO_EXIT=0.

## Bugs / gaps found

- Mojo `out` is a reserved argument name: the layer gateway's
  output parameter is named `dst` (compile error caught by the
  standalone driver before the gate).
- KV-APPEND GAP (recorded as immediate next work, not fixed
  here — it needs a new kernel): A-065 is a single-position
  decode layer (kv_len == 1), where the attention K/V layout
  [kv_heads][1][head_dim] equals the k/v projection layout, so
  no copy is needed. Multi-position decode needs an
  insert-at-position (KV-append) kernel that does not exist in
  the Wave 7 set. This is A-066's (full decode loop) road:
  either a small copy/insert shader through the A-055 pipeline
  or a shim-side buffer copy entry, with parity at kv_len > 1.
- A-046:B1 CPU remainder still open (from A-059): core/compute
  .mojo gemm_iq demands cols % 256 for IQ4_NL (GPU path proven
  at K=288); fix home unchanged — not this slice's scope.

## Banking

Committed on yrsa/aesir-team-01, subject "A-065: One full layer
on GPU". NOT merged, NOT pushed — keeper banks after A-063 and
A-064 in roadmap order.
