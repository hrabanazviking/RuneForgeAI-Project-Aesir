# Q35-4b — Real-file serve proof: 27B Q8_0 resident on :18435 (worker slice)

Worker ran all six Forge roles sequentially in one seat (recon ->
design -> build -> test -> repair -> record); no sub-agents. Seat:
/home/volmarr/aesir-q35-4b @ yrsa/q35-4b, base fd73cad9 (Q35-3b
merged + banked). Scope: serve the REAL 27B file through the
Qwen35 CPU session in RESIDENT mode (--qwen35-resident) on side
port :18435 — the configuration Q35-7 inherits. All other services
(aesir-gate, Ollama, Voxta) stayed DOWN throughout by Volmarr's
orders; :18434 untouched and down.

## Design (no code changes to the engine)

This slice is a proof, not a feature: the merged tree already
carries Q35-4a (CPU serve session), Q35-5 (snapshots), Q35-3r
(resident contract) and Q35-3b (U1 fix, FAITHFUL grade). The only
new code is proof tooling:
- aesir_engine/tests/ref_qwen35_realfile_q35_4b.mojo — in-process
  reference driver: Qwen35CPUSession over the real file,
  resident_q8=True, ctx 4096, serve-default sampling, driven with
  exactly serve_loaded's call sequence (Q35-4a contract). Modes:
  turns (T1 + resident T2 + stateless snapshot resend) and long
  (R1 serve-length prompt, run twice from reset).
- hidden_files/qwen35-adapter/q35_4b_bench.py — HTTP bench:
  health -> resident T1 -> resident T2 -> intervening
  different-session request -> stateless resend -> long exchange.
  NO sampling fields are sent in any request (R2: the serve's own
  defaults apply); replies are compared to the reference logs.
- hidden_files/qwen35-adapter/q35-4b-long-prompt.txt — the R1
  user message (a ~430-token passage + question; exact token count
  measured in the run, below).
- hidden_files/qwen35-adapter/build-q35-4b.sh — engine compile +
  reference driver + full regression rebuild set.

Prompts: system "You are a helpful assistant."; U1 "What is the
capital of France? Name one famous museum there."; U2 "What
language do most people speak in that city?"; generations capped
at 32 tokens (turns) / 48 (long) per the ~2.2 tok/s plan (R4).

## R2 — serve sampling defaults, as found (no retuning)

- NativeSamplingConfig() defaults (core/sampling_config.mojo):
  temperature 0 (greedy), top_k 40, top_p 0.95, min_p 0,
  repetition_penalty 1.0, repeat_last_n 64, seed 42. The serve was
  launched with no --config and no sampling flags, and the bench
  sent no sampling fields, so these defaults governed every reply
  in this proof.
- Qwen35CPUSession._gen_config maps temperature/top_k/top_p/
  repetition_penalty/seed into GenerationConfig; min_p and
  repeat_last_n have no CPU-forward counterpart and are not
  claimed (Q35-4a truth, unchanged).
- The engine-level forward_pass_qwen35 DEFAULT repetition_penalty
  is 1.1 (core/inference.mojo) — that default governs direct
  forward calls without a config, NOT the serve path: the session
  always passes its mapped config, so the served rep-penalty is
  1.0. The Q35-3b grade's driver also used 1.0. Verdict: COHERENT
  under serve defaults — every proof reply is well-formed,
  on-topic, and factually right (Paris/Louvre; French; the long
  reply's reasoning opens correctly). No degeneration was observed
  in the proof turns. Two serve-surface findings were observed
  and are named below (F-4b-1, F-4b-2); neither is a sampling
  degeneration and neither was retuned in this slice.

## Results

File served: /mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-
Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf, sha256
1fca6eefc37607b5ab458f9a76815b36aeb38cf21ac36c49fdc0ab4eb186f08e
(re-measured this run). Serve unit: systemd user unit, MemoryMax
64G, ctx 4096, max_tokens 48, --timeout-ms 900000. Startup line:
"admission=native" — the real file took the registry's own
signature path (variant qwen35-27B, 64L/5120); NOT experimental.
Resident census at load (both reference and serve):
mode=q8_0_resident, large_tensors=498, q8_0_bytes=28,574,187,520,
f16_materialized_bytes_avoided=53,786,705,920.
MemAvailable before the serve run: 124,198,816 kB. Contention:
none — process list before the runs showed only the desktop
shell; no sibling worker builds were running during the bench.

/health raw body (q35-4b-bench.log):
{"status": "ready", "backend": "cpu", "cpu_offload": 0,
"profile": "qwen35", "context": 4096, "model": "<real file path>",
"model_digest": "", "max_tokens": 48, "generation_timeout_ms":
900000, "capabilities": {"text_generation": true, "embeddings":
false, "exact_prefix_reuse": true, "exact_prefix_reuse_detail":
"snapshot-based at committed turn boundaries only",
"post_history_configured": false, "session_residency": true,
"memory_injection": true, "experimental_admission": false,
"weight_load_mode": "q8_0_resident"}, "prefill_batch": 1,
"queue_limit": 4}
Health truth: profile qwen35, backend cpu, residency true,
exact_prefix_reuse true WITH the snapshot detail qualifier,
weight_load_mode "q8_0_resident", experimental_admission false.
Note: /health has no separate variant field — the variant truth
(qwen35-27B) is carried by admission=native + the plan (ripple
probe r1 on this tree: real file auto -> native qwen35,
experimental=False). If Q35-7 wants the variant string in
/health, that is a small named addition, not a silent gap.

In-process reference (q35-4b-ref-turns.log, ALL PASS): T1
prompt_tokens=23, POS1=55; stateless in-process resend reused=55
== POS1, reply == resident R2 exactly.

HTTP bench (q35-4b-bench.log, ALL PASS; serve-side elapsed_ms
agrees to the millisecond class in q35-4b-serve.log):
- T1: 200, wall 20.82 s, prompt 23, completion 32, reused 0.
  Reply == in-process R1 exactly. (End-to-end completion rate
  1.54 tok/s including the 23-token prefill.)
- T2 resident: 200, wall 18.27 s, prompt 65, reused 55 (==
  POS1, the resident path), evaluated 10, completion 32.
  Reply == in-process R2 exactly.
- Intervening different-session request: 200, wall 6.32 s,
  prompt 8, completion 8 (destroys residency, per Q35-5 design).
- Stateless resend: 200, wall 18.89 s, prompt 65, reused 55
  (== turn-1 boundary, via Q35-5 snapshot restore), evaluated
  10, completion 32. Reply == resident R2 exactly.
- Long (R1): 200, wall 139.75 s, prompt 483, completion 48.
  Reply == in-process reference exactly. Derived split (decode
  at the grade's ~2.2 tok/s): prefill of 483 tokens at roughly
  4 tok/s batched; labelled derived, not measured directly.

Peaks: serve process VmHWM 31,312,080 kB (~31.3 GB) measured
from /proc after a generation on a second short unit
(q35-4b-serve2.log); in-process reference peaks by /usr/bin/time
-v: 31,621,040 kB (turns) and 31,626,896 kB (long). The systemd
MemoryPeak for the serve units (5.35 GB / 4.50 GB) UNDERCOUNTS:
the mmap'd weight pages are not charged to the cgroup the way
RSS counts them — the /proc and time -v figures (~31.3–31.6 GB)
are the honest peak class, inside the 64G fence and the
expected 31–35 GB band from Q35-3b. (The first unit's time -v
summary did not survive the unit stop; the /proc measurement
replaced it.)

Findings (named, not fixed — proof scope):
- F-4b-1 raw-continuation surface: replies carry the
  "Assistant:" marker as generated text (T1 reply begins
  "Assistant:\n\nThe capital of France is **Paris**..."). This
  is the qwen35 raw-text serve contract (no chat template on
  this path; Q35-4a design). Q35-7's Voxta-facing presentation
  inherits it unless the route trims it.
- F-4b-2 special-token leakage after short answers: the
  intervening reply was 'Assistant:\n\nhello<|endoftext|>
  <|im_start|><|im_start|><|im_start|>' — the correct one-word
  answer, then control-token spellings until the 8-token cap.
  The qwen35 CPU serve path does not stop on the model's
  end/control tokens the way a chat serve needs. Named
  serve-config finding for Q35-7; NOT silently retuned here
  (R2 discipline).

## R1 — serve-length witness: PASS

Prompt: 483 tokens (the lighthouse passage + 3-part question in
q35-4b-long-prompt.txt) — 8x the Q35-3b grade's ~60 positions.
Served reply (48-token cap, verbatim):
"Assistant:\n\n<think>\nThe user is asking me to extract three
specific pieces of information from the passage:\n\n1. How many
iron steps did Tomas climb to reach the lamp room?\n2. How
often did the light flash?\n"
The reply EQUALS the in-process forward on the same prompt
exactly, and the in-process rerun from reset reproduces it
exactly (q35-4b-ref-long.log, ALL PASS) — same-path agreement
at serve length, the witness R1 asked for. Behaviour at length:
coherent — the model correctly identifies all three requested
facts and begins structured extraction; the text ends only
because the 48-token cap cut it inside the think block, not
from any degradation. No long-context collapse observed at 483
tokens. (llama.cpp comparison at length was not required and
was not run.)

## Regression (all on THIS tree, base fd73cad9 + proof tooling)

- Full engine compile: exit 0 (q35-4b-build.log,
  ENGINE_BUILD_EXIT=0; reference driver and every test binary
  also exit 0).
- Q35-1 loader: ALL PASS. Q35-2 registry: ALL PASS.
- Q35-3a forward: ALL PASS. Q35-3r resident: ALL PASS.
- Q35-4a session reference: ALL PASS.
- Q35-5 snapshot test: binary REBUILT from this tree and run —
  ALL PASS (q35-4b-regress-q35-5.log). This closes the
  coordinator-owed standalone rerun post-U1-fix in form;
  Q35-3r's r7 had already covered the behaviour in substance.
- Ripple/admission probe: ALL PASS (real file auto -> native
  qwen35, experimental=False).
- Note: direct test-binary runs need LD_LIBRARY_PATH=
  hidden_files/hip-serve/shims; the first regression pass's
  127s (q35-4b-regress.log) were that loader path, not test
  failures — the rerun (q35-4b-regress2.log) is the record.
- Full 905 matrix NOT re-run (slice order; baseline stands).
- Both serve units stopped; :18435 free; :18434 down and
  untouched; all other services stayed down throughout.

## Named risks for Q35-7

1. Stop-token handling (F-4b-2): the gate swap puts this serve
   in front of Voxta chat; short answers will leak control
   tokens until the qwen35 CPU path stops on the model's
   end tokens. Fix or explicitly accept before the swap.
2. "Assistant:" marker in raw replies (F-4b-1): presentation
   trimming is Q35-7's call, on the record here.
3. Latency: end-to-end completion ~1.5–1.8 tok/s on CPU in
   this proof (grade decode ~2.2 tok/s); a 32-token reply
   takes ~19–21 s and a ~500-token prompt ~2.3 min wall in
   the worst measured case. Voxta expectations must be set
   from these numbers; Q35-6 HIP is the speed road.
4. Memory: serve peak ~31.6 GB RSS class — the :18434 gate
   unit's fence must carry that class (64G used here).
5. Snapshot store remains per-session in-memory, limit 4
   (Q35-5) — inherited unchanged; long Voxta histories that
   resend after >4 intervening turns fall back to cold
   evaluation (proven pattern in Q35-5, unchanged here).
6. /health carries no variant string (see Results note) —
   add "qwen35-27B" to the payload only if Q35-7's checks
   want to read it there; admission=native already proves
   the signature path.
