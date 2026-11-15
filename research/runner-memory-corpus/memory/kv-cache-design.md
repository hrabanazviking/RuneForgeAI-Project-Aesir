# KV-Cache Design — The Design Space of the Cache Itself

**Dossier OR-6 (Memory), Topic A1 — Ollama Research Forge**
**Date: 2026-11-15**
**Status: Synthesis dossier. This file does not introduce a new paper or a new runner; it synthesises the corpus's own banked dossiers (PagedAttention, RadixAttention/SGLang, Prompt Cache, CacheBlend, StreamingLLM, H2O; the Ollama, llama.cpp/ggml, vLLM and SGLang runner dossiers; the MimirAlloc and memory-wall/roofline memory dossiers) into one account of how a KV cache can be designed, and what each choice costs. Internal references are given as corpus paths. Numbers we computed ourselves show their arithmetic. Numbers reported from elsewhere carry their source and hardware. Speculation is marked [SPECULATION].**

---

## 1. What the KV cache is, from first principles

### 1.1 Why it exists: autoregressive recompute avoidance

A decoder-only Transformer generates text one token at a time. To choose token *t+1*, every attention layer lets the new token's query vector attend to the key and value vectors of *all* previous tokens, *1…t*. Those key and value vectors are deterministic functions of the earlier tokens and the model weights: token *i*'s key at layer *l* does not change when token *i+1* arrives. Recomputing them at every step would turn generation into re-running the whole prefix forward pass for every new token — cost quadratic in sequence length per token, cubic over a full generation.

The KV cache is the memoisation of that observation. During **prefill** (processing the prompt), the engine computes each token's key and value at every layer once and stores them. During **decode**, each step computes keys/values for the *one* new token, appends them to the store, and reads the stored history to form attention. Per-step compute for the attention history drops from O(*t*) forward passes to O(1) new-token work plus an O(*t*) *read*. That read is the point the roofline dossier (`memory/memory-wall-and-roofline.md`) makes precise: decode is a bandwidth problem, and the cache converts an impossible compute bill into a merely large memory bill. Every design question in this dossier is a question about how to pay that memory bill well.

Three consequences follow immediately and shape everything below:

1. **The cache is exact, not a summary.** Unlike a recurrent state (§6), a full KV cache loses nothing: attention over the cache is mathematically the same attention the model would compute from scratch. Every lossy technique in §4–§5 (eviction, quantisation) is a deliberate departure from this exactness, and must be graded as one.
2. **The cache is append-mostly and read-whole.** In the common case entries are written once, in order, never modified, and read in full at every subsequent step. Almost every layout and allocator decision in §2 exploits this access pattern — and almost every complication (branching, editing, sharing) is a place where the pattern breaks.
3. **The cache is per-sequence state, not model state.** Weights are shared by every user of the model; the cache belongs to one conversation. That is why it, and not the weights, is where sessions, privacy, persistence and preemption live (§3–§4).

### 1.2 The size arithmetic — exact, and worth memorising

For a standard attention layer, one token contributes one key vector and one value vector *per KV head*. Hence, for a dense Transformer:

```
bytes per token  =  2  ×  L  ×  H_kv  ×  D  ×  b
                    │     │      │        │     │
                    K+V   │      │        │     bytes per stored element
                          │      │        head dimension
                          │      KV heads per layer (NOT query heads)
                          attention layers
```

Total cache for a sequence = bytes-per-token × tokens in the sequence × concurrent sequences. Two refinements matter for real models and are developed later: sliding-window layers only need `min(tokens, window)` entries (§2.4, §6), and hybrid models only pay this on their attention layers (§6). For a dense model the formula above is the whole story, and it is unforgiving because every factor is architectural — none of them is a runtime tuning knob except `b` (§5).

**Worked examples (our arithmetic from the published model configurations; f16/bf16, `b = 2`):**

| Model | L | H_kv | D | Bytes/token = 2·L·H_kv·D·2 | 4K tokens | 32K tokens | 128K tokens |
|---|---|---|---|---|---|---|---|
| Llama-2-7B (MHA) | 32 | 32 | 128 | 2·32·32·128·2 = **524,288 B = 512 KiB** | 2 GiB | 16 GiB | 64 GiB |
| Llama-3.1-8B (GQA) | 32 | 8 | 128 | 2·32·8·128·2 = **131,072 B = 128 KiB** | 0.5 GiB | 4 GiB | 16 GiB |
| Llama-3.1-70B (GQA) | 80 | 8 | 128 | 2·80·8·128·2 = **327,680 B = 320 KiB** | 1.25 GiB | 10 GiB | 40 GiB |

Cross-checks against the corpus: the 8B row reproduces the llama.cpp dossier's independently derived 128 KiB/token and its "32,768 tokens = 4 GiB" conclusion (`runners/llamacpp-ggml.md` §3.1); the 7B row reproduces the Prompt Cache paper's reported ~0.50 MB/token for Llama-7B (`papers/prompt-cache.md` §4); and the MimirAlloc dossier's harness convention for TinyLlama-1.1B in f32 — 2 × 22 layers × 4 KV heads × 64 head-dim × 4 bytes = **45,056 B/token** — is the same formula at a smaller scale (`memory/mimiralloc-our-own-proven-work.md` §4.2). The formula is not in dispute anywhere in the literature we read; only its inputs vary.

Read the table by columns and the field's history falls out:

- **MHA → GQA is a 4× cache cut at 7–8B scale** (512 KiB → 128 KiB per token) bought purely by sharing each KV head among a group of query heads. The MQA/GQA/MLA lineage (§8) is best understood as a sequence of attacks on the `H_kv` factor (and, for MLA, on the whole `H_kv × D` product, by caching a compressed latent instead of per-head vectors). A runner cannot retrofit these — they are properties of the trained model — but a runner *must* read them from the model metadata and budget from the true `H_kv`, never from the query-head count. Budgeting an 8B GQA model as if it were MHA over-reserves 4×; the reverse error OOMs.
- **Scale does not rescue you.** The 70B's per-token cost is *higher* than the 8B's (more layers), even with the same GQA ratio. Bigger models get longer advertised contexts *and* bigger per-token caches simultaneously.
- **Batch multiplies silently.** Every figure above is *per sequence*. The H2O paper's motivating example — ~180 GB of KV for a 30B model at batch 128 × 1,024 tokens (`papers/h2o.md` §2) — is this same arithmetic with the batch factor restored: at datacentre batch sizes the cache dwarfs the weights by an order of magnitude.

### 1.3 Why the cache, not the weights, is the binding constraint at long context

Weights are a fixed cost: a model's weight bytes do not care how long the conversation runs. Cache bytes grow linearly and without an intrinsic limit — the model will happily accept context until the memory runs out. The crossover is a division:

```
crossover context  T*  =  weight bytes  ÷  bytes per token
```

- Llama-3.1-8B, Q4_K_M weights ≈ 4.9 GB (llama.cpp dossier §3.1), f16 cache 131,072 B/token: T* ≈ 4.9 × 2³⁰ ÷ 131,072 ≈ **40,000 tokens**. Past ~40K of context, the *cache* is the larger resident object — for a model whose weights were quantised precisely to fit small cards.
- The same 8B with f16 weights (~16 GiB): T* ≈ 16 × 2³⁰ ÷ 131,072 = **131,072 tokens** — the crossover arrives almost exactly at the model's advertised 128K window. In other words, serving the *advertised* context of a modern 8B at full precision requires roughly *doubling* the machine the weights alone need, and the second half is all cache.
- Llama-2-7B (MHA), f16 weights ~14 GiB, cache 524,288 B/token: T* ≈ 14 × 2³⁰ ÷ 524,288 ≈ **28,700 tokens** — cache-bound well inside its 4K-trained window's extended use, which is why MHA-era models felt memory-starved out of proportion to their size.

Capacity is only half the binding. The cache also binds **bandwidth**: every decode step reads the entire resident cache (§1.1), so the per-token byte traffic of decode is `weight bytes + T × bytes-per-token`, and the single-stream decode ceiling is `sustained bandwidth ÷ bytes read per token` (roofline dossier §3.2). At T = 32K for the 8B above, the cache contributes 4 GiB of the ~8.9 GiB read per generated token — nearly half the traffic is history, not model. Long context therefore taxes the user twice: once in capacity (can it fit?) and once in speed (every token gets slower as the conversation grows), even before any quality question about long-context attention is asked. Any design that shrinks bytes-per-token (§5), avoids re-reading evicted history (§4.2), or shares history instead of duplicating it (§3) is attacking one or both of these two taxes. There is no third tax and no other kind of win.

**Applicability.** *(a) Ollama build:* `num_ctx` *is* this arithmetic wearing a UI — the fork should compute and display bytes-per-token from GGUF metadata at load time and show the crossover for the chosen weights/cache precision, instead of letting the user discover it as an OOM or a silent truncation (the failure modes catalogued in `runners/ollama.md` §4–§5). *(b) Aesir:* the same formula, evaluated per attention layer only, belongs in Aesir's fit-checker beside its weight-fit arithmetic; a fit verdict that counts weights but not cache is wrong by up to 2× at long context. *(c) MimirAlloc:* none at this level — the formula is accounting, not allocation — except that the *output* of the accounting (a single large, predictable, append-mostly region) is exactly the shape §2.5 argues should never go through a general allocator at all.

---

## 2. Layout design space

"Layout" answers four separable questions that are often conflated: **(i)** in what units is cache storage allocated, **(ii)** how does a token position map to an address, **(iii)** how are K and V arranged inside that storage for the attention kernel, and **(iv)** who else can point at the same storage. This section takes them in order.

### 2.1 Allocation geometry: contiguous arenas, blocked tables, radix trees, hybrids

**Contiguous per-sequence arena.** The classical design (early llama.cpp, HF Transformers, Ollama's inherited model): each sequence owns one contiguous tensor region sized to its maximum context, allocated up front. Addressing is trivial (position = offset), kernels are the fastest available — the PagedAttention paper measured its paged kernel at 20–26% higher attention latency than FasterTransformer's contiguous kernel (`papers/pagedattention-vllm.md` §4) — and the costs are all in the accounting: memory is pre-paid for context never used, two sequences cannot share a byte, freeing a middle sequence strands a hole (external fragmentation), and the PagedAttention paper's profiling found prior systems actually using only 20.4%–38.2% of the KV memory they had allocated. llama.cpp's modern form softens "per-sequence" into a shared cell-addressed pool (§2.5) but keeps the essential property: a sequence's capacity is reserved as a range, not grown block by block from a global free list.

**Blocked / paged tables.** PagedAttention's design (`papers/pagedattention-vllm.md`): one global pool of fixed-size blocks (16 tokens by default in vLLM); each sequence holds a block table mapping logical block index → physical block ID; allocation is on demand, one block at a time; blocks are reference-counted, which is what makes sharing (§3) and copy-on-write expressible at all. Internal fragmentation is bounded by one partial block per sequence; external fragmentation is zero by construction (all blocks are interchangeable). The price is indirection in the kernel (walk the table), a block manager in the scheduler's hot path, and all-or-nothing residency — a sequence needs *all* its blocks present to run, which shapes preemption (§4.3).

**Radix trees.** SGLang's RadixAttention (`papers/radixattention-sglang.md`) is not a different allocation geometry — underneath, it is the same paged pool — but a different *index*: a compressed trie over token sequences whose nodes own blocks, so that "which sequences share which prefix" is represented explicitly as shared tree paths rather than discovered by hashing. The tree buys longest-prefix matching over arbitrary shared structure (not just identical system prompts), LRU eviction over unreferenced *leaves* (shared trunks are structurally protected because they are not leaves), and cache-aware scheduling. vLLM's production answer to the same problem is deliberately flatter: a hash table over hash-chained full blocks (§3.1), no tree. The honest summary: paging decides *where bytes live*; radix/hashing decides *how reuse is found*. They compose, and conflating them produces muddled designs.

**Hybrids in production.** Every serious current system is a hybrid of the above plus tiering: SGLang's HiCache extends its radix tree across GPU → host DRAM → external storage with *different layouts per tier* (layer-first on GPU for kernels, page-first on host/storage for transfer efficiency — `runners/sglang.md` §5.3); vLLM V1 pairs its block pool with an external KV-connector tier rather than an in-engine swap tier (`runners/vllm.md` §4.3–4.4); llama.cpp pairs its cell pool with a RAM cache of idle slots' prompt state and on-disk slot files (`runners/llamacpp-ggml.md` §3.2, §3.4). The pattern to copy is not any one hybrid but the principle: **one addressing scheme (blocks), several residency tiers, layout chosen per tier.**

### 2.2 Block size: the one true tuning knob of layout

Block size `B` (tokens per block) trades four things against each other:

1. **Internal fragmentation.** A sequence wastes on average `B/2` token-slots in its last block. At B = 16 that is ~8 tokens/sequence — noise. At B = 256 it is ~128 tokens/sequence; across 100 concurrent sequences, ~12,800 token-slots (~1.6 GiB at the 8B's 128 KiB/token) held for nothing. Small blocks win.
2. **Sharing granularity.** Reuse can only be claimed in whole blocks (vLLM caches only full blocks; a 15-of-16-token match still recomputes the block — `runners/vllm.md` §4.2). The shorter and more varied the shared prefixes, the smaller B must be for sharing to fire at all. Small blocks win — with a floor: SGLang's default page size is 1 token, which eliminates rounding waste entirely and pushes all the cost into bookkeeping (below).
3. **Kernel and transfer efficiency.** Attention kernels read blocks; tiny blocks mean more table entries, more gathers, worse parallelism. The PagedAttention paper's sweep found 16–128 tokens good on long ShareGPT traces and 16–32 on shorter Alpaca traces. Tier transfers have the same shape in reverse: SGLang's hierarchical/MLA configurations use pages of 64–128 because I/O efficiency dominates there (`runners/sglang.md` §5.2). Large blocks win.
4. **Bookkeeping.** Block tables, hash entries and reference counts are all O(tokens ÷ B). At B = 1 the metadata is maximal but, on the evidence of two production systems running B = 16 (vLLM) and B = 1 (SGLang default), both ends are survivable; the metadata is small next to the cache itself in either case.

There is no universal optimum because the four terms weight differently by workload: many short sequences → small B; few long sequences → B barely matters for waste and should be chosen for the kernel; heavy prefix sharing with short shared spans → small B; tiered/offloaded caches → larger pages on the slow tiers. §7 turns this into a procedure. What the evidence does rule out is treating any system's default (16, or 1) as a law of nature: both are measurements on someone else's hardware and traces.

### 2.3 K and V arrangement inside the block

Given the blocks, the bytes inside them can still be arranged several ways, and the choice is a kernel contract, not a cosmetic one:

- **Separate K and V tensors** (llama.cpp: two large tensors per layer — `runners/llamacpp-ggml.md` §3.1; also the natural paged form, one block holding either K or V for its tokens). Attention reads all K (to score) then all V (to mix); separate tensors keep each read a clean stream, allow K and V to differ in precision (§5 — they should), and allow K to be stored **transposed** (see below) without disturbing V. This is the dominant production arrangement.
- **Interleaved K/V per token** (one record per token containing its K then its V, or per-head interleaving). Friendlier to *writing* (one token's state lands in one place) and to whole-token eviction/copying, worse for the read pattern (scoring strides over V bytes it does not yet need). Seen mainly in simpler/CPU-oriented implementations; the read-side penalty grows with head dimension.
- **Transposed K.** Scoring computes, for each past token, a dot product of the new query with that token's key. If K is stored as [token][dim], each dot product is a contiguous reduction — already good. Some kernels instead store K as [dim][token] so that the *matrix* of scores for all tokens is a single GEMV with unit-stride access across tokens, at the cost of strided appends (each new token writes one element into each of D rows). Which side wins depends on whether the engine is append-bound or score-bound; in decode it is overwhelmingly score/read-bound, which is why transposed-K (or an equivalent in-kernel transpose from a blocked layout) appears in high-performance decode kernels. The design rule is not "transpose" but: **choose the stored orientation for the decode read, and pay the transpose once at append time, never per read.**
- **Layer-first vs token-first across layers.** A block can hold one layer's slice for B tokens (layer-first: an attention kernel for layer *l* reads a compact region; a tier transfer must gather L regions to move B tokens) or all layers for one token-span (token/page-first: moving a token range is one contiguous copy; a single layer's kernel reads strided). SGLang's HiCache is the corpus's explicit worked example of refusing to choose once: layer-first on GPU, page-first on host/storage, with the conversion paid at tier boundaries (`runners/sglang.md` §5.3). llama.cpp's per-layer tensors are layer-first by construction; its slot save files are consequently large contiguous dumps whose size is architecture-dependent (`runners/llamacpp-ggml.md` §3.4).

A second axis cuts across all of the above: **positions are logical, not physical.** In llama.cpp's cell design a token is identified by (sequence id, position), and operations like "remove this position range" or "shift this range by a delta" are metadata operations on cells, not data movement (`runners/llamacpp-ggml.md` §3.1). That single decision is what makes context shifting, cache-reuse-by-shifting, and per-slot management cheap to express. A layout in which position *is* the address makes every such operation a memmove.

### 2.4 The attention pattern is part of the layout

Bytes-per-token (§1.2) assumes every layer caches every token. Two widespread departures change the layout itself, not just the total:

- **Sliding-window attention layers** (e.g. Gemma 3's local layers, Mistral's window) need only the last `W` tokens per such layer. Their cache is a ring buffer of capacity W, not a growing array — different allocation, different eviction (the window *is* the eviction), and a much smaller footprint. Ollama's new-engine line already exploits this: faithful per-model attention implementation converts directly into larger usable windows on the same memory (`runners/ollama.md` §4.5). SGLang's Unified Radix Cache gives SWA its own slot type, with the subtlety that reuse of a windowed layer needs only a *continuous window* before the reuse boundary, and out-of-window pages can be evicted independently, leaving marked "tombstone" slots (`runners/sglang.md` §5.4).
- **MLA-style latent caches** store one compressed latent vector per token per layer instead of per-head K and V; the §1.2 formula is replaced by `2` factors collapsing into a single latent dimension (plus a small decoupled RoPE key). The layout consequence for a runner is that K/V separation, per-head blocking and K-transposition all dissolve — there is one tensor, and the kernel reconstructs (or absorbs) the per-head projections. A cache manager designed around "K blocks and V blocks" does not survive contact with MLA unchanged; one designed around "per-layer per-token byte cost, read from metadata" does.

### 2.5 Where the corpus's runners sit — comparison table

All cells are from the banked runner dossiers cited; this table synthesises, it does not re-measure.

| | **Ollama** (`runners/ollama.md` §3–§5) | **llama.cpp / llama-server** (`runners/llamacpp-ggml.md` §3) | **vLLM V1** (`runners/vllm.md` §4–§5) | **SGLang** (`runners/sglang.md` §3, §5) |
|---|---|---|---|---|
| Allocation geometry | Slot-partitioned contiguous windows: runner started with `num_ctx × num_parallel` tokens of cache, partitioned per slot; full window allocated up front | Shared cell-addressed pool (unified KV): (seq, position) cells inside two large tensors per layer; capacity reserved per slot from the pool | Global paged pool, blocks of 16 tokens, allocated on demand; per-request block tables | Global paged pool (default page = 1 token); radix tree index over the pool |
| Growth | None — window fixed at runner start; changing `num_ctx` reloads the runner | Fixed `n_ctx` per slot; pool sized at startup | On demand, block by block, until pool exhaustion → preemption | Pool sized statically at startup (`--mem-fraction-static`); growth is into the pre-sized pool only |
| Sharing / reuse | Per-slot, last-prompt-only, exact-prefix; dies on unload; not shared across slots or models | Per-slot prefix reuse (`--cache-prompt`); `--cache-reuse` chunk shifting salvages near-prefixes; per-slot checkpoints rewind without reprocessing | Automatic prefix caching, hash-chained full blocks, on by default; `cache_salt` tenant isolation | RadixAttention: tree-structured sharing over arbitrary prefixes; cache-aware scheduling; fork hints from the frontend |
| Layout notes | Inherits llama.cpp layout on the GGUF path; per-model sliding-window savings on the new-engine path | Separate K and V tensors per layer, on the devices owning those layers; position-addressed cells enable rm/shift/copy as metadata ops | Per-layer blocks; block = 2 × B × H_kv × D × dtype bytes; duplicated-block quirk in V1 (append-only tables) | Layer-first on GPU; page-first on host/storage tiers (HiCache); per-component slots in Unified Radix Cache (FULL / SWA / MAMBA) |
| Eviction / preemption | None within a run; idle *models* evicted by keep-alive/scheduler, sessions simply end | No preemption; overflow = stop (server default) or positional context shift (opt-in); idle slots spilled to a bounded RAM cache | Preemption by recompute (V1 removed swap); all-or-nothing per sequence; priority-aware | Retraction (its preemption) + LRU eviction of unreferenced tree leaves; session-aware eviction protects live sessions' entries |
| Persistence | None — unload destroys reuse state | Three mechanisms: CLI prompt-cache files, server slot save/restore files, in-memory prompt cache (§4.4) | External KV connectors / LMCache tiers; no single-engine disk persistence story | HiCache L3 backends (Mooncake, 3FS, NIXL, local files) make the tree itself the session store |

The one-line reading: the field has converged on **paged pools + content-addressed reuse** at the serving end, while the local end (Ollama/llama.cpp) still runs **reserved windows + last-prompt reuse** — adequate at concurrency 1, and the gap between the two columns is precisely the list of things our fork can adopt in miniature (§7).

**Applicability.** *(a) Ollama build:* the cheapest layout upgrade with the largest effect is not full paging — it is llama.cpp's own lesson, position-addressed cells plus a *small* block table for the persona prefix (§3), keeping contiguous decode for the common path. *(b) Aesir:* adopt the block-table abstraction and per-tier layout split from the start; Aesir's targets (iGPU/NPU spill, Pi-class ARM) make tier boundaries more frequent, not less, than on a datacentre card. *(c) MimirAlloc:* a KV pool is the textbook case *against* a general allocator: one size class (the block), append-mostly, freed wholesale or by LRU — a dedicated free-list over a pre-sized arena does this in O(1) with zero metadata per allocation, where MimirAlloc's measured costs (one global lock; mapping-per-allocation above 1,024 B; K-008's large-path p99 of ~3.7–3.9 µs vs glibc's ~56–75 ns — `memory/mimiralloc-our-own-proven-work.md` §4.2) are all costs of generality the KV shape does not need. The MimirAlloc dossier's own verdict agrees: KV-shaped probes lost (Z-115), and KV should be a purpose-built arena problem. The allocator's proper role in a KV system is everything *around* the pool — block tables, hash maps, session records — not the pool itself.

---

## 3. Sharing and reuse semantics

Sharing is where the KV cache stops being a private scratchpad and becomes a data structure with semantics — and with failure modes. The governing fact is §3.4's position-binding; everything else is engineering around it.

### 3.1 Prefix sharing: three mechanisms, one invariant

The invariant: two sequences may share cached state **only for a token-identical prefix, at identical positions, under identical model configuration** (weights, adapter, cache precision, RoPE scaling). Given the invariant, the corpus contains three production mechanisms for finding and holding the shared part:

1. **Last-prompt comparison (llama.cpp / Ollama).** Compare the incoming prompt with the one prompt the slot last processed; reuse the longest common prefix; evaluate the suffix. One entry, no index, no sharing across slots. Correct, trivially private (nothing outlives the slot), and sufficient for append-only single-user chat — which is why Ollama gets away with it (`runners/ollama.md` §4.4).
2. **Hash-chained blocks (vLLM).** Each full block is named by a hash of (parent block's hash, this block's token IDs, extras: LoRA id, multimodal hashes, cache salt). Because the parent's hash is an input, a block's name *is* its entire prefix; lookup is a hash-table probe, and the longest hit is found block by block (`runners/vllm.md` §4.2). Since v0.11 the default hash is SHA-256 (~75 ns/token as documented — negligible against prefill). The chain is the design's quiet strength: no tree to balance or split, and a collision requires colliding with a *chained* value, not just a block's contents. Its weakness is the mirror image: nothing records that two cached prefixes share a *sub*-prefix except the chain itself, and V1's append-only block tables can transiently duplicate a block that already exists elsewhere (documented V1 limitation, same source).
3. **Radix tree (SGLang).** Prefixes are tree paths; partial overlaps are found by walking, nodes split on divergence, reference counts pin subtrees in use, and eviction proceeds leaf-to-root so shared trunks outlive private tips by construction (`papers/radixattention-sglang.md`). The tree costs more code and a little overhead (measured <0.3% on a no-reuse workload in the paper) and buys: sharing structure visible to the scheduler (cache-aware ordering reached ~96% of the optimal hit rate in the paper's evaluation), natural expression of *branching* (§3.2), and a single structure that tiering (§2.1) and hybrid checkpoints (§6) can hang off.

For our scale the choice is not ideological. A single-user chat has one dominant prefix family (persona + history + branches); a hash chain finds it as well as a tree does. The tree earns its complexity when prefixes share *partially* — same character, different scenario; same scenario, different character — which is a real shape in multi-character use. §7 rules on this for the fork specifically.

### 3.2 Copy-on-write at branch points: the chat case

A paged/shared cache must answer: what happens when two sequences share blocks and one of them *writes* the next token? The answer, from PagedAttention onward, is operating-system copy-on-write: a block with reference count > 1 is never written in place; the writer is given a fresh block, the shared block's contents are copied (only if the block is partial — a full shared block is simply left behind as the writer moves to a new block), and the writer proceeds privately. Cost: at most one block copy per divergence, and only for the boundary block.

In serving systems the canonical branch points are parallel sampling and beam search (the PagedAttention paper's sharing savings — up to ~55–66% of cache memory on beam-search workloads — come from exactly this). In *chat* the canonical branch points are product features:

- **Swipe / regenerate:** the user rejects a reply and asks for another. Everything up to the rejected reply is shared; the new reply is a sibling branch. With CoW blocks, a swipe costs one boundary-block copy plus the new generation's own blocks. Without sharing, the client resends the whole history and the runner re-prefills whatever its narrow reuse cannot salvage — and in Ollama today, a swipe that changes an early token invalidates the slot's single cached prefix from that token onward.
- **Edit-and-continue:** the user edits their message three turns ago. This is a branch at a *mid-history* point: the shared prefix is everything before the edit; everything after must be recomputed (positions and content both changed). A tree/block design expresses this as "retain the prefix blocks, drop the rest"; a contiguous design expresses it as a truncation plus re-prefill. Same semantics, very different constant factors.
- **What-if / parallel branches:** SGLang's frontend makes fork a language primitive (`fork`/`join`) so the runtime can pin the parent path *before* the branch runs (`papers/radixattention-sglang.md` §4). The lesson generalises beyond SGLang: a session API that *announces* an impending branch lets the cache manager protect the branch point; one that only shows the branch afterwards forces the manager to have kept everything, or to recompute.

The correctness edge that must be stated plainly: **CoW protects storage, not meaning.** Two branches sharing prefix blocks are guaranteed to *compute* identically over the shared span only if sampling state, adapters and configuration also match. The cache can share bytes; the session layer must still version what those bytes *mean*.

### 3.3 Cross-session sharing: where privacy and correctness bite

Sharing within one user's branching conversation is safe almost by definition. Sharing *across* sessions — other conversations, other characters, other users — is where the corpus's systems add deliberate friction, and a local fork should understand why before removing it:

- **Timing side channels.** A prefix hit is measurably faster than a miss. In a multi-tenant server, that lets a tenant probe whether a guessed prefix is already cached — i.e. whether someone else sent it. vLLM's answer is the `cache_salt`: a per-request salt folded into the *first* block's hash, so reuse only happens among requests carrying the same salt (`runners/vllm.md` §4.2). Its documentation also warns that fast non-cryptographic hash options theoretically risk collisions with privacy consequences in multi-tenant settings — the reason SHA-256 is the default despite xxHash being faster.
- **Isolation of saved state.** llama.cpp's slot files make the same point from the persistence side: saved slot state *is* conversation state, the design has no per-user isolation boundary on saved slots, and a controlled experiment has demonstrated cross-client slot-state recovery where slot saving was enabled and shared (`runners/llamacpp-ggml.md` §3.4 — reported there as a preprint finding, not a CVE, and repeated here with the same grading).
- **The single-user inversion.** On Volmarr's machines the threat model inverts: there is one user, and cross-*session* sharing (same persona across chats, shared lore across characters) is a *feature* worth real memory on a 6 GB card (§7). The correct local design is therefore not "no sharing" but "**sharing scoped by an explicit session/persona identity, never by accident**": reuse keys should include model + adapter + persona/session scope deliberately chosen by the application, playing the role `cache_salt` plays for tenants. What must not happen is the Ollama status quo's opposite failure — reuse so narrow (per-slot, last-prompt) that the user pays full re-prefill for a persona the machine computed minutes ago in another chat.

### 3.4 Position-dependence: why KV is not freely movable

The single most misunderstood property of the cache: **a token's KV encodes where the token was, not just what it was.** Under RoPE — the position scheme of essentially every model in this corpus — each key vector is rotated by an angle determined by its absolute position before being cached (and queries likewise at read time). A key cached at position 1,000 is a *different vector* from the same token's key at position 200, and attention scores computed against the wrong rotation are simply wrong — not degraded, wrong. Learned-absolute-embedding models bind position even more literally; ALiBi binds it in the bias rather than the vectors, which is why ALiBi caches are the most nearly movable of the three families.

Consequences, in increasing order of subtlety:

1. **Prefix reuse works because positions are preserved.** A shared prefix sits at the same positions in every reuser. This, and nothing else, is why §3.1's invariant holds.
2. **Mid-prompt reuse is invalid by default.** Moving a chunk from position 2,000 to position 500 (RAG assembly, lore injection, reordered history) reuses vectors rotated for the wrong place. Prompt Cache (`papers/prompt-cache.md`) is the corpus's exploration of how far this can be bent: it reserves disjoint position-ID ranges per declared module and relies on the *empirical* tolerance of models for discontinuous position IDs — measured to hold on its LongBench evaluation, model-dependent, and explicitly requiring per-model validation. It is a researched approximation, not a refutation of the binding.
3. **CacheBlend is the exception that proves the rule** (`papers/cacheblend.md`). It reuses chunks at *new* positions — and its entire contribution is the repair bill: recompute the KV of the highest-deviation tokens (~15% in its experiments) layer by layer to re-inject the cross-attention and position context the naive reuse omitted, pipelined against loading so the repair hides under I/O. Read correctly, CacheBlend does not show that position doesn't matter; it *prices* how much it matters — roughly a seventh of a prefill, on its workloads (Mistral-7B / Yi-34B / Llama-70B on 2× A40, RAG QA/summarisation) — and shows the price can be paid selectively.
4. **Shifting is re-basing, not moving.** llama.cpp's context shift (§4.2) works because it *rewrites* positions: surviving entries are shifted by a delta and their RoPE rotations adjusted to the new positions (`runners/llamacpp-ggml.md` §3.2). The operation exists precisely because the naive alternative — pretending the tokens were always at the new offsets without adjusting the vectors — is invalid.
5. **Quantisation interacts with position** (§5): KVQuant's pre-RoPE key quantisation exists because RoPE *mixes channels* — quantising after rotation smears per-channel outlier structure across dimensions and costs accuracy. Even the cache's *compression* must respect where position enters the pipeline.

**Design rule drawn here, applied in §7:** any feature that proposes to reuse KV at a different position than it was computed at is proposing an *approximation*, and must ship with (a) a named repair or tolerance argument and (b) a quality measurement against full prefill on the target model. Features that reuse at identical positions are exact and need no such burden.

**Applicability.** *(a) Ollama build:* implement sharing as scoped, hash-chained blocks (§7, Rule 3) with the scope key carrying model + quant + persona identity; treat swipe/regenerate as a first-class branch operation in the session API, not as a resend. *(b) Aesir:* Aesir's recorded prefix-snapshot work (§6) already embodies the exact-reuse discipline — snapshots restore bit-exact (diff 0.0) at identical prefix boundaries; keep that bar for any future non-prefix reuse and grade CacheBlend-style fusion, if attempted, by TTFT *and* quality delta, per the CacheBlend dossier's own applicability note. *(c) MimirAlloc:* sharing turns free into refcount-decrement; the pool's free path must therefore distinguish "release my reference" from "return to free list", and the last-release return is where the MimirAlloc campaigns found their tail costs live (burst-free p99 — §2.5). A refcounted block pool should make non-final releases O(1) counter work with no span/page traffic at all.

---

## 4. Lifecycle policies

A cache's life has four decisions: how it grows, what leaves when space is needed, what happens to a sequence that loses its space, and what survives a restart. Each has a production answer in the corpus and a characteristic failure mode when answered naively.

### 4.1 Allocation and growth

Three policies cover the field:

- **Reserve-the-maximum** (Ollama/llama.cpp slots): allocate the full window at start. Growth is a non-event; so is honesty about waste — a 4K conversation in a 32K slot holds 28K of zeros hostage, and on a small card that hostage-taking is the difference between one session and two. Its one virtue is predictability: admission is decided once, at load, and never revisited mid-generation.
- **Grow-on-demand from a pool** (vLLM, SGLang): allocate blocks as tokens arrive; admission is re-decided every step (can this sequence's next block be satisfied?), which is what makes continuous batching and preemption necessary *and* possible. The pool itself is pre-sized at startup in both systems (vLLM by a profiling run under `gpu_memory_utilization`; SGLang by `--mem-fraction-static`) — "on demand" describes block assignment, not OS allocation. This two-level shape (one big up-front arena, fine-grained assignment inside it) is the single most reusable systems idea in this dossier, and §7 adopts it verbatim.
- **Checkpoint-assisted growth** (llama.cpp server's per-slot checkpoints; SGLang's hybrid snapshots, §6): growth points double as restore points — at intervals the runtime records enough state to rewind to here instead of to zero. This converts several later lifecycle events (branch, preempt, resume) from recomputations into restores, at a storage cost per checkpoint that must be budgeted like cache itself.

### 4.2 Eviction: what leaves, and what it costs to be wrong

Eviction applies at two different levels that must not be confused: **cache-level eviction** (dropping *retained-for-reuse* state — finished prefixes in a radix tree or hash cache — to make room; the victim can be recomputed later and nobody's live generation is harmed) and **sequence-level eviction** (removing tokens from a *live* sequence's attention reach; the model permanently loses access to them). LRU over unreferenced tree leaves / free-queue order is the corpus's settled answer at the cache level (vLLM's free-queue LRU with reverse-order tail insertion; SGLang's leaf LRU — `runners/vllm.md` §4.1, `papers/radixattention-sglang.md`). Everything interesting is at the sequence level, where the corpus holds a small taxonomy of policies with sharply different honesty properties:

| Policy | Rule | Corpus source | Failure mode |
|---|---|---|---|
| Stop | Refuse/terminate at the window edge | llama-server default | Honest but useless for long chat |
| Positional shift | Keep first `n_keep` tokens, discard a middle span, re-base positions | llama.cpp shift; Ollama layer 2 (`num_keep` = 4 by default) | Keeps a *count*, not the content: a persona living past token 4 is discarded silently; first shift frees ~half the window |
| Front truncation | Drop oldest messages/tokens (FIFO) | Ollama layer 1 (message-level, system messages rescued); naive sliding windows everywhere | StreamingLLM's collapse: evicting the first tokens destroys the attention sink and perplexity explodes (Llama-2-13B window attention 5158 vs 5.40 sink+window, PG-19 — `papers/streamingllm.md` §5) |
| Sink + window | Pin the first few tokens forever; FIFO inside a rolling window | StreamingLLM (4 sink tokens sufficed on Llama-2-7B ablations) | Evicted middle is gone *forever* — stability without recall; must not be sold as memory |
| Attention-scored | Keep heavy hitters (accumulated attention) + a recent window; evict lowest-scored | H2O (20% budget ≈ full-cache quality on its suites; >95% attention sparsity measured) | Irreversible and backward-looking; needs attention scores that fused kernels may not expose; a once-mentioned name that never drew attention is exactly the adversarial victim |
| Observation-window scored | At end of prefill, score prompt tokens by attention from a trailing window; keep top-B per head (SnapKV); allocate B unevenly across layers (PyramidKV) | §8 pointers (pointed, not dossiered, per this dossier's brief) | Decided before generation begins; protects the prompt, says less about a growing generation |

Two cross-cutting judgements. First, **the policies compose**: the defensible long-chat stack is pinned head (persona + sinks, for both stability and product reasons) + heavy-hitter/recent hybrid for the middle + an *external* memory (summary/retrieval) for facts, because no eviction policy provides recall — H2O's dossier and StreamingLLM's dossier both insist on this pairing, and Ollama's current two-layer truncation is what happens when the composition is left to accident (system prompt rescued at layer 1, beheaded at layer 2 — `runners/ollama.md` §4.3). Second, **eviction granularity should be the block**: scoring may be per-token, but evicting inside blocks reintroduces the fragmentation paging exists to remove; score blocks by aggregating their tokens' scores (the H2O dossier's Aesir note makes the same point).

### 4.3 Preemption: recompute, swap, or spill

When resident sequences collectively need more than the pool — a new admission, a growth step with no free block — a *running* sequence must yield. The corpus's options, with their real costs:

- **Recompute (drop and re-prefill later).** vLLM V1's only mechanism: V0's swap was removed in the V1 redesign, and preemption is all-or-nothing per sequence (`runners/vllm.md` §3.3, §4.3). The PagedAttention paper's costing explains when this is right: at small block sizes, swapping means many small PCIe transfers and recompute wins; the two are comparable around block 16–64 (`papers/pagedattention-vllm.md` §4). Recompute also has a hidden ally — prefix caching: a preempted sequence's *retained* blocks may still be in the cache when it resumes, making its "recompute" partially a re-hit. Its cost is paid in the scarcest resource of a busy server (compute) and it re-pays the full prefill of whatever was not retained.
- **Swap to host RAM.** The V0 design and the classical OS answer. Cost is bytes ÷ interconnect bandwidth, paid twice (out and back), plus pinned-memory staging. On a single-user laptop the calculus differs from the datacentre's: host RAM is idle, the interconnect is the same PCIe, and the alternative (recompute on a small GPU) is slow in absolute terms — which is why llama.cpp's RAM cache for *idle* slots (bounded, default 8,192 MiB — `runners/llamacpp-ggml.md` §3.2) is the right local shape: spill the *idle*, never the running.
- **Spill to disk / session restore.** The slowest tier, treated in §4.4; as a *preemption* mechanism it is really "suspend this session" and belongs to session management, not the scheduler's inner loop.
- **Retraction** (SGLang's term for its preemption) sits in the recompute family, integrated with the radix tree: a retracted request's blocks return to the tree as reusable cache rather than to a void, so resumption is a tree hit plus suffix prefill.

The decision variable is the ratio `recompute cost ÷ transfer cost` for the sequence's length on the actual hardware — prefill FLOPs/token vs bytes/token over the actual bus — and it flips with sequence length (short sequences recompute cheaply; long ones are worth swapping) and with cache warmth. §7 fixes a local policy rather than re-deriving it per incident.

### 4.4 Persistence to disk and session restore

llama.cpp is the corpus's working example of cache persistence, and its dossier (`runners/llamacpp-ggml.md` §3.4) separates three mechanisms that are routinely conflated — the separation itself is a design lesson:

1. **CLI prompt cache** (`--prompt-cache`, `--prompt-cache-all`, `--prompt-cache-ro`): after prefill, the full inference state (KV + tokens) is written to a file; a later run loads it instead of re-processing. Tied to the same model and context size; documented to not guarantee identical subsequent tokens even at fixed seed; a binary blob in the build's internal format — non-portable across versions.
2. **Server slot save/restore** (`--slot-save-path` + `POST /slots/{id}?action=save|restore|erase`): disabled by default (endpoints return 501 without the path configured); restore requires the same model and slot count; every failure returns the same generic 400. The measured economics are the important part (community run reported in the dossier: Qwen3-1.7B, 7,289-token prompt, CPU-only Debian VM, llama.cpp commit `29c720e`): **cold prefill 160.7 s vs restore 2.14 s, file 836 MB** (~114,700 bytes per saved token for that architecture/cache type); a second measurement put a 5K-token chat at 9.9 s cold vs 1.4 s restored (~7×). Restore is a file read, not a computation — persistence economics are dominated by *when you save* and *how much you write*, never by FLOPs.
3. **In-memory prompt caching** (`--cache-prompt`, `--cache-reuse`): not persistence at all, but the within-run reuse of §3.1 — listed here because users and even documentation confuse "the server remembered my prompt" (this) with "my session was saved" (mechanisms 1–2). No auto-persistence exists in llama.cpp: upstream declined it, and the caller must drive save/restore explicitly (same source).

Design judgements for any system building on this: **(i)** a session file must carry its own validity envelope — model identity + quant, cache precision, tokeniser/template version, token count — and refuse (loudly, distinctly) on mismatch, instead of llama.cpp's single generic failure; **(ii)** file size is cache size: at the 8B's f16 rate a 32K session file is 4 GiB, so persistence policy (save on idle? on branch points only? compressed at §5 precision?) is a capacity decision, not a checkbox; **(iii)** a saved cache is a *privacy object* — it is the conversation, in a form that can be resumed — and must inherit the conversation's storage protections (§3.3); **(iv)** SGLang's HiCache L3 and vLLM's LMCache tier show the alternative framing: persistence as the bottom tier of the *cache* (content-addressed, evictable, shared by prefix) rather than as per-slot files. For a single-user fork, per-session files with an envelope are simpler and match the product ("my chats"); the tier framing wins if cross-session prefix reuse from disk is ever wanted.

**Applicability.** *(a) Ollama build:* replace the two-layer silent truncation with one declared policy — pinned persona head + rolling window + scored middle (§7, Rule 5) — surfaced in the API (tokens evicted, policy in force), with `shift: false`-style loud failure always available on *every* API route, not only the native one (the OpenAI route's inability to express it is documented in `runners/ollama.md` §4.3, §7.3). *(b) Aesir:* Aesir's token-level session residency and bounded snapshot store (4 per session, §6) are already a lifecycle policy; the addition this section argues for is an explicit preemption costing (recompute vs restore-from-snapshot vs spill) chosen by measured device throughput, CacheBlend-dossier style. *(c) MimirAlloc:* lifecycle is where allocator behaviour and cache behaviour meet most directly — growth-on-demand inside a pre-sized arena means the *host* allocator sees one large allocation per pool, not one per block; eviction and preemption then never call the host allocator in the hot path at all. The MimirAlloc L-006 harness shape — long-lived KV growth, per-step transient churn kept separate, teardown returning provably to baseline — is the lifecycle contract to test any Ollama/Aesir cache implementation against, whatever allocator sits underneath.

---

## 5. Precision: the cache is a numerical object

Cache precision is the only factor in §1.2's formula that a runner can change for a given model — `b`, bytes per element — which makes it the highest-leverage knob in this dossier and the one with the sharpest quality cliff. Halving `b` halves both taxes of §1.3 (capacity *and* per-step read bandwidth). The question is never whether to want it, but what the error does.

### 5.1 The ladder

| Storage | Bytes/elem | Cache vs f16 | Where the corpus meets it |
|---|---|---|---|
| f32 | 4 | 2× | MimirAlloc harness convention (45,056 B/token TinyLlama); reference/debugging |
| f16 | 2 | 1× | Default almost everywhere: llama.cpp `-ctk/-ctv` default f16; Ollama `OLLAMA_KV_CACHE_TYPE` default f16 |
| bf16 | 2 | 1× | Same bytes as f16, different error shape (below); llama.cpp cache type |
| fp8 (e4m3) / q8_0-class int8 | ~1 (+ scales) | ~0.5× | vLLM `kv_cache_dtype` fp8; llama.cpp q8_0 ≈ 34 B per 32 elems (32 int8 + f16 scale) → 32K 8B cache 4 GiB → ~2.1 GiB (`runners/llamacpp-ggml.md` §3.3); Ollama q8_0 "very small, usually unnoticeable" cost per the project (`runners/ollama.md` §4.5) |
| q4_0-class int4 | ~0.5 (+ scales) | ~0.25–0.28× | llama.cpp q4_0 (18 B per 32 elems); Ollama q4_0 with "small-to-medium" cost "more noticeable at large contexts" (same source); vLLM documents no INT4 KV (hardware/kernel reasons, per its docs as read in `runners/vllm.md` §4.3) |

Two precisions at the same byte width are not the same choice. **f16** spends its bits on mantissa (10) over a narrow exponent range (5 bits): fine resolution near typical magnitudes, overflow/underflow at extremes. **bf16** spends them on range (8 exponent bits) with a coarse mantissa (7): it rarely saturates but rounds every value harder. For cache purposes the practical reading is: bf16 is the safer container for activations with wide dynamic range (the reason it is the training default), f16 the finer one where range is known to be tame — and since both cost identical bytes, the choice is pure error-shaping and should follow the model's own training/compute precision unless measurements say otherwise. Neither is "half of f32" in behaviour; both are 1× in the only currency §1 counts.

A coupling that must be surfaced to users: in the llama.cpp/Ollama stack, quantised cache types are tied to Flash Attention being active (the dossier records this from two independent sources, with the exact per-backend coupling varying by build — `runners/llamacpp-ggml.md` §3.3). A fork must verify the coupling on its own build and report the *effective* cache type in force, not merely the requested one.

### 5.2 Scaling granularity: per-channel keys, per-token values

Uniform quantisation fails on the KV cache for a structural reason the KIVI/KVQuant line established (pointed in §8; summarised here only as far as §5's argument needs): **keys and values have different outlier geometry.** In keys, a few *channels* (dimensions) carry consistently large magnitudes across tokens; in values, outliers are spread per token. A single per-tensor scale is therefore destroyed by key channels it must accommodate, wasting resolution on everything else. The established remedies:

- **Keys per-channel:** one scale per channel (grouping elements along the token axis within a channel), so an outlier channel gets its own scale and stops taxing the rest. KIVI's central finding, and KVQuant's first component — the two lines agree on this despite independent derivations.
- **Values per-token:** one scale per token's value vector, matching where value outliers actually live. Again, both lines agree.
- **Pre-RoPE key quantisation (KVQuant):** quantise keys *before* the RoPE rotation is applied, because rotation mixes channels and would smear the per-channel structure the scheme depends on (§3.4, consequence 5). The cache then stores pre-rotation keys and applies rotation at read — a layout decision (§2.3) forced by a precision decision.
- **Outlier sparing (KVQuant):** keep a small fraction (~1% in its headline configuration) of outlier elements in full precision, stored sparsely; reported <0.1 perplexity degradation at 3-bit with sparing on WikiText-2/C4 across LLaMA/Llama-2/Llama-3/Mistral (paper's measurements, A100-class serving context — §8). KIVI's complementary tactic is a short full-precision *residual window* of recent tokens, quantising only the older bulk.
- **Non-uniform datatypes (KVQuant):** per-layer sensitivity-weighted codebooks instead of uniform integer grids, for the sub-4-bit regime where uniform grids waste codes on values that never occur.

The transferable principle is bigger than any scheme: **K and V are different distributions and must be quantised — and budgeted, and if necessary precision-tiered — independently.** llama.cpp's separate `-ctk`/`-ctv` flags and Ollama's single combined setting mark the two ends of getting this right; a fork should expose K and V separately even if it defaults them together.

### 5.3 The error story at long context

Why does cache quantisation degrade *more* at long context — as Ollama's own q4_0 warning states — when the per-element error is length-independent? Three compounding mechanisms, all structural:

1. **Every step reads the whole history.** A quantised weight is dequantised once per use in a fixed computation; a quantised cache entry participates in *every subsequent decode step's* attention. An early token's key error is not paid once — it is paid at every later position, and it perturbs the softmax denominator shared by all tokens, so errors interact rather than average out.
2. **Softmax amplifies key errors competitively.** Attention is a competition: a small perturbation to one key's score changes *every* token's weight after normalisation. At short context the competition is among few, well-separated candidates; at long context, among thousands of near-ties — precisely the regime where small score noise reorders the winners. (This is the same near-tie fragility the roofline/oracle disciplines in our own Aesir work grade for: rank changes at sub-logit gaps.)
3. **The important tokens are the outliers.** Attention sinks and heavy hitters (§4.2) are, numerically, the extreme entries — the ones quantisation represents worst. A scheme that spends its error budget uniformly spends it preferentially on the tokens the model leans on hardest. This is the concrete justification for mixed-precision policies: sinks/persona head and the recent window in f16, the bulk at int8, the cold middle (if anywhere) at int4 — precision following *measured importance*, not position alone. [The specific tier boundaries are a design proposal — SPECULATION as a prescription, though each ingredient (residual windows, outlier sparing, sink sensitivity) is individually evidenced in the sources above.]

**Grading discipline.** Cache-precision claims must be graded the H2O way — quality vs the full-precision cache *at the same context lengths the feature will actually run*, including the longest — and never by perplexity at 2K alone. A q4_0 cache that is "fine" at 4K and confabulating at 32K is not fine; it is a context-dependent defect, and the UI should say which contexts each precision tier is *validated* for (§7, Rule 4).

**Applicability.** *(a) Ollama build:* default q8_0-class KV on 6 GB-class cards (§7 works the arithmetic), expose K/V types separately, validate-and-label per model family — the project itself cautions that many-GQA-head models can be more sensitive to cache quantisation (`runners/ollama.md` §4.5), so a global silent default is the wrong shape. *(b) Aesir:* Aesir's compression-school direction — teaching the engine to *write* the packed forms it reads, graded packed-against-original — applies to cache tensors exactly as to weights, with the additional gate that cache packing must be graded at long context for the reasons above; a packed-cache win at short context proves almost nothing. *(c) MimirAlloc:* quantised blocks change the pool's block size, not its structure — but mixed-precision tiers mean *two or three block sizes* in one cache, i.e. two or three pools or size classes. That is still arena work, not general allocation; the failure mode to avoid is letting tiered block sizes drift into a general malloc workload through the back door.

---

## 6. The hybrid-model complication: the cache is no longer the whole memory

Everything above assumes the model's entire inter-token memory is the KV cache. A growing class of models breaks that assumption, and a cache design that ignores them will be wrong in a way no tuning fixes.

### 6.1 Two kinds of inter-token memory

- **Attention memory (KV):** grows linearly with tokens (§1.2), is token-addressable (entry *i* can be read, evicted, shared, re-based independently), and is exact.
- **Recurrent / SSM memory:** each recurrent layer carries a **fixed-size state** — for gated-delta / Mamba-class layers, a recurrent matrix state plus a short convolution state — that is *updated in place* by every token and does not grow. It is not token-addressable: the state after token 500 is a summary of tokens 1–500 fused together; there is no operation "remove token 300's contribution", no per-token eviction, no partial sharing, and no re-basing. It is, in the vocabulary of §4, a memory with exactly one lifecycle operation: **checkpoint and restore whole.**

Hybrid models interleave the two: most layers recurrent, full attention at intervals. Their serving memory is therefore `KV bytes (attention layers only) + state bytes (fixed, per sequence)`, and the two terms have opposite scaling — the state dominates at short context, the KV at long — and completely different reuse mechanics.

### 6.2 The qwen35 record (our own Aesir evidence)

The corpus's first-hand hybrid evidence is Aesir's Qwen3.5 work (`research/aesir/aesir-ideas-for-ollama.md` §3.2, from Aesir campaign records of 2026-11-14):

- **Architecture (real-file header census):** `qwen35` 27B — 64 blocks, hidden 5,120, FFN 17,408, 24 query heads / 4 KV heads, head dim 256, context 262,144; most layers recurrent Gated-DeltaNet (conv + recurrent state), full attention only at intervals, partial rotary (64 of 256 dimensions).
- **What its KV costs (our arithmetic, §1.2 applied per attention layer):** one attention layer costs 2 × 4 KV heads × 256 × 2 bytes = **4,096 B/token**. If attention sits at every 4th block — 16 of 64 layers — the hybrid's KV rate is 16 × 4,096 = **65,536 B/token = 64 KiB/token**: *half* the dense 8B's rate, from a model with over 3× the parameters. If all 64 blocks attended, the rate would be 262,144 B/token. [The every-4th-block count is an illustrative assumption: the Aesir record as read for this dossier states "attention at intervals" without fixing the interval; the per-layer figure (4,096 B/token) and the method are exact, and any reader with the model's GGUF metadata can substitute the true attention-layer count in one multiplication. The design conclusion — hybrid KV rates are set by the *attention-layer count*, a number that must be read, not inferred from total layers — does not depend on the assumption.]
- **What its state costs (recorded):** one full SSM+conv snapshot for this 27B ≈ **158.9 MB** — fixed, independent of context length, and *per checkpoint*. Aesir's store bound was 4 snapshots per session: ~636 MB of state checkpoints for one session of one hybrid model, before a single KV byte is counted.
- **The reuse mechanism that works (Q35-5, recorded as proven in the Aesir dossier):** snapshot the hybrid state (SSM + conv + boundary KV) at a prefix boundary; a later request/session matching that prefix restores the snapshot instead of re-running. Restores were **bit-exact** (SSM/conv/KV diffs 0.0), and a stateless resend reused **72 of 90 tokens** via snapshots after residency had been destroyed. Note what this is: RadixAttention's *idea* (reuse at prefix boundaries) with a different *payload* (an opaque state blob beside the KV blocks), because the recurrent part of the prefix's memory cannot be represented as blocks at all.

### 6.3 SGLang's generalisation: one tree, several memory kinds

SGLang's production line arrived at the same place from the serving side (`runners/sglang.md` §5.4, verified there against the project's own writing):

- **Separate pools as the foundation:** a per-token KV pool for attention layers and a **per-request state pool** for recurrent layers (state is allocated per request, fixed-size, bound for the request's life), both sized statically at startup — deliberately, to eliminate runtime OOM from state allocation.
- **Checkpointed prefix reuse (MambaRadixCache):** because an in-place state cannot be sliced, the runtime snapshots recurrent state at selected prefix endpoints and attaches snapshots to radix nodes; reuse copies the snapshot (copy-on-write — the cached checkpoint is never mutated) and resumes. Matching must find the deepest node holding *both* the KV prefix *and* a state checkpoint; eviction keeps **two LRU lists**, because a checkpoint can be evicted from any node (it is an annotation) while KV must go leaf-to-root; a cap on snapshots per root-to-leaf path bounds the multiplicative cost — each checkpoint is a full state, far larger per unit than a token of KV (cf. 158.9 MB above).
- **Unified Radix Cache (the general form):** one tree whose nodes carry **one slot per component** — FULL (full-attention KV), SWA (sliding-window KV, with tombstoned out-of-window slots), MAMBA (a state checkpoint at the node's endpoint) — and reuse is decided by **voting**: resume from the deepest boundary *every* component accepts. The same tree carries the HiCache tiers and session-aware eviction. Models named as motivating combinations include FULL+SWA and FULL+recurrent hybrids, and gated-delta-network linear attention (the Qwen3-Next / Qwen3.5 family) is handled in the same checkpoint spirit.

llama.cpp's side of the same recognition is quieter but real: its `llama_memory_i` abstraction exists precisely so that "memory" can mean KV cells for Transformers, recurrent state for Mamba/RWKV, or both for hybrids, behind one interface (`runners/llamacpp-ggml.md` §3.1). Three independent codebases converging on "memory is a sum of per-kind components behind one manager" is as close to a settled design fact as this young area has.

### 6.4 What this changes for cache design

1. **Budgeting must be per-component.** "Bytes per token" is now only the attention component's rate; the honest fit equation is `weights + T × kv_rate + sequences × state_bytes + checkpoints × state_bytes + buffers`. A fit-checker that omits the state terms will over-admit hybrid sessions by hundreds of MB each.
2. **Eviction splits.** KV components can use §4.2's whole taxonomy; state components can only be kept or dropped *whole, at boundaries*. There is no H2O for a fused recurrent state — importance scoring cannot reach inside it. [Whether a state can be *approximately* summarised/compressed for eviction purposes is an open research question — SPECULATION if asserted as a capability; no corpus source demonstrates it.]
3. **Branching costs a state copy.** A swipe in a hybrid session forks the KV cheaply (CoW blocks) *and* the state expensively (a full snapshot copy — 158.9 MB at 27B scale). Branch-heavy product features that are nearly free on dense models have a real, budgetable price on hybrids.
4. **Non-prefix reuse mostly dies.** CacheBlend-style fusion (§3.4) presumes token-addressable state that can be partially recomputed; a fused recurrent state offers no such handle. For hybrids, non-prefix reuse should be treated as unavailable unless a specific model family proves otherwise — the CacheBlend dossier's applicability note flags exactly this.
5. **Persistence gets easier and harder.** Easier: a hybrid session's recurrent memory is a fixed-size blob — save/restore is a bounded write, not a context-sized one. Harder: the *pair* (KV + state at a boundary) must be saved atomically and versioned together; restoring one without the other, or at a mismatched boundary, is silent corruption of exactly the kind §4.4's validity envelope exists to catch.

**Applicability.** *(a) Ollama build:* Ollama already serves hybrid GGUFs through llama.cpp's memory abstraction, but its *accounting and UI* speak only KV (`num_ctx`, cache-type settings). The fork should surface hybrid sessions' state bytes and snapshot counts as first-class budget lines, and must not promise swipe/branch costs measured on dense models when the loaded model is hybrid. *(b) Aesir:* Aesir is, on this evidence, *ahead* of the field's local end — Q35-5's bit-exact snapshots are the reference implementation of the pattern SGLang productised independently. The remaining Aesir work this section implies is the *policy* layer SGLang built around the mechanism: snapshot-placement policy (which boundaries earn a 158.9 MB checkpoint?), per-path caps, and the two-list eviction discipline. *(c) MimirAlloc:* state blobs are the opposite allocation shape from KV blocks — few, large, long-lived, copied whole. On the MimirAlloc evidence (mapping-per-allocation large path, K-008) such blobs are exactly where a naive allocator integration would pay microseconds per operation and header-page overhead per blob; a session-state store should be a small dedicated slab of fixed-size slots (state size is fixed per model!), which is again arena thinking, not general allocation.

---

## 7. Design rules for our work

This section is prescriptive: a decision procedure, then the procedure worked end-to-end for the case this campaign cares most about. Rules are numbered for citation from build-campaign documents. Each rule states its evidence base; where a rule extrapolates beyond the corpus, it says so.

### 7.1 The decision procedure

**Inputs:** model shape (layers by kind, KV heads, head dim, weight bytes at the chosen quant), context target T, VRAM budget V, workload shape (here: single-user long chat — one live sequence, occasional branches, persona prefix, sessions that pause and resume).

**Step 1 — Compute the model's two rates before choosing anything.**
`kv_rate` = 2 × L_attn × H_kv × D × b at f16 (b=2), from model metadata — never from parameter count. `state_rate` = recurrent state bytes per sequence (0 for dense models; from metadata/measurement for hybrids, §6). If either number cannot be produced for a model, the model is not yet *understood*, whatever its benchmark scores say. *(Evidence: §1.2, §6.4.)*

**Step 2 — Fix the residency budget honestly.**
`KV budget = V − weight bytes − runtime reserve − state bytes × concurrent sessions`. The runtime reserve (compute buffers, graphs, driver/context overhead, fragmentation headroom) must be a named number, not zero; §7.2 uses 512 MiB on a 6 GiB card as a planning reserve. [The 512 MiB figure is our planning choice, not a measurement — it should be replaced by a measured reserve per backend at first implementation, and the procedure is written so that only this one input changes.]

**Step 3 — Choose cache precision to meet the context target; do not choose the context to meet a precision habit.**
Compute max context at f16, then at int8-class, then at int4-class (§5.1 ratios: ~1×, ~0.53×, ~0.28× of f16 bytes in the llama.cpp quant formats). Take the *highest* precision whose max context ≥ T with headroom ≥ 10%. If even int4 cannot reach T, the honest options are a smaller model, a GQA/hybrid model with a lower `kv_rate`, or a reduced T — in that order of preference for chat quality. *(Evidence: §5; worked in §7.2.)*

**Step 4 — Choose layout: paged blocks over one pre-sized arena; block size by sharing shape.**
Default B = 16 tokens (the PagedAttention default, mid-range of its measured-good sweep). Drop to B = 1–4 only if profiling shows sub-block prefix sharing dominating (many short shared spans); raise the *tier-transfer* page size (not the GPU block size) to 64–128 if a host/disk tier is in use. One arena, sized at load; blocks assigned inside it; no per-block host allocation, ever. *(Evidence: §2.1–2.2, §2.5.)*

**Step 5 — Choose sharing scope and mechanism.**
Hash-chained blocks keyed by (parent hash, tokens, model+quant+cache-precision, scope id) where scope id = persona/session family chosen by the application (§3.3). Announce branches through the session API so branch points can be pinned before forking. Exact-position reuse only; anything else is a research feature behind a quality gate (§3.4).

**Step 6 — Choose the eviction composition (live sequence) and the retention policy (finished prefixes) separately.**
Live sequence, in priority order: pinned head (persona + sink tokens) → scored middle (heavy-hitter by accumulated attention where the kernel can supply scores; otherwise age-based with the persona-adjacent turns protected) → recent window (never evicted). Finished prefixes: LRU over unreferenced blocks, session-scoped entries protected while their session is live. Every eviction event is reported to the client (counts + policy), never silent. *(Evidence: §4.2 and the StreamingLLM/H2O dossiers.)*

**Step 7 — Choose preemption and persistence as one policy.**
Single-user default: never preempt the *running* sequence; spill *idle* sessions to host RAM (llama.cpp's RAM-cache shape), persist to disk on idle-timeout and on branch points (checkpoints), restore in preference to recompute whenever `file bytes ÷ disk bandwidth < suffix prefill time` — which, on the §4.4 measurements (2.14 s restore vs 160.7 s cold on a CPU-only box), is nearly always. Session files carry the §4.4 validity envelope.

### 7.2 Worked case: purplelongship, 6 GB, single-user long chat

**Machine:** purplelongship — ASUS ROG Zephyrus G14, RTX 2060 Max-Q, **6 GB VRAM** (verified in our records at driver install, 2026-10-28: "RTX 2060 awake … 6 GB VRAM"). **Workload:** one long character chat, persona prefix ~1–2K tokens, target context T = 8,192 minimum, 16,384 desired. **Model candidate:** Llama-3.1-8B class, Q4_K_M weights ≈ 4.9 GiB (llama.cpp dossier §3.1), `kv_rate` at f16 = 131,072 B/token (§1.2).

*The budget (Step 2), in MiB:* V = 6,144 (6 GiB) − weights 5,018 (4.9 GiB × 1,024) − reserve 512 = **614 MiB for KV**.

*Precision ladder (Step 3), max context = 614 MiB ÷ bytes-per-token:*

| Cache precision | Bytes/token (arithmetic) | Max tokens = 614×2²⁰ ÷ bytes/token | Verdict vs target |
|---|---|---|---|
| f16 | 131,072 | 643,825,664 ÷ 131,072 = **4,912** | Fails even the 8K minimum |
| q8_0 (~34 B/32 elems ⇒ ×34/64) | 131,072 × 0.53125 = 69,632 | 643,825,664 ÷ 69,632 = **9,246** | Meets 8K with ~13% headroom → **choose num_ctx 8,192** |
| q4_0 (~18 B/32 elems ⇒ ×18/64) | 131,072 × 0.28125 = 36,864 | 643,825,664 ÷ 36,864 = **17,465** | Meets 16K — but at the precision tier whose long-context cost is documented as noticeable (§5.1) |

**Decision (the procedure's output):** ship the 8B on this card at **q8_0 KV, num_ctx 8,192, one slot**, persona head pinned, sink+scored+window eviction (§7.1 Step 6) extending *usable* conversation well past 8,192 tokens of history at 8,192 tokens of resident cache. Offer 16K/q4_0 only as an explicitly-labelled experiment, validated per §5.3's grading discipline on this model before it is offered at all. Note what the arithmetic forbids: Ollama's stock behaviour on this card (VRAM tier → num_ctx 4,096 at f16 — `runners/ollama.md` §4.1) is not a conservative version of this decision; it is a *different* one, spending the whole KV budget on precision the workload cannot perceive while halving the context it can — and then truncating silently when even that fills (§4.3 of the Ollama dossier).

*The alternative the procedure surfaces (Step 3's "smaller model" branch):* a 3B-class GQA model (28 attention layers × 8 KV heads × 128 head-dim ⇒ `kv_rate` = 2×28×8×128×2 = 114,688 B/token f16; Q4 weights ≈ 2.0 GiB) leaves 6,144 − 2,048 − 512 = 3,584 MiB for KV ⇒ 3,584×2²⁰ ÷ 114,688 = **32,768 tokens at full f16 precision**. On a 6 GB card, *context is bought with model size more cheaply than with cache precision* — a trade the UI should show as arithmetic, not folklore: 8B smarts at 8K validated context, or 3B smarts at 32K, both honest, user's choice.

*Decode-speed sanity check (roofline, §1.3):* at 8,192 tokens the q8_0 cache reads 8,192 × 69,632 B ≈ 0.53 GiB per generated token, against 4.9 GiB of weights — the cache is ~10% of per-token traffic, so at this operating point decode speed is weight-dominated and the precision choice cost almost no speed; at 32K f16 on the 3B, cache reads are 3.5 GiB vs 2.0 GiB of weights — the cache *is* the traffic, and per-token latency will grow visibly across the conversation. Both statements follow from `bandwidth ÷ bytes-per-token-read`; the card's sustained bandwidth must be *measured* (STREAM-style, per the roofline dossier §4.3) before either is turned into a tok/s promise. [No tok/s figure is asserted for this card in this dossier.]

*Hybrid variant, for completeness:* were the chat model a qwen35-class hybrid at the §6.2 illustrative rate (64 KiB/token f16) with ~159 MB state, the same 614 MiB budget (weights held equal for illustration only) would hold (614−159) MiB ÷ 64 KiB ≈ **7,280 tokens of KV plus one state**, and each additional *checkpoint* would cost another ~159 MB — the binding constraint quietly moves from tokens to snapshots. Real hybrid weights differ; the structural point is the one §6.4 makes: budget the components separately or the fit-checker lies.

### 7.3 The rules, distilled

1. **Budget from `kv_rate`, never from parameter count or advertised context.** Compute bytes/token from metadata (attention layers × KV heads × head dim × precision) at load; display the crossover context beside any `num_ctx` control. (§1)
2. **One arena, blocks inside it, no per-block host allocation.** Pre-size the pool once; assign fixed-size blocks (default 16) from a free list; reference-count them. A general allocator — MimirAlloc included, on its own measured evidence — is for the structures *around* the pool, never for the pool. (§2)
3. **Reuse is exact-position, hash-chained, and scope-keyed.** Parent-hash + tokens + model/quant/precision + application-chosen scope. Branches are announced by the session API and served by copy-on-write on the boundary block only. Non-position reuse is a gated research feature, never a default. (§3)
4. **Precision is chosen per model, per K/V separately, and labelled with its validated context range.** Default int8-class on ≤8 GB cards; f16 where the budget honestly affords the target context; int4-class only behind a per-model long-context quality gate. The *effective* precision in force is reported, including any Flash-Attention coupling surprises. (§5)
5. **Eviction is a declared composition, never an accident of two layers.** Pinned persona/sink head + scored middle + protected recent window for live sequences; LRU over unreferenced blocks for retained prefixes; every eviction visible in the API. Silent truncation of a persona is a defect, full stop. (§4)
6. **Spill idle, restore before recompute, persist with an envelope.** Idle sessions go to RAM, then to disk at checkpoints/branch points; session files carry model/quant/precision/tokeniser identity and refuse loudly on mismatch; a saved cache inherits the conversation's privacy handling. (§4)
7. **Hybrids are budgeted per component and branched at checkpoint cost.** State bytes and snapshot counts are first-class budget lines; snapshot placement is a policy with a per-path cap; no design may assume token-addressable memory for a recurrent layer. (§6)

**The three strongest rules** (if the build campaign keeps only three): **Rule 1** (the arithmetic is the product — most small-card misery in the corpus traces to budgets nobody computed), **Rule 5** (the persona-beheading failure is the corpus's clearest demonstrated harm, and it is a *policy composition* bug, not a capacity fact), and **Rule 2** (the arena/block discipline is what makes Rules 3, 5 and 6 implementable at all — and it is the point where our own MimirAlloc evidence most directly disciplines the design).

---

## 8. Further reading — annotated pointers (verified links only)

*Corpus-internal dossiers are cited by path in the text throughout and are not repeated here. The pointers below are for the lines this dossier deliberately did **not** dossier — per its brief, §8 is a pointer list, not a set of summaries. All external links verified as resolving to the named work on 2026-11-15.*

**KV quantisation (for §5):**
- **KIVI** — Liu et al., "KIVI: A Tuning-Free Asymmetric 2bit Quantization for KV Cache", ICML 2024. The per-channel-K / per-token-V finding and the full-precision residual window. https://arxiv.org/abs/2402.02750
- **KVQuant** — Hooper et al., "KVQuant: Towards 10 Million Context Length LLM Inference with KV Cache Quantization", NeurIPS 2024. Pre-RoPE per-channel key quantisation, non-uniform datatypes, 1% outlier sparing; <0.1 perplexity degradation at 3-bit as reported. https://arxiv.org/abs/2401.18079

**Scored eviction beyond H2O (for §4.2):**
- **SnapKV** — Li et al., "SnapKV: LLM Knows What You Are Looking For Before Generation", 2024. Observation-window scoring at end of prefill; the natural next dossier after H2O. https://arxiv.org/abs/2404.14469
- **PyramidKV** — Cai et al., "PyramidKV: Dynamic KV Cache Compression Based on Pyramidal Information Funneling", 2024. Per-layer budget allocation over SnapKV-style scores. https://arxiv.org/abs/2406.02069

**Attention-shape attacks on `kv_rate` (for §1.2, §2.4):**
- **MQA** — Shazeer, "Fast Transformer Decoding: One Write-Head Is All You Need", 2019. The one-KV-head endpoint of the sharing spectrum. https://arxiv.org/abs/1911.02150
- **GQA** — Ainslie et al., "GQA: Training Generalized Multi-Query Transformer Models from Multi-Head Checkpoints", EMNLP 2023. The grouped middle point every current open model family uses. https://arxiv.org/abs/2305.13245
- **MLA** — DeepSeek-AI, "DeepSeek-V2: A Strong, Economical, and Efficient Mixture-of-Experts Language Model", 2024 (the MLA paper in substance; reports a 93.3% KV reduction vs its MHA baseline). The latent-cache redesign of the whole §1.2 formula. https://arxiv.org/abs/2405.04434

**Primary sources for the synthesised systems (full dossiers in the corpus):**
- PagedAttention/vLLM — Kwon et al., SOSP 2023: https://arxiv.org/abs/2309.06180 → corpus: `papers/pagedattention-vllm.md`, `runners/vllm.md`
- RadixAttention/SGLang — Zheng et al., NeurIPS 2024: https://arxiv.org/abs/2312.07104 → corpus: `papers/radixattention-sglang.md`, `runners/sglang.md`
- Prompt Cache — Gim et al., MLSys 2024: https://arxiv.org/abs/2311.04934 → corpus: `papers/prompt-cache.md`
- CacheBlend — Yao et al., EuroSys 2025: https://arxiv.org/abs/2405.16444 → corpus: `papers/cacheblend.md`
- StreamingLLM — Xiao et al., ICLR 2024: https://arxiv.org/abs/2309.17453 → corpus: `papers/streamingllm.md`
- H2O — Zhang et al., NeurIPS 2023: https://arxiv.org/abs/2306.14048 → corpus: `papers/h2o.md`

### Sources and access dates

- Corpus dossiers (all in this repository, read in full for this synthesis, 2026-11-15): `papers/` — pagedattention-vllm, radixattention-sglang, prompt-cache, cacheblend, streamingllm, h2o; `runners/` — ollama, llamacpp-ggml, vllm, sglang; `memory/` — mimiralloc-our-own-proven-work, memory-wall-and-roofline; `aesir/aesir-ideas-for-ollama.md` (qwen35/Q35-5 records, themselves citing Aesir campaign records of 2026-11-14).
- Fleet fact: purplelongship RTX 2060 Max-Q 6 GB VRAM — our own records, verified at NVIDIA driver install, 2026-10-28.
- External pointers in §8: link targets verified 2026-11-15 (arXiv records for 2402.02750, 2401.18079, 2404.14469, 2406.02069, 1911.02150, 2305.13245, 2405.04434). The §8 works were **not** read in full for this dossier and are cited as pointers only; no measurement from them is relied on in §§1–7 beyond the one-line characterisations in §5.2/§8, which are stated as those works' own reported claims.

### What could not be verified in this pass

- **The qwen35 attention interval** (how many of its 64 blocks are full-attention): the Aesir records read state "attention at intervals" without the count; §6.2 therefore gives the exact per-layer rate (4,096 B/token) and an explicitly-labelled illustrative total. One GGUF metadata read settles it.
- **A measured runtime reserve for the RTX 2060 Max-Q under Ollama/llama.cpp**: §7.2's 512 MiB is a planning figure, flagged as such at the point of use; the procedure's outputs move by ±1 precision tier if the true reserve differs by ~±300 MiB, which is why Step 2 demands a measured replacement.
- **Sustained memory bandwidth of purplelongship's RTX 2060 Max-Q**: not measured in any record available to this pass; §7.2 accordingly asserts no tok/s figure for the card and prescribes the STREAM-style measurement instead (roofline dossier §4.3).
- **Whether SGLang's Unified Radix Cache is the default for all model classes** at access time: the SGLang runner dossier records this as unverified there (transition in progress); §6.3 describes the design without claiming default status.

*End of dossier — OR-6 Topic A1, 2026-11-15.*
