# OR-6 Dossier A8-2: MemoryBank — Ebbinghaus Forgetting as a Memory Update Rule, and the Summarised User Profile

> Research Forge campaign — commissioned by Volmarr, 2026-11-15.
> Domain: OR-6 (memory), Wave 14 — agent-memory ancestors. This dossier treats the second ancestor the banked descendant audit (`research/memory/agent-memory-architectures.md`, dossier A5) cites but does not treat in depth: the field's main **forgetting** mechanism ancestor, and one of its two **user-profile summarisation** ancestors (the other line runs through ChatGPT's profile extraction, A5 §5.2). It extends A5; where A5 is silent — and A5 is almost entirely silent on decay, mentioning forgetting only as something Letta-style blocks do *not* do automatically (A5 §3.5) — this dossier is the corpus's first treatment, and says so.
> Clean-room note: written in our own words. No source text is reproduced beyond short factual labels (the retention formula, metric names, scores as published). Every factual claim about the paper is cited to a source in §8, accessed 2026-11-15.

---

## 1. Full citation (as verified)

Zhong, W., Guo, L., Gao, Q., Ye, H., & Wang, Y. (2024). *MemoryBank: Enhancing Large Language Models with Long-Term Memory.* Proceedings of the AAAI Conference on Artificial Intelligence, 38(17), 19724–19731. arXiv:2305.10250 [cs.CL] — submitted 17 May 2023 (v1), revised 21 May 2023 (v3). https://arxiv.org/abs/2305.10250

Verification, 2026-11-15: arXiv identifier, title, and five-author list checked against the arXiv record on that date; the coordinator's believed identifier (2305.10250) and venue (AAAI 2024) both checked out — the AAAI proceedings placement (vol. 38, pp. 19724–19731) is confirmed by the OpenAIRE/DBLP record for the paper. Affiliations as published: Sun Yat-Sen University, Harbin Institute of Technology, and KTH Royal Institute of Technology. Code and materials released by the authors at the MemoryBank-SiliconFriend repository linked from the paper.

**Essence.** A model-agnostic long-term memory layer for LLM companions with three parts: a **store** holding raw conversations plus two tiers of model-written summary (daily → global event summaries; daily → global user-personality profiles), a **dense retriever** over that store, and — the contribution the field remembers — an **updater governed by the Ebbinghaus forgetting curve**: each memory carries a strength that decays exponentially with elapsed time, and each successful recall resets its clock and raises its strength, so unrehearsed memories fade and rehearsed ones persist. Demonstrated as **SiliconFriend**, a long-term AI companion tuned on psychological-dialogue data. MemoryBank is the ancestor that asked the question Generative Agents never asked — *should some memories be lost?* — and answered it with psychology's oldest quantitative memory law.

---

## 2. The problem as framed

The paper opens on a deficiency it states plainly: LLMs have no long-term memory, and the lack is felt most in **sustained-interaction roles — personal companionship, psychological counselling, secretarial assistance** — where the relationship itself is the product and a companion that forgets the user between sessions has failed at its one job.

Two distinct problems are folded into that framing, and separating them is necessary to judge the design:

1. **The continuity problem.** Without persistence, every session starts from a stranger. The system must store past interactions, retrieve the relevant ones into the present context, and maintain a running understanding of *who this user is* — their personality, emotional patterns, preferences — that deepens over time. This is the problem MemoryBank shares with every system in A5, and its storage/retrieval/profile machinery (§3.1–3.2, §3.4) is its answer.
2. **The ageing problem — this paper's distinctive framing.** A memory that keeps everything forever is, the authors argue, wrong twice over. Practically, it grows without bound while retrieval quality degrades in the clutter. Humanly, it is *un-anthropomorphic*: people forget, and a companion that forgets nothing does not feel like a mind that has lived alongside the user — it feels like a transcript. Long-term companionship therefore needs memory that **ages**: memories should fade unless life rehearses them, exactly as human retention does. Forgetting is framed not as data loss to be minimised but as a *feature of believable, bounded, human-like memory* — "selectively preserve memory" is the paper's own summary of the goal.

Note what the ageing problem is *not*, in this framing: it is not a truth problem. The paper contains no notion of a memory becoming *false* — no contradiction, no supersession, no user correction. Memories in MemoryBank do not go wrong; they only go *old*. §5.3 returns to this, because it is the precise point where the ancestor's world-model diverges from this corpus's honesty standard: decay answers "what is no longer salient?", and is silent on "what is no longer true?" — and a personal agent needs the second answer far more than the first.

The setting the paper optimises for follows from the framing: **SiliconFriend**, a bilingual (English/Chinese) AI companion for long-term emotional companionship, built over three different base models to prove the memory layer is model-agnostic (§3.5).

---

## 3. Core mechanism, in our own words

MemoryBank is a unified mechanism of three pillars — **storage, retrieval, updating** — plus the summarisation layer that produces the profile. In A5's §2.3 vocabulary: storage is the write target, retrieval is the read, summarisation is a write-side derivation, and the forgetting updater is the *manage* operation — the only fully-specified manage-by-decay design in the ancestor literature.

### 3.1 Storage: three kinds of record

- **In-depth conversation records.** Every multi-turn conversation, stored in detail, in chronological order, with timestamps. This is the episodic layer — the raw material everything else derives from, and (unlike Generative Agents' stream) it is *not* the primary retrieval surface for the profile; it coexists with the summaries below.
- **Hierarchical event summaries.** Conversations are distilled by the LLM into a **daily event summary** (prompted, in substance: summarise the events and key information in this content), and daily summaries are further synthesised into a **global event summary**. Two levels of compression, each model-written from the level below.
- **Dynamic personality profiles.** In parallel, the LLM infers **daily personality insights** from each day's conversations (prompted, in substance: summarise the user's personality traits and emotions from this dialogue), aggregated in turn into a **global user portrait**. The portrait is a standing, evolving summary — the direct ancestor of the profile-summary pattern A5 §5.2 tracks into production in ChatGPT's "improved memory."

Storage is thus already a small hierarchy — raw / daily / global, for both events and personality — a year before the production systems made the same shape famous. What it does not have: any per-fact structure. Summaries are prose; the portrait is prose; there are no slots, no keys, no validity intervals. A fact inside a summary can only be changed by re-summarising.

### 3.2 Retrieval: dense passage retrieval over memory pieces

Retrieval follows the Dense Passage Retrieval pattern. Every conversation turn and every event summary is a **memory piece**; each piece is pre-encoded by an encoder model into a vector; the whole store is indexed with **FAISS** for similarity search. At conversation time, the current context is encoded with the same encoder and used as the query; the most relevant pieces are retrieved and assembled into the prompt **together with the global user portrait and the global event summary** — i.e., retrieved episodes plus the two standing global summaries, injected as one context package. The encoder is interchangeable by design (the SiliconFriend implementations use MiniLM for English and Text2vec for Chinese; the integration runs through LangChain).

Contrast with Generative Agents (§3.2 of the companion dossier): retrieval here is **relevance-only**. There is no recency term and no importance term in the ranking — recency's role is moved entirely into the *updater* (§3.3), where time acts on whether a memory survives rather than on whether it ranks. That separation — *ranking by relevance, survival by decay* — is MemoryBank's cleanest design idea, and §5 shows it is also the idea the field half-kept.

### 3.3 The updating mechanism: the forgetting curve as specified

The updater implements three principles the paper takes from Ebbinghaus's forgetting-curve theory: retention falls with time since learning; the fall is steep early and flattens; and spaced rehearsal resets the curve and makes it shallower. The formalisation, exactly as specified:

- **Retention** follows an exponential decay: **R = e^(−t/S)**, where *t* is the time elapsed since the memory was learned (or last reinforced), and *S* is the memory's **strength**.
- **Strength is a discrete counter, initialised to S = 1** when a memory is first mentioned/stored.
- **Reinforcement:** when a memory is **recalled in conversation**, its strength **increases by 1 (S → S + 1)** and its elapsed-time clock **resets (t → 0)**. A memory rehearsed often therefore decays ever more slowly — larger *S* flattens the exponent — and starts each decay from full retention.
- **Forgetting:** a memory whose retention has decayed is forgotten with correspondingly higher probability — the mechanism is probabilistic fading governed by R, not a hard delete-at-threshold rule. The paper is candid about the model's status, and this dossier preserves the candour: the authors describe the updater as **an exploratory, highly simplified model** of real memory, noting that actual retention varies by person and material and that Ebbinghaus's fuller theory (overlearning, meaningful-material effects) is deliberately not simulated.

Three properties of the rule as specified deserve emphasis, because §5 and §6 turn on them:

1. **Decay is content-blind.** The curve sees time, strength, and recall events — nothing else. It cannot distinguish a trivial chat from a fact the user stated once, solemnly, and never repeated. Under this rule, *said once and never rehearsed* is the exact profile of both the most forgettable trivia and the most important standing facts (an allergy, a bereavement, a boundary). The rule has no channel through which importance could protect a memory: unlike Generative Agents, MemoryBank assigns **no importance score at write time at all**.
2. **Recall is the only rehearsal.** A memory survives by being *used in conversation*. Memories about topics the user avoids — often the sensitive ones — decay fastest. The dynamics are human-like in precisely the way that is dangerous for a fiduciary memory.
3. **Forgetting is destruction.** A faded memory is gone from the store; there is no tombstone, no archive tier, no record that it existed or that the system chose to drop it. The operation is un-auditable by construction — the exact opposite pole from bi-temporal invalidation (§5.3).

### 3.4 The profile/summary layer, as a mechanism

The summarisation layer (§3.1) deserves separate statement because it, not the curve, is MemoryBank's most-copied part. Its properties: **daily cadence** (summaries and personality insights are per-day artefacts); **two-level aggregation** (daily → global, by further LLM summarisation of the summaries); **standing injection** (the global portrait and global event summary ride along with every retrieval package, §3.2 — they are, in effect, unpinned-but-always-present context, a halfway house between Generative Agents' everything-competes stream and Letta's pinned core blocks); and **prose all the way down** — no stage produces a discrete, individually inspectable or deletable fact. A user cannot ask MemoryBank "what do you believe about me?" and receive a list they can correct line by line; they receive a paragraph the system wrote about them, correctable only by more conversation and another summarisation pass. A5 §5.2's inspectability-versus-currency trade is already fully present here, in 2023, on the currency side.

### 3.5 SiliconFriend: the demonstration setting, as reported

SiliconFriend instantiates MemoryBank as an emotional-support companion over **three base models** — ChatGPT (closed), ChatGLM-6B and BELLE (open, bilingual) — to demonstrate model-agnosticism. The open models receive an additional stage MemoryBank itself does not require: **LoRA fine-tuning (rank 16, 3 epochs) on 38k psychological dialogues** collected from online sources, to give the companion its empathetic register. The memory layer is then integrated identically across all three. Two separations matter for reading the results in §4: the empathy effects belong substantially to the *tuning*, not to MemoryBank; and the memory effects are evaluated on the *combination*, so MemoryBank's isolated contribution is visible only where the probing questions test recall directly.

---

## 4. Reported results, as reported

**Evaluation method, stated plainly first.** MemoryBank's evaluation measures **memory recall and companion quality as judged by human annotators and by example inspection** — qualitative case studies with real users, plus a quantitative probe study on *simulated* conversations. It does not measure factual consistency over time, contradiction handling, or correctness of the personality portrait against any ground truth about the (simulated) users. As with Generative Agents, a fluent, confident, wrong recollection can score well on coherence. Every number below inherits that caveat.

### 4.1 Qualitative analysis (as reported)

Three strands, all by showcased example rather than by rate:

- **Psychological companionship.** In real-user dialogues collected on the authors' online platform, SiliconFriend's responses are presented as markedly more empathetic and constructively supportive than its untuned base (ChatGLM) — an effect the design attributes jointly to the psychological tuning and the memory (§3.5's separation applies).
- **Memory recall.** In example dialogues, SiliconFriend days later correctly recalls previously discussed specifics (a recommended book and algorithm from an earlier study-advice conversation) and correctly recognises an item that had *not* been discussed — i.e., in the examples shown, it neither forgets the planted facts nor confabulates the unplanted one.
- **Personality-conditioned interaction.** Examples show recommendations tailored to different users' inferred traits, offered as evidence the portrait (§3.4) is doing work.

### 4.2 Quantitative analysis (as reported)

**Setup.** A synthetic memory store: **10 days** of conversations for **15 virtual users** of diverse personalities, the users themselves role-played by ChatGPT, each day covering at least two topics; stores built in both English and Chinese. Against this store, **194 probing questions** (97 English, 97 Chinese), written manually, each testing whether the model recalls the pertinent memory and answers appropriately. **Human annotators** scored three SiliconFriend variants on four metrics: **memory retrieval accuracy** (was the related memory retrieved: 0/1), **response correctness** (0 / 0.5 / 1), **contextual coherence** (0 / 0.5 / 1), and a **ranking score** across the three variants (s = 1/rank).

**Results, Table 2 of the paper, as published:**

| Language | Variant | Retrieval acc. | Correctness | Coherence | Ranking |
| --- | --- | --- | --- | --- | --- |
| English | SiliconFriend (ChatGLM) | 0.809 | 0.438 | 0.680 | 0.498 |
| English | SiliconFriend (BELLE) | 0.814 | 0.479 | 0.582 | 0.517 |
| English | SiliconFriend (ChatGPT) | 0.763 | 0.716 | 0.912 | 0.818 |
| Chinese | SiliconFriend (ChatGLM) | 0.840 | 0.418 | 0.428 | 0.510 |
| Chinese | SiliconFriend (BELLE) | 0.856 | 0.603 | 0.562 | 0.565 |
| Chinese | SiliconFriend (ChatGPT) | 0.711 | 0.655 | 0.675 | 0.758 |

Read as the paper reads it: retrieval accuracy is high across all variants (0.71–0.86) — the memory layer works on open and closed models alike, which is the paper's generalizability claim — while correctness and coherence track the *base model's* strength (ChatGPT variant clearly ahead), i.e. MemoryBank gets the memory into the room and the base model decides how well it is used. Language effects are mixed and variant-dependent (BELLE relatively stronger in Chinese, ChatGLM and ChatGPT in English).

**What is not in the evaluation — the dossier's emphasis, because §5 depends on it:**

- **No ablation of the forgetting mechanism itself.** The paper lists applicability "with and without memory forgetting mechanism" among its generalizability claims, but the reported quantitative study does not isolate decay's contribution: there is no with-decay versus without-decay comparison on recall, coherence, or store growth in the results as published. The curve — the paper's signature mechanism — is *motivated* and *specified*, but its benefit is **not measured** in the paper's own experiments. The field inherited an unmeasured mechanism on the strength of its psychological plausibility.
- **No long horizon.** Ten simulated days is the entire temporal extent. A forgetting curve whose whole interest lies in months-scale dynamics is evaluated inside the steep early segment of its own curve.
- **Simulated users, simulated facts.** The store's contents were generated by ChatGPT role-play; the probing questions test recall of planted, unambiguous facts. Nothing in the setup can produce a contradiction, a correction, or a user who changes — the conditions under which decay does its damage (§3.3) are designed out.

### 4.3 The honest summary of the evidence

MemoryBank demonstrates: a model-agnostic memory layer can give three different LLMs usable 10-day recall (retrieval accuracy ≈ 0.71–0.86 on planted facts) and a working user-portrait summary, in two languages. It asserts, but does not demonstrate, that Ebbinghaus decay improves the result. Both halves of that sentence must travel together wherever this corpus cites the paper.

---

## 5. The inheritance audit

Method as in the companion dossier: fate in modern systems per the banked dossier A5; judgement ours, inference marked.

### 5.1 Mechanism by mechanism

| Mechanism (2023) | Fate in modern systems (per A5) | Judgement |
| --- | --- | --- |
| Raw store + daily/global event summaries | **Survives, industrialised.** ChatGPT's summary-era memory (A5 §5.2) is this shape at product scale; Letta's sleep-time consolidation produces the same derived artefacts in the background (A5 §3.4). | The summary hierarchy is a permanent acquisition — with A5 §5.4.6's drift warning attached. |
| Global user portrait, always injected | **Survives, and splits in two.** ChatGPT's memory summary is the direct descendant (rolling prose portrait, user-reviewable, A5 §5.2). Letta's `human` block is the same intent in the rival form: discrete, bounded, user-inspectable (A5 §3.3). | The *portrait* won; the *prose-only* form is exactly what the inspectability critique (A5 §6.4.4) argues against for identity-class facts. |
| Dense retrieval (DPR + FAISS), relevance-only | **Survives as the default read path** everywhere (A5 §2.3), usually re-augmented with the recency/importance signals MemoryBank omitted — i.e. the field merged MemoryBank's retriever with Generative Agents' score. | Neither ancestor's read path survived pure; the hybrid did. |
| **Ebbinghaus decay as the update rule** | **Dropped — see §5.2, the headline answer.** | — |
| Probabilistic forgetting (deletion by fading) | **Dropped, and replaced by its opposite:** explicit, witnessed operations — Mem0's model-decided delete (A5 §6.2a), user-initiated deletion with documented semantics (A5 §5.1), Graphiti's refusal to delete at all (A5 §6.2c). | Modern forgetting is *editorial or legal*, never *entropic*. |
| Model-agnostic memory-as-layer | **Survives as an architecture boundary.** Mem0 is explicitly memory-as-middleware beside the agent (A5 §5.3); A5 §7.1 recommends the same boundary (a memory service beside the runner) for this programme's own Ollama build. | MemoryBank's least-discussed claim may be its most durable: memory is a layer, not a model feature. |

### 5.2 The headline question: does anything modern keep MemoryBank-style decay?

**No. On the evidence of the banked dossier, no modern system surveyed in this corpus keeps Ebbinghaus-style decay — decay of a memory's survival or strength as a function of elapsed time and rehearsal — as a memory-management mechanism.** The audit, system by system (all per A5):

- **Letta/MemGPT:** A5 §3.5 states it in so many words — *"forgetting is not automatic; nothing fades on its own; a memory leaves only if an agent edits it out or a sleep-time pass removes it."* Removal is an editorial act by an identifiable editor, recorded (in the git-backed line, as a diff).
- **Mem0:** the update vocabulary is add / update / delete / no-op, each a **model decision at consolidation time** about a specific new fact against specific retrieved neighbours (A5 §§5.3, 6.2a). Time enters only as content (a fact's date), never as an entropic force on the store.
- **Zep/Graphiti:** the anti-decay design in pure form — facts are *invalidated*, never faded and never deleted; a fact from a year ago that was never contradicted is exactly as retrievable as yesterday's, and a superseded fact remains fully queryable *as history* (A5 §6.2c). Age, without contradiction, does nothing.
- **ChatGPT memory:** management is automatic but *editorial* — updating, combining, prioritising, backgrounding (A5 §5.2) — decisions by a pipeline about content, with user-visible controls and disclosed retention. Nothing in the documented behaviour describes time-based strength decay or probabilistic loss.

What survives of the curve is only its weakest echo: **recency as one ranking signal among several** in retrieval (A5 §2.3) — and even there, the surviving form is Generative Agents' version (recency *boosts rank*), not MemoryBank's (age *threatens existence*). [Inference:] the field kept decay exactly where decay is harmless — ordering a list it will re-derive next turn — and discarded it exactly where it was dangerous: deciding what continues to exist. The reasons are reconstructible from A5's failure catalogue (§5.4 there): production's formative memory failures were *staleness, unwitnessed writes, and deletion that does not delete* — all failures of **insufficiently deliberate** memory management. A mechanism whose essence is *deliberate-less* management — loss by entropy, unwitnessed, content-blind (§3.3) — solves none of them and manufactures a new one: the quietly vanished fact, undiscoverable because there is nothing left to inspect. Add §4.2's finding — the mechanism was never ablated even by its authors — and the field's verdict reads as rational, not merely fashionable: **an unmeasured, un-auditable deletion rule had no claim on systems whose users were already complaining that memory acted without their knowledge.**

One boundary on this headline, stated for honesty: the audit covers the systems A5 surveys (the Letta lineage, ChatGPT, Mem0, Zep/Graphiti) — the systems this corpus treats as the modern field. Decay-like rules persist at the field's edges (cache-eviction policies for agent scratchpads, TTLs on session state, ranking half-lives in recommender-style context assembly) [inference/general knowledge, not from A5], but none of those is a *long-term personal memory* store forgetting by Ebbinghaus curve. As a claim about agent memory proper, the headline stands: **decay is the ancestor mechanism the field tried in print once and did not keep.**

### 5.3 Judged against the corpus's honesty standard

The corpus's standard (A5 §6): supersession must be **non-destructive and auditable**; bi-temporal invalidation is the mechanism that meets it. MemoryBank judged against it:

1. **Decay is destructive and un-auditable by design.** A faded memory leaves no tombstone, no validity interval, no record of the decision — because there was no decision, only an exponent. Against the standard's first term it scores zero; against the second, less than zero, since the absence is indistinguishable from never having known.
2. **Decay does not even address the standard's problem.** The honesty problem is *contradiction* — two values for one slot, one of them stale. Decay acts on age and rehearsal, which are uncorrelated with truth: a stale fact rehearsed often (the old address, mentioned fondly for years) is *strengthened* by MemoryBank's rule, while its quiet correction, stated once, decays. Under this updater the store does not merely fail to resolve contradictions; its dynamics can actively entrench the wrong side of one. Append-only-plus-retrieval guarantees eventual contradiction (A5 §6.1); **append-only-plus-decay guarantees eventual contradiction *with the evidence preferentially deleted by salience rather than by truth*** — the theorem's premises plus a biased eraser.
3. **The profile layer fails the auditability term separately.** A global portrait in prose, re-summarised from summaries (§3.4), has no provenance chain a user can walk: which conversation produced this trait attribution? Under the standard, a derived record must cite its evidence and remain correctable as a record (A5 §6.4.3, §6.4.6). MemoryBank's portrait cites nothing and can be corrected only statistically, by more conversation. ChatGPT's summary era inherited this defect intact (A5 §5.4.6); Letta's discrete blocks and Graphiti's episode-linked edges are the field's two repairs.

To be fair to the ancestor — and the fairness matters, because §6 salvages something real from it — MemoryBank never claimed to solve truth. Its frame (§2) is companionship believability over days, inside which decay is a *character* feature: the companion feels lived-with partly because its memory has a human grain. The failure is not the paper's; it belongs to any later design that imports the curve into a setting where memory is *fiduciary* — where the user relies on the store being complete and correct — without noticing that the frame changed underneath the mechanism.

---

## 6. Applicability: is there a defensible role for decay?

*[This section is engineering judgement, labelled as such throughout. It states this programme's position; it claims no external authority.]*

The question, precisely put: in a personal agent whose **supersession is already handled by invalidation** (bi-temporal versioning, tombstones, provenance — A5 §6.4), is there anything left for decay to do? Our answer: **yes — exactly one thing, and the whole answer turns on a distinction the ancestor blurred: decay as a retrieval-ranking signal versus decay as deletion.**

### 6.1 Decay as deletion: no defensible role

Once invalidation exists, deletion-by-age has no work to do and three harms to offer. It deletes without a truth reason (age is not falsity), without a witness (no record survives), and with the worst possible selection bias (§3.3: the unrehearsed-once-stated standing fact is its first victim — and standing facts are precisely the class a personal agent exists to keep). Storage cost, the one honest argument for entropic deletion, is not binding at personal scale: a lifetime of extracted facts is megabytes. Where genuine deletion is required — user demand, legal erasure, sensitive-fact hygiene — it must be a **deliberate, tombstoned operation** (A5 §6.4.2), including the hard-purge path, never a curve crossing a threshold in the night. **Position: in our builds, nothing is ever forgotten by entropy. Forgetting is a decision or it does not happen.**

### 6.2 Decay as a ranking signal: a real, bounded role

What decay legitimately models is not truth but **attention**: among *currently valid* facts, the recently relevant usually matter more to the present turn. That is a ranking claim, and it is safe precisely because ranking is re-derived every turn and destroys nothing. Concretely, for this programme's memory-service design (A5 §7.1):

- **Scope it to the valid view.** Decay may order *only* records whose `valid_to IS NULL` and which no tombstone touches. Superseded and deleted records are not decayed; they are *excluded by semantics* before ranking begins (and see Q18, §7 — the read-time filter is the enforcement point).
- **Scope it to the episodic tier.** Recency weighting is defensible for choosing which *episodes* to excerpt into a crowded prompt. It is not defensible for semantic facts (a user's allergy does not become less true with age) and it is forbidden for the anchor tier (§6.1 of the companion dossier: the anchor is never scored at all).
- **Make rehearsal a ranking effect only.** MemoryBank's reinforcement insight — what gets used should surface more readily — survives translation as an access-count *ranking* boost, capped, and never as a survival condition. A fact used daily and a fact used once stand equal in the store; they differ only in the order of a list.
- **Keep it inspectable.** Any decay parameter in the ranking must be visible in the turn's provenance log (the injected set and its scores are part of the turn's record, A5 §5.3), so "why did it surface that?" always has an answer that does not include "because the rest had faded."

In short: **Ebbinghaus belongs in the sort key, never in the delete key.** The ancestor put the curve in charge of existence; the defensible modern form puts it in charge of emphasis, inside a store whose existence decisions are made by invalidation and by witnessed human or editorial acts. That is, in the end, exactly the settlement the field reached (§5.2) — this section's contribution is to state it as a rule with its scopes, rather than as an outcome to observe.

### 6.3 The one remainder: bounded stores that are not fiduciary

For completeness: decay-as-deletion remains defensible where the store is explicitly *not* a record — an agent's working scratchpad, a simulation's ambience (MemoryBank's own frame), a cache whose misses cost nothing. The rule is about what the user is entitled to rely on. A companion's memory of the user is fiduciary the moment the user trusts it; designs should decide which side of that line each store sits on, in writing, before choosing an updater.

---

## 7. Cross-links

- **Descendant audit:** `research/memory/agent-memory-architectures.md` (A5) — the modern-systems evidence for §5's audit (§§3.5, 5, 6.2 there); §5.2 there is the production history of this paper's profile layer; §6.4 is the honest-store standard §5.3 judges against and §6 builds on; §7.1 is the memory-service boundary this dossier's §6.2 ranking rules are written for.
- **MEMORY-COMPENDIUM, agent-memory chapter (Chapter 7):** the compendium's Chapter 7 is built on A5 and therefore currently contains **no treatment of forgetting as a mechanism** beyond A5's observation that Letta does not do it automatically. What Wave 14 adds: the forgetting curve as specified (R = e^(−t/S), S init 1, +1 and clock-reset on recall — §3.3 here), the finding that the mechanism was never ablated by its own authors (§4.2), the headline audit result that no modern system keeps decay (§5.2), and the ranking-versus-deletion settlement (§6) as the chapter's engineering position on forgetting. The chapter's gap list should also note the profile layer's ancestry: ChatGPT's summary era descends from MemoryBank's portrait (§3.4) as much as from any product decision.
- **IDEA-LEDGER Q18 (read-time tombstone filtering):** Q18 asks whether injection-time filtering against tombstones/superseded versions is required for correctness. This dossier contributes the negative-space evidence: MemoryBank is the limiting case of a store with *no* tombstones and *no* read-time validity state of any kind — its read path cannot filter, because its write path never recorded anything to filter by; worse, its updater guarantees the store's contents drift from the user's life by entropy, so a future read-time filter would have nothing stable to enforce. The design moral for Q18's settlement: read-time filtering is only possible in stores that chose invalidation over decay at write time — the two ancestors' updaters (Generative Agents' none, MemoryBank's decay) both make Q18 unanswerable, which is itself an argument that the honest store's write semantics (A5 §6.4) are the precondition, and Q18 is a question only our own design generation gets to have.
- **Companion ancestor dossier:** `research/memory/generative-agents.md` (Wave 14) — the stream/score/reflection ancestor; §5.2 there (reflection's survival) and §5.2 here (decay's non-survival) are the wave's paired headline findings.

---

## 8. Sources

All sources accessed 2026-11-15. The paper was verified against its arXiv record (identifier, authors, title, versions) and its AAAI proceedings record (volume, pages) on that date; the mechanism specification (retention formula, strength initialisation and reinforcement rule), the storage/retrieval design, the SiliconFriend setup, and all evaluation figures are from the paper's full text as accessed on that date.

- Zhong, W., Guo, L., Gao, Q., Ye, H., & Wang, Y. (2024). *MemoryBank: Enhancing Large Language Models with Long-Term Memory.* Proceedings of the AAAI Conference on Artificial Intelligence, 38(17), 19724–19731. arXiv:2305.10250. https://arxiv.org/abs/2305.10250
- Ebbinghaus, H. (1885/1964). *Memory: A Contribution to Experimental Psychology.* — the forgetting-curve source the paper builds on, as cited within it.
- Karpukhin, V., et al. (2020). *Dense Passage Retrieval for Open-Domain Question Answering.* arXiv:2004.04906 — the retrieval pattern MemoryBank adopts, as cited within it.
- Descendant systems in §5, as cited and verified in the banked dossier: `research/memory/agent-memory-architectures.md`, §§3–6, 8 (accessed 2026-11-15).

*End of dossier A8-2. Companion file: `bibliography-additions-memory-wave14.md` in the staging root carries this paper in corpus bibliography format.*
