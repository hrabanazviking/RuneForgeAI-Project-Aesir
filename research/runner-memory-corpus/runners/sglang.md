# SGLang — Dossier OR-2

**Project:** SGLang (originally "Structured Generation Language"; now presented simply as a fast inference framework for large language, vision-language and diffusion models)
**Licence:** Apache License 2.0
**Principal languages:** Python for the frontend language and for the runtime (SRT — scheduler, managers, model execution); Rust for the cache-aware router / model gateway and, since the v0.5.21 line, for the radix-tree core used by default; C++ / CUDA / HIP / Triton / CUTLASS in the separate `sgl-kernel` package for attention, MoE, GEMM, quantisation and sampling kernels. Satellite runtimes in other stacks exist (a JAX path and a PyTorch-TPU path for Google TPUs) but the main repository is the Python + Rust + kernel stack described here.
**Origin:** LMSYS (the multi-university group behind Chatbot Arena — UC Berkeley, Stanford and collaborators). Paper first posted December 2023, published at NeurIPS 2024; code publicly released January 2024. Hosted by LMSYS as a non-profit open-source organisation; joined the PyTorch ecosystem in March 2025. A commercial company, RadixArk, was spun out in 2025 to sell managed inference on top of the open core.
**Repository:** https://github.com/sgl-project/sglang
**Documentation:** https://docs.sglang.ai (also served as https://docs.sglang.io in late 2026)
**As of:** 2026-11-15 (all sources accessed 2026-11-15; version references below are to the releases and docs current at that date — principally the v0.5.x line, with v0.4, December 2024, as the last clean architectural milestone for the scheduler, and the September 2025 HiCache design and the 2026 Unified Radix Cache work as the current cache frontier)
**Companion in this corpus:** `papers/radixattention-sglang.md` covers the NeurIPS 2024 paper itself — its problem statement, its evaluation, and its 2023-era baselines. This dossier covers the *project as it exists now*: what the runtime became after two years of production hardening, which paper ideas survived contact with DeepSeek-scale serving, and what grew around them.
**Clean-room note:** written in our own words from the sources in §10. No text copied beyond short factual labels (flag names, component names, licence name). No code lifted.

## Essence

SGLang is the serving engine that treats *reuse* as the organising principle of inference. Its founding observation was that real LLM workloads are not isolated prompts but programs — agent loops, multi-turn chats, few-shot evaluations, branching search — that resend the same long prefixes again and again. So instead of discarding a request's key/value (KV) cache when it finishes, SGLang keeps it in a radix tree keyed by token sequence (RadixAttention), orders waiting work so that resident prefixes get used before they are evicted, overlaps all of its own CPU bookkeeping with GPU execution so the scheduler itself costs almost nothing, and — in the feature that gives the project its name — offers a Python-embedded language in which a multi-call program can fork its generation state into parallel branches that share the cached trunk for free. Everything added since — hierarchical cache tiers into host RAM and external storage, a unified tree that also carries sliding-window and state-space-model state, prefill/decode disaggregation, EAGLE speculative decoding, grammar-constrained decoding that skips tokens the grammar has already decided — is an extension of that one stance: never recompute, reload, or re-decide anything you can prove you already know. The design target is unmistakable and opposite to Ollama's: fleets of datacentre GPUs, hundreds of concurrent clients, trillions of tokens a day by the project's own (unaudited) account. For a single-user character-chat runner the code is almost entirely unusable — and the cache design is the single most directly transferable idea in this whole research wave. That tension runs through §8 and §9.

---

## 2. Architecture

### 2.1 The two halves, and which one most users actually meet

SGLang has always been two co-designed pieces:

- **The frontend language.** A domain-specific language embedded in Python. A program is an ordinary Python function decorated as an SGLang function; inside it, primitives append text to a prompt state, request a generation, ask the model to choose among options, or split the state into parallel branches (§7). The frontend can run against SGLang's own runtime or, in principle, against other backends.
- **The runtime (SRT).** The serving engine proper: HTTP APIs (an OpenAI-compatible surface plus SGLang's native generate endpoint), tokenisation, scheduling, KV-cache management, model execution, sampling, structured-output enforcement, streaming.

The important production fact, confirmed by every in-depth walkthrough read for this dossier, is that **most production traffic never touches the frontend language**. Clients call the OpenAI-compatible endpoint with a full prompt or chat history, and they still get the full benefit of the radix cache, because the cache is keyed on token ids inside the runtime, not on frontend constructs. The frontend is best understood as an optional authoring layer that can *hint* structure to the runtime (a fork is coming; these branches share a trunk), not as a gate to the optimisations. Any design that copies SGLang should copy that separation: reuse must work for dumb clients, and get better — not merely work — for smart ones.

Above both halves, at fleet scale, sits a third piece that did not exist in the paper:

- **The router / model gateway.** A Rust program that sits in front of many runtime replicas and routes each request to the replica most likely to already hold its prefix in cache (§3.4). It began as the `sglang-router` package in v0.4 and has grown into a model gateway with load balancing, health checking and prefill/decode-disaggregation awareness. Its existence is an admission about the core design: the radix tree is *per replica*, so the system's headline optimisation can be destroyed one layer above the engine by a cache-blind load balancer (§8).

### 2.2 Runtime process layout

A single server is not one process. The layout described consistently across the current docs, a full-stack deep dive of the repository, and independent walkthroughs is:

- **HTTP / API process** — accepts requests, applies chat templates, owns client-facing state.
- **TokenizerManager** (in the main process) — tokenises prompts, preprocesses multimodal inputs, wraps each request into an internal tokenised message, tracks streaming state, and hands the message to the scheduler over a ZeroMQ queue.
- **Scheduler** (a subprocess; one per data-parallel rank) — the heart of the system. It owns the waiting and running queues, the radix tree, admission and retraction decisions, batch formation, and the dispatch of forward passes to the model workers. Nothing else decides what the GPU does next.
- **Model workers / model executor** — execute the forward pass for the batch the scheduler built, using the chosen attention backend and kernel library (§6). Under tensor parallelism there is one worker per GPU shard, driven in lockstep by the scheduler.
- **DetokenizerManager** (a subprocess) — receives output token ids, detokenises incrementally, trims stop sequences/strings, and returns streamed text to the TokenizerManager for delivery to the client.

The point of the split is the same point vLLM's V1 rewrite made independently: Python string work, HTTP handling and client slowness must never sit on the critical path between two GPU steps. Tokenisation and detokenisation are deliberately exiled from the scheduler process. Internal transport is ZeroMQ message passing — an operational detail with a security consequence the project learned publicly in 2026: those internal ports must not be exposed, because the messages are pickled Python objects (two deserialisation CVEs disclosed and fixed in the 0.5.10/0.5.11 line; recorded here as a design lesson for any multi-process Go runner too — internal queues are a trust boundary).

### 2.3 The model executor

Below the scheduler, the executor is a fairly conventional modern PyTorch serving stack, and SGLang does not pretend otherwise:

- Models are loaded from Hugging Face-format checkpoints (one model per server instance — a server does not hot-swap models the way Ollama does).
- The forward path runs through `torch.compile` and CUDA-graph capture where the configuration allows, for the usual reason: a decode step is many small kernels and launch overhead would otherwise dominate.
- Attention itself is *not* compiled; it is delegated to a pluggable attention backend (§6.2) that consumes the scheduler's page/block metadata and the radix cache's slot assignments.
- Custom kernels live in `sgl-kernel`, a separately versioned package of CUDA/HIP/CUTLASS/Triton kernels for attention support operations, MoE, GEMMs, quantised matmuls, sampling and KV-cache I/O (including the GPU-assisted transfer kernels HiCache uses, §5.3).

### 2.4 The zero-overhead scheduler — design goal and mechanism

"Zero-overhead" is SGLang's name for a specific, measurable claim: **the CPU side of scheduling should add no idle time to the GPU**. The motivation, stated in the v0.4 release post (4 December 2024), is that an unoptimised engine can spend as much as half its time on CPU work — batch scheduling, memory allocation, prefix matching against the cache — while the GPU waits. Radix-tree operations are exactly the kind of work that makes this worse, so SGLang had to solve it to keep its own headline feature affordable.

The mechanism, shipped in v0.4 and on by default ever since (disable flag: `--disable-overlap-schedule`), is **overlap scheduling**, an idea the post credits to the NanoFlow line of work:

1. The scheduler runs **one batch ahead**. While the GPU executes batch *N*, the CPU scheduler is already building batch *N+1* — doing its radix lookups, allocations, grammar-mask preparation and metadata construction concurrently with GPU compute.
2. The dependency problem — batch *N+1*'s composition can depend on which tokens batch *N* samples — is handled with placeholder "future" token values that are resolved when the real sampled tokens land, together with carefully placed CUDA events so the CPU never reads a result before the GPU has produced it, and never blocks the GPU waiting for its own bookkeeping.
3. Later refinements visible in the current codebase include a dedicated overlap path for speculative decoding (Speculative Decoding V2 in the docs) and a two-batch-overlap variant for multi-node deployments, which splits one batch into two micro-batches so communication and computation overlap as well; project material credits that variant with roughly 27–35% prefill and ~25% decode throughput gains in its target multi-node setting (project slide figures, not independently verified).

**Evidence and era.** The v0.4 post verifies the claim with Nsight profiling: five consecutive decode batches with no visible GPU idle gap (with the Triton attention backend; the post honestly notes a minor residual gap with the FlashInfer backend at that time). The measured end-to-end effect was modest compared with the name: **1.1× throughput over SGLang v0.3**, and 1.3× over the contemporary baselines the post compared against, with the gain largest on small models and large tensor-parallel sizes — exactly where per-step GPU work is shortest and CPU overhead is proportionally biggest. Benchmark shape for reproduction in the post: Llama-3.2-3B-Instruct, 500 random prompts, 4,096 input / 2,048 output tokens. Treat "zero" as "hidden under GPU time on the profiled configuration", not as a law of nature: on a small GPU where a decode step takes a millisecond, there is far less GPU time to hide CPU work under — a point that matters for §9.3.

---

## 3. RadixAttention in production form

The companion paper dossier covers the 2023 design. What follows is the mechanism as it exists in the current runtime — same core idea, considerably more machinery around it.

### 3.1 The tree as implemented

- **Structure.** A radix tree is a compressed trie: edges are labelled with *runs* of tokens rather than single tokens, so a path from the root spells out a token sequence and every node corresponds to a prefix some request has already computed. Each node maps its token run to the KV pool slots holding those tokens' keys and values, across all layers. There is one tree per scheduler (hence per data-parallel replica).
- **Match.** On arrival, a request's token ids are walked down the tree from the root. The walk follows the longest path that matches token-for-token; where a request diverges partway along an existing edge, the edge is **split** at the divergence point so the shared part becomes its own node. The result is a matched prefix length and the list of slots for it. Only the unmatched suffix is prefilled.
- **Granularity.** The cache is paged underneath (the KV pool is allocated in pages), but the default page size is **1 token**, so a prefix can match to the exact token rather than being rounded down to a block boundary — the sharpest contrast with hash-of-fixed-blocks prefix caching (vLLM's design, 16-token blocks). Larger page sizes are a deliberate trade: the HiCache and MLA benchmark configurations in §3.5 use page sizes of 64 or 128 because their kernels and transfer paths prefer coarse pages, at the cost of coarser matching and more internal waste. Page size is therefore a per-deployment tuning decision, not a constant of the design.
- **Insert.** When a request finishes (and, for its prompt portion, effectively as soon as its KV exists), its token sequence is inserted into the tree, reusing/splitting existing nodes as needed. Crucially, the cache holds **any finished sequence**, not only prefixes a client declared in advance — reuse is automatic and client-transparent. Generated tokens are part of what gets cached, which is what makes the *next turn* of a conversation a prefix hit on prompt-plus-previous-answer.
- **Reference counts / locking.** A node in use by a running request carries a reference count (lock). Locked nodes cannot be evicted, full stop. Matching a prefix increments the count on every node along the matched path for the duration of the request; finishing releases it. This is the mechanism that makes sharing safe under continuous batching: two requests can read the same trunk slots concurrently, and the trunk cannot be reclaimed out from under either of them.
- **Eviction.** When the pool needs space, eviction takes **unreferenced leaves only**, ordered by the configured eviction policy — least-recently-used by default, with least-frequently-used available (`--radix-eviction-policy lru|lfu`). Freeing a leaf can make its parent a leaf; if the parent is also unreferenced it becomes a candidate in turn, so eviction effectively prunes dead branches inward. An inner node shared by live branches survives as long as anything beneath it does. The whole tree can be flushed explicitly (`POST /flush_cache`), which operators must do after in-place weight updates, because cached KV computed under old weights is simply wrong under new ones.
- **Implementation language drift.** The tree began as Python scheduler code. By the v0.5.21 release notes (October 2026) the prefix cache runs on a **Rust core by default**, and the Unified Radix Cache work (§5.4) describes the split precisely: the Rust TreeCore owns tree topology, per-component lock accounting, intrusive LRU lists and eviction walks, while Python retains physical KV allocation and pool orchestration, applying the operations the Rust core returns. The reported motive is CPU overhead, not features: the L1-only Rust prototype reduced time-to-first-token by 38% (sliding-window model), 10% (full attention) and 5% (hybrid SSM) against the Python tree in a 200-turn conversation benchmark (project-reported; hardware and full setup in §3.5 notes). **[Interpretation]:** this is the overlap scheduler's lesson arriving a second time — once the GPU is saturated, the cache's own bookkeeping becomes the bottleneck, and the fix is to move the bookkeeping to a faster language, not to simplify the cache.

### 3.2 Cache-aware scheduling (inside one replica)

A resident prefix is worthless if the requests that would hit it are scheduled after it has been evicted. SGLang therefore lets the waiting-queue order be influenced by the tree. The control is `--schedule-policy`; the policies documented in current source and walkthroughs are:

- `fcfs` — first come, first served. The current default in the source the October 2026 in-depth walkthrough checked (defaults have changed between releases; the walkthrough explicitly warns readers to check `--help` on their own version rather than trust any article, including itself).
- `lpm` — longest prefix match: waiting requests are sorted by how much of their prompt is already cached, descending. This maximises hit rate and clusters requests sharing a trunk into the same scheduling window, at the cost of fairness — a request with no cached prefix can keep losing the sort (starvation is a documented failure mode; §8).
- `dfs-weight` — depth-first order over the tree, weighted: serve a whole subtree together before moving to another branch, so the shared ancestors stay hot for the entire cluster.
- Others listed in current source: `priority`, `lof` (longest output first, in the tuning docs' usage), `random`.

The paper-era version of this idea ordered purely by matched length and reached, on its own benchmarks, an average of 96% of the theoretically optimal hit rate (see companion dossier). The production version is more conservative — FCFS by default, cache-aware ordering as an opt-in — which is itself a finding: at fleet scale, fairness and tail latency matter enough that the project will not pay for hit rate with queue-jumping unless the operator asks it to. The tuning docs recommend `lpm` specifically "if the workload has many shared prefixes", accepting its extra scheduling overhead as the price.

### 3.3 Hit-rate behaviour on real workloads, as reported

Keep the eras separate; the numbers are not one series.

- **Paper era (2023, flagged).** Hit rates of 50–99% across the paper's own prefix-heavy benchmarks; production Chatbot Arena traffic over one month reported at 52.4% (a vision-language model) and 74.1% (Vicuna-33B), with a 1.7× average first-token latency improvement for the latter. Hardware: A10G/A100 class. Baselines of that era. See the companion dossier for the full context.
- **Independent reproduction (2026, small hardware).** An independent long-form analysis that re-implemented the radix cache and compared it with hashed-block prefix caching on ShareGPT multi-turn conversations measured **92.0% of prompt tokens reused via the radix tree vs 90.9% via 16-token blocks** — i.e. on ordinary multi-turn chat the two structures are close, and the radix tree's edge is granularity and branch handling, not a different order of magnitude. The same piece measured the value of a hit directly: a 2,176-token prompt with a 2,048-token cached prefix produced its first token in 153 ms instead of 2,102 ms uncached on an Apple M4 laptop (25 ms vs 122 ms on an RTX 3090). Those are one author's measurements on consumer hardware, cited here because they are the closest published analogue to our target workload — not as project benchmarks.
- **Fleet era (2025–2026, project and partner reported).** With HiCache tiers engaged (§5.3), partner reports quoted by LMSYS describe multi-turn hit rates climbing from ~40% (GPU-only, capacity-evicted) to ~80% (with external storage retention), and the Unified Radix Cache multi-turn benchmark reports late-round hit rates of ~98% and 96.8% once a large third tier is added (§3.5). The pattern across all eras is consistent and is the real finding: **on multi-turn traffic the hit rate is a capacity story, not a matching story**. Matching is nearly free and nearly perfect; what decides the rate is whether the prefix is still resident when the next turn arrives.

### 3.4 Cache-aware routing (across replicas)

Because each replica's tree is private, SGLang v0.4 added a **cache-aware load balancer**, now the Rust router/gateway. It maintains a lazily updated *approximate* copy of each worker's radix tree — built from routing history, with no worker synchronisation and, in the project's words, almost no overhead — and routes each new request to the worker predicted to have the highest prefix match, balanced against load so affinity does not create a hotspot.

Project benchmark (v0.4 post, December 2024): a synthetic workload of multiple long shared-prefix groups, perfectly balanced, data-parallel size 8, Llama-3.1-8B-Instruct, hardware 8× A100 80 GB for the reproduction commands. Throughput rose from 82,665 to 158,596 tokens/s and hit rate from 20% to 75% versus the v0.3 round-robin behaviour — headline "up to 1.9× throughput, 3.8× hit rate". The post itself cautions that the workload is idealised and results vary with traffic shape. The transferable point is not the multiplier; it is that **round-robin across cache-private replicas collapsed the hit rate to 20% on traffic that was 75%-hittable** — routing is part of the cache design, not an operational afterthought.

### 3.5 The hierarchical and unified benchmarks (for §5.3–§5.4)

Two project benchmark sets are cited repeatedly in §§5–6, collected here with their hardware so the numbers are not quoted bare later:

- **HiCache (LMSYS post, 10 September 2025).** Headline: up to 6× throughput improvement and up to 80% TTFT reduction in the project's own measurements. Partner figures quoted in the same post: DeepSeek-R1-671B under prefill/decode disaggregation with a Mooncake storage tier, on in-house online requests from a general QA scenario — cache hits cost 84% less TTFT than full recomputation (Ant Group); a coding-agent workload on Qwen3-Coder-480B, dialogues past 25K tokens at ~8 turns per session, with a 3FS-backed store — average TTFT down 56%, throughput doubled, hit rate 40% → 80% (Novita AI). Reproduction configs in the post use 8× H20 and 8× H800 clusters, page size 64, context 65,536, hierarchical cache ratio 2.
- **Unified Radix Cache (SGLang blog, 2026, adapted from LMSYS).** Multi-turn benchmark, effective input throughput defined as total full prompt length divided by wall time (so cached tokens count as processed): DeepSeek-V4-Flash (full + sliding-window attention) on 4× H200, tensor-parallel 4, 48 clients, 60 rounds, 4,096 input + 16 output tokens per turn — 9.4K tokens/s GPU-only, 14.3K with host tier added, **145.5K with a 500 GiB Mooncake third tier**, late-round hit rate ~98%, average TTFT under 9 s. A three-component model (full + sliding-window + Mamba) on 8× H200, TP 8, 64 clients, 30 rounds, 1,216 + 64 tokens per turn — 15.5K → 21.1K → 67.1K across the same tier progression, hit rate 96.8%, average TTFT 1.23 s. Read these as *capacity demonstrations*: with 60 rounds of growing conversations, a GPU-only cache evicts almost everything between rounds, so the third tier is not an increment, it is the difference between a cache and no cache. The 15.5× figure in the blog's title is this ratio, on this workload, on this hardware.

---

## 4. Scheduling & batching

### 4.1 Continuous batching

The batch is re-formed every step. A request joins when the scheduler admits it and leaves the moment it finishes, is aborted, or is retracted; there is no static batch that runs to completion. In the scheduler's own terms there are waiting requests (not yet admitted), running requests (prefilling in chunks or decoding), and the per-step decision of which of them the next forward pass serves. Prefill and decode requests can be mixed in one batch (the "mixed chunked prefill" mode) or scheduled in alternating prefill-only and decode-only steps depending on configuration and feature interactions — notably, some speculative modes disable the mixed mode (§6.3). The scheduler's admission accounting is token-based: each step has budgets for prefill tokens and running requests, and admission reserves room for a request's expected growth, scaled by a conservativeness factor (§4.3).

### 4.2 Chunked prefill

A long prompt is not prefilled in one forward pass. It is cut into chunks of at most `--chunked-prefill-size` tokens (typical documented values run from 2,048–8,192 for latency-sensitive serving up to much larger values in throughput recipes for frontier models; 8,192 is the value in the October 2026 walkthrough's example launch), and the chunks are interleaved with decode steps for already-running requests. The unfinished request is carried as a chunked request: it holds its allocated slots and its radix-match state, is not sampled from until its final chunk lands, and resumes at the front of the prefill queue on the next round.

The trade is explicit in the tuning docs: smaller chunks protect inter-token latency for everyone already decoding (a single 100K-token prompt cannot freeze the server), larger chunks maximise prefill throughput and minimise time-to-first-token for the long prompt itself. If out-of-memory errors occur during prefill, the documented first remedy is to reduce the chunk size. For a single-user runner the fleet reasoning inverts — there is nobody else to protect — but the mechanism still matters, for UI responsiveness and cancellation rather than fairness (§9).

### 4.3 Preemption — called retraction

SGLang's word for preemption is **retraction**. When the KV pool fills mid-generation, the scheduler retracts running requests: their decode state is abandoned, their slots are freed (their prefix stays in the radix tree if it was inserted, so re-admission can hit it), and they return to the waiting queue to be prefilled again later. In other words, like vLLM V1, SGLang chose **recompute over swap** as the in-engine pressure response; spilling exists only as the separate HiCache tiering feature (§5.3), not as the preemption mechanism.

Admission is designed to make retraction rare rather than graceful:

- A **new-token-ratio forecast**: the scheduler estimates how many tokens running requests will still generate (starting optimistic, decaying as requests actually finish, jumping back up after a retraction) and refuses new admissions that the forecast says will not fit.
- `--schedule-conservativeness` scales that forecast. Too low: over-admission, frequent retraction, wasted prefill. Too high: under-filled batches and queueing. The tuning docs' operational guidance is unusually candid: an occasional retraction, roughly one per minute, is acceptable; frequent "KV cache pool is full. Retract requests." warnings are a configuration bug — raise conservativeness (their example: 1.3) or lower `--max-running-requests`. A 2026 operator manual's harder line is worth recording: queueing is the honest failure mode, because retraction hides overload as silently wasted work. **[Note]:** at the extreme, current versions abort the last request if the pool is still exhausted after retracting everything else (documented in the v0.5.22-era manual) — retraction is not guaranteed to save the batch.
- `--retraction-policy` (current server arguments) chooses the victim order: `length` (the historical behaviour — retract short-output, long-input requests first, i.e. the ones cheapest to recompute relative to what they free) or `priority` (retract lower-priority requests first).

### 4.4 Deployment shapes (design level)

All of the following compose; a large deployment typically uses several at once.

- **Tensor parallelism (TP).** One model sharded across GPUs, layer by layer. The default way to fit a model larger than one GPU and to buy KV capacity per replica. `--tp-size`.
- **Data parallelism (DP).** Whole replicas side by side, each with its own scheduler and its own radix tree, behind the cache-aware router (§3.4). `--dp-size`. This is the shape that makes routing part of the cache design.
- **Data-parallel attention (DP attention).** A hybrid introduced in v0.4 for DeepSeek-style multi-head latent attention (MLA) models, which have a single KV head: under plain TP every GPU would duplicate the same KV cache. Instead, attention runs data-parallel (each DP worker handles different requests' attention, with its own non-duplicated KV), results are all-gathered into the MoE/MLP layers which run tensor-parallel, then scattered back. Project benchmark: 1.9× decoding throughput vs v0.3 on 8× H100 80 GB with a DeepSeek-Coder-V2 FP8 checkpoint (radix cache disabled in that benchmark's commands — the gain is the parallelism shape, not caching).
- **Expert parallelism (EP).** For mixture-of-experts models, experts are distributed across GPUs rather than replicated, combined with DP attention in the DeepSeek serving recipes; a two-batch-overlap mode hides the resulting all-to-all communication behind compute (§2.4).
- **Pipeline parallelism (PP).** Layers split across GPUs/nodes; supported (the scheduler has a dedicated pipeline mixin with staggered micro-batches), but it is the least-celebrated axis in SGLang's own material — TP inside a node, DP across replicas is the canonical shape.
- **Prefill/decode disaggregation (PD).** Prefill and decode run as separate server pools with separate parallelism shapes, the router sends each request to a prefill instance first, and the computed KV is transferred to a decode instance over Mooncake or NIXL (RDMA/NVLink where available). The rationale is phase interference: prefill is compute-bound, decode is memory-bandwidth-bound, and colocated long prefills spike decode latency. The honest cost accounting from a 2026 production write-up is worth preserving: disaggregation does not remove the KV cost, it converts recomputation-and-interference into transfer, queueing and failure-recovery overhead, and it pays only when long prefills measurably damage decode tail latency in the colocated baseline. Recent versions add zero-downtime role switching (a v0.5.21 headline: instances can flip between prefill and decode roles without restart), which softens the sizing problem of fixed pools. Hybrid-model state (Mamba checkpoints, §5.4) is carried over a dedicated state-transfer channel in this mode.
- **The router as a shape.** Multi-node DP and PD deployments are fronted by the Rust gateway, which is also where session affinity can be enforced. The project's own failure-mode writing is blunt: deploy DP without cache-aware routing and you have paid for a radix cache you will rarely hit.

---

## 5. Memory management

### 5.1 KV pool sizing

SGLang allocates its KV pool **statically at startup**, not on demand. The accounting, from the tuning docs:

> Total GPU memory = model weights + KV cache pool + CUDA-graph buffers + activations, and `--mem-fraction-static` is the fraction of total GPU memory assigned to (weights + KV pool).

Equivalently: KV pool = (`--mem-fraction-static` × total VRAM) − weights. Everything else — activations, CUDA graphs, kernel workspaces — must live in what the fraction leaves behind. The documented rule of thumb is to reserve roughly 5–8 GB for activations and graphs, then push the fraction as high as that allows (typical values 0.85–0.92 in recipes; the historical default is 0.9). At startup the server profiles its memory, computes the pool capacity in tokens (`max_total_num_tokens` in the logs, alongside chunk size, prefill budget and the running-request cap), initialises the tree cache, and reports the resulting numbers — that token capacity is, as with vLLM, the single most informative line in the boot log.

Two operational corollaries the docs state plainly: lowering `--mem-fraction-static` is the remedy for startup/prefill OOM but it *shrinks* the cache and therefore lowers concurrency and hit rates; and a server that looks like it is "using" ~90% of VRAM while idle is behaving correctly — the pool is pre-allocated. `--max-total-tokens` can cap the pool directly when an operator wants a smaller, deliberate cache.

For hybrid models there are **two pools**, sized separately (§5.4): a token-level KV pool for the full-attention layers and a request-level state pool for the recurrent layers, both fixed at startup — the PyTorch-blog engineering account notes that the fixed sizing is deliberate, to eliminate runtime OOM from state allocation.

### 5.2 Fragmentation stance

SGLang's stance is the paged stance, taken further than most: because KV lives in a single pre-allocated pool of pages and every allocation is page-granular, there is no per-request contiguous reservation to fragment, and freed pages return to the pool for any future request regardless of size. The radix tree is an index *over* that pool, not an allocator of variable-sized extents — a node's slots need not be contiguous.

The residual waste is therefore exactly two things:

1. **Page rounding.** A sequence's last page is partially filled. At the default page size of 1 token this waste is zero, which is a genuine (if small) structural advantage over 16-token-block designs; at the page sizes of 64–128 used by the hierarchical/MLA configurations it grows to tens of tokens per sequence per component — accepted there because transfer and kernel efficiency dominate.
2. **Retention waste.** Cached-but-dead prefixes occupy pool pages until eviction needs them. This is not fragmentation in the allocator sense — the pages are reclaimable in LRU order at any time — but it means "pool full" and "pool full of useful data" are different states that only the hit-rate metrics distinguish. SGLang exposes cache hit rate and token-usage metrics (`--enable-metrics`, Prometheus) precisely so operators can tell them apart.

There is no defragmentation or compaction pass, and none is needed by the design. What SGLang adds over a plain paged allocator is that eviction is *content-aware*: the LRU order runs over tree leaves, so reclaim automatically sacrifices the least-recently-used branch tips before touching shared trunks.

### 5.3 HiCache — the tiered extension

HiCache (design post September 2025; extended repeatedly since) answers the capacity limit of §3.3 by extending the same tree across three tiers:

- **L1 — GPU HBM.** The ordinary radix cache.
- **L2 — host (CPU) DRAM.** A pinned-memory pool, private to the instance, sized as a multiple of L1 (`--hicache-ratio`; ratio 2 in the published benchmarks).
- **L3 — external storage.** A pluggable backend behind a deliberately tiny interface (get / exists / set, in our paraphrase): Mooncake, DeepSeek's 3FS KV store, NIXL, and a local-file reference backend ship with the project.

The tree becomes a page table over all three tiers (the "HiRadixTree"): a node records where each of its pages currently lives. A hit in L2 is loaded back to L1; a hit in L3 is first prefetched into L2, then loaded. Only tokens missing from all tiers are recomputed.

Engineering details that carry design lessons:

- **Layout split.** The GPU pool keeps a layer-first layout (what attention kernels want); the host/storage tiers use a page-first layout (what large I/O transfers want). Decoupling the two layouts, plus zero-copy paths and custom GPU-assisted I/O kernels, is credited with up to 3× CPU↔GPU transfer throughput and up to 2× end-to-end tier throughput in typical deployments (project figures).
- **Layer-wise overlap.** On an L2 hit, KV for layer *N+1* is loaded while layer *N* computes — the transfer hides behind the forward pass, the same overlap instinct as the scheduler's.
- **Prefetch policy for L3.** Because storage latency is high and unpredictable, prefetch from L3 is configurable: best-effort (abandon the prefetch if the request becomes schedulable — minimise time-to-first-token), wait-for-completion (maximise reuse), or timeout-bounded middle grounds. A short L3 hit can be worth less than recomputation; one explainer of the design puts a concrete floor on it (hits under ~32 tokens are recomputed rather than fetched, in that implementation's policy).
- **Write policies.** Write-through (copy every new node down immediately), write-through-selective (copy only nodes that have been hit repeatedly — hot-spot backup, less I/O), write-back (copy under pressure, when faster tiers fill). The choice is a bandwidth-vs-retention trade, exposed to the operator rather than hidden.

Benchmarks: §3.5. The one-sentence summary for our purposes: **tiering converts the radix cache from a GPU-memory optimisation into a session store** — conversations can leave the GPU entirely and still resume without re-prefill, which is precisely the property a long-running character chat wants from system RAM and disk (§9.1).

### 5.4 Hybrid and SSM models — verified support

This is verified, current, and one of the fastest-moving parts of the project. Three layers of support exist:

1. **Separate pools (the foundation).** For hybrid linear-attention / Mamba models (the Jamba pattern: most layers recurrent, some layers full attention), SGLang splits memory into a **Mamba state pool** and a **KV pool**. The difference is granularity: KV is allocated per token; recurrent state is allocated **per request** — a fixed-size state slot bound to the request for its whole life (a dedicated hybrid request-to-token pool maintains that binding), because an SSM layer's memory does not grow with sequence length. The KV pool for such a model only covers its attention layers, via a mapping from logical to physical layer indices.
2. **Prefix caching for recurrent state (MambaRadixCache).** This is the hard part, and the reason is fundamental: an SSM state is updated *in place* and summarises its whole prefix, so unlike KV it cannot be sliced — the state at token 500 does not contain a recoverable state-at-token-300. SGLang's answer is **checkpointing**: at selected prefix endpoints the runtime snapshots the recurrent state and attaches the snapshot to the corresponding radix node. A later request matching that prefix copies the snapshot (copy-on-write — the cached checkpoint is never mutated by the reuser, who continues updating a private copy) and resumes from it. Match, insert and evict are therefore component-specific: matching must find the deepest node that has *both* the KV prefix *and* a state checkpoint; eviction keeps **two LRU lists** (KV leaves must go leaf-to-root as usual, but a state checkpoint can be evicted from any node, since it is an annotation on the node rather than the node's substance). A cap on snapshots retained per root-to-leaf path (`--mamba-max-states-per-path` in the hybrid tuning material) bounds the multiplicative cost — every checkpoint is a full recurrent state, far larger per unit than one token of KV. Speculative decoding interacts awkwardly (a draft tree needs one state slot per draft token; the hybrid account describes exactly that workaround) and PD disaggregation needed a dedicated state-transfer channel; both are recorded as solved-but-delicate in the project's own writing.
3. **Unified Radix Cache (2026, the generalisation).** The newer design replaces per-combination cache classes with **one tree whose nodes carry one slot per component**: FULL (full-attention KV for the whole matched prefix), SWA (sliding-window attention KV — reuse needs only a continuous window immediately before the reuse boundary, and out-of-window pages can be evicted independently, leaving an explicitly-marked empty "tombstone" slot), and MAMBA (a checkpoint at the node's endpoint). Reuse is decided by **voting**: the match walks candidate boundaries and computation resumes from the deepest boundary *every* component accepts. Models cited as motivating combinations: DeepSeek-V4 (FULL+SWA), Kimi-K3 (FULL+MAMBA-style recurrent layers), a three-component model using all of them. The same tree also carries the HiCache tiers, auxiliary "sidecar" pools (compressed-KV and indexer state that share a component's page indices), **session-aware eviction** (requests may carry a stable session id; eviction prefers unreferenced entries over entries a live session still references — a direct, named protection for ongoing conversations), and the Rust TreeCore of §3.1. Gated-delta-network linear attention (the Qwen3-Next / Qwen3.5 family) is handled in the same spirit, with its own kernel backend selection (§6.2) and radix modes that use state checkpoints via extra buffers.

**What could not be verified:** the exact release in which Unified Radix Cache became the default for all model classes (the blog describes merged TreeCore work and a still-Python path for session-aware caching, implying a transition in progress at access time), and whether pure (non-hybrid) Mamba models — with no attention layers at all — are a supported serving target in the main runtime, as opposed to hybrid models that contain Mamba layers. This dossier claims hybrid support only.

### 5.5 Constrained decoding's memory angle

Constrained (structured) decoding is covered as a feature in §6.4; its *memory* footprint is small and specific, which is why it belongs here:

- Per request, the grammar machinery holds a compiled automaton/pushdown state and, per decode step, a **vocabulary-sized bitmask** of allowed next tokens. A bitmask is vocab ÷ 8 bytes — tens of kilobytes for a large vocabulary — computed on CPU (in the XGrammar design) and applied to the logits. Against a KV cache measured in hundreds of megabytes per conversation this is noise.
- The interesting interaction runs the other way: **jump-forward decoding saves forward passes, not KV bytes** (§6.4). Tokens the grammar forces are appended without a model call, but before the model samples again those tokens must be prefilled so their KV exists — the XGrammar integration documentation states this explicitly. So constrained decoding reduces *compute steps* and *latency*, leaves KV growth per output token unchanged, and its cache interaction is benign: jumped tokens enter the radix tree like any others.
- Grammar compilation itself is a CPU-and-time cost on first use of a schema, not a GPU-memory cost; the production guidance is to reuse schemas rather than generate a fresh one per request.

---

## 6. Quantization & kernels

### 6.1 Supported quantisation

SGLang separates three choices that Ollama's GGUF world fuses into one file: **weight quantisation method**, **GEMM kernel backend** for that method, and **KV-cache dtype**. They are set independently (`--quantization`, `--fp8-gemm-backend` / `--fp4-gemm-backend`, `--kv-cache-dtype`), and a model may mix them freely (FP8 weights with a BF16 cache, BF16 weights with an FP8 cache).

- **Weight methods.** The v0.5.22-era server accepts roughly thirty named methods. The load-bearing families: FP8 (both pre-quantised checkpoints and online quantisation of BF16 weights at load), INT4 weight-only via AWQ and GPTQ — served through Marlin kernels (`awq_marlin`, `gptq_marlin`; the plain GPTQ CUDA kernel was removed in late 2026 in favour of the Marlin path), ModelOpt FP8 and FP4, microscaling FP4 formats (MXFP4, and online NVFP4) for Blackwell-class hardware, compressed-tensors checkpoints, AMD Quark, GGUF (supported, but peripheral — see §8), and MLX 4/8-bit paths on Apple Silicon. As with vLLM, selection is normally **checkpoint-driven**: the method is read from the checkpoint's own config, and an explicit flag that disagrees is rejected except for known-compatible upgrades.
- **KV-cache dtype.** `auto` (the model's dtype), BF16, FP8 in both e4m3 and e5m2 variants, and FP4 variants on the newest backends. FP8 halves and FP4 quarters the bytes per cached token, multiplying the pool's token capacity by 2 or 4 — for a prefix-cache-centric engine this is a *hit-rate* feature as much as a capacity feature, since a larger effective pool retains more branches. FP8 KV needs per-tensor scales (from a quantisation parameter file; absent one, scales default to 1.0 and the server warns).
- **Draft-model quantisation** for speculative decoding is set independently again (§6.3), including an explicit "unquant" override.

Era note: FP8 is the production default recommendation on Hopper-and-later NVIDIA hardware across the 2025–2026 serving literature (near-lossless, natively supported); INT4 AWQ/GPTQ is the Ampere-era and memory-tight answer; FP4 is Blackwell-only in practice. SGLang's coverage mirrors that landscape rather than inventing its own formats — notably, it has **no equivalent of GGUF's K-quants as a first-class ecosystem**, which is one root of its misfit for the Ollama use case (§8).

### 6.2 Attention backends and kernels

Attention is a pluggable backend chosen per deployment (`--attention-backend`, with separate prefill/decode overrides available, including an experimental hybrid mode that mixes two backends by phase). The current official support matrix (docs, accessed 2026-11-15) is large; the shape of it:

- **Standard (MHA/GQA) backends:** FlashInfer, FlashAttention 3, FlashAttention 4, Triton, TensorRT-LLM MHA kernels, Torch SDPA, FlexAttention, plus platform backends — AITER and Wave on AMD ROCm, an Ascend NPU backend, Intel XPU, and an Intel AMX CPU backend.
- **MLA backends (DeepSeek-style latent attention):** FlashInfer MLA, FlashMLA, CUTLASS MLA, TensorRT-LLM MLA, FlashAttention 3/4, Triton — each with its own fixed native page size (1 for FlashInfer MLA, 64 for FlashMLA, 128 for CUTLASS MLA, 32/64 for the TensorRT-LLM family), which couples the backend choice back into the cache's page-size decision (§3.1).
- **Sparse and linear attention:** a DeepSeek Sparse Attention backend family (auto-activated by architecture, with its own prefill/decode sub-backends), and gated-delta-network linear attention for hybrid models (§5.4), auto-activated, Triton by default with FlashInfer kernels on the newest NVIDIA parts.
- **Auto-selection (CUDA):** if the operator does not choose, SGLang picks by hardware and architecture — FlashAttention 3 on Hopper, TensorRT-LLM MHA on Blackwell (FlashInfer for MLA there), FlashInfer on Ampere/Ada and other parts where available, Triton as the fallback. The docs call auto-selection best-effort; production guides advise pinning the backend explicitly.

FlashInfer deserves its own sentence because it is easy to misclassify: it is not an SGLang component but an external kernel library and generator (attention for paged/ragged KV, plus GEMM, MoE, sampling and communication kernels) that SGLang, vLLM and others all integrate; SGLang defaults to it on a large share of NVIDIA hardware and its block-sparse KV handling is designed for exactly the irregular, prefix-shared batches a radix cache produces. SGLang's own `sgl-kernel` package (§2.3) covers the operations FlashInfer and the attention backends do not.

### 6.3 Speculative decoding

Speculative decoding is a first-class, heavily developed feature — the current docs list more methods than any other section of the engine:

- **EAGLE-2 and EAGLE-3** (the recommended path): a small draft head/model, trained against the target model's internal features, proposes a *tree* of candidate tokens; the target verifies the tree in one forward pass and keeps the longest accepted path, preserving the target's output distribution. Tunables: drafting steps, per-step branching factor (top-k), and draft-token budget, with auto defaults per model family. Variants layered on top: frequency-ranked speculative sampling (truncate the draft's vocabulary to high-frequency tokens to cut its LM-head cost), torch.compile for the draft, and an adaptive mode that adjusts speculation depth as acceptance rates drift.
- **MTP** (multi-token prediction): models trained with native multi-token heads (the DeepSeek lineage and others) reuse those heads as the draft — no separate draft model.
- **Standalone draft-model decoding:** any smaller LLM as a plain token-level draft.
- **NGRAM:** draft-free speculation from an n-gram cache over previous tokens (CUDA-only; notably it *disables* the overlap scheduler and mixed chunked prefill — an interaction the docs state and any adopter should note: speculation is not free of scheduling consequences).
- **Newer/niche:** DFLASH (linear block verification with a dedicated draft checkpoint), UNO (a trained LoRA on the target itself serves as the draft, avoiding a second model), block-verification modes for stochastic sampling.

**Numbers, with context.** The docs' own comparison table, Llama-3.1-8B-Instruct on MT-Bench, **one H100**: 158.34 tokens/s with no speculation, 244.10 with EAGLE-2 (~1.54×), 373.25 with EAGLE-3 (~2.36×). Single-request latency-oriented figures on datacentre hardware — the right way to read them for our purposes is as evidence that speculation is a *latency* tool whose value peaks at low concurrency, which is precisely the single-user regime (§9 mentions it only in passing; the draft-model memory cost is the blocker there, §8).

**Ecosystem note:** draft models are trained by a sibling project, SpecForge, and deployed into SGLang — speculation in this ecosystem is a small supply chain (target checkpoint + matched draft checkpoint + tuning), not a flag you flip on an arbitrary local model. That, more than any kernel question, is what keeps it out of reach for a general local runner today.

### 6.4 Structured outputs and the compressed FSM

The paper's second invention survives, transformed. Constrained decoding in current SGLang:

- A request may carry a JSON schema, a regex, or an EBNF grammar. The constraint is compiled to an automaton (a pushdown automaton in the XGrammar backend, which handles the nesting JSON requires), and at each decode step a CPU-computed bitmask removes every token that would make the output unparseable. The model only ever samples legal continuations.
- **Backends are pluggable** (`--grammar-backend`): XGrammar is the default (and the v0.4 integration was a headline feature, claiming up to 10× faster JSON decoding than other open-source solutions of that moment — a December 2024 project claim, era-flagged), with Outlines and llguidance as alternatives.
- **Jump-forward / compressed FSM.** The paper's compressed finite-state machine generalised into a simple, durable trick: wherever the grammar permits exactly one continuation for a run of tokens — the punctuation and fixed keys of a JSON object are the canonical case — those tokens are *determined*, so the engine appends them in a single step without spending forward passes deciding them one at a time. Secondary analyses estimate that rigid schemas can bypass on the order of 30–50% of generation steps this way (an estimate, not a project benchmark). The model is only invoked at genuine choice points. §5.5 covers the memory side (small) and the caveat (jumped tokens still need their KV prefilled before the next real sample).

For character chat this machinery is mostly irrelevant — free prose has no grammar — except in one place: tool calls, game-state extraction, and "respond as JSON" character modes, where jump-forward is effectively free latency. Noted for completeness; it is not one of the steals in §9.

---

## 7. The frontend idea itself: programs-as-prompts

### 7.1 What the language actually offers

Strip away the serving machinery and the frontend is a claim about *authorship*: an LLM application is a program, so it should be written as one, in a real programming language, with the generation calls as primitives inside ordinary control flow. Concretely (primitive names are factual labels):

- A decorated function receives a **state** object holding the conversation-so-far.
- Appending (`+=` / extend) adds system/user/assistant text to the state.
- `gen` runs a generation and binds the result to a name, retrievable later from the state; it accepts sampling parameters and a grammar constraint.
- `select` asks the model to choose among a fixed list of options, scored in one pass.
- `fork` clones the state into N parallel branches; `join` brings branches back together so the program can read all their results and continue as one conversation.
- Everything else is Python: loops, conditionals on generated text, calls to tools and databases between generations, nested SGLang functions.

The runtime co-design is the point. Because the interpreter knows a fork is coming, it can pin the shared trunk in the cache before the branches diverge; because branches are issued as a batch of requests sharing a prefix, the scheduler and radix tree (§§3–4) make the shared part cost once instead of N times. The paper's own framing calls the runtime side of this *API speculative execution* as well: the interpreter can begin work it can predict the program will need. Without the runtime, the language would be a convenience; without the language, the runtime would have to rediscover program structure from raw requests — which, §2.1 noted, is what it in fact does for API clients, at some cost in foresight.

### 7.2 What a chat application gains: branching as a native operation

Map the primitives onto what character-chat users already do by hand:

- **Swipes / regenerates.** "Generate three alternative replies to this turn and let me pick" *is* `fork(3)` + three `gen`s + a user-driven `select`. In a conventional chat stack each swipe is a fresh request that re-prefills the entire history (or relies on an opaque server-side prefix cache happening to still hold it). In the SGLang model the trunk is computed once, held by reference count while the branches run, and the three branches differ only in their cheap suffixes. The paper-era workloads that showed the largest gains — tree-of-thought, parallel sampling, multi-candidate evaluation — are structurally identical to swiping.
- **Branching stories.** "Continue from this earlier turn instead" is a fork at an older tree node. A radix-tree-backed chat does not need a separate "branch" data model in the application *and* a cache in the engine that happen to agree; they are the same tree, and the engine-side branch costs no re-prefill at all.
- **Parallel judgement.** A main reply plus simultaneous side-generations (a continuity check, a summary for the memory system, a safety/quality score via `select`) share the trunk and run as one batch — the pattern the frontend examples use for multi-aspect evaluation maps directly onto the sidecar generations a rich character app wants per turn.
- **Structured multi-call scenes.** Interleaving generation with tool calls, dice, lorebook lookups and state updates is just Python between `gen` calls, with the conversation state — not a hand-serialised prompt string — as the thing being passed around.

### 7.3 What it costs

- **A programming model leak.** The application author now writes against a stateful, forkable generation runtime, not against "send messages, receive text". Retries, cancellation, persistence and error handling all have to be re-thought in fork/join terms: what does it mean to save a program with three live branches? What is restored on reload? SGLang's answer (the runtime owns it, ephemerally) does not transfer to a chat app that must persist conversations for months.
- **Python-shaped gravity.** The frontend is embedded in Python and assumes its host ecosystem. A Go application cannot adopt the language; it can only adopt the *idea* — a session API whose operations are append / generate / fork / join over a shared cached trunk (§9.1). **[Assessment]:** that idea is the valuable part, and it does not need the DSL.
- **Production reality check.** As §2.1 recorded, most real SGLang traffic bypasses the frontend entirely and uses the OpenAI-compatible API. The language won mindshare and benchmarks; the API won deployments. Any dossier reader should take both halves of that sentence seriously: programs-as-prompts is a genuinely better authoring model for branching generation, *and* the market has so far preferred stateless requests plus a smart cache. A chat application is the unusual case where the stateful model is arguably right, because the application itself is already stateful — the conversation *is* the program.

---

## 8. Strengths / weaknesses

### Strengths

- **The cache is the architecture, and it shows.** Radix-tree prefix reuse with exact-token granularity, reference-counted sharing, LRU leaf eviction, cache-aware scheduling inside the replica and cache-aware routing across replicas, then tiering into host RAM and external storage, then generalisation to sliding-window and recurrent state — no other open engine has thought this hard, for this long, about not recomputing prefixes. The 2026 unified-tree work (one structure for full attention, sliding window and Mamba state, with session-aware eviction) is the current frontier of the idea anywhere.
- **The scheduler respects the GPU.** Overlap scheduling plus, later, moving the cache bookkeeping itself into Rust, is a coherent two-act answer to CPU overhead. The project profiles its claims (Nsight traces in the v0.4 post) and publishes its caveats alongside them.
- **DeepSeek-class serving is a home game.** DP attention, expert parallelism, MLA-specific backends, PD disaggregation with two transfer engines, EAGLE/MTP speculation — SGLang became the reference open stack for the large-MoE era, and its feature velocity (roughly fortnightly releases; a Rust prefix-cache core, a Decisions/Score classification API and zero-downtime PD role switching all landed in a single October 2026 release) reflects a large, well-funded contributor base. The project's own adoption claim — production use across hundreds of thousands of GPUs, trillions of tokens daily — is unaudited but consistent with its visible footprint at major labs and clouds.
- **Structured output is genuinely best-in-class in design:** grammar backends are pluggable, masking is overlapped with GPU work, and jump-forward removes determined tokens from the decode loop entirely rather than merely constraining them.
- **Honest operational surface.** Hit rate, token usage, retraction counts and queue depth are first-class metrics; the tuning docs name failure modes (starvation under `lpm`, prefix poisoning by volatile prompt headers, cache thrash under mixed long-document traffic, stale KV after weight updates) that many projects leave for users to discover.

### Weaknesses

- **Complexity is the price of everything above.** A current server exposes over five hundred command-line options (535 counted by a v0.5.22-era operator manual). Page size couples to attention backend couples to MLA support couples to speculative mode; NGRAM speculation disables the overlap scheduler; UNO speculation forbids tensor parallelism above 1; PD disaggregation has its own matrix of unsupported combinations. The system rewards a dedicated platform team and punishes casual operation — the opposite trade from Ollama's.
- **Python control plane, permanently.** The scheduler and managers are Python (with Rust islands growing: router, tree core). That is a deployment weight (PyTorch + CUDA + a matched kernel package; the project's own reliable install path is its container image), a startup cost, and a hard floor on operability for small machines — independent of how good the algorithms are.
- **The cache's value is workload-conditional, and the condition is discipline.** Exact-prefix matching means a timestamp, random id or reordered paragraph at the top of the prompt silently zeroes the hit rate ("prefix poisoning" in the project's own failure-mode lists). Nothing in the engine detects or repairs this; prompt assembly discipline is an application responsibility the engine assumes.
- **Fairness is an afterthought the operator must supply.** Cache-aware policies trade tail latency for hit rate; the default reverted to FCFS. There is no built-in notion of per-user fairness, deadlines, or session priority beyond the blunt instruments of schedule policy and retraction policy — acceptable in its target market, but a gap a copier must fill deliberately.
- **Non-determinism under sharing.** The in-depth walkthrough lists it plainly: the same prompt at temperature 0 can produce different text depending on batch composition and cache state. Shared-fleet serving accepts this; a personal runner whose user compares swipes may not want batch-dependent outputs.
- **GGUF and the local ecosystem are peripheral.** GGUF loads, but SGLang's quantisation centre of gravity is the GPU serving formats (FP8/AWQ/GPTQ/ModelOpt). The model-zoo gravity is Hugging Face datacentre checkpoints, not the local-model ecosystem Ollama users actually have on disk.

### Fit / misfit for a 6 GB single-user Go runner

**As software: a total misfit, and not a close call.** SGLang assumes a datacentre GPU it can claim ~90% of at startup, a PyTorch/CUDA (or ROCm/TPU) stack, multiple cooperating processes with a message bus between them, and an operator. On a 6 GB card its static allocation arithmetic (§5.1) leaves a KV pool measured in the low thousands of tokens for any model worth chatting with, after weights, activations and CUDA graphs take their share — the engine would boot, and then retract its way through every long conversation. Its CPU/Apple-Silicon paths exist in late 2026 releases but are ports, not the design centre. Nothing in the codebase is Go, and the parts that are fast are fast because of CUDA kernels a Go runner would have to replace wholesale.

**As a design catalogue: the best fit in this research wave.** A long single-user character chat is, almost uniquely among LLM workloads, the exact shape SGLang was built for, miniaturised: one enormous shared prefix (persona + lore + history), tiny suffixes per turn, constant branching (swipes, regenerates, alternate continuations), long idle gaps between turns during which a fleet engine would evict and a personal engine should *retain*, and a user who feels time-to-first-token on every single turn because there is no aggregate throughput to hide behind. Every headline SGLang mechanism has a one-user analogue that survives the scaling-down; §9 names the three worth stealing and prices them.

---

## 9. IDEAS TO STEAL

Each idea is stated as a translation into an improved Ollama for long single-user character chats on ~6 GB of GPU memory, with the expected gain and the honest cost. All three assume the runner keeps a paged KV pool (the vLLM lesson) — SGLang's contributions are what to build *on top of* the pool.

### 9.1 Radix-tree prefix cache as persona-trunk + swipe-branches

**The steal.** Replace "the KV cache belongs to the current request and is discarded/rebuilt per turn" with a persistent, token-keyed radix tree over the KV pool, owned by the session layer:

- The **trunk** is the stable head of every chat with a character: system prompt, character card, persona, lore/world-info that is constant for the session, formatted once, tokenised once, and inserted into the tree at session start. It is shared — by reference count, not by copying — across every chat with that character and across every branch.
- The **conversation branch** grows from the trunk one turn at a time. Each completed turn (user message + assistant reply) is inserted, so the next turn's prefill is only the new user message. This is the ordinary multi-turn win, and on long chats it is the difference between re-prefilling tens of thousands of tokens per turn and pre-filling dozens.
- **Swipes and regenerates are forks, not restarts.** Generating an alternative reply forks at the node for "history up to this user turn"; the fork's KV shares every ancestor slot. Keeping three swipes alive costs three suffixes, not three histories. Deleting a swipe frees its unique suffix leaves only. Branching the story at an old turn is the same operation at an older node. The application's conversation-tree data model and the engine's cache tree become one structure with two views.
- **Protect the active session the way production learned to.** Pin (reference-count) the trunk and the current branch tip for the live session; let LRU eviction prune only unreferenced leaves — abandoned swipes first, then old branches of other characters, then other characters' trunks. SGLang's 2026 session-aware eviction (§5.4) is this exact policy arriving in the fleet world; a single-user runner can implement the simple version from day one: *the session the user is looking at is never evicted*.
- **Tier it, cheaply (the HiCache lesson, miniaturised).** When GPU pages run out, demote cold subtrees to host RAM instead of discarding them (a 6 GB machine typically has an order of magnitude more RAM); when RAM runs out, demote to disk. Restoration must beat recomputation — on consumer hardware, PCIe/NVMe bandwidth versus a small model's prefill speed makes host-RAM restore a clear win for long prefixes and disk restore a win for very long ones; measure both, and adopt the fleet trick of a minimum hit length below which recompute is cheaper. This tiering is what turns "the user came back to a chat after two days" from a full re-prefill into a restore.
- **Prompt-assembly discipline is part of the feature.** The tree only pays if the trunk is byte-stable: timestamps, random seeds, rotating tips and reordered history must be placed *after* the stable prefix or kept out of the cached region entirely. Ship a "cache health" readout (matched tokens / prompt tokens per turn) so a broken template is visible as a collapsing hit rate instead of a mysterious slowdown.

**Expected gain.** Time-to-first-token on later turns of a long chat falls by roughly the fraction of the prompt that is prefix — in the independent consumer-hardware measurement of §3.3, a 94%-cached prompt cut TTFT by ~13× on a laptop-class chip and ~5× on an RTX 3090; the fleet figures (§3.5) show the same shape at larger scale. Regenerate/swipe becomes a near-free operation instead of the most expensive one in the UI. Memory *saving* is equally real: N branches share one trunk instead of N copies, which on 6 GB is the difference between keeping a conversation's branches resident and not keeping them at all.

**Cost / risk.** This is the largest single piece of engineering in this dossier: a tree index with node splitting, reference counts, LRU leaf eviction and (for the tiering) serialisation of KV pages, all correctly invalidated when the model, quantisation, context parameters or template change (stale KV is *wrong* KV — the fleet world's flush-on-weight-update rule applies verbatim). Bugs here corrupt output subtly rather than crashing. Hybrid/SSM models multiply the cost: a branch point needs a copyable recurrent-state checkpoint per node (§5.4), each far larger than a token of KV, so checkpoint placement must be sparse and deliberate. Mitigation: ship the tree for pure-attention models first, with checkpoints as a later, capped addition.

### 9.2 Cache-aware request ordering — even when the queue is tiny

**The steal.** SGLang orders waiting requests by resident-prefix length (`lpm`, `dfs-weight`) so the cache is spent on requests that will actually hit it. A single-user runner's queue is usually one deep — but not always, and the exceptions are exactly the expensive moments:

- **Turn + sidecars.** A modern character app fires several generations per user turn: the reply itself, plus a summary update, a memory/lore extraction, maybe a second candidate reply. Order them so the one sharing the longest resident prefix (the reply, off the full history) runs first and *extends* the tree, and the sidecars — which typically share the trunk plus part of the history — run against the warmed tree rather than racing it cold.
- **Swipe sets.** Generate all swipes of one turn consecutively (depth-first over that turn's subtree) before serving a queued generation from a different chat or character; interleaving two characters' turns thrashes a 6 GB pool that can hold roughly one long conversation comfortably.
- **Session switching.** When the user switches chats, prefer completing (or checkpointing to the host tier, §9.1) the outgoing session's in-flight work over starting the incoming session's prefill immediately; the incoming prefill will hit the trunk the outgoing work just inserted, if any is shared (same character), and if none is shared the delay is one decode-step long, not a conversation long.
- **The general rule, stated once:** whenever more than one generation is pending, sort by *matched prefix length descending, arrival order as tie-break* — the fleet policy with its fairness failure mode (§8) defused by the tie-break and by the queue being short and single-owner.

**Expected gain.** Modest in steady state (a lone user rarely queues), large at the burst moments that dominate perceived quality: multi-candidate turns, app-generated sidecar calls, and rapid chat-switching. It costs no memory and no model quality; it purely avoids evicting a prefix milliseconds before its next use — the failure the fleet router exists to prevent at scale (§3.4), prevented here by ordering instead of routing.

**Cost / risk.** Small: a matched-length computation per pending request (a tree walk the engine already performs at admission) and a sort. The risks are the fleet ones in miniature — starvation if a stream of high-hit sidecars keeps jumping a low-hit user request (hence the arrival tie-break and a cap on how long any user-visible request may be overtaken), and added scheduler complexity interacting with cancellation (a cancelled high-hit request must release its pins promptly or the ordering poisons the pool). Both are manageable at this scale; neither exists if ordering stays naive FCFS, which remains the correct fallback default — make cache-aware ordering engage only when the queue depth exceeds one.

### 9.3 Overlap scheduling's lesson for a Go event loop

**The steal.** Not the mechanism — a Go runner has no Python GIL problem to hide and no datacentre GPU whose idle gaps cost fleet money — but the *accounting discipline* behind it: **enumerate every piece of CPU work that sits between two GPU steps, and get all of it off that path.**

Concretely, for a Go runner's decode loop, the between-steps work is: token sampling bookkeeping, stop-condition and stop-string checks, detokenisation and streaming to the UI, grammar-mask preparation if constrained decoding is active, KV-pool bookkeeping for the next step, and — in a chat app — lorebook/memory lookups for the *next* turn. SGLang's design says each of these should either (a) run concurrently with the current GPU step (Go goroutines and channels are a *better* tool for this than SGLang's Python-plus-future-tokens machinery — the previous step's post-processing and the next step's preparation pipeline naturally behind the in-flight forward pass), (b) be precomputed before the loop starts (templates rendered, masks compiled, prompts tokenised while the user is still typing — the idle human is the cheapest overlap window a single-user system has), or (c) be moved to a cheaper implementation if it cannot be hidden (the fleet world's eventual answer for its tree bookkeeping was Rust; the Go analogue is that the radix-tree operations of §9.1 must be allocation-light and lock-brief, because at batch size 1 with a small model, a decode step can take only a few milliseconds and there is little GPU time to hide CPU work under — §2.4's caveat inverted: the smaller the model, the more the CPU *is* the bottleneck).

Two specific transfers:

- **Prepare-ahead as an explicit pipeline stage.** Structure the runner as SGLang does: while step *N* executes, step *N+1*'s batch metadata, slot assignments and sampling state are already built and waiting. In Go this is a modest, testable refactor of the generation loop, not a research project.
- **Profile the gap, not the average.** SGLang verified "zero overhead" with a GPU trace showing no idle gaps between decode batches, not with end-to-end tokens/second. A Go runner should adopt the same acceptance test at its own scale: timestamp the gaps between forward passes in a long generation; if gaps attributable to bookkeeping exceed a small fraction of step time, the loop — not the kernel — is the next optimisation target. This measurement discipline also catches the single-user-specific stall the fleet never sees: UI rendering and streaming flushes blocking the generation goroutine.

**Expected gain.** At batch size 1 on consumer GPUs with small-to-mid models, inter-token latency is a sum of GPU step time plus every CPU cost in the loop; shaving the CPU term is worth proportionally more the smaller the model — the same reason SGLang's overlap gain was largest on its smallest benchmark model (§2.4). The precompute-while-typing variant additionally hides tokenisation and template work inside human time, where it is entirely free.

**Cost / risk.** Pipelining adds the classic hazards: a cancellation or stop condition discovered in post-processing must reliably abort a prepared-but-not-yet-run step; speculative preparation must never mutate shared cache state before the step it belongs to is confirmed (SGLang's future-token placeholder machinery exists precisely because this is subtle). Goroutine-per-stage designs can also *add* latency through channel hand-offs if applied dogmatically to a loop whose steps are a millisecond long. The discipline to copy is "measure the gap, then hide what the measurement indicts" — not "overlap everything".

---

## 10. Sources

All accessed 2026-11-15. Project sources are listed first; independent and secondary sources are marked, and every number in the dossier that rests on them is flagged in place with its hardware and era.

**Project / primary**

- SGLang GitHub repository and README — project description, licence (Apache-2.0), supported hardware, ecosystem projects (Diffusion, Omni, SpecForge, router/gateway), release line through v0.5.21/v0.5.22. https://github.com/sgl-project/sglang
- SGLang documentation — server arguments (eviction policy, retraction policy, memory and scheduling flags), hyperparameter tuning (mem-fraction-static accounting, retraction guidance, schedule policies), attention backend support matrix and auto-selection, speculative decoding (methods, parameters, EAGLE benchmark table), PD disaggregation. https://docs.sglang.ai / https://docs.sglang.io
- LMSYS blog, "SGLang v0.4: Zero-Overhead Batch Scheduler, Cache-Aware Load Balancer, Faster Structured Outputs", 2024-12-04 — overlap scheduling design and Nsight verification, cache-aware router benchmark (8× A100 80 GB), DP attention benchmark (8× H100 80 GB), XGrammar integration. https://www.lmsys.org/blog/2024-12-04-sglang-v0-4
- LMSYS blog, "SGLang HiCache: Fast Hierarchical KV Caching with Your Favorite Storage Backends", 2025-09-10 — three-tier design, layouts, prefetch and write policies, storage backends, partner results (Ant Group, Novita AI) and reproduction configs. https://www.lmsys.org/blog/2025-09-10-sglang-hicache
- SGLang blog, "HiCache in SGLang: hybrid-model caching" and "Unified Radix Cache in SGLang: one tree for hybrid model prefix caching", 2026 — tier model, unified FULL/SWA/MAMBA tree, safe reuse boundary, session-aware eviction, Rust TreeCore, multi-turn benchmarks (4×/8× H200). https://www.sglang.io/blog/hicache and https://www.sglang.io/blog/unified-radix-cache
- PyTorch blog, "Hybrid Models Meet SGLang: More than Full Attention", 2025 — Mamba/KV pool split, hybrid request-to-token pool, MambaRadixCache match/insert/evict, speculative and disaggregation interactions. https://pytorch.org/blog/hybrid-models-meet-sglang-more-than-full-attention/
- XGrammar documentation, engine-integration page — jump-forward mechanics, the requirement to prefill jumped tokens before resuming sampling, bitmask flow. https://xgrammar.mlc.ai/docs/latest/using_xgrammar/engine_integration.html
- Zheng et al., "SGLang: Efficient Execution of Structured Language Model Programs", NeurIPS 2024 (arXiv:2312.07104) — used here only for the frontend primitives and compressed-FSM origin; the paper's results are covered in the companion dossier. https://arxiv.org/abs/2312.07104

**Independent / secondary (marked as such in the text)**

- Belgavi, "SGLang, in depth: RadixAttention, cache-aware scheduling, structured decoding and running it in production", 2026-10-04 — process layout, tree mechanics with reference counts and edge splitting, schedule-policy defaults and failure modes, worked KV-size example. https://www.aicassindra.com/blogs/gpu/gpu_sglang.html
- Residual Stream, "SGLang and RadixAttention: Sharing the KV Cache Across Requests", 2026 — independent radix-vs-block-hash comparison on ShareGPT (92.0% vs 90.9%) and cached-prefix TTFT measurements on an Apple M4 and an RTX 3090. https://residual-stream.lvtan71.workers.dev/posts/sglang-radixattention-explained/
- "SGLang 101" operator manual, edition 2026.10 (checked against v0.5.22) — option count, KV-pool log lines, retraction behaviour and tuning judgement, quantisation method inventory and KV dtype list. https://aiengineeringfromscratch.com/manual-sglang-101
- Full-stack repository deep dive, 2026 — three-process runtime (TokenizerManager / Scheduler / DetokenizerManager over ZeroMQ), sgl-kernel and Rust gateway layout. https://blog.frankzhwei.me/posts/sglang_deep_dive/
- Production-practices and comparison write-ups (Restack production guide, v0.5.18-scoped; Metarix engine comparison, 2026-11-14) — PD disaggregation cost framing; the note that fleet-scale adoption figures are the project's own claims. https://adcs.restack.tech/inference/sglang-production-practices/ and https://metarix.io/vllm-vs-sglang-vs-tensorrt-llm

**Numbers discipline.** Paper-era results (2023, A10G/A100, vLLM v0.2.5-era baselines) are flagged wherever they appear and are not used as current rankings. Project-reported fleet numbers carry their hardware, model, workload shape and date in place. The only consumer-hardware measurements cited (M4, RTX 3090) are one independent author's, and are presented as an analogue for our target workload, not as benchmarks of record. Anything that could not be verified from the sources above is marked as assessment or left as an explicit open question in §5.4.
