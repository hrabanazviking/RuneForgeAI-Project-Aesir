# Titans — Learning to Memorize at Test Time

## 1. Full citation

- **Title:** Titans: Learning to Memorize at Test Time
- **Authors:** Ali Behrouz, Peilin Zhong, and Vahab Mirrokni — Google Research (Behrouz also Cornell University, as given in secondary records of his affiliation; the arXiv record itself lists the three authors without affiliation lines in the abstract page)
- **Venue / year:** arXiv preprint, submitted 31 December 2024; commonly cited as 2025 (the coordinator's dating). A later NeurIPS 2025 publication is reported by secondary sources; it is **not** recorded on the arXiv v1 record read for this dossier and is flagged here as reported-elsewhere, not verified at the arXiv source.
- **arXiv:** arXiv:2501.00663 [cs.LG] (also cross-listed cs.AI, cs.CL) — v1 submitted 31 December 2024, 22:32 UTC. DOI 10.48550/arXiv.2501.00663. https://arxiv.org/abs/2501.00663
- **Verification note (2026-11-15):** the coordinator's identifiers checked out — title, authorship (Behrouz et al., Google), and arXiv number are correct. One dating nuance, recorded rather than silently "corrected": the submission timestamp is 31 December **2024**, so bibliographies split between 2024 and 2025; this dossier cites it as (2024; arXiv Jan 2025 listing). No official code release is named in the paper — a reproducibility caveat later made concrete by an independent reimplementation (see §4).

## 2. The problem as framed

The abstract frames the field as a decade-long negotiation between two memory shapes, and the paper's contribution as refusing the choice:

- **Recurrent models** compress data into a fixed-size hidden state — cheap, unbounded in input length, but the compression is lossy and, in classical designs, its dynamics are fixed at training time.
- **Attention** attends to the entire context window and models direct dependencies exactly — at quadratic cost, which caps it at a fixed-length context.

Titans' reframing, in the paper's own memory vocabulary: attention, *because* its context is limited but its dependency modelling is accurate, functions as a **short-term memory**; what is missing is a complementary **long-term, more persistent memory** that can memorise the long past and keep doing so while the model runs. The design requirements the paper sets for that module follow from the failures of both parents: it must be large in effective capacity yet bounded in state; compressive, but **selective about what it keeps, with the selection learned rather than heuristic**; it must keep learning at inference (the historical context of *this* sequence is only available at test time); and it must retain fast parallelisable training with fast inference — the property that killed earlier test-time-learning designs.

The sharpest form of the problem is the write policy. A fixed-size memory written indiscriminately fills with the predictable bulk of the stream and evicts — by interference — the rare items the future will actually query. Human memory's folk solution is surprise: the unexpected is what gets encoded. Titans turns that folk solution into the objective itself (§3).

## 3. Core mechanism in our own words

### 3.1 The neural long-term memory module: memory as a learner

The long-term memory is not a buffer, a cache, or a matrix — it is a **small neural network (a deep MLP) whose parameters are the memory**. Storing an association means training that network, at inference time, to map a key to a value; recalling means running the network on a query. Formally the memory at step $t$, $\mathcal{M}_t$, is updated by an **inner-loop gradient descent** on an associative loss for the current token's key–value pair, of the form

$$\ell(\mathcal{M}_{t-1}; x_t) = \|\mathcal{M}_{t-1}(k_t) - v_t\|^2, \qquad \text{surprise}_t \;\propto\; \nabla \ell(\mathcal{M}_{t-1}; x_t)$$

The gradient **is** the surprise signal: if the memory already predicts $v_t$ from $k_t$, the gradient is small and the token writes almost nothing; if the token violates what memory expects, the gradient is large and the write is strong. Selection is therefore not a separate scoring head — it falls out of the learning objective. The memory is, in the paper's phrase, a meta in-context learner: the outer training teaches it *how* to memorise; the inner loop does the memorising, per sequence, at test time.

Two refinements keep raw surprise usable over millions of tokens:

- **Momentum (surprise that persists).** The update carries a momentum term — a running surprise state $S_t = \eta_t S_{t-1} - \theta_t \nabla\ell(\mathcal{M}_{t-1}; x_t)$, with the memory stepped by that accumulated term. A surprising event's neighbourhood is usually informative too; momentum lets the write window extend over the tokens *around* a surprise instead of spiking on one token and closing.
- **Adaptive forgetting (decay as a gate).** The memory update includes a data-dependent decay / weight-decay factor, schematically $\mathcal{M}_t = (1-\alpha_t)\,\mathcal{M}_{t-1} + S_t$: before each write, a learned, input-dependent fraction of the existing memory is faded. This is the capacity valve — without it, a fixed-size network written for 2M tokens saturates — and it is also, doctrinally, the most consequential term in the paper (§5): forgetting here is a *learned function of the stream*, applied continuously, with no record of what was faded.

Because the inner loop is defined over chunks with an associative formulation, training remains parallelisable (the paper's claimed resolution of the test-time-training efficiency problem), while inference is recurrent: one bounded memory update per token/chunk.

Alongside the learned memory, Titans models also carry **persistent memory**: a small set of learnable, input-independent tokens/parameters prepended to the sequence, representing task-level knowledge that is neither short-term context nor sequence-specific long-term memory. (Secondary summaries differ in how much weight they give this component; it is part of the architecture family as presented.)

### 3.2 The three-branch architecture and its variants

A Titans model has three functional components:

1. **Core** — the main processing stack that hosts the other two.
2. **Short-term memory** — sliding-window attention over the current segment: exact, local, limited.
3. **Long-term memory** — the neural module of §3.1, holding the compressed long past.

The paper presents three variants for wiring long-term memory into the core, differing in how much the two streams interact:

- **MAC — Memory as Context.** The memory is queried for the past, and its output is concatenated with the persistent tokens and the current segment as *context* for attention. Attention can then attend jointly to what memory retrieved and to the exact local window. Reported as the strongest variant on long-context reasoning.
- **MAG — Memory as Gate.** Attention and memory run as **parallel branches** over the same input, and their outputs are combined by a learned gate — the closest analogue in this wave to Infini-attention's $\beta$-gate (`papers/infini-attention.md` §3.2), except that here the two branches are full modules rather than two reads in one block.
- **MAL — Memory as Layer.** The memory is inserted as a **layer** in the stack — input passes through memory and attention sequentially, in the hybrid-layer style familiar from SSM/attention interleavings (Wave 8). The simplest wiring, and in the paper's experiments generally the weakest of the three; MAC and MAG outperform it.

The variants are the paper's honest admission that *where* a learned memory plugs in matters as much as the memory itself — and, for §6, they are a menu no runner can collapse into a flag.

## 4. Reported results — as reported, with context

All figures are as reported in the paper (v1) unless flagged as secondary. **Scale caution, stated plainly as the brief requires: these are small-scale research demonstrations by datacenter standards** — models of roughly **170M–760M parameters** (760M the headline comparison size, trained on ~30B tokens in the language-modelling comparisons) — and the striking comparisons against GPT-4 / Llama-3.1-70B are on a single fine-tuned long-context benchmark family, not on general capability.

- **Language modelling and common-sense reasoning.** Titans variants are reported more effective than Transformers (Transformer++ baseline) and recent modern linear recurrent models (including Mamba-2 class baselines) at matched scale. Secondary reporting of the paper's tables gives, at 760M: Wikipedia perplexity ~19.93 (MAC) / ~18.61 (MAG) vs Transformer++ 25.21 and Mamba-2 ~22.94; average downstream accuracy (PIQA, HellaSwag, Winograd, ARC, SIQA, BoolQ) ~52.5% for both MAC and MAG vs 48.69% for Transformer++. These secondary transcriptions are consistent with the abstract's claim; the exact table values should be quoted from the paper PDF before reuse in any other dossier.
- **Long context / needle tasks.** The headline claim (abstract): Titans **scale effectively beyond a 2M-token context window**, with higher accuracy on needle-in-haystack tasks than baselines as length grows, where Transformer and recurrent baselines degrade.
- **BABILong.** On BABILong — facts embedded at known depths in very long distractor text, requiring reasoning over retrieved facts — the paper reports Titans (after fine-tuning) **outperforming much larger models including GPT-4 and Llama-3.1-70B** on the benchmark's long-length settings, despite the Titans models' sub-1B scale. Read with the standard caveat the corpus applies to all such rows: this is a fine-tuned specialist result on a synthetic retrieval-reasoning probe, not evidence of general superiority over those models.
- **Beyond language.** The evaluation also covers **genomics and time-series** tasks, where Titans are likewise reported ahead of Transformer and linear-recurrent baselines — evidence the memory module is not a language-only artefact, of no direct runner consequence.
- **Reproducibility status (post-paper, flagged as such).** No official implementation accompanied v1. An independent 2025 reimplementation-and-analysis ("Titans Revisited", Sapienza University of Rome; located during this wave's verification, not part of the original paper) reports that a faithful reimplementation does **not always outperform established baselines**, identifying chunking choices as a major factor, and notes ambiguities in the original description. The corpus should therefore grade Titans' results as **author-reported, independently contested in part** — a stronger caution than applies to Infini-attention, whose claims are narrower.

## 5. Position vs the corpus's memory doctrine

*[Corpus synthesis — this section is the corpus's judgement, not the paper's.]*

Everything §5 of the Infini-attention dossier says about superimposed memory applies here, deepened by one qualitative step. Infini-attention's memory at least has a fixed algebra: bindings are added, and the delta rule can correct a binding when the same key recurs. Titans' memory is a **trained network whose contents are its weights**. Against the agent-memory standard (`memory/agent-memory-architectures.md` — inspectable records, addressable entries, anchor pinning, bi-temporal invalidation, read-time tombstone filtering, auditability):

- **Not inspectable, in the strongest sense available.** There is no decoding of an MLP's weights into a list of stored facts. One can probe behaviour; one cannot enumerate contents.
- **Not addressable, not pinnable.** No entry exists to exempt from decay. The character anchor — the corpus's un-pushable, resident, never-reprocessed core — has no possible representation here: anything written into the module is subject to the same gradient interference and the same $(1-\alpha_t)$ fade as everything else.
- **Not invalidatable — and actively forgetful by a learned rule.** The adaptive forgetting gate is decay promoted from a heuristic to a learned policy. Under IDEA-LEDGER #47 that is precisely the forbidden move at the record layer: a fading term deciding what ceases to exist, where the fading is driven by stream statistics, leaves no tombstone, and cannot be appealed. A fact about a person that the stream has made "unsurprising" is exactly the fact this gate is trained to let go.
- **Not auditable or bi-temporal.** The weights at time $t$ summarise an unlogged history of gradient steps. There is no "valid from / superseded at", no provenance, and no replay that excludes one episode: you cannot un-train one conversation from the module without retraining from a checkpoint that may not exist.

The boundary, stated as precisely for Titans as for its companion:

> **A memory that learns at test time is a capability substrate — it can absorb gist, style, skills, and the shape of a domain ever more fluently — but it is not a record substrate: facts, commitments, and identity anchors require a memory whose contents can be listed, pinned, corrected, and proven deleted, and a weight-space memory can do none of the four, so any architecture that stores facts about a person inside it has made those facts uncorrectable by design.**

The test-time-learning property adds a second, sharper hazard the static-compression case lacks: **the memory is writable by the input stream itself.** Anything in context — including adversarial or merely mistaken content — that is sufficiently surprising gets gradient-written into long-term memory with the same authority as the user's own corrections. In record-substrate terms, that is a write path with no authentication, no review, and no undo. For a personal agent, that property alone disqualifies the module from holding the record, whatever its benchmark scores.

## 6. Applicability

### (a) Runners

- **Not servable today in a ggml-class stack; an architecture, not a feature.** A Titans checkpoint requires a runner to implement: an inner-loop gradient update at inference (the forward pass contains an optimiser), momentum and decay state per memory module, chunked parallel training semantics irrelevant to serving but baked into checkpoint expectations, and one of three distinct wirings (MAC/MAG/MAL) with different data flow. No mainstream runner — and, as of this dossier (2026-11-15), no production-grade reference implementation at all, per the secondary literature located in verification — serves this family. If checkpoints ever ship, this is the **detect-and-honour** class in its purest form: detect the architecture, implement the inner loop exactly or refuse the model; there is no honest approximation, because approximating the memory update *is* changing what the model remembers.
- **A serving-semantics warning worth banking now:** a Titans-class model's outputs are **not a function of (weights, context) alone** in the usual runner sense — they depend on the *order and history of everything the memory module has consumed since it was last reset*. Session boundaries, prefix caching, snapshot/restore, and reproducibility all acquire a new state object whose semantics (when is it reset? is it per-session? does restoring a snapshot restore the memory weights?) must be specified by the runner, because the checkpoint format cannot specify them. The corpus has met this shape before with SSM state (`papers/mamba.md` §6); Titans makes the state *trainable at runtime*, which removes even the consolation that the state is a deterministic summary of a visible prefix — it is, but only if the runner also logs every update, which serving stacks do not.

### (b) Idea-level steals for the Ollama / agent stack

- **Surprise-gated writing as a *policy* for the external memory store — the wave's best steal, evaluated honestly.** Titans' write rule — spend storage where prediction error is high; the already-known costs nothing — translates cleanly to the record layer as a **write gate**: when an incoming episode contradicts or extends what the store already predicts about the user (a changed preference, a new commitment, a corrected fact), that is a high-priority write; when it merely repeats the known, no new record is needed. This is compatible with the corpus's law, and the compatibility has a precise shape under IDEA-LEDGER #47:
  - *Surprise as a WRITE gate is compatible.* It decides what earns a new explicit record — a ranking/prioritisation decision, in the family of the sort key. The record, once written, exists under the ordinary rules: pinned if it is an anchor, superseded only by a witnessed correction, tombstoned on deletion.
  - *Surprise as a DELETE rule would not be.* The moment low surprise (or the $(1-\alpha_t)$ fade) is allowed to *remove* records, the store has re-imported MemoryBank's defect (IDEA-LEDGER R21) with a learned coefficient: existence decided by stream statistics, no tombstone, no appeal. Titans' forgetting gate is good engineering for a weight-space gist store and a doctrinal violation for a record store; the steal takes the gate's *input* (the surprise signal) and refuses its *output* (deletion).
  - One honest cost: a surprise gate inherits the model's miscalibrations. Facts stated quietly, in passing, in familiar words — a changed medication, a moved house, phrased like small talk — can score low-surprise and be gated out. The record store therefore needs the gate to be **advisory with a floor**: witnessed acts (the user stating a fact about themselves, making a commitment, issuing a correction) write unconditionally; surprise ranks the *ambient* stream (inferred preferences, episode summaries) where a missed write costs little. That floor is corpus policy, not Titans'.
- **Momentum as an episode-boundary hint (minor, labelled analogy).** Titans' insight that significance extends over a neighbourhood, not a token, has a record-layer echo: extraction should operate on episodes, not utterances — the correction is often in the sentence *after* the surprising one. Already implicit in the corpus's extraction practice; noted, not claimed as new.

## 7. Cross-links

- `papers/infini-attention.md` — companion dossier this wave: the same capability-vs-record boundary (§5 in both), with a static associative memory where Titans has a learning one; MAG's gate vs Infini-attention's $\beta$-gate is the direct structural comparison.
- `papers/mamba.md`, `papers/mamba-2.md` — the state cousins (Wave 8): fixed-size recurrent state as memory. Titans is the point where that lineage's state becomes a trained network with its own inner optimiser; the recall bounds discussed there (state size vs associations stored) bound Titans' module too, softened but not repealed by depth.
- `memory/agent-memory-architectures.md` — the record-substrate standard used in §5 (bi-temporal invalidation, anchor pinning, auditability, read-time tombstone filtering).
- `memory/generative-agents.md` — reflection as the heuristic ancestor of learned selection: a hand-scored importance rating at write time is Titans' surprise gate with the learning removed; the corpus's finding that the heuristic line never acquired a supersession operation is the cautionary prehistory of §5.
- `memory/memorybank.md` — the decay-as-deletion limiting case; §6(b)'s write-gate/delete-rule distinction is IDEA-LEDGER #47 / R21 applied to Titans' forgetting gate.
- `memory/MEMORY-COMPENDIUM.md` — belongs, with its companion, under **Chapter 7 (Memory Above the Model)**'s taxonomy as the in-architecture contrast class, indexed under the chapter topic *memory inside the architecture: learned / test-time memory*; its runner consequences (§6a) also belong to **Chapter 8 (Memory Decisions Are Runner Decisions)**.
- `synthesis/IDEA-LEDGER.md` — governing entries **#47** (sort-key / delete-key law) and **R21** (Ebbinghaus/decay as a deletion rule, rejected), both applied in §§5–6. On checking the ledger for this wave, **no Q-entry specifically on test-time-learned memory was found**; the absence is recorded honestly. §6(b)'s advisory-gate-with-a-floor proposal is offered to the coordinator as a candidate ledger note, not asserted as an entry.

## 8. Sources with dates accessed (2026-11-15)

- Behrouz, Zhong & Mirrokni, *Titans: Learning to Memorize at Test Time*, arXiv:2501.00663v1 — arXiv abstract record (title, authors, submission history, abstract claims incl. >2M context and task coverage), accessed 2026-11-15.
- Secondary reporting of the paper's full text and tables (architecture variants MAC/MAG/MAL, update rule with momentum term $S_t$ and decay $(1-\alpha_t)$, 170M–760M scales, 760M comparison numbers, BABILong framing), accessed via web summaries 2026-11-15 — used only where consistent with the abstract record, and flagged as secondary in §4.
- "Titans Revisited" independent reimplementation notice (alphaXiv record for the reimplementation paper), accessed 2026-11-15 — basis for the reproducibility caution in §4.
- Corpus files consulted for §§5–7 (local, this repository): `memory/agent-memory-architectures.md`, `memory/generative-agents.md`, `memory/memorybank.md`, `memory/MEMORY-COMPENDIUM.md` (chapter list), `papers/mamba.md`, `synthesis/IDEA-LEDGER.md` (#47, R21; Q-list checked), accessed 2026-11-15.
