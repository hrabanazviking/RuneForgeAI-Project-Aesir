# Project Aesir — Qwen35 SPEED Campaign (QS) — MAP

Commission (Volmarr, 2026-11-14 ~20:05 EST): make the Qwen3.8-27B
heretic (architecture qwen35, Q8_0 GGUF, 28,596,003,296 B, sha256
1fca6eefc37607b5ab458f9a76815b36aeb38cf21ac36c49fdc0ab4eb186f08e)
run on Aesir EXTREMELY FAST, robust, efficient, ultra stable.

Team shape: QS-0 lead runs the six Mythic Engineering roles
sequentially in one seat (no sub-agents spawned — depth limit;
established fallback, recorded per commission). Sole writer in
~/aesir-hipserve on branch yrsa/hip-serve. Main (31ab9363) is
NEVER touched. The live aesir-gate serve (transient unit, CPU
resident, :18434, ctx 4096, WorkingDirectory ~/aesir-q35-7) is a
bench TARGET only — never restarted, stopped or reconfigured;
~/aesir-q35-7 is never touched.

## Yardsticks (measured 2026-11-13/14, from prior records + commission)

- Ollama, same 27B: Q8_0 gen 7.65 tok/s, prompt 136.61 tok/s;
  Q4_K_M gen 12.11 tok/s.
- Aesir CPU resident (Q35-4b/Q35-3b): grade decode ~2.2 tok/s;
  end-to-end serve ~1.5-1.8 tok/s; 483-token prefill ~4 tok/s
  (derived). Serve VmHWM ~31.3 GB.
- Aesir HIP decode: ~0.07-0.09 tok/s (naive byte-load GEMV,
  ~11-14 s/token). Correct (71/71 rank 1 gap 0.0), a crawl.
- Aesir CPU-resident end-to-end speed on the LIVE gate at stated
  prompt sizes: never honestly benched before QS-0. Headline
  measurement of this campaign's first slice.

## Hard laws (all slices)

- FRESH-BOOT LAW: heavy runs forbidden until uptime >= 60 min
  AND load1 < 1.5 AND MemAvailable > 100 GB. Check before every
  heavy run; record the check in the slice log.
- SERIALIZED HEAVY RUNS: atomic lock mkdir
  hidden_files/qwen35-speed/HEAVY.lock before any heavy run;
  remove when done. Heavy work detached via machine-level
  systemd-run units (sudo systemd-run --unit=<name>
  -p User=volmarr -p MemoryHigh=<sized> -p MemoryMax=<sized>),
  output to log files; NEVER tmux. device.invoke < ~110 s.
- Numbers only from logs/files on this machine. Every bench
  states context size + configuration.
- Grading law: teacher-forcing rank + logit gap vs llama.cpp on
  RAW prompts; NEVER llama-cli --single-turn. Near-tie band
  (rank <= 2, sub-logit gap) = FAITHFUL. Any speed change must
  keep the grade FAITHFUL or it does not bank.
- Never touch README.md. No Docker. Ollama + Voxta stay DOWN.
- Service key read on-device only; never printed, never filed.

## Workstreams and slices

### QS-0 — Recon + plan + baseline + profiles (THIS SLICE)
- QS-0.1 Campaign records (MAP/LEDGER) banked. DONE at creation.
- QS-0.2 Prior-record mining: speed facts extracted to LEDGER.
- QS-0.3 Baseline harness qs0_bench.py (live gate, streaming
  TTFT if supported, prompt/decode tok/s at ~500 and ~2000
  token prompts, gen 128-256, ctx 4096 as running).
- QS-0.4 Baseline run (heavy-gate checked) -> QS-0-BASELINE.md.
- QS-0.5 CPU profile of the running server during a bench
  window (perf if permitted; perf_event_paranoid=4 noted;
  fallback /proc sampling + engine timing, method recorded).
- QS-0.6 HIP profile: Q35-6 HIP session harness standalone,
  FENCED (systemd-run, fence from Q35-6 logs: MemoryMax 96G
  class), lock held, per-kernel/per-phase timing (rocprof if
  present, else engine timers), decode-focused.
- QS-0.7 QS-0-BASELINE.md filed (baseline table, CPU + HIP
  indictments, recommended QS-1/QS-2 slice order); banked.

### QS-1 — CPU-resident speed (grade must stay FAITHFUL)
- QS-1.1 Attack the QS-0 CPU indictment's top hotspot (expected
  candidates from prior records: gemm_q8_0 single-row decode
  path, batched prefill one-row-at-a-time F32 scratch decode,
  delta-net recurrent step on CPU).
- QS-1.2 Threading/bandwidth audit: 32 cores — measure scaling
  of decode vs thread count; NUMA/affinity if indicted.
- QS-1.3 Prefill: batched GEMM width for Q8_0 (the HIP fixture
  precedent: batched beat GEMV-loop 6.7x); target prompt tok/s
  toward Ollama's 136.61.
- QS-1.4 Re-grade (198-record teacher-forcing) + re-bench;
  target: beat 2.2 tok/s grade decode, then Ollama Q8_0 7.65.
- QS-1.5 SIMD width audit of Q8_0 dequant in the decode GEMV
  (IQ width-16 precedent from the roadmap era: scalar decode
  was ~90% of IQ cost; width-16 gave ~3x numerics-unchanged).

### QS-2 — HIP decode speed
- Goal: beat Ollama Q8_0 7.65 tok/s, then Q4_K_M 12.11 tok/s;
  or name the measured ceiling with evidence.
- QS-2.1 Replace naive byte-load GEMV with vectorized/coalesced
  GEMV (QS-0.6 indictment decides the exact kernel order).
- QS-2.2 Gated-DeltaNet recurrent step on device: per-token
  launch count + fusion opportunities (named suspect, Q35-6).
- QS-2.3 Conv ring: stage/commit already fixed (D2); measure
  its share; fuse shift into the conv kernel if indicted.
- QS-2.4 Launch-overhead: kernel launches per token census;
  graph/persistent-kernel or batching remedy as measured.
- QS-2.5 Re-grade HIP (71/71 standard) + real-file serve bench
  at the Q35-6b shape; native admission decision input.

### QS-3 — Packed residency + searched-fit packer
- QS-3.1 Q4_K_M resident-analogue contract (QC_RESULTS named
  work item 1): resident load for the QC-6 product (~19.5 GB
  vs ~31.0 GB) + serve smoke.
- QS-3.2 Searched-fit packer for the QC-6 out-of-band record
  (p5 pos22, rank 3 gap 0.421): per-tensor tier search until
  the strict gate passes or the search space is exhausted.
- QS-3.3 Speed check: Q4_K_M resident decode vs Q8_0 resident
  (Ollama says the smaller tier is ~1.6x faster on decode).

### QS-4 — Sampling parity on qwen35
- QS-4.1 min_p on the qwen35 CPU-forward sampling path.
- QS-4.2 repeat_last_n on the qwen35 CPU-forward path.
- QS-4.3 Parity proofs vs the generic path; serve defaults
  unchanged unless Volmarr directs (R2 discipline).

### QS-5 — Ultra-stable serve
- QS-5.1 Real persistent systemd unit replacing the transient
  aesir-gate (same command/config; gate swap only at a
  Volmarr-cleared window — the running gate is not touched
  by QS-0..QS-4).
- QS-5.2 Watchdog + restart policy; health-probe loop.
- QS-5.3 Soak proof (sustained mixed load, hours class) +
  crash-recovery proof (kill -9 -> clean restart -> bench
  replies still == reference).
- QS-5.4 Memory discipline: VmHWM watch, fence sized from
  measured peaks (Q8_0 class 31.3-31.6 GB; systemd MemoryPeak
  UNDERCOUNTS mmap pages — never size from it).

### QS-6 — Final gate
- QS-6.1 Full 905-case battery defense on the final tree
  (baseline: 900 passed / 3 failed / 2 skipped; the 3 named:
  two proven pre-existing + one contention race case).
- QS-6.2 Final grades: CPU FAITHFUL re-proof, HIP grade,
  Q4_K_M strict gate if QS-3 lands it.
- QS-6.3 SPEED_AND_STABILITY_RESULTS.md: every headline number
  traced to a banked log; honest ceilings named.

## Slice order note
QS-0 first. QS-1 vs QS-2 order is decided by the QS-0 profile
indictments (filed in QS-0-BASELINE.md). QS-3/QS-4 parallel-safe
after QS-1. QS-5 last-but-one (needs the final config). QS-6
closes.
