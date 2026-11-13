# A-082 - HIP Q8_0 GEMV: verdicts

Slice A-082 (Wave 10, HIP/ROCm fair trial): Q8_0 dequant +
single-row GEMV executed on the Radeon 8060S (gfx1151) through
the A-010-A-012 HIP gate, as the HIP counterpart of A-056
(Vulkan Q8_0 GEMV). Evidence: hidden_files/a082_bench.log,
hidden_files/a082_probe.log, hidden_files/A082_LEDGER.md.

## Path of record

- Gateway: core/hip_gemv.mojo (HipGemv). Gate first: HipMemory
  runtime probe (A-011) + exactly one HIP device +
  AMDGate.get_device_properties(0) plausible with gfx_arch
  == gfx1151 (A-010). Any other device identity is refused
  before any launch; no host fallback exists in the path.
- Kernel: Mojo-native, launched through MAX
  DeviceContext(api="hip") (the A-029 proven road), compiled
  --target-accelerator gfx1151. One thread per output row,
  Float32 accumulation in sequential k order (A-075 law);
  fp16 scale decode + int8 byte extraction run in-kernel over
  the raw GGUF Q8_0 bytes (34-byte blocks), nothing is
  dequantized on the host. Only the kernel shapes A-029 proved
  are used (no shared memory / barriers / subgroup ops).
- Device-execution evidence (law 6): gate identity above
  (device name "AMD Radeon 8060S Graphics", gfx1151); the hip
  shim dispatch counter (aesir_hip_q8_gemv_dispatch_count)
  increments only after launch + readback + synchronize
  completed, and the suite asserts +2 for 2 dispatches;
  A-029 triangulation (arch-specific code object, hidden-
  device runs raise hipErrorNoDevice) covers the launch road.

## Parity verdicts (CPU oracle, raw bytes, sequential F32)

- Oracle parity, 6 shapes (1,32) (4,64) (16,288) (37,320)
  (64,1024) (13,4096): max_abs = 0.0 at EVERY shape - the HIP
  kernel is bit-exact against the sequential CPU oracle
  (identical dequant, identical k-order Float32 accumulation;
  filed bound was 1e-3, an accumulation-order bound carried
  over from A-056's tree-reduction Vulkan kernel).
- Engine cross-check (gemm_q8_0, dyadic K=1024 N=96): PASS
  within half an F16 ULP of the engine F16 output at every
  output (the engine rounding distance; comparator-artifact
  class bound, as A-056).
- Known value (scale 0.25, q = i-16, x = 1): -4 exact.
- Rejection (zero rows, cols=48, oversize operand, short
  activation list): PASS, all raised before device work.

## Bench (bench_hip_q8_gemv_a082.mojo, purpleraider)

Weight bytes read per GEMV = rows * (cols/32) * 34.

| shape | HIP per-call | HIP resident-loop | CPU sequential |
|---|---|---|---|
| 512x4096 | 16.93 ms (0.12 GiB/s) | 1.02 ms (2.03 GiB/s) | 1.65 ms (1.26 GiB/s) |
| 64x1024 | 13.41 ms | 0.71 ms (0.09 GiB/s) | 0.056 ms (1.17 GiB/s) |
| 37x320 | 13.22 ms | 0.66 ms (0.018 GiB/s) | 0.0098 ms (1.20 GiB/s) |

- Per-call q8_0_gemv creates a fresh DeviceContext: a flat
  ~13-16 ms floor at every shape. That is context-creation
  cost, not kernel cost - measured, not hidden.
- q8_0_gemv_repeated (one context, operands uploaded once,
  weight-resident loop of launch + readback + sync) removes
  it: at the large decode shape (512x4096) HIP reaches
  2.03 GiB/s vs the CPU oracle's 1.26 GiB/s. Small shapes
  stay latency-bound (~0.66-0.71 ms launch+sync+readback
  floor) and lose to the CPU oracle, which is microseconds
  at those sizes - filed honestly for the A-085 bake-off.
- Kernel-shape headroom (one thread per row, uncoalesced row
  reads) is real and deliberately unclaimed here: tiled /
  shared-memory / wavefront-reduction shapes were NOT probed
  by A-029 and are A-085 bake-off territory, not this slice.

## Verdict

A-082 acceptance met: CPU-oracle parity (bit-exact) +
device-execution evidence (gfx1151 gate identity + completed-
dispatch counter), fail-closed everywhere else.
