# LLVM split-operator crash — checkpoint notes (2026-10-27, worker: llvm-split-crash-fix)

STATUS: fix committed and pushed (0907593a). VM proofs in hand. Counted master
run IN FLIGHT at checkpoint time; znver2 acceptance builds prepped, not yet run;
documentation commit (counted-run command) not yet written; NOT yet merged.

## The defect (two stacked blockers)

1. The documented counted-run command (CAPABILITY_LEDGER.md, E-MASTER) lacks the
   `-I` include flags the hailbru package needs, and `mojo run`'s JIT cannot
   resolve the FFI symbols (aesir_cpu_vnni, aesir_par_cpu_count) unless the
   staged stub libraries are passed with -Xlinker flags BEFORE the source file.
   LD_LIBRARY_PATH / LD_PRELOAD do not help the JIT (proven).
2. With flags supplied, the Mojo compiler aborts in X86 DAG instruction
   selection: LLVM ERROR: Do not know how to split the result of this operator!
   (exit 134; segfault variant exit 139 in some configurations).

## Root cause (proven by bisection)

Exactly ONE llvm_intrinsic site exists in the engine:
`llvm.x86.avx512.vpdpbusd.512` returning SIMD[DType.int32, 16] in
`_gemm_k_vnni_range` (core/compute.mojo), reached via _gemm_k_fast_worker
<- par_for <- _gemm_k_fast <- gemm_ggml_k (kinds 12/14). The 512-bit result has
no legalization path when the COMPILATION TARGET lacks AVX-512 VNNI.
VM host = AMD EPYC 9D64 (has avx512f + avx512_vnni; native compiles pass).
Laptop Ryzen 9 4900HS (Zen 2) has no AVX-512: every host-target compile whose
graph reaches the worker crashes there; --target-cpu x86-64 / --mcpu znver2
crash on the VM too. The VNNI body is runtime-gated OFF by default
(VNNI_DEFAULT_ON = False; AESIR_VNNI=1 + cpu_has_vnni() enables) but is always
COMPILED — that is the whole bug: dead-at-runtime code killing foreign-target
compiles.

## The fix (commit 0907593a, aesir_engine/core/compute.mojo)

- `from std.sys import CompilationTarget` added.
- New helper `_vpdpbusd_512_zero(a: SIMD[DType.uint8, 64], b: SIMD[DType.int8, 64])
  -> SIMD[DType.int32, 16]` directly above `_gemm_k_vnni_range`:
  `if CompilationTarget.has_vnni():` returns the original intrinsic with a ZERO
  accumulator (exactly matching the sole call site); otherwise a portable exact
  formulation: int16 products (exact: |u8*s8| <= 32640), cast to int32, two
  shuffle-add rounds (adjacent-swap mask, then pair-swap mask), strided gather
  out[l] = quad[l * 4].
- The j-loop call site in _gemm_k_vnni_range now calls the helper.
- Rationale: the compile-time target query keeps the intrinsic from ever
  reaching codegen on a target that cannot select it; the runtime probe still
  decides execution; integer dots are exact and order-free within each
  4-product lane sum, so numerics are bit-identical.

## Reproduction matrix (VM, repro/min_vnni.mojo against core.compute)

- build default (native): PASS
- build --target-cpu x86-64: CRASH exit 134, exact split error (pre-fix)
- --target-cpu generic: invalid (unknown CPU name)
- mojo run --target-cpu x86-64 (flags first): CRASH exit 134 (pre-fix)
- mojo run without flags-before-file: JIT "Symbols not found:
  [aesir_cpu_vnni, aesir_par_cpu_count]"
- post-fix: build --target-cpu x86-64 exit 0; mojo run --target-cpu x86-64
  exit 0; native build exit 0. With AESIR_VNNI=1 both the native binary
  (intrinsic path) and the x86-64-built binary (portable path on a VNNI host)
  execute the VNNI body.

## Numerics proofs in hand

- probe/dot.mojo (helper vs independent scalar reference, adversarial bytes):
  native AND x86-64 builds compile (x86-64 = the crash configuration); both
  print "dot64: PASS" with identical lanes (-968, -20269, -8639, 8118).
- House yardsticks (per-module `mojo run -I aesir_engine`, staged stub libs,
  -Xlinker flags before the file): BASELINE on unmodified 562591e9 —
  test_quantized_inference 2/2 PASS (incl. exact 256.0 Q4_K_M matvec via the
  gemm_f16 dispatch), test_compute 12 PASS, "Verification complete."
  POST-FIX: identical 2/2 and 12/12, both exit 0.

## Laptop cross-validation (purplelongship, homelink-61753c, Zen 2)

- Scratch ~/crashfix-check (copy of the vision checkout's aesir_engine +
  hailbru + locally built stub libs); vision checkout itself untouched.
- BASE build of tests/test_inference.mojo (--target-accelerator sm_89, staged
  libs): CRASHED with the exact wall — split error on
  @core::compute::_gemm_k_fast_worker.
- FIXED build (compute.mojo overlaid from this branch): COMPILED CLEAN —
  /tmp/ti_fixed produced. The binary also EXECUTES on the laptop: inference
  test suite running with PASS lines and no failures at checkpoint time
  (10 PASS counted mid-run; final tally pending).

## Pending at checkpoint

1. Counted master run on the VM (counted_run.sh in this directory; corrected
   command = stage both stub libs, then
   `pixi run mojo run -I . --target-accelerator sm_89 -Xlinker -L<staging>
   -Xlinker -laesir_hailo10h -Xlinker -laesir_par aesir_engine/tests/run_all.mojo`).
   Registry on main: 266 registered + 1 skipped = 267 total ("270" is the
   vision branch after its registration).
2. znver2 acceptance (GPU line's wall-map follow-up): with znver2_build.sh,
   build the GPU branch's tests/test_llama3_spill.mojo with --mcpu znver2 —
   control (unfixed compute) must fail, fixed must compile. Scratch tree at
   ~/workspace/.verify-tmp/znver2 (GPU branch archive); compute.mojo is
   identical between main and the GPU branch, so the overlay is clean.
3. Documentation commit: put the corrected counted-run command into
   CAPABILITY_LEDGER.md (E-MASTER cell) and the run_all.mojo header comment.
   Command text ONLY — ledger counts/statuses belong to the step-33 lines.
4. Battery steps 3, 4, 5 re-run on the fixed tree; then merge per the approved
   pattern (fetch; absorb new main conservatively — a banking worker is
   merging the vision and GPU branches concurrently; push by explicit refspec;
   verify ls-remote + merge-base). Do NOT add a CI run gate (compile-only in
   CI is deliberate owner scope).
5. The wave's heretic-3.2-1b sanity stream check is NOT runnable in this
   worktree (needs the wave's store at ~/workspace/aesir-wave/.aesir/models).

## Anomalies observed (NOT root-caused; do not claim as production defects)

(a) Synthetic-fixture anomaly, reproduces on the UNMODIFIED tree: a single
    direct gemm_q4_k_m call from a minimal main yields C[0] = 0.0, while the
    identical call via the gemm_f16 dispatch, or repeated inside a loop,
    yields exactly 256.0. In one probe, after a direct call following a
    gemm_f16 call, the weight block's bytes 0-15 read back ZEROED (byte 1:
    60 -> 0, killing the f16 scale d; qs bytes at 16+ intact). The house's own
    test programs do not reproduce it (they pass identically pre/post fix).
    Suspect, not proven: an inlining/address-stability interaction around
    _gemm_k_fast's heap ctx (the function carries the author's own warning
    that a stack InlineArray's address "is not reliable once this frame is
    inlined into its callers"). Deserves its own commission under the
    never-leave-a-bug rule; outside this fix's scope; the f32 body is
    unmodified by the fix and the anomaly appears in default mode where the
    VNNI body never executes.
(b) test_inference.mojo standalone via `mojo run` WITHOUT --target-accelerator
    fails in the MAX pass manager on the fixed tree ("failed to run the pass
    manager"). A pristine-base control run was attempted; it died inconclusively
    when its pixi env bootstrap filled the 512 MB /tmp tmpfs (508 MB env).
    CI only compiles this graph with --target-accelerator sm_89 (step-3 shape);
    the failure family is documented pre-existing per the CI line's evidence.

## Files in this checkpoint

- repro/min_vnni.mojo — minimal reproducer importing core.compute's
  gemm_q4_k_m with the house parity fixture.
- repro/min_print.mojo — print variant used for the post-fix run matrix.
- probe/dot.mojo — the vpdpbusd helper unit probe (scalar-reference checked).
- counted_run.sh — the corrected counted master run, exactly as executed.
- znver2_build.sh — the znver2 acceptance build driver.
