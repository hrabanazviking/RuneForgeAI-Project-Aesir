# A-066 — Full decode loop on GPU (small fixture)

A stories260K-class fixture model generating entirely on the
GPU path. Per step: embedding gather -> 2 x full layer with KV
cache -> final RMSNorm -> Q8_0 LM head -> greedy argmax. The
host loop only sequences steps and reads back the one-uint
device-produced token id per generated step.

| Step | Kernel | Slice |
|---|---|---|
| x = embedding row of token | embed_gather (new) | A-066 |
| k/v row -> cache slot `position` | kv_append (new) | A-066 |
| attention over kv_len cached rows, stride max_len | attention_decode_strided (new) | A-066 |
| full layer composition | VulkanLayer.forward_kv | A-065 + A-066 |
| final norm / LM head / greedy | rmsnorm / Q8_0 GEMV / sampling_greedy | A-060 / A-056 / A-063 |

New SPIR-V goes through the A-055 pipeline discipline
(glslangValidator + spirv-val, compiled twice and byte-
compared on purpleraider; generated header + manifest extended
additively: 13 -> 16 kernels, all 13 prior SPIR-V hashes
byte-identical). The KV-append and gather are compute
dispatches, not vkCmdCopyBuffer - the shim still resolves no
copy entry point, so the A-019 zero-copy counter cannot
increment. Modules: `aesir_engine/core/vulkan_decode.mojo`,
`aesir_engine/core/vulkan_kv_cache.mojo`,
`VulkanLayer.forward_kv` in `core/vulkan_layer.mojo`,
`VulkanAttention.decode_attention_strided` in
`core/vulkan_attention.mojo`; tests:
`aesir_engine/tests/test_vulkan_decode_a066.mojo`.

## The KV-append gap (A-065's named road) - closed

A-065 filed: multi-position decode needs an insert-at-
position kernel that did not exist in the Wave 7 set.
A-066 builds it as the kv_append compute shader above
(the A-055-pipeline option from the A-065 ledger). One
further gap surfaced while building: the A-062 attention
kernel derives its cache row stride from kv_len itself, so
it reads the wrong rows from a max_len-deep cache - closed
additively by attention_decode_strided (separate stride
push field); the A-062 kernel and its pinned SPIR-V are
untouched.

## Fixture + geometry

dim 256 = 4 query heads x head_dim 64, GQA ratio 2 (2 KV
heads, kv_dim 128), ffn 512, 2 layers, vocab 96, max_len 16,
eps 1e-5, RoPE base 10000. RAW prompt token ids [5, 17, 42]
(no template anywhere in the path), 8 greedy tokens
generated. Deterministic in-file LCG fixtures (embedding
Float32, per-layer + head Q8_0) - the A-056..A-065 fixture
discipline; sha-pinned real models are A-067's acceptance.

## Acceptance: greedy token-exact vs the CPU oracle

Independent sequential Float32 oracle in the test file with
its own multi-position KV cache, consuming the identical raw
bytes. GPU tokens == oracle tokens at all 8 steps:
[12, 72, 74, 66, 66, 23, 26, 86]. Oracle top-1/top-2 logit
gaps per generated step: 1.463, 6.245, 1.212, 3.632, 0.608,
3.509, 1.314, 0.283 - the minimum gap (0.283) sits ~45x above
the A-065 chained accumulation-order delta scale (0.0062),
so token-exactness is a sound verdict, not a near-tie call.

Component parity: KV-append bit-exact at 4 positions with
unrelated slots untouched; strided attention (kv_len 3 of
max_len 16) max_abs 5.96e-08 vs the oracle.

Device-execution evidence (law 6): AMD Radeon 8060S
(RADV STRIX_HALO), llvmpipe refused by identity check.
Per full generation (10 steps = 3 prompt + 8 generated - 1):
embed_gather +10, kv_append +40 (10 x 2 layers x 2),
strided attention +20, greedy +8; live device bytes return
exactly to baseline (no leaks). Rejection: 6 of 6 invalid
calls raise before any dispatch.
