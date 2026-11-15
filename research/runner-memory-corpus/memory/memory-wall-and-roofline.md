# The Memory Wall & the Roofline Method

**Dossier OR-6 (Memory), Dossier 2 of 2 — Ollama Research Forge**
**Date: 2026-11-15**
**Status: Public-literature summary, in our own words. Every load-bearing claim is tied to a source actually read in this pass (full citations in §6). Claims are reported with their context; our own application reasoning is labelled as such, and speculation is marked.**

---

## 1. The memory wall — the original argument

### 1.1 Wulf & McKee (1995): diverging exponentials

Wm. A. Wulf and Sally A. McKee, "Hitting the Memory Wall: Implications of the Obvious", *ACM SIGARCH Computer Architecture News* 23(1):20–24, March 1995 (the note itself is dated December 1994, University of Virginia, Computer Science Report CS-94-48; DOI 10.1145/216585.216588). *[Read in full in this pass: the paper's own PDF.]*

Their argument, in our words:

- Everyone already "knew" that microprocessor speed improves faster than DRAM speed. What had been missed is what *diverging exponentials* do over time: "each is improving exponentially, but the exponent for microprocessors is substantially larger than that for DRAMs. The difference between diverging exponentials also grows exponentially" — so a gap that is merely an annoyance today becomes the whole story downstream.
- They make it concrete with the average memory access time, `t_avg = p·t_c + (1−p)·t_m`, where `t_c` is cache access time, `t_m` is DRAM access time, and `p` is the cache hit probability. Their assumptions are deliberately conservative and deliberately generous to the optimist: cache speed scales with the processor; the cache is *perfect* (no conflict or capacity misses — only compulsory misses, at a rate of 1% or less); DRAM performance improves at **7% per year** (cited to Hennessy & Patterson, 1990); microprocessor performance improves at **80% per year** (Baskett's 1991 estimate).
- Even so, the arithmetic is merciless: under those assumptions the average cost per memory access becomes **1.52 cycles in 2000, 8.25 cycles in 2005, and 98.8 cycles in 2010**. With roughly 20% of instructions referencing memory (they take the lower figure from Hennessy & Patterson's 20–40%), the wall is *defined* as the point where `t_avg` exceeds 5 instruction times: "At that point system performance is totally determined by memory speed; making the processor faster won't affect the wall-clock time to complete an application."
- The conclusion is robust to the starting numbers, and they say so: changing the miss/hit cost ratio (they explore both 4 and 16) and the hit rate (even 99.8%) moves the date, not the outcome — the 5-cycles-per-access wall arrives in ~5 years at a 90% hit rate, within the decade at 99%, in 11–12 years even at 99.8%. "In 10-15 years each memory access will cost, on average, tens or even hundreds of processor cycles. Under each scenario, system speed is dominated by memory performance."
- And the escape hatches do not work, by construction of the thought experiment: "We have already assumed a perfect cache, so a bigger/smarter one won't help. We're already using the full bandwidth of the memory, so prefetching or other related schemes won't help either." Every technique they knew of "provide[s] one-time boosts to either bandwidth or latency. While these delay the date of impact, they don't change the fundamentals."

Two things about the paper are worth carrying forward precisely:

1. **It is a latency-framed argument.** The 1995 note reasons about average *access time* — how long the processor waits — not yet about *bandwidth* as the separately binding resource. Later work (McCalpin, §1.3) criticises exactly this conflation.
2. **It is honest about being a trend argument.** "Our prediction of the memory wall is probably wrong too — but it suggests that we have to start thinking 'out of the box'." The claim that survives is not any specific year's number; it is the structural claim that when two exponentials diverge, the slower one eventually sets the system's speed.

### 1.2 McKee's retrospective (2004): did we hit it?

Sally A. McKee, "Reflections on the Memory Wall", *Proceedings of CF'04*, Ischia, Italy, April 2004. *[Read in this pass via the archived PDF.]*

- McKee revisits the note nine years on and asks the question directly: "Are we hitting the Memory Wall? And if so, for what types of applications?" Her answer, as reported in the paper: **yes, for many types of applications** — with the workload-dependence in the sentence doing real work. The wall is not a single date for all programs; it binds where the working set and access pattern defeat the cache hierarchy.
- She grounds the trend in McCalpin's STREAM measurements (§1.3): on the STREAM record, peak MFLOPS had been increasing at about **50% per year**, whereas (sustained) bandwidth had generally been increasing at about **35% per year** — and the highest-performing machine at only ~15%. The gap in the *measured* record is smaller than the 1995 note's 80%-vs-7% framing, but it points the same way, and it is a gap in *delivered* numbers, not vendor peaks.
- The retrospective's framing point for our purposes: the interesting question stopped being "will memory dominate?" and became "for *which* workloads, *which* level of the hierarchy, and *which* resource — latency or bandwidth — binds first?" That is exactly the question the roofline model (§2) was built to answer per-kernel.

### 1.3 McCalpin: machine balance, STREAM, and the latency/bandwidth distinction

John D. McCalpin, "Memory Bandwidth and Machine Balance in Current High Performance Computers", *IEEE Technical Committee on Computer Architecture Newsletter*, Dec 1995 (revised to 19 Sep 1995); and the STREAM benchmark (introduced 1991; `www.cs.virginia.edu/stream`). *[Read in this pass: the paper via ResearchGate's copy, McKee 2004's STREAM discussion, McCalpin's SC16 invited-talk coverage in HPCwire (7 Nov 2016), and McCalpin's "Perspectives on the 'Memory Wall'" talk slides.]*

- **Machine balance** is McCalpin's name for the ratio that decides everything: how much computation a machine offers per unit of memory traffic it can sustain. His 1995 survey measured *sustainable* bandwidth — "the sustainable data transfer rates for uncached unit-stride vector operations" — across uniprocessors, vector machines, shared- and distributed-memory systems, and analysed algorithms against that delivered rate, not against theoretical peaks.
- **STREAM** is the instrument: a small synthetic benchmark timing four long-vector operations (Copy, Scale, Add, Triad) and reporting the *sustained* memory rate ordinary programs can achieve. McCalpin's SC16 summary (as reported by HPCwire) stresses why it mattered: it got "vendors to pay attention to sustained, rather than peak, bandwidths", and its ~1,100 contributed results document the changing balance between compute, latency and bandwidth over 25 years.
- **The critique of Wulf & McKee** (from McCalpin's "Perspectives" talk): the 1994/95 note "did not distinguish latency & bandwidth — this is crucial to understanding 'the wall' for real applications", and it did not consider application size, run-time scaling, or cache-size scaling. Both distinctions matter practically: a workload can be latency-bound (dependent, unpredictable accesses; too little concurrency to hide the wait) while using little bandwidth, or bandwidth-bound (streaming, predictable, fully pipelined) while being insensitive to latency. They need different fixes, and confusing them wastes engineering.
- The modern form of the problem, in McCalpin's telling: DRAM latency measured in CPU clocks grew from ~14 clocks (1991) to ~400 clocks (2003) in his talk's figures, so sustaining even a fixed fraction of peak bandwidth requires an order of magnitude more *concurrent* memory references in flight. Concurrency — threads, prefetch distance, independent streams — is therefore part of the bandwidth story, not a separate topic.

**The line so far, in one sentence:** Wulf & McKee proved the gap must eventually dominate; McCalpin gave the field a way to *measure* the delivered side of the gap and insisted latency and bandwidth be kept apart; McKee confirmed the wall arrives per-workload, not all at once. What was still missing was a per-kernel method for saying, before optimising, *which* ceiling a given piece of code will hit. That is the roofline.

---

## 2. The roofline model (Williams, Waterman & Patterson, 2009)

Samuel Williams, Andrew Waterman, and David Patterson, "Roofline: An Insightful Visual Performance Model for Multicore Architectures", *Communications of the ACM* 52(4):65–76, April 2009. DOI 10.1145/1498765.1498785. *[Read in this pass: the CACM paper itself (Auburn/Duke copies of the published text).]*

### 2.1 The model

- **Operational intensity.** The paper's central quantity: *operations per byte of DRAM traffic* — deliberately named "operational intensity" rather than "arithmetic intensity" or "machine balance", because the operations need not be floating-point (they can be integer ops, comparisons, etc.). Crucially, the bytes counted are the traffic **between the caches and memory** — i.e. after the cache hierarchy has filtered what it can. A kernel's intensity is therefore a property of the kernel *as run on a hierarchy*, not just of its source code: better locality raises the intensity by reducing DRAM bytes for the same operations.
- **The bound.** Attainable performance is the minimum of two ceilings:

  > **Attainable GFlops/sec = min( Peak Floating-Point Performance, Peak Memory Bandwidth × Operational Intensity )**

  Plotted on log-log axes (performance vs intensity), the bandwidth term is a 45° slope and the compute term is a flat ceiling; together they look like a roof — hence the name.
- **The ridge point** is the intensity where the two ceilings meet — the minimum operational intensity needed to reach peak compute. **Left of the ridge, a kernel is memory-bound:** its performance rises linearly with intensity, and the only ways to go faster are to use bandwidth better or to move fewer bytes (raise intensity). **Right of the ridge, a kernel is compute-bound:** more bandwidth buys nothing; only more/better compute helps. The paper's worked example (2.2 GHz AMD Opteron X2) spans intensities from 0.25 to 16 Flops/DRAM-byte against a 17.6 GFlops/sec peak — a useful reminder of how *low* the ridge sat on 2009 hardware compared with today's accelerators (see §3.2, where an H100's ridge is ~295 FLOP/byte in BF16 by the same formula).
- **What the model is for.** The paper applies the model to four kernels across four diverse multicore machines to show the working method: measure (or bound) a kernel's intensity and achieved performance, plot it under the machine's roof, and the *gap* and the *side of the ridge* tell you what to fix — locality/bandwidth work on the left, compute work on the right. A kernel sitting far below its own ceiling is an implementation problem; a kernel sitting *on* the bandwidth slope is a hardware-limit fact, and no amount of instruction tuning will move it.

### 2.2 What the roofline does and does not say

- It is an **upper bound**, not a prediction. Real kernels sit below the roof (latency effects, imperfect overlap, instruction mix, occupancy). The distance below the roof is diagnostic information, not model failure.
- In its 2009 form it models **one memory level (DRAM) and one compute ceiling**. Later practice adds ceilings (per-cache-level rooflines, latency ceilings, interconnect roofs), but the discipline is unchanged: name the resource, measure its delivered peak, compute the intensity, locate the kernel.
- It says nothing by itself about **capacity** (whether the working set fits at all) or **latency-bound** small kernels. Those need their own measurements — a point that matters directly for small-GPU inference (§4.1).

---

## 3. The modern reading: LLM inference through the roofline

### 3.1 The survey that applied it: Yuan et al. (2024)

Zhihang Yuan et al., "LLM Inference Unveiled: Survey and Roofline Model Insights", arXiv:2402.16363 (submitted 26 Feb 2024; v6, 1 May 2024). *[Read in this pass: the arXiv record/abstract, plus secondary reports quoting its measured tables — the per-layer intensity figures below are reported as that paper's Table 1 values via those reports; the abstract and framing are from the paper itself.]*

The paper's contribution, per its abstract, is a framework "based on roofline model for systematic analysis of LLM inference techniques" that "identifies the bottlenecks when deploying LLMs on hardware devices and provides a clear understanding of practical problems, such as **why LLMs are memory-bound, how much memory and computation they need, and how to choose the right hardware**", analysing compression (distillation, quantization), algorithmic improvements and system techniques by their effect on memory access vs computation.

Its measured centrepiece (LLaMA-2-7B on an NVIDIA A6000, as reported from its Table 1): the *same* layer has opposite character in the two phases of inference — e.g. the query projection measures **~1024 OPs/byte in prefill (compute-bound)** vs **~1 OP/byte in decode (memory-bound)**; the feed-forward gate projection ~1215 OPs/byte in prefill vs ~1 OP/byte in decode. Its conclusion for decode is quoted verbatim in the secondary literature: "in the decode stage, all computations are memory-bound, resulting in performance significantly below the computational capacity of the GPU's computation units."

### 3.2 Why: GEMM vs GEMV, in arithmetic-intensity terms

The phase split is not an implementation quirk; it follows from the shapes, and it can be derived in a few lines (this derivation is standard and is stated in the same form across the sources read — Pope et al. 2023 and the DistServe line via the decode reference entry; the worked AI≈B form via the inference-performance references read in this pass):

- **Prefill** processes the whole prompt (P tokens) in parallel. Each weight matrix is read once and used for all P token positions: a matrix–matrix product (**GEMM**). FLOPs per weight byte scale with P, so intensity is high (hundreds to thousands of FLOP/byte in the reports read) — comfortably right of any modern ridge point. **Prefill is compute-bound.** Its user-visible metric is time-to-first-token (TTFT).
- **Decode** generates one token per step per sequence. The activation is a single vector; the same weight matrices are now multiplied by one vector (**GEMV**). Each weight is read, used for ~one multiply-add, and discarded: **~2 FLOPs per parameter against 2 bytes per FP16 parameter ≈ 1 FLOP/byte** at batch 1. Against a modern ridge point — e.g. an H100 SXM's ~989 TFLOP/s BF16 ÷ 3.35 TB/s ≈ **295 FLOP/byte** (vendor peaks as reported in the references read) — decode at batch 1 sits *two-plus orders of magnitude* left of the ridge. **Decode is memory-bandwidth-bound**, and its ceiling has the simple closed form:

  > **tokens/sec per sequence ≲ memory bandwidth ÷ bytes that must be read per token**
  > where bytes-per-token ≈ active weight bytes + KV-cache bytes read that step.

  A worked example from the sources read: a 70B model in FP16 (~140 GB of weights) on a 3.35 TB/s H100 tops out near **~20 tokens/sec per sequence** before any optimisation — not because the FLOPs are lacking, but because 140 GB must stream through the chip for every single token.
- **The KV cache is part of the per-token traffic, and it grows.** Every decode step reads the keys/values of all previous tokens and appends one more token's worth. KV bytes per token are fixed by architecture (layers × KV heads × head dim × 2 × bytes-per-element — cf. Dossier 1, where our own harness computed 45,056 B/token for TinyLlama-1.1B in f32), so the KV term is small for short contexts and increasingly material for long ones — taxing, as one source puts it, "the phase that is already starved for bandwidth". Long-context decode is therefore *more* bandwidth-bound, not less, and its ceiling falls as context grows even with weights unchanged.

### 3.3 Why batching changes the intensity — and what it does not change

Batching is the one lever that moves decode's intensity itself, which is why it dominates serving-system design:

- With **B sequences decoded together**, the weight matrices are read **once per step** and used for B tokens: FLOPs per step ≈ 2·N·B (N = parameters) against ≈ the same weight bytes, so **intensity ≈ B** (in the FP16 form above; the general statement is AI scales with B until other terms dominate). Aggregate throughput (tokens/sec across all sequences) therefore climbs **near-linearly in B** while decode remains on the bandwidth slope — each weight byte fetched now yields B tokens instead of one.
- This continues **until** one of three limits binds: the ridge point is reached (B on the order of the ridge — ~150–300 for H100-class parts in the reports read — at which point decode becomes compute-bound and further batching buys little); KV-cache **capacity** runs out (each sequence's KV must stay resident; capacity, not bandwidth, becomes the wall); or per-sequence latency SLOs forbid larger batches. Continuous (iteration-level) batching — introduced by Orca and now standard in vLLM / TensorRT-LLM / SGLang per the sources read — exists to keep B high in practice by admitting/finishing sequences at token granularity instead of waiting for the slowest sequence in a static batch; chunked prefill and prefill/decode disaggregation (DistServe) exist because mixing a compute-bound prefill into a decode batch lengthens every decode step in that batch.
- **What batching does not change:** per-sequence latency at batch 1, the bytes-per-token floor for a single stream, or prefill's compute-bound character. A single-user local workload (one stream, interactive) lives at B≈1 by definition — which is precisely the regime of §4.1. For that regime the remaining levers are the ones that cut *bytes*: **quantization** (fewer bytes per weight → proportionally higher decode ceiling on the same bandwidth; this is why INT4/Q4-class formats dominate local inference), keeping weights resident in the fastest memory that fits them, and reducing KV bytes (fewer KV heads / GQA, KV quantization, shorter effective context).

### 3.4 Latency vs bandwidth, one more time

McCalpin's distinction (§1.3) survives intact into the LLM era and explains a common confusion: at very small scale (tiny models, small GPUs, short contexts), a decode step's time can be dominated by **fixed costs** — kernel launches, synchronisation, host-side scheduling — rather than by streaming bytes. Such a step is latency/overhead-bound, sits *below* the bandwidth slope on a roofline plot, and will not speed up proportionally with quantization. The roofline tells you this too — but only if you plot the *measured* point instead of assuming it lies on the slope. (This paragraph is our synthesis of McCalpin's distinction applied to the small-model regime; it is labelled as synthesis, not as a claim from any single cited source.)

---

## 4. Applicability

### 4.1 Ollama on a 6 GB GPU

*[This section is our analysis, applying the cited method to the stated target. No 6 GB-GPU measurement was taken for this dossier; any specific tok/s figure for such a card would be speculation and none is asserted.]*

What the method predicts and prescribes for a single-user Ollama deployment on a ~6 GB-VRAM GPU:

1. **Decode will be bandwidth-bound; plan around bytes, not FLOPs.** At B=1 the ceiling is `sustained bandwidth ÷ (active weight bytes + KV read per step)`. The practical consequences: (a) the model's *quantized size on disk ≈ its active bytes* is the first-order predictor of single-stream tok/s — a Q4 build of a given model should decode roughly (FP16 bytes ÷ Q4 bytes) ≈ 3–4x faster than its FP16 form on the same card, *if* the step is truly on the bandwidth slope and dequantisation does not become the new ceiling; (b) a faster-FLOPs card with the same memory system will **not** decode faster; (c) prefill (prompt processing) will still feel compute-bound — long prompts will be slow in proportion to compute, not bandwidth, and conflating the two phases in one "speed" number hides both.
2. **Capacity is the first wall on 6 GB, bandwidth the second.** Weights + KV cache + runtime buffers must fit in VRAM. If they do not, layers spill to host RAM over PCIe and the effective "bandwidth" for the spilled fraction collapses to the interconnect's — the roofline still applies, but with a much lower slope for those bytes, and measured tok/s falls off a cliff rather than along a slope. The roofline discipline here is accounting: enumerate the bytes (weights by layer placement, KV = per-token KV bytes × context length, buffers) *before* running, and treat "fits entirely in VRAM" as a precondition for any bandwidth-based prediction.
3. **Measure the card's delivered bandwidth, not its spec sheet.** Following McCalpin/STREAM: run a STREAM-like triad (or the engine's own large-copy/GEMV microbenchmark) on the actual card and use the *sustained* figure as the roof. Vendor peak bandwidth is an upper bound on the upper bound.
4. **Report decode as tok/s at a stated context length and batch=1**, alongside the implied achieved bandwidth (tok/s × bytes/token). If implied bandwidth is far below the measured sustained bandwidth, the gap — not the hardware — is the finding (overheads, dequant cost, kernel quality, spill). If it is close, the run is at the wall and only fewer bytes or more bandwidth will help.

### 4.2 Aesir

*[Our analysis, applying the cited method to Aesir's known shape — a from-scratch engine targeting, among other hosts, AMD Strix Halo and ARM edge devices, with an accelerator-first law. Aesir-specific measurements cited are from Dossier 1's records.]*

1. **Aesir's decode kernels should be designed and graded as GEMV/bandwidth kernels.** Any decode design review that leads with FLOP counts is answering the prefill question. The grading sheet for a decode kernel is: bytes moved per token (weights touched + KV read), achieved GB/s vs the host's measured sustained GB/s, and distance below the bandwidth slope.
2. **Use the host facts already banked.** The MimirAlloc Z13 campaign measured the Strix Halo host directly: single-CCD bandwidth plateau 61.8 GB/s at 4 threads, 1 core 38.2 GB/s, peak 112.76 GB/s, cross-CCD latency 103 ns vs intra-CCD ~32 ns (Dossier 1, §4.3). Those are CPU-side figures; the GPU/NPU paths need their own STREAM-equivalents before any Aesir roofline is drawn for them. Drawing the roof from vendor peaks would repeat, in modern dress, the error STREAM was created to correct.
3. **Quantization is Aesir's decode lever; compression work should be graded in bytes.** Teaching the engine to *write* packed forms (the compression-school direction) pays off exactly insofar as packed bytes-per-token fall and the dequant path stays cheaper than the bandwidth it saves. Grade packed-vs-original by achieved tok/s *and* implied bandwidth, with coherence/parity graded separately — a faster-but-wrong decode is not on any roofline; it is off the chart entirely.
4. **KV placement is a roofline decision.** Per-CCD / per-memory-tier KV placement, KV element size, and context-length policy all change bytes-per-token-read. They should be evaluated as movements of the decode point (fewer bytes → higher ceiling at the same slope), with the L-006-style lifecycle (grow during decode, return everything at teardown) as the correctness template.

### 4.3 How the roofline method should discipline our own benchmarking

A standing protocol, distilled from the sources above and from the MimirAlloc campaigns' measurement law (Dossier 1). This is the section to hold every future Ollama/Aesir benchmark — ours included — against.

**What to measure, every time:**
1. **The machine's roofs, measured on the machine:** sustained memory bandwidth (STREAM-triad or equivalent) for each memory tier in play (VRAM, host RAM, per-CCD where relevant); peak compute only if prefill/compute claims are being made. Record governor/clocks, contention and co-tenants — a wall measured under contention is not a baseline (the Z13 logs void or flag contended runs for exactly this reason).
2. **The workload's bytes:** model file size *and* active bytes (they differ under spill), KV bytes/token × context length, batch size, prompt length. Without the byte count, a tok/s number cannot be converted into the only form that transfers between machines: **achieved bandwidth and % of sustained peak**.
3. **Phases separately:** prefill (tokens/sec or TTFT at a stated prompt length) and decode (tok/s or time-per-output-token at a stated context length and batch) are different regimes with different roofs. A single blended "tok/s" over a short generation mostly measures whichever phase dominated the stopwatch.
4. **Distributions and conditions, not single runs:** medians over repeated runs, spread shown, drift checks between identical legs (the Z-004 protocol-gate pattern), machine state recorded in the run file. One run is an anecdote; the MimirAlloc rule — medians, alternating legs, checksums equal — applies verbatim.

**What a claimed tok/s does and does not prove:**
- It **does** prove: that *this* binary, model build, context, batch and machine state produced that rate once (or, with repetitions, typically). Converted to implied bandwidth and compared with the measured roof, it can prove a run is *at the wall* (nothing left without fewer bytes / more bandwidth) or *below the wall by a stated gap* (implementation headroom exists, sized by the gap).
- It **does not** prove: that the engine is "fast" in general (a small model at short context on a wide card says nothing about a large model at long context); that a change *caused* an improvement (without an A/B under the protocol above, drift and contention are equally good explanations — cf. the Z-054 glibc leg that had to be DRIFT-REJECTed); that compute is the bottleneck or the saviour (at B=1 decode it is neither); or anything at all about correctness/coherence, which tok/s does not measure.
- **Red flags that void a tok/s claim on sight:** batch/context/quant unstated; prompt-processing tokens folded into generation rate; comparison across different byte counts presented as an engine comparison (a Q4 number vs an FP16 number is primarily a *bytes* comparison); peak vendor bandwidth used as the roof; a single run on a shared machine.

**The one-line discipline:** *Never report a speed without its bytes, its phase, its machine state, and its distance from a measured roof.*

---

## 5. Summary in five sentences

Wulf & McKee showed in 1995 that diverging processor/DRAM exponentials must eventually make memory, not compute, set system speed — and that no cache or prefetch trick changes the fundamentals. McCalpin supplied the measurement culture (sustained bandwidth, machine balance, latency ≠ bandwidth) and McKee confirmed the wall binds per-workload. Williams, Waterman & Patterson turned that into a per-kernel method: compute operational intensity, draw the two ceilings, and the side of the ridge point tells you which resource to spend on. For LLM inference the method yields the field's central fact — prefill is a compute-bound GEMM, decode is a bandwidth-bound GEMV at ~1 FLOP/byte for batch 1, and batching is powerful precisely because it multiplies decode's intensity while single-stream local inference cannot use it. For our work the roofline is therefore not background reading but a benchmarking law: measure the roof on the machine, count the bytes, separate the phases, and let no tok/s claim travel without them.

---

## 6. Sources (all read in this pass, 2026-11-15)

1. Wm. A. Wulf & Sally A. McKee, "Hitting the Memory Wall: Implications of the Obvious", *ACM SIGARCH Computer Architecture News* 23(1):20–24, March 1995 (note dated Dec 1994; UVA CS Report CS-94-48). DOI 10.1145/216585.216588. Read in full: http://ciar.org/ttk/wall.pdf — source of the 7%/yr DRAM, 80%/yr processor, 1.52/8.25/98.8 cycles (2000/2005/2010), 5-cycles-per-access wall definition, and the "perfect cache / full bandwidth" passage, all quoted or closely paraphrased in §1.1.
2. Sally A. McKee, "Reflections on the Memory Wall", *Proc. CF'04*, Ischia, April 2004. Read via archived PDF (web.archive.org copy of the Cornell-hosted paper) — source of the per-workload verdict and the STREAM-trend figures (~50%/yr MFLOPS vs ~35%/yr bandwidth) in §1.2.
3. John D. McCalpin, "Memory Bandwidth and Machine Balance in Current High Performance Computers", *IEEE TCCA Newsletter*, Dec 1995 (rev. 19 Sep 1995) — read via ResearchGate copy; John D. McCalpin, "Perspectives on the 'Memory Wall'" (talk slides) — source of the latency-vs-bandwidth critique; HPCwire, "McCalpin Traces HPC System Balance Trends" (7 Nov 2016, SC16 invited-talk interview) — source of the STREAM purpose/history statements. Together: §1.3.
4. Samuel Williams, Andrew Waterman & David Patterson, "Roofline: An Insightful Visual Performance Model for Multicore Architectures", *Communications of the ACM* 52(4):65–76, April 2009. DOI 10.1145/1498765.1498785. Read: published-text copies hosted by Auburn University and Duke University — source of the operational-intensity definition, the attainable-performance formula (quoted in §2.1), the ridge point, and the Opteron X2 worked example.
5. Zhihang Yuan et al., "LLM Inference Unveiled: Survey and Roofline Model Insights", arXiv:2402.16363 (Feb–May 2024). Read: arXiv abstract page (framing quoted in §3.1); per-layer intensity values (~1024 and ~1215 OPs/byte prefill vs ~1 OP/byte decode, LLaMA-2-7B on A6000) and the decode conclusion quote as reported from its Table 1 in secondary coverage read in this pass — flagged here as reported-via-secondary, not re-read from the paper's PDF tables.
6. Reece Pope et al., "Efficiently Scaling Transformer Inference", *Proc. MLSys* 5, 2023 (arXiv:2211.05102), and the DistServe prefill/decode split — as cited and summarised in the decode reference entry read in this pass (ngpestelos.com/reference/decode, updated 2026-09-11): source of the GEMV/batch framing cross-check in §3.2–3.3.
7. Supporting practitioner/reference reports read in this pass for worked numbers (H100 ridge ≈295 FLOP/byte from 989 TFLOP/s ÷ 3.35 TB/s; AI≈B for batched decode; 70B FP16 ≈140 GB → ~20 tok/s ceiling example; continuous batching attribution to Orca and adoption in vLLM/TensorRT-LLM/SGLang): frankk.site "LLM Inference Speed and the Memory Hierarchy"; blog.sumedhkhodke.com "Prefill vs Decode"; the Vanta inference-performance skill page (github.com/jpoindexter/vanta). These are secondary sources and are used only for arithmetic illustrations whose inputs (vendor peaks) they state explicitly — not as primary evidence for any historical claim.
8. SK hynix Newsroom, "The real bottleneck: Data, not compute" (AI Ecosystem series) — corroborating citation of the Wulf & McKee reference and the ~60%/yr vs ~7%/yr popular framing; not relied on for any number in §1.1 (the paper itself governs).

**Not relied on:** search-result snippets that could not be opened, and any source dated after this dossier's evidence pass except as explicitly noted. Where a figure comes from a secondary report of a primary table (item 5), the text says so at the point of use.

*End of Dossier 2 — 2026-11-15.*
