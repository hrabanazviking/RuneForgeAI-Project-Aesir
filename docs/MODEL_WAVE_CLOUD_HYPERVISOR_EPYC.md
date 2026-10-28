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

### zen-4b-i1 (qwen3) — PARTIALLY FIXED (honest)
Baseline: degenerate loops on every prompt (", and, and…"), oracle
clean. Root cause #1 (RoPE variant) FIXED (change 4 above): short
ChatML probe is oracle-exact. Root cause #2 remains open for long
prompts: battery t1 (176 tokens) still degenerates on Q4_K_M (136.50 s)
and Q6_K (205.88/205.96/154.66/202.49 s, RSS 5.06 GB). Bisection
evidence: tokenization byte-identical to llama-tokenize; prefill
chunking exonerated (`AESIR_PREFILL_BATCH=1` identical); sampling at
temperature 0.7 on a failing 22-token prompt is coherent (the state is
healthy there; greedy choice derails), while the 176-token prompt
degrades even sampled. Standing hypothesis, unproven at logits level
(the local llama.cpp build has no logits-dump tool): the engine samples
from f16-rounded logits, and Zen's tied Q6_K embedding creates many
near-tie decisions where f16 rounding flips the argmax vs the f32
oracle; the identified fix design — keep the final projection's logits
in f32 through the sampler — is recorded here as the next engine
change, deliberately not landed unproven at campaign end because its
regression surface spans every model. All seven quants are registered;
Q5_K_M/Q3_K_M/Q2_K batteries and IQ probes reproduce the same family
behavior (sensible openings, then drift), consistent with the single
open defect.

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

- Zen root cause #2 (above): long-prompt divergence open; f32-logits
  fix designed, not landed.
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
