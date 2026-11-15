# Virtual Memory, Paging, and the Cache / TLB Hierarchy — The Classical Foundations

**Dossier OR-6 (Memory Domain), Topics B1 + B2 — Ollama Research Forge**
**Commissioned by:** Volmarr Wyrd, 2026-11-15
**Date of research:** 2026-11-15 (all web sources accessed 2026-11-15; see §8)
**Status:** B-side foundations dossier. The MEMORY-COMPENDIUM (Ch. 10) flags B1 (virtual memory & paging) and B2 (cache hierarchies) as the corpus's shallow side — touched constantly, dossiered nowhere. This document fills that slot.
**Readers:** Yrsa engineering (a) the improved Ollama in Go, (b) Aesir, (c) MimirAlloc and future allocator work.
**Companion dossiers in this corpus:** `memory/allocator-lineages.md` (E1/E2 — the allocators that live on top of everything described here), `memory/mimiralloc-our-own-proven-work.md` (E6 — our own measured THP and fault evidence), `memory/unified-memory.md` (B7 — the Z13 case study this dossier references for swap and pinning), `memory/memory-wall-and-roofline.md` (B5 — the bandwidth method), `memory/kv-cache-design.md` (A1 — the workload whose bytes dominate).
**Clean-room note:** Written in our own words from the public sources in §8. No passages are copied. Short factual labels (syscall names, flag names, structure names) are quoted as names, not prose. Judgements beyond a cited source are marked **[Engineering judgement]**. Speculation is marked **[SPECULATION]**.

---

## 1. Header + Essence: The Illusion, and Where It Bills You

Every program a runner executes believes three things that are not true:

1. **Memory is private and contiguous.** The process sees one flat address space, starting near zero, extending for gigabytes, with its code, heap, and stack laid out as if no other process existed.
2. **Memory is present.** An address that was reserved can be read or written immediately, as if a physical byte already waits behind it.
3. **Memory is uniform.** One byte costs roughly what the next byte costs.

The operating system and the hardware maintain all three illusions together, by conspiracy: the OS invents mappings, the memory-management unit (MMU) translates addresses on every access, the caches pretend DRAM is fast, and the page-fault handler quietly materialises bytes that did not exist a microsecond earlier. For most programs the conspiracy is cheap, because most programs touch a modest working set with strong locality, and the machinery amortises to invisibility.

**An LLM runner lives exactly where the illusion is most expensive.** Its defining memory behaviours are the conspiracy's worst cases, all at once:

- **Multi-gigabyte streaming tensors.** Decode reads essentially all resident weights once per generated token — tens of gigabytes, sequentially, with almost no reuse within the step (the roofline dossier's §3 result: decode intensity ≈ 1 FLOP/byte at batch 1). The caches cannot hold the stream; the TLB cannot hold its translations at base page size; the only thing that saves the access pattern is that it is *predictable*, so prefetchers and readahead can run ahead of it (§4.4, §5.3).
- **Page-fault-priced first touches.** A model does not become resident when it is "loaded." It becomes resident page by page, as it is touched — on load, on first prefill, and again on the first decode step that reaches a cold region. First-token latency therefore contains a page-in bill that warm benchmarks never show (§5.2). Our own fleet has already misread this once: a 56.7 tok/s "cold" Ollama reading discarded as mmap page-in against a ~1,010 tok/s warm prompt-eval baseline (recorded in `memory/unified-memory.md` §5, item 3).
- **TLB reach measured in gigabytes.** Translation is cached in a structure with on the order of a thousand useful entries. At 4 KiB pages that covers single-digit megabytes comfortably and tens of megabytes at the second level — against a 40 GB weight stream it covers nothing. The runner's resident set is three to four orders of magnitude larger than the translation cache's natural reach, and closing that gap is what huge pages *are for* (§3).

The thesis of this dossier, stated once and then argued section by section:

> **Virtual memory is not background plumbing beneath the allocator and the KV cache. It is the layer that prices every byte they touch — in faults on first touch, in walks on translation miss, in evictions under pressure — and a runner that does not reason at this layer will keep rediscovering its costs as mysteries at the layers above.**

Every classical mechanism below is therefore presented in two beats: what it is, and what it does to an LLM workload. A reader who only needs the second beat can read the last paragraph of each section; a reader who skips the first beat will not know *why* the second beat is true, and will misapply it to the next machine.

---

## 2. Virtual Memory Mechanics

### 2.1 Address translation: the split every address undergoes

Paging — the dominant form of virtual memory since the Atlas system of the early 1960s, and the form OSTEP's Ch. 18 uses as its teaching model — chops both sides of memory into fixed-size units. The virtual address space is divided into **pages**; physical memory is divided into **page frames** of the same size. A per-process **page table** records, for each virtual page, which frame (if any) currently holds it (Arpaci-Dusseau & Arpaci-Dusseau, OSTEP Ch. 18, accessed 2026-11-15 [S1]).

Translation is then arithmetic, not search. A virtual address splits into two fields:

- the **virtual page number (VPN)** — the high bits, which index the page table; and
- the **offset** — the low bits, which name the byte inside the page and pass through translation unchanged.

The page-table entry (PTE) found at that index supplies the **physical frame number (PFN)**, which replaces the VPN to form the physical address. Because page size is a power of two, the split is a bit-field extraction: a 4 KiB page means a 12-bit offset and everything above it is the VPN. The PTE carries more than the frame number — a valid/present bit, protection bits (read/write/execute, user/supervisor), and the accessed and dirty bits that the replacement machinery of §5 lives on. The valid bit is what makes sparse address spaces cheap: unused ranges are simply marked invalid, and no frame is ever allocated for them.

Two consequences matter immediately for runners:

1. **Contiguity is a virtual property only.** A 40 GB weight array that is perfectly contiguous in the runner's address space is, physically, tens of thousands of frames scattered wherever the kernel found them. Nothing in the program can tell — until performance says otherwise: physical scatter is invisible to correctness and visible to the TLB (§3), to huge-page formation (§3.4), and to NUMA placement (§6).
2. **Every access pays translation.** In the naive model, each load or store needs *two* memory references: one to fetch the translation, one to fetch the data. OSTEP states the problem in exactly those terms, and it is the entire reason the TLB exists (§3.1). Paging buys flexibility and simple free-space management — any free frame serves any page, so external fragmentation of physical memory disappears by construction — at the price of making translation a per-access cost that hardware must then hide.

### 2.2 Page tables: why one level was never going to survive

A flat ("linear") page table is an array with one entry per virtual page. OSTEP's arithmetic shows why that cannot scale: a 32-bit address space with 4 KiB pages has 2²⁰ pages; at 4 bytes per entry the table alone is 4 MiB *per process* — and a 64-bit space makes the flat form absurd (OSTEP Ch. 18 §18.2 [S1]). Real page tables are therefore **multi-level**: a tree in which each level indexes a slice of the VPN, and subtrees for unmapped regions are simply never allocated. Sparsity of the address space becomes sparsity of the table.

On x86-64 the production form is a 4-level tree for 4 KiB pages (a 5th level exists on newer parts and kernels, widening the virtual space; the mechanics are identical). The levels are conventionally named, from the root the CPU's page-table base register (CR3 on x86) points at:

```
virtual address ──► [PML4 index] → [PDPT index] → [PD index] → [PT index] → [offset]
                      PML4 entry     PDPT entry     PD entry     PT entry
```

Each level is itself one page of entries (512 entries × 8 bytes at 4 KiB pages), and each step of a **page walk** is a dependent memory read: you cannot know where the PD table lives until you have read the PML4 entry that points to it. A full 4-level walk is therefore up to four *serial* memory accesses before the data access itself can begin (§3.3 prices this). The tree's saving grace is the same sparsity: a process that maps a few gigabytes in a few large regions has a small, cache-friendly upper tree, even though its leaf level is large.

The huge-page mechanism (§3.4) is, structurally, nothing more than *stopping the walk early*: a PD entry with its page-size bit set names a 2 MiB frame directly instead of pointing to a PT page; a PDPT entry can likewise name a 1 GiB frame. One entry, one translation, 512× or 262,144× the coverage of a base-page entry.

**What this does to an LLM workload.** Page-table memory itself is a real, usually uncounted, line in the runner's budget. At 8 bytes per PTE, a 40 GiB resident set at 4 KiB pages needs ~10.5 million leaf entries ≈ 80 MiB of leaf page tables, plus upper levels — small next to the weights, but not zero, and it is kernel memory that competes on a unified-memory machine (§5.4). The same set at 2 MiB pages needs ~20 thousand entries ≈ 160 KiB. When §7 asks why huge pages matter beyond TLB reach, this 512× collapse in table footprint — and the cache pressure the tables themselves exert — is the second half of the answer.

### 2.3 Page size as the fundamental quantum

Everything in the VM system is denominated in pages, so the choice of page size is the choice of the system's quantum — the smallest unit that can be mapped, faulted, protected, reclaimed, or shared independently. The sizes in play on our fleet and its neighbours:

| Quantum | Where it appears | Notes |
|---|---|---|
| 4 KiB | x86-64 base page; most Linux/Windows defaults | The historical default; the unit of the fault, TLB, and page-cache arithmetic throughout this dossier unless stated |
| 16 KiB | Raspberry Pi (Mimir) host page size in our records; Apple Silicon base page; newer ARM Linux configurations | MimirAlloc's Pi campaign ran entirely at 16 KiB — one reason its verdicts did not transfer to the 4 KiB Z13 (see `memory/mimiralloc-our-own-proven-work.md` §2) |
| 64 KiB | ARM configurations; some HPC Linux builds | A middle road: 16× the TLB reach and 1/16 the table size of 4 KiB, without huge pages' alignment demands |
| 2 MiB | x86-64 "huge" page (PMD level); Linux THP size on x86-64 | The workhorse huge size; §3.4 |
| 1 GiB | x86-64 "gigantic" page (PUD level); hugetlb reservations | Rarely transparent; usually pre-reserved. Reach is enormous; flexibility is poor |

The quantum cuts both ways, and the trade is worth stating precisely because §3 and §5 both spend it:

- **Smaller pages** waste less inside a partially-used mapping (internal fragmentation is bounded by one page per mapping), fault in less unneeded data, and let reclaim be surgical. They cost more entries everywhere: more PTEs, more TLB pressure, more faults per gigabyte touched.
- **Larger pages** invert every term: fewer entries, fewer faults, vastly more reach — and any byte touched pins the whole page, any dirty byte dirties the whole page, and reclaim can only move in page-sized lumps.

There is no free direction. The art, in §7's terms, is matching the quantum to the access shape: streaming weights want the largest quantum available; sparse, long-lived small structures want the smallest.

### 2.4 The page fault as the unit of surprise

A **page fault** is not an error. It is the routine trap the hardware raises when an access finds no usable translation — PTE invalid, not present, or protection violated — handing control to the kernel to decide what the access *means*. OSTEP's beyond-physical-memory chapters build the whole swapping edifice on this one trap (OSTEP Ch. 21 [S5]); the Linux fault path distinguishes the cases that matter for pricing:

- **Minor (soft) fault — the page is already in RAM; only the mapping is missing.** First touch of anonymous memory (the kernel supplies a zero page, then a private frame on write), a file page already in the page cache (§5.3) that this process has not mapped yet, a copy-on-write break, a stack growth. No disk I/O. Cost is kernel bookkeeping: order of a few microseconds per page in the measurements summarised by the secondary sources read for this dossier (≈2.3 µs per page for first-touch anonymous on a VM, in one such summary [S9] — treat as an order of magnitude, not a constant; it varies with kernel, contention, and page size).
- **Major (hard) fault — the page must be read from storage.** The faulting thread sleeps while the page comes in. Cost is a storage read: order of ~100 µs on NVMe, milliseconds on spinning disk [S9][S10]. Three orders of magnitude above a minor fault, and it lands on whichever thread happened to touch the page first.
- **Invalid fault — the address was never the process's to touch.** The kernel delivers SIGSEGV. This is the only fault that is actually an error.

**Demand paging** is the policy of resolving mappings lazily: `mmap` (§2.5) creates the *promise* of memory, and each page is materialised only when first touched, by a fault. Its opposite — pre-faulting everything at map time — is available (`MAP_POPULATE`, `MADV_WILLNEED`, an explicit touch loop) and is sometimes exactly right (§5.3, §7.1), but laziness is the default because most reservations are never fully touched and most files are never fully read.

**What this does to an LLM workload — the accounting that warm benchmarks hide.** Price a cold model load in faults. A 28.6 GiB resident model (the Z13's 27B at Q8_0, per `memory/unified-memory.md` §3.4) at 4 KiB pages is ~7.3 million pages. If every one arrived by individual minor fault at ~2 µs, first touch alone would be ~15 seconds of pure fault handling; major faults from cold storage are worse per page but are batched by readahead (§5.3) into large I/Os, which is why real cold loads take seconds rather than minutes. The point is not the exact figure — it is that **load time, time-to-first-token, and the first decode pass over a cold region are all denominated in faults**, and any runner measurement that does not separate cold (fault-paying) from warm (fault-free) runs is averaging two different machines. The corpus's measurement law (MEMORY-COMPENDIUM Ch. 9) — phases separately, machine state stated — applies to faults with full force: report major/minor fault counts (`/usr/bin/time -v`, `ps -o min_flt,maj_flt`, `/proc/<pid>/stat`) beside any cold-start number, or the number does not transfer.

A second, quieter consequence: **the thread that faults pays.** Under demand paging, whichever thread first touches a page absorbs its fault latency — and, on NUMA, chooses its home node (§6). Loader-thread design is therefore latency design and placement design simultaneously, whether the runner intends it or not.

### 2.5 mmap: the real allocation API beneath every allocator

Programmers meet memory through `malloc`, language runtimes, and tensor libraries. The kernel meets it through exactly one door: **`mmap`** (and its historical sibling `brk`/`sbrk`, now a thin legacy path). `mmap` creates a mapping in the caller's virtual address space — a range of virtual pages with a protection, a sharing mode, and a backing (Linux `mmap(2)` man page, accessed 2026-11-15 [S6]):

- **Anonymous mappings** (`MAP_ANONYMOUS`) have no file behind them. They are the raw material of heaps and arenas: zero-filled on demand, swappable, reclaimed by unmapping. Every large allocator allocation ultimately becomes one of these (or a slice of a larger one).
- **File mappings** name a file and an offset; the mapping's pages *are* the file's pages, demand-paged through the page cache (§5.3). This is how model files are loaded by llama.cpp/Ollama-class runners: the GGUF is mapped, not read, and "loading" is the controlled faulting-in of its pages.
- **`MAP_POPULATE`** asks the kernel to prefault the mapping at map time — for a file mapping, to read it ahead — trading a slower `mmap` call for freedom from blocking faults later [S6]. **`MAP_NORESERVE`**, **`MAP_LOCKED`** (pin against reclaim/swap), and **`MAP_HUGETLB`** (back the mapping from the reserved huge-page pool) complete the small set of flags a runner actually steers with.

Above this door sit the allocators, and the connection to the corpus's allocator dossier is direct and should be stated as a dependency, not an analogy: **jemalloc, tcmalloc, mimalloc, glibc's allocator, Go's runtime, and MimirAlloc are all, at bottom, policies for carving, caching, and returning `mmap` extents** (`memory/allocator-lineages.md` §§2, 5). Their famous differences — size classes, thread caches, decay timers, eager purging — are differences in *mmap policy*: how big an extent to request, when to ask for more, when to give pages back (`munmap`, or `madvise(MADV_DONTNEED)` / `MADV_FREE` to release the physical backing while keeping the virtual range), and at what page-size alignment. Go's runtime is the clearest documented case: its heap is a set of large virtual arenas whose physical backing is committed and released by the scavenger under the GC's direction — virtual space is never unmapped, only decommitted (allocator dossier §5.2). When §7.3 reads MimirAlloc's large path "through VM economics," this is the economics meant: a fresh `mmap` per large allocation is a fresh negotiation with everything in §2.1–§2.4 — page tables to build, faults to take, TLB entries to earn — repeated per allocation, where an arena pays it once.

`madvise` is the steering wheel for an existing mapping, and it deserves naming here because §3.4, §5.3, and §7 all turn its levers: it advises the kernel about a range's expected use so the kernel can choose readahead, caching, and page-size policy accordingly (Linux `madvise(2)` man page [S7]). The levers that matter to runners are tabulated in §5.3; the mechanism to hold is that *advice is the only channel by which a program's knowledge of its own access pattern reaches the VM system* — and runners know their access patterns better than almost any other workload class. Not using the channel is a decision, and usually the wrong one.

---

## 3. The TLB Economy

### 3.1 The TLB: a cache for translations, sized like a cache

The **translation lookaside buffer (TLB)** is a small hardware cache inside the MMU holding recent virtual-to-physical translations. OSTEP's Ch. 19 puts its role without understatement: on every memory reference the hardware checks the TLB first; on a hit, translation completes without touching the page table at all; on a miss, the page table must be consulted and the TLB refilled — and it is this hit rate, in OSTEP's framing, that "in a real sense makes virtual memory possible" (OSTEP Ch. 19 [S2]).

OSTEP's teaching numbers — a typical TLB of 32, 64, or 128 entries, fully associative — are the right shape for L1 TLBs and the right era to learn the idea from. Production parts today are two-level, like the data caches they parallel (vendor figures vary by microarchitecture; the ranges below are from the public summaries read for this dossier [S11][S12], and any design decision should be taken against the specific part's manual):

| Level | Typical entries (4 KiB pages) | Character |
|---|---|---|
| L1 dTLB / iTLB | ~64–128 (e.g. 72 data / 64 instruction on AMD Zen 5; 96 / 128 on Intel Golden Cove P-core, as reported [S11]) | Per-core, fully or highly associative, hit in ~1 cycle alongside L1 access |
| L2 TLB (STLB) | ~1,024–4,096 (e.g. 2,048 on Zen 5; 4,096 on Golden Cove, as reported [S11]) | Unified, set-associative, hit in on the order of ~7–10 cycles |

Two structural facts matter more than the counts. First, TLBs are commonly **split by page size**: entries for 2 MiB and 1 GiB pages live in separate (smaller) pools than 4 KiB entries, so the arithmetic of §3.2 must be done per size class, not on a single lumped total [S12]. Second, entries are tagged by address-space identifier on modern parts, so a context switch no longer flushes the whole TLB — but two processes' working sets still *share* its capacity, which is why a co-tenant's streaming workload can evict a runner's translations (§5.1's working-set competition, one level down).

### 3.2 TLB reach: the one multiplication that governs §3

**TLB reach = entries × page size.** It is the largest virtual range whose translations can all be resident at once — the working set, measured in pages, that a program can touch without a translation miss (definition as used in OSTEP-derived teaching and the TLB references read [S11][S12]).

Do the arithmetic at the scales a runner actually lives at, using a representative 2,048-entry L2 TLB:

| Page size | Reach (2,048 entries) | Pages in a 40 GiB weight set | Fraction of the set the TLB can hold |
|---|---|---|---|
| 4 KiB | 8 MiB | ~10.5 million | 0.02 % |
| 2 MiB | 4 GiB | ~20 thousand | 10 % |
| 1 GiB | 2 TiB (theoretical; 1 GiB entries are far fewer in practice) | 40 | all of it, many times over |

At the L1 level the picture is starker: 64 entries × 4 KiB = 256 KiB of reach — smaller than a single transformer layer's weight slice for any serious model.

Read the middle row carefully, because it is the whole huge-page argument in one line: **moving from 4 KiB to 2 MiB pages multiplies reach by 512 without adding a single TLB entry.** A 4 GiB reach does not cover a 40 GiB stream either — but decode does not need the whole stream's translations resident *simultaneously* in the way a random-access workload would. A sequential stream needs, at any instant, the translations for the pages it is currently passing through plus prefetch lookahead; misses arrive at page boundaries, one per 2 MiB instead of one per 4 KiB, and each miss is amortised over 512× as much data. §3.3 prices the miss; §4.4 explains why the stream survives anyway; the reach table is what makes the two compatible.

The honest caveat, carried from the sources [S12]: reach is an *upper bound*. Set-associative conflicts, entries reserved per page size, and co-tenant pressure all reduce effective reach below entries × size. Treat it as the roofline of translation — a ceiling you approach with good locality, not a guarantee.

### 3.3 Page-walk costs: what a miss actually pays

On a TLB miss, hardware on x86 walks the page table (§2.2): up to four dependent memory reads for a 4-level table with 4 KiB pages (three if a 2 MiB PD entry terminates the walk, two for 1 GiB). Modern walkers keep **paging-structure caches** that hold upper-level entries, so the common miss is much cheaper than the worst case — often only the leaf level needs fetching, and if the PTE is in the data caches the refill costs on the order of a dozen cycles [S11]. The worst case is the honest bound to design against: if every level misses every cache, four serial DRAM accesses at ~60–100 ns each put the walk in the several-hundred-cycle range (one public deep-dive estimates up to ~800 cycles including the eventual data access [S11]) — paid *before* the load that caused it can proceed, and paid again at the next page boundary if the working set has already evicted the entry.

Two multiplier effects deserve explicit mention:

- **Shootdowns.** When a mapping changes — `munmap`, `mprotect`, a THP collapse or split, a page migration — every core that may hold the stale translation must be told to invalidate it. That is a TLB shootdown: an inter-processor interrupt plus invalidations on potentially many cores. A long-lived, rarely-remapped weight arena generates essentially none. An allocator that maps and unmaps per allocation (§7.3) generates them as a steady tax on *all* cores, including cores doing unrelated work.
- **Nested translation.** Under virtualisation, a guest's walk is itself translated by the host's tables, multiplying walk length. The THP documentation notes that faster TLB-miss handling is disproportionately valuable there (Linux kernel THP documentation [S3]). Our fleet runs runners on bare metal and in VMs both; the VM case is strictly worse per miss, which strengthens, not weakens, the huge-page argument inside guests.

**What this does to an LLM workload.** Decode's weight stream at 4 KiB pages takes a TLB miss every 4 KiB of progress per stream — with dozens of concurrent streams (one per layer tensor, per KV region, per activation buffer) interleaved, the L1 TLB thrashes continuously and the L2 TLB cycles far below its nominal reach. The resulting walk traffic is *extra memory traffic* competing for the same bandwidth the roofline budget already spent on weights. It rarely dominates — walks hit paging-structure caches and PTEs are cache-resident for a hot stream — but it is a real, measurable slice of the gap between achieved and sustained bandwidth, and it is the slice that huge pages delete almost entirely. **[Engineering judgement]** On a bandwidth-bound workload, translation overhead should be treated as a bandwidth tax and measured as one (`perf stat` TLB-miss counters against bytes streamed), not chased as a latency curiosity.

### 3.4 Huge pages: 2 MiB / 1 GiB, explicit and transparent

A **huge page** is a mapping whose PTE lives one or two levels higher in the tree (§2.2), so one entry covers 2 MiB (PMD level) or 1 GiB (PUD level) of contiguous virtual *and* physical memory. The contiguity requirement is the price: the kernel must find 2 MiB of physically contiguous, 2 MiB-aligned free memory, which is why huge-page availability degrades on a fragmented, long-up machine and why the mechanisms for obtaining them differ:

- **Explicit huge pages (hugetlbfs / `MAP_HUGETLB`).** A pool reserved in advance, allocated from only on request. Guaranteed if reserved; wasteful if the reservation sits idle; inflexible under changing load. The database/VM-host road.
- **Transparent Huge Pages (THP).** The kernel promotes eligible anonymous (and, in newer kernels, shmem and read-only file) mappings automatically: either at fault time, if a suitably aligned contiguous extent is available, or later, when the `khugepaged` daemon scans and *collapses* 512 resident base pages into one huge page (Linux kernel THP documentation, accessed 2026-11-15 [S3]). Policy is global — `/sys/kernel/mm/transparent_hugepage/enabled` = `always` / `madvise` / `never` — and per-range via `madvise(MADV_HUGEPAGE)` / `MADV_NOHUGEPAGE`, with `MADV_COLLAPSE` (since Linux 6.1) available to force a synchronous best-effort collapse [S7]. The defrag policy (`defrag` = `always` / `defer` / `defer+madvise` / `madvise` / `never`) decides who pays when no contiguous extent is free: the faulting thread stalls in direct reclaim/compaction under `always`, or the attempt defers to background threads under `defer` [S3].

The kernel documentation's own accounting of *why* THP pays is worth restating in our words because it corrects a common misattribution [S3]. The smaller factor is fault count: one fault per 2 MiB region instead of 512 — a 512× reduction in fault-path entries, which matters only on first touch. The larger, lasting factor is translation: every subsequent access benefits from TLB entries that each cover 512× more memory (fewer misses) *and* from shorter walks when misses do occur (the walk terminates one level early). Huge pages are a *steady-state translation* optimisation with a first-touch bonus, not the reverse.

The costs are equally documented and must travel with the recommendation [S3][S7]: a sparsely-touched 2 MiB region pins 2 MiB where 4 KiB would do (the docs' example: touching 1 byte can wire 2 MB); fault-time compaction under aggressive defrag settings can stall the touching thread; collapse/split work by `khugepaged` is background CPU spent on bookkeeping; and a huge page is the unit of reclaim and migration, so one hot byte keeps 2 MiB resident. THP is therefore a *placement* decision for known-dense, known-hot ranges — weight arenas are the textbook case; sparse caches and mostly-empty reservations are the textbook counter-case.

### 3.5 Our own evidence: the MimirAlloc Z13 THP slices

The corpus does not have to take THP on the literature's word. The MimirAlloc Z13 campaign measured huge-page adoption directly, on purpleraider (Strix Halo, 4 KiB base pages), and the results are banked in `memory/mimiralloc-our-own-proven-work.md` §4.3, which governs the figures here:

- **Z-013** recorded an early **THP win at 2 MiB and 20 MiB** allocation scales, with the 200 MiB bandwidth result unstable and explicitly deferred to a later slice at the time.
- **Z-049**, the dedicated huge-page/fault study, recorded the mature verdict: **2 MiB — ADOPT, but bimodal on PMD alignment** (the win depends on the mapping actually landing PMD-aligned; an unaligned 2 MiB request gets base pages and base-page costs, which is why the result distribution has two modes rather than one noisy mode); **20 MiB — ADOPT (WIN)**; **200 MiB — ADOPT on fault behaviour, with bandwidth TIE**.

Read those three lines as one lesson, because it generalises beyond MimirAlloc: **at weight-arena scales, huge pages win first and most reliably on the fault axis** — fewer faults, cheaper first touch, shorter walks — **while steady-state bandwidth, already bounded by the DRAM system (§4), may not move at all.** A team that benchmarks THP by warm streaming bandwidth alone can honestly measure "no difference" and wrongly conclude huge pages do nothing; the Z-049 shape (fault WIN, bandwidth TIE at the largest size) is the expected signature, not a disappointment. The alignment bimodality is the operational half of the lesson: huge-page policy that does not also control *alignment* (2 MiB-aligned extent requests from the allocator) collects only the aligned fraction of the win.

Two scope cautions, in the corpus's own discipline. First, these are allocator-path measurements on one machine, not decode benchmarks; they price faults and allocator-visible bandwidth, and §7 states the transfer to runner weight arenas as engineering judgement built on them, not as a measured decode result. Second, the Z13's page size is 4 KiB; on the 16 KiB-page Pi the same questions would be asked at different quanta (§2.3), and the Pi campaign's silence on THP is a gap, not a negative result.

---

## 4. The Cache Hierarchy as Programmers Must Hold It

### 4.1 The ladder, in orders of magnitude — Drepper's numbers, dated, and their modern correction

The canonical programmer-facing treatment remains Ulrich Drepper's *What Every Programmer Should Know About Memory* (2007) — written for the Linux/x86 commodity hardware of its day, structured around one motto: memory access is the limiting factor for most programs (Drepper 2007, accessed 2026-11-15 via the public PDF [S4]). Its cache section gives the era's ladder in cycles, and the figures are worth quoting *as 2007 figures* because their ratios, more than their values, are the durable content:

| Level | Drepper (2007) [S4] | Modern commodity correction (qualitative; ranges across current x86-64 / ARM cores, from the public summaries read [S13][S14]) |
|---|---|---|
| Register | ≤ 1 cycle | Unchanged: ~1 cycle |
| L1d | ~3 cycles | ~4 cycles; 32–48 KiB per core (split L1d/L1i) |
| L2 | ~14 cycles | ~12–14 cycles; 256 KiB–2 MiB per core, now typically private |
| L3 / LLC | (not yet the universal third level in the 2007 baseline figures) | ~30–50 cycles; tens of MiB shared (32 MiB per CCD on Strix Halo, per our Z13 records) — the level that did not exist in Drepper's headline table is now the interesting one for small-model work |
| Main memory | ~240 cycles (via the front-side bus) | ~200–300 cycles, ~60–100 ns; the bus is gone (integrated controllers), the latency in cycles is not |

Three corrections, stated qualitatively as the task's quality law requires, because exact figures vary by vendor, part, and clock:

1. **Capacities grew by roughly an order of magnitude per level; latencies in cycles barely moved.** That asymmetry *is* the memory wall (MEMORY-COMPENDIUM Ch. 1) expressed inside the chip: each generation buys room, not speed, so the working-set thresholds at which a kernel falls off a level keep moving while the cost of falling stays ~50–100× per level missed.
2. **The LLC became a design variable.** A quantised small model, a KV tile, or a hot expert subset that fits in a modern LLC (tens of MiB) runs at L3 latency and at many times DRAM bandwidth. "Fits in L3" was a curiosity in 2007; for 1–3B-class models at low precision, and for per-step KV slices of larger ones, it is now a real operating regime — the corpus's PowerInfer dossier (`runners/powerinfer.md`, hot/cold neuron placement) exploits exactly this boundary.
3. **DRAM latency in nanoseconds improved modestly; in cycles it worsened**, because clocks rose faster. Any latency quoted without its unit and its era — the failure Drepper's table is most often subjected to — is folklore. This dossier's rule, following the corpus: cycles for intra-chip reasoning, nanoseconds for cross-machine comparison, era and source attached to both.

**What this does to an LLM workload.** Hold the ladder against decode's access pattern and the pattern's cruelty becomes precise: the weight stream has *no* level it fits in above DRAM, so every byte is bought at DRAM latency and bandwidth — but it is bought *once per step, in order*, which is the one pattern DRAM and prefetchers serve best (§4.4). The KV cache, by contrast, is re-read whole every step: at short context it can be LLC-resident and cheap; at long context it spills to DRAM and joins the weight stream in the per-token byte bill (KV dossier §1.2's "taxed twice" result). Activations and per-step scratch are the only genuinely cache-shaped data in the system — small, hot, reused within the step — and they are where tiling and SRAM discipline (the FlashAttention lineage, MEMORY-COMPENDIUM Ch. 4) earn their keep. Three data classes, three different levels of the ladder, three different optimisations: a runner that speaks of "the cache" in the singular has already confused them.

### 4.2 Cache lines: the true transfer unit

Caches do not move bytes. They move **cache lines** — fixed-size blocks, **64 bytes** on x86-64 and most ARM cores (128 bytes on Apple Silicon, per the summaries read [S14]) — and every consequence in this section is arithmetic on that one fact (Drepper 2007 §3 [S4]):

- A load of one byte fetches its whole line. Sixteen consecutive FP32 weights cost one miss, not sixteen; the other fifteen are free *if the program goes on to use them* — spatial locality, cashed.
- A scattered access pattern pays a full line (and a full DRAM round trip's bandwidth share) for every element it actually uses. Pointer-chasing through a token graph or a hash table is not "a bit slower" than streaming; at 4 useful bytes per 64-byte line it wastes 94% of the bandwidth it consumes.
- Writes are line-granular too, and dirty lines are written back whole — which is why false sharing (two cores writing different variables that share a line, forcing the line to ping-pong between them under the coherence protocol) is an allocator/layout bug, as the allocator dossier's Hoard section establishes, not an application misfortune.

For tensor code the line is the floor of all vectorisation reasoning: a GEMV that reads weights in 64-byte-aligned, unit-stride sweeps is requesting exactly the transfers the hardware wants to make; any layout that strides by more than a line per element (column-major traversal of a row-major tensor, per-head interleavings read per-token) multiplies DRAM traffic by the stride factor. Quantised formats earn part of their speed here, beyond the obvious byte saving: a Q4 weight block packs more weights per line, so each fetched line carries more arithmetic.

### 4.3 Associativity and conflict pathology, in one paragraph

A cache line's address determines which *set* of lines it may live in; the number of lines per set is the cache's **associativity** (direct-mapped = 1, fully associative = any line anywhere, production caches = typically 8–16 ways at L1/L2). Associativity exists because direct mapping has a pathological failure: two hot lines whose addresses collide in the same set evict each other on every access, even while the rest of the cache sits empty — *conflict misses*, losses with capacity to spare. The LLM-shaped instance to recognise is the power-of-two stride: tensors whose row length is a large power of two map successive rows to the same sets, so a nominally LLC-resident working set can thrash a single set and perform like a much smaller cache. The classical defences are the hardware's (more ways, hashed indexing on modern parts) and the layout's (padding rows by a line, skewing tile offsets — the same instinct as slab colouring in the allocator dossier §3.2). One paragraph is what this topic gets because runners rarely choose cache geometry — but they *do* choose tensor strides, and a mysterious 2× that appears only at certain dimensions is a conflict pathology until proven otherwise.

### 4.4 Prefetchers: why streaming works at all

DRAM latency (~200+ cycles) cannot be hidden by caches for a stream that fits in none of them. It is hidden by **prefetching**: hardware that watches the miss stream, detects regular patterns — unit stride, constant stride, sequential lines — and issues fetches for lines not yet demanded, so the data is in flight or resident when the core arrives (Drepper 2007 [S4] treats prefetching as a first-class part of the memory system; the prefetcher taxonomy in the summaries read distinguishes stream, adjacent-line, and stride/pattern prefetchers [S13]).

Decode's weight streaming is the prefetcher's best case, and this deserves to be said as a positive law, not a consolation: **a single, long, unit-stride, never-revisited sweep is the most predictable access pattern a program can present.** Given a few lines to detect the stream, the prefetcher runs ahead, multiple misses are outstanding in parallel, and the core consumes bandwidth rather than latency — Little's law (MEMORY-COMPENDIUM Ch. 1) satisfied by hardware on the program's behalf. This is *the* reason a bandwidth-bound workload can approach sustained DRAM bandwidth at all; without prefetch, every 64-byte line would cost a serial latency, and decode would run an order of magnitude slower than the roofline ceiling.

The boundaries of the gift are as important as the gift:

- **Prefetchers do not cross page boundaries speculatively with the same freedom** — a translation must exist (or be cheaply obtainable) for the next page before its lines can be fetched, and TLB-miss handling at stream heads is part of why §3's reach still matters inside a streaming workload [S11]. Huge pages widen the runway: one translation covers megabytes of prefetchable stream.
- **Interleaved streams compete.** Prefetchers track a limited number of streams; a decode step that interleaves weights, KV, and activations presents several, and layer-fused kernels that keep the stream count low are, among other things, prefetcher-friendly.
- **Random access gets nothing.** Attention's gather over a long KV cache, sparse/MoE expert selection, and sampling structures are stride-less patterns; they pay latency the stream was spared. This asymmetry — weights stream, KV gathers — is a hardware fact that KV layout (§3.3 of the KV dossier: orientation chosen for the decode read) is designed around.

---

## 5. Working Sets, Thrashing, and the Page Cache

### 5.1 Working sets and thrashing: the vocabulary of "too much"

Peter Denning's **working set** (1968) names the set of pages a process has referenced in a recent window of its execution — the pages that must be resident if the process is to run without faulting constantly. The definition's power is that it converts a vague condition ("the machine is overloaded") into an arithmetic one: **if the sum of the working sets of all runnable processes exceeds physical memory, the system thrashes** — every fault evicts a page another process (or the same one, moments later) needs next, fault rates explode, CPU utilisation collapses, and the machine spends its life paging instead of computing (OSTEP Ch. 22's policy treatment and the working-set literature as summarised in the sources read [S10][S15]). The companion control idea, page-fault frequency, allocates frames to keep each process's fault rate inside a band — more frames when faults run hot, fewer when cold.

Linux does not implement Denning's model literally; it implements its descendants — active/inactive list management with referenced-bit sampling (a clock-family approximation to LRU), per-cgroup reclaim, and, in recent kernels, multi-generational LRU (MGLRU) — but the *diagnostic* vocabulary transfers unchanged, and §5.4 uses it on our own incident.

**What this does to an LLM workload.** A runner's working set has a peculiar shape: an enormous, slowly-cycling streaming component (weights — every page touched once per token, so at any window longer than a step the *whole model* is in the working set) plus a hot, small, truly resident component (current KV head, activations, code). Classical working-set logic was built for programs whose hot set is a small fraction of their footprint; a decode process's hot set *is* its footprint. Two practical consequences:

1. **A resident model cannot be "partially swapped" gracefully.** If physical memory cannot hold the weights plus everything else, the system does not degrade to "slightly slower model" — it degrades to re-faulting weight pages from storage or swap *every token*, which is thrashing with a per-token period. The failure is categorical, and §5.4 shows it wearing a desktop's clothes.
2. **Co-tenancy is working-set addition.** The runner plus a browser plus a compositor plus a second runner do not each get a machine; their working sets sum against one RAM. Admission control (§7.1) is working-set arithmetic done in advance, by the runner, instead of in arrears, by the kernel's OOM killer.

### 5.2 Demand paging of model files: first-token latency is a paging event

Return to §2.5's file mapping with §5.1's vocabulary. When a runner `mmap`s a GGUF and begins prefill, the weight pages are not resident; they arrive by fault, in the order prefill touches them, read from storage through the page cache. Therefore:

- **Time-to-first-token (cold) = page-in of the prefill working set + compute.** For a multi-GB model on NVMe at several GB/s, page-in alone is seconds; on a warm run (pages already cached, §5.3) it is ~zero. Cold and warm TTFT are different metrics and must never be averaged (the corpus's discarded 56.7 tok/s cold reading, §1, is this error caught in the wild).
- **The first decode sweep is a second cold pass.** Prefill touches weights in GEMM order; decode touches them in GEMV order — largely the same pages, so a full prefill usually warms the set, but any region prefill skipped (experts not routed, layers offloaded, a second model in a pipeline) faults on its first decode touch instead, mid-generation, as a latency spike with no compute cause.
- **Fault order is loader order.** Because the faulting thread pays (§2.4), a loader that touches pages in file order on one thread serialises storage latency; a loader that prefaults in parallel (multiple threads touching disjoint ranges, `MADV_WILLNEED` issued ahead, `MAP_POPULATE`) overlaps it. Load-time engineering *is* fault-scheduling engineering.

### 5.3 The page cache and readahead: the invisible second copy

File pages read from storage do not pass through memory; they *stay* in it, in the **page cache** — the kernel's cache of file contents, occupying otherwise-free RAM, evictable under pressure because the file itself is the backing store. An `mmap`ed file's pages and the page cache are the same pages: mapping a file does not copy it, and reading it by `read()` populates the same cache the mapping faults against.

Three consequences, each routinely missed in runner RAM budgets:

1. **The "second copy" is real but it is not a copy.** After a model has been loaded once, its pages sit in the page cache. A second process mapping the same file faults *minor* (§2.4) against those resident pages — fast — and the pages are *shared*: two runners on one model file do not double the physical footprint of the read-only weight pages. But a budget that counts "model size × processes" overstates, and a budget that counts page cache as "free memory" understates what reclaim will actually have to do under pressure, because cache pages are only free *after* eviction work. The honest instruments are the four numbers of the allocator dossier §6.1, with page cache named as its own line — `free`'s "buff/cache" column is the page cache wearing a summary's clothes.
2. **Readahead is the kernel's prefetcher for storage.** On detecting sequential access to a file (or a mapping faulting sequentially), the kernel reads ahead of the fault — issuing larger, batched I/O so subsequent faults hit resident pages. It is the storage-level twin of §4.4's hardware prefetcher, with the same best case (a model file read in order) and the same failure (random access defeats it and wastes I/O on unread pages). The runner controls it through the `madvise` levers below — which is to say, the runner *is* responsible for telling the kernel which case it is.
3. **Dirty and writeback asymmetry.** Read-only weight mappings are clean pages: eviction is free (drop them; re-read if needed). Anonymous and written pages (KV arenas in host RAM, activation buffers, a page cache dirtied by *writing* model files) must be written to swap or their file before reuse, which makes their eviction slower and their pressure more dangerous (§5.4).

The `madvise` levers, as documented in the man page [S7], tabulated for runner use:

| Lever | Documented effect [S7] | Runner use |
|---|---|---|
| `MADV_SEQUENTIAL` | Expect sequential access; kernel may read ahead aggressively and free pages soon after access | A weight file consumed in one pass and not re-read (rare for runners — weights *are* re-read every token; see the warning below) |
| `MADV_RANDOM` | Expect random access; minimise readahead | Genuinely random file access (embedding lookups over a mapped table); *wrong* for weight streams |
| `MADV_WILLNEED` | Expect access soon; kernel starts reading the range in now | Prefaulting the next model / next layer range ahead of the compute that needs it — the explicit form of §5.2's fault scheduling |
| `MADV_HUGEPAGE` / `MADV_NOHUGEPAGE` | Opt a range into / out of THP (§3.4) | Weight arenas in; sparse or footprint-sensitive ranges out |
| `MADV_DONTNEED` | Release the range's resources; next access re-faults (zero page for anonymous, file contents for file-backed) | The allocator's give-back verb (§2.5); also how a runner sheds a cold model's pages without unmapping |
| `MADV_FREE` | Mark pages freeable under pressure, contents preserved until actually reclaimed | jemalloc's muzzy state and mimalloc's reset mode ride on this class of lazy release (allocator dossier §§2.4–2.5) |

**Warning, stated plainly because it is the most common `madvise` error in inference code:** weights are *not* `MADV_SEQUENTIAL` in the kernel's sense, despite being read sequentially. The man page's contract for sequential ranges is "accessed once, freeable soon after" [S7] — but a resident model's pages are accessed once *per token*, forever. Marking them sequential invites the kernel to drop pages the next token needs, converting a warm stream into a perpetual major-fault loop. The correct advice for weights is usually *no* readahead advice at all (the default readahead already suits the stream), plus `MADV_WILLNEED` at load and `MADV_HUGEPAGE` where §3.4 applies. Advice is semantics, not decoration.

### 5.4 Swap, pinning, and the Z13 cascade of 2026-11-14 — referenced, not re-derived

Swap is the page system's pressure valve for *anonymous* pages: under memory pressure, cold anonymous pages are written to swap space so their frames can serve hotter uses, and faulted back if touched again (OSTEP Ch. 21 [S5]). File-backed clean pages need no swap — their file is their swap. Two properties decide swap's role in any incident: **pinned pages cannot be swapped** (locked, or held by a subsystem that has pinned them against reclaim), and **swap bandwidth is storage bandwidth** — a working set that genuinely exceeds RAM will thrash against swap at storage speed (§5.1), which is a failure mode, not a tier.

The full forensic account of the Z13's 2026-11-14 cascade lives in `memory/unified-memory.md` §§2.5, 3.3, 5, and this dossier references it rather than re-deriving it, per its commission. The VM-economics summary, in this dossier's vocabulary, is:

- Purpleraider's GPU allocations are mappings of the *same* physical pool the OS pages in (`unified-memory.md` §2.2: GTT is a mapping budget, not a separate memory). At the pre-fix setting, the GPU could map ~124 GiB of the machine's 128 GiB.
- GPU-held pages during inference are **pinned in practice** — unswappable and not reclaimable by the OOM killer (unified-memory dossier §2.5, items 5–6). Swap — a ~125 GB partition — was therefore *structurally unable* to absorb the pressure that mattered: the swappable remainder was small, and the OOM killer fired while swap sat largely unused, killing the desktop session while the largest pinned tenant (a 44.2 GB resident model) survived untouched (dossier §3.3).
- In working-set terms (§5.1): the sum of working sets exceeded the pool, but the *evictable* sum did not cover the excess, because the plurality was pinned. Thrashing's modern UMA form is not a fault storm; it is an OOM kill of the bystanders.

The standing remedies are recorded in the same dossier and in force (GTT capped at 100 GiB, heavy runs fenced in cgroups, MemAvailable headroom checks) — they are budget mechanisms, and §7.1 generalises them into runner policy. The lesson this dossier adds is taxonomic: **on a unified machine, "swap exists" is not evidence that memory pressure is survivable.** The questions that decide survival are how much of the working set is pinnable by accelerators, and whether the runner's own budget counts pinned bytes as spent. §7 returns to both.

---

## 6. NUMA at the Boundary — One Section, Deliberately

A full NUMA dossier is a separate commission (field map B3); this section covers only the seam where paging meets node locality, because a runner cannot load a model correctly without it.

On a **NUMA** (non-uniform memory access) machine, physical memory is divided among **nodes**, each attached to some cores and one memory controller complex; every frame is equally *correct* from every core, but a local node's frames are measurably cheaper than a remote node's. Our own fleet carries the intra-package version of the same fact: MimirAlloc's Z13 measurements put intra-CCD latency at ~32 ns against cross-CCD ~103 ns (3.2×) on one Strix Halo package (`memory/mimiralloc-our-own-proven-work.md` §4.3) — one socket, one pool, and already a 3× locality gradient. Multi-socket servers widen the same gradient across sockets.

Linux's default placement policy is **first-touch**: a page's node is chosen not at `mmap` time (no frame exists yet) but at *fault* time, and the default is the node of the CPU that takes the fault (documented in the `mbind(2)` / `set_mempolicy(2)` family: the system-wide default allocates on the node of the CPU that triggers the allocation [S8]; hwloc's binding documentation states the same policy as `HWLOC_MEMBIND_FIRSTTOUCH` — each page allocated on the local node of the thread that touches it [S16]). The alternatives — `MPOL_BIND` (restrict to named nodes), `MPOL_INTERLEAVE` (round-robin pages across nodes, buying aggregate bandwidth at average latency), `MPOL_PREFERRED` (try a node first, fall back) — are set per-process or per-range with `set_mempolicy` / `mbind`, and they only govern *future* faults unless a move flag is passed [S8].

Now the runner consequence, which is the whole reason this section exists:

> **Under first-touch, the loader decides the placement, permanently, as a side effect of faulting.** If one loader thread reads the entire model in at startup — the natural implementation — every weight page lands on that thread's node. Decode threads later running on other nodes then read *every weight byte remotely*, for the life of the process, at remote latency and at the interconnect's bandwidth share instead of the local controller's. No subsequent scheduling cleverness repairs it short of page migration. Conversely, a loader that faults each range on (or interleaves across) the nodes that will compute on it makes decode bandwidth a local-memory property from the first token.

Three design rules follow, stated at the boundary's depth and no deeper:

1. **Parallel first-touch is a placement API.** Loading weight ranges concurrently from threads pinned to their target nodes (or explicitly interleaving a shared read-only weight set) is how a runner *asks* for placement without naming NUMA at all.
2. **Interleave is the honest default for shared read-only weights** when decode threads span nodes: it forfeits best-case local latency to guarantee no node is the whole model's bottleneck — bandwidth-optimised rather than latency-optimised, which matches decode's character (§4.4).
3. **Measure before policy.** Node counts, distances, and per-node bandwidth are machine facts (`numactl --hardware`, STREAM per node) to be read at startup, like page size (§2.3) — never assumed from the single-socket machines the code was written on.

**Flagged gap:** everything beyond this seam — topology-aware KV placement, thread pinning discipline, CXL-attached nodes (field map B8), per-CCD arena design for Strix Halo-class parts — belongs to the future B3 dossier. The MimirAlloc campaign's ARENA_PER_CCD decision (filed at Z-037 from the Z-012 latency measurements) is the corpus's current frontier marker there, and it is a decision, not yet a general treatment.

---

## 7. Applicability

### 7.1 Ollama / Go — living on the VM system deliberately

Ollama's stack crosses this dossier at three surfaces: Go's runtime (which manages the server heap), the llama.cpp-derived runner (which `mmap`s model files), and the OS beneath both. Concrete policy, each item traceable to a section above:

**Loading discipline (§2.4, §2.5, §5.2).**
- Treat model load as a *fault-scheduling* problem with a stated budget: map the GGUF, then prefault deliberately — `MADV_WILLNEED` over the weight ranges (or `MAP_POPULATE` at map time) issued *ahead* of first compute, from enough threads to overlap storage latency — instead of letting prefill discover the pages serially. Report cold and warm TTFT as separate metrics, with major/minor fault counts beside them; a regression in cold TTFT is usually a readahead or prefault regression, not a kernel regression.
- Never mark weight mappings `MADV_SEQUENTIAL` (§5.3's warning). Default readahead already matches the stream; sequential advice's "free after access" half is actively harmful to a per-token re-read set.
- Keep the Go heap out of the weight path entirely (allocator dossier §5.3's routing table, which this dossier's §2.5 grounds): weights and KV live in off-heap `mmap` arenas whose accounting the runner owns, so GC pacing never prices gigabytes of pointer-free live data and `GOMEMLIMIT` is never asked to govern bytes it cannot see.

**Huge-page policy for weight arenas (§3.2–§3.5).**
- Request weight arenas 2 MiB-aligned and sized in 2 MiB multiples, and apply `MADV_HUGEPAGE` to them under a system THP mode of `madvise` (not `always` — the runner should opt its known-dense ranges in and leave the rest of the system alone). The expected win, per Z-049's shape, is on faults and translation, not on warm bandwidth; validate it by fault counts and TLB-miss counters, not by tok/s alone.
- Verify, don't assume: read back `AnonHugePages` in `/proc/<pid>/smaps` per arena. THP is a request the kernel may decline (alignment, fragmentation, policy); a runner that cannot state whether its weights are actually huge-page-backed does not have a huge-page policy, it has a hope.
- On the 16 KiB-page Pi-class targets, re-derive rather than transplant: the quantum differs (§2.3) and THP's PMD multiple differs with it.

**RAM budgeting with the page cache counted honestly (§5.3, §5.4).**
- Budget in the four numbers (live / allocator-held / resident / virtual — allocator dossier §6.1) *plus* a named page-cache line: a model that has ever been loaded is resident in cache until evicted, and two models "alternating" on a tight machine are both competing for cache residency as well as for arena space. Double-counting runs in both directions — counting cache pages as free overstates headroom; counting a shared mapped model once per process overstates footprint — and both errors have the same cure: read `smaps_rollup` (PSS) for the process and `MemAvailable` for the machine, and budget against those.
- On unified-memory machines, apply the unified dossier's law as a loading rule: admission is decided against a disaggregated budget (weights / KV / page cache / OS headroom) with pinned bytes counted as spent and unswappable (§5.4). Refuse a load that does not fit the budget, loudly and in advance — the alternative the Z13 record documents is the kernel choosing the victim afterwards.

**NUMA (§6).** On any multi-node host, first-touch the weight arena from the threads/nodes that will decode, or interleave it; expose the choice in configuration, because the wrong default is silent and permanent.

### 7.2 Aesir — packed-weight streaming on this foundation

Aesir's serve path reads packed (quantised) weights as a per-token stream — the workload §4.4 identifies as the prefetcher's best case and §3 identifies as the TLB's worst. Its VM-layer discipline follows directly:

- **The packed format is a VM optimisation as well as a bandwidth one.** Fewer bytes per token (§4.2: more weights per cache line) also means fewer pages per token, fewer faults per load, and a resident set whose TLB footprint shrinks in proportion to the compression. When the compression school grades a packed form (MEMORY-COMPENDIUM Ch. 9's oracle discipline), its page/fault accounting belongs in the grade beside its faithfulness band: a format that is 56.7% of the bytes is, to first order, 56.7% of the paging cost too.
- **Resident-format loading (§5.2's rule, already Aesir law via the unified dossier §6.2):** never materialise a widened intermediate copy of the weights — a widening loader briefly doubles the working set, and on a unified machine that transient is exactly the size that converts a fitting load into an OOM (§5.4). Stream the packed form into its final arena, faulting each range once, in compute order.
- **Arena geometry (§3.4, §3.5):** allocate the weight arena as one (or few) large, 2 MiB-aligned extents, `MADV_HUGEPAGE` applied, mappings never churned — so shootdowns (§3.3) are ~zero in steady state and the TLB working set is the §3.2 middle row, not the top row. Session/KV arenas follow the same geometry per session, with the snapshot store (≈158.9 MB per hybrid snapshot, per the KV dossier §3.7) budgeted as pinned-equivalent resident bytes.
- **The HIP/GTT surface is a mapping surface (§5.4).** Aesir's device contexts map the same pool the CPU pages in; the recorded incident of a single device context pinning +106.4 GiB (unified dossier §3.2) is, in this dossier's terms, a mapping created without a budget. Every device mapping should be created against the same ledger as every CPU mapping — one pool, one accounting, no exceptions for "it's the GPU's memory," because on this machine there is no such separate thing.

### 7.3 MimirAlloc — the mmap-per-allocation large path, read through VM economics

The companion dossier (`memory/mimiralloc-our-own-proven-work.md`) establishes the facts: above a 1,024 B cutoff, MimirAlloc takes a **fresh OS mapping per large allocation** (plus a header page per mapping); its large-path p99 on the Pi measured ~3,852 ns (alloc) / ~3,686 ns (free) against glibc's ~75 ns / ~56 ns (K-008); and its one repeatable virtue is returning memory — back to within 128 KiB of baseline after free where glibc retained 1,232 KiB (K-008 §3), with Z13 retention/resident-shape wins echoing it (Z-006, Z-057, Z-061). The allocator dossier §7.3 places the design in its lineage. What *this* dossier adds is the page-fault accounting that makes the trade legible as VM economics rather than as an implementation detail:

**Cost side — what a fresh mapping actually buys, per allocation:**
1. **Page-table construction.** A new mapping needs its PTEs built across every level the range spans (§2.2). Small next to a fault, but nonzero, and multiplied by allocation count.
2. **First-touch faults, one per page, forever unamortised.** A reused arena page is faulted once in the process's life; a fresh mapping's pages are faulted on *every* allocation cycle. At 4 KiB pages and ~2 µs per minor fault (§2.4), a 1 MiB large allocation carries ~256 faults ≈ ~0.5 ms of fault path on its first touch if touched densely — the right order of magnitude to explain microsecond-class p99s once kernel entry, zeroing, and TLB work are added, and the precise reason the Z13 huge-page result matters here: the same allocation at 2 MiB pages is *one* fault (Z-049's "ADOPT on fault" at 200 MiB is this arithmetic, measured). **[Engineering judgement]** The K-008 large-path gap (~51–66× at p99) is best read as *fault-and-mapping cost per cycle versus arena-reuse cost per cycle* — glibc's large path reuses arena extents and pays the VM system rarely; MimirAlloc's pays it always. The lineage dossier's prescription (arena reuse above the cutoff, §7.3 there) is, in VM terms, a prescription to amortise §2's costs instead of repurchasing them.
3. **TLB and shootdown churn.** Each unmap invalidates translations, with shootdowns to every core that held them (§3.3); each new mapping starts with a cold TLB for its range. A churn workload (the Pi's `mixed_lifecycle`, MimirAlloc's worst at 65.2×) is, in this reading, a workload that maximises mapping churn per unit of useful work — the VM system, not the free list, is where its time goes. The burst-free tail (p99 1,167 ns vs 56 ns, K-008) sits in the same place: free is where mappings are torn down and spans released, so free is where the VM bill arrives.
4. **A header page per mapping** is a full page — the quantum of §2.3 — spent on bookkeeping per allocation: at 4 KiB pages, a 1,025-byte allocation costs ≥ 8 KiB of footprint (data page + header page) before fragmentation is even discussed. Page-granularity waste is invisible to any accounting that stops at requested bytes (four-numbers discipline, allocator dossier §6.1).

**Benefit side — why the design wins retention, stated in the same currency:** a mapping-per-allocation allocator holds *nothing* it is not using. Free is `munmap`: the pages, the page tables, and the resident footprint all return to the system completely and immediately — no decay timer, no muzzy limbo, no retained arena whose "reuse-ready" defence must be taken on faith (§5.3's levers are the *compromise* positions other allocators occupy; MimirAlloc's large path is the uncompromised endpoint). On a machine where retained bytes are a safety property — the unified pool of §5.4, a 6 GB card's host side, a long-running server beside other tenants — that completeness is worth real money, and the Z13 soak results (resident-shape WIN, drift TIE) are its measured form.

**The synthesis for future allocator work:** the large path's problem is not that it returns memory; it is that it pays *mapping* prices to do so. The VM system offers the middle positions explicitly — keep the virtual extent, release the physical backing (`MADV_DONTNEED` for immediate release, `MADV_FREE` for pressure-deferred release), reuse the extent for the next allocation of its class. That is precisely the arena-with-decommit design the mature allocators converged on (jemalloc's dirty→muzzy→retained ladder, mimalloc's delayed purge — allocator dossier §§2.4–2.5), and reading it through this dossier shows *why* it converges there: it amortises page tables and TLB warmth across allocations while still surrendering resident bytes on a tunable fuse. Any MimirAlloc successor slice should be graded on both axes the campaigns already measure — p99 alloc/free *and* retained-after-free — with the fault counts (`min_flt` deltas per workload) added as the third, explanatory axis. **[SPECULATION]** With huge-page-backed extents (§3.5) the fault term shrinks by up to 512× per extent, which may narrow the honest cost of prompt return enough to move the trade's optimum; that is a measurable slice proposal, not a claim.

---

## 8. Sources

All web sources accessed **2026-11-15**. Corpus-internal sources are cited by path; their own source lists govern their figures.

### Public — primary and documentation

- [S1] Arpaci-Dusseau, R. H. & Arpaci-Dusseau, A. C., *Operating Systems: Three Easy Pieces* (OSTEP), Ch. 18 "Paging: Introduction" (v1.10, publicly available PDF). https://pages.cs.wisc.edu/~remzi/OSTEP/vm-paging.pdf
- [S2] OSTEP, Ch. 19 "Paging: Faster Translations (TLBs)" (v1.10, public PDF). https://pages.cs.wisc.edu/~remzi/OSTEP/vm-tlbs.pdf
- [S3] Linux Kernel Documentation, "Transparent Hugepage Support" (admin-guide/mm/transhuge, kernel.org docs, 6.4 tree as served). https://docs.kernel.org/6.4/admin-guide/mm/transhuge.html
- [S4] Drepper, U., "What Every Programmer Should Know About Memory" (2007; public PDF as hosted). https://www.fit.vutbr.cz/~ibarina/pub/reading-cpumemory.pdf — *Era note: all cycle figures from this source are 2007 commodity-hardware figures and are labelled as such at every use (§4.1).*
- [S5] OSTEP, Ch. 21 "Beyond Physical Memory: Mechanisms" (public PDF, research.cs.wisc.edu mirror). https://research.cs.wisc.edu/wind/OSTEP/vm-beyondphys.pdf
- [S6] Linux man-pages, `mmap(2)` (Michael Kerrisk's man-pages site). https://www.michaelkerrisk.com/linux/man-pages/man2/mmap.2.html
- [S7] Linux man-pages, `madvise(2)` (Ubuntu manpages mirror as served). https://manpages.ubuntu.com/manpages/tenacious/man2/madvise.2.html
- [S8] Linux man-pages, `mbind(2)` (huihoo mirror as served). https://docs.huihoo.com/linux/man/20100621/htmlman2/mbind.2.html

### Public — secondary summaries read for ranges and cross-checks (figures used as orders of magnitude / reported values, flagged as such in text)

- [S9] "Virtual memory at work" (OS course notes synthesising OSTEP / Silberschatz: demand paging, minor vs major fault costs, working set, page cache, swap). https://os.easy-tech.blog/en/12-virtual-memory/
- [S10] Stanford CS140 lecture notes, "Thrashing and Working Sets" (Ousterhout; Denning's working-set model, page-fault frequency). http://web.stanford.edu/~ouster/cgi-bin/cs140-winter12/lecture.php?topic=thrashing
- [S11] "Cache Deep Dive IV — TLB, Huge Pages, and Memory-Level Parallelism" (TLB sizes for Zen 5 / Golden Cove as reported, reach arithmetic, page-walk worst case). https://dev.to/tyler_tan_13b1f742020d35a/cache-deep-dive-iv-tlb-huge-pages-and-memory-level-parallelism-5lf
- [S12] "TLB and Locality" (reach formula E × P, per-page-size TLB capacities, walk structure). https://www.computationpath.com/tlb-and-locality
- [S13] "Performance Engineering: Memory Hierarchy, Caches, and Data Layout" (modern latency ranges, prefetcher taxonomy, TLB level latencies). https://sankethbk.github.io/blog/posts/performance-engineering/2026-10-11-memory-and-caches/
- [S14] "CPU Caches" notes (modern per-level sizes/latencies as ranges, 64 B lines, 128 B on Apple Silicon). https://www.aprelius.com/notes/cs/cpu-caches
- [S15] MPI-SWS OS lecture notes, "Demand Paging, Thrashing, Working Sets" (Anderson/Dahlin + Silberschatz readings; Denning τ-window definition). https://courses.mpi-sws.org/os-ss13/lectures/mem4.pdf
- [S16] hwloc documentation, `hwloc_set_membind(3)` (first-touch policy definition; Linux default). https://man.archlinux.org/man/extra/hwloc/hwloc_set_membind.3.en

### Corpus-internal (banked in this repository; govern all figures cited from them)

- `memory/allocator-lineages.md` — allocator designs, mmap/extent policies, Go runtime allocator, four-numbers measurement discipline.
- `memory/mimiralloc-our-own-proven-work.md` — MimirAlloc campaign records: K-002/K-008 baselines and tails, Z-013/Z-049 THP verdicts, Z-006/Z-057/Z-061 retention results, Z-011/Z-012 bandwidth and CCD latency facts, page-size records (16 KiB Pi / 4 KiB Z13).
- `memory/unified-memory.md` — Z13 unified-memory architecture (GTT as mapping budget), the 2026-11-14 cascade forensics, swap/pinning analysis, standing fences and caps.
- `memory/memory-wall-and-roofline.md` — memory wall, roofline method, decode intensity and bandwidth ceilings.
- `memory/kv-cache-design.md` — KV size formula, per-token costs, hybrid state snapshots.
- `memory/MEMORY-COMPENDIUM.md` — Ch. 2 (hierarchy, with the B-side gap flagged), Ch. 9 (measurement discipline), Ch. 10 (the gap audit this dossier answers for B1/B2).

### What could not be verified in this pass

- **Vendor-exact TLB geometries.** Entry counts per page size for current Intel/AMD parts are taken from public secondary summaries [S11][S12], not from the vendors' optimisation manuals directly (the manuals were not text-fetchable in this pass). The dossier therefore works in ranges and orders of magnitude; any per-part design decision must be re-grounded in that part's manual.
- **Fault-cost constants.** The ~2.3 µs minor-fault and ~100 µs NVMe major-fault figures are single-source orders of magnitude [S9], consistent with the qualitative treatment in the OS texts but not measured on our fleet. A fleet measurement (fault counts × controlled cold loads on purplelongship and purpleraider) is owed and is cheap to run; until then these numbers price *shape*, not budgets.
- **Drepper's figures beyond the cache section.** The public PDF's later sections (virtual memory, NUMA) were read in part via the slide-form extraction; load-bearing claims in this dossier rest only on the cache/latency material actually read, plus the kernel and man-page sources for VM/NUMA mechanics.
- **THP behaviour for file-backed (GGUF) mappings specifically.** Kernel documentation and the man page establish that THP for file-backed memory is restricted (read-only, alignment and configuration conditions [S7]); the Z13 evidence is for anonymous allocator mappings. Whether a given Ollama/llama.cpp build's weight mappings actually obtain huge pages on a given kernel configuration is an empirical per-build check (§7.1's smaps verification), not asserted here.
- **5-level paging deployment state** across the fleet's kernels was not inventoried; the dossier's walk arithmetic uses the 4-level form and notes the 5th level changes width, not mechanics.

*End of dossier — OR-6 B1/B2, virtual memory and caches. 2026-11-15.*
