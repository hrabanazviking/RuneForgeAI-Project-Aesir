# A-065 — One full layer on GPU (Vulkan composition)

One whole transformer decode layer composed on the GPU from the
banked Wave 7 Vulkan kernels — no new shader, no new shim entry:

| Step | Kernel | Slice |
|---|---|---|
| h = RMSNorm(x, g_attn) | rmsnorm | A-060 |
| q / k / v = GEMV(wq / wk / wv, h) | Q8_0 GEMV | A-056 |
| RoPE(q), RoPE(k) at position | rope | A-060 |
| attn = decode_attention(q, k, v) | attention_decode | A-062 |
| res = x + GEMV(wo, attn) | Q8_0 GEMV + elementwise add | A-056 / A-061 |
| h2 = RMSNorm(res, g_ffn) | rmsnorm | A-060 |
| mlp = silu(GEMV(w_gate, h2)) * GEMV(w_up, h2) | Q8_0 GEMV + gated elementwise | A-056 / A-061 |
| out = res + GEMV(w_down, mlp) | Q8_0 GEMV + elementwise add | A-056 / A-061 |

All SPIR-V comes from the A-055 generated header
(`aesir_engine/shaders/generated/aesir_shaders_spv.h`) through the
banked gateways. Module: `aesir_engine/core/vulkan_layer.mojo`
(`VulkanLayer.forward`); tests:
`aesir_engine/tests/test_vulkan_layer_a065.mojo`.

## Fixture + geometry

Decode position 3, eps 1e-5, RoPE base 10000. dim 256 =
4 query heads x head_dim 64, GQA ratio 2 (2 KV heads, kv_dim 128),
ffn 512. Weights are deterministic in-file Q8_0 fixtures (LCG,
per-layer seeds) — the fixture discipline of A-056..A-062;
sha-pinned real-model fixtures are A-067's acceptance.

## Parity vs CPU oracle (raw-oracle discipline)

Independent sequential Float32 CPU layer oracle in the test file
consuming the identical raw Q8_0 bytes. Attention context is the
single current position (kv_len == 1; see the KV note below), so
the oracle's attention output for query head h is exactly the v
row of KV head h // 2.

| Layer index | Mode | max_abs |
|---|---|---|
| 0 | chained | 0.0017852783 |
| 1 | chained | 0.003753662 |
| 2 | chained | 0.006225586 |
| 2 | standalone | 0.0014648438 |
| any | zero-weight known value | 0.0 (exact) |

Filed bounds: standalone 5e-3, chained 2e-2. The chained growth
(~3.5x per layer) is accumulation-order amplification: layer L+1
consumes layer L's GPU output, whose tree-vs-sequential rounding
delta is amplified by the next layer's GEMV/norm gain. It is a
comparator/accumulation artifact class, not a dequant error —
the standalone per-layer deltas (<= 0.0018) sit at the A-056
single-GEMV accumulation scale.

## Device-execution evidence (law 6)

Device: AMD Radeon 8060S (RADV STRIX_HALO); llvmpipe refused by
identity check. Per-layer shim dispatch counter deltas, asserted
exact: rmsnorm +2, rope +2, q8_gemv +7, attention +1,
elementwise +3. Buffer accounting (live bytes / live count)
returns exactly to baseline after a layer — no leaks.

## KV scope note (honest)

This is a single-position decode layer: at kv_len == 1 the
attention K/V operand layout [kv_heads][1][head_dim] is exactly
the k/v projection layout, so projections feed attention with no
copy. Multi-position decode needs a KV-append
(insert-at-position) kernel that does not exist in the Wave 7
set; recorded as the immediate next work in CAMPAIGN_STATE.md
(A-066's road).
