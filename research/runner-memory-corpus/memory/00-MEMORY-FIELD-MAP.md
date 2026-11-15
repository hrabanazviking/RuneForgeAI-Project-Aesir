# OR-6 — Memory Field Map: the topic tree

*Version 1, 2026-11-15. Memory researched as a science in its own right, to the same depth
as the runner corpus, because most runner decisions are memory decisions wearing a
scheduling costume. Every dossier in this tree carries applicability notes for three
consumers: the **Ollama build**, **Project Aesir**, and **MimirAlloc**. The crown of this
workstream is `MEMORY-COMPENDIUM.md` in this folder.*

## A. AI / LLM memory

- **A1 KV-cache design** — layout (per-layer K/V, head packing), growth strategies, block/paged
  allocation, sharing across sequences and sessions.
- **A2 KV compression & eviction** — importance-scored eviction (H2O, SnapKV, PyramidKV lineages),
  sliding-window + attention-sink hybrids (StreamingLLM), merging/reconstruction methods.
- **A3 KV quantization** — per-channel vs per-token scaling (KIVI, KVQuant lineage), error
  behaviour at long context, mixed-precision policies.
- **A4 Context-window economics** — what a token of context costs in bytes, FLOPs, and latency at
  each model scale; prefill/decode asymmetry; when a bigger window is a worse product.
- **A5 Agent memory architectures** — episodic / semantic / procedural stores, memory banks,
  retrieval-backed memory, the MemGPT/Letta lineage (virtual context management), memory
  honesty & supersession lifecycles (never silently drop; superseded/absorbed states).
- **A6 Recurrent & SSM state as memory** — fixed-size state vs growing KV; hybrid models (the
  qwen35 lesson from our own Aesir work: most layers recurrent, attention at intervals,
  snapshots of SSM+conv state for prefix reuse).
- **A7 Attention variants as memory trade-offs** — MHA → MQA → GQA → MLA, sliding-window,
  sparse/block attention, linear attention: each is a memory/bandwidth bargain.
- **A8 Memory-augmented lineage** — Neural Turing Machines, DNC, retrieval-augmented
  generation read as external memory, memory layers in modern architectures.
- **A9 Deployed memory** — working vs long-term memory in shipped systems; residency,
  pinning/anchoring (the character-anchor law from our own campaigns), stable-order recall.

## B. Computer memory as a science

- **B1 Virtual memory & paging** — page tables, TLBs and shootdowns, demand paging, thrashing,
  page replacement, huge pages.
- **B2 Cache hierarchies** — L1/L2/LLC organisation, associativity, replacement policies,
  prefetching, cache-oblivious design, false sharing.
- **B3 NUMA & topology** — first-touch placement, interleaving, cross-socket costs.
- **B4 Latency vs bandwidth** — the two currencies; Little's law; why LLM decode is a
  latency/bandwidth problem, not a FLOPs problem.
- **B5 The memory wall** — the literature from Wulf & McKee onward; how the wall shapes
  every runner design; roofline model & arithmetic intensity as the working method.
- **B6 DRAM generations** — DDR / LPDDR / GDDR / HBM compared: bandwidth, capacity, power,
  packaging; where each appears in our fleet.
- **B7 Unified memory architectures** — CPU+GPU shared physical memory; the Z13 / Strix Halo
  as a living case (mining our own Z13 campaign records: GTT sizing, the 100 GiB cap,
  Adaptive Sync fix, crash forensics) + Apple Silicon as the other exemplar.
- **B8 CXL & pooling** — memory disaggregation, pooled tiers, what changes when memory
  becomes a fabric resource.

## C. GPU memory

- **C1 VRAM budgeting** — weights + KV + activations + workspace + fragmentation reserve;
  the 6 GB discipline (our purplelongship constraint) vs the 128 GB unified case.
- **C2 Access patterns** — coalescing, vectorised loads, bank conflicts; why GEMV decode
  is bandwidth-bound and what kernels do about it.
- **C3 On-chip memory** — shared memory / LDS, register pressure and occupancy, tiling.
- **C4 Host↔device paths** — pinned memory, zero-copy over PCIe and unified fabrics,
  unified virtual addressing, migration costs.
- **C5 Fragmentation & allocation on device** — caching allocators (PyTorch's as the case
  study), pool strategies, defragmentation by design (paged KV as the exemplar).
- **C6 CUDA & HIP memory models** — as publicly documented; where they differ and why
  it matters for portable runners (Aesir's HIP lessons included).

## D. NPU memory

- **D1 SRAM-centric design** — when the whole working set must live on-chip; tiling as a
  way of life.
- **D2 Dataflows** — weight-stationary, output-stationary, row-stationary (Eyeriss lineage);
  data reuse as the primary energy/latency lever.
- **D3 On-chip vs off-chip trade-offs** — compiler-managed movement, double buffering.
- **D4 Hailo as the public case** — public Hailo material + the dataflow literature; our
  own Hailo campaign records mined as OUR work (Aesir-Hailo line).

## E. Memory allocation as a discipline

- **E1 Allocator lineages** — dlmalloc, jemalloc, tcmalloc, mimalloc: designs, size classes,
  thread caches, huge-page strategies, return-to-OS policies.
- **E2 Specialised shapes** — slab, arena/region, pool, bump/linear allocators; when each
  wins; allocator choice as an architecture decision.
- **E3 Fragmentation theory** — internal vs external, measurement methods, worst-case
  bounds, why workloads differ (Robson's results and their modern readings).
- **E4 Alignment & layout** — cache-line discipline, structure-of-arrays, padding costs.
- **E5 Managed vs manual** — GC designs read as allocation+reclamation policies; what
  Go's GC means for a Go runner (Ollama) vs manual control (Aesir/Mojo, MimirAlloc/C).
- **E6 MimirAlloc — our own proven work** — both campaigns (Pi 117/117, Z13 117/117)
  mined as first-class sources WITH their numbers: what was built, what beat glibc
  where, what honestly lost, the 4-symbol public ABI, the gate results (4,988 passed
  on the Z13 campaign). First-hand evidence outranks literature.

## F. Cross-cutting method

- **F1 Measurement methodology** — how to measure memory honestly: RSS vs working set vs
  committed, allocator arenas vs live bytes, bandwidth microbenchmarks, soak behaviour.
- **F2 Memory in serving systems** — admission control, preemption & recompute-vs-swap,
  tiered KV (GPU→CPU→SSD) designs, persistence of sessions.

*Staffing: OR-6 runs parallel to OR-1…OR-5, 2–3 leads at a time across the whole campaign.
First OR-6 dossiers: E6 (MimirAlloc — our own numbers), B5 (memory wall + roofline),
A1 (KV-cache design), B7 (unified memory / Z13 case).*
