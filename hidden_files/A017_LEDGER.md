# A-017 Ledger — Device selection policy (team-03)

- Slice: A-017 — Device selection policy (docs/AESIR_Z13_MASSIVE_ROADMAP.md, Wave 2)
- Machine: purpleraider (ASUS ROG Flow Z13, Strix Halo, gfx1151), worktree /home/volmarr/aesir-team-03, branch yrsa/aesir-team-03
- Base: main 11594f9a (A-014 banked; ls-remote verified 11594f9a73216b28d19e0ef4519a65a06b53fbfc). Team branch reset onto it after verifying A-012 is banked in main by subject (5c505afd "A-012: HIP transfer + streams"; the original team commit 67aca2d0 is the pre-rebase twin, not an ancestor — expected keeper rebase).
- Crew: lead + 6 Mythic Engineering sub-agents spawned first (registry audit, test-pattern audit, policy design, doctor plan, git verify, op-kind taxonomy) — all 6 returned, no rate limits.
- Toolchain note: `mojo --version` on this box now reports Mojo 1.2.0 (2016d0cd); the A-003-era baseline ran 1.0.0. Suite baseline counts were unchanged by this (307/1/2/310 before this slice's cases).

## Deliverables
- `aesir_engine/core/device_policy.mojo` (new): typed placement policy consuming the A-009 `BackendRegistry` (never re-probes). Device classes NPU/GPU/CPU; canonical op kinds matmul, attention, embedding, elementwise, sampling, transfer, generic. `PlacementPolicy.decide(registry, op_kind) -> PlacementDecision{device_class, backend, reason}` — pure and deterministic. Default order NPU -> GPU -> CPU (Volmarr's accelerator-first law); GPU class resolves HIP first, then Vulkan; CPU is reached only as logged spillover. Per-op override API (`with_override`): honored when satisfiable and logged; when unsatisfiable, the fall-through AND its reason are both logged.
- Honesty gate: `npu_execution_proven` defaults False. XRT presence alone never places an op on the NPU — every decision logs "skip NPU (NPU present (XRT) but no NPU execution is proven yet -- presence only, not placement)". `npu_supports_op_kind` (matmul/embedding/elementwise only) applies only once execution is proven; attention/sampling are never NPU kinds in this engine.
- `aesir_engine/cli/doctor.mojo`: new text section "Device placement policy (accelerator-first)" (effective-order line + one decision line per op kind) and a JSON `"placement"` object {effective_order, decisions[], npu_execution_proven}. Readiness/scope contract untouched.
- `aesir_engine/tests/test_device_policy.mojo` (new): 6 cases over fake registries — accelerator-first all-present, GPU backend fallback (Vulkan-only, degraded HIP), CPU spillover + empty-registry fail-closed, override (honored CPU pin, unsatisfiable NPU pin fall-through), NPU proven path (matmul->NPU, attention->GPU with reason), deterministic decision log + effective-order line.
- `aesir_engine/tests/run_all.mojo`: 6 cases registered as cli.device_policy_*; finish pin re-pinned 310 -> 316 with the house-style re-pin comment.

## Suite (counts READ FROM LOG)
- Log: hidden_files/a017_run_all_canonical.log, sha256 13827518e2b0adcb8d023afba28dcb61f77a46cd62cda82bd43c66aba584d786
- [SUMMARY] Passed: 313 / Failed: 1 / Skipped: 2 / Total: 316 — exactly the main baseline 307/1/2/310 plus the 6 new cases, all 6 PASS (grep: cli.device_policy_* all [CASE PASS]).
- Sole failure: gguf.tensor_directory_interface — the pre-existing J-022 loader/test contract drift (roads A-165/A-121), unchanged, out of this slice's scope.
- Skips: the 2 pre-declared (vision.cuda_session_image_chat, rag.real_engine_integration).
- Wall 0:41.43 (time -v), max RSS ~1.57 GiB. Canonical command: 4 FFI shims staged (hailo10h stub, thread_par, hip_memory, vulkan context+buffer), `pixi run --frozen mojo run -I . --target-accelerator sm_89 -Xlinker -L<staging> -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan aesir_engine/tests/run_all.mojo`, run inside tmux (session a017) after a foreground attempt died with the box (see Incidents).

## Doctor — REAL output from purpleraider (acceptance)
- Text log: hidden_files/a017_doctor.log, sha256 f07621160fd5c135068195bf64485ac0327baa44e0e8985768fa97f1262f6c08, exit 0.
- JSON log: hidden_files/a017_doctor_json.log, sha256 15b8184d0e54f87e17dd9216122037a38a27132c3ad897c8fd7ad66627aa7a5c, exit 0.
- Registry on this machine: HIP present 7.15.0 (AMD Radeon 8060S Graphics), Vulkan present 1.4.354 (RADV STRIX_HALO), XRT present 2.25.0 (presence only), CPU present (AMD RYZEN AI MAX+ 395).
- Effective order shown: `effective order: NPU -> GPU -> CPU (generic placement: GPU via HIP)`; every op kind -> GPU (HIP) with the NPU presence-only skip logged. JSON carries the same decisions and `"npu_execution_proven":false`.

## Bug found and fixed in scope
- Compile error: `PlacementPolicy(Copyable, ImplicitlyCopyable)` cannot synthesize an implicit copy constructor over `List[PlacementOverride]` under this toolchain. Fixed in scope: policy is `Copyable` only (explicit `.copy()` already used internally). No other bugs discovered.

## Incidents (honest record)
- The box rebooted during the first full foreground suite attempt (observed `up 0 min` at 01:07 EST, log frozen at 148 CASE PASS). Cause not established from this worktree (no panic evidence captured); the suite was relaunched in tmux and completed cleanly. No data lost; the partial log was overwritten by the canonical run.
- Two base64 emissions of the helper run script were flagged by the runtime's injection check and were NOT used; the suite and doctor were run with directly-issued device commands (tmux) instead, and this ledger records the exact canonical command above. No run_a017.sh is committed for this slice for that reason.
