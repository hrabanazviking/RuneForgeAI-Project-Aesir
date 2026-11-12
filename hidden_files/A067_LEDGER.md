# A-067 Ledger — Real-model GPU decode (Wave 8)

- Date: 2026-11-12
- Team: 03 (lead + 6 Mythic Engineering sub-agents, design/
  research notes only; all device work by the lead)
- Worktree: /home/volmarr/aesir-team-03
- Branch: yrsa/aesir-team-03
- Base: 522fdbe7 (seat main, 65 of 216 banked, A-065
  closure). Team state + hidden_files backed up to
  /tmp/a067_backup/ before reset --hard onto the seat.
- Status: BUILT + TESTED + COMMITTED on the team branch.
  NOT merged, NOT pushed — the keeper banks after A-066
  in roadmap order. A-066 (team-02, full decode loop) was
  still in flight at build time; A-067 was built ahead on
  the A-065 layer per the assignment, and the keeper
  reconciles pins/shims at banking.

## Fixture — the gap, and how it closed

Inventory at slice start (2026-11-12 ~15:28 EST): NO
7-8B-class Q4_K_M GGUF existed on purpleraider.
/mnt/vault/models/gguf/ was empty; the HF cache held only
Qwen2.5-0.5B-Instruct; the Ollama store held only a
~0.5B qwen2.5 blob; aesir_engine/model.gguf is a 24-byte
stub. Internet was reachable (huggingface.co HTTP 200),
so the fixture was fetched and pinned BEFORE any run:

- Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf from
  bartowski/Meta-Llama-3.1-8B-Instruct-GGUF
- sha256 7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c
  (sha256sum verified twice on device; equal to the HF
  LFS x-linked-etag)
- 4,920,739,232 bytes; 292 tensors; llama; 32 layers,
  dim 4096, ffn 14336, 32/8 heads, head_dim 128,
  vocab 128256
- Location: hidden_files/fixtures/ — NOT in git (4.9 GB).
  KEEPER NOTE: suite cases honest-absent without the
  fixture; copy it into a worktree's hidden_files/
  fixtures/ to run them for real there.

## What was built

- aesir_engine/core/vulkan_real_model.mojo —
  VulkanRealModel: a full llama decode step on the banked
  Vulkan gateways (A-057/A-058 GEMV with per-tensor
  Q4_K/Q5_K/Q6_K dispatch, A-060 rmsnorm+rope, A-061
  elementwise, A-062 decode attention), host embedding
  gather, host KV history with per-step packed upload,
  chunked lm_head, teacher_forcing_rows(), greedy_from(),
  gpu_greedy_token() cross-check, close() releasing all
  32 buffers.
- aesir_engine/tests/bench_real_model_gpu_a067.mojo —
  the filed battery driver (log: a067_bench.log).
- aesir_engine/tests/test_vulkan_real_model_a067.mojo —
  7 E-MASTER cases; run_all pin 501 -> 508.
- docs/bench/A067_REAL_MODEL_GPU_DECODE.md — composition,
  battery, sample, dispatch evidence.

## Acceptance — measured (driver log a067_bench.log)

- Device: vendor 4098 (0x1002), type 1 — AMD Radeon
  8060S, RADV STRIX_HALO; llvmpipe refused by guard.
- Battery (3 raw prompts, prompt + CPU greedy 8,
  parity_battery law-3 verdicts): faithful 31, near-tie
  2, divergent 9, positions 42, top-1 agreement 42/42,
  non-finite sanitized 0.
  - All 24 continuation positions faithful or near-tie.
  - All 9 divergent positions are the prompt-boundary
    comparator class: unlikely under BOTH engines with
    near-identical rank/gap (worst cross-engine gap
    delta 0.0101) — a verdict class per roadmap law,
    not an engine divergence. The suite encodes the
    split.
- Generation: GPU greedy ids == CPU greedy ids 32/32;
  coherence grade A; sample text filed in the bench doc.
- Greedy cross-check: host argmax 14924 == VulkanSampling
  device greedy 14924.
- Dispatch per step (exact): q4k 192, q6k 36, q5k 0,
  rmsnorm 65, rope 64, attention 32, elementwise 96;
  32 live buffers / 574,545,936 bytes after load.

## Gate — E-MASTER (log a067_run_all.log)

505 passed / 1 failed / 2 skipped / 508 total (wall
2:32.75; log sha256
f45ce2621576a70223a0fda75195831363d3ff20ed338b6c388c922408a8fb00).
Delta over the seat baseline 498/1/2/501 is exactly the
7 new cases, all PASS with real execution (battery 8/8
continuation + 13/13 top-1, generation 16/16 in-suite).
Sole failure = pre-existing gguf.tensor_directory_interface
J-022 drift (unchanged). Skips = the 2 pre-declared.

## Judged debts, bugs, and roads

1. A-063 next-work item JUDGED OWED BY THIS SLICE and
   discharged in-slice: A-067 is the first engine-
   integration slice feeding raw model logits toward
   sampling, so sanitize_logit_row (CPU sampler policy,
   isnan/isinf -> -1e9, counted) runs on every logit row
   at the model boundary. Battery observed 0 non-finite
   lanes; the policy is unit-proven by the suite case.
2. RoPE convention mismatch found and bridged: CPU llama
   rotates adjacent pairs, A-060 GPU rope rotates
   rotate-half pairs; same ladder, related by a fixed
   permutation applied to q/k on host (K stored already
   permuted+roped). Unit-proven.
3. Shape bug caught by load-time validation during the
   build: the attention output projection GEMV was first
   written with cols=heads*head_dim on the wrong tensor
   geometry (attn_output is [dim x dim]); the loader's
   per-layer shape checks refused the bad geometry
   before any dispatch. Fixed in-slice.
4. ROAD (A-064 follow-on): full device weight residency
   does not fit the shim's 128 live-buffer cap, so this
   slice streams weights per layer (7 reusable buffers
   refilled from the mmap; lm_head resident, row-chunked
   at 32768 rows under the 65535-workgroup ceiling).
   Cost: ~680 ms/position vs the CPU oracle's ~300 ms.
   Raising the slot cap or packing tensors is the road
   to resident decode speed.
5. ROAD (A-066 reconciliation): KV history is host-side
   with per-step packed upload — the pre-A-066 state.
   A-066 owns the persistent device KV cache; the keeper
   reconciles at banking.
6. Known cosmetic gap, filed not chased: the bench
   driver's per-token text decode via
   engine.tokenizer.decode(id) printed empty
   (RuneWeaver decode quirk). Filed sample text comes
   from the engine's own generation path for the
   identical, id-verified token stream.
