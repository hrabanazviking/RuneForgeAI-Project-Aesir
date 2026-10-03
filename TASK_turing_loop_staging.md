# SPD-01/02 — bounded runtime-group32-column staging experiment

Established2026-10-03 before code. Narrow16 experiment7e75738 passes all full
numeric/bit/guard gates but loses all56 original64 comparisons; retain32-column
width. Exact prior trace/narrow implementation CI remain separate pending checks.
Volmarr authorizes sequential scoped implementations/pushes.

Original shared-staged kernels unroll all eight packed32-column sections inside
each256-value block. Add an isolated optional native module with runtime loop of
exactly eight groups, retaining public MMA, padded32-column shared arrays and
chronological per-output accumulation/barriers. Runtime-group format helper is a
mechanical translation of owned packed_block_group equations: kind remains
compile-time12/13/14, group0..7 from loop, lane0..31; machine-width addressing,
Int32 bounded quant fields, identical Q4/Q5 scale*q and Q6 d*scale*q order. No
changes to quantization defaults/production. Fewer replicated instructions may
change register use or speed, while dynamic addressing/branches may cost more;
no cause, occupancy, register reduction or speed assumed without evidence.

Rows64/128,batch4/8/16/32,precision0 only; threads128/256 and source shared10560/
19008 atbatch32 unchanged. Every padded row/token shared cell initialized, same
stream/both barriers/all warps/half-weight conversions, no global workspace.
Leave all old core kernels/quantization bodies verbatim. Extend harness final
loop_rows=0 with exclusive cached/large/narrow flags; native collector explicit
rows64/128 before model/CUDA. Unique mode metadata columns32 admits complete
native/candidate/original64 F32-bit/signed-zero vectors and original840 rotated
samples. Legacy schema/defaults intact; no service dispatch.

Each config earns144 synthetic Q4/Q5/Q6 tails/12 span refusals,1658880 actual
outputs perowner/2100 independent Float64 original-weight dots/1622640 guards,
all fixed .002 scaled/.0002 RMS and original UInt32 bits. Full ten samples/three
actual calls per owner, no favorable subset, finite atomic ratios only after all
quality/hash gates. Keep every failure/CSV/source/binary/model/build/process hash;
pinned GGUF/NumPy remain test-only. No cross-capture12832 score.

Finishsm75/sm89/original/header/master/normal/check before serial rows64/128 GPU,
then CPU oracles. Portable metadata/bit/rotation/hash/interrupt/finite/exclusive
contracts and compile join existingCI steps. Verify unchanged authenticated active
normal prefill4. Document wins/rejection/manual/owners/ledger/TODO/roadmap/devlog,
push and verify exactCI; next select repeated primitive/actual-F32 gates if a
shape wins, otherwise retain originals and choose another measured design.
Production32/full-model/generation/replay/control/context/device/concurrency/
soak/refreshed-provider gates remain separate. Prior successful source quality
never implies a new kernel's complete-model acceptance.
