# J-018 — The Expert Cache, Built

**Slice:** J-018 (Part II — Models Bigger Than Memory), Project Aesir Janas clean-room road.
**Roadmap text:** "In-memory cache of streamed experts with eviction by measured reuse (J-016's data chooses the policy), sized to free memory at open, honoured hard cap (the --cache analogue: an Aesir flag + env), statistics out."
**Built:** 2026-10-31 ~03:17 EDT, on the VM (compile + unit tests + offline trace replay only; **no inference anywhere** — VM MemAvailable ≈ 0.4–0.7 GB throughout, purplelongship yielded to the 204 road's live S-087 grade phase, untouched by this slice).
**Spec stood on:** J-017 §4/§5.1/§6.1 (binding D4 contract), J-016's measured trace + simulations, J-015's per-expert byte figures. **No Janas material was used or needed** — J-017 was the spec; the clean-room law was not engaged.

---

## 1. What was built

`aesir_engine/core/expert_cache.mojo` — a standalone, tested engine module in the tree's own style (pure checked arithmetic, `def`/`struct`, error-raising admission, `describe()` evidence strings), plus `aesir_engine/tests/test_expert_cache.mojo`, wired into `aesir_engine/tests/run_all.mojo` as case `memory.expert_cache` beside `memory.checked_span`.

**The integration gap, stated honestly:** Aesir at origin/main `caec4149` still has **no MoE code at all** (J-012/J-016/J-017) — there is no MoE forward path, loader residency split, or CLI surface to integrate a cache into yet. This slice therefore builds the cache as the proven engine those later Part II slices will call, and does **not** fake an integration. Open-time wiring (reading the actual environment/flag into `resolve_hard_cap`, calling `plan_expert_cache_budget` from model open, streaming slabs into entries on a miss) lands with the MoE core; the contracts those callers must honour are this module's signatures.

### 1.1 How the binding contract (J-017 §4.1/§5.1) is met

| J-017 clause | Implementation |
|---|---|
| Cache unit = whole expert, 3 slabs atomic (§3.2) | One entry per (layer, expert) pair holding the pair's full byte size as one buffer; admitted/evicted atomically. A hit ⇒ zero reads for that firing. |
| Byte accounting at directory-true per-pair sizes (§4.1.4) | Every `access()` carries the pair's true size for its layer; a size change for a resident pair raises. Budgets, segments and statistics are all bytes; pair counts derived. |
| Sized at open: min(cap, free − reserve) (§4.1.1–2) | `plan_expert_cache_budget(free_at_open, total, cap, resident, kv_allowance, scratch, per_token_routed)` returns the full stated arithmetic (see §2). |
| Hard cap honoured exactly, never transiently (§4.1.3) | Admission is evict-then-admit or refuse (bypass / too-large); the unit churn test asserts resident bytes ≤ budget after every one of 200 mixed accesses, and the replay asserts it over 73,856. |
| Resident bytes excluded, never evictable (§4.1.5) | The module only ever holds routed-expert bytes; resident set enters sizing only as a reserve term. |
| Shrink with in-flight pinning (§4.1.6) | `pin`/`unpin` + `shrink(new_budget)`: sheds probation (LRU) first, then main by (frequency, recency), never a pinned entry; if only pinned bytes remain over budget it returns the overage visibly instead of corrupting in-flight work. |
| Statistics in J-016 vocabulary (§4.1.7) | `ExpertCacheStats`: accesses, hits, misses, **cold_misses**, hit rate (per-mille, integer), bypasses, too-large refusals, admissions, promotions, evictions, **evicted_before_reuse**, **bytes_streamed**, bytes evicted, resident bytes/entries now — all over (layer, expert) pairs. |
| Pluggable, frequency-capable policy; no hard-wired LRU (§4.1.8) | One policy interface, three policies: `segmented` (shipping, §3), `lru` and `lfu` (faithful J-016 baselines). |
| Admission discipline; unconditional admit-on-miss ruled out (§5.1) | The shipping policy is probationary with a frequency gate (§3); bypass is a first-class, separately counted outcome. Baselines keep unconditional admission *by definition* — they exist to reproduce J-016's sims, and are not the shipping policy. |

### 1.2 Decisions this slice was charged to make (J-017 §6.1 "open" list)

- **Flag / env names:** flag `--expert-cache-bytes`, env `AESIR_EXPERT_CACHE_BYTES`, both parsed by the module's tested `parse_byte_size` (plain bytes or K/M/G suffix, 1024-based — a memory quantity, so decimal units would mislead). Resolution: flag beats env; zero from both = unset (`resolve_hard_cap`). The `--cache` analogue's *value grammar* is therefore fixed now; the CLI plumbing is J-036's surface work.
- **Reserve composition (default):** reserve = resident bytes (directory-measured by the caller) + KV allowance + scratch + OS/other-programs headroom of **one fifth of total memory** (adopting the shape the census recorded, as a stated Aesir default — not a measurement). KV allowance and scratch are **named configuration values supplied by the caller**, never invented inside the module (J-017 §2.3: KV bytes are J-087's to measure; until then the allowance is conservative configuration, labelled as such wherever it is reported — `ExpertCacheSizing.describe()` prints every term).
- **Floor:** budget < one token's full routed demand (`per_token_routed_bytes`, J-015's exact ceilings) is reported as `below_floor` in the sizing — the honest "say so at open" behaviour of J-017 §5.3, not silent thrash.
- **Segment structure:** two segments — probation at **1/8 of budget**, main at 7/8 (policy below).

## 2. The shipping policy — segmented probationary/frequency (DECIDED for J-018; verdict is J-024's)

- **Probation segment** (1/8 of budget, LRU inside): a first touch may enter only here, and only if its frequency estimate is not below the probation LRU victim's (the frequency gate); otherwise the miss is **bypassed** — served, counted, not admitted.
- **Main segment** (7/8): on a probation entry's second touch it is promoted, evicting main victims only when their frequency is ≤ its own. Main eviction is by (frequency, recency).
- **Frequency estimates** are exact per-pair counters with TinyLFU-style aging (halved every 4,096 accesses) in the segmented policy only. Cold accounting is tracked in a separate ever-seen set, immune to aging (§4, defect 2).

## 3. Validation against J-016's real trace (MEASURED replay of a MEASURED trace)

Harness: `j018_replay_trace.mojo` (campaign records; filed in repo beside this doc) feeds all **73,856 accesses** of `j016_trace_olmoe.jsonl` through the real Mojo module. Per-layer pair sizes are the trace header's `expert_bytes_per_layer` divided by 1024 (exact for both layer classes: 4,079,616→3,984; 3,538,944→3,456) and budgets scale by the same factor (pair-class × mean size 3,720 scaled — J-016's own `approx_bytes_at_mean_expert` construction), so every byte comparison the policies make is the full-scale comparison. Full output: `j018_replay_results.txt`.

| Policy (byte budget ≈ pairs) | This module | J-016 offline sim (pair capacity) |
|---|---:|---:|
| LRU @128 | **0.185** | 0.186 |
| LFU @128 | **0.300** | 0.302 |
| LRU @512 | **0.740** | 0.741 |
| LFU @512 | **0.747** | 0.748 |
| **Segmented @128 (shipping)** | **0.333** | — |
| **Segmented @512 (shipping)** | **0.760** | — |

- **Cold misses = exactly 1,024 in all six runs** — J-016's cold count to the access. **PROVEN:** the module's accounting core is faithful.
- Residual baseline deltas (≤0.002) are the byte-budget vs pair-capacity construction, visible in the record (LFU @128 holds 127 entries at the end: the byte budget, spent on layer-dependent sizes, buys one fewer large pair than a flat 128-pair capacity). Explained, not a defect.
- LRU @128 streamed bytes scale back to **396.9 MB/token** — J-016's table figure exactly.
- The shipping policy beats both baselines at both sizes on this trace (+14.8 points over LRU @128; +2.0 @512, with 42,551 bypasses @128 — the admission discipline refusing the thrash traffic, per J-017 §5.1's prediction). This is **one trace, one model, prompt-phase** — a shipping choice, not a verdict; J-024's tournament (per text type, more traces) owns the verdict and may replace it.

## 4. Defects found and fixed in scope (never-leave-a-bug rule)

1. **Eviction was O(entries × payload) per eviction.** `_evict_at` used an indexed `List.pop`, which shifts and deep-copies every following entry's payload; the first full-trace replay could not finish one policy in 280 s. Fixed with swap-remove (entry order carries no meaning — victim selection scans by tick/frequency) plus key re-lookup in promotion; the same replay then completed all six policies in ~120 s, unit tests unchanged-green.
2. **Cold misses were over-counted under aging (2,735 vs the true 1,024).** The aged frequency sketch decays counts to zero, and cold detection read the sketch — repeats were re-labelled cold. Fixed with a separate ever-seen set for cold accounting; replay now reports exactly 1,024 everywhere.
3. **The `lfu` baseline was not J-016's LFU.** Its first build carried the admission gate + aging, inflating it to 0.360/0.782 against the sim's 0.302/0.748 — a mislabelled baseline is a dishonest comparison. The gate and aging now live only in the segmented shipping policy; `lfu`/`lru` reproduce the sim definitions (and now the sim numbers, §3).

## 5. Tests (PROVEN, this run, VM)

`mojo run -I aesir_engine aesir_engine/tests/test_expert_cache.mojo` (via the project's pixi env; only this test target built, per the memory constraint):

- `PASS: expert cache sizing, cap resolution and size parsing` — reserve arithmetic (300+200+100+2000=2600; budget 7400), cap-at-sizing, below-floor, no negative budget, flag-beats-env, size grammar incl. rejection.
- `PASS: expert cache admission, promotion, pinning, shrink, cap` — probation→main promotion on second touch, oversize refusal, pin survives shrink, unpinned shrink reaches the new budget, resident ≤ budget after every churn access, hit/miss accounting closes.
- `PASS: expert cache LRU baseline and LFU policy modes` — canonical LRU eviction order on 1-2-3-1-4; LFU keeps its most frequent expert under a one-touch flood.

`run_all.mojo` registration is wired but the full runner was **not** executed (it builds the whole suite — outside this slice's VM memory budget; its own header also records a pre-existing segfault in an unrelated case). The standalone target is the tree's per-test shape and is what was run.

## 6. NOT PROVEN / carried forward

- **No live integration**: no MoE forward, loader split, disk streaming (J-019), or CLI/env plumbing consumes the module yet — by the road's own order, not by omission. NOT PROVEN that any Aesir run streams an expert.
- **Policy verdict**: J-024's tournament (per text type; Granite/`qwen2moe`/decode-heavy traces are NOT PROVEN demand, J-016 §7).
- **KV allowance value**: configuration until J-087 measures KV bytes.
- **Full-scale (unscaled) replay on a big-memory box**: the scaled replay is comparison-exact by construction, but a full-scale run on purplelongship remains a (cheap, later) confirmation — not run here because S-087 owns that machine this hour.
- **Performance at engine scale**: linear scans over entries/frequencies are sized for the pair universes in evidence (≤ a few thousand pairs); a 10⁵-pair universe wants indexed structures — a J-024/J-032-scale concern, recorded now.

**Evidence files.** Repo `docs/janas/`: this document + `j018_replay_trace.mojo`. Campaign records `~/workspace/model-tests/janas/`: this document, `j018_replay_trace.mojo`, `j018_replay_results.txt`. Engine: `aesir_engine/core/expert_cache.mojo`, `aesir_engine/tests/test_expert_cache.mojo`, `run_all.mojo` registration. No README touched anywhere.
