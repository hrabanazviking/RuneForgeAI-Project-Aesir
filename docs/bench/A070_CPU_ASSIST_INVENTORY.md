# A-070 - Lawful CPU assist: inventory, measurements, verdicts

Roadmap acceptance: *an assist inventory with per-item
measurements; unmeasured assists removed.* Law (Accelerator-
First): CPU participates only as (1) spillover for what
exceeds device residency, or (2) an assist that measurably,
massively speeds up the whole run.

## Method

Every host participation in the GPU decode/prefill paths was
inventoried from code (core/vulkan_real_model.mojo A-067,
core/vulkan_decode.mojo A-066, core/vulkan_gemm.mojo A-068,
core/vulkan_layer.mojo A-065), then measured two ways on the
RADV STRIX_HALO device (AMD Radeon 8060S, vendor 0x1002):

- External baseline (pre-instrumentation, banked-A-068 code):
  tests/bench_cpu_assist_a070.mojo, log
  hidden_files/a070_bench_baseline.log. Steady step 664-681 ms
  on the sha-pinned Llama-3.1-8B-Instruct-Q4_K_M fixture
  (A-067 fixture), RAW prompt "The capital of France is".
- In-path accounting (this slice): CpuAssistStats in
  VulkanRealModel accumulates per-assist host wall time and
  bytes inside decode_step/_layer, exposed via assist_stats().
  Same driver, log hidden_files/a070_bench.log: 16 steps,
  step avg 686 ms, greedy argmax sequence IDENTICAL to the
  baseline at all 16 positions (14924, 220, 315, 279, 11,
  264, 3363, 315, 6800, 12844, 323, 13444, 11, 449, 264,
  9257) - instrumentation and removals changed no output.

Verdicts come from the pure classifier pinned in
core/vulkan_real_model.mojo (assist_verdict): unmeasured =
never lawful; spillover = lawful; measured assist lawful if
>= 10x cheaper than the GPU alternative (massive) or < 1%
of the step it serves (trivial); anything else does not pay.

## Inventory - VulkanRealModel decode_step (per step, 32 layers,
## dim 4096, kv_dim 1024, vocab 128256)

| Assist | Freq/step | Bytes/step | Measured | Share of 686 ms step | Verdict |
|---|---|---|---|---|---|
| stream_upload (weights) | 224 uploads | 4,185 MB | 392 ms/step | 57.1% | LAWFUL - spillover |
| gains_upload (norm gains) | 64 uploads | 1.0 MB written | 0.52 ms/step | 0.08% | LAWFUL - trivial |
| embed_gather | 1 | 2,304 B read + 16 KB up | 4 us/call (external) | ~0.001% | LAWFUL - massive |
| rope_permute round trip | 64 (Q+K per layer) | 1.31 MB | 23.75 ms/step | 3.5% | DOES NOT PAY - roaded |
| kv_pack (incl. KV readback) | 32 | 2,228 KB up at kv_len ~8.5 | 12.11 ms/step at kv_len ~8.5 | 1.8% here; grows linearly | DOES NOT PAY at scale - roaded |
| lm_head_stitch (readback) | 4 chunks | 513 KB down | 28.39 ms/step | 4.1% | KEEP - contract transfer |
| sanitize | 1 | 513 KB scanned | 0.106 ms/step | 0.015% | LAWFUL - trivial |
| host_argmax (greedy_from) | 1 per generated token | row already on host | 150 us vs 544 us device greedy | 0.02% | LAWFUL - trivial |
| gpu_greedy_check | 0 in generation (cross-check only) | 513 KB up + 4 B down per call | 544 us/call | n/a | KEEP - cross-check only |

Named assists total 457 ms/step = 66.7% of the step, of
which the spillover stream upload alone is 392 ms (57.1%).
Excluding spillover, all remaining assists are 65 ms/step
(9.5%), dominated by the three roaded/contract items below.

### Per-item notes

- stream_upload: the A-014 shim caps live buffers at 128
  slots; an 8B model has 291 tensors, so total residency is
  impossible today and 7 reusable weight buffers are refilled
  from the GGUF mmap per layer (~127 MB/layer). This is
  textbook spillover (class 1) and it IS the step's dominant
  cost - the residency road (raised cap or offset-addressed
  GEMV, A-064 follow-on) is the campaign's biggest single
  lever, already filed in the A-067 ledger.
- gains_upload: F16->F32 conversion of one dim-length gain
  row per norm, folded into the upload map. Trivial.
- embed_gather: one token row dequantized from the mmap.
  The GPU alternative (device table + gather dispatch +
  readback, the gpu_greedy round-trip class) measures ~544 us
  end-to-end against 4 us host - the host gather is >100x
  cheaper. VulkanEmbed.gather (A-066) exists but needs a
  resident device table; the real-model table is quantized
  mmap, and residency is the stream_upload road above.
- rope_permute: the pure reindex is 3 us (Q) per call
  externally, but the in-path round trip - scalar _read_f32,
  permute, _write_f32 per Q and K per layer - costs
  23.75 ms/step (3.5%). It does not meet the trivial bound.
  ROAD: a GPU bridge kernel (rope_permute.comp) following
  the banked gemv_row_permute precedent in
  core/vulkan_gemv.mojo / vk_gemv_row_permute (which permutes
  GEMV weight rows, not [rows][head_dim] activations), or a
  layout-native Q/K projection. Kept until that kernel
  exists; removing it without the kernel removes decode.
- kv_pack: host KV history readback + append + full
  [kv_heads][kv_len][head_dim] re-pack + upload per layer.
  Cost is linear in kv_len per step (quadratic over a
  generation): 12.11 ms/step at kv_len ~8.5 extrapolates to
  roughly 0.7 s/step at the filed _MAX_POS 512 - it would
  exceed the entire current step. ROAD: persistent device
  KV for this path - the pattern exists in-repo
  (core/vulkan_kv_cache.mojo VulkanKVCache append_strided +
  VulkanEmbed, used by the A-066 loop); A-066 reconciliation
  at banking owns the pattern. Kept until then; it is
  measured, named, and does not pay at scale.
- lm_head_stitch: decode_step's contract returns the full
  sanitized logit row (teacher-forcing grading consumes it
  on the host), so the 513 KB readback is a contract
  transfer, not an optimization candidate. REMOVED inside
  it: the pre-A-070 zero-fill pass (128,256 appends/step of
  values immediately overwritten - unmeasured host work).
  The row is now built by stitch_chunk_append; equivalence
  with the zero-fill+scatter form is pinned in E-MASTER
  (cpu_assist.stitch_equivalence). ROAD: a device-greedy
  generation variant that skips the readback when only the
  argmax is needed (greedy_from currently re-reads via the
  returned row + host argmax, which is lawful per above).
- sanitize: the A-063-debt policy scan (NaN/Inf -> -1e9,
  identical function to the CPU sampler). No GPU kernel
  implements this exact policy; 0.015% of step. Trivial.
- host_argmax: operates on the row already on host (the
  readback cost is sunk in lm_head_stitch). 150 us vs the
  measured 544 us device greedy round trip - host is 3.6x
  cheaper AND a trivial share. Lawful.
- gpu_greedy_check: A-063 cross-check helper only; never in
  the generation path. Its measured cost is the evidence
  that host argmax is lawful.

## Inventory - A-066 decode loop (core/vulkan_decode.mojo)

- decode_alloc_churn: was one VulkanBuffers.allocate + free
  per layer per step (384 pairs per 32-step generate on the
  12-layer stories fixture; measured 15 us/pair = ~5.8 ms
  per generate). REMOVED in A-070: layer scratch is now
  ping-pong - two buffers allocated once, alternated per
  layer (all gateway dispatches are synchronous, so a
  buffer is reusable two layers later). Per-step alloc/free
  in the loop: zero. The A-066 E-MASTER cases re-prove
  token-exact generation on the changed loop.
- Sibling churn NOT removed here (found by full read of
  core/vulkan_layer.mojo after the bench): VulkanLayer.
  forward_kv allocates and frees 12 scratch buffers per
  invocation - per layer per token (alloc L293-304, free
  L326-337 in the banked file; forward has the same 12).
  At the measured 15 us/pair that is ~180 us per layer,
  ~2.2 ms/step on the 12-layer A-066 fixture - larger than
  the decode-loop churn removed above. It lives in the
  A-065 layer gateway, not in vulkan_decode.mojo, so it is
  roaded, not fixed, in A-070: ROAD - VulkanLayer scratch
  reuse (caller-owned or cached scratch) for the first
  slice that re-opens vulkan_layer.mojo. The ping-pong
  claim above covers vulkan_decode.mojo's own loop only.
- Everything else in the loop is device-resident by design
  (embed gather kernel, persistent device KV, device greedy;
  host reads back one uint per generated token - the loop's
  deliverable). VulkanLayer.forward_kv performs ~10 small
  host-sequenced dispatch waits per layer (17 dispatches in
  forward_kv, each gateway submit+wait-idle): those are dispatch
  sequencing, not CPU math assists; host-sync/timeline
  territory is A-071's road, noted here, not counted.

## Inventory - A-068 prefill (core/vulkan_gemm.mojo)

Fully device-resident GEMM: weights, activations, and
outputs never leave device buffers inside the call; no host
loops, no per-token sync, no host packing, no allocator
churn (zero allocations in the call). Host participation:
none. The only CPU work in the prefill path is one-time
weight upload at engine setup, outside the measured call -
the same spillover class as stream_upload.

## Removals summary

1. lm_head zero-fill pass (unmeasured) - removed.
2. A-066 decode-loop allocator churn (measured 15 us/pair,
   384 pairs/generate) - removed via ping-pong scratch.
3. Roaded with measurements (kept, named, do not pay as
   structured): rope_permute round trip (GPU bridge kernel
   road), kv_pack (persistent device KV road, A-066
   pattern). Plus the pre-existing residency road for
   stream_upload (A-064/A-067 ledgers).

## E-MASTER

Six new cases (tests/test_cpu_assist_a070.mojo, pin
518 -> 524): stats accounting invariants, policy verdict
table (spillover / massive / trivial / does-not-pay /
unmeasured / unmeasured-dominant), stitch append == scatter
equivalence, sanitize policy pin, inventory completeness
(10 canonical ids/names), zeroed stats on an unloaded model.
Suite counts are filed in hidden_files/A070_LEDGER.md from
hidden_files/a070_run_all.log.
