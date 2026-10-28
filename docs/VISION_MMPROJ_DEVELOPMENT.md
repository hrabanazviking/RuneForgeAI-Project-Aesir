# Vision (mmproj) Development — Design and Contract

Commissioned by Volmarr, 2026-10-27: "time to develop Project Aesir so it can
handle vision able models." Branch: `platform/cloud-hypervisor-epyc-vision`.
Sibling model repos are approved for use where a model's mmproj lives outside
the linked repo (Ministral-3-3B case).

This document is the contract for the vision line. It states what exists
today, what the end-to-end path will be, and exactly what each slice proves.
Nothing in this document promotes a capability beyond the evidence named for
it; `CAPABILITY_LEDGER.md` remains the only maturity authority.

## 1. Where Aesir stands today (inspected 2026-10-27, base `3d819147`)

- The engine loads one GGUF per model through two substrates:
  `loader/gguf.mojo` (`GGUFSeer`, F16 `RuneTensor` views + strict LLM tensor
  validation in `mmap_and_load`) and `loader/packed_gguf.mojo` (`PackedGGUF`,
  offset/shape inventory used by inspection and the native profiles).
- Architecture dispatch is by `general.architecture` string:
  `core/model_registry.mojo` (`ModelArchitectureRegistry`) classifies
  gemma4 / llama / qwen2 / qwen3 / mistral; `core/inference.mojo` builds
  `TransformerBlock`s from `blk.*` tensors and dispatches forward variants by
  architecture string (`gemma*` prefix, qwen35 SSM path, dense GQA path).
- **There is no vision code anywhere in the engine.** No source file mentions
  `mmproj`. Model resolution (`cli/model_reference.mojo`) resolves exactly
  one file per model; nothing ever looks for a sibling file beside a model.
- Consequences for a vision model today:
  - An `mmproj-*.gguf` file sitting beside the model GGUF is **silently
    ignored**. Chat runs text-only; the user is not told vision was dropped.
  - Pointing `aesir inspect` at an mmproj file itself **hard-errors**:
    `PackedGGUF` rejects any tensor with more than 2 dimensions
    ("Packed GGUF: only dense vectors/matrices supported"), and a real
    mmproj carries a 4-D patch-embedding tensor.
  - `GGUFSeer.mmap_and_load` on an mmproj fails twice over: the tensor table
    reader rejects rank > 2, and `_parse_metadata` ends by validating a
    tokenizer vocabulary that an mmproj does not carry.
- The chat template layer (`loader/chat_template.mojo`) is text-only; no
  image placeholder token handling exists.

## 2. The reference artifact (measured, not assumed)

`gemma-4-E2B-it-heretic-v1.mmproj-Q8_0.gguf`, from
`mradermacher/gemma-4-E2B-it-heretic-v1-GGUF` (the repo linked for the model
wave; the mmproj ships in-repo). Downloaded into this worktree's own
`.aesir/models` store. Size 557,368,352 bytes; sha256 recorded in
`~/workspace/model-tests/VISION_DEV_STATE.md` at download verification.

Header: GGUF v3, 40 metadata entries, 1,411 tensors.
`general.architecture = "clip"`, `general.type = "mmproj"`.

Vision metadata (`clip.vision.*`):

| key | value |
| --- | --- |
| projection_dim | 1536 (= the E2B language hidden size) |
| image_size | 224 |
| patch_size | 16 → (224/16)² = 196 patch tokens |
| embedding_length | 768 |
| feed_forward_length | 3072 |
| block_count | 16 |
| attention.head_count | 12 (head_dim 64) |
| projector_type | `gemma4v` |
| image_mean / image_std | [0,0,0] / [1,1,1] (pixels scaled to 0..1) |
| attention.layer_norm_epsilon | 1e-6 |

Tensor inventory, vision side (names exact):

- `v.patch_embd.weight` — F32, rank 4, dims [16, 16, 3, 768]
  (patch_h, patch_w, in_channels, out_channels; GGUF innermost-first).
- `v.position_embd.weight` — F32, rank 3, dims [768, 10240, 2].
  The exact position-embedding semantics of this factorized table must be
  verified against reference behaviour before any forward pass is claimed
  (Semantics pinned from the mtmd reference in section 5 below.)
- Per vision block `v.blk.{0..15}.*`: `ln1.weight`, `ln2.weight` (F32 [768]);
  `attn_q/k/v.weight`, `attn_out.weight` (Q8_0 [768, 768]);
  `attn_q_norm.weight`, `attn_k_norm.weight` (F32 [64]);
  `attn_post_norm.weight`, `ffn_post_norm.weight` (F32 [768]);
  `ffn_gate.weight`, `ffn_up.weight` (Q8_0 [768, 3072]);
  `ffn_down.weight` (Q8_0 [3072, 768]).
- Every Q8_0 weight carries four F32 scalar calibration tensors
  (`<name>.input_min/input_max/output_min/output_max`) — reference-side
  dynamic-quantization ranges. The vision parser inventories them; whether
  the encoder forward needs them is a Slice 3 question.
- Projector: `mm.input_projection.weight` — Q8_0 [768, 1536], mapping vision
  embedding 768 → language hidden 1536.

The same file also carries a complete **audio** tower (`a.blk.*`,
`mm.a.input_projection.weight`, `clip.has_audio_encoder = true`).
**Audio is out of scope for this line**; the parser inventories it as
"present, not interpreted".

Ministral-3-3B-Qwen3.8-Max-Reasoning-Distilled: its mmproj lives in the
static sibling repo (approved for use). Its structure has **not** been
measured yet; nothing about it is claimed until the file is in hand and
parsed. Expected differences to verify then: architecture string, projector
type, image size/patch geometry, tensor naming.

## 3. The end-to-end vision path (target)

1. **Discovery** — when a model is resolved, look beside the model file for
   an mmproj GGUF using the llama.cpp naming conventions, in order:
   `mmproj-<model-stem>.gguf`, `mmproj_<model-stem>.gguf`,
   `<model-stem>.mmproj-<quant>.gguf` (the heretic repo's spelling:
   `gemma-4-E2B-it-heretic-v1.mmproj-Q8_0.gguf`), `<model-stem>.mmproj.gguf`,
   any sibling whose name contains `mmproj` and ends `.gguf`
   (deterministic: shortest name, then lexicographic).
   No candidate → the model is text-only, exactly as today.
2. **Structure parse** — a dedicated inventory parser
   (`loader/mmproj.mojo`) built on `GGUFSeer`'s bounds-checked byte readers:
   header, full metadata fields, and the complete tensor table at ranks
   1–4 with per-tensor element counts and byte ranges, all range-checked
   against the file. It does **not** reuse `PackedGGUF` (rank ≤ 2, dense
   LLM assumptions) and does **not** run tokenizer validation.
   From the inventory it extracts a validated `VisionTowerSpec`: vision
   present, geometry (image/patch/embedding/feed-forward/blocks/heads),
   projector shape, and a cross-check that `projection_dim` equals the
   language model's `embedding_length`.
3. **Image preprocessing** (Slice 2) — decode an image to RGB, resize to
   `image_size`², scale by `image_mean`/`image_std`, patchify into
   (image_size/patch_size)² patch vectors in the patch-embedding's expected
   order. Codec scope is decided in that slice and stated honestly; there
   is no image decoder in the engine today.
4. **Vision encoder forward** (Slice 3) — patch-embedding convolution
   (a linear map over flattened patches), position-embedding add,
   16 bidirectional-attention blocks (Q8_0 GEMM via the existing packed
   dequant/GEMM substrate, per-head Q/K norms, post norms, GELU-gated FFN
   per the gemma4v block layout), final norm. Every stage verified against
   an independent numerical oracle before the next stage is built on it.
5. **Projection + embedding injection** (Slice 4) — `mm.input_projection`
   maps patch embeddings 768 → 1536; the resulting vectors replace the
   embedding rows of the image placeholder tokens in the prompt embedding
   stream before prefill. The language forward itself is unchanged.
6. **Chat surface** (Slice 4/5) — the chat template gains the gemma4 image
   markers (`<start_of_image>` … `<end_of_image>` around the image token
   span). How many soft tokens one image occupies under the gemma4v
   projector (pooling factor) is measured from reference behaviour in
   Slice 4, not assumed.

## 4. Slice plan and proof boundaries

- **Slice 1 — discovery + parsing + report (this commission's vertical
  slice).** Proves: Aesir finds the mmproj beside a vision model, parses
  its metadata and full tensor inventory from the real downloaded file,
  extracts and validates the vision tower spec against the language model,
  and reports the structure (CLI-facing report function + opt-in test on
  the real file + unit tests for discovery naming and spec validation).
  Proves nothing about image math or inference. **Registration closure DONE (2026-10-27): the three vision cases are registered in run_all (270 total) and AES-LDR-007 records the capability as partial.**
- **Slice 2 — image preprocessing.** Proves patchification math on known
  inputs against an independent oracle. Codec breadth stated as built.
- **Slice 3 — vision encoder forward.** Proves each stage numerically
  against an oracle on the real weights; end-to-end encoder output compared
  on a fixed test image. Position-embedding semantics resolved here, from
  evidence. **Stage 3a (patch-embedding projection) is DONE and oracle-
  verified on the real weights** (see `~/workspace/model-tests/
  VISION_DEV_STATE.md`). Stage 3b (position embedding + blocks) was gated
  on reading the reference semantics first; that reading is DONE and the
  pinned semantics are recorded in section 5 (FPE factorization, norm
  placement, RoPE form, clamping, pooling, projector token count). **Stage 3b is DONE (2026-10-27): the full forward is oracle-proven stage by stage (worst relative divergence 7.7e-06) and unit-tested.**
- **Slice 4 — projection + injection + chat markers.** Proves the projected
  embeddings enter prefill at the right positions with the right count.
  **DONE at unit + real-pair assembly level (2026-10-27); behavioural
  proof waits on the CUDA-session integration - see the outcome
  addendum below.**
- **Slice 5 — end-to-end + Ministral variant.** A real image question
  answered by the real model; Ministral mmproj measured and admitted the
  same way, or its deltas recorded as NOT PROVEN. **Ministral measured
  and admitted at spec level with Pixtral deltas recorded (2026-10-27);
  the end-to-end behavioural proof is NOT PROVEN on the development
  laptop - walls in the outcome addendum below.**

### Slice 4 injection design (recorded 2026-10-27; slices 1-3 closed)

- **What enters prefill.** The projected encoder output: 16 rows x
  1536 Float32 per 224x224 image. Pooling kernel 3 over the 14x14
  grid gives a 4x4 soft-token grid, so the open question in section 3
  item 6 is closed: the count is measured, and the pooled and
  projected stages are oracle-proven. Injection replaces embedding
  rows: when the prompt token stream is converted to embedding
  vectors for prefill, the rows at the image span take the encoder
  rows instead of token_embd lookups. The language forward
  (attention, KV cache, sampling) is unchanged; injected rows
  occupy real sequence positions and advance positions and KV
  exactly like text tokens.
- **The span.** The chat template wraps one image as
  <start_of_image>, then the image placeholder token repeated
  exactly n_soft times, then <end_of_image>. The marker ids and the
  placeholder token id are read from the language model tokenizer
  metadata at load; the first slice 4 implementation step verifies
  them against the reference chat behaviour on the real pair before
  any injection is claimed. One image per span; multiple images are
  multiple spans.
- **Fail-closed count discipline.** The number of rows replaced
  must equal the soft-token count of the encoder for the tower
  geometry. Any mismatch between template count and encoder output
  is a hard error before prefill, never a truncation or padding.
- **Interface.** The encoder entry point yields a Float32 buffer
  of [n_soft x projection_dim]; prefill embedding assembly accepts
  an optional span override (start position, row buffer, row width
  equal to embedding_length, already cross-checked at inspect
  time). No other prefill behaviour changes.
- **Accelerator placement (design constraint, per section 6).**
  The dense Q8_0 GEMMs of the encoder are the same substrate as
  the language model GEMMs; when the GPU line matures they run on
  the accelerator first, the CPU keeps orchestration and any
  spillover, threaded across all cores politely with thermal
  awareness. The current CPU forward is the correctness reference,
  not the performance target.
- **Proof plan.** (a) Unit: a synthetic embedding table plus a
  span override — exact rows replaced, neighbours untouched, count
  mismatch raises. (b) Integration on the real pair: fixed test
  image and prompt; the prefill embedding stream at the span equals
  the proven projected encoder output within the established
  Float32 tolerance, and equals token_embd rows everywhere else.
  (c) Behavioural end-to-end proof belongs to slice 5.

If a slice hits a genuine wall, the state note records exactly what is
proven and what is NOT PROVEN. No forward pass is ever faked, stubbed into
looking real, or reported beyond its oracle evidence.

### Slice 4/5 implementation outcome (2026-10-27, fourth commission)

- **Marker verification (design step 1).** The real LM's tokenizer
  metadata settles it: the canonical gemma4 template renders an image
  part as the single token `<|image|>` (id 258880); there are no
  start/end image tokens in the vocab. The span design adapts as this
  section always required (verify against reference behaviour first):
  the marker position expands to n_soft = 16 sequence positions
  carrying the marker id, whose embedding rows are the encoder's
  projected rows.
- **Implemented.** `apply_embedding_span` in `core/inference.mojo`
  (optional span override on both prefill entry points, applied
  immediately after embedding; Float32 rows cross an f16 seam);
  `AesirEngine.generate_image_chat` (marker from the tokenizer,
  exactly-one enforced, mmproj spec-checked, marker run verified
  equal to the encoder row count before generation, fail-closed);
  `encode_image_pixels` / `encode_image_rows` in
  `core/vision_encoder.mojo`.
- **Proven.** (a) Unit: tests/test_embedding_span.mojo, 4 cases (6 checks).
  (b) Real-pair assembly: tests/inject_mmproj.mojo - span rows match
  the numpy oracle dump at max abs 0.0019 (the f16 seam), neighbours
  bit-identical, all 24,576 span elements replaced. (c) Behavioural:
  NOT PROVEN on the development laptop - gemma4 execution in this
  codebase is the native CUDA session (the generic forward does not
  implement gemma4), forward-reaching compiles die in a pre-existing
  LLVM X86 DAG crash on this host CPU (identical on the untouched
  base), and the laptop NVIDIA driver is unloadable pending the
  owner's fix. tests/image_chat_mmproj.mojo (bit-exact forward
  control + red/blue behaviour + text-only control) is written and
  type-checks up to that codegen wall.
- **Pair admission repairs (GGUFSeer).** Array-typed
  `feed_forward_length` (per-layer widths; scalar summary = widest)
  and BF16 tensors (converted to f16 at load) are admitted - the
  real gemma4 file requires both (its only BF16 tensor is the
  per-layer projection).
- **PNG/JPEG.** Decoded by aesir_engine/image_decode.c (system
  libpng/libjpeg) bound link-time from the edge module
  loader/image_codecs.mojo into the same prep path: PNG pixel-exact
  vs the PPM route, JPEG within 3 LSBs on a smooth fixture
  (tests/test_image_codecs.mojo, opt-in). A dlopen binding cannot
  coexist in one binary with the engine's raw FFI declarations
  (core/cuda_gate.mojo), hence link-time binding at the edge.
- **Ministral-3-3B (slice 5 second half).** Its mmproj is a Pixtral
  tower (24 blocks x 1024, patch 14, variable native-resolution
  grids to 1540 px, CLIP mean/std, patch merger + 2-layer MLP
  projector, 2D-RoPE positions, no position table, no audio tower).
  Aesir parses it, spec-validates it (the spec's tensor stage is now
  projector-family aware; the canonical clip.projector_type key is
  read), and the language cross-check passes (projection_dim 3072
  == mistral3 embedding_length 3072). Its encoder forward is NOT
  implemented - a separate Pixtral encoder slice.

## 5. Reference semantics pinned from llama.cpp mtmd (2026-10-27, slice 3b gate)

Read from the llama.cpp checkout on this machine
(`~/workspace/model-tests/tools/llama.cpp`), `tools/mtmd/` unless noted.
These are the semantics the encoder implements; anything not listed here
as pinned is not assumed.

- **Graph entry**: `models/gemma4v.cpp`, `clip_graph_gemma4v::build()`.
  The tower is the generic `clip_graph::build_vit` (`clip.cpp:333`) with
  `NORM_TYPE_RMS`, `hparams.ffn_op`, no learned pos-embd argument (FPE is
  added before), and the `add_pos` RoPE callback.
- **Input scaling**: raw pixels are scaled `2*x - 1` before the patch
  convolution (`gemma4v.cpp:9-11`). With this file's mean 0 / std 1
  preprocessing (pixels in 0..1), the patch-embedding input is therefore
  in -1..1. Slice 3a proved the linear projection itself; the 2x-1
  scaling is part of the encoder forward from slice 3b on.
- **Factorized position embeddings (FPE)**: `v.position_embd.weight`
  [768, 10240, 2] is two axis tables. `pos_size = ne[1] = 10240`; table X
  is the view of rows 0..10239 (the dim-2 slab 0), table Y the view at
  offset `pos_size` rows (slab 1) (`gemma4v.cpp:31-47`). Per patch `i`
  (raster order), the host sets `pos_x[i] = i % n_cols`,
  `pos_y[i] = i / n_cols` (`clip.cpp:5829-5836`); the patch embedding gets
  `tbl_x[pos_x[i]] + tbl_y[pos_y[i]]` added. At 224/16 geometry only
  indices 0..13 of each table are reached.
- **RoPE inside attention** (`gemma4v.cpp:50-75`): applied to Q and K
  after the per-head norms. Head dim 64: dims [0, 32) are rotated with
  `pos_x`, dims [32, 64) with `pos_y`, both `GGML_ROPE_TYPE_NEOX` with
  `n_dims = 32`. ggml NEOX pairing is `(j, j + 16)` for `j` in 0..15,
  angle `pos * theta^(-2j/32)`, theta = `hparams.rope_theta = 100.0`
  (`clip.cpp:1824`). Kernel evidence: `ggml/src/ggml-cpu/ops.cpp`
  `ggml_rope_cache_init` (theta progression `freq_base^(-2/n_dims)`)
  and `rotate_pairs` (NEOX stride `n_dims/2`).
- **Attention scale**: `kq_scale = 1.0f` (`gemma4v.cpp:77`). Scores are
  plain `Q.K` with an unscaled softmax (`build_attn`, `clip.cpp:788`;
  non-flash path shown, flash path is the same math in F32). No mask:
  bidirectional. The Q/K per-head RMS norms and the V norm below take
  the place of the usual 1/sqrt(d) tempering.
- **Block structure** (`build_vit`, `clip.cpp:373-570`, separate-QKV
  branch; tensor roles per this file's inventory):
  1. `h = RMSNorm(x; ln1.weight, eps)` (no bias tensors exist).
  2. `Q/K/V = ClippableLinear(attn_q/k/v.weight, h)` (see clamping).
  3. Reshape to heads; per-head `Q = RMSNorm(Q; attn_q_norm.weight)`,
     `K = RMSNorm(K; attn_k_norm.weight)` over head_dim 64
     (norm-per-head branch: `q_norm->ne[0] == d_head`).
  4. RoPE on Q and K as above; `V = RMSNorm(V, eps)` with **no weight**
     (GEMMA4V special case, `clip.cpp:476-479`).
  5. Attention (scale 1.0), output through
     `ClippableLinear(attn_out.weight, .)`.
  6. `h = RMSNorm(attn_out; attn_post_norm.weight)`; residual `x += h`.
  7. `h = RMSNorm(x; ln2.weight)`; FFN: `geglu_split` =
     `gelu(ClippableLinear(ffn_gate.weight, h)) *
     ClippableLinear(ffn_up.weight, h)`, then
     `ClippableLinear(ffn_down.weight, .)` (`build_ffn`, `clip.cpp:662`;
     `FFN_GELU` set for GEMMA4V at `clip.cpp:1825`).
  8. `h = RMSNorm(ffn_out; ffn_post_norm.weight)`; residual `x += h`.
  No biases, no layer scales (`ls_1/ls_2/ls_out`), no tower pre/post
  norm tensors exist in this file (the 658-tensor vision inventory is
  exactly 16 blocks x 41 + patch + position embeddings), so those
  optional graph steps are absent here.
- **GELU variant**: `FFN_GELU` -> `ggml_gelu`, the tanh approximation
  `0.5*x*(1 + tanh(sqrt(2/pi)*x*(1 + 0.044715*x^2)))`
  (`ggml/src/ggml-cpu/vec.h:967-968`), **not** the erf form
  (`FFN_GELU_ERF` is a different hparams case).
- **ClippableLinear** (`gemma4v.cpp:120-133`; scalar loading
  `clip.cpp:2920-2946`): every `.weight` tensor with sibling F32 scalars
  `<base>.input_min/input_max/output_min/output_max` computes
  `y = clamp(W . clamp(x, in_min, in_max), out_min, out_max)`. In the
  graph this wraps **all** block linears (Q/K/V/out, gate/up/down) and
  the projector. It does **not** wrap the patch convolution. Missing
  scalars default to +-FLT_MAX (no clamp); this file carries all four
  scalars for every Q8_0 vision weight.
- **RMS norm**: ggml form, `x * rsqrt(mean(x^2) + eps) * w`,
  eps = 1e-6 (metadata `clip.vision.attention.layer_norm_epsilon`,
  matching the graph's `hparams.eps` source).
- **Pooler** (`gemma4v.cpp:88-107`): reshape the tower output to the
  14x14 patch grid, average-pool with kernel = stride = `n_merge`,
  then scale by `sqrt(768)`. `n_merge` defaults to 3 for GEMMA4V
  (`clip.cpp:1826`), overridable by GGUF key
  `clip.vision.projector.scale_factor` (`clip-impl.h:66`) -- **that key
  is absent from this file's metadata**, so n_merge = 3: the 14x14 grid
  pools to 4x4 = **16 soft tokens** per 224x224 image (pool windows start
  at 0/3/6/9, covering rows/cols 0..11). Pooled token order is
  `ox + 4*oy` (x fastest), matching the raster patch order.
- **std standardization**: optional tensors `v.std_bias` / `v.std_scale`
  (`clip-impl.h:437-438`) would apply `(x - bias) * scale` after pooling;
  **absent in this file**, so the step does not exist here.
- **Projector** (`gemma4v.cpp:110-117`): per-token plain RMS norm
  (`ggml_rms_norm`, no weight -- the `embedding_pre_projection_norm`),
  then `ClippableLinear(mm.input_projection.weight, .)` Q8_0
  [768 -> 1536]. Output: 16 tokens x 1536 at this geometry.
- **Host-side policies NOT part of the encoder** (recorded so they are
  never silently conflated with encoder semantics): mtmd resizes input
  images with a bicubic algorithm for GEMMA4V and applies a token-budget
  resize (`set_limit_image_tokens(70, 1120)`, `clip.cpp:1829`). Aesir's
  slices 2-4 hold preprocessing fixed at the slice-2 pipeline (bilinear,
  fixed 224) as the shared input to both implementations; the encoder
  verification is conditional on that input, exactly as slice 2/3a were.

## 6. Rules carried into every slice

- Existing test suites stay green; new tests follow `TESTING_PROTOCOL.md`
  (opt-in external-reference pattern for real weight files — model weights
  never enter Git).
- run_all registration and the `CAPABILITY_LEDGER.md` entry land together:
  the counted suite total is mirrored in the ledger's E-MASTER key and
  status summary, so a case is never added on one side only.
- The mmproj download lives only in this worktree's `.aesir/models`.
- Mojo conventions of the files being touched (`def`, bounds-checked reads,
  fail-closed errors) are matched, per `GIT_DISCIPLINE.md` and the doctrine.
- Accelerator-first execution (Volmarr, 2026-10-27): on a device with a
  GPU or NPU, most model work belongs on the accelerator. The CPU is for
  spillover when model parts exceed accelerator memory, or for an assist
  measured to massively speed up the complete run. On a device with NPU,
  GPU, and CPU, placement priority is NPU first, GPU next, and CPU last,
  but suitable work should also be partitioned for parallel use across
  all available processors when that gives the fastest complete run; the
  priority is not a strict serial fill order. Execution must use threaded
  access to all available cores and compute of every processor on the
  device, not a single-threaded or few-core subset with the remaining
  capacity idle, as long as that use is not choking off other running
  stuff: full-device use must leave breathing room for the operating
  system, Volmarr's own programs, and the other Aesir line sharing the
  machine. On purplelongship the mature vision execution target is
  therefore the RTX 2060 carrying the bulk of the tower, with CPU work
  only in the permitted spillover or measured-assist roles. CPU-first
  correctness slices prove semantics only and are not the target design.
- Thermal awareness and self-control (Volmarr, 2026-10-27): full-device
  use must never drive the machine into temperature meltdown. The vision
  execution design must watch device temperatures, throttle itself back
  before the danger zone when the machine starts to get too hot, and
  recover performance as temperatures fall. Speed and full-core use
  always bow to the machine's health.
