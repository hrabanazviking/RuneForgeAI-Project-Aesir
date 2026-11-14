# Q35-2 — Registry + profile + inspect — slice notes

Date: 2026-11-14. Seat: /home/volmarr/aesir-hipserve, branch yrsa/hip-serve,
HEAD at start 17cd0c98 (Q35-1 banked). Worker ran the six Forge roles
sequentially itself (recon -> design -> build -> test -> repair ->
record); sole writer; NOT committed / NOT pushed (coordinator
verifies and banks).

## What changed

1. `aesir_engine/core/qwen35_profile.mojo` (NEW, 262 lines):
   `Qwen35Profile` built formula-driven from the model's own GGUF
   metadata, mirroring gemma4_profile / dense_gqa_profile style.
   - `qwen35_profile_for(model)` reads block_count, embedding_length,
     feed_forward_length, head counts, key/value_length,
     full_attention_interval, ssm.{group_count,state_size,
     time_step_rank,inner_size,conv_kernel}, rope.{dimension_count,
     freq_base}, epsilon; vocabulary from token_embd.weight rows
     (248320 on the real file). Also `qwen35_27b_profile()`, the
     census-pinned named constructor.
   - Derived: full_attention_layers = blocks/interval (16),
     ssm_layers (48), qkv_width = 2*groups*state + inner (10240),
     kv_elements (full-attention layers only), ssm_state_elements
     (48 x 48 x 128 x 128 = 37,748,736), conv_ring_elements
     (48 x 10240 x 4 = 1,966,080), expected_tensor_count
     (3 + 11*full + 14*ssm = 851 real / 56 tiny).
   - `validate_relations()` refuses inconsistent hybrid geometry
     with named errors (interval not dividing block_count;
     inner != dt_rank*state; rope_dim > head_dim; incomplete SSM
     metadata; ...). `validate_qwen35(model, profile, context)`
     runs relations first, then metadata equality, context bounds,
     the exact per-layer tensor contract the Q35-1 loader validator
     proved (full-attn vs SSM layer split by interval), the exact
     tensor count, and the F32 norm/scale sweep the other profiles
     use. Tensor types stay recorded-not-enforced (Q35-1 U2).
2. `aesir_engine/core/model_registry.mojo` (+49/-~4):
   - `qwen35_quantization_supported(name)`: Q8_0 only, scoped to
     qwen35. The shared native lists are NOT extended (no other
     qwen35 quantization has evidence).
   - `classify()` qwen35 branch: family "Qwen 3.5",
     tensor_naming "qwen35/blk.*", supported_quantizations "Q8_0",
     recommended_context min(metadata, 8192). The real hybrid
     geometry (64L/5120) -> native_profile "qwen35", READY /
     COMPATIBLE (COMPATIBLE, not VERIFIED, following the qwen3
     precedent: no generation witness exists yet). Non-Q8_0 at the
     pinned geometry -> NOT READY. Other qwen35 geometries ->
     COMPATIBLE without native_profile, NOT READY (mirrors the
     qwen3 non-pinned treatment structurally).
   - Honesty flags: cuda_support and cpu_support stay false and
     capability_flags stays "inspection" — no execution path is
     proven until Q35-3 (CPU forward) / Q35-4 (serve); READY here
     means inspect/profile/memory-plan ready, and the reason
     string says exactly that.
   - `inspect()` dispatch: native_profile "qwen35" ->
     qwen35_profile_for + validate_qwen35 + qwen35_memory_plan,
     so tensor_validation can report "passed" for the real file.
3. `aesir_engine/core/inference_memory.mojo` (+21):
   `qwen35_memory_plan(weights, context, profile)`: weights =
   stored file bytes; kv = kv_elements(context) * 2 (F16, the
   llama3 convention) priced for ONLY the 16 full-attention
   layers; activations = dense-style F32 scratch +
   sampling_device_bytes + SSM state (ssm_state_elements * 4)
   + conv rings (conv_ring_elements * 4), all formula-driven.
4. Tests/probes (NEW): `aesir_engine/tests/test_qwen35_registry_q35_2.mojo`
   (policy proof, below) and
   `aesir_engine/tests/probe_qwen35_runtime_ripple_q35_2.mojo`
   (serve-admission ripple guard, below).
5. `hidden_files/qwen35-adapter/build-q35-2.sh` (NEW): engine +
   policy-test build following build-1.sh (pixi run --frozen mojo
   build -I . --target-accelerator gfx1151 + shim link line).
   Logs: q35-2-build.log (ENGINE_BUILD_EXIT=0, TEST_BUILD_EXIT=0),
   q35-2-test.log, q35-2-inspect-27b.log, q35-2-ripple.log.

## Inspect verdict (q35-2-inspect-27b.log, verbatim fields)

    "architecture":"qwen35","family":"Qwen 3.5","variant":"27B",
    "quantization":"Q8_0","tensor_naming":"qwen35/blk.*",
    "supported_quantizations":"Q8_0","metadata_context":262144,
    "recommended_context":8192,"evaluated_context":8192,
    "tensor_validation":"passed","estimated_vram_bytes":29295152100,
    "cuda_support":false,"cpu_support":false,
    "capabilities":"inspection","compatibility":"COMPATIBLE",
    "status":"READY","native_profile":"qwen35"

Footprint sanity: 29,295,152,100 = file bytes 28,596,003,296 +
KV 536,870,912 (16 full-attn layers, ctx 8192, F16) + activations
162,277,888 (SSM state 150,994,944 + conv rings 7,864,320 +
scratch/sampling 3,418,624) + 4. Same order as the 28.6 GB file,
as required. The inspect path prices the plan at the registry's
recommended context (8192), which is the plan's stated context;
no second context is involved. Before this slice the same command
returned compatibility UNSUPPORTED / "No architecture adapter is
registered." (hidden_files/hip-serve/inspect-27b.log).

## Policy test (q35-2-test.log, verbatim; fenced 24G/32G, exit 0)

    PASS (a): real geometry 64L/5120 Q8_0 -> native_profile qwen35, READY/COMPATIBLE
    PASS (b): Q4_0 refused; non-pinned geometry COMPATIBLE without native_profile
    PASS (d0): tiny-geometry formulas (qkv 56, 56 tensors, 1 full + 3 SSM) hold
    PASS (d1): real file validates via qwen35_profile_for + validate_qwen35
    PASS (c1): interval mutant refused: Qwen35 full_attention_interval 4 does not divide block_count 63
    PASS (c2): inner mutant refused: Qwen35 ssm_inner_size 6145 != ssm_time_step_rank * ssm_state_size (48 * 128)
    PASS (c3): mutated attn_qkv tensor refused: Packed GGUF: unexpected shape blk.0.attn_qkv.weight
    PASS (d2): inspect READY, tensor_validation passed, estimated_vram_bytes= 29295152100
    PASS (d3): 27B memory plan kv_bytes= 536870912  activation_bytes= 162277888  device_bytes= 29295152100
    PASS (e1): existing native.model_registry case still passes
    PASS (e2): existing native.gemma4_profiles case still passes
    Q35-2 qwen35 registry/profile policy: ALL PASS

## Regression evidence

- (e1)/(e2) above: the existing run_all cases
  native.model_registry (test_model_architecture_registry) and
  native.gemma4_profiles (test_gemma4_profiles) were imported and
  run unchanged inside the policy test — both pass.
- Full engine compile (main.mojo -> .aesir/aesir) exit 0 is the
  tree-wide compile evidence. The full 905-case matrix was NOT
  re-run (memory-tight box, live services), per the slice order;
  baseline to defend remains 901/905 per the gate doc.

## Ripple guard — serve admission did NOT leak (q35-2-ripple.log)

classify()/inspect() READY feeds NativeModelPlan (runtime_plan).
Probe verdict, verbatim:

    PASS (r1): NativeModelPlan(auto) refuses qwen35 today: Native CUDA session requires dense Gemma 4
    PASS (r2): NativeModelPlan(qwen35) refuses explicitly: Unsupported native model profile
    Q35-2 runtime ripple guard: PASS - no serve admission leaked

No qwen35 session can be constructed today; Q35-4 still owns
serve admission. NAMED WART for Q35-4 (not fixed here — runtime_plan
is outside this slice's files): under "auto", the refusal surfaces
from runtime_plan's gemma else-branch, so its text names Gemma 4
instead of the real cause. Q35-4 should give runtime_plan an
explicit qwen35 branch (admission + an honest refusal text until
then). cli/native_serve.mojo's profile->family derivation also
defaults unknown profiles to gemma4, but it is unreachable for
qwen35 while NativeModelPlan refuses — Q35-4 must handle it when
it wires the qwen35 session.

## Bugs / findings inside the slice (all handled, none silent)

- PackedGGUF cannot open the Q35-1 tiny fixture at all:
  packed_row_bytes requires Q8_0 rows 32-block-aligned and the
  fixture's ssm_out.weight has 24 Q8_0 columns (inner=24). The
  profile layer therefore cannot be exercised on that fixture;
  the policy test drives the profile path against the REAL file
  through the same metadata-only PackedGGUF seam inspect uses
  (nothing materialized), and keeps the tiny geometry as pure
  formula checks (d0). The real file is fully aligned. Named for
  the coordinator: if a PackedGGUF-openable tiny qwen35 fixture
  is wanted later, regenerate with inner % 32 == 0 (e.g. state 16
  x dt_rank 2 = inner 32) — that changes Q35-1's banked fixture
  expectations (qkv 56), so it was NOT done inside this slice.
- Build repairs in-slice: the first fenced build ran as root
  (pixi not on PATH / root-owned log) — rerun as a uid=volmarr
  unit with HOME exported; the test's first draft used an
  immutable PackedGGUF parameter for the tensor-mutation case —
  repaired to a `mut` parameter (the qwen3 test's pattern).
- MemAvailable was checked before every build/run (27.6–27.9 GB
each time, above the ~10 GB stand-down floor). aesir-gate /
  ollama / voxta were never touched and remained active
  throughout. All heavy runs fenced MemoryHigh=24G/MemoryMax=32G,
  one at a time.

## Files left in the worktree (uncommitted, for the coordinator)

Modified: aesir_engine/core/model_registry.mojo,
aesir_engine/core/inference_memory.mojo (+ the pre-existing
live-gate modification to hidden_files/hip-serve/serve-bench.log,
not mine). New: aesir_engine/core/qwen35_profile.mojo,
aesir_engine/tests/test_qwen35_registry_q35_2.mojo,
aesir_engine/tests/probe_qwen35_runtime_ripple_q35_2.mojo,
hidden_files/qwen35-adapter/{build-q35-2.sh, Q35-2-NOTES.md,
q35-2-build.log, q35-2-test.log, q35-2-inspect-27b.log,
q35-2-ripple.log, q35-2-test-build.log} + built binaries
test_qwen35_registry_q35_2 / probe_qwen35_runtime_ripple_q35_2
in hidden_files/qwen35-adapter/ and the rebuilt .aesir/aesir.
Next: Q35-3 (CPU forward correctness).
