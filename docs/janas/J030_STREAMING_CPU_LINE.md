# J-030 — Expert Streaming, CPU Line

**Slice:** J-030 (Part II — Models Bigger Than Memory), Project Aesir Janas clean-room road.
**Roadmap text:** "Expert streaming, CPU line. The same machinery with no GPU in play (pure CPU + disk), the toaster-grade configuration; measured."
**Executed:** 2026-10-31 ~11:54–12:1x EDT. **Closure shape: verdict / re-verification closure (the J-027/J-029 shape) — no new on-box leg ran this slice, and §7 states why plainly, with the coordination timeline.** Every number below traces to a filed artefact re-read and re-hashed this slice, or to arithmetic this slice's filed script (`j030_reverify.py`, output `j030_reverify_output.txt`) recomputed from those artefacts. No number was invented and no number comes from a run that did not happen.
**Base:** branch `yrsa/janas-j030` from `yrsa/janas-j029` tip `b88d90d990d346890a404f1ed3044ca65ab657a8` (ls-remote verified before branching). Origin/main `ba7ee09b6b4d09967b571f2f39714e9119dc3772` untouched by this slice.
**First item executed (never-leave-a-bug, carried from J-029 §8):** the stale pre-harvest J-023 doc in this branch line was reconciled by import-verbatim from `yrsa/janas-j023` @ `164306365b3f00c18450954c1a8b58ebbdd320de` — §6.
**No Janas material was used or needed** — this slice stands entirely on Aesir's own code and J-022/J-023 measurements; the clean-room law was not engaged beyond that record. Hailo untouched/parked. No README touched. No Docker. Nothing deleted to free disk (/tmp was 100 % full at slice start, pre-existing; this slice's scratch went to the workspace overlay under `~/workspace/.verify-tmp/j030`).

**Headline: the CPU line is not a configuration to build — it is the configuration that already ran.** The streamed MoE session built in J-022 (`core/moe_session.mojo` over the J-018 `ExpertCache` + J-019 `StreamReader`) has no GPU path at all: its compute is the engine's host primitives, its run scripts export `CUDA_VISIBLE_DEVICES=` (GPU hidden), and its J-022/J-023 runs are therefore pure CPU + disk runs, measured. Re-verified this slice from the filed logs: at the standard configuration (OLMoE Q4_K_M, 67-token prompt + 24 generated, 512 MiB expert cache) the CPU line's idle leg is **prefill 28.04 s (2.389 tok/s), decode 9.39 s (2.556 tok/s), wall/token 0.4113 s**, with every cache/stream counter and all 24 generated ids **identical** across the J-022 post-fix run, the J-023 idle leg, and the J-023 loaded leg — token identity **PROVEN** against the J-022 post-fix ids, which are themselves the faithfulness-PROVEN ids of J-022 §7.3 (teacher-forcing rank 0 at 23/24, step-23 rank 1 / gap 0.108 vs the ggml CPU comparator). A dedicated fresh CPU-line leg — including the constrained "toaster" variant the existing knobs make definable (§3) — is **deferred-with-reason to the J-034 gate** with the exact re-run recipe (§9): this worker has no device route to purplelongship, and the 204 road's occupancy of that box changed hands during this very slice (§7).

---

## 1. What the CPU line IS in the current tree — established from the code

Inspected this slice in the J-030 tree (`b88d90d9` + the §6 reconciliation commit):

- **`aesir_engine/core/moe_session.mojo`** (582 lines): the module docstring states the session's maths — "attention, norms, and GEMMs are the engine's existing **host primitives**, the same ones the dense TransformerBlock uses." The resident set (embeddings, attention, norms, routers, output head) is read through the ordinary `GGUFSeer` mmap; routed experts are served only through `ExpertCache` (constructed here with the `fsketch` policy, the J-024 winner) + `StreamReader` explicit pread. A text search of the module finds **no occurrence** of `cuda`, `gpu`, `vulkan`, or `device` at all.
- **`core/expert_cache.mojo`** and **`core/stream_reader.mojo`**: likewise no CUDA/GPU reference — the cache is host memory bookkeeping, the reader is `pread` + `posix_fadvise`.
- **The vehicle** `aesir_engine/tests/test_olmoe_stream.mojo` takes `<model.gguf> <context> <cache_bytes> <tokens_csv> <gen_count>` and calls only `MoEStreamSession` — there is no device argument to give it.
- **The run scripts make the no-GPU condition explicit, not incidental:** `docs/janas/j023_run.sh` line 15 is `export CUDA_VISIBLE_DEVICES=` (empty — GPU hidden from the process), and `j022_b1_verify.sh` line 5 is the same. The J-023 legs and the J-022 post-fix verification run therefore executed with no GPU visible to claim.
- **Machine record from the runs themselves:** J-022 §2 records GPU idle (1 MiB used) at its run start and states "The session is **CPU-only** (host primitives; GPU unused)". J-031 owns building GPU assistance into this machinery; until it does, **every** run of this session is a CPU-line run by construction.

**Conclusion of §1 (PROVEN from the tree):** the J-022 post-fix run and both J-023 legs *were* CPU-line measurements — pure CPU compute + NVMe/disk streaming, GPU hidden and untouched. J-030's job is to measure-grade them explicitly as that configuration, which §4–§5 do, not to re-run them under a new flag that does not exist.

## 2. The measurement plan — stated before the re-verification was run

- **Legs:** (L1) J-023 idle leg as the CPU-line baseline; (L2) J-023 loaded leg as the CPU line under the bounded browser-class co-runner (already the road's under-load data point for this machinery); (L3) J-022 post-fix run as the independent second binary / second occasion — its walls are expected to differ (it ran under S-093 contention, classed MEASURED-INDICATIVE by J-022 §7.3 itself) while its ids and counters must not.
- **Configuration (identical across L1–L3, so the numbers are directly comparable):** OLMoE-1B-7B-0924-Instruct Q4_K_M, 4,213,512,672 B, sha256 `8c310f1435a1222338fd2d3d974975be9cd908180b644bab0c2a94da1ac32f3f` (the J-015 pin); the lighthouse prose prompt, 67 ids from the model's own tokenizer stack; context 512; expert-cache budget 512 MiB = 536,870,912 B; 24 generated tokens; 91 stepped tokens.
- **Success:** generated ids of L1 and L2 exactly equal to the J-022 post-fix ids (all 24); cache/stream counters of L1/L2 in family with — in fact, per J-023's finding, identical to — L3's; walls reported as prefill / decode / per-token / tok/s with their honesty class, never as a baseline.
- **Failure handling:** any id or counter divergence would be a defect to bisect in scope, not a number to file quietly.

## 3. "Toaster-grade", concretely — what the knobs are, and what is not claimed

Two real constraint knobs exist in the current tree; no other knob is claimed:

1. **Cache budget** — the vehicle's `cache_bytes` argument is a genuine knob (J-022 itself ran a 4 GiB control through it). A constrained leg at 128 MiB (134,217,728 B) is definable today.
2. **Thread count** — `core/parallel.mojo`: `AESIR_THREADS=1` forces the serial path, `AESIR_THREADS=N` caps the worker chunk count, unset selects the online CPU count (≤ 32); `AESIR_PAR_MIN_WORK` overrides the threading engagement threshold. The GEMMs the session calls partition output columns across `par_for`, so this env genuinely constrains the CPU line's parallelism.

A dedicated constrained leg (e.g. `AESIR_THREADS=2` + 128 MiB cache) is therefore **definable but was NOT run this slice** (§7) — no number for it exists in this doc, and none may be quoted from it. It is roaded, with its exact recipe, to the J-034 gate (§9).

Two scope truths, stated so the headline is not over-read:

- **"Toaster-grade" here names a configuration (no GPU, CPU + disk only), not weak hardware.** All filed numbers are purplelongship numbers (Ryzen 9 laptop line, NVMe, kernel 7.0.0-38-generic). What a genuinely weaker/older CPU does with this machinery is **NOT PROVEN** (§8) — the configuration travels, the walls do not automatically.
- The standard 512 MiB configuration graded in §4 is the CPU line as the road has actually run it; it is not a minimum-hardware claim. The runs' own peak RSS is on file in the J-023 metas: **1,938,424 KiB (idle) / 1,939,492 KiB (loaded)** maximum resident set — the whole CPU-line process, resident set + cache + touched pages, stayed under ~1.94 GB on a run whose model file is 4.21 GB and whose expert body is 3,900,702,720 B.

## 4. The CPU line, measured — re-verified from the filed logs

Artefacts re-read and re-hashed this slice (campaign copies, `~/workspace/model-tests/janas/j023_harvest/`; the same run logs are banked in the J-023 branch line as `j023_run_idle.txt` / `j023_run_loaded.txt` with identical hashes):

| Artefact | sha256 |
|---|---|
| `run_idle.log` | `811b77594ce5dd9077948bb4949a48bbcbcb69fbf0c1474e0df7a73e0888bffd` |
| `run_loaded.log` | `2cbb3c3380be4e5876d663461f18d54fbfaacb9f77c0311fd57e548a68c363e8` |
| `j023_analyze_output.txt` | `e5d0ba8c909890546e66eecbe5810754d73f364639e85082ed89e38ca74af710` |
| `run_idle.meta` / `run_loaded.meta` | `d9f6242fe797c6e9191deefaf114facb93ffa1043c06a189ab39a0dba26167b6` / `a4f5eda145715d5c4419dff223fba4eb41c593753df32538edad3aa59654d4aa` |
| `j022_b1_run_fix.txt` (repo, this tree) | `3b444a244991e287e1237d5a29a24a2ffb7092d373ce037a1c63d2be264bdb01` |

The harvest hashes agree with the values J-029 §2 recorded for the same files. `j030_reverify.py` parsed all three logs and recomputed every derived figure below from the filed raw timings and counters (output filed as `j030_reverify_output.txt`, sha256 `4e4a6eba05cda8cc7e219aeed0571f4ab9db4d577a41be338fd7b8686669597c`):

| Leg | Prefill (s) | Prefill tok/s | Decode (s) | Decode tok/s | Engine wall (s) | Wall/token (s) | Overall tok/s |
|---|---:|---:|---:|---:|---:|---:|---:|
| **L1 idle (J-023)** | 28.040114 | 2.3894 | 9.388560 | 2.5563 | 37.428674 | 0.411304 | 2.4313 |
| L2 loaded (J-023) | 29.474193 | 2.2732 | 10.142579 | 2.3663 | 39.616771 | 0.435349 | 2.2970 |
| L3 J-022 post-fix (S-093-contended) | 47.320765 | 1.4159 | 14.422598 | 1.6641 | 61.743363 | 0.678498 | 1.4738 |

Ratios L2/L1, recomputed: wall/token **1.0585**, prefill 1.0511, decode 1.0803 — agreeing with J-023's analyser (1.058 / 1.051 / 1.080) and its NO-THRASH verdict. Cache/stream counters, **identical in all three legs**: accesses 11,648; hits 3,007; misses 8,641; cold misses 950; hit rate 0.258156 (per-mille 258 as filed); admissions 1,265; promotions 192; evictions 1,125; bypasses 7,376; evicted-before-reuse 3,387; bytes streamed 32,948,699,136 (= 362,073,616.9 B per stepped token); StreamReader reads 25,923, bytes read 32,948,699,136 (== bytes streamed, checked), advice calls 34,945.

Machine state on file for L1/L2 (the `.meta` files): L1 started loadavg 1.86/2.55/3.33, Tctl +55.0 °C, MemAvailable 38,282,652 KiB (S-093's cooldown wake — J-023's own caveat stands: a post-occupation baseline, not pristine cold idle), ended Tctl +66.9 °C; L2 ended Tctl +82.4 °C under the co-runner's own heat, co-runner verified gone.

**Reading of the table, with its classes:** the CPU line's *behaviour* (ids, counters, bytes) is deterministic and reproduced across three runs, two binaries, and two load conditions — **MEASURED, and the identity part PROVEN (§5)**. The *walls* are single runs per leg on a thermally varying laptop — **MEASURED-INDICATIVE**, exactly as J-022/J-023 classed them; L3's row is the standing proof of why: same ids, same counters, 65 % more wall, purely from S-093 contention. No tok/s figure in this section is a baseline, and none is a claim about any other CPU.

## 5. Token identity — the success criterion, checked by script

`j030_reverify.py` asserts, and its filed output records **ALL CHECKS PASS** (exit 0):

- L1 generated ids == J-022 post-fix ids — PASS (all 24: `187, 187, 510, 1708, 5967, 6225, 327, 247, 33848, 562, 68, 1658, 13, 253, 760, 581, 323, 6574, 1475, 15, 733, 369, 247, 10086`)
- L2 generated ids == J-022 post-fix ids — PASS
- L1 prompt ids == J-022 prompt ids (all 67) — PASS
- L1 cache counters == J-022 post-fix cache counters (every field) — PASS
- L2 cache counters == L1 cache counters — PASS
- L2 stream counters == L1 stream counters — PASS
- Stream bytes read == cache bytes streamed (L1) — PASS

So the CPU line reproduces, token for token, the output whose faithfulness J-022 §7.3 proved against the ggml CPU comparator (rank 0 at 23/24; the one exception, step 23, is the comparator's own near-tie: Aesir's 10086 vs ggml free-running's 41789, gap 0.108 — the same step in every leg here). **Token identity for the CPU line: PROVEN** (for this model, prompt, and configuration — the scope every identity proof on this road carries).

## 6. The J-023 reconciliation (first item, from J-029 §8) — hashes

- Before: `docs/janas/J023_STREAMING_UNDER_LOAD.md` in the J-029-tip tree, sha256 **`b9771797db0bb332e78d749c33651a7c13fa2bde549481f8aeb079e25d745e7b`** — the stale pre-harvest version (banking-time header, measurement leg still "BLOCKED-WITH-REASON").
- Source: the same path on branch `yrsa/janas-j023` @ `164306365b3f00c18450954c1a8b58ebbdd320de` (ls-remote verified this slice; the local J-023 worktree stands at that commit), sha256 **`5440a4a92b134681680c5ac5e2f40053362c01a4709c117c90b225a12e2af689`**.
- After: the J-030 tree's file is byte-identical to the source — sha256 `5440a4a9…f689` re-verified after the copy; the diff is +32/−10 lines (the harvest §5/§6 completion replacing the blocked header). Banked as its own commit ahead of this doc, per the slice's instruction. No line of the harvested text was edited.

## 7. No new on-box leg ran this slice — stated plainly, with the timeline

- **At dispatch (~11:42–11:53 EDT)** the 204 road's S-095 was live on purplelongship (driver PID 1952430, tf/fr legs in flight, no DONE marker — 204 heartbeat 11:42, re-read at this slice's start). Coordination law: yield; never contend, never stack.
- **On this slice's second check (~11:59–12:0x EDT)** the picture had moved: S-095's driver **completed at 11:46:29 EDT** (`GRADE_DONE / DRIVER_EXIT=0`, tmux gone), its closure worker was verification-record-only (no inference re-run, **no S-096 start**), and the 204 file's 12:0x entry records **S-095 DONE** with S-096 the next open slice. So at the moment of writing there is no *recorded* live 204 run — and also no guarantee: S-096's dispatch is the 204 keeper's next move and can land at any tick.
- **This worker has no device route to purplelongship** (the same posture recorded by the J-024/J-028/J-029 workers): it cannot independently verify on-box processes, cannot build on-box with the proven J-022 recipe, and cannot run the guarded leg driver. A leg it cannot guard, build, or verify would be exactly the kind of unmeasured claim this road forbids.
- **The VM cannot substitute:** MemAvailable measured this slice ≈ 5,040 MB at start and ≈ 4,761 MB later (free -m) — below the 5,500 MB inference gate both times. No VM inference was attempted.

The closure therefore stands on §1's construction proof plus §4/§5's re-verification — the honest shape the slice's own instruction prescribes for this coordination state — and the fresh dedicated leg (standard + constrained) is deferred-with-reason to J-034 with the recipe in §9, where a device-capable worker in a verified clean gap can run it.

## 8. Honesty ledger

- **PROVEN:** the CPU-line construction (§1 — no GPU path in the session/cache/reader code; `CUDA_VISIBLE_DEVICES=` in both run scripts; J-022's recorded GPU-idle 1 MiB at run start); token identity across L1/L2/L3 vs the J-022 post-fix ids (§5, script-checked, all 24); the J-023 reconciliation (§6, sha-verified both sides); that every figure in §4 exists in, or is arithmetic by the filed script on, the hashed artefacts of §4.
- **MEASURED:** the cache/stream counters (identical across three runs — deterministic quantities); bytes streamed and bytes/token; the L1/L2/L3 raw prefill/decode timings as filed.
- **MEASURED-INDICATIVE:** every wall-derived rate in §4 (wall/token, prefill/decode/overall tok/s, the L2/L1 ratios) — single runs per leg, thermally varying box, L1 in S-093's cooldown wake, L3 under live S-093 contention. Real measurements of those runs; not baselines; not transferable to other machines.
- **SIMULATED:** only inherited — J-023's co-runner load class in L2 (a bounded named stand-in for browser-class load), classed as such by J-023 itself.
- **NOT PROVEN:** any GPU comparison (that is J-031, by the roadmap's own division — nothing here grades GPU assistance, for or against); tok/s or walls on weaker/older CPUs than purplelongship's Ryzen 9 (the true "toaster hardware" question); the constrained configuration's numbers (`AESIR_THREADS`-capped and/or 128 MiB cache — knobs proven to exist in §3, never run); decode-heavy behaviour (24 generated tokens is this road's standard leg, not a decode study — J-033's soak owns length); any other model, prompt set, cache budget (the J-022 4 GiB control was a pre-fix bisection instrument, not a CPU-line leg), or storage device; a fresh dedicated J-030 leg of any shape (§7, §9).

## 9. Deferred to the J-034 gate — the dedicated CPU-line leg, exact recipe

For a device-capable worker, in a verified clean gap (204 heartbeat checked **and** on-box guard: no 204 worker processes at leg start, per the J-023 guard discipline):

1. Build from the then-current Janas branch tip with the proven J-022 recipe (C shims `hailo10h_stub.c` / `thread_par.c` first, then `pixi run mojo build --mcpu znver2 --target-accelerator sm_75 -I . -I aesir_engine` + shim link flags) — the `test_olmoe_stream` vehicle.
2. Environment: `export CUDA_VISIBLE_DEVICES=` before every leg; log `nvidia-smi` VRAM/utilisation at leg start and end (expect 1 MiB / no process claim) so the no-GPU condition is on file, not just in the script.
3. Legs, all on the §2 configuration (same file/pin, 67-id prompt, context 512, 24 gen): **(a)** standard — cache 536870912, threads unset; **(b)** constrained threads — `AESIR_THREADS=2`, cache 536870912; **(c)** constrained cache — cache 134217728, threads unset. (Optionally (d) both constraints together.)
4. Per leg, log machine state (loadavg, Tctl, MemAvailable) at start/end, file the full run log, and grade: ids must equal the §5 ids in legs (a)–(c) (threading is bit-identical by `par_for`'s construction; a cache-budget change may lawfully change counters but must not change ids — any id change is a defect to bisect, per J-022's bisection precedent); report walls as MEASURED-INDICATIVE single runs.
5. File results beside this doc and re-cite this slice's §4 table as the re-verification baseline those legs supersede.

## 10. Defects found

- **J-023 doc stale in this branch line — FIXED in scope** (§6; the carried item from J-029 §8, closed with hashes).
- **No defect found in the J-022/J-023 numbers or the session code.** The re-verification's seven checks all PASS. L3's divergent wall is explained by its recorded contention, not by any engine difference (identical counters, identical ids). One construction note for the §9 re-run: the current tree's session constructs its `ExpertCache` with the `fsketch` policy (the J-024 integration flip), whereas the L1–L3 binaries predate that flip — the §9 legs therefore also serve as the first live confirmation that the flipped default reproduces the §5 ids, which is stated there as an explicit grading criterion, not assumed here.

## 11. Artefacts

Filed beside this doc in `docs/janas/`: this document; `j030_reverify.py` (the parser/checker of §4–§5); `j030_reverify_output.txt` (its filed output, ALL CHECKS PASS). The reconciled `J023_STREAMING_UNDER_LOAD.md` (§6) travels in its own commit. Campaign copies of this doc and both artefacts live in `~/workspace/model-tests/janas/`, sha-identical. The evidence artefacts themselves (`j022_b1_run_fix.txt`, the J-023 scripts and harvest logs) already stand filed under their own slices.
