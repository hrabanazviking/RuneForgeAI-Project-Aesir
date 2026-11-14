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
  1.0. The Q35-3b grade's driver also used 1.0. Verdict: (filled
  after the run — coherence under serve defaults.)

## Results

(Filled as the run lands: health payload raw, reference log,
bench numbers per turn with wall times and tok/s, peaks,
contention note.)

## R1 — serve-length witness

(Filled after the run: prompt token count, reply text verbatim,
in-process agreement verdict.)

## Regression

(Filled after the run: engine compile, Q35-1, Q35-2, Q35-3a,
Q35-3r, Q35-4a session, Q35-5 snapshot binary rebuilt from THIS
tree and run, ripple.)

## Named risks for Q35-7

(Filled at record time.)
