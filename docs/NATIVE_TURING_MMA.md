# Physical Turing MMA prerequisite

This optional probe exercises locked Mojo 1.0.0/MAX 26.5.0 public MMA on the
observed RTX 2060 Max-Q sm_75. It loads no weights and changes no inference
dispatch. Real packed-weight precision, full-model quality and speed gates
remain open. Compilation alone does not prove physical execution.

## Target compatibility and ownership

NVIDIA's m16n8k8 row/column fragment mapping owns the four F16 A, two F16 B and
four F32 accumulator/output values per lane. Every active warp lane calls the
same public operation. Inactive tails branch uniformly by warp. No software
substitution exists. core/turing_mma_probe.mojo owns checked output-span/count/
block admission and the optional target, called only by test_turing_mma.mojo.

Pinned stdlib RTX 2060 uses +ptx63,+sm_75. Its public MMA build failed LLVM
instruction selection. A diagnostic assembly experiment compiled but CUDA JIT
rejected it; installed ptxas rejected the emitted PTX 6.3 because this shape
needs6.5. Final code retains the public MMA API and constructs a DeviceFunction
with the matching RTX 2060 target layout and +ptx65,+sm_75. No installed library,
driver, dependency, permission, emitted PTX or production target is patched.
Internal _TargetType and MLIR target schema are pinned compatibility surfaces;
revisit them explicitly if the lock changes. All initial failures remain.

Actual borrowed length, nonnegative offset, tiles 1..64, steps1..16, cases 0..5
and block32/128 reject before function construction/enqueue. Subtraction bounds
the output span. Warp tails never touch inactive outputs. The type-checked
DeviceFunction interface owns launch and context lifetime.

## Reproduce the complete exact gate

Use a prepared frozen environment and physical sm_75 device. Choose new paths
in a private artifact directory outside Git. From the repository root:

```bash
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_mma.mojo \
  -o "$ARTIFACTS/turing-mma-probe"
timeout 60 "$ARTIFACTS/turing-mma-probe" > "$ARTIFACTS/complete.csv" 2>&1
python3 scripts/check_turing_mma.py "$ARTIFACTS/complete.csv" \
  --output "$ARTIFACTS/complete.json"
python3 scripts/test_check_turing_mma.py
```

The native probe checks every value against Float64 equations before PASS.
Actual F32 results export through Float64 text. The first default F32 formatter
rounded correct1.01953125 to1.0195312 and failed independent admission; preserve
that failure, do not loosen the budget. Independent stdlib integer numerator/256
equations import no native code and check all 50688 values. The108 ordered cases
cover identity/five signed nonuniform cases, tiles 1/3/7, blocks 32/128 and chains
1/3/7. Required totals include5400 guards and9 invalid metadata rejections.
Deliberately exact binary inputs/results have a predeclared zero-error budget;
this does not cover real F16 weight/activation conversion.

The checker requires complete ordered finite values, guards, backend/shape/count
metadata and final marker. Missing/trailing/duplicate/wrong records fail closed.
Input is regular UTF-8<=8MiB, opened nonblocking/no-follow. The SHA hashes the
admitted text snapshot without reopening a path. Exclusive JSON output retains
failure and exit1. Six portable adversarial tests cover evidence and special/
oversized files. Hosted CI runs those tests and compiles only, with no GPU claim.

## Instruction and owned trace evidence

Emitted kernel PTX declares6.5/sm_75 and invokes
mma.sync.aligned.m16n8k8.row.col.f32.f16.f16.f32. Installed ptxas accepts it;
offline disassembly of that exact emitted PTX contains HMMA.1688.F32. This is
offline instruction identity, not privileged counters or live SASS capture.
Owned Nsight captures preserve actual device activity and complete native output
equality, but none earns a fully admitted timeline in this slice.

Nsight2023.4.4.54 embeds captured stdout into SQLite StringIds. The first
full-CSV trace exceeded the analyzer's16384-character per-string limit and was
rejected. An exec-only redirection attempt retained the initial Python image
name in Nsight's process table and failed strict executable identity admission.
Final capture uses an owned launcher: open a new0600 output file with O_EXCL,
spawn the same native probe with stdout/stderr there and wait/reap it with a
timeout. The parent/profiler share an owned process group for failure cleanup.
The first child capture records a truncated15-character Linux process name and
fails identity admission against the longer filename. Use a short basename
(the final attempt uses mma-probe), verify its identical binary SHA and require
exact observed basename admission. That attempt passes identity, but strict
analysis rejects initial CUDA API timestamps outside the exporter's reported
analysis interval. All captures and failures are retained. Do not widen interval
admission or claim a complete validated CUDA timeline. Physical exact-output
execution and offline instruction identity remain the accepted evidence here.
All output remains independently validated; CUDA tracing is retained without
embedding large stdout. Keep the admission limit and raw SQLite unchanged.
The existing matching importer handles split Nsight packages. No installation,
live-service attachment or counter permission change is needed.

Preserve complete CSV/binary/source/build failures, PTX/cubin/SASS and profiler
artifacts outside Git. Publish only reviewed summaries/hashes. No timing here
proves a speed gain. Rebuild the production launcher after Mojo edits and check
its unchanged checksum and active readiness. See physical evidence for identities
and exact publication receipts for the pushed revision and CI.

## Authoritative interfaces

- [Pinned public MMA](https://github.com/modular/modular/blob/max/v26.5/max/mojo/max/gpu/compute/arch/mma_nvidia.mojo)
- [Pinned RTX2060 target](https://github.com/modular/modular/blob/max/v26.5/mojo/stdlib/std/gpu/host/info.mojo)
- [Pinned DeviceFunction](https://github.com/modular/modular/blob/max/v26.5/max/mojo/max/gpu/host/device_context.mojo)
- [Target-definition guide](https://github.com/modular/modular/blob/max/v26.5/mojo/stdlib/docs/adding-gpu-targets.md)
- [NVIDIA fragments and requirements](https://docs.nvidia.com/cuda/parallel-thread-execution/index.html#matrix-fragments-for-mma-m16n8k8)

The target follows the matching upstream factual layout, documented under
Apache2.0 with LLVM exceptions. AESIR owns equations, admission, test protocol
and independent checker; no external inference engine is involved.
