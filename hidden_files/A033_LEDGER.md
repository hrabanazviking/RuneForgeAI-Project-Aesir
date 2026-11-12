# A-033 Ledger — Structured errors everywhere (team-01)

Roadmap: "Every backend failure path maps to the repo ERROR_TAXONOMY.
Acceptance: fault-injection tests per backend produce taxonomy-coded errors."
Base: c9f0047ecd117d623bf72d22d38421ae853532eb (31 of 216 banked)

## What was built
- NEW aesir_engine/core/structured_errors.mojo: single mapping authority.
  backend x failure-kind -> taxonomy code/name/severity; StructuredError
  value with render() = "CODE NAME [backend=.. op=.. severity=..] detail";
  raise/injection entry points; translate_backend_error (already-coded
  errors keep their code, bare errors wrap as INT-002); coded_error_text
  helper used to prefix real raise sites without changing their text.
- Mapping (kind -> code): unavailable GPU-002 (cpu INT-002); init hip
  GPU-012 / cuda+vulkan+npu GPU-001 / cpu INT-004; alloc MEM-002 device /
  MEM-001 cpu-host; invalid+shape VAL-003; launch GPU-003 (cpu INF-001);
  sync+transfer GPU-004 (cpu INF-008); unsupported GPU-002 accelerators /
  MDL-010 cpu; internal INT-001.
- Real paths wired (code prefixed, original message text preserved so all
  pre-existing substring tests pass unchanged): amd_gate (8 sites),
  hip_memory (_raise_for_rc + alloc sites), hip_transfer (_raise_for_rc,
  host alloc, stream/event), vulkan_buffers (_raise_for_rc + alloc/map/
  vec_add/align), cuda_gate (9), metal_gate (6), intel_gate (8), max_gate
  (3), compute gemm_f16_npu + gemm_f16_gpu/rmsnorm_gpu entries,
  backend_registry unknown-runtime, error_guard logit sanitizer.
  Vulkan context already carried taxonomy codes from A-013; A-033 tests
  assert its alloc/absent codes agree with the central table.
- Tests: aesir_engine/tests/test_structured_errors.mojo, 5 cases in
  run_all (pin 362 -> 367): errors.structured_mapping_table (21 rows),
  errors.structured_fault_injection (5 backends, 11 injections),
  errors.structured_real_paths (6 real coded failures), 
  errors.structured_translation, errors.structured_vulkan_cpu_consistency.

## Suite evidence
- hidden_files/a033_run_all.log sha256 d6dd23a0266fa4fc19f342afea13b2a5dc0779ae4541fa954d1b831cd0513a24
- Seat-gate shape: 6 shims staged incl. libaesir_aff, target gfx1151.
- Result: 364 passed / 1 failed / 2 skipped / 367 total = baseline
  359/1/2/362 + exactly the 5 new cases, all passing.
- Sole failure: gguf.tensor_directory_interface — pre-existing J-022
  drift, tolerated, unchanged. Skips: the 2 pre-declared.
- No rotating flake appeared in this run (team-09 suite ran concurrently).

## Bugs / gaps
- No new bug found in wired paths. Taxonomy gap recorded: ERROR_TAXONOMY
  has no dedicated "execution not implemented" code; A-033 maps it to
  GPU-002 (no physical execution path present) following the A-013 reuse
  precedent, cpu-unsupported to MDL-010. A dedicated code is a natural
  A-089 (extends A-033) item — recorded in CAMPAIGN_STATE.md.
- CPU compute.mojo internal shape/storage raises (many, in non-backend
  kernels) remain bare by design scope: they are not backend failure
  paths; the CPU backend kinds are covered via the central table +
  fault injection + error_guard wiring.
