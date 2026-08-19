# Project A.E.S.I.R. Future Integration Roadmap

> **Living idea vault for future capabilities, experiments, integrations, and related projects**
>
> **Project:** RuneForgeAI Project A.E.S.I.R.  
> **Expanded name:** Advanced Edge System for Interface and Response  
> **Design theme:** Small models. Big systems. Local sovereignty.  
> **Created from:** Volmarr's Project A.E.S.I.R. design discussion, August 19, 2026  
> **Status:** Vision and planning document, not a statement of currently implemented capabilities

---

## 1. Purpose of This Document

This document collects and organizes the larger set of ideas intended to eventually connect with **Project A.E.S.I.R.** without forcing all of them into the core inference engine at once.

The central goal is to preserve the ideas while keeping development disciplined. Project A.E.S.I.R. should remain useful as a lean local inference engine even when every optional system is disabled. More advanced capabilities should attach through clean interfaces, capability flags, plugins, companion services, or higher-level clients.

This document is therefore both:

- a **future roadmap** for Project A.E.S.I.R.;
- an **idea vault** for concepts that should not be forgotten;
- an **integration map** for older RuneForgeAI experiments;
- a guardrail against recreating an overgrown monolith;
- a place to capture ambitious ideas before they are ready for implementation.

For current implementation truth, use the repository's existing [`CAPABILITY_LEDGER.md`](./CAPABILITY_LEDGER.md). This file describes direction and possibilities rather than claiming that a capability already exists.

---

## 2. North-Star Vision

### 2.1 Small Models, Big Systems

A.E.S.I.R. should explore how a relatively small local model can become dramatically more capable when it is surrounded by efficient external systems for:

- persistent memory;
- structured world state;
- model routing;
- specialized submodels;
- retrieval;
- tools;
- agent coordination;
- speech;
- persistent personality;
- task state;
- optional simulation and roleplay systems.

The individual model does not need to contain the entire mind of the system.

The model can perform the reasoning that is best handled by a neural network while A.E.S.I.R. handles durable state, memory, orchestration, routing, and interfaces outside the context window.

**Core principle:** move as much reusable cognition as practical out of repeated token inference and into efficient structured systems.

### 2.2 Local Sovereignty

A.E.S.I.R. should remain centered on AI that people can actually own and operate themselves.

The target is not merely high-end gaming desktops. The architecture should scale across a hardware spectrum:

```text
Raspberry Pi / SBC
        ↓
Low-power mini PC
        ↓
Laptop / integrated GPU
        ↓
Consumer gaming GPU
        ↓
Multi-device local system
        ↓
Optional distributed nodes
```

A low-power system should still receive a useful experience. More powerful hardware should increase capability rather than being a prerequisite for basic usefulness.

### 2.3 Affordability as an Engineering Constraint

Efficiency is not only a benchmark target. It is an accessibility feature.

A.E.S.I.R. should favor designs that reduce:

- required RAM;
- required VRAM;
- repeated context tokens;
- unnecessary model invocations;
- idle power use;
- unnecessary background services;
- duplicated memory across components;
- dependency on expensive cloud inference;
- the number of separate applications needed for a complete local AI system.

The long-term ideal is a system capable enough to feel substantial while remaining usable by people with modest hardware and limited budgets.

---

## 3. Architectural Rules for Future Expansion

A.E.S.I.R. already uses a Mythic Engineering architecture organized into distinct realms. Future capabilities should extend those boundaries rather than blur them.

### Existing architectural realms

| Realm | Responsibility | Future expansion direction |
|---|---|---|
| **Midgard** | User/client domain | CLI chat, terminal coding client, voice clients, roleplay clients, external applications |
| **Bifrost** | Transport and interface layer | Ollama-compatible API, additional compatibility APIs, streaming, local IPC, remote-node transport |
| **Asgard** | Orchestration | Model routing, agent coordination, personality runtime, tool selection, context assembly |
| **Nidavellir** | Compute | Mojo inference kernels, quantized compute, hardware dispatch, acceleration, efficient primitives |
| **Mímisbrunnr** | Memory | KV cache, RAG, persistent memory, world state, second-brain storage, cognitive state |

### Expansion rules

1. **The core inference path must remain usable by itself.**
2. **Advanced features should be optional whenever practical.**
3. **Performance-critical paths belong in Mojo when Mojo provides a meaningful advantage.**
4. **Higher-level clients may use Python or other languages when ecosystem flexibility matters more than raw speed.**
5. **One canonical component should own each kind of state.** Avoid multiple competing memory authorities.
6. **Components communicate through explicit interfaces rather than hidden shared assumptions.**
7. **Experimental capability must not be described as production capability.**
8. **Hardware-specific acceleration should degrade gracefully to available hardware.**
9. **Old projects should be mined for useful concepts and components, not merged wholesale.**
10. **A feature should justify its RAM, compute, token, maintenance, and complexity costs.**

---

## 4. Capability Track A: Extreme Edge Inference Efficiency

This remains the foundation under everything else.

### Goal

Make local model inference as fast, memory-efficient, and hardware-flexible as practical, with special attention to small and inexpensive devices.

### Design directions

- Continue the bare-metal Mojo approach for the inference hot path.
- Minimize unnecessary memory copies.
- Reuse pre-allocated memory wherever practical.
- Keep token-generation paths free of avoidable allocation churn.
- Support efficient quantized model execution as the implementation matures.
- Allow capability-aware CPU, GPU, NPU, and other accelerator dispatch.
- Keep model loading and residency strategies conscious of low-memory hardware.
- Benchmark memory use as seriously as tokens per second.
- Include low-power hardware in development targets rather than treating it as an afterthought.

### Raspberry Pi / SBC profile

A Raspberry Pi class device is an important philosophical and engineering target.

A.E.S.I.R. should eventually be able to recognize that it is running on constrained hardware and automatically favor:

- smaller models;
- lower-memory inference modes;
- fewer simultaneous model residents;
- compact context;
- aggressive external memory retrieval rather than giant prompts;
- task-specific routing;
- lower-overhead services;
- CPU-friendly kernels;
- optional offloading to another local node when available.

The Pi does not have to imitate a large GPU workstation. It should operate intelligently within its own resource envelope.

---

## 5. Capability Track B: Model Routing and Small-Model Cognitive Swarms

### Core idea

Instead of expecting one large model to perform every cognitive task, A.E.S.I.R. should be able to coordinate a rapid sequence or small swarm of specialized models.

A system using several inexpensive small models may sometimes achieve a better capability-per-watt or capability-per-gigabyte ratio than repeatedly invoking one much larger general model.

### Possible roles

A routing layer could distinguish work such as:

- conversational response;
- planning;
- coding;
- summarization;
- extraction;
- classification;
- memory selection;
- retrieval query generation;
- world-state updates;
- tool selection;
- reflection or verification;
- roleplay narration;
- character dialogue.

### Routing patterns

#### Sequential routing

```text
User Input
   ↓
Intent / Task Router
   ↓
Specialist Model
   ↓
Verifier or Formatter
   ↓
Response
```

#### Parallel specialist routing

```text
                 ┌→ Coding Specialist ─┐
Input → Router ──┼→ Memory Specialist ─┼→ Arbiter → Output
                 └→ Planning Specialist┘
```

#### Escalation routing

Start with the smallest appropriate model. Escalate only when confidence, complexity, or failure conditions justify a more expensive model.

```text
Tiny Model → Small Model → Medium Model → Large/Remote Model
     use only as much inference as the task actually needs
```

### Shared-state rule

Specialist models should not each rebuild the entire conversation and world state from raw text.

They should receive concise task-specific context assembled from a shared memory/state layer.

This is one of the main mechanisms by which smaller models can punch above their individual weight.

---

## 6. Capability Track C: Yggdrasil-Style Cognitive Memory and Second Brain

### Design lineage

The memory concepts first explored in the Norse Saga Engine and related Yggdrasil-style cognition experiments should be revisited as a cleaner, modular A.E.S.I.R. capability.

The intention is not to transplant the old system unchanged. The old work is an **idea mine**.

### Goal

Reduce dependence on the model's finite context window by maintaining durable memory outside the model.

### Memory classes worth exploring

- **Working memory:** active facts required for the current task.
- **Episodic memory:** things that happened during previous interactions.
- **Semantic memory:** durable facts, concepts, preferences, documentation, and learned knowledge.
- **Procedural memory:** reusable workflows and instructions.
- **Project memory:** repository state, design decisions, unresolved work, architecture, and task history.
- **Relationship/personality memory:** optional continuity for persistent companions and roleplay agents.
- **World memory:** entities, locations, objects, relationships, events, and environmental state.

### Memory pipeline concept

```text
Incoming Interaction
        ↓
Memory Relevance / Classification
        ↓
┌───────────────────────────────┐
│ Working / Episodic / Semantic│
│ Project / World / Persona    │
└───────────────────────────────┘
        ↓
Compact Retrieval
        ↓
Context Composer
        ↓
Model
```

### Desired properties

- persistent across model changes;
- model-agnostic;
- queryable without loading an LLM when possible;
- cheap to update;
- capable of storing structured and unstructured information;
- able to summarize or compact old material;
- able to expose only the most relevant information to the active model;
- inspectable and editable by the user;
- capable of operating completely locally.

### Why this matters for small models

A small model should not have to repeatedly infer facts that the system already knows.

External memory can reduce:

- repeated prompt tokens;
- context-window pressure;
- hallucinated continuity;
- model-size dependence for long-term recall;
- repeated reasoning over stable information.

---

## 7. Capability Track D: Structured World Modeling

### Core idea

A.E.S.I.R. should eventually support an optional explicit world/state model outside the language model.

This does **not** have to be limited to games or fictional worlds. A world model can represent any persistent environment the AI needs to reason about.

### Possible world-state entities

```text
People / Agents
Projects
Files
Repositories
Tasks
Devices
Locations
Objects
Services
Events
Relationships
Resources
Goals
Rules
Time / Timeline
Environment State
```

### Example: coding world state

Instead of injecting an enormous conversation history, A.E.S.I.R. could maintain compact structured facts such as:

```yaml
project: Project Aesir
active_branch: feature/model-router
current_goal: implement routing interface
blocked_by:
  - benchmark harness incomplete
recent_decisions:
  - keep inference hot path in Mojo
  - clients may remain language agnostic
active_files:
  - aesir.mojo
  - core/router.mojo
```

The model receives the relevant state rather than the entire history that produced it.

### Benefits

- better continuity;
- fewer repeated tokens;
- less dependence on raw chat history;
- cheaper inference;
- clearer agent coordination;
- persistent understanding of objects and relationships;
- easier simulation of consequences over time;
- more reliable roleplay and game worlds;
- useful state tracking for coding, research, household assistants, and autonomous agents.

### Relationship to memory

Memory answers: **What has happened or been learned?**

World state answers: **What is true right now?**

The two systems should communicate but should not be collapsed into one ambiguous store.

---

## 8. Capability Track E: Persistent Agentic Personality

### Goal

Allow A.E.S.I.R. to host persistent AI companions or agents whose identity exists above any single model checkpoint.

This makes it possible to change the underlying model without completely replacing the agent.

### Personality package concept

A personality package could contain optional layers such as:

- identity and role;
- behavioral instructions;
- speaking style;
- interests;
- relationship context;
- personal history;
- values;
- current goals;
- long-term memories;
- emotional or mood state if the selected character system uses one;
- tool permissions;
- world-state relationships;
- preferred model or model-routing rules.

### Separation of concerns

```text
Underlying LLM
     +
Persona Definition
     +
Persistent Memory
     +
World State
     +
Tools
     +
Model Router
     =
Persistent A.E.S.I.R. Agent
```

The personality should not require the entire persona definition and life history to be re-sent verbatim on every turn if the system can represent portions more efficiently.

### Potential use cases

- personal AI companion;
- coding partner;
- research agent;
- game master;
- roleplay character;
- household assistant;
- persistent autonomous local agent;
- specialist members of a multi-agent team.

---

## 9. Capability Track F: Optional Roleplay and Game Simulation Layer

### Source material

The Norse Saga Engine contains years of accumulated experiments, including systems that may be useful to future A.E.S.I.R. roleplay and simulation capabilities.

**Do not merge the Norse Saga Engine wholesale.**

Instead:

1. identify isolated subsystems;
2. document what problem each subsystem solved;
3. discard redundant or convoluted implementation;
4. redesign the useful concept against the new A.E.S.I.R. interfaces;
5. port only what earns its place.

### Possible optional game capabilities

- persistent characters;
- NPC memory;
- relationships;
- factions;
- locations;
- inventory and objects;
- quest/task state;
- time progression;
- event systems;
- rules engines;
- dice and probability systems;
- scene state;
- consequences and causality;
- narrative memory;
- procedural world events;
- world simulation between conversations.

### Why it belongs above the core

The inference engine should never need RPG systems to function.

The roleplay layer should consume generic capabilities such as:

- memory;
- world state;
- model routing;
- tools;
- structured events;
- persistent personas.

This allows the same underlying technology to support both an RPG world and a non-fiction personal assistant.

---

## 10. Capability Track G: Pluggable Speech-to-Text and Text-to-Speech

### Goal

Voice should become another first-class interface rather than a separate unrelated application.

A.E.S.I.R. should eventually be able to connect to multiple STT and TTS engines through common interfaces.

### Speech-to-text interface

Potential backends may include local Whisper-family implementations and other future engines.

Conceptual interface:

```text
Audio Input
    ↓
STT Adapter
    ↓
Normalized Transcript
    ↓
A.E.S.I.R. Conversation / Agent Runtime
```

### Text-to-speech interface

Potential backends may include Piper, Kokoro, or other local engines according to platform support and user preference.

```text
A.E.S.I.R. Response
    ↓
TTS Adapter
    ↓
Selected Voice Backend
    ↓
Audio Output
```

### Requirements

- backend selection through configuration;
- local-first operation;
- streaming where practical;
- voice-engine failure should not break text interaction;
- low-power backends for SBC use;
- higher-quality backends for stronger hardware;
- no hard dependency on one speech project.

### Future personality integration

Persistent agents could optionally store a preferred voice profile separately from their language model and text personality.

---

## 11. Capability Track H: Standalone Chat Experience

A.E.S.I.R. should be usable without requiring a separate chat application.

### Minimum local chat experience

- load/select model;
- interactive terminal chat;
- streaming output;
- system/persona selection;
- memory on/off;
- model-routing on/off;
- world-state on/off;
- voice on/off when installed;
- session save/load;
- basic runtime statistics.

### Philosophy

The standalone client should be lightweight enough that users can test and use A.E.S.I.R. immediately, while external clients remain free to connect through APIs.

---

## 12. Capability Track I: Terminal-Based Vibe Coding Client

### Existing project direction

The existing terminal-based vibe coding project should be reconsidered as a **client and development environment that can sit on top of A.E.S.I.R.**, rather than being forced to contain the whole AI stack itself.

### Language strategy

Keeping much of this client in Python can be an advantage because Python has an enormous developer-tooling ecosystem.

The performance-critical inference runtime can remain in Mojo.

This creates a deliberate split:

```text
Python / flexible client ecosystem
             ↓
       clean protocol/API
             ↓
Mojo / performance-critical A.E.S.I.R. runtime
```

### Backend-agnostic design

The coding client should ideally be able to connect to:

- Project A.E.S.I.R.;
- Ollama;
- other local inference servers;
- compatible remote APIs when explicitly configured.

A.E.S.I.R. should be the preferred high-performance local backend, not an artificial lock-in requirement.

### Future coding-agent capabilities

- repository state tracking;
- file search;
- project memory;
- task ledger;
- model routing by coding task;
- planner/coder/reviewer specialization;
- terminal execution through explicit tools;
- persistent architectural decisions;
- compact working-set context rather than entire-repository prompt dumps.

The world-model and second-brain systems could become especially useful here because a coding agent operates inside a persistent world consisting of files, branches, tests, dependencies, decisions, and goals.

---

## 13. Capability Track J: Compatibility and Open Interfaces

### Core principle

A.E.S.I.R. should be fast without becoming an island.

### Compatibility targets

- preserve Ollama-style compatibility where useful;
- consider additional widely used API shapes where they improve interoperability;
- keep internal interfaces separate from public compatibility layers;
- expose capability discovery so a client can ask what the runtime supports;
- allow optional features without requiring clients to understand all of them.

### Capability discovery concept

```json
{
  "inference": true,
  "streaming": true,
  "memory": true,
  "world_model": false,
  "model_router": true,
  "stt": false,
  "tts": true,
  "distributed_nodes": false
}
```

This allows clients to adapt rather than assume every installation is identical.

---

## 14. Capability Track K: Multi-Device Local Intelligence

A.E.S.I.R. should treat multiple devices as a potential cooperative system rather than assuming that every capability must run on one machine.

### Example local topology

```text
Raspberry Pi
  ├─ persistent memory
  ├─ orchestration
  ├─ low-power always-on agent
  └─ lightweight model
        │
        │ LAN / private network
        ▼
Laptop / Desktop GPU
  ├─ larger model
  ├─ heavy embeddings
  ├─ speech synthesis
  └─ accelerated inference
```

### Scheduling ideas

A device coordinator could eventually route based on:

- available RAM/VRAM;
- model residency;
- current load;
- expected latency;
- power constraints;
- device capabilities;
- privacy policy;
- whether the task can wait;
- whether the task requires a specific accelerator.

### Graceful behavior

If the stronger node disappears, the Pi should retain core memory/state and fall back to the capabilities it can perform locally.

The system should degrade rather than collapse.

---

## 15. Capability Track L: Distributed and Volunteer Inference

### Status

**Long-term speculative integration. Not a current implementation priority.**

### Vision

A future ecosystem could allow idle devices across the internet to contribute inference or compute capacity, conceptually similar to volunteer computing or time-sharing.

A.E.S.I.R. does not need to build the global network itself.

A more realistic future role is to provide an optional integration layer if a credible distributed inference ecosystem emerges.

### Possible future architecture

```text
Local A.E.S.I.R.
      ↓
Distributed Compute Adapter
      ↓
Trusted / Selected Remote Nodes
      ↓
Returned Compute Result
```

### Hard problems that must be solved elsewhere or explicitly addressed

- trust;
- malicious nodes;
- privacy;
- encrypted or privacy-preserving computation;
- model-weight licensing;
- heterogeneous hardware;
- unreliable nodes;
- bandwidth;
- latency;
- result verification;
- compensation or reciprocity;
- abuse prevention;
- secure sandboxing.

### Design rule

Do not burden the local core with this complexity now.

Keep the architecture open enough that a future distributed backend could be added without redesigning the entire system.

---

## 16. Capability Track M: Plugin and Feature-Toggle Architecture

A.E.S.I.R. should support **opt-in power**.

### Principle

Users should not pay the resource cost of features they do not use.

A basic installation might be:

```text
Inference + CLI/API
```

A larger installation might become:

```text
Inference
+ Persistent Memory
+ World Model
+ Model Router
+ Agent Personality
+ Voice
+ Coding Tools
+ RPG Simulation
+ Multi-Device Compute
```

### Plugin requirements

A plugin or optional module should declare:

- name;
- version;
- capability provided;
- dependencies;
- memory requirements;
- hardware requirements;
- configuration schema;
- interfaces consumed;
- interfaces exposed.

### Core safeguard

Optional modules should not silently inject themselves into the generation hot path.

The orchestrator should explicitly compose enabled capabilities.

---

## 17. Reusing Older RuneForgeAI Projects Without Importing Their Complexity

### 17.1 Norse Saga Engine

Treat as a repository of hard-earned design lessons and useful subsystem ideas.

Potential concepts to salvage:

- Yggdrasil-style memory cognition;
- persistent character state;
- world simulation;
- event handling;
- narrative continuity;
- relationship state;
- RPG systems;
- structured context assembly.

Do not preserve complexity merely because it already exists.

### 17.2 Existing world-modeling project

Treat as a conceptual prototype and plugin library.

Potential path:

1. inventory existing capabilities;
2. identify systems that solve a still-relevant problem;
3. define an A.E.S.I.R.-native interface;
4. reimplement performance-sensitive pieces in Mojo where useful;
5. keep experimental pieces outside the core;
6. verify each imported concept independently.

### 17.3 Terminal vibe-coding project

Treat primarily as a future A.E.S.I.R. client and agentic development interface.

Do not require it to become the inference engine.

### 17.4 Future projects

New experimental projects can become proving grounds for modules before they are promoted into A.E.S.I.R.

A successful experiment should enter A.E.S.I.R. because the interface and use case are understood, not simply because the code exists.

---

## 18. The A.E.S.I.R. Cognitive Stack

The long-term system can be conceptualized as layers rather than one giant application.

```text
┌──────────────────────────────────────────────┐
│ MIDGARD                                      │
│ Chat • Voice • Coding CLI • Games • Apps    │
├──────────────────────────────────────────────┤
│ BIFROST                                      │
│ APIs • Streaming • IPC • Compatibility      │
├──────────────────────────────────────────────┤
│ ASGARD                                       │
│ Orchestrator • Router • Agents • Tools       │
│ Persona • Context Composer • Task Control    │
├──────────────────────────────────────────────┤
│ MÍMISBRUNNR                                  │
│ KV • RAG • Second Brain • Project Memory     │
│ World State • Episodic/Semantic Memory       │
├──────────────────────────────────────────────┤
│ NIDAVELLIR                                   │
│ Mojo Kernels • Quantized Compute • SIMD      │
│ CPU/GPU/NPU Dispatch • Device Sharding       │
├──────────────────────────────────────────────┤
│ HARDWARE                                     │
│ Pi • SBC • Laptop • GPU • Multi-Node System │
└──────────────────────────────────────────────┘
```

The language model becomes one participant in this stack rather than the entire system.

---

## 19. Context-Minimization Strategy

A major research direction should be reducing the amount of raw information that must be pushed through the LLM on every turn.

### Traditional approach

```text
Huge system prompt
+ huge chat history
+ huge document context
+ huge persona
+ huge world description
= expensive inference
```

### A.E.S.I.R. target approach

```text
Persistent state outside model
        +
Small task-specific retrieval
        +
Compact persona slice
        +
Relevant world-state slice
        +
Current request
        =
Focused inference
```

### Desired result

A smaller model receives better-selected information and wastes fewer tokens reconstructing the state of the system.

This principle ties together:

- memory;
- world modeling;
- project state;
- roleplay state;
- model routing;
- second-brain features;
- low-power inference.

---

## 20. Anti-Spaghetti Rules

The Norse Saga Engine demonstrated how quickly a creative AI project can accumulate overlapping layers. A.E.S.I.R. should intentionally learn from that experience.

### Rules

- **No duplicate source of truth.** One system owns a state category.
- **No feature enters the hot path merely because it is interesting.**
- **Every major subsystem gets a documented interface.**
- **Experimental modules stay clearly marked experimental.**
- **Current capability claims stay evidence-backed.**
- **Brainstorming documents are allowed, but they are not specifications.**
- **Specifications should be extractable from brainstorms into concise implementation documents.**
- **Old code is evidence, not sacred text.** Rebuild when cleaner than adapting.
- **Prefer small composable components over giant manager classes.**
- **Measure memory, latency, power, and complexity, not only feature count.**
- **Every optional system must be disableable.**
- **Graceful degradation is a feature.**
- **The lowest supported hardware tier must remain visible during architecture decisions.**

---

## 21. Suggested Development Phases

These are organizational phases, not release promises.

### Phase 0: Harden the foundation

Focus on making the current inference core truthful, testable, stable, and measurable.

- [ ] Continue capability-ledger discipline.
- [ ] Stabilize core inference behavior.
- [ ] Benchmark memory and performance.
- [ ] Keep API/server boundaries clean.
- [ ] Avoid adding high-level cognitive systems prematurely.

### Phase 1: Edge efficiency and hardware spectrum

- [ ] Establish repeatable low-power hardware benchmarks.
- [ ] Define constrained-device profiles.
- [ ] Improve low-memory model execution.
- [ ] Expand hardware capability detection.
- [ ] Improve device dispatch and graceful fallback.

### Phase 2: Persistent memory / second brain

- [ ] Define memory interfaces.
- [ ] Separate working, episodic, semantic, project, and world state.
- [ ] Implement compact retrieval.
- [ ] Add inspectable local persistence.
- [ ] Benchmark token savings from external memory.

### Phase 3: Model routing

- [ ] Define a model-provider interface.
- [ ] Add task classification/routing.
- [ ] Add smallest-model-first escalation.
- [ ] Add specialist chains.
- [ ] Benchmark multi-small-model workflows against one larger model.

### Phase 4: Standalone interaction and voice

- [ ] Interactive native chat mode.
- [ ] STT adapter interface.
- [ ] TTS adapter interface.
- [ ] Streaming speech where practical.
- [ ] Keep text-only operation fully independent.

### Phase 5: Persistent agents and world state

- [ ] Define persona package format.
- [ ] Define structured world-state schema.
- [ ] Connect memory and world state without conflating them.
- [ ] Add tool/permission metadata.
- [ ] Test persistent agent continuity across model changes.

### Phase 6: Coding client integration

- [ ] Connect terminal vibe-coding client to A.E.S.I.R.
- [ ] Preserve alternative backends.
- [ ] Add project/repository world state.
- [ ] Add coding-agent model routing.
- [ ] Use persistent design-decision memory.

### Phase 7: Roleplay / simulation modules

- [ ] Inventory reusable Norse Saga Engine concepts.
- [ ] Port only cleanly isolated systems.
- [ ] Add optional game-world state.
- [ ] Add character relationship and event systems.
- [ ] Keep all RPG functionality removable from the core runtime.

### Phase 8: Multi-device intelligence

- [ ] Separate coordinator and worker responsibilities.
- [ ] Add capability-aware node discovery.
- [ ] Route tasks according to hardware/resources.
- [ ] Preserve local fallback when nodes disappear.

### Phase 9: External distributed ecosystems

- [ ] Watch distributed inference projects and standards.
- [ ] Define a possible remote-compute adapter boundary.
- [ ] Do not implement global volunteer infrastructure unless the ecosystem and security model justify it.

---

## 22. Research Questions

These questions can guide experiments without becoming premature commitments.

### Inference

- How small can a useful model become when memory and world state are externalized?
- Which tasks benefit most from specialist small models?
- When does routing overhead erase the savings from smaller models?
- Which operations are worth moving into dedicated Mojo kernels?
- What produces the best capability per watt on a Raspberry Pi class device?

### Memory

- What information should be stored as text versus structured state?
- When should memories be summarized, merged, or forgotten?
- Can retrieval run effectively without invoking an LLM?
- How much prompt/context reduction can the memory system produce in real workloads?

### World modeling

- What is the smallest general schema useful for both coding and roleplay?
- How should events update world state?
- How should uncertain state be represented?
- How should multiple agents share state without corrupting it?

### Model routing

- Can tiny classification models route reliably enough to save compute?
- When should the system escalate to a larger model?
- Can the router learn preferred model/task mappings from benchmark history?
- How much parallelism is actually useful on low-power hardware?

### Persistent agents

- Which identity information must be present every turn?
- Which parts can be retrieved only when relevant?
- How much continuity can live in external state rather than prompt text?
- Can an agent change underlying models while retaining recognizable continuity?

---

## 23. Metrics That Matter

A.E.S.I.R. should avoid optimizing only for headline token speed.

Useful metrics include:

| Metric | Why it matters |
|---|---|
| Tokens/sec | Raw generation speed |
| Time to first token | Conversational responsiveness |
| Peak RAM | Determines whether constrained devices can run the system |
| Peak VRAM | Determines model/device compatibility |
| Idle RAM | Important for always-on agents |
| Power draw | Critical for mobile, nomadic, solar, battery, and SBC use |
| Context tokens per task | Measures cognitive-system efficiency |
| Model calls per task | Measures routing overhead |
| Task success rate | Prevents fake efficiency that reduces usefulness |
| Cold-start time | Important for models loaded on demand |
| Memory retrieval latency | Determines whether second-brain features remain lightweight |
| Graceful fallback success | Measures resilience across hardware changes |

### A useful north-star metric

Consider tracking a composite idea such as:

> **Useful task capability per watt, per gigabyte, and per token.**

It does not need to become a formal benchmark immediately, but it reflects the philosophy better than raw tokens per second alone.

---

## 24. Idea Inbox for Future Voice Sessions

This section is intentionally lightweight. New ideas should be easy to capture before they are polished.

Copy this template whenever a new concept appears:

```markdown
### Idea: <short name>

**Date:** YYYY-MM-DD  
**Source:** Voice session / coding session / brainstorm / experiment  
**Status:** Raw idea

#### Problem
What problem does this solve?

#### Concept
What is the idea in plain language?

#### Likely A.E.S.I.R. Realm
Midgard / Bifrost / Asgard / Nidavellir / Mímisbrunnr / External Client

#### Core or Optional?
Core / Optional / Experimental / External Integration

#### Why It Matters for Small Hardware
How could this reduce RAM, compute, power, latency, or token usage?

#### Dependencies
What must exist first?

#### First Experiment
What is the smallest test that could prove or disprove the idea?

#### Notes
Anything else worth preserving.
```

The purpose is capture, not perfection.

A rough idea can be refined later into a proper specification.

---

## 25. Immediate Backlog of Ideas Captured in the August 19 Discussion

- [ ] Preserve Raspberry Pi / very-low-power hardware as a first-class design target.
- [ ] Explore small-model routing rather than relying on one large model for every task.
- [ ] Explore rapid-fire specialist model pipelines.
- [ ] Investigate smallest-model-first escalation.
- [ ] Revisit Yggdrasil memory ideas as a modular second-brain architecture.
- [ ] Keep persistent memory outside the model whenever practical.
- [ ] Add explicit structured world state as a general capability, not only an RPG feature.
- [ ] Use world state to reduce repeated context and inference cost.
- [ ] Explore persistent agent personalities that can survive underlying model changes.
- [ ] Eventually support optional roleplay/game systems extracted from the Norse Saga Engine.
- [ ] Treat the Norse Saga Engine as an idea/component library, not a codebase to merge wholesale.
- [ ] Inventory the older world-modeling project for reusable concepts.
- [ ] Reimplement useful performance-sensitive world-model components in Mojo where justified.
- [ ] Add pluggable speech-to-text support.
- [ ] Add pluggable text-to-speech support.
- [ ] Allow low-resource and high-quality speech backends to coexist.
- [ ] Provide a standalone interactive chat experience.
- [ ] Integrate the terminal-based vibe-coding project as an A.E.S.I.R. client.
- [ ] Keep the coding client backend-agnostic so it can also use Ollama and other runtimes.
- [ ] Keep the coding-client ecosystem flexible even if the A.E.S.I.R. runtime hot path remains Mojo.
- [ ] Continue multi-device and shard-oriented work.
- [ ] Explore coordinator/worker designs for Pi + laptop + GPU combinations.
- [ ] Allow the system to scale down and up rather than assuming one hardware tier.
- [ ] Keep optional systems switchable so unused features consume no unnecessary resources.
- [ ] Preserve clean plugin seams for future capabilities that do not exist yet.
- [ ] Keep a future adapter boundary open for distributed/volunteer inference networks.
- [ ] Do not make global volunteer inference a core development burden unless a credible ecosystem emerges.
- [ ] Optimize for fewer repeated tokens, not just faster repeated tokens.
- [ ] Measure capability per resource, not only raw model size or token speed.
- [ ] Keep brainstorm documents, but distill mature ideas into concise implementation specs.

---

## 26. Long-Term Identity of Project A.E.S.I.R.

A.E.S.I.R. can begin as an efficient inference engine without being limited forever to the definition of an inference server.

The larger possibility is a **modular local intelligence runtime**.

At its smallest:

```text
A.E.S.I.R. = fast local inference
```

With selected modules:

```text
A.E.S.I.R.
= inference
+ memory
+ world state
+ routing
+ agents
+ tools
+ voice
+ clients
+ optional simulation
```

The key is that the second expression must never destroy the elegance of the first.

The project should grow by **composition**, not accumulation.

---

## 27. Final Design Principle

> **Do not ask a small model to carry an entire world inside its context window. Build the world around it.**

A.E.S.I.R.'s strongest long-term direction is not simply making models run faster. It is designing an efficient external cognitive architecture that lets modest models use memory, state, tools, routing, and specialized computation intelligently.

That direction connects the major threads behind the project:

- edge AI;
- affordable hardware;
- Raspberry Pi and nomadic computing;
- Mojo performance;
- local sovereignty;
- second-brain memory;
- Yggdrasil cognition;
- world modeling;
- agentic personalities;
- roleplay simulation;
- voice interaction;
- coding agents;
- multi-device systems;
- open interfaces;
- future distributed intelligence.

The aim is not one enormous application that always runs everything.

The aim is a lean forge where the user can awaken only the capabilities they need.
