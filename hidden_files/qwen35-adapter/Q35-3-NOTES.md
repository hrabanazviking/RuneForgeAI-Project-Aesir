# Q35-3a — CPU forward geometry repair, fixture-grade proof (worker slice)

Worker ran all six Forge roles sequentially in one seat (recon -> design
-> build -> test -> repair -> record); no sub-agents. Seat:
/home/volmarr/aesir-hipserve @ yrsa/hip-serve 73674d63, sole writer.
NOT committed / NOT pushed — coordinator verifies and banks.
Scope note: this is Q35-3a (fixture grade). Q35-3b (real-file oracle
grade vs a CPU comparator) is parent-gated and was NOT attempted; no
real GGUF was loaded through the forward path (the Q35-2 regression
re-ran its metadata-only inspect of the real file, as banked).

## Fixes (formulas before -> after)

All in aesir_engine/core/inference.mojo (Qwen35Block.forward /
forward_batched, Qwen35State) and aesir_engine/aesir.mojo (construction).
No shared helper touched.

1. Conv / qkv width (both forwards):
   before: conv_dim = 3 * inner (18432 on the real shape; also the
   value the state ring was sized with at construction).
   after:  conv_dim = qkv_weight.rows = qkv_width
           = 2*groups*state + inner (10240 real; 128 fixture).
   The conv ring, qkv buffer, conv loop and ring indexing all derive
   from this one variable in both paths, so they move together.
2. qkv band slicing (both forwards):
   before: q_off = h*d_state, k_off = inner + h*d_state,
           v_off = 2*inner + h*d_state (equal-thirds assumption).
   after:  q_off = g*d_state, k_off = qk_band + g*d_state,
           v_off = 2*qk_band + vh*d_state, where qk_band =
           groups*d_state (q band [0,2048), k [2048,4096), v
           [4096,10240) on the real shape; [0,32) [32,64) [64,128)
           on the fixture).
3. Recurrence head loop (both forwards):
   before: h in [0, state.head_count) with head_count = group_count
           (16 real) — computed 16 heads, wrote y only into the first
           2048 of 6144 slots, indexed ssm_a/dt_bias/alpha/beta by
           group head.
   after:  vh in [0, v_heads) with v_heads = dt_rank (48 real; 4
           fixture); group g = vh // (dt_rank // groups) (3 v-heads
           per group real, 2 fixture); ssm_a / dt_bias / alpha / beta
           indexed by vh; state slot offset vh*d_state*d_state;
           y and the z-gate (silu(z)) written at y_off = vh*d_state,
           spanning the full inner width.
4. q/k L2 normalization: before, done in place inside the head loop
   (would re-normalize broadcast-shared slices once per v-head).
   After: normalized ONCE per group band before the recurrence loop
   (per row in the batched path). Same eps-inside-sqrt (1e-6).
5. Qwen35State construction (aesir.mojo):
   before: Qwen35State(ssm_layers, ssm_group_count, state, 3*inner,
           kernel) — s_data = layers x groups x state x state,
           conv ring width 3*inner.
   after:  Qwen35State(ssm_layers, ssm_time_step_rank, state,
           qkv_width = 2*groups*state + inner, kernel) — s_data =
           layers x v_heads x state x state (real: 48 SSM layers
           x 48 x 128 x 128 = 37,748,736 f32 elements =
           150,994,944 B, matching the Q35-2 memory plan), conv
           ring width
           qkv_width. Qwen35Block gained ssm_group_count /
           ssm_state_size fields from GGUF config (init + copyinit).
6. Logit-row sink: forward_pass_qwen35 and
   forward_pass_qwen35_batched now honor kv_cache.capture_logit_row
   exactly like forward_pass (A-045) — captures the pre-sampling row
   the sampler sees; no-op when off. Added so fixture proofs (and
   Q35-3b teacher-forcing later) can observe qwen35 logits.

## Audit of the parts NOT changed (read, verified against layout truth)

- Full-attention branch (both paths): fused attn_q split is
  per-head interleaved [q(head_dim) | gate(head_dim)] at 2*q_width —
  matches the validator's 2*q_width rows and the plan's "correct"
  verdict; gate applied as attn * sigmoid(gate) after flash-attn.
- Partial rotary: apply_rope_partial_neox(q, k, pos, head_dim,
  rope_dims = config.rope_dimension_count = 64, theta) — 64 of 256
  on the real shape, as specified.
- SSM output path: per-v-head RMSNorm over d_state with the shared
  ssm_norm weight, gated by silu(z) at the v-head's inner offset,
  then ssm_out projection (inner -> hidden). Matches layout truth.
- ssm_slot arithmetic (layer - full-attn count before it) verified
  consistent between block and state sizing.

## Fixture (scripts/make_qwen35_fixtures.py, second profile appended)

qwen35_forward.gguf (913,120 B, 56 tensors, sha256
cb75eb8bd5beafb0f2f84b3ad6308c08f8e2a890fa7fac48e2168b542f8e2fac,
deterministic across regenerations; Q35-1 tiny fixtures regenerate
byte-identical, sha256 93d5864d... unchanged): hidden 128, ffn 256,
heads 2, kv_heads 1, head_dim 64, groups 2, state 16, dt_rank 4,
inner 64, qkv_width 128, conv_kernel 4, blocks 4, interval 4,
vocab 1024, context 512. Every Q8_0 input width % 32 == 0 (128,
256, 64, 128). Weights: seeded (20261114) pseudo-random — Q8_0 int8
payloads with small f16 scales, F32 norms in [0.9,1.1], conv1d in
[-0.25,0.25], dt_bias in [-0.5,0.5], ssm_a in [-3.0,-0.5] (negative
=> decay exp(a*dt) < 1, stable by construction).

## Proofs (logs in this folder)

Test driver: aesir_engine/tests/test_qwen35_forward_q35_3.mojo
(pattern: AesirEngine facade like bench_cpu_baseline_a030, direct
_forward_position / _forward_batch dispatch, KVCache with the
logit-row sink on). Build: build-q35-3.sh — full engine compile
ENGINE_BUILD_EXIT=0 (q35-3-build.log); test build exit 0
(q35-3-test-build.log). Run log: q35-3-test.log, ALL PASS, exit 0.

Verbatim outcomes:
- (a0) engine state geometry: layers=3 v_heads(dt_rank)=4 state=16
  conv_dim(qkv_width)=128.
- (a) forward over fixed 8-token sequence: finite logits (1024 wide),
  argmax 79 < vocab 1024, greedy sampled token == argmax.
- (c) STATE EQUALITY per-token vs batched (one 8-token chunk):
  s_data max_abs_diff = 0.0008479953, conv_data max_abs_diff =
  0.0078125, logits max_abs_diff = 0.013671875 (max |logit| =
  13.5546875, so ~0.1% relative). Next tokens identical. NOT
  bit-identical — see finding F1.
- (d1) continuation split per-token (A=4 then B=4, separate calls on
  one state/KV): s/conv/logits max_abs_diff = 0.0 / 0.0 / 0.0 EXACT.
- (d2) batched pure-prefill A (4) + per-token B: 0.0 / 0.0 / 0.0
  EXACT vs the one-stream per-token run.
- (d3) per-token A + batched chunk B at start_pos 4: diffs identical
  to (c) (0.0008479953 / 0.0078125 / 0.013671875); next token
  identical; batched continuation does not reset state.
- (b) greedy generation, prompt [1,3,17,42], 16 tokens, two
  independent runs IDENTICAL, all < 1024:
  1019 675 143 452 111 251 827 386 423 176 368 1018 910 490 742 849
- (e) real-signature formulas: q band 2048 @ 0, k band 2048 @ 2048,
  v band 6144 @ 4096, qkv_width 10240, state/layer 48x128x128 =
  786432, v-heads/group 3; fixture formulas likewise.

Regression (rebuilt from unchanged sources, same run unit):
- Q35-1 loader test: ALL PASS (q35-3-regress-q35-1.log).
- Q35-2 registry test: ALL PASS (q35-3-regress-q35-2.log).
- Full engine compile: exit 0. Full 905 matrix NOT re-run (slice
  order; baseline 901/905 stands).

## Findings and named risks

- F1 (for Q35-5): per-token vs batched are NOT bit-identical when
  positions pass through the batched block path: diffs at f16
  rounding scale (conv diff 0.0078125 = 2^-7, one f16 ulp at
  magnitude 8-16). Yet a 4-token batched prefill followed by
  per-token processing is bit-EXACT vs pure per-token (d2), and a
  batched continuation chunk reproduces the (c) diffs exactly (d3).
  The precise origin inside the batched block path (projection GEMM
  batching vs batched attention/conv handling) is NOT proven here;
  Q35-5 must not claim cross-path snapshot equality beyond these
  numbers, and same-path continuation (d1/d2) is the exact seed.
- U1 (unchanged, Q35-3b is the arbiter): recurrence semantics beyond
  layout — dt softplus/bias order, decay application, q/k repeat
  order, norm placement — cannot be settled at fixture grade. The
  fixture proves geometry + stability + determinism, not semantic
  agreement with llama.cpp.
- U1-rope-sections: rope.dimension_sections [11, 11, 10, 0] exists
  in both real files; no engine code reads it (Q40-1 finding).
  Recorded as a named Q35-3b risk: if llama.cpp's qwen35 rope is
  sectioned (mrope-style) rather than plain partial-neox over the
  first 64 dims, the full-attention layers will diverge at oracle
  grade even with correct widths. No rope-section logic invented.
- U1-scale: the recurrence applies head_scale = 1/sqrt(d_state) to
  the q-readout (pre-existing code, layout-neutral). Whether
  llama.cpp scales q by 1/sqrt(state) BEFORE the state read (and
  whether q/k L2-norm eps matches) is semantic — Q35-3b arbiters.
- Build-environment note (not a code bug): fenced systemd-run units
  run with empty $HOME (User=volmarr), which breaks the build
  scripts' PATH="$HOME/.pixi/bin" line, and a root-owned log from a
  first root run blocks later user runs. Working pattern used here:
  sudo systemd-run -p User=volmarr with `export HOME=/home/volmarr`
  inside the unit command; logs first created by the user unit.
