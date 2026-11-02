# J-034 — Part II Gate: Streaming Evidence Pack

**Slice:** J-034 (Part II — Models Bigger Than Memory, J-015–J-034), Project Aesir Janas clean-room road.
**Roadmap text:** "Part II gate. Streaming evidence pack: every number re-measured at the gate, the residency design as-built documented, deltas back to the concordance."
**Executed:** 2026-10-31 ~13:03–13:13 EDT. **Closure shape: offline re-verification closure** (the J-027/J-029/J-030 precedent): every headline Part II number was re-derived at this gate from the filed artefacts by a filed script (§2), not taken from prose. No new live leg ran — §5 states plainly why, and re-cites every deferred leg owed to this gate with its recipe pointer.
**Base:** branch `yrsa/janas-j034` in fresh worktree `~/workspace/aesir-janas-j034`, from `yrsa/janas-j033` tip `664cb5232908d74b52c0adb8adc80b1311f6b04a`. Origin/main untouched at `ba7ee09b6b4d09967b571f2f39714e9119dc3772` (ls-remote verified at gate start and at banking, §8).
**Deviation recorded (keeper's banking of J-033):** the J-033 doc §8 described its pending branch as created from `yrsa/janas-j032` tip `d405df13`. The branch as actually banked by the keeper was created from the **corrected** j032 tip `084a37b0a342bc90e0f8e0b39b2ca03a2add2f11` (the one-line J-032 header correction), so the correction is chained into the lineage; its six files are sha-identical to the campaign copies. This gate's base is that actual tip, `664cb523`. The J-033 doc §8 pending-commit instructions (P1/P2) are therefore **superseded — both landings are done and ls-remote verified** (j032 == `084a37b0`, j033 == `664cb523`, verified first-hand at this gate).

---

## 1. Gate verdict

**Part II CLOSED-WITH-DEFERRED-LEGS.**

- The offline evidence pack is **PROVEN by re-verification at this gate**: the filed script `j034_reverify.py` re-parsed the filed artefacts and recomputed / cross-checked every headline number — **128/128 checks PASS, 0 FAIL** (§2, `j034_reverify_output.txt`).
- The live legs listed in §5 remain **NOT PROVEN / DEFERRED-WITH-REASON** and stay roaded where their own docs road them. None of them is claimed anywhere in this gate.
- Part II's two measured rejections stand as results, not gaps: router-shadow prefetch (J-025) and cache-map persistence (J-027) were both measured against pre-registered rules and rejected, with oracle ceilings proving the rejections are structural, not tuning failures.

No README touched. Hailo untouched/parked (no finish-line branch contact, no chip run). No Docker. No Janas source opened — this gate needed no Janas material at all (clean-room law unengaged).

## 2. Re-verification at the gate (PROVEN)

Script: `docs/janas/j034_reverify.py` (campaign copy sha-identical in `~/workspace/model-tests/janas/`). Output: `j034_reverify_output.txt`. It reads only filed artefacts: the campaign results JSONs / replay outputs / harvest logs, and the in-tree `docs/janas/` artefacts of this branch line. Counts per group:

| Group | Checks | Result |
|---|---|---|
| Doc census (§3) | 20/20 PASS | in-tree vs campaign-only census exact |
| J-016 trace sha + stats | 13/13 PASS | trace sha256 recomputed `85e1d2413cbfcd43516a03d8463c7266d486cf0f0d0a6ed3104d09111facf99a` == pin; 577 tokens / 73,856 accesses; entropy 5.9836/6.0; cold 1,024; median stack distance 298; the same sha is carried in all five downstream results JSONs |
| J-018 cache replay | 5/5 PASS | 6 real-module runs, cold exactly 1,024 in all, LRU 13,733 @128 / 54,691 @512, segmented beats both baselines @128 |
| J-019 disk bench | 9/9 PASS | 14 legs filed; all 12 demand legs checksum-agree (5887966450294); cold resident 0.0 on every cold leg; pread+readahead cold 2.364 s / 1.470 GB/s (recomputed) vs mmap 2.874 s / 1.209 — pread_ra wins by 17.7 % of mmap wall; madvise buys mmap only ~2.9 %; O_DIRECT over-read 11,231,232 B on record |
| J-020 cold/warm | 4/4 PASS | cold/cold 22.513 s over 67,477,831,680 B; page warmth −6.6 % wall; expert-cache warmth −8.6 % wall on −10.5 % bytes; cold-leg checksums/miss counts internally consistent |
| J-022 faithfulness + counters | 7/7 PASS | teacher-forcing grade file re-parsed: 24 steps, rank 0 at 23/24, step 23 rank 1 gap 0.108 (near-tie band); streamed counters exact (11,648 / 3,007 / 1,265 / 192 / 1,125 / 7,376 / 3,387); bytes streamed 32,948,699,136 == stream bytes_read; 80B attempt refusal verbatim + EXIT=1 |
| J-023 idle/loaded + NO THRASH | 5/5 PASS | loaded ids == idle ids == J-022 post-fix ids (all 24); every cache/stream counter bit-identical between legs; wall/token 0.4113 → 0.4353 (ratio 1.058, recomputed) — no thrash by the pre-registered definition |
| J-024 tournament + fsketch | 11/11 PASS | validation gates EXACT; fsketch wins @128/256/512 (0.3514 / 0.5334 / 0.7688); real-module replay hits == tournament hits at all 4 budgets; pre-fix segmented @1024 starvation on record (0.960, 963 resident) and post-fix replay @1024 at the ceiling (72,832 hits, bypasses 0, evictions 0, 1,024 resident); dropping trial priced (23.2 % dropped, 0.152 mass/token-layer) |
| J-025 prefetch rejection | 6/6 PASS | PL overlap 0.977/8 — below the random 1.000 expectation; verdict REJECT with no passing candidate; ORACLE-direct still loses (+28.54 % @128 / +12.36 % @512); ORACLE-gatedpre headroom only −0.03 % / −0.49 % |
| J-026 pool / replay | 6/6 PASS | validation EXACT 5/5; tenants A 266 tok / 34,048 acc, B 311 tok / 39,808 acc; naive == ceiling identity (the over-commit) on record; real-module replay == simulator pool counters @256 (11,605 / 13,403) and @512 (18,184 / 20,317); pool @256 worst tenant beats static (0.3367 vs 0.3226) |
| J-027 persistence rejection | 4/4 PASS | validation 7/7 EXACT; verdict REJECT; ORACLE preload nets exactly 0.000 % in every segmentation and budget (conservation, re-derived over all aggregates); FIRSTTOK near-miss −0.334 % @512 NATURAL with 86.077 % token-0 saving |
| J-028 pressure | 8/8 PASS | validation 6/6 EXACT; BASE 0.7688 / 112.982 MB-per-token; STEP 0.5453 at 1.963× base streamed (ratio recomputed); SQUEEZE 0.6029; RECOVERY 0.6583 with real-module replay == simulator on every counter; CRASH refuses at exactly token 288 (36,864 accesses served, resident shed to 0 first); 0 invariant / 0 accounting violations in all non-refusal schedules |
| J-029 verdict numbers | 7/7 PASS | every quoted headline figure (2.364 / 2.874 / 1.470 / 1.209 / 22.513 / 2.997) present in the verdict doc and equal to the artefact values recomputed above |
| J-030 CPU line | 6/6 PASS | the filed `j030_reverify_output.txt` re-counted at 7/7 CHECK PASS, and its identities re-derived independently here (ids, cache, stream bytes, prefill 2.3894 / decode 2.5563 / overall 2.4313 tok/s, loaded/idle ratio 1.0585) |
| J-031 GPU accounting | 9/9 PASS | FULL_GPU arithmetic re-derived: 311,027,712 + 352,321,536 + 3,900,702,720 = 4,564,051,968; headroom 804,657,152 against usable 5,368,709,120; plan unit tests 7/7 PASS lines filed; cold-token demand 487,587,840 B == the J-015/J-016 stats ceiling |
| J-032 80B refusal | 2/2 PASS | filed `j032_reverify_output.txt` re-counted at 25/25 PASS; size arithmetic re-derived (file exceeds total GPU+RAM by 0.63 GB) |
| J-033 analyser | 6/6 PASS | filed exercises PASS; **the analyser was re-run at this gate** on the real J-023 harvest logs (fixtures copied under `~/workspace/.verify-tmp/j034/`): total_generated=48, cumulative_hit=0.258, ceiling HELD, bytes/total-token 362,073,616.9 in both windows, wall/total-token 0.4113 / 0.4353, VERDICT: NO DEGRADATION TREND (PARTIAL SOAK) |

**Defect found and fixed in scope at this gate:** the gate script's first pass carried one wrong expectation of its own — an exact-string match on the post-fix segmented @1024 replay line that omitted the line's `promotions=657` field (segment moves are part of the fixed policy's normal operation). The filed artefact was correct; the check was not. Fixed to parse the line's fields (hits / bypasses / evictions / entries), full script re-run: 128/128 PASS. No defect was found in any Part II artefact, number, or prior slice record.

**Lightest unit tests (run at this gate, VM, PROVEN):** both standalone suites were rebuilt from this gate's tree (pixi Mojo, `-I . -I aesir_engine`, binaries under `~/workspace/.verify-tmp/j034/`; MemAvailable ~5,787 MB at start, no inference): `test_expert_cache.mojo` **9/9 groups PASS** (sizing/cap, admission/promotion/pin/shrink, LRU/LFU baselines, fsketch, the no-scarcity starvation fix, shared-pool sizing + drive, pressure decisions + drive) and `test_moe_gpu_plan.mojo` **7/7 groups PASS**. Output filed as `j034_unit_test_output.txt`.

## 3. Doc census (part of the gate)

Part II slice docs J-015–J-033, where each lives at this gate:

- **In-tree** (`docs/janas/` on this branch line): J-017, J-018, J-019, J-020, J-022, J-023, J-024, J-025, J-026, J-027, J-028, J-029, J-030, J-031, J-032, J-033 — 16 docs, with their artefacts (results JSONs, replay scripts/outputs, run logs, harness files).
- **Campaign-only** (`~/workspace/model-tests/janas/`, not in this branch tree): **J-015** (`J015_MOE_ANATOMY.md`), **J-016** (`J016_ROUTER_INSTRUMENTATION.md`), **J-021** (`J021_DENSE_SPILL_GENERALISED.md`) — 3 docs. They stand banked on their own slice branches (`yrsa/janas-j015` @ `5d5be15d`, `yrsa/janas-j016` @ `462d3ad8`, `yrsa/janas-j021` @ `9690ecfe`, per the state file's closure entries) and in the campaign records; they were never merged into this branch line, which forked from the J-017 line. The gate records the split exactly; consolidating the branch lines is a keeper decision, not gate work.
- J-034's own doc + script + output are filed in-tree and as sha-identical campaign copies.

## 4. The residency design, as built (Part II's as-built summary)

What Part II actually built, in the order a session meets it:

- **Resident set (never streamed, never evictable):** everything except routed experts — embeddings (+ untied output head), attention, all norms, routers, shared experts and their gate vectors where present (J-017 D1; per-witness budgets measured in J-015: OLMoE resident 311,027,712 B of a 4,213,512,672 B file; expert body 3,900,702,720 B = 92.62 % streams).
- **Streamed experts:** routed experts only, cache unit = the whole expert (its 3 slabs admitted/evicted atomically), read unit = one slab, all offsets/sizes from the GGUF tensor directory, never a family layout assumption (J-017 D2/D3, built in J-018/J-022).
- **The cache:** `expert_cache.mojo` — sized at open from free memory minus a stated reserve under a hard cap (`--expert-cache-bytes` / `AESIR_EXPERT_CACHE_BYTES`, flag beats env, never exceeded even transiently), evict-then-admit, pin-aware shrink. **Default policy is fsketch** (TinyLFU-style sketch admission over a single LRU segment), flipped from segmented on J-024's tournament + real-module replay evidence; the admission-starvation fix (no-scarcity budgets admit gate-free; promotion never evicts) applies to all filtering policies. Segmented / LRU / LFU remain as measured baselines.
- **The shared pool:** two sessions in one process size ONCE against a summed reserve (`plan_shared_cache_pool`), with a floor-and-borrow arbiter (floor = T/2N as a return guarantee, work-conserving borrowing, shrink-back by the cache's own order) — J-026, measured on the real trace with real-module replay exactness.
- **The pressure protocol:** `plan_pressure_budget` re-runs open-time sizing on a fresh free-memory sample at token boundaries; the cache sheds first, in policy order, pins held; resident/KV are never cannibalised; below the floor (one token's full routed demand) the run refuses cleanly after shedding to resident-only — J-028, with the CRASH schedule's refusal at exactly token 288 on record.
- **Disk discipline (the J-029 verdict, settled):** explicit `pread` of exactly the missed slabs + next-slab readahead advice (`stream_reader.mojo`). Plain mmap fault-driven paging is the slowest cold discipline measured and is **not** the streaming path (it remains the resident set's load shape only); the page cache is kept as a cache, not used as the pager; O_DIRECT stays rejected (cold tie, warm collapse, +11,231,232 B over-read); async I/O is NOT PROVEN (no binding exists; none was faked).
- **Two questions measured and closed with rejections:** router-shadow prefetch (J-025 — adjacent layers route essentially independently, PL overlap 0.977/8 < chance; even a perfect oracle loses on direct fetch) and cross-session cache-map persistence (J-027 — oracle preload nets exactly zero by conservation; J-044's learned file must not grow an expert-map section on this evidence). Cache-conditional expert dropping stays **DEFAULT OFF** (J-017 D6; J-024 priced it at 0.152 mass/token-layer @128, agreement cost NOT PROVEN — §5).
- **Dense spill, generalised:** the proven dense spill is re-expressed through the same residency machinery as a static pinned partition (`dense_residency.mojo`, accounting cross-validated to the byte, token-identity re-proven on purplelongship) — J-021; its doc is campaign-only per §3.
- **CPU line: PROVEN.** The J-022/J-023 runs are pure CPU+disk by construction (no GPU path in the three modules; `CUDA_VISIBLE_DEVICES=`; GPU idle at 1 MiB) and are graded as the CPU line in J-030: OLMoE Q4_K_M, 67 prompt + 24 gen, ctx 512, 512 MiB cache — idle prefill 2.3894 tok/s, decode 2.5563 tok/s, wall/token 0.4113 s (MEASURED-INDICATIVE, single runs); under the J-023 co-runner load, wall/token 0.4353 s (+5.8 %, wall only, NO THRASH).
- **GPU line: DESIGNED AND ACCOUNTED ONLY.** The MoE stack has no GPU execution path today (J-031 inspection, re-verified at J-032). `moe_gpu_plan.mojo` plans the division (resident first, then allowances, remainder as a whole-expert device cache) and prices transfers exactly; on the stated 6 GB card OLMoE degenerates to FULL_GPU residency (4,564,051,968 B of 5,368,709,120 B usable). No GPU wall, tok/s, or kernel-faithfulness claim exists — the live leg is §5.
- **The 80B class: NOT PROVEN.** The pin-verified Qwen3-Next-80B-A3B Q4_K_M file (48,506,100,512 B, sha256 `f73551b55e3796526c37772c96227151fa11af328802b8f9865d635104e280fd`) is refused by the loader (block 0 is an SSM block carrying no `attn_q`) and the session admits only arch `olmoe`. The blockers are B2a (no `qwen3next` loader admission) and B2b (no `qwen3next` forward — hybrid Gated-DeltaNet recurrence + shared expert + 512-expert routing), roaded to J-123. File size alone is not the fundamental bar; the forward is.

## 5. Deferred legs re-cited at this gate (all NOT PROVEN / DEFERRED-WITH-REASON)

None of these ran at this gate. Common cause, stated once and applying to all: **the 204 road's S-098 was dispatched at ~12:43 EDT and its state file shows no S-098 completion — purplelongship is yielded under the coordination law; this gate worker has no device route in any case; and the VM's MemAvailable flickered around the 5,500 MB inference gate (~5,438–5,787 MB at gate checks), so no VM inference ran either.** Several legs additionally need code that later parts own, as noted per leg. Each remains roaded at its recipe:

1. **J-024 live confirmation + dropping-agreement leg** — live confirmation of the fsketch default on the J-022 model, and a teacher-forcing agreement grade of a dropping run (rank + logit gap vs the ggml CPU comparator on the raw prompt). Recipe: J-024 doc's live-leg record + J-032 §8's grading pattern. Additional blocker for the agreement half: **no dropping implementation exists** in the MoE session to grade (dropping was measured offline only; default stays OFF).
2. **J-026 live two-session leg** — two pool-capped OLMoE sessions in one process, per-session token-identity vs solo, in a guarded idle gap. Recipe: J-026 doc's J-034 re-cite specification. Additional blocker: no Aesir surface yet hosts two MoE sessions in one process (the pool/arbiter are built and replay-proven; the hosting surface is not).
3. **J-028 live mid-run pressure leg** — J-023-shape co-runner taking RAM mid-generation, swap counters at zero. Recipe: J-028 doc §7.
4. **J-030 dedicated fresh CPU-line leg** — standard + `AESIR_THREADS=2` + 128 MiB cache legs, nvidia-smi logging, fsketch-default id confirmation. Recipe: J-030 doc §9.
5. **J-031 live GPU leg** — recipe: J-031 doc §9 (device pieces in dependency order — MoE device admission/profile, device expert payload store, OLMoE device block maths, per-miss upload batching — then run_all registration + counted run, FULL + capped-cache legs on the J-030 configuration, ids-first grading). Additional blocker: those device pieces are unbuilt; this leg is execution work, not a measurement appointment.
6. **J-032 80B attempt (via J-123)** — recipe: J-032 doc §8 (guarded idle gap, re-pin first, ids-first, raw-oracle grading; never `llama-cli --single-turn` as comparator). Additional blocker: B2a/B2b — the `qwen3next` forward lands via **J-123** (Part VIII); until then a new attempt is a known refusal, not an experiment. This leg also carries J-022's deferred bigger-than-RAM leg, which is the same attempt.
7. **J-033 soak leg** — ≥2,000 generated tokens across mixed prompts on the J-022 model (8 windows × 256, ~17–20 min of genuinely idle box at the J-030 CPU-line rates). Recipe: J-033 doc §7, steps 1–7 complete (coordination, ids via the tokdump route, staged harness with sha-pinned files, guarded run, analyser, spot grade, filing).

## 6. Concordance deltas for Part II rows

Against `DELTA_TABLE.md` (the Concordance frozen at J-014; grades below are this gate's report, the keeper amends the table):

| Row | Subject | Part II outcome |
|---|---|---|
| 1 | Expert streaming from disk (models ≫ RAM) | **PARTIALLY RESOLVED.** Streaming is built and PROVEN end-to-end on OLMoE with faithfulness graded (J-018/J-019/J-022); the "models ≫ RAM" headline leg (80B class) is NOT PROVEN — blocker B2, carried to J-123 / J-133. |
| 2 | Expert cache: free-memory-sized + hard cap + reserve | **RESOLVED (PROVEN).** J-018 built exactly this contract; extended by J-024 (fsketch default), J-026 (shared pool), J-028 (pressure re-sizing). |
| 3 | O_DIRECT disk discipline, gentle degradation under load | **RESOLVED, with the row's premise corrected on evidence.** Gentle degradation PROVEN (J-023 NO THRASH, wall-only +5.8 %). O_DIRECT itself was measured and **rejected** (J-019/J-029 verdict: pread + readahead advice is the discipline). The row's intent — a measured disk discipline + no thrash collapse — is closed; its named mechanism is not adopted, on Aesir's own numbers. |
| 4 | Expert read-ahead prefetch (decode + prefill variants) | **RESOLVED as a MEASURED REJECTION** for router-shadow expert prefetch (J-025, oracle ceiling included). Disk-level readahead advice (a different mechanism) is adopted in J-019. A latency case for expert prefetch is NOT PROVEN either way and stays named in J-025 §7's reopen conditions. |
| 5 | Cache-conditional dropping of light experts | **RESOLVED as measured, default OFF stands.** J-017 D6 decided the shape; J-024's trial priced it (23.2 % of accesses, 0.152 mass/token-layer @128, streamed −33.7 %); the agreement-cost leg is NOT PROVEN and deferred (§5 item 1). Dropping may not be enabled by default on this evidence. |
| 19 | Whole-pass GPU + VRAM expert tier (meets Part II at J-031) | **PARTIALLY RESOLVED — design/accounting only.** J-031 built the planning layer and priced the tier exactly; execution is NOT PROVEN and stays WANTED for Part IV / the §5 item 5 recipe. |
| 42 | Slash-command family incl. `/experts` | Noted only: `/experts` was "meaningless until Part II" — the cache + statistics surface it would report now exists (J-018 statistics in J-016 vocabulary); the command itself is Part VII work, untouched here. |
| 79 / 82 | Qwen3 MoE (30B-A3B) / Qwen3-Next | Unchanged WANTED, Part VIII (J-122 family / J-123). Part II adds the binding evidence for 82: the pin, the refusal, blockers B2a/B2b (J-032). |

All other Concordance rows are untouched by Part II.

## 7. Honesty ledger of this gate

- Every number in §2 was recomputed at this gate from filed artefacts by the filed script; the run's output is filed beside this doc. Walls inherited from J-022/J-023/J-030 remain MEASURED-INDICATIVE (single runs, machine states as recorded by their slices); this gate re-derives their arithmetic, it does not re-run them.
- No live leg ran at this gate, and none is implied. §5 is the complete list of legs owed to this gate as recorded in the state file and the slice docs (J-024 ×2 legs counted as one item with two halves, per their docs).
- The J-021 token-identity and accounting proofs, and J-015/J-016's measurements, stand on their own slices' on-box records; this gate verified their filed artefacts (§2 groups, §3 census), not the boxes they ran on.
- Machine state at this gate (VM): MemAvailable flickering ~5,438–5,787 MB around the 5,500 MB gate — lightest file/script work only, no inference; /tmp healthy (~3 % of 512 MB); scratch under `~/workspace/.verify-tmp/j034/`, nothing deleted anywhere.

## 8. Banking

Filed on branch `yrsa/janas-j034` (worktree `~/workspace/aesir-janas-j034`, base `664cb523`): this doc, `j034_reverify.py`, `j034_reverify_output.txt`, `j034_unit_test_output.txt` — all under `docs/janas/`, with sha-identical campaign copies in `~/workspace/model-tests/janas/`. Push is by explicit refspec (`git push origin HEAD:refs/heads/yrsa/janas-j034`, foreground) with `git ls-remote` verification that the branch moved and origin/main stayed at `ba7ee09b6b4d09967b571f2f39714e9119dc3772`; the commit hash and the ls-remote lines are recorded in the campaign state file entry for J-034 and in the gate worker's report (a doc cannot contain its own commit hash). No README touched.
