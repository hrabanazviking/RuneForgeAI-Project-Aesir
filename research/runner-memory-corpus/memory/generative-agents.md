# OR-6 Dossier A8-1: Generative Agents — The Memory Stream, the Three-Factor Retrieval Score, and Reflection

> Research Forge campaign — commissioned by Volmarr, 2026-11-15.
> Domain: OR-6 (memory), Wave 14 — agent-memory ancestors. This dossier is the deep treatment of the ancestor that the banked descendant audit (`research/memory/agent-memory-architectures.md`, dossier A5) cites in its §4 but deliberately compresses. It extends that dossier; it does not repeat its taxonomy, its production survey, or its benchmark hygiene sections. Where this dossier and A5 overlap (the headline architecture, the ablation numbers), the overlap is the minimum needed to stand alone, and A5 is the governing text.
> Clean-room note: written in our own words. No source text is reproduced beyond short factual labels (component names, parameter values, scores as published). Every factual claim about the paper is cited to a source in §8, accessed 2026-11-15.

---

## 1. Full citation (as verified)

Park, J. S., O'Brien, J. C., Cai, C. J., Morris, M. R., Liang, P., & Bernstein, M. S. (2023). *Generative Agents: Interactive Simulacra of Human Behavior.* Proceedings of the 36th Annual ACM Symposium on User Interface Software and Technology (UIST '23), San Francisco, CA, USA. ACM. DOI: 10.1145/3586183.3606763. arXiv:2304.03442 [cs.HC] — submitted 7 April 2023 (v1), revised 6 August 2023 (v2). https://arxiv.org/abs/2304.03442

Verification, 2026-11-15: arXiv identifier, title, and six-author list checked against the arXiv record on that date; the coordinator's believed identifier (2304.03442) and venue (UIST 2023) both checked out. Affiliations as published: Stanford University (Park, O'Brien, Liang, Bernstein) and Google Research (Cai, Morris). The underlying model in the paper's implementation is ChatGPT (gpt-3.5-turbo). Code released by the authors at the project's public repository (linked from the paper).

**Essence.** The first complete, published architecture in which a language-model agent's long-horizon behaviour is carried entirely by an external, natural-language memory system: an append-only **memory stream** of everything the agent perceives and does, a **retrieval score** that fuses recency, importance, and relevance to decide what enters the prompt, periodic **reflection** that synthesises higher-level inferences from lower-level memories and writes them back into the same stream, and **planning** that turns retrieved memory into day-scale behaviour. Every later agent-memory system in this corpus either inherits one of these four mechanisms, replaces one of them, or exists to repair the damage one of them does (A5, §§3–6).

---

## 2. The problem as framed

The paper's question is not "how does a chatbot remember a user?" It is: **what does it take for a simulated person to remain believable over days of simulated life?**

Believable long-horizon behaviour, as the authors frame it, needs memory far beyond any context window, for three distinct reasons:

1. **Volume.** An agent that perceives its environment continuously accumulates experience at a rate no prompt can hold. Within simulated hours the raw record already exceeds the window; within days it exceeds it by orders of magnitude. Some selection mechanism is therefore not an optimisation but a precondition — the only question is what it selects *by*.
2. **Abstraction.** A person does not act on raw episodes alone. They act on conclusions drawn from episodes — "Klaus is absorbed in his research," "Maria values the café regulars" — and those conclusions, not the thousand observations beneath them, are what steer plans. A memory system that stores only episodes leaves the agent to re-derive its understanding of its world on every decision, or to act without one.
3. **Coherence over time.** Behaviour reads as believable when today's actions are visibly continuous with yesterday's experiences and intentions: the agent remembers the conversation, keeps the appointment it made, pursues the goal it formed. That continuity is a *retrieval* property — the right memory must surface at the right moment — and a *planning* property: intentions must themselves persist somewhere retrievable, or they evaporate at the next context reset.

The framing matters for how the rest of this dossier — and A5 — reads the paper. The success criterion is **believability as judged by human raters**, in a closed sandbox, over two simulated days, with 25 agents. It is not factual accuracy of recall, not consistency under contradiction, and not behaviour at production scale or duration. The authors are explicit that the town ("Smallville") is a demonstration vehicle for an architecture and an interaction pattern. Reading Generative Agents as a production memory design — rather than as the ancestor that *named the mechanisms* production designs now combine — is the single most common misreading of it, and A5's §4.1 already warns against it. This dossier keeps the warning and adds the mechanism-level detail A5 omitted.

One further framing point, because §5 turns on it: in Smallville, almost nothing an agent learns ever becomes *false*. Townsfolk do not move house, change jobs, or retract statements on a two-day horizon. The architecture therefore never has to answer the question the whole honesty literature turns on — *what happens when memory contradicts itself?* — and, as §5 shows, it contains no mechanism that could.

---

## 3. Core mechanism, in our own words

### 3.1 The memory stream

The store is a single append-only list of **memory objects**. Each object is a short natural-language description plus two timestamps: when it was created and when it was last accessed. Three kinds of content share the one stream, distinguished by type rather than by separate stores:

- **Observations** — the base layer. Everything the agent perceives: environmental events, other agents' actions and utterances, and the agent's own actions, each rendered as a natural-language sentence at perception time. Observations are the only entries that originate outside the model; everything else in the stream is model-written.
- **Reflections** — higher-level inferences synthesised from observations and earlier reflections (§3.3), written back into the stream as first-class entries.
- **Plans** — intentions generated by the planner (§3.4), likewise written back, so that a commitment made in the morning is retrievable context in the afternoon.

Each agent is seeded with a single paragraph of identity description (name, traits, occupation, relationships, current preoccupations) entered as initial stream content. There is no other persistent state: no profile table, no fact store, no separate persona store. Identity, experience, inference, and intention are one list, competing under one retrieval rule. Hold that fact for §6.1 — it is the precise point of contrast with this corpus's anchor law.

In A5's taxonomy (§2.1 there), the stream is episodic memory that also carries its own derived semantic products. The unification is elegant and, as A5 notes, a provenance hazard: a reflection sits in the stream with the same retrievability as an observation, separated only by its type tag and its cited evidence — neither of which the retrieval score in §3.2 consults.

### 3.2 Retrieval: the three-factor score

Because the stream outgrows the prompt almost immediately, every decision point retrieves a subset. Retrieval is a **ranking**, computed per memory object as a weighted sum of three components, each normalised to the range [0, 1] across the candidate set (min–max normalisation, as described in the paper), with **all three weights set to 1** in the paper's implementation — recency, importance, and relevance count equally:

- **Recency.** An exponential decay on the time since the memory was last *accessed* — not since it was created. The implementation's decay factor is **0.995 per simulated hour**, i.e. the recency component falls as 0.995 raised to the hours elapsed since last access. Two consequences follow, both load-bearing in §5: retrieval *refreshes* a memory (being used makes it young again), and an unretrieved memory fades from contention geometrically even if it is important — importance is a separate component and cannot rescue a memory whose recency has decayed if the other candidates dominate the sum.
- **Importance.** An integer score from **1 to 10**, assigned **by the language model itself at the moment the memory is created**, in response to a prompt asking it to rate the event's significance on a scale where mundane routine (brushing teeth, making the bed) sits at the bottom and life-turning events (a breakup, a college admission) at the top. Importance is therefore a write-time model judgement: fixed at creation, never revised, and only as calibrated as the model's intuitions about significance. It is the ancestor of every "salience score" in later systems — and of every failure in which the extractor's judgement, not the user's, decided what mattered.
- **Relevance.** Cosine similarity between an embedding of the memory text and an embedding of the current situation/query (the implementation uses a standard OpenAI embedding model of the period). This is the only component that depends on the present context; recency and importance are properties the memory carries with it.

The highest-scoring memories, up to the prompt's capacity, are placed in context, and the access timestamps of the retrieved set are updated — closing the rich-get-richer loop noted above.

Stated as a design pattern, which is how the field received it: **score = recency + importance + relevance, all normalised, equally weighted, rank and take the top.** A5 (§4.2) records the same formula; this dossier adds the normalisation and the access-based (not creation-based) recency clock, because both details matter to the inheritance audit: most descendants kept the three signals but changed exactly these two properties (creation-based decay, learned or tuned weights).

### 3.3 Reflection: the tree, the trigger, the citations

Reflection is the architecture's consolidation step — episodic → semantic, in A5's §2.3 vocabulary — and the most original mechanism in the paper.

- **Trigger.** Reflection is not continuous. The agent reflects when the **sum of the importance scores of its recently perceived events exceeds a threshold — 150 in the implementation** — which in practice fires roughly **two to three times per simulated day**. Importance thus does double duty: it ranks memories for retrieval, and its accumulation meters how much "has happened" since the agent last made sense of its experience.
- **Procedure.** On triggering, the agent takes its most recent memories (the implementation works from the 100 most recent stream entries) and prompts the model to name the most salient high-level questions those memories raise. For each question, it retrieves the stream entries relevant to that question, then prompts the model to draw inferences from them — each inference required to **cite the specific memory entries it was drawn from**. The inferences are written into the stream as reflection objects.
- **The reflection tree.** Because reflections are stream entries, they can themselves be retrieved as evidence for later reflections. The result is a tree: observations at the leaves, first-order reflections above them, and increasingly abstract conclusions ("Klaus is deeply committed to his research topic") at the top, each level retrievable by the same §3.2 score and usable by the planner. Abstraction compounds: the agent's operative picture of its world is mostly reflections about reflections, several model-inferences removed from anything it actually perceived.

The citation requirement is the paper's one honesty mechanism, and its limits define the honesty discussion in §5: a citation lets an *auditor* check a reflection against its evidence. It does nothing for the *acting agent*, which retrieves the reflection by score and uses it as context without re-walking its citations. Provenance is recorded; it is not enforced at read time.

### 3.4 Planning

Planning converts memory into behaviour at three scales. The agent first generates a **day plan** in broad strokes (a handful of agenda items seeded by its identity paragraph and a summary of the previous day), then **decomposes it recursively** — day into hour blocks, hour blocks into short action segments — retrieving memories and reflections as context at each step. Execution is reactive: when the agent perceives something that warrants a response (a conversation opening, an unexpected event), it decides whether to **react** — interrupting and revising the current plan segment — or to continue. Completed and revised plans live in the stream (§3.1), so planning is both a consumer and a producer of memory.

Planning is dossiered here for completeness and because the ablation (§4) prices it separately; its durable inheritance is narrower than the other three mechanisms (§5).

### 3.5 The loop, assembled

Perceive → append observation (model scores its importance) → importance accumulation crosses threshold → reflect (questions → retrieval → cited inferences → append reflections) → plan from retrieved set → act → perceive. Every stage reads and writes the same stream through the same score. The architecture's unity is its beauty and, §5 argues, its structural defect: there is exactly one store, one ranking, and no operation anywhere in the loop whose job is to decide that something in the stream is *no longer true*.

---

## 4. Reported results, as reported

**Evaluation method, stated plainly first.** Both evaluations in this paper measure **believability as judged by humans (and, for the open run, by observed emergent behaviour)**. Neither measures factual consistency, recall precision against a ground-truth record, or contradiction handling. A confidently wrong memory can score *well* under this method if it produces coherent behaviour. Every number below inherits that caveat.

### 4.1 The ablation (the paper's controlled evaluation)

Agents were "interviewed" — probed with questions testing self-knowledge, memory of past events, planning, reaction, and reflection — under five conditions: the **full architecture**; **no reflection**; **no reflection and no planning**; **observation-only** ablations down to a fully ablated agent that perceives but retains nothing usable; and a **human crowdworker baseline**, in which crowdworkers role-played the agents' behaviour by hand. Human raters ranked the believability of the agents' interview responses; rankings were summarised with **TrueSkill**. Reported means (μ), as published and as already carried in A5 §4.3:

| Condition | TrueSkill μ (as reported) |
| --- | --- |
| Full architecture | ≈ 29.89 |
| No reflection | ≈ 26.88 |
| No reflection, no planning | ≈ 25.64 |
| Human crowdworker baseline | ≈ 22.95 |
| Full ablation | ≈ 21.21 |

Read as the paper reads it: **each component contributes**. Removing reflection costs believability; removing planning as well costs more; the full architecture beats even humans hand-writing the behaviour — a result about the *tedium and inconsistency of hand-simulation* as much as about the architecture, and the paper's own framing treats the crowdworker condition as a baseline, not a rival. The ordering, not the absolute values, is the finding: observation alone is not enough, consolidation (reflection) is worth measurable believability, and planning on top of reflection is worth more.

### 4.2 The open two-day simulation (the emergent-behaviour demonstration)

Twenty-five agents ran unguided for two simulated days from seed paragraphs plus one injected intention: one agent (Isabella) was seeded with the goal of hosting a Valentine's Day party. As reported: knowledge of the party **spread from 4% of agents (the seed) to 52%** by the end of the run (knowledge of the mayoral candidacy, the run's other tracked item, spread 4% → 32%); the density of the agents' relationship network rose over the run (reported from 0.167 to 0.74); and of the agents invited to the party, a subset coordinated and actually attended at the right place and time (reported as 5 of 12 invited). Agents also formed new relationships, held conversations that referenced earlier ones, and maintained day-scale routines recognisably continuous with their seed identities.

What this establishes, at most: the architecture sustains *socially coherent multi-agent behaviour* over days with no scripting beyond the seeds. What it does not establish is listed in A5 §4.3 and repeated here because §5 depends on it: nothing about recall *accuracy* (no ground-truth audit of what agents "remembered" versus what happened), nothing about months-long streams, nothing about cost viability — the authors themselves report the full runs cost **thousands of dollars in tokens and multiple days of wall-clock time** for 25 agents over two simulated days.

### 4.3 Failure observations the paper itself reports

The authors document, and this dossier underlines: agents sometimes **fail to retrieve** a memory they demonstrably perceived; sometimes retrieve a **fragment** — a detail detached from its event; and sometimes produce behaviour resting on **embellished or invented** recollection, with reflection the usual source (see §5.2). These are reported qualitatively, not as rates. There is no error-rate table for memory correctness in this paper, because memory correctness is not what it measures.

---

## 5. The inheritance audit

Method: the left column is this paper's mechanisms; the middle is their fate in the modern systems as established by the banked dossier A5 (Letta/MemGPT lineage, ChatGPT memory, Mem0, Zep/Graphiti); the right column is this dossier's judgement, with inference marked as inference.

### 5.1 Mechanism by mechanism

| Mechanism (2023) | Fate in modern systems (per A5) | Judgement |
| --- | --- | --- |
| Append-only natural-language episodic stream | **Survives, generalised.** Letta's recall store is the production descendant (A5 §4 intro, §3.2); ChatGPT's reference-chat-history and Mem0's episode inputs are the same idea behind product boundaries; Graphiti keeps raw *episodes* verbatim as provenance (A5 §6.2c). | The stream won. What changed is that serious systems stopped letting the stream be the *only* store. |
| Three-factor retrieval score (recency + importance + relevance) | **Survives, nearly intact, everywhere.** A5 §2.3 names the production ranking signals: embedding similarity, recency/decay, importance, graph distance, lexical match — the paper's three, plus two. Weights are now tuned or learned rather than fixed at 1, and recency is usually creation-based rather than access-based [inference: a simplification made because access-based recency's rich-get-richer loop is a staleness hazard, §5.2]. | This is the paper's most complete inheritance. Scored retrieval is now so universal it is invisible — which is precisely why the contradiction theorem (§5.3) applies so widely. |
| Write-time model-assigned importance (1–10) | **Survives, transformed.** Extraction pipelines (Mem0, ChatGPT) make the significance judgement at write time inside the extractor rather than as an explicit numeric rating; Letta's agent makes it implicitly when it chooses what to file. The explicit 1–10 scale largely disappeared [inference: because an uncalibrated integer from the writing model proved a weak signal next to retrieval-side relevance]. | The *judgement* survived; the *number* did not. |
| Reflection (scheduled, cited, tree-forming consolidation) | **Survives as a pattern, renamed, and staffed differently.** See §5.2 — the headline answer. | — |
| Plans written back as memories | **Mostly dropped** in conversational memory systems; survives in agent frameworks as task/state persistence rather than as stream entries. [Inference: because a personal assistant's intentions are the *user's*, held in task systems, not the agent's own simulated intentions.] | The narrowest inheritance — correctly so; it was the mechanism most specific to simulated persons. |
| One unified store for identity + episode + inference | **Dropped, deliberately, by the strongest descendants.** Letta splits core/recall/archival precisely so identity does not compete with episodes (A5 §3.2–3.3); Graphiti separates episodes from derived edges; ChatGPT separates saved memories from chat history. | The field's verdict on the unified stream is the anchor law (§6.1): unification was the simplification to outgrow. |

### 5.2 The headline question: does anything modern keep reflection?

**Yes — reflection is the ancestor mechanism with the strongest living descendants, but it survives under new names and with its authority demoted.** Per A5:

- **Letta's sleep-time compute** (A5 §3.4) is reflection productionised: a background agent re-reads transcripts while the primary agent idles, consolidates near-limit blocks, files material into archival storage, and in stronger descriptions invalidates contradicted archival records. Same operation — batch, model-written consolidation of episodes into durable form — moved off the critical path and given a separate worker.
- **ChatGPT's automatic memory management and rolling summary** (A5 §5.2) are reflection with the citations and the inspectability removed: continuous background re-synthesis of the user's profile from episodes. A5 names the cost exactly — summary drift (§5.4.6 there) is reflection fabrication at production scale, *with no citations to check*, i.e. the modern version kept the mechanism and dropped its one honesty mitigation.
- **Mem0's consolidation phase** (A5 §5.3) is reflection narrowed to a decision: new facts are compared against retrieved neighbours and resolved as add / update / delete / no-op. Less generative than Park et al.'s open-ended inference, and for that reason safer — it synthesises *decisions about facts* rather than new narrative conclusions.

What no modern system kept: the **reflection tree as a retrievable object** — multi-level model inferences, themselves evidence for further inferences, retrieved with observation-level authority. [Inference:] the tree died because its failure mode is compounding: each level multiplies the fabrication surface while the citation trail grows too long for any read-time check. Modern consolidation is kept *one level deep* — episodes → facts/summary — and the derived products are typed as derived (A5 §6.4.6's approval tiers make exactly this a rule). Reflection survived by being flattened and demoted: from the agent's way of *understanding its world* to a background *housekeeping* operation whose outputs are labelled as second-class records.

### 5.3 Judged against the corpus's honesty standard

The corpus's standard (A5 §6): a memory store is honest only if supersession is **non-destructive and auditable** — the mechanism that meets it is **bi-temporal invalidation** (Graphiti pattern): the old fact is closed, not deleted; the new fact points at it; both remain queryable with their validity intervals and provenance.

Generative Agents, judged against that standard, fails it completely — and instructively, because the failure is architectural, not incidental:

1. **The stream is append-only with no supersession operation at all.** There is no write in the architecture that means "this earlier entry is no longer true." A correction can only be *another entry*, competing with the entry it corrects under the §3.2 score.
2. **The score is a salience ranking, not a truth predicate** — A5 §6.1's exact point. Recency rewards *access*, so a stale memory that keeps being retrieved out-competes the correction that replaced it; importance was fixed at write time by a model that could not know the fact would change; relevance measures topical similarity to the present moment, which a superseded fact often matches *better* than its successor (it was phrased in the vocabulary of the situation that produced it).
3. **Therefore the corpus's theorem applies to this architecture in its purest form:** *append-only store + retrieval ⇒ eventual contradiction* (A5 §6.1, §6.6). Generative Agents is, in A5's words, the theorem's cleanest early exhibit. In a two-day simulation almost no fact changes, so the theorem has no time to bite; run the identical architecture as a personal agent for a year and it bites with probability approaching certainty. The paper cannot be faulted for not solving a problem outside its frame — but any modern system that adopts the stream-plus-score design *without* adding a supersession mechanism has adopted the theorem's premises and will meet its conclusion. Several have (A5 §5.5).

Reflection compounds the verdict rather than softening it: a reflection drawn partly from a since-superseded observation is not itself superseded when the observation is corrected — the architecture has no dependency tracking between stream entries except the citation lists, which nothing consults at write or read time. Invalidation in Graphiti propagates because edges are first-class; in the stream, a reflection is just more text.

---

## 6. Applicability

### 6.1 The anchor law, read against Generative Agents — the corpus's design position

*[This subsection states this programme's own design position, labelled as ours. It is not a claim about the paper's intent.]*

Volmarr's anchor law, as enforced in this programme's Voxta/Aesir work and generalised in A5 (§3.3, §6.4.5): **the character prompt — who is speaking — sits in a pinned, unpushable anchor at a fixed position in memory; it is never retrieved, never scored, never evicted, and never silently rewritten; resident character context is not reprocessed each turn.** Identity is not a retrieval problem.

Generative Agents is the exact counter-design, and the contrast is worth drawing precisely because the paper's agents *feel* so continuous:

- In Smallville, the agent's identity is **one seed paragraph inside the same scored stream as everything else**. It has no tier, no pin, no budget protection. It stays influential only insofar as it keeps winning retrieval — helped by being constantly relevant and frequently accessed, but guaranteed nothing. Scale the stream to a year and thin the seed's access frequency, and the architecture contains no mechanism that would notice the agent's identity quietly falling out of its own context.
- Identity *change* is equally unguarded: a reflection can synthesise a conclusion about the agent itself ("I am someone who…"), enter it in the stream with full standing, and steer behaviour thereafter — an unapproved, unwitnessed self-edit of the persona by the consolidation process. A5 §6.4.5 names the rule this violates: extractors and reflections may *propose* anchor changes; they may not commit them.
- The modern field has already voted on this contrast: Letta's `persona` block — always in prompt, size-bounded, edited only by explicit recorded tool calls — *is* the anchor law arrived at independently from the production side (A5 §3.3). The distance from Park et al.'s unified stream to Letta's pinned core block is the distance this corpus's own position travels, and it was travelled by both programmes for the same reason: **what must never be lost must never be left to compete.**

Our position, stated once and plainly: Generative Agents proves a scored stream is sufficient for *believable* identity over days. The anchor law exists because believable-over-days is not the requirement; *faithful-over-years, under contradiction, with the user able to inspect and correct* is. For that requirement the stream is the episodic layer — valuable, kept — and identity moves out of it into a pinned, versioned, approval-gated anchor. The ancestor supplies the stream; it must not be allowed to supply the constitution.

### 6.2 What a personal-agent build should still take from this paper

- The **three-signal ranking** as the read path's starting point — with creation-based recency, tuned weights, and (per A5 §6.3) a read-time tombstone filter the ancestor never had.
- **Cited consolidation**: any reflection-style pass in our builds keeps Park et al.'s citation requirement *and* enforces it — derived records carry their evidence ids as data (A5 §6.4.3), not as prose.
- The **importance-accumulation trigger** as a scheduling idea for sleep-time consolidation: reflect when enough has happened, not on a wall-clock timer. [Engineering judgement, ours:] importance-sum is a better consolidation trigger than elapsed time for bursty personal-agent workloads, and it is the one scheduling mechanism in the paper no descendant appears to have kept — an unclaimed inheritance worth taking.

---

## 7. Cross-links

- **Descendant audit:** `research/memory/agent-memory-architectures.md` (A5) — §4 is the compressed treatment this dossier expands; §§5–6 are the modern-systems and honesty analysis this dossier's §5 audit is built from; §6.2(c) states the bi-temporal standard §5.3 judges against; §7 carries the applicability to the Ollama/Aesir builds.
- **MEMORY-COMPENDIUM, agent-memory chapter (Chapter 7):** the compendium's §7.4 already synthesises A5's compressed account of this paper. What Wave 14 adds to that chapter: the retrieval score's normalisation and access-based recency clock (§3.2 here), the reflection trigger arithmetic and tree mechanics (§3.3), the crowdworker-baseline context for the ablation numbers (§4.1), and the inheritance audit's two headline findings — reflection survives flattened and demoted (§5.2), the unified store was deliberately abandoned by the strongest descendants (§5.1). A compendium revision should also carry §6.1's anchor contrast, which sharpens the chapter's existing anchor material with its counter-design.
- **IDEA-LEDGER Q18 (read-time tombstone filtering):** Q18 asks whether injection-time filtering against tombstones/superseded versions is required for correctness, the gap being that no surveyed system documents it (A5 §6.3). This dossier adds the ancestor evidence: the gap is *original*, not a modern oversight — the founding architecture retrieves by score alone, updates access timestamps on retrieval (actively *reinforcing* whatever it served, stale or not), and consults no validity state at read time. A read path designed in 2023's image inherits the hole by default; Q18's settle-by-design-decision stands, now with the note that "do what the field does" is not an available answer, because what the field does descends from a design that never faced the question.
- **Companion ancestor dossier:** `research/memory/memorybank.md` (Wave 14) — the forgetting ancestor; §6 of that dossier takes up the decay question this dossier's §5.3 leaves open (what, if anything, should ever *fade*?).

---

## 8. Sources

All sources accessed 2026-11-15. The paper was verified against its arXiv record (identifier, authors, title, versions) on that date; mechanism parameters (decay factor, importance scale, reflection threshold, normalisation, weights) are as described in the paper and as already carried, in compressed form, in the banked dossier A5, whose §8 verification notes cover the same record.

- Park, J. S., O'Brien, J. C., Cai, C. J., Morris, M. R., Liang, P., & Bernstein, M. S. (2023). *Generative Agents: Interactive Simulacra of Human Behavior.* Proceedings of UIST '23. arXiv:2304.03442. https://arxiv.org/abs/2304.03442 — DOI: 10.1145/3586183.3606763.
- Packer, C., et al. (2023/2024); Chhikara, P., et al. (2025); Rasmussen, P., et al. (2025); OpenAI Help Center memory documentation — the descendant systems of §5, as cited and verified in the banked dossier: `research/memory/agent-memory-architectures.md`, §§3, 5, 6, 8 (accessed 2026-11-15).

*End of dossier A8-1. Companion file: `bibliography-additions-memory-wave14.md` in the staging root carries this paper in corpus bibliography format.*
