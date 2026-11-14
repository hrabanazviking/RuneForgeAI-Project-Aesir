# Q40-1 — Registry family generalization for qwen35 — slice notes

Date: 2026-11-14. Seat: /home/volmarr/aesir-q35-40b, branch
yrsa/qwen35-40b, HEAD at start e6f1bbbf (Q35-1 + Q35-2 merged).
Worker ran the six Forge roles sequentially itself (recon ->
design -> build -> test -> repair -> record); sole writer in THIS
worktree; NOT committed / NOT pushed (coordinator verifies and
banks). The 27B seat (/home/volmarr/aesir-hipserve) was not touched
at all — this tree built its own shims and binary.

## Recon findings that shaped the design

- The Q35-2 pin lived in exactly one place: `classify()` in
  model_registry.mojo admitted only `layers == 64 and hidden ==
  5120`. Everything downstream was already general:
  `qwen35_profile_for` builds the profile from the file's own
  metadata, `qwen35_memory_plan` is formula-driven, and
  `validate_qwen35`'s tensor count was ALREADY the formula
  `expected_tensor_count() = 3 + 11*full + 14*ssm` (851 at 64L;
  1275 at 96L — verified against the real 40B's 1275 tensors), so
  no hard-coded total needed replacing.
- BUT `validate_qwen35(model, qwen35_profile_for(model), ctx)` on
  its own is self-consistent for ANY relation-satisfying geometry:
  nothing compared the geometry against the proven family. That
  comparison is the real generalization work of this slice.
- `classify()` receives only (architecture, size_label, layers,
  hidden, metadata_context, file_type, jinja) — it cannot see FFN,
  heads, or SSM geometry, and its 7-arg signature is used by the
  banked tests. So the signature check belongs in two layers
  (below), not in a classify signature change.

## Design choice (and why)

Two-layer, signature-driven, depth-free:

1. classify() (model_registry.mojo, qwen35 branch, ~line 330):
   admission is now `hidden == 5120 and layers > 0 and layers % 4
   == 0` — the proven per-layer width at any positive depth that
   is a multiple of the family full_attention_interval (4). No
   pinned depth, no size_label check: the 27B (64L) and the 40B
   (96L) are admitted by the same rule, and so would a future
   128L family member. model_variant stays purely the file's own
   general.size_label ("27B" / "39B"), native_profile stays
   "qwen35" for the whole family. Non-Q8_0 at an admitted
   geometry still returns NOT READY with native_profile set
   (the Q35-2 test's pinned expectation).
2. Profile layer (qwen35_profile.mojo): NEW
   `validate_qwen35_family_signature(profile)` (line 174) — the
   per-layer facts proven identical across BOTH real files:
   hidden 5120, FFN 17408, heads 24, KV heads 4, head_dim 256,
   interval 4, SSM groups 16, state 128, dt_rank 48, inner 6144,
   conv kernel 4, rope_dim 64 (Q8_0 is enforced in classify).
   Depth is deliberately NOT in the signature. Every refusal
   names the field, e.g. "Qwen35 family signature mismatch:
   feed_forward_length 17409 != 17408". `validate_qwen35` calls
   it (line 274) after relations + metadata equality, so the
   inspect() path (classify READY -> profile_for ->
   validate_qwen35 -> qwen35_memory_plan) can only reach READY /
   tensor_validation "passed" for a true family member; anything
   off-signature surfaces as NOT READY with the named error.
3. Variant label / constructors: `qwen35_40b_profile()` (line
   165) added as the twin of `qwen35_27b_profile()` because the
   pinned-constructor-per-size pattern is the code's convention —
   but it is a census record and a test anchor ONLY. Neither
   classify nor inspect selects a profile by size; both run off
   the metadata-built profile + family signature. No separate
   "40B" native_profile name was invented.

Files changed: aesir_engine/core/qwen35_profile.mojo (+52:
 docstring generalization note, qwen35_40b_profile,
 validate_qwen35_family_signature, one call in validate_qwen35),
 aesir_engine/core/model_registry.mojo (+14/-2 in the qwen35
 classify branch; reason text now "hybrid family profile").
 inference_memory.mojo UNCHANGED (already formula-driven).
New: aesir_engine/tests/test_qwen35_registry_q40_1.mojo,
 hidden_files/qwen35-adapter/{build-q40-1.sh,
 run-q40-1-proofs.sh, Q40-1-NOTES.md} + logs below + built
 binaries (.aesir/aesir and the three test/probe binaries in
 this folder; shims built fresh under this tree's
 hidden_files/hip-serve/shims/).

## Inspect verdicts (verbatim fields)

40B (q40-inspect.log, INSPECT_EXIT=0):

    "architecture":"qwen35","family":"Qwen 3.5","variant":"39B",
    "quantization":"Q8_0","tensor_naming":"qwen35/blk.*",
    "metadata_context":262144,"recommended_context":8192,
    "evaluated_context":8192,"tensor_validation":"passed",
    "estimated_vram_bytes":42584556036,"cuda_support":false,
    "cpu_support":false,"capabilities":"inspection",
    "compatibility":"COMPATIBLE","status":"READY",
    "native_profile":"qwen35","reason":"Matched the native
    Qwen 3.5 hybrid family profile (inspection and memory
    planning; execution lands in Q35-3/Q35-4)."

Before this slice (q40-inspect-prefix.log): COMPATIBLE /
NOT READY, native_profile absent, tensor_validation not_run,
estimated_vram_bytes 0, "this geometry has no matching native
profile yet." Same file, same command.

27B regression (q40-inspect-27b-regress.log, INSPECT_EXIT=0):
READY / COMPATIBLE, native_profile "qwen35",
tensor_validation "passed", estimated_vram_bytes 29295152100
— EXACTLY the banked Q35-2 value, zero drift. (Only the reason
text changed, 27B -> family, per the design above.)

## Footprint arithmetic (40B, evaluated context 8192)

qwen35_memory_plan(weights = file bytes, ctx 8192, profile):

- weights: 41,537,542,144 (the stored file)
- KV: 24 full-attention layers x 2 (K+V) x 8192 ctx x 1024
  kv_width (4 KV heads x 256) elements x 2 B (F16) = 805,306,368
- activations: 241,707,520, decomposed as
  - dense-style scratch: activation_elements(8192) = 531,968
    elements x 4 B = 2,127,872, plus sampling_device_bytes
    (248320) = 1,290,752 -> scratch total 3,418,624
  - SSM state: 72 SSM layers x 48 v-heads x 128 x 128 =
    56,623,104 elements x 4 B = 226,492,416
  - conv rings: 72 x 10240 qkv width x 4 kernel = 2,949,120
    elements x 4 B = 11,796,480
- device total: 41,537,542,144 + 805,306,368 + 241,707,520 + 4
  (one int32 output) = 42,584,556,036 — matches inspect exactly
  and the plan's own device_bytes in test (e4).

## Policy test (q40-1-test.log, fenced, TEST_RUN_EXIT=0)

    PASS (a): 40B geometry 96L/5120 Q8_0 -> native_profile qwen35, READY/COMPATIBLE, variant 39B
    PASS (b): depth-free admission (128L admitted); 95L and 96L/4096 refused a native profile
    PASS (c): Q4_0 at 96L/5120 refused; Q8_0 is the only family quantization
    PASS (d0): 40B formulas (24 full + 72 SSM, qkv 10240, 1275 tensors) hold
    PASS (d1): family signature admits both depths (27B 64L and 40B 96L)
    PASS (d2): off-family FFN refused: Qwen35 family signature mismatch: feed_forward_length 17409 != 17408
    PASS (e0): real 40B validates via qwen35_profile_for + validate_qwen35
    PASS (e1): 96L inner mutant refused: Qwen35 ssm_inner_size 6145 != ssm_time_step_rank * ssm_state_size (48 * 128)
    PASS (e2): 96L interval mutant refused: Qwen35 full_attention_interval 5 does not divide block_count 96
    PASS (e3): inspect 40B READY, tensor_validation passed, estimated_vram_bytes= 42584556036
    PASS (e4): 40B memory plan kv_bytes= 805306368  activation_bytes= 241707520  device_bytes= 42584556036
    PASS (e5): 27B inspect unchanged, estimated_vram_bytes= 29295152100
    PASS (f1): existing native.model_registry case still passes
    PASS (f2): existing native.gemma4_profiles case still passes
    Q40-1 qwen35 registry family generalization: ALL PASS

## Regression + ripple (fenced, both exit 0)

- Banked Q35-2 policy test, source UNCHANGED, rebuilt and re-run
  against the 27B (q40-q35-2-test-regress.log): ALL PASS,
  including (d2)/(d3) at the exact banked footprint 29295152100.
  Build exits (q40-1-build.log): ENGINE_BUILD_EXIT=0,
  Q40_1_TEST_BUILD_EXIT=0, Q35_2_TEST_BUILD_EXIT=0,
  RIPPLE_BUILD_EXIT=0.
- Ripple guard (q40-ripple.log): the Q35-2 ripple probe,
  unchanged source, run against the 40B file — NativeModelPlan
  still refuses qwen35 under "auto" ("Native CUDA session
  requires dense Gemma 4") and under explicit "qwen35"
  ("Unsupported native model profile"): PASS, no serve
  admission leaked by the generalization. Q35-4 still owns
  runtime_plan, including the known wart that the auto refusal
  text names Gemma 4.
- Full 905-case matrix NOT re-run (slice order, same as Q35-2;
  baseline 901/905 stands). Full engine compile exit 0 is the
  tree-wide compile evidence.

## Named next work / observations

- ROPE SECTIONS (for Q35-3, NOT built here): both real files
  carry qwen35.rope.dimension_sections = [11, 11, 10, 0]
  (verified this session by a read-only header parse of both
  files; the sections sum to 32 = rope_dimension_count / 2).
  NO engine code reads the key today: grep for
  dimension_sections over aesir_engine/ has no match; the
  loader config parser (loader/gguf.mojo) handles only the
  scalar rope.dimension_count / rope.freq_base keys (array
  values are not parsed there), and the profile layer
  (PackedGGUF-based) ignores it too. Q35-3's partial-rope
  forward work must decide how the sections map onto the
  64-of-256 partial rotary and teach the loader/profile to
  carry them.
- Forward/session/HIP/serve for the 40B follow the Q35 plan's
  order on the 27B line (Q35-3 CPU forward first); the 40B's
  full-residency loads stay parent-gated per the MAP (report
  MemAvailable + live set + expected peak first).
- validate_qwen35 is now family-scoped: a future non-family
  qwen35 geometry (different per-layer signature, internally
  consistent) will be refused by the family check even with a
  hand-built profile. That is this slice's intent (honest
  NOT READY off-signature); admitting a second family is a
  future slice's explicit act, not a silent widening.

## Safety record

MemAvailable checked before every build/run: 27.78-27.90 GB
throughout (floor ~10 GB). All heavy runs fenced in transient
systemd units (MemoryHigh=24G / MemoryMax=32G, User=volmarr),
one at a time. aesir-gate and ollama verified active before and
after; never touched. GGUF/vault read-only (header parse +
metadata-only inspect/test seams). No commits, no pushes.
