# OR-6 — NUMA: Non-Uniform Memory Access

**Domain:** Memory (B-side) · **Dossier:** OR-6 · **Date:** 2026-11-15
**Readers:** Engineers building LLM runners and allocators
**Companion dossiers:** *Virtual Memory and Caches* (first-touch, page faults, TLB), *Memory Wall and Roofline* (why decode is bandwidth-bound), *Unified Memory* (single-address-space APUs), *GPU Memory Internals*, *KV-Cache Design*

> **Scale honesty, up front.** On most of Volmarr's fleet — single-socket laptops and a Raspberry Pi — classical NUMA is a *second-order* effect, and on several machines the operating system correctly reports exactly one NUMA node. Optimising for it there would be theatre. On the hardware LLM serving actually runs on at scale — dual-socket Xeons and EPYCs, multi-APU nodes — it is *first-order*: a misplaced weight buffer can halve usable bandwidth. And in its modern, intra-package form it reaches back into the fleet: two L3 islands in a laptop APU and two CPU chiplets in Strix Halo are NUMA in everything but the name the OS gives them. This dossier's job is to teach how to tell the three cases apart, how big the tax is in each, and what a runner should — and should not — do about it.

---

## 1. Essence: memory has a geography

The flat mental model — `malloc` returns memory, memory has one speed — is a useful lie on a small machine and an expensive lie on a large one.

**NUMA is the name for the map.** A NUMA system divides processors and memory into *nodes*: groups of cores with a memory controller and a slice of physical RAM that is *close* to them. Every core can address every byte in the machine — the address space stays unified and cache-coherent — but the cost of reaching a byte depends on where the core sits relative to where the byte lives. Local access goes straight to the attached controller. Remote access crosses an interconnect, pays extra latency, and shares a link that is narrower than the sum of the local memory channels it competes with.

Three consequences follow, and everything else in this dossier is a corollary:

1. **Placement is a performance decision.** Which node a page lands on is chosen once (usually at first touch) and then sticks. The OS cannot read the programmer's mind about which threads will use the data later.
2. **Bandwidth does not sum unless the work is spread to match.** Ten threads streaming from one node's controllers get one node's bandwidth, however many nodes the machine has.
3. **Threads and data must be placed together.** A perfectly placed buffer is worthless if the scheduler migrates its reader to the far side of the machine, and vice versa.

### The map is fractal

The 2005 textbook picture stops at the socket: node = socket. The 2026 map has at least four levels, and a runner that only reads the top level will misplace work on modern parts:

```
Machine
└── Socket / package            ← classical NUMA node (OS-visible, usually)
    └── Die / chiplet (CCD)     ← own L3, own path to the I/O die
        └── Core complex (CCX)  ← historical Zen 1/2 grouping
            └── L3 island       ← the cache a thread's data must actually be in
                └── Core → L1/L2
    └── Memory-side cache / MALL (Strix Halo, MI300) — a further locality tier
CPU-less nodes: CXL / HBM memory expanders appear as nodes with no cores at all
```

Firmware decides how much of this fractal the OS is *told* about. AMD's Nodes Per Socket (NPS) setting and Intel's Sub-NUMA Clustering (SNC) — §3.3 — can present one socket as one, two, or four OS NUMA nodes, or even one node per L3 cache, without changing a single transistor. So "how many NUMA nodes does this machine have?" has two answers — the physical geography and the *reported* geography — and a runner lives with the reported one while paying for the physical one.

---

## 2. The classical picture

### 2.1 Nodes, local and remote

A classical server: two (or four, or eight) sockets on one board. Each socket carries its own integrated memory controllers and its own DIMMs. Firmware describes the topology to the OS in the ACPI SRAT (which cores and address ranges belong to which node) and SLIT (a matrix of relative distances). Linux normalises the SLIT so that local distance is 10 (1.0×) and everything else is scaled against it — a neighbouring node commonly reports 21, i.e. a claimed 2.1× latency. Treat SLIT numbers as firmware *claims*, not measurements: in one documented check the SLIT claimed 2.1× while Intel's Memory Latency Checker (MLC) measured 195.7 ns remote against 108.2 ns local — 1.81× [S9]. The Heterogeneous Memory Attribute Table (HMAT, ACPI 6.2+) is the newer, richer successor, carrying per initiator→target latency and bandwidth figures, and is how CXL and HBM tiers are described [S9].

### 2.2 The measured ratios — dated, because they move

There is no single "NUMA penalty." There is a family of measurements, each pinned to an interconnect generation and a traffic pattern. The honest summary across two decades of published measurement:

**Latency: remote ≈ 1.3–2× local for one hop.** This band recurs in every era below. Loaded latency (under bandwidth saturation) diverges much further than idle latency, because remote traffic queues on the interconnect.

**Bandwidth: the interconnect, not DRAM, is the ceiling for remote streams.** A single thread or a single node pulling remotely is capped by the link, often at ⅓–½ of local bandwidth, and in pathological snoop configurations far worse. Aggregate bandwidth, by contrast, *scales* with nodes — but only if threads and pages are spread so each node's controllers do their share.

| Era / system | Local | Remote (1 hop) | Ratio | Source |
|---|---|---|---|---|
| 2011, 4× AMD Opteron 6172 (Magny-Cours, HyperTransport 3), theoretical per-node bandwidth | 21.3 GB/s local; 19.2 GB/s same-package node | 6.4 GB/s other package | ~3.3× bandwidth drop cross-package | Bergstrom, STREAM study [S10] |
| 2011, 4× Intel Xeon X7560 (Nehalem-EX, QPI), theoretical | 17.1 GB/s local | 25.6 GB/s aggregate to other nodes (3 links) | links sum; per-link still the cap | [S10] |
| ~2015, 2× Xeon E5-2650, Intel MLC idle latency | 69.4 / 69.8 ns | 118.4 / 120.9 ns | ~1.7× latency | Intel Community MLC dump [S11] |
| Same system, MLC read-only bandwidth, all threads on one node | ~43.0 GB/s local | ~20.5 GB/s remote | ~2.1× bandwidth | [S11] |
| ~2015, 2× Xeon E5-2603 v3 (Haswell-EP, low core count, early-snoop BIOS mode), MLC | ~44.3 GB/s local | ~6.0 GB/s remote | ~7× — *outlier*, see note | Intel Community thread [S12] |
| 2022-era 2-node system, MLC idle latency vs SLIT claim | 108.2 ns | 195.7 ns | 1.81× measured (2.1× claimed) | Scargall [S9] |
| 2025, 4× AMD Instinct MI300A node (Infinity Fabric / xGMI), Chips & Cheese | 227 ns local DRAM (HBM — high absolute latency) | 477 ns near socket; 559 ns far socket | ~2.1× / ~2.5×; Infinity Cache hit cuts remote to ~369 / ~430 ns | [S13] |

Two reading notes. First, the Haswell 7× row is real but not representative: the thread itself attributes the very low remote figure to the low-core-count part and its early-snoop coherency mode, and notes a home-snoop BIOS setting trades a little latency for much better remote bandwidth [S12]. It is included as a warning that *firmware settings are part of the geography*. Second, absolute latencies have not fallen the way bandwidth has risen — local DRAM is still roughly 70–110 ns on DDR servers, and HBM trades latency for bandwidth outright (227 ns local on MI300A [S13]). NUMA ratios therefore remain material even as links get faster.

**Rules of thumb a runner may carry** *(synthesis of the table above, not a single source)*: budget ~1.5× latency and ~½ bandwidth for one remote hop on a healthy dual-socket DDR machine; budget worse under load; never budget from the datasheet — measure (§6).

### 2.3 The interconnects

**Intel QPI → UPI.** QuickPath Interconnect (2008, Nehalem through Haswell/Broadwell Xeons) replaced the shared front-side bus with point-to-point coherent links — the change that made Intel servers NUMA by construction, since each socket gained its own memory controllers. Ultra Path Interconnect (2017, Skylake-SP onward) is its successor: higher transfer efficiency per wire, a directory-based coherency protocol, and a low-power link state. Published per-link figures run from 9.6 GT/s (19.2 GB/s unidirectional) for late QPI to 10.4–10.6 GT/s (~20.8 GB/s) for first-generation UPI, with UPI 2.0 specified at 24 GT/s (48 GB/s per direction per link); sockets carry two to three links, so topology and link count — not just link speed — set the remote ceiling [S14][S15].

**AMD HyperTransport → Infinity Fabric / xGMI.** Opteron servers were NUMA from the start (integrated controllers from 2003), linked by HyperTransport (6.4 GB/s per 8-bit HT3 link in the 2011 study [S10]). Zen (2017) replaced it with Infinity Fabric: a coherent fabric that works at three scales with one protocol family — inside a die, between chiplets and the I/O die in a package, and, as xGMI (external Global Memory Interconnect), between packages and GPUs. On MI300-class systems a single xGMI link is rated 64 GB/s per direction with roughly 45–48 GB/s realised after CRC and protocol overhead, and pairs of links give 128 GB/s per direction between MI300A APUs [S16][S17]. Inside an EPYC package, each CCD talks to the I/O die over its own fabric links (the Illinois CS 433 course notes, drawing on AMD's EPYC 9004 overview, cite ~36 Gb/s per CCX–IOD interface, up to two interfaces per CCX [S18]) — which is why cross-CCD traffic inside one socket is already an interconnect crossing, not an on-die freebie.

The pattern to remember: in both vendors, the interconnect is *provisioned for coherency plus spillover*, not for sustained full-rate remote streaming. It is a good road and a narrow one.

---

## 3. The intra-package turn

The most important change since the classical era: the interesting NUMA boundary moved *inside* the package. A 2026 laptop can report one NUMA node and still punish a bandwidth-critical loop for crossing invisible lines.

### 3.1 Zen CCDs and L3 islands

AMD's chiplet construction, from Zen 2 onward: processor cores live on Core Complex Dies (CCDs); memory controllers, PCIe, and (on APUs) graphics live on a separate I/O die (IOD); Infinity Fabric connects them [S19][S20].

- **Zen 2 (2019):** each CCD holds **two** Core Complexes (CCXs) of 4 cores, each CCX with its **own 16 MB L3** (desktop). A core has fast, direct access to its CCX's L3; reaching data in the sibling CCX's L3 — same die, millimetres away — already goes over Infinity Fabric [S20][S21].
- **Zen 3 (2020) onward:** the CCX boundary inside the CCD was removed — one 8-core complex sharing a unified **32 MB L3 per CCD**. The island grew, but did not disappear: a 16-core desktop part still has *two* CCDs and therefore two 32 MB L3 islands, and cross-CCD access still traverses the fabric via the IOD [S21].
- **Zen 4 EPYC (Genoa):** up to 12 CCDs around one IOD — 12 L3 domains, 384 MB of L3 in total on a 96-core part. One secondary treatment puts the tiers at sub-10 ns for an intra-CCD L3 hit, ~50–100 ns for a cross-CCD fabric hop, and a further NUMA hop on top for cross-socket [S22]. *(Engineering-grade secondary figures; treat the ordering as reliable and the exact nanoseconds as indicative.)*
- **Zen 5** keeps the 8-core / 32 MB-per-CCD shape for client and Strix Halo (below).

So "local" for a running thread is really a stack: local L1/L2 → local L3 island → other island in the package → local DRAM → remote DRAM. For a working set that fits in one island's L3, the DRAM NUMA question never arises. For one that streams — LLM weights, §5 — the island boundary matters because threads cooperating on one matrix multiply want the *same* rows resident in *their* island, and a thread migrated across islands by the scheduler takes a cold L3 with it.

**The fleet's Zen 2 case, stated precisely.** The brief for this dossier describes the G14's Zen 2 as a chiplet design. The correction matters and is recorded here rather than silently repeated: the original ROG Zephyrus G14 ships a **Renoir** APU (Ryzen 4000 mobile), and Renoir is a **monolithic** single die — AMD's chiplet Zen 2 parts are the desktop/server Matisse and Rome lines. But the locality lesson survives the correction intact: Renoir keeps Zen 2's two-CCX layout on that one die — two groups of 4 cores, each with its own (smaller, APU-sized) L3 partition, communicating over on-die Infinity Fabric [S23][S24]. One die, zero OS NUMA nodes, two L3 islands. That is the whole thesis of this section in one laptop.

### 3.2 Strix Halo: dual-CCD plus GPU, one memory

Strix Halo (Ryzen AI Max 300 series, launched January 2025) is the fleet's live case and the clearest example of the fractal map on a client part. From AMD's launch positioning and subsequent die-shot analyses (the detailed floorplan annotations in circulation are third-party analysis of package photographs, *not* an official AMD floorplan — flagged here as the evidence grade they are [S25]):

- **Two Zen 5 CCDs**, 8 cores each (16 cores / 32 threads on the flagship Max+ 395), **32 MB L3 per CCD, 64 MB total** [S25][S26].
- **One large SoC / I/O die** carrying a 40-CU RDNA 3.5 integrated GPU (Radeon 8060S), the XDNA 2 NPU (50 TOPS), media/display, PCIe/USB — and the memory controllers [S25][S26].
- **Unified, soldered memory:** a 256-bit LPDDR5X-8000 interface, ~256 GB/s theoretical bandwidth, up to 128 GB, shared by CPU, GPU, and NPU [S26]. A **32 MB MALL / Infinity Cache** sits between the GPU side and the memory interface, acting as a last-level cache for graphics and compute traffic [S27].
- **The CCD↔IOD link is not desktop Infinity Fabric verbatim.** AMD's product management described it in interview as a distinct, power-optimised interconnect (internally "DDR SSP"), chosen because the dies sit unusually close in the package, saving watts [S27]. Public per-link bandwidth figures for this client link are **not** published at the level available for EPYC/MI300 — see §8, unverifiable items.

What the OS sees: typically **one NUMA node** — the memory is one pool behind one set of controllers, and there is no second DRAM node to be remote *from*. Proxmox and Linux topology reporting on Strix Halo systems is described as correct and unremarkable in homelab coverage [S26]. What the hardware does: a decode thread on CCD 0 streaming weights still shares the single memory interface with the GPU, still loses its warm data if migrated to CCD 1's L3 island, and still crosses the package interconnect to reach the controllers on the other die. **Strix Halo is UMA at the DRAM tier and NUMA at the cache/interconnect tier.** A runner that asks only "how many NUMA nodes?" will conclude there is nothing to do; a runner that asks "how many L3 islands, and which threads share a barrier?" has the right question. §7.2 returns to this.

### 3.3 Firmware redraws the map: NPS and SNC

Two BIOS knobs prove that reported NUMA topology is partly a *policy choice*:

- **AMD NPS (NUMA Nodes Per Socket)** on EPYC: NPS1 presents one node per socket with memory interleaved across all (up to 12) channels; NPS2 splits the socket into halves; NPS4 into quadrants, each with its own channels, CCDs, and I/O. NPS0 interleaves the whole *system* into one node and is explicitly not recommended by AMD. A further option, "L3 Cache as NUMA Domain," exposes **each CCD's L3 as its own NUMA node** [S28][S29]. The same silicon can therefore present 1, 2, 4, or 8+ nodes per socket. Workload evidence that this is not cosmetic: one published VPP (vector packet processing) case on a single-socket EPYC 9534 tripled packet rate moving from NPS1 to NPS4, because per-node buffer pools removed a shared-lock bottleneck and kept buffers near their consumers [S30]. *(Single-workload report, packet processing not inference — cited for the mechanism, not as an inference benchmark.)*
- **Intel SNC (Sub-NUMA Clustering)** on Xeon Scalable / Xeon 6: partitions one socket's cores, LLC slices, and memory controllers into 2 (SNC2) or 3 (SNC3) clusters, each presented to the OS as a NUMA node. Intel's own tuning guidance recommends SNC enabled by default for NUMA-aware workloads such as SQL Server, on locality grounds [S31]. Secondary measurements put the local-latency gain at roughly 6–8% (e.g. 80.8 ns → 74.2 ns in one Ice Lake test summary [S32]) — small next to a cross-socket hop, which is exactly the point: SNC harvests the *intra*-socket tier of the fractal.

### 3.4 The monolithic contrasts — and why they still are not flat

- **Intel client parts** were long single monolithic dies with a ring, then a mesh, interconnect and one shared LLC: one NUMA node, genuinely. Even there, far-side mesh hops make LLC/DRAM latency position-dependent — SNC exists precisely because "one die" stopped meaning "uniform" at server core counts [S31].
- **Apple silicon** (M-series) is the strongest UMA design in production: one die (or two dies fused with a high-bandwidth bridge on Ultra), unified LPDDR on a very wide bus, no OS-visible NUMA nodes at all. Locality has not vanished — it has moved into performance/efficiency core clusters, per-cluster caches, and a system-level cache — but there is no DRAM placement decision for software to make. Apple is the limiting case that proves the rule: NUMA pain is proportional to how much of the geography the hardware *exposes* to software.
- **Raspberry Pi (Mimir's class):** one SoC, one memory controller complex, one node. Nothing in this dossier's classical machinery applies, and §5.4 says so again for inference specifically.

**Why a 2026 laptop is quietly a NUMA machine:** not because it has remote DRAM — it does not — but because the three costs NUMA thinking manages (interconnect crossings, shared-link bandwidth contention, cache-island warmth) all exist inside its package. The vocabulary transfers even where the node count is 1.

---

## 4. OS machinery (Linux)

### 4.1 First-touch placement — the one-paragraph recap

The corpus's *Virtual Memory and Caches* dossier covers the mechanism in full; the load-bearing sentence is: under Linux's default policy, an anonymous page is physically allocated **on the node of the CPU that first touches it**, at fault time, not at `malloc`/`mmap` time — and it stays there [S33][S34]. Everything in this section is either a way to override that default or a way to live with it deliberately. The classic failure it creates: a single loader thread touches a 20 GB weight buffer on node 0; the compute pool on node 1 then streams it remotely for the life of the process. §5.1 is that failure at inference scale.

### 4.2 Memory policies

Linux memory policy decides, per allocation, which node(s) may supply the page. The kernel documentation defines four scopes — system default, task/process, VMA (a range of one address space), and shared-object — with the more specific scope winning, and cpusets able to restrict all of them [S1]. The modes that matter to a runner:

| Mode | Semantics (per kernel documentation [S1]) | Runner's use |
|---|---|---|
| **Default / local** (`MPOL_DEFAULT`, system default at runtime) | Allocate on the node local to the faulting CPU — i.e. first-touch rules | Correct *if* the touching thread is the future user |
| **Bind** (`MPOL_BIND`) | Allocate *only* from the listed nodes; fail rather than spill | Hard partitioning: one replica per node, pinned tenants |
| **Preferred** (`MPOL_PREFERRED` / `MPOL_PREFERRED_MANY`) | Try the listed node(s) first, fall back by increasing firmware distance | Soft partitioning that degrades instead of OOMing |
| **Interleave** (`MPOL_INTERLEAVED`) | Round-robin pages across the listed nodes at page granularity | Shared read-mostly data consumed from all nodes (§7.1) |
| **Weighted interleave** (newer kernels / `numactl --weighted-interleave`) | Interleave in proportion to per-node bandwidth weights | Heterogeneous tiers (DRAM + CXL) |

APIs: `set_mempolicy(2)` sets the calling thread's task policy; `mbind(2)` installs a VMA policy for an address range and, since 2.6.16, can migrate already-resident pages to match a new policy; `get_mempolicy(2)` queries; `move_pages(2)` migrates specific pages — the call the Arm llama.cpp optimisation uses to place tensor segments [S1][S35]. The user-space front end is **libnuma** and the **`numactl`** tool: `numactl --interleave=0,1`, `--membind=0`, `--preferred=0`, `--localalloc`, plus `--cpunodebind` / `--physcpubind` for CPU placement, with the policy inherited by children [S2]. Two kernel-doc caveats runners trip over: VMA policy applies to anonymous pages (and to private file mappings only at copy-on-write), **not** to `MAP_SHARED` file mappings [S1] — directly relevant to `mmap`'d model files, §7.1 — and a task policy installed by one thread does not retroactively change its existing sibling threads' policies [S1].

### 4.3 AutoNUMA balancing: the kernel as repair crew

Static policy assumes the programmer knows the geography in advance. **Automatic NUMA balancing** (AutoNUMA) is the kernel's attempt to fix placement at runtime. Per Red Hat and SUSE's tuning guides: the kernel periodically unmaps a sample of a task's pages; the next access raises a *NUMA hinting fault*, which records which node the accessor lives on; from those statistics the kernel both **migrates pages** toward their frequent accessor and **migrates tasks** toward their pages, via the scheduler's NUMA balancing path [S3][S4][S5].

The costs are structural, not incidental, and the kernel's own sysctl documentation names them: the periodic unmapping and fault trapping "incur additional overhead," scanning is throttled by `numa_balancing_scan_period_min_ms` / `_max_ms`, `_scan_delay_ms`, and `_scan_size_mb` under `/proc/sys/kernel/`, and activity is observable in `/proc/vmstat` (`numa_pte_updates`, `numa_hint_faults`, `numa_pages_migrated`, …) [S5][S4]. Three operational rules follow from the vendor guides:

- It is controlled by `/proc/sys/kernel/numa_balancing` (1 = on) and only activates when the machine actually presents multiple nodes [S3].
- **Manual tuning overrides it** — an application placed with explicit policies/affinity opts out of the periodic unmapping for its pages; the guides recommend disabling AutoNUMA where placement is already deliberately bound, since the data should already be local [S3][S4].
- It is a *converger for long-lived, phase-stable workloads* (databases, VMs). For a runner whose access pattern is a perfectly regular stream (§5), AutoNUMA mostly pays fault overhead to rediscover what first-touch discipline would have gotten right for free — and its page migration of a multi-GB weight buffer is not free either. *(This last judgement is engineering reasoning from the documented mechanism, marked as such.)*

### 4.4 Thread pinning

Memory policy without CPU policy is half a placement. Linux CPU affinity — `sched_setaffinity(2)`, `taskset`, `numactl --physcpubind` / `--cpunodebind`, or cgroup cpusets — decides where threads may run; memory policy decides where their faults land. Pinning buys three things: first-touch lands where the thread will stay; L1/L2/L3 warmth survives across quanta; and barriers/atomics stop paying cross-island or cross-socket coherency costs (§5.3). It costs scheduler freedom: a pinned pool cannot borrow idle cores elsewhere, and a wrong pin is worse than no pin. Hence the stance taken in §7: affinity as an *opt-in, measured* knob, never a silent default.

### 4.5 Topology discovery: hwloc is the map-reader

No runner should hardcode "cores 0–7 = node 0." The portable map-reader is **hwloc** (Portable Hardware Locality): a C library plus tools that discover and expose the full hierarchy — NUMA nodes, packages, dies, shared caches, cores, processing units (SMT threads), plus memory sizes and I/O-device locality — portably across OSes, with a CPU/memory binding API on top [S6]. Its `lstopo` tool prints the map (text or graphical) and is the first command to run on an unfamiliar machine, ahead of `numactl --hardware` (nodes, distances, CPUs per node) and `lscpu`. For a Go or Rust runner, hwloc is consumed via its XML export or C API rather than reimplemented from `/sys/devices/system/node/` and CPUID leaves by hand — the topology rules (SNC, NPS, L3-as-NUMA, CPU-less CXL nodes) change faster than hand-rolled parsers do. *(The choice of hwloc over hand-parsing is engineering judgement; hwloc's coverage and portability are as documented in [S6].)*

---

## 5. What NUMA does to LLM inference specifically

Inference is not a generic workload, and its NUMA profile follows from two facts established elsewhere in this corpus: **decode is a streaming, bandwidth-bound pass over the weights** (one token requires reading essentially the whole active weight set), while **prefill is a dense, compute-heavier pass** over a prompt batch. NUMA taxes the two differently.

### 5.1 Weight streaming: the interconnect tax, paid every token

Autoregressive decode has no reuse to hide behind: at batch size 1, each generated token streams the model's weights from DRAM once. If a decode thread's weights are remote, *every one of those bytes crosses the interconnect, every token, for the whole generation.* Using §2.2's healthy dual-socket figures, a model fully resident on the wrong node caps decode at roughly the remote bandwidth (~20 GB/s where local is ~43 GB/s in the MLC example [S11]) — i.e. it approximately halves the token rate ceiling, before latency effects. There is no cache fix: the weight set is orders of magnitude larger than any L3.

The failure is usually created at load time, by §4.1: one loader thread `mmap`s or reads the file and touches (or the page cache populates) the pages from one node. The Arm engineering blog on llama.cpp/Neoverse states the server-scale version plainly: ggml's tensor buffers come from a `malloc` that "is not NUMA-aware," so once threads span nodes, the matrix-multiply accumulates "significant cross-NUMA memory access" [S35]. Their proof-of-concept fix is the textbook one — split `dst`/`src0` buffers into per-node segments aligned with thread IDs, place the segments with `move_pages()`, replicate the small shared `wdata` buffer per node — and it is worth citing with its numbers because they are *measured on a real 2-node Neoverse N2 system* (64 cores per node), llama3 Q4_0:

- Text generation: best unoptimised 26.52 tok/s (32 threads) → **41.15 tok/s (40 threads), +55%** with the NUMA optimisation.
- Prompt processing: 48.73 → 74.67 tok/s, **+53%**.
- The bandwidth table is the diagnostic made visible: unoptimised 128-thread run drew **70.6 GB/s from node 0 and 0.2 GB/s from node 1** — one node's controllers saturated, the other's idle — while the optimised run balanced to 74.4 / 72.2 GB/s [S35].

The patch was reviewed but **not merged** upstream, the blog notes, for low server/cloud interest in llama.cpp's community [S35] — a useful reminder that consumer-runner defaults are set by consumer hardware, where §5.4 applies.

llama.cpp's shipped `--numa` option is the lighter-weight version of the same idea, with three modes documented in its CLI: `distribute` (spread execution evenly over all nodes), `isolate` (spawn threads only on CPUs of the node execution started on), and `numactl` (honour a CPU map imposed from outside via numactl) — alongside `--cpu-mask` / `--cpu-range` / `--cpu-strict` affinity controls [S36]. A single-community A/B in a containerised benchmark reports the `isolate`-style discipline — binding 15 threads to one node's physical cores — at 25.47 tok/s against 18.95 tok/s unbound (**+34%**), attributing the gap to threads wandering across sockets [S37]. *(Single unverified community report, one model, container quota confounds present — cited as an anecdote consistent with the mechanism, not as a benchmark to quote onward.)*

**Placement strategies for weights, in order of increasing commitment:** (a) *interleave* the read-only weight pages across nodes so every thread's stream is ~½ local, ~½ remote but the *aggregate* uses all controllers — the safe shared default; (b) *replicate* the weights per node (one copy per node, threads read only their copy) — best locality, costs N× RAM, the standard trick for serving replicas; (c) *partition* the model (layers or tensor rows per node, as in the Arm segmenting) — necessary when the model exceeds one node's RAM, and the only option that also partitions compute cleanly. Which is right depends on model size vs node size vs replica count; §7 marks the per-project calls as judgement.

### 5.2 KV cache placement

The KV cache differs from weights in every way that matters here: it is *written* incrementally during decode, *read* in full on every subsequent token by the attention computation, it is per-sequence (not shared), and it grows. Consequences:

- **KV belongs with its sequence's compute.** In multi-socket serving, a request should be *owned* by one node: its decode threads, its KV pages, and ideally its share of the weights all on the same node. Migrating a live sequence between nodes means either migrating its KV (a bulk copy over the interconnect) or paying remote attention reads for the rest of its life.
- **Disaggregated serving sharpens this.** In prefill/decode-split architectures (see the corpus's papers dossiers), the KV produced by the prefill worker must be *transferred* to the decode worker; on a multi-node machine that transfer should be planned as a bulk, one-time interconnect crossing — cheap amortised over a long generation — not discovered as a per-token cost.
- **Long context makes KV a bandwidth term, not a footnote.** At long contexts the per-token KV read rivals the weight stream; a remote KV then taxes decode exactly as remote weights do. First-touch discipline applies to KV arena allocation just as to weight loading: the thread that will run attention for a sequence should be the thread (on the node) that first touches its KV pages, or the arena should be explicitly bound per node (§7.3).

### 5.3 Thread-pool topology mistakes

The recurring bugs, in the order they are usually met:

1. **The unpinned pool.** N worker threads spawned with no affinity on a multi-node or multi-island part. The Linux scheduler load-balances them freely; a thread wakes on a different island/node from the one where its data (and its warm L3) lives. The Arm blog isolates the synchronisation half of this cost: ggml's barrier uses atomics, and "atomic operations in `ggml_barrier()` across NUMA node is time-consuming" — their fix reduces cross-node atomics to one representative thread per node [S35]. Any runner with a per-layer global barrier (i.e. essentially every CPU inference engine) has this term.
2. **Oversubscribing one island.** Spawning "all cores" threads for a job whose working set fits one CCD, so half the threads run with cold L3 and fabric-crossing accesses for no benefit. More threads ≠ more bandwidth once the local controllers saturate.
3. **SMT-sibling blindness.** Treating 32 logical CPUs on a 16-core part as 32 independent workers; sibling threads share a core's execution resources and L1/L2. Topology discovery (§4.5) exists to prevent exactly this miscount.
4. **Loader/worker node mismatch** — §5.1's first-touch failure, restated as a threading bug: the pool is fine, the *loader* ran elsewhere.
5. **Assuming node = socket on SNC/NPS machines.** A pool sized and pinned for "2 nodes" on a box firmware presents as 4 or 6 nodes silently misplaces a third of its threads. Read the map at runtime; never bake it in.

### 5.4 Where the effect is honestly negligible

Plainly, as commissioned:

- **Single-node consumer parts with the model on GPU.** If inference runs on a discrete GPU, the CPU-side NUMA question reduces to whether the *PCIe* device is attached to the socket doing the feeding — a real but usually small effect, and zero on a single-socket laptop.
- **Single-CCD / single-island APUs and all Pis.** One memory pool, one L3 island (or a small enough core count that islands don't bind): there is no placement decision to get wrong. Mimir (Pi) is in this class for DRAM purposes.
- **Small models that fit in L3.** A sub-L3 working set never streams DRAM in steady state; geography below the cache is irrelevant until it spills.
- **GPU-resident serving on Strix Halo-class APUs** where the CPU only orchestrates: the live locality questions are GPU↔MALL↔DRAM and CCD migration of the orchestrator, not DRAM node placement — second-order, measurable only after the big terms are fixed.

The discipline is symmetric: do not pay NUMA complexity where the map is flat, and do not assume the map is flat where it is not.

---

## 6. Measurement: proving a NUMA effect

NUMA folklore is full of 2× claims that were really frequency, SMT, or page-cache artefacts. The standard of proof for this corpus:

**See the placement.** `numastat` (from the numactl package) reports per-node allocation counters — `numa_hit` (allocated on the intended/local node), `numa_miss` (intended elsewhere, landed here for lack of room), `numa_foreign`, `interleave_hit`, `local_node` / `other_node` — system-wide and, with `-p <pid>`, per process from `/proc/<pid>/numa_maps` [S7][S8]. High hit + low miss/foreign is the healthy signature; `numastat -p` on a running server immediately exposes the §5.1 failure (a process whose gigabytes sit on node 1 while its threads run on node 0). `/proc/vmstat`'s NUMA counters expose AutoNUMA's own activity (§4.3).

**See the traffic.** `perf` provides the sampling side: `perf mem` / PMU events for local vs remote access classification on supported parts, `perf c2c` for cache-line contention and cross-node sharing, and uncore counters for interconnect utilisation. Intel MLC remains the reference microbenchmark for the idle-latency matrix and per-node bandwidth matrix quoted in §2.2 [S9][S11]; STREAM, run pinned and placed in each configuration in turn, is the portable bandwidth check [S10].

**The A/B discipline.** A NUMA claim is proven only by a *controlled pinning experiment*: same binary, same model, same prompt set, same thread count, page cache state controlled (llama.cpp's own `--numa` documentation warns to drop the page cache before a first numactl run, because cached file pages carry the placement of whoever faulted them first [S36]) — varying *only* placement: (1) unbound baseline, (2) all-local bound (`numactl --cpunodebind=0 --membind=0`), (3) interleaved, (4) per-node replicated/partitioned if implemented. Report tokens/s for decode and prefill separately (§5: they respond differently), plus the `numastat -p` before/after as the manipulation check. If the manipulation didn't change placement, a null result proves nothing; if placement changed and speed didn't, *that* is a publishable null — it means the workload wasn't DRAM-bound in the first place.

**The standing warning:** never optimise for a geography you have not measured *on that machine, with that firmware*. NPS/SNC settings, DIMM population (an unpopulated channel silently removes a quarter of a node's bandwidth), and snoop modes all redraw the map (§2.2, §3.3). `lstopo` and `numactl -H` output belong in every NUMA bug report, next to the kernel version.

---

## 7. Applicability

*Everything in this section is engineering judgement for Volmarr's projects, reasoned from the mechanisms and measurements above. No fleet NUMA measurement exists yet; none is claimed. Where a recommendation needs a measurement to confirm it, that is stated.*

### 7.1 Ollama / Go

Ollama inherits llama.cpp's ggml compute and therefore its `--numa` modes and affinity flags where exposed, but the *process-level* decisions are Ollama's own (and Go's runtime adds one wrinkle: Go threads are runtime-managed, so affinity set at process start via `numactl` or `taskset` is far more reliable than trying to pin individual goroutines).

- **Loader-thread first-touch discipline — do this first.** Model loading should touch weight pages from the threads/nodes that will compute on them, or explicitly interleave them. For `mmap`'d GGUF files, recall §4.2's caveat: shared file mappings ignore VMA policy and their page-cache pages take the placement of the first faulter — so *who faults the model in* is the placement decision, and a dedicated loader goroutine on the wrong node silently decides wrong for everyone. Warm-up passes should be run by the serving pool, in parallel, per node.
- **Interleave as the safe default for shared read-only weights.** For a single model instance served by threads spanning nodes, `MPOL_INTERLEAVED` weights (§5.1 strategy (a)) guarantee aggregate bandwidth use and bounded badness (~½ remote traffic) with no RAM multiplication and no partitioning code. It is the right default *when* a multi-node machine is detected; on a single-node machine it is a no-op and should not be forced.
- **Affinity as an opt-in knob, never a silent default.** Expose the equivalent of llama.cpp's `isolate` / `distribute` choice and an affinity string, default off, documented as "measure with §6 before enabling." A laptop user must never be pinned by a server heuristic.
- **One instance per node beats one instance across nodes** where RAM allows replication (§5.1 strategy (b)): two Ollama instances, each bound to a node with its own model copy, behind the existing scheduler, will generally out-serve one instance straddling both — at the cost of duplicated RAM and split KV capacity. *Judgement; the crossover depends on model size vs per-node RAM and must be measured per deployment.*

### 7.2 Aesir

Aesir is where this dossier stops being background reading: its multi-core CPU decode path on **purpleraider (Strix Halo)** is the fleet's live intra-package case (§3.2).

- **The map to code against is islands, not nodes.** Linux will report one NUMA node; the topology that matters is 2 CCDs × 32 MB L3 + one shared memory interface + the GPU on the SoC die. Aesir's thread pool should be built from hwloc (§4.5), grouped by shared L3, not from a raw logical-CPU count.
- **Keep a decode step inside one island where the working set allows.** Per-layer barriers should be hierarchical in the Arm blog's sense [S35]: synchronise within the island cheaply, cross islands once per barrier through representative threads. A flat global barrier over 32 threads spanning both CCDs pays the fabric on every layer, every token.
- **Pin the pool; migrate never.** Decode threads should be created with affinity to a chosen island set and left there, so L3 warmth and any per-island weight caching survive. If both CCDs are needed for bandwidth/compute, partition the matmul rows by island (each island's threads read the rows they own, repeatedly) rather than striping rows so finely that every thread touches every island's data.
- **CPU↔GPU sharing is the other half of Strix Halo locality.** When the GPU (8060S) runs part of the model, the shared 256-bit interface and the 32 MB MALL cache are contended resources; CPU decode threads streaming weights at full rate can starve GPU work and vice versa. Scheduling that contention is a bandwidth-budgeting problem (§2's lesson at package scale), and it — not DRAM node placement — is the first NUMA-flavoured measurement Aesir should take on purpleraider: tokens/s for CPU-only, GPU-only, and split execution, with thread placement varied. *No such measurement exists yet; this is a proposed experiment, stated as such.*
- **Do not import server machinery.** `mbind` per-node arenas, AutoNUMA tuning, NPS — none of it exists or matters on this part. The transferable assets are the *concepts*: first-touch by the using thread, island-aware barriers, measured A/B placement.

### 7.3 MimirAlloc

An allocator is the one component that can make NUMA placement *structural* instead of advisory. The honest scope first: **on MimirAlloc's proven ground — a single-node Pi — per-node arenas are dead weight**, and this dossier does not recommend building them for that target. The design note below is for the allocator's life on multi-node and multi-island hardware, recorded now so the abstraction is not painted into a corner.

- **Per-node arenas are the allocator's NUMA answer.** The established pattern (visible in production allocators' arena designs generally): one arena per NUMA node (or per L3 island, on island machines), threads allocate from their local arena by default, free lists stay arena-local, and cross-arena frees are batched back to the owning arena rather than contending on its locks. This simultaneously fixes placement (an arena's pages are faulted/bound on its node), lock contention (the NPS4/VPP lesson of §3.3, at allocator scale [S30]), and false sharing.
- **Bind the arena's pages, don't hope for first-touch.** A long-lived arena can `mbind` its extents to its node at creation; a short-lived or lazily-grown one should at minimum ensure the *owning* thread performs the first touch of each new extent. An arena first-touched by an initialiser thread on another node is §5.1's bug, fossilised.
- **KV and weight arenas want different policies** (§5.2): weight arenas are candidates for interleave-or-replicate; KV arenas should be strictly node-local to their owning sequence's compute. The allocator API should therefore take placement as an *arena property* (`LOCAL_TO_NODE(n)`, `INTERLEAVED`, `REPLICATED`), not as a per-allocation flag scattered through call sites.
- **Island granularity is a configuration, not a rewrite.** If the arena key is "locality domain" as reported by hwloc — NUMA node where they exist, shared-L3 domain where they don't — the same code serves the Pi (one domain), Strix Halo (two cache domains, one memory domain: allocate arenas per CCD for lock/L3 purposes while binding pages to the single memory node), and a dual-socket EPYC (four NPS4 domains). *This unification is a design proposal, marked as judgement; it has not been prototyped.*

---

## 8. Sources

All web sources accessed **2026-11-15**. Claims in the body are tied to the sources actually read below; ratios are dated with their hardware era in §2.2.

**Kernel, OS, and tools**

- [S1] Linux Kernel Documentation, *NUMA Memory Policy* (v6.3) — policy scopes (system/task/VMA/shared), `MPOL_BIND` / `MPOL_PREFERRED` / `MPOL_INTERLEAVED` / `MPOL_PREFERRED_MANY` semantics, `set_mempolicy` / `mbind` / `get_mempolicy` APIs, VMA-policy applicability limits. https://www.kernel.org/doc/html/v6.3/admin-guide/mm/numa_memory_policy.html
- [S2] `numactl(8)` manual page — `--interleave`, `--membind`, `--preferred`, `--cpunodebind`, `--physcpubind`, `--localalloc`, `--balancing`. https://man7.org/linux/man-pages/man8/numactl.8.html
- [S3] Red Hat Enterprise Linux 7, *Virtualization Tuning and Optimization Guide*, §9.2 "Automatic NUMA Balancing" — mechanism (tasks and data moved toward each other), enablement conditions (`numactl --hardware`, `/proc/sys/kernel/numa_balancing`), manual tuning overriding it. https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/virtualization_tuning_and_optimization_guide/sect-virtualization_tuning_optimization_guide-numa-auto_numa_balancing.html
- [S4] SUSE Linux Enterprise Server 15 SP6, *System Analysis and Tuning Guide*, "Automatic NUMA Balancing" — three-step implementation, configuration, `/proc/vmstat` monitoring counters. https://documentation.suse.com/en-us/sles/15-SP6/html/SLES-all/cha-tuning-numactl.html
- [S5] Linux kernel patch documentation, "mm: numa: Document automatic NUMA balancing sysctls" (2013) — hinting-fault sampling, scan-period sysctls, overhead warning, disable-when-bound guidance. https://www.spinics.net/lists/kernel/msg1616262.html
- [S6] hwloc (Portable Hardware Locality) Documentation v2.9.3 — hierarchical topology discovery (NUMA nodes, caches, packages, dies, cores, PUs), `lstopo`, binding APIs, portability. https://www-lb.open-mpi.org/projects/hwloc/doc/v2.9.3/a00359.php
- [S7] Red Hat Enterprise Linux 8/10, *Monitoring and Managing System Status and Performance*, "Profiling memory allocation with numastat" — `numa_hit` / `numa_miss` semantics and interpretation. https://docs.redhat.com/en/documentation/red_hat_enterprise_Linux/8/html/monitoring_and_managing_system_status_and_performance/profiling-memory-allocation-with-numastat_monitoring-and-managing-system-status-and-performance
- [S8] TheLinuxCode, "Demystifying Linux Memory Usage with Numastat" — full counter table (`numa_foreign`, `interleave_hit`, `local_node`, `other_node`) and per-process usage. https://thelinuxcode.com/run-numastat-command/
- [S33] Shiva's Notes, "Linux Memory Allocation: malloc, mmap, Pages, TLBs, and Huge Pages" — first-touch placement stated plainly (page placed on the node local to the faulting CPU; sticky thereafter), `MAP_POPULATE` and manual pre-touch as placement control. https://www.shivasnotes.com/blog/5961/Linux-Memory-Allocation-malloc-mmap-Pages-TLBs-and-Huge-Pages
- [S34] B. Goglin / UTK ICL, "Design Considerations for Shared Memory MPI Implementations on Linux NUMA Systems" (MPICH case study) — "memory is physically allocated upon first touch"; pages are not migrated (pre-AutoNUMA era statement of the default). http://icl.cs.utk.edu/%7Emucci/latest/pubs/AMD-MPI-05.pdf

**Measured ratios and interconnects**

- [S9] S. Scargall, "Linux NUMA Distances Explained" (2022) — SLIT normalisation (local = 10), worked example (claimed 2.1× vs MLC-measured 108.2 ns / 195.7 ns = 1.81×), HMAT description. https://stevescargall.com/blog/2022/11/linux-numa-distances-explained/
- [S10] L. Bergstrom, "Measuring NUMA Effects with the STREAM Benchmark," arXiv:1103.3225 (2011) — Opteron 6172 and Xeon X7560 topologies and theoretical bandwidth tables (21.3 / 19.2 / 6.4 GB/s; 17.1 GB/s local), NUMA-aware vs unaware STREAM results. https://arxiv.org/pdf/1103.3225
- [S11] Intel Community, "Interpreting Intel Memory Latency Checker Output" — dual Xeon E5-2650 MLC matrices: idle latency 69.4 ns local / 118.4–120.9 ns remote; read-only bandwidth ~43.0 GB/s local / ~20.5 GB/s remote. https://community.intel.com/t/interpreting-intel-memory-latency-checker-output/21709
- [S12] Intel Community, "Memory Bandwidth on a NUMA System" — Haswell-EP E5-2603 v3 MLC matrices (~44.3 GB/s local / ~6.0 GB/s remote in early-snoop mode) and the snoop-mode discussion attributing the outlier. https://community.intel.com/t5/Software-Tuning-Performance/Memory-bandwidth-on-a-NUMA-system/td-p/1095836
- [S13] Chips and Cheese, "Inside the AMD Radeon Instinct MI300A's Giant Memory Subsystem" (2025) — Infinity Fabric latency measurements: 227 ns local DRAM, 477 ns / 559 ns remote, Infinity Cache mitigation, cross-CCD latencies. https://old.chipsandcheese.com/2025/01/18/inside-the-amd-radeon-instinct-mi300as-giant-memory-subsystem/
- [S14] Wikipedia, "Intel Ultra Path Interconnect" — UPI replacing QPI in Skylake-SP (2017), directory coherency, UPI 2.0 at 24 GT/s (48 GB/s per direction per link). https://en.wikipedia.org/wiki/Intel_Ultra_Path_Interconnect
- [S15] X. Ryan, "Transport Speed of Common Computer Buses" — per-link QPI/UPI transfer-rate and bandwidth table (QPI to 9.6 GT/s / 19.2 GB/s; UPI 10.4 GT/s / 20.8 GB/s). https://xryan.net/p/295
- [S16] AMD ROCm Blog, "Understanding RCCL Bandwidth and xGMI Performance on AMD Instinct MI300X" — xGMI 64 GB/s theoretical per link, ~45–48 GB/s realised. https://rocm.blogs.amd.com/software-tools-optimization/mi300x-rccl-xgmi/README.html
- [S17] "Inter-APU Communication on AMD MI300A Systems via Infinity Fabric: a Deep Dive," arXiv:2508.11298 (MEMSYS 2025) — xGMI 3 links at 32 GT/s, 64 GB/s per direction per link, 128 GB/s per APU pair. https://arxiv.org/html/2508.11298v2

**Chiplet / intra-package topology**

- [S18] University of Illinois CS 433 course notes, "AMD Zen Architecture" (drawing on AMD EPYC 9004 materials) — 8 cores per CCX with shared L3, Infinity Fabric CCX↔IOD interfaces, NPS configurations, "LLC as NUMA." https://courses.physics.illinois.edu/cs433/fa2022/projects/AMD-Zen.pdf
- [S19] Wikipedia, "Zen 2" — chiplet construction (CCDs + separate I/O die), 2 CCXs of 4 cores per CCD, Renoir as the mobile/APU line. https://en.wikipedia.org/wiki/Zen_2
- [S20] Tom's Hardware, "Ryzen 4000 Detailed" (AMD PPR reporting) — Zen 2 CCD = 2 CCXs × 4 cores × 16 MB L3; Zen 3 contrast (single 8-core CCX, 32 MB). https://www.tomshardware.com/news/ryzen-4000-detailed-purported-amd-confidential-documents-outline-zen-3s-inner-workings
- [S21] Wikipedia, "Zen 3" — one CCX per CCD, unified 32 MB L3 per CCD vs Zen 2's two 16 MB pools. https://en.wikipedia.org/wiki/Zen_3
- [S22] CodeSwiftr, "AMD CPU Microarchitecture and GPU at Datacenter Scale" (2026) — Genoa: 12 CCDs × 32 MB L3, intra-CCD vs cross-CCD (~50–100 ns) vs cross-socket tiers. *(Secondary synthesis; used for tier ordering, flagged in text.)* https://codeswiftr.com/blog/amd-engineering-deep-dive/
- [S23] PCWorld, "Ryzen 4000 CPUs Explained: How AMD Optimized Zen 2 for Laptops" (2020) — Renoir mobile design: two 4-core CCXs as the building block of the 8-core mobile part. https://www.pcworld.com/article/398840/ryzen-4000-cpus-amd-zen-2-laptops.html
- [S24] Hardware Times, "AMD Ryzen Chiplet vs. Intel's Monolithic" — Matisse as the first consumer chiplet design; Zen/Zen+ consumer parts monolithic; APU distinction. https://hardwaretimes.com/amd-ryzen-chiplet-vs-intels-monolithic-history-and-future/
- [S25] RottenWifi Blog, "AMD Strix Halo Ryzen AI Max+ 395 Die Shot Explained" (2025) — two Zen 5 CCDs + large I/O die (40-CU GPU, controllers, NPU); explicit caveat that annotations are third-party analysis, not an official AMD floorplan. https://blog.rottenwifi.com/amd-strix-halo-ryzen-ai-max-395-die-shots-reveal-a-three-die-apu-built-around-a-giant-gpu/
- [S26] BotMonster, "Ryzen AI Max 395 Mini PC Verdict" (2026) — 16 Zen 5 cores, two CCDs, 64 MB L3, 256-bit LPDDR5X-8000 ≈ 256 GB/s, unified memory to 128 GB; Linux/Proxmox NUMA topology reported correctly. https://botmonster.com/hardware/amd-strix-halo-mini-pcs-ryzen-ai-max-395-homelab/
- [S27] Notebookcheck, interview with AMD's Ben Conrad on Strix Halo design decisions (2025) — 32 MB Infinity (MALL) Cache between GPU and memory interface; power-optimised CCD↔IOD interconnect distinct from desktop. http://www.notebookcheck.net/Our-big-Middle-cores-are-better-than-their-army-of-little-cores-AMD-s-Ben-Conrad-chats-about-some-of-the-design-decisions-behind-Ryzen-AI-APUs-and-what-makes-Strix-Halo-tick.951459.0.html
- [S28] AMD, *EPYC 8005 BIOS & Workload Tuning Guide* — NPS0/1/2/4 definitions, "L3 Cache as NUMA Domain" option. https://docs.amd.com/api/khub/documents/P2tP1~7DP8fvkAwNNo8PLg/content
- [S29] Cisco, *Performance Tuning for UCS M8 Platforms with AMD EPYC 4th/5th Gen* — NPS topology explanation (NPS4 quadrants: CCDs + UMCs + I/O hub per node), L3-as-NUMA. https://WWW.Cisco.com/c/en/us/products/collateral/servers-unified-computing/ucs-c-series-rack-servers/ucs-c245-m8-rack-ser-4th-gen-amd-epyc-pro-wp.pdf
- [S30] H. Aryachyy, "How NUMA Tripled VPP's Packet Rate on AMD EPYC" (2026) — single-socket EPYC 9534, NPS1→NPS4 case with per-node buffer pools. *(Single-workload report; cited for mechanism.)* https://haryachyy.wordpress.com/2026/10/12/how-numa-tripled-vpps-packet-rate-on-amd-epyc/
- [S31] Intel, *Xeon 6 Processor BIOS NUMA Tuning Guide* (Feb 2025) — SNC2/SNC3 partitioning of LLC/cores/controllers into NUMA domains; SNC recommended enabled by default for NUMA-aware workloads; VirtualNUMA. https://cdrdv2-public.intel.com/845720/845720_1p0.pdf
- [S32] CopyProgramming summary of SNC measurements — SNC local latency 80.8 ns → 74.2 ns (~6–8%), local bandwidth +4.5%. *(Secondary summary of vendor/test figures; used only for the SNC gain's order of magnitude.)* https://copyprogramming.com/howto/clustering-on-the-output-of-t-sne

**LLM inference**

- [S35] Arm Community Blog, "Scaling llama.cpp on Neoverse N2: Solving Cross-NUMA Performance Issues" — `ggml_barrier` cross-node atomics, non-NUMA-aware `malloc` tensor buffers, segment + `move_pages()` + per-node `wdata` optimisation, measured +55% TG / +53% prompt, per-node bandwidth table (70.6/0.2 → 74.4/72.2 GB/s); patch reviewed, not merged. https://developer.arm.com/community/arm-community-blogs/b/ai-blog/posts/introduce-the-cross-numa-problem-and-optimization-in-llama-cpp-with-llama3-model-running-in-neoverse-n2
- [S36] llama.cpp CLI documentation — `--numa {distribute|isolate|numactl}`, `--cpu-mask` / `--cpu-range` / `--cpu-strict`, page-cache warning for numactl runs. https://manpages.debian.org/testing/llama.cpp-tools-extra/llama-tts.1.en.html (and mirrored CLI README)
- [S37] Hugging Face community benchmark discussion, Ornith-1.5-35B GGUF — unbound 18.95 tok/s vs single-node-bound 25.47 tok/s (+34%) under a 16-core container quota. *(Anecdotal single report; flagged in text.)* https://huggingface.co/ornith-ai/Ornith-1.5-35B-A3B-GGUF/discussions/17

### Unverifiable / not established from sources read

- **Strix Halo CCD↔IOD link bandwidth** (per-link GB/s for the client power-optimised interconnect): AMD has not published it at EPYC/MI300 detail level in any source read; only its existence and power-optimised character are documented [S27]. No figure is asserted in this dossier.
- **Fleet measurements:** no NUMA, L3-island, or placement measurement has been taken on Volmarr's machines (G14, purpleraider/Strix Halo, purplelongship, Mimir) for this dossier. §7.2's Aesir experiment is a proposal. Any future claim of a fleet NUMA effect must come with the §6 A/B evidence.
- **Renoir L3 size per CCX:** sources read agree on the two-CCX layout [S23] but give inconsistent/shorthand figures for the APU's reduced L3; the dossier therefore describes it qualitatively ("smaller, APU-sized") rather than asserting a megabyte figure.
- **Zen 6 material** surfaced during research (12-core CCDs, NPS changes) postdates this dossier's hardware scope and was deliberately excluded as forward-looking and partly rumour-grade.

---

*End of OR-6. Cross-references: first-touch mechanics — Virtual Memory and Caches; bandwidth-bound decode — Memory Wall and Roofline; APU unified addressing — Unified Memory; KV ownership — KV-Cache Design.*
