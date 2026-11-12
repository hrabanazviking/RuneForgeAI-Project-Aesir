# A-067 — Real-model GPU decode

Wave 8. A 7–8B-class Q4_K_M fixture decoding end-to-end on
the GPU: every transformer layer, the final norm, and the
lm_head run through the banked Vulkan gateways (A-057/A-058
GEMV, A-060 norm+RoPE, A-061 elementwise, A-062 decode
attention, A-063 sampling), graded against the CPU engine
oracle under raw-oracle discipline.

- Date: 2026-11-12
- Host: purpleraider, AMD Radeon 8060S (vendor 0x1002,
  device_type 1), RADV STRIX_HALO. llvmpipe is refused by
  the suite guard (vendor + RADV name check).
- Module: `aesir_engine/core/vulkan_real_model.mojo`
  (`VulkanRealModel`), driver:
  `aesir_engine/tests/bench_real_model_gpu_a067.mojo`,
  evidence log: `hidden_files/a067_bench.log`.

## Fixture (sha-pinned before the first run)

`Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf` from
`bartowski/Meta-Llama-3.1-8B-Instruct-GGUF`:

- sha256 `7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c`
  (verified twice on device; equal to the Hugging Face LFS
  x-linked-etag)
- size 4,920,739,232 bytes; 292 tensors; arch llama
- geometry: 32 layers, dim 4096, ffn 14336, 32 heads,
  8 KV heads, head_dim 128, vocab 128256
- The file lives in `hidden_files/fixtures/` and is not in
  git. No 7–8B Q4_K_M GGUF existed on the machine before
  this slice; the inventory gap and the download are
  recorded in `hidden_files/A067_LEDGER.md`.

## Composition

`decode_step(token, position)` runs one full decode step:

host embedding-row dequant gather → per layer [streamed
weight upload → rmsnorm → q/k/v GEMV with per-tensor format
dispatch (Q4_K / Q5_K / Q6_K) → host RoPE-layout permutation
→ GPU rope → append k/v to the host KV history → pack +
upload K/V → decode_attention → wo GEMV → residual add →
rmsnorm → gate/up GEMV → gated silu → down GEMV → residual
add] → final rmsnorm → chunked lm_head GEMV → non-finite
sanitization → logit row.

Three design facts worth filing:

1. **Streamed residency.** The shim caps live buffers at
   128 slots; a resident 8B model does not fit the slot
   budget. Seven reusable weight buffers are refilled per
   layer from the mmap (the bytes never leave the page
   cache), the lm_head stays resident in 4 row-chunked
   buffers (128256 rows > the 65535-workgroup dispatch
   ceiling, so every wide GEMV is row-chunked), and one
   loaded model holds exactly **32 live buffers /
   574,545,936 bytes**. Full device residency is an A-064
   follow-on road, recorded in the ledger.
2. **RoPE bridge.** The CPU llama path rotates adjacent
   pairs (2i, 2i+1); the A-060 GPU rope rotates
   rotate-half pairs (i, i+half) on the same frequency
   ladder. The two are the same rotation under the fixed
   permutation p[i]=x[2i], p[i+half]=x[2i+1]; attention is
   invariant when q and k share it. The module permutes
   q/k on host between GEMV and GPU rope, and stores K in
   the history already permuted+roped. Unit-proven in the
   suite (permutation case).
3. **Sanitization (A-063 debt discharged).** Every logit
   row leaving the module passes `sanitize_logit_row`,
   which applies the CPU sampler's own policy lane-wise
   (isnan/isinf → −1e9) and counts replacements. The
   battery observed 0 non-finite lanes; the policy itself
   is unit-proven in the suite.

KV scope, stated plainly: the KV history is host-side with
a per-step packed upload — the pre-A-066 state. A-066 owns
the persistent device KV cache; the keeper reconciles at
banking in roadmap order.

## Teacher-forcing battery (raw prompts, no template)

Sequences are prompt + the CPU engine's own 8-token greedy
continuation, teacher-forced through both engines; graded
with `core/parity_battery` (law 3: faithful = rank 1;
near-tie = rank ≤ 2 with gap < 1.0; else divergence).
Positions split per the A-045 precedent (below).

| prompt | positions | faithful | near-tie | divergent | top-1 agree |
|---|---|---|---|---|---|
| "The capital of France is" | 13 | 9 | 1 | 3 | 13/13 |
| "Water is made of hydrogen and" | 14 | 10 | 1 | 3 | 14/14 |
| "The quick brown fox jumps over the" | 15 | 12 | 0 | 3 | 15/15 |
| **total** | **42** | **31** | **2** | **9** | **42/42** |

**Continuation positions (24): all 24 faithful or
near-tie.** Every position whose target is model-generated
text lands in the law-3 faithful band.

**All 9 divergent positions are the prompt-boundary
comparator class**: the target is a prompt-internal token
that is unlikely under BOTH engines, with near-identical
rank and gap on both sides — e.g. prompt 0 pos 0: GPU rank
89 / gap 3.924 vs CPU rank 85 / gap 3.914; prompt 1 pos 0:
GPU rank 1854 / gap 5.773 vs CPU rank 1796 / gap 5.781.
Worst cross-engine gap delta across the class: 0.0101.
This is the comparator artifact class named in the
roadmap law, not an engine divergence; the suite encodes
the split (continuation judged by verdict, prompt-internal
judged by cross-engine gap agreement ≤ 0.05 + top-1).

Non-finite lanes sanitized during the battery: **0**.
Greedy cross-check: host argmax 14924 ==
`VulkanSampling` device greedy 14924.

## Generation sample (coherence-graded)

GPU greedy, prompt "The capital of France is", 32 tokens.
The GPU token ids equal the CPU engine's greedy ids
**32/32** (suite asserts the first 16; the driver log +
a CPU 32-token control run agree on all 32), so the text
below — produced by the engine's generation path for the
identical id stream — is the GPU sample's text:

> The capital of France is Paris is a city of grandeur
> and beauty, with a rich history and culture that is
> reflected in its stunning architecture, world-class
> museums, and vibrant arts scene. From

Coherence grade: **A** — grammatical, on-topic, factual,
no repetition or degeneration across 32 tokens; the seam
after the prompt is the model's own greedy continuation,
identical in the CPU stream.

## Dispatch evidence (one decode step, exact)

q4k GEMV 192 (6/layer), q6k GEMV 36 (1/layer + 4 lm_head
chunks), q5k 0, rmsnorm 65 (2/layer + final), rope 64,
attention 32, elementwise 96. Live after load: 32 buffers,
574,545,936 bytes.

## Timing (indicative, not a baseline)

GPU load 162 ms (streamed; weights stay in the mmap). GPU
teacher-forcing ≈ 680 ms/position — dominated by the
per-layer streamed weight uploads, the known cost of the
streamed-residency design; the residency road is where
decode speed lives next. CPU oracle for comparison: load
498 ms, teacher-forcing ≈ 300 ms/position.

## Suite

7 new cases (`gpu.vulkan_real_model_*`): sanitize_policy,
rope_permutation, fixture_config, teacher_forcing,
generation, dispatch_evidence, rejection. E-MASTER gate:
**505 passed / 1 failed / 2 skipped of 508** — the sole
failure is the pre-existing `gguf.tensor_directory_interface`
J-022 drift; skips are the 2 pre-declared. Log:
`hidden_files/a067_run_all.log` (sha256
f45ce2621576a70223a0fda75195831363d3ff20ed338b6c388c922408a8fb00).
