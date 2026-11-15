# CacheBlend — CacheBlend: Fast Large Language Model Serving for RAG with Cached Knowledge Fusion

## 1. Full citation

- **Title:** CacheBlend: Fast Large Language Model Serving for RAG with Cached Knowledge Fusion
- **Authors:** Jiayi Yao, Hanchen Li, Yuhan Liu, Siddhant Ray, Yihua Cheng, Qizheng Zhang, Kuntai Du, Shan Lu, Junchen Jiang
- **Affiliations (as listed in the paper):** University of Chicago (Yao also CUHK Shenzhen; Zhang also Stanford; Lu also Microsoft Research)
- **Venue / year:** Twentieth European Conference on Computer Systems (EuroSys '25), Rotterdam, Netherlands, 30 March – 3 April 2025. ACM. DOI: 10.1145/3689031.3696098 — **venue verified** against the ACM proceedings record embedded in the paper (EuroSys '25, DOI above).
- **arXiv:** arXiv:2405.16444 [cs.LG] — v1 26 May 2024; v3 3 April 2025 — https://arxiv.org/abs/2405.16444
- **Code (as reported in the paper):** https://github.com/LMCache/LMCache

## 2. The problem it attacks

Retrieval-augmented generation builds each prompt from several retrieved text chunks. Prefix caching only reuses the chunk that happens to sit at the very start of the prompt; every other chunk is re-prefilled even if the server computed its KV cache yesterday. The obvious fix — reuse every chunk's precomputed KV cache wherever it lands — is wrong in a specific way: a chunk's cached KV was computed without any attention to the chunks that now precede it, so the cross-attention between chunks is missing and answer quality drops. The paper's question is narrow and practical: how to fuse several precomputed KV caches into one prompt at near-reuse speed while keeping full-prefill quality.

## 3. Core idea in our own words

Reuse all the chunks' KV caches, then repair them cheaply. CacheBlend runs a layer-by-layer partial prefill in which, at each layer, it **recomputes the KV of only a small subset of tokens** and keeps the loaded KV for the rest. The tokens chosen for recomputation are the ones whose freshly computed KV deviates most from the cached KV — the paper calls them high-KV-deviation (HKVD) tokens — because those are precisely the tokens whose values were most changed by the new preceding context. Recomputing them re-injects most of the missing cross-attention. The paper finds a recompute fraction under ~15% typically restores full-prefill quality, which it attributes to the sparsity of real attention patterns.

The second half of the idea is systems-level: the selective recompute for layer *i* runs **in parallel with loading layer *i+1*'s cached KV from storage**. If recompute time is matched to load time, the repair is effectively free, and the KV store can live on slow, cheap, large media (CPU RAM, SSD) without adding latency. A loading controller picks the recompute ratio (and, given a ratio, the cheapest storage tier) so that neither side waits for the other.

## 4. Key design details a runner engineer needs

- **Chunk store:** inputs are split into chunks (the evaluation uses 512-token chunks via LangChain-style splitting); each chunk is hashed (same block-hashing approach as vLLM) to its stored KV cache; new chunks' fused KV is written back; eviction is LRU when storage fills. Hash tables are small (~16 MB per million chunks, as reported).
- **Fusor:** the component that merges caches. It works layer by layer because the HKVD set for a layer depends on the previous layer's recompute. First checked layer selects HKVD tokens by KV deviation; later layers recompute the tracked HKVD indices. Only HKVD tokens' KV entries are overwritten.
- **Loading controller:** estimates recompute delay as `ratio × full-prefill delay` (profiled offline) and load delay as `per-token KV size × length / storage throughput` (measured offline); chooses the ratio whose recompute hides under load time, floored at the quality-driven minimum (~15% in their experiments). Symmetrically, for a fixed 15% ratio it picks the cheapest storage device whose load time stays under recompute time.
- **Engine integration:** implemented on top of **vLLM** (~3K lines of Python / PyTorch). Three internal interfaces: fetch a chunk's KV for one layer, run one layer of partial prefill, synchronise before each layer. Two threads pipeline layer-*i* compute against layer-*i+1* fetch.
- **Where it hooks in:** between the retriever and the inference engine — it consumes retrieved chunks + their cached KVs and hands the engine a fused KV cache, after which decoding is completely standard.

## 5. Reported results — as reported, with context

All figures are the paper's own measurements.

- **Headline:** vs full KV recompute, **TTFT reduced 2.2–3.3×** and **throughput increased 2.8–5×**, without compromising generation quality. Vs prefix caching specifically: same TTFT range (2.2–3.3×) and up to 3.3× throughput at equal TTFT in the paper's RAG serving experiments.
- **Quality:** vs full KV reuse (the Prompt Cache-style baseline), CacheBlend scored **0.1–0.2 higher absolute F1** on QA tasks and **0.03–0.25 higher Rouge-L** on summarisation in the abstract's accounting (the evaluation section reports 0.15–0.35 quality improvement over full reuse across metrics); its drop vs full recompute / prefix caching was only **0.01–0.03**.
- **Setup:** models **Mistral-7B, Yi-34B, and Llama-70B** (8-bit quantisation applied to Yi-34B and Llama-70B); hardware **2× NVIDIA A40 GPUs, 128 GB RAM, 1 TB NVMe SSD (measured 4.8 GB/s)** on RunPod — 1 GPU for the 7B / 34B models, 2 GPUs for the 70B model. Datasets: **2WikiMQA, Musique** (multi-hop QA, F1), **SAMSum, MultiNews** (summarisation, Rouge-L), plus extended synthetic RAG sets built from Musique / 2WikiMQA (6,000 queries, top-6 retrieved chunks). Baselines: full KV recompute, prefix caching (given the generous assumption of zero KV loading delay), full KV reuse, and LangChain-style MapReduce / MapRerank.
- **Motivating scale (as reported):** full prefill of a 4,000-token RAG input took ~3 s (Llama-34B) to ~6 s (Llama-70B) on one A40 — the delay CacheBlend exists to remove.
- **Recompute budget:** quality held at recompute ratios around **15%**; the ratio is a tuned, workload-dependent parameter, not a universal constant.

## 6. Limitations / what it does not solve

- It repairs cross-attention approximately. Quality is *measured* to be near full-prefill on the paper's QA / summarisation sets; there is no guarantee for adversarial chunk combinations or tasks where every token's cross-attention matters.
- The HKVD selection needs a first-layer (and per-layer) deviation check — extra bookkeeping and a partial forward pass structure that must be woven into the engine's prefill, layer by layer. It is not a drop-in cache format.
- Benefits require chunk reuse across requests and a chunking discipline stable enough that hashes match. One-off documents gain nothing.
- Evaluation is RAG-shaped: multiple medium chunks, answer-focused tasks. Long single-document prompts and open-ended generation are outside the measured envelope.
- Storage still costs the full KV per chunk; CacheBlend makes slow storage *usable*, it does not make KV smaller.

## 7. Applicability

### (a) Ollama on a 6 GB consumer GPU running long character chats

- The direct RAG framing is not the chat case, but the mechanism solves a real chat problem: lorebook / world-info injection. A character chat with retrieval-style lore assembles each prompt from the persona block plus whichever lore chunks triggered this turn — chunks in varying order, never a clean shared prefix. Prefix caching (RadixAttention) misses all but the first chunk; CacheBlend's "reuse any chunk, recompute the worst-deviating ~15%" is the first technique in this wave that matches that assembly pattern.
- The pipelining lesson is tailor-made for a 6 GB card: keep the lore chunks' KV on system RAM or SSD, stream them in layer by layer, and hide the transfer under the small selective recompute. GPU memory then holds weights + the live conversation, not a library of lore caches.
- Cost honesty: implementing HKVD fusion inside Ollama's llama.cpp-based stack is real engine work (layer-wise partial prefill hooks), not a configuration flag. The cheap intermediate step is chunk-level KV persistence to disk with plain prefix reuse; CacheBlend is the upgrade when measurements show lore re-prefill dominating TTFT.
- The 15% figure must be re-measured for roleplay models / quantised weights before trusting it; the paper's number comes from FP / 8-bit datacentre models on QA tasks.

### (b) Project Aesir (Mojo runner — sessions, prefix memory, hybrid SSM models)

- CacheBlend gives Aesir its **non-prefix reuse** story, completing the trio: PagedAttention (allocation), RadixAttention (prefix reuse), CacheBlend (arbitrary chunk fusion). Aesir's memory system should be designed so a "document" (lore pack, retrieved memory, tool output) is a first-class cacheable chunk with a content hash, exactly as CacheBlend's store assumes.
- The loading-controller idea — size the repair work to hide under storage latency — generalises to Aesir's heterogeneous fleet: on a Pi-class device with slow SD storage the controller would raise the recompute ratio; on fast NVMe it would lower it toward the quality floor. One policy, parameterised by measured device throughput.
- Hybrid SSM warning, again concrete: chunk fusion assumes each chunk's state can be repaired token-wise. Attention KV can; an SSM recurrent state summarising a chunk cannot be partially recomputed per token in the same way. For hybrid models Aesir should restrict CacheBlend-style fusion to attention layers and treat SSM state at chunk boundaries as either recomputed wholesale or explicitly approximate — an open research point to log, not a detail to hand-wave.
- Aesir should adopt the paper's evaluation discipline for any fusion work: report TTFT *and* a quality delta vs full prefill on the same prompts. Speed-only claims for approximate reuse are not acceptable evidence.

## 8. Access

- Date accessed: **2026-11-15**
- arXiv abstract: https://arxiv.org/abs/2405.16444
- arXiv HTML (read for design + evaluation detail): https://arxiv.org/html/2405.16444v3
- DOI: https://doi.org/10.1145/3689031.3696098
