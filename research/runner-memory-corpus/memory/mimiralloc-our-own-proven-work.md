# MimirAlloc — Our Own Proven Work

**Dossier OR-6 (Memory), Dossier 1 of 2 — Ollama Research Forge**
**Date: 2026-11-15**
**Status: First-hand record. This is Volmarr's own project — no clean-room restriction applies; everything below is read from our own campaign records on this VM.**

> How to read the numbers: every load-bearing figure is quoted **exactly as the named record states it**, with the record named beside it. First-hand measured numbers outrank any literature summary. Where a record itself labels a figure as contended, indicative-only, or owed, that label is carried with the figure — never stripped off.

---

## 1. What MimirAlloc is

MimirAlloc is Volmarr Wyrd's independently engineered, general-purpose memory allocator, held in the GitHub repository **hrabanazviking/RuneForgeAI-MimirAlloc** under the MIT License.

- **Origin and purpose.** The project charter (slice A-001, `docs/PROJECT_CHARTER.md`, banking copy at `~/workspace/goals/mimiralloc-forge/hidden_files/banking/A-001/docs/PROJECT_CHARTER.md`) states the purpose plainly: an allocator focused first on 64-bit ARM devices, with "correct memory ownership, dependable behaviour under pressure, useful diagnostics, low overhead, responsible behaviour on mobile devices, and competitive performance that is measured rather than asserted." The practical motivation recorded in the charter is Project Aesir and the Mojo toolchain — a suspected tcmalloc-related obstacle when building or running Mojo on an ARM device — with the allocator also standing as a useful standalone open-source allocator in its own right.
- **Honest scope limit, from the charter itself.** "An allocator manages dynamic memory for other software; it is not an inference engine and not a GPU or NPU runtime. It may help with startup, temporary allocations, fragmentation and stability, but it cannot by itself make an unsupported compiler, driver, operating system or model architecture work." That sentence should govern every claim made for MimirAlloc in the Ollama and Aesir work: it is a host-side allocation layer, not an inference accelerator.
- **Method.** Contract-first API/ABI work (the A-008 contract specification, `docs/contracts.md` in banking copies), an evidence-before-claims principle ("a status claim is only as strong as the check behind it"), clean-room provenance with a dated source ledger, and graded status labels (Proposed / Implemented / Host-tested / Device-tested / Integration-proven / Performance-measured / Blocked) that were never allowed to be promoted beyond the evidence held. Both campaigns were run Mythic-Engineering style: waves of nine team slices, banked in roadmap order under a 10-minute keeper, with every banking verified from disk / git objects rather than from worker reports.

### 1.1 Design as built (the shipped core)

The architecture of record for the banked core, as characterised by the Z13 campaign's opening study and confirmed in the Pi campaign's own Phase 11 documents:

- **Language / form:** a C11 allocator library, version **0.1.0** (research release; SemVer 0.1.0, SONAME `libmimiralloc.so.0` — M-007, graded in the M-009 packet §3, SRC-13 MET).
- **Size:** ~3,757 lines in total, with `src/core/mimir_core.c` at 2,983 lines. *(Source: Z13 opening study recorded in `memory/2026-11-12.md` — "C11 allocator library v0.1.0, ~3,757 lines (src/core/mimir_core.c 2,983)". This line-count figure comes from that study record; it was not re-counted from a local source tree in this dossier pass — see §7, Unverified.)*
- **Locking:** **ONE global lock** serialising all operations. *(Sources: the same Z13 study record; and K-002, `docs/PHASE_11_BASELINE_BENCHMARKS.md` §5 — "one global lock serialises all operations", listed there as a design fact from the banked code.)*
- **Size classes:** **20 size classes, 16..1024 B**. *(Sources: Z13 study record; K-002 §1 — "sizes drawn from the banked size-class table, 20 classes 16..1024, G-002/banked core".)*
- **Large path:** **above 1024 B, a mapping per allocation** — each large allocation takes a fresh OS mapping (plus header/bookkeeping), rather than being carved from a reused arena. *(Sources: Z13 study record — "above 1024 B a mapping per allocation"; K-002 §1/§3 — `large_batch` sizes "above the 1024 cutoff; the mapping-per-allocation path for MimirAlloc", and §5 "large allocations map fresh pages per allocation with a header page per mapping".)*
- **Page size is a host property, never hardcoded.** The design record (B-006, `docs/PHASE_3_MINIMAL_ALLOCATOR_DESIGN.md` §3) requires the system page size to be discovered at runtime on every target. The Pi it was built on reported `getconf PAGE_SIZE` = **16384** (16 KiB); the SM-X400 tablet probed in the field notes reported **4096** (4 KiB). Both values are recorded as observed facts for those hosts only. This distinction turned out to matter enormously — see §4.3.
- **Layering (design, B-006 §4):** L1 public boundary → L2 admission + checked arithmetic → L3 small-object fast path (pass-through in the Phase 3 form) → L4 central ownership (sole client of L5) → L5 page/span manager → L6 OS abstraction (the only layer with platform-specific code) → L7 optional observability (compiled out in the Phase 3 form; a sidecar, never in-line).

### 1.2 Public ABI — exactly 4 symbols (founding library)

The public dynamic ABI of the shipped library is **exactly 4 symbols**:

```
mimir_malloc   mimir_free   mimir_calloc   mimir_realloc
```

This was not a one-off claim; it was re-verified by `nm -D --defined-only` at gate after gate, including the final Pi gate:

- M-009 fresh run (Phase 13 exit packet, `~/workspace/goals/mimiralloc-forge/hidden_files/banking/M-009/docs/PHASE_13_EXIT_EVIDENCE.md` §2): "`make lib` exit 0; `nm -D --defined-only` = exactly 4 symbols: mimir_malloc, mimir_free, mimir_calloc, mimir_realloc."
- The same 4-symbol check is recorded in slice after slice (e.g. L-006: "`nm -D` on the built library shows exactly the 4 public symbols", with the public header verified byte-identical to base).

Two honest nuances, both from the records:

1. **The namespaced surface grew in design before it grew in code.** The earliest Phase 3 header (C-001, `include/mimir_alloc.h`) declared only the pair `mimir_malloc` / `mimir_free`; `mimir_calloc` / `mimir_realloc` were B-008 scope at that point. The 4-symbol ABI is the *shipped library's* verified state, not the first header's.
2. **The Z13 line later widened the export count on purpose.** By Z-083 ("Gap closure for real programs", the interposing variant), the Z13 keeper log records: "Exports now exactly 13" (`~/workspace/goals/mimiralloc-z13-forge/hidden_files/keeper-run-log.md`, Z-083 banking entry), with the earlier ABI scripts (z075–z082) failing their count==10 checks on the 13-symbol tree "BY DESIGN (point-in-time records of their own base…) — not a defect". So: **4 symbols is the founding/Pi library's ABI of record; 13 is the Z13 line's later, deliberate export count.** Any future citation must say which tree it means.

---

## 2. The two campaigns — how they differed

Both campaigns are **COMPLETE at 117/117 slices**. They share one repository and one allocator core, but they are separate hardware lines with separate roadmaps, and the second campaign's founding law was that the first campaign's performance verdicts did **not** transfer.

| | Campaign 1 — Pi / ARM | Campaign 2 — Z13 / x86-64 |
|---|---|---|
| Goal record | `~/workspace/goals/mimiralloc-forge/GOAL.md` (goal_b1d74bd20d29) | `~/workspace/goals/mimiralloc-z13-forge/GOAL.md` (goal_1e876573436a) |
| Host | Raspberry Pi **Mimir** (purpleviking1), aarch64 | **purpleraider** — ASUS ROG Flow Z13, Strix Halo (x86-64) |
| Roadmap | Phases 0–13, slices A-001…M-009 (13 waves × 9) | New 117-slice roadmap Z-001…Z-117 (13 waves) |
| Launched | 2026-11-06 (Volmarr's direct order; 9 teams × 6 = 54 sub-agents; base main b0b8374, documentation only at launch) — `memory/2026-11-06.md` launch record | After the Pi campaign; seat `~/mimiralloc-z13-forge` on purpleraider |
| Completed | 2026-11-07 — final head **776ca8c** verified on the Pi; all 13 waves banked (`memory/2026-11-07.md`; keeper log final entries) | 2026-11-13 — remote main **e78d8716** (full: e78d8716c06a5ee97139cebb0069de1f0619ad94), 117/117 verified on origin/main (`memory/2026-11-13.md`) |
| Page size on host | **16 KiB** (16384) | **4 KiB** host (the Z13 line explicitly discharged the "no 4 KiB-page run ever" debt — see below) |
| Banking identity | Yrsa's own GitHub identity (gh-yrsa git-database API) | Yrsa's own GitHub identity **only**, via a dedicated SSH key whose private half never leaves purpleraider (GOAL.md) |
| Governing question | Build it correctly, clean-room, on ARM64 — and find out honestly how fast it is | Make it run **best on this machine** — measurement-first against glibc **on this hardware only**, with honest WIN/TIE/LOSS grading written in as law (GOAL.md) |
| Final gate | **4,590 run / 0 failed** (see §3) | **4,988 passed / 0 failed / 77 skipped** (see §3) |
| Closure character | Phase 13 exit **PARTIAL / NOT MET for any stable claim**; research release 0.1.0 stands as graded | Closure packet `docs/Z13_Z117_CAMPAIGN_CLOSURE.md` in the repo (566 lines / 28,687 B as banked) |

**Why a second campaign at all — the debts the Pi line itself recorded.** The Z13 opening study (`memory/2026-11-12.md`) names them directly: the first campaign's honest losses (its "L-06") "were all measured on a 16 KiB-page Pi — treated by this line as questions, not evidence", and two debts were "this machine's to pay first": **O-01 (no x86-64 run ever)** and **O-06 (no 4 KiB-page run ever)**. The Z13 keeper log records both as formally discharged by Z-001: "O-01 and O-06 formally discharged" (`~/workspace/goals/mimiralloc-z13-forge/hidden_files/keeper_run_log.md`, Z-001 entry). The Pi packet agrees from its side: SRC-10 (x86-64) and SRC-11 (Android) are graded **OWED** in M-009 §3 — "No hosted suite run; publicly listed unmet; no x86-64 stable claim. Phase 3 exit UNMET" and "No physical device run; publicly listed owed; no Android claim. Phase 4 exit UNMET".

In short: **Campaign 1 proved correctness and measured the cost on one unusual host (ARM, 16 KiB pages). Campaign 2 re-asked every performance question on a mainstream host (x86-64, 4 KiB pages, many cores, two CCDs) and spent 117 slices finding out which parts of the design were host artefacts and which were real.**

---

## 3. Final gate numbers — verified, with the record for each

### 3.1 Pi campaign final gate: 4,590 / 0

- **Record:** M-009 Phase 13 Exit Evidence Packet, §2 "Fresh run at 83125d6" (`~/workspace/goals/mimiralloc-forge/hidden_files/banking/M-009/docs/PHASE_13_EXIT_EVIDENCE.md`): "`make clean && make test` exit 0: `CHECKS: 4590 run, 0 failed`." The underlying recorded run is `tests/abi/recorded_run_m009.txt` in the same banking folder.
- **Independent keeper re-verification at the banked head:** the Pi keeper log's final entries record, at banked head **776ca8c**: "make clean && make test 4590/0 PASS, nm -D exactly 4, Samtal 200, free 13G" (`~/workspace/goals/mimiralloc-forge/hidden_files/keeper-run-log.md`, 2026-11-07 16:57 EST entry), and a post-completion tick re-verified "remote main = local main = 776ca8cc4424cb26375145622bf23b9ba48330ac … make test 4590/0, nm -D exactly 4".
- **Known failure kept visible, not hidden:** the same M-009 run records `make test-g008` standalone at "214 checks / 1 failure, exit 2 — the known stale check (INC-H001-01), reproduced, never hidden (SRC-08)". The headline gate is 4590/0; the stale g008 check is a separate standalone target and is carried as PARTIAL (SRC-08), not folded into the headline and not deleted.

### 3.2 Z13 campaign final gate: 4,988 passed / 0 failed / 77 skipped

- **Record (banking entry):** Z13 keeper log, final tick (`~/workspace/goals/mimiralloc-z13-forge/hidden_files/keeper-run-log.md`, "Tick 2026-11-13 13:10 EST — CLOSED"): "BANKED Z-117 by the keeper directly at the seat: fetch-first (remote unchanged 627b1fa), clean cherry-pick -> seat e78d871, stat identical; **seat gate GREEN 4988/0/77 (seat_gate_z117.log)**; explicit-refspec push HEAD:refs/heads/main via Yrsa SSH road, ls-remote verified 627b1fa -> e78d871 == seat HEAD; 117 distinct slice subjects (Z-001..Z-117) counted on origin/main. BANKED: 117 of 117 — ROADMAP COMPLETE, all 13 waves done." The finishing lead's own final gate is recorded in the same entry as "final gate GREEN 4988/0/77 (z117_gate.log)".
- **Record (memory):** `memory/2026-11-13.md` — "MIMIRALLOC Z13 ROADMAP COMPLETE (2026-11-13): all 117 slices Z-001…Z-117 banked and verified on origin/main of RuneForgeAI-MimirAlloc (remote e78d8716); final seat gate GREEN 4,988 passed / 0 failed / 77 skipped; closure packet at docs/Z13_Z117_CAMPAIGN_CLOSURE.md in the repo".
- **What the 77 skips are:** the Z-001 gate entry in `~/workspace/goals/mimiralloc-z13-forge/hidden_files/keeper_run_log.md` breaks the standing gate down as "make test 8/8 targets, **4988 checks / 0 failed**, EXIT:0, **77 by-design skips (70 test_c007 + 7 test_c008)**". The 4988/0/77 figure is the campaign's standing full-suite gate, re-run green at slice after slice (the keeper logs cite "gate GREEN 4988/0/77" throughout, e.g. seat_gate_z064/z065/z066, z093, z115 logs) — it is a stable suite size, not a number that grew slice by slice.
- **Current-state cross-check (2026-11-15):** `~/workspace/CURRENT_STATE.md` (re-verified 2026-11-15 01:03 EST) carries both lines as ROADMAP COMPLETE with remote main = e78d871 = 117 of 117 for the Z13 seat and for the Pi's remote view (Pi local HEAD 776ca8c unchanged; "remote governs").

### 3.3 Pi closure grading (so "complete" is never misread as "stable")

M-009 §3 grades the 20 stable-release criteria (SRC-01..SRC-20) as: **MET 11 / PARTIAL 6 / OWED 3 / UNMET 0 of 20**, with the headline verdict (§1): "Phase 13 exit: **NOT MET as a stable-release exit; PARTIAL overall**… What stands is a **research release 0.1.0**… an experimental allocator, verified on one target only, losing to glibc on all measured workloads, with every limitation public. **No default global interposition is claimed**". Fourteen carried-owed entries remain on the public register (M-009 §6), including the x86-64 hosted run, the physical Android run, and the Phase 12 Qwen3 comparison run (model absent on the Pi + no aarch64 Aesir engine — SRC-12 OWED).

---

## 4. What it proved

### 4.1 Correctness — proven, on both lines

- Pi line: full suite **4590/0** at the final head; fuzzing corpus runs with 0 violations (M-009 fresh re-run PASS; M-004 recorded run 168,384 checks / 0 failed); long soak **MET** (M-005: "10 cycles, 159,476 ops, RSS flat 1392 kB, dlopen 6/6, Samtal 200 throughout" — M-009 §3, SRC-07).
- Z13 line: full suite **4988/0/77** held green across the whole 117-slice campaign, including under deliberate fault-injection / RED-path work (e.g. Z-008: "run_gate.sh GREEN 4988/0/77 on unmodified tree; RED path proven").
- Both lines kept the host's other tenant alive throughout: Samtal HTTP 200 before and after runs is recorded as a standing check, not an afterthought. Correctness was never bought by starving or disturbing the machine.

### 4.2 Where it honestly LOST — the Pi verdict (the headline result)

Phase 11 (Performance research) is the Pi campaign's centre of gravity, and its verdict is unambiguous. K-009's exit packet states it in one paragraph: Phase 11 "produced a slower-but-measured allocator" that lost to glibc across the board (K-002 baseline: "median factors about 5x to about 65x"), "and **no slice in this wave found a workload where it wins**." Phase 11 exit: **PARTIAL — 6 MET / 2 PARTIAL** (K-009 §2 grading header; the packet's own tally line).

**The baseline itself — K-002** (`docs/PHASE_11_BASELINE_BENCHMARKS.md`; one source compiled twice, byte-identical workload code, only the allocator function pointers differing; 7 separate processes per leg, alternating legs; medians reported; per-workload checksums identical across legs in all 56 raw lines; reproduction run agreeing within 9%):

| Workload | Verdict (K-002 §3, ranked worst first) |
|---|---|
| `mixed_lifecycle` | **65.2x slower** — the realistic shape (many live blocks, partial frees, refills) is where the gap is largest |
| `small_churn` | **18.2x slower** — glibc per-thread cache ≈ 21 ns/op vs banked small path ≈ 384 ns/op (§3 figures as stated) |
| `mixed_batch` | **14.8x slower** — same story at batch scale across all 20 classes |
| `large_batch` | **5.4x slower** — the narrowest gap; both sides pay real kernel mapping costs, MimirAlloc still loses (fresh mapping + header page + bookkeeping vs glibc arena reuse) |

K-002 §4, in full: "**Nowhere in this suite.** No workload, repetition, or size band measured here has MimirAlloc ahead of glibc. The closest approach is `large_batch` (5.4x)."

**Causes, as K-002 §5 labels them** — design facts from the banked code: one global lock serialises all operations; large allocations map fresh pages per allocation with a header page per mapping; the core performs validation and statistics bookkeeping on the allocation path. One material caveat is recorded as INC-K002-02 and must travel with any citation of the early baseline: the banked production build at K-002 time carried **no optimisation level (`-O0`)** against an optimised glibc. Later Phase 11 slices (K-004 onward) measured the shipped **`-O2`** flavour — and still lost (see K-008 below) — so the loss is not an artefact of `-O0` alone, but the exact K-002 factors are `-O0`-build factors.

**Tail latency — K-008** (`docs/PHASE_11_TAIL_RSS_ENERGY_K008.md`; `-O2` shipped flavour; per-op timing, p50/p95/p99, median of 5 fresh-process repetitions; timer floor ≈37 ns, with glibc's small-op p50s sitting *at* the floor and therefore read as "≤ floor"):

- Interleaved small (the common case): MimirAlloc **p99 93 ns vs glibc 56 ns** for both alloc and free (~1.7x) — "a consistent, modest tail cost — not a blowout."
- Burst free is the worst small-size tail: MimirAlloc burst512 free **p99 1167 ns vs glibc 56 ns** (~21x at p99), while burst *alloc* p99 ties glibc at 93 ns. The cost sits in **free**, not alloc — freeing a burst walks the span-release path (pages/spans released on free are re-faulted and re-processed per burst cycle).
  - *Citation note:* the "1,167 ns vs 56 ns" figure sometimes quoted as "the small path" is precisely this **burst512 free p99** pair from K-008's table. The interleaved-small p99 pair is 93 vs 56 ns. Quote each with its pattern name.
- Large path: MimirAlloc large_inter **p99 3852 ns (alloc) / 3686 ns (free) vs glibc 75 ns / 56 ns** (~51x / ~66x at p99) — "the single largest latency gap measured in Phase 11 so far. Every large alloc/free pays microseconds of mapping-path work where glibc pays nanoseconds."

**What Phase 11 tried and what happened (all Pi, all recorded):** batching lost everywhere (K-007; its batching proposal P-1 was recorded, NOT implemented — carried owed in M-009 §6); the locality/metadata-placement work ended with no change worth making (K-005); one real speed improvement did ship inside the wave (per the Phase 11 verdict briefing, 2026-11-07). None of it closed the gap. The forge's own summary briefing ("Phase 11 Performance Verdict", 2026-11-07) puts it the way the campaign insisted it be put: "Measured on the Pi, it loses to glibc on every workload Phase 11 tried, even though it stayed completely correct… The full suite still passed 4,590 checks with no failures, so this is a speed result, not a correctness failure."

**Footprint — the one Pi bright spot, stated precisely (K-008 §3):** after free, MimirAlloc returns to within **128 KiB** of baseline on the small-hold leg (20,000×64 B), where glibc retains the full **1232 KiB** in its arena; on the large-hold leg MimirAlloc retained **0** (glibc's retained figure is negative in the record, −1424 KiB, i.e. below its own pre-hold baseline reading). K-008 itself adds the honest qualifier: retained arena memory "is not a defect per se — it is reuse-ready memory — but it is footprint a caller still pays." So the Pi allocator's genuine, measured virtue is **returning memory**, not speed.

**LLM-shaped behaviour — L-006 (Phase 12):** an explicit-adoption harness (the harness itself calls `mimir_*`; explicitly *not* an Aesir inference run) profiled load / prefill / decode / teardown against a real GGUF file (TinyLlama-1.1B Q4_0, 637,699,456 bytes, sha256 recorded in the slice doc; the Phase 12 reference model Qwen3-1.7B Q4_K_M was **not on the Pi** — INC-L003-04 — so that comparison stayed OWED). The campaign briefing records the result: a full prefill/decode/teardown cycle "came back exactly to baseline, with no allocation left behind". The harness's KV convention (stated in L-006 as a harness convention, not an Aesir fact): KV bytes per token = layers × KV heads × head dim × 2 (K and V) × 4 (f32) = **45,056 B/token** for that model's parsed dimensions. The transferable point is the *shape*: long-lived KV growth + per-step transient churn + a teardown that provably returns everything.

### 4.3 The Z13 re-measurement — same allocator, different host, different answers in places

The Z13 line re-ran the K-002 baseline on its own hardware first (Z-003, recorded run `tests/perf/recorded_run_z13_k002.txt`; keeper log, `keeper_run_log.md`): "bench 56/56, checksums identical per workload; **LOSS all 4: 10.4x / 40.2x / 2.4x / 67.2x**; Tensile contention ~5.3–6.1 load recorded in the file." *(The four factors are quoted here in the order the keeper log lists them; this dossier did not re-open the recorded run file on purpleraider to map each factor to its workload name — see §7.)* The keeper's ruling on Z-003 is itself a lesson: "LOSS stands (first on-machine table on THIS hardware line; roadmap Law 1 makes Pi verdicts inadmissible…)".

Across the 117 Z13 slices, the honest pattern that emerges from the keeper log is **not** "still loses everywhere" and **not** "now it wins" — it is workload- and mechanism-specific:

**Still lost (Z13, recorded):**
- Core churn/lifecycle shapes stayed lost, sometimes worse: Z-054's fresh quiet-window run of record — "small_churn LOSS 8.59x, mixed_batch LOSS 7.38x, **mixed_lifecycle STILL LOST 71.9x** (KL-D)"; Z-038 arena ladder — "LOSS vs glibc every rung both legs"; Z-046 threshold study — "LOSS vs glibc at the fixed 1024 B cutoff (315-486x in the 128 KiB-16 MiB decades)"; Z-007 energy — "energy LOSS all 4, proven 4.42x on large_batch" (with a contended window recorded and quiet re-runs owed for two workloads); Z-005 — "instructions/op 3.6x-46x vs glibc"; Z-115 (Aesir KV-cache-shaped) — "**LOSS all three KV shapes vs both glibc columns; no adoption**".
- The 1024 B cutoff was re-examined and **left unchanged, justified** (Z-054: "cutoff of record 1024 B UNCHANGED justified") — a negative result the campaign chose to keep rather than tune away.

**Tied (Z13, recorded):**
- Z-051: "fully-touched huge allocs **TIE at all six sizes 256 MiB..8 GiB**; untouched LOSS 1.10-1.22x" — plus a real posture difference recorded: "calloc(256 MiB) NOT lazy in this core (46.7 ms eager memset, bytes proven zero)".
- Z-046: "TIE at dense-touch 32 MiB (1.01x)".
- Z-052 (mremap): "ladder before LOSS 3.77x -> after 0.266x WIN vs before, **1.004x TIE vs glibc**" — i.e. the fix brought MimirAlloc to parity with glibc on that path, no more claimed.
- Z-006: "PEAK Pss TIE/LOSS split".

**Won (Z13, recorded — each with its scope attached):**
- **Retention / footprint:** Z-006 — "retention **WIN 3 of 4**"; Z-057 soak — "resident-shape WIN"; Z-061 — "resident shape WIN holds (1.948 vs 2.637)", drift TIE (+1.5% flat). This is the Z13 echo of the Pi K-008 footprint result: the allocator's defensible advantage is giving memory back and holding a smaller resident shape over long runs.
- **Large-batch cycling traffic:** Z-054 — "**large_batch WIN** (KL-C discharged for cycling traffic…; mimir 63.48 vs Z-009 3064.69 ns/op)", with the glibc leg flagged DRIFT-REJECT (bimodal in both runs) and the grade therefore taken "on two-sided bounds + Z-048 drift-clean A/B". Z-113 later records the large_batch WIN *widening* under a proven GPU co-tenant (gpu_busy 94-98%). Note the contrast with Pi K-002, where large_batch was the *narrowest loss* (5.4x): same workload family, opposite verdict, different host and a further-developed core. Neither verdict cancels the other; each belongs to its machine.
- **Huge-page / fault behaviour:** Z-049 — "2 MiB ADOPT (bimodal on PMD alignment), **20 MiB ADOPT (WIN)**, 200 MiB ADOPT on fault (bandwidth TIE)"; Z-013 — "THP WIN 2/20 MiB" (200 MiB bandwidth unstable, deferred at the time to Z-014).
- **Power-proportional tuning:** Z-114 — "PPW tuned70 **WIN all four workloads (1.72-2.26x)**, envelope held, throughput -25..-27% filed" — a performance-per-watt win bought with an explicitly filed throughput cost. Quote both halves or neither.
- **Host facts measured for later work (not allocator wins, but banked knowledge):** Z-011 — single-CCD plateau 61.8 GB/s at 4 threads, 1 core 38.2 GB/s, peak 112.76 GB/s, saturation at 16 threads (quiet window); Z-012 — cross-CCD latency 103 ns vs intra-CCD ~32 ns (3.2x), SMT sibling +18%, leading to an ARENA_PER_CCD=YES decision filed for Z-037. These are the kind of numbers the roofline dossier (Dossier 2) says must be measured, not assumed.

**No-adoption honesty as a pattern:** Z-095 ("NO ADOPTION (honest negative): v1 won the traces but regressed the oracle small_churn +6.13% over the pre-registered 2% bar; v2/v3 regressed broadly; all regressions recorded in full"), Z-059 (best-fit policy: current policy ≡ first-fit TIE on every metric, best-fit LOSS — NO ADOPTION), Z-112's pool replacement (NO-ADOPTION: miss WIN −76.9..−84.3% but hit witness 488-1386x regression; follow-on named). Pre-registered bars, regressions printed in full, and "no adoption" as a normal outcome — that discipline is as much a result of these campaigns as any number.

### 4.4 What it did *not* prove (carried owed, verbatim in spirit)

- No stable/production release: Pi Phase 13 exit PARTIAL / NOT MET for a stable claim; research release 0.1.0 only.
- No Android proof: physical-device run OWED on the Pi line (SRC-11); Phase 4 exit UNMET.
- No Aesir comparison run: Qwen3 model absent on the Pi + no aarch64 Aesir engine at the time (SRC-12 OWED; Phase 12 NOT MET in the register). The Z13 line's KV-shaped probes (Z-115) are harness shapes, not an Aesir integration proof — and they LOST.
- No default global interposition claim, ever: opt-in only (SRC-18 MET precisely because no artifact enables it by default).
- A known, public defect bars any production claim by itself: INC-M002-01/02 — a lock/unlock failure is never reported and the observable return is silently ambiguous (the safety leg holds — no sync failure returns overlapping memory — but the reporting leg is a GAP, carried unresolved in M-009 §5).

---

## 5. Lessons that transfer

### 5.1 To the Ollama build

1. **Do not expect a custom host allocator to speed up Ollama's decode.** MimirAlloc — correct, fuzzed, soaked — lost to glibc on every general workload on the Pi and on most core shapes on the Z13, including all three KV-cache-shaped probes (Z-115). Ollama/llama.cpp decode is bounded by memory bandwidth (see Dossier 2), not by host `malloc` speed. If an allocator change is proposed for the Ollama build, the burden of proof is a K-002-style A/B on the target machine (identical workload code, alternating legs, medians, checksums equal) — not a microbenchmark of the allocator alone.
2. **Where an allocator *can* plausibly help Ollama is footprint and longevity, not tok/s.** The one repeatable MimirAlloc advantage on both hosts is retention/resident shape: returning freed memory (Pi K-008: back to within 128 KiB of baseline where glibc retained 1232 KiB) and holding a smaller resident shape across soaks (Z-057/Z-061). On a 6 GB GPU machine where the host side also juggles model files, KV spill and page cache, a long-running server that provably returns to baseline at teardown (L-006 shape) is worth more than a faster churn path. Measure RSS/PSS retained-after-free, not just throughput.
3. **Page size and mapping policy are first-order on small machines.** The mapping-per-allocation large path is exactly what made large ops cost microseconds vs glibc's nanoseconds (K-008 F-3). Any Ollama-side buffer strategy that allocates large blocks per token/step inherits that cost shape unless it reuses arenas/pools. Prefer pre-allocated, reused workspaces for per-step scratch — the L-006 harness's separation of long-lived KV slices from per-step transient churn is the right template.
4. **Carry the measurement protocol with the code.** Z13's Z-004 protocol gate (identical-legs demo worst 0.85% vs a 5% bound; drift 2.28% vs an 8% bound; attempts 1–8 voided by the drift rule *and kept as evidence*) is directly reusable for Ollama benchmarking on shared, noisy machines: void drifted runs openly, keep them, and never grade on a single window.

### 5.2 To Aesir

1. **Aesir's allocator questions are KV-shaped, and KV-shaped probes lost.** Z-115 tested three KV shapes against two glibc columns and lost all three, with the earlier blockers (B-087-1/2/3) still standing and the Aesir tree untouched. Aesir should therefore treat its KV cache as a **purpose-built arena problem** (pre-sized, append-mostly, freed wholesale at teardown — the L-006 lifecycle), not as a general-allocator problem. A general allocator, ours included, is the wrong tool for that shape as currently designed.
2. **The Phase 12 separation taxonomy is the durable asset.** L-002/L-004/L-006's discipline — weights (W) vs explicit-adoption allocations (C1) vs the engine's own implicit heap (C2) vs graphs/runtime (G) vs residual (R), reconciled at quiescent snapshots from `/proc/self/smaps` + allocator counters kept strictly separate — is how Aesir memory claims should be evidenced. It prevented the classic error of crediting (or blaming) the allocator for bytes it never touched.
3. **Host facts before engine claims.** The Z13 line banked the numbers Aesir's AMD work needs anyway: per-CCD L3 32 MiB, cross-CCD 103 ns vs intra ~32 ns, single-CCD bandwidth plateau 61.8 GB/s at 4 threads, peak 112.76 GB/s (Z-011/Z-012). Aesir's allocator/arena placement on Strix Halo should be per-CCD aware because the measurement says the machine is, not because it sounds right.
4. **The honest-loss culture is the integration contract.** Aesir slices that touch allocation should adopt the MimirAlloc grading law wholesale: WIN/TIE/LOSS per workload, pre-registered adoption bars (Z-095's 2% bar), regressions printed in full, NO-ADOPTION as a respectable verdict. The Qwen3 comparison that stayed OWED on the Pi (SRC-12) should be run — when an aarch64/AMD Aesir engine and the model are both present — rather than quietly forgotten.

### 5.3 To future allocator work

1. **One global lock is a correctness choice with a measured price.** It bought auditability across Phases 3–10 and cost the small path dearly (≈384 ns/op vs glibc ≈21 ns/op at K-002 time; burst-free p99 1167 ns). Any successor design must either shard (per-thread caches, per-CCD arenas — the Z13 ARENA_PER_CCD direction) or state plainly that it is optimising for correctness/footprint, not speed.
2. **Free is where the tail lives.** K-008's sharpest finding is asymmetric: burst *alloc* tied glibc at p99 while burst *free* was ~21x worse, because free walks the span-release path. Future work should budget its optimisation effort on the release/re-fault cycle first, and should measure alloc and free as separate distributions, always.
3. **The large-path needs arena reuse or huge-page awareness, not fresh mappings.** Mapping-per-allocation above 1024 B was the single largest latency gap on the Pi; on the Z13, the wins that did appear in large territory came from THP adoption (Z-049) and cycling-traffic behaviour (Z-054), not from mapping faster. The 1024 B cutoff itself survived re-examination (Z-054) — tune the *policy above the cutoff*, not the cutoff.
4. **Page size is not a constant of nature.** The same design measured on 16 KiB pages (Pi) and 4 KiB pages (Z13) produced different verdicts on the same workload family (large_batch: narrowest loss → WIN for cycling traffic). Runtime discovery (B-006 law) plus per-page-size measurement is mandatory; a benchmark on one page size is evidence about that page size.
5. **Optimisation level is part of the claim.** K-002's `-O0` caveat (INC-K002-02) shadowed the early baseline until `-O2` measurements (K-004/K-008) confirmed the loss independently. State the build flavour in the same sentence as any factor, forever.
6. **Pre-register the bar, then honour it.** Z-095 is the model: a variant that *won its traces* was still rejected because it regressed the oracle workload past a bar fixed before the run. Without that discipline, allocator work degenerates into cherry-picked wins — the exact failure these two campaigns were built to avoid.
7. **Keep the owed list public and priced.** Fourteen carried-owed entries (Pi) and the Z13 closure's carried-open ledger are not embarrassments; they are the reason the proven parts can be trusted. Future allocator work inherits them as its opening queue — starting with the silent lock-failure reporting GAP (INC-M002-01/02), which bars production claims until fixed.

---

## 6. Source index (records actually read for this dossier)

**On this VM:**
- `~/workspace/goals/mimiralloc-forge/GOAL.md`; `~/workspace/goals/mimiralloc-z13-forge/GOAL.md`
- `~/workspace/goals/mimiralloc-forge/hidden_files/banking/A-001/docs/PROJECT_CHARTER.md` (charter, owner, licence, scope limits)
- `~/workspace/goals/mimiralloc-forge/hidden_files/banking/B-006/docs/PHASE_3_MINIMAL_ALLOCATOR_DESIGN.md` (layering, runtime page-size law, 16 KiB Pi / 4 KiB tablet observations)
- `~/workspace/goals/mimiralloc-forge/hidden_files/banking/C-001/include/mimir_alloc.h` (earliest header: pair only, U-03 caveat)
- `~/workspace/goals/mimiralloc-forge/hidden_files/banking/K-002/docs/PHASE_11_BASELINE_BENCHMARKS.md` (baseline factors, method, §4 "Nowhere", §5 causes, INC-K002-02 `-O0` caveat)
- `~/workspace/goals/mimiralloc-forge/hidden_files/banking/K-008/docs/PHASE_11_TAIL_RSS_ENERGY_K008.md` (per-op latency table, footprint table)
- `~/workspace/goals/mimiralloc-forge/hidden_files/banking/K-009/docs/PHASE_11_EXIT_EVIDENCE.md` (Phase 11 exit: PARTIAL, no winning workload)
- `~/workspace/goals/mimiralloc-forge/hidden_files/banking/L-006/docs/PHASE_12_PREFILL_DECODE_TEARDOWN_PROFILE.md` (harness method, KV 45,056 B/token convention, model hash)
- `~/workspace/goals/mimiralloc-forge/hidden_files/banking/M-009/docs/PHASE_13_EXIT_EVIDENCE.md` (final Pi gate 4590/0, nm exactly 4, SRC tally 11/6/3, 14 carried-owed)
- `~/workspace/goals/mimiralloc-forge/hidden_files/keeper-run-log.md` (Pi banking/verification entries at 776ca8c)
- `~/workspace/goals/mimiralloc-z13-forge/hidden_files/keeper_run_log.md` (Z-001 gate breakdown 4988/0 + 77 skips split 70+7; Z-003 LOSS factors)
- `~/workspace/goals/mimiralloc-z13-forge/hidden_files/keeper-run-log.md` (Z-006…Z-115 verdict entries; Z-083 exports exactly 13; Z-117 banking at e78d871, seat gate 4988/0/77)
- `~/workspace/CURRENT_STATE.md` (2026-11-15 01:03 EST re-verification: both lines 117/117, remote e78d871)
- Briefing: `~/workspace/goals/mimiralloc-forge/briefs/Phase 11 Performance Verdict (2026-11-07 19.48.50).html` (plain-language Phase 11 summary)

**Memory records:**
- `memory/2026-11-06.md` (campaign launch), `memory/2026-11-07.md` (Pi completion at 776ca8c), `memory/2026-11-12.md` (Z13 opening study: v0.1.0, ~3,757 lines, core 2,983, 4 symbols, one global lock, 20 classes 16..1024 B, mapping-per-allocation above 1024 B; L-06 loss summary), `memory/2026-11-13.md` (Z13 completion: 117/117 at e78d8716, final gate 4,988/0/77, closure packet path)

**In the repo (not re-opened from this VM in this pass — cited via the records above):** RuneForgeAI-MimirAlloc, `docs/Z13_Z117_CAMPAIGN_CLOSURE.md` (Z13 closure packet, 566 lines / 28,687 B as banked per the keeper log).

---

## 7. What could not be verified in this pass

- **Line counts (~3,757 total / 2,983 core)** rest on the Z13 opening study as recorded in `memory/2026-11-12.md`. No local source tree was present under the two goal folders' `files/` directories on this VM (both are empty) to re-count from. The figure is quoted as the study recorded it.
- **Z-003's four LOSS factors (10.4x / 40.2x / 2.4x / 67.2x)** are quoted in the keeper log's order. The underlying recorded run (`tests/perf/recorded_run_z13_k002.txt`) lives on purpleraider / in the repo and was not re-opened here (this dossier's orders: no other machine), so the factor-to-workload mapping is not asserted.
- **The Z13 closure packet's full text** (`docs/Z13_Z117_CAMPAIGN_CLOSURE.md`) was not read directly; its existence, size, banking commit (e78d871) and gate are verified from the keeper log + memory + CURRENT_STATE board, and its carried-open items are known from the keeper's Z-117 muster/closure entries. A follow-up pass with repo access should read it in full before quoting any Z13 campaign-level tally beyond the slice verdicts cited here.
- **Z13 slice verdicts** are cited from the keeper logs' verified-from-disk summaries (the keeper's own rule was verification against `git show --stat` and gate logs on purpleraider before banking). The underlying per-slice recorded runs were not individually re-read in this pass.

*End of Dossier 1 — 2026-11-15.*
