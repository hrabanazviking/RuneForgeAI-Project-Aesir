# Memory Technologies — DRAM Generations and CXL: The Datasheet Layer

**Dossier OR-6 (Memory), Topics B6 + B8 — Ollama Research Forge**
**Date: 2026-11-15**
**Status: Literature dossier, in our own words. Every bandwidth figure is tied to a source read on 2026-11-15 (access date given per source in §9) or shows its arithmetic from sourced inputs. Vendor marketing figures are marked [VENDOR CLAIM]. Speculation is marked [SPECULATION]. Where sources disagreed, the disagreement is stated, not smoothed over. Companion dossiers: `memory/memory-wall-and-roofline.md` (Topic B5 — the method this dossier feeds), `memory/unified-memory.md` (Topic B7 — the Z13 case that §3 and §8 draw on), `memory/kv-cache-design.md` (Topic A1 — the budget that competes inside every pool named here).**

**Field-map position:** The MEMORY-COMPENDIUM's Chapter 10 audit lists B6 (DRAM generations) and B8 (CXL & pooling) as unfilled branches — present in the corpus only as scattered anchors. This dossier fills both as one document, because they are one subject: B8 is what happens when a DRAM branch is moved off the motherboard and onto a fabric, and it cannot be priced without the B6 numbers in hand.

---

## 1. Essence — every tok/s number is a datasheet number in disguise

Strip any benchmark in this corpus down to its moving parts and the same sentence falls out:

> **Decode tokens per second, at batch 1, ≈ sustained memory bandwidth ÷ bytes read per token.**

That is the roofline rule of the B5 dossier. It means the *physical* layer — the DRAM standard soldered or slotted into the machine, the width of its bus, the rate on its pins — is not background colour for runner engineering. It is the ceiling every runner number is a fraction of. A 7B model at Q4 does not run at "llama.cpp speed" or "Ollama speed" in the first instance; it runs at *some percentage of what its memory system can stream*, and the engine's job is to make that percentage large. Change the memory technology and the same binary, the same quant, the same prompt produces a different machine.

This dossier is therefore organised by the only three variables a DRAM technology actually trades in:

1. **Bandwidth (GB/s)** — how many bytes per second the technology can stream when the access pattern is long and sequential. This sets the decode ceiling.
2. **Latency (ns)** — how long one dependent, unprepared access takes to return its first data. This sets prefill's small-print, time-to-first-token behaviour at small batch, KV-cache random-access cost, and whether a tier can serve *live* decode traffic or only *stored* traffic.
3. **Capacity per dollar and per watt (GB/$, GB/W)** — how much of the stuff a machine can afford, in money and in heat, at purchase time. This sets which model class fits at all — the first wall, hit before bandwidth ever matters.

Every branch below — DDR, LPDDR, GDDR, HBM, SRAM, and CXL-attached DRAM — is a different point in that three-variable space, chosen by a different industry for a different reason. None of them is "better memory." Each is a bargain:

| Branch | Buys | Pays |
|---|---|---|
| DDR (desktop/server) | Capacity per dollar, upgradeability | The lowest bandwidth per package of any branch |
| LPDDR (mobile/unified) | Bandwidth per watt, thin integration | Soldered capacity, fixed at purchase, forever |
| GDDR (discrete GPU) | Bandwidth per dollar *on a card* | Capacity capped at card sizes; a second, separate pool |
| HBM (datacentre) | Bandwidth outright — 4–25× the other branches per package | Cost, packaging scarcity, datacentre-only supply |
| SRAM (on-chip) | Latency and bandwidth density beyond any DRAM | ~100× scarcer per die; kilobytes-to-megabytes, never gigabytes |
| CXL-attached DRAM | Capacity beyond the DIMM slots; capacity shared between hosts | 2–3× local-DRAM latency; one PCIe-class link of bandwidth |

**The fleet in one paragraph.** Volmarr's machines span three of these branches simultaneously, which is why this dossier exists: the laptops carry **DDR4/DDR5** system memory beside **GDDR6** on discrete RTX cards (purplelongship, the Zephyrus G14, is the corpus's worked case: RTX 2060 Max-Q, 6 GB VRAM, verified in our records 2026-10-28); the Z13 (purpleraider) collapses the split into one **LPDDR5X** unified pool of 128 GB; and Mimir, the Pi 5, runs **LPDDR4X** at embedded scale. The same model, quantised identically, is a different workload on each — not because the software changes, but because the datasheet underneath it does. §8 works that comparison in full.

**A note on numbers that age.** DRAM figures rot faster than any other numbers in this corpus. Pin rates are revised upward inside a generation's lifetime (DDR5's JEDEC range has already moved from 4800–6400 MT/s at launch to 8800 MT/s in later revisions), vendor parts routinely exceed the JEDEC baseline they are named after (HBM4 is the current case), and prices — §5.4 — moved by multiples during 2025–26 alone. Every table in this dossier is therefore stamped: *figures as published in the sources read 2026-11-15*. A reader in 2027 should re-derive, not re-quote.

---

## 2. The DDR line — the general-purpose branch

### 2.1 What a "generation" changes, and what it does not

DDR (Double Data Rate) SDRAM is the JEDEC-standardised main memory of desktops, laptops, and servers: JESD79-4 for DDR4 (published 2012), JESD79-5 for DDR5 (published July 2020, since revised). Each generation's bargain, across the whole DDR lineage, has been the same: **roughly double the per-pin transfer rate, at slightly lower voltage, at roughly unchanged true latency.** The third clause is the one marketing leaves out, and for LLM work it matters (§2.4).

The DDR4→DDR5 step, from the vendor and JEDEC-summary sources read for this dossier (Kingston's generation comparison; JEDEC-spec summaries in §9):

| Property | DDR4 | DDR5 |
|---|---|---|
| JEDEC standard | JESD79-4 (2012) | JESD79-5 (2020, extended since) |
| Data rates (JEDEC) | 1600–3200 MT/s | 4800 MT/s at launch; standard since extended to 8800 MT/s; Kingston lists retail range to 9200 MT/s |
| Supply voltage | 1.2 V | 1.1 V |
| Module structure | One 64-bit channel per DIMM | Two independent 32-bit sub-channels per DIMM |
| Burst length | 8 | 16 (so one access still delivers a 64-byte cache line per sub-channel pair) |
| On-die ECC | No | Yes (single-bit correction inside the die; *not* a substitute for system ECC) |
| Power management | On the motherboard | PMIC on the module itself |
| Max UDIMM capacity (retail class) | 32 GB | 64 GB (server/3DS constructions go far higher) |
| Compatibility | — | **Not interchangeable**: different keying, voltage, signalling. A generation change is a platform change. |

Two of these rows do real work for inference and deserve plain statements:

- **The sub-channel split does not widen the bus.** A DDR5 DIMM still moves 64 bits of data per transfer, exactly like DDR4. What the split buys is *concurrency*: two independent command/address paths, so the controller can keep more, smaller accesses in flight. Streaming decode barely notices; mixed workloads (prefill kernels interleaved with KV reads) notice somewhat. Anyone who reads "dual channel per DIMM" as doubled bandwidth has been marketed to.
- **On-die ECC is not ECC memory.** It corrects errors *inside* the DRAM die to keep yields viable at DDR5 densities. It does not report errors to the host and does not protect the bus. Server DDR5 with true ECC is a separate product property.

### 2.2 The bandwidth arithmetic — the one formula in this dossier

All theoretical bandwidth in this dossier, for every branch, is the same multiplication:

```
theoretical bandwidth (GB/s) = transfer rate (MT/s, or Gb/s per pin) × bus width (bits) ÷ 8
```

For a standard 64-bit DDR channel, width ÷ 8 = 8 bytes, so per-channel bandwidth is simply `rate × 8`:

| Configuration | Arithmetic | Theoretical bandwidth |
|---|---|---|
| DDR4-3200, one channel | 3,200 × 8 B | **25.6 GB/s** |
| DDR4-3200, dual channel (typical DDR4 laptop/desktop) | 2 × 25.6 | **51.2 GB/s** |
| DDR5-4800, one channel | 4,800 × 8 B | **38.4 GB/s** |
| DDR5-4800, dual channel | 2 × 38.4 | **76.8 GB/s** |
| DDR5-5600, dual channel (mainstream laptop case) | 2 × (5,600 × 8 B) | **89.6 GB/s** |
| DDR5-6400, dual channel | 2 × 51.2 | **102.4 GB/s** |
| DDR5-6400, 8 channels (server socket) | 8 × 51.2 | **409.6 GB/s** |
| DDR5-6400, 12 channels (high-end server socket) | 12 × 51.2 | **614.4 GB/s** |

The fleet's headline case from the commissioning brief checks out exactly: **dual-channel DDR5-5600 = 89.6 GB/s theoretical** (5,600 MT/s × 8 bytes × 2 channels). Hold that number against §3's Z13 figure (256 GB/s) and §5's HBM figures (3,350 GB/s for one accelerator package) and the shape of the whole field is visible: a mainstream laptop's system memory streams at roughly **1/3 of the Z13's unified pool and 1/37 of one H100's HBM**. CPU-only inference on a dual-channel laptop is not slow because laptop CPUs are weak; it is slow because 89.6 theoretical GB/s divided by a 4–5 GB Q4 weight set is a hard ceiling of roughly 18–22 tok/s *before* any inefficiency, and the sustained figure (§2.3) cuts that further.

The server rows matter for §7: even a fully populated 12-channel DDR5 socket tops out near 0.6 TB/s. That is the local-DRAM bandwidth a CXL pool or an HBM accelerator is compared against in datacentre design, and it is why servers buy channels the way GPUs buy stacks — bandwidth is purchased by *multiplying interfaces*, never by wishing a single interface faster.

### 2.3 "Theoretical" and the sustained-bandwidth discount

The formula above is a datasheet ceiling: every pin, every cycle, no refresh, no bank conflicts, no read/write turnaround, perfect scheduling. No real system sustains it. The corpus's method (B5 dossier, after McCalpin's STREAM discipline) is to plan against **sustained** bandwidth — what a long streaming triad actually delivers on the machine in question — and to treat the gap as a property to measure, not a disappointment to hide.

What the evidence in and around this corpus supports, stated as a planning rule [SYNTHESIS of the sources and records cited]:

- **Well-tuned streaming on a healthy memory system typically delivers ~75–85% of theoretical.** The corpus's own anchor: the Z13's LPDDR5X-8000 interface is 256 GB/s theoretical, with ~215 GB/s consistently *reported* in secondary coverage — 215 ÷ 256 ≈ **84%** (unified-memory dossier §2.1; the measurement is still owed on our own machine, and the dossier says so).
- **CPU-side paths can sit far below the interface figure.** Our own MimirAlloc campaign measured the Strix Halo *CPU* path directly: single-CCD plateau 61.8 GB/s, whole-chip peak 112.76 GB/s (B5 dossier §4, from campaign records) — nowhere near 256 GB/s, because a CPU core complex cannot issue enough concurrent requests to saturate the interface the way a GPU can. The same datasheet number is a different ceiling for each requester on the package. This is McCalpin's concurrency point, measured on our own hardware.
- **Therefore: every tok/s prediction in runner work should name which figure it divides by.** "89.6 GB/s" for a DDR5-5600 laptop means ~67–76 GB/s of plannable stream. A decode estimate that divides by the theoretical figure is optimistic by construction, by 15–25%, before the engine's own losses are counted at all.

Refresh is part of the discount and worth naming once: DRAM cells leak and must be periodically re-read and rewritten; DDR5 halved the full-refresh interval at high temperature (32 ms vs DDR4's 64 ms in the standard summaries read), and a read that collides with a refresh window waits. The cost is small in bandwidth percentage and occasionally large in tail latency — one more reason sustained, not peak, is the honest denominator.

### 2.4 Latency: the variable DDR generations do not improve

First-word (CAS) latency in nanoseconds has been essentially flat for three generations, because rising clock rates are cancelled by rising cycle counts:

```
true CAS latency (ns) = CL × 2000 ÷ MT/s
DDR4-3200 CL22 (JEDEC):  22 × 2000 ÷ 3200 ≈ 13.8 ns
DDR5-4800 CL40 (JEDEC):  40 × 2000 ÷ 4800 ≈ 16.7 ns
DDR5-6400 CL52 (JEDEC):  52 × 2000 ÷ 6400 ≈ 16.3 ns
Enthusiast kits (either generation, tighter bins): ≈ 10 ns
```

(Sources: JEDEC-timing tables in the generation comparisons read for this dossier, §9.) Full CPU load-to-use latency — controller, queues, row activation on a miss, the return path — is a different and larger number: the measurement literature sampled in §7 puts local DDR5 at roughly **80–130 ns** depending on idle vs loaded state and platform (Octopus pod measurements ~115 ns P50; Meta production figures ~130 ns idle). Both statements are true at once: the *cell* answers in ~14–17 ns; the *system* delivers in ~80–130 ns.

For LLM inference the consequence is precise:

- **Decode barely cares about DRAM latency.** It streams weights in long, prefetchable bursts; bandwidth is its currency (B5 dossier §3).
- **Prefill's tail, small-batch serving, and KV random access care.** Scattered KV reads, short prompts, and synchronisation-heavy kernels pay latency per dependent access. A DDR5 platform is *not* a lower-latency platform than the DDR4 machine it replaces; it is a wider one. Upgrading a latency-bound workload by changing DDR generation alone buys approximately nothing — a fact worth having before money moves.
- **Latency is bought elsewhere in the hierarchy** — with cache (§6), with concurrency (more requests in flight to hide the wait), or with locality (not making the access at all). No DIMM purchase buys it.

### 2.5 Capacity economics of the DDR line

DDR's enduring virtue is the third variable: it is the cheapest, most upgradeable way to own gigabytes. Socketed DIMMs mean capacity is a *field decision* — a DDR4 laptop in the fleet can be re-provisioned years after purchase; servers scale to terabytes per socket by populating channels (which also buys bandwidth, §2.2 — on servers the two variables are the same purchase). Indicative contract pricing as reported by The Next Platform (read 2026-11-15): around the start of the AI boom (Nov 2022) server DDR4 averaged roughly **$3/GB** and DDR5 roughly **$4/GB**. Those figures are historical anchors, not current quotes — §5.4 documents why 2025–26 pricing cannot be quoted as a stable table at all. The structural point survives any price cycle: **commodity DDR is, per gigabyte, the cheapest DRAM branch by a wide margin, and HBM's premium over it is the price of bandwidth** (§5.4).

For local inference this economics row is decisive in a quiet way: host RAM is where oversized models, CPU-offloaded layers, KV spill tiers, and mmap'd weight files live. Its cheapness is why "the model that does not fit in VRAM" has a home at all — at DDR bandwidth and DDR latency, which is exactly the trade the runner must then price honestly.

---

## 3. LPDDR — the mobile branch that ate the unified machine

### 3.1 The design point: bandwidth per watt, not bandwidth per dollar

LPDDR (Low-Power DDR) is a *separate* JEDEC lineage from desktop DDR (JESD209 family), sharing a surname and a cell technology but not a standard, a package, or a design goal. Its goal is stated in its name and engineered into every choice: **minimum energy per bit moved**, with deep sleep states, aggressive voltage and frequency scaling, and fine-grained channel gating (typical LPDDR5/5X systems split the interface into 16-bit channels that can be powered independently, so a mostly-idle system lights only the width it needs).

The electrical signature, from the comparisons read for this dossier (§9):

- LPDDR5: up to 6,400 MT/s (JESD209-5). LPDDR5X: to **8,533 MT/s** (the "X" revision's raised ceiling; parts are binned below it — the Z13 runs its interface at 8,000 MT/s).
- I/O voltage around **0.5–0.6 V** for LPDDR5X against DDR5's 1.1 V supply. *[Caution, ours: these two numbers are not the same kind of quantity — one is an I/O rail, the other a core supply — and placing them side by side as a direct "half the voltage" claim, as much marketing does, overstates the comparison. The direction is real (LPDDR moves a bit for materially less energy; that is its entire design brief and its measured reputation) but the honest statement is qualitative plus architectural — DVFS, channel gating, sleep states — not a single voltage ratio.]*
- Per-package bandwidth is modest — tens of GB/s per package at these rates (a 64-bit LPDDR5X package at 8,533 MT/s: 8,533 × 8 B ≈ 68.3 GB/s). LPDDR systems reach large totals the server way, by multiplying interfaces: wider buses, more packages in parallel (§3.2).

### 3.2 Why UMA designs chose it — the worked cases

A unified-memory machine needs one memory that a CPU, a GPU, and an NPU can all live behind, inside a laptop or phone power envelope, with no fanfare and no second pool. LPDDR is the only branch that fits that brief: desktop DDR's I/O power and module form factor are wrong for a thin SoC design, GDDR is a GPU peripheral that expects to be *someone else's* memory, and HBM's packaging cost is wrong by an order of magnitude. Apple Silicon and AMD's Strix Halo are the same conclusion reached independently.

The arithmetic, fleet case first:

```
Z13 / Strix Halo — LPDDR5X-8000, 256-bit bus (32 bytes):
  8,000 MT/s × 32 B = 256 GB/s theoretical; ~215 GB/s reported sustained (≈84%)

Apple M4 Max — LPDDR5X-8533, 512-bit bus (64 bytes):
  8,533 MT/s × 64 B = 546 GB/s published

Apple M4 (base) — LPDDR5X, 128-bit class bus:
  120 GB/s published (unified dossier §2.3 ladder)

Pi 5 (Mimir) — LPDDR4X-4267, 32-bit bus (4 bytes):
  4,267 MT/s × 4 B ≈ 17.1 GB/s theoretical
```

Notes on provenance: the Z13 and Apple figures are as documented in the corpus's unified-memory dossier (§2.1, §2.3) and re-verified against secondary coverage in this pass (§9). The Pi 5 figure is *our arithmetic* from the widely documented LPDDR4X-4267 rate and 32-bit interface; secondary guides variously quote ~13.7–17 GB/s for the same board without showing their width assumption — we flag the spread rather than pick silently, and note the board's real constraint is anyway capacity and CPU, not the last GB/s of stream. The Pi 5's memory is shared between its CPU and VideoCore GPU in the same unified pattern, at 1/15 of the Z13's bandwidth: the architecture scales down intact; the numbers do not.

Read the Z13 and M4 Max rows against each other and the LPDDR branch's real trade is visible. Both are "128 GB unified LPDDR5X." The Apple part has **twice the bus width** and therefore ~2.1× the bandwidth (546 vs 256 theoretical) — the unified dossier's bandwidth-per-capacity column (4.27 vs 2.0 GB/s per GB) is the single most informative spec-sheet ratio in this whole area, and §8 elevates it to a rule. LPDDR did not decide between these machines; *how much LPDDR interface each vendor chose to buy* did.

### 3.3 The constraint: soldered means decided

LPDDR's costs are paid in a different currency — permanence:

- **Capacity is a purchase-time constant.** LPDDR ships soldered or in-package. The Z13's 128 GB, the Pi's 4/8/16 GB SKU, an Apple machine's tier — none can be changed afterwards by any upgrade, only by replacing the machine. Every capacity plan for an LPDDR machine is therefore a plan against a *fixed endowment* (the unified dossier's budgeting discipline exists for exactly this reason).
- **Per-GB price is worse than DDR's, and hidden.** LPDDR capacity is bought as part of an SoC/board price, often in vendor-controlled tiers whose step prices bear no resemblance to commodity $/GB. The buyer cannot comparison-shop the memory separately; the capacity decision is bundled, at the moment of maximum ignorance about future model sizes.
- **Latency is not the branch's gift.** LPDDR optimises energy and burst bandwidth; its system latency is comparable to or somewhat worse than desktop DDR's, and its narrow channels favour bursts over scattered access. For decode (streaming) this is the right trade. For latency-sensitive small work it is not a free one.

**Verdict for the branch:** LPDDR is what makes the unified machine *possible* — large, cool, single-pool memory behind every engine at once — and its bandwidth-per-watt is why a 128 GB laptop can run a 70B-class model at reading speed from a battery-class power budget. Its price is that the machine's memory is a sealed fact: the runner's budgeting, not the buyer's screwdriver, is the only capacity tool left.

---

## 4. GDDR — the discrete-GPU branch

### 4.1 The design point: bandwidth per dollar, on someone else's board

GDDR (Graphics DDR) is DRAM specialised for exactly one customer: a GPU on a discrete board, hungry for streaming bandwidth, indifferent to the latency and capacity virtues the other branches prize. Its method is the mirror of HBM's (§5): instead of an extremely wide bus at modest pin rates, GDDR runs a *moderately* wide bus (128–512 bits across the whole card) at *extreme* per-pin rates, using signalling tricks — PAM4 in GDDR6X, PAM3 in GDDR7 — to push more bits per cycle down each wire than plain NRZ allows. The DRAM dies sit on the card's PCB around the GPU; the memory belongs to the card, is invisible to the host except through the GPU, and dies with the card's product tier.

Generations, from the technical comparisons read for this dossier (§9):

| Generation | Signalling | Per-pin rate (shipping parts) | Per-device bandwidth (32-bit device) | Exemplar |
|---|---|---|---|---|
| GDDR6 | NRZ | 14–20 Gb/s | 56–80 GB/s | RTX 2060 (14 Gb/s), RX 7900 XTX (20 Gb/s) |
| GDDR6X | PAM4 | 19–24 Gb/s (21 typical) | 84–96 GB/s | RTX 4090: 21 Gb/s × 384-bit = 1,008 GB/s |
| GDDR7 | PAM3 | 28–32 Gb/s at launch; JEDEC roadmap to 48 Gb/s | 128 GB/s at 32 Gb/s; 192 GB/s at 48 Gb/s (JEDEC figure) | RTX 5090: 28 Gb/s × 512-bit = 1,792 GB/s |

(JESD239 for GDDR7 was published March 2024; GDDR7 cards shipped from January 2025. GDDR6X is a Micron/NVIDIA development, not a JEDEC standard generation — a fact its naming deliberately blurs.)

### 4.2 The fleet case: RTX 2060, with its variants named

The corpus's target card, verified in this pass against the TechPowerUp GPU database and consistent secondary listings (§9):

```
RTX 2060 (reference, TU106) — GDDR6, 192-bit bus, 14 Gb/s per pin:
  14 × 192 ÷ 8 = 336 GB/s theoretical
  Capacity: 6 GB (launch, Jan 2019)
```

**Variant dependence — read before quoting 336 anywhere:**

- **RTX 2060 SUPER**: 256-bit bus, same 14 Gb/s → **448 GB/s**, 8 GB. A different memory system wearing a near-identical name.
- **RTX 2060 12 GB** (Dec 2021): 192-bit, **336 GB/s**, double the capacity at identical bandwidth — a capacity variant, not a speed variant.
- **RTX 2060 Max-Q (purplelongship's card)**: the laptop, power-capped member of the family; our records verify the machine and its **6 GB VRAM** (driver install, 2026-10-28), and the corpus has *not* measured this card's sustained bandwidth — the KV dossier explicitly asserts no tok/s figure for it and prescribes a STREAM-style measurement (still owed). Max-Q parts cap clocks and power below desktop reference; whether a given Max-Q board's *memory* runs at the full 14 Gb/s is board-specific. **336 GB/s is therefore the reference-design ceiling for the family, used in this dossier as the branch exemplar — not a measured property of purplelongship's card.** Any fleet arithmetic that divides by 336 for that machine is dividing by a ceiling, and §2.3's discount applies on top.

Even at its ceiling, the card teaches the branch's lesson cleanly: 336 GB/s is **3.75×** a dual-channel DDR5-5600 laptop's theoretical system bandwidth and **1.3×** the Z13's unified theoretical figure — which is why a 2019 mid-range card out-decodes modern integrated parts *for models that fit* — while its 6 GB capacity is 1/21 of the Z13's pool, which is why so few interesting models fit. GDDR's bargain in one card: real bandwidth, toy capacity, and a hard wall between the two pools (weights in GDDR, everything else in DDR, PCIe between them).

### 4.3 Where the branch is going

GDDR7's launch parts roughly double GDDR6's per-pin rate at *lower* voltage (1.1–1.2 V class, with on-die ECC added) — the RTX 5090's 1,792 GB/s on a consumer card would have been an HBM headline five years ago. The direction of travel is that discrete consumer bandwidth keeps climbing toward 2 TB/s while consumer *capacity* stays pinned at 16–32 GB by product segmentation, not by technology. [SYNTHESIS: for local LLM work this widens the branch's original tension rather than resolving it — the cards get faster at exactly the variable that is already sufficient, and stay scarce at the variable (capacity) that decides which models run at all. The datacentre answer to that tension is §5; the consumer answer, so far, is §3's unified pool.]

---

## 5. HBM — the datacentre branch, and the gap table

### 5.1 The design point: width instead of speed

High Bandwidth Memory inverts GDDR's method. Instead of pushing pin rates to extremes over a narrow bus, HBM stacks DRAM dies vertically (4–16 high, connected by thousands of through-silicon vias), places the stack on a silicon interposer *millimetres* from the accelerator die, and connects them with an interface so wide it stops resembling a bus: **1,024 bits per stack** through HBM3E, **2,048 bits** in HBM4. Pin rates stay comparatively gentle (6.4 Gb/s for HBM3 — slower per pin than a GDDR6 card from 2019), because width does the work:

```
HBM3, per stack:   6.4 Gb/s × 1,024 bits ÷ 8 = 819 GB/s
HBM3E, per stack:  ~9.2–9.6 Gb/s × 1,024 ÷ 8 ≈ 1.18–1.23 TB/s  (vendor parts; >1.2 TB/s class)
HBM4, per stack:   8 Gb/s (JEDEC baseline) × 2,048 ÷ 8 = 2,048 GB/s ≈ 2 TB/s
```

Generations, JEDEC baselines with vendor parts marked (sources §9; JEDEC documents JESD235 lineage for HBM2/2e, JESD238 for HBM3, JESD270-4 for HBM4, published 16 Apr 2025):

| Generation | Interface/stack | Pin rate | Bandwidth/stack | Capacity/stack (typical) | First volume use |
|---|---|---|---|---|---|
| HBM2 | 1,024-bit | ~2.0 Gb/s | ~256 GB/s | 4–8 GB | 2016–17 |
| HBM2e | 1,024-bit | 3.2–3.6 Gb/s | ~410–460 GB/s | 16 GB | 2020 (A100: 5 stacks → 80 GB, 2.0 TB/s package) |
| HBM3 | 1,024-bit | 6.4 Gb/s | **819 GB/s** | 16–24 GB | 2022 (H100) |
| HBM3E | 1,024-bit | 9.2–9.6+ Gb/s [VENDOR] | **~1.2 TB/s** [VENDOR] | 24–36 GB | 2024 (H200, MI300 refreshes) |
| HBM4 | 2,048-bit | 8 Gb/s JEDEC; 10–13 Gb/s [VENDOR parts] | **2 TB/s** JEDEC; >2.8 TB/s [VENDOR] | 36 GB (12-high); to 64 GB (16-high) | 2026 (Rubin-class) |

Per-*package* figures are what a buyer of accelerators actually gets, and they are vendor-published package specifications: **H100 SXM — 80 GB HBM3, 3.35 TB/s; H200 SXM — 141 GB HBM3e, 4.8 TB/s; B200 — 192 GB HBM3e, 8 TB/s** (NVIDIA product specifications as carried in the comparisons read, §9). Note the cleanest natural experiment in this dossier hiding in that list: H100 and H200 are the *same GH100 compute die* with different memory systems, and the H200's memory-bound inference advantage tracks its bandwidth ratio (4.8 ÷ 3.35 ≈ 1.43×) — compute held constant, datasheet changed, tok/s followed. That is §1's essence with a control group.

### 5.2 Why HBM is the wall-breaker

Return to the decode rule with datacentre numbers: a 70B model in FP16 (~140 GB of weights) on an H100's 3.35 TB/s has a single-stream ceiling near 3,350 ÷ 140 ≈ **24 tok/s** (the B5 dossier's worked example, ~20 tok/s with real-world allowance) — slow in absolute terms, and still **an order of magnitude above** what the same weights would do on any non-HBM branch, if they fit at all. At serving batch sizes, where weights are read once per *batch* of tokens, HBM's bandwidth converts directly into aggregate throughput per accelerator, which is the only number a datacentre is paid for. HBM also wins the watt variable at this scale: moving a bit across millimetres of interposer costs far less energy than driving it across a PCB to GDDR or across a board to DDR, so at multi-TB/s rates HBM is the *most* bandwidth-per-watt-efficient branch, not merely the fastest (SemiWiki comparison, §9). The wall did not move; HBM is what it costs to buy one's way further along it than anyone else.

### 5.3 Why it will not reach Volmarr's desk

Three independent reasons, any one sufficient:

1. **It is not a component; it is a co-packaged subsystem.** HBM is bonded onto the accelerator's package (CoWoS-class advanced packaging) at manufacture. There is no HBM DIMM, no HBM card upgrade, no socket. To buy HBM is to buy the accelerator it is attached to, at datacentre-accelerator prices, in datacentre-accelerator form factors and power envelopes (H100/H200 SXM: up to 700 W for the package).
2. **Supply is allocated, not retailed.** The three makers (SK hynix, Samsung, Micron) sell HBM output forward to a handful of accelerator vendors; industry coverage read for this dossier estimates HBM at roughly a quarter of global DRAM wafer starts in 2026, bid for in advance. A consumer product line built on HBM would be queueing behind NVIDIA and AMD for its own memory.
3. **Its economics only close at datacentre utilisation.** §5.4's per-GB premium buys bandwidth that pays for itself only when the accelerator is kept saturated by paying batch workloads around the clock. A personal machine decoding one stream at batch 1 would use HBM's capacity idly and its bandwidth at one stream's worth — the most expensive possible way to read a novel aloud.

[VENDOR CLAIM, flagged as the industry framing rather than our finding: accelerator vendors present HBM capacity growth (80 → 141 → 192 GB per package across three generations) as "democratising" large-model serving. The capacity is real; the democratisation stops at the cloud invoice. For this programme HBM matters as the *reference point* — the number that defines how far below the frontier every local figure sits, and the serving tier that hosted models actually run on — not as a roadmap item.]

### 5.4 Capacity per dollar: HBM's premium, and a warning about pricing tables

The Next Platform's industry analysis (read 2026-11-15, §9) gives the most coherent published per-GB ladder, with its own caveats attached — HBM has no spot market, so all its figures are reported contract estimates:

| Memory | Reported cost/GB | Basis |
|---|---|---|
| DDR4 (server, Nov 2022) | ~$3/GB | Market average at that date |
| DDR5 (server, Nov 2022) | ~$4/GB | Market average at that date |
| HBM2e | ~$10/GB | Reported contract estimate |
| HBM3 | ~$12/GB | Reported contract estimate |
| HBM3E | ~$13.50/GB | Reported contract estimate |
| HBM4 | ~$16/GB (rumoured $560–600 per 36 GB stack) | Rumour-grade; the source itself flags it |

Two structural facts underneath the ladder, both from the industry coverage read:

- **HBM consumes roughly 3× the wafer area per gigabyte of conventional DRAM** (stacking, TSV processing, yield loss across 8–12 dies that must *all* work). Its premium is not profiteering pasted onto identical silicon; it is geometry. The same fact runs in reverse as a market force: every wafer allocated to HBM removes ~3 GB-equivalents of commodity DDR supply, which is the mechanism behind the 2025–26 commodity price spike.
- **That spike voids casual price tables.** Coverage read in this pass (Tom's Hardware price tracking via secondary reporting) describes mainstream DDR5 kits multiplying several-fold during 2025–26 — figures like a 32 GB DDR5-6000 kit moving from ~$108 (summer 2025) to $400–570 (2026) appear in that coverage. We report the *existence and rough scale* of the spike because it changes buying advice, but we do **not** build a $/GB table on retail tracking of a market in that condition: any such table would be stale on arrival and false within a quarter. The durable statement is the *ordering* — DDR < LPDDR (bundled) < GDDR (bundled) < HBM per GB, with HBM at roughly 3–4× commodity DDR on a calm market — plus the date stamp: **all pricing in this section as reported in sources read 2026-11-15, in a historically abnormal market.**

### 5.5 THE GAP TABLE — all branches, one page

*The centrepiece. Theoretical (datasheet) bandwidth unless marked sustained/reported. Figures as published in sources read 2026-11-15; per-configuration arithmetic shown in the sections cited. This table ages — re-derive before re-quoting (§1).*

| System / configuration | Branch | Capacity in play | Bandwidth | Latency class (system) | § |
|---|---|---|---|---|---|
| Pi 5 (Mimir) | LPDDR4X-4267, 32-bit | 4–16 GB (SKU) | **~17 GB/s** theoretical (our arithmetic; guides quote 13.7–17) | DDR-class, ~100 ns | 3.2 |
| Laptop, dual-channel DDR4-3200 | DDR4 | 16–64 GB | **51.2 GB/s** theoretical | ~80–130 ns | 2.2 |
| Laptop, dual-channel DDR5-5600 | DDR5 | 16–64 GB | **89.6 GB/s** theoretical (~67–76 plannable) | ~80–130 ns | 2.2–2.3 |
| Server socket, 12-ch DDR5-6400 | DDR5 | 0.5–3 TB | **614 GB/s** theoretical | ~80–130 ns (local socket) | 2.2 |
| Z13 (purpleraider), LPDDR5X-8000, 256-bit | LPDDR5X unified | 128 GB | **256 GB/s** theoretical; **~215 reported** sustained | DDR-class | 3.2 |
| Apple M4 Max, LPDDR5X-8533, 512-bit | LPDDR5X unified | 128 GB | **546 GB/s** published | DDR-class | 3.2 |
| RTX 2060 (reference), GDDR6 192-bit | GDDR6 | 6 GB | **336 GB/s** theoretical (Max-Q: ceiling, unmeasured) | GPU-local, hidden by batching | 4.2 |
| RTX 4090, GDDR6X 384-bit | GDDR6X | 24 GB | **1,008 GB/s** | GPU-local | 4.1 |
| RTX 5090, GDDR7 512-bit | GDDR7 | 32 GB | **1,792 GB/s** | GPU-local | 4.1 |
| One HBM3 stack | HBM3 | 16–24 GB | **819 GB/s** per stack | Accelerator-local | 5.1 |
| NVIDIA H100 SXM (package) | HBM3 | 80 GB | **3,350 GB/s** | Accelerator-local | 5.1 |
| NVIDIA H200 SXM (package) | HBM3E | 141 GB | **4,800 GB/s** | Accelerator-local | 5.1 |
| NVIDIA B200 (package) | HBM3E | 192 GB | **8,000 GB/s** | Accelerator-local | 5.1 |
| CXL Type-3 expander, ×8 PCIe 5.0 link | DDR5 behind CXL | 128–512 GB per device | **~32 GB/s per direction** link ceiling; devices interleave to more | **~210–270 ns** direct-attached | 7 |
| CXL pool through a switch | DDR5 behind CXL | TBs pooled | Link-bound per host | **~490–600 ns** | 7 |

Read the table by columns and the field's shape is unmistakable:

- **Bandwidth spans ~470×** from the Pi's LPDDR4X to a B200 package — wider than the spread in any other commodity spec in computing. "Runs LLMs" is a meaningless predicate across this range without the row named.
- **Capacity and bandwidth are anti-correlated at the extremes a consumer can buy.** The largest local pool (128 GB unified) streams at 256 GB/s; the fastest local card (1,792 GB/s) holds 32 GB; the 6 GB fleet card sits at 336 GB/s. Every local architecture is a choice of which wall to meet first.
- **Latency barely moves** — one order of magnitude across the entire table (tens of ns on-chip, §6, to ~600 ns through a CXL switch) — while bandwidth moves nearly three orders. The memory wall (B5) is a bandwidth wall in this era; latency is the tax specific tiers pay, not the general condition.

---

## 6. SRAM and the on-chip tier — the tier above the datasheet

Everything above is DRAM: one transistor and one capacitor per bit (1T1C), charge leaking, refresh ticking, density supreme. SRAM is the other cell: a latch of (typically) **six transistors per bit (6T)**, holding its state actively while powered, needing no refresh, answering in a small number of cycles — and occupying, per bit, several times the silicon area of a DRAM cell (textbook worked comparisons put the cell-area ratio at roughly 6×; §9). That single ratio explains the entire on-chip tier:

- **Why on-chip memory is ~100× scarcer.** A processor die has a fixed area budget contested by cores, accelerators, and interconnect. DRAM-scale capacity in SRAM cells is geometrically absurd — gigabytes of SRAM would be a wafer-sized, unpayable die — so on-chip SRAM exists in megabytes: kilobytes of register file per core/SM, tens of KB of L1, hundreds of KB to a few MB of L2, tens of MB of shared L3/LLC on CPUs; on GPUs, per-SM shared memory/L1 in the hundreds of KB and L2 in the tens of MB (the fleet's RTX 2060: 3 MB L2, per its database entry, §9). *[The "~100×" is an order-of-magnitude characterisation of SRAM-vs-DRAM capacity per die/package at comparable cost — flagged as such, not a measured constant.]*
- **What the scarcity buys.** Latency in the ~1–20 ns class across the cache levels (order-of-magnitude textbook figures; exact values are design-specific) against DRAM's 80–130 ns system latency, and aggregate bandwidth that scales with the number of banks and ports rather than with a pin count — an L1 can serve a load per cycle per core, a rate no off-chip technology approaches per requester.
- **Register files are the zeroth tier**: the operands the ALUs literally read, sub-cycle, sized in kilobytes, managed by the compiler and the rename hardware — the only "memory" whose allocation is decided per-instruction.

**The link to LLM work is direct, and mostly negative-space:** every technique that keeps a byte out of DRAM for one more use is spending SRAM economics against DRAM economics. FlashAttention's tiling exists to keep attention tiles in on-chip SRAM rather than round-tripping HBM; kernel fusion exists to keep intermediates in registers instead of writing them to VRAM and back; KV-cache *layout* work (§A1 dossier) is partly about making DRAM reads behave like streams so the small SRAM tier can prefetch across the latency gap. And the NPU design point — SRAM-centric dataflow machines that refuse to treat DRAM as a working surface at all, tiling the whole computation through on-chip buffers (the corpus's D1–D4 topics: Eyeriss-lineage dataflows, Hailo as the public case) — is the logical extreme of this section: when energy per DRAM access dwarfs energy per operation, the architecture is designed *around* the datasheet layer this dossier describes. That dataflow dossier is a separate flagged gap in the field map; this section is deliberately only the bridge to it.

**One-line summary of the tier:** DRAM is where bytes *live*; SRAM is where bytes are *used*; the entire art of fast inference kernels is minimising the rent paid moving between the two.

---

## 7. CXL — DRAM at the end of a fabric

### 7.1 What CXL is, precisely

Compute Express Link is **not a memory technology**. It is an interconnect — defined by the CXL Consortium, running on the PCIe physical layer — that gives attached devices *memory semantics*: cache-coherent load/store access, the thing PCIe alone never offered. Three sub-protocols, composable per device (Consortium material and the Lenovo/CXL technical introductions read for this dossier, §9):

- **CXL.io** — PCIe-like discovery, configuration, DMA. Every device speaks it.
- **CXL.cache** — a device may coherently cache *host* memory.
- **CXL.mem** — the host may map *device* memory into its own physical address space (as Host-managed Device Memory, HDM) and reach it with ordinary loads and stores, in 64-byte cacheline transactions, under defined coherence rules.

Device types follow from the combination: **Type 1** (accelerators without local memory: .io + .cache), **Type 2** (accelerators with memory, e.g. GPUs: all three), **Type 3** (memory expanders: .io + .mem) — a controller plus commodity DRAM (DDR4 or DDR5 in shipping parts) in a PCIe-card or E3.S form factor, presenting its DRAM to the host as a CPU-less NUMA node. Type 3 is the type this dossier cares about: it is §2's DDR, relocated behind a link.

### 7.2 The generations: expansion, then pooling, then sharing

| Version | PHY | Rate | What it actually added |
|---|---|---|---|
| CXL 1.1 (2019) | PCIe 5.0 | 32 GT/s | Point-to-point attach: one host, its expanders. **Capacity expansion only.** |
| CXL 2.0 (Nov 2020) | PCIe 5.0 | 32 GT/s | Switching; a pool of Type-3 devices behind a switch, **sliced dynamically between hosts (pooling)** — each host owns its slice exclusively; single-level switch, up to 16 hosts. |
| CXL 3.0 (Aug 2022) | PCIe 6.0 | 64 GT/s, PAM4 | Fabrics: multi-level switching, port-based routing, peer-to-peer, and **sharing** — multiple hosts mapping the *same* region coherently, via back-invalidate coherency. Consortium: doubled rate "with no added latency over CXL 2.0," full backward compatibility. |
| CXL 3.1 (Nov 2023) / 3.2 | PCIe 6.0 | 64 GT/s | Fabric management, security (TEE), hot-page monitoring (3.2's CHMU) — the operations layer for pools. |
| CXL 4.0 (Nov 2025) | PCIe 7.0 | 128 GT/s | Specification published (per the GA buyer's guide read, §9); **no silicon** at the time of that guide. |

The verbs matter and are routinely conflated in marketing, so, plainly: **expansion** = more memory for one host (1.1, shipping). **Pooling** = one body of memory, exclusively re-sliced between hosts over time (2.0, shipping in server products). **Sharing** = several hosts coherently reading/writing the *same* bytes at once (3.0, specified; in the sources read, still prototype/early-silicon territory, with the Octopus authors noting its back-invalidate mechanism "requires significant hardware changes on both processors and devices"). A claim about "CXL shared memory" that does not name its verb and version is not yet a claim.

### 7.3 The price: latency and link bandwidth, measured

CXL memory is DRAM, so its *cell* latency is §2.4's. Everything the link adds is transport: serialisation, protocol, controller, and — through a switch — re-serialisation per hop. The most complete public measurements found in this pass (Octopus, NSDI '26, Microsoft Azure/Columbia, on real silicon; Meta production figures as reported alongside; §9):

| Path | P50 load-to-use latency (random 64 B reads) |
|---|---|
| Local DDR5 | ~115 ns (Octopus testbed); ~130 ns idle (Meta production) |
| CXL expander, direct-attached (ASIC Type-3) | **~210–270 ns** |
| CXL multi-port device (pooling without a switch) | ~260–300 ns |
| CXL through a switch | **~490–600 ns** (switch itself ≥ ~220 ns of it) |
| Same data via RDMA from another server | ~3,550 ns |

Under load the gap persists proportionally (Meta: 234 ns local vs 372 ns CXL-attached at 60% bandwidth utilisation, as reported). Independent summaries of the same literature converge on the rule of thumb the commissioning brief stated: **direct-attached CXL ≈ 2–3× local-DRAM latency** (170–300 ns class against 80–130 ns local). Verified — with one correction to the folklore: the *best-case* vendor/guide figure of "only ~70 ns added over local DRAM" (§9, buyer's guide) describes favourable direct-attach conditions and should be read as a floor, not a planning number; the measured pod figures above are what a system designer should budget. Both are in this dossier because both are in the literature, labelled as what they are.

Bandwidth is the second price, and it is a *link* price: a ×8 PCIe 5.0 CXL link carries ~32 GB/s per direction, ×16 ~64 GB/s — i.e. **one CXL device ≈ one DDR channel's worth of bandwidth**, against a local socket's 300–600 GB/s (§2.2). A composable-appliance study measured its shared CXL tier at **27–28 GB/s** reads in practice (§7.4). Multiple expanders interleaved can add aggregate bandwidth (and vendor expansion claims of "+30% system bandwidth" exist — [VENDOR CLAIM], configuration-specific), but the default mental model must be: **CXL sells capacity by the terabyte and bandwidth by the channel.** Nobody sane puts hot decode weights behind it.

### 7.4 Where it plausibly matters for LLM serving — the published experiment direction

The literature's centre of gravity is consistent, and it is *not* weight storage. It is the KV cache — the one large, growing, reuse-rich, latency-tolerant-enough byte class in serving:

1. **KV as a capacity tier (offload).** Long-context, high-concurrency serving generates KV far beyond HBM capacity (§A1 dossier's arithmetic: a 100K-token request on a 405B-class model can carry ~48 GiB of KV; a fleet of such requests is terabytes). CXL Type-3 capacity — CPU-addressable, ~250 ns, tens of GB/s — sits exactly between local DRAM (scarce per host) and NVMe (µs-class, block semantics) for this job. The real-hardware evaluation read in this pass (three genuine CXL cards, arXiv:2405.14209) adds the necessary cold water: using CXL memory for *tensor offloading* (GPU↔CPU traffic) brought **limited improvement, bottlenecked by the PCIe path between CPU and GPU**, while using its *capacity* to enable **larger batch sizes did raise inference throughput**. Capacity yes; data-path shortcut no. That distinction is the whole engineering content of this subsection.
2. **KV as a *shared* tier (prefix reuse across hosts).** A feasibility study on a 512 GiB composable CXL appliance (Seagate appliance, vLLM/llm-d connector, Qwen2.5-7B-Instruct, two nodes; arXiv preprint, §9) mapped one CXL region into several hosts as a shared KV tier: cross-node prefix reuse cut time-to-first-token **5.5–36.6×** at 95.4–99.5% external hit rates, with cross-node reuse only 1–4% slower than same-node reuse on that testbed; measured tier latency 461–507 ns at 27–28 GB/s — ~4.5× local-DRAM latency, and ~2.4× *lower* latency than the 100 GbE RoCE alternative. The authors label it a feasibility study, not a performance evaluation; we carry it at exactly that grade.
3. **KV racks and hybrid devices.** SK hynix's HyMCache line (CXL-attached hybrid memory: a little device DRAM in front of large SSD-backed capacity, exploiting KV's read-dominant, append-only, prefix-predictable access) reports, in the authors' evaluation, **3.0× over a local LMCache baseline at equal DRAM budget** in single-node serving (preprint, §9) — a claim about *cost per reusable token*, not raw speed: DRAM-scale reuse behaviour at SSD-scale capacity prices. TraCT (SK hynix, via secondary coverage) applies CXL shared memory to prefill/decode disaggregation, attacking KV *transfer* between workers rather than recompute. Both are the same bet: in multi-turn, agentic, RAG-heavy serving, **yesterday's KV is an asset class, and assets want a cheap, shared warehouse** — which is a capacity-and-sharing problem, CXL's exact shape.
4. **What is *not* in the literature** (absence noted honestly): no source read shows CXL memory serving *live decode weight traffic* competitively, no consumer or workstation CXL memory product, and no evidence that CXL changes single-host, single-stream inference — Volmarr's regime — at all. [SPECULATION, marked: if CXL reaches small machines this decade, the plausible first form is a workstation/server capacity expander for KV-heavy local *serving* (many concurrent sessions), not a laptop technology; nothing in the 2026 product record points at laptops.]

### 7.5 Honest status, late 2026

- **Shipping:** CXL 1.1/2.0 Type-3 expansion on current server platforms (Intel Xeon 6, AMD EPYC 9005 hosts in volume per the pooling guide read, §9); GA expander modules from multiple vendors (e.g. Micron CZ120, 128/256 GB, E3.S, CXL 2.0; Samsung CMM family and its pooling box); pooling appliances at hyperscalers, with production latency numbers (Meta's, above) to prove it.
- **Specified, not deployed:** CXL 3.x fabrics and true coherent sharing; 4.0 on paper only.
- **Absent:** consumer desktops and laptops. No platform in any source read exposes CXL memory expansion outside the server lines; the fleet in §8 has no CXL anywhere in it, and no upgrade path adds any.
- **The one-sentence verdict:** CXL is DRAM's answer to a *datacentre accounting* problem — memory stranded, idle, on the wrong host — and it is a good answer at ~2–3× latency for capacity-class bytes (KV above all). It is not a bandwidth technology, not a consumer technology, and not a 2026 purchasing consideration for this programme. Its design lesson (§8) is portable even though its hardware is not.

---

## 8. Applicability — reading any spec sheet like an inference engineer

### 8.1 The three-variable discipline (the portable skill)

Any hardware page — a laptop listing, a GPU box, a cloud instance menu — can be reduced, in under a minute, to the three variables of §1. The procedure, in order:

1. **Find the memory, not the processor.** Identify branch (§§2–5), bus width, and pin rate; compute theoretical bandwidth yourself (`rate × width ÷ 8`). If the vendor prints a bandwidth, check it against your multiplication — the disagreements are informative (binned parts, Max-Q-style caps, "up to" configurations).
2. **Apply the sustained discount.** Plan at ~75–85% of theoretical for GPU/SoC streaming paths; expect CPU-only paths to deliver far less (§2.3's 112.76 GB/s measured CPU peak on a 256 GB/s interface is the standing warning). A number without a discount is a ceiling being mistaken for a floor.
3. **Compute bandwidth per GB of capacity** for any unified or accelerator part (`bandwidth ÷ capacity`). This single ratio predicts relative decode speed between two machines that "both fit the model" better than any headline figure — 546 ÷ 128 = 4.27 (M4 Max) vs 256 ÷ 128 = 2.0 (Strix Halo) is the whole Apple-vs-Z13 story in one division.
4. **Price capacity as a wall, bandwidth as a slope.** First: do weights + KV at target context + runtime reserve fit the pool, with the platform's usable fraction (not the sticker) as the denominator? If not, no bandwidth figure matters. If yes: ceiling tok/s ≈ sustained bandwidth ÷ (weight bytes + KV bytes read per step at that context). Both steps are arithmetic, not benchmarking.
5. **Ask which latency class the workload's *scattered* accesses pay.** Streaming decode: irrelevant. Prefill tails, small batches, KV random access, tiered storage: read the latency column, and treat any tier above ~300 ns as a *store* (things are fetched from it in bulk, ahead of need) rather than a *working surface*.

Worked micro-example, fleet numbers throughout: a Q4 8B model (~4.9 GB weights) decodes, ceiling-wise, at ~215 ÷ 4.9 ≈ **44 tok/s** on the Z13's *reported sustained* unified bandwidth; at ≤336 ÷ 4.9 ≈ **69 tok/s** on the RTX 2060 *if it fit and if the card sustained its reference rate* — it does not fit with useful KV beside it (KV dossier §7.2: 614 MiB of KV room after weights and reserve), which is why the "slower" machine is the one that can actually hold the conversation. Ceiling arithmetic, honestly discounted and capacity-checked, predicts the fleet's real behaviour better than any review benchmark.

### 8.2 For Ollama and Aesir hardware reasoning

- **Model placement is datasheet placement.** Every placement decision in a runner — GPU-resident vs CPU-offloaded layers, KV precision and location, mmap vs load — is a choice between rows of the §5.5 table. The runner should *know* its rows: enumerate pools at startup with (branch, capacity, measured-or-estimated sustained bandwidth, latency class) and budget against that table, rather than discovering tiers by OOM. The unified dossier's law generalises: *never hard-code which tier a byte class belongs to; let the ledger decide* — CXL (§7) is simply the tier that makes the generalisation non-optional in datacentre design, and the habit is free to adopt locally now.
- **Quantisation is a bandwidth purchase.** Cutting bytes/token is the only lever that raises the decode ceiling on fixed hardware (§B5); priced in this dossier's terms, moving FP16→Q4 is equivalent to bolting a ~3–4× wider memory bus onto the machine. Aesir's compression school should be graded in exactly that currency: bytes saved per token, against the dequant cost — a datasheet intervention, not a file-format preference.
- **Measure the fleet's missing numbers.** This dossier inherits two explicit debts from the corpus and adds a third: (i) STREAM-class sustained bandwidth for purpleraider's GPU path (256 theoretical / ~215 reported / *unmeasured by us*); (ii) sustained bandwidth of purplelongship's RTX 2060 Max-Q (336 is a family ceiling, §4.2); (iii) Mimir's delivered LPDDR4X stream (§3.2's 13.7–17 GB/s source spread). Until those are measured, every fleet tok/s discussion should carry its denominators labelled *theoretical*, *reported*, or *measured* — the discipline of §2.3 applied to ourselves.
- **Do not plan on CXL, LPDDR upgrades, or HBM.** §7.5 and §3.3: the fleet's memory futures are fixed at purchase (LPDDR machines) or card-bound (GDDR machines). The only capacity roadmap available to this programme is *software*: KV compression, prefix reuse, tiering to disk — the A-dossiers' subjects. CXL's contribution to Aesir is architectural (tier-agnostic byte-class ledgers), not procurement.

### 8.3 Why the fleet spans three branches — and what it teaches

Volmarr's fleet is an accidental teaching collection:

| Machine | Memory architecture | First wall | Decode character |
|---|---|---|---|
| purplelongship (Zephyrus G14) | DDR system RAM **+ separate** GDDR6 pool (RTX 2060 Max-Q, 6 GB) | **Capacity** (6 GB VRAM) | Fast per byte (≤336 GB/s ceiling), tiny room; spill over PCIe collapses the slope |
| purpleraider (ROG Flow Z13) | One LPDDR5X pool (128 GB, 256 GB/s theoretical) shared by CPU+GPU+NPU | **Safety/budget** (the pool is the whole machine — unified dossier) | Moderate per byte (~215 reported), enormous room; models fit that cannot run elsewhere locally |
| Mimir (Pi 5) | One LPDDR4X pool (≤16 GB, ~17 GB/s theoretical) | **Both, immediately** | Small models only, at rates set by a phone-class datasheet |

The lesson the three machines teach together — the sentence this dossier exists to make quotable:

> **The split-pool machine (G14) and the unified machine (Z13) fail in opposite directions, and the failure direction is chosen by the DRAM branch, not by the software.** GDDR+DDR gives bandwidth with a capacity cliff and a bus between the pools; LPDDR unified gives capacity with a bandwidth ceiling and a shared-fate pool. A runner designed on one machine and merely *ported* to the other imports the wrong instincts: on the G14 the sin is wasting VRAM bytes; on the Z13 the sin is wasting *bandwidth* bytes and under-budgeting the shared pool. Ollama's and Aesir's hardware reasoning must therefore be parameterised by the §5.5 row the machine occupies — branch, capacity, sustained bandwidth, latency class — and any design claim that does not state its row is a claim about one machine, travelling under a false passport.

---

## 9. Sources

*All sources accessed 2026-11-15. "Read" = opened and read in this pass; "via search results" = figures taken from the source's indexed text as returned in search, not a full read. Vendor figures are the vendor's own published specifications as carried by the cited source. Per-GB pricing sources carry their own caveats, reproduced in §5.4.*

**DDR generations (§2)**
1. Kingston, "DDR4 vs DDR5 DRAM: The Differences in Performance, Compatibility, and Platform Support" — read in full. Source of: DDR4 2133–3200 MT/s, DDR5 4800–9200 MT/s ranges; voltages 1.2/1.1 V; sub-channel split; BL8→BL16; on-die ECC; PMIC move; DDR5-6400 = 51.2 GB/s single-channel, 102.4 dual. https://www.kingston.com/en/blog/pc-performance/ddr-memory-generation-differences
2. JEDEC-spec generation summaries (JESD79-4 / JESD79-5; data-rate extensions to 8800 MT/s; CAS-latency tables DDR4-3200 CL22 ≈ 13.75 ns, DDR5-4800 CL40 ≈ 16.7 ns, DDR5-5600 CL46 ≈ 16.4 ns, DDR5-6400 CL52 ≈ 16.3 ns; per-64-bit-channel bandwidth table 25.6/38.4/44.8/51.2 GB/s) — via search results: Things Embedded DDR4-vs-DDR5 white paper, https://things-embedded.com/us/white-paper/ddr4-vs-ddr5-industrial-computing/ ; Ampheo DDR generation comparison, https://www.ampheo.com/blog/what-is-the-difference-between-ddr3-ddr4-and-ddr5 ; AesTechno comparison, https://www.aestechno.com/en/ddr4-vs-ddr5-comparison/
3. DDR5 SDRAM, Wikipedia (standard history, ~14 ns latency parity note, refresh-interval change) — via search results. https://en.wikipedia.org/wiki/DDR5_SDRAM

**LPDDR (§3)**
4. Corpus-internal: `memory/unified-memory.md` §§2.1–2.3 (Strix Halo 256-bit LPDDR5X-8000 = 256 GB/s theoretical, ~215 GB/s reported; Apple ladder M4 120 / M4 Pro 273 / M4 Max 546 GB/s) — read from the corpus in this pass; its own sourcing is secondary coverage, graded there.
5. LPDDR5X-vs-DDR5 comparisons (LPDDR5 6,400 MT/s; LPDDR5X to 8,533 MT/s; I/O voltage 0.5–0.6 V; per-package ~68 GB/s at 8533/64-bit; channel-gating and DVFS design points) — via search results: GeeKomPC comparison, https://www.geekompc.com/lpddr5x-vs-ddr5/ ; NTChip LPDDR guide, https://www.ntchip.com/electronics-news/lpddrx-memory-guide ; SemiWiki "DDR vs LPDDR vs HBM" wiki (bandwidth-per-package and energy-per-bit characterisations; HBM bandwidth/W note in §5.2), https://semiwiki.com/wikis/semiconductor-ip-wikis/ddr-vs-lpddr-vs-hbm-wiki/
6. Apple M4 Max 546 GB/s / 512-bit LPDDR5X-8533 / 128 GB — via search results, multiple consistent secondary sources, e.g. https://awesomeagents.ai/hardware/apple-m4-max/ and the Strix-Halo-vs-M4-Max comparison (also carrying Strix ~215–228 GB/s measured range), https://www.techdaur.com/blog/amd-ryzen-ai-max-395-strix-halo-128gb-vs-apple-m4-max-local-llm-benchmark
7. Raspberry Pi 5 memory (LPDDR4X-4267 SDRAM, 4/8 GB at launch, later 16 GB SKU; 32-bit interface) — via search results: Raspberry Pi 5 hardware overviews, e.g. https://circuitlabs.net/raspberry-pi-5-hardware-overview-soc-and-memory/ ; bandwidth quotes of 13.7 GB/s and ~17 GB/s both appear in secondary guides (discrepancy flagged in §3.2).

**GDDR (§4)**
8. GDDR6/GDDR6X/GDDR7 technical comparison (GDDR6 14–20 Gb/s; GDDR6X PAM4 19–24 Gb/s; GDDR7 PAM3, JESD239 Mar 2024, 32 Gb/s launch to 48 Gb/s roadmap, 128–192 GB/s per device; RTX 4090 21 Gb/s × 384-bit = 1,008 GB/s) — via search results: Wevolver, https://www.wevolver.com/article/gddr6-vs-gddr7-a-technical-comparison-of-graphics-memory ; GDDR7 explainers, https://rottenwifi.com/what-is-gddr7-memory-everything-you-need-to-know-about-the-new-graphics-vram-technology/
9. RTX 5090: 32 GB GDDR7, 512-bit, 28 Gb/s, 1,792 GB/s (NVIDIA specifications as carried) — via search results, e.g. https://jarvislabs.ai/ai-faqs/nvidia-rtx-5090-specs
10. RTX 2060 family (TU106 reference: 6 GB GDDR6, 192-bit, 14 Gb/s effective, 336.0 GB/s; 12 GB variant same bus/bandwidth; TU104 variant entry) — via search results: TechPowerUp GPU Database, https://www.techpowerup.com/gpu-specs/geforce-rtx-2060.c3310 and https://www.techpowerup.com/gpu-specs/geforce-rtx-2060-12-gb.c3836 ; RTX 2060 SUPER 256-bit / 448 GB/s comparison via https://cputronic.com/en/gpu/nvidia-geforce-rtx-2060-12-gb . Fleet fact (purplelongship = RTX 2060 Max-Q, 6 GB VRAM, verified 2026-10-28; sustained bandwidth unmeasured) — corpus-internal: `memory/kv-cache-design.md` §7.2 and its source list.

**HBM (§5)**
11. HBM generation tables (HBM2 ~256 GB/s; HBM2e ~410–460; HBM3 819 GB/s at 6.4 Gb/s × 1,024-bit, JESD238; HBM3E ~1.2 TB/s [vendor]; HBM4 2 TB/s at 8 Gb/s × 2,048-bit, JESD270-4, 16 Apr 2025; vendor HBM4 parts >2.8 TB/s) — via search results: The Model Press HBM explainer, https://themodelpress.com/explainers/hbm-memory ; IONOS HBM explainer, https://www.ionos.com/digitalguide/server/know-how/high-bandwidth-memory-hbm/ ; SignalStack HBM overview (JEDEC press-release figures), https://www.signalstack.news/blog/what-is-hbm-high-bandwidth-memory/
12. Accelerator packages (A100 80 GB HBM2e 2.0 TB/s; H100 SXM 80 GB HBM3 3.35 TB/s; H200 SXM 141 GB HBM3e 4.8 TB/s; B200 192 GB HBM3e 8 TB/s — NVIDIA specifications as carried) — via search results: E2E Networks comparison, https://www.e2enetworks.com/blog/nvidia-a100-vs-h100-vs-h200-gpu-comparison ; Spheron H100-vs-H200, https://www.spheron.network/blog/nvidia-h100-vs-h200/
13. Pricing and wafer economics (DDR4 ~$3/GB, DDR5 ~$4/GB Nov 2022; HBM2e ~$10, HBM3 ~$12, HBM3E ~$13.50, HBM4 ~$16/GB rumoured; ~3× wafer area per HBM GB) — via search results: The Next Platform, "Memory Is The Lynchpin Of The IT Industry," https://www.nextplatform.com/store/2026/10/08/memory-is-the-lynchpin-of-the-it-industry-and-doubly-so-for-ai/5301841 ; 2025–26 retail spike scale via TechTimes/Tom's Hardware tracking summary, https://Www.techtimes.com/articles/324825/20260818/ai-wiped-out-two-decades-falling-ram-prices-full-ddr5-table-builders.htm (used only for the spike's existence/scale, per §5.4).

**SRAM (§6)**
14. SRAM-vs-DRAM cell economics (6T vs 1T1C; density, cost/bit, refresh; cache/register roles; ~1/6 cell-area worked comparison) — via search results: DiffStudy, https://diffstudy.com/sram-vs-dram/ ; ChipBuddy CMOS VLSI ch. 10, https://www.chipbuddyvlsi.com/vol1/10/ ; Onzuu comparison, https://www.onzuu.com/blog/dram-vs-sram-what-is-the-difference

**CXL (§7)**
15. CXL Consortium, "CXL Consortium releases Compute Express Link 3.0 specification" (press release, 2 Aug 2022: fabric capabilities, enhanced pooling/sharing, 64 GT/s, no added latency over 2.0, backward compatibility) — read in full. https://computeexpresslink.org/wp-content/uploads/2023/12/CXL_3.0-Specification-Release_FINAL.pdf?ref=vlsi.kr
16. Protocol/device-type and version summaries (CXL.io/.cache/.mem; Type 1/2/3; 1.1 expansion, 2.0 switching/pooling, 3.x fabrics; PCIe 5.0 32 GT/s → ×16 ≈ 64 GB/s per direction; EDSFF form factors) — via search results: Lenovo Press LP2146, "Introduction to CXL 2.0 Memory," https://lenovopress.lenovo.com/lp2146.pdf ; AMI CXL deep dive, https://www.aminext.blog/en/post/cxl-compute-express-link-deep-dive-1
17. Latency measurements (local DDR5 ~115 ns P50; CXL expander 230–270 ns; multi-port 260–300 ns; via switch 490–600 ns, switch ≥ ~220 ns; RDMA ~3,550 ns; Meta ~130 ns idle local vs ~250 ns CXL DDR4, 234 vs 372 ns loaded; Samsung switch pool 596 ns / ~60 GB/s as disclosed) — via search results: BuySellRam CXL explainer summarising the Octopus (NSDI '26) and Meta figures, https://www.buysellram.com/blog/cxl-memory-explained-can-servers-finally-share-ram/ ; InsideDeepTech CXL pooling guide (ASIC expander range 210–270 ns vs 80–130 ns local DDR5; Xeon 6 / EPYC 9005 CXL 2.0 volume status; 3.1/3.2/4.0 spec status), https://www.insidedeeptech.com/cxl-memory-pooling-full-guide/
18. Best-case latency claim ("~70 ns added over local DRAM," Type-3/KV-cache positioning; GA device list incl. Micron CZ120) — via search results: Steve Scargall, CXL Device & Fabric Buyer's Guide (updated 2 Jun 2026), https://stevescargall.com/blog/2025/06/cxl-device-fabric-buyers-guide-a-list-of-ga-components/ — carried as the floor-figure source, contrasted with [17] in §7.3.
19. LLM-on-CXL evaluations: (a) real-card characterisation (three genuine CXL cards; tensor offloading limited by CPU↔GPU PCIe path; capacity-enabled larger batches raised inference throughput) — arXiv:2405.14209, via search results, https://arxiv.org/html/2405.14209v3 ; (b) composable shared-KV feasibility study (512 GiB appliance; Qwen2.5-7B-Instruct; TTFT 5.5–36.6× at 95.4–99.5% hit; 461–507 ns, 27–28 GB/s; authors' feasibility framing) — arXiv preprint via search results, https://arxiv.org/pdf/2609.10790.pdf ; (c) HyMCache CXL memory rack (CXL-hybrid DRAM+SSD device; 3.0× vs local LMCache at equal DRAM budget, single-node, authors' evaluation) — arXiv preprint via search results, https://arxiv.org/html/2607.18141v3 ; (d) TraCT and KV-tier framing via secondary summary, https://www.kad8.com/hardware/cxl-workloads-kv-cache-memory-pooling-and-tiering/ (also the source of the 170–300 ns ≈ 2–3× rule-of-thumb cross-check and the 405B KV illustration).

**Corpus-internal sources**
20. `memory/memory-wall-and-roofline.md` (B5: decode ceiling rule; STREAM/sustained discipline; Strix Halo CPU-path measurements 61.8 / 112.76 GB/s from MimirAlloc campaign records; H100 70B FP16 worked example) and `memory/MEMORY-COMPENDIUM.md` ch. 10 (B6/B8 gap statement this dossier fills) — read in this pass.

### What could not be verified in this pass

- **No primary JEDEC documents were read.** JEDEC standards are paywalled/registration-gated; all JEDEC figures here arrive via vendor summaries and technical coverage that cite the standards (JESD79-4/-5, JESD209-5, JESD238, JESD270-4, JESD239). The arithmetic cross-checks (rate × width) all reconcile, which raises confidence, but a figure that appears in exactly one secondary chain — notably HBM4 *vendor* parts above 2.8 TB/s/stack and LPDDR6 anything — should be treated as provisional. LPDDR6 was deliberately left undescribed beyond its existence in roadmaps: no verifiable figures were found in the sources read.
- **No AMD primary sustained-bandwidth figure for Strix Halo exists in the sources read** (carried from the unified dossier's finding): 215 GB/s is consistent secondary reporting, not a measurement by AMD or by us.
- **Purplelongship's RTX 2060 Max-Q sustained bandwidth remains unmeasured** (debt restated in §8.2); 336 GB/s is the reference family's ceiling.
- **Pi 5 delivered bandwidth** could not be pinned beyond the 13.7–17 GB/s secondary spread (§3.2).
- **CXL latency figures rest substantially on one measurement programme** (Octopus) plus Meta's figures as relayed by secondary explainers; the primary papers were reached via search-result text, not full reads. The 2–3× rule is corroborated by multiple independent summaries, but per-device variance across the three-vendor card study is real and is flattened in §7.3's ranges.
- **All pricing** is as-reported in a historically abnormal market (§5.4); HBM contract figures are estimates by construction, there being no public HBM market.
