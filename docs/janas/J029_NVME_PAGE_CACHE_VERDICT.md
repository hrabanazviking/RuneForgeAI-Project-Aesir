# J-029 — NVMe vs Page Cache Verdict

**Slice:** J-029 (Part II — Models Bigger Than Memory), Project Aesir Janas clean-room road.
**Roadmap text:** "On purplelongship's storage, the streaming path vs OS paging, final numbers; the design note updated with the verdict."
**Executed:** 2026-10-31 ~11:40 EDT. **Verdict / synthesis closure — no new on-box leg was run this slice, and §6 states why plainly.** Every number below was MEASURED earlier in this road on the same storage, and every number was re-verified this slice against the filed results artefacts (`j019_results.jsonl`, `j020_results.jsonl`, the J-023 harvest files), not taken from prose alone.
**Base:** branch `yrsa/janas-j029` from `yrsa/janas-j028` tip `4118272cdae92ad0c13a9851fe6b7fbfb3b2a0e4` (ls-remote verified before branching). Origin/main `ba7ee09b6b4d09967b571f2f39714e9119dc3772` untouched by this slice.
**No Janas material was used or needed** — this slice stands entirely on Aesir's own J-017/J-019/J-020/J-023 evidence; the clean-room law was not engaged beyond that record. Hailo untouched/parked. No README touched.

**Headline verdict: the streaming path wins, and the question's either/or framing dissolves.** On purplelongship's NVMe, Aesir's settled disk discipline for streamed experts is **explicit pread of exactly the missed slabs + next-slab readahead advice** — the `stream_reader.mojo` discipline built in J-019. Plain mmap paging — letting OS page faults drive demand — is the **slowest cold discipline measured** (2.874 s vs 2.364 s for the streaming path on the identical demand, −17.7 % of wall) and is **not** the streaming path. The winning path still reads *through* the page cache (pread is buffered I/O; its warm legs run at page-cache speed) — what loses is fault-driven paging as the demand mechanism, not the page cache as a cache. O_DIRECT, the one discipline that truly bypasses the page cache, stays **rejected** (cold tie, no warm state, +11,231,232 B over-read). Async I/O remains **NOT PROVEN**.

---

## 1. The question and the verdict rule — stated up front

**Question.** For the routed-expert miss stream of a bigger-than-memory MoE model on purplelongship's storage, which discipline should serve the misses:

- **(A) The streaming path** — explicit `pread` of exactly the missed slabs at directory-true offsets, with readahead advice issued for the next slab while the current slab is consumed (`stream_reader.mojo`, J-019: `read_slab` + `advise_willneed`, `readahead(2)` as the inline equivalent, `POSIX_FADV_SEQUENTIAL` at open); or
- **(B) OS paging** — plain `mmap` of the model file (Aesir's current loader shape for resident weights), where page faults and the kernel's own readahead window decide what moves, when, and in what granularity?

**Verdict rule (applied as stated here, before the table).** The streaming path is settled as the design's disk discipline iff all four hold on the measured evidence: **(i)** it wins the **cold** case at bench scale — cold is the primary case, because a bigger-than-RAM model lives cold, and warm rankings in this road's harness are consume-bound and indicative only; **(ii)** at session scale its absolute numbers do not collapse relative to bench scale (a discipline that only wins a 16-token bench would not settle a design); **(iii)** the warm case shows no penalty beyond the consume-bound noise band — the winner may not buy its cold win with a warm loss; **(iv)** the assembled path (J-018 cache + J-019 reader, J-022/J-023) shows no thrash collapse under load, by J-023's pre-registered definition. A discipline that bypasses the page cache (O_DIRECT) must beat the winner **outright cold** to be considered at all, because it pays for its bypass with the loss of any warm state. If any of (i)–(iv) had failed, this slice would have recorded the discipline question as still open rather than forcing a verdict.

## 2. Evidence base and provenance — every number's origin

All measurements are on **purplelongship** (Ryzen 9 / RTX 2060 laptop line), **NVMe**, kernel **7.0.0-38-generic**, over one file:

- **File:** OLMoE-1B-7B-0924-Instruct Q4_K_M, 4,213,512,672 B, sha256 `8c310f1435a1222338fd2d3d974975be9cd908180b644bab0c2a94da1ac32f3f` — the J-015 pin, re-verified on-box in both J-019 and J-020.
- **Demand:** the J-016 router trace (`j016_trace_olmoe.jsonl`, sha256 `85e1d2413cbfcd43516a03d8463c7266d486cf0f0d0a6ed3104d09111facf99a`, re-verified in J-019) — real router demand, never a synthetic sequential read, per J-017 §6.2's binding contract.
- **Cold is measured, not hoped:** every cold leg first evicts the file with `POSIX_FADV_DONTNEED` and reports the mincore-resident fraction — **0.0 on all 7 J-019 cold legs and on both J-020 cold-page legs**. "Cold" in this road means a verified-empty page cache for the file.
- **Checksums close every leg:** all 12 J-019 demand legs agree on checksum **5887966450294** (the demand stream is the demand stream, whichever discipline reads it); the two J-020 cold-stream legs agree on **114906799452623**, and each J-020 leg's byte total equals the cache layer's streamed total for that run to the byte.
- **Artefacts re-verified this slice:** `j019_results.jsonl` sha256 `040fcc7eeb08d531e72edbb1e7667c20ed4dcadb3321ef58dff2565bd90323da` (matches the hash J-019's own doc records); `j020_results.jsonl` sha256 `dae5492fec7a9279734e489c46246045c7e599afebae77d6a816962d7f6e5c76`; J-023 harvest — `j023_analyze_output.txt` sha256 `e5d0ba8c909890546e66eecbe5810754d73f364639e85082ed89e38ca74af710`, `run_idle.log` `811b77594ce5dd9077948bb4949a48bbcbcb69fbf0c1474e0df7a73e0888bffd`, `run_loaded.log` `2cbb3c3380be4e5876d663461f18d54fbfaacb9f77c0311fd57e548a68c363e8`. Every figure in §3 was read back out of these files during this slice; the derived ratios (percentages, per-token walls) are arithmetic on those filed figures and are shown with their inputs.

The three evidence slices, and what each contributes:

| Slice | Scale | What it measured |
|---|---|---|
| J-019 | Bench: 16 tokens, cap 512 → 2,048 accesses, 914 misses, 2,742 slabs, 3,475,193,856 B | Head-to-head disciplines on the identical demand: seq (ceiling reference), mmap, mmap+madvise-WILLNEED, pread, **pread+readahead(2)**, pipelined advice, O_DIRECT — cold and warm. |
| J-020 | Session: full J-016 session miss streams, 47,472–53,073 slabs, 60.39–67.48 GB | The streaming discipline only, at full-session scale: cold stream / cold page, cold stream / warm page, warm stream / cold page. Prices page-cache warmth vs expert-cache warmth. |
| J-023 | Assembled: live streamed OLMoE session (J-022 vehicle), 512 MiB cache, 67+24 tokens | The assembled streaming path under a bounded browser-class co-runner vs idle: counters, walls, token identity, against the pre-registered thrash definition. |

## 3. Final numbers

### 3.1 Bench scale — the head-to-head (J-019, MEASURED)

Demand legs move 3,475,193,856 B in 2,742 slabs; `seq` moves the whole file (4,213,512,672 B) as a bandwidth ceiling reference. Single-pass walls on an idle machine in guarded gaps of the 204 road (1-min loadavg 0.16–0.38 per leg, Tctl ≤ 58.8 °C) — class **MEASURED** for the cold comparisons; warm deltas **MEASURED-INDICATIVE** (§3.2).

| Strategy | Cold wall (s) | Cold GB/s | Warm wall (s) | Warm GB/s | Slab mean cold (ms) |
|---|---:|---:|---:|---:|---:|
| seq (ceiling ref, whole file) | 2.732 | 1.542 | 1.542 | 2.732 | — |
| mmap (OS paging) | 2.874 | 1.209 | 1.002 | 3.469 | 1.045 |
| mmap + madvise-WILLNEED | 2.792 | 1.245 | 1.018 | 3.414 | 1.016 |
| pread | 2.529 | 1.374 | 1.085 | 3.203 | 0.920 |
| **pread + readahead(2) — the streaming path** | **2.364** | **1.470** | 1.111 | 3.127 | 0.860 |
| pipe (advice thread 8 slabs ahead) | 2.486 | 1.398 | 1.094 | 3.176 | 0.904 |
| O_DIRECT (aligned cover) | 2.363 | 1.471 | 2.338 | 1.486 | 0.860 |

Margins, cold (arithmetic on the filed walls): explicit pread beats plain mmap by **12.0 %** of wall (2.529 vs 2.874 s); adding next-slab readahead beats plain mmap by **17.7 %** (2.364 vs 2.874 s) and plain pread by **6.5 %**. `madvise` on the mmap path buys **~2.9 %** — the fault path, not the advice, is mmap's cost. O_DIRECT's cold wall ties the streaming path (2.363 vs 2.364 s) but over-reads **11,231,232 B** (0.32 % of demand) on aligned covers, in both its legs — and see its warm row.

### 3.2 Warm state — convergence, and why mmap's warm "lead" is not a win (J-019, MEASURED-INDICATIVE as a ranking)

Warm, every page-cache strategy converges into **3.127–3.469 GB/s** — a ±~5 % band around a consume-bound ceiling (the harness's crc32 consume dominates once no disk wait remains). Inside that band mmap's nominal lead (3.469 GB/s) is an artefact of skipping a copy the real engine cannot skip: a cache miss must land bytes in a cache-owned buffer, which is exactly what pread does and exactly what a faulted mmap page is not. The streaming path's warm figure (3.127 GB/s) sits inside the same band — **rule (iii) holds: no warm penalty beyond noise.** O_DIRECT stands outside the band entirely: its "warm" leg (2.338 s / 1.486 GB/s) is its cold leg repeated, because bypassing the page cache means there is no warm state to have. Under the §1 rule it needed an outright cold win to offset that; it tied. **Rejected, reaffirmed.**

### 3.3 Session scale — the streaming path at full size (J-020, MEASURED)

The replay's real miss streams over the same pinned file, read under the streaming discipline only (pread + next-slab readahead), in a guarded idle gap (loadavg ≈ 0.5–0.95, Tctl 44.2 °C at start):

| Leg | Misses | Slabs | Bytes | Wall (s) | GB/s | Resident before |
|---|---:|---:|---:|---:|---:|---:|
| cold stream, cold page cache | 17,691 | 53,073 | 67,477,831,680 | 22.513 | 2.997 | 0.0 |
| cold stream, warm page cache | 17,691 | 53,073 | 67,477,831,680 | 21.029 | 3.209 | — (warm by construction) |
| warm stream, cold page cache | 15,824 | 47,472 | 60,392,128,512 | 20.581 | 2.934 | 0.0 |

What this leg proves, and what it does not:

- **Rule (ii) holds.** The streaming path does not collapse at session scale — it improves: 2.93–3.21 GB/s against the bench's cold 1.470 GB/s, because the full-session segmented streams carry strong sequential locality across 47–53k slabs that readahead converts into device throughput (J-020's own reading; the workloads differ, the discipline is the same — the two results are consistent, not contradictory).
- **Page-cache warmth is worth less than expert-cache warmth.** Re-reading the identical cold stream with a warm page cache saves **6.6 %** of wall (21.029 vs 22.513 s); the warm expert cache's smaller miss stream saves **8.6 %** of wall (20.581 s) on **10.5 % fewer bytes**. A design that "warms up" only the OS page cache buys the smaller of the two wins — the cache, not the pager, is where warmth pays.
- **Honest limit:** J-020 ran **no mmap leg** — there is no session-scale OS-paging wall in this road's evidence, and none is claimed. The head-to-head verdict rests on §3.1's identical-demand bench comparison; §3.3 prices the winner at scale and prices page-cache warmth. A session-scale head-to-head remains **NOT PROVEN** (§7) and is not needed for the verdict under the §1 rule, which asked for non-collapse at scale, not a second head-to-head.

### 3.4 Under load — the assembled path (J-023, MEASURED; walls MEASURED-INDICATIVE, single run per leg)

The J-022 streamed OLMoE session — resident set via the ordinary GGUF mmap, routed experts only through the J-018 cache + J-019 StreamReader — run idle and under J-023's bounded co-runner (4 CPU spinners + a capped 10 GiB touched-page holder; load **SIMULATED** by design, a named stand-in for browser-class load), in the first clean gap after the 204 road's S-093 exited (waiter-fired; Tctl 55.0→66.9 °C idle leg, loaded leg ending 82.4 °C under the co-runner's own heat):

| Leg | Hit | Bytes streamed | Bytes/token (91 tokens) | Wall/token | Prefill | Decode |
|---|---:|---:|---:|---:|---:|---:|
| idle | 0.258 | 32,948,699,136 | 362,073,616.9 | 0.4113 s | 28.04 s | 9.39 s |
| loaded | 0.258 | 32,948,699,136 | 362,073,616.9 | 0.4353 s | 29.47 s | 10.14 s |

Every cache/stream counter is **bit-identical** between legs (accesses 11,648 / admissions 1,265 / promotions 192 / evictions 1,125 / bypasses 7,376 / evicted-before-reuse 3,387; StreamReader reads 25,923, advice calls 34,945 in both), generated ids are identical in both legs and to J-022's post-fix run, and the analyser's verdict against the pre-registered thrash definition is **NO THRASH — gentle degradation**: wall/token ratio **1.058** (+5.8 %; prefill +5.1 %, decode +8.0 %). **Rule (iv) holds.**

Bearing on this slice's question, stated with its limit: the streaming path's demand behaviour (what is read, in what order, at whose decision) is **invariant under load** — load moved walls only, through CPU contention and thermals. The limit, recorded in J-023's own closure and repeated here because it bounds the page-cache reading: the co-runner's holder channel through the page cache is **NOT PROVEN to have bitten** (major faults 1,535 on the cold idle leg vs 2 on the loaded leg is an ordering artefact — the idle leg ran first, cold), so the observed +5.8 % is consistent with CPU contention + thermals, **undecomposed**. J-023 therefore proves the assembled path does not collapse under load; it does not isolate a page-cache-pressure component, and this verdict does not borrow it as one.

## 4. The verdict (DECIDED — settled for the design)

All four clauses of the §1 rule hold on the measured evidence — (i) cold win at bench scale, +17.7 % of wall over OS paging on identical demand; (ii) session-scale non-collapse, 2.93–3.21 GB/s at 47–53k slabs; (iii) warm convergence with no penalty beyond the consume-bound band; (iv) no thrash collapse of the assembled path under load, degradation wall-only at +5.8 %:

1. **Aesir's streaming path is explicit pread of exactly the missed slabs + next-slab readahead advice** — the `stream_reader.mojo` discipline (`read_slab` at directory-true offsets + `advise_willneed` / `readahead(2)`, `POSIX_FADV_SEQUENTIAL` at open), called on a J-018 expert-cache miss. This was J-019's decided verdict at bench scale; J-020's session numbers and J-023's under-load numbers are the full-scale evidence J-019 §8 reserved for this slice, and they confirm it. **The question J-017 left open (§6.2: I/O mechanism, readahead depth) is now closed.**
2. **Plain mmap paging is not the streaming path.** It is the slowest cold discipline measured; `madvise` does not rescue it (~2.9 %); its warm lead is a harness artefact the engine cannot realise. Scope note, so the verdict is not over-read: mmap remains how the **resident set** is loaded in the assembled session (J-022/J-023 vehicle) — residency is a one-time, every-token load, not a demand stream. The verdict governs the **streamed set's miss path**, which is the traffic that scales with tokens.
3. **The page cache is a cache, not a pager — the title's either/or dissolves.** The winning discipline reads through the page cache and takes its warm band (3.13–3.47 GB/s) when the bytes are resident; what it refuses is letting page faults decide the demand stream. Page-cache warmth is a real but second-order effect (6.6 % at session scale, §3.3) — worth having, never worth designing around; expert-cache warmth is the larger win (8.6 % wall on 10.5 % fewer bytes).
4. **O_DIRECT stays rejected** (cold tie 2.363 vs 2.364 s; no warm state, 1.486 GB/s "warm"; +11,231,232 B over-read; aligned-cover machinery around 32-byte-aligned slabs). No later slice re-litigates it without new evidence, per J-019 §6.
5. **Readahead depth, as built, is one slab** (next-slab advice while the current slab is consumed; the 8-slab threaded variant, `pipe`, measured between plain pread and the inline form cold — 2.486 s — and is not the built discipline). Deeper lookahead is a prefetch question (J-025 measured and rejected router-shadow prefetch on other grounds); nothing in this verdict licenses reading bytes the router has not demanded.

## 5. The design note, updated

J-017's design doc gains a new **§9 — J-029 verdict addendum**, recording this verdict as the design's settled disk discipline and closing §6.2's open I/O-mechanism question, cross-pointing to this doc for the numbers. The addendum is appended text only — no existing line of the design is altered.

One gap had to be repaired to do that, recorded here and in §8: **the J-017 design doc was not present in this branch line at all.** It lives only on branch `yrsa/janas-j017` @ `4225e639` (the J-018 line branched from origin/main, not from J-017, and no later slice carried the file forward). The doc filed in this slice's tree is that branch's file **verbatim** — sha256 `cf0e982b425897f6e19f67158d446e2458449fe01540d5aa7e103d42fab71c8a`, byte-identical to the campaign copy in `~/workspace/model-tests/janas/` — plus the §9 addendum. Nothing was rewritten; the design's own text is preserved exactly.

## 6. No new on-box leg was run this slice — stated plainly

**No confirmation leg ran, and no number in this doc comes from this slice's run.** The reasons, both checked this slice:

- **purplelongship was occupied for the whole run.** The 204 road's S-095 is live there: its state file's 11:32 EDT tick records the driver (`python3 ~/s095_driver.py all`, PID 1952430, tmux `s095` created 10:44:45 EDT) alive with a tf leg in flight (PID 2078802, ~9:00 CPU time, 398 % CPU, Tctl 69.5 °C) and no DONE marker. The coordination law forbids running a disk-contending leg beside a live 204 run, and this worker has no device route to independently re-check on-box processes — the 204 heartbeat is the record relied on, named as such (the same posture as J-024/J-028).
- **The VM cannot substitute.** MemAvailable measured this slice ≈ 613 MB — far below the 5,500 MB inference gate; no VM inference or heavy leg is honest here. /tmp filled to 100 % during this run (a 509 MB pytest tree belonging to other work, not this slice's) — nothing was deleted to free it; this slice's work needed no /tmp.

This closure shape is the commissioned one for a verdict slice: J-019 and J-020 already measured this exact storage, this exact file, and this exact demand, cold-verified and checksum-closed; J-023 measured the assembled path under load. A single fresh confirmation pair (streaming pread+readahead vs plain mmap, cold, J-019 harness discipline, checksums agreeing) would re-measure what is already measured, at single-run **MEASURED-INDICATIVE** weight — it remains a legitimate spot-check for any future idle gap, and J-033's soak owns full-scale re-measurement, but the verdict does not wait on it and does not borrow strength from a run that did not happen.

## 7. Honesty ledger

- **PROVEN:** J-019's module unit test (slab reads byte-exact, advice counted separately, EOF/short reads refused uncounted — J-019 §1); the J-023 token identity (loaded ids == idle ids == J-022 post-fix ids, all 24); that the numbers in §3 exist in the filed artefacts exactly as quoted (re-read and re-hashed this slice, §2).
- **MEASURED:** the J-019 cold bench comparisons (identical demand, cold verified at resident fraction 0.0, checksums agreeing across all 12 demand legs, idle guarded gaps, machine state recorded per leg); the J-020 session disk walls (single-pass walls on an idle machine in a guarded gap — measured comparisons for these two streams); J-023's cache/stream counters under load (bit-identical, both legs).
- **MEASURED-INDICATIVE:** all warm-leg rankings (consume-bound harness, §3.2); the J-020 absolute GB/s rates as a general figure (locality-dependent, §3.3); J-023's wall/token degradation (+5.8 % — single run per leg, idle leg in S-093's cooldown wake, undecomposed between CPU contention and thermals); anything a future single confirmation leg would add.
- **NOT PROVEN:** async I/O (io_uring / POSIX AIO — no binding in Mojo 1.0 or this tree; the measured overlap win is captured synchronously by one-slab-ahead advice, J-019 §6); a session-scale mmap-vs-streaming head-to-head (no J-020 mmap leg exists, §3.3); the page-cache-pressure component of J-023's degradation (holder channel not proven to have bitten, §3.4); decode-heavy demand's discipline behaviour (the J-016 trace is prompt-phase with 4 generation tokens — a different lookahead depth could in principle argue there, on evidence that does not yet exist); any other model family, file, or NVMe (Granite/`qwen2moe` slab geometry differs — the discipline is offset-agnostic by construction, its numbers here are OLMoE-on-this-NVMe numbers); any tok/s claim for the disk discipline itself (walls here are read/consume walls and assembled-session walls, not a disk-only token rate); a fresh J-029 confirmation leg (§6 — not run, by coordination law, not by omission).

## 8. Defects found

- **J-017 design doc missing from the J-018+ branch line — fixed in scope.** See §5: the file existed only on `yrsa/janas-j017` @ `4225e639`. This slice imports it verbatim (sha256 above) and appends the §9 verdict addendum, so the design note and its verdict now travel together on the road's main line. No line of the imported text was changed.
- **J-023 doc in this branch line is the stale pre-harvest version — recorded, not silently left.** The tree's `J023_STREAMING_UNDER_LOAD.md` still carries its banking-time header ("measurement leg BLOCKED-WITH-REASON") and §5, because J-024 branched from the pre-harvest J-023 tip `6b9dc742`; the harvest that closed J-023 (idle/loaded legs run, analyser verdict NO THRASH, doc §5/§6 completed) banked separately on `yrsa/janas-j023` @ `164306365b3f00c18450954c1a8b58ebbdd320de`. This slice's J-023 numbers were therefore verified against the harvest artefacts (campaign copies in `~/workspace/model-tests/janas/j023_harvest/`, hashed in §2) and the state file's closure entry, not against the stale tree doc. **Immediate next item for the keeper:** reconcile the tree's J-023 doc with the harvested version on `yrsa/janas-j023` @ `16430636` (the same import-verbatim move as §5) so no later slice reads the blocked header as the slice's state. Not done here: replacing another slice's doc wholesale is beyond this slice's named work (the §5 import was required by this slice's own instruction), and it is recorded here, with the exact source, instead of being left unnoted.
- **No defect found in the J-019/J-020 numbers themselves.** Every figure quoted in J-019's and J-020's prose was found in their results files at the quoted value during this slice's re-verification, including the two fields J-019 §7 records as repaired during its own closure (the pipe:warm percentiles are not used by this verdict).

## 9. Artefacts

Filed beside this doc in `docs/janas/`: this document, and `J017_EXPERT_RESIDENCY_DESIGN.md` (imported verbatim from `yrsa/janas-j017` @ `4225e639` + the new §9 verdict addendum — §5). No engine code, harness, or results file is added by this slice: the evidence artefacts (`j019_disk_bench.py`, `j019_results.jsonl`, `j020_disk_bench.py`, `j020_results.jsonl`, the J-023 harvest files) already stand filed under their own slices. Campaign copies of this doc and of the updated J-017 design doc live in `~/workspace/model-tests/janas/`.
