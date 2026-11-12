# A-061 Ledger — Vulkan elementwise + softmax (team-02)

- Slice: A-061 — Vulkan elementwise + softmax. Roadmap acceptance:
  reference parity; softmax max-subtraction proven on adversarial
  logits.
- Base: 3d60e523 (A-058 banking closure, 58 of 216) on branch
  yrsa/aesir-team-02. Built on that base without reset/rebase per
  keeper instruction (A-059 banked at the seat meanwhile; A-060 in
  parallel on team-05); keeper reconciles pins/shim at banking.
- Previous lead's partial: aesir_engine/core/.vulkan_elementwise
  .mojo.musegadget-partial (2100 B) was a sound header + truncated
  body (cut mid _raise_for_rc). Discarded; the gateway was
  rewritten cleanly in full. (The partial file was already absent
  from the worktree when the rm ran; git status confirms it is
  gone and untracked.)

## What was built

- aesir_engine/core/vulkan_elementwise.mojo — VulkanElementwise
  gateway: elementwise(a, b, y, n, mode) modes 0 silu / 1 mul /
  2 add (residual) / 3 gated silu; softmax(x, n, rows) in place;
  elementwise_dispatch_count() / softmax_dispatch_count().
  Fail-closed, validated before dispatch (n/rows positive, mode
  0..3, buffers cover operands).
- aesir_engine/vulkan_buffer_shim.c — appended
  aesir_vk_buffer_elementwise / aesir_vk_buffer_softmax +
  counters, in the A-060 pattern: pipeline per call, submit,
  queue-wait-idle, counter increments only after wait-idle.
  SPIR-V taken ONLY from the A-055 generated header
  (kElementwiseSpv 2868 B sha256 804583081f7299d73d96d78ce565a2
  76f51f64db815e6756d8512860d33170ca; kSoftmaxSpv 4552 B sha256
  706162baf9e9194a8ea5f3e558bd6bbe00acbce026bd7cd1487b6a95e482c
  1cc) — no hand-embedded words (the A-062 duplicate-definition
  bug class avoided by construction).
- aesir_engine/tests/test_vulkan_elementwise_softmax_a061.mojo
  — 6 cases; aesir_engine/tests/run_all.mojo registers them and
  re-pins 463 -> 469 on this base (union reconciles at banking).
- docs/bench/A061_VULKAN_ELEMENTWISE_SOFTMAX.md — filed doc.

## Parity verdicts (sequential F32 oracles in the test file,
## CPU vs GPU, raw-oracle discipline; device = RADV STRIX_HALO,
## llvmpipe refused by identity check)

- Elementwise: mul and add BITWISE EXACT (max_abs 0.0) at all 6
  sizes (37/255/256/257/1000/4096). silu worst 4.77e-07 at
  scale 4, 9.54e-07 at scale 50. Gated silu worst 1.91e-06 at
  scale 4, 3.05e-05 at scale 50 (inputs to ±50, outputs to ±50:
  relative ~6e-07). Filed bound 1e-3 — PASS with wide headroom.
- Softmax parity: worst 5.96e-08 over shapes (rows,n) =
  (1,64),(4,37),(3,257),(2,1024). Bound 1e-3 — PASS.
- Softmax adversarial: +100-shifted row finite and matching
  oracle; all -1000 constant row EXACTLY uniform (1/64 each) —
  max-subtraction proven (naive exp would overflow/underflow);
  single-spike row matches oracle. Worst adversarial max_abs
  within the same bound — PASS.
- Known values: silu(0)=0 exact; mul/add exact dyadic — PASS.
- Rejection: 9/9 bad calls rejected — PASS.
- Dispatch evidence: counters +2/+2 for 2+2 dispatches, buffer
  accounting exact, no leaks — PASS (law 6 device-execution
  evidence).

## Suite (E-MASTER run_all, hidden_files/a061_run_all.log)

- Gate run: 466 passed / 1 failed / 2 skipped / 469 total =
  this base's pin 463 + exactly the 6 new A-061 cases, all
  passing. Sole failure = pre-existing tolerated
  gguf.tensor_directory_interface (J-022 drift); skips = the 2
  pre-declared. Zero regressions. MOJO_EXIT=1 is the ledger's
  own fail signal for that one tolerated case (same as every
  prior gate on this base).
- Run 1 failed to compile: List[Float32] return needed the
  transfer operator (return out^) in the test oracle — my bug,
  fixed in-slice; gate run above is the re-run.

## Bugs found / fixed

- Test-oracle compile error above (mine, fixed in-slice).
- No engine/shim bug found. No other slice's code touched.
