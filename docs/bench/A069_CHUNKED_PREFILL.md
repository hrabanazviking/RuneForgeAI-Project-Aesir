# A-069 — Chunked prefill (bounded-memory prompt processing)

A long prompt is processed in chunks of at most
`chunk_size` tokens instead of one monolithic pass. For
each chunk, one full transformer layer runs batched over
the chunk's tokens, the chunk's K/V rows are written
incrementally into the caller-owned KV caches on the GPU,
and chunk causal attention reads the caches — all prior
chunks plus the causal prefix of the current chunk. The
caller streams chunks (upload chunk → layer chunk → read
chunk outputs); the only state that persists across
chunks is the KV cache itself.

Module: `aesir_engine/core/vulkan_prefill.mojo`
(`VulkanChunkedPrefill`), composing the banked gateways
(A-068 F32 GEMM projections, A-060 batched RMSNorm,
A-061 elementwise) with three new kernels. Tests:
`aesir_engine/tests/test_vulkan_prefill_a069.mojo`
(7 E-MASTER cases, gpu.vulkan_chunked_prefill_*); bench:
`aesir_engine/tests/bench_chunked_prefill_a069.mojo`.

| Kernel | Source | Job |
|---|---|---|
| rope_batched | aesir_engine/shaders/rope_batched.comp | RoPE with per-row GLOBAL positions (base_position + token index) |
| kv_append_chunk | aesir_engine/shaders/kv_append_chunk.comp | chunk of token-major K/V rows into the [kv_heads][max_len][head_dim] cache at chunk_start slots, bit-exact |
| attention_prefill | aesir_engine/shaders/attention_prefill.comp | causal attention for a chunk of queries over the cache; NO materialised score matrix |

Pipeline registration: all three kernels were compiled
through the A-055 SPIR-V pipeline and registered in
`aesir_engine/shaders/SHADER_MANIFEST.json` and the
generated header `aesir_engine/shaders/generated/aesir_shaders_spv.h`:
manifest kernel_count 22 → 25, every prior hash
byte-identical.

## Why chunked == unchunked (bitwise)

Every kernel's math is per-token independent of the chunk
partition: GEMM workgroups are per (row, token); RoPE
uses global positions, so a token's rotation is the same
in any chunking; KV appends are bit-exact copies;
attention accumulates cache positions in the same
increasing order as the unchunked pass and never stores
a score matrix (scores are recomputed in a second pass).
The measured result (hidden_files/a069_driver.log and
a069_bench.log): chunk 16 and chunk 7 vs single-chunk at
seq=40, and chunk 256 vs whole at seq=1024, agree at
max_abs 0.0 on outputs and K/V caches.

## Parity vs CPU oracle (raw-oracle discipline)

Independent sequential Float32 CPU oracle consuming the
identical dense operands, per token in prompt order at
global positions. Source: hidden_files/a069_driver.log
(A069_DRIVER_ALL_PASS).

| Case | Result |
|---|---|
| Oracle parity, seq=40 chunk=16 (16/16/8) | out 1.13e-06, K 4.65e-06, V 9.54e-07 |
| Identical to unchunked (chunk 16, chunk 7) | bitwise 0.0 |
| Causal isolation (perturb token 20) | <20 bitwise 0.0; >=20 changed (2.33) |
| RoPE global positions (chunk at 8) | vs global 5.96e-07; vs restarted 1.90 |
| KV append (5 tokens at slot 7) | bit-exact, neighbours untouched |
| Rejection (zero tokens, overruns, head_dim 128, bogus id) | all raise pre-dispatch |

## Measured performance + bounded memory (hidden_files/a069_bench.log)

Device: AMD Radeon 8060S (RADV STRIX_HALO).

| Measurement | Value |
|---|---|
| 8k prompt, seq=8192, chunk=256, 32 chunks | 0.617 s → 13,273.96 tok/s |
| Workspace at chunk=256 | 393,216 bytes |
| Workspace, single-chunk 8192 (unchunked) | 12,582,912 bytes (32×) |
| KV cache, one 8k cache | 1,048,576 bytes |
| Score matrix at 8k, one head (never materialised) | 268,435,456 bytes avoided |
| Live buffers mid-8k run | 2,191,616 bytes |
| Live buffers mid-1k chunked run | 356,608 bytes (vs 553,216 whole) |
| Live buffers after free | 0 |

Every scratch buffer is sized by the CHUNK's token count,
never by the sequence length: an 8192-token prompt runs
in the same workspace as a 256-token prompt at the same
chunk size. The KV cache is O(seq) by definition; nothing
in the path is O(seq^2) or O(seq × chunk) beyond the
cache. A069_BENCH: PASS.

## Device-execution evidence (law 6)

Device: AMD Radeon 8060S (RADV STRIX_HALO); llvmpipe
refused by identity check. Shim dispatch counters
asserted exact per chunk in the dispatch-evidence case
(rope_batched 2, kv_append_chunk 2, attention_prefill 1,
plus the composed gateways' rmsnorm 2 / f32_gemm 7 /
elementwise 3); bench totals rope_batched 74,
kv_append_chunk 74, attention_prefill 37. Counters
increment only after a submit + queue-wait-idle
completed on the device. No host fallback exists in the
gateway or the shim.

## Scope note (honest)

Dense Float32 weights for one layer (the A-068 F32 GEMM
path); the Q8_0 decode layer (A-065/A-066) is untouched
and embedding ingestion stays the caller's. The
attention kernel's fixed accumulator bounds head_dim
to 64.
