# J-027 — The Cache Persistence Question

**Slice:** J-027 (Part II — Models Bigger Than Memory), Project Aesir Janas clean-room road.
**Roadmap text:** "Whether a warm expert map (which experts, not their bytes) should persist between sessions like Janas's learned config does: measured benefit, decided on evidence, recorded either way."
**Executed:** 2026-10-31 ~11:0x–11:5x EDT. **Offline trace work only** (VM; no inference anywhere; purplelongship untouched — the 204 road's S-095 has been live there since ~10:22 EDT and this slice was designed offline). VM MemAvailable ≈ 0.5–0.6 GB throughout; `/tmp` 100 % full (pre-existing) — nothing deleted, TMPDIR redirected to the workspace overlay.
**Base:** branch `yrsa/janas-j027` from `yrsa/janas-j026` tip `6c4d4502` (the fsketch-default tree, J-026's shared-pool build). Origin/main `ba7ee09b` untouched. **No Janas material was used or needed** — this slice stands on J-015/J-016/J-020/J-024 evidence; the clean-room law was not engaged.
**Headline verdict: REJECTED — measured, and the rejection is the result.** No buildable persisted map, under any of three application mechanisms, at either operating budget, in any of three session segmentations, saves a single net byte. The best buildable row (a first-token-only map, plain preload) *costs* −0.33 % of streamed bytes at 512 pairs while cutting token-0 streamed bytes by 86 % — it moves cost earlier, it does not remove it. The ceiling rows prove why: a *perfect* persisted map (the target session's own token-0 set) nets **exactly 0.000 %** under preload, in every session, at every budget — and seeding the admission sketch pays (+3.4…+4.8 %) only with the target session's *own* counts, i.e. with knowledge of the future. Every real (prior-sessions-only) map is stale in exactly the way this model's flat router entropy (5.9836/6.0, J-016) guarantees. §6 states the verdict, what it does and does not claim, and the exact reopen conditions.

---

## 1. Field and method

**Trace.** The J-016 measured OLMoE trace (`j016_trace_olmoe.jsonl`, sha256 `85e1d2413cbfcd43516a03d8463c7266d486cf0f0d0a6ed3104d09111facf99a` — re-verified this run; 577 tokens, 9,232 token-layers, 73,856 accesses; 6 prompts: prose 71 incl. 4 gen tokens, code 100, structured 129, numbers 91, instructions 91, technical 95; kept in campaign records, not committed, as J-016 left it). One model, one quant, prompt-phase — the same scope limit J-017 §1 binds on every citation of it.

**What "persistence" means here.** A **map** — the ranked list of (layer, expert) pairs with access counts, *not* expert bytes — is saved at session end. At the next session open it is applied to the fresh expert cache by one of the mechanisms in §2. The priced map format (the spec this slice measures): 16-byte header + 4 bytes per entry (layer u8, expert u8, count u16 LE saturating). A full-frequency map for this model is 2,816–4,112 B; a bounded first-token map is 528 B. The bytes are trivial; the question was never storage cost — it is whether the map's *guidance* pays.

**Cache under test.** `fsketch` — the shipping default since J-024's integration (single LRU segment; aged exact-counter sketch, halved every 4,096 accesses; a miss is admitted only when the candidate's frequency exceeds the victim's, otherwise bypassed). Byte budgets built exactly as J-016/J-018/J-024 built them: pairs × mean scaled pair size (3,720; full-scale = scaled × 1024). Operating budgets **128 / 512 pairs** (≈0.49 / 1.95 GB).

**Sessions.** Every segmentation below is a sequence of **same-model (OLMoE) sessions** — the trace's six prompts are six workloads on one model file. Persistence here is within-model, cross-workload; nothing in this slice speaks to maps across different models. Session 1 of a segmentation has no prior session and is NO-PERSIST for every candidate by definition; headline aggregates cover the **eligible** sessions (2..N) only.

| Segmentation | Sessions | The real-world pattern it models |
|---|---|---|
| **NATURAL** (primary — the verdict rests on it) | The six prompts in trace order: prose, code, structured, numbers, instructions, technical | Successive separate conversations / CLI runs on a machine where the model stays installed and only the expert cache is cold |
| **REPEAT** (secondary) | NATURAL's six, then the same six again in the same order (sessions 7–12) | The returning user — daily reuse of the same model for similar work; the strongest honest case for a learned map |
| **GROUPED** (secondary) | Three sittings — {prose+technical}, {code+structured}, {numbers+instructions} (J-026's tenant grouping); cache resets only between sittings | One sitting with several prompts, engine restarted between sittings |

## 2. Candidates, mechanisms, and the verdict rule — stated before measuring

**Candidates** (all learned from **prior sessions only**; no candidate ever sees the target session):

| Candidate | Definition |
|---|---|
| `NO-PERSIST` | Cold fsketch cache every session (the base). |
| `LAST` | Ranked by frequency in the immediately previous session alone (ties: more recent last use, then pair). Persisted map = that session's distinct pairs (700–1,013 entries). |
| `CUMULATIVE` | Ranked by frequency over **all** prior sessions — the learned-config analogue. Persisted map = all distinct pairs seen so far (≤1,024 entries). |
| `FIRSTTOK` | J-020's FIRSTTOK predictor in cross-session form: ranked by how many prior sessions' **token-0 sets** contain the pair, ties by cumulative frequency. Persisted (bounded) map = top 128 entries = 528 B. |
| `ORACLE` | The target session's **own** token-0 set (preload rows) and/or its own full counts (seed rows). Ceiling only — never a candidate. |

**Mechanisms** (how the map is applied at session open; the task's own alternatives — preload or admission priority):

- **PRELOAD-PLAIN** — the map's top-128 pairs are streamed in before token 0 (J-020's warm-up shape, ≤¼ of a 512 budget). Charged in full (§2.1). Sketch frequency 0 for preloaded pairs.
- **SEED** — no preload (zero prefetch bytes). The session's fsketch frequency sketch is initialised from the persisted map's counts (every mapped pair): admission priority, tested pure.
- **SEED+PRELOAD** — the top-128 preload with each preloaded pair's sketch frequency initialised to its persisted count, the rest of the map seeded as in SEED. This is J-020's proven preload shape (its replica preload took `freq_hint` = the predictor's evidence counts).

**Amendment record (honesty).** PRELOAD-PLAIN was measured first. Reviewing its rows against J-020's filing showed the plain form *discards the counts that are a frequency map's content* — it fairly tests a persisted set, but not a persisted frequency map. SEED and SEED+PRELOAD were therefore added under the **same verdict thresholds**, defined before either was measured. The rule below applies per (candidate × mechanism) row; an adoption would have named its row exactly.

### 2.1 Preload charging (fixed in advance)

A pair that does not fit the remaining budget at open is **skipped on metadata** (no fetch, no charge — a real loader knows pair sizes from the directory before reading). Every admitted pair is fetched and charged its full pair size as prefetch streamed bytes, part of the strategy's total. Preloaded entries carry ancient recency (best-ranked least ancient) and no demand-statistic contact. A preloaded pair demand-hit before eviction is **useful**; evicted-before-use and resident-but-unused at session end are counted separately and their bytes stay charged. Cap pressure is reported: prefetch bytes, demand evictions vs the NO-PERSIST session, preloaded pairs evicted before use.

### 2.2 Verdict rule (stated before results; NATURAL, eligible sessions)

- **ADOPT** (full-map persistence) iff some full-map row (LAST or CUMULATIVE × any mechanism) satisfies **all** of: (a) aggregate net streamed saving ≥ **+2.0 %** at 512 pairs **and** ≥ 0 % at 128; (b) token-0 streamed saving ≥ 20 % at both budgets; (c) no eligible session with a net loss worse than 2 % at either budget. Winner: the larger 512 saving.
- **ADOPT-BOUNDED** (a narrower form) iff no full row passes but some FIRSTTOK row satisfies **all** of: (a) net saving **> 0 %** at 512 **and** ≥ −1.0 % at 128; (b) token-0 saving ≥ 40 % at 512; (c) no eligible session worse than −5 % at 512.
- Otherwise **REJECT**: no map persists between sessions; the question is recorded as answered on this evidence, with reopen conditions named (§6).

## 3. Validation gate — PROVEN

No payoff number below was trusted before this gate passed. The simulator's no-persistence fsketch reproduces, **EXACTLY**:

- J-024's tournament fsketch counters at **128/256/512** (hits 25,953/39,394/56,781; misses, cold 1,024, bypasses, admissions, evictions, evicted-before-reuse, streamed bytes, entries, resident bytes — every field), and
- the real-MoJO-module replay counters (`j024_replay_results.txt`) at 128/512;
- and, as the segmented continuity leg, J-024's FastCache segmented run reproduces **J-020's recorded cold-session numbers EXACTLY** (hits 56,165, misses 17,691, cold 1,024, streamed scaled 65,896,320) and J-020's prose_cold EXACTLY (hits 4,877, misses 4,211, cold 975, streamed scaled 15,682,608).

**Gate: 7/7 EXACT.** Base re-measured per segmentation (eligible sessions, fsketch, fresh cache per session): NATURAL hit 0.370 @128 / 0.780 @512, total streamed 155,305 MB @128 / 54,233 MB @512 over the five eligible sessions; token 0 costs the full 487.6 MB (128 pairs = J-015's ceiling) in *every* cold session at both budgets — the cold-start cost persistence was supposed to remove.

## 4. Measurements (SIMULATED on the MEASURED trace)

Sign convention: **net saving %** = (NO-PERSIST total − strategy total) / NO-PERSIST total, prefetch bytes charged to the strategy. Negative = the strategy *costs* bytes. Full counters, per-session rows included: `j027_persistence_results.json`.

### 4.1 NATURAL — headline table (eligible sessions 2–6)

| Row | @128: net / tok-0 saving | @512: net / tok-0 saving | tok-0 hit @512 | worst session @512 |
|---|---:|---:|---:|---:|
| base (NO-PERSIST) | — (hit 0.370) | — (hit 0.780) | 0.000 | — |
| LAST · PRELOAD-PLAIN | −1.35 % / +13.8 % | −1.63 % / +25.8 % | 0.259 | −5.51 % |
| LAST · SEED | −3.53 % / 0 % | −3.98 % / 0 % | 0.000 | −21.74 % |
| LAST · SEED+PRELOAD | −6.94 % / +25.8 % | **−21.33 %** / +25.8 % | 0.259 | −46.26 % |
| CUMULATIVE · PRELOAD-PLAIN | −1.32 % / +15.6 % | −1.50 % / +31.7 % | 0.317 | −5.51 % |
| CUMULATIVE · SEED | −8.81 % / 0 % | **−13.32 %** / 0 % | 0.000 | −21.74 % |
| CUMULATIVE · SEED+PRELOAD | −12.39 % / +31.4 % | **−27.14 %** / +31.7 % | 0.317 | −46.26 % |
| FIRSTTOK · PRELOAD-PLAIN | **−0.34 %** / +78.3 % | **−0.33 %** / +86.1 % | 0.869 | −1.42 % |
| FIRSTTOK · SEED | −1.33 % / 0 % | −4.27 % / 0 % | 0.000 | −10.64 % |
| FIRSTTOK · SEED+PRELOAD | −1.54 % / +86.1 % | −4.48 % / +86.1 % | 0.869 | −10.60 % |
| ORACLE · PRELOAD-PLAIN (ceiling) | **0.000 %** / +100 % | **0.000 %** / +100 % | 1.000 | 0.00 % |
| ORACLE · SEED (ceiling) | +3.45 % / 0 % | +4.47 % / 0 % | 0.000 | +1.64 % |

**No buildable row is positive anywhere.** Three measured shapes:

1. **Plain preload is a small, steady tax — except at token 0, where it works exactly as J-020 found.** Full maps convert badly (LAST @512: 408 of 640 preloads ever used, 232 evicted before use; their token-0 overlap with the next session is only 0.26–0.32 — a *different workload's* frequency ranking is a poor first-token predictor). FIRSTTOK is the honourable near-miss: token-0 streamed falls from 2,437.9 MB to 339.4 MB over the five eligible sessions @512 (per session 52.5–96.8 MB vs the cold 487.6 MB), whole-session hit rises 0.780 → 0.790, and the net cost of buying that is just **+180.9 MB over 54,233 MB (−0.33 %)** — but the rule's bounded clause (a) demands net > 0, and −0.33 % is not > 0.
2. **Seeding the sketch with real (stale) counts is actively harmful.** CUMULATIVE·SEED @512: bypasses rise 9,818 → 12,716 (+29.5 %) and demand streamed rises +13.3 %. The mechanism is visible in the counters: fsketch's admission test is *relative* (candidate frequency must exceed the victim's) — yesterday's inflated counts sit on resident victims and raise the bar against today's genuinely new pairs, which then bypass and stream on *every* demand. Adding preload on top compounds it (−21…−27 %): seeded preloads become near-unevictable (evictions collapse 1,842 → 376) while the session's own working set streams around them.
3. **The oracle rows isolate the cause: staleness, not mechanism.** ORACLE·SEED pays +3.45 %/+4.47 % — seeding works *when the counts are the target session's own*. ORACLE·PRELOAD-PLAIN nets **exactly 0.000 % in every eligible session of every segmentation at both budgets** (verified by an independent probe, §5): the ceiling of preload persistence is byte-neutral *by construction* on this trace.

### 4.2 The other segmentations agree (no contradiction to name)

REPEAT (the returning-user case, persistence's best honest hope): FIRSTTOK·PRELOAD-PLAIN net −0.28 % @128 / −0.29 % @512 with token-0 savings 82.6 %/88.2 % — a second lap over the *identical* prompts does not flip the sign. Full maps −1.34…−1.55 % plain; seeding −3.3…−25.8 %. GROUPED: FIRSTTOK·PRELOAD-PLAIN −0.26 %/−0.23 %, token-0 68.0 %/82.2 %; full maps −0.69…−0.97 % plain; seeding −0.27…−18.8 %. The ordering of mechanisms and candidates is identical everywhere; only magnitudes move.

### 4.3 Map sizes (the priced format, §1)

LAST maps: 3,916 / 2,816 / 3,664 / 4,056 / 4,052 B across NATURAL's eligible sessions. CUMULATIVE grows 3,916 → 4,112 B (the whole 1,024-pair universe costs 4,112 B — storage was never the obstacle). FIRSTTOK bounded map: **528 B**, constant. ORACLE: no persisted artefact (it cannot exist).

## 5. Why — the conservation law, verified at session scale

J-025 §6's arithmetic, restated for the session boundary: **streamed bytes are conserved under preload.** A prefetch fetch and a demand miss are the same read; preload can only win by creating residency the base policy would not have created *and* having that residency re-used before eviction. The probe that proves the ceiling (run independently of the payoff matrix, on the code session @512): the oracle preload's 128 pairs are hit 128 times at token 0 and **3,359 more times** later in the session — and the demand streamed in *every token after token 0 is identical to the base, to the byte*. The base policy had already admitted exactly the token-0 set at token 0 (admissions differ by exactly 128; bypasses identical at 315; evictions identical at 152): the residency the oracle "creates" is residency fsketch creates itself, one token later. What remains for a real map is only the *prediction error* on top of that neutral ceiling — stale rankings fetch pairs the session does not open with (232–549 evicted before use for full maps), and each wasted fetch is a pure addition. Seeding escapes conservation only by changing admission decisions — and with stale counts it changes them for the worse (§4.1.2); with true counts it would change them for the better (+4.47 %), which is precisely the part no prior session can supply on a model whose router entropy is 5.9836/6.0 and whose cross-session token-0 overlap for frequency maps is 0.26–0.32. The one structured, cross-session-stable signal in this trace remains what J-020 found: **token-0 sets themselves** (FIRSTTOK's 0.87–0.89 token-0 hit rate) — and even that signal, charged honestly, buys its token-0 win at a small whole-session loss on bytes.

## 6. Verdict

**REJECTED — no expert map persists between sessions in Aesir.** No (candidate × mechanism) row satisfies the §2.2 rule: full-map rows fail clause (a) at both budgets under every mechanism (best full row: CUMULATIVE·PRELOAD-PLAIN, −1.32 %/−1.50 %); FIRSTTOK fails the bounded clause (a) at 512 (−0.33 % plain, −4.27 % seed, −4.48 % seed+preload — its token-0 clauses (b) pass with room, 86.1 % ≥ 40 %, and its worst session passes (c), −1.42 %; the byte clause is the one it cannot meet). Per the roadmap's own instruction ("decided on evidence, recorded either way"), the measured rejection **is** the slice's result. Nothing is built: no map file, no preload hook, no sketch seeding in `expert_cache.mojo` / `moe_session.mojo`; the fsketch default stands exactly as J-024/J-026 left it. **Consequences carried forward, explicitly:** (i) **J-044's learned file** must not grow an expert-map section for OLMoE-class models on this evidence — its placement/thread choices are a different artefact, ungraded here; if J-044 wants an expert map it must re-open this slice with new evidence, not inherit a presumption. (ii) **J-034's Part II gate** re-cites this rejection beside J-025's (the two persistence-adjacent questions of Part II — within-session shadow prefetch, cross-session map persistence — are now both measured and both closed). (iii) J-028 (memory-pressure honesty) is unaffected, except that there is no persisted map for a pressured reopen to reload.

**Scope honesty — what this verdict does not claim.** (a) It grades **streamed bytes**, the currency of every Part II sibling slice. FIRSTTOK·PRELOAD-PLAIN's token-0 effect is real and large (487.6 MB → ~68 MB mean per session @512): a persisted first-token map could in principle pay in **first-token latency** (those bytes can stream during process open / prompt submission, before token 0 demands them) while losing marginally on bytes. No latency was measured here (offline replay has no wall), so a latency case is **NOT PROVEN either way** and may not be smuggled in as this slice's conclusion — it would have to be argued on a live vehicle under its own pre-registered rule. (b) One trace, one model, prompt-phase demand (4 gen tokens) — the J-016 scope limit, again. (c) **Reopen conditions, named:** a live first-token-latency measurement showing the token-0 transfer (not the bytes) is worth ≥ its −0.33 % byte tax; a decode-heavy trace (J-033's soak shape) whose sessions share materially more than token-0 structure; a second model's trace with cross-session frequency stability materially above this one's (full-map token-0 overlap > ~0.5); or a *damped* seeding variant (persisted counts compressed, e.g. log-scaled or capped at in-session magnitudes) — the raw-count seeding measured here is not that variant, and the variant is NOT PROVEN in either direction.

## 7. Honesty ledger

- **PROVEN:** the validation gate — simulator base reproduces J-024 tournament fsketch EXACTLY at 128/256/512, the real Mojo module's replay EXACTLY at 128/512, and J-020's cold + prose-cold segmented numbers EXACTLY (§3). Trace integrity: sha256 re-verified. The §5 conservation probe: per-token demand streams of the oracle-preload and base runs compared directly (identical after token 0, to the byte; admissions differ by exactly the 128 preloaded pairs).
- **SIMULATED (on a MEASURED trace):** every payoff number in §4 — offline session-sequence simulation through the gate-validated fsketch, under §2's candidates/mechanisms/charging. No live run, wall, or tok/s is claimed anywhere in this document.
- **MEASURED (from the trace itself):** map entry counts and sizes (§4.3); base cold-session counters per segmentation (§3).
- **NOT PROVEN:** any latency effect of a persisted map, in either direction (§6a); persistence on decode-heavy demand, on Granite/`qwen2moe` demand, or on any second model (no traces exist); the damped-seeding variant (§6c); persistence of *bytes* (a warm cache directory) — a different question this slice never asked, neither answered nor prejudged by this verdict; any benefit on machines whose bottleneck is seeks/latency rather than bytes.
- **Defects found and fixed in scope (never-leave-a-bug law):** (1) The first mechanism measured (PRELOAD-PLAIN) silently discarded the persisted counts — for frequency-map candidates that tests a weaker artefact than the slice's own question names. Caught on review of the first matrix against J-020's `freq_hint` preload precedent, *before* any verdict was drawn; repaired by adding the SEED and SEED+PRELOAD mechanisms under the unchanged verdict rule, with the amendment recorded in §2 and in the simulator's header. All §4 numbers are from the full three-mechanism matrix. (2) No defect was found in prior slices' work: the gate's seven EXACT reproductions stand as this slice's re-verification of J-020/J-024.
- **Coordination:** 204 road checked at dispatch (S-095 live on purplelongship from ~10:22 EDT) — this slice ran **no** purplelongship work at all; VM work was simulation-only at MemAvailable ≈ 0.5–0.6 GB (no Mojo build was needed — the question slice's honest deliverable is this design+measurement record). /tmp found 100 % full (pre-existing) — nothing deleted; TMPDIR redirected to `~/workspace/.verify-tmp/`. No README touched. Hailo untouched/parked.

## 8. Artefacts

Filed beside this doc in `docs/janas/`: `j027_persistence.py` (candidates, the three mechanisms, segmentations, the validation gate, the verdict rule — the trace path and the J-024 results path are arguments; the 1.2 MB trace itself stays in campaign records, as J-016 left it) and `j027_persistence_results.json` (validation gate, per-session rows and aggregates for every (segmentation × budget × candidate × mechanism), map sizes, the verdict). Campaign copies of the doc, script and results live in `~/workspace/model-tests/janas/`.
