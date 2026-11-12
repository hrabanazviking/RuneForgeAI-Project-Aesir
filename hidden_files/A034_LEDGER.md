# A-034 Ledger - Deterministic replay

- Slice: A-034 - Deterministic replay (roadmap: Seeded runs reproduce exactly on the CPU path. Acceptance: two runs of the standard battery produce identical token streams and identical filed hashes.)
- Team: 02 (restart lead + 6 Mythic Engineering sub-agents), worktree /home/volmarr/aesir-team-02, branch yrsa/aesir-team-02
- Base: c9f0047e (A-031 banked at seat; 31 of 216). Status: BUILT + TESTED + COMMITTED by team-02; banking is the keeper/seat job in roadmap order (A-032, A-033 bank first). Do NOT merge or push from this worktree.
- Date: 2026-11-12 (battery 06:15 EST, suite 06:18 EST), host purpleraider, Mojo 1.2.0, target gfx1151, CPU path.

## Design (inherited from the previous lead, verified sound, kept)

- Root defect fixed by the slice: GenerationConfig.seed never reached the sampler; every forward pass re-seeded RuneRNG(42), so seeded runs were neither seed-controlled nor honestly reproducible.
- aesir_engine/core/inference.mojo: new replay_rng(seed, position) - stateless by construction: a RuneRNG seeded once per generation and advanced once per sampled position is reproduced by constructing RuneRNG(seed) and discarding position draws, so position p draws the (p+1)-th stream value, exactly what one persistent RNG would draw. All six sampling sites (forward_pass, forward_pass_batched, forward_pass_gemma4, forward_pass_gemma4_batched, forward_pass_qwen35, forward_pass_qwen35_batched) now take seed: UInt64 = 42 and sample via replay_rng(seed, start_pos) (batched twins: start_pos + batch_len - 1, the last row position, matching their last-row-only output stage).
- aesir_engine/aesir.mojo: gen_config.seed threaded as the trailing argument at all six AesirEngine dispatch call sites (_forward_position and _forward_position_batched, all architectures).
- Battery harness aesir_engine/tests/replay_a034.mojo is STANDALONE - it is NOT part of run_all; the run_all pin stays 362 (stated plainly per slice instructions). RAW prompt only (One day, Timmy went to), no chat template, CPU path; fixture stories260K.F16.gguf sha256 57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3.
- Battery legs: GREEDY temp 0.0, 32 tokens, asserted token-for-token against the pinned A-004 raw-prompt oracle; SEEDED temp 0.8 / top_k 40 / top_p 0.95 / rep 1.0 / seed 1234 on two fresh engine instances, asserted identical; ALTSEED seed 999, asserted DIFFERENT (proves the seed is live). Driver hidden_files/run_a034.sh builds once and runs the binary TWICE as separate processes, diffs full outputs, files sha256 hashes.

## Bugs found and fixed in scope (this restart)

1. Mojo overload-resolution error (the cancelled run failed battery): inference.mojo:1418, the no-KVCache forward_pass overload appended seed positionally to its inner forward_pass call, landing it in the is_prefill (Bool) slot of the main signature (seed comes after is_prefill/span_start/span_rows there). Compiler: no matching function in call to forward_pass; candidate not viable: value passed to is_prefill cannot be converted from UInt64 to Bool. Fix: pass it as a keyword, seed=seed, in that one inner call. All other call sites were audited against their callee signatures and are correctly ordered.
2. Link failure (found on the restart, after fix 1 let compilation succeed): run_a034.sh built with no native shim libraries, so the link died on undefined references aesir_par_cpu_count, aesir_par_for, aesir_cpu_vnni (all in aesir_engine/thread_par.c) and sibling shim symbols. Fix: run_a034.sh now stages the six native shims exactly as the canonical E-MASTER gate scripts do (hailo10h stub, par, hip, merged vulkan, zc, aff into a mktemp staging dir), builds with --target-accelerator gfx1151 and -Xlinker -L/-l for all six, and exports LD_LIBRARY_PATH to the staging dir for the two runs. All six cc steps exit 0 in the battery log.

## Evidence (all counts/hashes read from logs, never memory)

- Replay battery hidden_files/a034_battery.log: BUILD_EXIT=0, RUN1_EXIT=0, RUN2_EXIT=0, DIFF_EXIT=0 (two separate processes, full outputs byte-identical).
- Filed run hashes (sha256 of the full process outputs): run1 8566b03946f9bfcbb6abf640daa176028fc4ef1df4eb19fd591b4a620442d42f - run2 8566b03946f9bfcbb6abf640daa176028fc4ef1df4eb19fd591b4a620442d42f (IDENTICAL).
- Filed FNV-1a token-stream hashes (from a034_run1.log and a034_run2.log, identical in both): GREEDY 7bb54597001a24e0; SEEDED(1234) cd2bc2d155dd6f3e; ALTSEED(999) c55ae7749fd98274 (differs - seed is live). A034_REPLAY: PASS printed by both processes.
- Token streams: GREEDY 265,282,295,433,335,345,357,426,342,394,261,370,268,414,444,335,261,370,268,414,444,426,291,268,414,444,286,399,262,423,388,269 (equals the pinned A-004 oracle - asserted in-process). SEEDED 265,282,295,433,335,345,357,426,338,394,261,282,271,433,268,425,428,404,295,265,282,295,433,426,338,308,277,428,415,413,312,286.
- Full E-MASTER suite in this worktree (hidden_files/run_a034_suite.sh, log hidden_files/a034_run_all.log): Passed 359 / Failed 1 / Skipped 2 / Total 362 - identical to the base pin (359/1/2/362). Sole failure: gguf.tensor_directory_interface (J-022 drift, tolerated). Skips: vision.cuda_session_image_chat and rag.real_engine_integration (the 2 pre-declared). Zero regressions; no new run_all cases added (replay harness is standalone, above).

## Raw-oracle note

Correctness anchor is the A-004 pinned oracle on the RAW prompt (CPU engine vs the llama.cpp-pinned id stream), token-exact for the greedy leg; the seeded legs are judged on exact self-reproduction across instances and processes, which is the slice acceptance - no template-rendered prompts anywhere.
