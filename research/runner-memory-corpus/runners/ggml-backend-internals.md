# ggml — Backend and Graph-Allocator Internals (OR-2 Deep-Dive Addendum)

**Corpus:** Ollama Research Forge — runner dossiers, deep-dive addendum to `runners/llamacpp-ggml.md`; companion to `runners/llamacpp-kv-internals.md` (the layer above) and `memory/gpu-memory-internals.md` (the framework-side account)
**Subject:** ggml, the tensor library bundled inside ggml-org/llama.cpp — how it assigns tensors to device buffers, how its graph allocator places a compute graph's tensors, how its CUDA/HIP pools actually behave, how llama.cpp estimates memory before loading, and what happens when allocation fails
**Clean-room note:** This dossier is a behavioural description written in our own words from ggml's and llama.cpp's public source and documentation. It describes design and behaviour only; no upstream code is reproduced. Every substantive claim names the file or component it was read from, so a reader can re-verify against the pinned tag.

---

## 1. Identity and version stamp

- **Project:** ggml, as bundled in ggml-org/llama.cpp. At this release ggml is not read from its standalone repository; it lives in the `ggml/` subtree of llama.cpp (`ggml/include/`, `ggml/src/`), and that subtree at the tag below is the object of this dossier.
- **State read:** release tag **`v1.0.0`** — llama.cpp's first semantic-version release, and ggml's simultaneous bump to the same number. Verified directly against the Git host on 2026-11-15: the annotated tag object is `a6d1a74dbebce3a16f4f2ceddbf38c21a08d8674`, tagged 2026-11-13T10:20:13Z, pointing at commit **`b1b770d90d94cad9e9ea5b993bdbc383a522fb28`**. Secondary release coverage of the same tag names build `b12359` as the matching nightly build number. All source reading for this dossier was done against the `v1.0.0` tag on **2026-11-15**.
- **Composition with the KV addendum:** `runners/llamacpp-kv-internals.md` read the same tag one layer up (KV cells, slots, server reuse). This dossier reads the layer beneath it: the KV tensors that dossier describes are, in the end, tensors in buffers allocated by the machinery described here, and the compute graphs that consume them are placed by the allocator in Section 4. Where the two dossiers touch (memory breakdown, reserve graphs), they cite the same functions from opposite sides.
- **Scope warning:** ggml moves with llama.cpp, weekly. Anything below is a statement about **v1.0.0**, not about master, and should be re-checked before being treated as current. File paths below are paths inside the repository at the tag (for example `ggml/src/ggml-alloc.c`).

## 2. Architecture in one pass

ggml separates four things that less careful designs fuse:

1. **A device** (`ggml_backend_dev_t`, declared in `ggml/include/ggml-backend.h`) — a physical or logical place work can run: a CPU, a dedicated GPU, an integrated GPU, an accelerator meant to assist the CPU, or a *meta* device wrapping several devices for tensor parallelism. A device reports its type, its free and total memory, and a small capability set (asynchronous work, pinned host buffers, buffers created from a host pointer, events, mmap support).
2. **A buffer type** (`ggml_backend_buffer_type_t`, same header) — a *kind* of memory a device can provide, characterised by an alignment, an optional maximum buffer size, and an optional per-tensor allocation-size function. The allocation-size function is where a backend quietly charges more than the tensor's logical bytes (padding, row expansion) — Section 3.3.
3. **A buffer** (`ggml_backend_buffer_t`) — one allocated extent of some buffer type, carrying a usage tag with exactly three values: *any*, *weights*, or *compute* (`ggml/include/ggml-backend.h`). The usage tag is not bookkeeping decoration: the scheduler uses it to prefer running an operation on the backend that already holds its weights (`ggml/src/ggml-backend.cpp`, scheduler assignment passes).
4. **A backend instance / stream** (`ggml_backend_t`) — an execution context on a device that computes graphs whose tensors live in buffers.

Two allocators sit on top of that vocabulary, and confusing them is the most common error in descriptions of ggml:

- **The static tensor allocator** (`ggml_tallocr` in `ggml/src/ggml-alloc.c`, declared in `ggml/include/ggml-alloc.h`) — a simple bump allocator over one already-allocated buffer: tensors are laid end to end, each padded to the buffer's alignment, and running out of room is a hard abort with a logged message naming the tensor and the shortfall. It is used where a fixed set of tensors must be packed into a known buffer, not for compute graphs.
- **The graph allocator** (`ggml_gallocr` in the same file) — the subject of Section 4. It does not allocate bytes directly; it *simulates* a graph's execution against per-buffer-type dynamic allocators, records where every tensor would live, and only then materialises real backend buffers sized to the simulation's high-water marks.

Between the graph allocator and multi-device execution sits the **backend scheduler** (`ggml_backend_sched`, implemented in `ggml/src/ggml-backend.cpp`, declared in `ggml/include/ggml-backend.h`). The scheduler owns one graph allocator spanning several buffer types, splits a graph into per-backend subgraphs ("splits"), inserts copies where a tensor must cross devices, and decides which backend each node runs on. Section 3.4 describes its assignment rules; Section 4.4 describes when it re-plans.

A final architectural fact that shapes everything below: **ggml has no global device-memory manager.** Each buffer type allocates from its driver directly; each CUDA/HIP *scratch* pool is per-device and per-backend-context; the graph allocator's buffers are per-scheduler. There is no cross-model, cross-context, or cross-process accounting inside ggml at all. Any such accounting in a product built on ggml (Ollama included) is that product's own layer — a point Section 6 returns to.

## 3. Question 1 — Buffer architecture: types, assignment, and the split arrangements

### 3.1 The buffer types present at v1.0.0

Reading the buffer-type constructors in `ggml/src/ggml-backend.cpp` and `ggml/src/ggml-cuda/ggml-cuda.cu` (the single translation unit that implements both the CUDA and, via HIP translation, the ROCm backend):

- **CPU** (`ggml/src/ggml-backend.cpp`). Host memory obtained through an aligned allocation. Alignment is ggml's standard tensor alignment; the per-tensor allocation size defaults to the tensor's logical byte count (the buffer type supplies no override); it reports itself as a host buffer type. This type is defined in the common backend file, deliberately, so every other backend can refer to it.
- **CPU_Mapped** (`ggml/src/ggml-backend.cpp`). A non-owning wrapper over a caller-supplied host pointer — the mechanism behind loading weights straight out of an mmap of the model file. Its free operation is a no-op because the buffer does not own the memory. In `src/llama-model.cpp`, model loading uses the device-level "buffer from host pointer" capability to wrap mmap ranges in backend buffers where the device supports it, with an explicit comment that wrapping per-context ranges (rather than the whole file) is what keeps unrelated regions from being pinned on unified-memory systems.
- **Per-device CUDA/HIP** (`ggml_backend_cuda_buffer_type(device)` in `ggml/src/ggml-cuda/ggml-cuda.cu`). One buffer type per visible device, up to the backend's device cap of 16 (`ggml/include/ggml-cuda.h`). Alignment is 128 bytes. Allocation is a single device allocation per buffer (Section 7 for its failure path). Under HIP the same source is translated, the backend renames itself "ROCm", and the allocation calls become their HIP equivalents; there is no separate HIP buffer implementation at this tag — `ggml/src/ggml-hip/` contains only build files.
- **CUDA host (pinned)** (`ggml_backend_cuda_host_buffer_type()` in the same file). Page-locked host memory for faster host↔device copies. Notably, if allocating pinned memory fails, this buffer type's allocation silently substitutes an ordinary CPU buffer — the one genuine in-allocator fallback found in this dossier (Section 7.3).
- **Backend-specific extras.** A device may expose additional buffer types beyond its default and host types through an "extra buffer types" hook (`ggml/include/ggml-backend.h`). The CPU device uses this family of mechanisms for specialised host layouts (for example repacked weight layouts used by CPU kernels); those types accept only tensors they know how to transform, which is why model code in `src/llama-model.cpp` is careful to route derived tensors (the Hadamard rotations of the KV dossier) onto a plain device buffer type rather than a CPU extra type. The full catalogue of extra types per backend was not enumerated for this dossier and any claim about a specific extra type beyond that routing behaviour is **unverified** here.
- **Composite buffer types** (`ggml/src/ggml-backend.cpp`). Two wrappers deserve naming because model code depends on them: a *multi-buffer*, which presents several real buffers as one logical buffer (used when a context's tensors are spread across disjoint file ranges or devices, and which has no single base pointer), and the *meta* device's buffers for tensor parallelism (Section 3.4).

There is **no pooled variant at the buffer-type level**. Pooling in ggml exists in exactly two places, neither of which is a buffer type: the CUDA/HIP scratch pools inside the CUDA backend (Section 5), and the graph allocator's reuse of offsets inside its own compute buffers (Section 4). A weights buffer is one driver allocation (or one mmap wrap) per materialised chunk; nothing caches or recycles weights buffers.

### 3.2 How a tensor gets its buffer

Assignment happens at three different times, by three different deciders, and a dossier reader should keep them separate:

1. **Weights — decided by the model loader, before any graph exists.** In `src/llama-model-loader.cpp`, each model tensor is created against an ordered *buffer-type list*: separate lists for input tensors, output tensors, each layer, and the CPU fallback list. A selection helper walks the list and picks the first buffer type that can hold the tensor (considering its operation and type). This is the machinery that `-ngl/--n-gpu-layers`, tensor-split proportions, and per-tensor buffer-type overrides ultimately feed: they shape the lists, and the lists shape placement. Tensors for a context are then packed together by the generic "allocate all tensors of a context from a buffer type" utility (`ggml/include/ggml-alloc.h`, implemented at the end of `ggml/src/ggml-alloc.c` via the planning logic in `ggml/src/ggml-backend.cpp`), which plans how tensors pack into one or more buffers respecting the buffer type's alignment and maximum size, rather than giving every tensor its own allocation.
2. **Graph tensors — decided by the scheduler and graph allocator, per graph.** A compute graph's intermediate tensors start unallocated. The scheduler assigns each node a backend (Section 3.4); the graph allocator then places the node's output in the buffer type belonging to that backend's slot in the allocator (Section 4). Pre-allocated tensors (weights, inputs placed by the caller) are never re-placed: the allocator treats any tensor that already has data or a buffer as external and leaves it alone (`ggml/src/ggml-alloc.c`, the "is allocated" test in the graph allocator).
3. **KV and other long-lived context tensors — decided by their owning subsystem**, which allocates its own buffers from a chosen device buffer type and hands tensors to graphs pre-allocated, so from the graph allocator's perspective they are external inputs. (Their internal organisation is the KV addendum's subject.)

### 3.3 Allocation size is a backend opinion, not a byte count

The generic layer's default is honest — allocation size equals logical bytes (`ggml/src/ggml-backend.cpp`) — but buffer types may override it, and the CUDA/HIP type does (`ggml/src/ggml-cuda/ggml-cuda.cu`): for quantised tensors whose row length is not a multiple of the matrix-row padding the kernels expect, the charged size is expanded by the padding rows, and flash-attention outputs can carry a backend-computed size larger than the naive product. Two consequences follow. First, **VRAM accounting that multiplies element counts by type sizes will under-report CUDA usage** for exactly the quantised models everyone runs; ggml's own accounting (Section 6) avoids this trap only because it asks each buffer type for its allocation size instead of computing bytes itself. Second, the padding is real memory with defined contents: the CUDA buffer's tensor-initialisation path zeroes the padded region of quantised tensors in non-compute buffers specifically so padding cannot produce NaNs.

### 3.4 Multi-device: three different arrangements, often conflated

At v1.0.0 "multi-GPU" names three mechanically distinct designs (`docs/multi-gpu.md` is the project's own summary; the mechanisms are in the files named):

- **Layer split (the default; pipeline parallelism).** Layers are distributed across devices in contiguous ranges, in proportions given by the tensor-split setting or derived from device memory. Each device holds its layers' weights in its own per-device buffer type, and its layers' KV lives with it. Execution is the scheduler's ordinary multi-backend path: the graph is cut into per-backend splits, activations cross devices at split boundaries via inserted copies, and — when the devices support async work and events — splits can be pipelined. This is not a special buffer type at all; it is the scheduler (`ggml/src/ggml-backend.cpp`) doing its normal job over several ordinary devices.
- **Row split (deprecated).** The older tensor-parallel path, built on a "split buffer type" obtained through a registry procedure (`ggml/include/ggml-backend.h` still declares the split-buffer-type procedure pointer, commented as the old path). The project documentation at this tag marks the mode deprecated and directs users to the tensor mode. Its internals were not read in depth for this dossier; any detailed claim about its current behaviour is **unverified**.
- **Tensor split (experimental; the meta device).** A *meta device* (`ggml/src/ggml-backend-meta.cpp`, device type META in `ggml/include/ggml-backend.h`) wraps several real devices and presents as one device whose tensors are sharded. The meta implementation propagates a per-tensor *split state* through the graph — which axis (if any) a tensor is split along, or whether it is mirrored on all devices — with per-operation rules for how split states combine (matrix multiplication, concatenation, views, reshapes, attention, and others each have a handler in that file). Weights and KV are both sharded in this mode, cross-device reductions happen per layer, and the mode carries hard preconditions documented in `docs/multi-gpu.md` (flash attention required, non-quantised KV only, an architecture allow-list, and no automatic memory fitting). It is explicitly labelled experimental by the project.

The scheduler's assignment logic, which the layer mode relies on, is worth stating plainly because it *is* the tensor-to-buffer assignment for graph nodes (`ggml/src/ggml-backend.cpp`, the graph-splitting passes): pre-allocated tensors pull their operations toward the backend that owns their buffer (weights most strongly); assignment then expands outward from those anchors to neighbouring nodes; unsupported operations fall to a backend that supports them, with the CPU backend as the universal last resort when it is in the backend list; and a final pass tries to upgrade nodes to higher-priority backends where the buffer type matches and the operation is supported. Backend priority is list order: lower index wins. Copies are inserted only where a split's input lives elsewhere.


## 4. Question 2 — The graph allocator (`ggml/src/ggml-alloc.c`)

### 4.1 The shape of the problem it solves

A compute graph's intermediate tensors are numerous, short-lived, and — crucially — known in full before execution: a ggml graph is a static list of nodes in execution order, each with named sources. The graph allocator (`ggml_gallocr`) exploits that total knowledge. It is created over one or more buffer types (`ggml_gallocr_new` / `ggml_gallocr_new_n` in `ggml/include/ggml-alloc.h`); duplicate buffer types are deduplicated so the same type used in two scheduler slots shares one underlying allocator and, ultimately, one buffer.

Underneath it, per buffer type, sits a **dynamic tensor allocator** (`ggml_dyn_tallocr` in `ggml/src/ggml-alloc.c`). It manages a small number of *chunks* (at most 16) — a chunk is the unit that will become one real backend buffer — each chunk carrying an address-sorted free-block list (at most 256 blocks) with neighbour merging on free. Allocation is best-fit with a deliberate bias: interior free blocks are considered first by tightest fit; the *last* block of a chunk (the frontier, whose growth extends the chunk) is considered separately, scored by how much of the chunk's already-simulated size would remain unused, so that growth is preferred where it wastes least. If nothing fits, a new chunk is started, sized at least to the allocator's maximum chunk size (derived from the buffer type's maximum buffer size) or to the tensor, whichever is larger; the final chunk is treated as effectively unbounded so planning cannot fail for lack of a chunk slot — the failure, if any, is deferred to real buffer allocation, where it can be reported (Section 7). Offsets are aligned to the buffer type's alignment throughout.

### 4.2 Liveness: reference counting over a static graph

Placement is computed by a simulation (`ggml_gallocr_alloc_graph_impl` in `ggml/src/ggml-alloc.c`) that walks the graph exactly as execution would:

1. **Count first.** Before placing anything, the simulation counts, for every tensor, its number of *children* (nodes that consume it as a source) and its number of *views* (view tensors based on it). Leaf tensors and tensors flagged as graph inputs are allocated up front, in non-overlapping space, precisely so later reuse can never overwrite them — the header contract in `ggml/include/ggml-alloc.h` states this for inputs explicitly.
2. **Views get no storage.** A view tensor (reshape, view, transpose, permute and kin — recognised structurally by having a view source) is never given its own allocation; it aliases its source's storage, and its existence instead extends the source's life through the view count.
3. **Allocate in execution order.** Each node's parents are ensured allocated, then the node itself (Section 4.3 for the in-place shortcut).
4. **Free on last use.** After a node is processed, each parent's child count is decremented; when a tensor's children *and* views both reach zero, its bytes return to its chunk's free list immediately, available to the very next allocations. Graph outputs are the exception: a tensor flagged as an output is never freed and never overwritten (also stated as a header contract), because the caller will read it after the graph finishes.

The simulation records, per node and leaf, the chosen buffer, the address (chunk plus offset), and the maximum size the tensor may occupy there. Those records — not the simulation's transient state — are what later graph allocations replay (Section 4.4).

### 4.3 In-place reuse: the second, sharper reuse

Independent of free-list reuse, a node may **inherit its parent's address outright** when its operation is one the source lists as safe to run in place (`ggml_op_can_inplace` in `ggml/src/ggml-alloc.c` — a closed list of elementwise and normalisation-style operations, with a source comment warning that operations returning true must not rely on restrict-pointer assumptions in their kernels). Inheritance is refused unless *all* of the following hold, each check visible in the allocation routine:

- the parent was allocated by this graph allocator (external tensors — weights, caller buffers — are never overwritten);
- neither the parent nor its view source is flagged as a graph output;
- parent and node have the same layout;
- the parent has **exactly one child** (this node) and **no views**.

A special case handles a parent that is itself a view: inheritance can pass through to the view's source when that source has exactly this one view, no other children, and the view's data pointer is the source's. When inheritance succeeds and the node is smaller than the parent, the surplus tail bytes are returned to the free list immediately, so in-place growth of the free pool happens even mid-"reuse". The effect of the two mechanisms together is that a chain of elementwise operations over one large tensor costs one tensor's storage, not a chain's worth — the single largest peak-memory saving in ordinary transformer graphs after KV itself.

### 4.4 When allocations are re-planned

The allocator separates *reserving* (running the simulation and materialising buffers) from *allocating a graph* (replaying a previous simulation's recorded addresses onto a new graph's tensors):

- **`ggml_gallocr_reserve` / `reserve_n`** runs the simulation and then materialises buffers: for each buffer type, if any chunk's simulated high-water mark exceeds the existing real buffer's chunk size (or no buffer exists), the old virtual buffer is freed wholesale and a new one is allocated at the new sizes, tagged as compute usage. Buffers only ever grow through this path; a reserve whose simulation fits inside the existing buffers keeps them. The multi-buffer form takes explicit per-node and per-leaf buffer assignments (supplied by the scheduler); the single-buffer form assigns everything to buffer 0.
- **`ggml_gallocr_alloc_graph`** is the fast path: it checks whether the recorded plan still fits the incoming graph — same node and leaf counts, and every tensor's current allocation size no larger than the size recorded for its slot (`size_max`). If it fits, addresses are replayed with no simulation and no buffer traffic. If it does not fit: with a **single** buffer type, the allocator re-reserves automatically; with **multiple** buffer types it *refuses* and returns failure, because re-planning could change which backend each node belongs to — the header states this contract, and the scheduler path (below) is responsible for re-splitting and re-reserving properly.
- **The scheduler's re-plan trigger** (`ggml/src/ggml-backend.cpp`): on graph allocation, the scheduler compares the new graph's per-node backend assignments and graph size against the previous allocation's. If assignments changed, or the replay fails, it synchronises, invokes an optional caller-supplied reallocation callback (the header notes this path "costs a synchronization of the backends"), re-reserves through the graph allocator, and replays. llama.cpp's context layer builds on this by reserving *worst-case* graphs up front (Section 6.3) precisely so that steady-state inference never pays this path.

### 4.5 What the allocator guarantees about peak usage — and what it does not

Stated carefully, because this is where secondary descriptions most often overclaim:

- **Guaranteed, by construction:** for the exact graph that was simulated, no two simultaneously-live tensors (under the child/view counting of Section 4.2, with outputs and inputs pinned as described) occupy overlapping bytes; every tensor's recorded slot is at least as large as the allocation size its buffer type charges for it; and the materialised buffer size equals the simulation's per-chunk high-water mark — no more, for that graph. Peak compute-buffer usage for a reserved graph is therefore *known exactly before execution*, which is what makes the memory estimation of Section 6 possible at all.
- **Not guaranteed:** any bound relative to a *different* graph. A graph with more tokens, more sequences, or a different backend assignment can need more, and will trigger Section 4.4's re-plan (or failure, in the multi-buffer replay case). There is no fragmentation bound: best-fit over an address-sorted free list with merging is a heuristic, and the high-water mark it produces is whatever the simulation reached, not a proven optimum. There is also no fairness or isolation between graphs sharing a scheduler over time — buffers are sized to the largest graph reserved since the last reset, and they do not shrink on their own.

## 5. Question 3 — Pooling behaviour: the CUDA/HIP scratch pools

### 5.1 Two pools in one file, selected per device

Scratch allocations inside CUDA/HIP kernels (temporary workspaces requested through the backend context's pool) are served by one of two implementations in `ggml/src/ggml-cuda/ggml-cuda.cu`, chosen when a pool is created for a device: a **debug pool** if the pool-debug environment flag is set; otherwise the **virtual-memory (VMM) pool** if the device reports VMM support; otherwise the **legacy pool**. A third fact matters as much: *backend buffers themselves* (weights, KV, graph-allocator compute buffers) do **not** go through these pools at all — a buffer-type allocation is a direct driver allocation of exactly the requested size (plus the growth described in Section 5.2 only where the legacy pool is the allocator). The pools serve transient, kernel-internal scratch whose lifetime is a single operation or graph step. Conflating "ggml pools GPU memory" (true, for scratch) with "ggml caches model buffers" (false) is the second common error this dossier exists to correct.

### 5.2 The legacy pool: best-fit free list, 5% look-ahead, flush-on-OOM

The legacy pool (`ggml_cuda_pool_leg`) keeps up to 256 cached blocks per device. Its behaviour, as implemented:

- **Allocation** first scans the cache for the smallest block that fits (best fit, with an exact-fit fast exit). Only on a miss does it allocate from the driver — and then it allocates **5% more than requested**, rounded up to a 256-byte multiple, explicitly as look-ahead so a slightly larger later request can reuse the block. The cached block's recorded size is the enlarged size.
- **Freeing returns the block to the cache, not to the driver.** A freed block sits in the pool, still resident in VRAM, until the pool is destroyed, the cache is flushed (below), or the cache is full: if all 256 slots are occupied when a block is freed, that block *is* returned to the driver immediately, with a debug log advising a larger pool cap.
- **On driver allocation failure**, the pool synchronises the device, **flushes its entire cache back to the driver**, invalidates any captured CUDA graphs (whose recorded addresses may have pointed into cached blocks — the source comment calls this out), and retries the allocation once. A second failure is fatal at this layer (Section 7).
- **Pool destruction** frees everything cached and asserts nothing remains accounted.

Growth behaviour under fragmentation follows directly: the cache is a set of whole, unsplit blocks. A request reuses a larger cached block *whole* (no splitting, no sub-allocation), so internal waste is the difference between block and request; the 5% look-ahead deliberately manufactures small amounts of that waste to buy reuse. There is no coalescing, because blocks are independent driver allocations. Under a churning mix of sizes the cache can therefore hold substantial resident-but-unused VRAM — bounded by the sum of the largest recent block in each of up to 256 slots — and the only reclamation pressure is the OOM flush and pool destruction. Nothing ages out on a timer.

### 5.3 The VMM pool: one reservation, bump allocation, stack discipline

Where the driver and device support virtual memory management (probed per device at backend initialisation, with the allocation granularity queried from the driver — `ggml/src/ggml-cuda/ggml-cuda.cu`, device-info setup; the VMM code is compiled when the platform headers provide it, per `ggml/src/ggml-cuda/common.cuh`), the pool (`ggml_cuda_pool_vmm`) is a different animal entirely:

- **Address space first, physical memory on demand.** The pool reserves a large virtual range once — up to 32 GiB — and halves that reservation repeatedly if the reservation itself reports out-of-memory, warning about the reduced ceiling. Physical backing is created and mapped only as allocations require it, in multiples of the driver's allocation granularity, appended at the end of the mapped region.
- **Allocation is a bump pointer.** Request sizes are rounded up to 128-byte alignment; the allocation is carved from the frontier; there is no free-list search because there is, structurally, nothing to search.
- **Freeing is stack-ordered, and enforced.** A free must exactly unwind the most recent live allocation — the implementation asserts that the freed pointer is precisely the frontier minus the freed size. Out-of-order frees are not handled; they are programming errors at this layer. Physical backing is **never unmapped during the pool's life**: the mapped region only grows, and the whole reservation and mapping are torn down only when the pool is destroyed.
- The same file's **debug pool** is the deliberate opposite: exact-size driver allocations, freed immediately on release, existing so memory-checking tools can catch overruns and use-after-free; it asserts zero outstanding bytes at destruction (a leak check).

For HIP/ROCm, the VMM path carries a platform workaround (mappings are tracked individually so they can be unmapped one by one at destruction, citing a ROCm runtime issue), but the allocation discipline is the same code.

### 5.4 What is returned to the driver, summarised

| Layer | On free | On destruction |
|---|---|---|
| Legacy scratch pool | Retained in cache (up to 256 blocks); returned only if cache full, on OOM flush, or at destruction | Everything returned |
| VMM scratch pool | Nothing (frontier rewinds; backing stays mapped) | Reservation released, all mappings torn down |
| Debug scratch pool | Returned immediately | Asserts nothing outstanding |
| Backend buffers (weights/KV/compute) | n/a — freed as whole buffers by their owner | Driver allocation released per buffer |

The operational consequence for a long-lived server is direct: **scratch-pool VRAM is high-water-mark VRAM.** Once a large scratch allocation has happened, that memory stays resident for the life of the backend context under both real pools, and external observers (including other processes and naive "free VRAM" readings) will see it as used. ggml's own device-memory queries report the driver's free/total figures, not the pools' internal state, so pool retention is invisible to the fit logic of Section 6 except insofar as the driver itself reports less free memory.


## 6. Question 4 — VRAM accounting: how memory is estimated before loading

### 6.1 The headline: at v1.0.0, the estimate is a measurement, not a formula

The single most consequential finding in this dossier is that llama.cpp's pre-load memory figure is **not** computed from architectural parameters (layers × hidden size × bytes-per-element and similar closed forms). It is *measured by dry-running the real machinery with allocation disabled*, in `common/fit.cpp`:

1. The model is loaded with allocation turned off (`no_alloc`) and the loader in a no-load mode. Tensor metadata, shapes, and buffer-type assignments are all real; the buffers created for weights are zero-sized dummies, and tensors are pointed at those dummies so the scheduler will not try to allocate them for real (`src/llama-model.cpp`).
2. A real context is created on that phantom model. Context creation reserves worst-case compute graphs (Section 6.3) — but in no-allocation mode the reserve path runs in its *size-only* form: the scheduler splits the graph and the graph allocator runs its full simulation, reporting the per-backend buffer sizes it *would* materialise, without materialising them (`ggml/src/ggml-backend.cpp`, the reserve-size entry point; `ggml/src/ggml-alloc.c`, the reserve-with-no-allocation implementation and its size-reporting variant).
3. The context's **memory breakdown** is then read out and summed per device (`src/llama-context.cpp`, `llama_context::memory_breakdown`, exposed publicly as `llama_get_memory_breakdown`).

Anything in the codebase that needs to know "how much will this take?" — the `--fit` logic, memory reporting — consumes that breakdown. The estimate inherits the allocator's exactness (Section 4.5) and its blind spots (Section 6.4) in equal measure.

### 6.2 What is counted: the three buckets

The breakdown is a map from buffer type to three components (`src/llama-context.cpp`; `src/llama-model.cpp` for the model part):

- **Model** — the sum over all model contexts of their buffer sizes. In a real load these are the materialised buffer sizes; in the no-allocation measurement they are recomputed by asking, per context, what its tensors would occupy under their assigned buffer types — which routes through each buffer type's own allocation-size function, so CUDA's quantised-row padding (Section 3.3) *is* included. mmap-wrapped weights count at their wrapped size on the host side; the accounting does not attempt to predict page-cache residency.
- **Context** — the memory module's own breakdown (the KV cache buffers and their auxiliary tensors, per buffer type — the KV addendum's Section 6.1 describes this from the cache's side), plus, when enabled, the MoE expert cache's breakdown. KV size here is the *allocated buffer* size for the configured context length, sequence count, and cache types — again a structural sum, not a per-token formula, although of course it scales with those parameters exactly as the cache's tensor shapes dictate.
- **Compute** — per backend, the graph allocator's materialised buffer size for the reserved worst-case graphs (or, in no-allocation mode, the expected sizes recorded during the size-only reserve). This is the prompt-processing and token-generation reserve of Section 6.3, whichever is resident.

Free and total memory per device are obtained separately, from the device properties (`ggml/include/ggml-backend.h`; the CUDA implementation queries the driver). The fit logic in `common/fit.cpp` places the breakdown beside those figures per device, treats host buffer types as belonging to a synthetic final "device" (the host), and — a detail worth stealing — refuses to assign work to a GPU-class device that reports 0 free / 0 total, rather than treating unknown as infinite, while allowing non-GPU accelerators that report 0/0 to fall back to the host budget.

### 6.3 The compute reserve: worst-case graphs, reserved in a deliberate order

`llama_context::sched_reserve` (`src/llama-context.cpp`) constructs the measurement the compute bucket reports. It builds a micro-batch at the largest relevant shape — token count the smaller of context size and micro-batch size, all sequences — and reserves, in order: the prompt-processing graph, then the token-generation graph, then the prompt-processing graph *again*, so the resident buffers are sized for the larger of the two and no reallocation occurs when inference alternates between them. Two architecture-specific exceptions adjust which shape is truly worst-case (the source tags a decay-tensor case whose single-sequence graph is larger than its multi-sequence one). The expected per-backend sizes are recorded at reserve time, and the context destructor later *verifies* them: if the scheduler's actual buffer sizes at teardown differ from the recorded expectation (and the model was really allocated, and no training optimiser has legitimately grown them), it logs a warning. Estimation drift is thus treated by the project as a detectable defect, not as noise — a posture Section 9 recommends copying.

### 6.4 What is estimated by formula, and what is not counted

- **Formula-estimated:** essentially nothing in the headline path. The older style of llama.cpp memory folklore — hand-derived bytes-per-token tables, fixed per-layer overheads — is not what v1.0.0's fit path does. Where closed-form arithmetic does appear, it is inside tensor *shapes* (KV dimensions from hyperparameters, activation dimensions from batch shape), which the dry run then prices exactly through the allocators.
- **Counted but easy to miss:** CUDA scratch-pool retention (Section 5.4) is *not* a line in the breakdown; it appears only as reduced driver-reported free memory after the fact. Captured CUDA graphs, driver context memory, and any other process's residency are likewise outside the breakdown — fit compares its three buckets against driver free memory, so those consumers are handled only implicitly, as shrinkage of "free".
- **The Ollama-consumption link — unverified.** This dossier read the ggml/llama.cpp side at the pin. How Ollama's own scheduler obtains or adapts these figures (Ollama vendors its own llama.cpp integration and its scheduler has its own VRAM estimation history) was **not** read for this dossier, and no claim is made here about which of the mechanisms above Ollama actually calls at any given Ollama version. Treating "llama.cpp measures by dry run" as "Ollama's scheduler therefore measures by dry run" would be an inference, and it is marked **unverified**.

### 6.5 The fit loop built on the measurement

For completeness: `common/fit.cpp`'s fitting procedure re-runs the Section 6.1 measurement repeatedly — starting from the requested parameters, checking per-device margins against free memory, and adjusting the knobs it is allowed to touch (GPU layer count and its fractional-layer refinement, context size when it was left automatic, and related settings) until the measured breakdown fits with the requested margins, or it concludes it cannot fit. Tensor-split mode is explicitly excluded: fitting throws for it, matching the meta mode's documented "no auto-fit" status (Section 3.4). Each iteration is a full phantom load and context creation, which is why the fit code goes to lengths to suppress and reroute logging during measurement — the measurement is an expensive, real execution of the loading path, not a lookup.

## 7. Question 5 — Failure behaviour

### 7.1 Mid-load failures: exceptions at the llama layer, null returns at the ggml layer

The two layers fail differently, and the seam matters:

- At the **ggml buffer-type layer**, allocation failure is a *value*, not an abort: the CUDA buffer-type allocator logs the size, device, and driver error and returns a null buffer (`ggml/src/ggml-cuda/ggml-cuda.cu`); the CPU buffer-type allocator logs and returns null likewise (`ggml/src/ggml-backend.cpp`). The generic zero-size case never reaches a backend at all — it returns a dummy buffer (`ggml/src/ggml-backend.cpp`).
- At the **llama model layer**, a null buffer is immediately fatal to the load: model loading converts it into a thrown runtime error naming the buffer type ("unable to allocate … buffer"), aborting model creation (`src/llama-model.cpp`). There is no retry with fewer layers, no spill of the offending context to CPU, and no partial-load success state inside the library: fitting must happen *before* loading (Section 6.5), because loading itself does not negotiate.
- The **static bump allocator** is the harsh exception inside ggml: if a tensor does not fit in its fixed buffer, it logs the tensor name and shortfall and aborts the process (`ggml/src/ggml-alloc.c`). Callers use it only where sizes are pre-computed, so the abort is an assertion of a programming error rather than an expected runtime path — but a fork reusing the utility should know which contract it is importing.

### 7.2 Mid-inference failures: reserve returns false, the context throws, one graceful retry exists

- The graph allocator's reserve path returns **false** if a compute buffer cannot be materialised, logging the buffer type and size (`ggml/src/ggml-alloc.c`). The replay path returns false in the multi-buffer re-plan case (Section 4.4) without even attempting allocation.
- The scheduler propagates allocation failure as a false return from its graph-allocation entry points (`ggml/src/ggml-backend.cpp`).
- The context layer converts reserve failure into a thrown runtime error ("failed to allocate compute … buffers") during context creation or re-reserve (`src/llama-context.cpp`) — *except* for one designed retry: if the prompt-processing reserve fails while pipeline parallelism is enabled, the context logs a warning, disables pipeline parallelism, rebuilds its scheduler, and retries the reserve once before giving up. That is the only mid-inference allocation fallback found at this layer.
- Inside the CUDA scratch pools, failure handling is the legacy pool's flush-and-retry-once (Section 5.2); if the retry also fails, the pool's error checking aborts rather than returning an error to the kernel that requested scratch. The VMM pool likewise treats driver mapping failures as fatal checked errors, with the single softened case being the initial virtual-reservation halving (Section 5.3). Scratch OOM is therefore, in practice, a process-fatal event wearing a retry's clothing.
- **No automatic CPU fallback exists inside ggml's allocators.** A graph node runs on CPU because the scheduler *assigned* it there (unsupported operation, offload policy, weights resident there) — a planning decision made before allocation — never because a GPU allocation failed at run time and the node was re-homed. Designs that want OOM-triggered CPU spill must build it above ggml, at the fit/scheduler-policy level, before the failing reserve happens.

### 7.3 The one true allocator fallback: pinned → ordinary host memory

For completeness, the single place a ggml allocator silently substitutes a cheaper memory kind: the CUDA host buffer type falls back to a plain CPU buffer when its pinned allocation fails (`ggml/src/ggml-cuda/ggml-cuda.cu`). The cost is copy speed, not correctness, which is presumably why this substitution is tolerated where device-memory substitutions are not.

## 8. Strengths and weaknesses, as engineering

**Strengths.**

- *Estimation by dry run.* Pricing a load by simulating the real allocators over the real graph (Section 6) eliminates an entire class of formula-drift bugs. The estimate cannot silently diverge from the allocator, because it *is* the allocator, run in a no-materialise mode.
- *Static-graph liveness done simply.* Child/view counting over a known execution order, plus a tightly-gated in-place inheritance, gets most of the attainable reuse with machinery a single engineer can hold in their head (Section 4). Peak compute memory is known before execution, exactly.
- *Failure contracts are mostly honest values.* Null buffers and false returns at the seams (Sections 7.1–7.2) let the layer above decide policy; the project then actually exercises that freedom (fit before load, pipeline-parallel retry).
- *The VMM scratch pool is the right shape for scratch:* one reservation, granularity-priced growth, zero search, and a stack discipline that matches how kernel temporaries actually nest.
- *Backend allocation-size overrides* let kernels' real padding costs live in exactly one place per backend, and all accounting flows through them (Sections 3.3, 6.2).

**Weaknesses.**

- *Two scratch pools, two failure personalities.* Legacy and VMM pools differ in reuse geometry, reclamation, and fragmentation behaviour, selected by a device capability the operator may not know they are exercising. Behaviour on an older card is not behaviour on a newer one, and neither pool ever returns scratch memory to the driver while the process lives.
- *Buffers only grow.* The graph allocator's materialised buffers are sized to the largest graph reserved and never shrink outside a reset/reserve cycle. A server that once reserves a worst case pays for it forever — by design, but the design's cost lands on exactly the small-VRAM machines that can least afford it.
- *Abort paths inside a library.* The bump allocator's hard abort and the scratch pools' checked-fatal driver errors mean "allocation failed" can still mean "process died", depending on which allocator was serving. The seams documented in Section 7 must be learned, not assumed.
- *No cross-anything accounting.* ggml cannot answer "how much VRAM does this process hold?" in its own terms — the breakdown covers model/context/compute for one context, while pools, graphs, driver context, and other contexts sit outside it. Every embedding product rebuilds this ledger itself, with varying honesty.
- *Multi-buffer re-planning is brittle by contract.* The replay path's refusal to re-plan multi-backend graphs (Section 4.4) pushes a synchronisation and re-reserve onto the scheduler at the worst moment (mid-serving, on shape change), and the callback that reports it exists precisely because the cost is user-visible.

## 9. Judgment: what the fork should steal, and what it should deliberately do differently

*This section is our judgment, labelled as such; everything above is description of the sources. Cross-references are to this corpus: IDEA-LEDGER #41 (weight-arena VM discipline) and `memory/allocator-lineages.md` (whose §5.3 and §7.1 argue that a Go runner's tensor and KV memory should live outside the GC heap, in purpose-built arenas whose counters are the budget).*

**Steal:**

1. **Dry-run measurement as the only estimator.** Build the fork's scheduler estimates the way `common/fit.cpp` does at v1.0.0: phantom-load with allocation disabled, reserve the worst-case graphs in size-only mode, and read a per-device breakdown of model / context / compute. This composes directly with the allocator-lineages dossier's Go routing: the dry run is cheap to expose across the cgo boundary because it produces three numbers per device, not a data structure — and those numbers, not Go's `MemStats`, become the scheduler's budget, exactly as that dossier prescribes for off-heap arenas.
2. **The three-bucket breakdown as a public, stable shape.** Model, context, compute, per device, with host memory as an explicit bucket. It is the smallest accounting vocabulary that has ever sufficed, and the fork should adopt it verbatim as its ledger format — including ggml's rule that a GPU-class device reporting unknown memory is treated as unusable for fitting, never as infinite.
3. **Child/view liveness counting with gated in-place inheritance**, if the fork ever places its own graphs. The gate list in Section 4.3 (own allocation only, never outputs, same layout, single child, no views) is a complete, field-tested safety condition; do not loosen it casually.
4. **The VMM arena pattern for scratch and, by extension, for the KV arena of IDEA-LEDGER #4:** reserve address space once, map physical backing at driver granularity on growth, bump-allocate, never unmap mid-life. ggml's VMM pool is independent confirmation, from the incumbent's own codebase, of the expandable-arena preference the corpus already recorded from the framework side (`memory/gpu-memory-internals.md`).
5. **Expected-vs-actual verification at teardown.** Recording reserve-time expected buffer sizes and warning when reality drifts (Section 6.3) is a nearly free integrity check. The fork should log its arena high-water marks against the dry-run prediction on every unload.

**Deliberately do differently:**

1. **Give the weight arena the VM discipline ggml does not attempt (IDEA-LEDGER #41).** ggml's weights buffers are plain driver allocations or mmap wraps chosen by the loader; nothing in ggml prefaults deliberately, requests huge-page alignment, or verifies huge-page residency. #41's discipline — 2 MiB-aligned arenas, deliberate parallel prefaulting so first-touch faults never land inside generation, residency verified rather than assumed — is *additive* to everything in this dossier and is the fork's clearest cheap win on cold-load latency. Where ggml's mmap-wrap path (Section 3.1) is used, #41 is precisely the policy layer it lacks.
2. **Make scratch/pool retention a first-class ledger line.** ggml hides pool retention inside driver free-memory shrinkage (Sections 5.4, 6.4). The fork's ledger should report reserved-by-pools separately from allocated, per the five-number discipline the corpus already adopted elsewhere, so that "where did the VRAM go?" never requires reading a vendor tool.
3. **Never import an abort as an allocation contract.** Where the fork wraps ggml (or reimplements these allocators), every allocation path the server can reach must return an error the scheduler can act on. ggml's bump-allocator abort is safe only under its pre-computed-sizes assumption; a fork that routes dynamic shapes through anything similar will eventually die mid-request instead of shedding load.
4. **Plan the OOM→CPU-spill decision at fit time, in the open.** ggml's silence on run-time fallback (Section 7.2) is defensible for a library; for the fork's *product*, the equivalent decision — fewer GPU layers, smaller context, CPU spill of named layers — should be made by its fit loop before load and disclosed in the load record, never improvised after a failed reserve. The one graceful retry ggml does have (dropping pipeline parallelism) is the model: a named, logged, single-step degradation.
5. **Shrink, or at least re-reserve downward, on sustained shape change.** ggml's grow-only compute buffers are the right default for a library that cannot know serving patterns; a single-user fork *can* know (its worst case is its configured context and parallelism), so its reserve should be sized to configuration, not to the largest transient it has ever seen — and re-reserving smaller after a configuration change should be a supported, tested path.

## 10. Sources and verification notes

All sources are from ggml-org/llama.cpp at tag **v1.0.0** (annotated tag object `a6d1a74dbebce3a16f4f2ceddbf38c21a08d8674`; commit `b1b770d90d94cad9e9ea5b993bdbc383a522fb28`; tagged 2026-11-13T10:20:13Z), read **2026-11-15** as raw file views of the tag, except where marked secondary.

**Primary — ggml headers:**
- `ggml/include/ggml-backend.h` — device types and capabilities, buffer-type/buffer/backend vocabulary, buffer usage values, scheduler contract and its worked example, reallocation-callback documentation, split-buffer-type procedure (marked as the old path), meta-device constants.
- `ggml/include/ggml-alloc.h` — tensor and graph allocator contracts: input/output tensor guarantees, reserve/alloc-graph semantics including the multi-buffer re-plan refusal, size-only reserve variant.
- `ggml/include/ggml-cuda.h` — CUDA/HIP backend surface: per-device and host buffer types, device cap of 16, device memory query.

**Primary — ggml implementation:**
- `ggml/src/ggml-alloc.c` — bump allocator and its abort-on-overflow; dynamic tensor allocator (chunks, free blocks, best-fit and frontier scoring); virtual buffers over chunked backend buffers; graph allocator (hash bookkeeping, child/view counting, view handling, in-place conditions and extra-space return, free-on-last-use, reserve materialisation and growth rule, replay validity check and single- vs multi-buffer re-plan behaviour).
- `ggml/src/ggml-backend.cpp` — CPU and CPU_Mapped buffer types; generic allocation-size/alignment defaults; tensor-packing plan for context allocation; multi-buffer wrapper; scheduler (assignment passes, split construction, copy insertion, re-plan trigger and callback invocation, reserve/reserve-size entry points).
- `ggml/src/ggml-cuda/ggml-cuda.cu` — per-device buffer type (128-byte alignment, quantised row-padding allocation size, null-on-failure allocation); pinned host buffer type and its CPU fallback; scratch pools (legacy best-fit cache with 5%/256-byte look-ahead, 256-block cap, flush-and-retry-on-OOM with CUDA-graph invalidation; VMM pool with 32 GiB reservation halving, granularity growth, bump allocation, stack-order free assertion; debug pool); VMM device probing.
- `ggml/src/ggml-cuda/common.cuh` — VMM compilation gating and per-device VMM fields (granularity).
- `ggml/src/ggml-backend-meta.cpp` — meta device for tensor parallelism: split-state propagation with per-operation handlers. (Read for structure and split-state rules; not every operation handler was read line by line.)

**Primary — llama layer (for Sections 6–7):**
- `src/llama-model.cpp` — phantom (no-allocation) load mechanics, mmap buffer wrapping per context range, weights usage tagging, null-buffer-to-exception conversion, model memory breakdown.
- `src/llama-model-loader.cpp` — per-tensor buffer-type lists and the selection walk (input/output/layer/CPU lists).
- `src/llama-context.cpp` — worst-case reserve order (prompt-processing, token-generation, prompt-processing again) and its exceptions, pipeline-parallel reserve retry, expected-size recording and teardown verification, context memory breakdown aggregation.
- `common/fit.cpp` — the measurement procedure (phantom load plus real context), per-device margin accounting including the host bucket and the 0/0-device rules, the iterative fit loop, and the tensor-split exclusion.

**Primary — project documentation:**
- `docs/multi-gpu.md` — the three split modes as the project presents them at this tag: layer (default), row (deprecated), tensor (experimental, with its preconditions and the no-auto-fit limitation).

**Secondary (corroboration only, not load-bearing):**
- Release coverage of v1.0.0 (2026-11-13/14) for the matching build number `b12359` and the release's framing as ggml's and llama.cpp's joint first semantic version. Tag and commit identity were verified directly against the Git host's tag reference, not taken from coverage.

**Explicitly unverified in this dossier:**
- How Ollama's own scheduler consumes (or replaces) llama.cpp's memory breakdown and fit machinery at any Ollama version (Section 6.4). The ggml/llama side is verified; the Ollama side was out of scope and not read.
- The deprecated row-split path's current internals (Section 3.4) — its existence, declaration, and deprecated status are verified; its allocation behaviour is not.
- The full catalogue of backend-specific extra buffer types and their per-type acceptance rules (Section 3.1).
- Per-device VMM granularity values on specific hardware (the value is driver-queried at runtime by design; no constant exists in source to report).
- Whether captured-CUDA-graph invalidation has costs or failure modes beyond the legacy pool's flush path (the invalidation itself is verified; its downstream effects were not traced).
- Anything on master after the v1.0.0 tag.

*End of dossier — OR-2, read and written 2026-11-15.*
