# vLLM — Dossier OR-2

**Project:** vLLM (the name is usually glossed as "virtual LLM", after virtual memory)
**Licence:** Apache License 2.0
**Principal languages:** Python for the engine, scheduler, API server and most orchestration; C++ / CUDA / Triton for the performance-critical kernels and attention back ends. (The kernel layer is where the speed lives; the control plane is Python.)
**Origin:** UC Berkeley Sky Computing Lab, 2023. Became a PyTorch Foundation hosted project in May 2025.
**Repository:** https://github.com/vllm-project/vllm
**Website / docs:** https://vllm.ai — https://docs.vllm.ai
**As of:** 2026-11-15 (all sources accessed 2026-11-15; version references below are to the releases and docs current at that date — principally the v0.30–v0.32 line, with the V1 engine as the only engine since v0.11, October 2025)
**Companion in this corpus:** `papers/pagedattention-vllm.md` covers the 2023 SOSP paper that introduced PagedAttention. This dossier covers the *project as it exists now* — the V1 engine, the serving stack, and the ecosystem that has grown around that paper.
**Clean-room note:** written in our own words from the sources in §10. No text copied beyond short factual labels (flag names, component names, licence name). No code lifted.

## Essence

vLLM is the datacentre serving engine that turned one memory-management idea — treat the attention key/value cache like operating-system virtual memory, in fixed-size pages — into the default way to serve open-weight language models at scale. Its 2023 paper proved the memory point; the project since then has been about everything around it: a scheduler that re-decides the batch on every forward pass, a KV cache that is also a content-addressed prefix store, chunked prefill so one long prompt cannot stall everyone else, speculative decoding, disaggregated prefill/decode, and an OpenAI-compatible HTTP front end. The design target is unmistakable throughout: many simultaneous users, high aggregate throughput, on datacentre GPUs — above all NVIDIA, with AMD, Intel, TPU and CPU as second-class but real ports. It is the engine to study for *serving* ideas, and the engine to be most careful about copying naively into a single-user laptop runner, because almost every one of its wins is bought with assumptions a 6 GB laptop violates. That tension is the point of §8 and §9.

---

## 2. Architecture today — the V1 core

### 2.1 What V1 is, and when it arrived

The V1 rewrite was announced as an alpha on 27 January 2025 (blog post "vLLM V1: A Major Upgrade to vLLM's Core Architecture") and became the default engine during 2025. V0 was fully deprecated afterwards — the V1 guide in the current docs carries an explicit deprecation announcement for V0 and points to RFC #18571 for the details. The V1 goals, as the project states them, were threefold: a simpler, more modular, easier-to-hack codebase; near-zero CPU overhead in the hot loop; and all the key optimisations combined into one unified architecture, enabled by default rather than as a pile of opt-in flags.

The rewrite kept what was stable from V0 — model implementations, GPU kernels, utilities — and rebuilt the core systems: scheduler, KV cache manager, worker, sampler, and API server. The headline performance claim attached to the launch was up to about 1.7× higher throughput than V0 (the launch post's figure, without multi-step scheduling; treat it as the project's own claim on its own benchmarks, not an independent measurement — see §10, "numbers" note).

### 2.2 The process split — the single most important V1 change

In V0, tokenisation, scheduling, detokenisation and CUDA calls all contended inside one process, so the GPU sat idle whenever the Python side was busy. V1 splits the system into processes connected by ZeroMQ (ZMQ) sockets:

- **API server process (P0).** Owns everything request-shaped: HTTP handling, tokenisation, multimodal preprocessing, detokenisation, streaming output to the client. It can be scaled out — the current docs describe running several API-server processes against one engine core (`--api-server-count`), useful when input processing becomes the bottleneck and spare CPU exists.
- **EngineCore process (P1).** Owns exactly two things — the scheduler and model execution — and runs them in a tight busy loop: poll the input queue, schedule a step, have the workers execute it, hand outputs to a dedicated output thread, repeat. Nothing else lives there. That isolation is the point: a slow tokenisation or a slow client can no longer stall the GPU loop.
- **Worker processes, one per GPU.** Each holds its shard of the model and runs the forward pass. An engine core drives (tensor-parallel size) × (pipeline-parallel size) workers. With data parallelism there is one engine core per replica, plus a coordinator process.
- **In-process fallback.** For offline use (`LLM(...)` in a script) the same machinery can run in-process — the anatomy post describes an `InprocClient` that is effectively the EngineCore in the same process — but the multi-process form is the production shape, and the offline form is a convenience, not the design centre.

The internal wiring, as described in the September 2025 anatomy post (which analyses commit 42172ad, 9 August 2025) and the V1 design docs, is:

- `LLM` / `AsyncLLM` (the user-facing engine) → a **processor** that validates, tokenises and packs inputs into engine-core requests → an **engine-core client** (in-process, or a ZMQ-backed async multiprocess client at scale) → **EngineCore** → **ModelExecutor** → **Worker(s)** → **ModelRunner** (holds sampler, KV cache, and forward-pass buffers such as input ids and positions) plus an **InputBatch** (CPU-side forward-pass buffers, block tables, sampling metadata).
- Inside EngineCore sit the **Scheduler** (with its waiting and running queues, a scheduling policy, and the KV cache manager) and a **Structured Output Manager** for guided/structured decoding.

### 2.3 The step loop

Every engine step has the same three stages, repeated until no requests remain:

1. **Schedule** — decide which requests run in this step (decode, and/or chunked prefill — §3).
2. **Forward pass** — run the model and sample tokens.
3. **Post-process** — append sampled token ids, detokenise, check stop conditions (length limit, end-of-sequence token unless ignored, stop token ids, stop strings). Finished requests return their KV blocks to the free pool and their output is returned early; in streaming mode intermediate tokens are sent as generated.

For the forward pass itself, all sequences in the step are flattened and concatenated into one long "super sequence"; position indices and attention masks keep each sequence attending only to its own tokens, so continuous batching needs no right-padding. The last-token hidden states are gathered per sequence, logits computed, and tokens sampled per the sampling configuration (greedy, temperature, top-p, top-k, and so on).

### 2.4 Execution path: torch.compile and CUDA graphs

Unless eager execution is forced (`--enforce-eager`), V1 runs the model through `torch.compile` by default and captures CUDA graphs during warm-up. The design, as described in the V1 launch material and the anatomy post:

- Attention is wrapped as a custom operation so the compiler does not trace inside it; the graph is split at each attention call, and the pieces between attention calls are compiled by Inductor into fused kernels. Attention stays hand-written; everything else is generated.
- **Piecewise CUDA graphs** capture the compiled pieces (everything except attention) so a step's kernel sequence replays with far fewer launches; **full CUDA graphs** capture a whole decode-only step where the attention back end allows it. The default capture mode is described in secondary sources as full-and-piecewise combined. The purpose in both cases is the same: a decode step is hundreds of short kernels, and per-kernel launch overhead would otherwise dominate the few-millisecond step.
- The trade-off is recorded in the V1 guide itself: CUDA graph capture takes up more memory in V1 than in V0. That cost is part of the startup memory budget in §4.

### 2.5 How V1 differs from the 2023 V0 design

| Aspect | V0 (2023 design, as described in the paper and the V1 guide) | V1 (2025–, current) |
|---|---|---|
| Process model | Single process; tokenisation, scheduling and CUDA calls contended | Isolated EngineCore process; API server separate; ZMQ between them; one worker process per GPU |
| Scheduler | Two kinds of step — a prefill step *or* a decode step; chunked prefill an opt-in extra | One unified scheduler; no prefill/decode phases; a per-step token budget covers both, chunked prefill on by default |
| Prefix caching | Opt-in, with measurable overhead | On by default; the V1 team measured under 1% throughput cost even at a 0% hit rate (their figure, secondary source) |
| Preemption | GPU↔CPU KV swap supported as an alternative to recompute | Swap removed; recompute is the only preemption mode (see §3.3) |
| Execution | Eager-first with CUDA graphs as an optimisation | torch.compile + piecewise/full CUDA graphs as the default path |
| Tensor parallelism | Asymmetric limitations in V0 (request state handling) | Clean design: request state cached on workers, only incremental diffs transmitted per step |
| CPU overhead | GPU bubbles whenever Python was busy | Near-zero CPU overhead is an explicit V1 goal; CPU prepares step N+1 while the GPU runs step N (async-first design) |
| Feature surface at launch | Broad | Narrower at alpha (January 2025: no logprobs, prompt logprobs, pipeline parallelism, structured decoding, speculative decoding, Prometheus metrics, LoRA; Ampere-or-later NVIDIA only). Most of these were restored during 2025; see the feature table in the current V1 guide (§1.6) |

### 2.6 What V1 supports now (current docs, feature table)

The current V1 guide's feature table (accessed 2026-11-15) lists as functional: prefix caching, chunked prefill, LoRA, logprobs calculation, FP8 KV cache, speculative decoding, prompt logprobs with prefix caching, and alternative structured-output back ends. Concurrent partial prefills are in progress. Removed and not coming back without strong demand: `best_of` sampling, per-request logits processors (replaced by global logits processors set at start-up), GPU↔CPU KV cache swapping, and request-level structured-output back end selection. Hardware listed as functional: NVIDIA, AMD, Intel GPU, TPU, CPU. Model types functional: decoder-only, pooling models, Mamba and hybrid Mamba/attention models (with the caveat that prefix caching is not yet supported for the Mamba/hybrid set), multimodal models, and Whisper among encoder–decoder models (other encoder–decoder models only via the plugin system).

### 2.7 Scale-out: parallelism and distribution

vLLM combines four parallelism strategies, all documented in the optimisation guide:

- **Tensor parallelism (TP)** — shards model parameters across GPUs within each layer; the common way to fit a model too large for one GPU, and also a way to free per-GPU memory for KV cache. Intranode bandwidth is much higher than internode, so TP is preferred over pipeline parallelism where it fits.
- **Pipeline parallelism (PP)** — distributes layers across GPUs/nodes; for when TP alone is not enough, or for deep narrow models. Costs latency.
- **Expert parallelism (EP)** — for mixture-of-experts models (DeepSeek V3, Qwen MoE, Llama-4 class); experts distributed across GPUs, enabled with `enable_expert_parallel`, using the same degree as TP for MoE layers.
- **Data parallelism (DP)** — replicates the whole model across GPU sets and processes different request batches in parallel; for scaling throughput rather than model size. Multi-node DP uses a coordinator, a master address and an RPC port, with headless engine nodes and a separate API-server node; replicas that have no work still execute dummy steps to stay in lockstep at synchronisation points.

A single engine core drives TP×PP workers; DP adds one engine core per replica. The anatomy post walks through a concrete two-node, 8×H100-per-node example (TP=4, DP=4, two engine cores per node) to show the shape: a `CoreEngineProcManager` launching engine-core processes, ZMQ DEALER sockets for the front-end handshake, NCCL for the DP group, and per-process input/main/output threads in steady-state busy loops.

---

## 3. Scheduling

### 3.1 Continuous batching, in current form

Continuous batching is the standing rule: the batch is re-decided at every forward pass. A finished request leaves and a waiting one joins at the next step; there is no fixed batch that must run to completion together. The V1 scheduler's own summary, quoted in the V1 guide, is that there is no "decoding phase" nor "prefill phase" in the scheduler — a decoding request is simply one that is a single token behind, a new request is a whole prompt behind, and a preempted request is its prompt-plus-output behind. The scheduler keeps, in the project's words, a simple dictionary mapping each request id to a token count, and hands out a fixed token budget per step.

Each step, in order:

1. **Decode first.** Requests already in the `running` queue are served first — one new token each (more under speculative decoding; see §6.3). For each, the scheduler calls the KV cache manager's `allocate_slots` (§4) and subtracts the token count from the step's budget. Decode is prioritised because it is latency-sensitive: inter-token latency is what a streaming user feels.
2. **Prefill with what remains.** Waiting-queue requests are then considered. The scheduler first asks how many of their blocks are already computed (the prefix-cache hit count; zero if prefix caching is off), calls `allocate_slots`, moves the admitted request from waiting to running, and subtracts from the budget. A prefill that cannot fit in the remaining budget is chunked (§4.2) rather than deferred whole.
3. **Admission control.** `max_num_seqs` caps how many sequences may be running at once; `max_num_batched_tokens` caps how many tokens (prefill + decode) one step may contain. Both are knobs the operator tunes against preemption (§3.3).

Scheduling policy is configurable via `--scheduling-policy`: **FCFS** (first come, first served) is the default, and **priority** scheduling serves higher-priority requests first, with FCFS as the tie-breaker. Priority is carried on the request (the anatomy post describes waiting-queue insertion as append for FCFS, heap-push for priority). There is no documented notion of per-user fairness, deadlines, or starvation protection beyond the policy choice itself — a gap worth noting for any single-user adaptation, where "priority" is nearly meaningless and FCFS is the whole policy.

### 3.2 Chunked prefill

Chunked prefill splits a long prompt's prefill across several steps so that one huge prompt cannot monopolise a step and stall every decoding request behind it. The mechanism is the token budget itself: if the pending prefill exceeds the remaining budget, only a chunk is scheduled; the rest waits for later steps. Only in the final chunk's step is a token sampled.

Status: in V0 chunked prefill was an opt-in experimental flag (`--enable-chunked-prefill`); in V1 it is **enabled by default whenever possible**, and the V1 guide lists it as a behavioural difference from V0. The tuning guidance in the optimisation guide is explicit and worth quoting in paraphrase: smaller `max_num_batched_tokens` (e.g. 2048) gives better inter-token latency because fewer prefill tokens slow down decodes; larger values give better time-to-first-token; for optimal throughput the guide recommends `max_num_batched_tokens` above 8192, especially for smaller models on large GPUs. If chunked prefill is disabled, `max_num_batched_tokens` must exceed `max_model_len` or the server may fail at start-up. The underlying idea is credited in the docs to the Sarathi paper (Agrawal et al., arXiv 2308.16369) and a 2024 follow-up (arXiv 2401.08671).

An independent simulation-based write-up (Residual Stream, October 2026, on a laptop-class measurement rig — *not* vLLM's own hardware) illustrates the effect size in its own setup: with a 512-token budget, gaps between tokens stayed at or under 0.55 s where whole-prompt prefill left gaps up to 4.2 s. That is a simulation on different hardware, cited here only as an illustration of *why* the mechanism matters, not as a vLLM benchmark.

### 3.3 Preemption: recompute, not swap

When KV cache space runs out mid-generation, vLLM preempts requests to free blocks for others. The policy in V1:

- **Default mode is RECOMPUTE.** A preempted request's KV blocks are freed; when space is available again it is recomputed from its prompt (and generated tokens so far) by re-running prefill. The optimisation guide states this explicitly and gives the reason: recomputation has lower overhead than swapping in the V1 architecture.
- **SWAP is gone in V1.** GPU↔CPU KV cache swapping, which V0 offered as the alternative (copying KV blocks to host RAM instead of discarding them), is listed in the V1 guide as a removed feature: "with the new simplified core architecture, vLLM V1 no longer requires KV cache swapping to handle request preemptions." The swap mode still appears in older (v0.8.x-era) copies of the optimisation guide that search engines surface — that is a V0-era document, not current behaviour, and the disagreement is resolved in favour of the current V1 guide.
- **What the operator sees.** A warning naming the preempted sequence group and the mode (`PreemptionMode.RECOMPUTE`), plus a cumulative counter. The documented remedies are: raise `gpu_memory_utilization`, lower `max_num_seqs` or `max_num_batched_tokens`, or add tensor/pipeline parallelism. Preemptions are exposed as Prometheus metrics (`vllm:num_preemptions_total` in the guides) and in the stats log.

The design judgement embedded here is worth naming: recompute is cheap *when prefill is cheap relative to the PCIe transfer that swapping would need, and when the preempted request is short*. For a single-user laptop runner holding one long conversation, recompute of a long context is the expensive case, not the cheap one — see §9.4.

### 3.4 Priority handling

As in §2.1: two policies, FCFS default, priority with FCFS tie-break. Priority is a per-request attribute set by the caller. The scheduler's waiting queue is a heap under priority scheduling. There is no documented ageing, deadline, or preemption-by-priority (a high-priority arrival does not evict a running low-priority request; preemption is driven by KV space, and the victim choice is by the eviction/preemption logic, with low-priority requests named as the eviction candidates in the anatomy post's description of `allocate_slots` failing). **[Speculation, marked]:** the exact victim-selection order under priority scheduling is not pinned down in the docs I read; the anatomy post says the engine "may attempt recompute preemption by evicting low-priority requests", which suggests priority influences victim choice, but I could not verify the precise rule from the docs alone.

---

## 4. KV cache management

### 4.1 Block allocation (PagedAttention, V1 form)

The KV cache manager is, in the anatomy post's words, "the heart of paged attention". Its job is a memory allocator over a pool of fixed-size physical blocks:

- **Block size:** 16 tokens by default for a standard transformer layer. The per-block byte size is 2 (key + value) × block size × number of KV heads × head size × dtype bytes (2 for bf16). So for a model with, say, 8 KV heads of 128 dimensions in bf16, one block is 2 × 16 × 8 × 128 × 2 = 65,536 bytes per layer — and that is *per layer*, so the per-token KV cost scales with layer count. (Worked example is my arithmetic from the formula the anatomy post gives, not a quoted measurement.)
- **The pool:** at initialisation the manager allocates *all* its blocks up front into a block pool — a list of block objects — precisely to avoid Python object-creation overhead in the hot loop and to keep every block trackable at all times. The free blocks form a doubly linked **free queue** (the pointers live directly on the block objects, giving O(1) moves of an element from the middle to the tail and avoiding a wrapper queue). The pool is "often on the order of hundreds of thousands" of blocks depending on VRAM size and block size (anatomy post).
- **Allocation (`allocate_slots`):** given a request and a number of new tokens, the manager computes how many new blocks are needed (ceiling division — 17 new tokens at block size 16 needs 2 blocks), checks the free queue has enough, and pops that many blocks from the head of the queue into the request's block list (`req_to_blocks`, request id → list of block ids). If there are not enough blocks, allocation fails early and the scheduler either preempts (§2.3) or skips scheduling the request this step. The per-request **block table** maps the request's logical blocks to physical blocks anywhere in the pool — the virtual-memory analogy from the paper, unchanged in spirit.
- **Freeing:** when a request finishes, its blocks are returned to the free queue if no other request is using them (reference count zero). Freed blocks are appended to the *tail* of the free queue in **reverse order** — the last block of a request hashes more tokens and is less likely to be reused, so it should be evicted first. That ordering detail is the LRU eviction policy made concrete.
- **Reference counting:** blocks shared between requests (via prefix caching, §3.2) carry a reference count; a block is only truly free when its count reaches zero.

### 4.2 Prefix caching — automatic, hash-based, on by default

Prefix caching avoids recomputing tokens that several prompts share at the beginning. In V1 it is **enabled by default** (disable with `enable_prefix_caching=False`), because the V1 redesign made its overhead low enough — the project and secondary sources put the cost at under 1% throughput even at a 0% hit rate.

**How it works (design doc, current docs):**

- Only **full blocks** are cached. A prefix that does not align to a block boundary leaves its final partial block uncached and recomputed (the remainder `long_prefix_len % block_size` tokens).
- Each block is identified by a **hash chain**: the hash of a block is computed from (a) the parent block's hash, (b) the exact token ids in this block, and (c) extra hashes — LoRA adapter id, multimodal input hashes, and a per-request `cache_salt` for tenant isolation. Including the exact tokens (rather than only the parent hash) is stated as a collision-reduction measure. The chain means a block's identity captures its entire prefix, so a hash-table lookup is enough — no tree structure is needed (contrast SGLang's radix tree; vLLM deliberately chose the flat hash table).
- The hash function history matters: earlier versions used Python's built-in hash; **since v0.11 the default is SHA-256** (the design doc says "as of v0.11"; a secondary write-up dates the same change to v0.11, April 2026 — the two agree on the version, and I take the doc's version number as authoritative). The cost is quoted in the design doc as about 75 ns per token (under 4 ms for 50k tokens of context) — negligible against prefill compute. The serve-time flag `--prefix-caching-hash-algo` selects among `sha256` (default; pickle serialisation, hashes may not be reproducible across Python/vLLM versions), `sha256_cbor` (CBOR serialisation, reproducible and cross-language, recommended for deterministic caching across environments), `xxhash` and `xxhash_cbor` (128-bit xxHash, faster, non-cryptographic — the docs warn explicitly that a non-cryptographic hash in a multi-tenant setup theoretically risks collisions that could cause undefined behaviour or leak private information).
- **Cache isolation:** a per-request `cache_salt` is injected into the hash of the *first* block, so only requests carrying the same salt can reuse each other's cached blocks. The stated purpose is to prevent timing-based probing (inferring cached content from latency differences) in shared environments.
- **Lookup and allocation flow:** for a new request the scheduler calls `get_computed_blocks`, which hashes the prompt tokens and looks the hashes up in the global `cached_block_hash_to_block` map, then `find_longest_cache_hit` returns the longest matching prefix. `allocate_slots` then "touches" the hit blocks (reference count +1, removed from the free queue so they cannot be evicted mid-use) and allocates fresh blocks for the uncached suffix. When a block fills during decoding it is immediately entered into the cache map, so it can be reused by other requests in the same batch.
- **Eviction is LRU over the free queue:** when the head (least-recently-used) block of the free queue is a cached block and a fresh allocation needs it, the block is evicted — popped from the queue, its id removed from the cache map, its hash cleared — and only then reused. A cached block that is still referenced is never evicted.
- **A known V1 quirk — duplicated blocks:** because the V1 block table is append-only, a request that re-derives a block already cached under the same hash cannot be re-pointed at the existing block mid-request (V0 did that re-pointing); the duplicate persists until the request is freed, when it is eliminated. The design doc documents this openly as a V1 limitation.
- **What it does not do:** prefix caching shortens *prefill only*. It does nothing for decode, and it brings no gain for long answers where generation dominates — the docs say so. It is also prefix-only: only leading tokens can be skipped, never a middle substring. And a hit requires a whole-block match; a prompt that shares 15 of 16 tokens with a cached block still recomputes that block.
- **Multimodal note:** image placeholder tokens are distinguished by folding the image hash (from the front-end image processor) into the extra hashes, so two requests with the same placeholder layout but different images do not collide.

### 4.3 KV cache quantisation and offload options

**Quantised KV cache** is independent of weight quantisation and is controlled separately by `kv_cache_dtype`:

- The supported values in current docs are `fp8` (and `int8` in older discussion; the current quantisation page lists "Quantized KV Cache" as a supported format family and the FP8 KV cache is listed as functional in the V1 guide). FP8 KV halves the per-token KV memory, doubling the concurrency or context that fits — at a small accuracy cost. A 2026 vLLM study reported in secondary sources (blog, August 2026) concluded FP8 KV (e4m3) was "ready to be the default starting point for many long-context deployments" after fixes for a FlashAttention-3 long-context precision bug (two-level accumulation, per-head scales); the same study shipped experimental `turboquant` variants (FP8 keys + 4-bit values at 2.6× compression, 3-bit at 3.8×) but kept FP8 as the recommended default. Those are secondary-source claims; I did not read the underlying study itself.
- Weight quantisation (AWQ/GPTQ) is weight-only and does *not* quantise the KV cache; the two can be combined freely (e.g. AWQ weights + FP8 KV), because AWQ/GPTQ weights are dequantised to higher precision for compute. The forum answer the docs link to states vLLM does not support INT4 KV cache, for hardware/kernel reasons.
- **CPU swap / offload tiers in V1:** there is no general GPU↔CPU KV swap in V1 (§3.3 — removed). Offload in the current architecture happens instead through the **KV connector** mechanism (§3.4): KV blocks can be stored in, and loaded from, an external KV service. That is a different shape from V0's swap — it is a serving-topology feature, not a memory-pressure relief valve for a single engine. There is no documented "spill to host RAM when the pool fills" tier inside one V1 engine; when the pool fills, the answer is preemption.

### 4.4 Disaggregated prefill/decode (KV transfer) — design level

Prefill (compute-bound) and decode (memory-bandwidth-bound) have different performance profiles, so separating them lets each be scaled and tuned independently — prefill for time-to-first-token, decode for inter-token latency. The docs mark disaggregated prefilling as **experimental** and note explicitly that it does *not* improve throughput; it helps tune TTFT and tail latency separately.

Design, as documented:

- **Topology:** N prefill instances and M decode instances, autoscaled on the live request mix, fronted by a router. In the current LMCache documentation the minimal deployment is five processes: a prefill vLLM, a decode vLLM, one LMCache server per vLLM instance, and a router (`vllm-router --vllm-pd-disaggregation`) that sends each request to a prefill instance first and then to a decode instance, threading the transfer handshake between them.
- **The connector abstraction:** a `KVTransferConfig` names a `kv_connector` and a `kv_role` (`kv_producer`, `kv_consumer`, or `kv_both`). The connector interface is explicitly described in the anatomy post as *not yet stable*, with near-term breaking changes expected. Connectors are created in two places — inside the worker (role "worker") and inside the scheduler (role "scheduler").
- **The transfer flow:** during scheduling, after local prefix-cache checks, the scheduler asks the connector for externally cached tokens (`get_num_new_matched_tokens`; prefill always sees 0, decode may hit). At the end of scheduling it builds connector metadata: prefill marks its requests as store, decode as fetch. Around the forward pass a connector context manager runs: on entry the decode side loads KV from the external service into paged memory (`start_load_kv`); on exit the prefill side blocks until its KV is uploaded (`wait_for_save`). Decode loads external KV only once, on the first step of its requests; afterwards it computes and stores locally. Transfers can also be done layer-by-layer (before/after each attention layer) depending on configuration.
- **Production connector — LMCache + NIXL:** the fastest production-ready connector in the anatomy post's assessment is LMCache, backed by NVIDIA's NIXL (NVIDIA Inference Xfer Library) over UCX/RDMA. LMCache runs in two modes with vLLM V1: in-process (`LMCacheConnectorV1`, inside the vLLM process) and multi-process (`LMCacheMPConnector`, a standalone `lmcache server` owning KV storage, recommended for distributed storage and cross-instance sharing). In the disaggregated LMCache deployment the two connectors are composed with a `MultiConnector`: `NixlConnector` handles the prefill→decode handoff for the current request over NIXL, and `LMCacheMPConnector` handles offload/load to the instance's LMCache server for cross-request reuse. The KV-source order on the prefill path is: local GPU cache → LMCache → recompute. LMCache's own tiering is CPU DRAM, NVMe (via GPUDirect Storage), then object stores / Redis / Valkey / Bigtable / Mooncake / NIXL back ends, with CacheGen compression for constrained links and CacheBlend for non-prefix reuse (per the LMCache docs via secondary coverage).
- **Numbers attached to this (handle with care):** a November 2026 Medium guide claims, on an 8-node, 64× H200, 400 Gb/s RoCEv2 cluster serving a 70B dense model and a 671B MoE under long-context RAG traffic, that NIXL disaggregation cut p99 inter-token latency by 74% and boosted GPU goodput 2.4×. That is a vendor-style Medium post, not a vLLM project measurement, and its hardware (64 datacentre GPUs) is many orders from our target; cited only to show the *claimed* shape of the win, not as a verified result. The vLLM docs' own caution — experimental, no throughput gain, latency-tuning only — is the more authoritative statement.
- **Failure handling:** a `kv_load_failure_policy` can be set to `fail` so a failed transfer surfaces instead of silently recomputing (LMCache docs). Single-node NIXL over localhost uses loopback/TCP, not RDMA, so single-node numbers are functional tests only, not representative latencies.

---

## 5. Memory management

### 5.1 How the KV pool is sized — the profiling run

vLLM does not allocate KV memory on demand. At start-up it claims the GPU up front, in this order:

1. **Load the weights** onto the GPU.
2. **Profile.** Run a dummy/profiling forward pass (at the largest batch the configuration allows) to measure peak activation memory, and estimate CUDA graph memory (v0.21.0+ accounts for graph memory in the estimate; earlier versions could misjudge it).
3. **Take the budget.** The budget is `gpu_memory_utilization` × total GPU memory. Whatever remains under that cap after weights, profiled peak activations, CUDA graph buffers and other runtime overheads becomes the KV cache pool, which is allocated up front and carved into fixed-size blocks. The engine logs the resulting capacity in tokens at start-up — the guides call that the most important number about a server.
4. **Refuse to boot if it does not fit.** If the remainder is too small for `max_model_len` (i.e. the KV for one sequence at full context does not fit), vLLM refuses to start and says so.

The formula, in words: *KV pool = utilisation × total VRAM − weights − profiled activations − CUDA graph buffers − runtime overhead.* Everything draws from the same budget; weights are fixed for a model and precision, activations and graph buffers scale with batch size and sequence length.

### 5.2 `gpu_memory_utilization` — and a documentation disagreement

The flag is the single most important memory knob. **Disagreement found (recorded as required):** sources disagree on its default. The long-standing default reported across tutorials and troubleshooting guides is **0.90**. The current docs (v0.30-era attention/quantisation pages and the optimisation guide I read) variously show 0.90 and 0.92, and one careful secondary analysis (August 2026, checked against v0.27.1) states the default "has changed across releases (0.9 for a long time; the current docs show 0.92)". A separate September 2026 guide says the default was lowered from 0.95 to 0.9 because start-up profiling could misjudge peak use, quoting maintainer Woosuk Kwon to the effect that profiling should be made more accurate and the value set back to 0.95. **Resolution for this dossier:** treat the default as *version-dependent, 0.90–0.92 in the 2026 releases*, and always set it explicitly and check `vllm serve --help` for the version in use. The semantics are stable across versions: it is a fraction of *total* VRAM, not of free VRAM — so two instances at 0.9 on one GPU will OOM, a second instance or a display server sharing the GPU breaks the arithmetic, and `nvidia-smi` showing ~90% memory in use on an idle vLLM server is correct behaviour (pre-allocation), not a leak.

Practical guidance from the docs and guides, consistent across sources: on a dedicated GPU, 0.90–0.95 is the usual range (0.95 buys real KV capacity and is the cheapest capacity available; it costs the safety margin). On a shared GPU, divide by the number of resident processes. Lowering the value fixes a CUDA OOM at start-up but *worsens* a "no available memory for the cache blocks" error, which needs the value raised (or `max_model_len` lowered) — the two failure modes need opposite fixes, and several guides warn that the widely copied "just lower it to 0.80" advice is wrong half the time.

### 5.3 Fragmentation stance

Fragmentation is the problem PagedAttention exists to solve, and the V1 stance is structural rather than tuned: because KV is allocated in fixed-size blocks from a single pool, a finished request's blocks return to the free queue and are immediately reusable by any other request; there is no per-request contiguous reservation to fragment. The only waste is the tail of the last block of each sequence (at most 15 tokens per sequence at block size 16) plus the duplicated-block quirk in §4.2. The 2023 paper's measurement — that contemporary systems held real token state in only 20.4–38.2% of KV cache memory — is the baseline the design answers; I did not re-verify that figure against the paper for this dossier (it belongs to the companion paper dossier). There is no documented defragmentation pass, compaction step, or fragmentation metric in the current docs; the design assumes block allocation makes fragmentation a non-issue, and the residual waste is the per-sequence tail block.

### 5.4 CPU swap / offload tiers

As established in §3.3 and §4.3: **V1 has no CPU swap tier inside one engine.** The V0 GPU↔CPU swap is removed. The tiers that exist are:

- **GPU HBM** — the only tier the scheduler itself manages.
- **External KV service via connectors** — LMCache (DRAM → NVMe → object store) or a shared-storage connector; this is cross-instance and cross-request storage, reached through the connector API, not a spill tier the scheduler falls back to under pressure.
- **Host RAM as a side effect** — the API server, tokeniser, and multimodal caches live in host RAM (the multimodal processor cache defaults to 4 GiB, tunable via `mm_processor_cache_gb`), but that is input data, not KV spill.

For a laptop runner this is a sharp lesson: vLLM's answer to "KV pool full" is "preempt and recompute", never "spill to RAM and keep going". A single-user design that wants graceful degradation under memory pressure has to invent the spill tier vLLM deliberately deleted.

---

## 6. Quantisation & kernels

### 6.1 Supported quantisation ecosystems

The current quantisation page (docs, accessed 2026-11-15) lists as supported: **AutoAWQ, BitsAndBytes, GPTQModel, Intel Neural Compressor, LLM Compressor** (with FP8 W8A8, INT4 W4A16, INT8 W4A8, INT8 W8A8 under it), **NVIDIA Model Optimizer, Online Quantization, AMD Quark, Quantized KV Cache, TorchAO, FP8 ViT Encoder Attention**. Removed: the `fp_quant` method and the QuTLASS back end (use a compressed-tensors checkpoint instead). Out-of-tree quantisation methods can be registered with a decorator (`@register_quantization_config`) without modifying the codebase.

The hardware compatibility table on the same page (subject-to-change, by the docs' own note) shows, in summary: AWQ runs on Turing/Ampere/Ada/Hopper/Intel GPU/x86 CPU but not Volta or AMD GPU; GPTQ runs on Volta through Hopper plus Intel GPU and x86 CPU but not AMD GPU; Marlin (GPTQ/AWQ/FP8/FP4) on Turing–Hopper; llm-compressor FP8 W8A8 on Ada/Hopper/AMD GPU; llm-compressor INT8 W8A8 on Turing–Hopper/x86/Arm CPU; GGUF on Volta–Hopper and AMD GPU. (The full table is in the source; the pattern to carry away is that *every* quantisation choice is hardware-gated, and the docs' table is the authority, not any summary.)

Two behaviours that matter for engineering:

- **Checkpoint-driven selection.** For pre-quantised checkpoints vLLM reads the quantisation method out of the checkpoint's own config; the operator generally does not pass `--quantization` at all, and passing it only asserts consistency. (Secondary source, checked against v0.27.1.)
- **Activation-quantisation fallback.** A checkpoint requesting W8A8 or W4A4 falls back to a weight-only kernel (Marlin, Humming, CPU W8A16) running activations in 16-bit if the kernel for the requested activation quantisation is unavailable — W8A8 runs as W8A16, W4A4 as W4A16 — at no accuracy cost but not the calibrated scheme; a warning is logged once. `VLLM_STRICT_QUANT_SCHEME=1` forbids the fallback and fails start-up instead. Marlin no longer quantises activations to INT8/FP8 at all (the `VLLM_MARLIN_INPUT_DTYPE` variable was removed; setting it is an error); W4A8 via the `humming` method is the current route.
- **FP8 is the 2026 production default on Hopper+.** FP8 W8A8 (native on Hopper H100/H200, and on AMD MI300X/MI355X via ROCm per secondary sources) is described in several 2026 guides as near-lossless (~99% quality, ~0.1–0.3% perplexity increase) with roughly a third faster inference and half the weight/activation memory; FP4 (NVFP4/MXFP4) arrives on Blackwell B200. On older hardware (Ampere and below) FP8 checkpoints still load as weight-only W8A16 through FP8 Marlin — the memory saving is kept, the FP8 arithmetic is lost. **GGUF note:** since a June 2026 change, GGUF lives outside vLLM core (a separate `vllm-gguf` plugin); it is absent from the core quantisation-method list in v0.27.1. That matters for any Ollama-facing comparison, since GGUF is Ollama's native format — vLLM treats it as a peripheral, not a first-class citizen.

### 6.2 Attention back ends

Attention is a plug-in registry. The back-end feature-support page (auto-generated from the registry) documents selection:

- **Explicit:** `--attention-backend FLASH_ATTN` (or the structured `--attention-config.backend`).
- **Automatic (default):** vLLM iterates back ends in priority order, validates each against the configuration (model dtype, head size, compute capability), and takes the first compatible one.
- **Priority on CUDA, standard attention:** on Blackwell (SM 10.x) the order is FlashInfer first, then FlashAttention, then Triton attention; on Ampere/Hopper the order is FlashAttention first, then FlashInfer (secondary source, consistent with the docs page's tables). There are composite back ends for multimodal-prefix configurations — `TRITON_FLASH_ATTN` on Hopper and `TRITON_FLASHINFER` on Blackwell — which use Triton where a batch needs bidirectional image attention and FlashAttention/FlashInfer for causal text prefill and decode, sharing one KV cache. Per-KV-cache-group overrides are possible (`backend_per_kind`, e.g. different back ends for full vs sliding-window attention groups), and FlashAttention version can be forced (2, 3, or 4).
- **The families:** FlashAttention (versions 2/3/4 across the hardware generations; FA3 for Hopper, FA4 for Blackwell shapes), FlashInfer (paged and ragged KV, plus GEMM/MoE/sampling/communication kernels; the library underneath vLLM and SGLang), Triton attention (the portable fallback, and the basis of the AMD V1 back end built on Triton kernels), plus MLA-specific back ends for DeepSeek-style multi-head latent attention (FlashInfer MLA, Triton MLA, TRTLLM ragged) and ROCm-specific ones.
- **What the back end does in the design:** it is the layer that consumes the block tables and executes paged attention over non-contiguous KV blocks. The choice is validated, not merely preferred — an incompatible explicit choice raises an error with the reason.

### 6.3 Speculative decoding

Speculative decoding is documented as a latency optimisation for medium-to-low queries-per-second, memory-bound workloads: a cheap proposer guesses several tokens ahead, the large model verifies them in one forward pass, and the longest prefix the large model agrees with is kept. The acceptance rule preserves the target model's distribution in expectation (the classic draft–verify–accept/reject loop, with a rebalanced distribution sampled at the first rejection).

Methods supported in current docs (the method list has grown well past the 2023 paper's draft-model picture):

- **Model-based (best latency reduction):** EAGLE and EAGLE-3 (the EAGLE lineage: a lightweight draft built by surgery on the large model — keep embeddings and LM head, replace the transformer stack with a small MLP, fine-tune it as a cheap draft; EAGLE-3 moves to direct token prediction over fused features with a training-time-test scheme), MTP / multi-token prediction (models trained natively with multiple prediction heads, e.g. the DeepSeek lineage, reuse the target's own MTP layers as the draft), a generic **draft model** (a separate small LM), and PARD (parallel draft model). EAGLE-3 is reported in secondary sources at acceptance rates of 0.8–0.9 and speedups up to ~6.5× at batch size 1 on benchmarks — those are secondary figures, not vLLM project measurements.
- **Draft-free (modest speedups, no extra model, no extra VRAM pressure at peak traffic):** **n-gram** (prompt lookup: take the last tokens, find a prior match in the prompt/output, propose the tokens that followed it; window bounded by `prompt_lookup_min`/`prompt_lookup_max`, `num_speculative_tokens` proposals) and **suffix decoding** (a suffix tree built over the request's history; dynamic speculation depth; requires Arctic Inference for the suffix path in some builds). The docs' own method-selection table is candid: n-gram and suffix give low-to-medium gain at low QPS and medium gain at high QPS, while EAGLE/draft-model give high gain at low QPS and medium-to-high at high QPS.
- **Also listed:** LiLiCorr and DFlash in the docs' method enumeration (the README, as summarised in a November 2026 comparison, lists n-gram, suffix, EAGLE and DFlash). Medusa (auxiliary prediction heads on the large model) appears in the 2025 anatomy post's account of V1 ("V1 does not support the LLM draft model method, instead it implements faster-but-less-accurate proposal schemes: n-gram, EAGLE, and Medusa") — **but the current docs' method list no longer foregrounds Medusa or a plain draft-model exclusion in the same way**, and the current docs do list a generic draft-model method. The anatomy post is August 2025; the docs are current. I record the disagreement as a *time* difference (the method set changed between August 2025 and late 2026) rather than a contradiction, but a reader should not rely on the anatomy post's method list as current.
- **Configuration:** a single JSON `speculative_config` (or `--speculative-config` on the CLI), with `method`, `model` (draft/EAGLE checkpoint; omitted for n-gram/suffix/MTP), `num_speculative_tokens`, and method-specific keys. Draft models can themselves be quantised. The project maintains a separate `vllm-project/speculators` repository for training draft models.
- **Interaction warning from the field:** the docs' method table and a secondary analysis both note that LoRA + speculative decoding is listed as unsupported in the feature-compatibility matrix — a combination a multi-adapter deployment has to plan around (merge the adapter, or serve it on a separate instance with speculation).

---

## 7. Serving surface

Briefly, as design ideas (this dossier's focus is the engine, not the API):

- **OpenAI-compatible server** is the primary front end: `vllm serve <model>` starts an HTTP server speaking the OpenAI chat/completions API, so existing OpenAI clients can be repointed at a self-hosted endpoint without rewriting application code. The older `python -m vllm.entrypoints.openai.api_server` invocation is deprecated in favour of `vllm serve`. The server also exposes an Anthropic Messages API and gRPC support, streaming, and Prometheus metrics (`/metrics`).
- **Structured outputs (guided decoding).** Outputs can be constrained to a JSON schema, regex, choice list or grammar. The mechanism is a grammar-compiled finite-state machine: the grammar is compiled asynchronously (status `WAITING_FOR_FSM` until ready), a bitmask over the vocabulary is maintained, and disallowed logits are masked to −∞ after each forward pass before sampling; the FSM advances as tokens are accepted. Back ends are third-party libraries — **XGrammar** is the default, with Guidance (and Outlines / llguidance as options in the docs' comparison). The LM Format Enforcer back end is deprecated, due for removal in v0.35.0 (per the v0.33.0 release-candidate notes summarised November 2026). The older `guided_json` / `guided_regex` request fields were removed in v0.12.0; current clients use `response_format` / `structured_outputs` in the request body. The design idea worth stealing is the *bitmask over the vocabulary applied post-logits* — a clean separation between the grammar compiler and the sampler.
- **Multi-LoRA.** Many LoRA adapters can be served on one base model without loading multiple full models: adapters are named at start-up (`--lora-modules name=path`, with `--enable-lora`), and the client selects one per request by putting its name in the `model` field. Support covers dense and MoE layers. The KV-cache consequence is real: prefix-cache blocks are keyed with the LoRA id in the extra hashes (§4.2), so each adapter caches its own copy of a shared system prompt — fine at two adapters, wasteful at forty (secondary analysis). And LoRA + speculative decoding is unsupported (§6.3).
- **Tool calling and reasoning parsers** are part of the serving layer (the README lists tool-call and reasoning parsers alongside the APIs), as are multimodal inputs (the multimodal processor cache, §4.4) and pooling/embedding/reward models — vLLM is a general inference server, not a chat-only one. The offline `LLM.generate` API is the same engine without the HTTP layer.

---

## 8. Strengths / weaknesses

### Strengths

- **The KV cache is a solved problem at datacentre scale.** Block allocation, hash-chained prefix caching on by default, and LRU eviction over a single pool together remove the fragmentation and recomputation waste that dominated pre-vLLM serving. This is the project's durable contribution, and the reason every other engine copied it.
- **The unified scheduler composes.** One token budget, no phases — chunked prefill, prefix caching and speculative decoding stop fighting each other over phase boundaries, which is what made all three cheap to enable by default.
- **Breadth is unmatched in open source.** Model coverage (decoder-only, MoE, hybrid Mamba, multimodal, pooling, Whisper), hardware coverage (NVIDIA/AMD/Intel/TPU/CPU), quantisation coverage (§5.1), and serving surface (OpenAI + Anthropic + gRPC, structured outputs, multi-LoRA) in one project. The PyTorch Foundation hosting (May 2025) and ~93,000–97,000 GitHub stars across the sources I read (the count moves with the crawl date; ~97k in one November 2026 index, ~93k in a September 2026 radar — the order of magnitude is the point) reflect that breadth.
- **Near-zero CPU overhead in the hot loop** is a real architectural achievement, not a slogan: process isolation plus ZMQ plus torch.compile plus CUDA graphs is a coherent answer to "Python is slow".
- **Disaggregation and KV connectors** give operators a genuine second axis (latency tuning) beyond "add GPUs", and LMCache turns the KV cache into a shared, tiered, cross-instance resource.

### Weaknesses (including the honest ones the project states itself)

- **Throughput over latency, by design.** Every mechanism optimises aggregate tokens per second across many users. Single-request latency (time-to-first-token for one user, inter-token latency at batch size 1) is a secondary objective, improved only insofar as chunked prefill and speculative decoding happen to help it.
- **Disaggregated prefill is experimental and does not improve throughput** (docs' own words). The connector interface is not yet stable and has breaking changes planned. LMCache's multi-process path has had version-skew failures (e.g. the Dynamo docs note an `Unsupported GPUKVFormat` failure on vLLM ≥ 0.20.0 fixed only on LMCache main).
- **Feature churn is fast and breaking.** `guided_json` removed in v0.12.0; V0 fully deprecated; swap removed in V1; GGUF moved out of core; `fp_quant`/QuTLASS removed; Marlin activation quantisation removed; defaults (notably `gpu_memory_utilization`) drift between releases. Pinning a version is not optional.
- **The memory model is greedy and brittle at the edges.** Pre-allocating ~90% of VRAM at start-up means a shared GPU, a display server, or a second process breaks start-up; profiling can misjudge peak activation/graph memory (the stated reason the default was cut from 0.95 to 0.90); and the failure modes need opposite fixes (§4.2). There is no graceful degradation — only preemption.
- **CPU support is a port, not a peer.** The V1 guide lists CPU as functional, but the design (CUDA graphs, FlashAttention/FlashInfer back ends, torch.compile for CUDA) is CUDA-first throughout; CPU exists for development and for specific deployments, not as a performance target.
- **Complexity and operational weight.** A production deployment is several processes (API servers, engine core, workers, optionally a coordinator, a router, LMCache servers), ZMQ sockets, NCCL groups, CUDA graph capture, and a Prometheus surface. That is the correct price for a datacentre engine and the wrong price for a laptop.

### Honest unsuitability for a 6 GB single-user laptop — stated precisely

vLLM is not merely "heavy" on a 6 GB laptop; it is wrong in four specific, locatable places:

1. **The memory claim does not fit.** The start-up sequence (§5.1) loads full weights, profiles peak activations, reserves CUDA graph buffers, and then claims `gpu_memory_utilization` (0.90–0.92) of *total* VRAM as a KV pool. On a 6 GB card that is ~5.4–5.5 GB before a single token is generated — and a 7–8B model in bf16 alone is ~15 GB, so it cannot load at all without 4-bit quantisation (~4–5 GB for the weights), leaving of the order of a gigabyte for activations, graphs and KV combined. The engine will refuse to boot (`no available memory for the cache blocks`) or OOM during profiling/graph capture. There is no mode in which vLLM runs a 7B model in 6 GB and degrades gracefully; the sizing logic assumes a datacentre card where weights are a minority of VRAM.
2. **The Python stack is the product.** The control plane is Python + PyTorch + CUDA + (usually) FlashAttention/FlashInfer + torch.compile + ZMQ + an HTTP server. The install is a large wheel set with a CUDA-matched PyTorch; the process count at rest is several processes; the resident overhead (interpreter, torch, CUDA context, graph buffers) is measured in gigabytes before the model loads. A Go single-binary runner's entire pitch is the absence of exactly this stack.
3. **CUDA-first, with everything else a port.** The performance path — FlashAttention/FlashInfer, CUDA graphs, torch.compile/Inductor, NIXL/RDMA — is NVIDIA CUDA. On a laptop without a datacentre NVIDIA GPU (integrated graphics, Apple Silicon, a small consumer card, or CPU-only), the engine falls back to the Triton/CPU paths that exist but are not where the optimisation effort goes. The V1 launch itself supported only Ampere-or-later NVIDIA GPUs; AMD support arrived later via a Triton back end built by AMD/IBM/Red Hat.
4. **Throughput-over-latency tuning fights the single-user experience.** The scheduler's virtues — a large `max_num_batched_tokens` for throughput, prefix caching across *many* users' shared prompts, disaggregation across instances — pay off when dozens of requests share the GPU. With one user, the batch is usually size 1: continuous batching has nothing to batch, prefix caching only helps across *turns* of the same conversation (which it does — see §9.2), and the token-budget machinery is pure overhead against a simple "prefill the prompt, then decode" loop. The preemption policy is the sharpest example: recompute is cheap when the preempted request is one of hundreds and short; for a single user whose one long conversation is preempted, recompute means re-running a long prefill the user is waiting on, with no other request benefiting.

None of this is a criticism of vLLM. It is a statement of *fit*: the engine is optimised for a problem (many users, big GPUs, throughput) that is the opposite of the laptop problem (one user, small memory, latency and responsiveness). The right move is to steal its ideas at single-user scale (§9), not to port the engine.

---

## 9. Ideas to steal for a Go single-user runner

Each idea is translated to single-user scale, with an expected gain, a cost, and a risk. Gains are qualitative (no benchmarks were run for this dossier); "large" means it changes the feel of the product, "moderate" means a measurable but not transformative win.

### 9.1 Block-table KV in miniature

**The idea (from vLLM):** allocate the KV cache as a pool of fixed-size blocks (16 tokens), hand them out per request through a block table that maps logical blocks to physical blocks, and return them to a free list on completion. Never reserve a contiguous slab per sequence.

**Single-user translation:** one conversation is one sequence, so the pool is small — but the *mechanism* still pays. A Go runner today typically grows a KV buffer per sequence (append, reallocate, or pre-allocate the full context window). Replace it with a block pool: a fixed arena of, say, 32-token blocks (larger than vLLM's 16 — see the trade-off below), a free list, and a per-sequence slice of block ids. Growing the conversation allocates one block at a time; truncating or clearing the context returns blocks; switching models or contexts never leaves a half-used giant slab stranded.

**Expected gain:** moderate. The win is not throughput (there is no multi-user packing to do) but *memory honesty*: the runner can hold a longer context in the same RAM, report exact KV usage ("context is 61% full"), and support cheap context operations (fork a conversation branch by sharing blocks with a reference count; drop the tail by freeing blocks) that a contiguous buffer makes expensive or impossible.

**Cost / risk:** low-to-moderate. The block table is a small indirection layer; the attention kernel must gather KV through it (llama.cpp-style GGML already does block-like KV layouts, so this is a known shape, not an invention). The main risk is kernel complexity: every attention implementation in the runner has to go through the table. Mitigate by making the block size a build-time constant and keeping the table a plain slice of ints. **Block-size choice is the lever:** vLLM's 16 tokens minimises tail waste per sequence but maximises table overhead; with one sequence, a 32- or 64-token block wastes at most 63 tokens of KV at the tail — negligible — and halves/quarters the table work and the hash work in §9.2. Steal the mechanism, not the constant.

### 9.2 Hash-chained prefix caching

**The idea (from vLLM):** hash each full KV block from its parent block's hash plus its exact token ids (plus extras: adapter id, media hash, tenant salt). Keep a hash → block map. On a new prompt, hash its blocks, find the longest cached prefix, reuse those blocks, and compute only the suffix. Evict least-recently-used from the free queue. Only full blocks are cached; only a prefix can be skipped.

**Single-user translation:** this is the highest-value steal in the dossier, because the single-user workload *is* prefix reuse: every turn of a chat resends the system prompt plus the whole history. Implement it as: a map from block hash to block id, a reference count per block, and a lookup at prefill time. On each user turn, hash the (system prompt + history) blocks, reuse the hits, prefill only the new turn's tokens. Use a fast non-cryptographic hash (xxHash or FNV — the multi-tenant collision attack that forces vLLM onto SHA-256 does not apply to a single user on their own laptop; a 128-bit hash is ample), and hash only full blocks.

**Expected gain:** large. For a multi-turn chat, prefill per turn drops from O(full history) to O(new tokens only). Time-to-first-token on turn N becomes nearly independent of conversation length (up to the block-alignment remainder). This is the difference between a chat that gets slower every turn and one that stays flat.

**Cost / risk:** low-to-moderate. The hash must be computed over token ids (cheap — tens of nanoseconds per token in vLLM's measurement, and a single-user prompt is short). The subtleties to copy carefully from vLLM: (a) fold anything that changes the KV into the hash — the model id, the LoRA adapter if any, and any sampler-affecting state must not leak across; vLLM's "extra hashes" are the pattern; (b) handle the partial tail block (the last, incomplete block of a prefix is never cached — recompute its remainder); (c) eviction must be LRU over *free* blocks only, never a block still referenced by the live conversation; (d) when the user edits an earlier message, the hash chain breaks at the edit point — everything after it recomputes, which is correct and is also the reason to keep blocks small enough that an edit does not invalidate a huge span. **Do not copy** vLLM's SHA-256 default or its pickle serialisation — both are multi-tenant defences a laptop does not need.

### 9.3 Chunked prefill for responsiveness

**The idea (from vLLM):** cap the number of new tokens per engine step (`max_num_batched_tokens`); a prefill that does not fit is split across steps, and decode requests are served first out of each step's budget. One long prompt can no longer freeze the stream.

**Single-user translation:** with one user there is no competing decode stream to protect — but there *is* a UI to protect. A long paste, a big file dropped into context, or a "summarise this 100k-token document" prompt is a prefill that takes seconds to minutes on a laptop, during which the interface is frozen and the user cannot cancel, and the first token is delayed by the whole prefill. Chunk it: prefill in slices of, say, 512–2048 tokens per step, yield control to the event loop (and to a cancel check) between slices, and stream a progress indicator ("prefilling… 12,400 / 96,000 tokens"). The first token still waits for the full prefill — chunked prefill does not shorten time-to-first-token for the request itself — but the *application* stays alive, cancellable, and honest about progress.

**Expected gain:** moderate for feel, zero for raw speed. It converts a freeze into a progress bar. On a laptop that is often the difference between "the app hung" and "the app is working".

**Cost / risk:** low. The mechanism is a loop bound and a yield point; the attention implementation must support attending over a partially prefilled prefix (position offsets per chunk), which any chunked implementation already needs for §9.2's suffix prefill. The risk is a subtle correctness bug in position/attention-mask bookkeeping across chunk boundaries — test with a long prompt computed chunked vs whole and diff the logits. The tuning question is the chunk size: too small and kernel-launch overhead dominates (vLLM's guidance — smaller budget for latency, larger for TTFT — maps here to smaller chunks for UI responsiveness, larger chunks for raw prefill throughput).

### 9.4 Preemption-by-recompute — with a laptop-sized caveat

**The idea (from vLLM):** when the KV pool fills, free a request's blocks and recompute it later from its prompt. No swap to host RAM; recompute is cheaper than a PCIe transfer in the datacentre.

**Single-user translation:** the single-user analogue of "pool full" is "context window full" (or RAM full). The vLLM answer — discard and recompute — is *half* right for a laptop. Recompute is the correct fallback when the discarded span is short (a few hundred tokens: re-prefill is a second or two). It is the wrong fallback when the discarded span is the user's whole 32k-token conversation (re-prefill is minutes on a laptop, and the user is waiting on exactly that). So steal the *policy shape* (a defined preemption order and a recompute path that always works) but change the *victim and the tier*:

- **Victim order:** preempt the *oldest, least-recently-used* cached prefix blocks first (the §9.2 cache), never the live conversation's tail. If the live conversation itself no longer fits, summarise-and-truncate or spill — do not silently recompute the whole thing.
- **Add the tier vLLM deleted:** a host-RAM (or disk) spill for KV blocks. On a laptop, RAM is plentiful relative to VRAM and the transfer is over a local bus, not a datacentre fabric — the cost calculation that made swap more expensive than recompute in vLLM's V1 *inverts* on a laptop for long contexts. Spilling the oldest conversation turns to RAM and loading them back on demand is the correct laptop analogue of vLLM's connector-based offload (§4.4), at single-user scale.
- **Keep a recompute path as the ultimate fallback** (it must always work, even if the spill is corrupt or missing), and make preemption visible: log it, and if it happens to the live conversation, tell the user ("context was compacted") rather than silently degrading.

**Expected gain:** moderate (robustness, not speed). The product stops crashing or freezing when context fills, and degrades in a way the user can understand.

**Cost / risk:** moderate. A spill tier is real engineering (serialisation format, integrity checks, eviction policy, load-on-demand). The risk of *not* doing it is worse: either the runner OOMs, or it recomputes a long context on every turn. Start with the cheap version — spill whole *turns* (aligned to block boundaries from §9.2) to a file, keyed by the same hash chain, so a spilled turn can be reloaded by hash instead of recomputed.

### 9.5 (Smaller steals, noted briefly)

- **Decode-first within a step.** Even with one user, the runner sometimes has two things to do at once (the live generation, and a background prefill — e.g. pre-warming the next turn's system prompt, or a background embedding). vLLM's rule — serve running decodes before admitting new prefill out of the same token budget — is the right priority, and it is three lines of scheduler logic.
- **A token budget, not a phase flag.** Replace any "are we prefilling or decoding" boolean with a per-step token budget. It is the change that lets chunked prefill (§9.3), prefix-cache suffix prefill (§9.2) and speculative decoding compose instead of special-casing each other.
- **Structured outputs as a vocabulary bitmask.** Constraining sampling by masking disallowed logits to −∞ after the forward pass, with the grammar compiled once up front, is a clean separation worth copying if the runner ever needs guaranteed-JSON output. The grammar compiler itself (XGrammar-class) is a large dependency; the *interface* (bitmask in, masked logits out) is the steal.
- **Profiling run at start-up.** vLLM's start-up profile — load weights, run a dummy pass, measure peak activation memory, then size the KV pool from what remains — is worth copying in miniature: measure, then allocate, rather than guessing a context size and OOMing mid-conversation. On a laptop the "profile" can be a cheap arithmetic estimate plus a small probe, not a full dummy forward pass.
- **What *not* to steal:** the multi-process EngineCore/ZMQ split (a single-user Go binary has no Python contention to isolate), CUDA graphs (no CUDA graph equivalent is needed when the batch is 1 and the kernel count per step is small), disaggregated prefill/decode across instances (there is one instance), and tensor/pipeline parallelism (there is one device).

---

## 10. Sources

All sources accessed **2026-11-15**. "Docs" means the vLLM documentation site (docs.vllm.ai); versioned doc URLs are given where the fetch returned one, "latest" where the page is the living doc. Secondary sources are marked as such; claims that rest only on a secondary source are flagged in the text.

**Primary — vLLM project:**

1. vLLM documentation, "vLLM V1" (V1 guide) — https://docs.vllm.ai/en/latest/usage/v1_guide/ — V1 goals, V0 deprecation (RFC #18571), unified scheduler, chunked prefill on by default, CUDA-graph memory note, feature table (functional / in progress / removed), hardware and model support, removed features (GPU↔CPU swap, `best_of`, per-request logits processors).
2. vLLM documentation, "Optimization and Tuning" — https://docs.vllm.ai/en/v0.16.0/configuration/optimization/ — preemption (RECOMPUTE default in V1), chunked prefill tuning (`max_num_batched_tokens`, >8192 for throughput, decode-first policy), parallelism strategies (TP/PP/EP/DP), API-server scale-out, multimodal caching, CPU requirements (1 API process + 1 engine-core process + N worker processes).
3. vLLM documentation, "Automatic Prefix Caching" (design doc) — https://docs.vllm.ai/en/latest/design/prefix_caching/ — hash-chain design (parent hash + block tokens + extra hashes), SHA-256 default since v0.11, `--prefix-caching-hash-algo` options (`sha256`, `sha256_cbor`, `xxhash`, `xxhash_cbor`), `cache_salt` isolation, block data structure (pool, free queue, ref counts), allocate/append/free/eviction (LRU) workflows, duplicated-blocks V1 quirk, free-in-reverse-order rule.
4. vLLM documentation, "Quantization" — https://docs.vllm.ai/en/latest/features/quantization/index.html — supported formats (AutoAWQ, BitsAndBytes, GPTQModel, Intel Neural Compressor, LLM Compressor FP8/INT8/INT4, NVIDIA Model Optimizer, Online Quantization, AMD Quark, Quantized KV Cache, TorchAO), hardware compatibility table, activation-quantisation fallback and `VLLM_STRICT_QUANT_SCHEME`, removed `fp_quant`/QuTLASS, out-of-tree registration.
5. vLLM documentation, "Speculative Decoding" — https://docs.vllm.ai/en/stable/features/speculative_decoding/ — methods (EAGLE, LiLiCorr, MTP, draft model, PARD, n-gram, suffix), method-selection table (model-based best at low QPS; n-gram/suffix modest, no extra load at peak), `speculative_config` keys, `vllm-project/speculators` for training draft models.
6. vLLM documentation, "Attention Backend Feature Support" — https://docs.vllm.ai/en/v0.30.0/design/attention_backends/ — `--attention-backend` / `--attention-config.backend`, automatic priority-order selection with validation, Blackwell order (FlashInfer, FlashAttention, Triton), composite back ends (`TRITON_FLASH_ATTN`, `TRITON_FLASHINFER`), per-kind overrides.
7. vLLM documentation, "LMCache Examples" (disaggregated) — https://docs.vllm.ai/en/latest/examples/disaggregated/lmcache/ — in-process vs multi-process LMCache, disaggregated-prefill example (≥2 GPUs, NIXL), KV sharing, `MultiConnector`.
8. vLLM blog, "vLLM V1: A Major Upgrade to vLLM's Core Architecture" (27 January 2025), via Red Hat Developer mirror — https://developers.redhat.com/articles/2025/01/28/vllm-v1-a-major-upgrade-vllms-core-architecture — V1 scope (scheduler, KV manager, worker, sampler, API server), multiprocessing/EngineCore, torch.compile + piecewise CUDA graphs, up-to-1.7× throughput claim, alpha limitations.
9. vLLM GitHub repository — https://github.com/vllm-project/vllm — licence (Apache-2.0, LICENSE file), project home. (README contents as summarised in secondary indexes; the repo itself was not cloned for this dossier.)

**Primary-adjacent — long-form technical walkthrough of the V1 codebase (used for internals, cross-checked against the docs above):**

10. Gordic, A., "Inside vLLM: Anatomy of a High-Throughput LLM Inference System", vLLM Blog, 5 September 2025 — https://vllm.ai/blog/2025-09-05-anatomy-of-vllm — analysis based on commit 42172ad (9 August 2025). EngineCore/ModelExecutor/Worker/ModelRunner/InputBatch structure; scheduler (decode-first, `allocate_slots`, free-block queue, 16-token blocks, block-byte formula); forward pass (flattened super-sequence); chunked prefill; prefix caching walkthrough (`hash_request_tokens`, `find_longest_cache_hit`, ref counts); guided decoding FSM (StructuredOutputManager, grammar bitmask, −∞ masking); speculative decoding (n-gram/EAGLE/Medusa as of August 2025 — see the method-list time note in §6.3); disaggregated P/D (KVTransferConfig, connector roles, `start_load_kv`/`wait_for_save`, LMCache+NIXL); MultiProcExecutor and distributed serving (DP coordinator, ZMQ DEALER, dummy lockstep steps).

**Secondary (used for corroboration, hardware context, and claims flagged as secondary in the text):**

11. Wikipedia, "VLLM" — https://en.wikipedia.org/wiki/VLLM — stable release 0.32.0, 18 October 2026; Apache-2.0; Berkeley Sky Computing Lab origin; PagedAttention summary.
12. Metarix, "vLLM vs SGLang vs TensorRT-LLM Compared" (accessed 14 November 2026) — https://metarix.io/vllm-vs-sglang-vs-tensorrt-llm — README feature list (speculative decoding n-gram/suffix/EAGLE/DFlash; disaggregated prefill/decode/encode), disaggregation marked experimental with no throughput gain, v0.33.0 release-candidate notes (CUDA 13.0-only wheels, LM Format Enforcer deprecation for v0.35.0), quantisation comparison.
13. Rubin Lake, "vLLM — Technology Radar" — https://rubinlake.com/en/technology-radar/data-platforms-and-mlops/vllm — ~93,000 stars, 2,000+ contributors, v0.30.0 (22 September 2026); PyTorch Foundation hosting 7 May 2025.
14. OpenSourceDex, "vllm" — https://opensourcedex.com/tool/vllm — ~97,000 stars, 24,824 forks, 7,953 open issues (crawl date November 2026); Python, Apache-2.0.
15. LMCache documentation, "Disaggregated Prefill" — https://docs.lmcache.ai/mp/disaggregated_prefill.html — five-process minimal deployment, MultiConnector (NixlConnector + LMCacheMPConnector), KV-source order (local GPU → LMCache → recompute), `kv_load_failure_policy`, single-node NIXL loopback caveat.
16. NVIDIA Dynamo documentation, "LMCache" — https://docs.nvidia.com/dynamo/v1.3.0/integrations/kv-cache-integrations/lm-cache — LMCache integration, `LMCacheMPConnector` GPU KV format failure on vLLM ≥ 0.20.0, disaggregated launch shape.
17. Residual Stream, "vLLM Architecture: Continuous Batching and Serving at Scale" (October 2026) — https://residual-stream.lvtan71.workers.dev/posts/vllm-architecture-explained/ — unified scheduler rule, process split, CUDA graphs, chunked-prefill simulation (512-token budget, ≤0.55 s gaps vs 4.2 s whole-prompt, laptop rig — simulation, not a vLLM benchmark).
18. Aicassindra, "vLLM on GPU, in Depth" (30 September 2026) — https://www.aicassindra.com/blogs/gpu/gpu_vllm_gpu.html — start-up profiling sequence, `gpu_memory_utilization` default drift (0.9 long-standing; current docs 0.92), worked KV-token budget (Llama-3.1-8B bf16, ~128 KiB/token, ~442k tokens on 80 GB at 0.90 — the author's arithmetic, not a measured result).
19. Spheron, "vLLM OOM Preemption Fix" (2026) — https://www.spheron.network/blog/vllm-gpu-memory-utilization-guide-fix-low-throughput-and-oom/ — default lowered 0.95 → 0.9 over profiling accuracy, Woosuk Kwon quotation on restoring 0.95.
20. Subodh KC, "vLLM CUDA OOM at Startup? Two Bugs, Two Opposite Fixes" (8 August 2026) — https://subodhkc.com/blog/fix-vllm-cuda-out-of-memory-kv-cache-docker — the two OOM failure modes and their opposite fixes; current docs default 0.92.
21. J. Reb, "Quantizing LLM Weights and the KV Cache" (9 August 2026) — https://blog.jreb.nl/2026/08/09/quantizing-llm-weights-and-kv-cache/ — FP8 KV study summary (FA3 precision bug, two-level accumulation, per-head scales, turboquant variants, FP8 as recommended default); FP8 production-default claims.
22. Particula, "AWQ vs GPTQ vs FP8" — https://particula.tech/blog/awq-vs-gptq-vs-fp8-quantization-choice — v0.27.1 support matrix, checkpoint-driven quantisation selection, GGUF moved out of core (June 2026 PR), FP8 W8A16 fallback on pre-Hopper hardware.
23. Teliaz blog, "Speculative Decoding: The Math, the Drafters, and When the Bet Pays Off" (27 October 2026) — https://blog.teliaz.com/2026/10/27/speculative-decoding-the-math-the-drafters-and-when-the-bet-pays-off/ — EAGLE-3 acceptance/speedup figures, vLLM method table reading, LoRA + specdec unsupported.
24. Asif Muhammad Iqbal, "Disaggregated Prefill-Decode in vLLM: NixlConnector Guide" (November 2026, Medium) — https://medium.com/@asifmuhammadiqbal/disaggregated-prefill-decode-in-vllm-nixlconnector-guide-58aa8306e170 — claimed 74% p99 ITL cut and 2.4× goodput on 64× H200 (vendor-style post; not a project measurement — see §4.4).

**Numbers and their hardware context.** Every performance number in this dossier carries its context where it appears: the 1.7× V1-vs-V0 claim is the project's own launch figure (benchmarks not reproduced here); the <1% prefix-caching overhead is the V1 team's figure; the 75 ns/token hash cost is from the design doc; the 442k-token worked example is one author's arithmetic for Llama-3.1-8B on an 80 GB GPU at 0.90 utilisation; the 74% / 2.4× disaggregation figures are from a Medium post on 64× H200s; the 0.55 s vs 4.2 s chunked-prefill figures are from a laptop simulation, not vLLM hardware. No benchmark was run for this dossier and none is claimed.

### What could not be verified

- **Exact current release number.** Sources accessed 2026-11-15 variously cite v0.30.0 (22 September 2026), v0.31.0 (October 2026), v0.32.0 (18 October 2026, Wikipedia stable release), and a v0.33.0 release candidate. I did not fetch the GitHub releases page directly, so I do not state a single "current version" — the dossier is written against the v0.30–v0.32 line and the living docs, and the reader should check the releases page for the number on the day they read this.
- **Exact `gpu_memory_utilization` default.** Documented as 0.90 in long-standing sources and 0.92 in current docs; see §5.2 for the disagreement and the resolution (set it explicitly).
- **Priority-scheduler victim selection.** The docs confirm priority scheduling exists and that low-priority requests are eviction candidates; the precise victim order under priority scheduling was not pinned down in the sources read. Marked as speculation in §2.4.
- **Speculative-decoding method list currency.** The August 2025 anatomy post and the current docs differ (Medusa / draft-model exclusion vs the current broader list); recorded in §6.3 as a time difference, with the current docs taken as authoritative.
- **Star/fork counts.** ~93k (September 2026 radar) vs ~97k (November 2026 index) — the count moves with the crawl date; only the order of magnitude is asserted.
- **Performance claims.** All throughput/latency figures in this dossier are attributed to their sources with hardware context (§9, "Numbers"); none was independently reproduced. The FP8-KV study and the EAGLE-3 acceptance figures rest on secondary summaries, not on the underlying studies, which I did not read.

---

*End of dossier OR-2 — vLLM. As of 2026-11-15.*
