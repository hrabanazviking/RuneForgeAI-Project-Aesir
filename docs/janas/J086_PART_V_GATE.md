# J-086 — Part V Gate: Drafts Evidence Pack

**Slice:** J-086 (Part V — Drafts: speculative decoding, J-071–J-086), Project Aesir Janas clean-room road.
**Roadmap text:** "Part V gate. Drafts evidence pack: identity proof re-run, acceptance tables, net tok/s deltas per pair per text type, the losses named."
**Executed:** 2026-11-01 ~12:00–12:35 EST, in fresh worktree `~/workspace/aesir-janas-j086` on branch `yrsa/janas-j086`, from `yrsa/janas-j085` tip `9c87377be8e6b3167b61c4c4da5f54fd5f15e7db` (verified by `git ls-remote` at gate start: remote `yrsa/janas-j085` == that hash; no remote `yrsa/janas-j086` existed before this slice). Origin/main untouched at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5` (ls-remote verified at gate start and at banking, §7).
**Machine state (VM, stated for every number below):** KVM, 4 vCPU, kernel 7.0.0-39-generic. MemAvailable ~4.10 GB at gate start, flickering down to ~1.3 GB during the runs — below the 5,500 MB inference gate at every moment. No model inference ran anywhere; lightest compiles only, one at a time. purplelongship was not used at all — unreachable (last_seen 2026-11-01T02:07:13Z) and yielded to the 204 road under the coordination law in any case.

---

## 1. Gate verdict

**Part V CLOSED-WITH-DEFERRED-LEGS.**

- The full Part V test surface was **rebuilt and re-run from this gate tree, first-hand, at this gate**: all 14 distinct Part V test modules plus the pre-existing acceptance-arithmetic suite and Part II's expert cache — **16/16 modules build exit 0 and run exit 0; the 14 Part V primaries total 164 test groups PASS, every module's count exactly the count its own slice filed** (§2.1, `j086_test_output.txt`).
- The **deterministic artefacts re-ran byte-identical** where their filed form is the script's raw output (J-076 census, J-077 admission, J-078 pair record, J-079 measurement, J-074 tokenizer probe), and statistic-identical for the J-082 mirror (its filed copy carries a filing header); the **J-080 real-module replay re-ran EXACT at both budgets** against the filed results (§2.2).
- The **doc census passes**: all 15 slice docs (J-071–J-085), all 15 filed test outputs, and all 15 filed inspect outputs in this tree are **sha256-identical** to their campaign copies in `~/workspace/model-tests/janas/` (§2.4).
- The **identity proof stands re-run** (§3.1): greedy speculative emission is token-identical to plain greedy *by construction and by the loop-level long-generation proof* (7 configurations, 2,842 tokens, 797 rounds, re-run at this gate at 8/8 groups). The **live** arch-matrix identity proof is NOT PROVEN and is deferred (§5 item 1).
- **No net tok/s delta exists anywhere in Part V — every pair, every text type: NOT PROVEN** (§3.3). No live speculative round has ever run on any hardware in this road: **G-PROPOSER** (no proposer implementation exists in-tree) and **G-EXECUTOR** (no verify-pass executor or session wiring exists; J-036's gate and the engine facade still fail closed — re-verified first-hand in this tree at this gate, §2.3) block every live leg, and each of the thirteen deferred legs is re-cited in §5 with its blocker and recipe pointer. None is claimed anywhere in this gate.
- Part V built the drafts *accounting and protocol layer entire* — the verify account, the draft loop, the pairing/admission gates, the acceptance instrument, the adaptive controller, the placement planner, the sampling correction, the configuration surface, the loss guard, and the long-session stability harness, all unit-proven — and measured **no live acceptance, no live wall, and no live tok/s**. The losses it *did* measure are named in §3.4.

No README touched. Hailo untouched/parked (no finish-line branch contact, no chip run or probe). No Docker. No Janas source opened — this gate needed no Janas material at all; it re-verifies Aesir's own filed Part V evidence (clean-room law unengaged).

## 2. Re-verification at the gate (PROVEN)

Build line (the slices' own filed recipe): `cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o <staging>/libaesir_par.so -lpthread` (exit 0; `thread_par.c` sha256 `88f19b95…cacd`, library sha256 `2082ce3f…6c28a` — byte-identical to the J-079–J-085 staging builds, as expected from the identical source; this gate's staging was compiled fresh, not reused), then per module `mojo build -I aesir_engine -Xlinker -L<staging> -Xlinker -laesir_par` (Mojo 1.0.0, the J-071 worktree's installed env invoked directly with its pixi activation variables, as J-071–J-085 filed; `pixi run` remains blocked on this VM); runs with `LD_LIBRARY_PATH=<staging>`. Staging on the workspace overlay (`~/workspace/.verify-tmp/j086stage`), TMPDIR redirected there, nothing deleted. Full output: `j086_test_output.txt`.

### 2.1 The suites, re-run (all groups PASS, counts exactly as filed)

| Module (slice) | Groups at gate | Filed by its slice | Result |
|---|---|---|---|
| `test_speculative_verify` (J-071) | 13 | 13 | ALL PASS, exit 0 |
| `test_speculative_loop` (J-072) | 12 | 12 | ALL PASS, exit 0 |
| `test_speculative_identity` (J-073) | 8 | 8 | ALL PASS, exit 0 |
| `test_cross_model_pairing` (J-074) | 10 | 10 | ALL PASS, exit 0 |
| `test_speculative_acceptance` (J-075) | 10 | 10 | ALL PASS, exit 0 |
| `test_mtp_census` (J-076) | 8 | 8 | ALL PASS, exit 0 |
| `test_mtp_head_support` (J-077) | 10 | 10 | ALL PASS, exit 0 |
| `test_assistant_pairing` (J-078) | 10 | 10 | ALL PASS, exit 0 |
| `test_speculative_adaptive` (J-079) | 11 | 11 | ALL PASS, exit 0 |
| `test_speculative_placement` (J-081) | 13 | 13 | ALL PASS, exit 0 |
| `test_speculative_sampling` (J-082) | 17 | 17 | ALL PASS, exit 0 |
| `test_draft_config` (J-083) | 17 | 17 | ALL PASS, exit 0 |
| `test_draft_loss_guard` (J-084) | 12 | 12 | ALL PASS, exit 0 |
| `test_long_session_stability` (J-085) | 13 | 13 | ALL PASS, exit 0 |
| `test_speculative` (pre-existing) | 2 | 2 | PASS, exit 0 |
| `test_expert_cache` (Part II neighbour) | 9 | 9 | PASS, exit 0 |

J-080 has no Mojo suite by design (a measurement slice in the J-025/J-027 shape); its code evidence is re-verified in §2.2. The J-082 suite's chi-square statistics reproduce its filed values exactly at this gate (corrected 8.518 / 5.676 / 0.641 / 1.675 / 5.597, bonus 6.747 — visible in `j086_test_output.txt`), and the J-085 suite reproduces its filed totals (633 rounds, 2,517 drafted, 1,587 accepted, 2,224 emitted, 7,003 leakage checks, 0 violations).

### 2.2 Deterministic artefacts, re-run

| Artefact | Route at this gate | Result |
|---|---|---|
| J-076 MTP census (`j076_mtp_census.py`) | Full re-run over the same 27 VM files | **Byte-identical** to the filed output: 27 files, **0 head tensors in 2,987 tensor-directory entries**, verdicts NO_MTP ×8 / VOCAB_ONLY ×19 |
| J-077 admission (`j077_admission.py`) | Re-run over J-076's census rows | **Byte-identical**: censused=27, admitted=0, refuse_no_mtp=8, refuse_vocab_only=19, refuse_not_proven=5 |
| J-078 pair record (`j078_pair_record.py`) | Re-run | **Byte-identical** to the filed output |
| J-079 measurement (`j079_measurement.py`) | Re-run | **Byte-identical** to the filed output |
| J-074 tokenizer probe (`j074_tokenizer_probe.py`) | Re-run against the VM wave files | **Byte-identical** to the filed output (target fingerprint sha256 `2e7e49d0…80f`; cross-quant IDENTICAL; qwen2-vocab REFUSED at index 151,646; TinyLlama REFUSED at index 0) |
| J-082 mirror (`j082_mirror.py`) | Re-run | Every statistic **identical** to the filed output (the filed copy carries a 4-line filing header the raw script output does not; all statistic lines agree verbatim) |
| J-080 replay (`j080_replay.mojo` through the REAL `ExpertCache`) | Rebuilt from this tree; re-flattened schedule (73,856 rows) from the campaign J-016 trace | **EXACT at both budgets**, every compared counter (hits 25,698 / 56,741; streamed 179,059,584 / 63,839,664 scaled; bypasses / admissions / evictions / evicted-before-reuse / entries / resident all equal to `j080_replay_results.txt`) |
| J-080 results JSON | Recomputed from the filed `j080_streaming_results.json` | Validation gate EXACT (tournament @128/256/512, real-module replay @128/512); trace sha `85e1d241…f99a` and model pin `8c310f14…f3f` as filed; the §3.4 tax cells recompute to the filed values |

### 2.3 Inspection recounts — and the one flagged class

All fifteen Part V inspect scripts were re-run individually from this gate tree: **500 checks in total, 488 PASS, 12 FAIL — and every FAIL is a slice-time snapshot assertion of a single named class**, disposed here, not hidden:

- **Fully clean from the gate tree (exit 0):** J-078 (45/45), J-080 (24/24), J-081 (20/20), J-082 (22/22), J-083 (20/20).
- **J-071 (20/23):** its assertions `speculative.mojo is 142 lines` (now 150), `draft bound: default 4, hard limit 64`, and `SpeculativeEngine referenced only by its module + tests` are superseded by **J-072's own documented commit `0017bebe`** — the legacy-bound reconciliation (hard limit 15, default 4 = initial k, +8 lines), verified first-hand at this gate by `git log` (that commit is the *only* post-J-071 change to `core/speculative.mojo` in the whole Part V lineage) — and by the J-072/J-082 modules referencing the engine, which is Part V's own design.
- **J-072 (18/19), J-073 (39/40), J-074 (40/41), J-075 (52/53), J-076 (53/54), J-077 (40/41), J-079 (51/52):** the single FAIL in each is its *"imported only by its own test"* assertion. The importer lists the failures print contain **only later Part V modules and their tests** — the road's own bindings (J-077 binds J-076's classifier, J-078 binds J-077/J-074, J-079/J-084/J-085 bind J-075's ledger, J-085 binds the loop) — and **no session, facade, or live wiring anywhere**.
- **J-084 (21/22), J-085 (23/24):** the single FAIL in each is its *"no other tree file changed"* slice-time diff assertion, which cannot hold in a descendant tree (J-084's tree now also carries J-085's files; J-085's re-run was taken with this gate's own `j086_test_output.txt` already present in the tree).

**Disposition:** these assertions were true in each slice's own tree and were the right assertions there — they pinned that no wiring was faked *at that slice*. In a gate tree they fail mechanically because the road grew exactly as its later slices document. No FAIL touches a number, a suite, or a built module; no prior slice's file is edited by this gate (the J-070 precedent: corrections live in the gate's record, not in rewritten slice files). The substantive claim underneath every one of them — **no proposer implementation and no verify executor/session wiring exists** — was verified directly at this gate and still holds: in this tree, `aesir_engine/aesir.mojo:1086` the facade's `speculative_generate` raises *"speculative model generation and KV reconciliation are not implemented"*, and J-036's `require_draft_check_use()` still fails closed (`git grep`, this tree). **G-PROPOSER and G-EXECUTOR stand.**

### 2.4 Doc census

All 15 Part V slice docs (J-071–J-085), their 15 filed test outputs, and their 15 filed inspect outputs are sha256-identical between this branch tree (`docs/janas/`) and the campaign copies (`~/workspace/model-tests/janas/`) — 45/45 files, verified by hash at this gate and asserted mechanically by `j086_inspect.py`.

## 3. The drafts evidence pack

### 3.1 Identity proof — status

| Form | Status | Evidence |
|---|---|---|
| Greedy identity **by construction** | **PROVEN** | J-071's verify account derives emission from the target list only; acceptance is a strict prefix; KV/context rollback exact; a greedy round consumes zero RNG draws, enforced. Re-run at this gate: 13/13 groups. J-071's claim verdict mechanically refuses an identity claim grounded on a broken account and any speed claim grounded on accounting. |
| Greedy identity at **loop level, long generation** | **PROVEN** (SIMULATED target choices) | J-073: 7 configurations, **2,842 tokens, 797 rounds** — speculative emission token-for-token identical to plain greedy over the whole generation in every configuration, final state exact (KV/context, RNG word, proposer-KV accounting); all three proposer slots incl. in-generation slot switching; band-top k=15; capacity-shortened rounds; always-right / always-wrong (295 consecutive zero-accepted rounds) / alternating / coincidence-past-mismatch adversarial proposers; a negative control proves the checker can fail (divergence at exactly index 257 / 599). Re-run at this gate: 8/8 groups. |
| Sampled identity (distribution) | **PROVEN** (seeded fixtures) | J-082: the rejection correction over the *shaped* distributions passes chi-square at α=0.001 in all five registered cases + the bonus-token case, with the naive uncorrected control failing as required in every case (finite-huge statistics in the untruncated cases; structural zero-bin failures where the draft's support includes target-forbidden tokens). The independent Python mirror reproduces every statistic. Re-run at this gate: 17/17 groups + mirror (§2.2). |
| Greedy identity **live, per architecture** | **NOT PROVEN / DEFERRED-WITH-REASON** | No live round has run on any model (G-PROPOSER + G-EXECUTOR, §2.3). Recipe: §5 item 1 (J-073 doc §7). Under J-071's verdict rule the live claim stands REQUIRES_LIVE until that recipe files identical live ids. |

### 3.2 Acceptance tables — as filed, with their honesty classes

The only acceptance table Part V files is J-075's, and it is **SIMULATED**: synthetic rounds for the first pair's shape (proposer kind `cross_model`, pair id 1, k=4, ten rounds per row) built through J-071's account from stated draft/target lists. No model drafted and no model verified for any row. **These are fixture rates for the instrument, not real-pair acceptance, and no row may be quoted as a pair's acceptance.**

| Pair | Text type | Language | Rounds | Drafted | Accepted | Rate |
|---|---|---|---|---|---|---|
| cross_model / 1 | prose | english | 10 | 40 | 34 | 85.00% |
| cross_model / 1 | prose | italian | 10 | 40 | 12 | **30.00%** |
| cross_model / 1 | prose | *(aggregate)* | 20 | 80 | 46 | 57.50% |
| cross_model / 1 | code | not_applicable | 10 | 40 | 36 | 90.00% |
| cross_model / 1 | structured | not_applicable | 10 | 40 | 31 | 77.50% |
| cross_model / 1 | *(all rows)* | — | 40 | 160 | 113 | 70.62% |

What the table proves is the *instrument*: the ledger separates (kind, pair, text type, language) so the Italian-prose collapse is visible in its own row (30.00%, histogram bins 0/1/2 with no fully-accepted round) instead of hiding inside the prose aggregate (57.50%) — the census's Italian lesson reproduced at the SIMULATED class. Real-pair acceptance for every row is **NOT PROVEN** (§5 item 3).

Supporting fixture evidence, all SIMULATED and labelled as such in its own doc: J-079's adaptive-depth replay (hot/cold/mixed/switch regimes against fixed k — §3.4), J-080's modelled acceptance regimes over the MEASURED J-016 trace (§3.4), and J-085's long stream (633 rounds, 2,517 drafted, 1,587 accepted over the J-033 soak shape — a stability fixture, not an acceptance measurement).

### 3.3 Net tok/s deltas per pair per text type — NOT PROVEN, per pair

**No net tok/s delta exists for any pair at any text type.** No live speculative round has run, so no speculative wall exists to delta against a plain wall. The table the roadmap asks for, filled honestly:

| Pair (as named by its slice) | prose | code | structured | Blocker |
|---|---|---|---|---|
| Cross-model Qwen3-0.6B → Qwen3-4B (J-074 pair 1) | NOT PROVEN | NOT PROVEN | NOT PROVEN | Drafter file absent from the VM; pair tokenizer identity NOT PROVEN (target side pinned, §2.2); G-PROPOSER + G-EXECUTOR |
| MTP head on a WITH_MTP file (J-077) | NOT PROVEN | NOT PROVEN | NOT PROVEN | Zero proven WITH_MTP files exist (J-076 census: 0 heads in 2,987 entries; every named case ABSENT-FILE / NOT PROVEN); no head executor in-tree |
| Assistant-model pair, Gemma pattern (J-078) | NOT PROVEN | NOT PROVEN | NOT PROVEN | Assistant file ABSENT-FILE at ledger level; no Gemma file on the VM; G-PROPOSER + G-EXECUTOR |
| Conversation (prompt-lookup) drafts (J-072 slot) | NOT PROVEN | NOT PROVEN | NOT PROVEN | No conversation proposer is built; G-EXECUTOR |

Janas's published cross-model figure (1.14× on its dense pair) remains **Janas's number on Janas's machine** — a target for §5's legs, never quoted as Aesir's. Any live tok/s claim for a (pair, regime, k, budget) cell must additionally first repay that cell's J-080 byte tax (§3.4) and, for a GPU check, J-081's per-round crossing account.

### 3.4 The losses, named

1. **The byte tax (J-080, SIMULATED acceptance on the MEASURED J-016 trace; BATCH-ALL net streamed bytes per emitted token vs plain sequential decode).** Speculation over the Part II expert stream taxes at every depth, in every acceptance regime, at both operating budgets. Cold text: **+47.10% / +135.55% / +307.33%** @128 (k=2/4/8) and **+38.50% / +104.18% / +193.00%** @512. Mixed: +19.48% / +49.40% / +151.20% @128; +17.69% / +38.76% / +106.22% @512. Hot: +0.21% / +0.51% / +13.58% @128; +0.46% / +0.28% / +10.63% @512. The floor tax at *perfect* acceptance is +0.2…+2.1% — speculation pays a byte tax even when it never misses. The dominant term is rejected-suffix waste, multiplicative in (k − A). **Verdict as filed: MIXED** — BATCH-PREFIX beats SEQ in exactly one cell (mixed / k=2 @512, **−0.33%**); no buildable BATCH-ALL cell is cache-neutral. This grades streamed bytes only; the wall-clock case for speculation is NOT PROVEN either way (§5 item 8).
2. **The step floor (J-084, exact arithmetic over filed rows).** A pair pays on steps iff its acceptance rate beats its drafter's relative step cost r — the break-even rate is exactly r at every k. First-pair floor (0.6B/4B parameter ratio): **r = 1500 bp**; worst-case admissible drafter (resident bytes at most half the target's): **r = 5000 bp**. Against the floors: the Italian fixture row (3000 bp) clears the light floor and **FAILS the worst-case floor** — on steps alone the Italian collapse is a loss only for a heavy drafter; J-079's cold replay at fixed k=4 (2500 bp) **FAILS both floors**; mixed (5625 bp) and hot (10000 bp) clear both. On bytes, cold loses at *every* depth (item 1). The guard built on this floor disables a (pair, text-type, language) row at the close of the **second consecutive losing 4-round window** — round 8 at the earliest — and its live disabling is deferred (§5 item 11).
3. **Adaptive depth's limit (J-079, SIMULATED fixture replay).** Adaptive k shallows cold waste from fixed-k4's 144 wasted drafts to 56 (cold regime) and tracks the switch regime (trajectory 4→6→8→…→2, 5 moves) — but shallowing cannot cure a loss that is still +47.10% in bytes at k=2: when shallowing has done its work and the row still loses, the honest move is J-084's stop. Fixed deep k in cold text is the worst configuration measured on this road's cache (+307.33% at k=8 @128).
4. **Placement losses (J-081, PLAN class).** The reverse direction (GPU draft + CPU check) is priced and never kept while a non-refused GPU check exists; every GPU check of an MoE target is REFUSED by J-031 admission and its refused price stays on the record (the expert stream re-paid as upload: H2D 1,000,016 B on the filed fixture); iGPU combinations are priced (0 copy bytes; up to 4,500,000,000 B contended) and refused by name — no backend exists.
5. **The census's empty hand (J-076/J-077).** Zero proven MTP heads anywhere readable: the 8 readable full files provably carry none (398 tensors ×7 Zen quants + TinyLlama), the 19 vocab fixtures are vocab-only, and every family the docs name as head-carrying (Qwen3.5 dense, Qwen3.6/qwen35moe, Qwen3-Next, Qwen3.8-Flash-Next, Gemma 4 assistant) is ABSENT-FILE or unread on unreachable hardware. Admission over the real census rows therefore admits **0** and refuses 27 by name (8 NO_MTP + 19 VOCAB_ONLY) plus 5 named NOT PROVEN cases — the refusal *is* the slice's result, in the J-032 shape.

### 3.5 What Part V built (the as-built layer)

In the order a session would meet it: **J-071** `core/speculative_verify.mojo` — the verify account (emission derived from the target list only, strict-prefix acceptance, exact KV/context rollback, zero-RNG-draw invariant for greedy rounds, proposer shapes for the three slots, identity checker, mechanical claim verdict). **J-072** `core/speculative_loop.mojo` — propose-k/verify/accept-prefix+one over the account, slot dispatch for head/conversation/cross-model proposers, k planning with explicit KV-capacity shortening, the legacy bound reconciled (hard 15, default 4). **J-073** the loop-level identity proof suite (no production code changed). **J-074** `core/cross_model_pairing.mojo` + the tokenizer probe — pairing rules with tokenizer identity *verified by full-table comparison*, never assumed (the qwen2-vocab witness: same vocab size, same model string, still refused at index 151,646). **J-075** `core/speculative_acceptance.mojo` — the permanent (kind, pair, text-type, language) acceptance ledger + classifier. **J-076** `core/mtp_census.mojo` — the header/directory-only head classifier. **J-077** `core/mtp_head_support.mojo` — admission binding the census to the loop's dispatch (WITH_MTP admitted, everything else refused by name, never silently plain). **J-078** `core/assistant_pairing.mojo` — assistant-pair admission with the pair sized once through J-026's shared pool (headroom charged once). **J-079** `core/speculative_adaptive.mojo` — the windowed deepen/shallow controller over J-075's rows. **J-080** the streaming interplay measurement (no new module; simulator + real-module replay). **J-081** `core/speculative_placement.mojo` — draft/draft-check placement planning over Part III's engine + J-031's admission. **J-082** `core/speculative_sampling.mojo` — the rejection correction over shaped distributions, chi-square-proven. **J-083** `core/draft_config.mojo` — `--mtp` / `--no-mtp` / `--draft <model>` / `--draft-k` on chat + server surfaces with env equivalents and learned-file persistence, every use still refused at the J-036 gate. **J-084** `core/draft_loss_guard.mojo` — the measured floor + the two-window disable rule with a pinned log record. **J-085** `core/long_session_stability.mojo` — the J-033-shaped long stream over the composed controllers: no drift (divergence −1 over 2,224 emitted), no leakage (**7,003 checks, 0 violations**, rollback identity exact 930 = 2,517 − 1,587), memory held (KV/context bound 512 → 355 observed; ledger plateau at 5 rows; the expert-cache resident bound explicitly NOT exercised — owned by §5 item 12's live leg).

**The standing gap every Part V slice records, stated once for the part:** no proposer implementation and no verify-pass executor/session wiring exists behind any of these accounts. The accounts are the filed evidence; the builds they name are the deferred legs of §5. Nothing in Part V fakes a wall, an acceptance, or a tok/s.

## 4. Concordance — every Part V slice, its final state and banked tip

Branch chain verified at this gate by `git ls-remote` (each branch's remote tip == the next slice's recorded base; origin/main == `605562f6b919a0f58fa6decd0b45a83cdc41a6d5` throughout).

| Slice | Final state | Banked branch @ tip |
|---|---|---|
| J-071 Verification-first design | CLOSED (verify account PROVEN by construction; its live legs are J-072/J-073 by roadmap order) | `yrsa/janas-j071` @ `c6626f26` |
| J-072 Draft loop | CLOSED (loop PROVEN over the account; live wiring is §5 item 1's dependency) | `yrsa/janas-j072` @ `5b09d16a` |
| J-073 Token-identity proof | CLOSED-WITH-DEFERRED-LEG (loop-level identity PROVEN; live arch-matrix leg deferred, §5.1) | `yrsa/janas-j073` @ `452a2eb8` |
| J-074 Cross-model drafts | CLOSED-WITH-DEFERRED-LEG (pairing rules + tokenizer evidence PROVEN; live pairing deferred, §5.2) | `yrsa/janas-j074` @ `eb3f1ec6` |
| J-075 Acceptance measurement | CLOSED-WITH-DEFERRED-LEG (instrument PROVEN; fixture table SIMULATED; real-pair acceptance deferred, §5.3) | `yrsa/janas-j075` @ `0fd9095e` |
| J-076 MTP census in files | CLOSED-WITH-DEFERRED-LEG (VM census PROVEN, 0 heads; named-case on-box census deferred, §5.4) | `yrsa/janas-j076` @ `50c31c61` |
| J-077 MTP head support | CLOSED-WITH-DEFERRED-LEG (admission gate PROVEN, 0 admitted on real rows; live drafter leg deferred, §5.5) | `yrsa/janas-j077` @ `c5bfc450` |
| J-078 Assistant-model drafts | CLOSED-WITH-DEFERRED-LEG (pair admission + budget PROVEN on fixtures; measured gain deferred, §5.6) | `yrsa/janas-j078` @ `427326fc` |
| J-079 Adaptive depth | CLOSED-WITH-DEFERRED-LEG (controller PROVEN; tuning measured SIMULATED; live tuning deferred, §5.7) | `yrsa/janas-j079` @ `9f17123c` |
| J-080 Drafts + streaming | CLOSED-WITH-DEFERRED-LEG (byte interplay measured SIMULATED on the MEASURED trace, verdict MIXED; live session deferred, §5.8) | `yrsa/janas-j080` @ `5f340234` |
| J-081 Drafts + placement | CLOSED-WITH-DEFERRED-LEG (placement planning PROVEN at PLAN class; live placed round deferred, §5.9) | `yrsa/janas-j081` @ `40bb186b` |
| J-082 Sampling correctness | CLOSED-WITH-DEFERRED-LEG (correction chi-square-PROVEN on fixtures; live sampled pair deferred, §5.10) | `yrsa/janas-j082` @ `6284bfb2` |
| J-083 Draft configuration surface | CLOSED-WITH-DEFERRED-LEG (surface + persistence PROVEN, use gate still refused; live configured run deferred, §5.11) | `yrsa/janas-j083` @ `2e9c0195` |
| J-084 When drafts lose | CLOSED-WITH-DEFERRED-LEG (floor derived, guard PROVEN; live disabling deferred, §5.12) | `yrsa/janas-j084` @ `23a61d5c` |
| J-085 Long-session stability | CLOSED-WITH-DEFERRED-LEG (all three legs PASS at SIMULATED fixture class; live long session deferred, §5.13) | `yrsa/janas-j085` @ `9c87377b` |

**Counts:** 15 slices — **2 CLOSED** (J-071, J-072), **13 CLOSED-WITH-DEFERRED-LEG**. Every deferred leg traces to the same two standing blockers plus machine access: **G-PROPOSER** (no proposer implementation in-tree), **G-EXECUTOR** (no verify-pass executor/session wiring; the J-036 gate and facade fail closed), purplelongship unreachable, and the VM below its inference gate.

**Concordance deltas for Part V rows** — against `DELTA_TABLE.md` (the Concordance frozen at J-014; grades below are this gate's report, the keeper amends the table):

| Row | Subject | Part V outcome |
|---|---|---|
| 28 | Speculative verification identity (text unchanged with drafts) | **PARTIALLY RESOLVED, advanced.** The integrated loop now exists over the verify account (J-071/J-072) and identity is PROVEN by construction + at loop level over long generations (J-073) and in distribution for sampling (J-082); the row's remaining gap is exactly the live arch-matrix proof — NOT PROVEN, deferred (§5.1). The frozen row's "no integrated loop, no KV ownership" is superseded: the loop owns KV/context rollback exactly; a *session* still does not. |
| 29 | MTP-head drafts | **PARTIALLY RESOLVED — admission only.** The census classifier + admission gate are built and PROVEN (J-076/J-077); zero proven WITH_MTP files exist, no head executor exists, and no MTP draft has run. Execution NOT PROVEN, deferred (§5.4, §5.5). |
| 30 | Assistant-model drafts (drafter reads main KV) | **PARTIALLY RESOLVED — admission only.** Pair admission + shared-pool budget PROVEN on fixtures (J-078); the assistant file is ABSENT-FILE at ledger level and measured gain is NOT PROVEN, deferred (§5.6). |
| 31 | Cross-model drafts (same-vocab pair) | **PARTIALLY RESOLVED — rules + target-side evidence.** Pairing rules PROVEN and the target's tokenizer fingerprint pinned from the real file (J-074); pair tokenizer identity and live pairing NOT PROVEN (drafter file absent), deferred (§5.2). |
| 32 | Conversation (prompt-lookup) drafts | **PARTIALLY RESOLVED — slot only.** The loop's conversation slot exists in dispatch and in J-073's slot-switching proof; no conversation proposer is built. NOT PROVEN live, deferred (§5.1's recipe carries it as a slot). |
| 33 | Adaptive draft sizing + periodic re-trial | **PARTIALLY RESOLVED.** The adaptive controller is built and PROVEN, its tuning measured against fixed k at the SIMULATED class (J-079), and the disable half of the row's intent is built in J-084's guard; live tuning and live disabling are NOT PROVEN, deferred (§5.7, §5.12). The periodic re-trial of a *live* choice rides the same legs. |

Row 62 (MTP-preserving conversion/extraction, Part VIII J-121) is untouched by Part V; J-076/J-077 give it its census ground. All other Concordance rows are untouched by Part V.

## 5. Deferred legs re-cited at this gate (all NOT PROVEN / DEFERRED-WITH-REASON)

None of these ran at this gate. Common blockers, stated once and applying where named: **(a) G-PROPOSER** — no proposer implementation exists in-tree (no MTP head has been read from any file, no assistant/cross-model pairing has run, no conversation proposer is built); **(b) G-EXECUTOR** — no verify-pass executor or session wiring exists (the J-036 use gate and the facade's `speculative_generate` fail closed, §2.3); the wiring these legs need has no slice of its own yet in Part V, as J-073 §7 names honestly; **(c)** purplelongship is unreachable (last_seen 2026-11-01T02:07:13Z) and yielded to the 204 road in any case — every live recipe runs there in a guarded idle gap, checking `ROADMAP_204_STATE.md`'s heartbeat first, one heavy run at a time, load and temperature stated; **(d)** the VM is below its 5,500 MB inference gate (flickering ~1.3–4.1 GB during this gate). Every recipe additionally re-pins its files by full sha256 before any round and grades ids-first under the raw-oracle discipline (teacher-forcing rank + logit gap vs the ggml CPU comparator on the raw prompt; never `llama-cli --single-turn`).

1. **J-073 live arch-matrix identity** — greedy speculative ids vs greedy plain ids, token-for-token over long generations, per architecture. Recipe: J-073 doc §7. Blocked by (a) + (b) + (c) + (d). Carries the live halves of J-071/J-072 (their design names this slice's leg as the proof) and the conversation slot's live form (row 32).
2. **J-074 live pairing (Qwen3-0.6B → Qwen3-4B)** — fetch/pin the drafter file, run the §3 tokenizer comparison for the pair (its step 2 discharges pair tokenizer identity), then live rounds. Recipe: J-074 doc §6. Blocked by (a) + (b) + (c) + (d); the drafter file is additionally absent from the VM.
3. **J-075 real-pair acceptance** — acceptance per (pair, text type, language) on real pairs, the Italian-prose row included, filed through the J-075 ledger. Recipe: J-075 doc §6. Blocked by (a) + (b) + (c) + (d); depends on items 1–2's wiring and on J-077/J-078's pairs under their own pair ids.
4. **J-076 named-case on-box census** — header/directory-only reads of the named cases where they live (Qwen3-Next-80B on purplelongship incl. a beside-the-model MTP block file; the Gemma mains PRESENT_VERIFIED on the laptop; OLMoE/Granite directories), same classifier, no inference. Recipe: J-076 doc §5. Blocked by (c); filed as J-077's first act and re-cited here.
5. **J-077 live MTP drafter** — "reads and runs them as drafters" for a proven WITH_MTP file. Recipe: J-077 doc §5 (4 steps). Blocked by: zero proven WITH_MTP files exist (item 4 is its first act) + (a) + (b) + (c) + (d).
6. **J-078 live assistant pair / measured gain** — the Gemma-pattern pair loaded together, gain measured. Recipe: J-078 doc §6. Blocked by: assistant file ABSENT-FILE at ledger level + (a) + (b) + (c) + (d).
7. **J-079 live adaptive measurement** — the controller tuning k live on a real pair, measured against fixed k on walls. Recipe: J-079 doc §6. Blocked by (a) + (b) + (c) + (d).
8. **J-080 live drafts + streaming session** — a live speculative session over the Part II expert stream on the J-022 model (OLMoE pin `8c310f14…f3f`), live cache counters + walls per (regime, k, budget) cell against §3.4's tax table. Recipe: J-080 doc §6. Blocked by (a) + (b) + (c) + (d).
9. **J-081 live placed round** — the kept combinations (§3.4 item 4) executed live: CPU draft + GPU check for independent dense drafts, both-on-GPU for coupled drafts, both-on-CPU for MoE. Recipe: J-081 doc §6. Blocked by (a) + (b) + (c) + (d); the MoE GPU-check form additionally needs J-031's unbuilt device pieces.
10. **J-082 live sampled pair** — a real pair's shaped distributions graded by the slice's own rule shape (seeded chi-square, naive control failing). Recipe: J-082 doc §6. Blocked by (a) + (b) + (c) + (d).
11. **J-083 live configured draft run** — a run actually driven by the filed configuration surface (`--mtp` / `--draft` / `--draft-k`, env, learned file) end-to-end. Recipe: J-083 doc §6. Blocked by (a) + (b) — the use gate refuses by design until an executor exists to honour — + (c) + (d).
12. **J-084 live loss-guard disabling** — a live losing row disabled in-session by the guard, the pinned log record filed from a real session. Recipe: J-084 doc §6. Blocked by (a) + (b) + (c) + (d).
13. **J-085 live long session** — the J-033 soak shape with drafts live: ≥2,000 generated tokens across mixed prompts, drift/leakage/memory graded on real accounts (incl. the expert-cache resident bound the fixture harness explicitly did not exercise). Recipe: J-085 doc §6 (6 steps). Blocked by (a) + (b) + (c) + (d).
14. **The full counted suite (`run_all`) on this tree.** Not run at this gate, per the standing Part II/III/IV gate precedent (VM memory gate); the standalone suites re-run in §2 are the filed evidence.

## 6. Honesty ledger of this gate

- Every number in §2 was recomputed or re-run at this gate from the filed artefacts, by the routes named per item: suites rebuilt and re-run (not re-derived from prose), deterministic scripts re-run, the census re-run over the real files, the replay rebuilt and re-run. Where a re-run was not possible or not the honest route, §2 says so (the J-082 mirror's filing header; the §2.3 inspect disposition).
- No live leg ran at this gate, and none is implied. §5 is the complete list of legs owed to this gate as recorded in the slice docs (J-073–J-085, one per slice) plus the standing `run_all` item.
- The one imperfection this gate found is filed in full in §2.3: twelve slice-time snapshot assertions in earlier inspect scripts no longer pass in a descendant tree, each traced to a documented later-slice change or to the gate's own files, none touching a number, a suite, or a built module. No defect was found in any Part V module, number, or slice record; nothing was left unfixed that is a defect — the inspect scripts' filed outputs stand as their slices' records, and this section is their correction's home, per the J-070 precedent.
- Machine state at this gate (VM): MemAvailable ~4.10 GB at start flickering to ~1.3 GB — lightest compiles and scripts only, no inference; scratch under `~/workspace/.verify-tmp/j086stage` + `j086build`, nothing deleted anywhere.

## 7. Banking

Filed on branch `yrsa/janas-j086` (worktree `~/workspace/aesir-janas-j086`, base `9c87377b`): `docs/janas/J086_PART_V_GATE.md`, `docs/janas/j086_inspect.py`, `docs/janas/j086_inspect_output.txt`, `docs/janas/j086_test_output.txt` — with sha-identical campaign copies in `~/workspace/model-tests/janas/`. Two commits (gate artefacts, then doc), push by explicit refspec `refs/heads/yrsa/janas-j086:refs/heads/yrsa/janas-j086` (foreground git only), `git ls-remote` verification that the branch moved and origin/main stayed at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`; the commit hashes and ls-remote lines are recorded in the campaign state file entry for J-086 and in the gate worker's report (a doc cannot contain its own commit hash). No README touched.
