# Qwen35 Adapter Campaign — Ledger

## 2026-11-14 — Q35-5: residency + prefix snapshots for hybrid state, fixture-grade proof (verified + banked by coordinator)

- Snapshot/restore for Qwen35State at committed turn boundaries:
  Qwen35Snapshot deep-copies s_data + conv_data, the committed
  token stream, and — per the KV finding — the full-attention
  layers' KV prefix rows [0, boundary). KVCache is append-only
  and positionally stable WITHIN one live cache, but reset()
  redraws it over the same pool and intervening conversations
  overwrite prefix rows, so surviving snapshots COPY the KV
  prefix (only the 16-of-64 real / 1-of-4 fixture attn layers
  carry rows). Zero-state kept as a virtual snapshot at 0.
- Reuse = longest snapshot whose stream is an exact prefix of
  the new request's stream, or no reuse. Two exact checks in
  begin_turn (position 0 only): text-extension (resent text is
  byte-exactly snapshot conversation + "Assistant: " + its reply
  + one new user message; the stream is then snapshot.stream +
  tokenize(delta) BY CONSTRUCTION — re-tokenized reply text can
  never reproduce generated IDs, the seam HS-6 names) and
  token-prefix via reusable_prompt_prefix (final-token rule
  included). Resident Q35-4a path untouched.
- Store bound: snapshot_limit = 4 turn-boundary snapshots per
  session (configurable field), FIFO eviction, zero-state
  excluded. Real cost per snapshot: 27B SSM+conv 158,859,264 B
  + KV boundary x 65,536 B (4096 -> 268,435,456 B); 40B SSM
  alone ~235 MB — the bound is an informed choice (notes).
- Capability honesty: /health for qwen35 now reports
  exact_prefix_reuse=true ONLY with the new qualifier key
  exact_prefix_reuse_detail="snapshot-based at committed turn
  boundaries only" (serve_loaded gains the optional detail
  param; other profiles' payloads byte-identical).
- Proof ALL PASS (logs q35-5-*): session (a1) restore diffs
  s/conv/KV = 0.0/0.0/0.0 bit-exact; (a2) B re-run after restore
  s/conv/logits diffs 0.0, reply == resident; (a3) stateless
  begin prompt=90 reused=72, state/logits diffs 0.0; (c)
  diverged reused=0 prompt=191, reply == fresh cold reference;
  (d) 6 turns -> exactly 4 snapshots, oldest (60) evicted and
  unrestorable. Serve bench: resident reused=72/18 reply==R2;
  stateless (intervening session destroys residency) reused=72
  evaluated=18 reply==R2; diverged reused=0; bound resend-oldest
  reused=0 prompt=193 cold. F1: bit-exactness claimed only for
  same-path copy+continuation, never cross-path (notes).
- Regression: full engine compile exit 0; Q35-1 ALL PASS;
  Q35-2 ALL PASS; Q35-3a ALL PASS (greedy identical); Q35-4a
  session reference ALL PASS; Q35-4a resident + fresh HTTP
  benches ALL PASS (q35_4_bench.py caps assertion updated to
  the Q35-5 truth — deliberate extension); ripple probe ALL
  PASS unchanged. Proof units stopped; :18435 free; gate
  untouched. Full notes: Q35-5-NOTES.md. Banked by coordinator after disk verification of all proof logs. Next: Q35-6 (HIP) / Q35-3b (parent-gated).

## 2026-11-14 — Q35-4a: Qwen35 CPU serve session, fixture-grade proof (worker slice; verified + banked by coordinator)

- runtime_plan admits qwen35 explicitly: qwen35_profile_for +
  validate_qwen35 + qwen35_memory_plan branch; final else is
  gemma4-explicit (unknown profiles refuse by name). Fixture
  admission is an explicit opt-in (NativeModelPlan 4th arg
  experimental_qwen35 / serve flag --experimental-qwen35): the
  registry signature pin (64L/5120) is the only check skipped —
  validate_qwen35 runs in full — and the plan is marked
  experimental, reported in /health as experimental_admission.
  Without the opt-in the fixture still refuses with the registry's
  own reason. Variant follows the file (qwen35-27B real /
  qwen35-4L/128d fixture); serve family/parameter_size derive from it.
- NEW Qwen35CPUSession (aesir_engine/qwen35_session.mojo) over
  AesirEngine: batched prefill, per-token decode, persistent
  qwen35_state. reset() snapshots the committed stream (no reuse
  claimed), freshens KV, returns to position 0 WITHOUT wiping SSM
  state — the engine's reset-on-position-0 rule wipes it on the
  next conversation's first forward; resident turns skip reset and
  keep state bit-exact. Capabilities: residency TRUE,
  exact_prefix_reuse FALSE, suspend/restore not implemented,
  structured output + tools refused.
- Dispatch: cpu admitted ONLY for qwen35 (verbatim no-CPU-fallback
  refusal kept for all other profiles); qwen35 + cuda/hip refused
  as CPU-only in this slice; native_settings config whitelist
  gains cpu. Fixture tokenizer made byte-level toy (chars as
  tokens; weights untouched; Q35-1 fixtures byte-identical).
- Proof ALL PASS (logs q35-4-*): serve on side port 18435,
  /health profile=qwen35 backend=cpu residency=true
  exact_prefix_reuse=false experimental_admission=true; turn 1
  200 == in-process reference; resident turn 2 200 with
  reused_prompt_tokens=72, evaluated=18, reply == in-process A+B
  greedy reference EXACTLY (token streams in q35-4-session-test.log);
  fresh-instance control reused=0, prompt=193, different
  continuation. Proof units stopped; gate untouched on :18434.
- Regression: full engine compile exit 0; Q35-1 ALL PASS; Q35-2
  ALL PASS (sources unchanged); Q35-3a ALL PASS, greedy sequence
  identical. Ripple probe UPDATED by slice purpose: it asserted
  NativeModelPlan refuses qwen35 (Q35-2 truth); now asserts the
  Q35-4a admission truth (native for the real file, experimental-
  only for the fixture, unknown refused) — ALL PASS. Full notes:
  Q35-4-NOTES.md. Next: coordinator verify + bank; then Q35-5
  (SSM snapshots) / Q35-3b (parent-gated).

## 2026-11-14 — Q35-3a: CPU forward geometry repair, fixture-grade proof (worker slice; verified + banked by coordinator)

- Delta-net geometry repaired in inference.mojo (both forwards,
  identically) + aesir.mojo construction: conv_dim 3*inner ->
  qkv_width = qkv_weight.rows (2*groups*state + inner; 10240 real);
  qkv bands q [0, groups*state), k [groups*state, 2*groups*state),
  v [2*groups*state, qkv_width); recurrence over v-heads
  (dt_rank = 48 real) with q/k broadcast from group heads
  (3 v-heads/group), ssm_a/dt_bias/alpha/beta per v-head, y/z-gate
  over full inner width; q/k L2-norm once per group band (was
  in-loop per head); Qwen35State now layers x v_heads x state x
  state with conv ring qkv_width (construction passed group_count
  and 3*inner before). A-045 logit-row sink mirrored into both
  qwen35 forward_pass functions. Full-attention branch, partial
  rotary (64/256), ssm_norm/ssm_out path audited — already
  layout-true, unchanged.
- New fixture qwen35_forward.gguf (second profile in
  scripts/make_qwen35_fixtures.py; Q35-1 fixtures byte-identical):
  hidden 128, groups 2, state 16, dt_rank 4, inner 64, qkv 128,
  vocab 1024, all Q8_0 widths % 32 == 0, seeded random weights,
  ssm_a negative (stable by construction).
- Proof ALL PASS (q35-3-test.log): (a) finite logits, argmax 79 <
  1024, greedy == argmax; (b) greedy 16 tokens identical across
  two runs (1019 675 143 452 111 251 827 386 423 176 368 1018 910
  490 742 849); (c) per-token vs batched: s max_abs_diff
  0.0008479953, conv 0.0078125, logits 0.013671875 (max |logit|
  13.5546875) — NOT bit-identical, next token identical (finding
  F1 for Q35-5); (d1) split per-token continuation EXACT 0.0;
  (d2) batched-prefill-A + per-token-B EXACT 0.0; (d3) batched
  continuation chunk carries state, diffs as (c); (e) real
  signature formulas (2048 @ 0 / 2048 @ 2048 / 6144 @ 4096 /
  48x128x128 per layer).
- Regression: full engine compile exit 0; Q35-1 loader test ALL
  PASS; Q35-2 registry test ALL PASS (rebuilt, unchanged sources).
  Full 905 matrix not re-run. Named risks carried to Q35-3b:
  U1 semantics beyond layout (oracle-arbitrated), rope
  dimension_sections [11,11,10,0] unread by any engine code,
  1/sqrt(d_state) q-readout scale placement. No real file loaded
  through the forward path; Q35-3b stays parent-gated.
- Full notes: Q35-3-NOTES.md. Next: coordinator verify + bank;
  then Q35-3b (parent-gated) / Q35-4.

## 2026-11-14 — Q40-1: registry family generalization for qwen35 (worker slice; verified + banked by coordinator)

- Pin found in exactly one place: classify() admitted only
  64L/5120. The rest of Q35-2 was already general (expected
  tensor count = 3 + 11*full + 14*ssm = 851 at 64L, 1275 at
  96L, verified). The missing piece: nothing compared a
  geometry against the proven family.
- classify() qwen35 branch is now depth-free: hidden 5120 at
  any positive depth that is a multiple of the family interval
  4 -> native_profile "qwen35" (variant stays the file's own
  size_label: "27B" / "39B"). NEW
  validate_qwen35_family_signature (qwen35_profile.mojo)
  enforces the per-layer signature proven identical on both
  real files (5120 / 17408 / 24 / 4 / 256 / groups 16 / state
  128 / dt_rank 48 / inner 6144 / interval 4 / conv 4 / rope
  64; Q8_0 in classify) with named refusals, called from
  validate_qwen35 — so inspect reaches READY only for true
  family members at any depth. qwen35_40b_profile() twin added
  as census record/test anchor only; the path is signature-
  driven, never size-selected. inference_memory unchanged.
- 40B inspect (q40-inspect.log): READY / COMPATIBLE,
  native_profile "qwen35", tensor_validation "passed",
  estimated_vram_bytes 42584556036 = weights 41537542144 +
  KV 805306368 (24 full-attention layers, ctx 8192, F16) +
  activations 241707520 (SSM state 226492416 + conv rings
  11796480 + scratch 3418624) + 4. Before: NOT READY,
  no profile, 0 (q40-inspect-prefix.log).
- Zero drift on the proven path: 27B inspect re-run
  (q40-inspect-27b-regress.log) READY / COMPATIBLE at EXACTLY
  29295152100; the banked Q35-2 policy test, unchanged,
  re-built and re-run ALL PASS (q40-q35-2-test-regress.log).
- New policy test ALL PASS (q40-1-test.log): 96L classify,
  depth-free admission (128L in, 95L and 96L/4096 out),
  Q4_0 refused, both pinned constructors pass the family
  signature, off-family FFN refused by name, 96L inner and
  interval mutants refused by name, real-40B validate +
  inspect + exact plan numbers.
- Ripple guard PASS against the 40B (q40-ripple.log):
  NativeModelPlan still refuses qwen35 under auto and
  explicit — no serve admission leaked; Q35-4 owns it.
- Named next work: rope.dimension_sections [11, 11, 10, 0]
  is present in BOTH real files (read-only header parse this
  session) and read by NO engine code today (loader parses
  only the scalar rope keys; profile layer ignores it) —
  Q35-3 partial-rope work owns it. Full notes: Q40-1-NOTES.md.

## 2026-11-14 — 40B line opened (coordinator): recon verdict + separate-worktree road

- Volmarr's new primary objective: get the 40B (Qwen3.8-40B-Ultimate-
  Heretic Q8_0, 41,537,542,144 B) working on Aesir properly. SHA-256
  verified on-device: ccf16c2874da7846268901ab300d5138e896f08ed16811ff
  0b58b7f0126ac426.
- Header recon (read-only python parse + the loader probe below):
  architecture **qwen35** — the same hybrid family as the 27B, deeper:
  **96 blocks (72 SSM + 24 full-attention, interval 4)**, hidden 5120,
  FFN 17408, 24/4 heads, head dim 256, context 262,144. Per-layer
  geometry IDENTICAL to the 27B (groups 16, state 128, dt_rank 48,
  inner 6144, qkv width 10240, conv kernel 4, partial rope 64 with
  rope.dimension_sections [11, 11, 10, 0]). Tensors 1275 = 746 Q8_0 +
  529 F32; the census arithmetic closes exactly against the layer
  counts; no vision tensors (text stack only, despite the "vl"
  finetune name). Vocab 248,320.
- Road taken: **separate worktree** /home/volmarr/aesir-q35-40b on
  branch **yrsa/qwen35-40b**, based on banked yrsa/hip-serve @
  17cd0c98 — because the seat worktree had an active writer (the
  Q35-2 worker, mid-slice: registry/profile edits in flight at
  11:18–11:22). Q35 slices merge in as they bank; the adapter is
  never re-implemented in parallel. Volmarr ruled the earlier
  two-crew overlap a misunderstanding — no fault either side.
- Q35-1 generalization check: the loader validator is formula-driven
  from config (verified in the banked diff) — no 27B hardcoding to
  fix. First 40B proof already landed: the Q35-1 real-file probe run
  against the 40B file → **VALIDATION PASS** (96 blocks, 1275
  tensors, 3,965,696 F32 elements converted, small peak; log:
  q40-probe.log in this folder). Reading note: the probe's PASS line
  still prints "real 27B" — that is the probe's hard-coded text from
  Q35-1; its file argument was the 40B. Recorded here so the log is
  never misread; the text fix belongs to the probe's home line.
- Known gap for this line: the Q35-2 registry design pins
  native_profile on the 64L/5120 geometry — the 96L 40B needs the
  family-geometry generalization once Q35-2's final form is banked
  and merged in. Forward/session/HIP/serve follow the Q35 plan's
  order. Full-residency loads stay parent-gated: report MemAvailable
  + live set + expected peak + 100 GiB GTT fit before any attempt.

## 2026-11-14 — Q35-2: registry + profile + inspect (worker slice; verified + banked by coordinator)

- `core/qwen35_profile.mojo` NEW: formula-driven Qwen35Profile from
  GGUF metadata (qwen35_profile_for + validate_qwen35 +
  validate_relations with named refusals: interval not dividing
  blocks, inner != dt_rank*state, rope/head inconsistency; exact
  851-tensor contract mirroring the Q35-1 loader validator).
- classify() qwen35 branch: real geometry 64L/5120 ->
  native_profile "qwen35", READY / COMPATIBLE (qwen3 precedent:
  no generation witness yet), tensor_naming "qwen35/blk.*";
  Q8_0 admitted via a qwen35-scoped policy only (shared native
  lists untouched); other geometries COMPATIBLE without
  native_profile. cuda/cpu support stay false, capabilities stay
  "inspection" — execution is Q35-3/Q35-4, stated in the reason.
- inspect() dispatch + `qwen35_memory_plan`: KV priced for ONLY
  the 16 full-attention layers; activations carry SSM state
  (150,994,944 B) + conv rings (7,864,320 B), formula-driven.
  Real-file inspect now: READY / COMPATIBLE, tensor_validation
  "passed", estimated_vram_bytes 29295152100 at ctx 8192
  (q35-2-inspect-27b.log; was UNSUPPORTED at the gate).
- Policy test ALL PASS (q35-2-test.log): classify admit/refuse,
  three named validate refusals, real-file validate + inspect,
  exact memory numbers; existing native.model_registry +
  native.gemma4_profiles cases run unchanged inside it — pass.
  Full engine compile exit 0 (q35-2-build.log). Full 905 matrix
  NOT re-run (slice order; baseline 901/905 stands).
- Ripple guard PASS (q35-2-ripple.log): NativeModelPlan still
  refuses qwen35 under both "auto" and explicit "qwen35" — no
  serve admission leaked; Q35-4 owns runtime_plan. Named wart:
  the auto refusal text names Gemma 4 (gemma else-branch) —
  Q35-4 should add an explicit qwen35 branch. Also named:
  PackedGGUF cannot open the Q35-1 tiny fixture (ssm_out Q8_0
  columns 24, not 32-aligned), so the profile proof runs on the
  real file via the inspect seam; fixture regeneration was NOT
  done in-slice (would change banked Q35-1 expectations).
- Full notes: Q35-2-NOTES.md. Next: Q35-3 (CPU forward).

## 2026-11-14 — Q35-1: loader truth (worker slice; verified + banked by coordinator)

- `_validate_qwen35_tensors` fixed: qkv rows and ssm_conv1d rows now
  `qkv_width = 2*groups*state + inner` from config (real file: 10240);
  type constants aligned to the real census (Q8_0 weight matrices,
  F32 small tensors; 498 Q8_0 + 353 F32 re-verified by header parse).
- U2 SETTLED: types are recorded, not enforced — `_require_tensor_shape`
  never compares expected_type (code read), and the type-probe fixture
  (attn_gate stored F16 vs validator Q8_0) still validates (test (c)).
- Synthetic fixtures (scripts/make_qwen35_fixtures.py; tiny correct
  geometry, qkv 56): good PASS, bad-qkv (88) rejected with the shape
  error, type-probe PASS. Log: q35-1-test.log, ALL PASS.
- Real-file probe PASS through the no-materialization seam
  (inject_mmproj-style staging + direct _validate_required_tensors;
  zero-copy views + only 2,645,504 F32 elements converted; unit peak
  226 MB): q35-1-realfile-probe.log.
- Full notes: Q35-1-NOTES.md (incl. the pre-existing
  gguf.tensor_directory_interface regression note — unchanged,
  out of scope). Next: Q35-2 (registry + profile + inspect).

Running record. Newest entries at the top. Every entry from disk or a
tool result, never from a summary.

## 2026-11-14 — QA-0: campaign opened, plan adopted, seat verified

- Campaign commissioned by Volmarr in chat ("yes make the adopter for
  that kind") after the HS line's 27B gate verdict (NOT RUNNABLE:
  no qwen35 adapter, no recurrent-state session, no HIP path).
- Ground truth read on-device: GATE_AND_27B_RESULTS.md, MAP.md
  (HS line), inspect-27b.log, and the prior crew's QWEN35_PLAN.md —
  a complete verified recon (four-part blocker stack: registry,
  loader validator, engine-core forward geometry, serve layer) with
  slices Q35-1…Q35-7 and unknowns U1–U5. **Adopted as this
  campaign's plan**; it was banked by the prior crew at a8215e29
  ("Qwen35 line: recon + slice plan (Q35-1..Q35-7) banked") while
  this campaign was opening — local HEAD == origin/yrsa/hip-serve ==
  a8215e29, verified by fetch + ls-remote. Seat checked quiet (no
  build/git processes) before this campaign's first write.
- Target file SHA-256 verified on-device this session:
  1fca6eefc37607b5ab458f9a76815b36aeb38cf21ac36c49fdc0ab4eb186f08e
  (28,596,003,296 B) — matches the gate doc.
- Machine state at open: MemAvailable ~27 GB of 127 GB; aesir-gate,
  ollama, voxta all active (live for Volmarr's Voxta testing — never
  to be touched). The tracked `hidden_files/hip-serve/serve-bench.log`
  modification in git status is the live gate's own log; left alone.
- Full-suite baseline to defend (from the gate doc): 901/905 with
  only the two proven pre-existing failures
  (gguf.tensor_directory_interface; gpu.hip_q4k_gemv_no_leak).
- Next: Q35-1 (loader truth) — validator formula fix + type-policy
  probe + synthetic fixture. The real-file load probe in Q35-1
  reaches tensor materialization only; the full CPU residency proof
  is Q35-3 and carries the U3 memory exception decision with it.
