# A-066 Ledger — Full decode loop on GPU (team-02)

- Date: 2026-11-12. Lead + 6 Mythic Engineering sub-agents
  (all 6 spawned, no 429; design/research notes only, all
  device work by the lead).
- Base: worktree reset --hard onto seat main 522fdbe7
  (65 of 216, A-065 closure) after verifying the seat log.
  CAMPAIGN_STATE.md + hidden_files backed up to
  /tmp/a066_backup/ before the reset. Untracked files left
  untracked and untouched.
- Inherited road (A-065 ledger): the KV-APPEND GAP — A-065 is
  single-position decode (kv_len == 1); multi-position decode
  needed an insert-at-position kernel absent from Wave 7.

## What was built

- aesir_engine/shaders/kv_append.comp + embed_gather.comp +
  attention_decode_strided.comp — three new compute kernels
  through the A-055 pipeline discipline: glslangValidator +
  spirv-val on purpleraider, compiled twice and byte-compared
  (kv_append 2020 B sha256 82c16b64…, embed_gather 1496 B
  01fa2ff6…, attention_decode_strided 5408 B e03262ac…).
  Generated header + SHADER_MANIFEST extended ADDITIVELY:
  13 -> 16 kernels; all 13 prior SPIR-V hashes byte-identical
  (verified in the manifest diff: the only removed line is
  kernel_count). NOTE: scripts/build_shaders.py was NOT run
  wholesale — it globs 17 .comp sources (the 4 IQ sources
  whose SPIR-V lives hand-embedded in the shim since A-059)
  while the manifest registers 13, so --check already fails
  at the A-065 baseline; the three kernels were compiled
  individually with the identical toolchain/flags and
  registered in the same format. Pre-existing condition,
  recorded here; not this slice's scope to re-architect.
- aesir_engine/vulkan_buffer_shim.c — one shared 2-binding
  move-dispatch helper + aesir_vk_buffer_kv_append /
  aesir_vk_buffer_embed_gather entries, and
  aesir_vk_buffer_attn_decode_strided cloned from the A-062
  entry (20-byte push incl. max_len; separate counter so
  A-062 counts stay exact). NO vkCmdCopyBuffer is resolved:
  append/gather are compute dispatches, so the A-019
  zero-copy counter still cannot increment (its suite cases
  pass in the gate below).
- aesir_engine/core/vulkan_kv_cache.mojo — VulkanKvCache
  .append + VulkanEmbed.gather gateways (fail-closed).
- aesir_engine/core/vulkan_layer.mojo — VulkanLayer
  .forward_kv: the A-065 composition with KV-append +
  strided attention over caller-owned caches; forward()
  untouched, A-065 dispatch counts unchanged.
- aesir_engine/core/vulkan_attention.mojo — additive
  decode_attention_strided + strided_dispatch_count.
- aesir_engine/core/vulkan_decode.mojo — VulkanDecode
  .generate: embed gather -> per-layer forward_kv -> final
  RMSNorm -> Q8_0 LM head -> greedy argmax, per step; host
  reads back only the device-produced token id. Fail-closed,
  no host fallback; prompt enters as RAW token ids.
- aesir_engine/tests/test_vulkan_decode_a066.mojo — 4
  E-MASTER cases with an independent sequential Float32 CPU
  oracle carrying its own multi-position KV cache.
- aesir_engine/tests/run_all.mojo — import + 4 run_case
  lines; pin 501 -> 505.
- aesir_engine/tests/test_spirv_pipeline_a055.mojo —
  kernel_count 13 -> 16, new kernel names/consts registered
  (A-063 precedent).
- docs/bench/A066_VULKAN_DECODE_LOOP.md — composition,
  parity, dispatch evidence.

## Acceptance: greedy token-exact vs the CPU oracle

Fixture: dim 256 = 4 heads x 64, GQA 2, ffn 512, 2 layers,
vocab 96, max_len 16, eps 1e-5, RoPE base 10000, RAW prompt
[5, 17, 42], 8 greedy tokens. GPU == oracle at all 8 steps:
[12, 72, 74, 66, 66, 23, 26, 86]. Oracle top-1/top-2 logit
gaps: 1.463 / 6.245 / 1.212 / 3.632 / 0.608 / 3.509 / 1.314 /
0.283 — minimum ~45x the A-065 chained accumulation delta
(0.0062), so token-exactness is a sound verdict.
Component parity: KV-append bit-exact at 4 positions, slots
isolated; strided attention (kv_len 3 of 16) max_abs
5.96e-08. Device evidence (law 6): AMD Radeon 8060S (RADV
STRIX_HALO), llvmpipe refused; per generation embed +10,
kv_append +40, strided attn +20, greedy +8; live bytes back
to baseline. Rejection: 6 of 6 raise before dispatch.

## Gate

Full E-MASTER suite (hidden_files/a066_run_all.log):
502 passed / 1 failed / 2 skipped / 505 total = seat baseline
498/1/2/501 + exactly the 4 new gpu.vulkan_decode_* cases,
all PASS. Sole failure: pre-existing tolerated J-022 drift
(gguf.tensor_directory_interface). Skips: the 2 pre-declared.
Standalone driver (hidden_files/a066_driver.log): all 4
cases PASS, MOJO_EXIT=0.

## Bugs / gaps found

- STRIDED-ATTENTION GAP (found + fixed in-slice): the A-062
  attention kernel derives its cache row stride from kv_len
  itself, so it reads wrong rows from any max_len-deep cache
  (kv_len < max_len). Fixed additively with the
  attention_decode_strided kernel + shim entry + gateway;
  the A-062 kernel/SPIR-V are untouched and its cases pass.
- Mojo: List[VulkanLayerWeights] is not ImplicitlyCopyable,
  so VulkanDecodeWeights carries no Copyable trait (compile
  error caught by the standalone driver before the gate).
- build_shaders.py wholesale-regeneration mismatch (17
  sources vs 13 registered) — pre-existing at baseline,
  recorded above; fix home is a future pipeline slice, not
  A-066's scope.
- A-046:B1 CPU remainder still open (from A-059) — unchanged.

## Banking

Committed on yrsa/aesir-team-02, subject "A-066: Full decode
loop on GPU". NOT merged, NOT pushed — keeper banks after
A-065 (already banked) in roadmap order.
