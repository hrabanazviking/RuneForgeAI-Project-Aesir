# PROJECT AESIR — MASSIVE CONTINUATION & FULL-SIZE ROADMAP

Commissioned by Volmarr, 2026-10-28 ~00:13 EDT: *"write a massive roadmap for continuing all this work and also for downloading and developing all other size types of the models too in this same vein."*

This roadmap continues every open Aesir line in its current vein — same laws, same proof discipline, same branch-and-banking order — and then extends the model wave to **every size type**: every quant rung published for the nine wave models (from every sibling repo), and the parameter-size siblings of those families after them.

---

## Governing laws (unchanged, binding on every slice)

1. **Accelerator-First Law** (Volmarr, 2026-10-27): on any device with a GPU or NPU, most of a model runs on the accelerator. CPU is permitted only as (1) spillover past VRAM, (2) an assist that measurably, massively speeds the whole run. A silent all-CPU run on an accelerator device is a FAILED slice, reported with numbers.
2. **Tri-device tiering**: on GPU+NPU+CPU devices — NPU first, then GPU, then CPU — with the work divided across everything the device has for maximum speed, not a rigid fill-order.
3. **Threading clause**: threaded use of ALL available cores of every processor. **Politeness rider**: never choke the machine's other life. **Thermal clause**: Aesir watches temperatures and throttles itself before the danger zone; the all-cores ambition bows to the machine's health.
4. **Never leave a discovered bug unfixed** (Volmarr, 2026-10-27): discovery creates the duty to repair, in-scope or commissioned on the spot. Escalate only where the repair crosses the standing pause-lines.
5. **Honest evidence**: grades are PROVEN / NOT PROVEN / REFUTED, with first-hand numbers. A bounded search's negative is a route marker, never an end (Possibility Law; Never-Stop Order). Vendor software limits are never hardware verdicts.
6. **In-house verification**: the local battery is the gate; GitHub Actions is manual-only everywhere (Volmarr's standing default) and is never the verification of record.
7. **Banking discipline**: branch → verify → merge to main by explicit refspec → verify the remote moved. State files are the baton — every line writes its state as it goes. README.md files are never overwritten. No Docker, ever.
8. **Two test sites**: Yrsa's VM (EPYC) and purplelongship (Ryzen 9 4900HS + RTX 2060 Max-Q, sm_75, 6 GB VRAM). Every model+quant verdict is recorded per site, per placement, honestly.

## State of the realm at writing (verified 2026-10-28 ~00:15 EDT)

- **Remote heads**: main `4baa1714` · wave `27f0a41c` · vision `811ffb18` · gpu `3dafab3e` · llvm-fix `501cb6df` · step33-zero `4baa1714` (= main).
- **Banking**: step-33 policy slice banked to main. Vision + GPU branch merges into main IN PROGRESS (banking worker).
- **Model wave** (coordinator's ledger is the authority): SmolLM2 DONE except IQ verdicts (IQ1_S broken, debug round 2 in flight; IQ2_M coherent but slow-path). Oprius static DONE (5 K-quants correct-with-caveat). Coder-3B: Q4_K_M/Q5_K_M/Q6_K ✓, Q3_K_M file degenerate on BOTH engines (engine faithful), crown Q8_0 tuned 777 s → 270 s, Q2_K in flight. Zen-4b: qwen3 arch, baseline BROKEN (degenerate loops, oracle clean) — qwen3 worker fixing. Ministral: mistral3+YaRN, registered, baseline battery next. Oprius-i1, Coder-7B, Stheno (VM side), Gemma-4: not started. Wave engine gains already on its branch: fast GEMM kinds 10/11/13 (37–60×), Q8_0 threading, IQ merge (partial), Q8_0 SIMD fast path (2.88×).
- **Vision**: slices 0–5 landed (encoder oracle-exact, injection proven at assembly, PNG/JPEG, Ministral/Pixtral spec-admitted). End-to-end image chat NOT PROVEN — waits on the crash fix + the convergence slice (Part I).
- **GPU line**: downloads CLOSED both phases (60/60 files sha256-verified on the laptop, 136 GB store). Baselines: Stheno Q4_K_S full-GPU 17.6 tok/s; crown Q3_K_M whole-GPU correct ~4 tok/s (generic matvec). Spill S1+S2 built and pushed; S3 proof run staged behind the crash fix. Gemma4-on-2060 PTX defect isolated to `element_kernel`; a fix is being verified (unproven at writing). Qwen2 CUDA profile missing (Coder-7B crown's road).
- **Compiler crash**: hunt in progress; wall fully mapped — the `_gemm_k_*` worker family only lowers for AVX-512 targets today (laptop default/znver2 SEGFAULT; VM x86-64-v3/znver2 split-operator abort; sibling `_gemm_k_vnni_range` crashes too; EPYC-native builds SIGILL on Zen 2).
- **Step 33**: 237 findings remain (corrected count, verified finding-for-finding): 176 across 94 pre-schema ledger entries awaiting faithful migration; 61 absolute-path findings in hand-authored files; +1 orphaned ledger-schema test with a stale baseline.
- **Hailo-10 finish line**: PARKED at Volmarr's word (reconfirmed 2026-10-27). Resume point slice 4.126. This roadmap does not reopen it; Part IV names its place in the order for when he gives the word.

---

# PART I — CLOSE THE OPEN FRONTS (slices 1–24)

*Nothing new starts until the ground already won is banked, proven, and merged.*

- **S-001** Banking completion: vision branch merged to main with registry reconciliation (both sides' cases preserved, collisions renumbered with dated notes, counts recounted true). Gate: step-3 compile + step-31 + vision unit suites green on the merged tree; ls-remote verified.
- **S-002** Banking completion: GPU branch merged to main the same way (spill S1/S2 + probes; additive-first conflict discipline). Gate: step-3 compile + step-31 green; CUDA probe sources compile clean.
- **S-003** Post-banking census: one verified statement of main — head, registry count, ledger totals, battery score — written into the CI ledger directory as the new baseline every later part measures against.
- **S-004** Crash hunt, reproduction matrix closure: every invocation class (host/target/opt-level) × crash-or-clean, on VM + laptop, from the untouched base. Gate: the matrix is complete and committed as the fix's test harness.
- **S-005** Crash hunt, bisection to the minimal construct: smallest reproducer that splits-or-segfaults, for `_gemm_k_fast_worker` and the `_gemm_k_vnni_range` sibling separately.
- **S-006** Crash fix, source-level restructure of the offending construct (numerics MUST NOT change). Gate: before/after outputs bit-identical on the compute + inference test programs over identical inputs.
- **S-007** Crash fix, acceptance A: the counted master run (`run_all`, 271+ cases) EXECUTES end-to-end via its corrected documented command and prints its counted results.
- **S-008** Crash fix, acceptance B: `mojo build --mcpu znver2` of a CPU-K-quant graph (the spill probe) compiles clean on the VM and on the laptop.
- **S-009** Crash fix, acceptance C: the vision line's `test_inference` base compiles on the laptop (the untouched-base control that crashed identically).
- **S-010** Crash fix, merge under the standard pattern; battery steps 3/4/5 green post-merge; wave correctness discipline re-confirmed (heretic-3.2-1b sanity stream).
- **S-011** SPILL S3 — the proof run: build `--mcpu znver2` + shim staging; run `test_llama3_spill <Stheno Q4_K_M> 4096 31` on purplelongship. Gate: tokens identical to the whole-GPU runs; [SPILL] line reads 31/32 GPU + 1 CPU; VRAM/RAM/tok-s/temperature report filed. (Unblocked by S-008.)
- **S-012** Spill hardening: spilled-run regression gate added to the battery (a canned over-VRAM case that must produce the split line + identical tokens, forever).
- **S-013** Spill policy instrumentation: every spilled run records GPU-resident share, both memories, tok/s vs full-GPU (smaller quant) and full-CPU, correctness verdict, core utilization, peak temperature — into GPU_2060_STATE.md's table format, automatically.
- **S-014** Gemma4 PTX fix verification: the element-kernel repair (in verification at writing) proven by the per-kernel probe (all kernels OK on sm_75) AND the full session run of the real Q4_K_M file: admission line, correct output, timings, thermals. If the fix fails verification, the slice becomes the minimal-reproducer + NOT FIXED report with untried roads named.
- **S-015** Gemma4-on-2060 baseline row: the full law-mandated record (placement, VRAM, RAM, tok/s, °C) entered beside the Stheno rows.
- **S-016** Coder Q2_K semantics verdict (wave-deferred question): does Aesir's Q2_K path match the oracle's semantics on Coder-3B Q2_K, token-for-token where distributions are peaked? The Oprius caveat resolves here, one way or the other, in writing.
- **S-017** Step-33 migration resumption: the 94 pre-schema entries migrated faithfully, in family batches (AES-NUM first), each batch re-running step 33 and recording the exact delta. No exemptions; every migrated field is the entry's own words relabeled/split.
- **S-018** Step-33 migration completion: findings from family (a) at zero; step 31 pin re-accounted exactly.
- **S-019** The 61 path findings, road decision executed: per-file cleanup of machine-local absolute paths in hand-authored files (prof/, docs/, data/, scripts/, tests/) — or the widened exemption, ONLY if Volmarr rules it. Default road: cleanup.
- **S-020** Orphaned `scripts/test_ledger_schema.py` repaired to the true current baseline and wired into the battery, or retired with a dated note if superseded — decided by what it actually covers vs `test_check_doc_drift.py`.
- **S-021** Step-33 ZERO: full battery run where step 33 reports zero with all negative probes still caught (the zero-slice's probe suite, extended). The honest end of the consistency campaign.
- **S-022** Wave branch checkpoint audit: every wave local commit pushed; the wave's `docs/MODEL_WAVE_*` record current; MODEL_WAVE_STATE.md reconciled with RESULTS.md files per model.
- **S-023** Convergence pre-staging: on the laptop, the gemma4 CUDA session's prefill path read and mapped for span injection (where the 16 soft rows enter), design note appended to VISION_DEV_STATE.md §4 — no code yet; the build slice is S-171.
- **S-024** Part I closing report: one plain-language ledger of every front closed, with heads, counts, and the evidence for each, delivered to Volmarr.

---

# PART II — FINISH THE WAVE (slices 25–64)

*The nine models, the declared matrix, both rounds: baseline → tune → re-test → ship. Continues the coordinator's remaining order.*

## II-A. Architecture repairs the wave already owes

- **S-025** Qwen3 support: loader/execution branch for qwen3 (zen-4b's arch) — config, QK-norm, rope — until zen-4b's baseline stops degenerating. Gate: oracle-parity battery on the fixed prompt set.
- **S-026** Zen-4b full declared matrix on the repaired arch (Q4_K_M, Q6_K, Q5_K_M, Q3_K_M, 2-bit tier, IQ1_S as offered), baseline round.
- **S-027** Mistral3 + YaRN: Ministral-3-3B baseline battery (Q4_K_M + Q6_K first, native [INST] rendering), YaRN rope scaling verified against the oracle at length.
- **S-028** Ministral full declared matrix, baseline round.
- **S-029** IQ1_S verdict: the IQ debug round concludes — root cause found and fixed, or the merge reverted and the defect specified exactly. No silent middle state.
- **S-030** IQ2_M speed: the slow path (~592 s probe) profiled; decode-once/fast-GEMM treatment as kinds 10/11/13 received; re-measured.
- **S-031** IQ integration re-verify: all IQ verdicts re-run on the integrated wave tree (SmolLM2 IQ1_S/IQ2_M first), results written into its RESULTS.md with the caveat language removed or proven.

## II-B. The unstarted four

- **S-032** Oprius-i1 (the size-diversity case): full ladder baseline — Q4_K_M, Q6_K, Q5_K_M, Q3_K_M, Q2_K, IQ2_M, IQ1_S — each with correctness + speed rows.
- **S-033** Oprius-i1 tuning round: per-rung Aesir tuning until each rung runs its best; the size-diversity findings (where small-size paths differ) written as engine knowledge.
- **S-034** Coder-7B downloads completed + verified (VM store), crown Q4_K_M baseline.
- **S-035** Coder-7B full declared matrix baseline (Q6_K, Q8_0, Q5_K_M, Q3_K_M, Q2_K).
- **S-036** Coder-7B crown tuning: Q4_K_M as the primary tuning target per Volmarr's special order — threaded/fast paths, memory discipline inside the VM's reach.
- **S-037** Stheno (VM side): crown Q3_K_M baseline + full ladder baseline (Q4_K_M, Q6_K, Q8_0, Q5_K_M, Q2_K, IQ2_M, IQ3_M as offered).
- **S-038** Stheno crown tuning on the VM: Q3_K_M best-speed work (the kind-11 fast path is the starting point).
- **S-039** Gemma-4 (wave side): the new arch through the generic engine — loader/config/execution gaps closed until the static Q4_K_M runs the battery correctly on CPU. (Its CUDA road is Part IV; its vision road is Part V.)
- **S-040** Gemma-4 full declared matrix baseline (incl. sibling-sourced IQ1_S + IQ2_M per the sibling ruling).
- **S-041** Gemma-4 tuning round per rung.

## II-C. Tuning pass + final sweep + ship

- **S-042** Kind-11 (Q3_K) speed program: profile the fast path's remaining scalar pockets; SIMD/thread treatment; before/after on Stheno crown + Coder-3B Q3_K_M (the degenerate-file control).
- **S-043** `AESIR_PAR_MIN_WORK` sweep: the threading threshold tuned per quant kind from measured crossovers, defaults set from evidence.
- **S-044** Prefill program: batched-prefill coverage extended to every quant kind the wave uses; long-prompt probes per crown.
- **S-045** Memory discipline pass: peak-RSS rows for every crown on the VM; any crown that cannot complete inside the VM's envelope gets its spill/Part-IV road named in its RESULTS.md (never a silent failure).
- **S-046** Final re-test sweep, VM: all 9 models × full matrix, fresh binary, one table — correctness, tok/s, RSS — against the baseline table, deltas printed.
- **S-047** Final re-test sweep, laptop (second site): the same matrix as far as the laptop line has placements (GPU where proven, CPU recorded as CPU), cross-site agreement table.
- **S-048** Divergence court: every cross-engine or cross-site divergence in the sweep gets a written verdict — engine bug (fixed under the never-leave-a-bug rule), file degeneracy (proven on both engines), or distribution near-tie (peaked-probe method) — no unexplained rows.
- **S-049** `docs/MODEL_WAVE_CLOUD_HYPERVISOR_EPYC.md` completed: the campaign's full record in-repo.
- **S-050** Full suites on the wave tree; counted run green (post-Part-I it can execute); battery green.
- **S-051** Wave ship: branch → push → PR → merge → remote verified. Wave state file closed with the final table.
- **S-052** Crown ceremony: the three crowns (Coder-3B Q8_0, Coder-7B Q4_K_M, Stheno Q3_K_M) each get one demonstration run on both sites, outputs filed — the wave's proof pieces.
- **S-053** Wave retrospective: durable lessons extracted into AGENTS.md + the wave docs (the self-improving step of the Forge Protocol).
- **S-054** Spillover queue: every defect discovered during Part II that was fixed in passing is listed with its fix commit; every one deferred is named with its road — an explicit zero-hidden-debt statement.

## II-D. Wave-adjacent completions

- **S-055** Heretic-3.2-1B regression canon: the wave's sanity-stream discipline formalized — the fixed token stream re-verified after every engine change from here on.
- **S-056** Tokenizer parity suite: every wave model's tokenizer checked against its oracle across the battery prompts (the class of bug that bit `encode` in the CI campaign gets a permanent guard).
- **S-057** Chat-format canon: per-model native rendering (gemma4, mistral [INST], qwen, llama) captured as tested fixtures, not per-run improvisation.
- **S-058** Oracle hygiene: llama.cpp oracle pinned, its `-c 2048` envelope rule and OOM behaviour documented in the wave tools directory.
- **S-059** Store integrity: full sha256 re-verification of the VM wave store against HF pins; a manifest file committed to the wave docs.
- **S-060** Download ledger: every wave file's source repo, pin, size, and verification date in one table (the seed of Part III's acquisition ledger).
- **S-061** Second-site store parity check: laptop store (60 files) vs VM store — the symmetric difference listed and explained.
- **S-062** Battery prompts v2: the Aurelia t1–t4 set extended with a code probe (for the Coders), a long-context probe, and a counting probe — versioned, so old and new results stay comparable.
- **S-063** Results schema: every RESULTS.md normalized to one table shape (model, quant, site, placement, correct, tok/s, memory, temp, notes) — machine-joinable for Part III's much larger matrix.
- **S-064** Part II closing report to Volmarr, plain language first: nine models, every rung, both sites, what got faster and by how much.

---

# PART III — EVERY SIZE TYPE (slices 65–140)

*Volmarr's expansion: "downloading and developing all other size types of the models too in this same vein." Two axes of "size": (A) every quant rung published for the nine wave models — the complete ladders, from every sibling repo that carries them; (B) the parameter-size siblings of the same families — the same models at their other sizes. Same vein throughout: acquire with pins, verify by hash, baseline, develop support, tune, re-test, record per site.*

## III-0. The quant taxonomy — what "every rung" means

The full GGUF size-type taxonomy Aesir must eventually speak, in the order this part develops them:

- **Precision tier**: F16, BF16, Q8_0.
- **K-quant ladder**: Q6_K, Q5_K_M, Q5_K_S, Q4_K_M, Q4_K_S, Q3_K_L, Q3_K_M, Q3_K_S, Q2_K, Q2_K_S.
- **Legacy quants**: Q4_0, Q4_1, Q5_0, Q5_1 (older repos still ship them; Aesir reads what the world publishes).
- **IQ (imatrix) ladder**: IQ4_XS, IQ4_NL, IQ4_M, IQ3_M, IQ3_S, IQ3_XXS, IQ2_M, IQ2_S, IQ2_XS, IQ2_XXS, IQ1_M, IQ1_S.
- **Ternary tier**: TQ1_0, TQ2_0 (where a repo offers them).
- **Dynamic (UD) variants**: unsloth-style UD-Q*_K_XL / UD-IQ* mixes where a family's publisher offers them — acquired as their own rungs, never silently substituted for the canonical ones.
- **mmproj companions**: every vision projector file (F16, Q8_0, and any other offered precision) for every vision-capable model in scope — Part V develops them; this part acquires and verifies them.

Per-family availability differs; the rule from the wave holds: **where a named rung does not exist, acquire the nearest honest tier and note the substitution; never invent a file.** Every family's FIRST slice in this part is a live inventory against Hugging Face (API-listed files + LFS pins), because availability claims in this roadmap are plans, not facts, until the inventory slice verifies them.

## III-A. Acquisition & stores (slices 65–78)

- **S-065** Master acquisition ledger created: one row per (family, rung, source repo) with HF path, LFS sha256 pin, byte size, and status fields for both stores. This ledger is the part's single source of truth.
- **S-066** Disk budget verdict: total bytes of the full III-A matrix computed from the ledger; VM free space vs laptop free space stated; the storage plan (what lives where, what streams, what waits) written into the ledger header. If the VM cannot hold its full share, the plan says so and names the remedy for Volmarr's ruling — no silent shortfall.
- **S-067** Download discipline codified: plain resumable curl only (the flagged-script lesson), `-L -C -`, sha256 verified against the pin before a file is marked present; a file that fails its hash is deleted and re-fetched, never nursed.
- **S-068** Gemma-4 E2B full-ladder inventory (static + i1 sibling + any UD publisher): every rung listed with pins.
- **S-069** Zen-4b full-ladder inventory (i1 repo + static sibling if published).
- **S-070** Oprius static + i1 full-ladder inventory (the two repos together are the family's complete ladder by design).
- **S-071** Ministral-3-3B full-ladder inventory (i1 repo + static sibling, incl. all mmproj precisions).
- **S-072** SmolLM2 full-ladder inventory.
- **S-073** Coder-3B full-ladder inventory.
- **S-074** Coder-7B full-ladder inventory.
- **S-075** Stheno full-ladder inventory (bartowski's ladder is the widest of the nine — every IQ and K rung he ships).
- **S-076** Acquisition wave 1 (VM store): all III-A files for the four smallest families (Oprius ×2 repos counted as one family, SmolLM2, Coder-3B, Ministral LM files) downloaded + hash-verified.
- **S-077** Acquisition wave 2 (VM store): Gemma-4, Zen-4b, Coder-7B, Stheno full ladders downloaded + hash-verified.
- **S-078** Acquisition parity (laptop store): the same matrix mirrored to purplelongship (its 60 wave files are the seed); the two stores' manifests diffed to zero unexplained differences.

## III-B. Engine development per rung class (slices 79–96)

*Development follows the wave's proven pattern: decode-once fast GEMM per kind, threading with bit-identical partitions, SIMD fast paths, oracle parity. Each class closes with a correctness gate on a peaked battery + a speed row vs the scalar path.*

- **S-079** Rung-class census: every acquired file's GGUF type inventory mapped against Aesir's current dequant/GEMM coverage — the definitive have/have-not table this section burns down.
- **S-080** Q5_K_S + Q4_K_S fast paths (the S-variants join the M-variants' treatment).
- **S-081** Q3_K_L + Q3_K_S fast paths (the kind-11 family completed: L/M/S one treatment).
- **S-082** Q2_K_S support + fast path.
- **S-083** Legacy quants (Q4_0/Q4_1/Q5_0/Q5_1): loader + dequant + GEMM kinds, oracle-parity gated — Aesir reads the old world too.
- **S-084** IQ4 family (XS/NL/M): dequant + fast path.
- **S-085** IQ3 family (M/S/XXS): dequant + fast path.
- **S-086** IQ2 family completion (S/XS/XXS join M): dequant + fast path; the IQ2_M speed work from S-030 generalizes here.
- **S-087** IQ1_M support (IQ1_S's sibling; the S-029 verdict's lessons applied from the start).
- **S-088** Ternary (TQ1_0/TQ2_0): host decode primitives to production GEMM kinds (the extreme-quantization module's primitives are the seed).
- **S-089** F16/BF16 weight path: direct half-precision GEMM (no dequant detour) for the precision tier, incl. the BF16-at-load conversion the vision line proved, generalized.
- **S-090** Mixed-type files: per-tensor type dispatch audited across every acquired file (real repos mix types per tensor — output tensors at Q8_0 inside Q4 files etc.); any file that loads wrong is a defect, fixed here.
- **S-091** UD-variant handling: dynamic per-layer type mixes load and run correctly; UD rungs enter the matrix as themselves.
- **S-092** Kind-table freeze: the GEMM kind registry for all of the above documented in-repo (kind ↔ type ↔ fast/scalar status) — the map Part IV's CUDA work mirrors.
- **S-093** CPU correctness gate per class: peaked-battery parity vs llama.cpp for at least one real file per rung class per architecture family touched.
- **S-094** CPU speed table per class: scalar vs fast, threaded vs serial, on both sites' CPUs (EPYC + Zen 2) — the Zen-2 column exists because of the crash fix's znver2 acceptance.
- **S-095** Extreme-rung honesty: for the sub-2-bit rungs (IQ1_*, TQ1_0), coherence expectations set from the oracle's own behaviour on the same files — Aesir is graded against the oracle, never against an imagined ideal.
- **S-096** Section gate: the census table from S-079 re-run — every acquired rung class reads SUPPORTED with a fast path, or carries a named, dated reason.

## III-C. Per-family full-ladder campaigns (slices 97–124)

*Each family: baseline every rung → tune → re-test → RESULTS table, on the VM first, laptop second (its placement story is Part IV). The family's crown (where Volmarr named one) gets the deepest tuning; every rung gets correctness + speed rows.*

- **S-097** Oprius (both repos, the complete ladder as one campaign): every rung baselined.
- **S-098** Oprius tuning + re-test; the size-diversity monograph updated with the full ladder's findings.
- **S-099** SmolLM2 full ladder beyond the wave matrix (every remaining rung) baselined.
- **S-100** SmolLM2 tuning + re-test.
- **S-101** Coder-3B full ladder baselined (crowns and wave rungs excluded — already done; this is the REST of its ladder).
- **S-102** Coder-3B tuning + re-test, crown Q8_0 re-confirmed at the head of its table.
- **S-103** Ministral full ladder baselined (LM rungs; mmproj is Part V).
- **S-104** Ministral tuning + re-test (YaRN length probes on every rung — reasoning models live or die at length).
- **S-105** Zen-4b full ladder baselined on the repaired qwen3 arch.
- **S-106** Zen-4b tuning + re-test.
- **S-107** Gemma-4 E2B full ladder baselined (generic engine; incl. both sibling IQ rungs + any UD rungs).
- **S-108** Gemma-4 tuning + re-test.
- **S-109** Coder-7B full ladder baselined (the heavy campaign: plan run order around the VM's memory envelope; over-envelope rungs get their Part-IV spill road named, not a failure mark).
- **S-110** Coder-7B tuning + re-test; crown Q4_K_M re-confirmed.
- **S-111** Stheno full ladder baselined — the widest ladder of the nine, incl. every IQ rung bartowski ships.
- **S-112** Stheno tuning + re-test; crown Q3_K_M re-confirmed; the Q3_K speed story from the laptop (generic-matvec gap) answered on CPU with the kind-11 program's numbers.
- **S-113** Sub-2-bit special campaign: IQ1_S/IQ1_M/IQ2_XXS/TQ1_0 across all families that offer them — one comparative table (coherence vs oracle, speed, bytes) — the extreme end of the size axis, honestly graded.
- **S-114** Precision-tier campaign: F16/BF16/Q8_0 across families — the quality ceiling rows every quant is implicitly compared against.
- **S-115** The FULL MATRIX table: every (family × rung) with correctness, tok/s, RSS, on the VM — published into the repo docs as the wave's successor document.
- **S-116** Cross-rung guidance: from the full matrix, per family, the rung Volmarr would actually run for (a) the VM, (b) the 6 GB laptop, (c) smallest viable — evidence-based, in the docs, so future choices start from data.
- **S-117** Laptop CPU sweep of the full matrix (second site, CPU placement recorded as CPU): the symmetric table to S-115.
- **S-118** Cross-site agreement court, full-matrix edition (as S-048, at Part III scale).
- **S-119** Part III-A ship: all engine work merged under the standard pattern; stores' manifests committed; the acquisition ledger closed at 100% verified or with named exceptions.
- **S-120** Part III-A closing report to Volmarr.

## III-D. Parameter-size siblings (slices 121–154)

*The same families at their other sizes — "all other size types" on the parameter axis. Each sibling enters at a sane quant subset first (Q4_K_M + Q6_K + its natural crown), proves itself, and only then earns full-ladder treatment by the III-C pattern. Availability is verified by inventory slices before any download byte moves.*

- **S-121** Sibling census: for each wave family, its published parameter siblings enumerated from HF (publisher repos preferred, the wave's own publishers first): expected territories — Gemma-4 E4B (and the wider gemma line), Qwen2.5-Coder 0.5B/1.5B/14B/32B, SmolLM2 135M/360M, Llama-3.2 1B/3B (Stheno's base family), Ministral 8B/14B, Mistral-3 larger siblings, Qwen3 sizes around zen-4b, Oprius's own line if it grows siblings. The census verifies; it does not assume.
- **S-122** Sibling acquisition protocol: crown-subset rule (3 rungs per sibling to start), pins + hashes, both stores, disk-budget re-verdict at the larger sizes (14B/32B files change the storage plan — S-066's header updated, Volmarr informed before the big bytes move).
- **S-123** SmolLM2 135M + 360M: crown-subset baseline + verdict (the tiny end — also the future on-device/NPU scouts).
- **S-124** Llama-3.2 1B + 3B: crown-subset baseline (Stheno's kin; the 3B is also a known CUDA-profile quantity from the repo's earlier evidence).
- **S-125** Qwen2.5-Coder 0.5B + 1.5B: crown-subset baseline.
- **S-126** Qwen2.5-Coder 14B: crown-subset baseline — first over-VRAM model on BOTH sites; its road runs through Part IV's spill, and this slice is gated on it.
- **S-127** Qwen2.5-Coder 32B: crown-subset baseline — the stress case: spill depth, KV pressure, thermal behaviour at length; gated on S-126's lessons.
- **S-128** Gemma-4 E4B: crown-subset baseline (arch shared with E2B; its mmproj pairs into Part V).
- **S-129** Ministral 8B: crown-subset baseline.
- **S-130** Ministral 14B: crown-subset baseline (spill-gated like S-126).
- **S-131** Zen/Qwen3 sibling sizes: crown-subset baselines per the census.
- **S-132** Sibling tuning round: each sibling's crown rung tuned as the wave crowns were.
- **S-133** Sibling full-ladder promotion court: which siblings earned the III-C full-ladder treatment (evidence: correctness + Volmarr's interest + store budget) — decided in the open, in the ledger.
- **S-134** Promoted siblings' full ladders: acquisition + campaigns per the III-C pattern (one slice per promoted sibling, split further if a ladder is bartowski-wide).
- **S-135** The SIZE TABLE: every (family × parameter size × crown) on both sites — the map of what Aesir can hold, from 135M to 32B.
- **S-136** Fit guidance: per device class (8 GB VM, 6 GB GPU laptop, 16 GB Pi), the largest size per family that runs WELL (not merely loads) — measured, thermal-aware.
- **S-137** Part III-D ship + closing report.

## III-E. Standing acquisition watch (slices 138–140, then continuous)

- **S-138** New-rung watch: a weekly check (manual-only cadence, in-house) of the nine families' repos + siblings for NEW published rungs/sizes; new arrivals enter the ledger as candidates, never auto-downloaded at scale without the disk verdict.
- **S-139** Publisher drift watch: mradermacher/bartowski re-quantizations of the same weights (same model, new file) — hash-pins make drift visible; drifted files are new rungs, not replacements.
- **S-140** Part III doctrine note: the size-type program's standing orders written into the wave docs so any future crew runs it identically.

---

# PART IV — ACCELERATOR COMPLETION (slices 141–170)

*The Accelerator-First Law made whole: every architecture gets a native CUDA profile, every rung class gets device kernels, and spill becomes the general road — not a llama3 special case. Purplelongship is the proving ground; the design is three-tier (NPU→GPU→CPU) from the first slice so phones and tablets inherit it.*

## IV-A. Profiles per architecture

- **S-141** Profile framework audit: the gemma4 + llama3 session patterns distilled into the shared profile contract (admission arithmetic, upload staging, KV plan, sampler parity) that every new profile implements.
- **S-142** Qwen2 CUDA profile (the GPU line's S4, promoted): dense-GQA profile for qwen2; Coder-3B Q8_0 crown + Q4_K_M execute on the 2060; correctness vs the VM's known-good outputs.
- **S-143** Qwen2 spill: Coder-7B crown Q4_K_M runs SPILLED on the 2060 (front layers resident, tail on CPU) — the Accelerator-First proof for the wave's biggest crown. Full law reporting.
- **S-144** Qwen3 CUDA profile (zen-4b's arch): QK-norm device path; baseline on the 2060.
- **S-145** Mistral3 CUDA profile (Ministral): YaRN rope on device; baseline on the 2060.
- **S-146** Llama-family generalization: the llama3 profile formally covers smollm2/oprius/llama-3.2 sizes (same arch, different geometries) with per-geometry admission tests — no per-model forks.
- **S-147** Gemma4 profile completion: with the PTX fix banked (S-014), the profile's quant coverage extends beyond Q4_K_M as kernels allow (see IV-B); E4B admitted by the same profile (pairs with S-128).

## IV-B. Device kernels per rung class

- **S-148** Q3_K specialized block kernel (closes the crown's 4 tok/s generic-matvec gap): Stheno crown decode speed measured before/after; numerics proven vs the generic path's outputs.
- **S-149** Q2_K + Q5_K/Q6_K device coverage audit → kernels where missing (the Turing packed-GEMM family extended rung by rung, mirroring S-092's kind table).
- **S-150** Q8_0 device path (Coder-3B's crown deserves device speed, not just admission).
- **S-151** IQ family on device, stage 1: IQ2_M + IQ1_S device dequant+GEMM (the wave's signature extreme rungs).
- **S-152** IQ family on device, stage 2: IQ3/IQ4 classes per the S-079 census priorities.
- **S-153** Ternary on device (if S-088 landed the host path): TQ rungs execute on the accelerator or carry a dated, evidenced reason.
- **S-154** Kernel parity court: every device kernel vs its CPU path on identical inputs — bit-exact where the math allows, bounded-divergence with the bound stated where it doesn't.

## IV-C. Spill, generalized

- **S-155** Spill framework extraction: Llama3SpillSession's pattern (prefix residency, per-layer CPU tail, boundary vector, KV-with-layer) lifted into the profile contract so qwen2/qwen3/mistral3/gemma4 spill identically.
- **S-156** Spill placement policy v2: whole-layer front residency + embedding/head rules + context auto-shrink as the last lever — one policy, all profiles, recorded per run (extends S-013's instrumentation to every profile).
- **S-157** KV spill: when KV itself pressures VRAM, the oldest KV blocks page to host RAM (the second spill axis) — proven on a long-context Coder-7B run.
- **S-158** Activation-boundary batching: prefill crosses the GPU→CPU boundary in blocks, not per token, where the tail allows — prefill tok/s on spilled runs measured before/after.
- **S-159** Spill correctness canon: for every profile, one over-VRAM case with tokens identical to a known-good full-resident (or full-CPU) run — the S-012 gate, generalized and battery-wired.
- **S-160** The 32B spill proof (pairs with S-127): the deepest spill in the program, run on the laptop with full thermal/utilization recording — the Accelerator-First Law's stress exhibit.

## IV-D. The governor — threading, politeness, thermal as systems

- **S-161** Thread governor: Aesir's CPU side claims all cores by default and YIELDS measurably under external load (the politeness rider as code: load sensing + worker-count backoff), proven by running a spilled model beside a competing workload.
- **S-162** Thermal governor: temperature sensing on both sites (NVML on the laptop; CPU sensors both), throttle curve implemented (reduce batch/workers, then spill deeper, never cook), proven with a sustained worst-case run that plateaus under the danger line.
- **S-163** Governor telemetry: every governed run logs its throttle events; a run that throttled says so in its results row (no silent slowdowns — the thermal cousin of the no-silent-CPU rule).
- **S-164** Three-tier placement design (NPU→GPU→CPU): the placement policy written for tri-device machines (phones/tablets) against the profile contract — design + a simulated-tier test on the laptop (GPU treated as "NPU tier" for policy purposes) so the logic is proven before any tri-device hardware arrives.

## IV-E. Second-site completeness + the parked frontier

- **S-165** Laptop full-matrix GPU sweep: every (family × rung) from Part III attempted on the 2060 with its true placement recorded — resident, spilled (with split), or CPU (with the reason). The Accelerator-First report card for the whole program.
- **S-166** Mimir readiness (no execution without Volmarr's word): the Pi's Aesir build verified current against main; the Hailo finish-line resume packet (slice 4.126 state) re-confirmed readable and complete — preparation only; the line stays parked.
- **S-167** NPU road design: for the day a tri-device target or the Hailo word arrives — the placement + kernel-delegation design against S-164's policy, written, not built.
- **S-168** Part IV ship: all profiles/kernels/spill/governor work merged under the standard pattern; GPU_2060_STATE.md closed with the full report card.
- **S-169** Part IV closing report to Volmarr: what now runs on the card that couldn't, what spills, at what speeds, at what temperatures.
- **S-170** Accelerator doctrine: the profile contract + spill policy + governor rules written as standing Aesir architecture docs in-repo.

---

# PART V — VISION COMPLETION (slices 171–188)

*From proven parts to a model that answers about what it sees — and then every vision pairing the size program brings in.*

- **S-171** CONVERGENCE, build: span injection into the gemma4 CUDA session's prefill (design staged at S-023): the encoder's 16 soft rows enter the session exactly where the marker token sits. Fail-closed semantics identical to the generic path's.
- **S-172** CONVERGENCE, proof: the written driver (`tests/image_chat_mmproj.mojo`) runs end-to-end on purplelongship — bit-exact forward control, red/blue behavioural answers, text-only control unchanged. This slice closes vision's NOT PROVEN.
- **S-173** Vision regression gate: the image-chat proof wired into the battery as a permanent case (a vision change can never silently break it again).
- **S-174** Pixtral encoder forward: the Ministral tower's forward built to the pinned spec (variable native-resolution grids, 2D-RoPE, patch merger, MLP projector), oracle-gated stage by stage as the Gemma tower was.
- **S-175** Ministral end-to-end image chat: injection via its own marker/template semantics (verified from ITS tokenizer metadata, as Gemma's was), behavioural proof on the laptop.
- **S-176** Gemma audio tower assessment: the mmproj's 751 audio tensors get a written verdict — scope in (with its own slice plan) or explicitly out with reasons; no silent third of the file ignored.
- **S-177** mmproj precision matrix: every acquired mmproj precision (F16/Q8_0/others) runs the encoder with oracle deltas per precision — the vision side of the size program.
- **S-178** E4B vision pairing (pairs with S-128): its mmproj through the same gates.
- **S-179** Image-format completeness: BMP/WebP intake assessed against real need (PNG/JPEG landed); formats added only with the pixel-exactness proofs the first two set as the standard. (Deliverable-image rules for Volmarr's own files are separate and unchanged: PNG/JPG.)
- **S-180** Resolution scaling: images larger than the tower's native grid — the tiling/scaling road, proven against oracle behaviour (Gemma's fixed 224 grid vs Pixtral's native-resolution design made this two different problems; both answered in writing).
- **S-181** Vision speed: encoder + injection costs profiled on both sites; the encoder gets the accelerator treatment where the profile allows (CUDA encoder path assessed, built if the win is real).
- **S-182** Vision battery v2: a fixed image set (colour fields, text-bearing image, natural photo) with expected-answer fixtures — behavioural grading that survives model swaps.
- **S-183** Samtal/Second-Life feed-in note: what the proven vision path hands to Volmarr's other hearths (the real-time loop's eyes) — a design note only; building those bridges stays their own commissions.
- **S-184** VISION_DEV_STATE.md closed: the full arc from spec to behavioural proof, with every NOT PROVEN either closed or carried with its road.
- **S-185** Part V ship + closing report.
- **S-186** (Reserve) Vision defect sweep: anything the never-leave-a-bug rule surfaced during Part V, gathered and closed.
- **S-187** (Reserve) Second vision model family from Part III-D's census, if one earned promotion.
- **S-188** (Reserve) Vision + spill combined proof: an over-VRAM vision model answering about an image, spilled — the two hard roads at once.

---

# PART VI — PROOF, BOOKKEEPING & THE STANDING ORDER OF WORK (slices 189–204)

- **S-189** Counted run as master gate: with the crash fixed, `run_all`'s counted results become a required line in every part's ship checklist (the registry grows past 271 as Parts III–V register their cases; every registration follows the vision slice's pattern).
- **S-190** Battery v3: the in-house battery extended with the spill gate (S-012/S-159), the vision gate (S-173), the PTX probe (S-014's), and per-rung-class CPU gates (S-093) — one command, one ledger, the verification of record for the whole program.
- **S-191** Ledger endgame audit: CAPABILITY_LEDGER vs registry vs battery — three-way agreement proven; the step-31 pin discipline holds at every merge (recount, re-account, never assume).
- **S-192** Evidence hygiene: `docs/evidence/**` generation rules re-checked against the exemption's exact scope (the step-33 campaign's lessons made permanent).
- **S-193** Docs consolidation: MODEL_WAVE_* + this roadmap's part-records + GPU/vision state files cross-linked from one in-repo index, so the program reads as one story.
- **S-194** Worktree hygiene: the campaign forest (wave, vision, gpu, llvm, banking, step33 worktrees) reconciled — merged ones retired, live ones listed with owners; the dirty main checkout's state reported to Volmarr untouched, as ever.
- **S-195** Keeper cadence: each part runs under 10-minute keeper timers per the Keeper Law (a tick continues stalled work slice by slice; it never merely reports).
- **S-196** Banking rhythm: every part ships in mergeable chapters (never one giant merge); main is never more than one part-chapter behind the frontier.
- **S-197** Usage stewardship: heavy downloads and full sweeps scheduled against Volmarr's weekly budget reality — the ledger (S-065) carries byte costs, the sweep plan carries run costs, both visible before they are spent.
- **S-198** Quarterly-shape review: at each part boundary, this roadmap is re-read against the realm's true state; slices overtaken by events are marked (with what replaced them), never silently dropped.
- **S-199** The Hailo gate: when Volmarr gives the word, the finish-line resumes at slice 4.126 under its own roadmap (the 200-slice corpus program) — this roadmap yields the forge to it without either program losing state.
- **S-200** Samtal/Rúnmál interface note: Aesir's proven capabilities (per the ledger) summarized for the hearths that will call it — Rúnmál's inference heart among them — as a standing, dated capability statement.
- **S-201** Final census: every slice in this roadmap accounted — done (with evidence), superseded (with the successor named), or open (with its road) — in one closing table.
- **S-202** Final report to Volmarr: the whole program, plain language first — what Aesir now runs, everywhere, at what speeds, and what remains honestly unproven.
- **S-203** Lessons harvest: the program's durable lessons into AGENTS.md and the architecture docs (S-170's companions).
- **S-204** Successor roadmap seed: the next horizon named from S-201's open rows (new families, new hardware, the NPU road) — written as questions for Volmarr, not assumptions.

---

## The order of battle, at a glance

1. **Part I** closes the ground already won (banking, crash, spill proof, PTX, step-33 zero). *Nothing else outranks it — three other parts gate on the crash fix alone.*
2. **Part II** finishes the declared wave and ships it.
3. **Part III** is the size empire: III-A/B/C complete the nine families' ladders; III-D climbs the parameter axis to 32B; III-E keeps watch.
4. **Part IV** makes the accelerator whole — profiles, kernels, generalized spill, the governor — and produces the 2060's full report card.
5. **Part V** gives Aesir proven sight, then every pairing the size program brings.
6. **Part VI** is the spine: proof, bookkeeping, and the standing order that keeps all of it honest.

*Written 2026-10-28 by Yrsa, from the live state files (MODEL_WAVE_STATE.md, VISION_DEV_STATE.md, GPU_2060_STATE.md, the CI ledgers) and remote heads verified at writing. Where this roadmap states a fact, it was verified at writing; where it plans, it says so. Slices gate on evidence, not enthusiasm.*
