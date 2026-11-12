# A-072 — Continuous batching v1

Roadmap acceptance: *multiple sequences decoded together on
GPU — a 4-sequence run, per-sequence outputs match their
single-sequence runs (greedy), aggregate tokens/s filed.*

## What was built

`aesir_engine/core/vulkan_batch.mojo` — `VulkanBatchDecode`,
an iteration-level scheduler over the banked A-066 decode
step (embed gather → per-layer `VulkanLayer.forward_kv` →
final norm → Q8_0 LM head → greedy argmax). No new kernels,
no new shim entries: pure composition of banked gateways.

Scheduler semantics (v1):

- At most `max_active` sequences are resident at once.
- At the start of each iteration, free slots refill from the
  waiting queue in request order. A sequence admitted
  mid-run starts at position 0 with its own KV caches while
  its batchmates are mid-context (heterogeneous positions).
- One iteration advances every resident sequence by exactly
  one position, in request order.
- A sequence leaves the batch in the iteration of its final
  step; its KV caches are freed immediately and the slot is
  reusable from the next iteration.
- Sequences share ONLY the resident weights (A-064). KV
  caches, token streams, and position counters are fully
  per-sequence, so each sequence performs bit-for-bit the
  solo A-066 computation.
- Shared transient buffers (x / normed / logits / tok_out /
  ping-pong layer scratch, A-070 discipline) are allocated
  once per batch run; live device bytes return to the
  pre-run baseline (asserted in tests and bench).
- All validation happens before the first allocation or
  dispatch (fail-closed, mirroring A-066); rejection cases
  assert dispatch counters and live bytes unmoved.

Scope, filed honestly: v1 issues the same per-sequence
single-token dispatches under the scheduler — it proves the
scheduling, isolation, and continuous admission, NOT a
fused batched GEMV. Throughput parity with serial solo runs
is therefore the expected bench outcome (below), and the
batched-dispatch speedup belongs to later work on the
A-068 GEMM road. A-071 (async dispatch) was not banked when
this slice was built; nothing here depends on it, and its
queued submission model slots under this scheduler without
changing its semantics when it lands.

## Acceptance evidence (standalone driver)

`hidden_files/a072_driver.log`: A072_DRIVER_ALL_PASS,
MOJO_EXIT=0, on AMD Radeon 8060S (RADV STRIX_HALO;
llvmpipe refused by identity check). Fixture: the A-066
small model (dim 256, 4 heads, GQA 2, head_dim 64, ffn 512,
vocab 96, 2 layers, max_len 16 in tests).

- 4-sequence run (prompts 3/2/5/1 tokens, 8 greedy tokens
  each, max_active 4): every sequence token-exact vs its
  `VulkanDecode.generate` solo run; sequence 0 additionally
  token-exact vs the independent Float32 CPU oracle
  (batch == solo == oracle chain closed). Dispatch deltas
  exactly the summed solo counts: embed 39, KV-append
  39×2×2=156, strided attention 39×2=78, greedy 32.
- Heterogeneous prompts/gens (4/8/6/3 tokens): outputs
  match solo; finish iterations exactly 5/8/9/2 as
  hand-computed from total steps 6/9/10/3.
- Dynamic admission (max_active 2): admissions at
  iterations 0/0/6/9, finishes 5/8/15/11 — a freed slot is
  refilled the next iteration, mid-run, at position 0.
- Isolation: replacing sequence 0's prompt leaves
  sequences 1–3 token-identical (no KV cross-talk).
- Rejection: 7 of 7 invalid batch shapes raise before any
  dispatch; counters and live bytes unmoved.
- Single-slot (max_active 1): scheduler serialises to
  admissions 0/10/19/31, 39 iterations, outputs still
  token-exact vs solo.

## Bench (hidden_files/a072_bench.log)

`aesir_engine/tests/bench_continuous_batch_a072.mojo`:
A072_BENCH: PASS, MOJO_EXIT=0. Geometry: A-066 fixture at
max_len 32, four prompts (3/2/5/1), 16 greedy tokens each
= 64 generated tokens per run; median of 3 trials after a
warmup whose batch output is asserted token-exact vs solo.

| Run | Median time | Aggregate tok/s |
|---|---|---|
| 4 solo runs, serial | 0.6788 s | 94.28 |
| 1 batch run, max_active 4 | 0.6800 s | 94.11 |

Batch/solo aggregate ratio: 0.998. As scoped above, v1
batching is throughput-neutral on this fixture — the
scheduler costs ~0.2% (noise scale) and buys continuous
admission, bounded resident state, and per-sequence
isolation; the throughput win requires fused batched
dispatch, which is later work, not claimed here.
