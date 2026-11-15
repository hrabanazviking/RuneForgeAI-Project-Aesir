# Sarathi-Serve — Taming Throughput-Latency Tradeoff in LLM Inference with Sarathi-Serve

## 1. Full citation

- **Title:** Taming Throughput-Latency Tradeoff in LLM Inference with Sarathi-Serve
- **Authors:** Amey Agrawal, Nitin Kedia, Ashish Panwar, Jayashree Mohan, Nipun Kwatra, Bhargav S. Gulavani, Alexey Tumanov, Ramachandran Ramjee
- **Affiliations (as listed in the paper):** Georgia Institute of Technology (Agrawal — work partly done during an internship at Microsoft Research India; Tumanov); Microsoft Research India (Kedia, Panwar, Mohan, Kwatra, Gulavani, Ramjee)
- **Venue / year:** 18th USENIX Symposium on Operating Systems Design and Implementation (OSDI '24), Santa Clara, CA, USA, 10–12 July 2024, pp. 117–134. ISBN 978-1-939133-40-3
- **Link:** https://www.usenix.org/conference/osdi24/presentation/agrawal (open-access proceedings page, PDF and BibTeX)
- **arXiv:** arXiv:2403.02310 [cs.LG] — submitted 4 March 2024; v3 (the version read for this dossier) 17 June 2024 — https://arxiv.org/abs/2403.02310
- **Code (as reported in the paper):** https://github.com/microsoft/sarathi-serve — implemented on top of vLLM
- **Lineage note:** Sarathi-Serve is the serving system built on the same group's earlier SARATHI paper (Agrawal et al., *SARATHI: Efficient LLM Inference by Piggybacking Decodes with Chunked Prefills*, arXiv:2308.16369, 2023), which introduced chunked prefill as a throughput technique. Sarathi-Serve adds the latency/SLO framing, stall-free scheduling as a policy, and the pipeline-parallelism results. The two papers are routinely conflated; cite 2403.02310 for anything about SLOs, capacity, or pipeline bubbles.

## 2. The problem as framed

Every request has two phases with opposite characters. Prefill processes the whole prompt in parallel: high latency per iteration, but it saturates GPU compute. Decode processes one token per request per iteration: low latency, low compute use, memory-bound. Batching is what makes decode efficient, so a serving system wants large batches — but batching forces prefill and decode iterations to interleave, and that interleaving is where both throughput and latency go to die. The paper classifies the schedulers of its day by which phase they sacrifice:

- **Decode-prioritising (request-level batching, e.g. FasterTransformer).** A batch runs its prefills, then decodes to completion; new requests cannot join mid-batch. Ongoing decodes are never disturbed, so time-between-tokens (TBT) is clean — but requests that finish early leave the batch running thin, and throughput collapses.
- **Prefill-prioritising (iteration-level batching, Orca and vLLM).** New prefills are admitted eagerly whenever memory allows, so batches stay full and throughput is high. The cost is the paper's signature phenomenon, the **generation stall**: a single long prefill iteration runs while every ongoing decode waits. The paper's Figure 1 shows stalls lasting *several seconds* in vLLM serving Yi-34B on two A100s over 128 arxiv-summarisation requests. Because prompt length is unbounded, stall length is unbounded — tail TBT is not a distribution the operator controls, it is a hostage of the longest prompt anyone submits.
- **Naive hybrid batching is not the escape.** Putting a full prefill and the running decodes in the *same* iteration (Orca-style selective batching) still charges the whole prefill to that iteration: the paper measures hybrid batching inflating TBT by **up to 28.3×** versus a decode-only batch (§4.2 of the paper). Mixing the phases is necessary but not sufficient; the prefill must also be *cut down to size* before it is mixed in.
- **Pipeline bubbles.** Under pipeline parallelism (PP), iterations of wildly different duration — the paper's example: a 4K-token Falcon-180B prompt takes ≈1,150 ms against ≈200 ms for a decode-only iteration at batch 32 — leave ≈950 ms bubbles in the pipeline. Variable iteration time, not communication, is what makes PP unattractive across commodity networks.

The problem, in one sentence: **the unit of prefill work (a whole prompt) is orders of magnitude larger than the unit of decode work (one token), and any scheduler that admits prefill in whole-prompt units will either stall decodes or idle the GPU.** This is the prefill/decode interference problem in its colocated form — the same interference DistServe and Splitwise attack by moving the phases to different machines (§7).

## 3. Core mechanism in our own words

Two mechanisms, designed as a pair. Neither works alone (the ablation in §4 below is the proof).

**Chunked prefill.** A prompt's prefill is not executed as one iteration. It is split into near-equal chunks, one chunk per iteration, spread over as many iterations as the prompt needs. Two observations make this cheap: prefill compute saturates at modest sequence lengths (the paper's Figure 4: throughput starts saturating around 512 tokens), so a chunk of a few hundred tokens still uses the GPU's arithmetic well; and real prompts are thousands of tokens (evaluation medians 1,730 and 7,059 — §4), so there is plenty of prompt to slice. Chunking does not reduce total prefill work; it changes its *granularity* from "one unbounded iteration" to "a stream of bounded iterations". The known cost is attention re-reads: chunk *k*'s attention must read the KV of all earlier chunks, so earlier chunks' KV is loaded repeatedly. The paper's defence is empirical: prefill attention stays compute-bound even at small chunk sizes, so the extra reads hide under arithmetic — and the measured overhead (§4) is ≤ ~25% at the smallest budget tested and negligible at the largest.

**Stall-free (decode-maximal) batching.** Each iteration is assembled under a fixed **token budget τ** — a cap on total tokens (prefill + decode) in the step — filled in a strict order (the paper's Algorithm 3):

1. **All running decodes first** — one token each. Decodes are never made to wait for admission; they are the batch's foundation, not its filler.
2. **Then the continuation chunk** of any prefill already in progress.
3. **Then new requests**, each admitted only as a chunk sized to whatever budget remains.

Because every iteration's compute is capped by τ, every iteration's duration is bounded, so the worst delay a decode can suffer from co-scheduled prefill work is one budget's worth of compute — independent of how long any prompt in the system is. The paper's name for the underlying opportunity is *arithmetic-intensity slack*: a decode iteration is memory-bound and leaves the GPU's arithmetic units mostly idle, so a bounded slice of compute-bound prefill work can ride in the same iteration at little marginal latency cost, provided the slice is small enough. "Stall-free" therefore does not mean prefills cost decodes nothing; it means the cost is *capped by a knob the operator chose*, rather than set by the longest prompt.

**Choosing τ.** The budget trades TBT against chunking overhead. Smaller τ → tighter TBT bound, more chunks, more re-read and launch overhead, plus a quantisation trap the paper calls out explicitly: GPU matmuls run in tiles, so a chunk size that misses the tile grid wastes whole thread blocks — a chunk of 257 tokens cost **32% more prefill time** than 256 in their measurement. Larger τ → more efficient prefill, looser tail. The paper's method is one-time profiling (they use their Vidur simulator) to find the largest τ whose iteration time still meets the TBT SLO. Under pipeline parallelism there is a second pressure toward uniformity: near-equal iterations are what starve the pipeline bubbles of §2.

**Implementation shape.** Built on vLLM, with paged chunked prefill over FlashAttention v2 / FlashInfer kernels (FlashAttention used for the reported evaluations), NCCL for tensor/pipeline parallelism. The scheduler is a policy layer; no model or kernel changes are required. That portability is why the idea, unlike the system, is everywhere now (§5).

## 4. Reported results — as reported, with hardware and model context

All figures are the paper's own, measured on datacentre hardware. **Nothing below was measured on consumer hardware, at batch size 1, or on a single-user workload.**

**Setup (paper Tables 1–3).** Models: Mistral-7B on 1× A100-80GB; Yi-34B on 2× A100 (TP2); LLaMA2-70B on 8× A40-48GB (TP4-PP2); Falcon-180B on 8× A100 across two nodes (TP4-PP2, 100 Gbps Ethernet between nodes). Azure NC96ads v4 VMs (NVLink within node) except the A40 server. Workloads are request-length traces drawn from two datasets: **openchat_sharegpt4** (median prompt 1,730 tokens, P90 5,696; median output 415) and **arxiv_summarization** (median prompt 7,059, P90 12,985; median output 208), Poisson arrivals, requests over 8,192 / 16,384 total tokens filtered out respectively. The SLO is a cap on **P99 TBT**: strict / relaxed = 0.1 s / 0.5 s (Mistral-7B), 0.2 s / 1 s (Yi-34B), 1 s / 5 s (LLaMA2-70B and Falcon-180B) — defined as 5× / 25× the interference-free decode-iteration time for that model/hardware pair. Token budgets: **512 (strict) and 2,048 (relaxed)** for all models, except LLaMA2-70B relaxed at 1,536 to damp pipeline bubbles. Baselines: vLLM and Orca. "Capacity" throughout means maximum sustainable queries/second under the SLO with median scheduling delay held under 2 s.

**Headline capacity gains (abstract and §5.1):**

- **Mistral-7B, 1× A100: up to 2.6×** the serving capacity of vLLM.
- **Yi-34B, 2× A100: up to 3.7×** vs vLLM under strict SLO (and up to 4.0× vs Orca, same setting, openchat_sharegpt4).
- **LLaMA2-70B, 8× A40 with PP: up to 4.3×** vs vLLM and **6.3×** vs Orca under strict SLO — the pipeline-bubble effect compounding the stall effect.
- **Falcon-180B, TP4-PP2 over 100 Gbps Ethernet: up to 5.6×** end-to-end serving capacity (abstract figure). In the dedicated PP experiment (§5.3), Sarathi-Serve beats vLLM's hybrid TP/PP configuration by **3.6× under strict SLO and 1.48× under relaxed SLO**; cross-node tensor parallelism alone had ~2× higher median TBT than the hybrid layout, which is the paper's argument that chunking is what makes cheap-network PP viable.

**The tradeoff is a dial, not a point (§5.2).** On openchat_sharegpt4: at a strict 100 ms P99-TBT SLO, Mistral-7B with budget 512 reaches **3.5×** vLLM's capacity; at a relaxed 1 s SLO, Yi-34B with budget 2,048 reaches **1.65×**. vLLM's capacity barely moves across its batch-size settings (32/64/128) because stalls, not batch size, cap it under a TBT SLO — the paper's cleanest single demonstration that the stall, not memory or batching breadth, was the binding constraint.

**Ablation — the two mechanisms need each other (paper Table 4).** Yi-34B on 2× A100, token budget 1,024, 128 requests; latencies in seconds:

| Scheduler | openchat P50 TTFT | openchat P99 TBT | arxiv P50 TTFT | arxiv P99 TBT |
|---|---|---|---|---|
| Hybrid batching only (full prefills mixed in) | 0.53 | 0.68 | 3.78 | 1.38 |
| Chunked prefill only (chunks not mixed with decodes) | 1.04 | 0.17 | 5.38 | 0.20 |
| **Sarathi-Serve (both)** | **0.76** | **0.14** | **3.90** | **0.17** |

Read it as the paper intends: hybrid-only keeps TTFT low but lets stalls through (worst TBT); chunked-only bounds TBT but pays TTFT (chunks queue instead of riding with decodes, and chunked prefill is slightly less efficient); only the combination is good on both axes at once.

**Chunking overhead (§5.4.1).** On Yi-34B prefill time, normalised to unchunked: at most **~25% overhead at chunk size 512**, falling with chunk size, and **almost negligible at 2,048**. This is the honest price tag of the whole technique, and it is a *prefill-time* price — paid to buy the TBT bound.

## 5. What it changed in practice

Chunked prefill is the rare systems-paper technique that became invisible infrastructure within two years:

- **vLLM.** Chunked prefill was an opt-in flag in V0; in the V1 engine it is **enabled by default whenever possible and, per the project's forum/docs discussion, cannot be disabled** — the V1 scheduler has no separate prefill/decode phases at all, only a per-step token budget (`max_num_batched_tokens`) filled decode-first, which is Sarathi-Serve's Algorithm 3 generalised (corpus: `runners/vllm.md` §3.1–§3.2, verified there against current docs on 2026-11-15). The vLLM optimisation guide's tuning advice is the paper's τ tradeoff restated: smaller budget → better inter-token latency; larger → better TTFT; >8,192 recommended for pure throughput.
- **SGLang.** Ships chunked prefill as `--chunked-prefill-size` with mixed chunked batches interleaved with decode steps, with the same stated trade (smaller chunks protect inter-token latency; larger chunks maximise prefill throughput) (corpus: `runners/sglang.md` §4.2).
- **The vocabulary stuck.** "Chunked prefill", "token budget", and the decode-first fill order are now the default mental model in serving documentation and in successor systems (DeepSpeed-MII's chunked prefill predates/parallels it; TensorRT-LLM and the disaggregation literature all position themselves relative to it). DistServe's paper explicitly treats chunked prefill as the strongest colocated baseline and argues — fairly — that it *mitigates but cannot eliminate* interference, because chunked prefill is slower than full prefill and still shares the GPU (§6 of this dossier's DistServe sibling).
- **What did not ship:** Sarathi-Serve itself as a standalone server. Like Orca before it, the system was absorbed into the engines rather than adopted as one — the Microsoft repository is a research artifact; the scheduler is the product.

## 6. Applicability, honestly scaled

### (a) Ollama on a 6 GB consumer GPU, single-user chat (RTX 2060 Max-Q class)

First, what does **not** transfer: every multiplier in §4. They are capacity gains in a multi-tenant queue under a tail-latency SLO, measured on A100/A40 fleets. A single user has no queue, no other tenants to protect, and no capacity to multiply. Quoting 2.6× anywhere near the 6 GB runner would be fabrication.

What transfers is the *stall*, because Volmarr's measured pain is exactly a stall, at exactly the paper's scale. The corpus's recorded baseline disease: a **14,712-token prompt re-evaluated in 52.1 s** per turn (Aesir campaign record; see IDEA-LEDGER #1). Size that against the paper's own workload table: 14,712 tokens is ~2.1× the arxiv_summarisation *median* prompt (7,059) and above its *P90* (12,985) — i.e. squarely in the class of prompts that produced multi-second generation stalls in the paper's Figure 1, on hardware (A100) far faster than a 2060. In a colocated step loop, work admitted in whole-prompt units makes every other obligation of the loop wait for the whole unit: on the 6 GB runner those obligations are the streaming UI, the stop/interrupt check, a second persona's turn, or a background sidecar (memory extraction, summarisation) sharing the card.

Chunking converts that unbounded wait into a bounded one, and the paper's numbers size the conversion:

- At the paper's strict budget (512), a 14,712-token prompt is **29 chunks**; at its relaxed budget (2,048), **8 chunks** (ceil(14712/2048)). No single step ever contains more than τ prefill tokens, so the worst-case delay imposed on anything else in the loop is one τ-sized step — with τ = 512, about **3.5% of the prompt** — instead of 100% of it.
- The price, from the paper's own ablation: prefill itself gets *slower*, by up to ~25% at budget 512 and negligibly at 2,048 (Yi-34B numbers; the direction and rough shape are the transferable part, not the percentages). **For a lone request with nothing else running, chunked prefill does not shorten time-to-first-token and slightly lengthens it.** Any dossier or build note claiming chunking speeds up single-user TTFT is misreading this paper.
- Therefore the local budget choice inverts the fleet logic: there is no stranger's TBT to protect, so the right τ on the 6 GB card is at the *large* end (the corpus's IDEA-LEDGER #18 suggests 512–2,048 as the starting sweep, auto-sized to headroom) — large enough that chunking overhead is negligible, small enough that a step stays short in wall-clock terms on a slow card, where one 2,048-token prefill step is itself a noticeable pause. The knob to expose is *maximum inter-token gap during ingestion*, not an abstract token count.

The real single-user wins, stated plainly:

1. **Responsiveness during ingestion.** A long paste, document, or re-primed history stops being a 52-second freeze: the UI can show progress ("prefilling… n / 14,712"), the user can cancel between chunks, and the application stays alive. This is IDEA-LEDGER #18's claim — robustness, zero raw-speed claim — and this paper is its mechanism and its evidence that the mechanism is cheap.
2. **Interrupt and stop behaviour.** A runner that only regains control at step boundaries can only honour a stop word, a user interrupt, or a new message at step boundaries. Whole-prompt prefill makes the boundary 52 s away; chunked prefill makes it one step away. For a chat product — and doubly for any voice/controller surface where a stop must land *now* — that is a correctness property, not a performance nicety.
3. **Co-resident work stops freezing.** The moment the runner does anything concurrent — a second character in a group scene, a swipe/regenerate racing a sidecar summary, an embedding call for memory recall — it has a two-tenant scheduling problem in miniature, and decode-maximal fill (decodes first, prefill in the leftover budget) is the correct miniature policy. This is also where the paper's 28.3× naive-hybrid warning bites locally: mixing a *full* 14,712-token prefill into a step with a live decode is precisely the configuration the paper measured at its worst.
4. **TTFT and TPOT become separate budgets.** Even with one user, the two phases are felt differently: TTFT is "how long until it starts answering", TPOT/TBT is "does the stream stutter". Sarathi-Serve's discipline — one budget knob, chosen against an explicit TBT target — gives the improved Ollama a principled way to present and tune both, instead of a single undifferentiated "speed".

Sequencing note: chunking pays fully only on top of prefix reuse (IDEA-LEDGER #1/#5/#13). Chunking a 14,712-token re-evaluation makes the waste *polite*; residency makes most of it *not happen*. The two compose: only the uncached suffix should ever be chunked.

### (b) Project Aesir

- **The resident-session serve should chunk its suffix prefill.** Aesir's serve design (HS-line: token-level session residency, exact-prefix reuse, snapshots for hybrid state) already eliminates re-evaluation of the committed prefix. What remains per turn is a suffix prefill of unbounded length (a long pasted document into a resident session is the same 14,712-token event). Chunking that suffix under a token budget gives Aesir's step loop the same bounded-step property: sessions sharing the engine cannot stall each other by more than one budget, and the serve's advertised properties can include a bounded inter-token gap, not just reuse counts.
- **Step boundaries are Aesir's control points.** Aesir's design repeatedly needs the engine to regain control between quanta of work: cancellation, session TTL/eviction checks, snapshot boundaries at stable prefixes (Q35-5), and — from the Hey Yrsa controller posture — a stop that cuts speech instantly. A scheduler whose largest uninterruptible unit is a whole prompt cannot honour any of those promptly. Chunked prefill is what makes the unit small by construction rather than by vigilance.
- **Uniform steps suit heterogeneous hardware.** The pipeline-bubble result generalises: any staged execution (Aesir's NPU → GPU → CPU division of labour, per its accelerator-first law) suffers when stage times vary wildly by step. Near-uniform per-step compute — the property Sarathi-Serve buys with τ — is what lets a multi-device pipeline stay fed. Aesir should treat per-step token budget as a *device-pipeline* parameter as well as a latency one, and profile it per backend the way the paper profiles τ per model/hardware pair (including the tile-quantisation warning: chunk sizes should respect each backend's natural tile/vector width — the 257-vs-256 lesson is a SIMD-width lesson in disguise, and Aesir's own wave retrospective records width as its proven decode lever).
- **What Aesir should not import:** the capacity/SLO evaluation framing. Aesir's serve is a resident-session, few-user engine; its honest metrics are per-session TTFT, worst inter-token gap, and reuse counts — the single-user translations in §6a — not requests/second at P99 under Poisson arrivals.

## 7. Cross-links

- `papers/orca.md` — iteration-level scheduling, the substrate Sarathi-Serve refines: Orca re-decides the batch per iteration but admits prefills whole; Sarathi-Serve's contribution begins exactly where Orca's stalls begin. Orca's selective batching is the "naive hybrid" whose 28.3× TBT inflation this paper measures.
- `papers/distserve.md` (this wave) — the rival answer to the same interference: disaggregate the phases onto different GPUs and optimise goodput. DistServe's own text concedes chunked prefill mitigates interference but argues it cannot eliminate it and pays a TTFT tax; Sarathi-Serve's related-work section returns the compliment (disaggregation wastes prefill-replica KV capacity and needs fast interconnects). Read as a pair: same disease, opposite surgeries.
- `papers/splitwise.md` (this wave) — the characterisation both papers stand on (compute-bound prefill, memory-bound decode) plus the third answer: phase-split across *heterogeneous* machine pools.
- `runners/vllm.md` §3.1–§3.2 — chunked prefill as shipped: V1's unified token-budget scheduler, on by default, decode-first fill, and the guide's budget-vs-latency tuning advice.
- `runners/sglang.md` §4.2 — chunked prefill in SGLang's scheduler, including its interaction with retraction and the mixed-batch mode.
- `synthesis/IDEA-LEDGER.md` — **#18** (chunked prefill with progress and cancellation) is this paper miniaturised for the 6 GB build; **#1/#5/#13** (residency and prefix reuse) are the precondition that decides how much prefill is left to chunk; **#25** (get CPU work off the decode path) is the same bounded-step discipline applied to the host side of the loop.

## 8. Sources

All sources accessed **2026-11-15**.

1. Agrawal, A., Kedia, N., Panwar, A., Mohan, J., Kwatra, N., Gulavani, B. S., Tumanov, A., & Ramjee, R. (2024). *Taming Throughput-Latency Tradeoff in LLM Inference with Sarathi-Serve.* OSDI '24, pp. 117–134. arXiv:2403.02310. Abstract page: https://arxiv.org/abs/2403.02310 — verified title, author list, venue line (via USENIX record below), and headline results (2.6× Mistral-7B / 1× A100; 3.7× Yi-34B / 2× A100; 5.6× Falcon-180B with pipeline parallelism, all vs vLLM).
2. Same paper, full HTML text (v3): https://arxiv.org/html/2403.02310v3 — read for the scheduler taxonomy and generation-stall framing (§1, Fig. 1), the 28.3× naive-hybrid TBT figure and Algorithm 3's fill order (§4.2), the token-budget tradeoffs including the 257-vs-256 tile-quantisation measurement (§4.3), the evaluation setup (Tables 1–3: hardware, dataset medians/P90, P99-TBT SLOs, budgets 512/2,048/1,536), capacity results (§5.1–§5.3), and the ablation and chunking-overhead figures (Table 4; §5.4: ≤ ~25% at 512, negligible at 2,048).
3. USENIX OSDI '24 proceedings record: https://www.usenix.org/conference/osdi24/presentation/agrawal — verified venue, dates, pages 117–134, ISBN 978-1-939133-40-3, and the BibTeX author order used in §1.
4. Corpus dossiers read for §5 and §7 (banked in this repository, accessed 2026-11-15): `runners/vllm.md` (V1 chunked prefill on by default, token-budget scheduler, tuning guidance), `runners/sglang.md` (chunked prefill size, mixed mode), `papers/orca.md` (iteration-level scheduling baseline), `synthesis/IDEA-LEDGER.md` (#1, #18, and the 14,712-token / 52.1 s baseline record cited in §6a).
