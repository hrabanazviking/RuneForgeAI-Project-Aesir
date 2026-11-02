# J-093 — Memory Ceiling

**Slice:** J-093 (Part VI — Long Context and the 8-Bit KV, J-087–J-098), Project Aesir Janas clean-room road.
**Roadmap text:** "Memory ceiling. Peak memory across the ladder with 8-bit KV + expert cache active together; the 2.6→4.9 GiB shape of Janas's growth tested against Aesir's own."
**Executed:** 2026-11-01 ~13:59–14:21 EST, in fresh worktree `~/workspace/aesir-janas-j093` on branch `yrsa/janas-j093`, from the verified tip of `yrsa/janas-j092` (`4bb58a0d60c320077888b2667ef811ea07b44e11`, local == ls-remote at slice start). Origin/main untouched at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`. The J-092 worktree and the canonical checkout were not worked in. Design + pre-registered definitions, forms and rules committed FIRST @ `fa99680a` (module + tests + harness), before any build or run of this slice.
**Machine state (VM, stated for every number below):** KVM, 4 vCPU, kernel 7.0.0-39-generic. MemAvailable ~0.39–1.16 GB across the slice (1,182,624 kB at the first check) — **far below the 5,500 MB inference gate at every moment**, so no model inference ran anywhere; lightest compiles only, one at a time. Load average up to ~15.2 (other campaigns); **no wall and no live peak is filed anywhere in this slice**, so contention touches no number. purplelongship was **not used at all** — unreachable (last_seen 2026-11-01T02:07:13Z) and owned by the 204 road when it returns. /tmp healthy.
**Clean-room record:** no Janas material was consulted in this slice and no Janas source code was opened, in this slice or any other. Janas's published long-context growth (2.6→4.9 GiB) is its growth on its machine, cited from its public documentation as recorded in the roadmap: it names the **shape** this slice tests (§6), and none of its figures are quoted here as Aesir's.

---

## 1. The question — and the honest shape, stated up front

**Question.** What is Aesir's peak memory at each ladder rung when the memory consumers are active **together** — model weights/resident set, KV at each precision, activations, sampling, **and** an expert cache sized by the tree's own rules — and does the growth shape of that peak match Janas's published 2.6→4.9 GiB shape?

**The tension, resolved from the tree (inspect-proven, §3).** The ladder's witness is **dense**: Qwen2.5-Coder-7B has no routed experts, so no expert cache ever runs inside its session. The expert cache is MoE machinery whose witness is OLMoE (Part II). And no session in the tree runs both at once: the dense CUDA session admits `DenseGQAProfile` only, the MoE session admits arch `olmoe` only, and no host surface constructs the pair in one process. There is therefore **no single-session combined number to file**, and this slice does not invent one. It files the ceiling in the two honest forms the tree's arithmetic supports, each labelled for exactly what it is:

- **Form A — the dense ladder's own peak** (§5.1): per rung, per precision, per line — weights + KV at the session context + activation + sampling, defined through J-091's admission arithmetic, carrying J-091's verdicts unchanged.
- **Form B — the combined-process ceiling** (§5.3): a host process holding the dense KV-bearing session **and** an OLMoE session's expert cache, budgeted by **J-026's shared-pool rule** (one sizing over summed reserves) on a stated machine. Form B is a host-memory account; the dense tenant's GPU device bytes are Form A's GPU column and are never added into Form B (that would charge the same weights in two memories).

**The findings, in one paragraph.** Form A's peak grows from 4,751,005,312 B at the 1k rung to 6,574,888,576 B at the 32k rung on the GPU line at f16 (CPU line exactly 905,728 B lower at every cell), and from 4,719,007,360 to 5,661,169,280 B at int8 (counterfactual — int8 is INTEGRATION_BLOCKED on both lines, J-091). Form B's combined peak grows from 9,045,716,096 to 10,869,599,360 B at f16 on the stated machine, while its **accounted ceiling stays constant** at 13,743,895,348 B — the pool shrinks by exactly the KV growth, which is what a shared budget is for. **The shape verdict (§6): Aesir's growth is FLATTER than Janas's published shape on every form, line and precision** — ratios 1.384× / 1.384× (Form A f16, GPU/CPU), 1.200× / 1.200× (Form A int8), 1.202× / 1.105× (Form B f16/int8) against Janas's 1.885× — because in Aesir's account the growing term (KV) is a minority of the peak at every rung (1.39% at the base, 28.69% at the top, f16 GPU): the fully-resident 4.68 GB weight set is a constant floor under the whole ladder. **Every live peak (RSS/VRAM high-water) is NOT PROVEN** — an accounted ceiling is not a measured peak; §7 files the exact recipe for the J-098 gate.

## 2. Definitions and verdict rules (pre-registered)

Stated in `core/memory_ceiling.mojo`'s header and committed (@ `fa99680a`) before the harness was built or run.

- **Peak moment:** a rung's peak is taken at the **write leg's session context** (rung + 128, J-091's session definition) — the moment the session's KV is largest while every other component is already resident. The read leg's total (same components at the rung itself) is priced in the harness and is never the peak.
- **Form A components** (all defined through the tree): **weights** = the sha-pinned file's bytes, 4,683,074,688 (a dense session's resident set is the whole file); **KV** = `ladder_kv_total` at the session context at the stated precision (f16 57,344 B/token via J-087, per-row int8 29,568 via J-088); **activation** = the profile's own `activation_elements` shape (208,896 fixed + 28 per context token) × 4 B; **sampling** = `sampling_device_bytes`, 905,728 B, on the **GPU line only** — the host line has no device sampler buffer, so the CPU peak is the GPU peak minus exactly that term at every cell. The GPU session peak **is** J-091's `ladder_gpu_required_bytes` at the session context, so Form A's GPU column must reproduce J-091 §5.3 exactly (the validation gate, §8).
- **Cell verdicts:** J-091's, inherited unchanged through `ladder_cell_verdict` (integration judged before caps). A rung's **peak verdict** is its write-leg verdict. This slice adds no verdict of its own.
- **Form B's pool rule, and why:** when sessions share a process the expert-cache budget is chosen by **J-026's pool rule** (`plan_shared_cache_pool`), not J-018's per-session sizing — J-026 §2 proved independent sizing over-commits (two sessions claim 14,800 B of a stated 10,000 B machine, the OS headroom charged twice; the same over-commit reproduces on this slice's stated machine, §5.3). The pool runs J-018's reserve arithmetic **once** over **summed** reserves, headroom (total ÷ 5) charged once. Tenants N = 2 under `SharedExpertBudget`: the dense tenant holds no cache bytes (protects 0), the MoE tenant's cap is the whole pool, the floor is pool ÷ 4.
- **Form B's stated machine:** total = free-at-open = **17,179,869,184 B (16 GiB)**, hard cap unset — a **STATED accounting input** in the J-018/J-026 test style, **not a measured machine** (the label travels with every Form B number). Summed reserves: resident_total = dense weights 4,683,074,688 + OLMoE resident 311,027,712 = **4,994,102,400**; kv_total = the dense tenant's KV at its session context (the rung's precision) + the MoE tenant's KV at its standard live configuration (context 512, J-022/J-030: f16 131,072 B/token via J-087; per-row int8 67,584 B/token via J-088 — so Form B's int8 column is a **counterfactual (CF) for both tenants**, exactly as J-091 labels its int8 GPU column); scratch_total = the dense tenant's activation bytes at its session context (its scratch role in this account — its only per-session volatile allocation beside KV in the admission shape; stated here, answered-locally) + OLMoE's activation allowance 16,777,216 B (J-031's named allowance).
- **Combined peak vs accounted ceiling:** combined **peak** = resident_total + kv_total + scratch_total + **min(pool, expert body 3,900,702,720)** — a cache can never hold more than the body it caches. The **accounted ceiling** charges the full pool instead: resident + kv + scratch + pool = free − headroom on the stated machine. Both are filed; the peak is the headline.
- **Growth-shape rule:** Janas's published ratio is 49/26 = **1,884,615 ppm** (floored parts per million). Aesir's shape per form/line/precision is top-rung peak × 1,000,000 ÷ base-rung peak (floored ppm, exact integer arithmetic). Verdict, mechanical, no tolerance band: below Janas's → **FLATTER**; equal → **MATCHES**; above → **STEEPER**. The driver is filed in bytes: the KV share of the peak at the base and top rungs.

## 3. Inspection — the two witnesses and the absence between them (PROVEN from the tree)

- **The dense witness has no routed experts.** Coder-7B's profile (`core/dense_gqa_profile.mojo`) is a dense GQA shape; its session (`core/llama3_cuda.mojo`) is built over `DenseGQAProfile`; nothing in its path constructs an `ExpertCache`. Its KV prices and caps are J-091's (host cap 16,000; profile cap 32,768; int8 integrated on neither line — inspect-asserted again by J-093's script through the verdict columns).
- **The MoE witness is the cache's home.** OLMoE-1B-7B Q4_K_M, sha256 `8c310f1435a1222338fd2d3d974975be9cd908180b644bab0c2a94da1ac32f3f`, 4,213,512,672 B (J-015 pin): resident set 311,027,712 B, routed body 3,900,702,720 B over 1,024 (layer, expert) pairs, per-token routed demand (cold ceiling) 487,587,840 B — all MEASURED in J-015/J-017. Its session (`core/moe_session.mojo`) admits arch `olmoe` only and takes the cache budget it is handed; the pool discipline is its documented host contract (J-026).
- **No combined session exists.** No file in the tree constructs a dense session and an MoE session in one process, and no session imports `core.memory_ceiling` after this slice either (inspect-asserted, §8) — Form B is a **process-budget account** over the tree's own sizing arithmetic, which is exactly the level at which J-026's pool rule operates (its live two-session leg is likewise NOT PROVEN, deferred there and re-cited in §7 here). Registration in `tests/run_all.mojo` is **not** done, for J-031 §10's stated reason (inspect-asserted).

## 4. What was built (PROVEN, VM, lightest target)

- **`aesir_engine/core/memory_ceiling.mojo`** (new; pure accounting in the road's grain): Form A peaks defined **through** `core/kv_ladder.mojo` (`ladder_gpu_required_bytes`, `ladder_kv_total`, `ladder_cell_verdict`); the activation term in the profile's own shape; floored-ppm ratio/share arithmetic with overflow guards; the pre-registered shape verdict against the filed Janas ratio constant; Form B defined **through** `core/expert_cache.mojo` (`plan_shared_cache_pool`, `SharedExpertBudget`); combined peak (min(pool, body)) and accounted ceiling as separate functions so neither can be quoted as the other. No existing module was modified; no session is wired.
- **`docs/janas/j093_ceiling.mojo`** (new; harness): prints the §5 tables from the module — one CEILING line per rung × precision, one COMBINED line per rung × precision, one GROWTH line per precision — deterministic (two runs byte-identical, sha256 `703c5514…2092`). It prints no live peak, by design (its header says so).
- **Tests — `test_memory_ceiling`: 10/10 groups PASS** (§8), including the validation gate reproducing J-091 §5.3 numbers EXACTLY where they overlap.

## 5. The ceiling tables (ACCOUNTED; every live peak NOT PROVEN)

### 5.1 Form A — the dense ladder's own peak (session context = rung + 128)

Itemised at the top and base rungs (GPU line, f16): base session (1,152) = weights 4,683,074,688 + KV 66,060,288 + activation 964,608 + sampling 905,728 = **4,751,005,312**; top session (32,896) = weights 4,683,074,688 + KV 1,886,388,224 + activation 4,519,936 + sampling 905,728 = **6,574,888,576**. The whole peak growth is KV growth plus the activation term's growth: 1,823,883,264 = 1,820,327,936 (KV) + 3,555,328 (activation), exactly.

| Rung (session) | KV f16 | Peak GPU f16 | Peak CPU f16 | KV int8 (CF) | Peak GPU int8 (CF) | Peak CPU int8 (CF) |
|---|---|---|---|---|---|---|
| 1,024 (1,152) | 66,060,288 | 4,751,005,312 | 4,750,099,584 | 34,062,336 | 4,719,007,360 | 4,718,101,632 |
| 4,096 (4,224) | 242,221,056 | 4,927,510,144 | 4,926,604,416 | 124,895,232 | 4,810,184,320 | 4,809,278,592 |
| 8,192 (8,320) | 477,102,080 | 5,162,849,920 | 5,161,944,192 | 246,005,760 | 4,931,753,600 | 4,930,847,872 |
| 16,384 (16,512) | 946,864,128 | 5,633,529,472 | 5,632,623,744 | 488,226,816 | 5,174,892,160 | 5,173,986,432 |
| 32,768 (32,896) | 1,886,388,224 | 6,574,888,576 | 6,573,982,848 | 972,668,928 | 5,661,169,280 | 5,660,263,552 |

The GPU columns **are** J-091 §5.3's admission totals (the validation gate, §8). Placement reading, unchanged from J-091: whole-GPU through the 8,192 session against the filed usable 5,368,709,120 B, spill-required from 16,384 at f16; the int8 CF would hold the 16,512 session whole and still spill at 32,896.

### 5.2 Form A verdicts — the peak cell of each rung (write leg; J-091's, unchanged)

| Rung | CPU f16 | GPU f16 | CPU int8 | GPU int8 |
|---|---|---|---|---|
| 1,024 | ACCOUNTED | ACCOUNTED | INTEGRATION_BLOCKED | INTEGRATION_BLOCKED |
| 4,096 | ACCOUNTED | ACCOUNTED | INTEGRATION_BLOCKED | INTEGRATION_BLOCKED |
| 8,192 | ACCOUNTED | ACCOUNTED | INTEGRATION_BLOCKED | INTEGRATION_BLOCKED |
| 16,384 | **CAP_REFUSED** | ACCOUNTED | INTEGRATION_BLOCKED | INTEGRATION_BLOCKED |
| 32,768 | **CAP_REFUSED** | **CAP_REFUSED** | INTEGRATION_BLOCKED | INTEGRATION_BLOCKED |

(Read-leg verdicts, filed in the harness: identical except GPU f16 read @32,768 ACCOUNTED — its session is exactly the rung. ACCOUNTED never means measured: every cell's live peak is deferred, §7.)

### 5.3 Form B — the combined-process ceiling (STATED 16 GiB machine; host account)

| Rung | KV total f16 | Pool f16 | Floor f16 | Combined peak f16 | Combined peak int8 (CF) |
|---|---|---|---|---|---|
| 1,024 | 133,169,152 | 8,598,881,972 | 2,149,720,493 | 9,045,716,096 | 8,981,212,288 |
| 4,096 | 309,329,920 | 8,422,377,140 | 2,105,594,285 | 9,222,220,928 | 9,072,389,248 |
| 8,192 | 544,210,944 | 8,187,037,364 | 2,046,759,341 | 9,457,560,704 | 9,193,958,528 |
| 16,384 | 1,013,972,992 | 7,716,357,812 | 1,929,089,453 | 9,928,240,256 | 9,437,097,088 |
| 32,768 | 1,953,497,088 | 6,774,998,708 | 1,693,749,677 | 10,869,599,360 | 9,923,374,208 |

Readings, no more than the arithmetic says: (a) the **accounted ceiling is 13,743,895,348 B at every rung and precision** (free − headroom on the stated machine) — as the dense tenant's KV grows, the pool shrinks by exactly the KV + scratch growth (f16 base→top: pool −1,823,883,264, the same bytes as Form A's growth), so the process's accounted total does not move; the growth shows up as **expert-cache shrinkage**, which is the pool rule working as designed. (b) The pool exceeds the expert body at every rung on this machine, so the cache's peak residency is the body itself (3,900,702,720) and the combined **peak** grows only by the KV growth on a two-model constant base (residents 4,994,102,400 + body 3,900,702,720 = 8,894,805,120 of the 9,045,716,096 base peak — 98.3% constant). (c) The pool stays far above its floor and above one token's routed demand at every rung (`below_floor` false throughout); on a small stated machine the same sizing states `below_floor` instead of hiding it (tests, §8). (d) The dense tenant under **independent** J-018 sizing would take 8,994,087,764 B of cache budget against this same free snapshot — beside the pool's 8,598,881,972 that is the J-026 over-commit shape reproducing at this slice's scale, and the reason the pool rule, not per-session sizing, governs Form B. (e) Form B's binding **run** verdicts are inherited from its tenants: the dense tenant's host-line session is CAP_REFUSED at the 16k/32k rungs (its Form A CPU verdicts) and its int8 column is CF for both tenants — Form B files a budget, not a runnable configuration, at those cells.

## 6. The Janas shape test (the roadmap's named comparison)

Janas's published growth: 2.6 → 4.9 GiB = ratio **1,884,615 ppm** (1.885×). Aesir's accounted growth, top-rung ÷ base-rung session peak:

| Form | Line / precision | Ratio (ppm) | Ratio (×) | Verdict |
|---|---|---|---|---|
| A | GPU f16 | 1,383,894 | 1.384× | **FLATTER** |
| A | CPU f16 | 1,383,967 | 1.384× | **FLATTER** |
| A | GPU int8 (CF) | 1,199,652 | 1.200× | **FLATTER** |
| A | CPU int8 (CF) | 1,199,690 | 1.200× | **FLATTER** |
| B | f16 | 1,201,629 | 1.202× | **FLATTER** |
| B | int8 (CF) | 1,104,903 | 1.105× | **FLATTER** |

**Verdict, stated plainly: Aesir's accounted peak growth is FLATTER than Janas's published shape on every form, line and precision — it MATCHES nowhere and is STEEPER nowhere.** Why, in bytes (f16, GPU line): the peak's constant part — the fully-resident weight set, 4,683,074,688 B — is **98.57%** of the base-rung peak and still **71.23%** of the top-rung peak; the only large growing term, KV, is **1.39%** (13,904 ppm) of the peak at the base rung and **28.69%** (286,908 ppm) at the top. A near-doubling shape like Janas's 1.885× needs the growing term to dominate the top of the ladder; in Aesir's account it is a minority at every rung, so the ratio is bounded well below it. At int8 the KV term is smaller still (0.72% → 17.18%), and the shape flattens further — 8-bit KV is a **ceiling** lever here exactly as J-092 filed it as a traffic/admission lever: it lowers every rung's peak (by 910,163,968 B at the top session) and flattens the growth, it does not change any work. Form B is flatter still for a different reason, also in bytes: its constant base is two models' residents plus the whole expert body (98.3% of its base peak), and its accounted ceiling does not grow at all — the pool absorbs the growth (§5.3).

## 7. Deferred legs — live peaks (DEFERRED-WITH-REASON; recipe for the J-098 gate to re-cite)

**Why deferred:** the VM stayed far below the 5,500 MB inference gate all tick (MemAvailable ~0.39–1.16 GB) and purplelongship is unreachable and 204-owned when it returns — no session could run on any box, so no RSS or VRAM high-water exists to file. Accounted ceilings are filed **instead of** measured peaks, never as them.

**The recipe, in dependency order:**

1. **Window and machine discipline:** purplelongship in a guarded idle gap (204 state heartbeat checked first; yield to a live 204 run); one heavy run at a time; per run file load, MemAvailable/VRAM, Tctl, and `nvidia-smi` state. The median of 3 runs per cell is the filed peak; a single run files as MEASURED-INDICATIVE.
2. **Re-pin before running:** sha256 of the Coder Q4_K_M file must equal `8053aeda222ba79e865a6eddd268332fd4e4dbe406371318d6df1f9beae9502b` (4,683,074,688 B) and of the OLMoE Q4_K_M file `8c310f1435a1222338fd2d3d974975be9cd908180b644bab0c2a94da1ac32f3f` (4,213,512,672 B) on the box before any leg; a file that does not verify does not run.
3. **Form A legs (f16 first):** per ACCOUNTED cell of §5.2, run the J-091 §7 read+write legs (same prompts, same session construction); record beside this slice's accounted peak for the cell: the host process **peak RSS** (VmHWM / `getrusage` maximum resident set, KiB) for the CPU line, and for the GPU line the session's **VRAM high-water** (`nvidia-smi` memory.used sampled through the session plus the driver's per-process peak where the surface reports it) **and** its host peak RSS. File measured and accounted side by side with the divergence named, never smoothed; a measured peak **above** the accounted ceiling is a defect in the accounting and reopens this slice.
4. **Cap-adjusted and cap-refused cells:** the GPU 32k write runs in J-091's cap-adjusted form (prompt 32,640 + 128 generated, session exactly 32,768), named as adjusted wherever filed; the CPU 16k/32k cells stay CAP_REFUSED unless the gate first lands its own explicit cap decision (J-091 §7 step 4) — the ceiling table does not presume it.
5. **Form B leg:** only on a host surface that constructs both sessions in one process under the J-026 host contract (pool sized once from summed reserves, each session built with its `cap_for` budget) — no such surface exists today (§3), so this leg waits on that wiring and is not faked from two separate processes: two processes do not share a pool, and their summed RSS is not Form B's measurement. When the surface exists: dense tenant at the ladder rungs (host line, ACCOUNTED cells), MoE tenant at context 512 with its standard configuration re-sized through the pool, the process peak RSS filed beside §5.3's combined peak and accounted ceiling for the same rung.
6. **Int8 legs:** only after J-088 §7's integration lands per line; until then every int8 peak — accounted CF in this slice, live anywhere — keeps the INTEGRATION_BLOCKED verdict in any gate table.
7. **Faithfulness of every Aesir row:** ids-first, then teacher-forcing rank + logit gap against the ggml CPU comparator on the raw prompt (CPU engine vs CPU comparator only; **never `llama-cli --single-turn`**), per J-089 §7 / J-091 §7 step 7; a reference that fails files COMPARATOR_ARTIFACT with its kind named.
8. **Registration:** with the counted live run, register `test_memory_ceiling` in `tests/run_all.mojo` and re-account the pin (J-031 §10's rule).

## 8. Tests and inspect (PROVEN, VM, lightest target)

Filed as `j093_test_output.txt` (build recipe and machine state in its header):

- **`test_memory_ceiling` (new): 10/10 groups PASS** — endpoints reproducing J-087/J-088 prices on both witnesses; the **validation gate** (Form A GPU session peaks == J-091 §5.3 EXACTLY at all 5 rungs, both precisions); CPU == GPU − 905,728 at all 10 session cells with read totals below the peak (read @16,384 == J-091's cross-check figure 5,626,175,104); peak verdicts inherited (int8 INTEGRATION_BLOCKED in all 20 line × rung × direction cells); the growth-shape ratios and KV-share pins; pool sizing at the base rung (reserve 8,580,987,212, pool 8,598,881,972, floor 2,149,720,493, MoE cap == pool, independent-sizing over-commit premise); combined peaks exact across the ladder with their ratios; the constant accounted ceiling with the pool shrink == KV + scratch growth (1,823,883,264); the below-floor shape on a tiny stated machine; 8 refusals.
- **Neighbours rebuilt from this tree:** `test_kv_ladder` (J-091) **8/8 PASS**; `test_attention_share` (J-092) **10/10 PASS**; `test_kv_account` (J-087) **10/10 PASS**; `test_kv_int8` (J-088) **8/8 PASS**; `test_expert_cache` (J-018/J-026/J-028) **9/9 PASS** — unchanged.
- **Ceiling harness: two runs byte-identical** (sha256 `703c5514…2092`), exit 0 both.
- **Inspect: `j093_inspect.py`** — checks the module's structure (peaks through J-091, pool through J-026; rules pre-registered in the header), the no-wiring and no-importer facts, the dense/MoE session shapes grepped first-hand, **re-derives every field of every filed CEILING, COMBINED and GROWTH line in Python and compares exactly**, the validation gate against J-091's filed LADDER lines parsed field-by-field, the Janas ratio and KV-share pins, and this doc's honesty content. Its count is filed in `j093_inspect_output.txt`.

## 9. Defects found

- **No defect found in prior work.** The validation gate reproduced J-091 §5.3's admission totals exactly at every rung and precision through the new module, the read leg at a pure 16,384 context reproduced J-091's filed cross-check figure, and every neighbour suite rebuilt from this tree passes unchanged (8/8, 10/10, 10/10, 8/8, 9/9) — J-087's, J-088's, J-091's, J-092's, J-018's, J-026's and J-028's filed figures are this slice's endpoints by construction and by re-run alike.
- **Own-work defect, found and fixed in-slice (test expectation only; no filed number rested on it):** the test's first build pinned the pool shrink (base→top, f16) as 1,823,903,264; the module, the harness and an independent Python derivation all give **1,823,883,264** (KV growth 1,820,327,936 + activation/scratch growth 3,555,328) — a 20,000 transcription slip in the expectation, caught by the suite's own failure on its first run, fixed, and the suite re-run to 10/10 before any number was filed.

## 10. NOT PROVEN list

- **Every live peak — RSS and VRAM high-water, every rung, line, precision and form: NOT PROVEN.** No live run executed in this slice on any hardware. §§5–6 are exact arithmetic (PROVEN as arithmetic) over J-091's frame and J-026's pool rule, plus pre-registered verdicts over tree facts (PROVEN from the tree); they contain no measurement of a running process.
- **That accounted ceilings bound live peaks** — the admission arithmetic the GPU column rests on cross-checked within 4 B at one context in J-091; allocator behaviour, driver overhead, page-cache residency (the J-030 CPU-line witness: a 1,938,424 KiB peak RSS on a run whose accounted resident classes are larger — mmap pages are not RSS) and fragmentation all sit between an account and a high-water mark. §7 step 3's rule stands: a measured peak above its accounted ceiling reopens this slice.
- **Form B as a run** — no host surface constructs the two sessions in one process today (§3); Form B is the pool rule's arithmetic over summed reserves, PROVEN as arithmetic, with its live leg deferred in §7 step 5. Its stated machine is a stated input, not a measured machine: on another machine the pool, floor and combined peak move with free/total exactly as the sizing states, and the accounted-ceiling constancy holds only while the sizing is uncapped and the pool exceeds the floor.
- **The int8 columns as runs** — counterfactuals over J-088's prices through the f16 sessions' shapes (Form A) and the pool arithmetic (Form B); no int8 session exists on either line (INTEGRATION_BLOCKED), and OLMoE's int8 KV is likewise unintegrated.
- **Any other model's ceiling** — filed for the Coder ladder witness and the OLMoE cache witness alone; the module is shape-generic, but no other model's ceiling is filed or claimed here.
- Janas's published growth figures as evidence about Aesir — they name the shape tested in §6 and are cited as nothing else anywhere in this slice.

## 11. Banking

Filed on branch `yrsa/janas-j093` (worktree `~/workspace/aesir-janas-j093`, base `4bb58a0d`): commits — design + accounting + harness first (@ `fa99680a`, pre-registered), then this doc, the inspect script and the filed outputs (with the §9 test-expectation fix). In the tree: `aesir_engine/core/memory_ceiling.mojo` (new) and `aesir_engine/tests/test_memory_ceiling.mojo` (10 groups); in `docs/janas/`: `J093_MEMORY_CEILING.md` (this doc), `j093_ceiling.mojo`, `j093_inspect.py`, `j093_inspect_output.txt`, `j093_test_output.txt`. **No existing module was modified.** Campaign copies of the doc + evidence in `~/workspace/model-tests/janas/`, sha-identical (verified by hash). Push by explicit refspec `git push origin <sha>:refs/heads/yrsa/janas-j093`, foreground, with `git ls-remote` verification that the branch moved and origin/main stayed at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`; the commit hashes and ls-remote lines are recorded in the campaign state entry for J-093 and the slice worker's report (a doc cannot contain its own commit hash). No README touched. Hailo untouched/parked. No Docker.
