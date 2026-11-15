# QS-4 NOTES — Sampling parity on qwen35 (min_p + repeat_last_n)

Team: QS-4 lead seat, six Mythic Engineering roles run
sequentially in one seat (no sub-agents available at depth 2/2;
recorded per commission). Tree: ~/aesir-qs-sample, branch
yrsa/qs-sample, base 183ee901 (QS-0 + QS-3 merged). Ports:
own serve smoke on 18437 only. Heavy lock: held by QS-1 at
campaign start (OWNER.txt, claimed 2026-11-15 ~01:28 EST) —
fixture/code work proceeded; heavy items retried later.

## QS-4.1 EVIDENCE — current behavior (2026-11-15)

Verdict: BOTH parameters are SILENT NO-OPS on the qwen35 CPU
serve path. A client asking for them gets neither the behavior
nor a refusal. (The HIP session states the same scope in its
header; the serve request parser accepts min_p and validates
it, and accepts repeat_last_n via sampling options/modelfile/
Ollama surfaces — then the value dies in the session.)

### Code audit (file:line at base 183ee901)

1. aesir_engine/cli/native_serve.mojo: the generate request
   parser maps "min_p" -> with_sampling_option "min-p" into
   NativeSamplingConfig (validated [0,1]); there is NO
   "repeat_last_n" request field (unknown fields raise).
   Serve defaults (QS-0-BASELINE): min_p 0, repeat_last_n 64.
2. aesir_engine/core/sampling_config.mojo: NativeSamplingConfig
   CARRIES both fields (min_p, repeat_last_n; validated).
3. aesir_engine/qwen35_session.mojo:300 _gen_config(): builds
   GenerationConfig from temperature/top_k/top_p/
   repetition_penalty/seed ONLY. min_p is dropped;
   repeat_last_n is dropped (GenerationConfig has no such
   field at all — it cannot even be expressed downstream).
   Session header (line 82) admits it: "min_p and
   repeat_last_n have no CPU-forward counterpart and are not
   claimed." QWEN35_RESULTS.md "Honest limits" says the same.
4. aesir_engine/aesir.mojo _forward_position/_forward_batch
   qwen35 branches: pass temperature/top_k/top_p/
   repetition_penalty/seed to forward_pass_qwen35 /
   forward_pass_qwen35_batched. No min_p, no repeat_last_n.
5. aesir_engine/core/inference.mojo forward_pass_qwen35
   (~2973) and _batched (~2885): call
   core.sampler.sample_token_from_logits WITHOUT min_p
   (sampler default 0.0) and with context_tokens = the FULL
   token list (prompt + generated so far). No windowing
   exists anywhere on the CPU path: sample_token_from_logits
   has no repeat_last_n parameter at this base.
6. Repetition penalty itself IS wired (full-context):
   apply_repetition_penalty over the whole context list.

### Live fixture probe (qs-4-probe-prefix.log)

probe_qwen35_sampling_qs_4 on fixtures/qwen35_k256_q8.gguf
(QS-3 k256 fixture), Qwen35CPUSession, temp 1.0, top_k 256,
top_p 1.0, seed 42, 24 generated tokens, prompt stream 25:

- WITNESS: _gen_config().min_p under sampling.min_p=0.95
  prints 0.0 — the drop, observed directly.
- A (min_p 0.00) == B (min_p 0.95): token streams IDENTICAL
  (49 tokens) — min_p silent no-op.
- C (rep 2.5, repeat_last_n 1) == D (rep 2.5, repeat_last_n
  8192): IDENTICAL — repeat_last_n silent no-op.
- A != C: repetition_penalty changes the stream — the
  penalty is wired; only its window is missing.

## Reference semantics (parity targets)

In-tree generic sampler (core/sampler.mojo) — the sampler the
llama/gemma CPU forwards and the HIP session share:
- apply_min_p: sort desc; softmax probs over the CURRENT
  candidate set; keep prob >= min_p * max_prob (always keeps
  the top token); no-op when min_p <= 0 or >= 1. Pipeline
  position in sample_token_from_logits: suppress mask ->
  repetition penalty -> freq/presence penalties ->
  temperature -> top_k -> top_p -> min_p -> weighted draw.
- llama.cpp min_p is the same rule in ratio form (keep
  p_i >= min_p * p_max over the candidate array); the CUDA
  sampler (core/cuda_sampling.mojo sampling_merge) applies
  it on unnormalized exp((l-m)/T) values — the same keep set,
  since normalization cancels in the ratio. Parity = the
  in-tree apply_min_p keep set.
- repeat_last_n: llama.cpp penalties + in-tree CUDA sampler
  (sampling_record ring of width repeat_last_n; counts > 0
  gate the penalty): repetition/frequency/presence penalties
  consider ONLY the last repeat_last_n context tokens
  (prompt + generated so far). Window slides per token.
- Greedy note: the in-tree sampler's temp<=0 / top_k==1 fast
  path is a pure argmax (penalties and min_p do not apply) —
  existing behavior on every CPU path; QS-4 keeps it exactly
  (parity with the engine, and the teacher-forcing grade,
  which runs greedy, is untouched by construction).

## Design (QS-4.2 / QS-4.3)

Minimal shared plumbing, defaults bit-identical to today:
1. GenerationConfig gains repeat_last_n: Int = 0 appended as
   the LAST field (0 = legacy full-context; validate
   0..8192). min_p field already exists (dead until now).
2. sample_token_from_logits gains repeat_last_n: Int = 0;
   when > 0 the penalty context (repetition + freq/presence)
   is the trailing repeat_last_n tokens of context_tokens.
   Order of operations UNCHANGED (see pipeline above).
3. forward_pass_qwen35 + forward_pass_qwen35_batched gain
   min_p (default 0.0) + repeat_last_n (default 0), passed
   to the sampler. Other archs' forwards untouched (their
   dead min_p is the same defect class — named as next work,
   out of QS-4 scope; defaults keep them bit-identical).
4. AesirEngine._forward_position/_forward_batch qwen35
   branches pass gen_config.min_p / gen_config.repeat_last_n.
5. Qwen35CPUSession._gen_config() passes sampling.min_p and
   sampling.repeat_last_n. Session header updated to claim
   both. HIP session call site wired the same way (it calls
   the sampler directly) + header updated.
6. Grade safety: logit-row capture (capture_logit_row) sits
   BEFORE sampling in both qwen35 forwards; sampling changes
   cannot move logits. Defaults (min_p 0, repeat_last_n 0
   from every existing GenerationConfig caller) keep all
   existing behavior bit-identical; the session's Native-
   SamplingConfig default repeat_last_n=64 becomes real on
   the qwen35 serve path — that IS the commissioned parity
   (serve defaults governed every prior proof at rep 1.0,
   where the window is a no-op by definition: penalty == 1.0
   short-circuits before the window matters).

Tests per slice: sampler-level distribution/keep-set tests
on synthetic logit rows (deterministic seeds), session-level
fixture generation comparisons (min_p on/off and window
narrow/wide must differ in the expected direction; defaults
must reproduce the pre-fix streams bit-exactly), existing
qwen35 fixture tests re-run, teacher-forcing grade battery
re-run (fixture grade now; 27B grade when the HEAVY lock
frees).

## QS-4.2 MIN_P — implemented + proven (2026-11-15)

Changes (defaults bit-identical everywhere):
- core/inference.mojo: forward_pass_qwen35 +
  forward_pass_qwen35_batched gain min_p: Scalar[f32] = 0.0,
  passed to sample_token_from_logits (which already implements
  apply_min_p; it was simply never fed on this path).
- aesir.mojo: _forward_position/_forward_batch qwen35 branches
  pass gen_config.min_p (the GenerationConfig field existed
  and was dead on every CPU forward).
- qwen35_session._gen_config(): min_p=self.sampling.min_p.
- qwen35_hip_session: host sampler call gains min_p likewise;
  both session headers updated to claim min_p (QS-4.2) and
  keep repeat_last_n honestly unclaimed until QS-4.3.

Evidence (logs in this folder):
- qs-4-minp-test.log — test_qwen35_sampling_qs_4 ALL PASS:
  (m1) apply_min_p keep sets exact on a known ladder
  (probs .644/.237/.087/.032: min_p 0.1 keeps 3, 0.5 keeps 1,
  0 keeps 4); (m2) distribution: logits 3.0 vs 2.9 (ratio
  0.905), min_p 0.95 -> token 1 drawn 0/512 seeded draws,
  min_p 0 control -> 230/512 (expectation ~243);
  (m3) session on k256 fixture: min_p=0 stream BIT-EXACT vs
  the pre-fix QS-4.1 probe stream; min_p=0.95 stream differs;
  _gen_config().min_p witness now 0.95.
- Grade safety: qs-4-fwd-fixture.log (test_qwen35_forward_
  q35_3 ALL PASS, greedy identical), qs-4-residentk.log
  (QS-3 K-resident ALL PASS, logits diff 0.0), qs-4-test-
  inference.log (test_inference PASS, exit 0). Logit-row
  capture precedes sampling in both qwen35 forwards, so the
  teacher-forcing grade cannot move; the 27B 198-record
  grade re-run waits on the HEAVY lock (QS-2 phase) and is
  scheduled before QS-4.4 closes.

## QS-4.3 REPEAT_LAST_N — implemented + proven (2026-11-15)

Semantics matched to the reference, stated exactly:
- Window: penalties consider ONLY the last repeat_last_n
  tokens of (prompt + generated so far) — llama.cpp penalties
  sampler and the in-tree CUDA sampler's ring (sampling_
  record) both define the window this way.
- Application order: UNCHANGED in-tree CPU order — repetition
  penalty, then frequency/presence penalties (both over the
  window), then temperature, top_k, top_p, min_p, draw.
  (llama.cpp likewise applies its penalties before the
  filter chain. The CUDA sampler has no freq/presence at
  all — pre-existing divergence, not introduced here.)
- repeat_last_n = 0 in GenerationConfig / the sampler means
  the LEGACY full-context behavior, so every existing caller
  is bit-identical; the qwen35 session always passes its
  configured window (NativeSamplingConfig default 64). At
  repetition_penalty == 1.0 and freq/presence == 0 the window
  is a no-op by construction, which is why every prior serve
  proof (defaults, rep 1.0) stands unchanged.

Changes: GenerationConfig gains repeat_last_n as its LAST
field (default 0, validated 0..8192; __init__/__copyinit__/
copy() all extended in field order, so positional callers
are untouched); sample_token_from_logits gains repeat_last_n
(trailing kwarg, default 0) and slices the penalty context;
qwen35 forwards + engine branches + CPU/HIP sessions pass it
through, mirroring QS-4.2.

Evidence (qs-4-rln-test.log, ALL PASS):
- (r1) sampler window, seeded 512-draw distributions: token
  present only 100 tokens back, rep 2.0: full-context draws
  85 vs window-64 draws 251 (expectations ~90 / ~243);
  frequency 0.5: full 184 vs window 251. Both penalty kinds
  window, in the expected direction, with wide margins.
- (r2) session: _gen_config().repeat_last_n witness carries
  the configured value; repeat_last_n 1 vs 8192 at rep 2.5
  now produce DIFFERENT streams (pre-fix they were identical).
- (m3) re-run in the same binary: the rep-1.0 default stream
  is still bit-exact vs the pre-fix probe.
- Grade battery re-run post-4.3: forward fixture ALL PASS
  (qs-4-fwd-fixture2.log), resident-K ALL PASS (qs-4-
  residentk2.log), test_inference PASS (qs-4-test-
  inference2.log). 27B grade still pending the HEAVY lock.

## QS-4.4 SERVE SMOKE — proven on :18437 (2026-11-15)

Setup: engine built from this tree (qs-4-engine-build.log,
exit 0); fenced systemd units qs4-smoke1/2/3 (User=volmarr,
MemoryHigh 8G / MemoryMax 12G), fixture fixtures/
qwen35_k256_q8.gguf, --accel cpu --profile qwen35
--experimental-qwen35 --qwen35-resident --context 512
--max-tokens 64 --port 18437. (First launch without
--experimental-qwen35 was refused by name: fixture geometry
has no native profile — admission honesty working as
designed.) Client: POST /v1/generate, key read in-process,
never printed. All requests: prompt "The old lighthouse
keeper", temperature 1.0, top_k 256, top_p 1.0, seed 42.

Results (qs-4-smoke-r*.log):
- min_p: R1 (min_p 0) vs R2 (min_p 0.95), 24 tokens: streams
  identical for 9 tokens, DIVERGE at token 10 — min_p
  observably changes serve generation.
- repeat_last_n (64-token runs): R5 (rep 1.0, win 8192) ==
  R7 (rep 1.0, win 1) — window is a no-op at penalty 1.0,
  and the fixed seed reproduces across instances. R6
  (rep 2.5, win 8192) DIVERGES from R5 at token ~42, exactly
  where token 375 repeats (11 tokens after its previous
  occurrence). R8 (rep 2.5, win 1) == R7: with a 1-token
  window the penalty cannot reach an 11-apart repeat, so
  the stream is untouched. R6 != R8 is the window proof, in
  the expected direction both ways.
- Honest note: at 24 tokens R3/R4 (rep 2.5, either window)
  matched R1 — no repeat fell inside the sampled stream's
  reach that early on this fixture; the 64-token runs are
  the discriminating ones. Recorded, not hidden.
- Units stopped clean; the live gate on :18434 was never
  touched.

## Remaining / next work (named, not hidden)

- 27B 198-record teacher-forcing grade re-run on the final
  QS-4 tree: NOT run — the HEAVY lock was held by QS-1 then
  QS-2 for the whole QS-4 window and load1 stayed > 8.
  Grade safety rests on: logit-row capture precedes sampling
  in both qwen35 forwards; the greedy fast path is untouched;
  defaults are bit-identical (m3 stream pin + resident-K
  logits diff 0.0 + forward fixture ALL PASS, re-run after
  each slice). QS-6's final gate re-grades the merged tree
  regardless; run the grade there or in the first free lock
  window.
- The generic (llama) and gemma4 CPU forwards have the same
  dead GenerationConfig.min_p (never passed to the sampler)
  and no repeat_last_n plumbing — same defect class, outside
  QS-4's qwen35 scope; the sampler + config support now
  exists, so wiring them is a small follow-up slice.
- The native /v1/generate request parser accepts min_p and
  repeat_penalty per request but not repeat_last_n (serve-
  default only, via --repeat-last-n / modelfile / Ollama
  options). Per-request repeat_last_n on the native route
  is a small parser follow-up if Volmarr wants it.
