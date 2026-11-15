# llama.cpp — KV-Cache and Slot Internals (OR-2 Deep-Dive Addendum)

**Corpus:** Ollama Research Forge — runner dossiers, deep-dive addendum to `runners/llamacpp-ggml.md`
**Subject:** ggml-org/llama.cpp — how the KV cache is organised, how sequences share it, and how llama-server's slots sit on top of it
**Clean-room note:** This dossier is a behavioural description written in our own words from llama.cpp's public source and documentation. It describes design and behaviour only; no upstream code is reproduced. Every substantive claim names the file or component it was read from, so a reader can re-verify against the pinned tag.

---

## 1. Identity and version stamp

- **Project:** llama.cpp (ggml-org/llama.cpp), the C/C++ inference engine underneath a large part of the local-LLM ecosystem, and its bundled HTTP server, llama-server.
- **State read:** release tag **`v1.0.0`** — the project's first semantic-version release, published 2026-11-13. The version-bump commit in that release is `4cda622` ("llama.cpp: bump version to 1.0.0", PR #32190); the nightly build bundled in the same release is `b12359`. All source reading for this dossier was done against the `v1.0.0` tag on **2026-11-15**.
- **Scope warning:** llama.cpp moves weekly. A nightly (`b12368`, 2026-11-14) already existed the day after the tag. Anything below is a statement about **v1.0.0**, not about master, and should be re-checked before being treated as current.
- **Why v1.0.0 matters for this topic specifically:** the 1.0.0 release is unusually disruptive in exactly the areas this dossier covers. Its release notes record: removal of 35 deprecated public functions; removal of the `defrag_thold` setting and its `--defrag-thold` flag (PR #30565); addition of OCP FP8 KV caches (`f8_e4m3` for `-ctk`/`-ctv`, PR #28392); a fix to on-device state-copy sizes for quantised KV caches (PR #30541); the server switching to reference-counted context checkpoints instead of deep copies (PR #30137); and the server visiting parent slots before child slots for shared-prefix requests (PR #30779). Several widely repeated descriptions of llama.cpp's KV behaviour — including "it defragments its cache" — are stale as of this release.

## 2. Architecture in one pass

Memory in llama.cpp is an abstraction, not a data structure owned by the context. The public header `include/llama.h` exposes an opaque memory handle, and `src/llama-memory.h` defines the internal interface behind it. The implementations a reader will meet are:

- **`llama_kv_cache`** (`src/llama-kv-cache.cpp`, `src/llama-kv-cache.h`) — the standard transformer KV cache, and the subject of most of this dossier.
- **`llama_kv_cache_iswa`** (`src/llama-kv-cache-iswa.cpp`) — a composite for models that interleave sliding-window attention (SWA) layers with full-attention layers; it is literally two `llama_kv_cache` instances glued together (Section 6).
- Recurrent and hybrid memory implementations for state-space / recurrent architectures, which share the same public verbs but not the cell machinery. They are out of scope here except where the server treats all memory types uniformly (checkpoints, Section 5).

At v1.0.0 the public memory verbs were renamed from the older `llama_kv_self_*` family to a `llama_memory_*` family (`include/llama.h`, "Memory" section): clear the memory; remove a sequence's tokens in a position range; copy one sequence to another; keep only one sequence; add a position delta to a sequence's tokens; divide positions by an integer; query a sequence's minimum/maximum stored position; and ask whether the memory supports shifting at all. State save/restore exists both for whole contexts and per sequence, including an extended per-sequence API with flags for partial (SWA/recurrent) state and for keeping state on device buffers — the RAM prompt cache in Section 5 is built on that extended API.

A context is configured through `llama_context_params` (`include/llama.h`). The fields that matter here are: total context size; logical and physical batch sizes; the maximum number of sequences; the K and V cache element types (marked experimental in the header); a flag forcing full-size SWA caches; a flag requesting a **unified** KV buffer shared across sequences (whose header comment advises disabling it when there are multiple sequences that do not share a large prefix, referencing PR #14363); and a facility for a second context to share another context's memory.

On top of the library sits **llama-server** (`tools/server/`). The server owns exactly one target context (plus an optional draft context for speculative decoding) and multiplexes a fixed set of **slots** onto it. A slot is a server-side request/session object; its numeric id is used directly as the library-level sequence id. Everything in Section 5 follows from that one decision: slots are not separate caches, they are named sequences inside one shared memory.

The rest of the dossier answers the five commissioned questions in order.

## 3. Question 1 — KV organisation: cells, streams, rings, sharing, shifting, and the death of defragmentation

### 3.1 The unit of allocation is the cell, and cells are metadata over flat tensors

For every layer that participates in the cache, `llama_kv_cache` holds a K tensor and a V tensor whose shape is conceptually *[per-token K width, number of cells, number of streams]*, stored in the cache's K and V element types. (Multi-head latent attention models are the exception: they keep no separate V tensor.) Layers are not obliged to participate: the cache constructor accepts layer filter, reuse, and share callbacks, so some layers can be skipped, can alias another layer's storage, or can share their cell bookkeeping with a second cache instance — in the sharing case the borrowing cache's size is forced to match the source's. Each layer entry also carries optional per-layer scale tensors used by the FP8 cache (Section 4) and optional rotation buffers used by the quantised-cache Hadamard rotation (Section 4).

The tensors themselves are dumb storage. All intelligence lives in a per-stream metadata structure, `llama_kv_cells` (`src/llama-kv-cells.h`). For each cell it tracks:

- the token **position** stored in the cell, with −1 meaning empty;
- an **extension record** for cells that need more than a scalar position — 2D spatial coordinates for M-RoPE models, and the originating token id for cells produced from embedding (multimodal) inputs;
- an accumulated **position shift** waiting to be applied to the stored keys (Section 3.5);
- a **bitset of sequence ids** — the single most consequential design choice in the whole cache. A cell does not belong to a sequence; it *lists* the sequences it is currently visible to. A shared prompt prefix, or the common trunk of parallel samples, is stored **once**, with several sequence bits set. There is no copying and no reference-counted block table in the vLLM sense; sharing is a bit in a bitset.

Around the per-cell arrays, `llama_kv_cells` maintains derived indexes: a set of used cell indices; for each sequence, an ordered set of (position, cell) pairs, which makes per-sequence minimum/maximum position queries logarithmic rather than scans; and a transposed per-sequence bit array over cells, used to build the explicit row lists consumed by the row-based flash-attention path (below).

### 3.2 Streams: unified pool vs one pool per sequence

The cache constructor derives the number of **streams** from the unified flag: unified means one stream; non-unified means one stream per sequence slot, with each sequence id statically mapped to the stream of the same number. In unified mode every sequence maps to stream 0, so all sequences compete for — and share — a single cell pool and a single set of cell metadata. In non-unified mode each sequence has a private pool of equal size and private metadata.

This distinction leaks into the copy verb: copying a sequence to another sequence **within** one stream is metadata-only (set the destination's bit on the source's cells), while a copy **across** streams must physically copy tensor rows and is deferred to the next cache update pass. The server's parent/child parallel-sampling mechanism (Section 5) is cheap precisely when parent and children live in the same stream.

### 3.3 Allocation: a ring search that tolerates holes

Placement is decided by the cache's slot-finding step (named `find_slot` in `src/llama-kv-cache.cpp` — an internal name that predates, and should not be confused with, the server's slots). Behaviour, as implemented:

- Each stream keeps a **ring head**: the cell index where the next search starts. The search walks forward from the head, wrapping around the end of the pool.
- A cell may be taken if it is **empty**, or if it belongs to **exactly one** sequence and that sequence's position in the cell is already outside its sliding-window reach (i.e. the cell is dead but not yet reclaimed). A cell shared by two or more sequences is never stolen, even if one of its owners no longer needs it — the other owners pin it.
- A heuristic guards against the ring head drifting far into sparse territory: if the head has run far ahead of the number of used cells (the code compares against the used count plus twice the incoming token count), the search restarts from cell 0 to fill early holes first.
- Placement is **not required to be contiguous** in the normal path; the finder is called in non-contiguous mode when batches are prepared. If every cell in the stream has been tested without success, the finder returns an empty placement — the failure mode of Section 7.

Non-contiguous placement is affordable because of how attention consumes the cache. Alongside the classic "attend over a prefix of the buffer" view, the cache can build, per micro-batch slice, an explicit list of the cell rows belonging to each sequence (the `llama_kv_rows_slice` structure in `src/llama-kv-cells.h`, feeding ggml's row-list flash-attention operation). Sequences whose cells are scattered therefore still attend correctly, at the cost of gathering rows. This is the load-bearing fact behind Section 3.4.

### 3.4 Defragmentation: removed, not merely reworked

Older descriptions of llama.cpp describe a defragmentation pass, governed by a fragmentation threshold, that compacts the cache by moving cells together when allocation fails or fragmentation grows. **At v1.0.0 that mechanism no longer exists:**

- The public setting and the server flag for the defragmentation threshold were removed in the 1.0.0 release (PR #30565, per the release notes).
- Searching the v1.0.0 `src/llama-kv-cache.cpp` for the defragmentation path returns nothing.
- In `src/llama-kv-cells.h`, the cell-move operation that compaction would need survives only as **commented-out code**, annotated as having been used during defragmentation.

The design bet is visible from the replacement: because placement is non-contiguous and attention can consume an explicit row list, fragmentation is a performance nuance rather than a correctness or capacity problem, so the project deleted the compactor instead of maintaining it. There is consequently **no defragmentation trigger to characterise** — not under load, not ever, at this version. Any capacity failure is handled by the allocation failure path (Section 7), not by compaction. This is the first of the three findings flagged for the fork in the accompanying report: a design that assumes "llama.cpp defragments, we can too, later" is assuming a mechanism its own authors have now abandoned.

### 3.5 Batch preparation is transactional

Before a batch runs, the cache *prepares* placements for all of its micro-batches: it tentatively applies each micro-batch to the cell metadata, snapshots the cells and ring heads it touched, and then rolls the metadata back. If any micro-batch cannot be placed, preparation fails as a whole, the batch-initialisation step reports a dedicated "failed prepare" memory status, and the public decode call returns **1**, which `include/llama.h` documents as "could not find a KV slot for the batch (try reducing the size of the batch or increase the context)". Nothing is half-written: either the whole batch has reserved cells, or the cache metadata is exactly as it was. The actual cell writes happen later, when the prepared micro-batch is applied; at that point the cache asserts an invariant that every position in a sequence's [min, max] range is present (the same guarantee the public header makes for the position-query functions), advances the ring head to just past the last placed cell, and — when an incoming write overwrites a cell that a sliding-window sequence had already masked out — purges that sequence's positions up to the overwritten point (the code comments reference PR #13746 for this interaction).

### 3.6 Context shift at library level: re-rotating keys instead of recomputing them

"Context shift" is widely misunderstood as moving data. At library level it moves **positions**, and repairs the stored keys afterwards:

- The add/divide verbs adjust each affected cell's recorded position and accumulate the delta into the cell's pending-shift field; a cache-wide "has shift" flag is set. No tensor data moves at this point.
- On the next update pass, if shifts are pending, the cache builds a single additional compute graph that re-applies the rotary position embedding to the stored K tensors, using each cell's accumulated shift, and then clears the pending shifts. V is untouched — values carry no position.
- The implied cost model is therefore: **one extra graph pass over the K cache of the RoPE-bearing layers**, proportional to cache size, versus the alternative of re-evaluating discarded-and-shifted tokens through the whole model. It is far cheaper than recomputation, but it is not free, and it is all-or-nothing per update.

Shifting is **not universally available**, and the cache says so through the can-shift query. At v1.0.0 it reports false for at least: an architecture whose RoPE dimensionality varies per layer (named in the source as the Step35 family — a single global re-rotation cannot express per-layer geometry), and any model whose positions are multi-dimensional (M-RoPE, more than one position per embedding). For the interleaved-SWA composite cache there is a further, stricter condition covered in Section 6. If a caller attempts an update with a pending shift on a cache that cannot shift, the update path aborts rather than silently producing wrong keys. The server layers its own, stricter rules on top (Section 7).

## 4. Question 2 — Quantised KV: per-context types, FP8 scales, and the padding bill

### 4.1 How the types are applied

K and V element types are **independent of each other, chosen per context, and uniform across layers**. They are set on the context parameters and surfaced by llama-server as `-ctk/--cache-type-k` and `-ctv/--cache-type-v`; both default to **f16** (`common/common.h`; `tools/server/README.md`). The server's documented allowed set at v1.0.0 is: f32, f16, bf16, **f8_e4m3 (new in this release, PR #28392)**, q8_0, q4_0, q4_1, iq4_nl, q5_0, q5_1. There is no per-layer mixing: one context, one K type, one V type. (The draft model in speculative decoding gets its own pair of types, per the server's draft cache-type flags.)

Two couplings matter:

- **Quantised V requires Flash Attention.** The context constructor refuses the combination outright, raising an error to the effect of "quantized V cache was requested, but this requires Flash Attention" when flash attention is off (`src/llama-context.cpp`). Quantised K alone does not carry this requirement.
- **FP8 carries scales.** The OCP FP8 formats support optional **static per-tensor scales**, and each cache layer holds pointers to K and V scale tensors sourced from per-layer scale values stored with the model. A quantised cache is therefore not just "the same tensors, narrower": for FP8 it is tensors plus scale metadata that must be created, carried through state save/restore, and kept consistent. (The 1.0.0 fix in PR #30541 — correcting on-device state-copy sizes for quantised caches — is a reminder that state serialisation is where quantised caches most easily break.)

### 4.2 The Hadamard rotation: quantisation quality is bought with a pre-transform

When a cache type is quantised and the head dimension permits, the cache precomputes an orthonormal Walsh–Hadamard rotation and applies it to keys (and, with a preference for smaller matrices, to values) before quantisation, spreading outlier energy across the row so that coarse quantisation hurts less (`src/llama-kv-cache.cpp`, rotation setup; the per-layer rotation buffers are visible in `src/llama-kv-cache.h`). The rotation size starts at 64 and doubles while it still divides the head dimension. DeepSeek's lightning-indexer keys are always rotated. The whole mechanism can be disabled through a model setting or the `LLAMA_ATTN_ROT_DISABLE` environment variable. For the fork, the lesson is that "support q8_0 KV" in llama.cpp quietly includes "and rotate K/V into a quantisation-friendly basis" — a naive byte-for-byte port of the type list without the rotation would not reproduce its quality.

### 4.3 Padding and alignment consequences

Quantisation is not the only force shaping the layout; the cache pays a visible padding bill in several places:

- **Context size is padded to a multiple of 256** when the context is created (Section 6), and attention lengths derived from the cache — both the plain KV length and the row-list length — are likewise rounded up to multiples of 256 so that compute graphs can be reused across steps instead of being rebuilt for every exact length.
- **Variable V widths are padded to the maximum.** When V is stored transposed, flash attention is off, and layers disagree about V size, the V cache is padded per layer to the largest V size across layers, with a warning logged (the path is tagged in the source as the variable-V-cache case). Memory is spent on the worst layer, uniformly.
- **Padding is explicitly initialised.** The cache buffers are written with defined values at creation specifically so that padded regions cannot produce NaNs that later leak into attention.
- **Block granularity follows the ggml type.** A cell row's byte stride comes from ggml's row size for the chosen element type, so block-quantised types impose their block structure on the head-dimension row: head dimensions and the type's block size must compose, and the savings of a quantised type are realised per row, not per element. The exact per-type block sizes and byte tables live in ggml's type traits, which were **not** read for this dossier; any bytes-per-token figure more precise than the cache's own logged totals (Section 6) is therefore **unverified** here.

## 5. Question 3 — Slots: the server layer

### 5.1 One context, N slots, slot id = sequence id

llama-server creates a fixed number of slots (`-np/--parallel`; see Section 6 for the surprisingly conditional default) and binds each slot to the sequence id equal to its slot index in the single shared target context. A slot (`tools/server/server-context.cpp`) carries everything the library knows nothing about: its retained prompt (a token list plus checkpoints, as a `server_prompt` in `tools/server/server-task.h`), its sampler chain, its LoRA set, its statistics, its speculative-decoding state, and its current task. All slots contend for the one context's KV pool under the rules of Sections 3 and 6. Older secondary descriptions of llama-server as running a context per slot are stale; at v1.0.0 there is one context, and the slot/sequence identity is the whole design.

### 5.2 The slot state machine

The slot lifecycle is an explicit state machine (the source comment references the state diagram in PR #9283):

**idle → started → processing prompt → done prompt → generating → (release) → idle**, with one extra state, **waiting-for-other**, for child slots in parallel sampling that must wait for their parent to finish the shared prompt. A slot counts as "processing" in every state except idle. Release is not amnesia by default: a released slot normally **keeps its prompt and KV** so the next task assigned to it can reuse them (Section 5.3). The exceptions, whose prompts are cleared on release, are child slots, stateless tasks, and the TTS and realtime slot flavours.

### 5.3 Choosing a slot, and the three layers of prompt reuse

Prompt reuse in llama-server is not one mechanism; it is three, stacked. Conflating them is the most common error in descriptions of this server.

**Layer 0 — which slot gets the task** (`get_available_slot` in `tools/server/server-context.cpp`):

1. If the request names a slot id, that slot is used; if it is busy, it is returned as-is and the caller defers the task rather than stealing it.
2. Otherwise, if prompt similarity matching is enabled — the threshold setting `slot_prompt_similarity` defaults to **0.1** (`common/common.h`) — the server scores every idle slot by the longest common prefix (LCP) between the slot's retained prompt and the new prompt, expressed as a fraction of the new prompt's length. The best-scoring idle slot above threshold wins. If the fraction of the *old* prompt that would survive the match is under one half, the old prompt is first evicted into the RAM prompt cache (Layer 2) rather than being discarded.
3. If no slot qualifies, the least-recently-used idle slot is taken (oldest last-used timestamp), again with its old prompt offered to the RAM cache first.

**Layer 1 — in-slot prefix reuse (`cache_prompt`).** Each task carries a `cache_prompt` flag, defaulting to **true** (`tools/server/server-task.h`). When a task starts on a slot, the server computes the LCP between the slot's retained tokens and the new prompt, then caps it: by the shared-prefix length for child slots, by any decision point in the prompt, and by the invocation point of an activated LoRA. Everything past the reusable prefix is removed from the sequence (a range-remove over positions from the end of the prefix onward), the slot's token list is truncated to the prefix, and only the suffix is evaluated. One deliberate inefficiency is invariant: **if the new prompt is identical to the retained one, the match is shortened by one token, so at least one token is always evaluated** — the server needs fresh logits to generate from, and the code enforces it rather than assuming it. This layer is pure prefix logic: a prompt that diverges at token 3 reuses 2 tokens, however much later text coincides. The per-request statistics record how many prompt tokens were served from cache versus freshly processed, and those numbers surface in the server's timings.

**Layer 1.5 — shifted chunk reuse (`--cache-reuse N`, default 0 = off).** For prompts that share *interior* chunks rather than a prefix, the server can optionally attempt reuse-by-relocation. It requires `cache_prompt` on, requires the memory to support shifting, and is disabled for multimodal prompts. It scans the retained prompt against the new prompt for matching runs of at least N tokens beyond the prefix; each run found is moved in place to its new position with a remove-plus-shift pair of memory operations (the shift being the K-re-rotation machinery of Section 3.6), and the reusable count grows accordingly. It is off by default, and it inherits every limitation of shifting — notably it is unavailable for the models and cache configurations of Sections 3.6 and 6 that cannot shift.

**Layer 2 — the RAM prompt cache (`server_prompt_cache`).** Slots hold one prompt each; the RAM cache is the server's memory of prompts that no slot currently holds. It lives in `tools/server/server-task.h` (structure) and `tools/server/server-task.cpp` (behaviour), and its properties at v1.0.0 are:

- **What an entry is:** a `server_prompt` (token list plus its checkpoints, the checkpoints shared by reference — one of the things v1.0.0's reference-counting change, PR #30137, makes cheap) plus the **serialised per-sequence state** of both the target and draft contexts, captured through the extended state API. Restoring an entry is therefore a state copy back into a sequence id, not a re-evaluation.
- **Limits:** `--cache-ram` caps the cache in MiB, default **8192 MiB**; −1 means no limit, 0 disables it, and decision-style models default to 0 unless the flag is given explicitly (`tools/server/README.md`, `common/common.h`). An entry individually larger than the limit is never stored — it is skipped with a warning rather than flushing the cache. If allocating an entry's buffers throws out-of-memory, the cache **shrinks its own limit to 40% of its current size** and carries on: a self-throttling failure mode rather than a crash.
- **Saving (`alloc`):** a prompt that is already fully contained in an existing entry is not stored again; entries that are strict prefixes of the incoming prompt are deleted as obsolete (the longer entry supersedes them); then, if room is needed, entries are evicted **from the front of the list — oldest first, a FIFO discipline, not LRU-by-access**.
- **Loading (`load`):** the slot's own retained prompt is the baseline candidate. Each entry is scored by LCP against the new prompt, expressed two ways: the fraction of the entry that would be kept, and the fraction of the new prompt it covers. Entries keeping less than **25%** of themselves are disqualified outright ("don't trash large prompts"). An entry wins only if it beats the incumbent on **both** fractions simultaneously. Winning is destructive: the entry's state blobs are written into the slot's sequence, the stored data is freed, and the entry is erased from the cache — a cached prompt can be restored into exactly one slot, once. (Eviction order being FIFO while restore is destructive makes this cache behave more like a queue of recently displaced sessions than like a shared prefix store.)
- **Idle-slot harvesting (`--cache-idle-slots`, default enabled, requires the RAM cache):** when a new task arrives, idle slots' prompts are saved into the RAM cache; **in unified mode only**, the idle slots are then cleared so their cells return to the shared pool. In non-unified mode their KV is left resident, because clearing a private pool buys the other slots nothing.

**A correctness caveat the fork should note.** A cache entry's identity, as defined by the `server_prompt` structure, is its **token list and checkpoints — nothing else**: no LoRA adapter set or scales, no sampler or template identity. The server does compare a new task's LoRA configuration against the *slot's previous task* when launching, and can clear the slot prompt on a mismatch; but whether that check validates a prompt that arrived via a RAM-cache restore (whose KV was computed under whatever configuration produced the entry) is **not established** by the v1.0.0 source reading done here. An external report (a dev.to article, read as a secondary source) demonstrated at the earlier build b11514 that KV computed under one LoRA scale could be silently reused for the same tokens under another, citing upstream issues #30129 and #26207, with `--cache-ram 0` or per-request `cache_prompt: false` as mitigations. The entry structure at v1.0.0 still contains no adapter identity, so the risk should be treated as **plausibly open, unverified at v1.0.0** — and as a design warning either way: a state cache keyed on tokens alone will eventually serve state computed under a different effective model.

### 5.4 Checkpoints: making non-rollback-able memory reusable

Prefix reuse assumes you can truncate a sequence at an arbitrary position. Sliding-window and recurrent memories cannot always honour that: their live state may start *after* the point a new prompt needs to resume from. The server's answer is per-slot **checkpoints** — periodic snapshots of sequence state taken during prompt processing, capped by `--ctx-checkpoints` (default **32**) with a minimum spacing of **8192 tokens**. When a reused prefix's live state begins too late (its minimum position is at or beyond a threshold computed with the SWA window in mind), the server restores the newest checkpoint that starts early enough, using partial-state restore where the memory type requires it. If no checkpoint qualifies, it does not approximate: it **forces full prompt re-processing** from position 0. At v1.0.0 checkpoints are reference-counted and shared between slot and cache entries instead of being deep-copied (PR #30137), which is what makes keeping up to 32 of them per slot affordable.

### 5.5 Parallel sampling: parent and child slots

For n-best style parallel sampling, one **parent** slot processes the shared prompt; at the done-prompt transition its prompt and sequence state are copied to the **child** slots, which have been sitting in the waiting state; children then generate independently. v1.0.0 orders slot visitation parent-before-children for shared-prefix requests (PR #30779) so the copy source is ready before children are considered. In unified mode the copy is the metadata-only same-stream operation of Section 3.2. Two restrictions follow from sharing: context shift is forbidden for parent and child slots (Section 7), and children do not retain their prompts on release (Section 5.2).

### 5.6 Disk persistence of slots

Separate from both in-slot reuse and the RAM cache, the server exposes explicit slot save/restore/erase task types (`tools/server/server-task.h`), reachable only when started with `--slot-save-path`; by default this is disabled (`tools/server/README.md`). It is an operator feature, not part of the automatic reuse machinery.

## 6. Question 4 — Memory accounting: what `-c` actually buys, and the SWA split

### 6.1 What the library reports

At cache creation, `llama_kv_cache` logs, per backend buffer type, the KV buffer size in MiB, and a summary line giving total MiB, cell count, layer count, sequence/stream counts, and the K and V contributions separately with their types (`src/llama-kv-cache.cpp`). Programmatically, each memory implementation exposes a **memory breakdown**: a map from backend buffer type to bytes, covering the KV buffers and the rotation buffers; the context aggregates model memory, KV memory, and the MoE cache into a total exposed through the public breakdown function. Accounting is therefore *structural* — derived from allocated buffers — rather than estimated per token. Per-token byte costs are whatever the logged totals divided by cell count say they are; the project does not publish a per-token formula, and (per Section 4.3) this dossier did not reconstruct one from ggml type traits.

### 6.2 `-c/--ctx-size`: a pool size, not a per-slot promise

`-c` defaults to 0, meaning "use the model's training context" (`tools/server/README.md`). In the context constructor (`src/llama-context.cpp`) the effective context size is taken from the parameter or the training size and **padded up to a multiple of 256**. What that number then means depends entirely on the unified flag:

- **Unified:** the per-sequence context equals the full (padded) size. The pool has that many cells, total, and every sequence's ceiling is the whole pool — sequences are limited by contention, not by a private quota.
- **Non-unified:** the total is **divided** by the maximum sequence count, each share is padded to a multiple of 256, and the context size is then *recomputed* as share × sequence count, with a warning if padding changed the number the user asked for. `-c 16384` with 4 sequences is 4096 per sequence, plus rounding — not 16384 each.

The server's per-slot figure, reported to clients, is the minimum of: the per-sequence context, the `--kv-unified-per-slot` value if set, and the model's training context. `--kv-unified-per-slot N` is the explicit way to think in per-slot terms: set without `-c`, it sizes the shared pool to *number of slots × N* (`tools/server/README.md`; server parameter preparation in `tools/server/server.cpp`).

### 6.3 The default-configuration trap

The interaction that most deserves the fork's attention: **`-np/--parallel` defaults to −1 ("auto"), and in auto mode the server sets the slot count to 4 and turns unified KV on.** If the operator instead passes an explicit `-np 4`, unified KV stays **off** unless `-kvu/--kv-unified` is also passed. The same command line, `-c 16384 -np 4`, therefore describes two different machines: auto-flavoured, one shared 16k-cell pool that any slot can mostly consume; explicit, four private ~4k pools. Neither is a bug — both are documented — but the meaning of the most-quoted llama-server flag silently flips with how a different flag was supplied. A further confound: `--fit` (default **on**) may adjust unset arguments, context size included, to fit device memory, with `--fit-ctx` setting a floor of 4096; the detailed fit algorithm was read only at README level for this dossier and its exact interaction with KV sizing is **unverified** beyond that.

### 6.4 Per-request accounting

What the server reports per request is reuse, not bytes: each slot's statistics record prompt tokens served from cache and prompt tokens actually processed, and these surface in response timings and metrics. Combined with the creation-time buffer logs and the breakdown API, an operator can answer "how big is the cache" and "how much reuse am I getting", but not "how many bytes did that request's KV occupy" — in a shared pool with shared cells, that question is not well-defined anyway, which is presumably the point.

### 6.5 SWA accounting: two caches, one shrunk

For interleaved-SWA models, `llama_kv_cache_iswa` (`src/llama-kv-cache-iswa.cpp`, read in full for this dossier) partitions layers by filter: non-SWA layers go to a base cache sized at the full context; SWA layers go to a second cache sized at **the sliding-window size times the number of sequences that can hold distinct windows (the sequence maximum in unified mode, 1 otherwise), plus one micro-batch, padded to a multiple of 256** — the code comments note the padding is for performance and reference issue #17037. `--swa-full` overrides the SWA cache to full size, with a warning. Position queries (min/max) are answered from the SWA cache, since the base cache is a superset of it; the memory breakdown is the sum of both caches.

The consequential interaction: the composite's can-shift answer requires **both** sub-caches to be shiftable **and of equal size**. With a shrunk SWA cache — the default — the sizes differ, so shifting is unavailable, and with it the server's context-shift continuation (Section 7) and shifted chunk reuse (Section 5.3) for exactly the long-context SWA models that would most want them, unless the operator pays for `--swa-full`. This is a quiet, structural trade: the memory saving and the shift features are mutually exclusive at v1.0.0.

## 7. Question 5 — Failure and edge behaviour

### 7.1 Prompt too large: reject, never truncate

A prompt that does not fit its slot's context is rejected **before** processing: the server raises its exceed-context-size error and releases the slot. For splittable prompts the test is token count against the per-slot context; non-splittable prompts are additionally checked against the micro-batch size. There is no silent prompt truncation anywhere in this path — truncation exists in llama-server only as the generation-time mechanism of Section 7.3, applied to a slot's own history, never to an incoming prompt.

### 7.2 Pool exhausted mid-decode: fail the batch, steal nothing

At library level, exhaustion is the failed-prepare path of Section 3.5: decode returns 1 and the caller must shrink the batch or enlarge the context. The allocator will not evict another sequence's live cells to make room, will not steal a shared cell, and recycles only empty cells and single-owner cells already dead under a sliding window. In unified mode this means one greedy sequence *can* starve the others up to the pool limit — admission control is the server's slot assignment, not the allocator's fairness. There is no compaction fallback (Section 3.4).

### 7.3 Generation reaches the ceiling: stop, or shift if explicitly enabled

When a generating slot fills its context, behaviour splits on `--context-shift`, which is **off by default**:

- **Off:** generation cannot proceed; the slot is released through the error path. Long generations simply end at the context wall unless the operator opted in.
- **On:** the server performs a context shift, but only in the generating state, never for parent/child shared-prompt slots (attempting it there errors and releases the slot), and never for multimodal prompts (the feature auto-disables for them; reaching the shift code with media present aborts). The algorithm (`update_slots` in `tools/server/server-context.cpp`): keep a head of the sequence — the request's keep-count, plus one if a beginning-of-sequence token is present, clamped so at least 4 positions remain free; the discardable middle is what lies between the kept head and the newest tokens; discard **half of it by default**, or the request's explicit discard count, clamped to discard at least nothing and at most all-but-one of the middle; remove that range from the sequence and shift everything after it down by the discarded amount (the K-re-rotation of Section 3.6); splice the slot's token list identically; mark the slot as truncated. The cost is one shift pass plus the discarded context; the quality consequence is deliberate and known — positions on either side of the seam were never attended together, so the model continues across a discontinuity it cannot see. It is a liveness feature, not a memory feature.

### 7.4 Defragmentation under load

Not applicable at v1.0.0: the mechanism was removed (Section 3.4). The honest answer to "what does defrag do under load" is that there is nothing to trigger, and allocation failure under load is handled by Sections 7.1–7.2.

### 7.5 Documented invariants worth stealing as a checklist

The sources state, in comments and header documentation, a set of invariants that together amount to the cache's contract:

- For any sequence, **every position in [pos_min, pos_max] is present** in memory (stated in `include/llama.h` and relied on by the apply step).
- A positive reused-prefix count with an empty live state (minimum position −1) is a "should not happen" hard abort, cross-referenced to PR #13833.
- Cell state may only be snapshotted or restored when **no shift is pending** — the cell copy/restore operations assert a zero accumulated shift.
- **At least one token is always evaluated** per prompt, so logits exist (Section 5.3).
- Overwriting a sliding-window-dead cell purges the victim sequence's positions consistently (PR #13746, Section 3.5).
- The interleaved-SWA composite may shift only when its two sub-caches are equal-sized (Section 6.5).
- Decode's positive return codes are warnings with defined state semantics, and on non-fatal returns the memory state is restored to what it was before the call (`include/llama.h`) — the transactional promise that Section 3.5 implements.

## 8. Strengths and weaknesses, as engineering

**Strengths.**

- *Sharing without a page table.* The per-cell sequence bitset gives prefix sharing, parallel-sampling sharing, and metadata-only same-stream copies with no block manager, no reference counts, and no fragmentation of ownership. For the single-node, few-slot regime llama-server targets, this is radically simpler than paged designs and the sharing is exact.
- *Transactional batch preparation.* Reserve-then-apply with rollback means the failure mode of a full cache is a clean, documented return code, never a half-written cache. Callers can reason about state after errors because the header promises restoration.
- *Reuse is layered honestly.* Slot affinity by LCP, in-slot prefix truncation, an explicitly-sized RAM state cache, and checkpoints for memories that cannot truncate: each layer has a clear cost (a state copy, a restore) and a clear switch, and reuse is reported per request.
- *Quantised KV is treated as a system feature,* with the rotation pre-transform for quality, FP8 scales carried as first-class tensors, and the flash-attention requirement for quantised V enforced at construction rather than discovered as wrong results.
- *The design deletes what it no longer needs.* Removing defragmentation once non-contiguous placement made it unnecessary is good hygiene; the codebase carries its invariants in comments with PR references, which made this dossier possible.

**Weaknesses.**

- *Configuration semantics are treacherous.* The unified/divided flip on how `-np` was supplied (Section 6.3), `--fit` silently resizing context, and per-slot numbers that are minima of three different quantities make capacity planning error-prone. The information exists, but it is spread across startup logs, README tables, and source.
- *No fairness or admission control in the allocator.* A unified pool is first-come-first-served; the allocator's only protections are structural (never steal shared or live cells). Multi-tenant use inherits whatever the slot layer does or does not do.
- *Features silently exclude each other.* Shrunk SWA caches disable shifting; shifting excludes M-RoPE and per-layer-RoPE models; chunk reuse requires shifting; quantised V requires flash attention. Each exclusion is individually reasonable, but they compose into capability cliffs that are only discoverable in source or by failure.
- *The RAM prompt cache's identity is tokens-only,* with FIFO eviction and destructive single-use restore (Section 5.3). As a session-displacement queue it is sensible; as anything resembling a general prefix cache it is both unsafe (configuration-blind) and weak (an entry serves one restore, and eviction ignores recency of use).
- *Accounting is structural, not operational.* Buffer totals at startup and reuse counts per request leave a gap: no per-sequence occupancy, no pool-pressure signal an autoscaler or a UI could consume.

## 9. Judgment: what the fork should steal, and what it should deliberately do differently

*This section is our judgment, labelled as such; everything above is description of the sources.*

**Steal:**

1. **The cell-with-sequence-bitset model** for shared prefixes and parallel sampling. For an Ollama-class fork whose common case is one user, a handful of concurrent requests, and heavy prefix overlap (system prompts, chat history), it delivers most of paged attention's sharing benefit at a fraction of the machinery.
2. **Transactional prepare/apply with a documented failure code.** Whatever allocator the fork builds, "reserve everything or change nothing, and say so in the API contract" should be copied verbatim as a principle.
3. **Non-contiguous placement plus row-list attention, instead of a defragmenter.** llama.cpp's deletion of defrag at v1.0.0 is evidence from the incumbent that compaction is the wrong place to spend complexity. Design allocation to tolerate holes from day one.
4. **K-shift as the continuation mechanism** — re-rotating stored keys is dramatically cheaper than re-evaluation, and the remove-plus-shift pair doubles as the engine for chunk reuse.
5. **Checkpoints for non-truncatable memories.** Any fork supporting SWA or recurrent models alongside prefix reuse needs exactly this escape hatch, including the "no checkpoint, full reprocess" honesty.
6. **The Hadamard rotation with quantised KV,** and the construction-time refusal of unsupported combinations (quantised V without flash attention) over runtime misbehaviour.

**Deliberately do differently:**

1. **Make pool-vs-per-slot an explicit, single decision in the sizing API.** Never let the meaning of a context-size setting depend on how a different setting was supplied. Report, per sequence, its ceiling and its current occupancy, in the API — not only in startup logs.
2. **Key every state cache on the full effective configuration** — tokens *plus* adapter set and scales, template/chat-format identity, and anything else that changes what the KV was computed under. llama.cpp's tokens-only entry (Section 5.3) is the cautionary tale; the fork should treat a cache hit under a different configuration as a correctness bug by construction, not by audit.
3. **Use recency-aware eviction and non-destructive restore in the RAM tier,** or drop the tier. FIFO plus single-use restore wastes the most valuable property of cached state — that popular prefixes recur.
4. **Decide the SWA/shift trade explicitly.** If the fork shrinks SWA caches, it should say in user-facing terms that continuation features are off for those models, or implement shifting for unequal sub-caches. Silent capability cliffs are how users lose trust in a runner.
5. **Add pool-pressure telemetry and optional per-sequence quotas** in unified mode, so one runaway generation cannot starve the rest of the pool without anyone seeing it happen.
6. **Publish a bytes-per-token table per KV type** (measured, per architecture family) as documentation. llama.cpp makes operators derive it from logs; the fork can simply tell them.

## 10. Sources and verification notes

All sources are from ggml-org/llama.cpp at tag **v1.0.0**, read **2026-11-15** (raw file views of the tag), except where marked secondary.

**Primary — library:**
- `include/llama.h` — context parameters (unified flag and its guidance, cache types), the renamed `llama_memory_*` verb family and its contracts, per-sequence state API including the extended flags, decode return-code semantics (return 1 = no KV slot for the batch).
- `src/llama-memory.h` — the memory interface the implementations share (via references from the cache sources).
- `src/llama-kv-cells.h` — cell metadata: position, extension record, pending shift, per-cell sequence bitset; used-set and per-sequence position indexes; row-slice structure for row-list attention; cell copy/restore shift assertions; the commented-out cell-move operation formerly used by defragmentation.
- `src/llama-kv-cache.h` — cache structure: per-layer K/V/scale/rotation tensors, streams and the sequence-to-stream map, ring-head array, slot-finding and prepare/apply API, memory breakdown.
- `src/llama-kv-cache.cpp` — constructor sizing and logging, ring search and its hole-filling heuristic, transactional prepare, apply invariants and the SWA purge interaction, shift graph construction, can-shift exclusions, Hadamard rotation setup, variable-V padding. (Searched for the defragmentation path: absent.)
- `src/llama-kv-cache-iswa.cpp` — the two-cache composite: layer filtering, SWA size formula and its 256-padding (issue #17037), full-size override, position queries answered from the SWA cache, summed breakdown, equal-size condition for shifting.
- `src/llama-context.cpp` — context-size derivation and 256-padding, divided per-sequence sizing in non-unified mode, quantised-V-requires-flash-attention refusal, aggregated memory breakdown.

**Primary — server and common:**
- `common/common.h` — defaults: f16/f16 cache types, prompt-similarity threshold 0.1, RAM cache default size.
- `tools/server/server-context.cpp` — slot state machine (diagram reference PR #9283), slot selection and LCP scoring, in-slot prefix reuse and the always-evaluate-one-token rule, shifted chunk reuse, checkpoint restore and forced reprocessing, parent/child handling, context-shift algorithm and its exclusions, exceed-context rejection.
- `tools/server/server-task.h` — task and slot types: `cache_prompt` default, `server_prompt` (tokens + checkpoints only), prompt-cache entry and cache structures and limits.
- `tools/server/server-task.cpp` — RAM prompt cache behaviour: containment dedup, supersede of prefix entries, FIFO eviction, over-limit skip, out-of-memory self-throttling to 40%, load scoring (25% keep floor, must win on both fractions), destructive restore.
- `tools/server/server.cpp` — parameter preparation: auto parallel mode (4 slots, unified on), per-slot context computation, `--kv-unified-per-slot` pool sizing.
- `tools/server/README.md` — documented flags and defaults: `-c`, `-ctk`/`-ctv` allowed values including f8_e4m3, `--swa-full`, `--cache-ram` (8192 MiB default), `--cache-idle-slots`, `--kv-unified-per-slot`, `--fit`/`--fit-ctx`, `--slot-save-path`.

**Primary — release record:**
- v1.0.0 release notes (GitHub, published 2026-11-13): version-bump commit `4cda622` / PR #32190; nightly b12359; removal of `defrag_thold`/`--defrag-thold` (PR #30565); FP8 KV caches (PR #28392); quantised-cache state-copy fix (PR #30541); reference-counted checkpoints (PR #30137); parent-before-child slot visitation (PR #30779).

**Secondary (corroboration only, not load-bearing):**
- DeepWiki's llama.cpp KV-cache pages and assorted web articles, used to cross-check terminology. One external article (dev.to) reporting tokens-only RAM-cache reuse across differing LoRA scales at build b11514, citing upstream issues #30129 and #26207 — flagged in Section 5.3 as a risk **not** re-verified at v1.0.0.

**Explicitly unverified in this dossier:**
- The internal eviction/search behaviour of any prompt-cache code beyond `server-task.cpp` as read above (the read covered the cache's own implementation; router-mode interactions were not read).
- Exact per-type KV block sizes and a closed-form bytes-per-token formula (ggml type traits not read).
- Whether the reported LoRA-scale stale-reuse behaviour persists at v1.0.0 (source structure suggests the identity gap remains; not demonstrated by execution).
- Exact JSON field sets of the `/slots` and `/props` endpoints for KV memory (route handlers not read).
- The `--fit` algorithm's detailed interaction with KV sizing (README-level behaviour only).
- Anything on master after the v1.0.0 tag, including nightly b12368 (2026-11-14).

*End of dossier — OR-2, read and written 2026-11-15.*
