# A-003 - E-MASTER Baseline on Z13 CPU (filed 2026-11-11)

## Machine / environment (from log header, a003_run_all_canonical.log)
- Host: purpleraider, Linux 7.3.0-10-generic x86_64
- CPU: AMD RYZEN AI MAX+ 395 w/ Radeon 8060S (Strix Halo), 32 threads, 121 GiB RAM
- Base commit: ba0cf0662d5fbc6a4531645cb435bc17b6916443, branch yrsa/aesir-team-03
- Toolchain: pixi 0.76.2; pixi env Mojo 1.0.0 (ed45d567) via `pixi install` from lockfile (log: a003_pixi_install.log). Note: ~/.pixi/bin/mojo on PATH reports 1.2.0 - NOT the version used; all runs went through `pixi run` (env Mojo 1.0.0).
- No NVIDIA GPU present (nvidia-smi cannot communicate with a driver; /dev/kfd + AMD /dev/dri present). Execution was on CPU; sm_89 is a compile target only (repo docs/GEMMA4_CUDA.md: CI uses this explicit compile target, its CPU runner does not execute GPU inference).

## Commands run
1. pixi install (in /home/volmarr/aesir-team-03): `PATH=$HOME/.pixi/bin:$PATH pixi install` -> "The default environment has been installed." (a003_pixi_install.log)
2. TRIAL (failed to build): canonical command WITHOUT --target-accelerator. Log a003_run_all.log sha256 96ac90eb93b3d0f06dc58d2ee903e9d2eae9c66bc73256c9010729c65817b7ff. Build error: function instantiation failed at run_all.mojo:361 via cli.cuda_chat_admission -> dispatch_cuda_chat; mojo: failed to run the pass manager; MOJO_EXIT=1; zero cases executed.
3. BASELINE (canonical, as filed in run_all.mojo header + CAPABILITY_LEDGER E-MASTER): staging cc shims (hailo10h_stub.c, thread_par.c) + `pixi run --frozen mojo run -I . --target-accelerator sm_89 -Xlinker -L$staging -Xlinker -laesir_hailo10h -Xlinker -laesir_par aesir_engine/tests/run_all.mojo`. Log a003_run_all_canonical.log sha256 ef1ed0f50414ad69d75ea241ff6a8a8eccf1ccbba0317a38381715172dd2cf0f. Wall 1:10.10 (time -v, includes JIT compile), max RSS 3,638,652 KiB, MOJO_EXIT=1 (suite raises on any failed case by design).

## BASELINE COUNTS (read from a003_run_all_canonical.log lines 1166-1169, [SUMMARY] block)
- Passed: 277
- Failed: 1
- Skipped: 2
- Total: 280
- Status: FAIL (solely due to the 1 failure below)
- Cross-check: grep -c '[CASE PASS]' = 277 in the same log.

## Failure triage (every failure -> named cause or named road-slice)
1. FAIL gguf.tensor_directory_interface :: "tensor directory admission differs for rank 3: GGUF is missing required tensor: token_embd.weight" (log line 231).
   NAMED CAUSE: test/loader contract drift from slice J-022 (git 2ce6c843, "loader admits MoE files"). aesir_engine/loader/gguf.mojo _parse_tensors now admits rank 1-3 (error text "Inference tensor must have one to three dimensions") and folds rank-3 MoE expert tensors [in, out, experts] into rows; the older test test_gguf_metadata_types.mojo tensor_directory_probe(3, 1, "one or two dimensions") still expects rank-3 rejection. The rank-3 fixture is therefore admitted and the load proceeds to required-tensor validation, producing the observed token_embd.weight error. Not a Z13/AMD-specific failure; not fixed inside A-003 because reconciling the rank contract changes J-022 MoE semantics.
   NAMED ROAD: A-165 (Corrupt-model battery - lying tensor directories, fail closed with named errors) as primary reconciliation home; A-121 (MoE battery) for the rank-3 expert-tensor contract. Recorded in CAMPAIGN_STATE.md as immediate next work item for the campaign.

## Skip triage (both pre-declared, expected on this hardware)
1. SKIP vision.cuda_session_image_chat :: "requires the real Gemma 4 pair and a CUDA device; opt-in program tests/image_chat_cuda_mmproj.mojo" (log line 269). No CUDA device on Z13 - honest-absent.
2. SKIP rag.real_engine_integration :: "requires a validated external GGUF fixture" (log line 442). External-fixture skip, pre-declared via record_skip in run_all.mojo.

## Other findings triaged
- Header known-issue NOT reproduced: run_all.mojo header warns of a segfault inside rag.cosine_similarity after 74 passing cases on the base tree; on purpleraider all 280 cases executed, rag.cosine_similarity PASSED (log line 428), no segfault. Baseline records: not reproduced on Z13 / Mojo 1.0.0.
- No-flag CPU build failure (trial 2): named cause = pre-existing, documented in DEVLOG.md line 898 ("tests/run_all.mojo does not build on the CPU-only toolchain", stdlib GPU-architecture constraint via cuda_sampling.mojo; instantiation chain via cli.cuda_chat_admission). NAMED ROAD: A-028 (Target-flag audit - fast suite builds and runs on the Z13 with zero NVIDIA flags) and A-002 (CPU build with no NVIDIA target flags).
- Ledger count drift: CAPABILITY_LEDGER.md E-MASTER row states 275 registered + 2 skipped = total 277, stale vs the code pin ledger.finish(280) (re-pin comments in run_all.mojo: 277->278->279->280) and vs this baseline (280 total). NAMED ROAD: A-208 (counts vs the A-003 baseline - zero unexplained regressions) is where ledger/count reconciliation belongs.

## Deliverable nature
Evidence-only slice: baseline counts + triage filed here and in CAMPAIGN_STATE.md. No tracked repo files changed; nothing to commit on yrsa/aesir-team-03. Banking (in roadmap order, after A-001/A-002) is the keeper's step at the ~/aesir-forge seat.

## Ledger cross-check (CAPABILITY_LEDGER.md E-MASTER row, verified from disk)
- Ledger states 276 passed / 0 failed / 2 skipped / 278 total for its last full E-MASTER run, and names the same two skips found here (vision.cuda_session_image_chat, rag.real_engine_integration). This Z13 baseline: 277 / 1 / 2 / 280. Total grew 278 -> 280 via the documented re-pins in run_all.mojo; the +1 failure is the gguf.tensor_directory_interface item triaged above.
- Ledger E-MASTER row header text elsewhere in the file still says 275 registered / total 277 - stale wording, same A-208 reconciliation item.

## Addendum - ledger semantics cross-check (team investigation, verified from disk)
- TestLedger (aesir_engine/tests/test_ledger.mojo): run_case records exactly one outcome per case and execution continues after a failure; record_skip never enters failure_details; finish(expected_total) FAILs on count mismatch OR any failed case. Code registrations verified: 278 run_case + 2 record_skip = pin 280. Expected clean run at this pin: 278 passed / 0 failed / 2 skipped / 280 total. This baseline differs from clean ONLY by the 1 triaged failure (277/1/2/280). No pre-tolerated failure count is named anywhere in the ledger or roadmap for A-003.
- Segfault header staleness: the header's "after 74 passing cases" figure dates from an earlier registration set - in the current order rag.cosine_similarity is the 84th registration (83 preceding, incl. 1 skip). No retraction/fix note exists in run_all.mojo or test_rag.mojo. Still NOT reproduced in this run (case passed, summary printed, exit 1 from the counted failure - not a crash exit).
