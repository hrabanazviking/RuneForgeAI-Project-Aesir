# A-069 Ledger — Chunked prefill (team-02)

- Date: 2026-11-12. Lead + 6 Mythic Engineering sub-agents
  (design notes only, device work by the lead). This ledger,
  the bench doc, and the commit were completed by a fresh
  lead finishing the slice from disk state: the previous
  lead had built everything below and recorded passing
  standalone driver + bench runs, and stopped before the
  full E-MASTER gate and the commit (verified from disk:
  worktree HEAD was the seat closure 8a548607, 68 of 216
  banked, with all A-069 work uncommitted in the tree).
- Base: worktree HEAD 8a548607 (banking closure A-068,
  68 of 216 banked) on yrsa/aesir-team-02.

## What was built

- aesir_engine/core/vulkan_prefill.mojo —
  VulkanChunkedPrefill: a long prompt is processed in
  chunks of at most chunk_size tokens; per chunk one full
  transformer layer runs batched over the chunk's tokens
  (A-068 F32 GEMM projections, A-060 batched RMSNorm,
  A-061 elementwise), the chunk's k/v rows are written
  incrementally into the caller-owned KV caches on the
  GPU, and chunk causal attention reads the caches (prior
  chunks plus the causal prefix of this chunk). The only
  state persisting across chunks is the KV cache itself.
  Weights are dense Float32 (the A-068 F32 GEMM path) for
  one layer; fail-closed, all shapes validated before any
  allocation or dispatch; no host fallback.
- Three new kernels, all through the A-055 SPIR-V
  pipeline and registered in SHADER_MANIFEST.json +
  generated header (kernel_count 22 -> 25, every prior
  hash byte-identical; SPIR-V pipeline cases re-pinned
  to 25 kernels / 25 header arrays):
  - rope_batched (shaders/rope_batched.comp): RoPE with
    per-row GLOBAL positions (base_position + token
    index). Restarting positions per chunk would collide
    chunk 2+ keys with chunk 1 keys; global positions
    are the correctness crux of this slice.
  - kv_append_chunk (shaders/kv_append_chunk.comp): a
    chunk of token-major k/v rows copied into the
    [kv_heads][max_len][head_dim] cache at slots
    chunk_start.. — pure data movement (no
    vkCmdCopyBuffer, A-019 discipline), bit-exact, so a
    chunked cache is byte-identical to the unchunked one.
  - attention_prefill (shaders/attention_prefill.comp):
    causal attention for a chunk of query tokens over
    the cache. It materialises NO score matrix (scores
    recomputed in a second pass), so attention workspace
    is O(1) per query, never O(seq^2); positions
    accumulate in increasing (unchunked) order.
- aesir_engine/vulkan_buffer_shim.c — entry points
  aesir_vk_buffer_rope_batched,
  aesir_vk_buffer_kv_append_chunk,
  aesir_vk_buffer_attn_prefill_chunk with per-kernel
  dispatch counters (law-6 device-execution evidence;
  each increments only after submit + wait-idle).
- aesir_engine/tests/test_vulkan_prefill_a069.mojo — 7
  E-MASTER cases (gpu.vulkan_chunked_prefill_*) with an
  independent sequential Float32 CPU oracle (raw-oracle
  discipline: per token, in prompt order, textbook layer
  at the token's global position).
- aesir_engine/tests/run_all.mojo — import + 7 run_case
  lines; pin 518 -> 525.
- aesir_engine/a069_driver.mojo (+ identical copy at
  hidden_files/a069_driver.mojo) — standalone driver.
- aesir_engine/tests/bench_chunked_prefill_a069.mojo —
  chunked prefill bench (1k identity + 8k bounded run).
- docs/bench/A069_CHUNKED_PREFILL.md — composition +
  measured numbers.

## Acceptance (standalone driver, hidden_files/a069_driver.log)

A069_DRIVER_ALL_PASS, MOJO_EXIT=0. All 7 cases PASS on
AMD Radeon 8060S (RADV STRIX_HALO; llvmpipe refused by
identity check):

- CPU oracle parity (seq=40, chunk=16 as 16/16/8 partial
  final chunk, max_len=64): outputs max_abs 1.13e-06,
  K max_abs 4.65e-06, V max_abs 9.54e-07 — accumulation-
  order scale only.
- Identical to unchunked: chunk 16 vs single-chunk and
  chunk 7 vs single-chunk, outputs + K + V all 0.0
  (bitwise).
- Causal isolation: perturbing token 20 leaves positions
  <20 bitwise unchanged (0.0) and changes >=20 (2.33).
- RoPE global positions: chunk starting at position 8
  matches the global oracle (5.96e-07) and differs from
  restarted local positions (1.90).
- KV append chunk slots: 5 tokens at slot 7 bit-exact,
  neighbours untouched.
- Rejection: zero tokens, chunk overrun, head_dim 128,
  append overrun, bogus id — all raise before dispatch,
  counters unmoved.
- Dispatch evidence + bounds: per-chunk counter deltas
  rope 2 / kv 2 / attn 1 / rmsnorm 2 / gemm 7 / elem 3;
  8k plan = 32 chunks of 256; workspace sized by the
  chunk only; live-buffer delta 0 (no leaks).

## Bench (hidden_files/a069_bench.log)

A069_BENCH: PASS, MOJO_EXIT=0. 8k prompt (seq=8192) in
32 chunks of 256: 0.617 s, 13,273.96 tok/s. Bounded
memory: chunk-256 workspace 393,216 bytes vs 12,582,912
for a single-chunk 8192 pass (32x smaller, exactly the
chunk ratio); one 8k KV cache 1,048,576 bytes; the
never-materialised 8k score matrix would have cost
268,435,456 bytes per head. Live buffers mid-8k run:
2,191,616 bytes. Identity at seq=1024: chunked vs whole
outputs + K bitwise 0.0. Dispatch totals for the bench
run: rope_batched 74, kv_append_chunk 74,
attention_prefill 37. Live buffers after free: 0.

## Gate

Full E-MASTER suite (hidden_files/a069_run_all.log,
sha256 144d185d0e571ca10fdeb08db90973799c919a0faf5d86d3bbc2ff9f40dddf55):
522 passed / 1 failed / 2 skipped / 525 total = seat
baseline 515/1/2/518 + exactly the 7 new
gpu.vulkan_chunked_prefill_* cases, all PASS. Sole
failure: pre-existing tolerated J-022 drift
(gguf.tensor_directory_interface). Skips: the 2
pre-declared. MOJO_EXIT=1 is driven solely by that
tolerated failure (same as the A-068 gate log). Zero
regressions.

## Bugs / gaps found

- No new defect is evidenced by the driver, bench, or
  suite logs for this slice: every A-069 case passed on
  the recorded runs and no in-slice fix was needed.
  Recorded honestly rather than inventing one.
- Scope boundary (honest, from the gateway header):
  dense Float32 weights for ONE layer; the Q8_0 decode
  layer (A-065/A-066) is untouched, and embedding
  ingestion stays the caller's. The attention kernel's
  fixed accumulator bounds head_dim to 64.
- A-046:B1 CPU remainder still open (from A-059):
  core/compute.mojo gemm_iq demands cols % 256 for
  IQ4_NL; fix home unchanged — not this slice's scope.

## Banking

Committed on yrsa/aesir-team-02, subject "A-069: Chunked
prefill". NOT merged, NOT pushed — keeper banks in
roadmap order from the seat.
