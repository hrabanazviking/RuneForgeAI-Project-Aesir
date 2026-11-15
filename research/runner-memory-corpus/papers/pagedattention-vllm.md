# PagedAttention / vLLM — Efficient Memory Management for Large Language Model Serving with PagedAttention

## 1. Full citation

- **Title:** Efficient Memory Management for Large Language Model Serving with PagedAttention
- **Authors:** Woosuk Kwon, Zhuohan Li, Siyuan Zhuang, Ying Sheng, Lianmin Zheng, Cody Hao Yu, Joseph E. Gonzalez, Hao Zhang, Ion Stoica
- **Venue / year:** ACM SIGOPS 29th Symposium on Operating Systems Principles (SOSP '23), Koblenz, Germany, 23–26 October 2023, pp. 611–626. DOI: 10.1145/3600006.3613165
- **arXiv:** arXiv:2309.06180 [cs.LG] — https://arxiv.org/abs/2309.06180
- **Code (as reported in the paper):** https://github.com/vllm-project/vllm

## 2. The problem it attacks

High-throughput LLM serving needs large batches, but the per-request key-value (KV) cache is large, grows token by token, and has an unknown final length. Systems that reserve one contiguous chunk per request at its maximum length waste most of that memory to internal fragmentation, reserved-but-unused slots, and external fragmentation, so the batch size — and therefore throughput — is capped by memory bookkeeping rather than by compute. A second loss is duplication: sequences that share a prompt, or branches of parallel sampling / beam search, cannot share KV storage when each sequence owns a private contiguous buffer.

## 3. Core idea in our own words

Borrow operating-system paging for the KV cache. Split each sequence's KV cache into fixed-size blocks (the paper's default is 16 tokens per block). Blocks do not need to sit next to each other in GPU memory. A per-sequence block table maps logical block numbers to physical block IDs, exactly like a page table maps virtual to physical pages, and a custom attention kernel walks that table when it reads keys and values.

Because allocation happens one block at a time, on demand, a sequence only holds memory for tokens it has actually produced. Because blocks are uniform, there is no external fragmentation. Because blocks are reference-counted, two sequences can point at the same physical block for a shared prefix; when one sequence writes into a shared block, the system copies that block first (copy-on-write) so the other sequence keeps the old contents. Preemption is handled at block granularity: a stalled sequence's blocks can be swapped to CPU memory or simply dropped and recomputed later.

## 4. Key design details a runner engineer needs

- **Data structures:** a global pool of physical KV blocks; per-sequence block table (logical → physical); per-block reference count; a free-block queue managed by a centralised KV-cache manager / block manager.
- **Block size trade-off:** too small hurts GPU parallelism on block reads; too large reintroduces internal fragmentation and lowers sharing probability. The paper's sweep found 16–128 good on ShareGPT traces and 16–32 good on shorter Alpaca traces; vLLM ships 16 as the default.
- **Attention kernel:** PagedAttention kernel resolves block-table indirection inside the attention computation. The paper measures 20–26% higher attention-kernel latency than NVIDIA FasterTransformer's highly optimised contiguous kernel — a cost paid only in attention, more than recovered end-to-end by larger batches.
- **Sharing:** copy-on-write at block granularity for parallel sampling (shared prompt) and beam search (shared prefix plus diverging tails). Sharing across different requests with a common system / few-shot prefix is supported by the same mechanism.
- **Scheduling / preemption:** iteration-level (continuous) batching inherited from the Orca line of work, co-designed with block allocation. Preemption is all-or-nothing per sequence (a sequence needs all its blocks resident to run). Recovery is by swapping blocks to CPU RAM or by recomputation; the paper finds recomputation preferable at small block sizes (many small PCIe transfers hurt swapping) and the two comparable at block sizes 16–64.
- **Where it hooks in:** between the scheduler and the attention kernels. The model weights, sampler, and tokeniser are untouched; the change is entirely in how KV tensors are allocated, addressed, and freed. Distributed execution (tensor parallelism, multi-GPU models larger than one device) is supported in the vLLM system built on top.

## 5. Reported results — as reported, with context

All figures below are the paper's own measurements, not ours.

- **Memory efficiency:** in the paper's profiling, prior systems used only **20.4%–38.2%** of allocated KV-cache memory for actual token states; vLLM claims near-zero waste by construction.
- **Throughput (headline):** **2–4× higher throughput at the same latency** than FasterTransformer and Orca, with larger gains for longer sequences, larger models, and more complex decoding.
- **Basic sampling (ShareGPT traces):** vLLM sustained **1.7×–2.7× higher request rates than Orca (Oracle)** and **2.7×–8× higher than Orca (Max)** at similar normalised latency; up to **22× higher request rates than FasterTransformer**. On OPT-13B it ran **2.2× more concurrent requests than Orca (Oracle)** and **4.3× more than Orca (Max)**. Workloads: ShareGPT and Alpaca traces (1-hour traces; 15-minute traces for OPT-175B); models in the OPT / LLaMA family including OPT-13B and OPT-175B; the motivating memory breakdown uses a 13B model on an **NVIDIA A100 (40 GB)**, where weights took ~65% and KV cache ~30% of memory.
- **Sharing savings:** memory saved by block sharing was **6.1%–9.8%** (Alpaca) / **16.2%–30.5%** (ShareGPT) for parallel sampling, and **37.6%–55.2%** (Alpaca) / **44.3%–66.3%** (ShareGPT) for beam search. Beam search (width 6, OPT-13B, Alpaca) widened the throughput lead over Orca (Oracle) from 1.3× (basic sampling) to **2.3×**.
- **Shared-prefix workload:** LLaMA-13B on WMT16 translation with a shared instruction + examples prefix: **1.67×** throughput vs Orca (Oracle) with a 1-example (80-token) prefix and **3.58×** with a 5-example (341-token) prefix.
- **Chatbot workload:** ~**2× higher sustainable request rate** than the Orca baselines on a synthesised ShareGPT-history chatbot trace (OPT-13B, prompts truncated to the last 1024 tokens).
- **Accuracy:** no change — PagedAttention is an exact memory-layout change, not an approximation.

Baselines named in the paper: NVIDIA FasterTransformer; Orca in three allocation variants (Oracle = true output length known, Pow2 = power-of-two over-reservation, Max = reserve to maximum length).

## 6. Limitations / what it does not solve

- It manages memory; it does not shrink the KV cache itself. A single very long sequence still needs its full KV footprint — eviction / compression (see H2O, StreamingLLM dossiers) is a separate problem.
- The win scales with concurrency. With one request at a time there is little fragmentation to remove, and the block-table indirection is a small net cost in the attention kernel.
- Prefix sharing only helps on exact token-prefix matches; reordered or mid-prompt reuse is out of scope (that is the CacheBlend / Prompt Cache problem).
- Preemption by recomputation re-pays prefill; preemption by swapping is PCIe-bound at small block sizes.
- The evaluation is datacentre-class (A100, large OPT/LLaMA models, trace-driven multi-request load). Nothing in the paper measures a single-user consumer GPU.

## 7. Applicability

### (a) Ollama on a 6 GB consumer GPU running long character chats

- The direct lesson is accounting, not throughput: on a 6 GB card the KV cache competes byte-for-byte with weights. Allocating KV in small fixed blocks, on demand, instead of reserving a full-context contiguous buffer per session, is what lets a long chat keep growing without pre-paying for context it may never use — and lets Ollama report honestly how many tokens actually fit.
- Reference-counted block sharing maps cleanly onto character-chat structure: the character card + system prompt + world-info prefix is identical across sessions and across regenerated / branched replies. Storing that prefix once and copy-on-writing at the branch point saves real memory at this scale, where a 1–2k-token persona prefix is a large fraction of a small cache.
- All-or-nothing preemption with recompute-vs-swap choice matters when the user switches characters or models: dropping and recomputing a cold session's blocks will usually beat swapping many small blocks over PCIe on a consumer board. Measure both; do not assume.
- What *not* to import: the multi-request batching machinery. A single-user chat rarely has a batch to grow; the payoff here is fragmentation removal and prefix sharing, not the 2–4× throughput headline.

### (b) Project Aesir (Mojo runner — sessions, prefix memory, hybrid SSM models)

- Aesir's prefix-memory design should adopt the block-table abstraction verbatim in spirit: logical token positions decoupled from physical storage, fixed-size blocks, reference counts, copy-on-write on divergence. That gives sessions, branches, and shared persona prefixes one uniform mechanism instead of three special cases.
- Keep the block size a tunable, workload-measured parameter (the paper's 16 default is an A100 measurement, not a law); Aesir's targets (AMD iGPU / NPU spillover, Pi-class ARM) need their own sweep.
- For hybrid SSM / attention models, paging applies only to the attention layers' KV; the SSM recurrent state is a fixed-size per-session blob. Treat that state as a single non-pageable "block" owned by the session, checkpointed / restored alongside the block table — do not try to page inside it.
- Aesir's preemption policy should copy the paper's explicit recompute-vs-swap costing, extended with a third option Aesir has and vLLM did not target: recompute on a different device class (e.g. rebuild prefix on NPU while GPU decodes).

## 8. Access

- Date accessed: **2026-11-15**
- arXiv abstract: https://arxiv.org/abs/2309.06180
- arXiv HTML (read for design + evaluation detail): https://arxiv.org/html/2309.06180v1
