# Physical Turing MMA prerequisite — 2026-10-01

The optional locked public MMA probe physically passes 108 cases and all 50,688
outputs against independent integer equations with zero error. All 5,400 prefix/
tail guards and nine invalid-span rejections pass. Cases cover identity, signed
nonuniform matrices, multiple warps, warp tails and accumulation chains.

Pinned RTX2060 target uses PTX6.3, causing LLVM selection failure for m16n8k8.
An assembly diagnostic exposes the same version problem at CUDA JIT/ptxas.
Final code retains public mma, with an isolated matching DeviceFunction target
using +ptx65/sm_75. No installed dependency, driver, permissions, generated PTX
or production target is patched. Emitted PTX declares6.5/sm_75; offline assembly
of that exact PTX contains HMMA.1688.F32. This is not live SASS/counter proof.

Complete profiled/unprofiled output matches, but strict trace admission rejects
all retained capture attempts: embedded stdout exceeds the string bound; exec
retains Python image name; child image name truncates; the short-name child then
has initial API timestamps outside the exporter's reported analysis interval.
No complete admitted CUDA timeline or profiler speed score is claimed. These
failures do not change the accepted physical exact-output and instruction proof.
The initial default F32 formatter loss and all build/JIT failures remain too.

complete.json retains the independent gate; provenance.json records source,
binary/hardware identities and hashes of51 raw/build/profiler artifacts outside
Git. Six portable adversarial tests pass. Hosted CI compiles only. Native
production executable remains f3442a1e with the original active service.

The next slice is original packed-weight Q4_K/Q5_K/Q6_K MMA with bounded F16
conversion, every complete native output, independent real-weight dots and
paired equal-work primitive timings. Full-model quality, state/control recovery
and provider lead remain separate open gates. [Operation](../../NATIVE_TURING_MMA.md).
Exact pushed revision and CI receipt are separate publication evidence.
