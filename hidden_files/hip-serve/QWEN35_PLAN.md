# Qwen35 Line Plan — serving the 27B heretic (qwen35) on Aesir

Seat: worktree `/home/volmarr/aesir-hipserve`, branch `yrsa/hip-serve`, head
2a24dfd4 (HS-1..HS-7 banked; main untouched at 31ab9363). Opened 2026-11-14
under Volmarr's continuation license: keep making Aesir more ready to be used
until he says he is starting to work on the machine himself. Rules for this
line: branch only, never push to main; Voxta and Ollama untouchable; the
testable serve (aesir-gate, llama3-3b on HIP, :18434) stays live in standard
form — swaps only at quiet moments, fenced identically, verified after;
heavy runs fenced (MemoryHigh=24G/MemoryMax=32G), MemAvailable checked first
(stand down under ~40 GB free), one heavy run at a time; every number
carries a contention note. Target: `/mnt/vault/models/gguf/Qwen3.8-27B-
Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf` (28,596,003,296 B,
sha256 1fca6eef...186f08e) served on Aesir at :18434 with a two-turn proof.

## Verified recon (2026-11-14, this session — tree + real file, not summaries)

### The blocker is a stack of four, not one

1. **Registry** (`aesir_engine/core/model_registry.mojo`):
   `ModelArchitectureRegistry.classify()` has branches for gemma4, llama,
   qwen2/qwen3 (dense GQA only), mistral. There is no qwen35 branch, so the
   file falls through to the default: UNSUPPORTED, "No architecture adapter
   is registered." That is the whole of the `aesir inspect` refusal
   (evidence: GATE_AND_27B_RESULTS.md + inspect-27b.log). Two follow-ons:
   `inspect()` post-READY validation routes every non-gemma4 profile into
   `dense_gqa_profile_for`/`validate_dense_gqa` — a qwen35 READY verdict
   needs its own dispatch branch; and the registry's native quantization
   lists (K-quants + F16/BF16/F32) do not include **Q8_0**, which is what
   the target file is.
2. **Loader validator** (`aesir_engine/loader/gguf.mojo`
   `_validate_qwen35_tensors`, line 1353): shape formulas encode an
   assumed layout that the real file does not have (details below). Its
   type expectations are F16 for every weight matrix; whether the type
   argument is actually enforced is ambiguous from the code —
   `_require_tensor_shape` (line 1092) fetches the actual type and raises
   only when the type record is missing. Q35-1 settles this by test.
3. **Engine-core forward** (`aesir_engine/core/inference.mojo`,
   Qwen35Block/Qwen35State/forward_pass_qwen35 + batched twin; wired in
   `aesir_engine/aesir.mojo`): the delta-net geometry is written against
   the same assumed layout (details below). This path is CPU/F16: the
   loader materializes every tensor as F16 (`seer.tensors` are
   RuneTensor[f16]), so a Q8_0 file loads dequantized at ~57 GB host RAM.
4. **Serve layer**: sessions exist only for the dense-GQA family
   (`core/llama3_cuda.mojo`, closed shape-admission table) and Gemma4
   (`core/gemma4_cuda.mojo`); `cli/native_serve.mojo` dispatches on
   profile llama3/qwen3/gemma4 and `core/runtime_plan.mojo` plans only
   those. No Qwen35 session, no qwen35 memory plan
   (`core/inference_memory.mojo` has llama3/gemma4 plans only).

### A-048's named cause, and why it no longer binds

A-048 (docs/bench/A048_ARCHITECTURE_LOAD_MATRIX.md, row M-004; asserted in
core/qwen_battery_a119.mojo): qwen35 smoke = LOAD_FAIL_NAMED_CAUSE,
"GGUF qwen35 SSM metadata is incomplete" — over **synthetic stories
fixtures**: the validator needs ssm metadata + SSM/fused-gate tensors no
fixture in the repo could supply. **The real 27B file supplies all of it**
(census below). A-048's failure was fixture-shaped; it is not evidence
about the real model. What it does prove: no real qwen35 fixture has ever
been loaded anywhere in this tree, so every qwen35 code path is unproven
against real geometry.

### The real file vs the code's assumptions (header census, read this session)

Metadata (all present): block_count 64, embedding_length 5120,
feed_forward_length 17408, head_count 24, head_count_kv 4, key_length 256,
full_attention_interval 4 (=> 16 full-attention layers, 48 SSM layers;
attn_q tensor count = 16, matches), attention.recurrent_layers array
present (64 entries), rope.dimension_count 64 (partial rotary of 256),
rope.freq_base 1e7, ssm.conv_kernel 4, ssm.group_count 16,
ssm.inner_size 6144, ssm.state_size 128, ssm.time_step_rank 48.
Tensor census: 851 tensors — 498 Q8_0, 353 F32; output.weight present
(not tied). Dims below are loader (rows x cols).

The real Gated-DeltaNet layout (llama.cpp qwen35 graph): per SSM layer,
q and k have group_count(16) heads x state(128) = 2048 each; v has
time_step_rank(48) heads x state(128) = 6144 = inner_size. So:
qkv_width = 2*groups*state + inner = 2048+2048+6144 = **10240**.

| Tensor (per SSM layer) | Real file | Validator expects | Forward assumes |
|---|---|---|---|
| attn_qkv.weight | 10240 x 5120, Q8_0 | 3*inner=18432 rows, F16 | conv_dim = 3*inner |
| ssm_conv1d.weight | 10240 x 4, F32 | (3*inner) x kernel, F32 | ring width 3*inner |
| attn_gate.weight | 6144 x 5120, Q8_0 | inner rows, F16 | inner (correct) |
| ssm_alpha / ssm_beta | 48 x 5120, Q8_0 | dt_rank rows, F16 | dt_rank rows (correct) |
| ssm_a | [48] F32 | [dt_rank] F32 | indexed by head (see below) |
| ssm_dt.bias | [48] F32 | F32 (correct) | per-head (see below) |
| ssm_norm.weight | [128] F32 | [state] F32 (correct) | per-head over d_state |
| ssm_out.weight | 5120 x 6144, Q8_0 | hidden x inner, F16 | (correct) |
| Full-attn attn_q | 12288 x 5120, Q8_0 | 2*q_width rows, F16 | fused q+gate split (correct) |
| Full-attn attn_k / attn_v | 1024 x 5120, Q8_0 | kv_dim rows, F16 | (correct) |

Forward-pass geometry bugs (per-token path, inference.mojo ~2429-2510;
the batched twin shares them):
- q/k/v slicing uses equal thirds: q_off = h*d_state, k_off = inner +
  h*d_state, v_off = 2*inner + h*d_state. Real offsets: q at 0, k at
  2048, v at 4096, each head strided within its own band.
- The recurrence loop runs h in [0, state.head_count) where the state was
  built with head_count = ssm_group_count (16) — but the recurrence is
  per **v-head**: 48 heads, with q/k broadcast from their 16 heads
  (each q/k head serves 3 v-heads), ssm_a/dt/beta indexed per v-head
  (48 entries), y and the z-gate 6144 wide over v-heads. As written it
  computes 16 heads and writes y only into the first 2048 slots.
- Qwen35State sizing (aesir.mojo construction): s_data is
  layers x groups x state x state; the real state is
  layers x v_heads(48) x state x state (~151 MB f32 for 48 layers);
  conv ring width is 3*inner instead of qkv_width (10240).

What already exists and helps: `core/hip_gemv.mojo` is a working HIP
**Q8_0** GEMV gateway (A-082) — the decode-critical device op for this
file's quantization exists. `core/compute.mojo` has gemm_q8_0 (CPU).
The tokenizer is gpt2-family/ChatML per inspect; the Seer path already
parses qwen tokenizers via RuneWeaver.

### Residency and prefix semantics for a hybrid (honest definitions)

- **Session residency** (applies, natural): within one serve session the
  SSM state (recurrence matrices + conv rings) and the 16 attention
  layers' KV persist across turns; turn N+1 continues from them. This is
  the direct analogue of HS-6 residency and the main chat win.
- **Exact prefix reuse** (applies ONLY via state snapshots): attention
  KV reuse is position-based and sound. SSM state is not positional —
  it is a summary of every token so far. A shared prompt prefix can be
  reused only by restoring an SSM+conv **snapshot taken at the exact
  token boundary** where the prefix ended, together with the KV for
  that prefix, and only if the prefix was processed identically. The
  batched prefill path claims bit-identical state vs per-token
  processing by construction; Q35-5 must PROVE that claim
  (state-equality test) before any reuse is advertised. Until then the
  serve must report exact_prefix_reuse for qwen35 as snapshot-based or
  off — never silently position-based.
- **Post-history anchor (HS-5) and memory injection (HS-7)**: text-level
  composition; they apply unchanged, subject to the injection contract's
  append-stability rule interacting with snapshots (injected blocks sit
  inside the snapshotted prefix or after it — the contract decides, the
  bench proves it).

## The slices (smallest honest sequence; each banked on this branch)

**Q35-1 — Loader truth for the real file.** Fix `_validate_qwen35_tensors`
formulas: qkv rows = 2*groups*state + inner; conv1d rows = qkv width;
settle the type-enforcement question by test and align the type policy
with the real census (Q8_0 weights, F32 small tensors). Proof: the
engine loader accepts the real 27B GGUF (load probe reaches tensor
materialization); a purpose-built small synthetic qwen35 fixture WITH
correct SSM geometry (the fixture A-048 named as owed: tiny dims,
interval 4, real layout) loads too; validator rejects a mutated fixture
with a wrong qkv width (negative test). Policy tests in the matrix.

**Q35-2 — Registry + profile + inspect.** qwen35 branch in
`classify()` (variant keyed on the hybrid geometry: 64L/5120d,
native_profile "qwen35", quantization policy admitting Q8_0);
`core/qwen35_profile.mojo` + validate mirroring gemma4_profile /
dense_gqa_profile; `inspect()` dispatch branch; `qwen35_memory_plan`
in inference_memory.mojo (weights + 16-layer KV + SSM state + conv
rings at a stated context). Proof: `aesir inspect` on the real file
returns READY/COMPATIBLE with tensor_validation "passed" and a sane
estimated footprint; registry policy tests (admit the real geometry,
refuse a wrong one) in the matrix.

**Q35-3 — Engine-core forward correctness (CPU).** Repair the
delta-net geometry end to end in inference.mojo + aesir.mojo: qkv
split (2048/2048/6144 for the real shape, formula-driven), conv_dim =
qkv_width everywhere (block, state, batched twin), recurrence over
v-heads with q/k broadcast, per-v-head ssm_a/dt/beta, y/z-gate over the
full inner width, Qwen35State sized layers x v_heads x state x state.
Proof in two grades: (a) the Q35-1 synthetic fixture — load, forward,
greedy completion, all IDs in vocab, and state-equality between
per-token and batched prefill; (b) the real 27B on CPU — load + a
short raw-prompt generation graded against a CPU comparator
(llama.cpp on the same file) by teacher-forcing rank + logit gap on
raw prompts, per house raw-oracle discipline; near-tie band applies.
Fence note: an F16-materialized 27B is ~57 GB host RSS — CPU proofs
run in a unit whose fence is sized for it and named as such; the
standing 24G/32G fence governs device work, and this exception is
recorded, never silent.

**Q35-4 — Serve session (CPU first).** A Qwen35 session implementing
the serve's session contract over the engine-core path; runtime_plan
admission for profile qwen35 (api=cpu), native_serve dispatch,
native_settings gate, SessionManager bookkeeping. Proof: serve the
synthetic fixture, then the real 27B, on a side port; two-turn
chat completion end to end; health reports the qwen35 profile with
capabilities stated per the semantics section (residency true,
prefix reuse as defined in Q35-5, anchor/injection true).

**Q35-5 — Residency + prefix snapshots for hybrid state.**
Snapshot/restore for Qwen35State (s_data + conv_data) bound to token
boundaries, integrated with prompt_prefix: reuse = KV prefix +
SSM snapshot at the same boundary, or no reuse. Proof: state-equality
test (chunked prefill snapshot == per-token state at the boundary);
an HS-3-style two-turn bench on the served 27B (CPU) reporting
turn-2 evaluated tokens vs turn-1; a diverged-history case reusing
only the shared head.

**Q35-6 — HIP execution.** Device path in steps: (a) projections via
the existing Q8_0 HIP GEMV (decode) + a Q8_0 prefill strategy (GEMV
rows or a GEMM — measured, not assumed); (b) full-attention layers on
device reusing the HIP attention/norm machinery at 24/4 heads x 256
dim with partial rotary; (c) the delta-net recurrence + conv1d as
device kernels with the state resident on device (the recurrence is
sequential per token — decode-step kernel, prefill processes
token-sequentially inside the kernel or in chunks with state
carry-over, proven equal to the CPU state trajectory). If (c)
proves disproportionate, the honest intermediate is (a)+(b) with
the SSM step on host and state round-tripped per token — shipped
only if measured end-to-end speed beats the CPU serve, and labelled
as hybrid placement. Proof: HIP serve of the real 27B, fixed-prompt
numeric agreement vs the CPU path (rank/gap), two-turn bench,
tok/s with contention noted. Footprint: Q8_0 weights 28.6 GB +
KV/state ~1-2 GB at ctx 4096-8192 — inside the 32G fence, tight;
context for the gate serve is set from the memory plan, not hope.

**Q35-7 — Gate swap + close.** At a quiet moment, swap aesir-gate to
the 27B on :18434 (llama3-3b remains the documented fallback in
VOXTA_SWITCHOVER), verify /health + one completion + a two-turn
chat; extend VOXTA_SWITCHOVER.md with the 27B-on-Aesir endpoint;
full matrix run fenced; QWEN35_RESULTS.md filed beside this plan;
the A-119 battery's qwen35 smoke row is reported for the record
(LOAD_FAIL row can be re-filed by the roadmap campaign — this line
only supplies the evidence; the roadmap seat is not ours to edit).

## Hard unknowns (named, with what settles each)

- **U1 — Recurrence semantics beyond layout.** The existing SSM step
  may differ from llama.cpp in more than offsets (dt softplus/bias
  order, decay application, q/k repeat, norm placement). Settled
  only by Q35-3's oracle grading; if the step is semantically off,
  Q35-3 becomes a bounded rewrite of that one step — the plan's
  shape survives, its cost grows. This is the line's main risk.
- **U2 — Validator type enforcement.** Whether the F16 type
  arguments in _require_tensor_shape bind at all. Settled by a
  Q35-1 probe test in minutes; affects only how Q35-1 is written.
- **U3 — CPU-serve memory vs fences.** ~57 GB F16 materialization
  cannot run under MemoryMax=32G. Q35-3/Q35-4 need an explicitly
  sized unit fence (recorded as an exception) or the CPU serve
  stays a proof, not a resident service, until Q35-6. Never solved
  by quietly dropping the fence.
- **U4 — Q8_0 prefill throughput on HIP.** GEMV exists; a prefill
  GEMM may not. If prefill is GEMV-bound, long-prompt chat on the
  HIP serve will be slow to first token even with fast decode;
  Q35-6 measures before promising.
- **U5 — Well/pool sizing for a 64-layer F16 model** in the Seer
  path (scratch for 5120-hidden prefill chunks). Settled at the
  Q35-3 load probe; a pool-sizing fix is in-scope if it blocks.

## First slice

Q35-1 (loader truth) — small, fully decidable, and it converts the
27B from "refused at inspect" to "loads through the engine's own
validator", which every later slice stands on.
