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
  (Slice 3 research item; NOT yet understood, NOT guessed here).
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
  Proves nothing about image math or inference.
- **Slice 2 — image preprocessing.** Proves patchification math on known
  inputs against an independent oracle. Codec breadth stated as built.
- **Slice 3 — vision encoder forward.** Proves each stage numerically
  against an oracle on the real weights; end-to-end encoder output compared
  on a fixed test image. Position-embedding semantics resolved here, from
  evidence.
- **Slice 4 — projection + injection + chat markers.** Proves the projected
  embeddings enter prefill at the right positions with the right count.
- **Slice 5 — end-to-end + Ministral variant.** A real image question
  answered by the real model; Ministral mmproj measured and admitted the
  same way, or its deltas recorded as NOT PROVEN.

If a slice hits a genuine wall, the state note records exactly what is
proven and what is NOT PROVEN. No forward pass is ever faked, stubbed into
looking real, or reported beyond its oracle evidence.

## 5. Rules carried into every slice

- Existing test suites stay green; new tests follow `TESTING_PROTOCOL.md`
  (opt-in external-reference pattern for real weight files — model weights
  never enter Git).
- The mmproj download lives only in this worktree's `.aesir/models`.
- Mojo conventions of the files being touched (`def`, bounds-checked reads,
  fail-closed errors) are matched, per `GIT_DISCIPLINE.md` and the doctrine.
