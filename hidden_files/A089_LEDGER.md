# A-089 Ledger - HIP error semantics (team-19)

Roadmap: "HIP error codes mapped into the taxonomy (extends A-033).
Acceptance: fault-injection tests per mapped code."
Base: 3822d595 (banked main, 85 of 216, A-085 closure)

## Defect found (the slice's reason to exist)
Before A-089 the two HIP gateways collapsed EVERY HIP runtime code
into one blanket taxonomy code: HipMemory raised GPU-001 for all
codes, HipTransfer raised GPU-004 for all codes. An out-of-memory,
an invalid argument, a missing device and an illegal address were
indistinguishable. A-033 had mapped hip failure KINDS, never the
per-code semantics the roadmap asks for here.

## What was built
- NEW aesir_engine/core/hip_errors.mojo: single mapping authority
  for raw HIP codes. hip_error_name (symbolic hipError_t name from
  the ROCm header on this host), hip_taxonomy_code,
  hip_error_text ("CODE NAME: <site>: HIP error <rc> (<name>)"),
  raise_hip_error, inject_hip_failure (fault-injection entry).
- Mapping (33 mapped codes): VAL-003 <- 1, 9, 17, 21, 400, 712,
  713 (invalid-argument family); MEM-003 <- 2, 1052 (OOM / HSA
  runtime memory); GPU-012 <- 3, 4 (ROCm init family); GPU-006 <-
  35 (driver); GPU-003 <- 53, 98, 701, 719, 720 (launch family);
  GPU-002 <- 100, 101, 801 (no-device / not-supported, the A-033
  unsupported precedent); GPU-004 <- 600, 702 (timeout family);
  GPU-005 <- 700 (illegal address); INT-001 <- 999, 1053 and ANY
  unmapped positive code (fail-closed fallback, never a blanket
  re-label). hipSuccess (0) is not an error and not mapped.
- structured_errors.mojo: GPU-005 ILLEGAL_MEMORY_ACCESS named and
  added to structured_code_of (taxonomy entry existed in
  ERROR_TAXONOMY.md; A-033 never needed it). This closes the
  taxonomy-gap note A-033 left for A-089 in kind: no NEW taxonomy
  code was invented; existing entries now cover every HIP code.
- Real paths rewired: hip_memory._raise_for_rc and
  hip_transfer._raise_for_rc delegate to raise_hip_error, keeping
  their pre-mapping sentinels ahead of the table: -1 (runtime not
  loadable) -> GPU-002 honest-absent text unchanged, A-022
  ownership codes -22004..-22016 -> VAL-003 unchanged.
  hipStreamQuery still treats 600 as a poll result, never raised;
  the 600 -> GPU-004 mapping applies only on raise paths.
  DeviceContext-launched kernel gateways (hip_gemv, hip_q4k_gemv,
  hip_attention_norms) surface upstream MAX/HIP errors before any
  shim rc exists; they hold no _raise_for_rc and are out of this
  mapping's reach - recorded, not silently skipped.
- Tests: aesir_engine/tests/test_hip_errors_a089.mojo, 5 cases in
  run_all (pin 594 -> 599): errors.hip_mapping_table (33 rows),
  errors.hip_fault_injection (one injection per mapped code, 33),
  errors.hip_fallback_and_success (unmapped 4242 -> INT-001,
  sentinel -1 -> GPU-002, hipSuccess handling, GPU-005 name),
  errors.hip_gateway_consistency (A-033 cross-table: init/sync
  agree; local VAL-003 rejections intact),
  errors.hip_real_paths (live-runtime fault injection: 1 EiB
  HipMemory.allocate and HipTransfer.host_allocate both raise
  MEM-003/MEM-001-coded errors carrying their site names).

## Suite evidence
- hidden_files/a089_run_all.log sha256
  8dcdc8befb29009be1601ed93924e361e5f18ad29a4fe64ac35dda6c2ef5fd04 (final post-review run; first run b76c0b27... also 596/1/2 with the 25-code table)
- Solo run on a quiet machine (load 0.17, no other suite/gate).
- Result: 596 passed / 1 failed / 2 skipped / 599 total = baseline
  591/1/2/594 + exactly the 5 new cases, all passing.
- Sole failure: gguf.tensor_directory_interface - pre-existing
  J-022 drift, tolerated, unchanged. Skips: the 2 pre-declared.
  Both named intermittents PASSED (incl.
  gpu.amd_hip_stream_async_round_trip).

## Post-review fixes (6-reviewer pass, 2026-11-13)
- Review found two more HIP shim consumers with the same defect:
  core/zero_copy.mojo (uncoded fallback) and
  core/weight_residency.mojo (blanket fallback, incl. the
  host-registration codes 712/713). Both rewired to
  raise_hip_error in this slice; absent/ownership branches
  untouched. Review also added 8 reachable codes (52, 201, 209,
  214, 215, 401, 709, 710 -> 33 mapped) and corrected 101
  InvalidDevice to VAL-003 (out-of-range ordinal, taxonomy
  wording). Contested mappings kept with rationale in the
  module header: 600 -> GPU-004 only on raise paths (poll path
  untouched), 801 -> GPU-002 per the A-033 precedent, 2 ->
  MEM-003 vs the A-033 kind-table MEM-002 split.

## Bugs / gaps
- No new bug found. Deliberate divergence, documented in the
  module header: HIP rc 2 maps to MEM-003 (exhausted memory)
  while the A-033 kind table keeps hip FAIL_ALLOC at MEM-002
  (null-return allocation failure) - different signals, both
  taxonomy-true; the gateway-consistency test pins the split.
