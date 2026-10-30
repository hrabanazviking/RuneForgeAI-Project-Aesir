# Model Wave — Cloud Hypervisor EPYC (VM, CPU)

Campaign (2026-10-27/28, commissioned by Volmarr): baseline-test all nine
models on the wave list, per quant matrix; fix and tune Aesir so each model
runs its best; re-test; document and ship. Baseline engine = remote main
`3d819147` (rounds 1–2: threading, batched prefill, VNNI study). Machine:
Cloud Hypervisor guest, AMD EPYC 9D64 (AVX-512 incl. BF16+VNNI), 2 vCPU,
~8 GB RAM, no GPU, 200 GB disk.

Method: greedy decoding; the canonical Aurelia battery (t1–t4) rendered in
each model's own chat format (read from its own GGUF template); oracle =
llama.cpp on the same GGUF (greedy, `-c 2048`) with identical-prefix
measurement, plus peaked short probes and llama-tokenize parity. Walls
include model load. Box contention during the campaign was heavy (parallel
campaign lines sharing the disk), so walls are comparative, not absolute;
correctness verdicts and same-probe before/after pairs are the load-bearing
results. Full per-model evidence lives in the campaign workspace
(`~/workspace/model-tests/wave/<model>/RESULTS.md`).

## Engine changes made by the wave

1. **Decode-once fast GEMM for kinds 10/11/13 (Q2_K/Q3_K/Q5_K).**
   `_gemm_k_fast` covered only Q4_K/Q6_K; the other K-quants fell to a
   scalar path that re-decoded every weight per activation row (~600 s for
   a 15-token Q5_K probe). All kinds 10–14 now take the fast path with
   per-kind block decoders mirroring `packed_value()` exactly; VNNI stays
   gated to kinds 12/14 and off by default (round-2 finding). SmolLM2
   Q5_K_M probe: ~600 s → 10.55 s, same exact answer.

2. **Q8_0 GEMM: threading, then decode-once SIMD fast path** (crown work
   for Coder-3B). `gemm_q8_0` was a naive serial triple loop. Step 1:
   partitioned across threads via `par_for`, per-element arithmetic
   unchanged (bit-identical). Step 2: a decode-once fast range — Q8_0
   blocks decode once into F32 scratch, then W=16 SIMD dots (lane-grouped
   sums; final-rounding differences only, the accepted fast-path class;
   the serial range remains as reference). Crown probe, identical output
   at every stage: 776.88 s → 455.24 s → **269.61 s (2.88×)**.

3. **IQ (imatrix) formats — loader, decoders, and two defect fixes.**
   Phases 1–2: the loader admits IQ1_S/IQ2_XXS/IQ2_XS/IQ2_S/IQ3_XXS/IQ3_S
   (byte geometry + type map) and the grid decoders land. Ground truth:
   all IQ super-blocks hold 256 values; sizes IQ1_S 50, IQ2_XXS 66,
   IQ2_XS 74, IQ2_S 82, IQ3_XXS 98, IQ3_S 110 bytes. **Dequantization is
   bit-exact vs ggml's own CPU backend**, element-level, including a
   100M-element Q5_K embedding (max diff 0.0); engine GEMM checksums match
   gguf-py numpy on all 117 IQ1_S tensors of the test file.
   Phase 3: the merged build mis-generated on IQ files (EOS loops) while
   the identical source in the IQ-branch build behaved — root cause: the
   IQ codebook grid lived in a stack `InlineArray` whose pointer escaped
   via `unsafe_origin_cast`, and this toolchain's liveness analysis
   reused the storage mid-call depending on codegen layout. Fix: the grid
   is heap-allocated via `@no_inline iq_grid_alloc(kind)` and freed by
   the caller after the row loop.
   Phase 4: IQ-quantized *embeddings* collapsed every prompt to `<unk>` —
   `_embed_token_into` dispatched only Q8_0 and kinds 10–14 and sent
   every other quantized format through the Q4_0 block decoder (wrong
   layout and wrong row stride). Fix: an IQ branch decoding via
   `dequantize_iq_block` over the heap grid; the Q4_0 branch now matches
   Q4_0 only and any other quantized format raises. Regression test
   `test_iq_embedding_lookup` added. (A suspected Q4_K scale/min unpack
   defect was investigated byte-by-byte against ggml's
   `get_scale_min_k4` and **cleared** — no such defect exists.)

4. **qwen3 architecture support.** qwen3 fell through to interleaved
   (GPT-J) RoPE; the `TransformerBlock` rope gate now includes qwen3
   (NeoX split-half pairing, like qwen2), and the loader's no-BOS gate
   adds qwen3. Suspects cleared by measurement: config (key_length 128),
   QK-norm (present, applied per-head pre-RoPE in llama.cpp order), GQA
   mapping, tokenizer counts (176 = 176).

5. **GGUF robustness for gemma4 files.** (a) Array-valued numeric
   metadata: gemma4 stores per-layer `feed_forward_length` as an
   ARRAY(INT32), which the reader rejected; arrays whose element type
   matches the expected scalar type now collapse to element 0 for the
   flat config (wrong types still raise). (b) BF16 tensors (ggml type
   30) now convert through the pool to f16, like F32 tensors.

## Crown verdicts

- **Qwen2.5-Coder-3B Q8_0 — CORRECT, engine optimized 2.88×** (above).
  Full battery on the fast engine: 690.69/881.21/652.02/791.43 s,
  RSS 3.78 GB, clean structured JSON on all four legs. No direct llama
  oracle for this quant (the raw file left the disk before the oracle
  pass; re-downloading 3.3 GB solely for it was not judged worthwhile) —
  correctness rests on the exact probe at every optimization stage,
  battery coherence, and the oracle-proven Q4_K_M/Q5_K_M/Q6_K family on
  the same model.
- **Qwen2.5-Coder-7B Q4_K_M — CORRECT.** Peaked probe "2+2 is 4." exact;
  battery 225.51/480.50/160.92/201.10 s, RSS 5.15 GB; oracle agreement up
  to the established leading-```json fence class. The crown needed no new
  engine work beyond the wave platform.
- **L3-8B-Stheno Q3_K_M — CORRECT.** Battery 220.38/232.19/193.47/
  319.05 s, RSS 4.76 GB, clean structured JSON; oracle prefixes t1 88,
  t2 42 chars (then a near-tie word flip) — long agreement for 8B at
  3 bits, carried by the new kind-11 fast path.

## Per-model results

### SmolLM2-1.7B-Instruct-heretic-i1 (llama) — DONE
Tokenizer parity proven (184 vs 185 = trailing-newline convention).
Q4_K_M CORRECT (48.63/54.06/42.28/50.49 s, RSS 2.60 GB; oracle prefixes
130/50/117/45). Q6_K CORRECT (72.34/99.74/55.56/99.62, RSS 2.94).
Q5_K_M CORRECT on the fast path (44.26/56.55/48.26/56.89, RSS 2.77).
Q3_K_M CORRECT on the fast path (87.65/104.58/110.95/65.37, RSS 2.42;
scalar baseline probe 856.29 s, also correct). IQ2_M CORRECT after the
IQ work (190.44/219.51/167.98/148.30, RSS 2.18). IQ1_S CORRECT-as-faithful:
structured 1-bit-class output, generating freely (223.86/209.59/285.38/
232.28, RSS 1.99). Note: llama.cpp RAW is itself incoherent on this
IQ1_S file untemplated (its first-token top-5 spans 0.63 logits); the
"2+2 is 4." form exists only under llama-cli's templated mode, which
injects a default system prompt — a different input. Shipped-engine
baselines were a loader error (IQ1_S) and "unsupported GGML tensor
type 22" (IQ2_M).

### Oprius-3.1-1.1B (llama) — DONE
All five K quants CORRECT-with-caveat: coherent on-topic prose on both
engines; the model ignores the battery's JSON-only instruction (its own
limit, identical on llama.cpp). Streams diverge from token ~1–2
(prefixes 0–24 chars) — proven diagnosis: identical prompt token counts
(213 = 213), peaked probes exact on both engines, llama thread-count
stable → cross-engine f16 epsilon flips on a flat distribution, not an
engine defect. Walls (contended): Q4_K_M 127.18/213.62/60.86/97.87
(RSS 0.74 GB); Q6_K 103.07/124.31/48.69/87.29 (0.96); Q5_K_M 115.42/
142.18/109.84/124.97 (0.85); Q3_K_M 105.94/115.51/84.19/136.01 (0.64);
Q2_K 65.13/121.87/89.60/97.30 (0.53; 2-bit degradation on both engines).

### Oprius-3.1-1.1B-i1 (llama; the size-diversity case) — DONE
Same base model through the IQ line; size span IQ1_S 270 MB → Q6_K
903 MB. K quants behave as the sibling (coherent prose, near-tie class):
Q4_K_M 230.25/216.04/192.76/245.39 (RSS 0.75 GB); Q6_K 323.66/561.33/
120.20/145.57 (0.95); Q5_K_M 91.08/214.58/209.04/220.49 (0.85); Q3_K_M
184.77/276.55/270.28/216.27 (0.64); Q2_K 300.91/293.31/136.63/160.91
(0.54). **IQ2_M is the phase-4 proof**: its `token_embd.weight` is IQ3_S;
pre-fix all four battery legs emitted `<unk>`; post-fix 120.66/119.70/
108.31/113.16 s, RSS 0.50 GB, coherent prose, with the llama oracle
coherent in the same family on the identical file+prompt. IQ1_S:
68.57/124.35/73.04/118.58 s, RSS 0.38 GB, 1-bit-class garbled prose
(its embedding is Q2_K — never in the phase-4 trap).

### Qwen2.5-Coder-3B-Instruct-heretic (qwen2) — DONE
Q4_K_M CORRECT (211.23/263.04/164.09/242.64 s contended, RSS 2.49 GB;
t1 oracle prefix 47 then a synonym near-tie; t2 fence class). Q8_0 crown:
see above. Q5_K_M CORRECT (137.92/128.51/113.89/80.87, RSS 2.78; oracle
prefixes 140/132). Q6_K CORRECT (148.64/163.27/151.61/152.54, RSS 3.08;
direct oracle comparison was environment-blocked by repeated contention
kills of the oracle process; the kind-14 path is oracle-proven
elsewhere). Q3_K_M: the FILE is degenerate on both engines (Aesir
semi-structured, llama brace/whitespace soup; both engines emit only
blank lines on the peaked probe) — the kind-11 decoder itself is proven
on SmolLM2. Q2_K: ENGINE FAITHFUL by a decisive test — Aesir and
llama.cpp fall into the **same** garbage attractor (dominant tokens
"program"/"demon") on the identical prompt; the file is wrecked at
2 bits everywhere. The repo offers no IQ2_M/IQ1_S for this model.

### Qwen2.5-Coder-7B-Instruct-heretic (qwen2) — DONE except Q6_K battery
Q4_K_M crown CORRECT (above). Q3_K_M CORRECT (200.58/203.05/171.93/
175.68, RSS 4.39). Q5_K_M CORRECT (306.73/282.96/221.36/238.80,
RSS 5.80). Q2_K CORRECT — holds structure at 7B, unlike the 3B file
(193.74/227.65/175.00/183.51, RSS 3.68). Q6_K CORRECT on the peaked
probe ("2+2 is 4." exact, RSS ~5.6 GB in flight — it fits); its full
battery was killed once by an IO stall under download contention and is
completed in the final sweep (see gaps).

### L3-8B-Stheno-v3.2 (llama) — crown DONE; Q5_K_M/Q2_K/Q6_K in the final sweep
Q3_K_M crown CORRECT (above). Q4_K_M CORRECT (562.92/954.73/159.29/
170.49 s — the first two legs in a heavy stall window — RSS 5.54 GB,
clean JSON). IQ2_M: t1 748.25 s, t2 810.45 s, RSS 3.73 GB — structured
JSON openings with 2-bit-class token corruption deeper in. Q5_K_M and
Q2_K batteries were re-run in the final sweep after an earlier attempt's
runs were lost to chain kills under contention (their timings are
recorded in the per-model RESULTS file; no numbers are claimed here
that are not on disk there). Chat format note: Stheno's own template
puts two spaces after `<|end_header_id|>`; battery prompts were rendered
exactly per its GGUF template.

### Ministral-3-3B-Qwen3.8-Max-Reasoning-Distilled-i1 (mistral3) — DONE except Q4_K_M battery
First mistral3 model on the platform; YaRN rope (factor 16). Its own
template format: `[SYSTEM_PROMPT]{sys}[/SYSTEM_PROMPT][INST]{user}[/INST]`.
Tokenizer parity exact (battery t1 = 174 tokens on both engines). Aesir
sizes the runtime context from the file (262144), so RSS runs ~1.2–1.6 GB
above file size on every quant. Q6_K CORRECT (t2 1048.91, t3 232.42,
t4 169.09 s; t1 OOM-killed under campaign contention at RSS 4.04 GB —
environment, not a verdict; RSS 4.43 GB). Q5_K_M CORRECT (135.10/372.14/
79.25/92.62, RSS 4.10). Q3_K_M CORRECT (97.89/109.11/87.12/98.21,
RSS 3.45). Q2_K CORRECT and notably robust at 2 bits (100.05/113.15/
92.35/96.33, RSS 3.13). IQ2_M CORRECT (369.76/346.38/328.32/339.74,
RSS 2.99). IQ1_S 1-bit class (319.90/346.91/324.94/178.25, RSS 2.64 —
keeps the JSON schema shape with corrupted tokens). Q4_K_M: peaked probe
CORRECT ("2 + 2 = 4", 95.65 s contended, RSS 3.77 GB); its full battery
was killed once at ~16 min under peak contention and is completed in the
final sweep (see gaps). The IQ files' embedding is Q5_K — never in the
phase-4 trap.

### zen-4b-i1 (qwen3) — FIXED; residual "degeneration" proven NOT an engine defect
Baseline: degenerate loops on every prompt (", and, and…"), oracle
clean. Root cause #1 (RoPE variant) FIXED (change 4 above): short
ChatML probe is oracle-exact. Battery t1 (176 tokens) still degenerates
on Q4_K_M (136.50 s) and Q6_K (205.88/205.96/154.66/202.49 s, RSS
5.06 GB). Bisection evidence: tokenization byte-identical to
llama-tokenize; prefill chunking exonerated (`AESIR_PREFILL_BATCH=1`
identical); sampling at temperature 0.7 on a failing 22-token prompt is
coherent (the state is healthy there; greedy choice derails), while the
176-token prompt degrades even sampled. **RESOLUTION (post-ship
addendum, 2026-10-28): a dedicated phase-5 investigation proved there
is no second engine defect.** Run raw (libllama free-running, identical
input), llama.cpp itself produces the same trajectory token-for-token —
sys3: "\n\tNdrFc\n\n\tNdrFc\n\nThe sum of 2 and 2 is 4" (ids 198 70564
271 70564 271 785 …), identical to Aesir; teacher forcing agrees with
the engine's argmax at 27/28 steps across six prompts. The model's
first generated position is a flat near-tie band (sys3: 70564 at 9.945
vs runner-up 9.835), so greedy raw-prompt behavior is the model's own;
the campaign's "oracle clean" references came from llama-cli
--single-turn, which re-renders the input through the GGUF chat
template — a different prompt than the raw ChatML Aesir receives. The
f16-logits hypothesis recorded during the campaign is withdrawn and
the f32-logits change is NOT to be landed. All seven quants are
registered; their battery readings stand as measured, re-read under
this resolution: Aesir is faithful on this model. (Evidence:
`~/workspace/model-tests/wave/z5-worker/` and the phase-5 section of
the IQ worker's report.)

### gemma-4-E2B-it-heretic-v1 (gemma4) — generation NOT PROVEN on CPU
Architecture recon (from the blob): 35 layers, hidden 1536, 8q/1kv
heads, dual head dims (512 global / 256 sliding-window), per-layer FFN
sizes and sliding-window pattern (metadata arrays), shared-KV layers,
per-layer input embeddings (256/layer; the projection tensor is the
file's single BF16 tensor), final logit softcapping, vocab 262144.
The repo's gemma4 support is a dedicated CUDA session that raises
"A compatible NVIDIA CUDA device is required; no CPU fallback" — by
design — and this host has no GPU; the generic CPU block cannot express
shared-KV layers or per-layer embeddings. Landed progress (change 5):
the file now loads through tensor mapping; generation stops at the
generic path's "missing required tensor: blk.15.attn_k.weight" — layer
15 is a shared-KV layer with no K/V tensors of its own, i.e. exactly
the architecture gap. Q4_K_M is registered (`cd4feac73d7e`); no
generation verdict is claimed for any quant. A CPU gemma4 forward is
the model's open requirement.

## Suites on the final tree

- `test_cli`: **green** (rc=0, 7 PASS, run from the repo root with the
  hailbru include path).
- `test_gguf_metadata_types`: **green** (17 PASS, no failures).
- `test_inference`: does not build on this CPU-only VM — a pre-existing
  condition verified identical on base main `3d819147`, and documented
  in the repo's own DEVLOG ("test_inference.mojo needs a GPU"; the
  aggregate runner hits the stdlib GPU-arch constraint via
  cuda_sampling.mojo). The wave's inference-path changes are covered
  instead by the focused suites above, the IQ workers' branch suites
  (extreme quants + the phase-4 embedding regression test), and several
  hundred end-to-end generation runs on the final binary.

## Honest gaps / NOT PROVEN

- Zen root cause #2: CLOSED post-ship — proven not an engine defect
  (raw-oracle token parity; see the Zen section's resolution addendum).
- Gemma-4 generation on CPU: NOT PROVEN (architecture work required;
  CUDA-only session by design).
- IQ2_XS / IQ3_XXS: implemented and fixture-verified; no end-to-end
  model file exists in the wave set for them.
- IQ embedding branch: end-to-end proven for IQ3_S (+ IQ2_S unit
  fixture); other IQ embedding kinds not proven end-to-end.
- `mean_pool_token_embeddings` (the RAG facade in
  `loader/corpus_ingestion.mojo`, not the generation path) reads
  embedding rows through `RuneTensor.get` and is likewise not
  format-aware for quantized tables — flagged, not fixed (out of the
  generation scope).
- Coder-3B Q8_0 has no direct llama oracle (see crown note); Coder-3B
  Q6_K's direct oracle comparison was environment-blocked.
- Final-sweep completions: Coder-7B Q6_K battery, Ministral Q4_K_M
  battery, Stheno Q5_K_M/Q2_K/Q6_K legs — run on the final binary; their
  disk-verified timings are recorded in the per-model RESULTS files.
- Files offered by the repos but outside the brief's matrix (Oprius
  IQ4_XS, SmolLM2 IQ3_*) were not tested.
- Wall-clock numbers throughout were measured under heavy shared-box
  contention (some legs IO-stalled to ~10–20% CPU duty); treat them as
  comparative. Correctness verdicts are contention-independent.

---

## Part II continuation — laptop-line re-tests, engine gains, and courts (2026-10-29/30, roadmap S-025–S-048)

This section completes the campaign record for Part II of the 204-slice
roadmap (slices S-025–S-048). It does not replace or revise the wave
record above; it records what was re-measured, fixed, and adjudicated
after the original wave shipped. Per-slice evidence lives in the
campaign workspace: `~/workspace/model-tests/ROADMAP_204_STATE.md`
(Part II entries), `~/workspace/model-tests/wave/S045_MEMORY_TABLE.md`,
`~/workspace/model-tests/wave/S047_LAPTOP_SWEEP_TABLE.md`,
`~/workspace/model-tests/wave/S048_DIVERGENCE_COURT.md`, and the
per-family `RESULTS.md` files under `~/workspace/model-tests/wave/*/`
(the S-0xx sections cited per family below).

**Placement — read this first.** Every Part II re-test in S-026–S-044
ran on the laptop line (purplelongship, the Zen 2 / RTX 2060 Max-Q
laptop) on **laptop CPU only, VRAM 1 MiB throughout, with no GPU
claim**. The only GPU/spill proof in the campaign record remains the
S-011 Llama-3 spill foundation (gpu_layers=31/32, token-identical to
whole-GPU runs, VRAM 4,746 MiB), which is a spill foundation proof,
not a wave-family placement. Comparator discipline from S-029 onward:
ggml **CPU comparator only**, near-tie band, oracle backend recorded
per row (tf_oracle / fr_oracle, plus the BOS-controlled fr oracle for
Gemma-4). Under Volmarr's 2026-10-29 machine-decoupling and
laptop-sweeps rulings, the size/quantisation-rung sweeps live on the
laptop; the VM line runs only work that genuinely needs the VM.

### Engine changes banked to main in Part II

Five engine changes landed on main during Part II, each under a hard
numerics gate (generated ids bit-identical to the crown trajectories
and tf-CPU grades reproduced exactly, unless the change itself was the
subject of the gate):

- **S-030 — IQ SIMD decode (`7859deea`, banked by fast-forward).**
  Root cause: `dequantize_iq_block` decoded all 256 lanes scalar while
  K kinds 10/11/13 decode width-16 SIMD; in single-row GEMMs that
  scalar decode was ~90% of IQ cost (IQ2_M decode ≈2.02 s/tok vs
  ≈0.24 s/tok for K kinds). Fix: SIMD lane decode for all six IQ kinds
  in `extreme_quantization.mojo`, preserving the exact f32 polynomial
  grid values, arithmetic signs, and (coef·gv)·sign order. Numerics
  proven unchanged three ways (SIMD decode bit-identical vs the scalar
  oracle, repo GEMM fixtures, free-running ids bit-identical with tf
  grades reproduced). Re-measured on Zen IQ2_M: sys3 36.51→12.08 s
  (3.02×), t1 125.40→46.52 s (2.70×); IQ1_S sys3 28.31→10.72 s;
  Q4_K_M control unchanged (9.19→9.18 s).
- **S-033 — Prefill chunk cap 32 → 256 (`57218795`).** Each prefill
  chunk re-decodes the weight blocks, so the old cap 32 repeated decode
  work (7 chunks for a 213-token prompt). At cap 256, Oprius-i1 t1
  walls fell ~9–10% on every K rung and 14.5% on IQ1_S, plateauing at
  whole-prompt coverage; ids bit-identical and tf-CPU grades
  reproduced exactly. `_prefill_batch_cap` default changed in
  `aesir_engine/aesir.mojo`; workspace clamp unchanged.
- **S-039 — Gemma-4 generic-CPU forward (`482f04d6`).** The wave left
  Gemma-4 generation NOT PROVEN on CPU (CUDA-only session by design;
  see the Gemma-4 section above). S-039 built the missing forward:
  gemma4 config parsing (SWA head dim/rope base, shared_kv_layers,
  per-layer input length, sliding-window pattern), relational tensor
  validation (541 tensors validate; the `blk.15.attn_k.weight` wall is
  gone), a gemma4 tokenizer mode, and `Gemma4Block` +
  `forward_pass_gemma4` mirroring the CUDA session (shared-KV under
  owning layers 13/14, full PLE branch, layer_output_scale, global
  RoPE). Q4_K_M PROVEN on laptop CPU (see the Gemma-4 verdict below).
- **S-041 — Batched Gemma-4 prefill (`68ba6d23`, banked by
  fast-forward via the GitHub API ref update after plain `git push`
  was spuriously rejected; server-enforced fast-forward, ls-remote
  verified).** Profile: prefill was ≈92% of the long-prompt wall under
  the per-token forward. Fix: `Gemma4Block.forward_batched` +
  `forward_pass_gemma4_batched` + `_gemma4_ple_batched`. Hard gate
  PASSED — every run bit-identical to the S-039/S-040 crown ids.
  Q4_K_M long (693 tok) 174.76→66.20 s (2.64×); Phase C long speedups
  2.69× (Q4_K_M) / 2.95× (Q6_K) / 3.70× (IQ2_M), tf grades reproducing
  S-040 exactly.
- **S-042 — Kind-11 (Q3_K) coefficient/vector hoist (`b4441348`,
  banked to main at S-043; origin/main at the close of Part II).**
  Profile found two pockets in the `kind == 11` branch of
  `_gemm_k_fast_range`: per-sub-block scale derivation with div/mod
  and repeated scalar byte loads, and packed-vector reloads (32 vector
  loads for 6 distinct vectors). Fix: all 16 sub-block coefficients
  computed straight-line from the 12 header bytes and the 6 distinct
  packed vectors hoisted before the decode loop in `compute.mojo`
  (+51/−11); per-element arithmetic identical, so the decoded scratch
  row is bit-identical by construction. Gains: Stheno Q3_K_M t1
  49.61→48.95 s, t2 63.32→60.91 s; Coder-3B Q3_K_M t1 25.29→24.14 s.
  Hard gate PASSED (ids bit-identical to the S-037 crown; tf-CPU
  191/200 rank-0, 195/200 ≤2, reproducing S-037/S-038 exactly).

### Per-family verdicts from the laptop line (S-025–S-044)

- **zen-4b-i1 (qwen3) — S-025/S-026/S-029/S-030/S-031.** S-025 DONE
  in-wave: qwen3 support shipped (NeoX RoPE + no-BOS); the phase-5
  closure proved raw-oracle token parity for Q4_K_M and closed root
  cause #2 (no engine defect; the "oracle clean" references were
  template-rendered prompts). S-026 laptop round: baseline PROVEN for
  6/7 rungs — tf_oracle rank-0: Q4_K_M 16/16 + 48/48, Q6_K 16/16 +
  48/48, Q5_K_M 16/16 + 47/48, Q3_K_M 16/16 + 47/48, Q2_K 15/16 +
  46/48, IQ2_M 16/16 + 47/48 (all misses near-tie, gaps ≤0.759).
  IQ1_S NOT PROVEN (see Honest gaps). S-031 re-confirmed IQ2_M PROVEN
  and IQ1_S NOT PROVEN by construction on the integrated tree.
- **SmolLM2-1.7B-heretic-i1 — S-031.** IQ2_M PROVEN (tf-CPU 16/16 +
  47/48, miss rank 1 / gap 0.230; fr-CPU identical 16/16; ids
  bit-identical to the wave fixed build; t1 22.02 s, RSS 2,186 MB).
  IQ1_S: ids bit-identical to the proven fixed build, but token-exact
  parity NOT PROVEN by construction (tf-CPU 4/16 + 35/48; S-029
  verdict confirmed). The stale OPEN DEFECT paragraph in the family
  RESULTS.md is marked SUPERSEDED.
- **Oprius-3.1-1.1B-i1 — S-032/S-033/S-043/S-047.** Full ladder
  re-measured (S-032): Q4_K_M control PROVEN (tf-t1 48/48 rank-0,
  fr-t1 bit-identical), Q6_K PROVEN (47/48), Q5_K_M PROVEN (47/48),
  Q3_K_M PROVEN (48/48 rank-0), Q2_K PROVEN engine-faithful (S-016
  class), IQ2_M PROVEN (43/48 rank-0, 48/48 ≤2). IQ1_S NOT PROVEN by
  construction, with one flagged anomaly carried to the divergence
  court (D-03, below). S-033 tuning landed the prefill-cap gain
  (above); S-043's PMW sweep and S-047's spot re-verification both
  reproduced the crown ids exactly.
- **Qwen2.5-Coder-7B-heretic — S-034/S-035/S-036/S-044/S-045.**
  See the crown baselines section below. Matrix verdicts (S-035):
  Q6_K, Q5_K_M, Q3_K_M PROVEN (each tf-CPU 199/199 rank-0); Q2_K
  PROVEN engine-faithful; Q8_0 PROVEN correct but REFUTED on speed
  (see Honest gaps).
- **L3-8B-Stheno-v3.2 — S-037/S-038/S-042/S-044/S-045.** Full ladder
  re-measured (S-037): Q3_K_M crown PROVEN, Q4_K_M PROVEN, Q6_K
  PROVEN (first generation verdict; the wave era was
  registration-blocked — the truncated-catalog hazard `9748cae99f63`
  is RESOLVED in the laptop store, full pin `0f0424440d11`),
  Q5_K_M PROVEN, Q2_K PROVEN engine-faithful class, IQ2_M PROVEN.
  tf-CPU rank-0 totals of 200: Q3 191, Q4 189, Q6 189, Q5 188,
  Q2 190, IQ2_M 189; rank ≤2 = 195/200 for every rung (the single
  beyond-band step in every leg is the step-0 prompt-boundary
  comparator effect, D-05 below). Walls fell sharply vs the contended
  wave VM (e.g. Q3_K_M t1 220.38 s wave → ~50 s class laptop;
  IQ2_M t1 748.25 s → 60.71 s).
- **gemma-4-E2B-it-heretic-v1 — S-039/S-040/S-041.** The wave's open
  requirement is closed on the laptop line: the S-039 CPU forward is
  PROVEN at Q4_K_M (probe tf-CPU 10/11 rank-0, fr-BOS bit-identical +
  EOS; mid 111 tok tf 47/48, fr-BOS identical 48/48; long 693 tok,
  beyond the 512 window, tf 32/32 rank-0, fr-BOS identical 32/32).
  S-040 full matrix: Q6_K PROVEN, Q5_K_M PROVEN, Q3_K_M PROVEN,
  IQ2_M PROVEN; Q2_K token-exact parity NOT PROVEN (2-bit degraded
  class, no ≤2 band measured); IQ1_S NOT PROVEN by construction
  (S-029 confirmed on a third family). S-041 batched prefill then cut
  long walls by 2.6–3.7× bit-identically (above). VM completion of
  the S-039 forward is NOT PROVEN (see Honest gaps).
- **Ministral-3-3B-i1 — S-027/S-028 (record audits only).** The
  residual re-check resolved as follows: YaRN appears only as GGUF
  metadata (factor 16, orig ctx 16384) and every battery prompt is
  ~174–230 tokens, so YaRN-at-length was never verified. Short-length
  baseline correctness stands as recorded in-wave; the laptop line
  did not re-run Ministral in S-026–S-044 (see Honest gaps).
- **Oprius-3.1-1.1B (static, non-i1) — no laptop re-test** in
  S-026–S-044; its wave verdicts are VM-only and stand as recorded
  above. The laptop ladder belongs to Oprius-i1, a different file set.

### Crown baselines and tuning outcomes (S-034–S-038)

- **S-034 — Coder-7B crown baseline.** All 5 declared rungs'
  sha256 verified against HF LFS pins on the laptop store. Crown
  Q4_K_M re-measured: probe + battery t1–t4 all bit-identical to the
  wave-era VM crown ids; tf-CPU 199/199 rank-0; walls probe 7.74 s,
  t1 40.62, t2 50.58, t3 41.37, t4 43.61 s (uncontended laptop, vs
  97.13–480.50 s contended wave); RSS peak 5,168 MB.
- **S-035 — Coder-7B full declared matrix** (verdicts above). Q8_0
  walls were ~25× the K rungs (probe 130.62 s; t1 1167.20 s;
  t2 1580.54 s; t3 1139.23 s; t4 1234.00 s; RSS 8,158 MB) despite
  perfect correctness grades — the speed defect carried to S-150.
- **S-036 — Coder-7B crown tuning: NO GAIN FOUND, honestly, gate
  passed.** Profile: fixed floor ≈3.1 s, decode slope ≈0.465 s/tok
  (weight-streaming-bound, ~55% of the t1 wall); fast-path census
  clean. Sweeps: default 16 threads best; PAR_MIN_WORK flat-to-worse;
  prefill cap 128/256/512 indistinguishable (7B geometry does not want
  a different cap — the S-033 tax is amortized at ≥128-row chunks);
  VNNI a no-op on Zen 2. Closing battery within ~3% of S-034, 22/22
  runs bit-identical, tf-CPU 199/199. No engine code changed.
- **S-037 — Stheno ladder baseline** (verdicts above).
- **S-038 — Stheno crown tuning: NO GAIN FOUND, honestly, gate
  passed.** Threads (default 16 best), PAR_MIN_WORK, prefill cap and
  VNNI sweeps all flat-to-worse; every run IDS_MATCH_CROWN=True;
  closing battery within ~2% of S-037 with tf-CPU grades reproduced
  exactly (191/200 rank-0, 195/200 ≤2). No engine code changed.

### Coverage and no-gain programs (S-043/S-044)

- **S-043 — `AESIR_PAR_MIN_WORK` per-kind crossover sweep: NO PER-KIND
  GAIN.** 314 runs, all rc=0, on Oprius-i1's full ladder plus Coder-3B
  spot legs, PMW from 0 to 16M. Hard gate PASSED
  (IDS_GATE_ALL_OK=True; tf-CPU grades at default reproduce S-032
  exactly). Sub-default thresholds were consistently SLOWER (+4–8%);
  0/2M/4M flat; 16M catastrophic (+43% to +117%). Verdict: per-kind
  defaults NOT justified; the single global default 2^20 stands. No
  engine code changed.
- **S-044 — Prefill program: coverage ALREADY COMPLETE, gate
  proven.** The census (full text in the campaign workspace,
  `wave/l3-8b-stheno/s044/S044_CENSUS.md`) proves `generate()`
  dispatches batched prefill by architecture for every wave quant
  kind (generic → `forward_pass_batched`, gemma4 → the S-041 batched
  twin, qwen35 → batched twin; GEMMs dispatch per-tensor kind,
  including S-030 IQ SIMD and S-042 kind-11). No build gap; nothing
  landed. Empirical gate on long prompts, default cap vs
  `AESIR_PREFILL_BATCH=1`, all ids bit-identical: Coder-3B Q8_0 crown
  (530 tok) 1154.65 vs 1667.57 s (1.44×); Coder-7B Q4_K_M crown
  (530 tok) 76.74 vs 245.73 s (3.20×); Stheno Q3_K_M crown (516 tok)
  88.50 vs 310.28 s (3.51×). Genuine per-token-only surfaces are
  sharded multi-device (no wave model runs sharded) and the separate
  CUDA sessions.

### Memory discipline (S-045)

Consolidated table: `wave/S045_MEMORY_TABLE.md`. Method: no heavy
inference on the VM; verdicts analytic from measured laptop RSS +
GGUF size against the VM envelope (total RAM 7,935 MB, swap 0;
MemAvailable chronically <1 GB at Part II checks, so every VM run
first needs the phase-5 gate, MemAvailable >5,500 MB).

- **All three crowns FIT — PROVEN ON VM in-wave; no crown needs spill
  on memory grounds** (stated explicitly, not silently): Coder-3B
  Q8_0 (GGUF 3,285,477,024 B; laptop RSS 3,790 MB; wave VM 3.78 GB),
  Coder-7B Q4_K_M (GGUF 4,683,074,688 B; laptop 5,168–5,207 MB; wave
  VM 5.15 GB), Stheno Q3_K_M (GGUF 4,018,917,920 B; laptop
  4,765–4,776 MB; wave VM 4.76 GB). Each crown's Part-IV spill road
  is named in its RESULTS.md anyway (Coder-7B → S-143; Coder-3B →
  S-155 with S-143 as sibling proof, plus S-150 for its Q8_0 speed
  defect; Stheno → S-155 on the S-011 foundation, plus S-156
  instrumentation).
- **Coder-7B Q8_0 DOES NOT FIT**: laptop RSS 8,158 MB exceeds the
  VM's 7,935 MB total, and the GGUF alone (8,098,526,336 B) exceeds
  it too; no swap. Roads: S-150 + spill S-143/S-155–S-160.
- **Q6_K 8B-class rows are MARGINAL**: Stheno Q6_K (RSS 7,040 MB,
  leaves 895 MB; wave VM OOM-killed) and Coder-7B Q6_K (RSS
  6,521 MB; wave VM battery t1/t2 OOM-killed rc=-9). Reliable VM
  completion NOT PROVEN for either; road = S-155 spill or a gated
  S-046 re-run.
- Other primaries: Zen Q4_K_M FITS — PROVEN ON VM; Oprius-i1 Q4_K_M
  FITS — PROVEN ON VM; SmolLM2 Q4_K_M and Ministral Q4_K_M FIT on
  their wave VM rows (laptop rows NOT MEASURED — see Honest gaps);
  Gemma-4 Q4_K_M FITS analytically (laptop ≈2.70 GB) with VM
  completion NOT PROVEN.

### Final re-test sweep, laptop — cross-site agreement (S-047)

Consolidated table: `wave/S047_LAPTOP_SWEEP_TABLE.md`. It covers all
nine wave families for the rungs actually re-tested on purplelongship
in S-026–S-044, each row citing its slice and RESULTS.md section,
placement (laptop CPU, VRAM 1 MiB, no GPU claim), verdict, and
agreement with wave-era VM ids/grades where recorded. Headline:
where ids are filed on both sites they agree — Coder-7B crown and
matrix bit-identical to wave ids (S-034/S-035), SmolLM2 IQ ids
bit-identical to the wave fixed build (S-031), Coder-3B t1
bit-identical to wave-era ids (S-042/S-043); wall gaps between sites
are contention/site effects, adjudicated at D-14 below. The slice's
fresh spot re-verification on main `b4441348` PASSED: Oprius-i1
Q4_K_M peaked probe ids exactly the S-032/S-043 crown, wall 2.05 s.

### Divergence court (S-048)

Full docket: `wave/S048_DIVERGENCE_COURT.md` — **16 entries
(D-01–D-16), every cross-engine and cross-site divergence in the
sweep given a written verdict; no unexplained rows.** Summary:
9 closed as near-tie / file degeneracy / comparator artifact /
site-contention (D-02 Zen rank-65 outlier = CPU-vs-CUDA comparator
artifact; D-05 Stheno step-0 = prompt-boundary comparator effect;
D-06/D-07 Q2_K = near-tie / engine-faithful, S-016 class; D-08
Coder-3B Q3_K_M = file degeneracy on both engines; D-09 all remaining
tf misses = near-tie within band; D-10 Gemma step-0 = BOS comparator
artifact; D-12 Zen phase-5 = template-rendering comparator artifact;
D-14 cross-site walls = contention/site, ids agreeing); D-01 closed
NOT PROVEN BY CONSTRUCTION (IQ1_S; the oracle disagrees with itself);
D-13 an engine speed bug FIXED inside the sweep (IQ2_M scalar decode,
S-030); D-16 a positive no-divergence finding for the remaining rows.
Carried open with roads and re-open criteria, not hidden:

- **D-03** (Oprius-i1 IQ1_S t1 step 1 at rank 38 / gap 2.432, at a
  still-shared context step) → the S-095-pattern comparator-stability
  re-check; it re-opens as a defect if comparator-stable.
- **D-04** (Gemma-4 Q2_K; no ≤2 band measured) → the same
  S-095-pattern comparator-stability re-check, Gemma-4 vehicle.
- **D-11** (Coder-7B Q8_0 speed) → **S-150**: a proven engine defect,
  root-caused at S-036 (`gemm_q8_0`'s fast range decodes blocks with
  a scalar per-lane loop into a full-width f32 scratch, unlike the K
  kinds' width-16 SIMD super-block decode).
- D-15 reclassified Ministral YaRN from a divergence to an untested
  gate component, road S-104 (see Honest gaps).

### Honest gaps / NOT PROVEN — Part II

- **S-046 (final re-test sweep, VM) is BLOCKED-WITH-REASON and NOT
  done.** VM host memory: total 7,935 MB, swap 0, MemAvailable
  measured at 352–697 MB across Part II checks — chronically <1 GB
  against the phase-5 gate of >5,500 MB. No VM inference sweep was
  attempted in Part II, the VM-side s026 orchestrator was NOT
  relaunched (stood down under the decoupling/laptop-sweeps rulings),
  and **this record does not claim a VM final sweep happened**. The
  laptop final sweep is S-047 (above). Road: VM host memory freeing
  before any VM sweep leg. Gemma-4 VM completion is among the items
  this leaves NOT PROVEN.
- **IQ1_S token-exact parity is NOT PROVEN by construction (S-029).**
  ggml's own CPU and CUDA IQ1_S kernels disagree (sys3 step 1: forced
  ids 25 vs 4142; Aesir 510), while Q4_K_M and IQ2_M controls are
  16/16 exact in both backends; no faithful implementation can be
  token-exact against both. Confirmed on Zen, SmolLM2, Oprius-i1 and
  Gemma-4. Successor measure: IQ1_S coherence grading, road S-095.
- **Coder-7B Q8_0 speed is REFUTED (S-035)** — correctness PROVEN
  (tf-CPU 199/199, fr-CPU bit-identical), walls ~25× the K rungs.
  Proven engine defect, root cause on file (S-036); road = S-150
  (Q8_0 device path) plus CPU fast-path work. Its HF-pin verification
  was not evidenced in the S-035 driver log and is not claimed.
- **Ministral YaRN-at-length is NOT PROVEN (S-027/S-028)** — YaRN is
  GGUF metadata only in the record (factor 16, orig ctx 16384) and
  every battery prompt is ~174–230 tokens. Road = S-104 (YaRN length
  probes per rung).
- **SmolLM2 Q4_K_M and Ministral laptop rows are NOT MEASURED**
  (S-045/S-047): S-031 covered only SmolLM2's IQ rungs, and Ministral
  had no laptop run in S-026–S-044. Their VM rows stand; the laptop
  rows' road was the S-047 table, which records them as gaps rather
  than filling them.
- **Stheno Q8_0 / IQ3_M are not in the laptop store and were not
  run** (S-037). Road = Part III acquisition (S-075/S-111).
- **Gemma-4 Q2_K has no ≤2 near-tie band measured** (S-040) —
  token-exact parity NOT PROVEN, no defect proven; road = the
  comparator-stability re-check (court D-04).
- Oprius static (non-i1) has no laptop re-test at all; Coder-3B
  Q6_K/Q5_K_M/Q2_K are wave-VM only; Gemma-4's remaining rungs inherit
  the S-041 batched-prefill path as recorded coverage, without a
  per-rung re-gate. None of these is claimed as laptop-measured.

Part II closes with S-049 (this completion of the campaign record).
S-046 remains BLOCKED-WITH-REASON in parallel. Next in roadmap order:
S-050 (full suites on the wave tree; counted run green; battery
green).

---

## Part II retrospective (2026-10-30, roadmap-204 S-053)

Durable lessons from the Part II continuation (S-025..S-052), extracted under
the Forge Protocol's self-improving step. Full text:
`wave/S053_RETROSPECTIVE.md` in the campaign workspace and the "Project Aesir
wave lessons" section of the workspace AGENTS.md.

1. Raw-oracle discipline only: never judge the engine against
   `llama-cli --single-turn` (template-rendered prompts are a different
   input — the trap behind Zen's wave-era "root cause #2"). Grade by
   teacher-forcing rank + logit gap on the raw prompt; record the oracle
   backend per row; CPU engine vs CPU comparator only.
2. Comparator artifacts are a verdict class: template rendering, BOS
   rendering, backend mismatch, and prompt-boundary step-0 effects fake
   divergences in neither engine's maths (S-048 court D-02/D-05/D-10/D-12).
3. IQ1_S token-exact parity is NOT PROVEN BY CONSTRUCTION: ggml's own CPU
   and CUDA IQ1_S kernels disagree with each other (S-029); the honest
   successor is coherence grading + the near-tie band (rank ≤2, sub-logit
   gap = faithful), road S-095.
4. Scalar dequant decode dominates single-row GEMM cost: the S-030 width-16
   SIMD IQ decode (7859deea) gave ~3× with numerics proven unchanged three
   ways; batched prefill bought only ~1.4×. The same scalar pocket in
   `gemm_q8_0` is the proven Coder-7B Q8_0 speed defect (road S-150) — never
   cite Q8_0 walls as a baseline until it is fixed.
5. A visible CUDA device changes test behaviour: the counted run hangs at
   the F009 case because the CUDAGate launch neither returns nor raises on
   the RTX 2060, so the SIMD fallback never engages (S-050; commissioned to
   S-054, road = GPU line). Suites run with `CUDA_VISIBLE_DEVICES=` say so,
   and a run at VRAM 1 MiB is a CPU run and is recorded as one.
6. Launch method fakes failures: a backgrounded battery launch inherits
   SIGINT ignored and breaks interruption tests (S-050 step 22). Check the
   harness before filing a code defect.
7. Machines are decoupled (size/rung sweeps on the laptop; the VM behind
   its MemAvailable >5,500 MB gate), one heavy run at a time per box, and
   walls measured under contention are not baselines — where ids agree and
   walls differ, it is contention (D-14).
8. Trust only disk: every number from files, git objects, or catalog
   listings; every model sha256-pinned before it runs. If the wave store
   vanishes, re-fetch + re-register from the HF pins kept in the campaign
   recon directory (proven road, S-026).
9. Bank incrementally by explicit refspec with ls-remote verification, so
   the ship slice is a behind_by=0 audit, not a merge event (S-051). Every
   divergence gets a written verdict class or a named road with re-open
   criteria — no unexplained rows (S-048).
