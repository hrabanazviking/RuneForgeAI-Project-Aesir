# OR-2 — KoboldCpp

**Dossier type:** Public-documentation behaviour dossier (OR series, Ollama Research Forge)
**Commissioned:** 2026-11-15, by Volmarr — research corpus for an improved Ollama in Go, aimed at personal character chat
**As of:** 2026-11-15
**Licence:** GNU AGPL-3.0 — for KoboldCpp itself and for KoboldAI Lite. Verified 2026-11-15 in the Licence section of the project README on the `concedo` branch: *"KoboldCpp and KoboldAI Lite are licensed under the GNU AGPL v3.0, unless a file states otherwise."* The same section states that bundled components retain their own licences, including MIT for GGML, llama.cpp, stable-diffusion.cpp, Qwen3-TTS.cpp and acestep.cpp, and Apache 2.0 for audio.cpp.
**Base / lineage (as documented):** A fork / build on top of **llama.cpp** (ggml-org), inspired by the original **KoboldAI**. The README's first line of identity is: *"Inspired by KoboldAI and built on llama.cpp."* The wiki introduction describes it in the project's own words as *"a single self-contained distributable from Concedo, that builds off llama.cpp."*
**Repository:** https://github.com/LostRuins/koboldcpp
**Wiki / FAQ:** https://github.com/LostRuins/koboldcpp/wiki
**API reference (project-hosted):** https://lite.koboldai.net/koboldcpp_api and, in a running instance, `http://localhost:5001/api`
**Official website (per README):** https://koboldcpp.net — the README also warns, prominently, that `koboldcpp.com` is *"a malicious fake site"* and that the only trusted downloads are the GitHub releases and koboldcpp.net.
**Maintainer (as documented):** LostRuins / Concedo (single named author in the README and wiki; contact handles listed in the README's Licence section).

> **LICENCE DISCIPLINE — READ FIRST.** This dossier was produced under an absolute clean-room rule for this AGPL-3.0 project: **public documentation and observable, documented behaviour only** — the project README, the project wiki/FAQ, release-note summaries, and the project's own published feature descriptions. No source code was read for implementation detail, and nothing is lifted, paraphrased from code, or reconstructed from code. Every behaviour below is described in our own words, at the level a user or an API client can observe it. Where a claim comes from a secondary guide rather than the project's own pages, that is said explicitly. Where the project's own documentation is internally out of date (it is, on context defaults — see §3.5), both versions are given with their dates. A separate clean-room study of KoboldCpp exists elsewhere in Volmarr's programme; this file is not it, and does not draw on it.

**Essence, in one paragraph.** KoboldCpp is the proof-of-market for the personal runner: take llama.cpp's GGUF inference engine, wrap it in **one downloadable file with no install step**, embed a complete fiction-and-persona web UI (KoboldAI Lite) inside that file, and optimise the whole product — not for throughput, not for serving many users, but for *one person keeping a long story or a long character conversation coherent and characterful*. Its lasting contribution is not speed; llama.cpp supplies the speed. Its contribution is a **feature canon for persona chat** — Memory, Author's Note, World Info, characters, scenarios, persistent story saves, and the deepest sampler menu in the consumer-runner class — packaged so that a non-technical roleplayer can be generating within minutes of a download. In market terms it is the closest existing relative of what this commission wants to build: a GGUF runner whose centre of gravity is fiction and persona, not serving.

---

## 2. The product shape: one file, no install, UI inside

### 2.1 What ships

Per the current README (read 2026-11-15):

- *"One executable file, no installation required. Ready-to-run downloads are available for Windows, Linux, and macOS."*
- *"**Fully Portable** — Single standalone executable for Windows, Linux or macOS, with no installation required and no external dependencies. Runs on CPU or GPU, with full or partial offloading."*
- Named release artefacts (README, Download and Run section): `koboldcpp.exe` (Windows, with CUDA), `koboldcpp-nocuda.exe` (Windows, smaller, CPU + Vulkan), `koboldcpp-oldpc.exe` (Windows, older hardware), `koboldcpp-linux-x64` and its `-nocuda` / `-oldpc` variants, and `koboldcpp-mac-arm64` for Apple Silicon. Intel Macs, Android (via Termux), OpenBSD and Raspberry Pi are documented as source-build targets.
- No model is bundled. The user downloads a GGUF separately (the README points newcomers at curated "Newbie Templates" in its launcher and at Hugging Face collections), picks it in a GUI launcher, clicks **Launch**, and opens `http://localhost:5001`.
- The same executable also offers a command-line form (`--model <path>`, `--help` for the full flag list), a `--cli` terminal chat and an `--agent` mode in recent versions (see §5.4), and a `--nomodel` mode that runs the UI against an *external* provider instead of a local model (see §6.4).

The quick-start in the README is five steps, and step 1 is the download itself. There is no package manager, no service registration, no model registry account, and no configuration file the user must author before first generation.

### 2.2 Distribution as a design decision

This shape is a deliberate market decision, and it is worth naming what it buys and what it costs, because the contrast with Ollama's shape is the whole lesson:

| | KoboldCpp shape | Ollama shape (for contrast) |
|---|---|---|
| Unit of distribution | One file per platform/backend variant | Installer + background daemon + CLI client |
| First-run path | Download file → run file → pick GGUF → Launch → browser opens | Install → daemon runs → `ollama pull <name>` → `ollama run <name>` |
| Model acquisition | User brings a GGUF file (any source); launcher templates help newcomers | Registry pull by name; curated library |
| UI | Embedded in the artefact (KoboldAI Lite, plus llama.cpp UI, image UI, music UI) | None bundled originally; UI is third-party or API-driven |
| Lifecycle | Process lives while the window/console lives; closing it ends the server | Daemon persists; models load/unload behind the API |
| Port / surface | One port (default 5001) serving UI + every API dialect (see §6) | One port (default 11434) serving its API |
| Updates | Download the newer file; release cadence is fast (see §7.3) | Installer / package update of the daemon |

What "just run it" buys in *this* market:

1. **It matches the audience's skill distribution.** The fiction/roleplay audience includes many users who have never used a terminal. A double-clickable file with a launcher that has a model-picker and a Launch button removes the two highest-dropout steps (install, CLI) entirely. Secondary setup guides repeatedly identify "no installer" as the first reason the SillyTavern community standardised on it (see §6.3).
2. **It makes the version the user runs legible.** One file = one version. Support conversations ("which build, which model, which flags?") start from a single artefact and a `--help` dump, not from daemon state, service state, and client state drifting apart.
3. **It makes the runner disposable and side-by-side-able.** A user can keep last month's file and this month's file in the same folder and A/B them against the same GGUF — behaviour a daemon-plus-registry shape makes awkward.
4. **It collapses "runner" and "app" into one product.** Because the UI ships inside, the project controls the *whole* persona-chat experience — prompt assembly, Memory/World Info editing, sampler presets, story saves — instead of exposing an API and hoping a frontend invents those features. §3 and §4 are only possible as a coherent canon because of this decision.

What it costs (documented or directly observable from the documented shape):

- **Variant sprawl.** Because one file must carry its GPU backends, the release splits into CUDA / nocuda / oldpc variants per platform, and the CUDA-carrying files are much larger — secondary guides reading the v1.124.2 release (31 October 2026) list the Windows CUDA build at roughly 623 MB against roughly 90 MB for the nocuda build, the difference being the bundled CUDA libraries. *[Secondary source; sizes are release-specific and will drift.]*
- **No shared service.** Each running instance is one process serving (by design) one principal user; multi-request queueing exists (recent versions document a queue limit, `--queuelimit`) but the product is not shaped as a multi-tenant server, and its own docs steer serving use-cases elsewhere.
- **Security posture follows from "personal appliance."** The server listens for API clients and supports an optional `--password` (wiki: it *"will require the user to request generations using an API key"*); third-party review of the current release notes that the password covers the text routes and that image routes are described in `--help` as not secured. For a single-user local tool this is a coherent trade; for anything network-exposed it is a warning label. *[The route-coverage detail is from a third-party review of the `--help` text, 2026-11; treat as documented behaviour to re-verify against a live `--help` before relying on it.]*

### 2.3 The launcher as part of the product

A detail the README and wiki together make clear: configuration that other runners expose as flags or config files is surfaced in a **GUI launcher** — model file, GPU layers / autofit, context size, backend choice, and toggles for the extras (vision projector, Whisper, TTS, embeddings model, Horde worker, admin mode, and more). The wiki's troubleshooting is written assuming the launcher exists. For the persona audience this matters as much as the single file itself: *every* capability in §§3–5 is reachable without editing text config, which is precisely the bar a Go re-implementation aimed at the same audience has to clear in its own idiom.

---

## 3. Context & memory behaviour

This is the section KoboldCpp exists for. Three different things are often conflated under "memory," and the project's documentation keeps them separate. They are separated here too:

- **(a) Engine context behaviour** — what happens to the token window and its cache as a conversation outgrows it (§3.1).
- **(b) Prompt-level memory features** — Memory, Author's Note, World Info: text the *UI/prompt layer* injects, at defined positions, on defined triggers (§§3.2–3.4). These are documented user-facing behaviours, described here by what they do for the user.
- **(c) Persistence** — stories, scenarios, characters and settings as saveable, reloadable artefacts (§3.6).

### 3.1 Context shifting, fast forwarding, Smart Context, SWA

All four behaviours below are described in the project wiki (FAQ, "What is ContextShift?" / "What is FastForwarding?" and neighbours), read 2026-11-15.

**Context Shifting (default on; disable with `--noshift`).** In the wiki's words, it *"utilizes KV cache shifting to automatically remove old tokens from context and add new ones without requiring any reprocessing,"* and it *"does not consume any additional context space, making it superior to SmartContext."* User-visible meaning: when a story grows past the allocated context, the conversation **keeps going** — the oldest material leaves the window and generation continues — instead of the session erroring or stalling for a full re-prefill. The wiki is equally explicit about the condition and the caveat, and both matter for design:

> *"So long as memory is not changed or edited and you don't use world info, you should be able to avoid almost all reprocessing between consecutive generations even at max context."*

and: *"Your outputs may be different with shifting enabled, but both seem equally coherent."* Context Shifting applies to GGUF models and overrides Smart Context when both are enabled.

**Fast Forwarding (default on; disable with `--nofastforward`).** The wiki: it *"allows the AI to skip reused tokens in the context that have already been processed in the previous turn."* User-visible meaning: in a turn-by-turn chat where most of the prompt is unchanged from last turn, only the new tail is processed, so response latency at long context stays usable. Release notes in the project's history (e.g. the v1.78 notes, via the SourceForge mirror) show `--nofastforward` being offered for cases where a user prefers full reprocessing for repeatability — i.e. the project treats "fast but stateful" vs "slow but pristine" as a user choice, defaulting to fast.

**Smart Context (legacy predecessor).** The wiki documents it as the earlier mechanism Context Shifting supersedes: when approaching max context, it truncates away the first half of the existing context and shifts the remaining half up, so reprocessing happens in large, infrequent chunks rather than every turn (the wiki explains it with a bus analogy — emptying half the bus rarely instead of a few seats every stop). It is retained in the docs because older guides and saves reference it. For a new design it is a historical note: the *idea* (amortise eviction) survived; the mechanism was replaced by KV-cache shifting.

**Sliding-window attention (SWA).** Documented in release notes (e.g. v1.92.1, via the mirror: SWA *"uses much less memory for the KV cache,"* enabled with `--useswa`, *"not compatible with ContextShifting, and may result in degraded output when used with FastForwarding"*). Later third-party settings guides (reading v1.122.1, October 2026) report SWA on by default for models that support it. Treat the default as version-dependent; the documented *behaviour* is a smaller KV cache for model families whose architecture supports a sliding window, with explicit incompatibility warnings against the shifting machinery. *[Default-on status: secondary source, version-specific.]*

**The design tension, stated plainly.** §3.1 and §3.4 pull against each other, and the wiki says so itself: the cache-reuse fast paths work best when the prompt prefix is *stable*, and World Info — whose entire purpose is to change the injected prefix as keywords come and go — breaks that stability. KoboldCpp ships both anyway, defaults both on, and documents the interaction honestly. That is the correct product instinct for persona chat (correctness of *story* outranks elegance of *cache*), and any re-implementation will hit the same trade and should document it the same way.

### 3.2 Memory (the field)

Wiki, "How do I make the AI remember things?":

> *"Memory — This is a sequence of text that will always be injected into the start of each prompt sent to the AI. It is useful for things the AI should always remember even over very long stories, such as main theme(s) of your story, the broad strokes of the setting, central conflict(s), and protagonist. As it uses up context space, try to keep Memory short, at most a paragraph or two."*

Behaviour, in our words: Memory is a **permanent, user-authored head-of-prompt block**. It survives context eviction because it is re-injected every turn rather than living in the scrolling history. Its cost is equally explicit in the docs: it is paid on *every* turn, in tokens, against the same context budget as the conversation itself. The guidance to keep it to a paragraph or two is a product-level admission that injection is not free — a lesson §9 returns to.

### 3.3 Author's Note

Wiki, same section:

> *"Author's Note — This is similar to memory, but is injected near the end of the prompt rather than at the start. It's used to describe recent situations, or guide the AI to behave in a certain way for the current scene. A/N Strength affects how far back this text is injected."*

Behaviour: a **positional steering note**. Where Memory says "these facts are always true," the Author's Note says "for *this* scene, write like *this*" — present-tense situation, tone, style, or behavioural direction — and its placement near the end of the prompt (recency-weighted by the model) plus a user-settable depth ("A/N Strength" / how far back it is injected) are the whole mechanism, exposed as a user control. The two injection points — head for permanence, near-tail for immediacy — are the minimal complete set, and KoboldCpp's canon has exactly these two plus the conditional third below.

### 3.4 World Info

Wiki, same section:

> *"World Info — This is text that is only situationally injected into the prompt. When the World Info 'Key' is matched, the corresponding 'Content' text gets injected into the start of the prompt. Useful for reminding the AI of facts, character names, ages, personalities, places as well as plot points, like a dictionary or encyclopedia."*

Behaviour: a **keyword-triggered lorebook**. The user authors entries of (key → content); when a key appears in the recent story text, that entry's content joins the prompt for that turn; when the key stops appearing, the entry leaves again. It is the answer to the Memory field's token-cost problem: a cast of thirty characters and a gazetteer of places cannot all live in an always-injected block, but any *one* scene only needs the entries its own words touch. Release-note history shows the project actively tuning this behaviour (e.g. v1.78 notes: *"Better world info length limiting (capped at 50% of max context before appending to memory)"* — i.e. triggered lore is budget-capped so it cannot crowd out the story itself). Secondary explainers add the user-level summary that entries are typically described as keyword + content (+ grouping/budget controls in the UI); the fine-grained entry fields beyond key/content are UI-surface details that vary by Lite version and are **not** relied on in this dossier.

World Info is, of the three, the feature with no analogue in serving-oriented runners, and the one most often cited by third-party comparisons as the reason fiction users choose this stack (see §8.1).

### 3.5 Context size, RoPE, and a documentation-drift warning

- `--contextsize N` sets the maximum context (README troubleshooting; wiki long-context section). The wiki's long-context text is **old**: it speaks of exceeding 2048, of GGUF support "up to 32k," and of a Lite slider capped at 2048 (with the documented workaround of typing past the slider). 
- The project's own release history moved past that text: release notes mirrored for v1.96.2 record *"Default context size is now 8k (up from 4k)"* at that version, and third-party guides reading the v1.122.1 launcher (October 2026) report a **16,384-token default** with a much higher accepted ceiling, flash attention on by default, and GPU-layer **autofit** as the default (`--gpulayers -1`). One guide in the same series reports 12,288 for v1.119 (August 2026) — i.e. the default moved more than once in 2026 alone.
- **Verdict for this dossier:** the *behaviour* (user-settable context, defaults rising over time, RoPE scaling applied to stretch GGUF models beyond trained length) is documented and stable; any *specific number* is version-stamped or it is wrong. RoPE behaviour per the wiki: `--ropeconfig` offers linear and NTK-aware scaling, can stretch a model "by over 4x … with minor to moderate quality degradation," and when unset, NTK-aware scaling is chosen automatically from `--contextsize`. The wiki's honesty about degradation on stretched context is again characteristic: the limit is surfaced, not hidden.

### 3.6 Stories, scenarios, characters, saves

From the README feature list and the wiki's Kobold Lite sections (read 2026-11-15):

- **Persistent story saves.** Lite provides *"persistent stories, editing tools, save formats"* (wiki intro); stories save as JSON, and Lite's documented import/export surface is deliberately promiscuous: KoboldAI Classic `.json` saves, KoboldAI United (V2) `.json` saves, KAISTORY files, TavernAI / SillyTavern character cards (JSON, and PNG/WebP card images), oobabooga character and story exports, Agnai and Tavern world-info formats, and raw text.
- **Settings travel with the story.** Wiki: *"Save File Includes Settings"* — *"your Kobold Lite UI, generation and sampler settings [can] be saved directly into the story json file itself, and loaded again in future."* And *"Persist Autosave Session"* autosaves story + settings so they are *"restored the next time you start KoboldCpp again"* (with the docs still recommending manual exports against data loss).
- **Characters and scenarios as first-class objects.** The README lists *"memory, world info, author's notes, characters, scenarios"* as bundled Lite features; the README's current quick-start and templates system packages launch configurations (model + settings) as shareable **`.kcpps`** templates, including curated newbie/popular template collections hosted under the project's Hugging Face organisation. The wiki's Admin-mode section documents `.kcpps` launch configs as the unit for runtime model/config swapping (`--admin` + `--admindir`).
- **Character-card import is an ecosystem bridge.** Accepting Tavern-format cards (the SillyTavern ecosystem's persona format) *and* multiple world-info formats means a user's cast and lore, authored in other tools, arrive intact. Placeholder substitution is documented in Lite (`{{user}}`, `{{char}}`, `{{[INPUT]}}`, `{{[OUTPUT]}}` replaced at runtime), which is what makes shared cards portable between users with different names/personas.
- **Modes are part of the save's world.** Lite documents distinct **chat, adventure, instruct, and story-writing** modes (README), with mode-specific UI skins (Classic, Messenger, Aesthetic, Corpo) and mode-specific behaviours (e.g. adventure's injectable adventure prompt, instruct start/end sequences, chat name fields). A "scenario" in this canon is therefore not just a system prompt: it is mode + character + memory + world info + sampler preset + opening, saved as one artefact.

### 3.7 TextDB: the built-in, deliberately-not-vector RAG

Wiki, "Can I Talk To or Search my Documents":

> *"KoboldCpp offers a TextDB Document Lookup in KoboldAI Lite — This is a very rudimentary form of browser-based RAG. You can access it from the Context > TextDB tab. It's powered by a text-based minisearch engine, you can paste a very large text document which is chunked and stored into the database, and at runtime it will find relevant snippets to add to the context depending on the query/instruction you send to the AI. … Note that this is NOT an embedding model or true vector database, it uses lunr and minisearch for retrieval scoring instead."*

Behaviour: paste a large document (or use the story history itself as the document); at generation time, lexically-relevant snippets are retrieved and added to context. The README separately lists *"retrieval-augmented generation (RAG) through TextDB"* among its tools. The project's own "very rudimentary" / "NOT a vector database" framing is the point to record: for lore-scale corpora, the project chose a zero-model, zero-index-cost lexical lookup inside the browser UI over an embeddings pipeline — while *also* offering a real embeddings endpoint for external vector systems (§5.3). Two different retrieval answers for two different scales, both shipped, each labelled honestly.

---

## 4. Sampling richness

### 4.1 The documented menu

The wiki's sampler section ("What are samplers?") is the canonical public list, read 2026-11-15. In the wiki's own ordering of presentation, with its one-line behaviour descriptions condensed in our words:

| Sampler | Documented behaviour (wiki) |
|---|---|
| Top-K | Keep only the K most likely candidate tokens; 0 disables |
| Top-A | Remove tokens below a probability threshold relative to the top token's probability; 0 disables |
| Top-P | Keep the smallest set of candidates whose cumulative probability reaches P; 1 disables |
| TFS (tail-free sampling) | Removes least-probable candidates using second-order-derivative shape of the distribution |
| Typical | Selects for tokens near the distribution's typical information content; 1 disables |
| Temperature | Scales the probability distribution — lower = more logical/less creative; removes nothing |
| Repetition Penalty | Penalises recently-used tokens to reduce repetition |
| Mirostat | Alternative method that *overrides* the other samplers; dynamically adjusts selection to hold perplexity near a target (wiki FAQ: type / tau 5.0 / eta 0.1); targets the "boredom trap" (repetitive) and "perplexity trap" (incoherent) simultaneously |
| Min-P | Removes tokens under a probability floor relative to the top token; 0 disables |
| DynaTemp (Dynamic Temperature) | Temperature varies automatically between user-set limits instead of staying fixed |
| **DRY** | *"A dynamic N-gram anti-repetition sampler, used as an alternative or together with Repetition Penalty. Only recommended for advanced users."* — i.e. it penalises *continuations of repeated sequences*, not merely repeated tokens |
| **XTC** | *"XTC (Exclude Top Choices) sampler is [a] creative writing sampler designed by the same author of DRY. It removes common tokens with high probability when there are many choices, allowing for more creative and flavorful text."* Documented starting values: `xtc_threshold=0.15`, `xtc_probability=0.5`; activated by raising `xtc_probability` above 0 |

Beyond the wiki list, the project's public surface also documents, in README/release-note level descriptions: **presence and frequency penalties** and **CFG (classifier-free guidance)** as part of the exposed stack (listed in third-party enumerations of the GUI/API surface against v1.114; the wiki list above predates some additions — treat CFG/presence/frequency as *documented in the product's public feature descriptions, not in the wiki sampler page read for this dossier*), **grammar sampling** (wiki FAQ: GBNF grammars constrain output syntax), **logit bias / token banning** controls (referenced across the API surface and the EOS-ban settings), and a **Token Probability Viewer** in Lite built on returned logprobs. Sampler **presets** — community-contributed, named configurations *"to emulate specific writing styles or platforms"* — are a Lite feature; the wiki warns, characteristically, that some presets carry sub-optimal orders and should be considered *"artistic rather than practical."*

### 4.2 Sampler order — and the "temperature last" idea

KoboldCpp does not merely expose the samplers; it exposes **the order they are applied in**, per request, as a first-class setting. Wiki:

> *"Sampler order controls the order in which the above samplers are applied in sequence, to the list of token candidates when choosing the next token. It is STRONGLY not advised to change this from the default of [6,0,1,3,4,2,5] as that can lead to very poor outputs."*

The documented defaults that accompany it: **Top-P = 0.92, RepPen = 1.1, Temperature = 0.7**, everything else disabled. Third-party guides confirm the same default order is carried as the KoboldCpp default inside SillyTavern's own presets, so the order survives the trip across the API into the dominant frontend.

On the specific "temperature-last" framing this dossier was asked to check: the wiki publishes the order as an opaque index list (`[6,0,1,3,4,2,5]`) without, in the pages read, printing the index-to-sampler key beside it, so the exact position of temperature in KoboldCpp's default chain is **not asserted here from the wiki alone**. What *is* documented, and what the idea rests on, is: (1) order is user-visible and reorderable; (2) the project treats order as load-bearing enough to warn strongly against changing it and to flag "bad suboptimal sampler orders" in the UI; (3) in the sibling llama.cpp sampler chain as publicly described in comparison guides, temperature is applied **last**, after penalties, DRY, truncation samplers and XTC — the rationale being that truncation/penalty stages should shape the candidate set first and temperature should scale what survives, rather than flattening the distribution before the filters see it. *[Point (3) is from secondary comparison documentation of llama-server's chain, June 2026; marked as such, and offered as the documented rationale for the pattern, not as a KoboldCpp-wiki claim.]*

### 4.3 Why persona chat demands this depth (and serving skips it)

The argument, assembled from the documented behaviours above:

1. **The failure modes of fiction are sampler-shaped.** Long-form roleplay degrades in specific, named ways: phrase looping (DRY's target — sequence-level, which flat repetition penalty handles bluntly and at a quality cost), bland "safest-next-word" prose (XTC's target), slow drift into incoherence at high creativity settings (Mirostat's and DynaTemp's target). A serving API optimised for short, factual, low-variance answers never meets these failures at scale; a 400-turn story meets all three in one evening.
2. **There is no "correct" output to average toward.** Serving systems minimise sampler surface because variance is a defect for them. For persona chat, variance *is* the product — but it must be * steerable* variance, per character and per scene, which is why presets (named, shareable, saveable with the story, §3.6) matter as much as the samplers themselves.
3. **The user is the tuner.** KoboldCpp's audience iteratively tunes a character's "feel" the way photographers tune a develop preset. That requires the controls to be *in the UI, per request, and in the API* — the wiki notes mirostat, for example, *"can now also be set on a per-generation basis within the API"* — not compiled in or hidden behind a server config. Third-party comparisons (June 2026) confirm the practical gap: Ollama's standard API exposed temperature/top-k/top-p/repeat-penalty class controls, with DRY, mirostat, XTC and CFG absent — the exact four a fiction user reaches for first.

---

## 5. Multimodal & extras: the "everything client" pattern

The current README's feature list (read 2026-11-15) is explicit that the single file is no longer a text runner with extras; it is a **multi-engine appliance**. Each item below is a documented feature; engines are loaded only when their model files are provided.

### 5.1 Vision / image input

- Text models with a compatible **multimodal projector (mmproj)** support image understanding: load the matching mmproj in the launcher (`--mmproj`) and chat with uploaded images (README). The wiki's LLaVA/mmproj section adds `--visionmaxres` for per-image resolution, and stresses the projector must match the model architecture.
- Lite's "AI Vision" documentation distinguishes three routes: true multimodal vision (mmproj), and two *interrogation* routes (AI Horde online, or a local A1111/Forge endpoint) that caption an image into text for a text-only model. The distinction is documented for users because the quality difference is real.

### 5.2 Image generation & editing; video; music

- **Image generation/editing** (README): Stable Diffusion 1.5, SDXL, SD3, Flux, Qwen Image, Ideogram, Z-Image, Klein, Krea2 "and more," via the bundled StableUI at `/sdui` and A1111-compatible endpoints (§6). The wiki/release history dates native SD support to the v1.60 era (via stable-diffusion.cpp) with an A1111-compatible API from the start.
- **Video generation** (README): WAN 2.2, LTX2.3, MiniMax H3 "and more."
- **Music generation** (README): ACE Step 1.5 and ACE Step XL, with a dedicated MusicUI at `/musicui`. Release coverage in late October 2026 (v1.124) describes further audio-model integrations arriving through an audio.cpp subset — a sign of the pattern in §5.5 rather than a stable list; model rosters in this area churn monthly and are **not** enumerated beyond the README's own list here.

### 5.3 Speech: STT and TTS

- **Speech-to-text:** Whisper (README: *"Speech-to-text with Whisper"*; wiki: load with `--whispermodel`, use from Lite with push-to-talk or voice-activity "Hands Free" mode, with resampling/conversion done locally in the browser). Recent README text also lists multimodal audio input from specific Gemma4 variants.
- **Text-to-speech:** README lists Qwen3TTS, Kokoro, OuteTTS, Parler and Dia. The wiki documents the OuteTTS route in detail (TTS model + WavTokenizer model, `--ttsmodel` / `--ttswavtokenizer`, GPU/thread/length controls, speaker and voice-cloning options via the API docs).
- Both directions are also API surfaces (§6), so external clients (including XTTS-style and OpenAI-speech-style clients) can use KoboldCpp purely as a local speech server.

### 5.4 Embeddings, tools, agent

- **Embeddings:** Wiki: *"GGUF embedding models can now be loaded with `--embeddingsmodel` and accessed from `/v1/embeddings` or `/api/extra/embeddings`, this can be used to [encode] text for search or storage within a Vector database."* Documented as aimed at third-party vector-DB solutions; not wired into Lite itself. A second, simultaneously-loaded model is supported by the launch shape (a dedicated embeddings model alongside the text model).
- **Reranking:** **Not found.** No reranking endpoint or reranker-model feature appears in the README, the wiki pages, or the API summaries read for this dossier (accessed 2026-11-15). Recorded as an absence, not an oversight: if a rerank surface exists, it is not part of the project's public documented surface as of this date. *(See §10, unverifiable items.)*
- **Tool calling & MCP:** README (current): *"MCP server support, tool calling, web search, retrieval-augmented generation (RAG) through TextDB, and an integrated KoboldCpp Agent for writing and editing code, running programs, and scheduling tasks"* — agent started via the launcher's Admin tab or `--agent`. Web search is separately documented in the wiki (`--websearch`; a DuckDuckGo-powered `/api/extra/websearch` proxy; must be enabled on both server and Lite).
- **AI Horde worker:** The wiki documents an embedded lightweight Horde worker: register a Horde key, set `--hordekey` / `--hordemodelname` / `--hordeworkername` (plus max-context / generation-length caps), and the same single file donates its GPU to the crowdsourced Horde network in the background. A personal appliance that can moonlight as a network worker is a distribution idea worth noting (§9).

### 5.5 The pattern

Read as a whole, §§5.1–5.4 describe a consistent strategy: **any model the user might want beside their chat model gets a loader, a UI tab, and a compatible API dialect inside the same file.** The cost is obvious — surface area, release size, and a feature matrix that ages unevenly (the wiki's older pages still describe a text+SD+Whisper product). The benefit is the one this market rewards: the user never has to assemble a stack. For persona chat specifically, the load-bearing extras are vision (character/scene images in-chat), TTS narration, and image generation; video/music/agent are reach. A re-implementation should copy the *pattern* (one artefact, lazily-loaded side engines, dialect-compatible endpoints) without necessarily copying the current roster.

---

## 6. API surface

### 6.1 One port, many dialects

README, "APIs and integrations" (read 2026-11-15): with the default port, a running instance serves —

| Interface | Base URL |
|---|---|
| KoboldCpp default API base | `http://localhost:5001` |
| OpenAI-compatible API | `http://localhost:5001/v1` |
| Interactive API documentation | `http://localhost:5001/api` |
| KoboldAI Lite web UI | `http://localhost:5001` |
| llama.cpp web UI | `http://localhost:5001/lcpp` |
| StableUI (image gen UI) | `http://localhost:5001/sdui` |
| MusicUI | `http://localhost:5001/musicui` |

*"Additional APIs supported: KoboldAI, OpenAI, Anthropic, Ollama, AUTOMATIC1111, ComfyUI, XTTS"* — plus, from the feature list, Whisper-transcription and OpenAI-speech client compatibility. A NoScript web UI at `/noscript` (wiki) serves browsers without JavaScript, including text browsers over SSH. The server also serves an OpenAPI description at `/api?json=1` in current versions (third-party review of v1.124.2 counts 86 path entries / 69 operations; *[secondary count, version-specific]*).

The strategy is **dialect maximalism**: instead of asking clients to adopt KoboldCpp's API, KoboldCpp speaks *theirs*. Any tool that can be pointed at an OpenAI base URL, an Ollama port, an A1111 server, or a ComfyUI instance can be pointed at this file.

### 6.2 The native Kobold API

Wiki, "How can I use the Kobold API?":

- The principal generation endpoint is **`/api/v1/generate`** — send a prompt plus the full generation settings (§4's sampler stack travels here, which is why the wiki recommends the native API over the OpenAI one: *"You're still recommended to use the Kobold API as it has many more settings"*).
- Utility endpoints documented alongside: `/api/v1/model`, `/api/v1/config/max_length`, `/api/v1/config/max_context_length`.
- KoboldCpp extensions under `/api/extra/*`: `/api/extra/generate/stream` (SSE streaming), `/api/extra/version`, `/api/extra/perf` (performance/timing), `/api/extra/abort`, `/api/extra/generate/check` (partial text of an in-progress generation), `/api/extra/tokencount`, `/api/extra/true_max_context_length`, and (from §§5.3–5.4) `/api/extra/embeddings`, transcription, TTS, websearch and music routes.
- Full request/response formats are in the project-hosted API reference; an in-instance copy lives at `/api`.

### 6.3 OpenAI-compatible and other emulations

- **OpenAI:** Wiki dates the OpenAI-compatible completions API to **v1.45.2**: `/v1/completions` and `/v1/chat/completions`, with `/v1/models`, `/v1/embeddings`, `/v1/images/generations`, `/v1/audio/speech`, `/v1/audio/transcriptions` and (current versions) `/v1/responses` appearing in the documented route lists. KoboldCpp accepts its extended sampler fields as non-OpenAI extension parameters on these routes (documented in third-party API guides against current releases) — the pragmatic bridge that lets an OpenAI-shaped client still reach DRY/Min-P-class controls. `max_tokens` on the chat/completions routes controls output length; `--defaultgenamount` covers clients that never send it (wiki).
- **Ollama emulation:** Wiki: *"there is now a simple Ollama compatible API … only exists to provide unparalleled larger ecosystem compatibility"* and *"for normal usage, this is NOT recommended."* Third-party tracking dates the emulation's arrival to the v1.79 era and its chat/generate/tags/version coverage on the same port, noting the practical trick of running KoboldCpp **on port 11434** so Ollama-only tools connect unchanged. The project's own framing — ship the emulation, recommend against it, keep the native API primary — is worth copying verbatim in spirit.
- **Anthropic:** `/v1/messages` appears in the README's supported-API list (current README, read 2026-11-15); third-party tracking dates its arrival to v1.115.2 (June 2026) with tool calling. *[Arrival version: secondary source.]*
- **A1111 / ComfyUI:** `/sdapi/v1/*` for image clients and a ComfyUI `/prompt` route, so image-ecosystem tools treat the file as an image server.
- **Admin / router behaviours (recent, documented in wiki/release summaries):** `--admin` runtime config swapping via `.kcpps` files (§3.6); a router mode in recent versions in which a request naming a different model triggers unload/load of the requested model (third-party comparison, November 2026) *[secondary; verify against current release notes before designing against it]*.

### 6.4 The reverse direction: Lite as a client

The README documents that the bundled UI is not captive to the local engine: started with `--nomodel` (or "Allow Launch Without Models" in the launcher), Lite connects directly to external providers — the README lists AI Horde, OpenAI Compatible, Anthropic, OpenRouter, Gemini, Grok, Mistral "among the supported services" — and an online Lite is hosted at lite.koboldai.net. So the artefact is simultaneously (a) a local server, (b) a frontend for other people's servers, and (c) with its Horde worker, a node in a volunteer network. That three-way shape is unusual among runners and is a large part of why the UI canon (§3) spread beyond the engine itself.

### 6.5 SillyTavern: the ecosystem role

Public facts only, at the level this corpus requires:

- SillyTavern is a third-party character-chat frontend; KoboldCpp's own wiki introduces it exactly that way: *"SillyTavern and Agnaistic are third-party frontend user interfaces that specialize in interaction with chat/roleplay with AI characters. They include support for KoboldCpp as a backend, via the KoboldAI API."*
- The documented connection is **Text Completion → KoboldCpp**, server URL `http://localhost:5001` (SillyTavern's own docs and every setup guide agree; it is also the single most common misconfiguration when users select Chat Completion instead).
- The pairing is old and load-bearing for both projects: SillyTavern carries KoboldCpp's sampler defaults (including the §4.2 order) as its own KoboldCpp presets, and KoboldCpp accepts SillyTavern/Tavern character-card and world-info formats in its own UI (§3.6). Each side imports the other's artefacts.
- Market consequence: for a large share of persona-chat users, "KoboldCpp" is experienced *through* SillyTavern, and the native Lite UI is the fallback/on-ramp. KoboldCpp thus holds two positions at once — the default **backend** of the dominant third-party frontend, and a complete **standalone** product. Any new entrant in this space is, whether it likes it or not, designing for both positions: an API that SillyTavern-class frontends can adopt, and a bundled experience for users who never install one.

---

## 7. Performance character

### 7.1 What is inherited, what is claimed

KoboldCpp's inference is llama.cpp's inference. The project does not claim a faster engine; its README sells *packaging and features* ("builds off llama.cpp, and adds…"), and its performance documentation is almost entirely about **configuration of the inherited engine**: backend selection, GPU layer offloading, context/batch sizing, flash attention, KV-cache quantisation (`--quantkv`, wiki: levels f16/q8/q4, full quantisation requiring flash attention), mmap/mlock, speculative decoding via a draft model (`--draftmodel`, wiki), and the §3.1 cache-reuse behaviours. Where the project does add performance-relevant behaviour of its own, it is in that last category — context shifting / fast forwarding change *how much reprocessing a long chat pays*, which for the persona workload (very long, mostly-append-only prompts) is worth more than raw tokens/second, and the wiki quantifies it qualitatively ("avoid almost all reprocessing … even at max context") rather than with benchmark tables.

Accordingly, this dossier records **no tokens/second figures**: none are published as first-party claims in the README/wiki pages read, and third-party numbers are hardware-specific anecdotes. *[Absence noted deliberately — see §10.]* The honest performance statement is: same GGUF, same quant, same backend ⇒ llama.cpp-class speed, plus KoboldCpp's prompt-reuse behaviours on top, minus whatever the user's World Info / Memory editing does to prefix stability (§3.1).

### 7.2 Hardware & backends, as documented (with the dated history)

Current README (2026-11-15): GPU acceleration via **`--usecuda`** (NVIDIA only) or **`--usevulkan`** (AMD, NVIDIA, Intel), GPU layer offloading via `--gpulayers N` with **`-1` = autofit** as the documented default behaviour ("Autofit is an estimate and may need manual adjustment"), Metal on macOS source builds, ROCm via source build (`LLAMA_HIPBLAS=1`) with the README pointing AMD users to Vulkan first and listing a community ROCm fork (YellowRoseCx/koboldcpp-rocm) as a third-party resource. The build table in the README (CPU / Vulkan / CUDA / ROCm / CUDA+Vulkan) is the current menu.

Brief dated history, from the wiki and older README copies (this is the "CLBlast-era" arc the commission asked to have on record):

- **Early era (2023):** acceleration meant **CuBLAS** (`--usecublas`) for NVIDIA and **CLBlast** (`--useclblast`, OpenCL) as the cross-vendor path — the old README's performance section reads: *"try CLBlast with `--useclblast` flags for a slightly slower but more GPU compatible speedup."* The wiki's build instructions still carry the CLBlast/OpenCL library-replacement notes as archaeology.
- **Deprecation arc:** release notes in the v1.78 era record CLBlast as *"still retained, but … further downgraded"*; third-party settings histories (reading release notes back to 2023) summarise the last ~15 months as: two backends removed, the main GPU flag renamed (`--usecublas` → `--usecuda`), flash attention defaulted on, manual layer counts replaced by autofit as the default. The current README knows only CUDA/Vulkan in its user-facing text.
- **Memory guidance (wiki, dated by its own assumptions):** at 2048 context, Q4_0 — 3B ≥ 4 GB RAM, 7B ≥ 8 GB, 13B ≥ 16 GB, 30B ≥ 32 GB, 65B ≥ 64 GB; and a period VRAM example (6 GB RTX 2060 offloading 32 layers of a 7B at 2k context). These numbers are GGUF-era rules of thumb, still directionally useful, explicitly *not* current-default measurements.

### 7.3 Release cadence as a performance-adjacent fact

Third-party trackers counting the project's own releases record ten tagged releases between mid-August and 2 November 2026 (v1.119 → v1.124.2, the latter dated 31 October 2026), i.e. a release roughly every two to three weeks, each typically merging newer upstream llama.cpp plus feature work. Cadence is a performance feature in disguise for a fork: it is the mechanism by which upstream engine improvements reach this user base (§8.2).

---

## 8. Strengths / weaknesses

### 8.1 Strengths (each tied to documented behaviour above)

1. **The persona-chat canon is complete and coherent** (§§3–4): two injection points + one conditional lorebook + characters/scenarios/saves + the full sampler stack + presets, all in one UI, all travelling through one native API. No other consumer runner documents an equivalent set.
2. **Zero-install distribution** (§2) matched to a non-technical audience; the five-step quick start is the shortest documented path from "no software" to "roleplaying with a local model" in its class.
3. **Dialect maximalism** (§6.1) makes the installed base of clients — SillyTavern first among them — a distribution channel rather than a compatibility burden.
4. **Honest documentation of trade-offs** (context-shift conditions, RoPE degradation, SWA incompatibilities, "very rudimentary" TextDB, presets that are "artistic rather than practical"). For a volunteer project this candour is a genuine engineering asset: users can reason about the tool.
5. **Longevity through the GGUF bet + backward compatibility:** the project documents support for *all* past GGML/GGUF models ("I plan to keep backwards compatibility with ALL past llama.cpp AND alpaca.cpp models," older README), so a user's model library never strands.
6. **Privacy shape:** fully local/offline operation, inputs sent nowhere (wiki FAQ), no account, no telemetry described anywhere in the public docs.

### 8.2 Weaknesses / risks

1. **AGPL-3.0 consequence (the structural one).** KoboldCpp and Lite are AGPL-3.0 while the engine beneath them is MIT. Anyone who *builds on* KoboldCpp — modifies it, or (under AGPL's network clause) offers a modified version as a network service — takes on copyleft source-disclosure obligations for the whole combined work. For Volmarr's programme this is dispositive and is why this dossier exists in behaviour-only form: the *ideas* in §§3–4 are free to re-implement; the *code* is not a base to fork from for a differently-licensed Go runner. The licence split also confuses users (the "but llama.cpp is MIT" trap appears in third-party FAQs often enough to be a documented confusion).
2. **Fork drift vs upstream llama.cpp (the maintenance reality).** KoboldCpp is a downstream fork carrying a large patch/feature surface (its own server, UI, sampler additions, media engines) on top of a fast-moving upstream. The observable symptoms in the public record: a release cadence of every ~2–3 weeks substantially spent merging upstream model/architecture support; features that must be re-validated per upstream change (release notes repeatedly note model families where context shifting / fast forwarding cannot be used); and documentation that lags the code (the wiki's 2048-era context text surviving into the 16k-default era, §3.5). None of this is a criticism of effort — the cadence shows the work being done — but it prices the fork strategy honestly: the feature canon is bought with a permanent merging tax, paid by what is publicly a very small maintainer team (the README/wiki speak in a single authorial voice, "Concedo").
3. **Single-port, single-process, personal-appliance limits** (§2.2): queueing and a shared password are the documented multi-user story; there is no documented per-user isolation, and the password's documented coverage excludes image routes. Fine for its market; disqualifying, unmodified, for shared serving.
4. **Surface-area sprawl** (§5.5): text + image + video + music + speech + agent in one artefact means every release is a matrix, some subsystems visibly age between touches, and the binary grows (the CUDA variant's size, §2.2). The "everything client" pattern has a carrying cost that shows up as exactly the uneven documentation noted above.
5. **Discoverability hazards the project itself flags:** a malicious lookalike domain (`koboldcpp.com`) prominent enough to warrant a README-top warning — a reminder that single-file distribution via direct download concentrates trust in one channel.

---

## 9. IDEAS TO STEAL — for the Go Ollama work

*Licence-clean by construction: every item below is an idea or a documented behaviour, described in our own words, to be implemented independently in Go. No KoboldCpp code, text, or asset is to be consulted in implementing any of them. Gains and costs are assessed for Volmarr's stated target — a personal, GGUF-based runner for character chat, engineered as an improved Ollama in Go.*

### 9.1 Adopt the persona-chat canon as the feature spec — Memory / Author's Note / World Info

- **Idea:** Ship exactly the three documented injection mechanisms as first-class, user-editable objects: (1) an always-injected head block (Memory), (2) a near-tail steering note with user-settable injection depth (Author's Note), (3) a keyword-triggered lorebook with a context-budget cap (World Info). Plus characters and scenarios as saveable bundles of (mode + character + memory + world info + sampler preset + opening).
- **Gain:** This is the proven minimum complete set for long persona coherence; it is what the fiction market demonstrably chooses a runner *for*. Implementing it in the runner (not hoping a frontend invents it) means every client of our API inherits it.
- **Cost/risk:** Prompt-assembly becomes a designed subsystem with ordering, budgeting and cache-interaction rules (§3.1's tension), not a string concatenation. Budget caps and injection positions need product decisions and tests. Risk of scope creep into "become a frontend" — mitigate by implementing the *objects and assembly* in the runner and keeping editing UIs thin.

### 9.2 Sampler depth as a first-class, per-request API surface — including order

- **Idea:** Expose the full documented stack (temperature, top-k, top-p, top-a, min-p, TFS, typical, repetition/presence/frequency penalties, DRY-class sequence anti-repetition, XTC-class top-choice exclusion, mirostat-class perplexity targeting, dynamic temperature, grammar constraints) **per request**, expose **sampler order** explicitly with a strongly-recommended default, and ship named, shareable, saveable **presets**.
- **Gain:** The clearest documented differentiator against Ollama's standard API (§4.3); for fiction users this *is* the product. Presets turn tuning into a community artefact (shareable feel), which is free R&D and free marketing.
- **Cost/risk:** Each sampler is a small algorithm with sharp edge cases and ordering interactions; the test burden is real, and bad defaults actively harm output (KoboldCpp's own warnings prove the point). Budget for a sampler test-suite and for preset validation. Go implementation must be written from the *published concepts* (DRY/XTC/mirostat are described in their own public literature) — never from KoboldCpp code.

### 9.3 Single-file distribution ambition

- **Idea:** Treat "one file, no install, embedded UI, bring-your-own GGUF" as a release requirement, not a packaging afterthought: per-platform artefacts, backend variants kept minimal, a launcher-grade first-run (model picker, hardware autofit, Launch) with a full CLI flag mirror (`--help` parity).
- **Gain:** Go is unusually well-suited to this (static binaries, cross-compilation, embeddable UI assets) — arguably better suited than the Python+PyInstaller route KoboldCpp documents. It is the distribution shape this audience has already voted for.
- **Cost/risk:** GPU backends resist true single-file purity (KoboldCpp's CUDA/nocuda/oldpc split is the documented evidence). Decide the variant matrix early; expect the CUDA-carrying artefact to be large. Code-signing / platform gatekeeper friction (the README documents macOS whitelisting steps) is part of the real cost.

### 9.4 Context behaviours for append-mostly chat: shifting + fast-forward, with the caveats printed

- **Idea:** Implement KV-cache reuse for unchanged prompt prefixes (fast-forward) and graceful oldest-token eviction at full context (shifting) as defaults for chat workloads — and document, in the UI itself, the condition that prefix-changing features (World Info, edited Memory) reduce reuse.
- **Gain:** For the actual persona workload (hundreds of turns, mostly-append), this is worth more perceived performance than raw decode speed, and it is behaviour a serving-shaped Ollama does not centre.
- **Cost/risk:** Cache-invalidation correctness is subtle; silent wrong-context bugs are the worst class this feature can produce. Needs adversarial tests around edits, lore triggers, and branching/retries. (Independently implementable against llama.cpp-class KV semantics / our own engine design; concepts only.)

### 9.5 Dialect maximalism, with a primary API that is richer than the emulations

- **Idea:** Serve our native API (full sampler/memory surface) **plus** OpenAI-compatible and Ollama-compatible dialects on one port, and say plainly — as KoboldCpp does — that the emulations exist for ecosystem compatibility while the native API is the complete one. Accept extended sampler fields as extensions on the OpenAI routes.
- **Gain:** Instant compatibility with the existing client ecology (SillyTavern-class frontends, OpenAI-base-URL tools, Ollama-only tools via the port trick) without diluting the native design.
- **Cost/risk:** Each dialect is a permanent translation-and-testing obligation, and dialect drift (upstream OpenAI/Ollama API changes) becomes our problem. Keep emulations deliberately *simple* (KoboldCpp's own word for its Ollama API) and version them.

### 9.6 Settings travel with the story; artefacts are promiscuously importable

- **Idea:** A story save contains its generation/sampler settings; autosave restores session state on relaunch; import accepts the ecosystem's existing character-card and world-info formats (Tavern cards incl. PNG-embedded, rival runners' exports, plain text) with placeholder substitution (`{{char}}` / `{{user}}`-class) at runtime.
- **Gain:** Users' creative assets — characters, lore, tuned presets — become portable *into* our runner from day one, removing the switching cost that protects incumbents; and once authored here, they are equally portable out, which this community rewards rather than punishes.
- **Cost/risk:** Format compatibility is a long tail of edge cases; card formats carry embedded-media and untrusted-content handling that needs care. Scope to the documented, widely-used formats first.

### 9.7 The honest-docs pattern, and the two-tier retrieval answer

- **Idea (docs):** Copy the *documentation ethic*: every performance-relevant feature ships with its failure condition written next to it (shifting vs world info; RoPE stretch degradation; SWA incompatibilities). **Idea (retrieval):** offer the two documented tiers — a zero-dependency lexical document lookup inside the product for lore-scale text (TextDB's role), and a real embeddings endpoint for external vector systems — rather than forcing one retrieval religion.
- **Gain:** Trust is this market's currency; the docs ethic is cheap and compounds. The retrieval split avoids both under-serving lore users and over-building a vector stack into v1.
- **Cost/risk:** Honest caveats require actually knowing the failure conditions — i.e. testing for them. Lexical lookup will be compared unfavourably to vector RAG by some users regardless of labelling; label it as plainly as KoboldCpp does.

### 9.8 What NOT to steal

- The **everything-client roster** (§5.5) at launch: video/music/agent breadth is KoboldCpp's *current* shape after years of accretion, not its founding advantage. Founding advantage = §§9.1–9.3. Add side engines (vision, TTS, image) only in the documented priority order the persona workload justifies.
- The **fork-of-llama.cpp maintenance posture** itself: our Go programme should decide its engine relationship (bind, port, or original) with the §8.2 merging tax priced in — KoboldCpp is the case study of both its power and its cost.

---

## 10. Sources

All sources accessed **2026-11-15**. Primary = the project's own public documentation. Secondary = third-party guides/reviews, used only where marked in the text, and never as the sole basis for a core behaviour claim where a primary source exists.

**Primary**

1. KoboldCpp README, `concedo` branch — https://raw.githubusercontent.com/LostRuins/koboldcpp/concedo/README.md — read in full (607 lines) 2026-11-15. Basis for: identity/lineage, feature list, single-file/portable claims, download artefacts, quick start, APIs-and-integrations table, build/backends table, `--nomodel` external providers, Licence section (AGPL-3.0 verification).
2. KoboldCpp Wiki / FAQ and Knowledgebase (GitHub wiki, read via its SourceForge mirror rendering) — https://github.com/LostRuins/koboldcpp/wiki (mirror read: https://sourceforge.net/p/koboldcpp/wiki/Home/) — read 2026-11-15. Basis for: Context Shifting / Fast Forwarding / Smart Context, Memory / Author's Note / World Info definitions, sampler list and default order `[6,0,1,3,4,2,5]` with defaults Top-P 0.92 / RepPen 1.1 / Temperature 0.7, DRY and XTC descriptions, mirostat and grammar FAQs, embeddings (`--embeddingsmodel`), mmproj/vision, Whisper and OuteTTS, TextDB, Kobold API endpoint list, OpenAI API (from v1.45.2) and Ollama API notes, save formats and Lite settings (Persist Autosave, Save File Includes Settings), Horde worker, Admin/`.kcpps`, RAM/VRAM guidance, CLBlast-era build notes.
3. KoboldCpp release-note summaries via the project's SourceForge mirror — v1.78, v1.92.1, v1.96.2, v1.97.4 listings — read 2026-11-15. Basis for: CLBlast downgrade note, `--nofastforward` introduction, world-info 50% cap, SWA introduction and incompatibilities, default context 4k→8k change.
4. Project API reference (hosted) — https://lite.koboldai.net/koboldcpp_api — cited as the project's canonical endpoint reference per README/wiki; endpoint *list* in §6.2 is taken from the wiki's own enumeration.

**Secondary (marked where used)**

5. Arcanum RPGs — "KoboldCpp Settings (2026)" (reading v1.122.1 launcher + wiki + release notes, October 2026) and "SillyTavern + KoboldCpp Setup Guide (2026)" — https://arcanumrpgs.com/blog/koboldcpp-settings/ ; https://arcanumrpgs.com/blog/sillytavern-kobold-setup/ — basis for: 16,384 default context at v1.122.1, flash-attention/shifting/fast-forward defaults, autofit description, SillyTavern connection details.
6. AIFOSS — "KoboldCpp vs Ollama vs llama.cpp for Creative Writing 2026" (1 June 2026, against v1.114.1) and "KoboldCpp Review 2026" — https://www.aifoss.dev/blog/koboldcpp-vs-ollama-vs-llamacpp-creative-2026/ — basis for: sampler-stack enumeration incl. CFG/presence/frequency, llama-server chain ending in temperature (§4.2 point 3), Ollama API sampler gap.
7. AnchorTerminal — "KoboldCpp review (2026)" (facts verified 8 October 2026; updated for v1.124.2) — https://www.anchorterminal.com/tools/koboldcpp — basis for: route inventory, OpenAPI counts at v1.124.2, password route-coverage note.
8. RefusalRate — "KoboldCpp vs Ollama (2026)" (4 November 2026); AICoderScope — "KoboldCpp as a Local Backend…" (August 2026); LocalAIMaster — "KoboldCpp Setup Guide" (against v1.124.2, November 2026); AICompanionGuides — "KoboldCpp Setup Guide for AI Companions (2026)" (against v1.124.2) — basis for: Ollama-emulation and Anthropic-API arrival versions, port-11434 practice, router-mode note, release artefact sizes, release cadence counts. Each such use is flagged in-line.
9. Botserv — "KoboldCpp: Roleplay and Creative Writing Locally" — https://www.botserv.de/en/local-ai/local-ai-software/koboldcpp-roleplay-creative-writing-locally/ — corroboration for World Info / Memory user-level descriptions.

**Unverifiable / absent in the public documented surface as of 2026-11-15**

- **Reranking:** no reranking endpoint, model, or feature found in the README, wiki, or API summaries read. Recorded as absent from the documented surface (§5.4), not as proven non-existent in code (which this dossier does not inspect).
- **First-party performance benchmarks:** the project publishes no tokens/second claims in the documentation read; none are reported (§7.1).
- **Exact index-to-sampler key** for the default sampler order `[6,0,1,3,4,2,5]`: not printed beside the list in the wiki pages read; the order's existence, default status, and reorderability are documented, the key is not asserted (§4.2).
- **Current-default values that move between versions** (context default, SWA default, queue limits): reported only with version stamps from the sources above; the wiki itself lags the releases on these points (§3.5).

*— End of OR-2 dossier. Behaviour and ideas only; no KoboldCpp source was read or used. —*
