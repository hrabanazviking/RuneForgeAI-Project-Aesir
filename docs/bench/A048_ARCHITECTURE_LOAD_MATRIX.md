# A-048 — Architecture Load Matrix (Wave 6)

Llama/Qwen/Gemma-family fixtures present in the repo, loaded + smoked on
the Z13 (purpleraider, AMD Ryzen AI Max / Strix Halo, CPU path).
Acceptance: matrix filed; failures are named with causes. Rows are cited
as A-048:M-001 … M-008 by later slices.

## Fixture inventory (what the banked repo actually contains, at 0cacfc61)

- ONE real GGUF weight fixture: stories260K.F16.gguf, architecture
  `llama`, sha256 57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3
  (pinned in fixture_manifest.json as gguf.stories260k-f16-v3;
  5 layers, emb 64, ffn 172, heads 8, kv-heads 4, ctx 128, vocab 512).
  aesir_engine/model.gguf is a 24-byte placeholder, not a model.
- NO real Qwen or Gemma GGUF weight fixture exists in the repo, and a
  whole-machine search on purpleraider found none either (only
  vocab-only llama.cpp test files ggml-vocab-qwen2/qwen35/gemma-4.gguf,
  external to this repo, tokenizer-only, no weights). The repo's
  Modelfile.gemma4-e2b references gemma-4-E2B-it-Q4_K_M.gguf, which is
  not present anywhere on the machine.
- Text/tokenizer fixtures in the repo (no weights): llama3 tokenizer
  parity JSON + roleplay prompts; gemma4 tokenizer parity JSON +
  conversation prompts (fixture_manifest.json). No Qwen text fixture is
  in the manifest. tests/fixtures/hailo10h_qwen25_1_5b.json belongs to
  the Hailo line and is not a GGUF load fixture; it is not counted here.

## Method

- Synthetic architecture fixtures (A-046 synth512 precedent, honestly
  labelled): hidden_files/make_a048_fixtures.py rewrites the pinned
  stories GGUF — identical tensor blob (all 48 tensors, byte-for-byte),
  only GGUF metadata changes: general.architecture and the
  arch-prefixed config keys (llama.* -> <arch>.*). Tokenizer tokens and
  scores are the stories tokenizer's, so these rows test the loader's
  architecture dispatch, the per-arch tensor validators, and the
  inference architecture modifiers (RoPE-NeoX for Qwen, GELU +
  sliding-window + sqrt(hidden) embedding scale for Gemma) — they do
  NOT test a family's real tokenizer or trained weights, and no row
  claims otherwise. Synth sha256s are in the A-048 ledger.
- Smoke harness: aesir_engine/tests/bench_arch_matrix_a048.mojo —
  GGUFSeer load, RAW prompt "One day, Timmy went to" (no chat template),
  prefill + 16 greedy decode tokens via forward_pass, CPU only.
  No accelerator execution is claimed anywhere in this matrix.
- Grading: the llama row is graded against the pinned F16 oracle greedy
  IDs (manifest / A-045). Synthetic rows are graded load + forward +
  greedy completion with all generated IDs in vocab range; arch
  modifiers legitimately change the computation, so synth generations
  are never oracle-graded (raw-oracle discipline: a comparator must be
  the same architecture; IQ-style coherence discipline applies by
  analogy — completion, not token exactness).
- Registry column: ModelArchitectureRegistry.classify verdict for this
  exact geometry, read from core/model_registry.mojo — a native profile
  (28/32-layer production geometries) is a different claim from the
  generic engine load+smoke, and the matrix keeps the two separate.

## Matrix

| ID | Architecture | Fixture | Load | Smoke (prefill + 16 greedy) | Prompt tokens | Generated (first 16 greedy) | Registry at this geometry | Verdict |
|----|--------------|---------|------|------------------------------|---------------|------------------------------|----------------------------|---------|
| M-001 | llama | REAL stories260K.F16.gguf (pinned) | PASS (48 tensors validated) | PASS, oracle 16/16 vs pinned F16 greedy IDs | 8 | 265 282 295 433 335 345 357 426 342 394 261 370 268 414 444 335 | NOT READY — no native profile for 5L/64d (profiles are 28L/3072d, 32L/4096d) | PASS — the one real-fixture row; generic engine faithful to its own pinned oracle |
| M-002 | qwen2 | SYNTH from stories tensors | PASS | PASS, completes, all IDs in vocab | 9 | 298 316 386 386 386 267 265 376 298 315 356 417 264 419 426 405 | NOT READY — Qwen branch requires a native profile; only qwen3 0.6B (28L/1024d) has one | SMOKE_PASS (synthetic) — loader no-BOS Qwen branch + rope_neox modifier exercised; generation differs from llama, as the modifiers require; not oracle-graded |
| M-003 | qwen3 | SYNTH from stories tensors | PASS | PASS, completes, all IDs in vocab; generation identical to M-002 (qwen2 and qwen3 share every modifier in this engine path) | 9 | 298 316 386 386 386 267 265 376 298 315 356 417 264 419 426 405 | NOT READY — 0.6B profile is 28L/1024d, this geometry is 5L/64d | SMOKE_PASS (synthetic) — same note as M-002 |
| M-004 | qwen35 | SYNTH from stories tensors | FAIL — "GGUF qwen35 SSM metadata is incomplete" | not reached | — | — | UNSUPPORTED — no registry branch for qwen35 | LOAD_FAIL, named cause: Qwen3.5 is a hybrid Gated-DeltaNet SSM architecture; its validator (loader/gguf.mojo _validate_qwen35_tensors) requires ssm_inner_size/group_count/state_size/time_step_rank metadata plus SSM and fused-Q-gate tensors. No such fixture — real or synthetic-shaped — exists in the repo, and stories tensors cannot supply SSM state geometry. A faithful synth would need purpose-built SSM tensors, not a metadata rewrite |
| M-005 | gemma | SYNTH from stories tensors | PASS | PASS but DEGENERATE: constant token 267 x16 | 10 | 267 (x16) | UNSUPPORTED — no registry branch for gemma | SMOKE_PASS_DEGENERATE, named cause: the Gemma embedding scale (inference.mojo: sqrt(hidden_dim) = 8x for emb 64, applied to every gemma* arch) is applied to Llama-trained embeddings; on this 260K toy the scaled residual stream collapses greedy decode to a single attractor token. Real Gemma weights are trained with that scale; this is a fixture/semantics mismatch, not evidence of an engine defect — and not a coherence pass either. Recorded, not hidden |
| M-006 | gemma2 | SYNTH from stories tensors | PASS | PASS but DEGENERATE: constant token 267 x16 | 10 | 267 (x16) | UNSUPPORTED — no registry branch for gemma2 | SMOKE_PASS_DEGENERATE — same cause as M-005, with the gemma2 GELU + alternating sliding-window modifiers also exercised in the forward path |
| M-007 | gemma4 | SYNTH from stories tensors | FAIL — "GGUF gemma4 shared_kv_layers metadata is incomplete" (first validator gate) | not reached | — | — | NOT READY at any geometry except E2B (35L/1536d) / E4B (42L/2560d) profiles | LOAD_FAIL, named cause: Gemma 4's validator (_validate_gemma4_tensors) requires shared-KV metadata, SWA head-dim + sliding-window-pattern arrays, and per-layer-input (PLE) tensors (per_layer_token_embd, per_layer_model_proj, rope_freqs, per-layer Q/K norms) that no fixture in the repo contains. The only Gemma 4 weight file named anywhere, in Modelfile.gemma4-e2b, is absent from the machine (see inventory). The E-MASTER suite's own Gemma 4 cases cover the profile logic; a load+smoke row awaits a real pinned Gemma 4 GGUF — named as immediate next work in team-07 CAMPAIGN_STATE.md |
| M-008 | mistral (BONUS, outside the roadmap's three families) | SYNTH from stories tensors | PASS | PASS, oracle-identical 16/16 to M-001 (generic path applies no Mistral-specific modifier in this engine) | 10 | 265 282 295 433 335 345 357 426 342 394 261 370 268 414 444 335 | NOT READY — registry: "native CUDA adapter is not implemented yet" | SMOKE_PASS (synthetic, bonus row — not part of the A-048 acceptance count) |

## Reconciliation

Roadmap families = Llama, Qwen, Gemma. Architecture strings exercised
= 7 (llama, qwen2, qwen3, qwen35, gemma, gemma2, gemma4) + 1 bonus
(mistral) = 8 rows. Outcomes: real-fixture PASS 1 (M-001);
SMOKE_PASS synthetic 2 (M-002, M-003); SMOKE_PASS_DEGENERATE 2
(M-005, M-006); LOAD_FAIL with named cause 2 (M-004, M-007); bonus
SMOKE_PASS 1 (M-008). No architecture the loader or registry names in
these families is left unrowed: qwen2/qwen3/qwen35 are the Qwen strings
in loader/gguf.mojo, gemma/gemma2/gemma4 are the Gemma strings in
core/inference.mojo and the validators, llama is the real fixture.

## Discipline notes

- CPU engine only; no accelerator claim (accelerator-visible is not
  accelerator-run). Prompt-token counts differ per row (8/9/10) because
  the loader's per-arch tokenizer handling differs (Qwen: no BOS;
  Gemma/Mistral synth rows keep the stories tokenizer under arch
  dispatch) — counts are read from the smoke logs, not assumed.
- All counts and generations in this doc were read from logs on disk:
  hidden_files/a048_smoke.log + per-file a048_smoke_*.log, and the
  E-MASTER gate log hidden_files/a048_run_all.log (see ledger).
