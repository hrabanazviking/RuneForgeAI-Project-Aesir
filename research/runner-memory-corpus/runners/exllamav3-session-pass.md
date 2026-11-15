# ExLlamaV3 — Session / Prefix Source-Structure Pass (Addendum to OR-2 Successor Volume)

**Addendum to:** `exllamav3.md` (OR-2 successor volume, banked 2026-11-15), keyed to its §10 unverified list and §4.5.
**Date:** 2026-11-15.
**Question set:** the six questions the V3 dossier left open on cross-job prefix deduplication and session semantics.
**Method:** structure-only reading of the public source — file layout, class and function inventories, parameter surfaces, and the behavioural descriptions the author placed in module and method documentation — plus public commit titles/dates for the release in question, and TabbyAPI's public documentation and backend structure where it exposes engine behaviour. No source text is reproduced; everything below is paraphrased behaviour, structure, and semantics in this pass's own words. No code, no snippets.
**Clean-room status:** clean. Design transfers, if any are taken, must be re-implemented from the behavioural descriptions here.

## Version stamp — what was actually read

- **ExLlamaV3:** `master`/`dev` head at commit `8c593e4` dated 2026-11-13, whose subject is the bump to **v1.6.7**; the package version file likewise reads 1.6.7. Tags v1.6.4, v1.6.5 and v1.6.6 were present in the same history and were used only to bound which changes landed in which release. This is one minor release ahead of the v1.6.6 the parent dossier verified as latest; nothing in the generator/cache structure read here depends on that difference, and where a claim is release-specific (Question 5) it is pinned to the v1.6.4 → v1.6.5 range explicitly.
- **Modules read at inventory level, in full where noted:** the generator package (the main generator, the job object, the page table, the asynchronous wrapper, the CPU page tier, the disk page tier, the sampler package), the cache package (the cache facade and the recurrent-state cache), the tokenizer module (encoding-path inventory only), and the constants module.
- **TabbyAPI:** head at commit `4728158` dated 2026-11-14; its server-options documentation and its ExLlamaV3 backend's generator-construction site were read for the user-facing exposure of the tiers in Question 2.
- **Not done:** no build, no run, no benchmark, no line-by-line audit of kernel code. Performance effects are therefore never asserted; only structure and stated behaviour are.

## Verdict summary, keyed to the parent dossier's §10

| Parent §10 item | This pass | Grade |
|---|---|---|
| Cross-job page-level deduplication across concurrent jobs | **Closed — yes, it exists, and it is stronger than V2's documented version** (Q1) | Verified-from-structure |
| Retention of a finished job's pages for reuse | **Closed — retained indefinitely until eviction; three tiers** (Q2) | Verified-from-structure |
| Cache page size | **Closed — fixed at 256 tokens, as in V2** (Q3) | Verified-from-structure |
| Defragmentation policy | **Closed — a real physical compaction exists, with explicit gates** (Q3) | Verified-from-structure |
| Job / sampler object shape; session semantics | **Closed — per-request job, no engine session object** (Q4) | Verified-from-structure |
| Mechanism of the v1.6.5 prompt-caching fix (§4.5's only proof caching exists) | **Closed at the behavioural level** (Q5) | Verified-from-structure + release history |
| Checkpoint / resume of a job's state (not a §10 item; added by this pass's brief) | **Narrowed — three partial mechanisms, no whole-job suspend** (Q6) | Verified-from-structure |

**Headline correction to the parent dossier:** §4.5/§8 called the missing dynamic-generator document "the single largest documentation regression relative to V2" and warned "do not assume parity." The structure read reverses the risk direction: **the machinery not only survived the rewrite, it grew** — a chained-hash prefix tree in VRAM, an optional pinned-memory second tier, an optional persistent disk third tier, and a separate recurrent-checkpoint cache for hybrid models, none of which V2's document described. What regressed is only the prose. A fork design may assume V2-style deduplication parity with V3, and should in fact study V3's tiering as the more advanced reference.

---

## Q1. Does V3 deduplicate KV pages across concurrent jobs on shared prefixes? By what key?

**Status: CLOSED. Evidence grade: verified-from-structure.**

Yes — deduplication is the page table's central design, not an optimisation bolted onto it.

**The key is content, chained.** Each complete page of 256 tokens is identified by a 128-bit hash digest computed over that page's token identifiers chained on the previous page's hash. A page's identifier therefore names its entire prefix, not just its own tokens: two sequences share a page exactly when they share every token up to the end of that page, and diverge from the first page where their tokens differ. Job lineage, conversation identity, and arrival order play no part in the key. The design treats a hash collision as impossible in practice and, on that stated assumption, does not re-check full token contents on a lookup.

**Only complete pages are shareable.** A page acquires its content hash only once all 256 of its token slots hold final key/value data. A partially filled tail page carries a placeholder random identifier instead; it becomes shareable at the moment it completes — including pages that complete during generation, not only during prefill (see Q5).

**How a new job claims pages.** At enqueue time the job pre-computes the chained hash of every complete page of its prompt. At start time, allocation walks those hashes in order and resolves each one through four sources, in this order:

1. **A page still referenced by another live job** — the new job simply takes an additional reference to the same physical page. This is the concurrent case the question asks about: two active jobs over one shared document hold the *same* physical pages for their common prefix, each with its own block-table entry pointing at them, and pay prefill and memory only for their divergent tails.
2. **An unreferenced page still resident in VRAM** — the finished-job case of Q2; the reference count rises from zero and the page is revived in place.
3. **The optional system-memory tier, or the disk tier behind it** — the page image is copied back into a freshly claimed VRAM page instead of being recomputed.
4. **No source** — a page is taken from the eviction pool (Q2) and the tokens are prefilled normally.

The job's own prompt hashes are protected during its allocation, so serving its early misses cannot evict the later pages it is about to hit.

**Sharing is read-only in effect, without a copy-on-write copy.** Shared pages are by construction complete; a job never writes into them. Everything a job writes — its uncached prompt remainder and all generated tokens — goes into freshly claimed pages that start with a unique placeholder identity and only earn a content hash when they fill. There is therefore no moment at which one job can mutate another job's prefix. Deduplication also runs in the other direction at completion time: when a job's page fills and its new hash turns out to already exist as a referenced page, the job drops its own copy and re-points at the existing page; if the duplicate exists only as an unreferenced page, that stale copy is cleared instead.

**Two qualifications, both structural:**

- *Hybrid/recurrent models:* a cached KV prefix is only resumable up to the longest prefix that also has a matching recurrent-state checkpoint (Q6). KV pages past that point may still be counted as cached, but the resume point rolls back to the checkpoint and the replay prefill rewrites them. On such models the effective deduplication boundary is the checkpoint boundary, not the KV boundary.
- *Multimodal prompts:* pages from the first page containing a multimodal placeholder identifier onward are marked non-persistable, because those identifiers are allocated per process. They still deduplicate within the process exactly as above; they are simply never written to the disk tier.

**Fork consequence:** the key design is directly transferable as behaviour — chain the hash, share only complete pages, protect the claimant's own hashes during allocation — and it needs no session concept to work (Q4).

---

## Q2. Are a finished job's pages retained for reuse, and under what eviction policy?

**Status: CLOSED. Evidence grade: verified-from-structure (engine tiers); TabbyAPI exposure verified from its public docs.**

Yes. Finishing is deliberately cheap: when a job ends, is cancelled, or fails, it releases its recurrent state and drops its reference on each of its pages — and nothing else happens to the pages. A complete page whose reference count falls to zero stays exactly where it is, indexed by its content hash in the unreferenced set, fully reusable by any later job whose prompt hashes match (Q1, source 2). There is **no time-to-live, no per-conversation expiry, and no finish-time flush**. Retention ends only when a page is chosen for reuse by a new allocation, or is moved by defragmentation (Q3).

**GPU-tier eviction policy (the default "tree" policy).** When an allocation needs pages, candidates are ordered least-valuable first:

1. Empty pages (no valid tokens), oldest first.
2. Orphaned chains — pages whose parent hash no longer resolves, so no prefix walk from a root can ever reach them as a usable prefix.
3. Intact cached trees, taken one tree at a time, least-recently-used root first — where a tree's recency is its root's last-access order, refreshed whenever any job reuses the prefix.

Within a tree, pages are pruned **leaf-first (tail-first)**: a cached sequence is eaten from its end, so the longest possible prefix survives partial eviction. The structure documentation contrasts this explicitly with the older page-at-a-time least-recently-used policy (retained in the code as a selectable legacy alternative), under which taking the root first destroyed the whole chain's reusability. A referenced or allocation-protected page blocks eviction of its ancestors, since evicting an ancestor would orphan a chain still in use.

**The second tier (system memory), when enabled.** Eviction from VRAM is not destruction if the optional pinned-memory tier is configured: at the moment a complete hashed page is repurposed, its full per-layer image (main cache and, where present, draft cache together, so a restored page stays valid for speculative decoding) is copied into a fixed-size slot in pinned host memory, keyed by the same chained hash. Duplicate pushes merely refresh recency. The tier's own eviction mirrors the GPU policy — orphaned chains first, then whole trees, least-recent root first, tail-first — with slots that have a transfer in flight passed over. This tier is off by default in the engine (size zero); TabbyAPI exposes it as a megabyte-sized server option.

**The third tier (disk), when enabled behind the second.** Pages entering the system-memory tier are written through to a per-model directory on disk, and recurrent checkpoints are written through the same way, so cached contexts survive a model reload and a server restart. A page found only on disk is promoted back into a system-memory slot (prefetched at enqueue time, so the allocation usually finds it already in flight) and then restored as any other tier hit. The disk budget is a single byte budget for the whole directory, shared across models and configurations, enforced least-recently-used-first. TabbyAPI exposes the directory, its size budget, an idle-flush switch, and a checkpoint-spacing option; it requires the system-memory tier to be on, and requires engine 1.6.2 or later.

**Idle behaviour.** When the job queue drains, the generator additionally flushes complete VRAM pages and checkpoints toward the disk tier (so a context does not have to be evicted first to be persisted), prunes recurrent checkpoints whose anchoring KV chain has been broken, and defragments (Q3). While jobs run, a periodic write-behind queues active sequences' complete pages for the disk tier as well, holding back the last couple of pages that speculative decoding could still rewind.

**What is *not* retained:** the job object itself, its sampler, and its output position are gone at finish (Q4). What persists is purely content — pages and, for hybrid models, checkpoints — addressed by hash. A "returning conversation" is a new job that happens to hash-match.

---

## Q3. What is the cache page/block size, and is there defragmentation or compaction?

**Status: CLOSED. Evidence grade: verified-from-structure.**

**Page size: a fixed 256 tokens.** It is a single named constant for the whole generator, not a configuration option, and the rest of the system is denominated in it: total cache capacity is the cache's token budget divided by 256; prefill chunk sizes, requeue budgets, and recurrent-checkpoint intervals are all required to be multiples of it. This is the same size V2's document specified, so the parent dossier's cautious inference from TabbyAPI's sample configurations (multiples of 256) can now be upgraded to verified.

**Defragmentation: yes — a real physical compaction, more ambitious than V2's.** V2's documented policy was conservative housekeeping over unreferenced pages when the queue was empty. V3 keeps those preconditions and adds an actual reordering:

- It runs only when no job holds any page reference (queue drained, or the last job cancelled), and only after a substantial amount of allocation activity has passed since the previous run (the gate is expressed as a multiple of the total page count), and it can be switched off entirely by a generator flag that defaults to on.
- It reconstructs the forest of cached chains from the parent-hash links, keeps for each tree its longest chain as the trunk (demoting side branches to new roots), and lays the surviving chains out as long contiguous runs of physical pages, with orphaned pages moved to the end ordered by last access.
- If that layout would move only a small fraction of the cache (a tenth or less), it does nothing. Otherwise it physically rotates the page images to their new slots — across every cache sharing the page table, main and draft together, with a tensor-parallel-aware dispatch where the model is so loaded — choosing a global rotation offset that minimises the number of copies.
- The benefit is structural, not measured here: subsequent allocations and prefix walks see long sequential runs instead of scattered pages (allocation itself tracks how many of a job's pages came out non-sequential, which is the fragmentation signal this pass exists to reduce).

**Compaction in the TokenSpeed sense — gathering one live request's scattered blocks to free whole parents — has no analogue**, because V3's pages are uniform and independently referenceable; there is no larger parent block for a page to be gathered out of. Fragmentation waste is bounded by the familiar tail effect: at most the unused tail of each live sequence's last, incomplete page.

---

## Q4. What does the job/session object hold? Is there a session layer?

**Status: CLOSED. Evidence grade: verified-from-structure.**

**There is no session object in the engine.** A search of the generator and cache packages finds no session type at all; the word survives only in unrelated senses (a disk tier going read-only "for the rest of the session" after a write failure). Everything conversational is rebuilt per request and recovered through the content cache (Q1/Q2). The two places a session *does* appear confirm the layering by their location: the shipped console-chat example keeps the conversation itself — a plain list of user/assistant text pairs, plus the system prompt — in the *caller*, re-renders and re-tokenizes the whole conversation on every turn, trims it from the head when it outgrows the cache, and saves/loads it as a small text file holding no key/value data at all; and a separate branching-decode example builds its own session wrapper *on top of* the engine. TabbyAPI follows the same shape: one fresh job per HTTP request.

**What a Job holds** (one job = exactly one sequence; batching is many jobs, not many sequences in a job):

- *Identity and scheduling:* a generator-assigned serial number (kept across internal requeues, so one logical stream keeps one serial), a caller-supplied opaque identifier echoed with every result event, queue bookkeeping (skip count and a fairness cap on how often smaller jobs may overtake it), and enqueue/prefill/first-token timing accumulators.
- *The sequence:* the prompt token identifiers and the growing full sequence (prompt plus everything generated), held in a growable sequence container; the pre-computed chained page hashes of the prompt; and, once started, the list of allocated page objects and the block-index structure built from them, together with how many leading pages were cache hits and the current key/value position.
- *Sampling state:* a reference to one sampler object (below); the job's own random generator, seeded from the job's seed argument (with the documented caveat that determinism is not guaranteed); the buffer of past token identifiers that history-dependent sampler steps require, staged through pinned memory; stop tokens and stop strings with the machinery to hold back output that might be the start of a stop string; banned-string state, including a checkpoint mechanism that can rewind the sequence if a banned string completes; constrained-output filters, each with its own per-job state; a forced-token queue for caller-injected output; token-healing state; and a repetition-loop detector.
- *Generation budgets:* maximum/minimum new-token counts, and a requeue budget (Q6) — a per-segment token allowance aligned to a page or checkpoint boundary, with headroom reserved for the speculative window.
- *Speculative state:* draft-acceptance counters, an optional per-round draft-statistics log, the suffix-automaton state used by n-gram and hybrid drafting, and any carried hidden state the multi-token-prediction drafter needs between chunks.
- *Recurrent state (hybrid models only):* a handle to the job's live recurrent state (a paired target/draft state where a recurrent drafter exists), the position of its last stashed checkpoint, and a private rolling checkpoint (Q6).
- *Multimodal state:* the list of input embeddings and any precomputed rotary-position material they imply.
- *Held output:* text and token/probability/logit buffers for output not yet safe to stream (because a stop or banned string might still resolve against it).

**What the sampler object is.** The base type is a minimal forward interface. The concrete sampler is a *composable pipeline*: an ordered list of steps — temperature, normalisation, sorting, top-k, top-p, min-p, adaptive-p, token banning, logit bias, repetition/presence/frequency penalties, a DRY-style repetition step, an XTC step, and sampling/argmax terminals — each step declaring whether it needs past identifiers or a device-side seed, with eligible suffixes of the pipeline collapsed into a fused implementation at use time (the parent dossier's §4.6 finding, now confirmed as the pipeline's normal mode rather than a special case). Named presets assemble the common pipelines. A sampler instance may be shared across jobs or set per job, and can be swapped on a live job through both the synchronous and asynchronous job wrappers; the *history-dependent* state (past identifiers, penalty counts) lives on the job, not in the sampler, which is what makes sharing safe.

**The Generator's own holdings**, for completeness: the pending and active job lists, the page table, the optional two cache tiers, the recurrent-checkpoint cache, and the draft model/cache pair. The asynchronous wrapper adds per-job result queues and callbacks around the same job type; it adds no session concept either.

**Verdict in one line:** per-request like V2, with a substantially richer per-job state bundle — and "session" deliberately emergent: re-submit the text, let the hashes do the remembering.

---

## Q5. How does the v1.6.5 prompt-caching fix work at the behavioural level?

**Status: CLOSED at the behavioural level. Evidence grade: verified-from-structure for the caching mechanism; verified from release history (commit titles and tag ranges) for what changed in 1.6.4 and 1.6.5.**

**What is cached, keyed how, invalidated when** — the general mechanism, of which the bug is a special case:

- *Cached:* the key/value contents of complete 256-token pages (Q1), plus recurrent checkpoints keyed to the same page identities on hybrid models (Q6).
- *Keyed:* solely by the chained hash of the page's **token identifiers** (Q1). The cache never sees text. Anything that changes the identifier sequence for the same text changes every hash from the first differing page onward, and the chain property means one early difference invalidates the whole suffix, not just one page.
- *Invalidated:* by eviction (Q2), by a hash change as just described, and — for the disk tier only — by identity: the disk directory is partitioned by a fingerprint covering the model (including sampled weight contents, so a requantization at the same bitrate still separates), the cache configuration and per-layer cache bit-widths, the page size, the on-disk format version, and the engine version. A different fingerprint is simply a different directory; stale pages are never served under a new identity.

**The regression, behaviourally.** The 1.6.4 line introduced a faster long-input encoding path: a long text is split into chunks at newline runs and the chunks are encoded as one parallel batch, on the assumption that chunked encoding yields exactly the identifiers that whole-text encoding would. Prompt caching is exquisitely sensitive to that assumption, because a conversational prompt *grows*: the prefix encoded one way in an earlier turn (or in an earlier, shorter request) must produce bit-identical identifiers when the longer text is encoded again, or the page hashes miss and the cached prefix is silently useless. Two boundary cases broke the identity, and the 1.6.5 range contains one fix for each, per its commit history:

1. *A cut inside a multi-character line-ending token.* A blank line written with carriage-return/line-feed pairs can be a single token to some tokenizers; splitting the text in the middle of that run made the chunked encoding tokenize the boundary differently from the whole text. The fix makes a split consume the complete run of carriage returns and line feeds, so a cut can never fall inside it.
2. *The correctness probe disturbing special-token handling.* Before first use, the chunked path probes whether the backend tokenizer encodes chunk-wise identically, by flipping its special-token mode, encoding a probe string both ways, and comparing. The probe originally failed to restore the mode it found, so a subsequent real encoding could treat special-token strings differently from an earlier one — again, same text, different identifiers, missed cache. The fix preserves the pre-existing mode across the probe.

Both failures share the signature in the release note — caching "fails sometimes": only long inputs take the chunked path at all (there is a character threshold in the tens of thousands), and among those, only inputs whose chunk boundaries or special tokens trip one of the two cases. Short prompts, and long prompts without those features, cached correctly throughout. Nothing in the cache itself was broken in either release; the cache faithfully keyed whatever identifiers it was given, and the fix restores the invariant it depends on: **tokenization of a given text must be a pure function of the text, independent of length, chunking, and call history.** That invariant — not any cache data structure — is the stealable lesson, and it applies to any fork that ever parallelises or streams its tokenizer.

---

## Q6. Is there checkpoint/resume of a job's state?

**Status: NARROWED — three real mechanisms, none of them a whole-job suspend. Evidence grade: verified-from-structure.**

V3 has no operation that captures a live job wholesale. What it has instead are three narrower mechanisms that together cover most of the practical ground:

1. **Requeue (intra-job segmentation).** A job carries a per-segment token budget; when a segment is exhausted the job re-initialises *itself* as a freshly queued job whose prompt is the entire sequence generated so far, carrying over its random generator, sampler, filters and their state, held output buffers, timing and draft counters, loop detector, and suffix-automaton state, under its original serial number. This is how one job can use the whole cache without monopolising it, and how a segment boundary is guaranteed to land on a page or checkpoint boundary so the next segment resumes with nothing to replay. It is continuation by re-submission, executed inside the engine.
2. **Recurrent-state checkpoints (hybrid models).** Because a recurrent state summarises its whole prefix and cannot be sliced like KV pages, the engine stashes copies of it at page boundaries, spaced by a checkpoint interval — a coarse spacing during prompt ingestion (tens of thousands of tokens; TabbyAPI documents 32,768 as the engine default it exposes) and a finer one near and past the prompt's end. Each stash is stored under the content hash of the page at its boundary, in a size-bounded (4 GB by default), least-recently-used system-memory cache of checkpoints, written through to the disk tier when that is enabled. A later job whose KV prefix matches restores the stash for its longest matching checkpoint and replays only the remainder. Checkpoints whose anchoring KV chain has been evicted are recognised as stranded and are evicted first, and pruned outright when the queue drains. Separately, a job whose state type cannot roll back in place keeps a private *rolling* checkpoint, refreshed at every page boundary outside the shared cache, which is committed under the final page's hash when the job ends — so a follow-up prompt extending the job's output replays less than one page.
3. **The persistent tiers as cross-process resume.** Because pages and checkpoints reach disk under a fingerprinted identity (Q5), a *new process* with the same model and cache configuration resumes prompts exactly as a later job in the same process would. This is the closest V3 comes to surviving a restart, and it is a property of the cache, not of any job.

**Comparison with TokenSpeed's suspend-by-image** (per the banked `tokenspeed.md` dossier): TokenSpeed, under cache pressure, images a *live, unfinished* request byte-for-byte to a private, unevictable host snapshot — published prefix pages become ordinary shared cache entries, everything else (unpublished state, sampling state, speculative readiness) goes to the request-private pool — frees its device pages for the specific blocked admission that triggered the eviction, and later restores the request to the exact position it left, with no recomputation; only if no victim's image fits does it abort instead. V3 has no equivalent: it never preempts a live job for capacity at all (admission simply waits, with the skip/fairness rule of Q4), its only mid-life transformation is the cooperative requeue above, and everything it retains after a job ends is content-addressed and evictable — so a returning conversation whose pages or checkpoint were evicted in the interim pays a replay prefill from the last surviving boundary, where TokenSpeed's retracted request pays only a copy back. The trade is symmetric: V3 needs no snapshot pool, no abort path, and no per-request private storage, and its retained state is useful to *every* later job rather than only to its owner — at the price of recompute-on-eviction where TokenSpeed guarantees restore.

---

## What remains open after this pass

- **Nothing in the six questions is left at the parent dossier's level of uncertainty.** The residuals are one level down: (a) deduplication and tier behaviour *under tensor parallelism* are structural certainties (the tiers and the defragmenter both carry explicit tensor-parallel dispatch paths) but were not exercised, and per-rank divergence behaviour is unverified; (b) the *performance* value of defragmentation's contiguity, and of tier restores versus prefill, is asserted nowhere here and should not be quoted without measurement; (c) the hash-collision assumption is the author's stated design position, not an independently verified property; (d) TabbyAPI's exposure of the engine tiers was verified from its current documentation and backend structure, but individual option defaults can drift between its rolling releases.
- The parent dossier's other §10 items (EXL2/GPTQ loadability, LoRA status, the in-repo format writeup, per-K/per-V cache-mode split at engine level, the QTIP licence point) were **outside this pass's brief and are untouched** — they stand exactly as the parent dossier left them.

## Single most consequential answer, for the fork

**Q1 with Q2: cross-job deduplication and finished-job retention are not merely present in V3 — they are the organising principle of its generator, and they are content-addressed end to end.** One chained hash per 256-token page simultaneously names a prefix, keys the VRAM sharing among concurrent jobs, keys the retention of finished jobs' pages, keys both spill tiers, and keys the recurrent checkpoints that make hybrid models resumable. A fork that adopts that single decision — *the prefix hash is the only identity state ever needs* — gets deduplication, prompt caching, multi-turn reuse, branching, and restart survival as corollaries, with no session layer to design, store, or invalidate. V2's document described the first two corollaries; V3's structure proves the design scales to all five.

*End of addendum. Clean-room note: written from the public structure listed in the version stamp, in this pass's own words; no source text reproduced beyond short factual labels (names, version numbers, and the 256-token page size), and no code included.*
