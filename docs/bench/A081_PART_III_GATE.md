# A-081 — Part III gate: GPU decode primary verdict

Wave 9 closer. Roadmap acceptance: "GPU path declared primary for
decode only if it beats the A-030 CPU baseline by >=2x on the
8B-class Q4 fixture decode; otherwise an honest verdict with the
blocking causes named as new road-slices. Ledger updated either
way."

## VERDICT: HONEST NEGATIVE — GPU path NOT declared primary

The GPU path is not declared primary for decode. The CPU path
remains the primary decode path for the 8B-class model. The
negative holds under BOTH readings of the gate bar (below), so
it does not rest on the cross-model-class comparison alone.

## Measured (this slice, fresh on current banked code)

Driver: aesir_engine/tests/bench_part3_gate_a081.mojo
(standalone, not in run_all; +0 suite cases, pin untouched).
Evidence log: hidden_files/a081_bench.log (sha256
43891878c4d3f97e2d7959a063d63171f55eb51bde49b2239e10d79d553c63f9),
MOJO_EXIT=0. Machine: purpleraider, AMD Radeon 8060S
(vendor 0x1002, device_type 1), RADV STRIX_HALO — device
execution proven by the identity guard (llvmpipe refused) and
the A-070 assist accounting snapshot in the same log. Quiet
window: load 0.05-0.21, Z-100 soak probes frozen (state T),
no seat gate or suite running at launch (ps-checked).

Fixture (identical for both paths): Meta-Llama-3.1-8B-Instruct-
Q4_K_M.gguf, sha256
7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c
(verified in this worktree before the run; the A-067 pin).
RAW prompt "The capital of France is" (6 tokens, add_bos=True,
no template — the A-004/A-045/A-067 standard), greedy decode,
32 steps, 3 reps each path, medians reported.

| Path | Rep tok/s | Median tok/s | ms/token |
|---|---|---|---|
| CPU (AesirEngine, PhaseTimings decode span) | 7.325 / 6.958 / 6.750 | 6.958 | 143.7 |
| GPU (VulkanRealModel, decode-step wall) | 1.501 / 1.497 / 1.474 | 1.497 | 667.9 |

GPU greedy ids == CPU greedy ids: 32 of 32 exact. Correctness
is not the blocker; speed is. (Consistent with the A-067
teacher-forcing battery: all continuation positions faithful
or near-tie under raw-oracle discipline, top-1 42/42.)

## The two readings of the bar

Reading A — the roadmap / Capability Ledger reading
(Z13-P2-030: "A-081 requires GPU decode >= 2x this decode
baseline on 8B-class Q4"): the A-030 baseline is 8,745.9 tok/s
decode (stories260K F16 fixture), so the bar is 17,491.8 tok/s
of 8B decode. GPU measured 1.497 tok/s — a shortfall factor of
about 11,700x. FAIL.

Reading B — the same-fixture reading: GPU 8B decode vs 2x the
CPU 8B decode measured in this same run: bar 13.92 tok/s, GPU
1.497 tok/s; GPU/CPU ratio 0.215x — the GPU path is about
4.7x SLOWER than the CPU path on the identical fixture, prompt
and machine window. FAIL.

## Consistency with banked Part III measurements

- A-067 (first real-model GPU decode): ~680 ms/position GPU.
  This run: 670 ms/step average (assist accounting, same log).
- A-070 (lawful CPU assist): step 664-686 ms, weight streaming
  392 ms/step (57.1 percent). This run: stream 377 ms/step of
  670 ms (56 percent), 4,185 MB streamed per step.
- A-077 (one-hour GPU soak): 4,590 steps in 3,600 s of decode
  = 1.275 tok/s sustained (includes 9 KV resets and long-KV
  attention growth) vs 1.497 tok/s here at short KV.
- A-074 subgroup attention (8.6-9.1x on the attention kernels)
  does not move end-to-end decode: at these KV lengths
  attention is a small share of the step and streaming
  dominates. Kernel-level wins do not rescue the step time
  while the weights are re-streamed every step.

## Blocking causes, named as new road-slices

R-A081-1 — Total device weight residency (the dominant cause).
VulkanRealModel streams the weights per layer from the mmap
because the shim's 128 live-buffer cap cannot hold the 8B
model resident (A-067 road, A-064 follow-on): 4,185 MB and
377 ms per step, 56 percent of the step. Road: raise or pack
the shim slot budget (or pack tensors into fewer, larger
buffers) so the 8B weights stay device-resident across steps.
Necessary but NOT sufficient: removing all streaming still
leaves ~293 ms/step (~3.4 tok/s), below the CPU's 6.958.

R-A081-2 — Per-step dispatch and host round-trip overhead.
One decode step issues ~485 dispatches (A-067 counts: Q4_K
192, Q6_K 36, rmsnorm 65, rope 64, attention 32, elementwise
96) plus a full-vocab logit readback, a host KV pack that
grows linearly with KV length (A-070: 12.11 ms/step at
kv_len ~8.5, judged DOES NOT PAY at scale), and a host RoPE
permutation round trip (A-070: 23.75 ms/step, DOES NOT PAY).
Roads: persistent device KV for VulkanRealModel (the A-066
pattern), a GPU RoPE permutation bridge kernel, and fused or
batched per-layer dispatch to cut submit/readback count.

R-A081-3 — Roadmap-wording observation (NOT a verdict input).
The A-030 baseline was measured on a 260K-parameter F16
fixture; no 8B decode on this hardware can reach 17,491.8
tok/s (the 4.9 GB of Q4 weights alone bound single-stream
decode to tens of tok/s at LPDDR5X bandwidth). Future gates
should state the bar same-fixture (GPU vs CPU on the pinned
8B fixture). Recorded for Volmarr / the keeper; the verdict
above stands on Reading B alone.

## What Part III did prove (not diminished by this verdict)

The Vulkan GPU path is CORRECT and ROBUST on the real 8B
model: parity under raw-oracle discipline (A-067, A-078 fuzz:
real 0 defects), one-hour soak with 0 errors and 0 non-finite
lanes (A-077), device-lost recovery (A-079), memory-pressure
routing (A-076), and prefill GEMM that beats the CPU stack by
an order of magnitude at batch (A-068: 30,073 tok/s at 64
tokens vs the CPU stack's 2,081-2,118). The gate question was
only whether GPU decode is PRIMARY. On speed, today, it is
not. The CPU path remains primary for decode; the GPU path
remains the prefill and correctness-proven second road, and
Part IV (HIP fair trial) proceeds on its own merits.
