# A-084 Ledger - HIP attention + norms (team-14)

- Base: 82591e7c (banked main, 82 of 216; A-082 banking
  closure). Worktree /home/volmarr/aesir-team-14, branch
  yrsa/aesir-team-14. Mustered 2026-11-13 by the keeper
  (expansion to 27 teams). First lead cancelled mid-work;
  second lead continued from the uncommitted work in place
  (gateway + test + shim counters were sound and kept).
- Slice: A-084 - HIP attention + norms. Minimal set
  matching A-060/A-062 scope. Acceptance: parity per op,
  with device-execution evidence for every accelerator
  claim. OUTCOME: PASS - parity per op inside filed
  bounds and device execution evidenced on the real
  gfx1151 device (details below).
- Banking order note: A-083 banked at the seat after this
  branch was cut (seat main de415271, 83 of 216, pin 589).
  Expect a run_all pin union at banking: this branch pin
  586 -> 591; union at the seat reconciles to 594.

## Deliverables
- aesir_engine/core/hip_attention_norms.mojo (new):
  HipAttnNorms gateway + three Mojo-native HIP kernels
  (_rms_kernel, _rope_kernel, _attn_kernel) launched
  through MAX DeviceContext(api="hip") - the A-029/A-082
  proven road - gated by the A-010-A-012 HIP gate
  (HipMemory runtime + device_count == 1 + AMDGate
  properties plausible with gfx_arch == gfx1151 +
  MojoNative). Math matches the Vulkan shaders of record
  (rmsnorm.comp, rope.comp, attention_decode.comp serial
  path) and core/compute.mojo: RMSNorm
  y = x*rsqrt(mean(x^2)+eps)*g; RoPE rotate-half pairs
  (i, i+head_dim/2) by position*base^(-2i/head_dim);
  decode attention, GQA kv_head = head//kv_per_query,
  scores scaled 1/sqrt(head_dim), max-subtraction
  softmax. Float32 accumulation throughout (A-075).
  Kernel shapes use only A-029-proven forms (one thread
  per output row / per RoPE pair / per (head, lane)
  recomputing scores serially); no shared memory,
  barriers, or subgroup ops. Fail-closed: gate failure
  or any shape violation raises before device work; no
  host fallback exists.
- aesir_engine/hip_memory_shim.c: three A-084
  dispatch-evidence counters appended (rmsnorm / rope /
  attn note+count pairs, same contract as A-082). A
  gateway notes a dispatch only after launch + readback
  + synchronize completed without raising, so each
  counter counts exactly the dispatches of that op that
  completed on the device (law 6).
- aesir_engine/tests/test_hip_attn_norms_a084.mojo
  (new): 5 cases, gpu.hip_attn_norms_*, with sequential
  Float32 CPU oracles in-file implementing the identical
  math. Second lead added one hardening: the rejection
  case now brackets its 7 bad-shape calls with counter
  reads and asserts no counter advanced on a rejected
  call (reviewer finding, fixed in-slice).
- aesir_engine/tests/run_all.mojo: imports + 5 run_case
  registrations (gpu.hip_attn_norms_rmsnorm_oracle,
  _rope_oracle, _attention_oracle, _rejection,
  _dispatch_evidence); team pin 586 -> 591 with the
  union note filed at the pin.

## Parity (from hidden_files/a084_run_all.log)
- RMSNorm: BIT-EXACT, max_abs 0.0 at all 3 configs
  (rows/n = 1/64, 3/128, 8/37 - odd n included).
- RoPE: worst max_abs 1.1920929e-06 (head_dim 32/64/128,
  positions 0/1/17) vs filed bound 1e-4 - transcendental
  evaluation-order noise only.
- Decode attention: worst max_abs 1.7881393e-07
  (MHA gqa=1 hd=32 kv=16; GQA x2 hd=64 kv=33; GQA x4
  hd=32 kv=8) vs filed bound 1e-4.
- Rejection: 7 bad shapes raised, counters unmoved.

## Device evidence (law 6)
- Dispatch-evidence case PASS on device
  " AMD Radeon 8060S Graphics " (gfx1151, gate-checked):
  exactly one call per op advanced each op counter by
  exactly +1 (rms/rope/attn). Parity cases run through
  the same no-fallback gateway.

## Suite (hidden_files/a084_run_all.log)
- 588 passed / 1 failed / 2 skipped / 591 total.
- Sole failure: gguf.tensor_directory_interface -
  the pre-existing J-022 drift, unchanged from base.
- Skips: the 2 pre-declared (vision.cuda_session_image_
  chat, rag.real_engine_integration).
- Baseline on this base was 583/1/2 of 586; delta is
  exactly the 5 new A-084 cases, all PASS. Neither known
  intermittent (resilience.state_vault_rejects_growth,
  gpu.amd_hip_stream_async_round_trip) fired.
- Run solo on an idle machine (load < 1, no seat gate
  live; A-083 seat gate had finished 08:15 EST).

## Notes / next work
- Honest-absent asymmetry (reviewer note, not a defect
  on this device): if the HIP gate is absent, the RoPE /
  attention / dispatch-evidence cases print honest-
  absent and return, while only RMSNorm asserts
  fail-closed rejection. On the Z13 the gate is present
  and all cases executed on device. Worth hardening in
  a later slice if HIP-less CI ever becomes real.
- Shim counters are non-atomic (inherited A-082
  pattern); concurrent gateway calls could lose an
  increment. Tests are single-threaded; not a defect
  for this slice.
- Speed is not claimed: the A-085 bake-off judges HIP
  vs Vulkan. This slice claims parity + execution only.

## Post-review fixes (second lead, same session)
- Reviewer findings F1/F3 fixed in-slice before banking:
  attention row_max sentinel -1.0e30 -> -3.4028235e38
  (matches the fused-kernel convention; the Vulkan shader
  uses -Inf; denom can no longer collapse to 0/0 on
  adversarial logits), rmsnorm eps and rope base now
  reject NaN/Inf exactly as core/compute.mojo does, and
  the gateway header byte-for-byte claim softened to
  math-identical (accumulation orders differ by design).
  Test oracle sentinel aligned; rejection case now
  covers 9 bad shapes incl. Inf eps and Inf base.
- Re-run (hidden_files/a084_run_all_fix.log): 588 passed
  / 1 failed / 2 skipped / 591 total, identical parity
  numbers, sole failure still pre-existing J-022.
- LayerNorm / standalone softmax: confirmed out of
  scope - A-060/A-062 scope is RMSNorm + RoPE + decode
  attention, and no LayerNorm oracle exists in
  aesir_engine/core (naming trap: layer_norm_epsilon
  feeds RMSNorm there).
