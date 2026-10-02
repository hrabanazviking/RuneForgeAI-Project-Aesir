# SPD-02 — physical Turing MMA feasibility prerequisite

Established2026-10-01. Volmarr authorizes repeated scoped slices and pushes.
Owned CUDA trace and SIMT matrix/tuning slices are published; every exercised
batch-four SIMT candidate loses, so native production remains f3442a1e. This
slice tests the locked Mojo1.0.0/MAX26.5.0 public mma API on actual sm_75.

## Scope and fixed acceptance

Public MAX26.5 source maps FP16 vectors of lengths4/2 with F32 accumulators4
onto llvm.nvvm.mma.m16n8k8.row.col.f32.f32. NVIDIA documents this F16 shape as
sm_75-capable; the newer16x8x16 shape needs sm_80. Use the supported public API
and authoritative fragment mapping, not a new guessed ABI or inline assembly.
Physically execute dynamic nonuniform/signed/identity matrices and accumulation
chains, multiple warps and warp-uniform tails. Every output and guard must match
independent CPU rational equations exactly for deliberately exact binary inputs.
Compile/SIMT output alone does not prove accelerated full-model support.

Use one owned CUDA context and bounded small output buffers. Validate actual
length, prefix/offset, tile/operation counts and warp-compatible block shape
before enqueue; unsupported metadata rejects before mutation. No Tensor-Core
performance-counter privilege, driver/dependency change or production service
attachment. Verify actual lowering/instruction identity when observable; keep any
counter/disassembly limitations explicit, without silent software substitution.

## Owned files and evidence

core/turing_mma_probe.mojo owns optional checked public MMA invocation/fragment
mapping, reached only by tests/test_turing_mma.mojo. This is a feasibility probe,
not production packed-weight projection. scripts/check_turing_mma.py owns strict
complete output/count/guard admission and independent stdlib rational checks;
portable adversarial tests prove rejection. Update INTERFACE/README_AI/manual,
public evidence, CI compile and portable checks, TODO/roadmap/ledger/DEVLOG.

Retain raw complete outputs, failed attempts, tool/source/binary identities and
hardware metadata outside Git, publish hashes/summaries. Check exact lowering in
matching public source and actual device execution; no broad Tensor-Core, F16
model quality or speed claim follows from this prerequisite. Rebuild the launcher
after Mojo edits and verify its unchanged production checksum/active readiness.
Publish and verify exact CI. Once the physical gate passes, next scope a packed
MMA projection candidate with original weight bytes, bounded workspaces and
predeclared precision/full-model quality gates. Keep strict references available.
