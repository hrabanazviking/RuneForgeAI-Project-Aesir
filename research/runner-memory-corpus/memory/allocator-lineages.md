# Allocator Lineages and Designs — The Discipline of Allocation Itself

**Dossier OR-6 (Memory Domain) — Ollama Research Forge**
**Commissioned by:** Volmarr Wyrd, 2026-11-15
**Date of research:** 2026-11-15 (all web sources accessed 2026-11-15)
**Companion dossier:** `mimiralloc-our-own-proven-work.md` in the same directory — Volmarr's own allocator, proven on two hardware lines. This dossier does not re-derive that record; it places it in lineage.
**Readers:** Yrsa engineering (a) the improved Ollama in Go, (b) Aesir, (c) future allocator work.
**Clean-room note:** Written in our own words from public papers, manuals, and source documentation listed in §8. No text is copied beyond short factual labels (names of structures, size-class counts, option names). Where a judgement goes beyond a cited source it is marked **[Engineering judgement]**.

---

## 1. Header + Essence: What Each Generation Solved That the Previous Could Not

An allocator has one job stated three ways that pull against each other:

1. **Space:** give back a block at least as large as requested, wasting as little as possible — now and after thousands of interleaved frees.
2. **Time:** do it in a handful of instructions in the common case.
3. **Concurrency:** do it from many threads/cores without serialising the whole program on one lock or one cache line.

Every generation in this dossier is a response to the previous generation failing one of those three under a new workload reality.

| Generation | Representative designs | The wall the previous generation hit | The move that broke through it |
|---|---|---|---|
| Single-heap, exact-fit era (1970s–1990s) | dlmalloc (Doug Lea, from 1987) | Naive first-fit over one free list was slow and fragmented badly on real C/C++ loads; special-purpose allocators proliferated per class. | Boundary tags for O(1) neighbour coalescing + many size-sorted bins approximating best-fit. One heap, done well, was *good enough* for single-threaded programs. |
| Thread era (2000–2006) | Hoard (2000), tcmalloc (2005–), ptmalloc2/glibc arenas | One global lock + one heap collapsed on multiprocessors: lock contention, cache-line ping-pong, and *false sharing* — two threads' objects sharing a cache line — plus *blowup* where per-thread heaps each retain memory no other thread can reuse. | Give up the single heap. Shard it: per-processor / per-thread caches in front of a shared middle/back end, transfer in batches, and bound how much idle memory any one shard may hoard. |
| Scale-and-return era (2006–2019) | jemalloc (2006), modern tcmalloc | Thread caches alone left two problems: (a) long-running servers grew RSS and never gave it back, even when live data was flat; (b) at hundreds to thousands of threads, cache and arena counts themselves became a fragmentation source. | Treat *returning memory to the OS* as a first-class, tunable, time-based policy (decay/purging), expose it through introspection (`mallctl`), and let applications supply their own backing memory via extent hooks. Add per-CPU (not just per-thread) front ends. |
| Locality-first era (2019–) | mimalloc (2019) | Even with arenas and thread caches, a single free list per size class scatters objects allocated together across the heap, thrashes caches, and forces atomic/locked coordination on cross-thread free — the dominant pattern in reference-counted languages where the producer and consumer are often different threads. | Shard the free list itself: many small free lists, one set per page, and *three* lists per page so local free, local alloc, and remote free never contend on the same head pointer. Eagerly purge a page the moment it becomes empty. |
| Fixed-shape world (parallel lineage, 1994–) | Slab (Bonwick 1994) → SLAB/SLUB in Linux; arenas/regions; bump allocators; KV block pools | General allocators pay per-object metadata, search, and fragmentation costs even when *every object in a subsystem has the same size and the same lifetime* — kernel objects, compiler AST nodes, per-request scratch, KV blocks. That generality is pure overhead there. | Refuse generality. One size per cache/pool, allocate by popping a free list or bumping a pointer, free by returning to the pool or by resetting the whole arena at once. Fragmentation is designed out, not managed. |

The through-line for a model runner is blunt: **a runner is not a general allocator workload.** Weights are a few huge, long-lived extents. The KV cache is a growing, append-mostly pool of identically-shaped blocks per layer. Per-step scratch is arena-shaped — allocated and dead within one decode step. Only the surrounding server code (HTTP, JSON, scheduling) looks like a general `malloc` workload. The lineage below matters because each of those four shapes has a different *right* allocator, and using the general one for all of them is how runners waste VRAM and RSS.

---

## 2. The Lineage Walk

### 2.1 dlmalloc — single heap, boundary tags, bins

**Source basis:** Doug Lea, *A Memory Allocator* (design essay, maintained from the 1987 codebase; version discussed here is the 2.x line described in the essay and in the `malloc.c` header comments). Accessed 2026-11-15 via the Tufts archive copy [S1].

**Core data structures.**

- **Chunk.** The unit of allocation. Every chunk carries size/status in a header word before the user payload. In the original form a matching size field also sat at the *end* of the chunk — the *boundary tag*. Later versions omit the trailing tag on in-use chunks (it is never consulted while the chunk is live) to save space, reconstructing it from the next chunk's header on free.
- **Boundary-tag coalescing.** Because a chunk can find its physical neighbours from size fields alone, `free()` can merge with a free predecessor and/or successor in constant time. Coalescing is the anti-fragmentation workhorse: without it the heap decays into unusable crumbs.
- **Bins.** Free chunks are held in 128 bins, grouped by size — exactly one size per bin below 512 bytes (8-byte spacing, matching alignment), approximately logarithmically spaced above that. Search proceeds smallest-first, i.e. an approximation to *best-fit*: take the smallest free chunk that satisfies the request, splitting it if it is larger and returning the remainder to a bin.
- **Top / wilderness chunk and `mmap` path.** The chunk at the break (`sbrk`) edge can be extended or trimmed; very large requests bypass bins entirely via a separate `mmap` mapping so a single large free does not pin the main heap.

Lea categorises the policy himself as *best-fit with coalescing*. Minimum chunk size in the classic design is 16 bytes on 32-bit (24 bytes on 64-bit in later variants) — header plus free-list pointers must fit in a freed chunk, so tiny allocations pay a fixed tax.

**Fragmentation strategy.** Best-fit placement (Wilson et al. 1995 found best-fit variants tend to produce the least fragmentation on real traces among general policies — see §4) + immediate coalescing on free + splitting remainders back into bins. Locality is a secondary heuristic: chunks allocated together tend to live/die together, so the allocator biases toward keeping temporal neighbours physically near, restricted to cases where it does not wreck best-fit.

**Thread strategy.** Essentially none in the original design — dlmalloc is a single-heap, single-lock (or no-lock, caller-serialised) allocator. The header comments state it is not designed for multiprocessing use without external synchronisation. Its descendant ptmalloc2 added multiple arenas and locks for glibc; that is ptmalloc's addition, not dlmalloc's.

**Return-memory-to-OS strategy.** Trim the top chunk when it grows past a threshold (`mallopt` `M_TRIM_THRESHOLD`) and return whole `mmap`'d large chunks on free. Interior free chunks are *not* returned — they cannot be, they are holes in the middle of the heap. This asymmetry (only the top can shrink) is the defining RSS behaviour of the entire single-heap family.

**Known failure modes.**

- **Lock serialisation** under threads — the reason the next generation exists.
- **Best-fit slivers:** best-fit tends to create many tiny remainders just below usable size. Sorted bins and oldest-first tie-breaking mitigate but do not eliminate this.
- **Tiny-object tax:** the 16/24-byte minimum makes dlmalloc a poor fit for programs allocating millions of sub-16-byte nodes.
- **Top-pinning:** one long-lived allocation near the top of the heap prevents all trimming beneath it, so RSS reflects the high-water mark, not live data.
- **No compaction:** pointers are raw addresses; a live block can never be moved. Fragmentation, once created, can only be worked around by placement, never undone (see Robson, §4).

**Why it still matters.** dlmalloc is the clearest statement of the single-heap optimum, and its vocabulary — chunk, bin, coalesce, split, top — is the vocabulary every later allocator either reuses or deliberately rejects. MimirAlloc's small-object core sits recognisably in this family (size classes + span management under one lock), which is precisely why its measured costs match this family's known costs — see §7.3.

### 2.2 Hoard — per-processor heaps + superblocks (the thread-era proof)

**Source basis:** Berger, McKinley, Blumofe & Wilson, *Hoard: A Scalable Memory Allocator for Multithreaded Applications*, ASPLOS 2000 [S2]. Accessed 2026-11-15 via the UT Austin technical report and presentation summaries.

**Core data structures.**

- **Superblock.** A fixed-size, page-multiple block (8 KiB in the evaluated configuration) carved entirely into blocks of *one* size class, with a free list threaded through its free blocks in LIFO order. A superblock belongs to exactly one heap at a time.
- **Per-processor heaps + one global heap.** `P` heaps for `P` processors, plus heap 0, the global heap. A thread hashes to a heap, locks only that heap, and allocates/frees within its superblocks. Large requests (> half a superblock) bypass the machinery and come straight from the OS.
- **Emptiness discipline.** Each heap tracks allocated bytes `a_i` and used bytes `u_i`. When a heap's free fraction crosses a threshold — in the paper, `f = 1/4`, `K = 0`, i.e. roughly when at least a quarter of its retained memory is empty beyond a small allowance — it transfers a (mostly empty) superblock to the global heap, where any other heap can claim it.

**Fragmentation strategy.** Two distinct enemies are named and treated separately. *False sharing* (actively induced, by handing adjacent small blocks in one cache line to different threads; passively induced, by interleaving lifetimes) is avoided by never splitting a superblock or a cache line across heaps — a superblock's blocks are only handed out by its owning heap. *Blowup* — the unbounded growth of total retained memory when each private heap keeps its own free memory — is bounded provably by the emptiness-transfer rule: total retained memory stays within a bounded factor of the single-heap optimum, rather than growing with processor count.

**Thread strategy.** One lock per heap, not one per allocation in the uncontended conceptual model: `malloc` takes one heap lock, `free` at most two (when the freed block's superblock must move). Producer–consumer patterns (thread A allocates, thread B frees) are the acknowledged worst case, serialising on the owning heap, but the paper argues empirically only a small fraction of frees are remote.

**Return-to-OS strategy.** Indirect: superblocks migrate to the global heap for *reuse by other heaps* rather than being returned to the OS promptly. Hoard optimises for reuse across processors, not for RSS shrinkage.

**Known failure modes.**

- Producer–consumer heavy workloads still contend on the owning heap.
- Superblock granularity wastes space when a size class has low occupancy — a nearly-empty superblock still pins its full extent in its heap until the emptiness rule fires.
- The thresholds `f` and `K` are workload-sensitive; the paper's values are tuned, not universal.

**Legacy.** Hoard proved three things the field then took as given: per-processor sharding scales linearly where a global lock does not; false sharing is an *allocator* bug, not an application bug; and any sharding scheme without a rebalancing rule will blow up. tcmalloc and jemalloc are both, in part, engineering answers to Hoard's remaining costs.

### 2.3 tcmalloc — thread caches + size classes + span management

**Source basis:** Ghemawat & Menage, original tcmalloc design document (perftools), and Google's current *TCMalloc design* documentation (Abseil-era, covering per-CPU mode, transfer cache, and hugepage-aware page heap) [S3][S4]. Accessed 2026-11-15.

**Core data structures — three tiers.**

- **Front end: per-thread, now per-CPU, cache.** One singly-linked free list per size class per cache. Allocation/deallocation in the common case touches only this cache — no lock, no atomic. Modern tcmalloc prefers *per-CPU* caches (using Linux restartable sequences, `rseq`, to update a CPU's cache without locking even under preemption) because per-thread caches made footprint scale with thread count. Legacy per-thread mode caps total cached bytes (`SetMaxTotalThreadCacheBytes`, with a 512 KiB minimum per thread cache in the documented implementation) and scavenges capacity between threads.
- **Size classes.** Small objects (≤ 256 KiB in current documentation; ≤ 32 KiB in the original perftools document — the threshold has grown across versions, and any citation must name its version) map to roughly 60–90 size classes depending on page-size variant (documented variants: 86 classes at 8 KiB pages, 78 at 32 KiB, 89 at 256 KiB, 46 in the small-but-slow configuration). Spacing grows with size (8 bytes, then 16, 32, … up to a capped maximum) so rounding waste — internal fragmentation — is bounded as a fraction, not an absolute.
- **Middle end: transfer cache + central free lists.** One per size class, each mutex-protected. The transfer cache is a simple array of pointers optimised for the cross-CPU flow (one CPU allocates what another frees); the central free list holds objects carved from spans and refills the transfer cache in batches, amortising its lock.
- **Back end: page heap + spans + pagemap.** Memory from the OS is held in *spans* — runs of contiguous TCMalloc pages (8 KiB default in current docs; 4 KiB in the original). A span is either a large object, or is split into equal small objects of one recorded size class. A 2- or 3-level radix-tree *pagemap* maps any address → its span → its size class, which is how `free(ptr)` with no size argument finds where the object belongs. Free spans live in the page heap in size-indexed lists and are split/coalesced best-fit style — dlmalloc's logic, lifted to page granularity.

**Fragmentation strategy.** Size-class rounding bounds internal fragmentation by construction. External fragmentation is fought at the span layer: spans coalesce with neighbours on free, large allocations best-fit over free spans, and freed memory can be *repurposed across size classes* (a span's class is a property of its current use, not its identity) — a flexibility Hoard's fixed superblocks lack. The hugepage-aware page heap additionally tries to keep hugepage-sized regions homogeneous so they can be released or backed by huge pages whole.

**Thread strategy.** No lock on the fast path; batch transfer through the middle end; per-CPU mode removes even the thread-count scaling problem. The cost moved, deliberately, to the refill path.

**Return-to-OS strategy.** The page heap can release whole free spans back to the OS (`MallocExtension::ReleaseFreeMemory` and periodic/background release in modern builds). Release is span-granular: a span with one live object cannot be partially released. Historically tcmalloc was conservative about release, favouring reuse; operators of long-running servers tuning for RSS have had to configure release rates explicitly — a recurring operational complaint that is documented behaviour, not a bug.

**Known failure modes.**

- **Cache retention:** front-end + transfer caches hold freed objects for reuse; aggregate retained memory scales with CPUs (per-CPU mode) and can surprise operators reading RSS.
- **Span pinning:** one long-lived small object pins its entire span (and, for hugepage accounting, potentially its hugepage region).
- **Large thread/CPU counts** stress the middle end; batch sizes and cache caps are tuning-sensitive.
- **Version drift in the numbers:** size-class counts and the small/large threshold differ materially between the 2005 perftools document, Chromium's fork, and current google/tcmalloc. Folklore that quotes "88 size classes, 32 KiB" without a version is quoting the oldest document as if it were current. Flagged here per the dossier's quality law: those figures are real, but version-bound.

### 2.4 jemalloc — arenas, size classes, decay-based purging, extent hooks

**Source basis:** Evans, *A Scalable Concurrent malloc(3) Implementation for FreeBSD*, BSDCan 2006 [S5]; jemalloc manual (5.3.x line), `mallctl` namespace and tuning documentation [S6][S7]. Accessed 2026-11-15.

**Core data structures.**

- **Arenas.** The heap is partitioned into multiple independent arenas (default historically 4× CPU count in the 2006 design; tunable via `opt.narenas`). Threads are assigned to arenas (round-robin/per-CPU modes via `opt.percpu_arena` in later versions) so contention is divided by arena count rather than eliminated per-thread. Each arena manages its own extents, bins, and purging independently.
- **Extents (2006: chunks/runs).** In the 2006 paper, memory came in large *chunks* split into *runs* of contiguous pages, each run serving one size class for small objects, tracked by bitmaps within the run. The modern allocator generalises chunks/runs to *extents* — contiguous virtual ranges with explicit state (active / dirty / muzzy / retained) managed through an extent-management layer that applications can replace (extent hooks, below).
- **Bins + thread cache (`tcache`).** Per-arena bins hold free small objects per size class, protected by bin locks; a per-thread cache in front makes the common case lock-free, with capped per-class counts and periodic flushing so caches cannot hoard unboundedly (the 2006-lineage teaching material quantifies the synchronisation reduction at roughly 10–100×). Large allocations (historically > chunk-fraction thresholds; oversize requests > `opt.oversize_threshold`, default 8 MiB, are segregated into a dedicated arena) go through the extent layer directly.
- **Size classes.** Quantised like tcmalloc's but with jemalloc's own spacing table, chosen (per Evans) to bound internal fragmentation while keeping metadata overhead under ~2% excluding fragmentation.

**Fragmentation strategy.** Three layers: (1) size-class quantisation + low-address-preferring placement inherited in spirit from phkmalloc; (2) arena isolation, which contains one subsystem's fragmentation from poisoning another's — and, with *explicit* arenas (`arenas.create`, `MALLOCX_ARENA`), lets an application deliberately segregate lifetimes (this is the hook a runner would use: one arena for weights, one for KV, one for scratch); (3) segregation of oversize allocations so huge extents never interleave with small-object runs.

**Thread strategy.** Arena sharding × tcache. Contention is a tunable: more arenas = less contention, more fragmentation/retention. jemalloc's documented sweet spot is very high thread counts (hundreds to thousands), where tcmalloc's central lists can become the hotter spot — a workload-dependent comparison, not a universal ranking.

**Return-to-OS strategy — jemalloc's signature contribution.** Freed pages move through explicit states: *dirty* (free, contents intact, reusable without OS work) → *muzzy* (purged with a lazy `madvise` such as `MADV_FREE`; contents may survive until the kernel needs the page) → *retained* (virtual address kept, physical backing released). Purging is *decay-based*: `opt.dirty_decay_ms` and `opt.muzzy_decay_ms` set approximate exponential-decay times (defaults have varied by release; 5.3-era tuning guidance discusses values from 1 s aggressive to 30 s throughput-favouring) after which unused dirty/muzzy pages are purged. `background_thread:true` moves purging off application threads onto jemalloc's own workers, trading a thread for smoother tail latency. Operators can force the issue per arena via `arena.<i>.purge` / `arena.<i>.decay` `mallctl` calls. No other allocator in this lineage makes the speed-vs-RSS trade-off this explicit or this tunable — which is why jemalloc became the default answer for long-running servers (Redis, Firefox, Meta services) whose RSS behaviour is operationally visible.

**Extent hooks.** `arena.<i>.extent_hooks` lets an application replace how an arena obtains, commits, decommits, purges, splits, and merges its backing memory. Documented uses include backing an arena with 1 GiB huge pages (HHVM) to cut TLB misses. **[Engineering judgement]** For a runner, extent hooks are the cleanest documented mechanism in any general allocator for saying "this arena is backed by pinned/huge/GPU-adjacent memory and must never be purged on the general policy" — the general allocator is told about special memory instead of being bypassed entirely.

**Introspection.** `mallctl()` exposes a tree-structured namespace: configuration (`opt.*`), per-arena statistics (`stats.arenas.<i>.*`), global allocated/active/mapped/retained counters, and actions (purge, decay, arena create/destroy/reset). `malloc_stats_print()` renders it. This is the measurement surface §6 builds on.

**Known failure modes.**

- **Arena multiplication:** too many arenas (or glibc-style arena sprawl jemalloc is often installed to fix) multiplies retention — each arena holds its own dirty pages awaiting decay.
- **Decay mis-tuning:** short decay = `madvise` churn and re-fault costs on bursty loads; long decay = the RSS complaints jemalloc was installed to solve, merely delayed.
- **tcache retention** in thread-churn workloads; threads that allocate heavily and then idle hold their caches.
- **Complexity cost:** jemalloc's configurability is itself a failure surface — production incidents in the field are disproportionately mis-set `MALLOC_CONF` strings carried across version upgrades whose defaults changed.

### 2.5 mimalloc — free-list sharding, segment design, eager commit/decommit

**Source basis:** Leijen, Zorn & de Moura, *Mimalloc: Free List Sharding in Action*, Microsoft Research Technical Report MSR-TR-2019-12 (also APLAS 2019) [S8]; mimalloc repository README and API/options documentation (v1/v2 design, with v3 notes where they differ) [S9][S10]. Accessed 2026-11-15.

**Core data structures.**

- **Segments and pages (v1/v2).** A thread obtains memory in *segments* — large aligned OS allocations (4 MiB in v1; 32 MiB in v2) whose metadata sits at the segment head. A segment is divided into *pages* (usually 64 KiB on 64-bit systems), and each page holds blocks of exactly one size class. In v3 the segment layer was reworked to allocate pages directly from large *arenas* (typically ~1 GiB virtual reservations) to improve cross-thread sharing; the page remains the operative unit. Any citation of segment size must name its major version.
- **Free-list sharding.** Instead of one free list per size class (tcmalloc/jemalloc style), mimalloc keeps a free list *per page*. Thousands of small lists. Objects allocated close in time land in the same page, hence close in memory — locality is a structural consequence, not a heuristic.
- **Free-list multi-sharding — the headline idea.** Each page has *three* lists:
  - `free` — the allocation list; the fast path pops its head.
  - `local_free` — blocks freed by the owning thread are pushed here (plain pointer write, no atomic).
  - `thread_free` — blocks freed by *other* threads are pushed here with a single atomic compare-and-swap on a separate head, encoding delayed-free state in low bits.
  Periodically — guaranteed by *temporal cadence*: because `free` is finite, every bounded number of allocations exhausts it and takes the slow path, which collects `local_free` and `thread_free` into `free` and does maintenance (deferred frees, abandoned-page reclamation). Maintenance cannot be starved by a hot allocation loop, because the fast path is designed to run out.
- **Heaps.** Each thread has a heap (a collection of pages per size class); heaps are first-class and can be created/destroyed explicitly (`mi_heap_*`), giving an arena-like facility inside a general allocator. When a thread exits, its pages with live objects become *abandoned* and are reclaimed by other threads rather than leaked.

**Fragmentation strategy.** Sharding itself: because a page holds one size class and frees return to that page's lists, a page becomes *completely* empty far more often than a bin in a global-list design does — and an empty page can be purged whole (below). Internal fragmentation is bounded by size-class spacing as usual; external fragmentation is reduced because free space concentrates into whole empty pages instead of scattering as single blocks across mixed pages. The tech report's Redis result — 7% faster than tcmalloc, 14% faster than jemalloc on that benchmark, with consistent wins across its sequential and concurrent suite — is quoted here as the report's own measured claim on its own suite, not as a universal ranking.

**Thread strategy.** Almost lock-free: no locks in the design; atomics only on the cross-thread free path and on abandoned-segment reclamation. Local alloc/free is a few instructions (pop/push a page-local list). This was designed for reference-counted language runtimes (Lean, Koka; later adopted as an allocator option by CPython's free-threaded build and others) where alloc/free rates are extreme and cross-thread free is common.

**Return-to-OS strategy.** *Eager page purging with a delay.* When a page becomes empty it is scheduled for purge: physical backing is released (decommit / `MADV_DONTNEED` on `mmap` systems — RSS drops immediately; or reset / `MADV_FREE`-style, per `mi_option_purge_decommits`) while the virtual range is retained for cheap reuse. `MIMALLOC_PURGE_DELAY` sets the delay before purging (documented defaults differ by major version: 10 ms in v1/v2 option tables, 1000 ms in v3's README — name the version). `0` purges immediately (lowest footprint, highest syscall/re-fault cost), `-1` disables purging. Large arenas can be *eagerly committed* on overcommit systems (`MIMALLOC_ARENA_EAGER_COMMIT=2`, the default) — commit is charged without raising peak RSS, so first-touch costs vanish. The net posture is the opposite of early tcmalloc: return aggressively by default, delay only enough to avoid thrash.

**Known failure modes.**

- **Abandoned-page pathology:** if threads exit holding many partially-live pages and no surviving thread reclaims them promptly, memory sits in the abandoned pool. v3's per-page rework was motivated in part by sharing/reclamation friction here.
- **Purge-delay sensitivity:** server operators see the same trade-off as jemalloc decay, with a much shorter default fuse — bursty workloads can pay repeated decommit/recommit cycles.
- **Small codebase, sharp edges:** mimalloc is deliberately compact (~10–12k lines); exotic alignment, huge-object, and interposition edge cases have historically lagged the older allocators' coverage. Its guarded/checked modes are opt-in.
- **Version churn in the design itself:** v1 → v2 → v3 changed segment sizes, defaults, and the ownership layer. Numbers quoted without a major version (a common folklore failure) are not comparable.

### 2.6 Lineage summary table

| | dlmalloc | Hoard | tcmalloc | jemalloc | mimalloc |
|---|---|---|---|---|---|
| Sharding unit | none (one heap) | superblock per processor heap | span; per-thread/CPU cache | extent; arena | page; per-thread heap |
| Fast-path sync | global lock / none | heap lock | none (rseq in per-CPU mode) | none (tcache) | none; CAS only on remote free |
| Free-space organisation | 128 size bins, best-fit | LIFO list per superblock | list per size class per cache + central lists | bins per arena + tcache | 3 lists per page |
| Coalescing | boundary tags, chunk-level | superblock-level only | span-level | extent split/merge | page-level (whole-page reuse) |
| Return to OS | trim top + free `mmap` chunks | via global heap reuse (weak) | whole free spans, configurable | decay dirty→muzzy→retained, per-arena, hookable | eager per-page purge, delayed, decommit/reset |
| Signature failure | lock serialisation; top-pinning | producer–consumer contention; superblock waste | cache/span retention surprises | arena × decay mis-tuning | abandoned pages; purge thrash |

---

## 3. Slab / Arena / Pool / Bump: The Fixed-Shape World

### 3.1 The observation

General allocators solve: *unknown sizes, unknown lifetimes, unknown threads.* Enormous subsystems solve none of that. A kernel allocates the same `inode`, `dentry`, and task structures millions of times. A compiler allocates AST nodes that all die at end of compilation unit. A request handler allocates scratch that all dies at end of request. A KV cache allocates blocks that each hold exactly *B* tokens' keys and values for one layer-group. When size is fixed and lifetime is uniform, allocation degenerates:

- **Allocate** = pop a free list, or bump a pointer. O(1), a few instructions, no search, no split, no coalesce.
- **Free** = push back to the pool, or *do nothing per object* and reset the whole region at the lifetime boundary.

### 3.2 Slab: Bonwick 1994 and the kernel lineage

**Source basis:** Bonwick, *The Slab Allocator: An Object-Caching Kernel Memory Allocator*, USENIX Summer 1994 [S11]; Bonwick & Adams, *Magazines and Vmem*, USENIX ATC 2001 [S12]; Linux SLUB documentation/source summaries [S13]. Accessed 2026-11-15.

Bonwick's design for SunOS 5.4:

- **Cache per object type.** A `kmem_cache` per type/size. The cache owns *slabs*: one or more contiguous pages carved into equal-size objects of that cache's size, nothing else. A slab is tracked as full / partial / free.
- **Object caching — the second idea, as important as the first.** Because the allocator knows the type, it can preserve an object's *constructed* state (invariant fields, initialised locks/lists) between uses: free returns the object to the cache *without* running its destructor; alloc returns it *without* re-running its constructor. Construction cost, often larger than allocation cost, is paid once per slab slot, not once per use.
- **Fragmentation result reported in the paper's lineage:** internal fragmentation bounded by construction (the SunOS implementation limited it to ~1/8, 12.5%), and system-level fragmentation reported falling from 46% to 14% in Solaris 2.4 versus the allocator it replaced. Quoted here as the design lineage's own reported figures.
- **Colouring and alignment:** slab objects are offset ("coloured") to spread them across cache sets and honour alignment without wasting a full stride per object.

**Magazines (2001)** fixed slab's multiprocessor scaling the same way Hoard/tcmalloc fixed malloc's: a per-CPU *magazine layer* — each CPU holds a pair of magazines (loaded/empty) of pre-batched objects, so the common case takes no global lock and scales linearly; *vmem* generalised the backing store into an arbitrary resource allocator feeding the slab layer.

**Linux: SLAB → SLUB.** Linux implemented Bonwick's design as SLAB (1996–97, Hemment). SLUB (Lameter, 2007; default since kernel 2.6.23; sole slab allocator since 6.8 after SLAB's removal) simplified it in the direction this dossier's lineage predicts: no per-CPU object queues — instead each CPU has *one current slab* per cache (`kmem_cache_cpu` with a `freelist` head and transaction id), allocation is a lockless pop via per-CPU compare-and-exchange, remote frees land on the slab's own freelist, partially-used slabs wait on a per-node partial list, and empty slabs are returned immediately to the page (buddy) allocator. The free list costs no extra memory: each free object stores the next-pointer inside itself. SLUB is slab with tcmalloc's per-CPU lesson absorbed.

### 3.3 Arenas / regions / bump allocators

**Source basis:** arena/region literature and production implementations as documented in pattern references and the Rust `bumpalo` / compiler-zone practice [S14][S15]. Accessed 2026-11-15.

An arena owns a chain of large backing blocks and one bump pointer per block. `alloc(n)` aligns the pointer, returns it, advances by `n`; if it does not fit, a new backing block is chained (the old block's tail is wasted — the arena's only internal fragmentation). There is no per-object header, no free list, no `free`. `reset()` sets the pointer(s) back to the start (typically retaining the largest block(s) for reuse); destruction returns all backing blocks at once.

Consequences, stated precisely:

- Allocation cost is a bounds check + add. Free cost is zero per object, O(1) per arena.
- External fragmentation *within* the arena is impossible in the Robson sense (nothing is ever freed out of order — nothing is freed at all), and irrelevant across arenas because each arena is reclaimed whole.
- The failure mode is symmetric: **lifetime leakage.** One object that must outlive the arena pins the entire arena; mixing lifetimes in one arena silently converts peak-lifetime memory into whole-phase memory. Cross-arena references create hidden lifetime ordering constraints (arena B referencing arena A forbids resetting A first). Destructors/finalisers do not run per object unless the arena implementation tracks them (most bump allocators do not).
- Production homes: compiler front/middle ends (V8's Zone, Rust compiler arenas, LLVM's `BumpPtrAllocator`), per-request scratch in servers, per-frame data in game engines, parsers building an AST per document. Go's standard library experimented with a user-arena API (`arena` package proposal / GOEXPERIMENT arenas) on exactly this rationale — bypass GC for phase-lived object graphs — and it remains experimental, not a stable commitment; cite it as an experiment, never as a Go feature.

**Pools** are the middle point: a slab-like cache of fixed-size reusable objects (connection pools, buffer pools, `sync.Pool` in Go) where individual checkout/checkin is allowed but sizes are fixed and reuse is LIFO-hot. A pool is a slab cache without kernel object-construction semantics.

### 3.4 The explicit connection: KV block pools ARE slab allocators

This is not an analogy. It is the same design, field by field:

| Slab (Bonwick 1994) | KV block pool (PagedAttention, Kwon et al., SOSP 2023; vLLM and descendants) |
|---|---|
| Cache holds objects of one type/size | Pool holds blocks of one shape: *B* tokens × layers × KV-heads × head-dim × 2 (K and V) × dtype bytes |
| Slab = pages carved into equal objects | GPU memory region carved at startup into equal blocks (vLLM default *B* = 16 tokens) |
| Free list of objects in the cache | Free list of block IDs in the block manager |
| Object allocated from its cache only | A sequence's next block allocated from the pool only, on demand when the previous block fills |
| No external fragmentation: any free object serves any request for that type | No external fragmentation: any free block serves any sequence — the vLLM paper's central claim |
| Internal fragmentation ≤ tail of one slab | Internal fragmentation ≤ tail of one block per sequence (average half a block) |
| Per-type accounting | Per-pool accounting: total blocks, free blocks, blocks per sequence (the block table) |
| Object's constructed state preserved | Block's KV contents are the state; sharing is by reference count (prefix caching / copy-on-write on shared prompt blocks) — slab object caching grown a refcount |

The differences are equally precise and equally instructive:

1. **Indirection is mandatory, not optional.** A kernel slab object is used by direct pointer. A KV block is used through a *block table* (logical block → physical block) consulted by the attention kernel, because a sequence's blocks are deliberately non-contiguous. PagedAttention is, in OS terms, slab allocation *plus paging*: fixed-size allocation units plus a page table. The cost is one level of indirection in the kernel's inner loop; the paper reports net throughput gains of 2–4× over contiguous-reservation serving systems because the memory saved admits far larger batches.
2. **The waste it kills is mostly *reservation* waste.** The vLLM authors profiled contiguous systems wasting the majority of KV memory to (a) reserving max-length space per sequence (internal/reservation waste), (b) external fragmentation between sequences, (c) unusable free gaps. Their reported result: paged allocation brings KV waste to roughly under 4% (the unfilled tail block), versus only ~20–40% of reserved memory holding real tokens in the contiguous baselines they measured. Figures quoted as the paper's reported measurements [S16][S17].
3. **Ollama's native KV cache is the contiguous design.** llama.cpp/Ollama historically allocate KV as contiguous per-sequence buffers (with later upstream work adding chunked/defragmenting behaviours varying by version — any claim about a specific Ollama build's KV defrag must be checked against that build, not assumed). **[Engineering judgement]** For the improved Ollama, the slab-pool design is the single highest-leverage allocator decision available: it converts KV memory from a Robson-exposed extent problem (§4.4) into a fixed-shape pool problem where fragmentation is bounded by half a block per sequence by construction.

---

## 4. Fragmentation Theory

**Source basis:** Wilson, Johnstone, Neely & Boles, *Dynamic Storage Allocation: A Survey and Critical Review*, IWMM 1995 [S18]; Robson 1971/1974/1977 as surveyed therein and in later tight-bounds literature [S19][S20]; PyTorch CUDA caching-allocator documentation and engineering notes [S21]. Accessed 2026-11-15.

### 4.1 Definitions that must not be blurred

- **Internal fragmentation:** bytes allocated but unused *inside* a block — size-class rounding, alignment padding, headers, a KV block's unfilled tail, an arena block's unusable remainder. Measurable exactly, per allocation.
- **External fragmentation:** free bytes that exist in total but not in any single piece large enough (or shaped right) to satisfy a request. Only meaningful relative to a request distribution; a heap can be 50% free and 100% unable to serve the next request.
- **Retention (not fragmentation, often confused with it):** free bytes the allocator *could* return to the OS but holds for reuse (dirty pages awaiting decay, thread caches, span caches). Retention inflates RSS/VRAM-reserved; fragmentation inflates *failure at a given ceiling*. Different diseases, different cures (§6).

### 4.2 Robson's bound: the worst case is logarithmically bad, and no policy escapes it

John Robson proved (1971, with bounds refined 1974/1977) that for online allocation without relocation — blocks cannot move once placed, the allocator does not know future requests — an adversary can force *any* deterministic allocator to need memory proportional to `M · log2(n)`, where `M` is the maximum live data at any moment and `n` is the ratio of largest to smallest block size. In modern competitive-ratio language: the optimal deterministic competitive ratio is Θ(log M) in the high-water mark. Randomisation improves the lower bound only modestly (Ω(log M / log log M), Luby–Naor–Orda 1994). The adversarial construction is a comb: allocate many blocks, free every second one, and the free space is diced into holes each too small for the next size the adversary requests, while total free space is ample.

Three practical readings:

1. **The bound is about *range of sizes*, not cleverness.** Halving `log2(n)` — e.g. by segregating huge allocations from small ones (jemalloc's oversize arena, tcmalloc's large path, dlmalloc's `mmap` path) — directly lowers the worst-case multiplier. Segregation is theory applied.
2. **Fixed-size allocation escapes the bound entirely.** If all requests are one size (`n = 1`), the log term vanishes. This is the theoretical statement of why slab/KV pools work (§3.4).
3. **Relocation escapes the bound.** A compacting garbage collector can move live blocks and coalesce all free space; Robson's adversary assumed it cannot. This is one deep reason GC languages tolerate allocation patterns that would wreck a manual heap — and why non-moving collectors (Go's, §5) only partially escape.

### 4.3 Wilson et al.: real programs are not adversaries

Wilson et al.'s 1995 survey — 150+ references, 1961–1995 — is the field's empirical correction to its own theory:

- Most theoretical and experimental work before 1995 assumed random, independent request streams. Real programs exhibit strong regularities: size distributions are heavily skewed (a few sizes dominate), lifetimes are often LIFO-correlated or phase-structured, and allocation comes in ramps, peaks, and plateaus. **Fragmentation at peaks is what matters** — a heap that fragments at its high-water mark sets the machine's memory requirement.
- Under real traces, good policies (best-fit variants, segregated storage with well-chosen size classes) track *close to optimal* — far from Robson's worst case. The survey's enduring verdict is that **policy (where you place, what you segregate, when you coalesce) matters more than mechanism**, and that allocator research had over-invested in mechanism.
- The "50% rule" folklore (Knuth's steady-state observation that first-fit tends toward ~N/2 holes for N live blocks) is a statement about a specific policy under specific assumptions, routinely quoted as if it were a law of all allocation. **Flagged as folklore-in-context:** the rule is real in Knuth's analysis; its unqualified repetition as a universal fragmentation constant is sourced nowhere in the survey and should not be cited as one.

**[Engineering judgement]** The Wilson lesson for runner engineering is to measure the *actual* request stream (weight loads: few, huge, once; KV: one size, append-mostly; activations/scratch: phase-lived; server glue: general) and give each stream the policy its regularity rewards — rather than benchmarking one allocator on synthetic random traces and declaring a winner.

### 4.4 Fragmentation under a hard ceiling: the GPU VRAM case

On host RAM, external fragmentation mostly costs RSS. Under a hard VRAM ceiling (a 6–24 GiB consumer GPU, a unified-memory APU budget), it costs *correctness of admission*: the runner must decide whether the next request/model fits, and "total free bytes" is the wrong number to decide with.

The publicly documented reference implementation is PyTorch's CUDA caching allocator [S21]:

- It obtains large *segments* from the driver (`cudaMalloc`) and carves them into *blocks* internally; freed blocks are cached for reuse, split when oversized, and coalesced with neighbours *within a segment* — but **blocks in different segments can never merge**, because each `cudaMalloc` is an independent driver allocation. Cross-segment fragmentation is therefore structural, exactly analogous to dlmalloc's inability to return interior holes.
- Its OOM error message institutionalises the measurement discipline: it reports memory *allocated* by tensors, memory *reserved but unallocated* by the caching allocator, and suggests `expandable_segments` when the reserved-but-unallocated gap is large — i.e. it names fragmentation, in the error, as a distinct cause from true exhaustion.
- *Expandable segments* (PyTorch 2.1+, stabilised later) replace per-segment `cudaMalloc` with one large virtual reservation per pool backed by CUDA virtual-memory APIs (`cuMemCreate`/`cuMemMap`), mapping physical pages (documented granularities: 2 MiB small-pool / 20 MiB large-pool pages) on demand. Because all blocks now live in one virtual range, neighbours can always merge; the cross-segment barrier disappears. Documented fragmentation examples that OOM under classic segments succeed under expandable segments; other fragmentation (within-block rounding, genuinely pinned interleavings) remains — the documentation is careful to separate the two classes.

**Translation to the runner case.** A model runner's VRAM allocator *is* an extent allocator under a hard ceiling, whether it is written as one or accreted as one:

- Weights: allocate once, never free until unload → place them first, place them contiguously, never interleave them with churn.
- KV pool: slab it (§3.4) so it cannot fragment internally at all.
- Transient compute buffers / CUDA-graph pools / sampler scratch: arena per phase, or a small set of reusable size-bucketed buffers.
- What remains for a general extent policy is small — and that is the point. Every subsystem moved to slab/arena is a subsystem Robson's adversary can no longer attack.

Ollama today delegates most device allocation to llama.cpp's backend buffers and (where used) the vendor runtime; **[Engineering judgement]** the improved Ollama should own its VRAM budget accounting explicitly — reserved vs allocated vs free-largest-block, per pool — because admission control and honest OOM messages ("fragmented: X GiB free in Y blocks, largest Z MiB") are allocator features, not logging afterthoughts. PyTorch's error string is the industry-proven template.

---

## 5. GC vs Manual vs Ownership

### 5.1 Three answers to "who frees, and when"

| Discipline | Who decides liveness | Can blocks move? | Allocator's job | Characteristic cost |
|---|---|---|---|---|
| Manual (`malloc`/`free`, C) | Programmer, per block | No | Placement + coalescing (this dossier §2) | Use-after-free / leaks are program bugs; fragmentation is allocator + program jointly |
| Tracing GC (Go, Java, JS) | Runtime, by reachability | Go: no (non-moving). Java (modern collectors): yes, mostly. | Placement + supplying the collector with scannable structure | Collection pauses/CPU, retention until next cycle, non-determinism of final reclamation |
| Ownership / RAII / reference counting (Rust, C++, Swift, Lean/Koka via RC) | Compiler-inserted drops / refcount decrements, deterministic | No (except by explicit move) | Placement, plus being fast enough to serve as the RC backend (mimalloc's design brief) | Refcount traffic; cycles need a backup (weak refs / leak-and-collect); drop timing is a semantic feature programs depend on |

Rust's landscape, briefly (per the task's scope): Rust standardises the *interface*, not the allocator — `GlobalAlloc` (an unsafe trait: `alloc`/`dealloc`/`alloc_zeroed`/`realloc` over an explicit `Layout` of size+alignment) registered once via `#[global_allocator]`, defaulting to an unspecified global (the system allocator for `cdylib`/`staticlib`; historically jemalloc on some targets). `Layout` being explicit is the notable design point: alignment is a first-class request, not a separate `memalign` family. The ecosystem then swaps implementations freely — mimalloc, jemalloc (via `tikv-jemallocator`), tcmalloc, snmalloc, or bump arenas (`bumpalo`) for scoped work — without language changes [S22]. **[Engineering judgement]** Mojo/Aesir sits closest to the ownership column: deterministic lifetimes are available at compile time, so Aesir should spend them (arena/slab placement decided statically) rather than paying a general allocator to rediscover lifetimes at runtime.

### 5.2 Go's runtime allocator, from its documented design

**Source basis:** Go runtime source documentation, `src/runtime/malloc.go` header (the allocator's own design comment) and `mheap`/`mcentral`/`mcache` structure [S23]; Go GC guide and runtime metrics documentation for the scavenger [S24]. Accessed 2026-11-15.

Go's allocator is explicitly documented as *originally based on tcmalloc, since diverged*. The documented structure:

- **Size classes:** small objects (≤ 32 KiB) round to one of ~70 size classes (68 usable small classes plus tiny/large handling in current tables — the header says "about 70"; exact counts vary by Go version), each with spans of exactly that class. A dedicated *tiny allocator* packs pointer-free objects < 16 bytes into a shared 16-byte block.
- **`mspan`:** a run of 8 KiB runtime pages carved into equal objects of one class, with a free *bitmap* (not a linked list) scanned for slots, and a scan/noscan distinction: spans of pointer-free objects are never scanned by the GC.
- **`mcache`:** per-*P* (per logical processor, not per thread/goroutine) cache holding one span per size class — allocation from it needs no lock.
- **`mcentral`:** per-size-class central collection of spans with free space (split by scan/noscan), mutex per class; refills mcaches a span at a time, amortising the lock.
- **`mheap`:** the global page heap over *arenas* of 64 MiB (64-bit non-Windows), with a radix-structured page allocator for free-page runs; large objects (> 32 KiB) allocate directly here, bypassing mcache/mcentral.
- **Sweeping is the free path:** there is no `free()` call from user code; the GC's sweeper discovers dead objects span by span and returns empty spans down the hierarchy (mcache → mcentral → mheap).
- **Scavenger:** a background process returns idle heap pages' physical backing to the OS (on Linux, `MADV_DONTNEED` by default since Go 1.16, so RSS drops promptly; `MADV_FREE` selectable via `GODEBUG=madvdontneed=0`). Virtual address space is *never unmapped* — only physical backing is released. Runtime metrics expose the distinction precisely: `HeapInuse` (live spans), `HeapIdle` (free spans held), `HeapReleased` (idle spans whose backing was returned), `HeapSys` (virtual obtained). `debug.FreeOSMemory()` forces a GC + maximal release.

Two documented properties drive everything in §5.3:

1. **The Go heap is non-moving.** Objects never relocate, so Go gets only part of the GC escape from Robson (§4.2): the collector can coalesce fully-empty spans, but cannot compact partially-live ones. Long-lived objects interleaved with churn pin their spans — the span-pinning failure mode, inherited from tcmalloc and acknowledged by the design's structure.
2. **Every heap byte is GC-accounted.** Heap objects carry bitmap/metadata, pointer-containing objects are scanned, and heap growth triggers collection pacing (`GOGC`, `GOMEMLIMIT`). The heap is optimised for many small-to-medium objects, not for a handful of multi-gigabyte arrays whose "liveness" a collector must re-verify every cycle.

### 5.3 Why a Go runner's tensor/KV memory should live outside the GC heap

Marked clearly: the following is **[Engineering judgement]** reasoned from the documented design above and from llama.cpp/Ollama practice — it is not a claim made by the Go documentation itself.

1. **Scan cost and pacing.** Model weights (gigabytes, pointer-free in substance but held as `[]byte`/unsafe buffers) and KV blocks (gigabytes, pure numeric data) placed on the Go heap inflate `HeapInuse`, distort GC pacing toward collections that can reclaim almost nothing (the memory is live for the model's lifetime), and — if any part is pointer-scanned — pay scan cost proportional to size for zero liveness information. The runtime already provides the distinction (noscan spans); multi-GB blobs defeat its granularity.
2. **Span/class mismatch.** The allocator's largest class is 32 KiB; everything larger is a direct mheap extent. A 4 GiB weight tensor is not "a large object" in this design's intended sense — it is thousands of arenas' worth of extent whose allocation, zeroing policy, and release are governed by heuristics tuned for program heaps, not device staging buffers.
3. **Release semantics are wrong for VRAM-adjacent host buffers.** A runner needs: allocate staging buffer → copy to device → release *now*, deterministically, and account it against a hard budget. The GC heap offers: release when reachability + sweep + scavenger eventually agree, with RSS following `MADV` policy. `debug.FreeOSMemory()` per unload is a sledgehammer (full GC) for a scalpel job.
4. **The proven pattern exists in the ecosystem:** allocate big, long-lived, pointer-free memory with `mmap` (anonymous, optionally huge-page-backed) or via cgo/`cudaHostRegister`-style pinned allocations, manage it with a purpose-built pool (slab for KV, arena for weights, ring for staging), and keep on the Go heap only the small descriptors (handles, block tables, metadata) that genuinely benefit from GC. This is how Go programs routinely hold off-heap caches and how llama.cpp's own buffers already live on the C side of Ollama's cgo boundary. The Go heap then stays small, collections stay cheap, and the runner's memory budget (§4.4) is accounted in the pool's own counters — exactly, not via `MemStats` archaeology.
5. **Caveat, honestly stated:** off-heap memory is invisible to `GOMEMLIMIT` and pprof heap profiles. A runner that moves its bulk off-heap *must* re-implement that accounting in its pool stats (§6) or it has traded GC pressure for operational blindness. This trade is worth it; it is still a trade.

---

## 6. Measurement: How Fragmentation and Allocator Overhead Are Actually Measured

### 6.1 The four numbers, never one

Any honest allocator report separates:

1. **Requested / live:** sum of user-requested sizes currently live (`uordblks` in glibc terms; `stats.allocated` in jemalloc; tensor-allocated in PyTorch terms).
2. **Allocator-held:** live + internal fragmentation + free-but-cached/retained (jemalloc `stats.active` / `stats.mapped`; Go `HeapInuse + HeapIdle − HeapReleased`).
3. **Resident (RSS/PSS):** physical pages actually backed — what the machine feels. PSS (proportional set size, from `/proc/<pid>/smaps_rollup`) is the honest variant under shared pages.
4. **Virtual / reserved:** address space obtained (`HeapSys`, jemalloc `stats.mapped`+`retained`, VRAM reserved). Cheap on 64-bit host, *the* budget on VRAM.

Fragmentation claims must say which gap they measure: (held − live)/live is *allocator overhead + internal fragmentation + retention*; (RSS − live) adds page-granularity effects; *external* fragmentation proper is only proven by a **failed allocation that total-free says should have succeeded**, or by reporting the **largest free block / extent** alongside total free. A report that gives only RSS and live data has measured retention and called it fragmentation — the most common measurement error in the field, and one this dossier explicitly refuses.

### 6.2 The instruments

- **glibc:** `mallinfo2()` (the `size_t` successor to deprecated `int`-typed `mallinfo()`) returns arena bytes, free chunk counts/bytes (`ordblks`, `fordblks`), `mmap`'d chunk count/bytes (`hblks`/`hblkhd`), in-use bytes (`uordblks`), and `keepcost` (releasable top). Documented limitation: `mallinfo`/`mallinfo2` report only the *main* arena; multi-arena programs need `malloc_info()` (XML, all arenas) or `malloc_stats()` [S25]. `mallopt()` tunes trim threshold, `mmap` threshold, arena caps — the knobs behind the numbers.
- **jemalloc:** `mallctl("stats.allocated" / "stats.active" / "stats.mapped" / "stats.retained" / "stats.resident")` after an `epoch` refresh, per-arena breakdowns under `stats.arenas.*`, plus `opt.*` echo of the decay/arena configuration that produced them. The allocated→active gap is internal fragmentation + metadata; active→mapped is retention awaiting decay; mapped→retained is virtual held after purge. jemalloc is the only allocator here whose stats decompose the four numbers of §6.1 natively.
- **tcmalloc:** `MallocExtension` properties (current allocated bytes, page-heap free/unmapped bytes, per-size-class stats) and its sampling profiler — allocation-site attribution being its distinctive strength.
- **mimalloc:** `mi_stats_print()` / collected stats (pages, segments/arenas, purged pages, RSS peak) and process-level `mi_process_info()` (elapsed, peak RSS, page faults) — enough to verify its eager-purge claim on a given workload.
- **Go:** `runtime.MemStats` / `runtime/metrics` (`HeapAlloc`, `HeapInuse`, `HeapIdle`, `HeapReleased`, `HeapSys`, `NextGC`) + pprof heap profiles; for off-heap pools (§5.3), the pool's own counters are the instrument — there is no runtime shortcut.
- **VRAM:** driver view (`nvidia-smi`, `/proc` DRM info, ROCm SMI) for reserved; framework view (PyTorch `memory_summary()`: allocated vs reserved vs reserved-unallocated, segment/block counts) for fragmentation. The reserved-unallocated figure *is* the fragmentation+retention gauge; the largest-block figure, where exposed, separates the two.
- **Latency:** allocator overhead is a *distribution*, not a mean — per-op p50/p95/p99 for alloc and free *separately* (MimirAlloc's K-008 lesson, §6.3, is that the tail lives in free). Timer resolution must be stated; a p50 at the timer floor is reported as "≤ floor", never as a precise value.

### 6.3 The discipline MimirAlloc's campaigns used (referenced, not re-derived)

Per the banked companion dossier `mimiralloc-our-own-proven-work.md`, whose records govern:

- **Identical-legs A/B:** one workload source compiled once, only allocator function pointers differing; legs alternated across ≥ 5–7 fresh processes; medians reported; per-workload checksums required identical across legs before any timing is believed (K-002 protocol; Z-004 protocol gate quantified identical-leg noise ≤ 0.85% against a 5% bound, drift 2.28% against an 8% bound, with drifted attempts *voided and kept as evidence*).
- **Pre-registered adoption bars:** a variant that won its target traces was still rejected for regressing an oracle workload past a bar fixed before the run (Z-095, 2% bar). Regressions printed in full; NO-ADOPTION recorded as a normal verdict.
- **Separate distributions:** alloc vs free, p50/p95/p99, timer floor declared (K-008: ≈37 ns floor; glibc small-op p50s at the floor read as ≤ floor).
- **Footprint as a first-class metric:** retained-after-free measured against baseline (K-008: MimirAlloc returned to within 128 KiB of baseline on the small-hold leg where glibc retained 1232 KiB), with the record's own qualifier carried: retained memory is reuse-ready, not a defect per se — but it is footprint a caller pays.
- **Host facts attached to every verdict:** page size (16 KiB Pi vs 4 KiB Z13), build flavour (`-O0` caveat INC-K002-02 on the early baseline, discharged by later `-O2` runs), contention state of the window, and machine identity. A factor without its host is not a result.

That protocol — not any single number — is the transferable asset, and §7 applies its standards to the recommendations.

---

## 7. Applicability

### 7.1 Ollama / Go (the improved Ollama)

**Do not replace Go's allocator. Route around it by memory class.** Concretely:

| Memory class | Recommended home | Design (lineage) |
|---|---|---|
| Weights (host staging + device) | Off-heap `mmap` arena per model, huge-page-eligible, loaded once, released whole on unload | Arena (§3.3) over extents; jemalloc extent-hook pattern if a general allocator must front it |
| KV cache (device) | Slab block pool with block table, per model instance; block = fixed token count × per-token KV bytes | Slab + paging (§3.4); vLLM block size 16 as the starting point, tuned per model/dtype |
| KV cache (host spill, if any) | Same pool design over `mmap`'d host memory | Slab (§3.2) |
| Per-request / per-step scratch | Per-request arena (bump, reset at request end); per-step buffers from a small size-bucketed pool | Arena (§3.3) / pool (§3.3) |
| Server glue (HTTP, JSON, scheduler) | Go heap, unmodified | Go runtime allocator (§5.2) — it is good at exactly this |
| Tokeniser / sampling temporaries | Go heap for small; arena for per-request bulk | Mixed |

Budget accounting: one VRAM ledger per device (reserved / allocated / free-total / free-largest, per pool), surfaced in errors and in an admin stats endpoint modelled on jemalloc `mallctl` decomposition and PyTorch's OOM wording (§4.4, §6.1). Admission control reads free-largest for contiguous needs and free-block-count for KV — never total-free alone.

What *not* to do, with lineage reasons: do not interpose a C allocator under the Go runtime (the runtime does not use `malloc` for its heap; interposition would affect only cgo code and would import §2's failure modes for no benefit); do not put KV on the Go heap as `[][]byte` per sequence (span pinning + GC pacing, §5.3); do not tune `GOGC`/`GOMEMLIMIT` to manage device memory (they cannot see it once it is correctly off-heap — account it in the ledger instead).

### 7.2 Aesir (Mojo / manual world)

Aesir owns its allocator decisions fully — no runtime allocator stands behind it. Recommendations, in lineage order:

1. **Weights:** extent/arena loading as in §7.1. On Strix Halo-class unified memory, the host/device distinction blurs but the *lifetime* distinction does not: weights are still load-once extents and must never interleave with churn (per-CCD placement awareness per the Z13 host facts banked in the MimirAlloc dossier: cross-CCD latency ~103 ns vs intra-CCD ~32 ns, measured).
2. **KV:** the slab block pool is even more natural in Aesir than in Go — the engine controls its attention kernels, so block-table indirection (§3.4) can be fused into the kernel rather than paid as a generic lookup. Aesir's KV-shaped harness probes against a *general* allocator lost on all shapes (MimirAlloc dossier, Z-115) — correctly interpreted, that result argues against general allocation for KV, not against the engine.
3. **Activations/scratch:** bump arenas per inference phase (prefill arena, decode-step arena), reset at phase boundaries; deterministic lifetimes are known statically in much of the graph — spend that knowledge (§5.1).
4. **General heap (engine internals, tooling):** if a general allocator is needed, the honest candidates by lineage are mimalloc (locality + eager return, best fit for RC-adjacent Mojo patterns) or jemalloc (if decay-tuned RSS behaviour and introspection matter more) — chosen by an A/B under the §6.3 protocol on the target machine, not by reputation. A single global lock design is a correctness scaffold, not a serving design (§7.3).

### 7.3 MimirAlloc — honest placement in the lineage

From its own banked record (companion dossier; figures governed by it):

- **Design placement:** a C11, dlmalloc-family small-object core — 20 size classes (16–1024 B), span/page management, boundary-style bookkeeping — with **one global lock**, and a large path (> 1024 B) that takes a **fresh OS mapping per allocation**. In lineage terms it implements the *first* generation's design with modern correctness discipline, and deliberately none of the thread-era machinery (no per-thread/per-CPU caches, no arena sharding, no lock-free remote free). Its page size is discovered at runtime, never hardcoded — a genuinely modern touch the first generation lacked.
- **Measured consequences, exactly as the lineage predicts:** correctness fully proven on both campaigns (Pi gate 4,590 checks / 0 failed; Z13 gate 4,988 passed / 0 failed / 77 skipped); speed lost to glibc on every Pi workload (K-002 medians ~5.4×–65.2× slower, `-O0` caveat on that baseline, loss confirmed at `-O2` in K-008) and on most Z13 core shapes, with the tail concentrated in *free* (burst-free p99 1,167 ns vs glibc 56 ns) — the single-lock + span-release path is where the lineage says the cost must sit. The one repeatable *win* is the return-to-OS axis: footprint/retention victories on both hosts (Pi: back to within 128 KiB of baseline post-free vs glibc's 1,232 KiB retained; Z13: retention WIN 3 of 4, resident-shape wins in soaks) — because a mapping-per-allocation large path and prompt span release *are* an aggressive return policy, paid for in allocation latency. MimirAlloc, measured honestly, traded §2.1's speed for §2.4's virtue before the trade was fashionable in its own design notes.
- **What would move it a generation:** per-P/per-thread small-object caches in front of the locked core (tcmalloc's move), or per-page free-list sharding with atomic remote free (mimalloc's move), plus arena reuse above the 1024 B cutoff instead of fresh mappings (the cutoff itself was re-examined on Z13 and left unchanged, justified — the policy *above* it is the target). Each is a named, testable slice under the campaigns' own pre-registered-bar discipline — and until one lands and wins under that discipline, MimirAlloc's honest grade stands as its dossiers state it: a correct, well-measured research allocator (v0.1.0) that loses on speed and wins on giving memory back.

---

## 8. Sources (all accessed 2026-11-15)

**Primary papers and design documents**

- [S1] Doug Lea, *A Memory Allocator* (dlmalloc design essay). https://www.cs.tufts.edu/~nr/cs257/archive/doug-lea/malloc.html
- [S2] Berger, McKinley, Blumofe & Wilson, *Hoard: A Scalable Memory Allocator for Multithreaded Applications*, ASPLOS 2000 (UT Austin TR-00-07). https://www.cs.utexas.edu/ftp/techreports/tr00-07.pdf
- [S3] Google, *TCMalloc Design* (current documentation: front/middle/back end, per-CPU mode, size classes, spans, pagemap). https://google.github.io/tcmalloc/design
- [S4] Ghemawat & Menage, *TCMalloc: Thread-Caching Malloc* (original perftools document). https://git.launchpad.net/ubuntu/+source/google-perftools/tree/docs/tcmalloc.html?h=applied/ubuntu/plucky-devel&id=9453128af5a3877c0becd57d3af6c4da105c421e
- [S5] Jason Evans, *A Scalable Concurrent malloc(3) Implementation for FreeBSD*, BSDCan 2006 (slides). https://papers.freebsd.org/2006/bsdcan/evans-jemalloc.files/evans-jemalloc-slides.pdf
- [S6] jemalloc manual (5.3.x): `mallctl` namespace, decay, extent hooks, arena controls. http://jemalloc.net/jemalloc.3.html
- [S7] jemalloc tuning guide (tikv-jemalloc-sys mirror of jemalloc TUNING.md, 5.3.0). https://docs.rs/crate/tikv-jemalloc-sys/latest/source/jemalloc/TUNING.md
- [S8] Leijen, Zorn & de Moura, *Mimalloc: Free List Sharding in Action*, MSR-TR-2019-12 / APLAS 2019 (abstract + publication page). https://www.microsoft.com/en-us/research/publication/mimalloc-free-list-sharding-in-action/
- [S9] mimalloc documentation (free-list sharding, multi-sharding, eager purging). https://microsoft.github.io/mimalloc/
- [S10] mimalloc runtime options (purge delay, purge decommits, arena eager commit; version-dependent defaults). https://microsoft.github.io/mimalloc/group__options.html
- [S11] Jeff Bonwick, *The Slab Allocator: An Object-Caching Kernel Memory Allocator*, USENIX Summer 1994 (as cited and summarised in kernel literature). https://phrack.org/issues/66/15
- [S12] Bonwick & Adams, *Magazines and Vmem: Extending the Slab Allocator to Many CPUs and Arbitrary Resources*, USENIX ATC 2001. https://static.usenix.org/events/usenix01/full_papers/bonwick/bonwick_html/index.html
- [S13] Linux SLUB internals (per-CPU slab, freelist-in-object, partial lists). https://kernel-internals.org/mm/slab-internals/
- [S16] Kwon et al., *Efficient Memory Management for Large Language Model Serving with PagedAttention*, SOSP 2023 (via vLLM design summaries). https://www.justmalhar.com/blog/what-is-vllm/
- [S17] PagedAttention block-table analysis (waste accounting, block size trade-offs). https://www.aicassindra.com/blogs/llm/paged-kv-blocks.html
- [S18] Wilson, Johnstone, Neely & Boles, *Dynamic Storage Allocation: A Survey and Critical Review*, IWMM 1995. https://www.cs.hmc.edu/~oneill/gc-library/Wilson-Alloc-Survey-1995.pdf
- [S19] Robson bounds — modern restatement: *Tight Bounds for Memory Allocation With and Without Request Fragmentation* (Θ(log M) deterministic optimum; Robson 1971). https://arxiv.org/pdf/2608.28462.pdf
- [S20] Robson, *Worst Case Fragmentation of First Fit and Best Fit Storage Allocation Strategies*, Computer Journal 1977 (bibliographic record). https://api.openalex.org/works/doi:10.1093%2FCOMJNL%2F20.3.242
- [S21] PyTorch, *When does fragmentation occur in the CUDA caching allocator?* (segments/blocks, cross-segment non-merging, expandable segments via `cuMemMap`). https://docs.pytorch.org/devlogs/eager/2026-06-01-cuda-caching-allocator/
- [S22] Rust standard library, `std::alloc` / `GlobalAlloc` (Layout, `#[global_allocator]`, System). https://doc.rust-lang.org/nightly/alloc/alloc/trait.GlobalAlloc.html
- [S23] Go runtime, `src/runtime/malloc.go` (allocator design comment: tcmalloc origin, ~70 size classes, mcache/mcentral/mheap/mspan, 64 MiB arenas). https://tip.golang.org/src/runtime/malloc.go
- [S24] Go runtime scavenger behaviour (`MADV_DONTNEED` default on Linux, HeapIdle/HeapReleased, FreeOSMemory) — runtime discussion summary. https://www.mail-archive.com/golang-nuts@googlegroups.com/msg47555.html
- [S25] GNU C Library manual, *Statistics of Malloc* (`mallinfo2` fields) + `mallinfo2(3)` man page (main-arena-only limitation). https://www.gnu.org/software/libc/manual/html_node/Statistics-of-Malloc.html and https://man.archlinux.org/man/core/man-pages/mallinfo2.3.en

**Secondary / pattern references (arena/bump practice)**

- [S14] *Pattern: Arena Allocator* (bump allocation, reset semantics, production uses incl. `bumpalo`, compiler zones). https://patterns.totorojam.com/patterns/arena-allocator/
- [S15] *Using an Arena Allocator for Per-Frame Data* (lifetime-uniform workloads, reset discipline). https://www.webassembly-wasm.com/js-wasm-interop-memory-management/linear-memory-management-and-allocators/using-an-arena-allocator-for-per-frame-data/

**Our own record**

- MimirAlloc dossier (banked companion, same directory): `mimiralloc-our-own-proven-work.md` — all MimirAlloc figures, grades, and campaign records cited in §6.3 and §7.3 are governed by that dossier and its named records (K-002, K-008, K-009, Z-003…Z-117, M-009).

### Unverifiable / folklore flagged in this pass

- Exact size-class counts and small/large thresholds for tcmalloc and Go vary by version and fork (perftools vs google/tcmalloc vs Chromium; Go release to release). This dossier gives ranges and names versions where the source does; any single "the number is N" claim without a version should be treated as unverified.
- mimalloc purge-delay defaults differ between its own v1/v2 option tables (10 ms) and v3 README (1000 ms) as published; both are cited with versions above rather than resolved to one figure.
- Knuth's "50% rule" is widely repeated as a universal fragmentation law; in the sources read it is a first-fit steady-state analysis result. Flagged in §4.3.
- jemalloc's 2006 chunk/run terminology vs modern extent terminology: the 2006 slides were read directly; the modern extent/decay description rests on the current manual, not on re-reading the full 2006 paper PDF (slides + manual + tuning guide only). No load-bearing claim rests solely on the unread portion.
- The Hoard paper was read via its technical-report text and presentation summaries; its headline speedups (e.g. up to 60× over the Solaris allocator on 14 processors) are the paper's own reported results on 2000-era hardware and are not carried into any recommendation here.

*End of dossier — OR-6, allocator lineages. 2026-11-15.*
