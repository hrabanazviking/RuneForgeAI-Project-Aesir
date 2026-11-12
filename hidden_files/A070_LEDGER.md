# A-070 Ledger - Lawful CPU assist (team-03)

- Status: BUILT + TESTED + COMMITTED 2026-11-12 on
  yrsa/aesir-team-03, base 8a548607 (seat closure, 68 of 216
  banked, A-001..A-068). Awaiting banking by the keeper in
  roadmap order (A-069 banks first). Do NOT merge or push
  from this worktree.
- Crew: lead (continuation) + 6 Mythic Engineering
  sub-agents (inventory x2, bench math, house style,
  GPU-replacement research, test design) - all returned,
  no rate limits.
- Continuation state verified from disk: HEAD 8a548607,
  uncommitted bench driver + baseline log intact; the
  17:19 edit_a070.py was TRUNCATED at line 122 (pairs 1-5
  complete, pair 6 a stub, no decode pairs, no main guard)
  and never applied (git diff empty). It was completed in
  place (same design, pairs preserved) and applied clean:
  19 edits vulkan_real_model.mojo, 6 vulkan_decode.mojo,
  1 bench driver. One compile fix in-slice: Mojo aliasing
  rule - mut-self _upload/_upload_gains call sites now copy
  the allocation to a local first. Two test-file compile
  fixes (List transfer ^, String byte_length).

## Deliverables
- core/vulkan_real_model.mojo: CpuAssistStats in-path
  accounting (stream/gains/embed/permute/kvpack/logits/
  sanitize + step wall), assist_stats() accessor, pure
  policy classifier (assist_verdict / assist_is_lawful,
  ASSIST_* ids 0..9, VERDICT_* codes), stitch_chunk_append
  + stitch_chunk_scatter oracle; lm_head zero-fill REMOVED.
- core/vulkan_decode.mojo: per-layer-per-step allocator
  churn REMOVED - ping-pong layer scratch (2 buffers).
- tests/test_cpu_assist_a070.mojo: 6 cases; run_all pin
  518 -> 524.
- tests/bench_cpu_assist_a070.mojo: baseline sections +
  A070_STATS in-path print.
- docs/bench/A070_CPU_ASSIST_INVENTORY.md: full inventory.

## Measurements (RADV STRIX_HALO, Llama-3.1-8B Q4_K_M,
## RAW prompt, 16 steps; logs below)
- Baseline (banked code): step steady 664-681 ms; embed
  4 us; permute Q 3 us; sanitize 109 us; host argmax 150 us;
  GPU greedy 524 us; alloc/free 15 us/pair; KV pack replica
  44 us/layer at kv_len 16.
- In-path (this slice): step avg 686 ms; stream_upload
  224/step, 4,185 MB/step, 392 ms/step (57.1%) LAWFUL
  spillover; gains 0.52 ms/step trivial; permute round trip
  23.75 ms/step (3.5%) DOES NOT PAY - roaded; kv_pack
  12.11 ms/step at kv_len ~8.5, linear in kv_len (~0.7 s/
  step class at _MAX_POS 512 extrapolated) DOES NOT PAY at
  scale - roaded; lm_head stitch 28.39 ms/step contract
  transfer, zero-fill removed; sanitize 0.106 ms/step
  trivial; host argmax 150 us vs GPU greedy 544 us lawful.
  Named assists 457 ms/step = 66.7% (spillover-dominated).
- Behaviour unchanged: bench argmax sequence identical to
  baseline at all 16 positions; A-066/A-067 suite cases
  re-pass on the ping-pong loop and stitched lm_head.
- Prefill (A-068 vulkan_gemm): zero host assists in the
  call (fully device-resident) - inventory states none.

## Suite (counts READ FROM LOG)
- hidden_files/a070_run_all.log (sha256
  d62688352726b44f82ae172fec583fd4e14659ef96071794c9e5b618bb2e0bb2):
  521 passed / 1 failed / 2 skipped / 524 total = baseline
  515/1/2/518 + exactly the 6 new cpu_assist.* cases, all
  PASS. Sole failure = pre-existing gguf.tensor_directory_
  interface J-022 drift (roads A-165/A-121). Skips = the 2
  pre-declared (vision.cuda_session_image_chat,
  rag.real_engine_integration).
- Bench log: hidden_files/a070_bench.log (sha256
  c234229a622ff12a1964a6b10c9f76bf44efd58b40d64ef3ba79fc5f59e91a86);
  baseline hidden_files/a070_bench_baseline.log.

## Roads / immediate next work
1. Persistent device KV for VulkanRealModel (kv_pack does
   not pay at scale) - VulkanKVCache pattern from A-066;
   first real-model integration slice or A-066 banking
   reconciliation owns it.
2. GPU RoPE permutation bridge kernel (rope_permute round
   trip 23.75 ms/step) - rope_permute.comp following the
   gemv_row_permute precedent.
3. Total weight residency (stream_upload 57.1% of step) -
   raised shim slot cap or offset-addressed GEMV; A-064
   follow-on, already filed at A-067.
4. Device-greedy generation variant skipping the lm_head
   readback when only argmax is needed.
5. VulkanLayer.forward_kv ~10 host-sequenced sync
   readbacks per layer: dispatch sequencing, A-071
   (async dispatch) territory - noted, not counted here.
