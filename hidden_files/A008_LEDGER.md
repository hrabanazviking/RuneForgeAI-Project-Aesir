# A-008 Ledger — Unified-memory semantics probe

Slice: A-008 (Wave 1, team-08). Machine: purpleraider (ASUS ROG Flow Z13,
AMD Ryzen AI Max / Strix Halo, Radeon 8060S gfx1151, 128 GB unified LPDDR5X).
All numbers below come from on-device run logs listed at the end — nothing
is estimated. Buffer size for every bandwidth row: 256 MiB (67,108,864
floats / uint32s). GPU timings are hipEvent (HIP) or host wall around
submit+waitIdle (Vulkan, submission overhead negligible at 256 MiB);
CPU timings are CLOCK_MONOTONIC wall. GPU kernel timings are best-of-5.

## Device identity (execution evidence)

- HIP: `AMD Radeon 8060S Graphics`, gcnArch `gfx1151`, totalMem
  65,227,026,432 B (== hipMemGetInfo total; matches A-011), 
  concurrentManagedAccess=1, pageableMemoryAccess=0, canMapHostMemory=1.
  Kernels compiled at runtime via HIPRTC for gfx1151 (hipcc absent;
  gcc host + libamdhip64, the A-011 C-shim pattern) and really launched:
  every GPU row is checksum-verified on the host (VERIFY ... OK lines).
- Vulkan: `AMD Radeon 8060S Graphics (RADV STRIX_HALO)`, Vulkan 1.4.354,
  selected explicitly; llvmpipe was enumerated and refused by the probe.

## HIP numbers (final warm series finalA.log; ranges span finalA-C + run4-7)

| Path | Measured | Range across warm runs |
|---|---|---|
| Managed: CPU first-touch write | 34.70 GB/s | 21-35 GB/s |
| Managed: CPU warm write | 34.36 GB/s | 24-35 GB/s |
| Managed: CPU read of CPU-written | 35.56 GB/s | 21-37 GB/s |
| Managed: CPU read of GPU-written | 36.68 GB/s | 17-37 GB/s |
| Managed: GPU read of CPU-written (kernel) | 222.91 GB/s | 203-224 GB/s |
| Managed: GPU fill (kernel write) | 231.58 GB/s | 196-232 GB/s |
| Device buffer: GPU fill (control) | 231.52 GB/s | 195-232 GB/s |
| Device: hipMemcpy H2D (pageable host) | 82.41 GB/s | 21-83 GB/s |
| Device: hipMemcpy D2H (pageable host) | 69.49 GB/s | 20-69 GB/s |
| Pinned: hipMemcpy H2D | 83.01 GB/s | 27-84 GB/s |
| Pinned: GPU read, zero-copy (no copy call) | 190.96 GB/s | 157-191 GB/s |
| Pinned: GPU fill, zero-copy (CPU sees data) | 202.29 GB/s | 139-202 GB/s |

CPU rows are single-threaded and contention-sensitive (9 teams share the
machine); GPU kernel rows are stable. CPU read symmetry was confirmed by
reread_probe: 4 consecutive CPU reads of GPU-written managed memory at
36.0-36.9 GB/s, identical after a CPU rewrite (35.61 GB/s).

## Page-fault / first-touch cost (managed)

- CPU first-touch write == warm write (34.70 vs 34.36 GB/s): no measurable
  CPU-side first-touch penalty at 256 MiB.
- GPU first-touch sum over a fresh 256 MiB managed allocation vs steady
  state: overhead +0.6 ms over 65,536 4-KiB pages = 0.009 us/page
  (finalA). Across all 10 runs the delta ranged -3.8..+3.3 ms, i.e. below
  run-to-run noise. Bound: < 0.05 us/page. On this APU managed memory
  does not exhibit a classic per-page fault cliff.

## Vulkan numbers (host-coherent, no copy calls anywhere)

RADV exposes two usable coherent flavours; they behave very differently.

| Memory type | CPU write | GPU sum (read) | GPU fill | CPU read of GPU-written |
|---|---|---|---|---|
| HOST_CACHED coherent (flags 0xe, heap 0) | 12.77-13.11 GB/s | 136.6-139.5 GB/s | 124.9-127.3 GB/s | 12.77-13.00 GB/s |
| DEVICE_LOCAL coherent (idx 9, flags 0xc7 incl. DEVICE_UNCACHED_AMD, heap 1) | 12.65-12.94 GB/s | 200.9-201.2 GB/s | 98.5-122.8 GB/s | 0.11 GB/s |

All Vulkan rows byte-exact (sum totals match, fill pattern bad=0).
The 0xc7 type gives the fastest GPU read but CPU reads run ~300x slower
than the cached type — it is device-uncached memory mapped into the CPU.

## Zero-copy design rule for Part I Wave 3 (written from the numbers above)

1. DEFAULT: allocate shared CPU<->GPU buffers as HIP managed memory.
   The GPU reads and writes it at full DRAM speed (203-232 GB/s, the
   same as device buffers), the CPU reads/writes it at full speed in
   both directions (~35 GB/s single-thread), and first-touch costs are
   unmeasurable (< 0.05 us/page). No copy call belongs in this path.
2. NEVER stage through hipMemcpy on this APU. The copy path measured
   20-83 GB/s — always slower and far more variable than direct kernel
   access (157-232 GB/s) — and it burns a second full pass over the
   same DRAM. Explicit copies are a discrete-GPU habit; here they are
   pure loss.
3. Host-pinned memory is a valid zero-copy path (GPU read 191 GB/s,
   GPU fill 202 GB/s, CPU-visible immediately) but beats managed on
   nothing; reserve it for external APIs that require pinned buffers.
4. Vulkan shared buffers MUST use the HOST_CACHED host-coherent memory
   type (flags 0xe). NEVER use the DEVICE_LOCAL coherent type (flags
   0xc7, DEVICE_UNCACHED_AMD) for anything the CPU reads: CPU reads
   measured 0.11 GB/s there vs 13 GB/s on the cached type. The 0xc7
   type is admissible only for GPU-only traffic with rare CPU writes.
5. The CPU is the slow side of every shared buffer (~35 GB/s per
   thread vs ~230 GB/s GPU). CPU-side producers filling shared buffers
   must be multithreaded; a single-threaded fill caps the pipeline.

## Method notes / bugs found and fixed inside this slice

- Cold-start effect: the first three probe runs on the idle machine
  showed GPU kernel bandwidth of only 30-108 GB/s; once warm, runs are
  stable at 140-232 GB/s. Benchmarks on this machine MUST warm up
  before recording (idle-clock ramp and/or co-tenant warm-up; exact
  cause not isolated — recorded as observed variance, not a claim).
- Measurement bug (mine, fixed): the first CPU-read loop used a single
  FP accumulator; its dependency chain capped reads at 3.06 GB/s and
  briefly masqueraded as a GPU-written-memory penalty. Fixed with 8
  independent accumulators; the penalty vanished (12.7 GB/s under load,
  36+ GB/s warm, symmetric both directions). Lesson banked: suspect
  the ruler before the hardware.
- Vulkan probe bug (mine, fixed): uint32 workgroup sums overflowed on
  a sequential pattern; switched to a 16-bit pattern with host-computed
  expected total. Also, the probe's first memory-type pick silently
  chose the device-uncached type; the probe now enumerates all types
  and runs each coherent flavour as its own labelled mode.
- No repository bugs were discovered by this slice.

## Exact commands

    cd spikes/a008_unified_memory && ./build_and_run.sh
    # HIP:    gcc -O2 -std=gnu11 -D__HIP_PLATFORM_AMD__ -I/usr/include \
    #           -o hip_unified_probe hip_unified_probe.c -lamdhip64 -lhiprtc -lm
    # Vulkan: glslc fill.comp -o fill.spv; glslc sum.comp -o sum.spv
    #         gcc -O2 -std=gnu11 -o vk_coherent_probe vk_coherent_probe.c -lvulkan
    #         ./vk_coherent_probe . 0   (host-cached coherent)
    #         ./vk_coherent_probe . 1   (device-local coherent)
    # Suite:  hidden_files/run_a008.sh (E-MASTER, canonical A-003 pattern)

## Log sha256 (purpleraider, spikes/a008_unified_memory/)

- finalA.log  d2b25966fc90550999c224c2d88b0be4201cf24a142794fabaf93c9b6a1370d0
- finalB.log  63df0d582b3e1f909e50eae27367445afb29e9476ea14e897222e548ee22b712
- finalC.log  4b6e7f2fab8b05b091ed8423dc31b9d8ceb530bd5b811865d9d016e603ee3b6d
- reread.log  0053fc22bb240db2b55acf080a21d46ec9588b77dff746114b69088a6e615f67
- vk_cached.log    18e98a14add426b1cfc36069bcd1b8a5e484384ea7c4f283167fc4349e59332f
- vk_devlocal.log  aecff0f039cafbc4fab2a5ad16e3576c00dbcfe4562c11e4c727e3f7f20e441f
- vk_cached2.log   79a441982d0ce85ca1b1924841ef8f8c001a9814dbcb8631194f8932da2418e2
- vk_devlocal2.log 034210db9d422edb28e4d2189edb8c15844e1b799c8c98f44db9b91268e82ca6
- sources: hip_unified_probe.c f191ed22a55e892abad506ca5988b4c3974590560b9dc0a10bdce44f48b931c8
- sources: vk_coherent_probe.c 8e9c994f0b9eb2932d01c2b4e05d39d88eab17fd2f8f65190d1d4a73df048fd8
- suite log: hidden_files/a008_run_all.log (see CAMPAIGN_STATE.md)
