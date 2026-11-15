# OR-2 — Jan (Jan Desktop, Menlo Research)

**Dossier type:** Public-documentation behaviour dossier (OR series, Ollama Research Forge)
**Commissioned:** 2026-11-15, by Volmarr — research corpus for an improved Ollama in Go
**As of:** 2026-11-15. All web sources below were accessed 2026-11-15.
**Subject:** Jan — the open-source desktop AI app from Menlo Research: a consumer chat application (threads, Projects, Assistants, files) wrapped around a local GGUF engine, with a model Hub, a hybrid local + cloud provider model, and a built-in local API server.
**Website:** https://www.jan.ai
**Documentation:** https://docs.jan.ai (Desktop docs under https://docs.jan.ai/desktop)
**Changelog:** https://www.jan.ai/changelog
**Repository (as linked from current docs and secondary sources):** https://github.com/menloresearch/jan — the project began under the `janhq` GitHub organisation (https://github.com/janhq/jan); Jan's own data-folder documentation still uses the `@janhq/` namespace for its bundled extensions, and 2026 secondary sources differ on which org name they cite. The organisation rename is recorded here as an observed inconsistency in public sources, not as a verified GitHub redirect chain.
**Engine lineage (as documented):** Nitro (2023–early 2024) → Cortex / Cortex.cpp (2024, a separate Menlo project) → direct, bundled llama.cpp (from Jan v0.6.6 onward), plus an experimental MLX engine on Apple Silicon (from v0.7.7, 2026-02-11).
**Latest release at dossier date:** Jan v0.8.8, 2026-10-28 — a security release that also moves the bundled llama.cpp engine to 0.7.0 (Jan changelog, read 2026-11-15).

> **LICENCE DISCIPLINE — READ FIRST.** This dossier was produced under a clean-room rule: **public documentation and observable, documented behaviour only** — Jan's docs site, Jan's changelog/release-note pages, the project README as summarised in public sources, and published feature descriptions. No source code was read for implementation detail, and nothing below is lifted or reconstructed from code. Every behaviour is described in our own words, at the level a user or an API client can observe it. Where a claim comes from a secondary guide rather than Jan's own pages, that is said explicitly. Where Jan's own documentation is internally inconsistent (it is, on the licence history and on one changelog date — see §1.1 and §6.3), both versions are given with their dates.

> **LICENCE — VERIFICATION RESULT (IMPORTANT CORRECTION TO THE COMMISSIONING PREMISE).** This dossier was commissioned on the premise that Jan is AGPL-3.0. Verification against Jan's own current documentation does **not** support that as the *current* licence:
>
> - **Current, verified 2026-11-15: Apache License 2.0.** Jan's own Desktop Overview page (https://docs.jan.ai/desktop, crawled 2026-11-15) states verbatim: *"Open source: Apache 2.0 licensed, built in public."* Multiple independent October–November 2026 guides that inspected the repository record the same: the repo LICENSE file today carries Apache 2.0, with an added attribution *request* (not a licence condition) that attribution appear in user-facing documentation where appropriate. *[Secondary corroboration; the LICENSE file itself was not read for this dossier, per the discipline above — the docs-site statement is the primary evidence relied on.]*
> - **Historical, verified: AGPL-3.0 / AGPLv3.** Jan's own earlier public pages described *"Jan Framework (AGPLv3)"* and *"Jan Desktop Client & Local server (AGPLv3, built on Jan Framework)"* (Jan "How We Work" page, preserved in the `jan-hq/jan_docs` dataset on Hugging Face, accessed 2026-11-15), and 2024-era descriptions of Jan routinely call it Affero GPL licensed. The related Cortex package (`cortexso`, npm, 2024) likewise listed licence AGPL-3.0.
> - **Therefore:** Jan *was* AGPL-3.0; as of 2026-11-15 it is documented by its own project as **Apache-2.0**. The exact release or commit at which the relicensing took effect could **not** be verified from the primary documentation read for this dossier (see §9.2). §7.2 works through the consequences of both eras. No part of this dossier relies on Jan code in either case — the discipline above was applied regardless of licence.

**Essence, in one paragraph.** Jan is the product-shape study in this corpus: what an Ollama-shaped local engine becomes when it grows a face for non-technical users. Ollama gives a developer a daemon, a registry and an API; Jan gives a person an installer, a first-run download of a house foundation model, a Hub that tells them — before downloading anything — whether a model *fits* their machine, a chat UI with threads, Projects and Assistants, the same screen offering frontier cloud models beside the local ones with the privacy boundary stated in plain words, and, one settings page away, an OpenAI-compatible server on `localhost:1337` that turns the whole app back into infrastructure for other tools. Its engine story is equally instructive, in the opposite direction: Jan burned two engine brands (Nitro, then the Cortex spin-out) before concluding that the right architecture was the boring one — bundle upstream llama.cpp directly, run it as a supervised worker, and spend the saved effort on the product layer. For Volmarr's Rúnmál line — a native desktop shell being built for similar reasons — Jan is the closest public analogue of the *whole product*, not just of the runner inside it.

---

## 2. Product architecture, as documented

### 2.1 The app shell: Tauri, not Electron (current builds)

- Current Jan is a **Tauri** desktop application — a Rust native shell hosting a web frontend — for macOS, Windows and Linux, with full offline support (Desktop Overview, docs.jan.ai/desktop, read 2026-11-15; the Tauri identification is corroborated by Jan's own v0.6.6 changelog, which notes the Linux *"AppImage now works properly with newest Tauri version and it went from almost 1GB to less than 200MB"* — Jan changelog, v0.6.6 page, read 2026-11-15).
- Older third-party descriptions of Jan as an Electron app exist and were true of earlier eras; they are **not** relied on here for the current architecture. *[Era confusion in secondary sources is common for this project; where a secondary source says "Electron," treat it as dated unless it names a 2026 version.]*
- Distribution, per the install docs and changelog: macOS `.dmg`; Windows installer (the desktop executable was renamed to `Jan-Desktop` in v0.8.5); Linux `.deb`, AppImage, and Flatpak via Flathub — the Linux install page calls Flatpak *"the recommended way to install Jan on Linux"* (docs.jan.ai/desktop/install/linux, via search extract, accessed 2026-11-15). Linux ARM64 builds are listed by 2026 secondary guides. *[ARM64: secondary source.]*
- No account is needed: the QuickStart is download → install → launch → Jan *"automatically downloads its default foundation model on first launch… you're ready to chat — no setup required"* (docs.jan.ai/desktop/quickstart, read 2026-11-15).
- The Desktop Overview also maps the wider product family as Jan itself presents it in 2026: **Jan Desktop** (the app), **Jan Web** (chat.jan.ai, *"a direct alternative to chatgpt.com"*), **Jan Server** (the local API server, §2.4), **Jan Models** (Menlo's own foundation models, §3.4), **Jan CLI / Jan Agent** (a separately installed terminal agent that connects to Desktop's Local API Server), and **Jan Platform** (*"the infrastructure layer for building AI products on top of Jan. (Coming Soon)"*). Cowork — an autonomous task mode — is documented as a preview/nightly-channel feature. This dossier covers Jan Desktop; the Agent/CLI line is noted only where it touches Desktop behaviour.

### 2.2 The local engine today: bundled llama.cpp with a router

Per the Local AI Engine guide (docs.jan.ai/desktop/local-engine/llama-cpp, read 2026-11-15):

- *"The llama.cpp engine is built into Jan and updates together with the app, so there is no separate engine version to download or pick."* **Settings > Model Providers > Llama.cpp** shows the engine version, build and commit, and the docs instruct users to quote those when reporting a model that fails to load. To run a *different* llama.cpp version, the documented escape hatch is to run your own `llama-server` and connect it to Jan as a custom endpoint (§3.3).
- **Router mode:** *"Jan v0.8.0 introduced a router that loads and unloads models on demand. Since v0.8.5, the engine ships with Jan and runs in a separate worker process. Old downloaded backends are no longer used; update Jan rather than installing a backend separately."* A **Max Concurrent Models** setting caps how many models the router keeps loaded (1 = strict single-model operation; 0 = unlimited).
- Engine-wide settings (applied to every model the router loads) and per-model overrides (on each model's own settings page) are documented in detail — threads/batch threads, continuous batching, parallel sequences, Flash Attention, KV-cache K/V precision types, mmap/MLock, context shift, prompt-cache RAM (default 8,192 MiB), cache reuse, RoPE controls, Mirostat, GBNF grammar and JSON-Schema output constraints, and per-model context size, GPU layers, chat template and `chat_template_kwargs`. The full inventory matters less than the *placement*: consumer app on the surface, essentially the whole llama.cpp tuning surface one settings page down, with defaults the docs repeatedly advise most users to leave alone.
- A second local engine, **MLX**, is offered on Apple Silicon only and is explicitly labelled **experimental** (docs.jan.ai/desktop/local-engine/mlx, read 2026-11-15): macOS 14+, M1 or later, models in MLX-Swift format served by a Jan-managed local inference server built on `mlx-swift-lm`. Documented limitations: **embeddings unavailable** (so no RAG on MLX — use llama.cpp), reasoning output not surfaced separately, and some newer architectures fail to load. Jan ships MLX-format versions of its own foundation models.

### 2.3 The Cortex lineage — and the extensions model

Jan has had three engine stories. The documented arc:

1. **Nitro (2023 – early 2024).** Jan's original built-in inference server, described in 2024-era Jan material as supporting llama.cpp and NVIDIA TensorRT-LLM engines; a "Nitro-TensorRT-LLM Extension" appears in Jan's changelog for 2024-03-19 (jan.ai/changelog, read 2026-11-15).
2. **Cortex / Cortex.cpp (2024).** Menlo generalised the engine into a **separate project**: a C++ "Local AI API Platform" with a Docker-inspired CLI (`cortex pull`, `cortex run`, `cortex serve`, `cortex engines install …`), client libraries, an OpenAI-compatible API goal (its roadmap named the full OpenAI API including Tools and multimodal), and **swappable engines** — llama.cpp by default, with ONNX Runtime and TensorRT-LLM as further engines (Cortex README as summarised in public Cortex documentation mirrors, accessed 2026-11-15). *[Cortex details in this paragraph are from public README summaries and package pages — secondary mirrors of the project's own README — not from Jan's current docs, which no longer document Cortex. Ports differ by era/source: the Cortex.cpp README summary gives a REST API at `localhost:39281`; the 2024 `cortexso` npm package describes `cortex serve` starting a server at `http://localhost:1337`. Treat both as era-specific.]*
3. **Direct llama.cpp (2025– ).** Jan v0.6.6's changelog is explicit and is the key primary document: *"Direct llama.cpp Access: Models now interface directly with llama.cpp (previously hidden behind Cortex)"*; *"Automatic Migration: Your existing models seamlessly move from Cortex to direct llama.cpp management"*; breaking change: *"Cortex extension is deprecated in favor of direct llama.cpp integration"* (jan.ai/changelog/2025-07-31-llamacpp-tutorials, read 2026-11-15). From there the line runs to the bundled, worker-process engine of §2.2 (v0.8.5) and its 0.7.0 engine bump in v0.8.8.

**Extensions, as observable in current public documentation.** Jan's Data Folder guide (docs.jan.ai/desktop/data-folder, read 2026-11-15) documents an on-disk `extensions/` directory in the user's data folder — *"Add-on central"* — holding bundled extensions under the `@janhq/` namespace, named by function: `assistant-extension`, `conversational-extension`, `download-extension`, `llamacpp-extension`, `mlx-extension`, `rag-extension`, and `vector-db-extension`, alongside an `extensions.json`. Behaviour-level reading: Jan's capabilities — engines, assistants, conversation storage, downloads, retrieval — are packaged as separable add-on units installed into the user's data folder rather than being indistinguishable monolith features. Two qualifications, stated plainly:

- The **current Desktop documentation does not present a public third-party extension store or a user-facing "install an extension" flow** in the pages read for this dossier. In the current product, the extensibility a *user* actually touches is (a) model providers (§3.3) and (b) **MCP servers** (§2.5). The extensions layer reads, in 2026, as Jan's internal modularity made visible on disk — historically a public architecture (2024-era Jan material describes a framework for building on Jan), today primarily a bundling mechanism. *[This characterisation is an inference from the documentation's shape, marked as such.]*
- The separate **Jan Agent** product documents its own plugin/skill system (docs index, docs.jan.ai/llms.txt, read 2026-11-15); that is the terminal agent's extensibility, not Desktop's, and is not conflated with it here.

### 2.4 API-server mode: OpenAI-compatible at 127.0.0.1:1337

Per the Local API Server guide (docs.jan.ai/desktop/api-server, read 2026-11-15):

- *"Jan provides a built-in, OpenAI-compatible API server that runs entirely on your computer, with local models powered by llama.cpp or MLX (on Apple Silicon Macs). Use it as a drop-in replacement for cloud APIs…"*
- **Startup rule:** the server needs a loadable **local** model to start. You download/import one, pick it under **Settings > Local API Server > Default Model**, and click **Start Server**; Jan reuses an already-loaded model or loads the default first. *"Once running, the server can also route requests to configured remote or custom providers, but those providers do not replace the local-model startup requirement"* — and the docs add, in so many words, that *"requests routed to remote providers are not offline or confined to your computer."*
- **Defaults:** host `127.0.0.1`, port `1337`, API prefix `/v1` — i.e. `http://127.0.0.1:1337/v1/chat/completions` — with host, port and prefix all changeable in a Configuration panel.
- **Security/config surface, all in the same panel:** an optional API key (sent as a bearer token; empty = no auth, with the docs warning against that when binding to `0.0.0.0`), a **Trusted Hosts** allowlist, a request timeout, CORS (enabled by default), verbose server logs, and an **Execute Tools on Server** toggle (off by default) controlling whether MCP tool calls arriving via chat completions are executed server-side or returned to the client to dispatch.
- **Hardening trajectory (from the changelog):** v0.8.5 made the server enforce Trusted Hosts when bound to `0.0.0.0`; v0.8.8 (2026-10-28) is a dedicated security release tightening local-API request-origin checks, chat-link handling, and file/path/shell-profile checks, alongside the engine bump. The direction of travel is consistent: a localhost tool being retrofitted, release by release, for the fact that users *do* expose it to LANs and browsers.
- **Ollama compatibility:** no Ollama-native API dialect (`/api/chat`, `/api/tags`, …) is documented for Jan's server in the pages read for this dossier. Jan's documented compatibility target is the **OpenAI** shape (plus, on the *client* side, Anthropic-compatible endpoints, §3.3). Recorded as an absence: if an Ollama dialect exists, it is not part of Jan's public documented surface as of 2026-11-15. This is a genuine product difference from Ollama itself and from dialect-maximalist peers in this corpus (see the KoboldCpp dossier, §6 of that file).

### 2.5 Tools and MCP: the current extensibility story

Per the MCP guide (docs.jan.ai/desktop/mcp, read 2026-11-15): Jan is an **MCP host**. Users add MCP servers under **Settings > MCP Servers** (command + arguments + environment variables; Node.js and/or Python on the machine are prerequisites for typical servers), and models with tool-calling capability can then read files, query data sources, search the web, drive a browser, and call web APIs through the standard protocol. Jan also ships built-in web search/fetch tools (QuickStart) and documents per-tool permissioning as its core safety behaviour: **each tool call must be approved individually, with the approval panel inline in the chat's tool card showing the exact arguments**, unless the user opts into Allow All MCP Tool Permissions in Settings. MCP left experimental status in v0.6.9 (2025-08-28, changelog). The docs are candid about the costs: tools consume context window, not all local models tool-call well, and prompt injection through tools is named as a live risk.

### 2.6 Data on disk: file-over-app

The Data Folder guide documents a user-visible, user-movable data directory (Windows `%APPDATA%/Jan/data`; macOS `~/Library/Application Support/Jan/data`; Linux `~/.local/share/Jan/data` by default) containing, in plain formats: `threads/<thread_id>/` (`thread.json` + `messages.jsonl`), `assistants/<id>/assistant.json`, per-engine model folders with a `model.yml` per model (path, name, size, SHA-256, embedding flag) beside the `.gguf`, the `extensions/` tree of §2.3, `files/`, `logs/app.log`, and the llama.cpp router's preset file. *"Jan stores your data locally in JSON format. Your data is yours alone."* Relocation is a Settings operation (Settings > General > Jan Data Folder). This inspectability is a documented product property, and §8 returns to it.

---

## 3. Model management, as documented

### 3.1 The Hub: an app-store front end over Hugging Face

Per the Model Management guide (docs.jan.ai/desktop/manage-models) and QuickStart (both read 2026-11-15):

- *"The easiest way to get started is using Jan's built-in model hub (which is connected to HuggingFace's Model Hub)"*: open the **Hub** tab, browse or search, open a model for details, click **Download**, then pick the model in any chat's model selector. Downloads show live progress in the top bar, can be cancelled, and (from v0.8.2) can be paused/resumed.
- **Fit labelling is the Hub's signature behaviour:** *"Each model shows a colored fit pill — Fits, May be slow, or Won't fit — based on your hardware. Quantization tiers are grouped as Small, Balanced, or Large, with a Recommended tag on the default download. No data is downloaded to determine fit status."* The QuickStart says the same in user language: *"Each model shows whether it fits your hardware, so you can pick one your machine can run comfortably."*
- **Bulk hygiene:** Settings for each engine offers **Delete All** for managed downloads (showing total space to be freed; user-imported models are left untouched), and v0.8.0 added bulk model deletion and per-model fit labels in the provider lists (changelog).

### 3.2 Import paths (four documented doors for the same GGUF)

1. **Hub download** (§3.1) — curated browse/search over Hugging Face.
2. **By Hugging Face ID** — paste a model ID (the docs' example form is `org/model_name`) into the Hub search bar and choose a quantisation; gated models are supported by entering a Hugging Face access token in Settings.
3. **From Hugging Face's own pages** — *"On any model page, click Use this model; under Local Apps, select Jan"* (Model Management guide).
4. **Import in place** — in the engine settings, **Import** links a GGUF (or MLX) file already on the computer *"in place without copying it… useful for models downloaded via your browser from Hugging Face, or models shared with other apps"*; deleting a linked model in Jan leaves the original file intact (llama.cpp engine guide). This link-don't-copy detail matters: it makes Jan composable with a model library the user already keeps for other tools, instead of demanding a second copy of every multi-GB file.

### 3.3 Engine switching and the hybrid posture: local and cloud in one selector

Jan's documented posture is explicitly hybrid, and the QuickStart states it as a headline feature: *"Jan runs models two ways, and you can mix both in the same app: Local models run entirely on your machine — private, offline, no API key. This is the default. Cloud models run on a provider's servers (OpenAI, Anthropic, Google, and more). They need an API key but let you use the largest frontier models without local hardware."*

- **Local engine switching:** llama.cpp (GGUF, all platforms, documented as stable) vs MLX (Apple Silicon only, experimental, separate model format) — switchable per model in the same Hub and Settings structure, with Jan's own foundation models offered in both formats (§2.2).
- **Cloud providers (per the docs index, docs.jan.ai/llms.txt, read 2026-11-15):** first-class setup guides for Anthropic, Google, Groq, Mistral AI, OpenAI, Azure OpenAI, OpenRouter, and Hugging Face (Router / Inference Endpoints), plus **Custom Endpoints** — *"Connect Jan to any OpenAI-compatible or Anthropic-compatible API endpoint, including self-hosted servers and proxies"* — which is also the documented route for pointing Jan at your own `llama-server` (§2.2) or any other local runner.
- **The boundary is made visible, repeatedly, in Jan's own words:** the API-server guide warns that remote-routed requests are not offline (§2.4); the File Upload guide warns that *"when using a local model, your files never leave your device. If you use a cloud provider (e.g. OpenAI, Anthropic), files are sent to that provider's API as part of the request"* (§4.3); the Privacy guide says of cloud models *"that's between you and them — Jan just makes the introduction. Local models keep everything at home"* (§6.4). The hybrid is not hidden behind a unified abstraction; the user picks the model per chat, and the model *is* the boundary.
- API keys are entered per provider under Settings > Model Providers. No Jan account mediates them.

### 3.4 Jan's own foundation models

Menlo does not only wrap other people's models; Jan ships and defaults to **house models**, documented in the docs' Models section (accessed 2026-11-15): Jan-v3-4B (a 4B instruct model distilled from a larger teacher, base Qwen3-4B-Instruct-2507, 262,144-token native context per its model page), Jan-Code-4B (its code-tuned variant), Jan-v1 (4B reasoning), Jan-Nano in 32k and 128k-context forms (small models built for MCP/tool-orchestrated research), Jan-v2-VL (8B vision-language, for agentic tasks), and Lucy (1.7B, web-search/tool-calling). The first-run auto-download (§2.1) installs a default from this line, so a new user's first conversation is with a Menlo-tuned small model chosen to behave well (tool use, instruction following) on modest hardware — an onboarding decision as much as a modelling one. The model pages' benchmark claims are Menlo's own and are **not** reproduced here beyond existence and positioning; this dossier did not independently verify any benchmark figure.

---

## 4. Chat and product memory features, as documented

Jan's "memory" is product memory, in three distinct layers. They are kept separate here because Jan's own documentation keeps them separate — and because the contrast with the persona canon (§4.4) turns on exactly which layers exist and which do not.

### 4.1 Threads: the conversation unit

- A **thread** is a single conversation, persisted as a folder (§2.6): `thread.json` (title, timestamps, active model settings, and a **clone of the assistant configuration** in use) plus `messages.jsonl` (one JSON object per message, including role, content, status, and token-speed metadata in the documented example). Threads live in the sidebar, can be organised into Projects (§4.2), and carry per-thread settings.
- Documented thread-level behaviours from the 2026 changelog include navigable **message version branching** (v0.8.3), persistent per-thread and per-message error surfacing (v0.8.1), per-thread activity indicators (v0.8.0), and a fix keeping a thread inside its Project when a document is attached (v0.8.7). The pattern: threads are treated as durable work artefacts to be resumed, branched and debugged — not as ephemeral chat scrollback.
- Engine-side continuity for long threads is provided by the llama.cpp prompt-cache machinery (engine guide: prompt-cache RAM budget, cache-reuse chunk size, context shift) rather than by any summarisation feature. No automatic conversation summarisation or learned user-profile memory is documented for Jan **Desktop** chat in the pages read. (The separate Jan Agent documents a file-based durable Memory for its terminal workflow, and Desktop's nightly Cowork documents an agent workspace with `memory/`, `skills/` and `subagents/` stores — Data Folder guide. Both are agent-workspace features, explicitly stored separately from Desktop chat, and the Data Folder guide notes the Agent's stores under `~/.jan/` are *"not automatically shared"* with the Desktop data folder. They are recorded here as an emerging fourth layer, not as Desktop chat memory.)

### 4.2 Projects: shared context containers

Per the Projects guide (docs.jan.ai/desktop/projects, read 2026-11-15): *"Projects let you organize your AI work around a topic or goal. Each project has its own conversations, an assigned assistant, and a shared set of files — all in one place."* All conversations inside a project share the same assistant and the same files; the assistant's instructions apply automatically to every conversation in the project; uploaded project documents are available as context across all of the project's conversations (§4.3). Projects arrived in v0.7.0 (2025-10-02, changelog) and file uploads inside Projects in v0.7.7.

### 4.3 Assistants and file attachment / retrieval

**Assistants** (docs.jan.ai/desktop/assistants, read 2026-11-15): *"Jan allows you to give models specific sets of instructions without having to repeat yourself. We called these models with your instructions, Assistants. Each of these assistants can also have their own set of configuration which can help guide how the AI model should behave and respond to your inputs."* Behaviour, in full:

- Create/edit/delete under Settings > Assistants; an assistant is a name, a description, and **instructions** (the docs' examples are a Python/JavaScript software-engineering mentor, and a casual brief-explanations persona), plus its own configuration/settings.
- Switch assistants **from the chat input** without entering Settings (the `+` menu → Use Assistant; the active one is checkmarked).
- Assign an assistant **to a Project** so every conversation in it inherits the persona/instructions (§4.2).
- The documented use cases are task-shaped: *"translation, travel planning, financial advice"* (Assistants guide).
- On disk (Data Folder guide), the default assistant is an `assistant.json` whose shape is openly OpenAI-Assistants-flavoured: `id`, `name`, `description`, an emoji `avatar`, `model: "*"` (all models allowed), `instructions`, `file_ids`, and a `tools` array whose documented entry is a **retrieval** tool. The default "Jan" assistant's stored instructions are tool-use instructions ("You have access to a set of tools to help you answer the user's question…"), and its retrieval tool is shown **disabled** in the documented example, with retrieval settings of `top_k: 2`, `chunk_size: 1024`, `chunk_overlap: 64`, an optional time-weighted retriever toggle, and a fixed retrieval prompt template of the form "Use the following pieces of context to answer the question at the end. — CONTEXT: … — QUESTION: … — Helpful Answer:".

**Files and retrieval** (docs.jan.ai/desktop/file-upload and /desktop/projects, read 2026-11-15) come in exactly two documented forms:

1. **Per-message attachments.** Attach images, audio or documents to a single message (via the `+` menu, drag-and-drop, or clipboard paste for images). Capability-gated: **Add Images** appears only when the active model has the `vision` capability; **Add Audio** (WAV/MP3, with a preview chip showing filename and duration) only when the model supports audio input. *"All files are processed locally on your machine"* — with the cloud caveat of §3.3.
2. **Project files (the RAG path).** *"Upload documents to a Project and Jan will chunk and index them for retrieval across every conversation in that project."* Supported formats include PDFs, Markdown, Office documents (DOCX, XLSX, PPTX) and code files; the Files panel shows each file with its size and **chunk count**, and upload shows chunking progress. Retrieval runs through the assistant retrieval machinery above (chunking + embedding-based retrieval; hence llama.cpp-only, since MLX has no embeddings, §2.2), with the `rag-extension` and `vector-db-extension` present in the extensions folder (§2.3).

So Jan's document memory is: **chunked, indexed, project-scoped retrieval, configured per assistant** — a "chat with my documents, across this project's threads" feature. It is not a per-chat lore system, and it is not automatic long-term memory of the user.

### 4.4 The contrast with the KoboldCpp persona canon — precise and fair

This corpus's KoboldCpp dossier (OR-2 — KoboldCpp, §§3–4 of that file) establishes the persona canon Jan should be measured against: **Memory** (a user-authored block always injected at the head of every prompt), **Author's Note** (a steering note injected *near the end* of the prompt, with user-settable injection depth), **World Info** (a keyword-triggered lorebook — entries join the prompt only when their key appears in the recent text, under a context-budget cap), **characters and scenarios** as saveable bundles (mode + character + memory + world info + sampler preset + opening, with settings travelling inside the story save file), Tavern-format character-card interoperability, and a deep creative sampler stack (DRY, XTC, Mirostat-class controls) with shareable presets.

Against that canon, Jan's documented position is:

| Persona-canon element (KoboldCpp) | Jan equivalent, as documented | Verdict |
|---|---|---|
| Assistant/character instructions | **Assistants**: named instructions + configuration, switchable mid-chat, inheritable by Projects | Present — but framed and exemplified as *task* personas (mentor, translator, travel planner, financial advice), not as persistent fictional characters |
| Always-injected head block (Memory field) | The assistant's `instructions` are the standing prompt for threads using that assistant; a Project applies its assistant's instructions to every conversation in it | Functionally adjacent — one standing instruction block per assistant/project. No separate "facts that must survive eviction" field distinct from instructions is documented |
| Near-tail steering with injection depth (Author's Note) | **None documented.** No positional injection control (head vs depth-N) appears in the Assistants, Projects or Model Settings pages read | Absent — Jan has no documented equivalent of scene-level, recency-weighted steering |
| Keyword-triggered lorebook (World Info) | **None documented.** Jan's conditional-context mechanism is embedding retrieval over chunked *documents* (project files / assistant retrieval), triggered by semantic similarity to the query, not by user-authored keyword → entry rules | Absent as a lorebook; retrieval solves a different problem (see fairness note) |
| Character/scenario as a portable artefact | Assistants are stored as individual `assistant.json` files on disk; threads snapshot the assistant configuration they used. No character-card format support (Tavern/PNG cards), no scenario object bundling instructions + files + sampler preset + opening greeting is documented | Partial — the assistant file is a portable prompt artefact; the *bundle* and the *ecosystem format* are not there |
| Story saves (narrative + settings in one file) | Threads persist as `thread.json` + `messages.jsonl` with model settings and assistant clone — a work-session save, reopenable and branchable | Adjacent in mechanism (settings do travel with the thread), different in intent: resuming work, not continuing a story world |
| Creative sampler depth + presets | Jan exposes llama.cpp's sampler surface per model (temperature/top-k/top-p/min-p, repeat controls, Mirostat, grammar/JSON schema — engine and model-settings guides) | Substantial overlap on raw controls; no documented fiction-oriented preset culture (named, shareable "writing style" presets saved with the artefact) in the pages read |

**Fairness note — the two systems are answering different questions, and each is better at its own.** KoboldCpp's World Info answers: *"remind the model of invented facts about my world, only in the scenes where those facts are relevant, at zero standing token cost."* Jan's project retrieval answers: *"let every conversation in this work project ask questions of these real documents I uploaded."* Keyword lore is deterministic, author-controlled and free to run (no embedding model needed); embedding retrieval needs no authoring effort and scales to documents nobody would hand-key. Neither substitutes for the other — a persona runner needs the first and can borrow the second; a productivity app needs the second and has no use for injection depth. The precise contrast is therefore not "Jan lacks memory features" — Jan has threads, projects, assistants and retrieval, a coherent *work* memory — but: **Jan's memory canon is organised around tasks, documents and sessions; KoboldCpp's is organised around a persistent invented world and a character who must stay in character inside it.** Jan's assistants are productivity-shaped by design and by every example its own documentation chooses. A personal runner aimed at character chat should treat Jan as the model for everything *around* the conversation (onboarding, projects, files, hybrid providers) and KoboldCpp as the model for everything *inside* it.

---

## 5. Hardware and performance, as documented

### 5.1 The inheritance, stated honestly

Jan publishes **no first-party tokens/second claims** in the documentation read for this dossier, and this dossier records none. Jan's performance is llama.cpp's performance (plus, on Apple Silicon, MLX's), and Jan's own docs frame it that way: the engine guide is a configuration guide for the bundled llama.cpp, not a benchmark page. The honest statement is the same one this corpus makes for KoboldCpp: same GGUF, same quantisation, same backend ⇒ llama.cpp-class speed; Jan's own contributions are in *loading behaviour, defaults and fit guidance* (§5.3), not in a faster kernel.

### 5.2 Backends and platform requirements, as documented

From the llama.cpp engine guide (read 2026-11-15), Jan bundles its backends with the app:

- **Windows/Linux, NVIDIA:** CUDA 13 where supported; GPUs/drivers that cannot run CUDA 13 (e.g. Pascal / GTX 10-series) fall back to **Vulkan**. No CUDA Toolkit install is required. (v0.8.6 restored native Turing code after v0.8.5's PTX toolchain error — changelog/engine guide.)
- **Windows/Linux, AMD and Intel:** **Vulkan** with a Vulkan-capable driver; the Linux AppImage uses the system Vulkan loader from v0.8.6. The changelog additionally records **AMD ROCm/HIP backend support on Linux** arriving in v0.8.2 (2026-06-01).
- **Apple Silicon:** Metal acceleration, no separate backend install; plus the experimental MLX engine (§2.2).
- **CPU-only operation** is a documented mode: turn off the GPU switches under Settings > Hardware > GPUs (or set GPU layers to 0).
- **Intel Macs are excluded from local inference:** *"The bundled local engine does not support Intel Macs"* (engine guide); the API-server guide dates this to v0.8.5 and notes MLX also requires Apple Silicon. Intel-Mac users are pointed at remote/custom providers — i.e. on that hardware Jan is a cloud client only.

Published minimums (Linux install page, via search extract, accessed 2026-11-15): Debian/Ubuntu, Fedora/RHEL, Arch or openSUSE; **CPU with AVX2** (Intel Haswell 2013+ / AMD Excavator 2015+); **8 GB RAM minimum, 16 GB recommended; 6 GB VRAM minimum for GPU acceleration; 10 GB free storage**. Windows guidance in secondary summaries of the install docs matches (Windows 10+, AVX2, 8/16 GB RAM, 10 GB storage). The macOS RAM-to-model guidance, as reported by a 2026 guide quoting Jan's Mac install page: **8 GB → models up to ~3B; 16 GB → ~7B comfortably; 32 GB → ~13B with headroom**. *[Mac table: secondary source quoting the install docs; treat the shape as documented guidance, the exact wording as unverified.]*

### 5.3 Jan-specific performance behaviour (the part that is actually Jan's)

- **Fit-before-download** (§3.1): the Hub's fit pills and Small/Balanced/Large quant tiers are a performance feature in disguise — they move the sizing decision to *before* the multi-GB download, using hardware detection the v0.6.6 changelog describes as automatic GPU/hardware capability detection.
- **Router loading** (§2.2): models load/unload on demand under a concurrency cap, so a multi-model library does not mean multi-model residency; v0.6.6 added auto-unload of unused models and more accurate memory reporting.
- **Prompt-cache economics:** engine-wide prompt-cache RAM budget (default 8,192 MiB), cache-reuse chunking, continuous batching and parallel sequences are exposed with defaults aimed at multi-conversation/tool workloads (engine guide).
- **Speculative decoding:** v0.8.0 shipped Multi-Token Prediction (MTP) support for compatible llama.cpp models; v0.8.8 added per-model MoE expert GPU cache and probabilistic draft sampling / draft batch size settings for speculative decoding (changelog).
- **Worker isolation:** since v0.8.5 the engine runs in a separate worker process — a stability property with a performance corollary: an engine crash does not take the app (and its threads/settings state) down with it. *[The crash-isolation rationale is stated in 2026 secondary coverage of the v0.8.5 notes; the worker-process fact itself is from Jan's own engine guide.]*

---

## 6. Project health, as public fact

### 6.1 Who Menlo Research is, on the public record

- The legal entity named in Jan's privacy policy is **Menlo Research Pte Ltd** (docs.jan.ai/desktop/privacy-policy, via search extract, accessed 2026-11-15). Jan began in 2023 as a local/offline open-source AI assistant; the company was subsequently known as Homebrew before becoming Menlo Research — a 2026 company profile dates the Menlo Research rebrand to March 2026 and describes a focus shift toward robotics (its open-source Asimov humanoid), with Jan retained as its on-device/edge-AI line. *[Rebrand dates and robotics framing: secondary source (RobotToday company profile, accessed 2026-11-15); treat as reported, not as Jan-docs fact.]*
- Funding posture, as reported: **bootstrapped and employee-owned, with no disclosed venture funding rounds**; a Tech in Asia profile reports a team of roughly 27, offices in Singapore and Ho Chi Minh City, and a practice of distributing equity to team members and open-source contributors. *[Secondary reporting, accessed 2026-11-15; figures are the publications', not audited.]*
- Jan is therefore not a foundation-model lab's side project or a VC-backed platform play: it is the flagship software of a small, self-funded applied R&D lab that also trains small models (§3.4) and, as of 2026, builds robots. That context explains both its polish-per-head and its strategic wanderings (§6.3).

### 6.2 Release cadence (primary source: Jan's own changelog, read 2026-11-15)

Jan's changelog shows an unbroken release line from v0.4.3 (2023-12-21) to **v0.8.8 (2026-10-28)**. The 2026 line alone: v0.7.6 (Jan 27), v0.7.7 (Feb 11, native MLX), v0.7.8 (Mar 11, Jan CLI + OpenClaw integration), v0.7.9 (Mar 23), v0.8.0 (May 22, router mode + MTP), v0.8.1 (May 29), v0.8.2 (Jun 1, ROCm/HIP + resumable downloads), v0.8.3 (Jun 24, message branching), v0.8.4 (Jul 21, native web search), v0.8.5 (Oct 8, bundled engine), v0.8.6 (Oct 9, hotfix), v0.8.7 (Oct 20, agent subagents), v0.8.8 (Oct 28, security + engine 0.7.0). That is roughly monthly feature releases with hotfixes in between — the cadence of an actively staffed product, sustained through the company's robotics expansion. The project also maintains stable/beta/nightly channels (documented since 2024) and remains at **0.x versioning** despite the maturity claims — a fact worth recording neutrally: after three years and (per secondary sources) millions of downloads, Jan has not declared a 1.0.

Popularity indicators, all secondary and dated: ~44,833 GitHub stars as of 2026-10-07 and an official-site claim of 6.9 million downloads, both as reported by an October 2026 Mac guide; ~45.7k stars in a November 2026 llama.cpp-ecosystem tracker. *[This dossier did not fetch the GitHub repository page itself; star/download figures are reported figures, included for scale only.]*

### 6.3 The Cortex spin-out, as documented — and its lesson

Cortex was Menlo's attempt to make the engine a product in its own right (§2.3): its own name, site (cortex.so), CLI, API and multi-engine roadmap, usable standalone or embedded in Jan. The public record of its trajectory inside Jan is short and complete: Cortex served as Jan's engine layer through 2024 (Jan v0.5.8, 2024-11-14, is changelogged as running models *"through Cortex"*); in v0.6.6 the Cortex extension was **deprecated in favour of direct llama.cpp integration**, with automatic migration of users' models; by v0.8.5 the engine simply *is* bundled llama.cpp. The standalone Cortex.cpp repository persists under the Menlo organisation, but its public documentation summaries available to this dossier date from April 2025, and **whether Cortex is under active standalone development as of 2026-11-15 could not be verified from primary sources** (§9.2). One documentation inconsistency is recorded for completeness: the v0.6.6 changelog *index* dates the release 2025-07-31 while the release *page itself* is headed January 31st, 2025. The deprecation content is identical in both views; the date discrepancy is Jan's, and is flagged rather than resolved here.

The engineering lesson is the durable part: Menlo spent roughly a year building an engine *platform* (swappable engines, its own API surface, its own release train) between its app and llama.cpp, then removed it and went direct — because the abstraction's cost (a second project to maintain, a migration to run, a brand users had to learn) bought engine-swappability that, in the event, the product did not need: llama.cpp won the GGUF world, and the second engine Jan eventually *did* add (MLX) arrived as a sibling extension, not through the Cortex abstraction. §7.3 prices this for our own design.

### 6.4 Privacy posture (documented)

Jan's Privacy guide (docs.jan.ai/desktop/privacy, read 2026-11-15): *"Zero data collection until you say so"* — tracking preferences are chosen at first launch and changeable in Settings; with permission, Jan collects only active-user and retention counts tied to a random ID, processed by PostHog in the EU; it states it does not collect chats, settings, model choices, files or prompts, in any configuration. Local conversations and data stay on the machine (§2.6); the only documented egress is what the user directs at a cloud provider (§3.3) or the opt-in analytics above. For a consumer AI app this is a strong, clearly stated posture — and it is stated in the product's own docs, where users can hold the project to it.

---

## 7. Strengths and weaknesses

### 7.1 Strengths (each tied to documented behaviour above)

1. **Best-in-class onboarding for local AI.** Installer → first launch auto-downloads a house model → chat, with no account, no terminal, no model-selection decision forced on a beginner (§§2.1, 3.4); and when the user *does* choose, the Hub's fit pills answer the only question that matters ("will it run on my machine?") before any download (§3.1). This is the funnel every other runner in this corpus makes the user climb manually.
2. **The hybrid UI with a visible boundary** (§3.3): local and frontier-cloud models in one selector, local as the default, and the privacy consequence of choosing cloud stated at exactly the places it bites (chat, file upload, API routing). It respects the user twice — capability without lock-in, honesty without nagging.
3. **File-over-app data** (§2.6): threads, assistants, model manifests and logs as plain JSON/JSONL/YAML in a folder the user can open, move, back up and diff. Portability and auditability that database-hidden competitors do not offer — and the property that makes third-party tooling (and dossiers like this one, at the documented level) possible.
4. **A server mode that grew up in public** (§2.4): OpenAI-compatible, configured from a settings page, and visibly hardened release over release (Trusted Hosts, origin checks, a dedicated security release) as real-world exposure patterns demanded it.
5. **Product-layer ambition beyond chat:** Projects, Assistants, MCP with per-call approval, web search, agents/Cowork — Jan keeps absorbing the "what do I do with a local model all day?" answers into one app (§§2.5, 4.2), which is precisely the layer pure runners leave empty.
6. **Sustained, staffed maintenance** (§6.2): three years of roughly monthly releases, its own tuned small models, and security releases handled as first-class events.

### 7.2 Weaknesses and risks

1. **Licence-history confusion (documentation debt with legal flavour).** Jan was AGPLv3, is now documented as Apache-2.0 (§1.1), and its own older pages — still publicly mirrored — say AGPLv3. Anyone evaluating Jan for embedding or redistribution must establish *which* licence covers *which* version; the project has not, in the documentation read, published a clear relicensing note. For the avoidance of doubt in our own programme: **current Jan (Apache-2.0) imposes no copyleft barrier** — but this dossier's docs-only discipline was applied anyway, and any use of *Cortex-era or pre-relicensing Jan code* would need its own licence check, since the 2024 Cortex package was AGPL-3.0 and AGPL obligations attach to the versions released under it. The generalisable warning: a licence change without a loud, dated announcement taxes every future evaluator.
2. **Engine/app coupling, second form.** Jan escaped the Cortex abstraction only to couple itself to a *bundled* engine: updating llama.cpp now means updating Jan, and a user who needs a different engine build must leave the app for their own `llama-server` (§2.2). The escape hatch exists and is documented, which softens this from a trap to a trade — but the trade is real, and it is the mirror image of Ollama's daemon-coupled-to-its-own-build problem.
3. **Platform cliff: Intel Macs.** Dropping local inference on Intel Macs (v0.8.5) is defensible engineering (dead architecture, Metal-less) but it silently converts a class of installed users into cloud-only clients, and the docs state it without a migration story beyond "use a provider" (§5.2).
4. **Two-format local world.** llama.cpp/GGUF (stable, full-featured) vs MLX (experimental, no embeddings/RAG, partial architecture coverage) means Mac users face a per-model engine decision with feature consequences that are easy to miss — the docs are honest about it (§2.2), but the fragmentation is inherent to the two-engine choice.
5. **Scope sprawl against a small, self-funded team.** Desktop + Web + Server + CLI/Agent + Cowork + a "Platform (Coming Soon)" + house models + (per secondary reporting) a humanoid-robot programme, from a ~27-person bootstrapped lab (§6.1). The 2026 release line shows Desktop still shipping well; the risk is forward-looking and structural, not a claim about current quality. *[Marked as assessment, not documented fact.]*
6. **Server-mode defaults still assume a friendly localhost.** API key empty by default and CORS on by default are the right defaults for a personal tool and the wrong ones the moment a user binds `0.0.0.0` — Jan mitigates with Trusted Hosts and warnings (§2.4), but the safe path requires the user to read them. A personal runner that ships a server inherits this exact footgun; §8.7 takes the lesson.
7. **0.x forever.** Three years, millions of reported downloads, no 1.0 (§6.2): users and embedders get no stable-surface commitment, and the fast changelog (breaking migrations in v0.6.6 and v0.8.5 alike) shows the project using that freedom. Fine for an app; limiting for infrastructure others build on.

### 7.3 The engine-as-separate-project complexity, priced

Jan's history is the corpus's cleanest natural experiment in engine packaging. **Nitro** (in-app engine, own name) → **Cortex** (separate project, own CLI/API/site, swappable-engine ambition) → **direct bundled llama.cpp** (no brand, no abstraction, worker process + router) → **MLX as a sibling extension** when a genuinely different engine was actually needed. Each transition cost a user-facing migration (the v0.6.6 notes lead with theirs) and a documentation rewrite; the middle step cost a year of platform-building that the final architecture does not use. The pattern to carry forward: *an engine abstraction earns its keep only when a second engine is real, shipped and maintained — until then it is a tax on every release.* Jan paid the tax, published the receipts in its own changelog, and simplified. That is more than most projects manage, and it is the single most transferable engineering fact in this dossier.

---

## 8. IDEAS TO STEAL — for the Go Ollama work and the Rúnmál shell

*Licence-clean by construction: every item below is an idea or a documented behaviour, described in our own words, to be implemented independently. No Jan code, text or asset is to be consulted in implementing any of them. Each item states its gain and its cost/risk.*

### 8.1 The Hub as onboarding: fit first, download second

- **Idea:** A model catalogue that (a) labels every model/variant with a hardware-fit verdict computed locally *before* any download, (b) groups quantisations in plain-language tiers (Jan's Small / Balanced / Large) with one **Recommended** default, and (c) auto-installs a small house default model on first launch so the first conversation happens before the first decision.
- **Gain:** Removes the two highest-dropout steps in local AI (choosing a model blind; downloading 8 GB that then won't load). Directly applicable to both the Go runner's catalogue and Rúnmál's first-run flow.
- **Cost/risk:** Fit verdicts require honest memory accounting (model + KV cache at chosen context + overhead) per platform/backend, and they *will* be wrong at the edges — Jan's three-state pill (Fits / May be slow / Won't fit) is the right humility: a middle state exists precisely so the label never has to lie.

### 8.2 Assistants as packaged prompt + settings artefacts

- **Idea:** A persona/task definition as a single small file: name, description, avatar, instructions, model allowance, and tool toggles (Jan's `assistant.json` shape, §4.3) — creatable in Settings, switchable from the chat input, assignable to a project so all its conversations inherit it, and **snapshotted into each thread** so an old conversation keeps the assistant it was actually held with.
- **Gain:** Personas become portable, diffable, shareable artefacts instead of settings-page state; the thread snapshot solves the "I edited the character and now my saved chat reads wrong" problem before it happens. For a persona-shaped runner this artefact is the natural *base unit* to extend with the Kobold-canon fields Jan lacks (memory block, author's note, lorebook reference, sampler preset) — Jan proves the packaging; the canon supplies the contents.
- **Cost/risk:** A file format is a commitment: version it from day one, or every artefact in the wild becomes a migration. Jan's OpenAI-flavoured shape also shows the temptation to borrow another platform's object model wholesale — interop-friendly, but it imports their assumptions (e.g. retrieval as the only tool).

### 8.3 One UI over local + cloud, with the boundary visible

- **Idea:** A single model selector mixing local and cloud models, local as default, where choosing a cloud model is *itself* the privacy disclosure — reinforced at the three places data can leave: chat, file upload, and API routing (§3.3).
- **Gain:** Users get frontier capability without a second app, and the local-first promise stays credible because it is never silently broken. For Rúnmál especially, this is the documented, user-tested shape of "hybrid."
- **Cost/risk:** Provider sprawl is unbounded (Jan documents eight named providers plus custom endpoints); each is a key-storage, capability-detection and error-surface obligation. The custom-endpoint escape hatch (any OpenAI/Anthropic-compatible URL) is what keeps the long tail affordable — steal that with the idea, not instead of it.

### 8.4 Engine/app separation without an engine platform

- **Idea:** Bundle the engine, run it as a **supervised worker process** under a **router** that loads/unloads models on demand under a concurrency cap, surface engine version/build/commit in Settings, and document the escape hatch (point the app at an external engine server) — the post-Cortex Jan shape (§§2.2, 7.3), adopted *without* repeating the Cortex detour.
- **Gain:** App survives engine crashes; engine upgrades ride app releases users already take; support conversations start from a quoted engine build. The router gives multi-model libraries single-model memory footprints.
- **Cost/risk:** Bundling couples engine CVEs to app releases (Jan's v0.8.8 is exactly an engine-bump-plus-security release); the worker/router layer is real engineering, and per-model vs engine-wide settings split (Jan's two-level scheme) must be designed, not accreted.

### 8.5 Projects: chunk once, share across every conversation

- **Idea:** A project object = assigned assistant + a shared file set, chunked and indexed **once**, retrievable from every thread in the project, with per-file size/chunk-count visible in the UI (§§4.2–4.3).
- **Gain:** Turns RAG from a per-chat ritual into standing context for a body of work; the visible chunk counts teach users what retrieval actually costs. For the Go runner, projects are the natural home for *both* document retrieval and a lorebook — same container, two retrieval mechanisms (§4.4).
- **Cost/risk:** Retrieval quality is bounded by chunking defaults users never tune (Jan's documented defaults are top_k 2 over 1024-token chunks — conservative to a fault for long documents); an embeddings dependency quietly makes one engine (llama.cpp) load-bearing for the feature, as MLX's gap shows.

### 8.6 File-over-app data layout

- **Idea:** Threads, assistants, model manifests (with SHA-256) and logs as plain files in one movable data folder, in formats a user can read with no tooling (§2.6).
- **Gain:** Backups are a folder copy; support is a file the user can send; third-party tools (sync, search, other frontends) can coexist with the app instead of reverse-engineering it. Aligns with this programme's existing plain-portable-forms law.
- **Cost/risk:** Plain files cap how much structure you can enforce — concurrent-write safety, schema evolution and partial-corruption recovery become the app's problem, and a factory-reset story must be designed alongside (Jan has one, and it is appropriately frightening).

### 8.7 The local API server as a settings page — with the safety defaults Jan converged on

- **Idea:** Ship the OpenAI-compatible server as a first-class Settings page: default-model picker, host/port/prefix, optional API key, Trusted Hosts, CORS toggle, verbose logs, and a server-side tool-execution toggle — and copy Jan's *learned* defaults trajectory, not its original one: require the local-model-first startup rule, warn in-line at the `0.0.0.0` choice, and treat origin checks as launch features, not security-release afterthoughts (§2.4).
- **Gain:** The server becomes a feature non-developers can actually turn on, which is what makes a personal runner into household infrastructure (other apps, other devices, agents).
- **Cost/risk:** Every toggle on that page is a support and security obligation forever; a localhost server in a consumer app *will* be exposed to LANs and browsers by users who never read the warnings — budget the hardening releases in advance, as Jan's changelog shows they will come due.

### 8.8 MCP with inline, per-call approval

- **Idea:** Tool extensibility via MCP, with approval **inline in the tool card showing the exact arguments**, per call by default, and an explicit allow-all opt-in for users who choose speed (§2.5).
- **Gain:** Extensibility without building a plugin store or an extension API of your own; the approval UX is the security model, made visible at the moment of risk. Jan's docs also model the honest accompanying copy (context cost, model variability, injection risk).
- **Cost/risk:** Approval fatigue is real — Jan's own allow-all switch exists because per-call approval wears users down; and tool quality is bounded by small local models' tool-calling ability, which no UI can fix.

### 8.9 Capability-gated UI

- **Idea:** Let model capabilities drive the interface: attachment options appear only when the active model supports vision/audio; fit labels appear in every model list; tool-capable models are flagged in the picker (§§3.1, 4.3).
- **Gain:** The UI never offers an action the current model cannot perform — a whole class of "why did it fail?" support load disappears, and capability metadata becomes a catalogue asset rather than documentation.
- **Cost/risk:** Capability metadata must come from somewhere trustworthy (model cards, probing, a curated registry) and be correctable per model by the user, or the gating itself becomes the bug.

---

## 9. Sources

### 9.1 Sources read (all accessed 2026-11-15)

**Jan's own documentation and changelog (primary):**

- Desktop Overview — https://docs.jan.ai/desktop (licence statement, product family, Tauri-era positioning)
- QuickStart — https://docs.jan.ai/desktop/quickstart (first-run model download, Hub, hybrid local/cloud)
- Local AI Engine (llama.cpp) — https://docs.jan.ai/desktop/local-engine/llama-cpp (bundled engine, router, worker process, backends, engine/per-model settings, Intel Mac exclusion)
- MLX — https://docs.jan.ai/desktop/local-engine/mlx (experimental status, limitations, mlx-swift-lm)
- Local API Server — https://docs.jan.ai/desktop/api-server (1337/v1 defaults, startup rule, key/Trusted Hosts/CORS/tool-execution settings)
- Assistants — https://docs.jan.ai/desktop/assistants (instructions + configuration, switching, project assignment)
- Projects — https://docs.jan.ai/desktop/projects (shared assistant + files per project)
- File Upload — https://docs.jan.ai/desktop/file-upload (attachments, capability gating, project chunking/indexing, local-vs-cloud file handling)
- Model Management — https://docs.jan.ai/desktop/manage-models (Hub, fit pills, quant tiers, HF-ID and in-place import, Delete All)
- Settings — https://docs.jan.ai/desktop/settings (providers, HF token, hardware monitoring, data-folder relocation, factory reset)
- Jan Data Folder — https://docs.jan.ai/desktop/data-folder (on-disk layout, assistant.json and retrieval defaults, model.yml, extensions tree, agent-workspace stores)
- Using MCP in Jan — https://docs.jan.ai/desktop/mcp (MCP host behaviour, inline approval, risks)
- Privacy — https://docs.jan.ai/desktop/privacy (opt-in analytics, PostHog EU, no chat/model tracking)
- Docs index — https://docs.jan.ai/llms.txt (provider list, Custom Endpoints, Jan Agent/Platform map)
- Changelog index — https://www.jan.ai/changelog (release dates v0.4.3–v0.8.8)
- Jan v0.6.6 release notes — https://www.jan.ai/changelog/2025-07-31-llamacpp-tutorials (Cortex deprecation, direct llama.cpp, automatic migration, Tauri AppImage note)

**Secondary sources (used only where marked in the text):**

- Jan "How We Work" page as preserved in the `jan-hq/jan_docs` dataset on Hugging Face — historical AGPLv3 statements for Jan Framework and Desktop.
- Cortex.cpp README summaries via public documentation mirrors (Toolerific/DeepWiki renderings of the project README) and the 2024 `cortexso` npm package page (Socket/npm.io) — Cortex CLI, engines, ports, AGPL-3.0 package licence. No Cortex source code was read.
- 2026 product guides and reviews (TechLogHub, ReviewRamble, TolsAI, AnyGen, LocalLLMGuide, a macOS guide at pasqualepillitteri.it, WindowsForum coverage of v0.8.5/v0.8.6) — Apache-2.0 corroboration, star/download figures, install minimums, Mac RAM table, worker-process crash-isolation rationale.
- Tech in Asia (Menlo Research profile) and RobotToday (Menlo Research company overview) — team size, bootstrapped/employee-owned posture, Singapore/Ho Chi Minh City, Homebrew→Menlo rebrand and robotics framing.
- This corpus: OR-2 — KoboldCpp dossier (persona canon, §§3–4 of that file), for the §4.4 contrast.

### 9.2 Unverifiable / open items (recorded, not papered over)

1. **Exact relicensing point (AGPL-3.0 → Apache-2.0):** not stated in any primary page read. The AGPL era is verified (Jan's own preserved pages; 2024 package records) and the Apache-2.0 present is verified (Jan's current docs), but the version/date of the change is **unverified** here.
2. **GitHub repository page itself** (star count, LICENSE file text, org redirect janhq → menloresearch) was not fetched for this dossier; all such figures above are dated secondary reports.
3. **Cortex's current standalone development status** (active, paused, or archived in practice) could not be verified from primary sources accessed 2026-11-15; only its deprecation *inside Jan* is primary-sourced.
4. **Jan Web (chat.jan.ai) and Jan Platform** are documented only at overview level; no behaviour claims about them are made in this dossier beyond existence and positioning.
5. **Benchmark figures** on Jan's model pages (Jan-v3-4B, Jan-Code-4B, Jan-Nano) are Menlo's own claims and were not independently verified; none are reproduced as findings.
6. **ARM64 Linux/Windows builds** are attested by secondary guides, not by an install page read in full for this dossier.
