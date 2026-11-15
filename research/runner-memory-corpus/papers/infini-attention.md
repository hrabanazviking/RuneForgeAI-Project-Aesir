# Infini-attention — Leave No Context Behind: Efficient Infinite Context Transformers with Infini-attention

## 1. Full citation

- **Title:** Leave No Context Behind: Efficient Infinite Context Transformers with Infini-attention
- **Authors:** Tsendsuren Munkhdalai, Manaal Faruqui, and Siddharth Gopal — Google (corresponding affiliation as given in the paper; Munkhdalai email tsendsuren@google.com)
- **Venue / year:** arXiv preprint, 2024. No peer-reviewed venue is recorded on the arXiv record and none is claimed here.
- **arXiv:** arXiv:2404.07143 [cs.CL] — v1 submitted 10 April 2024; v2 revised 9 August 2024 (v2 adds background, implementation details, recent citations and acknowledgements; 9 pages, 4 figures, 4 tables). DOI 10.48550/arXiv.2404.07143. https://arxiv.org/abs/2404.07143
- **Verification note (2026-11-15):** the coordinator's identifiers checked out exactly — title, authorship (Munkhdalai et al., Google), year, and arXiv number are all correct as briefed. The full text read for this dossier is the arXiv HTML v2.

## 2. The problem as framed

The paper starts from the Transformer's structural bind, stated in its introduction in cost terms: attention is quadratic in sequence length in both memory footprint and compute time, and the KV states alone are given as a 3 TB footprint for a 500B model at batch 512 and context 2,048 (citing Pope et al.). Scaling to 1M-token inputs on the standard architecture is therefore not a matter of patience but of a memory term that grows with the very thing being scaled.

The prior answers each give something up, and the paper's Table 1 / §3.2 comparison is the cleanest statement of the trade space:

- **Full attention / growing KV caches** keep the past exactly and addressably, at unbounded cost.
- **Segment-recurrence models (Transformer-XL, Compressive Transformer)** bound the cache by discarding or coarsely compressing old segments — the past beyond the cache is simply gone.
- **Retrieval-over-KV models (Memorizing Transformers)** keep the entire KV history and retrieve by kNN — exact, but storage grows with length and, in the cited design, is confined to a single layer for cost.
- **Summary-vector models (RMT, AutoCompressors)** compress each segment into soft-prompt vectors passed forward — potentially unbounded input, but quality depends on growing the number of summary vectors, so cost creeps back, and an efficient compression objective is itself an open problem in that line.
- **Classical recurrent state** is fixed-size and cheap, but — the background section's point, via RNNs and the authors' own Meta-learned Neural Memory (MNM, 2019) — squeezing an entire history into one fixed vector loses information in ways the model does not control.

What the paper wants, in its own framing, is a **compressive memory** in the older sense (Kanerva; Munkhdalai et al. 2019): a fixed number of parameters whose values are *changed* to store new information under an objective that the information can be recovered later — bounded storage and computation, no discarding step, and no separate retrieval store — that is also *practical* inside a modern LLM: minimal change to the standard attention block, reusable Q/K/V states, and plug-and-play continual pre-training of existing models. The selection of what survives compression is not heuristic in this design; it is whatever the learned projections and the associative update preserve under the language-modelling objective — which is precisely the property §5 below prices.

## 3. Core mechanism in our own words

### 3.1 Segmented processing with a recurrent attention layer

Like Transformer-XL, the model (the **Infini-Transformer**) processes input as a sequence of segments $X_s$, each of length $N$ (2,048 in the language-modelling experiments). Within a segment, ordinary masked causal dot-product attention runs as usual — this is the **local attention**, exact and fine-grained over the current segment. The departure is what happens at the segment boundary: where Transformer-XL discards all but a cached slice of the old KV states, Infini-attention **folds the segment's KV states into a compressive memory** and carries only that memory forward. Each attention layer thus maintains, per head ($H$ heads in parallel), a recurrent state

$$O_s, M_s = \text{infini-attention}(X_s, M_{s-1})$$

— a global compressive state alongside the local state, in every layer, not in one designated memory layer.

### 3.2 The compressive memory: an associative matrix read and written as linear attention

The memory is parameterised, per head, as an associative matrix $M_{s} \in \mathbb{R}^{d_{key} \times d_{value}}$ plus a normalisation vector $z_s \in \mathbb{R}^{d_{key}}$. No new Q/K/V projections are introduced: the memory **reuses the Q, K, V states already computed for dot-product attention**, which is what makes the mechanism a near-drop-in modification and cheap to continual-pre-train.

- **Retrieval (linear attention).** Before the update, the current segment's queries read the memory accumulated from all previous segments:

$$A_{mem} = \frac{\sigma(Q)\,M_{s-1}}{\sigma(Q)\,z_{s-1}}$$

with $\sigma$ = element-wise ELU+1 (following Katharopoulos et al.'s linear-attention formulation) and $z_{s-1}$ the running sum of transformed keys, acting as the normaliser. Reading is a matrix product, not a search: every past segment has been superimposed into the same matrix, and the query extracts a blend weighted by key similarity in the transformed space.

- **Update (associative binding).** After retrieval, the segment's own KV pairs are bound into the memory:

$$M_s \leftarrow M_{s-1} + \sigma(K)^{T} V, \qquad z_s \leftarrow z_{s-1} + \sum_t \sigma(K_t)$$

Each key–value pair adds an outer product; storage is superposition — many bindings share the same $d_{key} \times d_{value}$ numbers, which is the source of both the compression and the interference discussed in §5.

- **Delta-rule variant.** The paper also incorporates the delta rule (after Munkhdalai et al. 2019; Schlag et al.): first retrieve what the memory currently returns for these keys, and bind only the *residual*:

$$M_s \leftarrow M_{s-1} + \sigma(K)^{T}\!\left(V - \frac{\sigma(K)M_{s-1}}{\sigma(K)z_{s-1}}\right)$$

If the binding already exists, the memory is left (near-)unmodified; if the same key now carries a different value, the update corrects toward the new value rather than adding a second competing copy on top. This is the closest either paper in this wave comes to an in-architecture *correction* operation — note carefully what it is: a same-key overwrite driven by the stream itself, not an addressed invalidation of a named fact (see §5).

- **Gating between memory and local attention.** The two contexts are combined by a single learned scalar per head:

$$A = \text{sigmoid}(\beta) \odot A_{mem} + (1-\text{sigmoid}(\beta)) \odot A_{dot}$$

One extra parameter per head buys a learnable long-term/local trade-off. The paper's gating visualisation (Fig. 3) reports that heads specialise after training — gating scores near 0 (local) or 1 (memory) — alongside *mixer* heads near 0.5, with at least one short-range head per layer.

Two implementation details matter for interpretation: position embeddings are **not** applied to the K/Q used for the memory (the memory stores global content, not positions), and training back-propagates through time across segments with gradient checkpointing.

### 3.3 What "infinite" means, precisely

"Infinite" in this paper is a statement about the **input stream**, not about recall capacity. The memory footprint is constant in sequence length — $d_{key} \times (d_{value}+1) \times H \times l$ for the whole model — and per-segment compute is constant, so a stream of $S$ segments (effective context $N \times S$) can be processed for arbitrarily large $S$ with bounded memory and computation, in streaming fashion. Nothing in the construction makes the *information* retained unbounded: a fixed-size matrix into which ever more bindings are superimposed must, by counting alone, lose distinctions as $S$ grows. The honest paraphrase the corpus should use is: **unbounded input length at bounded cost, with compressive — hence lossy and interference-prone — recall of everything before the current segment.** The paper's own results (§4) show how far that lossy recall goes on its chosen probes; they do not repeal the counting argument, and the passkey result in particular should be read as "a single salient binding can survive superposition at 1M length under fine-tuning for that task," not as exact 1M-token recall.

## 4. Reported results — as reported, with context

All figures are the paper's own, from the v2 text and tables. **Scale caution, stated plainly as the brief requires: these are small research demonstrations by datacenter standards** — a from-scratch model of 12 layers / 8 heads, and continual-pre-training adaptations of 1B and 8B LLMs. No frontier-scale training, no serving benchmark, and no independent replication is reported in the paper.

- **Long-context language modelling (from scratch; PG19 and arXiv-math).** Segment length 2,048, training sequence length 32,768 (16 memory unroll steps). Infini-Transformer (Linear) reaches perplexity **9.65 on PG19 and 2.24 on arXiv-math**, against Memorizing Transformers at 11.37 / 2.26 and Transformer-XL at 11.88 / 2.42 — while using **1.6M memory parameters against Memorizing Transformers' 183M, the paper's 114× compression ratio** (the baseline's memory is a 65K-length KV retrieval store at its 9th layer). Linear+Delta is essentially tied (9.67 / 2.23). Training at 100K length improves arXiv-math perplexity further, to 2.21 (Linear) / 2.20 (Linear+Delta).
- **Passkey retrieval to 1M (1B LLM, continual pre-training).** A 1B model's attention is replaced with Infini-attention, continually pre-trained at 4K length (30K steps, batch 64), then fine-tuned on the passkey task with **only 5K-length inputs for 400 steps**. As reported in Table 3, zero-shot retrieval at 32K–1M is poor (single digits to ~14% token accuracy by position), but after that fine-tuning both variants solve the task at up to **1M context**: Linear+Delta reports 100/100/100 (start/middle/end) at most lengths and 100/100/100 at 1M; Linear reports 96/94/100 at 1M. The contrast the paper draws: a prior 8B LLaMA result solved passkey to 32K when fine-tuned at 32K; here a 1B model generalises from 5K fine-tuning to 1M test length.
- **Book summarisation to 500K (8B LLM, BookSum).** An 8B model continually pre-trained at 8K length (30K steps), fine-tuned at 32K, evaluated at up to **500K** input length. Infini-Transformer (Linear+Delta) reports ROUGE-1/2/L **40.0 / 8.8 / 17.9, overall 18.5**, against the strongest cited baseline (PRIMERA + Unlimiformer) at 37.9 / 8.2 / 16.3, overall 17.2 — claimed in the paper as a new state of the art on the task, with overall ROUGE improving as more of each book is provided (Fig. 4).
- **What is not reported:** no latency/throughput serving numbers, no ablation of recall as a function of the *number* of distinct facts stored (the interference curve that §3.3 predicts), no multi-fact needle suite of the RULER/BABILong kind, and no released checkpoint is named in the paper. The evidence supports the efficiency claim (bounded state, better perplexity per memory byte) strongly and the "solves 1M retrieval" claim narrowly, for one fine-tuned synthetic probe.

## 5. Position vs the corpus's memory doctrine

*[Corpus synthesis — this section is the corpus's judgement, not the paper's.]*

The corpus's agent-memory standard (`memory/agent-memory-architectures.md`) demands, of any memory that holds **facts about a person**: explicit records that can be inspected; addressable entries that can be pinned (the character anchor), corrected, and superseded; bi-temporal validity (when a fact was true, and when the system learned/superseded it); tombstones consulted at read time so a corrected fact cannot be resurrected; and an audit trail of who/what changed a record and why. IDEA-LEDGER #47 compresses the existence half of that standard into one law: decay may appear in the **sort key**, never in the **delete key** — what exists is decided by invalidation and witnessed acts, not by a ranking score or a fading curve.

Infini-attention's memory fails every clause of that standard, not by sloppiness but **by construction**:

- **Not inspectable.** The memory is a superimposed matrix of outer products. There is no operation that lists what it contains; a binding can only be probed by presenting a query and reading a blend.
- **Not addressable.** There are no entries. One cannot point at "the record that says X" because X was never stored as a record — it was added, as a rank-one update, into numbers shared with everything else.
- **Not invalidatable.** The delta rule overwrites a binding only when the stream happens to present the same key with a new value. A user saying "that is wrong, forget it" has no key to present and no delete operation to invoke; a correction stated in different words binds under a different key and *competes* with the original rather than superseding it. Interference, not invalidation, decides which wins.
- **Not auditable or bi-temporal.** The matrix carries no timestamps, no provenance, no validity interval. Its current state is a function of the whole stream's order and content, with no log from which that function could be replayed selectively.

That is not a condemnation — it is a **boundary**, and stating it precisely is this dossier's main job:

> **Learned compressive memory is a capability substrate — gist, style, skills, the statistical shape of a long document — not a record substrate for facts, commitments, and identity anchors; the moment a fact about a person must be correctable, the memory that holds it must be an explicit record, because a superimposed matrix can be overwritten by accident but can never be corrected on purpose.**

Confusing the two substrates is the failure mode the doctrine exists to prevent: an agent whose "memory" of the user lives inside such a matrix cannot be shown its false memory, cannot delete it on request, and cannot prove it is gone. Infini-attention inside its proper domain — carrying a 500K book's gist into a summary, holding a long stream's statistics cheaply — does none of that harm, because nothing in that domain is a commitment.

## 6. Applicability

### (a) Runners

- **Not servable today in a ggml-class stack, and not a feature gap.** Infini-attention changes the attention operator itself: per-layer recurrent memory state ($M$, $z$) carried across segments, linear-attention retrieval interleaved with dot-product attention, and a learned per-head gate. A GGUF checkpoint of an Infini-Transformer would require the runner to implement a new architecture class — state snapshot/restore semantics for the compressive memory (a bounded blob per layer per head, cf. the SSM-state discussion in `papers/mamba.md` §6), segment-boundary update ordering, and BPTT-shaped training provenance the runner cannot verify. This is the corpus's **detect-and-honour** class again (as with SSM/hybrid architectures in Wave 8): if checkpoints ever ship, the runner's duty is to detect the architecture, implement or refuse it honestly, and never approximate it by truncating to a sliding window while keeping the name. As of this dossier (2026-11-15), the paper names no public checkpoint and no mainstream runner support; the claim is unverified beyond the paper itself and should be re-checked before any stronger statement.
- **The bounded-state shape, if it ever ships, is genuinely attractive for the local target:** constant per-session state (1.6M parameters of memory in the small configuration — orders below a 1M-token KV cache), streaming inference, and no admission-control term in context length. The cost is the §5 one: that state's contents are a blend, and session snapshot/restore would preserve the blend faithfully without making it any more inspectable.

### (b) Idea-level steals for the Ollama / agent stack

- **Segment + summary rhythm as the ancestor of context compaction — labelled analogy, not equivalence.** Infini-attention's discipline — work exactly inside a bounded local window; at the boundary, fold what leaves the window into a compact carried state; let later processing consult the carried state alongside the exact local context — is recognisably the shape of agent-stack context compaction (summarise the old turns, keep the recent turns verbatim, carry the summary forward). The analogy is worth banking because it names the shared risk as well as the shared shape: a compaction summary, like $M_s$, is lossy, order-dependent, and — in most agent stacks — just as un-invalidatable once folded in. The corpus's doctrine supplies the fix the architecture lacks: in the agent stack the "memory" folded forward must remain backed by the explicit records it summarised, so any folded claim can be traced, corrected at the record layer, and re-folded. Analogy ends there: compaction is a prompt-management policy chosen per session; Infini-attention is a trained operator whose compression is learned, not written.
- **The delta rule as a design prompt (not a mechanism) for external-store updates:** "retrieve what is currently believed under this key; write the difference" is, at the record layer, exactly supersession — new version replaces old under the same anchor, old version tombstoned, both timestamps kept. Infini-attention performs the arithmetic version without the bookkeeping; the external store should perform the bookkeeping version without pretending the arithmetic makes it automatic.

## 7. Cross-links

- `papers/mamba.md`, `papers/mamba-2.md` — the state cousins (Wave 8). Mamba's selective SSM state and Infini-attention's associative matrix are the two poles of fixed-size learned state: a gated recurrence over channels vs a superimposed key–value binding store. Both are lossy by design; the Jelassi/MQAR recall bounds discussed in the Mamba dossier apply in spirit to any fixed-size state, this one included.
- `memory/agent-memory-architectures.md` — the record-substrate standard against which §5 measures this design (bi-temporal invalidation, anchor pinning, read-time tombstone filtering).
- `memory/generative-agents.md` — reflection as the heuristic ancestor of learned selection: Generative Agents chose what to keep with a hand-built recency+importance+relevance score; Infini-attention (and Titans) move the selection inside the learned parameters. The corpus's verdict on the heuristic line — no supersession operation at all — applies a fortiori to the learned line.
- `memory/MEMORY-COMPENDIUM.md` — this dossier belongs in **Chapter 7 (Memory Above the Model: Agent Memory)**'s taxonomy as the limiting contrast case, and in **Chapter 3 (KV Cache)**'s lineage as a bounded-state alternative to KV growth; the chapter topic under which it should be indexed is *memory inside the architecture: compressive / learned long-term memory*.
- `synthesis/IDEA-LEDGER.md` — **#47 (the sort-key / delete-key law)** is the directly governing entry, used in §§5–6. No IDEA-LEDGER Q-entry (open-question list) specifically on in-architecture learned memory was found on checking the ledger for this wave; that absence is recorded honestly — the Q-list's memory questions (e.g. Q18 on read-time tombstone filtering) concern the external record store, and §5 above is, in effect, the argument that they cannot be ported inside the architecture. A new Q-entry is a coordinator decision, not asserted here.
- Companion dossier this wave: `papers/titans.md` — the same boundary, one step further: a memory that not only compresses but *learns at test time* what to compress.

## 8. Sources with dates accessed (2026-11-15)

- Munkhdalai, Faruqui & Gopal, *Leave No Context Behind: Efficient Infinite Context Transformers with Infini-attention*, arXiv:2404.07143v2 — arXiv abstract record and full HTML text (method equations, Tables 1–4, gating analysis), accessed 2026-11-15.
- Corpus files consulted for §§5–7 (local, this repository): `memory/agent-memory-architectures.md`, `memory/generative-agents.md`, `memory/MEMORY-COMPENDIUM.md` (chapter list), `papers/mamba.md`, `synthesis/IDEA-LEDGER.md` (#47; Q-list checked), accessed 2026-11-15.
