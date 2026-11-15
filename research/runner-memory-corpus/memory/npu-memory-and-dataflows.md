# NPU Memory and Dataflow Architectures — When SRAM, Not DRAM, Is the Centre of the Design

**Dossier OR-6 (Memory Domain), Topics D1–D4 — Ollama Research Forge**
**Commissioned by:** Volmarr Wyrd, 2026-11-15
**Date of research:** 2026-11-15 (all web sources accessed 2026-11-15; see §8)
**Status:** The D-side dossier the MEMORY-COMPENDIUM Chapter 10 asked for. Chapter 10 (§10.1) records the gap plainly: the field map's D1–D3 — SRAM-centric design and the weight-stationary / output-stationary / row-stationary dataflows in the Eyeriss lineage — were *named* in the field map but had no banked dossier, and D4 (Hailo as the public case) existed only as campaign records mined as our own work. This dossier states the general theory once, properly, from the public literature, and then works Hailo as the public case against it.
**Readers:** Yrsa engineering (a) Project Aesir, whose standing law is accelerator-first — NPU, then GPU, then CPU, work divided for maximum speed — and (b) the improved Ollama in Go. A secondary reader is anyone in the programme who has to decide what an NPU can and cannot be asked to do for a language model, and why.
**Companion dossiers in this corpus:** `memory/memory-wall-and-roofline.md` (the wall this dossier is the architectural answer to), `memory/gpu-memory-internals.md` (the GPU side of the same problem — driver extents, caching allocators, tiling), `memory/unified-memory.md` (B7 — the halfway house: one DRAM pool shared by CPU/GPU/NPU), `memory/kv-cache-design.md` (A1 — the workload whose decode shape §4.4 reasons about), `runners/openvino-genai.md` and `runners/onnx-runtime-genai.md` (the two runner stacks whose NPU regimes §6 connects), `memory/mimiralloc-our-own-proven-work.md` (the allocator §7.3 contrasts against).
**Clean-room note:** Written in our own words from the public sources in §8. No passages are copied beyond short factual labels (architecture names, dataflow names, API and file-format names are facts, quoted as names). Judgements beyond a cited source are marked **[Reasoning]** or **[Engineering judgement]**. Vendor claims are marked as vendor claims. One short section (§5.4) is explicitly our own programme record, marked as such, and kept at the level of lessons. Speculation is marked **[SPECULATION]**.

---

## 1. Header + Essence: Two Different Questions

A GPU and an NPU are both, at bottom, arrays of multiply-accumulate (MAC) units fed by memory. They differ in the question their designers asked first.

**The GPU asks: how do I feed the ALUs from DRAM fast enough?** Its memory system is therefore a *delivery* system: a deep hierarchy of caches, a wide and expensive external interface (GDDR or HBM), coalescing rules, occupancy tricks to hide latency — all of it machinery for moving bytes from a large, distant, cheap-per-bit store to compute, at a rate the compute can tolerate. The model lives in DRAM. Compute visits it.

**The NPU asks: how do I avoid DRAM entirely — or, failing that, touch it as rarely as physics allows?** Its memory system is therefore a *residency* system: a comparatively enormous amount of on-chip SRAM, small per-processing-element register files, direct neighbour-to-neighbour wires, and a compiler that decides, before the first byte moves, exactly where every tensor will sit and in what order every value will be consumed. The model — or the working slice of it — lives next to the compute. Data flows past, through, or between the units that use it, and the design's whole energy budget depends on each fetched value being used many times before it is allowed to leave.

That second answer has a name, and the name is the subject of this dossier:

> **A dataflow is a memory decision before it is a compute decision. It is the schedule — fixed in hardware, in the compiler, or in both — that determines which of the three moving quantities in a neural layer (weights, input activations, partial sums) is held still in the cheapest storage, which are streamed, which are broadcast, and which are passed hand-to-hand between neighbouring compute units instead of being written back to a memory at all. Two accelerators with identical MAC counts and identical SRAM capacity, running different dataflows, are different machines in energy, in latency, and in which layer shapes they reward.**

Everything below follows from that:

1. §2 gives the energy arithmetic that makes this non-optional. The numbers are old (2014) and the dossier says what has and has not changed about them.
2. §3 states the taxonomy the field settled on — weight-stationary, output-stationary, input-stationary, row-stationary, no-local-reuse — as a table of *what is held still and what each choice buys*.
3. §4 works the most commercially successful instance, the systolic array, and reasons carefully (labelled as reasoning) about why the shape of LLM decode is its worst case.
4. §5 works Hailo as the public case: what its published architecture actually claims, what it pointedly does not publish, what changed between Hailo-8 and Hailo-10H, and — in one short, marked section — what our own programme record does and does not entitle us to conclude from it.
5. §6 shows that three different vendors' software stacks converge on the same memory shape — weights frozen into a compiled artefact, activations bounded by static shapes — because the hardware underneath them converged first.
6. §7 turns the theory into applicability: what dataflow literacy changes in Aesir's kernel and tiling decisions even on GPU, why Ollama is honestly not an NPU-first target, and the one honest line about MimirAlloc.
7. §8 lists the sources, with access dates.

A reader in a hurry can read §1, the table in §3.6, §4.4, §5.5, and all of §7.

---

## 2. The Energy Arithmetic That Forces the Design

### 2.1 The Horowitz table, dated and sourced

The canonical anchor for every dataflow argument is the energy table in Mark Horowitz's ISSCC 2014 plenary, *"Computing's Energy Problem (and What We Can Do About It)"* [S1]. It prices operations and accesses for a **45 nm** process — a node already old when the talk was given, chosen because its numbers were well characterised. The figures reproduced across the secondary literature that cites the table, and cross-checked in two independent reproductions read for this dossier [S2][S3], are:

| Operation / access (45 nm, Horowitz ISSCC 2014) | Energy |
|---|---|
| 8-bit integer add | ~0.03 pJ |
| 32-bit integer add | ~0.1 pJ |
| 32-bit floating-point add | ~0.9 pJ |
| 32-bit floating-point multiply | ~3.7 pJ |
| 32-bit read, small on-chip SRAM (order 8 KiB) | ~5 pJ |
| 32-bit read, larger on-chip cache (order 1 MiB) | ~100 pJ (for a 64-bit pair, in the ETH reproduction [S3]) |
| 32-bit read, off-chip DRAM | ~640 pJ |

Read the last row against the others, because the whole field is in that comparison:

- One 32-bit DRAM read costs roughly **170×** one 32-bit floating-point multiply (640 / 3.7).
- It costs roughly **6,400×** one 32-bit integer add, and more than **20,000×** one 8-bit integer add — and 8-bit integer MACs are the native operation of most inference NPUs.
- It costs roughly **two orders of magnitude** more than reading the same word from a small, close SRAM.

The often-quoted shorthand — *"a DRAM access costs 100–200× the energy of an SRAM access or a small integer operation"* — is therefore **directionally right but imprecise, and the imprecision matters**. Against a small SRAM read the ratio is ~128× (640 / 5). Against a large cache it is much smaller. Against the arithmetic itself it is far larger. The honest statement is not a single ratio; it is a **ladder**: register file ≪ small SRAM ≪ large SRAM / cache ≪ DRAM, with roughly an order of magnitude per rung, and arithmetic sitting at or below the bottom rung. Every dataflow in §3 is a strategy for keeping the overwhelming majority of accesses on the bottom two rungs.

Horowitz's own framing, as reproduced in his later seminar material, puts roughly half of a high-performance system's power in I/O and DRAM access alone, at on the order of 15–20 pJ/bit for the off-chip interface of that era [S4]. The Eyeriss paper states the same premise in one sentence as its motivation: fetching data from off-chip DRAM costs orders of magnitude more energy than fetching it from on-chip storage, and data movement can be more expensive than the computation itself [S5].

### 2.2 What has changed since 2014 — and what has not

The table is more than a decade old. The dossier separates the three things a reader might wrongly assume about its age:

**Absolute energies have fallen.** Newer nodes, lower voltages, and narrower inference precisions (INT8, INT4, FP8) all reduce the per-operation and per-access picojoules. No figure in the table should be used as a current absolute number for a modern part. Any dossier or pitch that quotes "640 pJ" as the cost of a DRAM access *on a 2025 chip* is misusing the source.

**The ladder has not flattened; if anything it has steepened.** The reason is structural, not anecdotal: transistor switching energy scales with process in a way that wire and off-chip interface energy does not. Moving a bit across a die, and especially off a die through a package pin, a board trace, and a DRAM interface, is dominated by capacitances that shrink slowly or not at all. A recent audit citing the same Horowitz accounting states the point directly: moving a word costs roughly 170× computing with it, *"and the ratio has grown at modern process nodes, where interconnect scales worse than transistors"* [S2]. That is a secondary source's characterisation, not a new measurement — but it agrees with the direction every accelerator designer since 2014 has actually built in, which is itself evidence: SRAM budgets per accelerator have grown relentlessly, and no major NPU has moved *toward* a DRAM-centric design. Hailo's second generation (§5.3) is the instructive partial exception, and it is about capacity, not about preferring DRAM energy.

**The conclusion the table licenses is therefore about ratios and strategy, not about watts.** It licenses: *an accelerator's energy is set first by how many DRAM accesses its schedule performs per MAC, and only second by how efficient its MACs are.* It does not license any specific TOPS/W claim for any specific modern chip. Vendor TOPS/W figures in §5 are reported as vendor figures for exactly this reason.

### 2.3 The implication: reuse is not an optimisation

A convolutional layer is reuse-rich by construction, and the Eyeriss paper quantifies the two native forms [S5]:

- **Filter (weight) reuse / convolutional reuse.** Each filter weight is applied at every output position — reused on the order of E² times across one output feature-map plane (E being the plane's width/height), and again across a batch.
- **Input (activation) reuse.** Each input pixel participates in many overlapping filter windows — reused on the order of R² times within one filter plane (R being the filter width/height).

A fully-connected layer keeps batch/filter reuse but loses the sliding-window form. A transformer projection is a dense matrix multiply whose reuse is set by its three dimensions. In every case the arithmetic itself defines a *maximum possible* number of MACs per byte fetched — the layer's operational intensity, in the roofline sense the corpus treats in `memory/memory-wall-and-roofline.md`. A naive schedule realises almost none of it: fetch a weight, fetch an activation, multiply, write the partial sum back, repeat — three memory touches, two of them potentially to DRAM, per MAC. At Horowitz ratios that schedule spends well over 99% of its energy moving data and under 1% computing.

So the design problem of an NPU is not "build fast MACs." It is:

> **For each layer shape, choose a schedule that converts the layer's mathematical reuse into physical locality — each weight, activation, and partial sum fetched from the cheapest level that can hold it, used the maximum number of times while it is there, and, wherever possible, handed directly to the neighbouring unit that needs it next rather than written anywhere at all.**

That choice *is* the dataflow. §3 is its taxonomy.

---

## 3. The Dataflow Taxonomy

### 3.0 Provenance, stated honestly

The taxonomy in its original form is Chen, Emer & Sze's, from the Eyeriss paper (ISCA 2016) [S5], which classifies the then-existing CNN dataflows into **weight-stationary (WS)**, **output-stationary (OS)** (in three sub-variants), and **no-local-reuse (NLR)**, and proposes **row-stationary (RS)** against them. The group's tutorial and survey material (MICRO 2016 tutorial; Sze, Chen, Yang & Emer, *Proceedings of the IEEE*, December 2017) [S6][S7] is the canonical teaching form, and later teaching material (the MIT 6.5930 lectures; Georgia Tech's MAESTRO work) adds **input-stationary (IS)** as a named peer [S8][S9]. This dossier presents the five-term taxonomy as the field now teaches it, and flags the provenance difference because a reader checking the 2016 paper alone will not find IS named there — that is an extension of the taxonomy, not a contradiction of it.

The setting for all five is the same **spatial architecture** [S5][S7]: an array of simple processing elements (PEs), each with a MAC datapath and a small local register file (RF — typically well under 1 KiB per PE; Eyeriss uses 0.5 KiB), sitting under a shared on-chip global buffer (typically 100–300 KiB in the 2016-era designs), sitting under off-chip DRAM. Four levels of storage, four energy prices (§2.1). A dataflow specifies, for each of the three data types, at which level its reuse is harvested:

- **Temporal reuse** — a value kept in an RF across cycles and used again.
- **Spatial reuse** — a value broadcast/multicast to many PEs at once, or passed PE-to-PE, so one fetch feeds many MACs.
- **Accumulation locality** — partial sums (psums) reduced where they are born, in an RF or on a neighbour wire, instead of round-tripping to the global buffer or DRAM.

"Stationary" names the data type whose movement the schedule minimises most aggressively — the one that stays in the RF while the other two stream past it.

### 3.1 Weight-stationary (WS)

**Holds still:** the weights. Each filter weight, once loaded into a PE's RF, remains there while the PE runs through every operation that uses that weight — in the Eyeriss formulation, an R×R tile of weights from one filter/channel is laid out across an R×R region of PEs and stays; input pixels are broadcast to the region in sequence [S5].

**Streams:** input activations (broadcast) and partial sums (accumulated spatially across the PE region, or spilled).

**Reuse maximised:** weight reuse — both convolutional reuse (a weight across all output positions) and filter reuse (a weight across the batch). This is the most valuable reuse when weights are the scarce, expensive-to-fetch quantity and each weight's use-count is high.

**Costs / weaknesses:** because the schedule is organised around exhausting each weight, psums are *not* always immediately reducible — MACs using the same weight produce partial results for different outputs, which must be buffered, typically in the global buffer, until their partners arrive [S5]. Psum traffic to the global buffer is WS's tax. WS also wants batch or spatial extent to amortise the weight load: load a weight once and use it E²·N times is excellent; load it once and use it once is the worst schedule imaginable — a point §4.4 returns to at length.

**Favours:** convolutional layers with large output planes; batched fully-connected / GEMM work where a loaded weight tile meets many activation vectors. Exemplars in the 2016 taxonomy include the neuFlow lineage [S5]; its most famous descendant is the TPU (§4).

### 3.2 Output-stationary (OS)

**Holds still:** the partial sums — one output activation's accumulation stays in a single PE's RF until it is finished, so the psum is read and written at RF price, the cheapest rung, for its entire life [S5].

**Streams:** weights and inputs, delivered to the accumulating PE in the order its output needs them.

**Reuse maximised:** psum accumulation locality, first and above all. The Eyeriss paper splits OS into three sub-variants by which region of the 4-D output space the array processes at once — single-channel/multiple-pixels (SOC-MOP, mainly convolutional, adding convolutional reuse at array level), multiple-channels/multiple-pixels (MOC-MOP, adding input reuse as well), and multiple-channels/single-pixel (MOC-SOP, mainly fully-connected, maximising input reuse at array level) [S5]. The sub-variants are a reminder that "OS" names the psum decision; the weight/input delivery can still be tuned separately.

**Costs / weaknesses:** weights and inputs must be re-delivered per output tile; if their reuse is not *also* harvested at the array level (broadcast/multicast), OS pays for its psum frugality with weight/input traffic. The variants exist precisely to claw that back spatially.

**Favours:** layers where psum traffic would otherwise dominate — deep reductions (large filter × channel products per output), fully-connected layers in the MOC-SOP form. ShiDianNao is the taxonomy's named OS exemplar [S6].

### 3.3 Input-stationary (IS)

**Holds still:** the input activations. An input tile is loaded into the array's RFs and kept while every filter that needs it is streamed past [S8][S9].

**Streams:** weights and partial sums.

**Reuse maximised:** input reuse — the sliding-window reuse of a convolution (each pixel used R² times) and, in matrix terms, the reuse of an activation row/column across many weight columns.

**Costs / weaknesses:** the mirror of WS: psums for many different outputs are generated from the resident inputs and must leave; weight delivery is continuous. IS is the natural choice when inputs are the expensive side (large activations, small/shared weights) and the unnatural one when weights dominate — which, in LLM-shaped work, they usually do. **[Engineering judgement]** IS is the least commercially prominent of the five in shipped NPUs, and the taxonomy's completeness case more than its volume case; it matters to the corpus chiefly because some attention-adjacent mappings (a resident K/V tile, weights/queries streamed) are IS-shaped, a point §7.1 uses.

### 3.4 Row-stationary (RS) — Eyeriss

**Holds still:** no single type — and that refusal is the contribution. RS decomposes the high-dimensional convolution into **1-D convolution primitives**: each PE holds one *row* of filter weights and works on one *row* of input pixels, producing one row of psums, so that within the PE's RF all three reuses are harvested at once for that row — weight row reuse, input sliding-window reuse along the row, and psum accumulation along the row — while rows are combined across PEs by direct inter-PE passing [S5].

**Streams:** rows, between neighbouring PEs, on wires — not to the global buffer and not to DRAM.

**Reuse maximised:** all three, balanced, at the lowest levels of the hierarchy simultaneously. Where WS/OS optimise one movement type and tax another, RS optimises the *sum*, reconfiguring its mapping per layer shape.

**Measured claim (2016, AlexNet shapes, equal area/parallelism):** RS was 1.4×–2.5× more energy-efficient than the compared dataflows on convolutional layers, and at least 1.3× on fully-connected layers at batch > 16 [S5]. The fabricated Eyeriss chip — 168 PEs, 108 KiB global buffer, 0.5 KiB RF per PE, 65 nm, 200 MHz — reported 0.0029 DRAM accesses per MAC on AlexNet convolutional layers [S10]. That last number is the dataflow programme in one statistic: fewer than three DRAM touches per *thousand* MACs.

**Costs / weaknesses:** complexity. RS needs a flexible network-on-chip (data's physical neighbours depend on the layer's mapping, so a fixed interconnect will not do), per-shape mapping logic in the compiler, and RF sized for rows of all three types. It is a CNN-native idea: its primitive *is* a convolution row. Dense GEMM can be mapped onto it, but the row structure buys less there, and transformer-shaped work (attention's data-dependent patterns, §4.3) buys less still.

**Favours:** varied convolutional networks on a power budget — the edge-vision regime Hailo (§5) also targets, by a different route.

### 3.5 No-local-reuse (NLR)

**Holds still:** nothing, at RF level — by definition. NLR has the two characteristics the Eyeriss paper states: (1) it does not exploit data reuse at the RF level, and (2) it uses inter-PE communication for input reuse and psum accumulation [S5]. PEs are essentially bare MACs; reuse, where it happens, happens spatially across the array and temporally in the *global buffer*, which is correspondingly large.

**Reuse maximised:** array-level input reuse and spatial psum reduction — real reuse, but harvested one rung higher (and roughly an order of magnitude more expensive per access) than RF-level reuse.

**Costs / weaknesses:** every operand that WS/OS/RS would have kept in an RF is instead fetched from the global buffer. NLR's compensating virtue is simplicity and area: no per-PE RF means more area for PEs and buffer. DianNao is the taxonomy's named exemplar family [S6].

**Why it is in the taxonomy at all:** NLR is the control case. It proves the taxonomy is measuring something: move the same reuse up one level of the hierarchy and the energy follows §2's ladder. **[Engineering judgement]** NLR is also the honest description of what a badly tiled GPU kernel does — operands streamed from a large shared store with no register-level residency plan — which is why §7.1 can use this 2016 taxonomy to grade 2026 GPU code.

### 3.6 The taxonomy as one table

| Dataflow | Held in the RF | Streamed / passed | Reuse maximised | Its tax | Layer shapes it favours |
|---|---|---|---|---|---|
| **Weight-stationary** | Weights | Inputs broadcast; psums accumulated spatially or via global buffer | Weight (convolutional + batch) | Psum buffering | CONV with large output planes; batched GEMM/FC |
| **Output-stationary** | Partial sums (one output's accumulation) | Weights + inputs delivered per output | Psum accumulation locality | Weight/input re-delivery | Deep reductions; FC (MOC-SOP form) |
| **Input-stationary** | Input activations | Weights; psums out | Input (sliding-window / row) | Psum egress; continuous weight delivery | Large activations, small shared weights |
| **Row-stationary** | One row each of weights, inputs, psums | Rows passed PE-to-PE | All three, balanced, at RF level | NoC + mapping complexity; CNN-native | Varied CONV nets on a power budget |
| **No-local-reuse** | Nothing | Everything via global buffer / inter-PE | Array-level input reuse only | Global-buffer energy on every operand | Simple, area-constrained designs (control case) |

Three cross-cutting lessons the table makes visible:

1. **Every dataflow is a choice of which tax to pay.** There is no schedule that minimises weight, input, and psum movement simultaneously for all shapes — RS comes closest for convolutions precisely by spending hardware (NoC, RF, compiler) on the problem. Dataflow selection is therefore per-layer-shape economics, and reconfigurability — in the array, or in the compiler's mapping — is worth silicon.
2. **Batch is a dataflow variable.** Batch multiplies weight reuse (WS's core asset) without changing the weights. Several rankings in the 2016 experiments move with batch size (RS's FC advantage is stated at batch > 16 [S5]). Any NPU benchmark quoted without a batch size is missing its most important parameter — a sentence §4.4 will need.
3. **The taxonomy is about GEMM too, whether or not its authors aimed it there.** A matrix multiply has the same three quantities and the same three reuses, with dimensions (M, N, K) in place of the convolution's shape parameters. WS/IS/OS for GEMM correspond exactly to which operand tile the schedule keeps resident — the mapping later systolic-array literature uses explicitly [S11]. The CNN-era taxonomy is the LLM era's tiling vocabulary, unchanged.

---

## 4. Systolic Arrays: The TPU Pattern

### 4.1 The pattern

A systolic array is a grid of PEs in which data moves rhythmically, one neighbour-step per cycle, like blood pumped through a heart — the metaphor is in the name (Kung, 1982 lineage, cited in the TPU paper as [Kun80]). Each PE does one small thing — typically a MAC — and hands its result and/or its operands to the next PE. No PE ever addresses a memory. The array as a whole converts one large SRAM read into a wave of computation that consumes the value as it propagates.

Google's TPU v1 (deployed 2015; Jouppi et al., ISCA 2017) [S12] is the canonical industrial instance, and its published facts are:

- **Array:** 256×256 8-bit MACs — 65,536 units — peak 92 TOPS (INT8).
- **On-chip memory:** 28 MiB of software-managed SRAM in total: a 24 MiB **Unified Buffer** for activations/intermediates, and 4 MiB of 32-bit **accumulators** (4,096 accumulators of 256 elements). Buffers are ~37% of the die; the matrix unit ~30%; control just 2% — the floorplan itself is the §1 thesis drawn to scale.
- **Weight path:** weights live in a separate off-chip 8 GiB DRAM ("Weight Memory," read-only at inference), staged through an on-chip Weight FIFO into the array. The matrix unit holds a 64 KiB weight tile plus a second tile for double-buffering, hiding the 256 cycles a tile shift-in takes.
- **Execution model:** deterministic, compiler/host-driven, CISC-like instructions sent over PCIe; deliberately *without* caches, out-of-order execution, branch prediction, prefetching, or multithreading — the paper argues those features optimise average throughput at the expense of the 99th-percentile latency its datacentre inference contracts actually specified.

### 4.2 The dataflow, precisely

TPU v1's matrix unit is **weight-stationary in the taxonomy's sense, implemented systolically** [S12][S11]:

1. A weight tile is preloaded from the top of the array and becomes resident.
2. Activations flow in from the left, one step per cycle, so a 256-element operation moves through the array as a **diagonal wavefront**.
3. Each PE multiplies its resident weight by the passing activation and adds the product into a partial sum that accumulates as it travels; finished sums land in the accumulators, are passed through the activation unit (nonlinearity/pooling), and are written to the Unified Buffer as the next layer's inputs.

The paper gives the energy reason in one clause: *"as reading a large SRAM uses much more power than arithmetic, the matrix unit uses systolic execution to save energy by reducing reads and writes of the Unified Buffer"* [S12]. That is §2 applied at the largest scale the industry had then shipped: the Unified Buffer is read *once* per activation vector, and the array's internal neighbour wires — the cheapest rung of the ladder — do the rest of the distribution. Software, the paper notes, is unaware of the systolic mechanics for correctness but must respect the unit's latency for performance; the compiler, not a cache, owns the schedule.

The roofline consequence is published and stark: the TPU's ridge point sits at ~**1,350 operations per byte** of weight-memory traffic [S12]. Below that intensity, the part is memory-bound no matter how wide the array is. Of the six production workloads measured, the MLPs and LSTMs were memory-bandwidth-bound and the CNNs compute-bound — and the paper's counterfactual (the same TPU with the K80 GPU's GDDR5 system) would have tripled achieved TOPS. Even the most successful SRAM-centric design of its era was, on most of its real workload, waiting on DRAM. That is not a failure of the design; it is the wall (§2) asserting itself at the boundary the design could not remove: weights too large to reside on-chip must still cross from DRAM, and their reuse is the only amortisation available.

### 4.3 What systolic weight-stationary does to irregular work

The array's strengths are exactly the dense GEMM's properties: regular shapes, static schedules, every PE doing the same operation on a predictable neighbour pattern, reuse fixed by the dimensions. Its published limits follow from the same facts:

- **Dense only, by decision.** The TPU paper states the matrix unit "is designed for dense matrices. Sparse architectural support was omitted" (a schedule decision, deferred to future designs) [S12]. A sparse operand does not become cheap in a systolic array: the wavefront moves at the dense rate regardless of how many values are zero, unless extra hardware skips them — the zeros are paid for in cycles and in movement, if not in MAC energy.
- **Shape quantisation.** Utilisation is set by how well the layer's dimensions fill 256×256 tiles. The paper's own counters show the failure mode: on one production CNN, on active cycles only about half the array held *useful* weights because some layers had shallow feature depth, and overall useful-MAC occupancy across the six workloads averaged roughly a quarter of peak [S12]. A systolic array does not degrade gracefully to small or odd shapes; it degrades by idling in lockstep.
- **Data-dependent work has no home.** Attention's core pattern — scores computed from the current token, a softmax over a growing, runtime-length set, then a weighted sum whose "weights" are themselves activations produced moments earlier — breaks the WS premise twice: there is no pre-loadable stationary operand of the right kind for the attention product itself, and the sequence dimension is dynamic where the array's schedule is static. Production transformer accelerators therefore surround the systolic GEMM engine with *other* units for exactly these operations (vector units for softmax/normalisation/elementwise work — the pattern visible in Qualcomm's fused design, §5.6/§6.3, and in every later TPU generation's addition of specialised units). **[Engineering judgement]** The systolic array in a modern SoC should be read as the GEMM organ of a heterogeneous body, not as the body.

### 4.4 The LLM-era question: decode is the worst case — [Reasoning]

*This subsection is reasoning from the taxonomy (§3) and the published TPU facts (§4.1–4.2), not a cited measurement. It is labelled as such throughout, per this dossier's quality law.*

Autoregressive LLM inference has two phases with opposite shapes (the corpus treats both in `memory/kv-cache-design.md`):

- **Prefill** processes a whole prompt at once: activation matrices with hundreds-to-thousands of rows against each weight matrix. Operationally this is large dense GEMM — batch-like reuse everywhere, weights amortised across every prompt row. A weight-stationary systolic array is *at home* here; prefill is close to its design centre.
- **Decode** generates one token at a time. Each step multiplies each weight matrix by a *single* activation vector — GEMV, not GEMM. Every weight in the model is used **exactly once per token**.

Now apply §3.1. WS's entire asset is weight reuse: load a weight into the array, use it many times. Decode offers a use-count of **one** per load (per step). The consequences, in order:

1. **The array's preload cost is unamortised.** Shifting a weight tile into a 256×256 array takes on the order of the array's dimension in cycles; with a batch of one vector behind it, the array spends a large fraction of its time loading weights it will use once, and most PEs are idle for most of the wavefront's life. Utilisation collapses from the §4.2 picture toward a thin diagonal.
2. **Operational intensity falls to its floor.** Per token, decode performs ~2 FLOPs per parameter while reading ~1 byte per parameter (at INT8; ~0.5 byte at INT4) — an intensity of roughly 2–4 ops/byte against a TPU-class ridge point of ~1,350. Decode is therefore not mildly but *categorically* memory-bound on any such design: its speed is set, almost exactly, by (weight bytes) / (DRAM bandwidth), and the MAC array's size is nearly irrelevant. This is the same arithmetic the corpus's roofline dossier derives for GPUs; the dataflow lens adds *why no schedule can fix it*: there is no reuse in the mathematics of single-token GEMV for a schedule to harvest. The only multipliers available are batching (serve many sequences' decode steps together, restoring weight reuse across the batch — the continuous-batching move the serving dossiers describe), speculation (verify several drafted tokens per weight pass, restoring reuse across the speculation width), and shrinking the bytes (quantisation). All three are *workload* changes, not dataflow changes.
3. **The KV cache is the second, growing weight.** Decode also re-reads the accumulated keys/values each step — activation-side traffic that grows with context length, has no stationary home in a WS array, and competes for the same DRAM bandwidth. An NPU whose SRAM cannot hold the working KV (the common case past short contexts) pays this from DRAM too.

**The balanced conclusion of the reasoning:** a weight-stationary systolic NPU is an excellent *prefill and batched-inference* engine and a structurally poor *single-stream decode* engine — not because it is badly built, but because decode denies it the one commodity its dataflow exists to exploit. Any evaluation of "NPUs for LLMs" that does not separate the two phases, state a batch size, and state a context length is not yet an evaluation. §5.5 applies exactly this test to the public Hailo material.

---

## 5. Hailo as the Public Case

Hailo is the right public case for this corpus for three reasons: its architecture is the purest commercial statement of the SRAM-centric position (§5.1); its second generation publicly retreats from that purity in an instructive direction (§5.3); and our own programme has a Hailo history that must be stated accurately and kept in its place (§5.4).

### 5.1 Hailo-8: the structure-defined dataflow claim

Hailo's own product material describes the Hailo-8 as follows [S13]:

- **Performance/power (vendor figures):** up to 26 TOPS (INT8), typical power consumption 2.5 W.
- **Memory:** *"Does not require external memory."* The accelerator integrates the memory it needs on the processor; there is no external DRAM in the inference path. This is the headline architectural fact, and Hailo repeats it across its materials, including a later company post calling Hailo-8/8L (in its words) the only accelerators delivering high-performance edge AI without external DRAM, by "keeping the full inference pipeline on-chip" [S14 — vendor marketing claim, reported as such].
- **Architecture:** a *"structure-driven dataflow architecture"* (the product brief's wording; elsewhere "structure-defined") that "takes advantage of the core properties of neural networks." Contemporary reporting of Hailo's own explanation fills in the mechanism: compute, memory, and control resources are *distributed* across the chip rather than centralised; the compiler analyses how much of each resource each layer needs and maps layers onto those distributed resources, with adjacent layers placed adjacently, so data movement stays local [S15].
- **Toolchain:** a comprehensive **Dataflow Compiler** translates trained models (TensorFlow / TFLite / Keras / PyTorch via ONNX) into Hailo's format; the host runtime is **HailoRT**; the device connects as a PCIe co-processor to x86 or ARM hosts [S13].
- **Scaling story:** simultaneous multi-stream and multi-model processing is a stated feature, and multiple Hailo-8 devices are the stated route to 52–208 TOPS configurations [S13].

In the vocabulary of §3, Hailo's design is best understood not as one of the five named dataflows but as the **compile-time, whole-graph generalisation of the dataflow idea**: instead of one stationary policy for an array, the compiler assigns each *layer* its own territory of compute/memory/control on a distributed fabric, and the network's own graph becomes the schedule. The reuse being harvested is inter-layer as much as intra-layer — an activation produced by layer *n* is consumed by layer *n+1* from nearby on-chip memory, never making the DRAM round-trip that a kernel-by-kernel GPU execution pays between layers. That is a genuinely different point in the design space from both the GPU (schedule in the runtime, residency in caches) and the TPU (schedule in the compiler, residency in one large buffer, one fixed WS policy).

**What the public material does not say** — and the dossier records the absence as a finding, not a complaint:

- No public SRAM capacity figure for Hailo-8 appears in the official product brief read for this dossier [S13]. Secondary sources circulate figures; none was verified against a Hailo primary document today, so none is stated here. **[Unverifiable from primary sources, 2026-11-15]**
- No public description was found of the internal mapping's granularity, of context-switch cost between compiled networks, or of how on-chip memory is partitioned when multiple models/streams share the device — despite multi-model support being a headline feature. The *capability* is public; the *memory mechanics* are not.
- No public per-layer or per-operator support matrix was read in the official brief; operator coverage lives in the developer-zone documentation behind the toolchain, and §5.4 explains why that distinction — catalogue vs silicon — is the whole lesson of our own record.

### 5.2 The host-memory model

What is public, and consistent across the brief and reporting [S13][S15]: Hailo-8 is a **co-processor**. The host (x86/ARM) owns the application, the cameras/streams, pre- and post-processing, and anything the compiled network does not contain; the device owns the compiled network's execution, fed over PCIe. There is no device-side DRAM for the host to manage, no unified virtual address space spanning host and accelerator, and no runtime graph execution: the unit of deployment is the **compiled artefact** produced by the Dataflow Compiler, loaded by HailoRT. Memory management, in the runner sense, has been moved almost entirely to compile time — the theme §6 generalises.

### 5.3 Hailo-10H: the vendor's own correction to the pure position

Hailo's second-generation part is publicly positioned as its generative-AI accelerator [S16]:

- **Performance/power (vendor figures):** 40 TOPS INT4 / 20 TOPS INT8, 2.5 W typical.
- **Memory:** a **direct DDR interface**, supporting LPDDR4/4X — on-module 4 GB or 8 GB in the M.2 module form — expressly "allowing it to scale for large models such as LLMs, VLMs and more" [S16].
- **Positioning:** "the industry's first edge AI accelerator to bring immersive generative AI capabilities directly to edge devices" (vendor claim), with LLMs, VLMs, and Stable Diffusion named as target workloads, and a company whitepaper on LLM deployment on the part [S16].

Read through §2 and §4.4, the 10H's memory change is the most honest sentence in the whole public NPU literature, even though it is written as marketing: **the SRAM-only position has a capacity wall, and language models are on the other side of it.** A vision network's weights fit the on-chip regime; a multi-billion-parameter model's weights do not, at any plausible SRAM budget, and decode (§4.4) would stream them from wherever they live in any case. Hailo's answer is not to abandon the dataflow architecture — the 10H keeps the structure-driven dataflow and the Dataflow Compiler — but to attach the smallest, closest DRAM that makes the workload *addressable*, and let the compiler manage the boundary. The pure doctrine ("no DRAM") was a property of a workload class (vision CNNs), not a law of nature. The vendor's own product line now says so.

### 5.4 Our record — short, marked, and bounded

> **[OUR RECORD — programme history, not public literature. This section reports lessons from Volmarr's own programme records, at the level of lessons only, as commissioned. It is context for §5.5, not evidence about Hailo silicon.]**
>
> Our programme ran a long Hailo campaign aimed, among other things, at text generation. That attempt **never achieved text generation**. During the campaign a closed verdict was at one point recorded against the hardware — in effect, that the catalogue of supported models/operations defined what the device could do. **Volmarr corrected that verdict on 2026-10-19, and the correction stands as the programme's position:** what had been measured was a *software* fact — the compiled catalogue, the compiler's operator coverage, and the toolchain path available to us — not a hardware limit of the silicon. His Possibility Law states the general form: a vendor software limit is a software fact, never a hardware verdict.
>
> Two disciplines follow, and this dossier observes both. (1) We do **not** claim Hailo-8-class hardware can run LLM text generation usefully; our campaign did not achieve it, and §4.4 gives structural reasons to expect the attempt to be hard. (2) We do **not** claim it cannot, on the basis of a catalogue or compiler path; the corrected record forbids that inference. What the record supports is narrower and more valuable: *in the compiled-blob regime (§6), the binding constraint a practitioner meets first is almost always the toolchain — operator coverage, quantisation path, catalogue — and any verdict about "the hardware" reached through a toolchain must be labelled as a toolchain verdict.*

### 5.5 What the public material does and does not establish about LLM-shaped workloads

Applying §4.4's test (separate the phases; demand batch and context) to the public record:

**Established publicly:**
- Hailo-8's vendor positioning is vision/edge inference; no LLM claim is made for it in the material read [S13].
- Hailo-10H's vendor positioning explicitly includes LLMs/VLMs, with a DDR-backed memory system sized at 4–8 GB — i.e., the small-model end of the LLM space, at INT4/INT8 precisions [S16].
- The deployment unit in both generations is a compiled artefact from the Dataflow Compiler (§5.2, §6) — so "support" for a given LLM means, concretely: that architecture, at that quantisation, with those operators, at those (static) shapes, compiles.

**Not established publicly (in the material read today):**
- No tokens/second figures for LLM decode on Hailo-10H, at any stated batch/context, were found in the official product material read [S16]. The whitepaper is linked from the product page; its numbers were not read for this dossier and are therefore not quoted. **[Not read — flagged, not filled in.]**
- No public statement of KV-cache residence (on-chip vs DDR), maximum context, or prefill/decode split performance.
- No public statement of which LLM architectures/operators are in the 10H compiler's coverage, at the granularity a practitioner would need (attention variants, RoPE forms, sampling placement — host or device).

**[Engineering judgement]** That pattern of disclosure is itself diagnostic, and it is the same pattern §5.6 and §5.7 show at Apple and Qualcomm: vendors publish TOPS and workload *names*; the memory facts that decide LLM usefulness (decode bandwidth, KV residence, context ceiling, operator coverage) are published late, in developer documentation, or not at all. A buyer applying this corpus's standards would treat an NPU's LLM claim as **unproven until the decode numbers exist at a stated batch and context** — for Hailo-10H as for everyone else. That is a standard of evidence, not a verdict on the part.

### 5.6 Apple Neural Engine — at public-fact level, deliberately

Apple publishes the least of any major vendor, and this dossier keeps the section at exactly the level Apple itself supports:

- The Neural Engine (ANE) is a dedicated neural accelerator integrated in Apple's A-series (since A11, 2017) and M-series SoCs, accessed by developers **only through Core ML**, which decides per-layer placement across ANE/GPU/CPU [S17].
- Apple markets it by throughput: e.g., 38 TOPS for the M4-generation Neural Engine (vendor figure) [S17].
- Models reach it as **compiled Core ML artefacts** with, in practice, static-shape discipline — the compiled-blob regime of §6 in Apple's dialect.

Beyond that, Apple publishes no instruction set, no memory-architecture description, no SRAM figure, and no direct programming interface [S17]. A substantial reverse-engineering literature exists; its specific claims (SRAM sizes, internal dataflow, throughput decompositions) were **not** adopted here, because none could be tied to an Apple primary source. **[Unverifiable from primary sources, 2026-11-15]** The dossier's finding about the ANE is therefore about *disclosure as architecture*: the ANE is the extreme case of the compiled-blob regime — the memory system is not merely compiler-managed, it is *undocumented*, and the practitioner's entire relationship to it is "submit a graph that fits the compiler's idea of the hardware, accept the placement you are given." For Aesir's purposes (§7) the ANE is a cautionary bound, not a target: it demonstrates how far the NPU road can go toward opacity, and why a programme that values inspectability should note the direction of travel.

### 5.7 Qualcomm Hexagon / AI Engine — briefly

Qualcomm's public position is the heterogeneous one [S18]:

- The Hexagon lineage began as a standalone DSP; in modern Snapdragon SoCs it is a **fused NPU** integrating **scalar, vector (HVX), and tensor** units under the "AI Engine" umbrella, alongside the SoC's CPU and GPU [S18].
- The architectural significance for this dossier is the *division of labour made explicit*: tensor units for the dense GEMM core (the systolic-like organ of §4.3), vector units for the elementwise/normalisation/softmax-shaped work a tensor array cannot do, scalar units for control. Qualcomm's more recent public material emphasises enlarged **shared memory** for the NPU — keeping more model state and intermediates on-chip, reducing trips to external memory — and transformer-targeted acceleration [S19 — vendor blog reporting; figures are vendor claims].

Hexagon matters to §6 less for its silicon than for its software surface: it is the hardware underneath ONNX Runtime's QNN execution provider, the corpus's second compiled-blob instance.

---

## 6. The Compiled-Blob Regime Meets the Corpus

Step back from any single vendor and a single memory shape repeats three times in this corpus, under three names. Naming it once is this section's job, because the corpus's runner dossiers (`runners/openvino-genai.md`, `runners/onnx-runtime-genai.md`) each meet it separately and a reader could miss that it is one phenomenon.

### 6.1 The shape

In the compiled-blob regime:

1. **Weights are frozen at compile time.** The model's parameters are quantised, laid out, tiled, and — in the strong forms — placed into specific on-chip territories by a vendor compiler, producing a device-specific artefact: Hailo's compiled format loaded by HailoRT [S13], OpenVINO's compiled blob for Intel NPU, QNN's context binary (§6.3). The artefact is not portable across devices, and in OpenVINO's documented case not guaranteed compatible even across driver/OpenVINO versions [S20].
2. **Activations are bounded by static shapes.** OpenVINO's NPU documentation states it flatly: only models with static shapes are supported on NPU [S20]. ONNX Runtime's QNN provider likewise does not support dynamic shapes (e.g., dynamic batch) [S21]. Compile-time scheduling requires knowing every tensor's size before execution; a dynamic dimension is not an inconvenience to this regime, it is a contradiction of it.
3. **Runtime allocation nearly disappears.** What a GPU runtime does continuously — allocate, free, cache, split, merge (see `memory/gpu-memory-internals.md`) — the NPU stack does once, at compile time, in the compiler's memory planner. The runtime's remaining memory jobs are loading the blob, providing input/output buffers, and (where the device has attached DRAM, as on Hailo-10H or Intel/Qualcomm SoCs) staging weights the compiler has scheduled across the boundary.
4. **Fallback is graph surgery, not an error.** An operator outside the compiler's coverage does not slow the NPU path down; it *amputates* it — the unsupported subgraph is partitioned to CPU/GPU, with the attendant copies at the boundary, or compilation fails outright. Coverage is therefore a memory-architecture fact as much as a compute fact: every fallback boundary is a place where tensors leave the SRAM regime and pay §2's ladder.

### 6.2 Instance one: Hailo (recap in regime terms)

Dataflow Compiler in, compiled format out; HailoRT loads and runs it; the network's memory plan *is* the compilation (§5.1–5.2). Of the three instances, Hailo's is the most complete form of the regime: no device DRAM on Hailo-8 means the compiler's plan must fit a fixed on-chip budget or the model does not run at all — the regime with its constraint worn openly.

### 6.3 Instance two: OpenVINO on Intel NPU

OpenVINO's NPU device documentation [S20][S22] shows the same shape from the software side:

- Compilation converts the model's intermediate representation into a proprietary, platform-specific form; the compiler "performs platform specific optimizations in order to efficiently schedule the execution of layers and memory transactions on various NPU hardware submodules" — i.e., the memory schedule is a compiler output, exactly as in §3's definition of dataflow [S22].
- Compiled models can be exported as blobs and re-imported to skip recompilation, with caching (`CACHE_DIR`) as the productised form; for GenAI/NPU use, ahead-of-time export (`EXPORT_BLOB`/`BLOB_PATH`) is documented, including a *weightless* blob variant that excludes weights and requires the original model at load [S23].
- The GenAI-on-NPU guidance adds the regime's practical corollaries: LLMs must be exported with NPU-specific settings (including prescribed quantisation formats), and system-RAM demands for compiling/serving larger models at longer prompts are called out explicitly [S23] — the host side of the boundary is part of the memory system too.

### 6.4 Instance three: ONNX Runtime's QNN provider (Qualcomm)

ONNX Runtime's QNN execution provider documentation [S21]:

- Builds a QNN graph from the ONNX model via the Qualcomm AI Engine Direct SDK, executed by a backend library — the HTP backend being the NPU path.
- The HTP backend accepts **quantised models only** in the documented flow (floating-point models must be quantised first, e.g., to a QDQ representation) — quantisation is not an optimisation in this regime; it is an admission requirement.
- Offers **context-binary caching**: a session option (`ep.context_enable`) dumps a compiled context binary (`model_qnn.bin`, wrapped by a generated ONNX file) that can be deployed to production devices to skip on-device graph compilation. The binary *is* the compiled memory+compute plan, shipped as a file.
- For Snapdragon LLM use, the GenAI path expects models in a specific packaged form whose assets are literally enumerated as context binaries plus their metadata and ONNX wrappers [S24].

### 6.5 The lesson the three instances teach together

**[Synthesis — this dossier's judgement, from S13/S20–S24]** Three vendors, three toolchains, one shape — because the shape is dictated by §2, not by corporate taste. Once a design commits to SRAM-centred execution with a compiler-owned schedule, it *must* freeze weights into an artefact (the schedule is about specific weights in specific places), it *must* bound activations statically (the plan is computed before any data exists), and it *must* treat unsupported operators as partition boundaries (there is no general runtime to improvise with). The practical corollaries for the corpus:

- **"NPU support" for a model is a compile result, not a runtime property.** It can change with a compiler version, a quantisation choice, or a shape change, without any hardware changing. Roadmaps should record it that way (this is §5.4's lesson, generalised).
- **Context length is a compile-time decision in this regime.** A KV cache sized for 4k tokens and one sized for 32k are different memory plans; long-context LLM serving — a dynamic, growing allocation problem on GPU — becomes a set of pre-compiled shape buckets, or is refused. Any NPU LLM roadmap that does not state its context buckets has not yet met its memory system.
- **The blob is a cache with an invalidation problem.** Version skew (blob vs driver vs runtime) is documented as unguaranteed by Intel [S20] and handled by regeneration in Qualcomm's flow [S21]. A runner shipping NPU support ships a blob-management problem alongside it.

---

## 7. Applicability

### 7.1 Aesir's accelerator-first law: dataflow literacy is kernel literacy

Aesir's standing law orders the devices — NPU first, then GPU, then CPU, work divided across everything for maximum speed, accelerator carrying the bulk, CPU as spillover and as measured assist. This dossier's contribution to that law is not "use NPUs more." It is sharper:

**(a) GPU shared-memory tiling *is* dataflow design, in the taxonomy's exact sense.** A GPU kernel that tiles a GEMM into shared memory and registers is choosing, per operand, what is stationary: keep the weight tile resident in registers/shared memory while activation tiles stream — that is WS, implemented in software on SIMT hardware. Accumulate an output tile in registers across the whole K-loop — that is OS, and it is why register-resident accumulation is the first rule of GEMM craft. Stage a K/V tile and stream queries past it — IS. A kernel with no residency plan, operands fetched from global memory per use, is NLR — §3.5's control case — regardless of how modern the GPU is. **[Engineering judgement]** Aesir kernel review can therefore use the 2016 taxonomy as a checklist with teeth: for every hot kernel, name each operand's stationary home (register / shared / L2 / DRAM), name the reuse count that justifies it, and treat any operand answered "DRAM, once" as a defect to be justified, not a default. FlashAttention — treated elsewhere in this corpus — is the celebrated proof of the principle on the attention side: its entire contribution is an OS/IS-flavoured residency plan for SRAM that refuses to materialise the attention matrix in HBM.

**(b) The NPU rung of the ladder must be programmed as what it is.** Where Aesir targets a real NPU (the programme's XDNA/Hailo lines), §6 says the integration is a *compiler-integration* project — artefact pipeline, quantisation discipline, shape buckets, coverage matrix — not a backend-kernel project. Budgeting it as "another ggml-style backend" understates it by exactly the compile-time memory plan. Conversely, §4.4 disciplines expectations: an NPU rung earns its place on prefill-shaped, batched, or fixed-shape vision/audio work first; single-stream long-context decode is the last workload to move, and only with batching/speculation arithmetic that survives §4.4's intensity floor.

**(c) Heterogeneous division should follow reuse, not just FLOPs.** The law says divide work for maximum speed. The dataflow lens refines the division rule: place each subgraph where its dominant reuse is cheapest — dense static GEMM toward the tensor/systolic organ, elementwise/softmax/norm toward vector units (Qualcomm's fused design, §5.7, is this rule in silicon), data-dependent and control-shaped work toward CPU/GPU — and count every boundary crossing at §2 prices before claiming the division is a win. A split that saves 1 ms of compute and adds two DRAM round-trips of a large activation has lost, and only the energy/latency arithmetic in this dossier shows it.

### 7.2 Ollama: why NPUs are not a near-term target — honestly

Ollama's model (and ggml's beneath it) is the opposite pole from §6: one portable weight format (GGUF), loaded at runtime, executed by general backends (CUDA/ROCm/Vulkan/Metal/CPU) that improvise the memory plan per machine, per model, per request — dynamic shapes, dynamic batching, dynamic context, arbitrary community models arriving as files, not as vendor-compiled artefacts. Against that, the NPU regime demands, per model × per device: a vendor compiler run, a quantisation path the compiler accepts, static shape buckets, an operator-coverage verdict, and a blob whose compatibility across driver versions is not guaranteed [S20][S21].

That is not an argument that NPUs are useless to a local-LLM runner; it is an argument about *sequence and shape*:

- The plausible near-term form is narrow and honest: a **curated set of popular small models, pre-compiled per major NPU family, offered as an explicitly bounded fast path** (fixed context buckets, stated batch), with the general GPU/CPU path remaining the product. Anything broader promises the catalogue as if it were the hardware — §5.4's corrected error, at product scale.
- The decode arithmetic (§4.4) caps the prize for the single-user, single-stream case that is Ollama's home workload: on an NPU with attached DRAM, decode speed is bounded by that DRAM's bandwidth, which on current edge parts is a fraction of a discrete GPU's. The win available is *energy* and *leaving the GPU free*, not raw tokens/second. A roadmap should say so.
- **[Engineering judgement]** For the improved-Ollama work, engineering effort ordered by §2's ladder still pays best on the GPU residency side (§7.1a) and the KV side (`memory/kv-cache-design.md`) before any NPU rung. NPU support is a legitimate later rung — entered through one vendor stack (OpenVINO's, as the most openly documented of the three), one model family, and written coverage criteria — not a launch property.

### 7.3 MimirAlloc: the honest line

The NPU world mostly abolishes runtime allocation — the memory plan is a compile-time artefact, and what remains at runtime is buffer hand-off, not allocation policy — **and that abolition is itself the lesson for MimirAlloc's home territory**: the more of a workload's allocation pattern can be moved from runtime decision to plan (ggml's graph allocator in `memory/gpu-memory-internals.md` is the GPU-side proof), the less any runtime allocator, however good, is asked to do. MimirAlloc's arena/pool disciplines are the same instinct, kept honest on the host side; no stronger connection exists, and this dossier does not invent one.

---

## 8. Sources

All sources accessed **2026-11-15**. Vendor figures are vendor figures. Where a claim in the text rests on a secondary reproduction rather than the primary document, the entry says so.

- **[S1]** M. Horowitz, "Computing's Energy Problem (and What We Can Do About It)," ISSCC 2014 plenary, DOI 10.1109/ISSCC.2014.6757323. Record via OpenAlex: https://api.openalex.org/w1999085092
- **[S2]** "Can quantum computers fix AI's energy problem? An audit from the matrix up" — secondary audit reproducing Horowitz's 45 nm figures (FP32 multiply ~3.7 pJ; 32-bit DRAM read ~640 pJ; ~170× ratio, and the ratio's growth at modern nodes): https://www.jos-quantum.de/blog/quantum-computing-for-ai/
- **[S3]** T. Hoefler et al., data-centric programming keynote slides (ETH Zürich), reproducing Horowitz ISSCC 2014 cache/DRAM energies (L1 ~10 pJ, L2 ~100 pJ, DRAM ~1.3 nJ per 64-bit pair): https://spcl.inf.ethz.ch/Publications/.pdf/ciuk20-keynote.pdf
- **[S4]** M. Horowitz, "Why Design Must Change: Rethinking Digital Design" seminar slides (EPFL mirror) — DRAM ~1 nJ/32-bit word, I/O share of system power: https://si2.epfl.ch/~demichel/si.epfl.ch/files/content/sites/si/files/shared/Seminar_Horowitz161209.pdf
- **[S5]** Y.-H. Chen, J. Emer, V. Sze, "Eyeriss: A Spatial Architecture for Energy-Efficient Dataflow for Convolutional Neural Networks," ISCA 2016, DOI 10.1109/ISCA.2016.40 — full text read: https://www.eecg.toronto.edu/~moshovos/000/lib/exe/fetch.php?media=wiki:aca2017:eyeriss-isca.pdf
- **[S6]** J. Emer, V. Sze, Y.-H. Chen, "Tutorial on DNN" / DNN hardware survey slides, MICRO 2016 tutorial (Eyeriss project) — dataflow taxonomy teaching form (WS/OS/NLR/RS, named exemplars): https://eems.mit.edu/wp-content/uploads/2016/11/Tutorial-on-DNN-4-of-9-DNN-Accelerator-Architectures.pdf
- **[S7]** V. Sze, Y.-H. Chen, T.-J. Yang, J. Emer, "Efficient Processing of Deep Neural Networks: A Tutorial and Survey," *Proceedings of the IEEE* 105(12), Dec 2017, DOI 10.1109/JPROC.2017.2761740; arXiv:1703.09039: https://arxiv.org/abs/1703.09039
- **[S8]** MIT 6.5930/6.5931 Hardware Architectures for Deep Learning, Lecture 12 slides (Sze & Emer, 2023) — taxonomy incl. input-stationary, OS variants, RS: https://www.slideshare.net/slideshow/l12pdf-257183693/257183693
- **[S9]** Georgia Tech MAESTRO, "Introduction to Dataflow for Deep Learning Accelerator Design" — stationary definition, IS/WS/OS access-count model: https://maestro.ece.gatech.edu/docs/build/html/_downloads/49f57cda7db8667e0cea0159084a5dcf/2_DataflowAnalysis.pdf
- **[S10]** Y.-H. Chen, T. Krishna, J. Emer, V. Sze, "Eyeriss: An Energy-Efficient Reconfigurable Accelerator for Deep Convolutional Neural Networks," IEEE JSSC 2017 (ISSCC 2016 chip) — 168 PEs, 35 fps AlexNet at 278 mW, 0.0029 DRAM access/MAC: https://www.rle.mit.edu/eyeriss-an-energy-efficient-reconfigurable-accelerator-for-deep-convolutional-neural-networks/
- **[S11]** "Systolic Array Data Flows for Efficient Matrix Multiplication in Deep Neural Networks" (SCALE-Sim-based study) — WS/IS/OS as GEMM mappings, TPU as WS exemplar: https://arxiv.org/html/2410.22595v1
- **[S12]** N. P. Jouppi et al., "In-Datacenter Performance Analysis of a Tensor Processing Unit," ISCA 2017 — full text read (256×256 array, 92 TOPS, 28 MiB on-chip, Unified Buffer, systolic rationale, ridge point ~1,350 ops/byte, dense-only decision, utilisation counters): http://lists.csail.mit.edu/pipermail/supertech/attachments/20170410/82d01fa7/attachment-0001.pdf
- **[S13]** Hailo, "Hailo-8 AI Processor" product brief (official) — 26 TOPS, 2.5 W typical, "does not require external memory," structure-driven dataflow architecture, Dataflow Compiler, HailoRT, multi-stream/multi-model, host architectures: https://hailo.ai/files/hailo-8-product-brief-en/
- **[S14]** Hailo company blog, "DRAM Shortage 2026: Why Edge AI is the Solution" — vendor claim of DRAM-less positioning for Hailo-8/8L (marketing claim, cited as such): https://hailo.ai/blog/dram-shortage-in-edge-ai-doing-more-with-less/
- **[S15]** EE Times Asia, "Details of Secretive Startup's AI Accelerator Emerge" (2019) — reporting of Hailo's distributed compute/memory/control and per-layer compiler mapping explanation: https://www.eetasia.com/details-of-secretive-startups-ai-accelerator-emerge/
- **[S16]** Hailo, "Hailo-10H" product page (official) — 40 TOPS INT4 / 20 TOPS INT8, 2.5 W typical, direct DDR interface, LPDDR4/4X, LLM/VLM/Stable Diffusion positioning, Dataflow Compiler, LLM whitepaper link: https://hailo.ai/products/ai-accelerators/hailo-10h-ai-accelerator/
- **[S17]** Apple Neural Engine at public-fact level — synthesis of secondary explainers checked against Apple's public positioning (Core ML as sole access path; M4 38 TOPS vendor figure; no public ISA/memory documentation). Representative sources read: https://samaustinai.com/2026/09/apple-neural-engine-explained and https://blog.obsidianridgelabs.com/blog/apple-neural-engine-explained — **no Apple primary architecture document exists publicly; ANE internals are marked unverifiable in §5.6.**
- **[S18]** Qualcomm support forum (official), "In today's Snapdragon SoCs, is the Hexagon DSP still a standalone block, or is it fully integrated as part of the NPU / AI Engine?" — fused scalar/vector/tensor Hexagon NPU as part of the AI Engine: https://mysupport.qualcomm.com/supportforums/s/question/0D5dK00000CTM9dSAH/in-todays-snapdragon-socs-is-the-hexagon-dsp-still-a-standalone-block-or-is-it-fully-integrated-as-part-of-the-npu-ai-engine
- **[S19]** Reporting of Qualcomm's September 2026 Hexagon NPU material (OnQ post by V. Sukumar) — Element Accelerator, 50% larger shared memory, MoE positioning (vendor claims, cited as such): https://AI.INFO/news/qualcomm-launches-phone-chips-local-30b-ai-models
- **[S20]** OpenVINO documentation, "NPU Device" (2023.3 edition, for the static-shapes and blob-compatibility statements in their clearest form) — static shapes only on NPU; offline compilation/blob import for development; blob compatibility across versions not guaranteed: https://docs.openvino.ai/2023.3/openvino_docs_OV_UG_supported_plugins_NPU.html
- **[S21]** ONNX Runtime documentation, "QNN Execution Provider" — QNN graph construction, HTP backend, quantised-model requirement, no dynamic shapes, context-binary dump/deploy flow: https://onnxruntime.ai/docs/execution-providers/QNN-ExecutionProvider
- **[S22]** OpenVINO documentation, "NPU Device" (2026 edition) — compiler converts IR to proprietary format and schedules layer execution and memory transactions on NPU submodules; model caching: https://docs.openvino.ai/2026/openvino-workflow/running-inference/inference-devices-and-modes/npu-device.html
- **[S23]** OpenVINO documentation, "OpenVINO GenAI on NPU" — LLM export settings for NPU, CACHE_DIR / weightless-blob caching, EXPORT_BLOB/BLOB_PATH ahead-of-time compilation: https://docs.openvino.ai/nightly/openvino-workflow-generative/inference-with-genai/inference-with-genai-on-npu.html
- **[S24]** ONNX Runtime GenAI tutorial, "Run SLMs on Snapdragon devices with NPUs" — packaged model assets enumerated as Qualcomm context binaries + metadata + ONNX wrappers: https://ONNXRuntime.ai/docs/genai/tutorials/snapdragon.html

**Programme record (not a web source):** §5.4 rests solely on Volmarr's programme records as summarised in this dossier's commission: the Hailo text-generation attempt's outcome, and Volmarr's correction of 2026-10-19 (catalogue/compile path as a software fact, not a hardware verdict), held in the programme's memory. No public source is claimed for it, and no detail beyond the lesson has been added.

**What could not be verified today, collected:** Hailo-8 on-chip SRAM capacity from a Hailo primary document (§5.1); Hailo-10H LLM decode throughput at any stated batch/context from material read (§5.5 — the vendor whitepaper exists and was not read); Apple Neural Engine internals of any kind from a primary source (§5.6); Hailo context-switch mechanics for multi-model execution (§5.1). Each is flagged at its point of use rather than filled in.

*— End of dossier OR-6 D1–D4. Banked for the Ollama Research Forge corpus, research/memory/, 2026-11-15.*
