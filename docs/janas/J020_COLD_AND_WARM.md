# J-020 — Cold and Warm Runs, Measured

**Slice:** J-020 (Part II — Models Bigger Than Memory), Project Aesir Janas clean-room road.
**Roadmap text:** "First-token and steady-state behaviour with a cold cache vs warm; the warm-up pass design (predictable early experts pre-fetched during prompt reading)."
**Built + measured:** 2026-10-31 ~04:36–05:2x EDT. Cache-layer replay on the VM (light compute only, MemAvailable ≈ 0.44–0.9 GB, no inference); disk legs on **purplelongship** (Ryzen 9 / RTX 2060 laptop line, NVMe, kernel 7.0.0-38-generic). **No Janas material was used or needed** — this slice stands on J-015/J-016/J-017/J-018/J-019 evidence; the clean-room law was not engaged.
**Spec stood on:** J-017 §5.2 + the J-017 J-020 contract (cold/warm always reported separately; warm-up spends inside the same cache cap), J-018 (the real `ExpertCache` module), J-019 (the streaming discipline whose miss-stream cost this slice prices).

---

## 1. Method — what "cold" and "warm" mean here, honestly

Aesir still has **no MoE forward/loader** (the J-018/J-019 integration gap, unchanged), so there is no live first-token latency to measure and none is claimed. Cold/warm behaviour is measured at the layer this road has actually built — the expert cache + reader — by replaying the **J-016 measured OLMoE trace** (577 tokens, 73,856 accesses, 6 prompts + 4 greedy gen tokens) through the **real J-018 Mojo `ExpertCache`** (`j020_replay.mojo`, budget = 512 pairs × mean scaled size 3,720 = 1,904,640 scaled bytes, the J-016/J-018 construction; sizes are header expert bytes ÷ 1024, exact). Four runs:

- **cold** — segmented policy, fresh cache, full session.
- **warm** — segmented policy, the *same* cache instance, session replayed immediately (a second session on a warm cache).
- **prose_cold** — segmented, fresh cache, the prose prompt alone (71 tokens): the single-short-prompt case that never reaches steady state.
- **lru_cold** — LRU baseline, fresh cache, full session (cross-check against J-016/J-018).

The replay's exact miss streams (`miss_cold.csv` 17,691 misses, `miss_warm.csv` 15,824) were then replayed over the real OLMoE file on purplelongship under the J-019 verdict discipline (§4). Warm-up predictors were evaluated two ways (§3): policy-free leave-one-prompt-out coverage, and a cache-level simulation through a Python replica of the J-018 module — the replica was **validated exact** against the Mojo replay before any simulation number was trusted (§2).

Full-scale byte figures below are scaled bytes × 1024, exact by construction.

## 2. Replica validation (PROVEN, VM)

`j020_validate_replica.py` compares the Python replica (`j020_policy.py`) against the Mojo replay per token (hits/misses/bypasses/streamed), per run (exact miss-stream equality), and on run totals. Result, reproduced identically on **four consecutive full runs** during this slice's closure:

```
cold:       EXACT MATCH (hits=56165 misses=17691 streamed=65896320)
warm:       EXACT MATCH (hits=114197 misses=33515 streamed=124873008)
prose_cold: EXACT MATCH (hits=4877 misses=4211 streamed=15682608)
lru_cold:   EXACT MATCH (hits=54691 misses=19165 streamed=71264496)
REPLICA VALIDATION: PASS — replica is exact on all four runs
```

(warm totals are cumulative over both passes in both implementations, as the validator documents.) One earlier validation invocation during closure reported a mismatch that no subsequent run reproduced (4/4 exact passes followed, including per-token miss sets); it is recorded here rather than hidden, and no number in this doc rests on that single invocation. The /tmp working artefacts of the original replay were lost to a tmpfs wipe during closure; everything load-bearing is banked in the repo beside this doc (replay source, miss streams, warm-up results JSON, all scripts), and the access streams are regenerable from `j020_flatten.py` + the J-016 trace in campaign records.

## 3. Cold vs warm at the cache layer (MEASURED — replay through the real module)

Run totals (segmented policy unless noted; full-scale bytes = scaled × 1024):

| Run | Accesses | Hit rate | Misses | Cold misses | Bypasses | Streamed (full-scale) |
|---|---:|---:|---:|---:|---:|---:|
| cold (session) | 73,856 | 0.760 | 17,691 | 1,024 | 8,149 | 67,477,831,680 B |
| warm (2nd session, same cache) | 73,856 | 0.786 | 15,824 | — (0 new pairs) | 6,829 | 60,392,128,512 B |
| prose_cold (71 tok alone) | 9,088 | 0.537 | 4,211 | 975 | 2,295 | 16,058,990,592 B |
| lru_cold (session) | 73,856 | 0.740 | 19,165 | 1,024 | 0 | 72,974,843,904 B |

Per-phase behaviour (from the replay's per-token lines):

| Window | Cold hit rate | Cold streamed/token | Warm hit rate | Warm streamed/token |
|---|---:|---:|---:|---:|
| Token 0 | 0/128 hits — 487,587,840 B streamed | 487,587,840 B | 94/128 hits | 130,056,192 B |
| First 8 tokens | 0.179 | 400,416,768 B | 0.763 | 116,484,096 B |
| First 32 tokens | 0.358 | 313,032,192 B | 0.733 | 130,652,160 B |
| Last 100 tokens (steady state) | 0.740 | 127,555,338 B | 0.743 | 125,977,559 B |
| Whole session | 0.760 | 116,945,982 B | 0.786 | 104,665,734 B |

**The cold/warm story, in plain terms:**

1. **The first token is pure cold cost.** From an empty cache, token 0 hits nothing: all 128 routed pairs stream, 487,587,840 B — exactly J-015's per-token cold ceiling. On a warm cache the same token streams 130,056,192 B (−73.3 %): 94 of 128 pairs are already resident. First-token cost is therefore a *cache-state* number, never a single figure — J-017's rule (always report cold and warm separately) is now measured, not just stated.
2. **Warmth is worth less than intuition says, because the cache is small against the working set.** A warm cache lifts the whole-session hit rate only 0.760 → 0.786 and cuts streamed bytes by 10.5 %. The reason is J-016's headline restated: the working set is all 1,024 pairs and the cache holds 512 — by the second session the cache's contents have substantially turned over (18,025 evictions across the warm pass). Warmth pays at the *start* of a session (first-8 hit rate 0.179 → 0.763) and barely at steady state (0.740 → 0.743).
3. **Steady state is a plateau, not a climb.** Cold-run streamed/token falls from 487.6 MB (token 0) through 313.0 MB (first 32) to ≈127.6 MB over the last 100 tokens — within 1 % of J-016's ≈126.4 MB/token at cap 512. There is no slow warm-up curve to exploit beyond the first few dozen tokens; the cache reaches its working regime almost immediately and stays there.
4. **A single short prompt never gets warm.** prose_cold (71 tokens, fresh cache) ends at hit rate 0.537 and 226.2 MB/token — it pays cold prices for most of its life and finishes before steady state. Short single-shot use is the cold case, permanently. This is the regime the warm-up pass (§4) exists for.
5. **The segmented policy's early behaviour is its price and its payoff.** In the first 8 cold tokens LRU actually hits *more* (0.492 vs 0.179) — the frequency gate bypasses 351 first-touch experts LRU would have admitted. By session end the ordering inverts (segmented 0.760 vs LRU 0.740; streamed 67.48 GB vs 72.97 GB): probation costs early hits to buy steady-state ones. Any warm-up design must therefore pre-load into the **main** segment (as §4's preload does), not probation, or the gate will bypass its own warm-up.

## 4. The warm-up pass — design and verdict (SIMULATED on the validated replica; structure MEASURED from the trace)

**Design (as evaluated):** during prompt reading — before the first token's experts are demanded — a predictor set of (layer, expert) pairs is streamed into the cache's main segment *inside the same hard cap* (J-017's constraint), charged byte-for-byte against the run: prefetch bytes count as streamed, entries compete for the same 512-pair budget, and a prefetched entry evicted before its first use is counted as pure loss. Candidates, all built **leave-one-prompt-out** (the held-out prompt never contributes to its own predictor):

- **GLOBFREQ-n** — the n most frequent pairs across the other five prompts.
- **FIRSTTOK-128** — pairs ranked by how often they appear in the other prompts' *first tokens*.
- **EARLY8-128** — pairs ranked by frequency in the other prompts' first 8 tokens.
- **PERLAYER2-32** — the 2 most common first-token experts per layer (32 pairs).
- **ORACLE-128** — the held-out prompt's own first token: the bound no predictor can beat.

**Structure first (why any of this could work):** first-token demand is *not* random across prompts — two prompts' first tokens share **111.5 of 128 pairs on average** (min 104, max 118), and in 14 of 16 layers at least 4 of 6 prompts agree on the same top-1 expert at token 0. Consecutive-token recall is only 0.285, and global frequency is flat (top-128 pairs cover just 31.4 % of all accesses) — so predictability lives specifically in *session starts*, not in the stream at large. That is exactly the warm-up shape: a start-of-session phenomenon.

**Coverage (LOO means):**

| Candidate | Prefetch | Token-0 coverage | Early-8 coverage | Waste |
|---|---:|---:|---:|---:|
| GLOBFREQ-64 | 244,424,704 B | 0.152 | 0.085 | 0.042 |
| GLOBFREQ-128 | 487,858,176 B | 0.283 | 0.171 | 0.042 |
| GLOBFREQ-256 | 973,283,328 B | 0.527 | 0.342 | 0.036 |
| FIRSTTOK-128 | 487,227,392 B | **0.888** | 0.220 | 0.009 |
| EARLY8-128 | 485,515,264 B | 0.382 | 0.185 | 0.042 |
| PERLAYER2-32 | 121,896,960 B | 0.232 | 0.057 | 0.000 |
| ORACLE-128 | 487,587,840 B | 1.000 | 0.234 | 0.000 |

**Cache-level simulation (LOO means, segmented replica at cap 512, prefetch charged, cap pressure counted):**

| Candidate | Net saving vs no warm-up | Token-0 streamed | Prefetched used resident | Evicted before use | Never accessed |
|---|---:|---:|---:|---:|---:|
| GLOBFREQ-64 | +815,431,680 B (4.95 %) | 487.6→412.4 MB | 61.3 / 64 | 0.0 | 2.7 |
| GLOBFREQ-128 | +1,978,925,056 B (12.02 %) | 487.6→349.6 MB | 122.7 / 128 | 0.0 | 5.3 |
| FIRSTTOK-128 | +1,658,454,016 B (10.07 %) | **487.6→57.9 MB** | 126.8 / 128 | 0.0 | 1.2 |
| EARLY8-128 | **+2,336,505,856 B (14.19 %)** | 487.6→302.9 MB | 122.7 / 128 | 0.0 | 5.3 |
| PERLAYER2-32 | +297,394,176 B (1.81 %) | 487.6→375.1 MB | 32.0 / 32 | 0.0 | 0.0 |
| ORACLE-128 | +1,721,671,680 B (10.45 %) | 487.6→0 MB | 128.0 / 128 | 0.0 | 0.0 |

**Verdict: ADOPT-BOUNDED.** A warm-up pass pays on this evidence, under three bounds:

1. **Predictor = first-token frequency (FIRSTTOK shape), sized ≈128 pairs (¼ of the 512-pair cap).** It captures 88.8 % of token 0 (vs the oracle's 100 %) and cuts first-token streamed bytes by 88 % (487.6 MB → 57.9 MB) — the single largest first-token reduction available from any honest predictor, and the metric the warm-up exists to move. Its total-session net (+10.07 %) even sits beside the oracle's (+10.45 %): on whole-session bytes there is almost nothing left for a better predictor to win, because steady state dominates the session.
2. **EARLY8 is the better *bytes* predictor but the worse *first-token* one** (+14.19 % net, token-0 only →302.9 MB). The design therefore records a split decision: if the optimisation target is first-token latency, FIRSTTOK; if it is total streamed bytes, EARLY8. The shipped default is FIRSTTOK (the roadmap's stated purpose is first-token behaviour), with EARLY8 named as the measured alternative for J-024/J-025 to re-tournament with prefetch machinery real.
3. **Hard bounds:** prefetch ≤ ¼ of the cache cap (at 256 pairs / ½ cap, GLOBFREQ's coverage gain no longer justifies the resident set it displaces — and every candidate at 128 already shows evicted-before-use = 0.0 only because 128 fits alongside the early working set); preload lands in the **main segment with the predictor's frequency evidence attached** (probation admission would bypass it, §3.5); prefetch bytes are charged to the same streamed-bytes accounting as demand misses, so a bad predictor shows up in the run's own statistics instead of hiding. Global-frequency alone (GLOBFREQ-128: token-0 coverage 0.283) is **rejected** as the predictor — session-start structure, not global heat, is what is predictable. Per-layer top-2 is a viable low-cost fallback (32 pairs, zero waste, +1.81 %) where a 128-pair budget is unavailable.

Honesty on the sim: these are **SIMULATED** numbers — the replica is proven exact against the real module on the four replay runs, and the sim replays held-out prompts through that replica with charged prefetch; but no live engine performed a warm-up (there is no MoE forward to perform one in), and the predictor's evidence base is five prompts of the same six-prompt trace. The verdict is a design decision for the integration slices to implement and J-024/J-025 to re-measure live, not a shipped behaviour.

## 5. The disk leg — what cold vs warm costs in wall time (MEASURED, purplelongship)

Harness `j020_disk_bench.py` (filed beside this doc; results `j020_results.jsonl`): the replay's real miss streams expanded to slabs at directory-true offsets over the J-015-pinned OLMoE Q4_K_M file (sha256 re-verified on-box this run: `8c310f1435a1222338fd2d3d974975be9cd908180b644bab0c2a94da1ac32f3f`), read under the J-019 verdict discipline only (explicit pread + next-slab readahead). Cold page state is measured, not hoped (POSIX_FADV_DONTNEED evict → mincore resident fraction recorded). Machine state: the legs ran in a guarded idle gap of the 204 road — its S-090 census process had finished before the first leg, an in-harness guard confirmed no 204 worker process at start (after one true abort and one false-positive abort on a stale idle tmux shell, fixed in the harness and recorded), loadavg ≈ 0.5–0.8, Tctl 44.2 °C at start.

| Leg | Misses | Slabs | Bytes | Wall (s) | GB/s | Checksum | Resident before |
|---|---:|---:|---:|---:|---:|---:|---:|
| cold stream, cold page cache | 17,691 | 53,073 | 67,477,831,680 | 22.513 | 2.997 | 114906799452623 | **0.0** |
| cold stream, warm page cache | 17,691 | 53,073 | 67,477,831,680 | 21.029 | 3.209 | 114906799452623 | — (warm by construction) |
| warm stream, cold page cache | 15,824 | 47,472 | 60,392,128,512 | 20.581 | 2.934 | 103098345931090 | **0.0** |

The two cold-stream legs agree on checksum (the stream is the stream; only the page state differs), and each leg's byte total equals the cache layer's streamed total for that run to the byte (§3) — the disk leg read exactly what the cache said it missed, nothing else.

**Reading the table:**

- **Cache warmth is worth 8.6 % of disk wall on this session.** The warm cache's smaller miss stream (15,824 vs 17,691 misses, −10.5 % bytes) costs 20.581 s cold-page vs the cold stream's 22.513 s. The saving tracks the byte saving — at the disk, a hit is worth exactly the slabs it does not read.
- **Page-cache warmth is worth less than cache warmth here:** re-reading the identical cold stream with a warm page cache saves only 6.6 % (21.029 s). This demand stream touches most of the 4.2 GB file with little within-pass re-read locality, so the second pass is bounded by consume + readahead, not by the device — the same consume-bound shape J-019 found in its warm legs. An engine that "warms up" only the OS page cache and not its own expert cache buys the smaller of the two wins.
- **Absolute rates (2.93–3.21 GB/s) run above J-019's cold pread_ra figure (1.470 GB/s)** because the workload differs, not because the discipline changed: J-019 replayed a 16-token LRU demand (2,742 slabs, near-random), while J-020's full-session segmented streams carry strong sequential locality across 47–53k slabs, which readahead converts into device throughput. The two results are consistent, not contradictory — locality is the difference, and it is named here rather than averaged away.

## 6. Honesty ledger

- **PROVEN:** the replica is exact against the real J-018 module (four consecutive validation passes: per-token values, exact miss streams, run totals, all four runs). The cold/warm/prose/LRU totals are the real Mojo module's own output.
- **MEASURED:** cold-vs-warm cache-layer behaviour (§3) — a trace replay through the real module, on the J-016 measured trace; warm-up *structure* statistics (§4: first-token overlap, per-layer agreement, recall, frequency coverage) — computed directly from the trace. Disk walls (§5) — single-pass walls on an idle machine in a guarded gap; read as measured comparisons for these two streams, not as a soak or a universal constant.
- **SIMULATED:** the warm-up cache-level verdict (§4 table) — exact-replica simulation with charged prefetch, LOO predictors; no live warm-up exists.
- **NOT PROVEN:** any live first-token or steady-state *latency* (no MoE forward/loader exists to time — the integration gap carried from J-018/J-019, unchanged); warm-up benefit on any model other than OLMoE, any prompt set beyond the J-016 six, or decode-heavy sessions (the trace carries 4 gen tokens); Granite/`qwen2moe` cold/warm behaviour (no traces — J-022/J-032 roads); whether prefetch-during-prompt-reading overlaps usefully with a real prompt pass (there is no prompt pass yet to overlap with — J-025's question, with §4's verdict as its starting evidence).

**Integration gap (recorded, not faked):** Aesir has no MoE forward/loader yet. J-020's outputs to the integration slices: (a) cold and warm are different operating regimes with different first-token costs — any future live benchmark that reports one number for both is wrong by ≈3.7× on token 0; (b) the warm-up design (§4 verdict: FIRSTTOK-128-class predictor, main-segment preload, ≤¼ cap, charged bytes) is decided and ready to implement when the forward lands; (c) the J-019 reader discipline prices the cold stream and the warm stream differently at the disk (§5) — the cache state is a disk-scheduling input, not just a memory statistic.

## 7. Artefacts

Filed beside this doc in `docs/janas/`: `j020_replay.mojo` (the Mojo replay through the real module), `j020_flatten.py` (trace → access streams), `j020_policy.py` (the validated replica incl. the preload admission path), `j020_validate_replica.py`, `j020_warmup_analysis.py`, `j020_warmup_results.json` (full LOO rows), `miss_cold.csv` / `miss_warm.csv` (the real miss streams), `j020_disk_bench.py` (+ its `j019_disk_bench.py` import), `j020_results.jsonl` (disk legs). Campaign copies of all scripts live in `~/workspace/model-tests/janas/`.
