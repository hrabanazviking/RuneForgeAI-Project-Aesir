# A-004 Ledger — E-REAL on Z13 CPU (team-04)

- Slice: A-004 — E-REAL on Z13 CPU (Wave 1). Roadmap: docs/AESIR_Z13_MASSIVE_ROADMAP.md.
- Machine: purpleraider (ASUS ROG Flow Z13), AMD RYZEN AI MAX+ 395 w/ Radeon 8060S, 32 threads, 121 GiB RAM. Kernel 7.3.0-10-generic. Execution on CPU (sm_89 is compile-target only, per team-03 canonical pattern; no accelerator execution claimed).
- Worktree: /home/volmarr/aesir-team-04, branch yrsa/aesir-team-04, base ba0cf0662d5fbc6a4531645cb435bc17b6916443. Mojo 1.0.0 (ed45d567), pixi run --frozen.

## Fixture (sha256 recorded BEFORE the run)
- Pinned: shibatch/stories-converted rev 4724c9612ac3278f58aa2dbd4d79457e2672247d, stories260K.F16.gguf, 601248 bytes, downloaded from the pinned Hugging Face URL in CAPABILITY_LEDGER.md / TASK_real_gguf_vertical_slice.md.
- sha256 BEFORE run (hidden_files/a004_fixture_sha256_before.txt): 57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3 — EXACT match to the pinned oracle hash in CAPABILITY_LEDGER.md.
- sha256 re-verified AFTER run: identical (57a81ed1...).

## E-REAL run — PASS (all values read from hidden_files/a004_ereal.log, sha256 78f2fea13eadd6e8720110323cdc70a800ef7a319c2b01ebb942e6f72ce885a3)
- Command (repo procedure, CAPABILITY_LEDGER E-REAL + team-03 canonical staging): pixi run --frozen mojo run -I . --target-accelerator sm_89 -Xlinker staging shims (libaesir_hailo10h, libaesir_par) aesir_engine/tests/test_real_gguf.mojo <fixture>. Script: hidden_files/run_a004.sh.
- MOJO_EXIT=0; final line: "Real GGUF loader, tokenizer, and exact 32-token inference: PASS". Wall 0:13.21, max RSS 1080472 KiB.
- Metadata (asserted in-test, PASS implies exact): GGUF v3, 48 tensors, 21 KV entries, architecture llama, context 128, embedding 64, feed-forward 172, 5 blocks, heads 8 / KV 4, vocab 512; token_embd.weight F16 zero-copy mmap alias verified; output_norm.weight F32->F16 conversion value verified. Log line: "GGUF validated: 48 tensors, 21 metadata entries, architecture llama".
- Tokenizer IDs for prompt "One day, Timmy went to" (log lines 137-145): 1, 385, 328, 432, 405, 263, 377, 267 — exact match to the pinned llama.cpp oracle in the test.
- First greedy token: ID 265, text " the" — exact match.
- 32 greedy token IDs (log lines 152-183): 265, 282, 295, 433, 335, 345, 357, 426, 342, 394, 261, 370, 268, 414, 444, 335, 261, 370, 268, 414, 444, 426, 291, 268, 414, 444, 286, 399, 262, 423, 388, 269 — exact match to the pinned oracle sequence; decoded text " the park with his mom. They saw a big box with a big box. The box was very small and"; stop reason "length".
- Also asserted PASS in the same run: 1-token replay (265 / " the" / length), full-context boundary (128 prompt tokens -> 1 generated, stop "context_exhausted"), and pool offset restoration (runtime boundary).

## E-MASTER gate (banking gate, team-04 worktree)
- Log: hidden_files/a004_run_all_canonical.log (sha256 ea5d36f5bbc1915f64f131d94fca112766413b077976cae422ed0513620b66de), summary lines 1166-1169: Passed 277 / Failed 1 / Skipped 2 / Total 280.
- Identical to the A-003 Z13 baseline (277/1/2/280): no regression. Sole failure = gguf.tensor_directory_interface, the pre-existing J-022 loader/test contract drift (rank-3 admission), already triaged by team-03 with roads A-165 (primary) / A-121 — NOT introduced by A-004 and out of this slice's scope (evidence-only slice, no tracked source changed). Skips = the 2 pre-declared (vision.cuda_session_image_chat, rag.real_engine_integration).

## Verdict
- A-004 acceptance: PASS — metadata, tokenizer IDs, first token, and 32 greedy token IDs all match the pinned oracle exactly on Z13 CPU. Raw-oracle discipline held (greedy exact-ID comparison against the pinned llama.cpp oracle, CPU vs CPU). No accelerator claim made.
- No new bug discovered in this slice. The known J-022 failure stands as the campaign's recorded next-work item (roads A-165/A-121) per team-03's triage.
