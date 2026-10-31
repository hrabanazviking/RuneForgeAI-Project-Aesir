# J-023 — Streaming Under Load (CLOSED 2026-10-31 — legs harvested from the waiter; NO THRASH, gentle degradation measured)

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

## 5. Results — MEASURED (harvested 2026-10-31 ~09:2x EDT; legs ran 09:08–09:10 EDT through the waiter)

The waiter fired the moment S-093 exited: `WAITER_GAP 2026-10-31T09:08:16-04:00` (S-093's driver had exited cleanly at 09:08:14 EDT, `DRIVER_EXIT=0` per the 204 road's 09:12 heartbeat), then idle → loaded back-to-back through the guard, `WAITER_DONE 2026-10-31T09:09:56-04:00`, both legs `rc=0`. The co-runner ran only for the loaded leg (4 spinners + 10 GiB holder filled, `mem_available_at_start=39,072,579,584`; MemAvailable under load 27,872,244 KiB) and was verified gone afterwards (`corunner_verified_gone`, `CORUNNER stopped cleanly`). Harvested files (this directory; sha256 verified byte-identical between purplelongship `~/j023/` and the filed copies; the `.log` files are banked under `.txt` names per this tree's convention, contents unchanged): `j023_run_idle.txt` (= on-box `run_idle.log`) `811b7759…ffd`, `j023_run_loaded.txt` (= `run_loaded.log`) `2cbb3c33…e8`, `run_idle.meta` `d9f6242f…b6`, `run_loaded.meta` `a4f5eda1…aa`, `j023_waiter.txt` (= `waiter.log`) `74d8a1f9…0e`, `j023_corunner.txt` (= `corunner.log`) `4e16e2c2…78`. The committed analyser (`j023_analyze.py`, run on the harvested logs; output filed as `j023_analyze_output.txt`) prints the table and verdict below.

| Quantity (91 stepped tokens = 67 prompt + 24 generated) | Idle leg | Loaded leg | Ratio |
|---|---|---|---|
| Hit rate | 0.258 | 0.258 | 1.000 |
| Bytes streamed | 32,948,699,136 | 32,948,699,136 | 1.000 |
| Streamed bytes/token | 362,073,616.9 | 362,073,616.9 | 1.000 |
| Prefill wall | 28.04 s | 29.47 s | 1.051 |
| Decode wall | 9.39 s | 10.14 s | 1.080 |
| Wall/token (prefill+decode) | 0.4113 s | 0.4353 s | **1.058** |
| Total engine wall | 37.43 s | 39.62 s | 1.058 |
| `/usr/bin/time` elapsed | 37.91 s | 40.10 s | 1.058 |
| Accesses / hits / misses / cold | 11,648 / 3,007 / 8,641 / 950 | identical | — |
| Admissions / promotions / evictions | 1,265 / 192 / 1,125 | identical | — |
| Bypasses / evicted-before-reuse | 7,376 / 3,387 | identical | — |
| Stream reads / bytes read | 25,923 / 32,948,699,136 | identical | — |
| Generated ids | 24 ids | **identical to idle** | — |

**Cross-check (required by the harvest path): PASS.** The idle leg's generated ids equal J-022's post-fix ids exactly — `187, 187, 510, 1708, 5967, 6225, 327, 247, 33848, 562, 68, 1658, 13, 253, 760, 581, 323, 6574, 1475, 15, 733, 369, 247, 10086` — and the loaded leg reproduces them token-for-token. No divergence to bisect.

**Verdict against the §3 definition, as written: NO THRASH — gentle degradation.** None of (a)–(d) triggers: hit ratio 1.000 (not < 0.5), bytes/token ratio 1.000 (not > 2), ids identical (no functional divergence), loaded run succeeded with wall/token ratio 1.058 (not > 3). The measured degradation is the wall/token ratio itself: **+5.8 % wall under the bounded browser-class load** (prefill +5.1 %, decode +8.0 %). The §3 prior expectation is confirmed by this run: every cache/stream counter is bit-identical between legs — load moved walls only, not counters.

**Machine state and honesty caveats (walls are MEASURED-INDICATIVE, single runs, not baselines):**
- The idle leg is a *post-S-093 cooldown* baseline, not a pristine cold idle: it started 12 s after S-093's exit at loadavg 1.86/2.55/3.33, Tctl +55.0 °C, ending at loadavg 2.98/2.73/3.35, Tctl +66.9 °C, MemAvailable 38,282,652 → 38,126,620 KiB. The loaded leg started at loadavg 2.74/2.68/3.33, Tctl +60.5 °C and ended at loadavg 4.90/3.26/3.50, Tctl +82.4 °C (the co-runner's own heat) — thermal state differs between legs, so the +5.8 % bundles CPU contention, page-cache pressure, and thermal drift together; it is not decomposed.
- Ordering effect, recorded plainly: the idle leg ran first and paid 1,535 major page faults (cold page cache for the GGUF after S-093's long occupation); the loaded leg ran second and paid only 2 major faults despite the 10 GiB holder — in this run the holder did **not** measurably evict the streamed pages, so the page-cache-pressure channel of the load is NOT PROVEN to have bitten; the observed wall cost is consistent with the 4-spinner CPU contention plus thermals. A reversed-order or repeated-leg design would be needed to isolate the memory channel; that is future work, not claimed here.
- Earlier blocked history (kept for the record): both legs were first attempted through the guard at 08:35 EDT → **GUARD_BLOCKED** (S-093 live; co-runner never started), and the slice banked blocked-with-reason at ~08:51 EDT with the waiter armed. S-093's grade phase (54 oracle legs; IQ legs 394–533 s each) was the blocker until its clean exit at 09:08:14 EDT.

## 6. Honesty ledger

- **PROVEN:** the harness mechanics — the guard blocked both legs while S-093 was live (exit 3 ×2, metas recorded, co-runner never started); the three scripts transferred to purplelongship byte-identical (sha256 of the on-box copies match the committed files: `j023_corunner.py` `ce5424e0…5ec1`, `j023_run.sh` `bc26bc6e…6d5`); the waiter (tmux `j023wait`, `WAITER_START 2026-10-31T08:36:14-04:00`) fired in the first clean gap and completed both legs (`WAITER_DONE 2026-10-31T09:09:56-04:00`). **Token identity under load is PROVEN for this run:** loaded ids == idle ids == J-022 post-fix ids, all 24 tokens.
- **SIMULATED (by design):** the co-runner's load class (§2) — a bounded stand-in for browser-class load, never presented as a real browser.
- **MEASURED:** the §5 comparison — hit rate, streamed bytes, and every cache/stream counter identical between legs; wall/token 0.4113 s idle → 0.4353 s loaded (ratio 1.058); verdict NO THRASH against the pre-registered §3 definition, computed by the committed analyser from the harvested logs. Also MEASURED: S-093's occupation of the box and its clean exit (09:08:14 EDT, `DRIVER_EXIT=0`), and both legs' machine state (metas filed).
- **MEASURED-INDICATIVE:** the wall numbers themselves — one run per leg, idle leg measured in S-093's cooldown wake, legs in fixed idle→loaded order, loaded-leg Tctl ending at +82.4 °C. They are a real measurement of these two runs, not a baseline or a tok/s claim.
- **NOT PROVEN:** that the co-runner's 10 GiB holder materially pressures the GGUF page cache on this box (major faults say it did not bite in this run: 1,535 idle vs 2 loaded — an ordering artifact, §5); any decomposition of the +5.8 % into CPU vs memory vs thermal shares; degradation under any other load class, model, prompt, or cache budget; repeated-run variance.
- **Bugs found:** none in the engine (no engine code was touched by this slice; the legs ran J-022's post-fix binary). One harness-design correction made pre-run: the loaded leg re-checks the S-093 guard *after* the co-runner starts and aborts with the co-runner killed, so a gap that closes during co-runner start-up can never turn into co-runner-on-S-093 contention.
