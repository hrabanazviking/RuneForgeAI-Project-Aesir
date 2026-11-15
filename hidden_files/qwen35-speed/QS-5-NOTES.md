# QS-5 NOTES — ULTRA-STABLE SERVE (permanent, self-healing gate)

Team: QS-5 lead seat, six Mythic Engineering roles run
sequentially in one seat (no sub-agents — depth limit;
recorded per commission). Work tree: ~/aesir-qs-stable on
branch yrsa/qs-stable @ base d1e5815f (QS-0+QS-1+QS-2+
QS-3+QS-4 merged into yrsa/hip-serve). Gate tree:
~/aesir-gate-serve, detached at d1e5815f, changes ONLY at
planned swaps. Main (31ab9363) never touched. Ollama/Voxta
left alone.

## Mission

Replace the TRANSIENT systemd-run aesir-gate unit (dies with
any reboot, no auto-restart) with a permanent, self-healing
installation: enabled at boot, Restart=on-failure, fences
from measured peaks, a health watchdog, a soak proof, and a
crash-recovery proof.

## Config decision (coordinator's, not relitigated)

The permanent unit serves the CPU Q8_0-resident
configuration on the merged tree — the proven, stable form
(now carrying QS-1 CPU speed + QS-4 sampling parity):
  .aesir/aesir serve <27B Q8_0 GGUF> --accel cpu
  --profile qwen35 --qwen35-resident --context 4096
  --max-tokens 512 --timeout-ms 900000 --port 18434
Model: /mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-
Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf (sha256
1fca6eefc37607b5ab458f9a76815b36aeb38cf21ac36c49fdc0ab4eb186f08e).
Auth: bearer key at ~/.config/aesir/service.key (read
on-device only; never printed, logged, or committed).
Strict routing: the request model field must be the full
GGUF path.

### Documented alternatives (NOT the default)

- HIP serve (QS-2): decode 3.55 tok/s cold / 3.83 tok/s
  warm (long pairs, v8 build), grade 71/71 FAITHFUL;
  isolated GEMV sustains 205.1 GB/s. NOT default because:
  it claims the GPU memory pool, and ~0.13 s/token of
  in-engine non-GEMV time inside it is still unexplained
  (next step named in QS-2 notes: real-scale per-phase
  profile). Faster per token, less proven as a 24/7 gate.
- Packed resident-K (QS-3): Q4_K_M resident contract
  (weight_load_mode=q4_k_m_resident, flag
  --qwen35-resident-k), resident bytes 16,223,236,576
  (~16.2 GB) vs ~28.6 GB Q8_0 resident. NOT default
  because: Q4_K_M is a different, lower-precision weight
  form than the proven Q8_0 gate configuration; the
  switchover-proven serve is Q8_0.

## Start truth (2026-11-15 ~02:45 EST)

- purpleraider up 6:46, load1 falling (0.16 at check),
  MemAvailable ~119 GB. HEAVY.lock free (no owner).
- Transient gate: aesir-gate.service loaded from
  /run/systemd/transient, active since 2026-11-14
  20:05:35 EST, WorkingDirectory ~/aesir-q35-7, fences
  MemoryHigh=48G / MemoryMax=64G, cgroup MemoryPeak
  30.8 GB over its life, health ready (profile qwen35,
  model_variant qwen35-27B, weight_load_mode
  q8_0_resident, session_residency true,
  exact_prefix_reuse true). sudo is passwordless.

## QS-5.1 BUILD + REHEARSAL

- Gate tree built in place (build-qs5-gate.sh, log
  qs5-build.log in the gate tree): shaders exit 0, all
  six shims built, engine build exit 0;
  .aesir/aesir = 5,082,096 bytes, sha256
  efc8334c56bae65fc98ee9ca13bf4eddd08fbf84dff28bfe288ed2b2dcf270c1.
- Rehearsal serve: transient unit qs5-rehearsal, fenced
  MemoryHigh=48G / MemoryMax=64G (measurement run only),
  WorkingDirectory ~/aesir-gate-serve, LD_LIBRARY_PATH =
  gate-tree shims, port 18438, otherwise the exact proven
  command shape. Ready immediately after start (resident
  load: 498 large tensors, q8_0_bytes=28,574,187,520,
  MimirWell 4,232,837,120 derived bytes).
- Verify (qs5_verify.py, log qs5-rehearsal-verify.log):
  ALL_PASS — health ready naming qwen35 /
  qwen35-27B / q8_0_resident; turn 1 completion 200 in
  25.5 s; turn 2 completion 200 in 12.0 s with
  reused_prompt_tokens=69 (prefix reuse proven on the
  merged build).
- FINDING (engine fact, not a QS-5 defect): the OpenAI
  chat parser (aesir_engine/server/openai.mojo) accepts
  only temperature / seed / top_p as sampling fields;
  min_p (or top_k) on /v1/chat/completions is refused
  HTTP 400 "Unsupported OpenAI request field". min_p +
  repeat_penalty ARE accepted on the native /v1/generate
  route (aesir_engine/cli/native_serve.mojo parser),
  which is where QS-4 proved them. QS-5 harnesses
  therefore exercise sampling as: chat legs with
  temperature+top_p, generate legs with min_p+
  repeat_penalty. First measure run died at this leg
  (HTTP 400, MEASURE_EXIT=1) before the prefill legs;
  harness fixed and re-run as qs5-measure2.

### Fence measurement (qs5_measure.py, qs5-measure2.log)

Load mix run against the rehearsal unit (qs5-measure2.log,
MEASURE2_EXIT=0; unit MemoryPeak read from the cgroup):
- short stateless: 200, 25.9 s (21 prompt / 32 completion)
- resident two-turn: t1 200 in 17.8 s; t2 200 in 28.3 s,
  reused_prompt_tokens=61
- sampling chat leg (temperature 0.8, top_p 0.95): 200,
  19.9 s
- generate leg (/v1/generate, min_p 0.05,
  repeat_penalty 1.1): HTTP 200, 15.4 s — QS-4 wiring
  exercised end to end on the merged build
- medium prefill: 845 prompt tokens, 200, 158.6 s
- full prefill: 3,055 prompt tokens + 64 gen, 200,
  642.3 s
- worst-case leg (qs5_peakleg.py, qs5-peakleg.log):
  3,383 prompt tokens + 132 gen (3,515 total, under the
  4,096 cap), 200, 676.7 s
Rehearsal cgroup MemoryPeak after the whole mix:
22,973,169,664 bytes = 21.39 GiB. The peak was set by the
resident load + page cache early and NO leg — not even
the 3,383-token prefill — pushed past it. MemoryCurrent
at idle after the mix: ~21.6 GB (resident weights are
mmap-backed; cgroup accounting includes their cache).

### Fence derivation (for the permanent unit)

Governing observed peak P: the Q35-7 transient's lifetime
cgroup peak, 30.8 GB as reported by systemctl (~28.7 GiB)
over 6 h of real traffic on the older build, is larger
than the merged build's measured 21.39 GiB, so P = 28.7
GiB governs.
- MemoryHigh = P x 1.4 = ~40 GiB -> 40G. Soft throttle
  line: the healthy merged-build serve peaks at 21.4 GiB,
  47% below High, so throttling never engages in health.
- MemoryMax = P x 1.8 = ~52 GiB -> 52G. Hard line: a
  runaway is killed and restarted by Restart=on-failure
  long before it can pressure the machine (121 GB RAM;
  the fence leaves ~69 GB for everything else).
Both fences sit below Q35-7's 48G/64G — justified by the
merged build's lower measured peak — while keeping at
least 40% headroom over the worst peak ever observed
for this serve in either build.

## QS-5.2 THE UNIT + WATCHDOG

UNIT_PLACEHOLDER

## QS-5.3 THE SWAP

SWAP_PLACEHOLDER

## QS-5.4 SOAK

SOAK_PLACEHOLDER

## QS-5.5 CRASH RECOVERY

CRASH_PLACEHOLDER

## Remaining / named follow-ups

- Literal reboot proof deferred to Volmarr's next
  natural reboot (QS-5 may not reboot his machine);
  boot persistence is proven by is-enabled + unit
  analysis (see QS-5.5).
- HIP and resident-K remain documented alternatives
  above; promoting either is a planned swap through
  the gate tree, not an edit on the live unit.
