# A-020 Ledger - Weight residency (team-06)

- Slice: A-020 - Weight residency (Wave 3). Roadmap: docs/AESIR_Z13_MASSIVE_ROADMAP.md.
- Machine: purpleraider (ASUS ROG Flow Z13), AMD Radeon 8060S (gfx1151), HIP runtime libamdhip64.so.7.
- Worktree: /home/volmarr/aesir-team-06, branch yrsa/aesir-team-06, base da2cf9d8 (seat main, A-017; ls-remote verified equal at tick start; A-006 verified banked in seat log at a8b8d8ff).
- Team: lead + 6 Mythic Engineering sub-agents (loader audit, accounting design, GPU-visibility path, E-REAL fixture audit, test design, git/suite verify) - all six reported; design inputs folded in below.

## What was built

- aesir_engine/core/weight_residency.mojo (new): ResidencyAccounting split of a loaded GGUFSeer (byte sizes from the loader's own _tensor_byte_size, so accounting cannot drift from admission math), zero-copy alias verification (tensor data pointer == mmap base + file offset, per tensor), HIP host-registration wrappers, and /proc accounting wrappers (process VmRSS; smaps of the mapping holding an address).
- aesir_engine/hip_memory_shim.c (extended, A-011 shim): aesir_hip_host_register / _unregister / _host_device_pointer (hipHostRegister with hipHostRegisterMapped=2, hipHostGetDevicePointer) + aesir_residency_process_rss_bytes + aesir_residency_mapping_bytes. The smaps reader is file-awareness-correct: a file-backed mapping's dirty pages are its own page cache (one copy); only anonymous mappings report anon dirty.
- aesir_engine/tests/test_weight_residency.mojo (new): 4 E-MASTER cases (below).
- aesir_engine/tests/test_weight_residency_real.mojo (new): standalone real-fixture proof (not in run_all, which takes no fixture path; A-004 test_real_gguf precedent). Runner: hidden_files/run_a020.sh (also re-runs the A-004 E-REAL binary). Suite runner: hidden_files/run_a020_suite.sh (seat-gate shape, worktree paths).
- run_all.mojo: +4 cases, pin 319 -> 323 with house-style comment.

## Loader audit result (pre-existing, verified this slice)

GGUFSeer._map_tensor already aliases F16 and quantized tensors directly into the single read-only mmap (zero-copy); only F32/BF16 tensors are converted into the MimirWell pool as f16 (the engine consumes f16 views). A-020 makes that residency measurable, verifies every alias pointer-exactly, and makes the mapping GPU-visible; it does not change the loader's mapping behaviour.

## Real-fixture proof (hidden_files/a020_real.log sha256 e1c7f4d587f1b6acf7c5f04885ce5aa514c0c08f7603915a84670f78eb69e024)

- Fixture: stories260K.F16.gguf (team-04 A-004 fixture), 601248 bytes, sha256 57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3 pinned before AND after the run in the log - exact match to the A-004 pin.
- Accounting (from the log): file_bytes 601248; data_offset (header+metadata) 14240; tensor_payload 587008 (= file - data_offset, exact); zero_copy_bytes 584192 across 37 tensors; converted_source_bytes 2816 across 11 tensors (the F32 norm tensors); converted_pool_bytes 1408; duplicate_resident_bytes 2816 = 0.48% of payload. Zero-copy aliases verified pointer-exact: 37/37.
- RSS + mapping (three distinct numbers, never conflated): process VmRSS 1085501440 before load, 1088479232 after (delta 2977792; the Mojo JIT process baseline dominates); the weight mapping itself (smaps, after faulting every tensor page in via the tensor views): resident 602112 bytes (= file size page-rounded), file-backed 602112, anonymous dirty 0 - a single file-backed residency.
- GPU visibility: hipHostRegisterMapped over the whole mapping, rc 0; hipHostGetDevicePointer == mmap pointer (same address, printed in the log). hipMemGetInfo free fell by exactly 602112 during registration - on this unified-memory APU the HIP pool CHARGES the registered range as device-visible; the no-copy evidence is pointer identity + mapping resident unchanged at 602112 + anon dirty still 0 after registration. Process RSS rose ~46 MB at first registration (HIP runtime context, 75x the weight size - not a weight copy; recorded, not hidden).
- E-REAL-class check in the same binary: exact 32 greedy token IDs vs the pinned A-004 oracle (raw prompt "One day, Timmy went to") PASS; the standalone A-004 E-REAL binary also re-run in the same script: PASS (EREAL_MOJO_EXIT=0). RESIDENCY_MOJO_EXIT=0.

## Device-side byte read - evidence chain (honest split)

- E-MASTER case gguf.weight_residency_gpu_visibility (in-suite, Mojo): synthetic file mmap registered, device pointer == host pointer, hipMemcpy device->host returns the pattern byte-exact. PASS.
- HIP probes on the real fixture (hidden_files/a020_probe.log sha256 f162e125ac85c2f3d03f55c742a436c26957e886766a4841c7eb8d41bb06a490; python/ctypes, same HIP calls): register rc 0, device pointer == host, hipMemcpy D2H 64 B at offset 0 returns the GGUF magic 47475546, and 4096 B at offset 80032 (token_embd.weight) byte-exact vs the file. PASS.
- OPEN BUG (in-slice discovery, not fixed, not hidden): a hipMemcpy FROM the registered GGUF mapping inside the standalone Mojo proof binary crashes inside libamdhip64 (first crash trace in the run history: glibc memmove called from libamdhip64 hipMemcpy), while the identical calls succeed from C/Python and from the in-suite Mojo case on a synthetic mapping. Root cause not established (candidates: Mojo JIT/HIP interop in that binary, loader-mapping lifetime interplay). The proof binary therefore asserts registration/accounting/E-REAL and cites the two proofs above for the byte read. Next work recorded in CAMPAIGN_STATE.md.

## E-MASTER gate (hidden_files/a020_run_all.log sha256 786f737db583565eb08184dec58e20030cb2e02332bf1f544c41a6b6c13fbd27)

- 320 passed / 1 failed / 2 skipped / 323 total - exactly the seat baseline (316/1/2/319) plus the 4 new A-020 cases, all passing: gguf.weight_residency_accounting_rules, gguf.weight_residency_mapping_accounting, gguf.weight_residency_gpu_visibility, gguf.weight_residency_no_device_copy.
- Sole failure: gguf.tensor_directory_interface, the pre-existing J-022 drift (roads A-165 primary / A-121) - identical at base; per tasking it is NOT fixed in this slice and does not block A-020 acceptance (the residency accounting uses the loader's tensor directory as-is and the real fixture loads and validates fully).
- Skips: the 2 pre-declared. MOJO_EXIT=1 reflects the sole pre-existing failure, same as the seat gate.

## Bugs found + fixed in-slice

- smaps accounting mislabelled a just-written file's dirty page-cache pages as anonymous duplicates (synthetic-case failure): fixed in the shim - file-backed mappings (nonzero inode) count clean+dirty pages as file-backed; only anonymous mappings report anon dirty. Fixture numbers unchanged (its pages are clean).
- Test-file placement: synthetic fixture moved from /tmp (tmpfs shmem accounting) to the repo filesystem so the accounting measures the same class of residency as the real fixture.
- open64 external_call signature aligned to the loader's 3-arg form (2-arg form conflicts in one program - the A-011 lowering trap).

## Verdict

- A-020 acceptance: PASS with the honest split the roadmap allows. GGUF weights are mmap'd once; 584192 of 587008 payload bytes (99.52%) are single-residency zero-copy views, GPU-visible at the SAME address after HIP host registration with a device-visible accounting charge of exactly the resident size (602112) and zero anonymous duplication. The measured exception is 2816 bytes (0.48%): the 11 F32 norm tensors, whose mmap source pages plus f16 pool conversion are resident twice by engine design. Closing even that requires the engine to consume F32 norm views directly (or a BF16/F32 alias path in _map_tensor) - named road: a loader/engine slice after A-121/A-165 settle the tensor-directory contract; not attempted here.
- No README touched. No merge, no push from this worktree (banking is the keeper's seat job).
