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

Sources in the branch (qs5-install/, reproducible
install): aesir-gate.service, aesir-gate-watchdog.service,
aesir-gate-watchdog.timer, aesir-gate-health.sh,
install-qs5.sh. Installed 2026-11-15 ~03:27 EST:
- /etc/systemd/system/aesir-gate.service (byte-identical
  to the repo source, diff-verified): User=volmarr,
  WorkingDirectory=/home/volmarr/aesir-gate-serve,
  ExecStart = the proven command on the gate tree
  (absolute paths, LD_LIBRARY_PATH = gate-tree shims),
  MemoryHigh=40G / MemoryMax=52G (QS-5.1 derivation),
  Restart=on-failure, RestartSec=10s,
  StartLimitIntervalSec=600 / Burst=5,
  RequiresMountsFor=/mnt/vault + After=mnt-vault.mount,
  TimeoutStopSec=60s, stdout/stderr appended to
  hidden_files/qwen35-speed/aesir-gate-permanent.log in
  the gate tree, WantedBy=multi-user.target.
- Watchdog: /usr/local/sbin/aesir-gate-health.sh (mode
  755, bash -n clean), run by aesir-gate-watchdog.service
  (oneshot, root) on aesir-gate-watchdog.timer
  (OnBootSec=2min, OnUnitActiveSec=2min, Persistent).
  Each run: reads the key at runtime (never logged),
  curls /health (15 s cap), requires unit active +
  status ready; logs every check to the journal
  (tag aesir-gate-watchdog) and to
  hidden_files/qwen35-speed/watchdog.log in the
  hipserve tree; consecutive-failure count in
  watchdog-state.txt beside it; at 3 consecutive
  failures it reset-failed + restarts the unit and
  logs the ACTION both places.
- systemd-analyze verify on all three units: exit 0.
- Live-fire test of the checker (against the still-
  running transient gate): exit 0, watchdog.log gained
  "2026-11-15T03:28:10-05:00 OK fails=0", state = 0.
- Enable state: watchdog timer ENABLED. aesir-gate.service
  enable DEFERRED to the swap by systemd itself: while
  the Q35-7 transient of the same name is loaded it
  shadows the file and enable is refused ("Unit
  /run/systemd/transient/aesir-gate.service is transient
  or generated"). install-qs5.sh handles this case with
  an explicit note. The swap (QS-5.3) stops the
  transient, daemon-reloads, enables, and starts — the
  enable is part of the single-restart window.
- The real unit was NOT started in this slice. The
  transient gate served throughout (MainPID 5932,
  never interrupted).

## QS-5.3 THE SWAP

Pre-swap: transient gate healthy (old Q35-7 build, PID
5932, up since 2026-11-14 20:05:35 EST), last requests
completed clean, no generation in flight.

Attempt 1 (03:29:42 EST): stop + daemon-reload + enable
+ start in one breath. systemd restarted the TRANSIENT
definition (old tree ~/aesir-q35-7, new PID 519897):
the transient unit file in /run/systemd/transient still
shadowed the /etc file, and enable was refused again
("transient or generated"). Health was ready again by
03:29:51 on the old build — the user-facing gap was
seconds, but the swap had NOT happened. Recorded, not
hidden: a same-name transient shadows its file until
the transient unit is fully retired.

Attempt 2 (the real transition): stop at
T_STOP2 = 2026-11-15T03:29:55-05:00; the stopped
transient stayed loaded (LoadState=loaded, inactive)
because its file persisted, so the file was removed
(sudo rm /run/systemd/transient/aesir-gate.service) and
daemon-reloaded: FragmentPath became
/etc/systemd/system/aesir-gate.service. Enable then
succeeded (multi-user.target.wants symlink created,
is-enabled = enabled). Start at 03:30:40; health ready
at 2026-11-15T03:30:45-05:00.
- Outage, final transition: 03:29:55 -> 03:30:45 = 50 s.
- Whole swap window: 03:29:42 -> 03:30:45 = 63 s, with
  the old build serving in between.
Post-swap verification (qs5-postswap-verify.log):
- Unit: active/running, FragmentPath = /etc file,
  MainPID 520736 with cwd /home/volmarr/aesir-gate-serve,
  MemoryHigh readback 42,949,672,960 (40 GiB),
  MemoryMax 55,834,574,848 (52 GiB), Restart=on-failure,
  RestartUSec=10s, NRestarts=0.
- qs5_verify.py postswap: ALL_PASS — health ready
  naming qwen35 / qwen35-27B / q8_0_resident; live
  completion 200 in 19.5 s; turn 2 completion 200 in
  11.9 s with reused_prompt_tokens=69 (prefix reuse
  across two turns on the permanent unit).
- Serve output lands in the gate tree's
  hidden_files/qwen35-speed/aesir-gate-permanent.log
  (resident load lines + requests as expected).
- Watchdog timer started after verification; first
  timer fire 03:32:00 EST.
- Display note: in this boot the manager still flags
  the unit object "Transient: yes" (sticky from the
  replaced transient incarnation). FragmentPath,
  enablement, and the wants symlink are all the
  permanent file's; at any reboot the unit loads purely
  as the enabled file unit.

## QS-5.4 SOAK

PASS criteria (stated before the soak starts):
- Duration >= 3 h of mixed load against the permanent
  unit (qs5_soak.py: short stateless, resident
  multi-turn, medium + long prefill, QS-4 sampling
  exercised — chat temperature/top_p legs and
  /v1/generate min_p + repeat_penalty legs).
- No unit restart during the soak (NRestarts stays 0,
  sampler health = ready at every minute sample).
- No failed requests (every request HTTP 200) and all
  completions sane (non-trivial text).
- Memory flat: least-squares slope of MemoryCurrent
  over the soak <= +5 MB/h in magnitude beyond noise
  (actual slope reported either way).
Sampler: every 60 s, MemoryCurrent + MemoryPeak +
NRestarts + health verdict to soak-mem.log; every
request to soak-req.log; summary to soak-summary.json
(all in hidden_files/qwen35-speed of the hipserve tree).

SOAK_RESULTS_PLACEHOLDER

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
