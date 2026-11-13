# A-085 — The bake-off: HIP vs Vulkan on gfx1151

Slice A-085 (Wave 10 close). HIP vs Vulkan on identical kernels
and fixtures: speed, bandwidth, stability, code health.
Host: purpleraider, AMD Radeon 8060S (gfx1151), RADV STRIX_HALO
for Vulkan; MAX DeviceContext(api="hip") for HIP. Device
identity asserted on both roads (Vulkan vendor 0x1002 / RADV,
llvmpipe refused; HIP gate gfx_arch == gfx1151, dispatch
counters increment only after synchronized device completion —
law 6 evidence on both sides).

## VERDICT

**Vulkan is the PRIMARY GPU road. HIP is PARKED** (probe-only,
never silently dropped) with the re-open criteria below.
A-086 integrates Vulkan as the registry's first-class backend;
HIP remains probe-only per the roadmap.

Scope note: this verdict chooses between the two GPU roads
only. It does not disturb A-081's Part III gate verdict, under
which the CPU path remains primary for 8B-class decode today;
A-086's "first-class GPU backend" is the GPU-side registry
question, not a decode-primary claim.

## Head-to-head: Q4_K GEMV, identical fixtures

Same kernel (Q4_K GEMV, raw GGUF bytes, in-kernel dequant),
same deterministic LCG fixture family, same shapes, same
median-of-reps discipline (dispatches=3, 5 at the Vulkan large
shape). Two independent paired runs are filed:

- Fresh paired run 2026-11-13 ~08:06 EST by the previous
  team-15 lead (logs hidden_files/a085_hip_q4k_fresh.log and
  hidden_files/a085_vulkan_q4k_fresh.log — shape lines only;
  the uptime lines in those logs record load averages
  0.28/1.42/1.59 (Vulkan) and 0.35/1.36/1.56 (HIP), so the
  window was quieting, not idle).
- Verify paired run 2026-11-13 ~08:29 EST by this lead, built
  and run in the seat tree at banked main de415271 (A-083
  banked; the team-15 branch predates A-083, so the HIP bench
  and its shim symbols exist only there) with full provenance
  headers (logs hidden_files/a085_hip_q4k_verify.log and
  hidden_files/a085_vulkan_q4k_verify.log, BUILD_EXIT=0,
  RUN_EXIT=0, both PASS).

Fixture identity, stated precisely: on EACH road, both new
runs reproduce that road's filed bench errors bit-identically
(Vulkan: the A-057 filed errors; HIP: the A-083 filed errors),
proving the same deterministic fixture and kernel per road.
The two roads' errors are NOT identical to each other — they
differ, most at small shapes (1x256: HIP 0.07287598 vs Vulkan
0.0014190674), because the kernels accumulate/round
differently (HIP keeps f32 throughout and never rounds
weights to f16; the Vulkan kernel reduces by tree). Both
roads are inside the filed parity band at every shape (see
Correctness), so the difference is not a correctness signal.

Per-call end-to-end medians (the decode-relevant number):

| shape (rows x K) | Vulkan fresh | HIP fresh | Vulkan faster |
|---|---|---|---|
| 1 x 256 | 0.237 ms | 5.20 ms | 21.9x |
| 7 x 512 | 0.175 ms | 1.76 ms | 10.0x |
| 64 x 1024 | 0.382 ms | 2.89 ms | 7.6x |
| 33 x 2048 | 0.429 ms | 3.69 ms | 8.6x |
| large | 0.454 ms (4096x4096) | 6.92 ms (1024x4096) | see bandwidth |

The verify run agrees in kind (same ordering, same scale):
Vulkan 0.208 / 0.173 / 0.547 / 0.448 / 0.507 ms vs HIP
5.399 / 1.841 / 3.079 / 3.617 / 7.699 ms at the same shapes
(ratios 26.0x / 10.7x / 5.6x / 8.1x). Filed A-057 / A-083
medians also agree in kind: HIP filed 2.01–7.14 ms; Vulkan
filed 0.19–0.42 ms at four shapes with a 2.99 ms outlier at
1x256 measured under load 2.63/2.93/2.86.

Bandwidth at the large shape (fresh run): Vulkan moves
9.44 MB of Q4_K weights in 0.454 ms = ~20.8 GB/s effective.
HIP per-call moves 2.36 MB in 6.92 ms = ~0.34 GB/s — the gap
is context setup, not silicon (see timing honesty). Verify
run: ~18.6 GB/s vs ~0.31 GB/s, same conclusion.

Correctness first (both PASS, filed band): Q4_K parity judged
at the f16-rounding band |err| <= 0.02*sqrt(K) + 0.02*|want|
(the A-083 ledger filing; the |want| term only widens the
band, so the floor 0.02*sqrt(K) is the strict check). Worst
fresh max_abs: HIP 0.8351822 at K=4096 vs band floor 1.28;
Vulkan 0.82373047 at K=4096 vs the same floor. Both roads
inside the band at every shape.

## Q8_0 GEMV (filed A-056 vs A-082)

- Parity: HIP bit-exact (max_abs 0.0, sequential-order kernel);
  Vulkan worst 9.83e-05 against its filed 1e-3 bound (tree
  reduction). Both PASS; HIP's bit-exactness is real but buys
  nothing the filed band requires.
- Timing honesty (A-082's own filing): HIP per-call carries a
  flat ~13–17 ms fresh-DeviceContext floor at every shape
  (filed per-call 16.93 / 13.41 / 13.22 ms); its resident loop
  (one context, weights resident, via the separate
  q8_0_gemv_repeated contract) reaches 1.02 ms / 2.03 GiB/s
  at 512x4096 vs the CPU sequential path's 1.65 ms /
  1.26 GiB/s at the same shape. No resident-loop Q4_K HIP
  numbers exist — A-083 is per-call only, with ~2–7 ms of
  per-call context setup by its own ledger. Vulkan's shared
  persistent context (A-013/A-014) has no such floor: its
  per-call numbers ARE its resident numbers. A decode loop
  pays per-call cost per token — the floor is decisive.

## Coverage (the bake-off is not two kernels)

- Vulkan: GEMV for Q8_0/Q4_K/Q6_K/Q5_K/IQ (A-056..A-059),
  RMSNorm+RoPE (A-060), elementwise+softmax (A-061), sampling
  (A-063), weight residency (A-064), decode attention
  (A-062), full layer (A-065), decode loop with token-exact
  greedy parity (A-066), real-model decode (A-067), prefill
  GEMM 185.5 GFLOPS at 128 tokens (A-068), chunked prefill
  (A-069), async (A-071), batching (A-072). Manifest
  kernel_count 13 -> 19 at A-068.
- HIP: Q8_0 GEMV (A-082) + Q4_K GEMV (A-083) only. No norm,
  RoPE, attention, layer, prefill, or other quants. Both HIP
  kernels are one-thread-per-row naive — honestly filed as
  untuned by their own slices.

## Stability

- Vulkan: 1-hour-class soak (A-077: 4,590 steps in 3,600 s,
  0 errors, per the A-081 gate filing), GPU fuzz with 0 real
  divergences (A-078), device-lost recovery (A-079),
  equivalence gate (A-080). Buffer accounting exact in every
  no-leak case.
- HIP: no soak, no fuzz, no recovery evidence. Two filed
  defects weigh openly: (1) every buffer-bearing MAX
  DeviceContext retains exactly 8 MiB of GTT until process
  exit (A-083 probe: 120 calls, never plateauing) — per-call
  context creation leaks by construction; (2) bench logs end
  with SharedSignalPool leak warnings (5,874 signals in the
  A-082 bench; 1,335 in the A-083 bench, reproduced in this
  slice's verify run). Neither is an A-083 operand leak; both
  are HIP-road lifecycle costs Vulkan does not carry.

## Code health

- Vulkan: GLSL->SPIR-V via the A-055 pipeline, manifest-
  registered, shared context/queue/buffer slots, one dispatch
  helper family. Cost: C shim size; benefit: every new op is
  a shader + a thin dispatch.
- HIP: Mojo-native kernels via MAX DeviceContext — nicer
  authoring language, but the runtime owns the lifecycle:
  ~2–17 ms context creation (shape/quant dependent), the
  8 MiB/context retention, and signal-pool warnings are all
  upstream-runtime behaviour the project cannot fix in its
  own code today.

## HIP re-open criteria (ALL required, then a fresh bake-off)

1. A persistent-context HIP launcher exists (no per-call
   DeviceContext) with per-call overhead < 0.5 ms median at
   64x1024 Q4_K on this machine, measured as in this doc.
2. The 8 MiB/context GTT retention is capped or released
   (pool knob or toolchain fix) and the no-leak invariant is
   re-filed against the new behaviour.
3. HIP reaches kernel coverage of at least the decode set
   (one K-quant GEMV + RMSNorm + attention) so a decode loop,
   not a single kernel, can be timed.
4. A HIP soak + fuzz pass at A-077/A-078 standard with
   0 real divergences.
Until then HIP stays probe-only: A-087..A-090 proceed as
roadmap-filed (reproducibility, zero-copy measurement, error
semantics, soak-or-verdict) and may supply re-open evidence;
A-084 (HIP attention + norms) is itself a step toward
criterion 3.

## Bugs

None discovered in engine code in scope. The fresh HIP bench
first failed to link against team-15's A-082-era hip shim
(missing A-083 dispatch symbols) — a staging error in this
slice's runner, fixed by staging the seat-tree shims; the
filed HIP numbers above are from the corrected runs. This
lead's verify runs were built in the seat tree at de415271
for the same reason (the team-15 branch predates A-083).
