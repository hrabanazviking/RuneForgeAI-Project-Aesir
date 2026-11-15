# Unified Memory Architectures — One Pool, New Physics

**Dossier OR-6 (Memory), Topic B7 — Ollama Research Forge**
**Date: 2026-11-15**
**Status: Synthesis dossier with a first-hand case study. Public claims are tied to sources read on 2026-11-15 (access date given per source in §7). Internal claims are tied to Volmarr's own campaign records on this VM, named beside each claim. Numbers we computed ourselves show their arithmetic. Speculation is marked [SPECULATION]. Where public guidance and our own record disagree, the disagreement is stated, not smoothed over.**

**Living case study:** Volmarr's ASUS ROG Flow Z13 (GZ302EA) — machine name **purpleraider** — AMD Ryzen AI Max+ 395 ("Strix Halo"), Radeon 8060S integrated GPU (gfx1151), 128 GB unified LPDDR5X, Kubuntu 26.10. This machine is not an illustration chosen for convenience. It is the machine on which our fleet learned, in one morning (2026-11-14), exactly what unified memory does to a system that is budgeted as if it were two machines.

**Readers:** Yrsa engineering the improved Ollama; Project Aesir; future hardware work. Companion dossiers in this corpus: `memory/kv-cache-design.md` (Topic A1 — the KV budget that competes inside the pool), `memory/memory-wall-and-roofline.md` (Topic B5 — the bandwidth method used in §4), `memory/mimiralloc-our-own-proven-work.md` (Topic E6 — our allocator evidence), `runners/mlx.md` (OR-2 — the Apple-side exemplar, cross-referenced in §5).

---

## 1. Essence — what unified memory actually changes

A unified memory architecture (UMA) puts the CPU, the GPU, and usually the NPU on one system-on-chip attached to **one physical pool of DRAM**. There is no separate graphics memory, no PCIe bus between "system RAM" and "VRAM," and therefore no copy step when work moves between processors. A buffer allocated once is addressable by every engine on the package.

That single fact rearranges the whole design problem of a model runner, in four moves:

1. **Capacity stops being the binding constraint — at consumer scale, for the first time.** On a discrete card, the question "does the model fit?" is answered against 6, 12, or 24 GB of VRAM, and the answer is usually no for anything interesting. On a 128 GB UMA machine the same question is answered against most of the machine's RAM. Models that need four discrete cards, or that simply cannot run locally at all, fit whole. This is the headline, and it is real.

2. **Bandwidth becomes the binding constraint instead.** Decode of a dense model reads essentially all of its weights once per generated token. Once the model fits, tokens per second are set, to first order, by `sustained bandwidth ÷ resident weight bytes` — the roofline rule developed in `memory/memory-wall-and-roofline.md`. UMA memory is LPDDR, not GDDR or HBM: its bandwidth is generous for an integrated part and modest next to a discrete card. UMA trades speed for capacity, deliberately.

3. **Zero-copy removes a tax and a cliff.** There is no host→device transfer to pay, no duplicate residency during load (weights held once in RAM and again in VRAM), and no "offload cliff" where spilling one layer too many collapses throughput to PCIe rates. Placement — which *processor* runs an operation — becomes a scheduling decision on shared buffers, not a data-movement decision. The MLX dossier (`runners/mlx.md` §2) makes this point from the Apple side in detail; it holds identically on Strix Halo.

4. **Allocation policy becomes the safety system — because the failure mode changes species.** On a discrete system, exhausting VRAM fails *locally*: the CUDA/HIP allocator returns an error, the process dies, the desktop lives. On a UMA system there is no protected island. The model's weights, its KV cache, the compositor, the browser, and the kernel all draw on the same gigabytes, and the GPU's share is typically *pinned* — unswappable and, in the worst documented cases, not reclaimable by the kernel's OOM killer. Exhaustion is therefore not an application error. It is a **system-wide OOM that takes the desktop with it**. Our Z13 proved this on 2026-11-14 (§3). This is the sentence the whole dossier hangs on:

> **On unified memory, capacity is abundant, bandwidth is the price, and the budget is the safety system. A runner that does not budget explicitly has not removed the VRAM wall — it has moved the wall to the whole machine.**

---

## 2. The architecture

### 2.1 Strix Halo as documented

The Ryzen AI Max+ 395 (Strix Halo) combines 16 Zen 5 CPU cores, a 40-compute-unit RDNA 3.5 integrated GPU (Radeon 8060S, LLVM target **gfx1151**), and an XDNA 2 NPU on one package, attached to a **256-bit LPDDR5X-8000** memory interface with a maximum of 128 GB. The bandwidth arithmetic is elementary and worth showing, because every downstream number in this dossier derives from it:

```
8,000 MT/s × 32 bytes (256 bit) = 256,000 MB/s ≈ 256 GB/s theoretical
```

Secondary technical coverage consistently reports roughly **215 GB/s measured** in practice (Level1Techs-forum measurements reported July 2025, carried by multiple 2026 guides; see §7). We did not find an AMD primary source publishing a sustained-bandwidth figure, and we did not measure one ourselves in the records mined for this dossier — treat 215 GB/s as *reported*, 256 GB/s as *theoretical*, and plan against the lower number. [Our records contain no STREAM-class bandwidth measurement for purpleraider; that is a measurement still owed — see §7.]

Two structural notes:

- **The bus is wide for an APU, narrow for a GPU.** A conventional dual-channel DDR5 desktop reaches roughly a third of this; a discrete RTX 4090-class card exceeds 1 TB/s from GDDR6X. Strix Halo's 256-bit interface is precisely the design decision that makes large-model inference *possible* on an integrated part — and its bandwidth is precisely why that inference is *slow* relative to discrete hardware of similar compute. Both halves are the same fact.
- **Memory is soldered.** Capacity is chosen at purchase and never changes. The Z13's 128 GB is a fixed endowment; all budgeting below is budgeting of a constant.

### 2.2 The coherence and mapping model: mapped, not partitioned

AMD's own ROCm documentation for RDNA 3.5 states the model plainly, and it is the most important public paragraph in this dossier (AMD ROCm, *RDNA3.5 system optimization*, read 2026-11-15):

- RDNA 3.5 APUs handle memory through **GPU Virtual Memory (GPUVM)** — per-process GPU virtual address spaces — *rather than a separate, discrete VRAM pool*.
- Memory is therefore **mapped rather than physically partitioned**. The terms GART and GTT describe *limits on how much system memory can be mapped into GPU address spaces*, not distinct kinds of physical memory.
- **GART** bounds platform address space mappable for kernel-driver use; it is kept relatively small and is mostly driver-internal.
- **GTT** (Graphics Translation Table) bounds system RAM mappable into GPU virtual address spaces *for user processes*. This is the pool PyTorch, ROCm, and LLM workloads actually allocate from. GTT allocations are dynamic, not permanently reserved, and the OS can in principle reclaim them when the GPU is idle. **The default GTT limit is approximately 50% of total system RAM.**
- A firmware/BIOS "VRAM" carve-out, by contrast, *is* a physical partition: memory reserved exclusively for the GPU and permanently removed from the system pool. AMD's guidance is explicit that on physically shared memory the carve-out "provides little benefit for most workloads while permanently reducing available system memory," and recommends keeping the BIOS reservation small (their example: **0.5 GB**) and sizing the flexible GTT/TTM pool instead. There is, in AMD's words, no performance distinction of the discrete kind — GTT-backed memory is not slower memory, because it is the *same* memory.

In our own words, the mental model is: **the GPU does not own a smaller, faster room inside the house. It holds a key that lets it map pages of the one house into its own address book, up to a configurable limit. The carve-out is the only true partition, and it is the wasteful way to grant access. The GTT limit is a mapping budget, not a memory type.**

Coherence follows from the same structure. CPU and GPU operate on the same physical pages through their respective virtual mappings; there is no second copy to keep coherent across a bus. What remains is the ordinary cost of synchronisation — fences, cache flushes at domain crossings, and page-table work when mappings are created or torn down — not data movement. [SPECULATION, flagged as interpretation: secondary analyses of MLX describe the equivalent Apple cross-device "transfer" as a cache-flush/fence rather than a copy (`runners/mlx.md` §3.1); the same characterisation is consistent with AMD's mapped-not-partitioned description, but AMD's page does not use those words, and we do not put them in AMD's mouth.]

### 2.3 Apple Silicon — the comparison case

Apple Silicon is the same architectural bet, taken earlier and integrated more tightly: CPU, GPU, and Neural Engine on one SoC, one pool of LPDDR in-package, no device residence for data (in MLX, arrays have no location; operations have a device — `runners/mlx.md` §2–§3). The instructive comparison is the bandwidth ladder (Apple-published figures as carried in the sources read 2026-11-15, §7):

| Chip | Max unified memory | Published bandwidth | Bandwidth per GB of capacity |
|---|---|---|---|
| Apple M4 | 32 GB | 120 GB/s | 3.75 |
| Apple M4 Pro | 64 GB | 273 GB/s | 4.27 |
| Apple M4 Max | 128 GB | 546 GB/s | 4.27 |
| AMD Ryzen AI Max+ 395 (Strix Halo) | 128 GB | 256 GB/s theoretical (~215 reported sustained) | 2.0 (1.68 sustained) |

Read the last column, not the second. At *equal capacity* (128 GB), an M4 Max offers roughly **2.1× the theoretical bandwidth** of Strix Halo — which is why, model for model, Apple silicon generates tokens roughly twice as fast at the same model size, and why "both have 128 GB unified" is a deeply misleading equivalence. Capacity is the marketing number; bandwidth per capacity is the performance number. [Bandwidth-per-watt: Apple does not publish directly comparable package-power figures for these parts in the sources we read, and AMD's configurable TDP range for Strix Halo (45–120 W in secondary coverage) is not measured under the same conditions. The qualitative claim — Apple's perf/W lead at this class — is widely reported but we could not ground a *number* for it in a source read for this dossier, so we assert the direction only and mark the magnitude unmeasured.]

Where the designs **agree**:

- One pool; zero-copy; capacity as the headline win; bandwidth as the decode ceiling.
- The GPU may not have everything: macOS caps the practical GPU working set at roughly **65–75% of physical RAM** (Metal's recommended working-set discipline; `runners/mlx.md` §3.5 gives the four distinct MLX/macOS limits in full). AMD's default GTT of ~50% of RAM is the same instinct with a different default. Both platforms discovered, independently, that "the GPU can address it all" must not mean "the GPU may take it all."
- Residency is active, not automatic: macOS/MLX expose *wired* (pinned) memory controls, and MLX-LM documents raising the wired limit as the remedy for large models — pinning discipline reappears the moment copies disappear (`runners/mlx.md` §2.3, §3.5).

Where they **diverge**:

- **Integration of the limit.** Apple's working-set limit is an OS/runtime contract the framework reads programmatically (`max_recommended_working_set_size`) and enforces inside the process. AMD's GTT limit on Linux is a *kernel parameter* — set at boot, changed by reboot (§2.4). Same policy idea, very different ergonomics: one is a dial the runner can reason about at runtime; the other is a fence the administrator sets before the runner starts.
- **Bandwidth headroom.** As above: Apple's top tier buys bandwidth with a wider/faster memory system at the same capacity. Strix Halo's capacity-per-dollar is its counter-argument (128 GB x86 machines at mini-PC and laptop prices, running the ordinary Linux/ROCm/Vulkan stack).
- **Ecosystem gravity.** MLX was designed *from* unified memory; ROCm was designed for discrete accelerators and adapted to APUs. The seams show exactly where this dossier's §5 pathologies live — legacy allocation pools, pinned-memory habits, and tooling that still says "VRAM" about a mapping budget.

### 2.4 The other UMA designs, briefly

- **Intel Lunar Lake (Core Ultra 200V):** on-package LPDDR5X-8533, up to **32 GB**, ~136 GB/s (secondary comparisons read 2026-11-15, §7). Architecturally unified in the same sense — CPU, Arc GPU, and NPU share the package memory — but the capacity ceiling (32 GB) keeps it in the small-model class. It is a bandwidth-respectable, capacity-poor UMA: the opposite trade from Strix Halo.
- **Qualcomm Snapdragon X Elite:** LPDDR5X-8448, up to **64 GB**, ~135 GB/s (same sources). Mid-capacity, similar bandwidth to Lunar Lake, Arm/Windows ecosystem. Again: fits mid-size models whole, generates at LPDDR rates.

The pattern across all four vendors is the dossier's first law restated as a table: **everyone sells capacity; bandwidth is what they actually ration.** For local-LLM purposes the ranking by *usable model class* is set by capacity (128 > 64 > 32 GB), and the ranking by *speed within that class* is set by bandwidth (546 > 256 > ~135 GB/s). Strix Halo's niche — maximum capacity on x86/Linux at consumer prices, at half of Apple's top-tier bandwidth — is a real niche, and it is exactly Volmarr's use case.

### 2.5 The Linux allocation path, in our own words

On Linux, a Strix Halo GPU allocation travels roughly this road (kernel DRM documentation + AMD ROCm RDNA 3.5 page, both read 2026-11-15; synthesis in our words):

1. **TTM is the bookkeeper.** The Translation Table Manager is the DRM subsystem that tracks buffer objects, their lifetime, their placement, and their CPU/GPU mappings, for both UMA devices and discrete cards (kernel.org, *DRM Memory Management*). On an APU, "placement" rarely means moving bytes between memories — there is only one memory — it means establishing and bounding *mappings*.
2. **`ttm.pages_limit` is the pool's page budget.** It caps how many system pages may be mapped for GPU use at once, exposed at `/sys/module/ttm/parameters/pages_limit` and settable at boot. The number is in **4 KiB pages, not bytes** — the single most error-prone unit in this whole area. 100 GiB = 102,400 MiB = **26,214,400 pages**. (Keep this arithmetic; §3 turns on it.)
3. **`amdgpu.gttsize` is the driver's GTT aperture, in MiB.** It bounds the GPU virtual address space window backed by system RAM. In practice the two knobs are set as a matched pair: `gttsize` in MiB and `pages_limit` = the same quantity in pages. A mismatch means the smaller one governs and the larger one is theatre.
4. **`amd-ttm` is AMD's supported front door.** AMD's `amd-debug-tools` package provides `amd-ttm`, which reads the current limit, converts pages ↔ GB for the human, and writes the setting persistently (its worked example, `--set 100`, produces exactly 26,214,400 pages — the same figure our own fix arrived at by the GRUB road; §3.3). AMD's clustering playbooks add the operational rule that accompanies the tool: **leave roughly 20% of system RAM for the operating system** (AMD Developer playbooks, read via search results 2026-11-15, §7).
5. **Pinning is where reclaim goes to die.** AMD's documentation says GTT allocations are dynamic and reclaimable *in principle*. In practice, memory actively mapped and pinned for GPU work — model weights during inference, a live session's arena — cannot be paged out and cannot satisfy the kernel's OOM killer. A deployment note cited in our stability research puts it bluntly: on a UMA machine, amdgpu GTT can pin system RAM that the OOM killer cannot reclaim (`~/workspace/research_notes/strix-halo-linux-stability-fixes-20261114-1437/report.md` §6, citing a Project Bluefin lab ADR). The gap between "reclaimable in principle" and "pinned in practice" is where §3 happened.
6. **Swap does not rescue pinned memory.** GPU-held pages are legally unswappable. The swappable remainder can flood faster than any disk drain, and the OOM killer fires before swap absorbs a burst — our own record's answer to Volmarr's "why is it not using the swap?" (`~/memory/2026-11-14.md`, swap Q&A entry, 2026-11-14). Swap on this machine is large (a ~125 GB partition plus a 512 MB file, per the same day's first-aid entry) and mostly beside the point for GPU bursts; the Linux memory-redesign goal exists precisely because of this (`~/workspace/goals/linux-memory-redesign-for-the-z13/GOAL.md`: "a roughly 125 GB swap went unused while pinned model and graphics memory OOM-killed the desktop").

---

## 3. OUR CASE — the Z13 record, told straight

Every fact in this section is cited to the record it was read from. Dates are EST as recorded.

### 3.1 The machine and its starting state

Purpleraider is the ASUS ROG Flow Z13 (GZ302EA), Ryzen AI Max+ 395 / Radeon 8060S (gfx1151), **128 GB unified LPDDR5X**, Kubuntu 26.10 (kernel 7.3 series, Mesa 26.2) (`~/workspace/research_notes/strix-halo-linux-stability-fixes-20261114-1437/report.md`, header + §2; `~/workspace/goals/purpleraider-fix-campaign-nine-mythic-teams/hidden_files/CAMPAIGN_STATE_snapshot_0423.md`, "Machine truths"). Purchase context: ordered 2026-10-29, received 2026-11-03, Walmart, $3,500 (`~/MEMORY.md`, Z13 entry). Storage law on the machine: programs on the internal SSD, all models and data on the 4 TB Btrfs "vault" drive (`~/MEMORY.md`, purpleraider storage law) — relevant here only because model *files* were never the constraint; resident memory always was.

At stock settings, the ROCm-visible GPU pool was capped at roughly 61 GB — the community-corroborated consequence of the default GTT ≈ 50% of RAM (§2.2). Our community research of 2026-11-12 recorded it as: "without them ROCm caps APU allocations ~61 GB" (`~/memory/2026-11-12.md`, community-research entries).

### 3.2 The November 12 tuning — removing the ceiling, on purpose

On 2026-11-12 Volmarr ordered a robustness campaign in substance verbatim: "do the bootloader changes and reboot so we have no memory ceiling" (`~/memory/2026-11-12.md`, robustness-order entry). Stage 2 applied the community-chorus parameters, preserving the existing display flags:

```
iommu=pt  amdgpu.gttsize=126976  ttm.pages_limit=32505856
```

(`~/memory/2026-11-12.md`, same entry; the fix campaign's state snapshot independently records the same trio riding on the wedge boot: `~/workspace/goals/purpleraider-fix-campaign-nine-mythic-teams/hidden_files/CAMPAIGN_STATE_snapshot_0423.md`. The popular `amd_iommu=off` variant was expressly forbidden — it kills the NPU.)

The arithmetic of that choice, which nobody wrote down at the time and which this dossier exists to write down:

- `gttsize=126976` MiB = **124 GiB** of GPU-mappable system RAM, out of 128 GiB total.
- `pages_limit=32505856` pages × 4 KiB = the same 124 GiB. The pair agreed; the intent was unmistakable: *the GPU may map essentially everything.*

The campaign completed and proved its point honestly (`~/workspace/your_files/research/rog-flow-z13/ROBUSTNESS_CAMPAIGN_2026-11-12.md` §§ Stage 2):

- Pool proof: `mem_info_gtt_total` **60.75 GiB → 121.5 GiB** (65,227,026,432 → 130,454,048,768 bytes). **Note the honest discrepancy, preserved rather than reconciled:** the *parameters request* 124 GiB; the *driver grants* 121.5 GiB. Any retelling that quotes only one of those numbers is incomplete.
- Allocation proof: an **80.0 GB fp32 tensor allocated on the Radeon 8060S**, filled and verified — impossible under the old pool.
- The same campaign's 30-minute sustained-inference soak survived at ~70 W with zero faults, and its 16-point daily self-check passed 16/16. **Solo, attended, one-tenant workloads on the sprawl configuration ran clean.** That is also in the record (`~/memory/2026-11-14.md`, context entry ~09:0x: "his solo workloads (27B/40B benches, 30-min GEMM soak, Nov 12 audit 16/16) ran clean"), and it matters: the 124 GiB setting was not stupid. It was a capacity decision that was correct for the workload it was tested under, and fatal for a different one.

A second, quieter datum from the same week shows how easily this pool gets claimed: a single Aesir test process creating a HIP `DeviceContext` **pinned +106.4 GiB of GTT for the suite's life**, flaking a downstream memory-budget test by construction (`~/memory/2026-11-13.md`, Aesir keeper reconciliation, 2026-11-13). One context object, 83% of the machine's memory, held as a side effect. Remember this in §5.

And the pool was *useful*: Ollama tuning on 2026-11-13 ran with the note "Memory is plentiful on this UMA box (121.5 GiB GTT)" while deciding a ~0.9 GiB KV saving bought nothing (`~/workspace/your_files/research/rog-flow-z13/OLLAMA_TUNING_2026-11-13.md`). That sentence is the budgeting fallacy (§5) wearing its friendliest face — true that day, load-bearing the next.

### 3.3 2026-11-14 — the cascade

The morning of 2026-11-14, purpleraider carried maximum multi-tenant contention: Aesir's 27 teams, Voxta, Ollama with large models, Chrome, and Yrsa's suites, on stock Linux memory settings plus the 124 GiB GPU pool (`~/memory/2026-11-14.md`, context entry). The failures, in the record's order:

1. **06:37 — first OOM, desktop dies, model survives.** A Chrome process invoked the kernel OOM killer; the kernel killed processes inside the KDE session, kwin died, the session cascaded (plasmashell/kded6/powerdevil crash files in `/var/crash`), all tmux sessions died — and **Ollama, a system service, survived with the 40B model still loaded (44.2 GB)** (`~/memory/2026-11-14.md` ~06:37 entry). Read that survivor list again: the one tenant with the largest pinned footprint was the one the failure could not touch. That is the UMA failure mode in miniature.
2. **07:13 — second OOM.** The kernel OOM-killed an Aesir Mojo process (total-vm ~134 GB) plus the session user manager; the desktop restarted; swap took ~10 GB this time and the session still fell (same file, 07:13 entries). First aid applied live: **MGLRU enabled + zswap enabled with zstd**, ahead of the ~125 GB swap partition (same file; design doc `~/workspace/your_files/research/rog-flow-z13/LINUX_UNIFIED_MEMORY_CAMPAIGN_2026-11-14.md`).
3. **09:12 — the fenced run dies *correctly*.** A baseline matrix run launched inside a systemd fence was OOM-killed at 35.4 GB peak + 25.5 GB swap — and the blow stayed inside the unit: Voxta 200, Ollama 200, kwin alive, ~109 GB available immediately after (same file, fenced-era entries). This is the first appearance of the remedy pattern: the same death, contained, became an unremarkable log line.
4. **~09:17–09:32 — hard crash and the fresh-boot lesson.** A hard crash requiring Volmarr's force restart, followed within minutes by a ~24 GB Aesir test serve launched on the just-rebooted machine while he was sitting at it (same file; `~/AGENTS.md`, "No massive tests on a just-started machine"). Separately, fresh boots at *light* load produced plasmashell/Chrome/KDE crash dumps — shell fragility on a cold system, a different incident class from the OOMs (same file, ~09:27–09:33 investigation entry), matching the published PSR/Adaptive-Sync display class in the stability report (§7 of that report; ranked fix #1 there).
5. **Under load throughout: `HSA BlockAllocator::alloc failed`** — ROCm GPU allocation failures of exactly the kind the stability research documents as a ROCm legacy-pool fragmentation/OOM behaviour that the Vulkan backend does not exhibit (`~/workspace/research_notes/strix-halo-linux-stability-fixes-20261114-1437/report.md` §6).

Yrsa's own retrospective in the record owns the crews' share plainly: all four failures happened under maximum contention her campaigns created, on a machine whose GPU pool her own November tuning had set to nearly the whole memory (same file, ranked-fixes entry: "part of the OOM violence may be our own over-allocation, fixable by removal rather than new code"). The research verdict agreed: the OOM + BlockAllocator group is "the textbook unified-memory failure mode (GPU pool vs. OS on one 128 GB pool)" with an official AMD remedy (stability report, Verdict).

**The fix, applied 2026-11-14 ~09:51 EST at Volmarr's order** (same file, vendor-fixes entry):

- **GTT/TTM cap: 100 GiB.** GRUB flags changed `amdgpu.gttsize 126976 → 102400`, `ttm.pages_limit 32505856 → 26214400`; only that line changed, all other flags preserved; grub backup kept; `update-grub` clean and verified in `grub.cfg`. **Disagreement with public guidance, stated openly:** AMD's documented road is `amd-ttm` writing a modprobe config (§2.5); our record says explicitly "**amd-ttm NOT installed (nothing installed)**" — the same numeric destination (102,400 MiB / 26,214,400 pages — identical to AMD's own `--set 100` example output) reached by the GRUB road instead. The value follows AMD's guidance and its "leave ~20% for the OS" rule (100 GiB leaves ~28 GiB, ≈22%); the mechanism does not. Future work should pick one road and record why.
- **KDE Adaptive Sync set to "Always."** The application entry records it applied live to the built-in panel (eDP-1), the external HDMI display untouched (same entry); a later consolidated claim in the same day's log says "Adaptive Sync was set to Always on both displays" (`~/memory/2026-11-14.md`, claim entry ~20:xx). **The records disagree on scope;** the contemporaneous application entry (built-in only) is the more specific source, and the both-displays statement is carried in `~/MEMORY.md`/alignment as Volmarr's settled state. We report both and do not silently merge them.
- **Verified live after Volmarr's own clean reboot (~10:01 EST):** `/proc/cmdline` carries `amdgpu.gttsize=102400` + `ttm.pages_limit=26214400` — "100 GiB cap IN FORCE" — with MemAvailable ~124 GB, Voxta + Ollama up, battery cap still 80% (same file, cap-live entry).

The keep became conditional the same day: fix the machine's behaviour inside the Walmart return window (operative deadline January 31, 2027; conservative floor December 3, 2026) or it goes back (`~/MEMORY.md`, Z13 keep entry, updated 2026-11-14). A verdict check is set for December 1, 2026 (`~/workspace/goals/asus-rog-flow-z13-order/crons/runonce/z13-return-window-verdict-check__runonce@2026-12-01T09:30:00.md`).

### 3.4 What actually ran on the machine — benchmark record

Only numbers found in records, with the record named:

**Ollama (the yardsticks).** For the 27B Heretic (qwen35) served through Ollama on purpleraider: **generation 7.65 tok/s at Q8_0; 12.11 tok/s at Q4_K_M** (`~/memory/2026-11-14.md`, AESIR SPEED + STABILITY commission entry, 2026-11-14 ~20:05 EST, where both figures are recorded as the campaign's yardsticks; the Q4 figure is independently restated in the same day's VOXTA QUICK-FIX entry — "generation 12.11 tok/s fine" — and in `~/workspace/goals/ollama-memory-forge/hidden_files/research-local-projects.md` §header). The same Voxta entry records the real user pain beside them: a 14,712-token prompt re-evaluated from cold cost **52.1 s before the first word** — decode was never the disease; re-processing was.

**Ollama (the tuning proof).** Qwen2.5-7B-Instruct Q4_K_M, 256-token protocol, 2026-11-13: stock Ollama silently ran **100% CPU at 16.82 tok/s** (it drops the Strix Halo iGPU unless told otherwise); correctly GPU-resident it reached **40.79 tok/s generation / 1,577.52 tok/s prompt eval** (medians), a 2.42× fix from one configuration defect (`~/workspace/your_files/research/rog-flow-z13/OLLAMA_TUNING_2026-11-13.md`). On UMA this failure mode has a special sting: "CPU vs GPU" is not two memories, it is two *processors reading the same pool at different bandwidth/compute profiles* — the model was resident either way; only the execution was wrong.

**Aesir (residency economics, measured the hard way).**

- A live HIP session's arena made **~the whole GTT pool read consumed: MemAvailable 124 GB → ~27 GB**, recovering on stop (`~/memory/2026-11-14.md`, HS milestone entry, 2026-11-14 ~10:25 EST). A session arena that sizes itself to the pool is the 124 GiB mistake re-implemented in userspace.
- The naive loader's format-widening priced a **27B load at ~57 GB peak** for a model whose Q8_0-resident form is **≈28.6 GB**; the 40B F16 estimate was **~83 GB** (same file, parent-gate ruling entry). The ruling that followed is quoted in §6 because it deserves to become general law: build the resident-format path first; attempt a load only under a *measured-fit rule* (free memory ≥ peak + 8 GB margin), fenced so failure kills only itself.
- End state in the current record: **aesir-gate serves the 27B Heretic in the Q8_0-resident CPU configuration** (fence 48G/64G in its later relight), live completion verified; **HIP decode measured ~0.07–0.09 tok/s — experimental, explicitly not chosen** for the gate (`~/workspace/CURRENT_STATE.md`, HIP-serve line, refreshed 2026-11-15 01:18 EST; `~/memory/2026-11-14.md` QS commission entry). Aesir's own compression school produced the 27B Q4_K_M product at **16,223,236,576 bytes (56.7% of Q8_0)**, admitted by all four readers, graded DIVERGENT by the strict gate at 99.49% in-band (same CURRENT_STATE line) — a capacity triumph and a faithfulness caveat in the same sentence, which is the honest shape of Q4 on this hardware.
- An earlier honest negative belongs here too: on the A-081 Part III gate, Aesir's GPU path ran the same 8B Q4_K_M fixture at **1.497 tok/s vs CPU 6.958 tok/s** (32/32 token ids exact), GPU/CPU = 0.215× against a ≥2× bar — GPU path *not* declared primary, blockers named as road slices (`~/workspace/goals/aesir-z13-strix-halo-forge/hidden_files/keeper-run-log.md`, A-081 entry). On UMA, "it runs on the GPU" is a claim about an address mapping, not about speed; this record is what grading that claim honestly looks like.

**MimirAlloc on the Z13** completed its second campaign at **117 of 117**, final gate **4,988 passed / 0 failed / 77 skipped** (`~/workspace/CURRENT_STATE.md`, MimirAlloc Z13 line; full treatment in `memory/mimiralloc-our-own-proven-work.md`). Its unified-memory-specific findings are taken up in §6.

### 3.5 The standing fences — operational lessons now in force

From the records, as standing practice after 2026-11-14:

1. **Every heavy run is fenced.** Heavy runs on purpleraider launch via `systemd-run` with `-p MemoryHigh=24G -p MemoryMax=32G` (the Aesir steering of 2026-11-14; the 27B serve later ran under a larger, *named* 48G/64G fence) (`~/memory/2026-11-14.md`, safety-steering entry). The 09:12 incident is the proof of value: identical OOM, zero collateral.
2. **Check headroom, stand down below it.** Check MemAvailable first; stand down under ~40 GB free; heavy runs **serialized, never two at once**; targeted subsets preferred over full matrices while Volmarr is using the machine (same entry).
3. **The fresh-boot law.** Volmarr, verbatim in substance: "never ever start a massive test on any machine that has just started up" (`~/AGENTS.md`, 2026-11-14 law; `~/memory/2026-11-14.md` ~09:36 EST entry). A freshly booted machine is still settling; the 09:32 incident — a ~24 GB serve minutes after a force restart, while he sat at the machine — is its origin. The one recorded exception proves the rule's shape: for the HS restart that same morning, Volmarr himself set the settle allowance ("work may begin two minutes after boot") for that boot (cap-live entry) — the law is *his* throttle to lift, not ours to assume away.
4. **Pause discipline.** All work on purpleraider paused at his word until he says he is done; GUI proofs moved to a separate headless desktop, never his live session (`~/MEMORY.md`, purpleraider pause entry; `~/AGENTS.md`, GUI proof law, both 2026-11-14).
5. **The redesign commission.** The deeper fix is commissioned, not improvised: live shields first (oomd tuning, cgroup fences, desktop protection), then a Linux-style kernel patch series for unified-memory handling, published to the Z13 fixes repo and donated upstream with his sign-off (`~/workspace/goals/linux-memory-redesign-for-the-z13/GOAL.md`; design doc `~/workspace/your_files/research/rog-flow-z13/LINUX_UNIFIED_MEMORY_CAMPAIGN_2026-11-14.md`, whose diagnosis adds: pinned GPU memory is essentially invisible in standard accounting, and its log lines mislead). Volmarr's own design direction for it is recorded: on a unified device, prefer pageable paths where a stack allows, add a compressed in-RAM tier (zswap) ahead of disk swap, and make reclaim wake early and gently instead of escalating to the killer (`~/memory/2026-11-14.md`, redesign-direction entry).

---

## 4. The economics

### 4.1 A 40B at Q8_0 is a capacity non-issue and a bandwidth question

Our arithmetic, from recorded figures: the 40B as Ollama held it resident occupied **44.2 GB** (`~/memory/2026-11-14.md` ~06:37 entry). Against the pool:

- **Capacity:** 44.2 GB is 35% of 128 GB, 44% of the capped 100 GiB GPU pool. It fits with the 27B (~28.6 GB resident) beside it — together ~72.8 GB — a combination Volmarr himself walked through when questioning the cap ("~100 GB still fits his largest model (40B, ~44 GB) plus the 27B together (~72 GB), while fencing ~28 GB the system/desktop can never lose"; `~/memory/2026-11-14.md`, cap-explanation entry). On any discrete consumer card this sentence is fantasy. On UMA it is arithmetic.
- **Bandwidth:** the roofline ceiling for decode is `bandwidth ÷ bytes read per token ≈ bandwidth ÷ resident weight bytes` (weights dominate at small batch; method in `memory/memory-wall-and-roofline.md`):

| Model (resident form) | Resident bytes (record) | Ceiling @ 256 GB/s theoretical | Ceiling @ ~215 GB/s reported sustained | Measured generation (record) |
|---|---|---|---|---|
| 27B Q8_0 | ≈28.6 GB | ≈9.0 tok/s | ≈7.5 tok/s | **7.65 tok/s** (Ollama) |
| 27B Q4_K_M | 16.22 GB (Aesir product) | ≈15.8 tok/s | ≈13.3 tok/s | **12.11 tok/s** (Ollama) |
| 40B Q8_0-class | 44.2 GB | ≈5.8 tok/s | ≈4.9 tok/s | *not in the records mined — see note* |

The measured 27B figures land at 85–91% of the *theoretical* ceiling and at/above the reported-sustained ceiling — which tells us two things: Ollama's decode on this machine is already close to the memory system's practical limit (there is no large software win hiding here), and the ~215 GB/s "measured" community figure is, if anything, conservative for this workload, or the effective read is slightly less than full resident bytes per token. Either way: **the remaining lever is bytes, not kernels.** Halving resident bytes (Q8_0 → Q4_K_M) bought 1.58× the tokens (12.11 / 7.65) — less than the 1.76× byte ratio, the difference being fixed per-token costs — and that trade is priced in faithfulness, as Aesir's DIVERGENT grade on its own Q4_K_M product attests (§3.4). *Note: no 40B generation rate was found in the records mined for this dossier; the ceilings in its row are our arithmetic only, and are labelled as such rather than dressed as measurements.*

### 4.2 The KV cache competes in the same pool — there is no wall, there is a commons

The KV-design dossier (`memory/kv-cache-design.md`) derives the cache's price exactly: bytes per token = 2 × layers × KV-heads × head-dim × bytes-per-element, growing linearly with context and with concurrent sessions, without intrinsic limit. On a discrete card, that growth is fenced by VRAM: the cache eats the card, the card says no, the runner degrades (shorter context, fewer slots, an allocator error). The failure is *legible and local*.

On UMA the same growth draws on the commons:

- Weights (fixed) + KV (grows with context × sessions) + prefix/snapshot stores (Aesir's hybrid snapshots run ≈158.9 MB each for the 27B, bounded at 4 per session in its design — `~/workspace/goals/ollama-memory-forge/hidden_files/research-local-projects.md` §5) + the OS + the desktop + every other tenant — **one sum, one limit, no internal walls unless someone builds them.**
- The failure at the limit is not "context truncated" or "request refused." It is the 06:37 pattern: the kernel chooses a victim, and the victim is whoever is *killable* — which, pinned GPU memory being unkillable, tends to mean **the desktop, the session manager, and the user's other work**, in some order. The model, holding the pinned plurality, survives its own famine.
- Long context is therefore not a feature to maximise but a *standing reservation against the OS*. Every doubling of `num_ctx` at fixed session count is a budget decision about how much of the machine the conversation may hold hostage, and it must be made in the same ledger as the weights — the KV dossier's sizing discipline (state precision, fragmentation reserve, and per-session caps *before* quoting a context length) is, on UMA, a system-safety discipline and not merely a serving optimisation.

### 4.3 The inversion of the 6 GB problem

Our fleet contains the opposite pole: the 6 GB discrete constraint on purplelongship, named in the field map as "the 6 GB discipline" (`research/memory/00-MEMORY-FIELD-MAP.md`, Topic C1). Designing for 6 GB VRAM teaches: quantise aggressively, cap context hard, offload reluctantly and knowingly, treat every hundred megabytes as contested, and expect failure to arrive as a clean allocator refusal at load time.

UMA inverts every term:

| | 6 GB discrete | 128 GB unified (Z13) |
|---|---|---|
| Binding constraint | Capacity (VRAM) | Bandwidth, then *aggregate* capacity |
| Load-time question | "Does it fit at all?" | "What else must still fit beside it?" |
| Typical failure | Refusal at load; process-local OOM | System-wide OOM under load, hours in, at peak context × tenants |
| Failure victim | The process that asked | The desktop / session / bystander processes |
| Scarce resource discipline | Bytes per weight (quantisation) | Bytes per *second* (bandwidth) + bytes *reserved* (budget) |
| Context length | Capped by arithmetic, visibly | Capped by policy, or not capped at all until the kernel caps it for you |
| Swap/offload | PCIe spill, slow but bounded | Pinned = unswappable; spill tier must be *designed* (zswap, tiered KV) |

The design skill does not transfer by scaling the numbers up. It transfers by recognising that **the 6 GB card enforces the budget physically, and the UMA machine requires the budget to be enforced by the software that the card made unnecessary.** Runners written for discrete GPUs routinely treat host RAM as the forgiving overflow tier; ported naively to UMA, that habit allocates from the same pool twice in its accounting and once in reality.

---

## 5. Failure modes & pathologies

1. **GTT sprawl.** Raising the GPU mapping limit toward total RAM converts every GPU allocation bug, leak, and arena over-size into a system event. Our case is canonical: parameters requesting 124 GiB (§3.2), a single HIP context pinning +106.4 GiB as a side effect (§3.2), a session arena reading as ~the whole pool consumed (§3.4). *None of these required a malicious or even buggy workload* — only defaults sized to the pool instead of to the need. Countermeasure class: explicit caps at every layer (kernel GTT, cgroup fence, per-session arena), each smaller than the layer above it.
2. **The "GPU memory is just RAM" budgeting fallacy.** Because GTT memory is the same DRAM, it is tempting to budget it as if it were ordinary process memory: overcommittable, swappable, reclaimable under pressure, forgiving. It is none of those while pinned. The MLX dossier makes the identical point from the Apple side — freed buffers retained in cache, wired limits that must be raised deliberately, residency that decays while the GPU idles and must be refreshed (`runners/mlx.md` §3.5, §2.3) — and our Ollama-tuning note ("memory is plentiful… the ~0.9 GiB saving buys nothing", §3.2) shows the fallacy in its mildest, most reasonable voice. The fallacy's tell: any sentence that quotes *total* RAM as the budget for a GPU workload. The correct budget is always a named sub-ledger (§6).
3. **Page-fault storms on first touch.** Mapped-not-partitioned memory must still be mapped: page tables built, pages faulted in, mappings established. First-touch costs surface as inexplicable load-time and first-token stalls — our Ollama recon in the sibling campaign caught the same physics from the CPU side, discarding a 56.7 tok/s "cold" reading that was really mmap page-in, against a ~1,010 tok/s warm prompt-eval baseline (`~/workspace/goals/ollama-memory-forge/hidden_files/recon-om0.md`). On the GPU side, long-context prefill can additionally trip device-timeout machinery: the stability research records Ollama long-prompt `ErrorDeviceLost` failures at defaults on this platform class and owners raising `amdgpu.lockup_timeout` because long prefills exceed the ~10 s default watchdog (stability report §6). A runner must treat *first* touch as a budgeted phase (pre-faulting, warm-up, watchdog awareness), not as free setup.
4. **Coherence and synchronisation costs.** Zero-copy is not zero-cost: cross-engine work still pays fences and cache maintenance, and concurrent CPU+GPU execution *shares the bus* — at decode, where the GPU alone can saturate bandwidth, splitting work across units adds nothing (the FusionML result reported in `runners/mlx.md` §2.3: splitting helped prefill ~1.15–1.38×, did not help decode). Designs that "use everything at once" on UMA must show their bandwidth arithmetic, or they are spending the same 256 GB/s twice on paper.
5. **Invisible accounting.** Pinned/GTT memory is poorly represented in the standard tools (`free`, RSS, most dashboards) — the redesign campaign's diagnosis names this directly (§3.5, item 5). A system can report comfortable headroom while the un-reclaimable plurality is already committed. Any UMA operations practice that does not include a GTT-specific readout (`mem_info_gtt_total` and friends) in its health check is flying on instruments that do not cover the risk. Our fix campaign's daily self-check already includes "GTT pool size" as one of its 16 checks (`~/workspace/your_files/research/rog-flow-z13/ROBUSTNESS_CAMPAIGN_2026-11-12.md` § Stage 5) — keep that pattern.
6. **Contention collapse at the desktop.** The compositor is a GPU client too. Under memory pressure the display path starves and resets with everything else — on this platform compounded by the documented PSR/VPE/display bug classes (stability report §§1, 7). The user-visible symptom ("the desktop froze/crashed") is then systematically misread as a desktop bug. Triage rule from our morning: on a UMA machine under AI load, *every* desktop failure is a memory-budget suspect until the logs acquit it.
7. **Fresh-boot fragility.** A just-booted UMA machine is at its most deceptive: MemAvailable reads enormous (~124 GB on the capped Z13), daemons and caches are still faulting in, and shell components are at their crash-prone cold state. Launching maximum work into that window caused real harm here (§3.3, item 4) and is now law (fresh-boot law, §3.5). [SPECULATION: part of the mechanism is likely first-touch fault storms (item 3) arriving simultaneously from every tenant at once; the record establishes the correlation and the law, not the full mechanism.]

---

## 6. Applicability

### 6.1 The improved Ollama — budgeting on UMA

Concrete rules, each traceable to a section above:

1. **Detect UMA and budget as one pool.** When the backend's memory *is* system memory (Strix Halo/GTT, Apple/Metal, other APUs), the runner's memory ledger must be a single disaggregated budget — weights / KV / prefix cache / workspace / **OS headroom as a first-class, named reservation** — under one arbiter, in the MLX style the ingest note already prescribes (`~/workspace/goals/ollama-research-forge/ingest/INGEST-002-memory-core.md`, decision rules: "On unified memory: disaggregate the budget… with named limits and one arbiter… a single global cap hides the fight until it becomes a crash"). AMD's ~20%-for-the-OS rule and our 100 GiB cap (≈22% reserved) are the same policy at two altitudes; the runner should enforce its own version *inside* whatever the kernel allows.
2. **Explicit caps, defaulted conservatively.** GPU-pool sizing must never default to "as much as the driver permits." Default to a fraction of RAM with the OS reservation subtracted; let raising it be a deliberate, logged act — the exact inversion of the community-chorus `gttsize=126976` recipe our machine followed in good faith.
3. **Resident-format loading + the measured-fit rule.** Never materialise a widened copy of the weights (§3.4: ~57 GB peak for a 28.6 GB model). Adopt Aesir's parent-gate rule verbatim as operating policy: *no load unless measured free memory ≥ expected peak + margin; the attempt fenced so its failure kills only itself.* In Ollama terms: pre-load admission control that refuses (loudly, with numbers) instead of OOMing (silently, with victims).
4. **Size KV from the ledger, not from the model's maximum.** Context length, slot count, and KV quantisation are one multiplication (KV dossier §1.2) charged against the same pool as the weights. Quote context as "X tokens at Y precision within budget Z," and evict/preempt by policy (the KV dossier's composite bet: pinned anchor + recent window + scored middle) — never by kernel OOM.
5. **Ship the fences with the runner.** On UMA, recommend and where possible self-apply cgroup limits (MemoryHigh/Max) for the serve process, and surface GTT/pinned consumption in the runner's own status output. A runner that knows it lives on a commons should behave like a good tenant *measurably*.
6. **Backend honesty on gfx1151.** Our records carry two Ollama-relevant warnings: stock Ollama silently fell back to 100% CPU on this iGPU until configured (§3.4 — a 2.42× defect hiding behind "it works"), and the ROCm path carries the BlockAllocator failure class that Vulkan/RADV does not (stability report §6). Detection and backend choice on UMA APUs are memory-architecture decisions, not packaging details.

### 6.2 Aesir — resident sessions on this machine

Aesir's design centre — resident sessions holding token-level state (KV arenas, and for hybrid models, SSM/conv snapshots) across turns — is *the* architecture UMA rewards: residency is cheap when there is no second pool to copy into, and the Voxta disease it cures (52.1 s of re-processing per turn, §3.4) is the most expensive habit a chat workload has. The Z13 record adds its disciplines:

- **Bound every arena.** Per-session KV arenas and a hard snapshot bound (4 per session in the Q35 design) are not tuning details; on a commons they are the difference between a session store and a slow-motion GTT sprawl (§5.1). The observed whole-pool arena reading (§3.4) must be graded as a defect class and tested against: *a session's footprint is a number it can state, not a pool it can fill.*
- **Resident format is the serve contract.** The Q8_0-resident path (28.6 GB, chosen for the live gate) over F16 materialisation (~57 GB) is what makes the 27B serve *coexist* with Volmarr's own programs — the parent gate said so explicitly (§3.4). Generalise: every Aesir serve configuration ships with its resident-bytes figure and its fence (48G/64G for the 27B gate) as part of the configuration, not as operational folklore.
- **Grade the accelerator claim per path.** CPU-resident serves the 27B today; HIP decode at ~0.07–0.09 tok/s is a research result, not a serve (§3.4); the A-081 negative (GPU 0.215× of CPU, same fixture) is the standing reminder that on UMA the GPU mapping is free and the GPU *speed* must still be earned kernel by kernel. The QS campaign's yardsticks (Ollama 7.65 / 12.11 tok/s) are the right shape of target: same machine, same pool, published numbers.
- **Prefix reuse is a memory feature.** HS-3's proof (turn 2 reusing tokens instead of re-evaluating) and the snapshot-restore result (bit-exact, reuse even after residency was destroyed) belong in this dossier because their *cost* is denominated in pool bytes (≈158.9 MB per hybrid snapshot) and their *return* in bandwidth-seconds not spent. Budget them in the same ledger as KV (§6.1.4).

### 6.3 MimirAlloc — unified pools as allocation territory

MimirAlloc's two completed campaigns (Pi 117/117; Z13 117/117, gate 4,988 passed / 0 failed / 77 skipped — §3.4) give this dossier its allocator evidence, and UMA is where its lessons bite hardest:

- **The honest core finding transfers:** a simple global-lock design with a fresh mapping per large allocation loses badly to glibc on churn workloads and wins only in scoped shapes (full treatment: `memory/mimiralloc-our-own-proven-work.md`; summary in `ingest/INGEST-002-memory-core.md` §5). On UMA, the large-allocation path is not an edge case — *weights, KV blocks, and session arenas are all large allocations*, and a mapping-per-allocation strategy pays page-table and fault costs (§5.3) at exactly the scale where the runner can least afford them. Arena/pool shapes with stated bounds (§6.2) are the UMA-appropriate form of MimirAlloc's "scoped wins."
- **Return-to-OS policy is a safety property here.** An allocator that retains freed arenas (the MLX cache behaviour, §5.2) is merely wasteful on a discrete host; on a UMA commons it is a standing reduction of everyone else's headroom, invisible to standard accounting (§5.5). MimirAlloc's discipline — judge a pool by its p99 under the real size distribution, its return-to-OS policy, and its behaviour at 2× expected fragmentation, in that order (INGEST-002, decision rules) — should be applied verbatim to every pool a runner builds on this machine.
- **The Z13 campaign's own framing is the correct research posture:** its roadmap treated "unified memory, huge pages, thread tuning for sixteen cores" as *the hardware's truths to be measured on this machine*, and demoted the Pi campaign's verdicts to questions until Z13 numbers answered them (`~/workspace/goals/mimiralloc-forge/agent_notes/2026-11-12/mimiralloc-forge.md`). Unified pools are allocation territory with their own physics — page size, fault cost, pinning — and the allocator that respects them will be the one measured *in* them, not imported with verdicts from a two-pool world.

---

## 7. Sources

### Public — read 2026-11-15 (browser search + text fetch)

- AMD ROCm — *RDNA3.5 system optimization* (GPUVM/GART/GTT definitions; GTT default ≈50% of RAM; BIOS carve-out guidance 0.5 GB; TTM `pages_limit`; `amd-ttm` with the `--set 100` → 26,214,400 pages worked example; kernel ≥6.18.4 requirement for gfx1151) — https://rocm.docs.amd.com/en/latest/reference/system-optimization/rdna3-5.html — **fetched and read in full, 2026-11-15**.
- AMD Developer playbooks — clustering on Ryzen AI Halo (shared-pool default = half of system memory; raise via GTT/TTM; BIOS VRAM minimum 0.5 GB; "leave roughly 20% of system RAM for the operating system"; `amd-ttm --set 120` example) — https://developer.amd.com/playbooks/clustering-rccl/ and https://developer.amd.com/playbooks/clustering-rccl-4-node/ — via search results, 2026-11-15.
- Linux kernel documentation — *DRM Memory Management* (TTM and GEM; TTM as the manager for UMA and dedicated-VRAM devices alike) — https://www.kernel.org/doc/html/latest/gpu/drm-mm.html — via search results, 2026-11-15.
- Strix Halo specifications and bandwidth coverage (256-bit LPDDR5X-8000; 256 GB/s theoretical; ~215 GB/s reported measured; up to 96 GB GPU-assigned on Windows, more via Linux GTT) — https://www.intelligentliving.co/amd-strix-halo-128gb-mini-supercomputer/ ; https://specpicks.com/reviews/amd-ryzen-ai-max-395-strix-halo-128gb-mini-pc-2026 ; https://myminingrig.com/ai-rigs/guides/strix-halo/ — via search results, 2026-11-15. *Secondary sources; no AMD primary sustained-bandwidth figure was found.*
- Apple Silicon bandwidth ladder (M4 120 GB/s / 32 GB; M4 Pro 273 GB/s / 64 GB; M4 Max 546 GB/s / 128 GB; GPU working set ≈65–75% of RAM) — https://www.gpufits.com/en/guides/mac-vs-gpu-for-llm-inference/ ; https://www.squaredtech.co/optimizing-local-llm-inference-on-apple-m4-memory-bottlenecks-vs-throughput ; https://www.aicassindra.com/blogs/gpu/gpu_apple_silicon.html — via search results, 2026-11-15.
- Intel Lunar Lake / Qualcomm Snapdragon X Elite memory figures (Lunar Lake: on-package LPDDR5X-8533, ≤32 GB, ~136 GB/s; X Elite: LPDDR5X-8448, ≤64 GB, ~135 GB/s) — https://www.myaihardware.com/compare-article/snapdragon-x-elite-vs-intel-core-ultra-9-288v-copilot-plus ; https://ts2.tech/en/next-gen-laptop-chip-showdown-intels-lunar-lake-vs-amds-ryzen-ai-vs-qualcomms-x-elite-who-wins-the-ai-pc-crown/ — via search results, 2026-11-15. *Secondary comparisons; treated as approximate.*

### Internal — Volmarr's records, read on this VM 2026-11-15

- `~/workspace/research_notes/strix-halo-linux-stability-fixes-20261114-1437/report.md` — the 2026-11-14 stability research (gfx1151 bug classes; GTT/TTM mechanics; AMD's cap guidance; BlockAllocator as a ROCm-pool behaviour). *Note: that directory's own AGENTS.md marks its contents as web-derived research data; it is cited here as a research record, and its load-bearing claims were cross-checked against the AMD ROCm page above.*
- `~/memory/2026-11-12.md` — community research + robustness order + campaign completion (GTT 60.75 → 121.5 GiB; 80.0 GB tensor proof).
- `~/memory/2026-11-13.md` — HIP DeviceContext +106.4 GiB GTT pin (Aesir keeper reconciliation).
- `~/memory/2026-11-14.md` — the cascade day: 06:37 / 07:13 OOMs, fenced 09:12 run, hard crash, fresh-boot law, ranked fixes, the 100 GiB cap applied + verified live, Voxta quick-fix (12.11 tok/s; 14,712 tokens / 52.1 s), HS milestone (arena 124 → ~27 GB), parent-gate measured-fit ruling (~57 GB vs ≈28.6 GB), QS commission (7.65 / 12.11 yardsticks; HIP ~0.07–0.09 tok/s).
- `~/workspace/your_files/research/rog-flow-z13/ROBUSTNESS_CAMPAIGN_2026-11-12.md` — Stage 2 pool/allocation proofs; Stage 5 self-check incl. GTT pool size.
- `~/workspace/your_files/research/rog-flow-z13/OLLAMA_TUNING_2026-11-13.md` — 7B Q4_K_M: 16.82 tok/s CPU-only → 40.79 tok/s GPU (medians).
- `~/workspace/your_files/research/rog-flow-z13/LINUX_UNIFIED_MEMORY_CAMPAIGN_2026-11-14.md` — redesign design doc (pinned-memory invisibility; MGLRU/zswap first aid).
- `~/workspace/goals/linux-memory-redesign-for-the-z13/GOAL.md` — the redesign commission (125 GB swap unused; pinned memory OOM-killed the desktop).
- `~/workspace/goals/purpleraider-fix-campaign-nine-mythic-teams/hidden_files/CAMPAIGN_STATE_snapshot_0423.md` — machine truths; the Stage-2 parameters on the wedge boot.
- `~/workspace/goals/ollama-memory-forge/hidden_files/research-local-projects.md` — Aesir prefix/session/snapshot evidence (158.9 MB snapshots, bound of 4; Q8_0-resident path).
- `~/workspace/goals/ollama-memory-forge/hidden_files/recon-om0.md` — cold page-in vs warm prompt-eval measurement discipline.
- `~/workspace/goals/aesir-z13-strix-halo-forge/hidden_files/keeper-run-log.md` — A-081 honest negative (GPU 1.497 vs CPU 6.958 tok/s).
- `~/workspace/goals/ollama-research-forge/ingest/INGEST-002-memory-core.md` — the corpus's own memory decision rules (one-pool disaggregated budgeting).
- `~/workspace/CURRENT_STATE.md` (refreshed 2026-11-15 01:18 EST) — Aesir HIP-serve end state (27B Q8_0-resident serve; Q4_K_M product 16,223,236,576 B, DIVERGENT at 99.49%); MimirAlloc Z13 117/117, gate 4,988 / 0 / 77.
- `~/MEMORY.md` — Z13 purchase/keep-or-return record; storage law; purpleraider pause.
- `~/AGENTS.md` — fresh-boot law; GUI-proof law (2026-11-14).

### Expected but not found

- **No 40B generation rate** for Ollama on purpleraider exists in the records mined; §4.1's 40B row is arithmetic only and is labelled as such.
- **No sustained-bandwidth measurement of our own** (STREAM-class or equivalent) for purpleraider was found in any record; the ~215 GB/s figure is community-reported. A fenced, attended bandwidth measurement on the capped configuration is owed before any future ceiling claim is quoted as ours.
- **No record of `amd-ttm` ever being run** on purpleraider was found — consistent with the cap entry's explicit "amd-ttm NOT installed," and recorded in §3.3 as a deliberate divergence from AMD's documented road, not an oversight to be silently corrected in retelling.
