# GPU Memory Internals — How VRAM Is Actually Allocated, Moved, and Fragmented Beneath a Runner

**Dossier OR-6 (Memory Domain), Topics C4 + C6 (GPU side) — Ollama Research Forge**
**Commissioned by:** Volmarr Wyrd, 2026-11-15
**Date of research:** 2026-11-15 (all web sources accessed 2026-11-15; see §8)
**Status:** GPU-below-the-API dossier. The MEMORY-COMPENDIUM (Chapter 10) flags C4 (host↔device paths) and C6 (CUDA/HIP memory models) as present only in fragments — PyTorch allocator notes here, a UMA case there, Aesir HIP lessons elsewhere — and not systematised. This dossier systematises the layer *below* the runner API: what the driver actually does with a byte of VRAM, and what allocator a serious runner is therefore forced to build on top of it.
**Readers:** Yrsa engineering (a) the improved Ollama in Go, which drives CUDA / ROCm / Vulkan backends via ggml, and (b) Project Aesir.
**Companion dossiers in this corpus:** `memory/kv-cache-design.md` (A1 — the workload; its §7.2 reserve line is tied to this dossier in §7.3 below), `memory/allocator-lineages.md` (host-side allocators — the same ideas in RAM), `memory/unified-memory.md` (B7 — when there is no separate VRAM at all), `memory/virtual-memory-and-caches.md` (B1/B2 — the CPU VM system that §5 shows CUDA's VMM mirroring), `runners/mlx.md` (the Metal/MLX side, pointed to in §6.3), `runners/llamacpp-ggml.md` (the ggml runner whose backend buffers §3.3 describes).
**Clean-room note:** Written in our own words from the public sources in §8. No passages are copied beyond short factual labels (API names, flag names, structure names are facts, quoted as names). Judgements beyond a cited source are marked **[Engineering judgement]**. Field knowledge that could not be tied to a public source read today is marked **[Field knowledge — unverified]**. Speculation is marked **[SPECULATION]**.

---

## 1. Header + Essence: A Second Computer's RAM, With a Worse Allocator API and No Swap

Forget, for a moment, that a GPU is a graphics device. From a memory manager's point of view a discrete GPU is a *second computer* bolted to the side of the first one:

- It has its own physical RAM (VRAM — GDDR or HBM on the card), its own page tables, its own address space, and its own memory-management unit.
- The host program cannot dereference that RAM. It can only ask a driver, over a bus, to allocate it, map it, copy into it, copy out of it, and free it.
- There is, in the ordinary discrete case, **no swap file for VRAM**. When host RAM fills, the OS pages cold data to disk and the program slows down. When VRAM fills, an allocation simply fails. The program gets an out-of-memory error at whatever moment it asked for one byte too many — usually in the middle of a forward pass, with a half-built graph in its hands.
- The allocation API the driver offers at the bottom — `cudaMalloc` and its kin — is deliberately primitive: synchronous, device-wide in its side effects, and priced like a system call into another machine, because that is roughly what it is (§2).

The thesis of this dossier, stated once:

> **The driver does not provide a memory manager. It provides a memory *frontier*. Every serious runner — PyTorch, vLLM, ggml/llama.cpp, TensorRT-LLM — therefore builds its own memory manager above `cudaMalloc`, suballocating tensors out of a small number of large driver extents it obtained early and almost never gives back. That built layer, not the driver, is the runner's real VRAM allocator, and most "GPU out of memory" behaviour users actually see is that layer's behaviour: its rounding, its splitting, its stream rules, and its fragmentation.**

Everything below follows from that one fact:

1. §2 explains *why* the raw layer cannot be used per-tensor.
2. §3 describes the caching-allocator pattern every serious runner converges on, with PyTorch's as the fully documented reference implementation and ggml's as the second, structurally different data point.
3. §4 prices movement — because on a discrete card, getting bytes *into* VRAM is a bus transfer with a hard bandwidth ceiling, and the pinned-memory discipline is what decides whether you reach it.
4. §5 shows why VRAM fragmentation is strictly worse than RAM fragmentation, and names the one documented escape hatch (CUDA's virtual-memory API).
5. §6 does the same tour for HIP, Vulkan, and Metal, because a Go runner via ggml does not get to choose only CUDA's rules.
6. §7 turns all of it into demands: what the Go layer should require from its backends, what Aesir should require on the HIP side, and how the 6 GB budgeting chain in the KV dossier must be re-read once driver and context reserves are put back on top of it — honestly, separating what the corpus has *measured* from what it has *assumed*.

A reader in a hurry can read §1, the last paragraph of each section, and all of §7.

---

## 2. The Raw Layer: What `cudaMalloc` Actually Is

### 2.1 Semantics: a synchronous, page-table-backed driver allocation

In the CUDA programming model, `cudaMalloc` returns an address in device memory usable by kernels and CUDA APIs [S1]. Behind that simple contract, the driver must do the work any OS allocator does, plus the work peculiar to a second processor:

- find or create physical pages in VRAM;
- build or update the GPU's page tables so the returned virtual address translates to those pages;
- record the allocation against the calling process's CUDA context, so it can be accounted, shared or revoked, and torn down at context destruction.

Two documented properties make the raw call expensive in ways `malloc` on the host usually is not:

**It synchronises.** NVIDIA's own stream-ordered allocator guide states the point as its motivation: managing memory with `cudaMalloc` / `cudaFree` *causes the GPU to synchronise across all executing streams* [S9]. A free, in particular, cannot complete until the driver knows no in-flight work can still touch the range — and the cheap way to know that is to drain. PyTorch's allocator guide makes the same point from the consumer side: these APIs, "especially `cudaFree`, introduce synchronization" that breaks the CPU-runs-ahead-of-GPU pipelining the whole runtime depends on [S5].

**First use pays for the context.** Lazy context creation means the first CUDA call in a process — very often the first `cudaMalloc` — also pays for building the context and its unified virtual-address map. NVIDIA developer-forum staff discussion of the classic "first `cudaMalloc` takes ~200 ms" reports attributes most of that first-call cost to context initialisation rather than to the allocation itself, and recommends forcing it early (historically with `cudaFree(0)`) so it does not land inside timed work [S11 — forum report, era CUDA ≤11; treat the millisecond figures as historical, the *mechanism* as still documented behaviour]. **[Engineering judgement]** The exact first-call cost is machine-, driver- and system-RAM-dependent and should never be quoted as a constant; what is stable is the *shape*: first allocation ≫ steady-state allocation ≫ suballocation from an already-held extent, which costs no driver call at all.

There is a modern partial exception, and it matters for §3 and §5: since CUDA 11.2 the driver also offers a **stream-ordered allocator** — `cudaMallocAsync` / `cudaFreeAsync` / `cudaMallocFromPoolAsync` — in which allocation and free are *operations inserted into a stream*, obeying that stream's ordering instead of synchronising the device, and drawing on a driver-managed memory pool (`cudaMemPool_t`) whose reuse and trimming behaviour the application can tune [S9][S10]. This is the driver itself learning the caching-allocator lesson (§3). It does not abolish the lesson: a runner that wants identical behaviour on HIP, Vulkan and older CUDA still ends up implementing its own pool above whichever primitive each backend offers.

### 2.2 Why nobody allocates per-tensor at runtime

Put §2.1 together and the industry-wide rule is arithmetic, not taste:

- A transformer forward pass touches hundreds to thousands of tensors (weights, activations, KV blocks, scratch). If each were a driver allocation, the pass would pay hundreds of synchronising driver round-trips — and a *free* per tensor on the way out, each one a potential device drain.
- Decode repeats that pass per token. Any per-token driver traffic is multiplied by every token the user ever generates.
- Allocation sizes in a runner are also *adversarially varied* — prompt length, batch, and context change tensor sizes continuously — so a naive per-tensor allocator would churn the driver's own free lists and fragment VRAM at driver level (§5), where the runner cannot even see it, let alone fix it.

Hence the universal pattern of §3: **allocate rarely, in large extents, at load / warm-up time; suballocate constantly, in-process, at run time; return extents to the driver only at model unload, context teardown, or under genuine memory pressure.**

### 2.3 The driver reserve: what is already gone before the runner asks for anything

A card advertised as "6 GB" never offers 6 GiB to a runner. Four consumers take their cut first. Only the first is cleanly documented; the dossier separates them honestly.

| Consumer | What it is | Size — and how well we know it |
|---|---|---|
| **Display / compositor** | If the card drives a display, the framebuffers, compositor surfaces and desktop working set live in the same VRAM. | **[Field knowledge — unverified]** Commonly a few hundred MiB on a desktop at 1080p–4K, more with multiple / high-refresh / HDR displays; zero on a headless compute card. No public NVIDIA document read today quantifies this; it is visible empirically in `nvidia-smi` before any compute process starts. |
| **Driver + CUDA context, per process** | Page tables, context state, module images, driver bookkeeping resident in VRAM for as long as the context lives. It does *not* disappear when allocations are freed — NVIDIA forum staff attribute a persistent ~111 MiB on a Tesla P4 (CUDA 9.2 era) after `cudaFreeHost`, explicitly, to "the CUDA context established by the process," released only at context destruction / process exit [S12 — forum report, 2019]. | A PyTorch-forum answer from a PyTorch developer (2021) decomposes a first-`.cuda()` footprint as **~300 MiB for a bare CUDA context**, plus ~500 MiB for the loaded PyTorch CUDA library's kernels, plus more again for cuDNN / cuBLAS — summing to the ~1.28 GiB the questioner observed in `nvidia-smi` [S13 — forum report, 2021]. Only the first term (~300 MiB, order-of-magnitude) is about CUDA itself; the rest is *that framework's* libraries and must not be charged to a ggml runner. |
| **Backend libraries** | cuBLAS / cuDNN (CUDA), rocBLAS / MIOpen (HIP), or the Vulkan driver's shader / pipeline caches: workspaces and loaded code the backend holds in VRAM. | Workload- and library-dependent; not publicly quantified as a fixed figure in the sources read. **[Engineering judgement]** For a ggml inference runner this is the smallest of the four on CUDA (ggml carries its own kernels rather than a large library working set) and the least predictable on ROCm, where library workspaces have historically been a visible line — flagged here as a measurement to take (§7.3), not a number to assume. |
| **Other processes** | Browsers with GPU acceleration, other runners, a second model, the desktop itself. | Entirely situational. On a single-purpose machine, ~0; on the user's daily-driver laptop, routinely the largest and most variable term. |

**The honest summary for a 6 GiB card:** the only component above with a citable public decomposition is the bare context, at roughly **300 MiB order-of-magnitude** in the 2021 PyTorch-forum account, with a smaller 111 MiB context residue reported on an older datacentre card / older CUDA [S12][S13]. A realistic *planning* reserve for "context + driver + display on a consumer laptop card that is also driving the screen" is therefore a **range, not a point: roughly 0.5–1.0 GiB [Field knowledge — unverified, synthesis of S12/S13 plus the display term above]**. §7.3 shows what that range does to the corpus's existing 6 GB arithmetic, and why the KV dossier's single 512 MiB reserve line sits at the *optimistic end* of it.

That is also why two tools never agree about VRAM, a confusion §5.3 formalises: `nvidia-smi` reports driver-visible residency (including context and other processes), a framework reports its own allocator's allocated/reserved split, and neither is "the memory" — they are views of different layers of the stack this dossier is describing.

---

## 3. The Caching-Allocator Pattern: The Runner's Real Memory Manager

### 3.1 The pattern, in one paragraph

Obtain large extents from the driver. Keep a free list of blocks carved from those extents, organised so a request can be served by splitting a larger free block and a free can be healed by merging with free neighbours. Round request sizes so similar requests produce identical block sizes and reuse each other. Keep separate pools for small and large requests so small churn cannot fragment the large pool. Remember which stream a block was used on, because a block is only safely reusable when the work that last touched it is known to be ordered before the new work. Almost never give an extent back. Every serious runner implements some version of exactly this; the differences are in rounding, pool boundaries, and how fragmentation is answered (§3.2 vs §3.3, §5).

### 3.2 Reference implementation: PyTorch's CUDA caching allocator

PyTorch's allocator is the canonical public description because PyTorch documents it twice, in complementary forms: a pseudocode guide to the allocator as of August 2022 by one of its authors [S5], and a 2026 PyTorch DevLog that re-derives its fragmentation behaviour and its expandable-segments fix in worked examples [S4]. The design, in our words:

**Two levels: segments and blocks.** A *segment* is one contiguous extent obtained from CUDA. A *block* is a sub-region of a segment tracking one allocation. Requests are served from blocks; segments are only created (by a driver call) when no existing block fits [S4][S5].

**Rounding first.** Every request is rounded up to a multiple of **512 bytes** by default (with an optional, more aggressive power-of-two-divisions rounding available by configuration, trading waste for reuse) [S5]. A 4-byte tensor therefore occupies a 512-byte block — a fact PyTorch users meet as "`max_memory_allocated` says 512" — and a new segment is itself rounded: **2 MiB** minimum for the small pool, **20 MiB** for requests in the 1–10 MiB range, and the request rounded up to a multiple of 2 MiB above that [S4][S5].

**Two pools.** Requests **< 1 MiB** go to a *small pool*; the rest to a *large pool* — explicitly "to avoid fragmenting the larger pool" with small allocations [S5]. Allocation search is best-fit within the pool: the smallest free block that fits is taken.

**Splitting with thresholds.** If the chosen block is larger than the request, it is split — front part allocated, remainder returned to the pool as a free block — but only if the remainder is worth tracking: **> 512 B** for small-pool blocks, **> 1 MiB** for large-pool blocks; otherwise the whole block is handed out and the slack becomes internal waste [S5].

**Merging on free — neighbours only, same segment only.** A freed block merges with its immediate predecessor / successor *if they are free*. Two free blocks separated by a live block cannot merge; two free blocks in *different segments* can never merge, because each segment is an independent driver allocation [S4][S5]. This single constraint is the root of the fragmentation worked examples in §5.2.

**Stream affinity.** Blocks are allocated *per stream*: each stream has its own cache, and a block freed on its creating stream can be reused there immediately, because stream order already guarantees the old kernel finishes before the new one starts. A block *used* on a different stream than it was created on cannot be reused until an event recorded on the using stream has completed — the allocator defers such blocks through a cross-stream delayed-free process checked on the next allocation [S5]. Rebalancing between stream caches happens only by emptying caches under low-memory conditions [S5].

**Holding, not returning.** If PyTorch ever uses N bytes, it keeps those N bytes cached until the user explicitly calls `empty_cache()` [S5]. On an actual driver OOM, the allocator's retry path is the confession of the whole design: synchronise, `cudaFree` *all* free cached blocks back to CUDA (letting the driver's page tables re-coalesce what the allocator's segment boundaries could not), and try the allocation once more before raising [S5].

**Expandable segments: the VMM answer.** With `expandable_segments:True`, a segment is no longer one `cudaMalloc`. It is one large *virtual* reservation (the DevLog says the allocator reserves on the order of 1⅛× total GPU memory of address space — cheap, because unmapped address space costs no VRAM) into which *physical* pages are mapped on demand via the VMM API of §5.4, in **2 MiB pages for the small pool and 20 MiB pages for the large pool** by default [S4]. Because every block in the segment now lives in one contiguous virtual range with no driver-allocation boundaries inside it, free blocks can always merge with their neighbours — the cross-segment barrier is gone, and the DevLog's paired examples (same allocation sequence, half the reserved memory in the good order vs the bad order without expandable segments; order-independent with them) collapse into one behaviour [S4]. This is the single most important allocator development in the corpus's period, and §5.4 and §7 both return to it.

**Accounting as a feature.** The allocator exports the distinction the whole dossier relies on: *allocated* (bytes in live blocks, counted after rounding) vs *reserved* (bytes in all segments the allocator holds), plus *inactive-split* bytes — free remainders trapped inside partly-live segments, named in the docs as "a potential source of fragmentation" because they cannot be returned to CUDA on the OOM retry while a sibling block is live [S5]. §7.1 turns this three-number ledger into a requirement for the Go runner.

### 3.3 Second data point: ggml's buffer system — same conclusion, different shape

ggml — the engine under llama.cpp and Ollama — reaches the same destination ("do not call the driver per tensor") by a route shaped by its workload: inference graphs are *known in advance* in a way training graphs are not, so ggml can plan rather than merely cache. From ggml's public backend interface and its documented allocator structure [S14][S15]:

**Buffer types, not raw pointers.** The backend abstraction separates a *buffer type* (`ggml_backend_buffer_type_t` — an allocation strategy belonging to a device, exposing name, alignment, maximum allocation size, and whether its memory is host-visible) from a *buffer* (`ggml_backend_buffer_t` — one allocated extent obtained through a buffer type) [S14]. A device offers a default buffer type for its own memory and, where applicable, a *host buffer type* for pinned host memory (§4.1) — so "where does this tensor live, and in what kind of memory" is a typed choice made before any byte is allocated. Multi-tensor allocation (`ggml_backend_buft_alloc_buffer_n`) plans a set of tensors together, accounting for alignment and per-backend maximum buffer size and splitting the set across several buffers when one extent cannot hold it [S14].

**The graph allocator plans lifetimes.** Above buffer types sit ggml's tensor allocators: a simple sequential allocator for straightforward cases, a dynamic allocator that maintains free blocks and merges adjacent free blocks on release, and the graph allocator (`ggml_gallocr`), which analyses a whole computation graph before execution — counting children and views, assigning each tensor a buffer and offset, reusing a tensor's memory once its last consumer has run, permitting in-place operation where an op can safely overwrite a single-child, view-free parent, and protecting graph outputs from reuse [S15]. Its *reserve* pass dry-runs the graph to compute the buffer size the plan needs; re-reserving a graph of the same or smaller topology reuses the existing buffer rather than reallocating [S15, via the ggbond binding's documentation of the same C API].

**Why the shapes differ — and why that is fine.** PyTorch's allocator is a *reactive cache* because training workloads allocate unpredictably and free out of order; ggml's graph allocator is a *static plan* because an inference graph's lifetimes are computable before the first token. **[Engineering judgement]** For the Go Ollama build this distinction is the design lesson, more than either implementation: weights and KV deserve the ggml treatment (long-lived extents, planned once, offsets assigned, never churned), while transient compute scratch deserves the PyTorch treatment (a caching pool with splitting, merging and stream rules), because scratch lifetimes follow the graph but scratch *sizes* follow the request. Conflating the two — one pool for everything — is how runners end up with a long-lived KV block stranded inside a churned scratch segment, unreleasable and unmergeable (§5.2).

**Honesty note on ggml sources.** ggml's *public documentation* of its CUDA- and Vulkan-backend buffer pools specifically (pool sizes, reuse margins, growth steps inside `ggml-cuda` / `ggml-vulkan`) is thin compared with PyTorch's allocator writing; the account above is therefore deliberately kept at the level the public backend / allocator documentation supports [S14][S15]. Backend-internal pool tunables are **[not verified from public docs read today]** and are a code-reading task against the pinned ggml revision the Go build actually vendors — flagged in §7.4.

### 3.4 The convergence, stated as law

Three independent implementations — PyTorch's cache, ggml's plan, and now CUDA's own stream-ordered pools [S9] — converge on the same five commitments. **[Synthesis, from S4/S5/S9/S14/S15]**

1. Suballocate from big extents; never call the driver in the steady state.
2. Never return an extent mid-session except under real pressure or explicit user action.
3. Split large free blocks; merge adjacent free blocks; accept that non-adjacent free memory is *not* usable for a larger request.
4. Segregate by size class and by lifetime, so churn in one class cannot strand memory in another.
5. Track stream / execution-order affinity, because on a GPU "free" means "free *and* provably no longer being read by in-flight work."

A runner that violates any one of the five will rediscover, in production, the failure that commitment exists to prevent.

---

## 4. Movement: Getting Bytes Into and Out of VRAM

Allocation decides where bytes may live. Movement decides what it costs to put them there — and on a discrete card, movement, not compute, is what "offload" and "load time" actually are.

### 4.1 Pinned (page-locked) host memory: the price of full bus bandwidth

Host RAM comes in two kinds for transfer purposes. *Pageable* memory (ordinary `malloc`) may be moved or swapped by the OS at any time, so the GPU's DMA engine cannot safely target it directly: a transfer from pageable memory is staged by the driver through a temporary pinned buffer — an extra copy on the host side before the bus copy begins. *Pinned* (page-locked) memory, allocated with `cudaHostAlloc` / `cudaMallocHost` on CUDA or `hipHostMalloc` on HIP, is memory the OS has promised not to move or page out, so the DMA engine can read or write it by physical address directly [S1][S7].

The documented consequences:

- **Bandwidth.** CUDA's guide lists higher host↔device bandwidth from page-locked memory (higher still for write-combining allocations on some systems) as a primary benefit [S1]. AMD's HIP documentation quantifies its side: for `hipMemcpy` / `hipMemcpyAsync`, pinned rather than pageable host memory can give **up to ~3× improvement in transfer bandwidth** [S7]. Treat the 3× as a vendor's best-case figure for its own API, not a guarantee — the stable claim is *direction and mechanism*: pageable transfers pay a staging copy, pinned transfers do not.
- **Asynchrony.** Only pinned source/destination memory makes `cudaMemcpyAsync` genuinely asynchronous with respect to the host: with a pinned buffer and a non-default stream, the copy is enqueued and the CPU proceeds; with pageable memory the call degrades toward synchronous staging. Pinned memory is therefore also the precondition for *overlapping* a copy with kernel execution on another stream (§4.3) [S1].
- **Scarcity.** The CUDA guide warns in the same breath that page-locked memory is a scarce resource whose allocations "start failing long before" pageable allocations do — every pinned page is a page the OS can never reclaim, so operating systems and drivers ration it [S1]. A runner pins a *staging pool*, sized in tens to a few hundreds of MiB and reused (§3.4, commitment 2, applied to host RAM); it does not pin the model.

**[Engineering judgement — the weight-load pattern]** Loading a multi-GiB model is the largest transfer a runner ever performs, and it is a *streaming* problem, not a *residency* problem: read a chunk from disk / page cache into a pinned staging buffer, enqueue an async H2D copy, reuse the buffer for the next chunk while the copy flies. One or two pinned buffers of, say, 32–128 MiB, double-buffered across two streams, saturate the bus; pinning the whole 5 GiB file would buy nothing and would fail on exactly the machines (small RAM, strict pinning limits) that most need the load to work. ggml's host buffer types (§3.3) exist precisely to give this pattern a typed home.

### 4.2 Zero-copy / mapped host memory: when not copying wins

Pinned memory can also be *mapped* into the device's address space (`cudaHostAllocMapped` / `cudaHostRegisterMapped`, device pointer via `cudaHostGetDevicePointer`; HIP mirrors this with `hipHostMallocMapped` / `hipHostGetDevicePointer`) [S1][S7]. A kernel can then dereference host RAM directly. The CUDA guide is explicit about both sides of the bargain: mapped access "does not provide the same bandwidth as device memory," but it eliminates the separate device allocation and the explicit copy, transfers data implicitly as the kernel touches it, and overlaps automatically with kernel execution without stream juggling [S1]. The application inherits the synchronisation burden — host and device now share memory with no copy boundary to hide behind, so stream/event ordering must prevent read-after-write hazards explicitly [S1]. AMD's HIP guide adds the performance warning in its own words: accessing host-resident pinned memory from device kernels forces traffic over the interconnect (PCIe), "much slower than the on-device bandwidth," and is generally not recommended for performance [S7].

When does zero-copy win anyway? **[Engineering judgement, from S1/S7]**

- **Single-touch data.** If a buffer will be read by the GPU exactly once and never reused (some embedding lookups, one-shot preprocessing outputs), copying it into VRAM first pays the same bus crossing *plus* a VRAM allocation *plus* a second read from VRAM. Mapping skips the last two.
- **Small, latency-bound transfers.** For a few KiB, transfer *setup* dominates transfer *bandwidth*; a mapped read can be cheaper than an enqueued copy. This is the regime of small control / sampling buffers, not of weights.
- **UMA-adjacent hardware.** On integrated parts where "host" and "device" memory are the same physical pool, mapped access is not a bus crossing at all — it is the native mode, and the whole pinned/copy apparatus collapses into residency management. That case is the unified-memory dossier's subject [corpus: `memory/unified-memory.md`]; this dossier notes only that code written *only* for the discrete case will make exactly the wrong choices there (§6.3).

Zero-copy loses, decisively, for anything read repeatedly — above all for weights during decode, which are read *once per token, forever*. Mapping weights over PCIe turns every token into a full model re-read across the bus at §4.4's rates; §4.4's arithmetic is why "run it from system RAM" is not a slow mode but a different, much smaller, product.

### 4.3 Async copies and streams: the ordering model underneath everything

A *stream* is an ordered queue of GPU operations: operations in one stream execute in issue order; operations in different streams may execute concurrently or interleave [S1]. Kernel launches, async copies, and (with the stream-ordered allocator) allocations and frees are all stream operations [S9].

Three consequences run through the whole dossier:

1. **Overlap is a stream property.** "Copy the next layer's weights while computing on the current layer" means, mechanically, *put the copy in a different stream from the compute, and synchronise only at the point of first use* (an event). A single-stream runner serialises every transfer against every kernel and pays the sum of both; a multi-stream runner pays, ideally, the maximum.
2. **Allocator safety is a stream property.** §3.2's stream-affinity rule is not allocator fussiness: it is the allocator encoding "this block's last reader is ordered before its next writer" in the only language the GPU guarantees — stream order, plus events where order crosses streams.
3. **Synchronisation is the tax on crossing streams.** Every event wait, every `cudaStreamSynchronize`, every synchronising `cudaFree` (§2.1) is a place where the CPU-ahead-of-GPU pipeline drains. Runner performance work is, to a surprising degree, the work of *removing* synchronisations that allocation and movement introduced — which is why §3's allocators go to such lengths to introduce none.

### 4.4 The bus, in numbers: PCIe and NVLink realities

Theoretical per-direction bandwidth for a full-width slot, from PCI-SIG-derived figures as tabulated in the sources read [S16][S17]:

| Link | Per direction (theoretical) | Both directions | Typical measured (per direction) |
|---|---|---|---|
| PCIe 3.0 ×16 | ~16 GB/s (15.75 GiB/s-class after 128b/130b encoding) | ~32 GB/s | ~12.1 GB/s [S17] |
| PCIe 4.0 ×16 | ~32 GB/s | ~64 GB/s | ~26.2 GB/s [S17] |
| PCIe 5.0 ×16 | ~64 GB/s | ~128 GB/s | — (not in sources read; do not assume the same efficiency ratio) |

Halve the lane count, halve the bandwidth: a ×8 slot (common when a second slot is populated, and the negotiated width on some laptops / eGPU enclosures) delivers Gen3 ×16 rates at Gen4, and Gen3 ×8 — ~8 GB/s theoretical — is a real configuration a runner can find itself on. The negotiated generation *and* width can also drop at idle and must be read under load [S16, citing NVIDIA's own `nvidia-smi` documentation practice].

NVLink exists to escape this table, but only where it exists: datacentre parts quote **600 GB/s bidirectional aggregate per GPU for A100 (NVLink 3)** and **900 GB/s for H100 (NVLink 4)** [S18 — secondary compilation of NVIDIA figures; treat as order-of-magnitude context]. Consumer cards in our fleet's class have no NVLink at all (NVIDIA removed it from GeForce after the RTX 3090 generation [S18]). **For every machine this corpus actually runs on, PCIe is the interconnect, and the table above is the law.**

Now the arithmetic that makes "offload costs X" a number instead of a vibe. **[Our arithmetic, from the table above]**

- Loading a 4.9 GiB Q4_K_M 8B model (the KV dossier's worked example) over Gen3 ×16 at the *typical* 12.1 GB/s takes ≈ **0.42 s of pure bus time** — before disk, decompression, or page-in. Over Gen4 ×16 typical, ≈ 0.20 s. Load time is rarely bus-bound in practice; §4.1's staging discipline decides whether it gets even this close.
- *Per-token* offload is the killer case. If one transformer layer's weights (≈ 4.9 GiB ÷ 32 layers ≈ 157 MiB for that model) do not fit in VRAM and must cross the bus *every token*, Gen3 ×16 typical bandwidth caps generation at ≈ 12,100 MiB/s ÷ 157 MiB ≈ **77 tokens/s as an absolute ceiling** — and a realistic pipeline, which cannot perfectly overlap a layer's arrival with the previous layer's compute at small batch, lands far below it. Two spilled layers halve it again. This is the quantitative content of the corpus's "offload cliff" (see `memory/unified-memory.md` on the cliff's absence under UMA): the cliff is not a metaphor, it is a division.

---

## 5. Fragmentation on the GPU: Worse Than RAM, For Structural Reasons

### 5.1 Why the GPU case is strictly harder

Host RAM fragmentation is mitigated by three mechanisms VRAM, at the raw API, does not have:

1. **Compaction.** A host allocator (or the kernel, for its own structures) can *move* live allocations to coalesce free space, because every access goes through a pointer the owner can update or through page tables the OS controls transparently. A GPU tensor's address is baked into kernels, graphs, and other tensors' metadata; the allocator cannot move a live block without invalidating work already enqueued against its address. PyTorch's guide states its version plainly: "The caching allocator cannot move these fragmented blocks around to construct a larger allocation" [S5].
2. **Overcommit and swap.** Host virtual memory lets the sum of reservations exceed RAM, with the page fault as the reconciliation mechanism. A `cudaMalloc` reservation *is* physical: reserved VRAM is VRAM no one else can use, for as long as it is held (§2.3, §5.3).
3. **Fine-grained remapping at the standard API.** Ordinary host `mmap` lets a process reserve a huge virtual range and commit pages into any part of it. Ordinary `cudaMalloc` does not: each call creates one self-contained extent whose interior layout the driver owns. The GPU equivalent of `mmap` exists — §5.4 — but it is a separate, lower-level API that an allocator must deliberately adopt.

What remains is exactly the host allocator's oldest problem, unsolved by any of the host's usual escapes: free space exists, in total more than enough, but not in one piece large enough.

### 5.2 The canonical failure, worked

The PyTorch DevLog's laboratory example is the cleanest public demonstration, and it deserves retelling because LLM serving hits it in production dress [S4]:

- Allocate eight 16 MiB tensors (without expandable segments). Each becomes its own 16 MiB segment: 128 MiB reserved.
- Free all eight. The pool now holds 128 MiB free — as eight separate 16 MiB blocks in eight unmergeable segments.
- Allocate four 32 MiB tensors. No free block is ≥ 32 MiB, and blocks cannot span segments, so the allocator makes four *new* 32 MiB driver allocations. Reserved is now 256 MiB to serve a 128 MiB live set — and the first 128 MiB of free space is stranded until something ≤ 16 MiB happens to want it.

Reverse the order (large first, then small) and the same work fits in 128 MiB, because small requests split large free blocks instead of creating small segments [S4]. Two morals, both load-bearing for §7:

- **Allocation order is a memory policy**, whether the runner chooses it or not. Warm-up sequences that establish the largest blocks first (largest context, largest batch shape) genuinely reserve less — the DevLog notes this as the classic workaround, while calling it, correctly, a leaky abstraction [S4].
- **In a runner, the "allocations" are contexts and KV growth steps.** A session that grows its KV in small increments early can strand the pool in small segments that a later, longer session cannot coalesce — the serving-shaped version of the laboratory example. KV block sizing (corpus: `memory/kv-cache-design.md`) and allocator segment sizing are therefore *the same decision seen from two floors of the building*.

A second, quieter stranding lives *inside* segments: a small live block split from a large segment pins the whole segment — its free remainder is counted as inactive-split, reusable for small requests but unreturnable to the driver on the OOM retry while its sibling lives [S5]. Long-lived small allocations (a persistent scratch tensor, a resident prefix block) should therefore never be served from the same segment population as large churn — §3.2's pool segregation, and §3.3's weights/KV vs scratch separation, are this sentence implemented twice.

### 5.3 Reserved vs allocated: the OOM-while-free paradox

Users meet fragmentation as a paradox: *"the card shows gigabytes free and the program says out of memory."* The paradox dissolves once the three numbers of §3.2 are kept separate — PyTorch's own OOM message prints them, which is why it is the corpus's exemplar of accounting as a feature (MEMORY-COMPENDIUM Ch. 1):

- **Allocated** — bytes in live blocks (post-rounding). What the workload is *using*.
- **Reserved** — bytes in all extents the allocator holds from the driver. What the process is *keeping from everyone else*. `nvidia-smi` sees something close to reserved (plus context and other allocations outside this allocator), which is why a framework "using" 11 GB can sit in a process `nvidia-smi` reports at 15 GB [illustrative decomposition pattern, cf. S5's metric definitions].
- **Reserved-but-unallocated** — reserved minus allocated: cached free blocks. Some of it is healthy cache (it will serve the next step without a driver call — that is its job). Some of it is *stranded*: free blocks individually too small, or in the wrong segment, or pinned by a live sibling, to serve the request that is about to fail.

An OOM can therefore be true in three different worlds at once: the *card* has free VRAM (held by no one), the *allocator* has free bytes (held by it, in unusable pieces), and the *request* has nowhere to go. The only honest diagnostic is the full ledger — total / allocated / reserved / reserved-unallocated / **largest single free block** — and the only honest user-facing message names which world failed. §7.1 makes the ledger a requirement, not a nicety. The `empty_cache()` escape hatch belongs in this section too: it returns *entirely-free segments* to the driver, helping other processes and sometimes de-fragmenting by surrender; it does not move live blocks, does not increase what the current process can allocate for a live working set that genuinely does not fit, and is a diagnostic / cooperative gesture, not a fix [S5; and PyTorch's API documentation as summarised in the search record].

### 5.4 The documented exception: CUDA's Virtual Memory Management API — the GPU's `mmap`

CUDA's VMM API (driver API, CUDA ≥ 10.2-era, documented in the current programming guide) separates the three things `cudaMalloc` fuses [S2][S3]:

| Step | Call | What it does |
|---|---|---|
| Reserve address space | `cuMemAddressReserve` | Claims a contiguous range of GPU *virtual* addresses. No physical memory is committed; the range is backed by nothing. Requires UVA support. |
| Create physical memory | `cuMemCreate` | Allocates a chunk of *physical* VRAM, returned as an opaque handle (`CUmemGenericAllocationHandle`) with **no address at all** until mapped. Size must be a multiple of the granularity reported by `cuMemGetAllocationGranularity`. |
| Bind them | `cuMemMap` | Maps a handle (or part of it) into a reserved virtual range at a chosen offset. |
| Make it usable | `cuMemSetAccess` | Sets access permissions for a mapped range per device — mapping alone does not grant access. |
| Unbind / release | `cuMemUnmap`, `cuMemRelease`, `cuMemAddressFree` | Tears the binding down in the reverse order; a reservation must be fully unmapped before it is freed. |

This is, operation for operation, the host VM vocabulary of the corpus's VM dossier translated to the GPU: reserve ≈ `mmap(PROT_NONE)`, create+map ≈ commit, unmap ≈ `munmap` / decommit, granularity ≈ page size. NVIDIA's guide itself motivates VMM with the same list a host VM programmer would give: mapping non-contiguous physical chunks into one contiguous virtual range to *reduce fragmentation*, growing an allocation by mapping more physical memory into an existing reservation *without copying*, and building custom allocators and KV caches on top [S2].

PyTorch's expandable segments (§3.2) are the proof that this is not a theoretical API: reserve ~all of address space once, map 2 / 20 MiB physical pages at the growing end as needed, unmap from the end under pressure — and the segment-boundary fragmentation of §5.2 disappears because there are no segment boundaries, only page boundaries inside one reservation [S4]. Two honest caveats:

- **VMM fixes *external* fragmentation between extents. It does not fix a live block in the middle.** If a long-lived allocation sits in the middle of the reservation, the free space on either side is virtually contiguous only if nothing live separates the mappings — expandable segments work because a segment's blocks are managed as one arena whose *tail* can unmap; a checkerboard of live blocks across the arena still strands the holes for any single larger request, exactly as in §5.1. What VMM buys is that the holes are at least all in *one* arena, mergeable the moment their neighbours free, with no driver-extent boundaries freezing them apart.
- **Support is a query, not an assumption.** VMM availability varies by device / driver and must be queried (`CU_DEVICE_ATTRIBUTE_VIRTUAL_MEMORY_MANAGEMENT_SUPPORTED`) before use [S2]. A cross-backend runner treats VMM as an optimisation path with a `cudaMalloc`-segment fallback, never as a baseline (§7.1).

**[Engineering judgement]** The HIP and Vulkan worlds have partial analogues rather than equivalents — HIP inherits CUDA-shaped APIs including stream-ordered allocation (§6.1), Vulkan exposes the physical/virtual split differently, through its heap/type system and dedicated allocations (§6.2) — and a Go layer that hard-codes VMM-shaped thinking into its backend interface will design an interface only one backend can implement. The portable abstraction is the *ledger and the arena* (§7.1); VMM is one backend's way of making an arena cheap.

---

## 6. Multi-Backend Reality: HIP, Vulkan, Metal

A runner via ggml does not live in CUDA's world alone. The three other backends each move one of the dials above to a different setting.

### 6.1 HIP / ROCm: the CUDA mirror, with its own grain

AMD's HIP is deliberately a CUDA mirror at the API level: `hipMalloc` for `cudaMalloc`, `hipHostMalloc` for `cudaHostAlloc`, `hipMemcpyAsync` for `cudaMemcpyAsync`, streams, events, mapped pinned memory with the same flag vocabulary (`hipHostMallocMapped`, `hipHostMallocWriteCombined`, `hipHostMallocPortable`, …) [S7][S8]. HIP documentation notes `hipMalloc` / `hipFree` are blocking calls and provides stream-ordered `hipMallocAsync` / `hipFreeAsync` as the non-blocking pair — the same §2.1 story, retold [S7]. Pinned-memory guidance, including the ~3× transfer-bandwidth figure, is likewise mirrored [S7]. Allocation granularity for `hipHostMalloc` is documented as 4 KiB [S8].

What the mirror does *not* guarantee — **[Engineering judgement, consistent with the corpus's Aesir HIP lessons in `memory/unified-memory.md` and the MEMORY-COMPENDIUM Ch. 10 flag]**:

- *Performance* equivalence. Identical API shape says nothing about driver allocation cost, workspace behaviour of the BLAS libraries behind the backend, or fragmentation behaviour under churn. Each must be measured per backend (§7.3).
- *APU behaviour.* On AMD APUs the "device" memory may be carved from the same physical pool as host memory (GTT/TTM budgets in the unified dossier's terms), so a `hipMalloc` can succeed or fail for reasons that are really *system* memory-policy reasons. The discrete-card mental model — VRAM as a sealed second RAM — is the wrong model on the very hardware Aesir most targets. The unified dossier is the authority there; this dossier's discrete analysis applies to Aesir's discrete targets and to its *API-shaped* decisions on APUs.
- *Documentation depth.* HIP's memory documentation is thinner and more version-scattered than CUDA's (multiple API entries in the current docs are marked deprecated in favour of renamed equivalents, and some sections carry beta notices [S8]). A backend abstraction should therefore lean on *measured behaviour* on ROCm more, and on documented guarantees less, than on CUDA.

### 6.2 Vulkan: explicit heaps and types — more control, more burden

Vulkan inverts CUDA's posture. Where CUDA hides the memory system behind `cudaMalloc` and lets the driver choose, Vulkan *exposes* the memory system and makes the application choose — which is why ggml's Vulkan backend lives a harder, more explicit life [S6][S19]:

**Heaps are physical pools; types are ways of using them.** A device advertises *memory heaps* (`VkMemoryHeap` — a sized pool, flagged device-local or host-local) and *memory types* (`VkMemoryType` — a heap index plus property flags: `DEVICE_LOCAL`, `HOST_VISIBLE`, `HOST_COHERENT`, `HOST_CACHED`, `LAZILY_ALLOCATED`, and vendor extensions) via `vkGetPhysicalDeviceMemoryProperties` [S19]. Every allocation (`vkAllocateMemory`) names a type; every buffer/image reports, in its memory requirements, a *bitmask* of types it may be bound to, plus its size and alignment. Finding a type is a search: intersect the resource's bitmask with the property flags the usage needs — the specification itself supplies the canonical search-loop pattern [S19]. On a UMA device there is typically a single heap, advertised as device-local, and the discrete distinctions collapse [S19] — the same collapse as §4.2/§6.1, expressed in Vulkan's vocabulary.

**Suballocation is the application's job — by design.** Khronos's own memory-management guidance is blunt: memory is allocated in blocks, and an application should *not* allocate a separate block for each resource — it should allocate large blocks and suballocate resources within them, exactly §3's pattern, here not as an optimisation but as the intended usage model, with the Vulkan Memory Allocator (VMA) library offered as the standard implementation of it [S6].

**Dedicated allocations are the sanctioned exception.** Some resources should get their own `VkDeviceMemory` block: very large buffers/images, resources the driver says prefer or require dedication (queried via the dedicated-allocation requirements path), shared/exportable resources, and render targets where the driver can optimise a dedicated placement [S6]. The parallel with §5 is exact: dedication trades a driver extent per resource (fragmentation risk, allocation-count limits) for placement quality and independent lifetime — right for a multi-GiB weights buffer, wrong for a thousand KV blocks.

**What this costs a runner.** **[Engineering judgement]** Three burdens CUDA spares you: (1) *type selection per allocation class* — weights want device-local, staging wants host-visible + coherent (or cached, with explicit flush/invalidate discipline if not coherent), readback wants host-visible + cached; getting one wrong is a silent 10×, not an error. (2) *Alignment and requirements plumbing* — every resource's size/alignment/type-mask must be honoured by the suballocator, per backend, per driver. (3) *A hard allocation-count ceiling* — Vulkan guarantees only a minimum number of simultaneous `VkDeviceMemory` allocations (`maxMemoryAllocationCount`, commonly 4096 on desktop drivers — **[Field knowledge — unverified]** as a typical value; the limit itself is a documented device limit queried at runtime), which alone forbids per-tensor `vkAllocateMemory` and forces the §3 pattern as a correctness matter, not a performance one. In exchange, Vulkan gives the runner something CUDA does not: *visibility*. Heap budgets are queryable, type choices are explicit, and a VRAM ledger (§7.1) can be built from ground truth rather than inference.

### 6.3 Metal: the unified heap — brief, by design

On Apple Silicon there is no discrete VRAM to intern: CPU and GPU share one physical pool, Metal buffers can be shared / managed rather than device-private, and "transfer" collapses toward residency and synchronisation rather than copies. That world — including MLX's device-less arrays, the recommended-working-set ceiling (roughly 65–75% of physical RAM in the corpus's account), and wired (pinned) memory discipline — is already dossiered in this corpus and is *not* re-derived here. **Pointer:** `runners/mlx.md` §2–§3 and `memory/unified-memory.md` §2. The one sentence this dossier needs from Metal is comparative: *Metal is what the discrete stack looks like when §4's bus is removed — every other section's problem either vanishes (movement, pinning for bandwidth) or survives unchanged (allocation policy, fragmentation of the allocator's own arenas, honest accounting).* A backend interface designed from the discrete case alone will force copies on Metal that do not exist; one designed from Metal alone will forget the bus on CUDA. §7.1's interface demands are written to survive both.

---

## 7. Applicability

### 7.1 For the improved Ollama in Go: what the Go layer should demand from its backend

The Go layer should never see `cudaMalloc`, `vkAllocateMemory`, or `hipMalloc`. It should see a backend contract with the following non-negotiables — each one is a section above, converted into an interface demand:

1. **Extent pools, owned by the backend, segregated by lifetime class.** At minimum three arenas per device: *weights* (allocated at load, freed at unload, planned — the ggml treatment, §3.3), *KV* (allocated at session/context creation, grown by a stated policy, freed at session end), and *compute scratch* (a caching pool with splitting/merging — the PyTorch treatment, §3.2). No class may be served from another class's extents. The Go layer requests *arenas with budgets*, not tensors with pointers.
2. **A VRAM ledger, queryable at any moment, per device.** Five numbers, in the vocabulary of §5.3: total device memory; driver/context/other-process residency as best the backend can report it (with an explicit "unknown" state where it cannot — Vulkan heap budgets and CUDA's `cudaMemGetInfo` get closest); allocator *reserved*; allocator *allocated*; and **largest single free block** per arena. Every OOM the runner produces must be phrased in these numbers ("needed 512 MiB contiguous in KV arena; reserved-unallocated 900 MiB in blocks ≤ 64 MiB") — the PyTorch OOM message (§5.3) is the UX bar. A runner that cannot produce this ledger cannot be debugged by its users, and on 6 GB cards (§7.3) it will need debugging.
3. **Pinned staging for all large H2D movement, owned as a pool.** A double-buffered pinned staging pool (§4.1) sized in the tens-of-MiB, through which all weight loads and large readbacks flow, with async copies on a dedicated transfer stream and event-based hand-off to compute streams (§4.3). No pageable `memcpy` path for anything larger than a stated threshold (suggest 1 MiB **[Engineering judgement]**), and no pinning of whole models.
4. **VMM / expandable arenas where available, segments where not.** On CUDA, prefer a VMM-backed expandable arena for the KV and scratch classes (query support first, §5.4); fall back to fixed segments with the §5.2 discipline (largest-first warm-up, growth in large steps). On Vulkan, the same demand reads as: VMA-style suballocation from large blocks, dedicated allocations only for weights-class extents (§6.2). On HIP, stream-ordered pools where they behave, measured (§6.1). The Go layer demands the *behaviour* (one mergeable arena per class, growable without copying live data where the backend allows); each backend states how close it gets.
5. **Growth policy is the runner's, not the allocator's accident.** KV arena growth in large, decreasing-frequency steps (e.g. double-until-cap, then fixed large increments **[Engineering judgement]**), never per-token and never per-small-block — §5.2's laboratory example is what per-small-increment growth becomes at serving scale.
6. **A stated non-goal: no cross-process VRAM promises.** The ledger's "other processes" line (§2.3) is read-only truth. The runner budgets against *currently free* VRAM at load time, re-checks before growing an arena, and degrades (shorter context, CPU offload of a stated layer count at §4.4's stated price) rather than discovering another process's existence via a driver OOM mid-generation.

### 7.2 For Aesir: the HIP-side equivalents

Aesir's demands mirror §7.1 with the §6.1 corrections applied:

- **Same three-arena, ledger-first contract** over HIP, with `hipMallocAsync` / pool APIs preferred over blocking `hipMalloc` in any steady-state path, and the blocking pair confined to load/teardown.
- **Measure, don't mirror.** Because HIP's documented guarantees are thinner, Aesir's backend should carry a small *measured* profile per device/driver: context residency (§2.3), pinned-transfer bandwidth achieved, stream-ordered pool behaviour under the §5.2 allocation sequence. The §5.2 sequence is a ready-made conformance test: run it against each backend's arena and record reserved-after-sequence; an arena that doubles is behaving like unexpandable segments, whatever its documentation says.
- **APU honesty.** On Strix Halo-class targets, Aesir's "VRAM ledger" is really a *system-memory ledger with a GTT budget line* (corpus: `memory/unified-memory.md`). Presenting it to users as VRAM would repeat, inside our own tool, the category error §6.1 warns against. The ledger interface should therefore carry a `memory_kind` (discrete / unified-carved / unified-shared) and let the budgeting logic of §7.3 branch on it.

### 7.3 The 6 GB budgeting consequence: putting the reserve back on top of the KV arithmetic

The KV dossier's worked example (its §7.2) budgets purplelongship — RTX 2060 Max-Q, 6 GiB VRAM, verified in our records at driver install 2026-10-28 — for a Llama-3.1-8B-class Q4_K_M model as:

```
V = 6,144 MiB − weights 5,018 MiB − reserve 512 MiB = 614 MiB for KV
```

and it flags its own reserve honestly at the point of use: *"The 512 MiB figure is our planning choice, not a measurement — it should be replaced by a measured reserve per backend at first implementation."* This dossier is where that flag gets cashed. Decompose the single "reserve" line into the §2.3 consumers, for *this* machine class (consumer laptop card, also driving the display, ggml/CUDA backend):

| Line | Corpus status today | This dossier's assessment |
|---|---|---|
| Weights 5,018 MiB | Derived from the quant's file size (llama.cpp dossier) — **measured-class** (file bytes; VRAM residency ≈ file bytes for a fully-resident load, modulo per-tensor alignment padding inside extents, §3.3) | Keep. Add a small alignment/rounding allowance *inside* the weights arena budget rather than as a separate fudge: PyTorch-class rounding (§3.2) wastes ≤ 512 B per block, but ggml's planned extents waste at most one alignment quantum per tensor — negligible at GiB scale, worth stating so no one inflates it. |
| CUDA context + driver | **Assumed** inside the 512 MiB | ~300 MiB order-of-magnitude for a bare context per the only public decomposition read [S13]; 111 MiB on older hardware/CUDA [S12]. Budget **300 MiB** as a planning figure, flagged as the first measurement owed (§7.4). |
| Display / compositor | **Not separated** in the KV dossier's line | **[Field knowledge — unverified]** A few hundred MiB while the card drives the laptop panel + desktop. On purplelongship-as-a-laptop this line is *real and non-zero*; on a headless run it vanishes — which is one concrete reason the same model "fits at the desk and OOMs on the couch." Budget **200–400 MiB** when display-attached, 0 when headless, and *say which mode the budget assumes*. |
| Backend workspaces + compute scratch + CUDA graphs | **Assumed** inside the 512 MiB | Workload-shaped, not fixed: prefill scratch grows with prompt batch; decode scratch is small and steady. This is §7.1's scratch arena, and it should be a *budgeted arena with a cap*, not a hope. No public figure read today sizes it for ggml; **[Engineering judgement]** cap it explicitly (e.g. 256 MiB) and let the ledger (§7.1) prove or refute the cap in testing. |
| Fragmentation headroom | **Assumed** inside the 512 MiB | Not a fixed tax but a *risk margin* against §5.2 stranding. With segregated arenas + large-step KV growth it can be small; with a single shared pool it must be large. Budget it as a percentage of the KV arena (suggest 10% **[Engineering judgement]**) rather than a flat MiB figure, so it scales with the thing that fragments. |

**The number chain, restated honestly:**

- *Optimistic end* (headless, bare context ~300 MiB, small scratch): total reserve ≈ 300 + 0 + ~150 + small headroom ≈ **~512 MiB — the KV dossier's figure is exactly this case.** Its 614 MiB KV result, and the context lengths derived from it (614 MiB ÷ 128 KiB/token ≈ 4,900 tokens at f16 KV for that model, before KV quantisation tiers), are therefore *headless-machine* numbers.
- *Display-attached planning case* (context 300 + display ~300 + scratch cap 256 + headroom): total reserve ≈ **0.9–1.1 GiB**, leaving ≈ **0–250 MiB** for KV at f16 — i.e. *the f16-KV configuration does not really fit on the display-attached 6 GiB card at all*, and the honest product answer at that operating point is a KV-quantised tier (the KV dossier's §5 machinery) or a shorter context, chosen *by the budget*, not discovered by an OOM.
- That spread — same card, same model, ~600 MiB of swing from two lines the original arithmetic folded into one assumed constant — is the entire argument of this dossier in miniature: **on a 6 GB card, the reserves the runner does not itemise are the same size as the KV cache it is trying to plan.** Itemising them is not bookkeeping pedantry; it is the difference between a context length the product can promise and one it can only sometimes reach.

Nothing in this section *overturns* the KV dossier: its procedure is explicitly written so that "only this one input changes" when the reserve is measured. This dossier's contribution is to split that input into five lines, attach a provenance to each, and name the measurement that retires the largest assumption (§7.4, item 1).

### 7.4 What could not be verified / measurements owed

1. **Measured context + driver + display reserve on the fleet's RTX 2060 Max-Q**, under the actual ggml/CUDA backend, display-attached and headless. This is the corpus's single largest open measurement debt (it moves §7.3 by ±hundreds of MiB). Method: `nvidia-smi` residency before any compute process; after context creation with no allocations; after backend init; differenced. *Not done in this dossier (no device access in this research task); all §2.3/§7.3 figures depending on it are flagged at the point of use.*
2. **ggml backend-internal pool tunables** (CUDA/Vulkan pool growth and reuse policy inside the vendored ggml revision). Public documentation supports §3.3's structural account only; internals are a code-read against the pinned revision, not a web source.
3. **PCIe 5.0 measured efficiency** and any NVLink figure beyond secondary compilations [S18] — included for context only; no fleet decision depends on either.
4. **HIP workspace / reserve behaviour on ROCm** for the Aesir targets (§6.1, §7.2) — to be measured with the §5.2 conformance sequence, per §7.2.
5. **Vulkan `maxMemoryAllocationCount` typical values** — the limit's existence and query path are documented [S19]; the "commonly 4096" figure is marked field knowledge where used (§6.2) and should be read from the actual device at runtime, never assumed.

---

## 8. Sources

All accessed **2026-11-15**. API names and flag names quoted in the text are factual labels from these sources.

- **[S1]** NVIDIA, *CUDA C++ Programming Guide* (v12.6.1 archive) — device memory, page-locked / pinned host memory, mapped memory, unified virtual address space, streams and asynchronous concurrent execution. https://docs.nvidia.com/cuda/archive/12.6.1/cuda-c-programming-guide/index.html
- **[S2]** NVIDIA, *CUDA Programming Guide — Virtual Memory Management* (§4.18 in the current guide) — VMM concepts, reserve/create/map/set-access workflow, support query, fragmentation and KV-cache motivations. https://docs.nvidia.com/cuda/cuda-programming-guide/04-special-topics/virtual-memory-management.html
- **[S3]** NVIDIA, *CUDA Driver API Reference — Virtual Memory Management* (§6.48) — `cuMemAddressReserve`, `cuMemCreate`, `cuMemMap`, `cuMemSetAccess`, granularity requirements. https://docs.nvidia.com/cuda/cuda-driver-api/cuda_driver_api/group__CUDA__VA.html
- **[S4]** Edward Yang, "When does fragmentation occur in the CUDA caching allocator?", *PyTorch DevLog*, 2026-06-01 — segments/blocks, cross-segment merging barrier, worked small-then-large vs large-then-small examples, expandable segments via `cuMemMap` (2 MiB small / 20 MiB large pages, ~1⅛× address-space reservation). https://docs.pytorch.org/devlogs/eager/2026-06-01-cuda-caching-allocator/
- **[S5]** Zachary DeVito, "A guide to PyTorch's CUDA caching allocator", 2022-08-04 — pseudocode reference: 512 B rounding, 2 MiB / 20 MiB segment sizing, small (<1 MiB) / large pools, split thresholds (512 B / 1 MiB), per-stream caches and cross-stream delayed free, OOM retry via `cudaFree`, allocated / reserved / inactive-split metrics; `cudaMalloc`/`cudaFree` synchronisation costs. https://zdevito.github.io/2022/08/04/cuda-caching-allocator.html
- **[S6]** Jordan Logan (AMD) for Khronos, "Memory management in Vulkan", Vulkan DevDay Montréal, April 2018 — heaps vs types, allocate-in-blocks / do-not-allocate-per-resource guidance, Vulkan Memory Allocator, dedicated allocations and their use cases. https://www.khronos.org/assets/uploads/developers/library/2018-vulkan-devday/03-Memory.pdf
- **[S7]** AMD, *HIP Documentation — Host memory* (HIP 7.x) — pageable vs pinned, `hipMalloc`/`hipFree` blocking vs `hipMallocAsync`/`hipFreeAsync`, pinned flags (`hipHostMallocMapped`, `WriteCombined`, `Portable`, …), ~3× pinned transfer-bandwidth figure, warning on kernel access to host-resident pinned memory over PCIe. https://rocm.docs.amd.com/projects/HIP/en/latest/how-to/hip_runtime_api/memory_management/host_memory.html
- **[S8]** AMD, *HIP Runtime API Reference — Memory Management* (HIP 7.x) — `hipMalloc`, `hipHostMalloc` (4 KiB allocation granularity), deprecated-alias landscape. https://rocm.docs.amd.com/projects/HIP/en/latest/reference/hip_runtime_api/modules/memory_management.html
- **[S9]** NVIDIA, *CUDA Programming Guide — Stream-Ordered Memory Allocator* (§4.3) — "`cudaMalloc` and `cudaFree` cause the GPU to synchronize across all executing streams"; `cudaMallocAsync` / `cudaFreeAsync`, memory pools and reuse policies. https://docs.nvidia.com/cuda/cuda-programming-guide/04-special-topics/stream-ordered-memory-allocation.html
- **[S10]** NVIDIA, *CUDA Runtime API Reference — Stream Ordered Memory Allocator* (§6.33) — `cudaMallocAsync`, `cudaMallocFromPoolAsync`, `cudaFreeAsync` semantics and pool association. https://docs.nvidia.com/cuda/cuda-runtime-api/cuda_runtime_api/group__CUDART__MEMORY__POOLS.html
- **[S11]** NVIDIA Developer Forums, "First cudaMalloc() takes long time?" — staff/community discussion attributing first-call cost to lazy context initialisation and the unified virtual-address map; historical millisecond figures treated as era-specific. https://forums.developer.nvidia.com/t/first-cudamalloc-takes-long-time/4057
- **[S12]** NVIDIA Developer Forums, "NVIDIA-SMI shows 111M GPU memory used, after cudaFreeHost…" (Tesla P4, CUDA 9.2, 2019) — staff attribution of persistent ~111 MiB to the per-process CUDA context, released only at context destruction. https://forums.developer.nvidia.com/t/nvidia-smi-shows-111m-gpu-memory-used-after-cudafreehost-release-the-memory-created-by-cudahostalloc/69099
- **[S13]** PyTorch Forums, "What is the initial ~1.3GB allocated VRAM when first using .cuda()?" (2021) — developer decomposition: ~300 MiB bare CUDA context + ~500 MiB PyTorch CUDA library + cuDNN/cuBLAS additions. Framework-specific beyond the first term; used only for that term's order of magnitude. https://discuss.pytorch.org/t/what-is-the-initial-1-3gb-allocated-vram-when-first-using-cuda/122079
- **[S14]** DeepWiki index of ggml / llama.cpp, "Backend System and Registration" — `ggml_backend_buffer_type_t` / `ggml_backend_buffer_t`, `ggml_backend_buft_alloc_buffer` and `ggml_backend_buft_alloc_buffer_n` (alignment, maximum buffer size, multi-buffer splitting). https://deepwiki.com/ggml-org/llama.cpp/4.2-cpu-backend
- **[S15]** DeepWiki index of ggml, "Memory Management and Allocation" — `ggml_tallocr`, `ggml_dyn_tallocr` (free-block merging), `ggml_gallocr` graph allocator (dependency/lifetime analysis, in-place optimisation, view handling, buffer assignment). https://deepwiki.com/ggml-org/ggml/2.3-memory-management-and-allocation
- **[S16]** "PCIe Gen 5 vs Gen 4 vs Gen 3 for AI" (compilation citing NVIDIA Ampere whitepaper and Hopper architecture material) — Gen3 ×16 ~16 GB/s, Gen4 ×16 ~32 GB/s, Gen5 ×16 ~64 GB/s per direction; negotiated link width/generation caution. https://www.myaihardware.com/deep-dive/pcie-gen-5-vs-gen-4-gen-3-for-ai-inference-vs-training
- **[S17]** Microway, "Performance Characteristics of Common Transports and Buses" — theoretical vs typical PCIe bandwidth: Gen3 ×16 16,000 MB/s theoretical / 12,100 MB/s typical; Gen4 ×16 32,000 / 26,200. https://www.microway.com/knowledge-center-articles/performance-characteristics-of-common-transports-buses/?action=history
- **[S18]** FiberMall, "NVLink Compatible Cards" (secondary compilation of NVIDIA figures) — NVLink 3 / A100 600 GB/s and NVLink 4 / H100 900 GB/s bidirectional aggregate per GPU; GeForce NVLink removal after RTX 3090. Used for order-of-magnitude context only. https://www.fibermall.com/blog/nvlink-compatible-cards.htm?p=10136
- **[S19]** Khronos, *Vulkan Specification — Memory Allocation* chapter — `VkPhysicalDeviceMemoryProperties`, heaps and types, property-flag combinations, UMA single-heap rule, memory-type search pattern, allocation limits framework. https://docs.vulkan.org/spec/latest/chapters/memory.html

*Corpus-internal sources (not web): `memory/kv-cache-design.md` §1.2, §7.2 (budget procedure, 512 MiB planning reserve and its own flag, 6 GiB fleet verification); `memory/unified-memory.md` (UMA/GTT, offload cliff, MLX pointers); `runners/mlx.md` §2–§3; `memory/MEMORY-COMPENDIUM.md` Ch. 1, Ch. 10 (C4/C6 gap flag this dossier answers).*
