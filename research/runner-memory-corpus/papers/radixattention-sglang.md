# RadixAttention / SGLang — SGLang: Efficient Execution of Structured Language Model Programs

## 1. Full citation

- **Title:** SGLang: Efficient Execution of Structured Language Model Programs
- **Authors:** Lianmin Zheng, Liangsheng Yin, Zhiqiang Xie, Chuyue Sun, Jeff Huang, Cody Hao Yu, Shiyi Cao, Christos Kozyrakis, Ion Stoica, Joseph E. Gonzalez, Clark Barrett, Ying Sheng
- **Venue / year:** Advances in Neural Information Processing Systems 37 (NeurIPS 2024). First posted as arXiv preprint 12 December 2023; revised 6 June 2024.
- **arXiv:** arXiv:2312.07104 [cs.AI] — https://arxiv.org/abs/2312.07104
- **Code (as reported in the paper):** https://github.com/sgl-project/sglang

## 2. The problem it attacks

Real LLM use is rarely one prompt → one completion. Agent loops, few-shot evaluation, tree search, multi-turn chat, and RAG pipelines are *programs*: many generation calls that share long common prefixes (system prompts, few-shot examples, chat history, retrieved context). Conventional engines discard a request's KV cache when the request ends, so every call in the program re-prefills the shared prefix from scratch — redundant compute and redundant memory traffic that grows with exactly the structure these workloads have most of.

## 3. Core idea in our own words

Keep finished requests' KV caches and index them in a **radix tree** keyed by token sequence. Each tree node holds the KV tensors for a contiguous run of tokens; the path from the root to any node is a prefix that some earlier call already computed. A new call walks the tree to find its longest matching prefix, reuses those KV entries, and only prefills the suffix that is genuinely new. After the call finishes, its own tokens are inserted into the tree for the next caller.

The tree is managed as a cache, not an archive: nodes carry reference counts (a node in use by a running batch cannot be evicted) and eviction is least-recently-used over unreferenced leaves. On top of this sits **cache-aware scheduling**: waiting requests are ordered by how much prefix they would hit, so the scheduler preferentially runs requests that reuse what is already resident, approaching the optimal hit rate instead of thrashing the cache with first-come-first-served order. The paper calls the whole mechanism **RadixAttention**. (The same paper also introduces a compressed finite-state machine for faster grammar-constrained decoding and an API speculative-execution trick; those are outside this dossier's KV-cache scope.)

## 4. Key design details a runner engineer needs

- **Data structure:** radix (compressed trie) tree over token sequences; edges labelled with token spans; nodes own paged KV blocks. Operations needed: longest-prefix match, insert (with node splitting on partial overlap), reference-count inc/dec, LRU eviction of unreferenced leaves. Compatible with paged attention and continuous batching underneath.
- **Cache-aware scheduling:** match every waiting request against the tree, sort by matched prefix length, admit greedily while memory allows, accounting for the fact that admitting a request can *increase* available space by sharing nodes (see the paper's Algorithm 1).
- **Frontend hints:** the SGLang language (primitives such as `gen`, `select`, `fork`, `join`) can tell the runtime about upcoming forks, so branches share the parent's tree path instead of rediscovering it. The runtime works without the frontend (plain API requests still hit the tree), but the ablation shows hints + intra-program parallelism are needed for the best numbers.
- **Multimodal note:** image inputs are hashed and the hash used as tree key material, so repeated questions about the same image reuse the image tokens' KV.
- **Overhead:** on a no-reuse workload (ShareGPT), tree management took 0.2 s of a 74.3 s run for 100 requests — under 0.3%. The authors argue it is safe to leave always on.
- **Where it hooks in:** the KV-cache manager + scheduler of the serving runtime. It generalises vLLM-style prefix sharing from "identical system prefix" to arbitrary tree-structured sharing (few-shot + question, chat history + branch, search tree).

## 5. Reported results — as reported, with context

All figures are the paper's own measurements.

- **Headline:** up to **6.4× higher throughput** and up to **3.7× lower latency** vs state-of-the-art systems across agent control, logical reasoning, few-shot benchmarks, JSON decoding, RAG pipelines, and multi-turn chat.
- **Setup:** models Llama-2 7B–70B, Mixtral-8×7B, LLaVA-v1.5-7B (image), LLaVA-NeXT-34B (video), float16; mostly **AWS EC2 G5 instances with NVIDIA A10G (24 GB)** GPUs (7B on one GPU, larger models via tensor parallelism), some runs on **A100 (80 GB)**. Baselines: Guidance (llama.cpp backend), LMQL (HF Transformers backend), and **vLLM v0.2.5**.
- **Cache behaviour:** hit rates of **50%–99%** across the evaluated benchmarks; cache-aware scheduling reached on average **96% of the optimal hit rate**. Gains concentrate where sharing exists: few-shot MMLU / HellaSwag (shared examples), agent traces (shared template + history), multi-turn chat with *short* outputs (prefix time dominates). For multi-turn chat with long outputs the paper reports **almost no speedup** — decoding dominates and sessions share little.
- **Multimodal:** up to ~**6× throughput** vs the model authors' HF implementations (LLaVA-v1.5-7B: 1.15 vs 0.18 images/s; LLaVA-NeXT-34B: 0.10 vs 0.02 frames/s).
- **Production deployment (Chatbot Arena, one month, as reported):** RadixAttention hit rate **52.4%** for LLaVA-NeXT-34B and **74.1%** for Vicuna-33B, cutting first-token latency by an average of **1.7×** for Vicuna-33B.
- **Compressed FSM (side result):** 1.6× throughput on the JSON-decoding benchmark from multi-token constrained decoding.

## 6. Limitations / what it does not solve

- Reuse is still exact-prefix only. Reordered chunks, edited-in-the-middle prompts, and non-prefix RAG assembly get no hit (CacheBlend's territory).
- No benefit when there is no sharing — unique long generations see only the (small) tree overhead.
- Cache-aware scheduling can starve low-hit requests; the paper names starvation/fairness as future work.
- The cache lives in GPU memory in the evaluated design; tiering to DRAM / disk is listed as a future direction, not a result.
- Headline numbers are against 2023-era baselines (notably vLLM v0.2.5, which later gained its own automatic prefix caching); treat 6.4× as a period measurement, not a current ranking.

## 7. Applicability

### (a) Ollama on a 6 GB consumer GPU running long character chats

- This is arguably the best-fitting paper in the wave for character chat. A long-running persona conversation *is* a tree: a fixed trunk (character card, system prompt, lore) plus one growing branch (the chat), plus short side branches every time the user regenerates, swipes an alternative reply, or branches the story. A radix-tree KV store makes regenerate / branch nearly free on the prefix side — the model only computes the new suffix.
- Multi-character scenes and "same character, new chat" restarts hit the shared trunk. On a 6 GB card, keeping the trunk resident in the tree (LRU-protected while a session is active) is worth more than any kernel tweak: it removes the multi-second re-prefill at every turn boundary after a context reassembly.
- Practical shape for Ollama-scale work: token-keyed radix tree over paged blocks, reference counts for the active session, LRU eviction only of unreferenced leaves, and eviction pressure reported to the user as "how much conversation history is still cached" rather than a silent context drop.
- Watch the failure mode the paper is honest about: if the app rebuilds prompts with the history in a different order, or injects a changing timestamp / random seed early in the prompt, the prefix match breaks at that token and everything after it misses. Prompt assembly discipline (stable content first, volatile content last) is a prerequisite, not an optimisation.

### (b) Project Aesir (Mojo runner — sessions, prefix memory, hybrid SSM models)

- Aesir's "prefix memory" should be a radix tree, not a hash map of whole prefixes: character sessions share partial prefixes (same character, different scenario; same scenario, different character) and only a tree captures partial overlap with node splitting.
- Adopt cache-aware admission for Aesir's multi-session scheduling: when several sessions compete for a small accelerator, run the session whose prefix is resident first; the paper's 96%-of-optimal scheduling result says ordering policy matters almost as much as cache size.
- Fork hints map directly onto Aesir's planned branch / what-if generation: the session API should tell the runtime "a fork is coming" so the parent path is pinned before the fork, exactly as SGLang's frontend does.
- Hybrid SSM caveat: an SSM layer's state at a branch point is a snapshot, not a token-indexed cache. The radix node for hybrid models must store, alongside KV blocks for attention layers, a copyable SSM state checkpoint at node boundaries — branching then means copy-on-write on both. Budget for that state copy; it is the hybrid analogue of KV block sharing and it is not free.

## 8. Access

- Date accessed: **2026-11-15**
- arXiv abstract: https://arxiv.org/abs/2312.07104
- arXiv HTML (read for RadixAttention design + evaluation detail): https://arxiv.org/html/2312.07104v2
