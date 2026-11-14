# Full-suite gate + the 27B gate — closing results for the HS line

Date: 2026-11-14. Branch `yrsa/hip-serve` (head fd53cc8c after HS-7).

## Full-suite gate (Grand Proving, build_matrix.sh amd, AOT, gfx1151)

Run fenced (MemoryHigh=24G/MemoryMax=32G), gate stopped, machine
otherwise idle. Log: `hidden_files/build_matrix_amd.log` (matrix
wrapper log: `hidden_files/hip-serve/build-matrix-hs7.log`).

- **901 passed / 2 failed / 2 skipped of 905.**
- All five cases this line added PASS inside the suite:
  serve.post_history_resolution, serve.post_history_application,
  serve.session_residency_delta, serve.memory_injection_render,
  serve.memory_injection_append_stability.
- Failure 1: `gguf.tensor_directory_interface` — the known pre-existing
  J-022 tolerated failure, identical in form to the HS-1 baseline.
- Failure 2: `gpu.hip_q4k_gemv_no_leak` ("HIP Q4_K GEMV loop retention
  0 != 50 x 8388608"). Attribution checked the campaign way: the A-083
  standalone driver was built and run on this tree AND on a clean
  worktree of the untouched base (main, 31ab9363). It fails with the
  identical message on the base — **pre-existing, not attributable to
  HS-4…HS-7** (the line touched no GEMV/kernel code). Logs:
  `hidden_files/hip-serve/gemv-cur.log` (current tree) and the base run
  (identical output, captured during the session).
- Note: `resilience.state_vault_rejects_growth`, a failure in the HS-1
  baseline, PASSED in this run.
- The matrix wrapper therefore reports FAIL (amd) on the strength of
  the two pre-existing failures; the HS line itself is gate-clean.

## The 27B gate — qwen3.8-27b-heretic on Aesir: NOT RUNNABLE today

Target file: `/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-
Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf` (28,596,003,296 B, sha256
1fca6eef…186f08e — the model Ollama currently serves to Voxta).

Evidence, all read this session:

1. The GGUF's own metadata says architecture **`qwen35`**, 64 blocks,
   hidden 5120, FFN 17408, 24 heads / 4 KV heads, head dim 256,
   context 262,144 — and it is a HYBRID: `qwen35.ssm.conv_kernel`,
   `qwen35.ssm.state_size`, `qwen35.ssm.group_count`,
   `qwen35.ssm.time_step_rank`, `qwen35.ssm.inner_size`,
   `qwen35.attention.recurrent_layers`, and
   `qwen35.full_attention_interval` are all present. Most layers are
   recurrent Gated-DeltaNet (SSM) layers carrying convolutional +
   recurrent state; full attention appears only at intervals. Rotary
   is partial (`rope.dimension_count` 64 of the 256 head dim).
2. The engine's own readiness probe is decisive:
   `aesir inspect <file>` → `"compatibility":"UNSUPPORTED"`,
   `"status":"UNSUPPORTED"`, `"native_profile":""`,
   `"reason":"No architecture adapter is registered."`
   (log `hidden_files/hip-serve/inspect-27b.log`). The registry assigns
   native_profile only for gemma4, llama3, and qwen3.
3. The serve sessions are the dense-GQA Llama-family session (a closed
   admission table of exact llama/qwen3/qwen2 shapes) and the Gemma4
   session. Neither can execute recurrent SSM layers; there is no
   Qwen35 session in the serve layer.
4. A `forward_pass_qwen35` exists in the engine-core dispatch
   (aesir.mojo), but the test battery grades qwen35 smoke as
   **LOAD_FAIL_NAMED_CAUSE** (A-048, asserted in
   tests/test_qwen_battery_a119.mojo) — there is no proven load path
   for this architecture anywhere in the tree yet.

Exactly what is missing (a new campaign, not a configuration change):
- a registered qwen35 adapter/profile (registry admission + tensor
  validation for the hybrid tensor layout);
- a Qwen35 serve session holding recurrent SSM state (with residency
  semantics defined for it — SSM state is not a KV cache);
- HIP device execution for the delta-net recurrence + partial rotary.

Until that campaign exists, the honest state is: **Ollama keeps
serving the 27B to Voxta (it works there today); Aesir's serve is
ready for the Llama/Qwen-dense and Gemma families, and the HS-1…HS-7
machinery (prefix cache, post-history anchor, residency, memory
injection) will apply to the 27B the moment a qwen35 session exists.**
No run was faked: the serve was never started against this GGUF
because admission refuses it before load.

## Line state at close

- HS-1 1a092c1d, HS-2 43777e52, HS-3 73d4482e, runbook 3d1804d4,
  HS-4 5e5738fe, HS-5 8f98b2a5, HS-6 23ee96d7, HS-7 fd53cc8c — all on
  `yrsa/hip-serve`, each ls-remote verified; main untouched at 31ab9363.
- The testable serve is LIVE again in its standard form: aesir-gate
  (fenced 24G/32G), llama3-3b:latest on HIP, :18434, ctx 8192, health
  ready with exact_prefix_reuse + session_residency + memory_injection
  all true; a live chat completion was verified after the final
  restart ("Ready.").
