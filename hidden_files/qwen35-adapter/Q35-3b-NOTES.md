# Q35-3b — real-file oracle grade (worker slice)

Worker runs all six Forge roles sequentially in one seat. Seat:
/home/volmarr/aesir-q35-3b @ yrsa/q35-3b, base 9853ba62.
Target file: /mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
  size on disk re-verified 2026-11-14: 28,596,003,296 B (matches brief).

## Recon (2026-11-14 ~13:34 EST, measured)
- MemAvailable 121,454 MB (free -m available col); load 0.12; up 3:32.
- aesir-gate / ollama / voxta all inactive (Volmarr's ordered stop stands).
- Worktree clean at base 9853ba62 on yrsa/q35-3b.
- No llama.cpp binary or source on box (confirms QC-0 U-QC1); ollama binary exists at /usr/local/bin/ollama (service stopped). g++ 15.3, cmake 4.3.4, git 2.55, 32 cores available for builds.
- Grading arithmetic = banked A-045/A-111: parity_logit_rank/gap (core/parity_battery.mojo), near-tie band rank<=2 AND gap<1.0 (core/near_tie_gate.mojo). Rows from KVCache.capture_logit_row sink (forward_pass_qwen35 honors it, Q35-3a fix 6).
- Load path decision: RESIDENT (qwen35_resident=True). Reasons: (1) Q35-3r proved resident numerics identical to default (logits diff 0.0, same packed views/kernels) so the grade is of the same forward; (2) resident avoids the 53.8 GB F16 materialization term — the only path that fits the fence honestly; (3) the real file passes resident validation (Q35-3r census: 498 large tensors all Q8_0).
- Battery honesty: core/qwen_battery_a119.mojo qwen_smoke_status(qwen35)=LOAD_FAIL_NAMED_CAUSE is a DATA row (A-048 era), asserted by tests/test_qwen_battery_a119.mojo. If the real load+forward succeeds here, that row is stale; disposition decided after the grade (deliberate in-slice update with citation, or named Q35-7 scope-out).
- Named risks carried from Q35-3: U1 recurrence semantics beyond layout (THIS slice arbitrates); rope dimension_sections [11,11,10,0] unread by engine; 1/sqrt(d_state) q-readout scale placement.

## Comparator plan
- Build llama.cpp natively (no Docker) OUTSIDE the repo at ~/llama.cpp-build; record commit + flags here. First check: does upstream llama.cpp know arch "qwen35" at all — if not, substitution must be named honestly.
- Teacher forcing: ONE token stream, tokenized once from the file's own tokenizer (Aesir RuneWeaver encode of RAW prompts, add_bos per file tokenizer config — to be pinned in recon of both tokenizers); the identical ID stream is fed to both engines. No chat template anywhere.

## Findings (streamed)
- Comparator: llama.cpp built NATIVELY (no Docker) at ~/llama.cpp-build, upstream ggml-org/llama.cpp commit a956a852c9c8bc1fb07206364838ddef299178c0 (shallow clone 2026-11-14), flags: -DGGML_NATIVE=ON -DLLAMA_CURL=OFF -DCMAKE_BUILD_TYPE=Release, targets llama-cli + llama-perplexity, BUILD_DONE_EXIT=0. Upstream KNOWS arch "qwen35" (src/llama-arch.cpp LLM_ARCH_QWEN35) — no substitution needed; the plan's named comparator grades the same file.
- Comparator tool: ~/llama.cpp-build/q35grade/q35grade.cpp (kept OUT of the repo with the build tree) — feeds token IDs from the tokens file, one decode per position, raw logits rows via llama_get_logits_ith; computes argmax + rank/gap of the true next token per position; greedy witness (40 tokens) for prompt 0. CPU only (n_gpu_layers=0).
- Aesir driver: aesir_engine/tests/grade_qwen35_oracle_q35_3b.mojo — modes grade/gen/batch, resident load, banked parity arithmetic imported from core.parity_battery (no re-typed band). Tokenize-once probe: aesir_engine/tests/probe_qwen35_tokens_q35_3b.mojo (metadata-only parse; round-trip decode witness per prompt).
- Grading set: 5 RAW prompts (factual / prose narrative / code / long prose / counting), exact token counts recorded in q35-3b-tokens.log when the probe runs.

## GRADE v1 (pre-fix): FAIL — and the oracle arbitrates U1
- Aesir (resident, per-token) vs llama.cpp: 198 positions, comp-argmax in-band 61/198 (30.8%), argmax agreement 50/198; Aesir greedy from P0 = token 9338 (" France") x40 (repetition loop) vs llama coherent text. Divergence present at pos 0 (kills the rope-sections hypothesis for the main defect; rope is identity at pos 0) and in every prompt; counting prompt least bad (28/38 in band).
- Static audit vs llama.cpp sources (all in ~/llama.cpp-build): delta rule order (decay->delta->rank-1->readout), 1/sqrt(d_state) at readout, sigmoid beta, softplus(alpha+dt_bias), exp(a*dt) with ssm_a = -exp(A_log) (verified all-negative in file, [-0.335,-0.0038]), conv tap order (tap0=oldest, both), L2 norm (ggml gdn form == x/sqrt(sum+eps), eps=1e-6 from file metadata), gated norm order, full-attn q/gate interleave + per-head q/k RMSNorm, ssm_slot arithmetic, embedding Q8_0 row decode, output.weight head — ALL match Aesir.
- THE DEFECT (U1, q/k repeat order): llama.cpp qwen35 graph does NOT pre-expand q/k (contrast qwen3next.cpp, which repeat-interleaves explicitly); ggml_compute_forward_gated_delta_net indexes q/k head as vh % n_k_heads (TILED broadcast). Aesir used vh // v_per_group (contiguous / repeat-interleave). On the real shape (16 groups, 48 v-heads) 32 of 48 v-heads read the WRONG q/k head in every SSM layer.
- FIX: inference.mojo both forward paths, g = vh % groups (one line each + comment). Rebuilt grade driver only and re-ran P0: rank_comp=1 gap=0 at all 4 positions; Aesir greedy P0 (40 tok) now TOKEN-IDENTICAL to llama.cpp: " Paris.\n\nThat is correct. **Paris** is the capital and most populous city of France. It is located in the north-central part of the country along the Seine River and is a major global" — the campaign milestone (first coherent words from the real file) lands WITH the fix.

## GRADE v2 (post-fix): FAITHFUL
- Aggregate (198 positions, 6 raw prompts): comparator argmax in Aesir's row: rank 1 at 197, in near-tie band 198/198 (100%). Argmax agreement 197/198. The single non-exact record: P5 pos 32, rank 2, gap 0.015 logits (textbook near-tie). True-token rank in Aesir: rank 1 at 142 (the comparator's own true-token rank-1 count on the same stream is also 142 — the rows are functionally identical, not merely close).
- Per prompt (comp-argmax in band / agree): P0 4/4, P1 18/18, P2 30/30, P3 59/59, P4 38/38, P5 49/49 (agree 48).
- Generation witness (P0, 40 greedy tokens): Aesir text == llama.cpp text, token-identical: " Paris.\n\nThat is correct. **Paris** is the capital and most populous city of France. It is located in the north-central part of the country along the Seine River and is a major global" (full text + IDs in q35-3b-v2-gen.log and q35-3b-comp-gen.txt).
- Batched vs per-token on the real file (P3, one chunk): next token identical (271); s_data max_abs_diff 0.00400, final-logits 0.015625 — f16 batching-rounding class (fixture F1), and ~6x tighter than the pre-fix run (0.0235 / 0.0890).
- Speeds (honest): Aesir resident CPU ~2.2 tok/s teacher-forcing incl. per-invocation load (P3: 59 positions in 29.1 s wall); llama.cpp ~2.7 tok/s equivalent (198 positions + 40 gen in 87.3 s, 28 threads). Peaks (time -v max RSS): comparator 28,236,480 KB; Aesir grade runs ~31.0 GB (P3 31,004,252 KB), gen 31.3 GB — file pages + pool, well inside the 110G fence. Units: q35-3b-comp (96G), q35-3b-aesir2 + q35-3b-rerun (110G); systemd MemoryPeak was not populated for these units ([not set]), so the time -v RSS figures are the recorded peaks.
- Load path: RESIDENT for every Aesir run above (mode=q8_0_resident, 498 large tensors, printed per run).

## U1 arbitration — settled items
- q/k repeat order: TILED (vh % groups). WAS the defect; fixed in inference.mojo (both paths).
- dt softplus/bias order, decay exp(a*dt) applied to whole state before delta, delta vs decayed state, readout from updated state: all match ggml exactly (source audit).
- 1/sqrt(d_state): ggml applies it at readout; Aesir likewise; linear in q, placement-invariant. SETTLED, no change.
- L2 norm: ggml gdn form reduces to x/sqrt(sum x^2 + eps), eps = file's 1e-6 == Aesir's. SETTLED.
- rope dimension_sections [11,11,10,0]: NOT a divergence for single-axis TEXT positions 0..~60 — the grade matches the oracle at rank 1 on 197/198 positions with Aesir's plain partial-neox over 64 dims, so whatever llama.cpp's sectioned rope does for text reduces to the same rotations here. NAMED RISK for Q35-4b: re-witness at serve context lengths (thousands of positions) and never for multimodal position axes (out of scope for this arch's text serve).

## Regression disposition (all rebuilt from the fixed tree)
- Q35-1 loader ALL PASS; Q35-2 registry ALL PASS; Q35-4a session ALL PASS; ripple ALL PASS; full engine compile exit 0.
- Q35-3a forward: ALL PASS. Its printed greedy changed (679 194 893 673 322 687 585 758 136 104 316 224 916 54 103 47) — expected: the sequence is a recorded outcome of the semantics, and the semantics were corrected; the test's assertions (determinism, geometry, state equality) are untouched and pass.
- Q35-3r resident: initially FAILED at (r2) — its hard-coded banked greedy (1019 675 ...) was recorded under the defective mapping. REPAIRED IN SLICE: the expected sequence in test_qwen35_resident_q35_3r.mojo was re-derived from the corrected Q35-3a run and updated with a Q35-3b citation comment; test then ALL PASS (r1-r7). This is the one deliberate expectation change in the slice; it is documented here and in the test source.
- A119 battery honesty: core/qwen_battery_a119.mojo qwen_smoke_status(qwen35)=LOAD_FAIL_NAMED_CAUSE was NOT changed. Reason: the function is explicitly A-048's FILED HISTORICAL smoke account ("as attested in the tree", fixture-era, named cause = incomplete SSM metadata in synthetic fixtures) — rewriting it would falsify a banked historical record, and it asserts nothing about the current engine. Named for Q35-7 (matrix owner): add a successor attestation row for the Q35-3b real-file grade rather than editing A-048's account. The function and its test remain mutually consistent; nothing is silently failing.

## Named risks for Q35-4b
- R1: rope sections re-witness at serve-length contexts (see U1 above).
- R2: serve-path sampling defaults differ from this grade's raw greedy (repetition_penalty 1.1 default in forward_pass_qwen35 vs 1.0 used here via GenerationConfig in the driver) — 4b should grade the SERVE path's own defaults, not assume the driver grade transfers.
- R3: f16 batched-prefill rounding on the real shape (0.0156 logits max) — inside band here, but prefix-reuse/snapshot equality claims (Q35-5) must keep using same-path seeds at serve scale.
- R4: Aesir CPU throughput ~2.2 tok/s at 27B Q8_0 — serve latency expectations for 4b must be set from this number, not fixture rates.
