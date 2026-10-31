# J-023 — Streaming Under Load (PENDING LEGS)

**Slice:** J-023 (Part II — Models Bigger Than Memory), Project Aesir Janas clean-room road.
**Roadmap text:** "Streaming under load. The same model with the machine deliberately busy (browser-class load simulated by a bounded co-runner): degradation measured, no thrash collapse; the gentle-degradation claim tested, not assumed."
**Base:** branch `yrsa/janas-j023` from `yrsa/janas-j022` tip `64f465a6d616ff46753d1b62b1bead9bcb3859f0` — explicitly NOT from origin/main (`ba7ee09b`): the streamed MoE session (`core/moe_session.mojo`, J-022) lives only on the J-022 line. origin/main untouched by this slice.
**Worked:** 2026-10-31, purplelongship (Ryzen 9 / RTX 2060 6 GB, 16 logical CPUs, kernel 7.0.0-38-generic). VM: no build, no inference (MemAvailable ~630 MB at slice start). **No Janas material used** — the clean-room law was not engaged. Hailo untouched/parked.

## 1. What is measured, and on what

The streamed OLMoE session proven faithful in J-022 (B1 fix `69aeaf01`): vehicle `test_olmoe_stream` over `MoEStreamSession` — resident set via the ordinary GGUF mmap, routed experts only through the J-018 `ExpertCache` + J-019 `StreamReader` path. Model: OLMoE-1B-7B Q4_K_M, the J-015 pin (sha256 `8c310f14…f3f`, 4,213,512,672 B). Prompt set identical to J-022's graded run: the lighthouse prose prompt, 67 ids from the model's own tokenizer stack, context 512, expert-cache budget 512 MiB (536,870,912 B), 24 generated tokens. The on-box binary is J-022's post-fix build (`~/j022/test_olmoe_stream_fix`, built 2026-10-31 08:21 EDT from the tree at `9a930a3a`, which contains the B1 fix; the J-023 branch base `64f465a6` adds only the J-022 doc §7 commit on top of that tree, no engine change).

Two legs, same binary, same arguments, differing only in machine load:

- **Idle leg** — nothing else running (guard-verified, §4); the baseline. Its generated ids must also reproduce J-022's post-fix run (`j022_b1_run_fix.txt`) token-for-token, which cross-checks the baseline against an independent earlier run.
- **Loaded leg** — the bounded co-runner (§2) live for the whole run.

Per leg, recorded: cache hit rate, bytes streamed, streamed bytes/token (over 67+24 = 91 stepped tokens), wall/token (prefill + decode), generated-id identity vs the idle leg, and cache behaviour (admissions / promotions / evictions / bypasses / evicted-before-reuse). Machine state (loadavg, Tctl, MemAvailable) is logged at leg start and end in each leg's `.meta` file.

## 2. The co-runner: browser-class load, bounded and named (SIMULATED load)

`j023_corunner.py` (this slice): a *simulation* of a busy desktop browser's footprint, with hard bounds stated in its source and printed at start:

- **CPU:** 4 spinner workers (of 16 logical CPUs = 25 %) doing floating-point churn — the busy-tab / JS-heavy-page class.
- **Memory:** one holder allocating a capped 10 GiB anonymous region, every page touched so it is genuinely resident, re-touched periodically — this pressures the page cache the streamed GGUF reads through, which is the channel through which memory pressure could hurt a streaming engine.
- **Safety:** the holder refuses to start if MemAvailable < holder + 12 GiB reserve; worker count and holder size are fixed arguments that never grow; the driver kills the co-runner after the leg and verifies it is gone (`corunner_verified_gone` in the loaded leg's meta).

The load is classed **SIMULATED** throughout: it is a named, bounded stand-in for browser-class load, not a real browser.

## 3. "Thrash collapse" — defined before measuring

The gentle-degradation claim is tested against an operational definition fixed *before* any loaded run:

**Thrash collapse** = any of:
(a) loaded hit rate < 0.5 × idle hit rate;
(b) loaded streamed bytes/token > 2 × idle;
(c) generated ids differ from the idle run (functional divergence under load);
(d) the loaded run fails, crashes, or its wall/token exceeds 3 × idle wall/token.

**Gentle degradation** = none of (a)–(d); the wall/token ratio then *is* the measured degradation. The analyser (`j023_analyze.py`) computes exactly these quantities and prints the verdict from the numbers, not by eye.

A design note recorded before measuring: the J-018 cache's budget is fixed at session open (flag/env hard cap, J-017 D4) and the session installs no OS-pressure shrink hook, so the prior expectation is that load moves *walls* (CPU contention + page-cache pressure on the reader) but not *counters* (hit rate / bytes are functions of routing demand, which is deterministic for a fixed prompt). The measurement exists to prove or break that expectation — in particular (b) would break if page-cache pressure ever fed back into admission behaviour, and (c) would break on any load-dependent state corruption of the kind J-022's token-57 defect exemplified.

## 4. Coordination with the 204 road (S-093) — the guard is part of the instrument

The 204 road's S-093 (CPU correctness gate per class) is LIVE on purplelongship for this whole slice (driver PID 2664092, started 06:47 EDT; grade phase from ~08:28 EDT). Per the coordination law:

- Every leg runs through `j023_run.sh`, whose guard refuses to start a leg while any S-093 compute process (`tf_oracle` / `fr_oracle` from the S-093 driver) is live, and — for the loaded leg — re-checks after the co-runner starts and aborts, killing the co-runner, if S-093 has appeared. **The co-runner is never added on top of a live S-093 run**, and no J-023 wall measured beside S-093 is ever presented as a baseline.
- At 08:35 EDT both legs were attempted through the guard and **GUARD_BLOCKED** (exit 3, `reason=s093_live_at_start`; loadavg 2.17/4.20/8.90, Tctl 69.6 °C, MemAvailable 38,063,552 KiB recorded in the metas). Nothing ran; the co-runner never started. That is the guard working, recorded here as evidence, not a failure of the slice.
- A waiter (`j023_wait.sh`, tmux session `j023wait`, started 08:36 EDT) polls until the S-093 driver and all its oracle processes are gone, then runs idle → loaded back-to-back through the same guard.

## 5. Results

PENDING — legs not yet run at doc-draft time (S-093 live). This section is completed from `~/j023/run_idle.log` / `run_loaded.log` + metas + `j023_analyze.py` output when the waiter fires, and the slice's status (CLOSED vs blocked-with-reason) is decided on that evidence alone.
