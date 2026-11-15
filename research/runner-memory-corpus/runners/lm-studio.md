# OR-2 — LM Studio

**Dossier:** OR-2 in the Ollama Research Forge corpus (model runners + memory)
**Subject:** LM Studio — closed-source desktop application for running local LLMs
**Vendor:** Element Labs, Inc.
**Licence:** Proprietary / closed-source. See §1.2 for the published terms stated precisely.
**As of:** 2026-11-15
**Audience:** Yrsa, engineering an improved Ollama in Go. Read this dossier for *product* benchmarks — discovery, download, load ergonomics, chat polish — not for engine internals.
**Links (verbatim from sources read 2026-11-15):**

- Product / docs home: https://lmstudio.ai/docs/app?ref=tako-analytics
- Full docs text dump used for this dossier: https://lmstudio.ai/llms-full.txt
- App Terms of Service: https://lmstudio.ai/app-terms
- “Free for use at work” announcement (2025-07-08): https://lmstudio.ai/blog/free-for-work
- 0.4.0 announcement: https://lmstudio.ai/blog/0.4.0
- App vs. daemon vs. CLI explainer: https://lmstudio.ai/docs/app/basics/lmstudio-vs-llmster-vs-lms
- System Requirements: https://lmstudio.ai/docs/app/system-requirements
- Enterprise Terms: https://lmstudio.ai/business-terms
- Hub Terms: https://www.lmstudio.ai/hub-terms

> **Discipline note — docs and observable behaviour ONLY.**
> LM Studio’s core application and its `llmster` daemon are closed-source. There is no source tree to read for them, and this dossier does not infer one. Every claim below is tied to (a) public documentation published by Element Labs and actually read for this dossier, (b) the published Terms / blog announcements, or (c) clearly-labelled secondary guides describing observable product behaviour (load-screen fields, sliders, CLI output). Where official documentation is silent — notably on KV-cache quantisation field names, see §3.3 — the dossier says so instead of filling the gap. Internals that are not documented are not invented. Speculation, where offered at all, is marked **[Speculation]**.
>
> Surrounding pieces *are* open and are distinguished throughout: the `lms` CLI, the Python and TypeScript SDKs, and the underlying engines (llama.cpp, MLX) have their own licences. Open neighbours do not make the core app open.

## Essence (one paragraph)

LM Studio is the market’s product benchmark for local-LLM user experience: a polished cross-platform desktop app that lets a non-terminal user search Hugging Face inside the product, download a quantised model with a hardware fit check, load it through a visual memory-budget panel (context length, GPU offload, Flash Attention, concurrency), chat with it in a ChatGPT-like client with presets, prompt templates and offline document chat, and — with one toggle — serve the same loaded model over an OpenAI-compatible (and, since 0.4.1, Anthropic-compatible) local API on `http://localhost:1234`. Since 0.4.0 (28 January 2026, per the vendor announcement) the same core also ships headless as the `llmster` daemon, driven by the MIT-licensed `lms` CLI, so the desktop discovery experience and the server deployment share one model store, one runtime-packaging system, and one set of load defaults. Its inference is not its own invention: GGUF models run on a packaged llama.cpp runtime on macOS, Windows and Linux, and MLX-format models run on an MLX runtime on Apple Silicon. The product value is therefore almost entirely *above* the engine — curation, fit estimation, load ergonomics, runtime packaging, and API compatibility — which is exactly why it matters to an Ollama-improvement project even though none of its core code can be read or reused.

---

## 1. Header facts

### 1.1 Identity and version anchor

- **Name:** LM Studio (desktop app); `llmster` (headless daemon); `lms` (CLI). The three-part split is the vendor’s own framing in “LM Studio, llmster, and lms” (docs, read 2026-11-15).
- **Vendor:** Element Labs, Inc., named as “Company” in the App Terms and as the counterparty in the Enterprise Terms (both read 2026-11-15).
- **Launch:** May 2023, per the vendor’s 2025-07-08 “free for work” post (“shortly after launching LM Studio back in May 2023” / linked launch reference). Secondary guides consistently give May 2023; the dossier relies on the vendor post for the month/year.
- **Version anchor for this dossier:** The 0.4.x line. 0.4.0 was announced 28 January 2026 (vendor blog, read 2026-11-15). Multiple secondary checkers citing the official changelog / download page report **0.4.28 (31 October 2026)** as the latest stable on 7–12 November 2026. That version string was **not** read directly from an official changelog page in this research pass — see §9, Unverifiable / limits — so treat “0.4.28” as secondary-verified, while all feature claims below are anchored to official docs / the 0.4.0 announcement that *were* read directly.
- **Platforms (official System Requirements, read 2026-11-15):**
  - macOS: Apple Silicon only (M1/M2/M3/M4 listed), macOS 14.0+, 16 GB+ RAM recommended (8 GB usable for smaller models / modest context). Intel Macs: “currently not supported.”
  - Windows: x64 and ARM (Snapdragon X Elite named); x64 requires AVX2; 16 GB RAM recommended; ≥4 GB dedicated VRAM recommended.
  - Linux: x64 and ARM64 (aarch64); distributed as an AppImage (secondary checkers in November 2026 also report a `.deb` for 0.4.28 — marked secondary); Ubuntu 20.04+ required, with the vendor’s own caveat that “Ubuntu versions newer than 22 are not well tested”; x64 ships with AVX2 by default.

### 1.2 Licence — stated precisely as published

**Core app + `llmster`: proprietary, not open source.**

App Terms of Service, **Version: August 23, 2026** (https://lmstudio.ai/app-terms, read in full for this dossier, 2026-11-15):

- **Grant (§ License Grant):** “a non-exclusive, non-transferable license to use the Software solely for Your personal and / or internal business purposes and solely in accordance with the Documentation.”
- **Trade-secret framing (§ Restrictions On Use):** “You acknowledge that the Software and its structure, organization, and source code constitute valuable trade secrets and Confidential information of Company and its suppliers.”
- **Prohibitions (same section, paraphrased only where quoting would exceed fair summary — the operative verbs are the vendor’s):** no modify / adapt / translate / create derivative works; no integration except through Company-published interfaces; no use of open-source products with the Software in a way that would impose source-disclosure / derivative-licensing / free-redistribution conditions on the Software; **no “sublicense, distribute, sell, use for service bureau use, as an application service provider, or a software-as-a-service, lease, rent, loan, or otherwise transfer”** the Software or Documentation to any third party; no reverse engineering / decompilation / disassembly except to the extent expressly permitted by applicable law; no removal/obscuring of proprietary notices.
- **Paid Features (§ Paid Features and Billing):** “Certain features of the Software may be offered for a fee, including through subscriptions, usage-based charges, or usage credits.” Fees are non-refundable except as required by law or expressly stated; the Company may change Paid Feature pricing/terms with notice where required by law. This clause is in the *current* desktop terms — i.e. “free today” does not contractually freeze all future features as free.
- **Third-party models (§ Specific Disclaimers):** Models are Third Party Products under a separate agreement between the user and the model provider. LM Studio facilitating download/integration does not transfer the model’s licence. A model’s own licence (Llama, Qwen, Gemma, etc.) governs commercial use of *that model* independently of LM Studio’s app licence. This distinction is load-bearing for any commercial deployment and is stated by the vendor itself.
- **Liability cap / remedy:** Sole remedy is to uninstall / stop using (plus cancel a Paid Feature); aggregate liability capped at **$50.00** in the desktop terms as read. Noted here because it is materially different from an MIT/Apache grant and matters for enterprise risk review.

**Commercial use — the July 2025 change:**

- Vendor announcement, **Published: 2025-07-08**, “LM Studio is free for use at work” (https://lmstudio.ai/blog/free-for-work, read 2026-11-15):
  - “Starting today, LM Studio is free to use both at home and at work.”
  - “Until now, the LM Studio app terms stated that for use at a company or organization, you should get in touch with us and get separate commercial license. This requirement is now removed.”
  - “**Starting today, there's no need to fill a form or contact us. You and your team can just use LM Studio at work!**”
- **Precise synthesis (do not overstate):** Since 2025-07-08, *internal* workplace use needs no separate licence, form, or fee. That is **not** the same as an open-source commercial licence: the August 2026 terms still limit the grant to “personal and / or internal business purposes” and still bar service-bureau / SaaS / resale / distribution to third parties. Secondary comparisons that summarise this as “free for commercial use” are correct for internal use and incomplete if read as “may embed/resell/host for others.” This dossier uses the terms’ wording, not the shorthand.
- **Enterprise:** A separate Enterprise offering exists. The July 2025 post describes it as covering SSO, model / MCP gating, and private collaboration, sold by contact (“contact us to get started”). The Enterprise Terms (Version: January 28, 2025, https://lmstudio.ai/business-terms, read 2026-11-15) are order-form terms: non-exclusive, non-transferable licence “solely for Customer's internal business purposes, for the term, on the number of servers and by the number of users, if applicable, specified in an Order Form,” with fees as set in the Order Form, non-refundable, first year payable on execution, thereafter 30 days. **No public Enterprise price was found in the documents read** — it is contact-sales / order-form pricing. Do not quote a number for it.
- **Bionic pricing — separate product, do not conflate:** In 2026 LM Studio also ships **Bionic**, described in docs and secondary coverage as a *separate* agent app built on the LM Studio runtime, with optional US-hosted cloud models. Secondary reviewers summarising https://lmstudio.ai/pricing in October–November 2026 consistently list Free $0 / Bionic+ $20 USD/month / Pro $100 USD/month (Pro = 5× Bionic+ usage limits, early access), plus cloud credits beyond allowance, with local models and LM Link models consuming no credits (the last point is also stated in the official Bionic “Understand Credits and Usage” docs page found via search, 2026-11-15). **Caveat:** this dossier did not fetch the pricing page itself as a primary source (search for `site:lmstudio.ai pricing` returned Hub/Bionic docs, not the pricing page body), so the $20/$100 figures are **secondary-verified, not primary-verified**. They are *not* the price of the core LM Studio desktop app: local inference in the core app is $0 under the terms above. Any reuse of the $20/$100 numbers must carry the “Bionic / cloud, secondary” label.
- **Open neighbours (vendor docs, read 2026-11-15):**
  - `lms` CLI: the docs dump states “`lms` is **MIT Licensed** and is developed in this repository on GitHub: https://github.com/lmstudio-ai/lms” and “The `lms` CLI is open source on GitHub.” (Search-result excerpt from https://lmstudio.ai/llms-full.txt; the CLI reference itself was read via the same dump.)
  - Python SDK (`lmstudio-python`) and TypeScript SDK (`lmstudio-js`): docs link to GitHub source for open-source contribution (https://github.com/lmstudio-ai/lmstudio-python, https://github.com/lmstudio-ai/lmstudio-js as linked in the docs dump).
  - Engines: llama.cpp and MLX are upstream open-source projects (links in official docs to github.com/ggerganov/llama.cpp — as printed in the docs — and github.com/ml-explore/mlx).
  - Consequence: scripts, CLI automation and SDK clients can be inspected and reused under their own licences; the GUI, the daemon core, the catalogue presentation, and the load-panel implementation cannot.

### 1.3 What this dossier is not

It is not a benchmark report (no LM Studio instance was run for this dossier), not a source audit (impossible for the closed core), and not legal advice. Licence paragraphs summarise published terms for engineering planning; a commercial deployment decision still needs the current terms read at decision time, because the vendor may amend them (the terms themselves reserve amendment of system requirements and Paid Feature terms).

---

## 2. Product shape

### 2.1 Three tools, one core (vendor framing)

Official explainer (https://lmstudio.ai/docs/app/basics/lmstudio-vs-llmster-vs-lms, read 2026-11-15):

| Piece | Form | Vendor-described role |
|---|---|---|
| **LM Studio app** | Desktop GUI (macOS / Windows / Linux) | “A user-friendly graphical interface containing the full capabilities of LM Studio.” Search/download from Hugging Face, built-in chat, document chat (RAG), model settings / prompt templates / presets, local server via native REST or OpenAI/Anthropic-compatible endpoints, MCP servers. “The easiest starting point if you're new.” |
| **`llmster`** | Headless daemon, standalone background service, no GUI required | Same model-serving capabilities without installing/launching the GUI. Vendor use cases: Linux server or cloud instance, GPU rig without a screen/display, CI/CD pipeline, background service starting on boot. Installed independently of the desktop app. |
| **`lms`** | CLI | Talks to *either* the desktop app or `llmster`; manages models from the terminal. Bundled automatically with either install. If LM Studio is not already running when an `lms` command is issued, “it will start running automatically” (docs wording). |

Canonical flows from the docs (verbatim commands):

```bash
lms get <model>        # Download a model
lms load <model>       # Load a model into memory
lms ls                 # List models available on disk
lms server start       # Start the local HTTP server
lms chat               # Start an interactive chat session in the terminal
lms log stream         # Stream incoming and outgoing request logs
# Example end-to-end:
lms get openai/gpt-oss-20b
lms load openai/gpt-oss-20b
lms server start       # listens on http://localhost:1234
```

Headless install (0.4.0 announcement + headless/systemd docs in the docs dump, read 2026-11-15):

```bash
# Linux / Mac
curl -fsSL https://lmstudio.ai/install.sh | bash
# Windows
irm https://lmstudio.ai/install.ps1 | iex

lms daemon up          # start the daemon
lms runtime update llama.cpp   # and, on macOS: lms runtime update mlx
```

The docs dump includes a complete systemd pattern for `llmster` on headless Linux: install via `install.sh`, `lms get`, manual test (`lms load` + `lms server start` + `curl http://localhost:1234/v1/models`), then a `Type=oneshot, RemainAfterExit=yes` unit whose `ExecStartPre` runs `lms daemon up` and `lms load … --yes`, `ExecStart` runs `lms server start`, and `ExecStop` runs `lms daemon down`. The docs note the alternative: skip the pinned load and rely on Just-In-Time (JIT) loading and eviction in the server (see §4.3). That a closed desktop product publishes a systemd unit at all is itself a product-position signal: since 0.4.0 it competes for the same “background service” slot as Ollama, not only for the desktop slot.

**Also documented, noted briefly so they are not mistaken for core scope:**

- **Run-on-login service mode** for GUI machines (docs: “run as a service on login”) as the GUI counterpart to the headless systemd setup.
- **LM Link** (docs section in the dump): use a model loaded on a remote device “as if it were loaded locally,” including through the REST API/SDK via `localhost`, with a per-machine preferred-device setting; headless machines join via `llmster` + `lms login` + `lms link enable`. LM Link is a routing convenience, not a new engine.
- **LM Studio Hub:** sharing surface for presets, `model.yaml` definitions, plugins and other artifacts, with public community sharing and (per the July 2025 post) public Hub organisations for free plus private collaboration under Enterprise/Teams. Hub Terms are separate (Version: August 23, 2026).
- **Bionic:** separate agent app (see §1.2). It *uses* the LM Studio runtime for local inference; it does not replace LM Studio. Comparisons of “runners” should compare LM Studio / `llmster`, not Bionic.

### 2.2 Engine layer — documented, not inferred

Official docs home (read 2026-11-15), verbatim in substance:

- “LM Studio supports running LLMs on Mac, Windows, and Linux using `llama.cpp`.”
- “On Apple Silicon Macs, LM Studio also supports running LLMs using Apple's `MLX`.”

Formats that follow from that, as documented across the dump:

- **GGUF** models via the llama.cpp runtime — the cross-platform path.
- **MLX** models (MLX-format / safetensors variants as presented in the catalogue, e.g. the `model.yaml` example in §3.4 resolving one logical model to a GGUF variant plus MLX 4-bit and 8-bit variants) via the MLX runtime, Apple Silicon only.
- Embedding models are first-class alongside LLMs in listings (`lms ls` separates LLMs and Embedding Models; `/v1/embeddings` requires an embedding model loaded).

**What is NOT documented and therefore not claimed here:** the GUI’s internal process architecture, how the daemon isolates model processes, the exact llama.cpp fork/patch set beyond versioning the vendor itself publishes (see §2.3), or any scheduling internals beyond the documented load options in §3 and the continuous-batching note in §5. Secondary guides name GPU backends (CUDA for NVIDIA, Vulkan for AMD/Intel/most systems, ROCm for supported AMD, Metal via MLX/llama.cpp on Mac, CPU fallback) and describe runtime-manager behaviour consistent with the official runtime system; those backend names are **observable / secondary-corroborated**, not quoted from the official System Requirements page, which does not enumerate backends. An engineer should treat the backend matrix as “check `lms runtime survey` / Runtime Manager on the target machine” rather than as a vendor guarantee in the docs read.

### 2.3 Runtime packaging — “LM Runtimes” (a first-class idea, see §8)

This is one of LM Studio’s most transferable designs, and it *is* officially documented:

- Docs dump, “Downloading runtimes”: “\[LM Runtimes\] are individually packaged software libraries, or LLM engines, that allow running certain formats of models (e.g. `llama.cpp`). As of LM Studio 0.3.0 … it's easy to download and even hot-swap runtimes without a full LM Studio update.” Checking/downloading runtimes requires network requests (listed under “Operations that require connectivity”; core chat/server/RAG do not — see §4.4).
- **Manager UI:** “To install or manage LM Runtimes, press `⌘` `Shift` `R` on Mac or `Ctrl` `Shift` `R` on Windows/Linux.” (Official docs home.)
- **CLI (official CLI reference in the dump):**
  ```bash
  lms runtime ls       # list installed runtimes
  lms runtime get      # download a runtime
  lms runtime select   # set the active runtime (interactive prompts)
  lms runtime remove   # uninstall a runtime
  lms runtime update   # update an installed runtime
  lms runtime survey   # (0.4.0 notes) print info about available GPUs
  ```
- **Versioning example (vendor-published):** 0.4.0 notes require / graduate the GGUF runtime to **llama.cpp v2.0.0** for parallel requests (“Please make sure your GGUF runtime is upgraded to llama.cpp v2.0.0”). A secondary checker citing the official changelog reports 0.4.26 shipping runtime **2.50.0 built from upstream build b11337** — included here only to show that runtimes carry their *own* version line independent of the app version; verify on the changelog before citing the number.
- **Implication:** app updates and engine updates are decoupled. A user can receive a newer llama.cpp (new model architecture, new backend fix) as a runtime download without waiting for / accepting a full app release, and can in principle hold/select among installed runtimes. The docs describe listing/selecting/removing; they do not promise arbitrary downgrade safety for every model — do not over-claim rollback guarantees.

---

## 3. Model management

### 3.1 Discovery and download — Hugging Face inside the product

Official “Download an LLM” / basics docs (docs dump, read 2026-11-15):

- “LM Studio comes with a built-in model downloader that let's you download any supported model from \[Hugging Face\].”
- **Search modes:** by keyword (e.g. `llama`, `gemma`, `lmstudio`), by specific `user/model` string, or by pasting a **full Hugging Face URL** into the search bar. Jump to Discover from anywhere with `⌘+2` / `Ctrl+2`; the 0.4.0 notes add a refreshed Model Search modal via the search button or `Cmd/Ctrl+Shift+M`, with format-filter preferences and modal size persisting across restarts.
- **Catalogue mechanics (offline docs):** “Any given version of LM Studio ships with an initial model catalog built-in. The entries in the catalog are typically the state of the online catalog near the moment we cut the release. However, in order to show stats and download options for each model, we need to make network requests (e.g. to huggingface.co).” So: browse scaffolding ships locally; live stats/options need network; *using* a downloaded model does not (see §4.4).
- **Quantisation choice at download time:** “You will often see several options for any given model named things like `Q3_K_S`, `Q_8` etc. These are all copies of the same model, provided in varying degrees of fidelity. The `Q` represents … ‘Quantization’ … Choose a 4-bit option or higher if your machine is capable enough.” The docs explain the trade-off in plain language at the point of choice — a deliberate beginner guardrail.
- **CLI parity:** `lms get [model]` — if omitted, staff picks are shown; append `@` for a quantisation (docs example: `llama-3.1-8b@q4_k_m`); `--mlx` / `--gguf` filter by format (otherwise results match installed runtimes); `-n/--limit`, `--always-show-all-results`, `--always-show-download-options` control prompting. Examples in docs: `lms get openai/gpt-oss-20b`, `lms get llama-3.1-8b@q4_k_m` (via secondary guide summarising the same CLI docs — the `@` syntax itself is in the official parameter table in the dump).
- **Staff Picks / curation:** Official CLI docs confirm the “staff picks shown when no model is given” behaviour. Secondary walkthroughs of the Discover UI (0.4.20-era screenshots, July 2026) describe the fuller surface: Staff Picks section, capability chips (e.g. Vision / Tool Use / Reasoning on a model card), parameter/architecture/format header, quantisation + size list, and a **“Likely Fit” / fit check** per download option against detected hardware. The fit-badge wording varies by version and was not quoted verbatim from official docs in this pass, so treat exact badge labels as **observed behaviour (secondary)**, while the underlying capabilities — resource estimation before load — *are* officially documented for the load step (see §3.2, `--estimate-only`). The product pattern is nevertheless unambiguous across sources: **fit is judged before the multi-GB download is committed, not after a failed load.**
- **My Models (local library):** Downloaded models are managed in My Models; the models directory can be changed there. On-disk layout preserves the Hugging Face structure (official sideload docs):
  ```
  ~/.lmstudio/models/
  └── publisher/
      └── model/
          └── model-file.gguf
  ```
  Sideloading is supported by placing files in that structure, or via (experimental, per docs) `lms import <path/to/model.gguf>` with `--user-repo` and `--dry-run` options; `lms import` also handles models downloaded outside the app. Hugging Face’s own “Use this model → LM Studio” affordance is documented in Qwen’s LM Studio guide (secondary to LM Studio, primary to HF behaviour): HF can hand off to LM Studio to run/download.
- **What discovery hides:** conversion. There is no documented in-app GGUF conversion flow; the product assumes the catalogue / HF already offers a GGUF or MLX variant. Users with only safetensors weights are outside the happy path (they must convert elsewhere or find a community quantisation). That is a scope choice, not an oversight to “fix” in a steal-list without costing it (see §8).

### 3.2 Loading — the load panel as a memory-budget contract

Loading is documented as a distinct step from chatting: “Loading a model typically means allocating memory to be able to accommodate the model's weights and other parameters in your computer's RAM.” (Getting-started docs.) Load-time parameters are set in the model loader dialog, can be saved as **per-model defaults** (My Models → gear icon; applies wherever the model is loaded, including via `lms load`), and — importantly — are **not** part of the newer chat Preset format (see §4.2). Inference/sampling parameters are the other half and apply per-chat.

**Officially documented load controls (docs dump + 0.4.0 announcement, read 2026-11-15):**

| Control | Documented form | Notes |
|---|---|---|
| Context Length | Loader field; CLI `--context-length <n>` (“The number of tokens to consider as context when generating text”); SDK load config; `model.yaml` key `llm.load.contextLength` | Capped in practice by the model’s trained maximum (catalogue `contextLengths` in `model.yaml` metadata). Docs warn via RAG/context docs that context is finite working memory; the *cost* framing (KV grows with context) is developed in §3.3. |
| GPU Offload | Loader field; CLI `--gpu` with values `0–1`, `off`, `max` (“How much to offload to the GPU”) — e.g. `--gpu 0.5` = 50% of layers, `--gpu max` = all, `--gpu off` = none. “If not specified, LM Studio will automatically determine optimal GPU usage.” | In the GUI the same idea is presented as a layer-count/percentage slider (secondary load-screen guides: max = total layers + bookkeeping layers). The *metaphor* — fraction of the model resident on GPU — is the ergonomics lesson in §8, regardless of slider vs. fraction rendering. |
| Flash Attention | Per-model default toggle (docs’ own example of why to set per-model defaults: “Whether or not to utilize Flash Attention for a given model”); estimator accounts for it | Also a gate for other features in secondary accounts (V-cache quantisation requires it — secondary, see §3.3). Officially, at minimum: a load-time boolean the product chooses to expose, not bury. |
| Max Concurrent Predictions (`n_parallel`) | Loader → “Manually choose model load parameters” → “Show advanced settings”; **default 4** | 0.4.0: requests beyond the limit queue; supported at launch for the llama.cpp engine, “MLX coming later/soon” (announcement + parallel-requests docs). Later secondary coverage reports MLX continuous batching arriving in 0.4.2 — marked secondary, not in the 0.4.0 primary text read. |
| Unified KV Cache | Loader toggle, **enabled by default** | 0.4.0 announcement, verbatim in substance: “when enabled, preallocated resources will not be hard-partitioned per concurrent request, allowing varying request sizes per request.” Docs add the default-4-slots note: “with unified KV set to true, which should result in no additional memory overhead.” This is the one KV control whose name and semantics *are* in the official text read. |
| TTL / auto-evict | CLI `--ttl <seconds>` (“when the model is not used for this number of seconds, it will be unloaded”); server JIT loading + eviction docs referenced from the systemd guide | Turns residency into a policy, not a manual chore. Multiple loaded models + JIT + TTL is the server-side memory story. |
| Resource estimate before load | CLI `--estimate-only`: “Print a resource (memory) estimate and exit without loading”; honours `--context-length` and `--gpu`; improved estimator (0.3.27 changelog in the API changelog dump) “accounts for flash attention and vision models.” Example output in docs: Estimated GPU Memory / Estimated Total Memory + a guardrails verdict (“This model may be loaded based on your resource guardrails settings”). GUI loader likewise shows an estimated memory figure (secondary guides call it “Estimated Memory Usage”; treat label as observed). | This is the load panel’s contract: *show the cost before paying it.* See §8. |
| MoE CPU offload (`n_cpu_moe`) | 0.4.0 Build 11 notes: “Added a slider to control n_cpu_moe”; Build 15-era bug note references “the cpu moe slider” | A Mixture-of-Experts-specific spill knob: keep experts on CPU while the rest runs on GPU. Officially present as a slider; detailed semantics beyond the name are not elaborated in the text read, so no further mechanism is claimed here. |
| Speculative decoding draft model | Chat sidebar → Speculative Decoding → Draft Model (docs: formerly gated to “Power User mode or higher”; in 0.4 terms, Developer Mode — see §4.3) | Inference-time rather than pure load-time, but configured alongside load in the UX. Docs give pairing guidance (same vocabulary required; e.g. Llama 3.1 8B ↔ Llama 3.2 1B) and warn a poor draft can *decrease* speed. Included because users experience it as part of “how fast will this load/run” setup. |

**Progressive disclosure is the design:** by default the loader can auto-decide GPU usage; the user opts into “Manually choose model load parameters” and then “Show advanced settings” to reach concurrency and the deeper toggles. Developer Mode (Settings → Developer, 0.4.0) “will reveal all advanced options across the app, including in the model loader dialog and sidebars,” collapsing the old User / Power User / Developer three-way switch into one binary. Beginners get a Load button; experts get the full panel without a separate edition.

### 3.3 The KV family — what is exposed, what is hidden, and the documentation gap

The corpus’s KV dossier formalises KV-cache sizing, quantisation and partitioning. Against that yardstick, LM Studio’s exposure is *selective*:

**Exposed (officially documented in text read):**
- Context Length (the dominant KV size driver — KV scales with loaded context, a relationship the official docs imply via context-as-working-memory and the estimator, and secondary guides state explicitly).
- Unified KV Cache on/off (partitioning policy under concurrency).
- Max Concurrent Predictions (how many KV consumers share the load).
- Flash Attention on/off (attention implementation with KV implications; estimator-aware).
- GPU offload fraction (decides where weights live; interacts with how much VRAM remains for KV — interaction explained in secondary guides, not as a formula in official docs read).

**Exposed in the product but NOT found verbatim in the official docs dump read (secondary / observed only — flagged, not laundered into “documented”):**
- “Offload KV Cache to GPU Memory” toggle.
- K Cache Quantisation Type / V Cache Quantisation Type (secondary load-screen primer lists defaults such as K = Q8_0, V = off, and warns “below Q8: attention quality drops sharply” / “Q4 V tanks structured output” — those are the *guide author’s* recommendations, not vendor defaults quoted from docs).
- A combined “KV Cache Quantization” selector set to Q8_0 in low-VRAM guides, with the note that value-cache quantisation requires Flash Attention.
- “Limit to Dedicated GPU Memory” / AutoFit behaviours and MoE expert-offload forcing beyond the `n_cpu_moe` slider name.

  Evidence note: a full-text find for “KV Cache” in https://lmstudio.ai/llms-full.txt (26,423 lines, crawled 2026-11-15) returned **no matches**, while “Unified KV Cache” appears via the 0.4.0 announcement text. The REST/SDK parameter references in the dump likewise foreground context length and GPU offload. Two readings are possible: (1) the quantisation/offload-KV fields exist in the GUI/advanced panel but are undocumented in the web docs dump, or (2) they vary by runtime/version (secondary notes say Flash/KV-offload controls “only affect models loaded by its llama.cpp-based engine”). Either way, the honest dossier statement is: **KV quantisation is part of LM Studio’s observed load-screen surface (llama.cpp engine) per multiple independent 2026 guides, but it could not be verified from official documentation in this pass.** A follow-up with hands-on screenshots of the current build’s Advanced load panel would settle field names/defaults; do not cite this dossier for exact KV-quant defaults.

**Hidden / not exposed as user knobs (in any source read):**
- Per-layer KV allocation, KV block/paging sizes, prefix-cache eviction policy, attention-backend selection beyond Flash on/off and runtime selection, and any direct KV-bytes budget field. The user budgets *indirectly* — context × concurrency × quantisation — while the estimator reports the resulting bytes. That indirection is arguably the product insight: users think in “context I need” and “layers on GPU,” not in “KV bytes,” so the product accepts the former and computes the latter.
- Sampling internals beyond the standard set (see §4.2) and prompt-template internals beyond Jinja/manual override (see §4.2) follow the same pattern: exposed when a user task needs them, hidden otherwise.

### 3.4 `model.yaml` — the catalogue’s abstraction (documented, easily missed)

Docs dump, `model.yaml` section (marked “Draft” in the dump — maturity caveat applies):

- “\[`model.yaml`\] describes a model and all of its variants in a single portable file. Models in LM Studio's \[model catalog\] are all implemented using model.yaml.”
- It “abstract[s] away the underlying format (GGUF, MLX, etc) and present[s] a single entry point for a given model,” and can bake in metadata, load and inference options, and custom logic (e.g. enable/disable thinking via a Jinja variable).
- Core fields: `model` (canonical `publisher/model`), `base` (concrete variants, each with a `key` and Hugging Face `sources`), `metadataOverrides` (domain, architectures, compatibilityTypes, paramsStrings, minMemoryUsageBytes, contextLengths, vision, reasoning, trainedForToolUse — presentation/catalogue metadata), `config` (`operation:` inference defaults + `load:` load defaults, e.g. `llm.prediction.temperature`, `llm.load.contextLength`), `customFields` (model-specific toggles with effects such as `setJinjaVariable`).
- Publish/clone via the Hub; `lms get` can fetch a published `model.yaml` definition. The file is metadata only — “it does not include the actual model weights.” Spec: https://modelyaml.org / GitHub `modelyaml/modelyaml` (as linked in docs).

For an Ollama-improvement reader: this is LM Studio’s answer to the Modelfile/registry-manifest problem — one logical model, many physical variants, with *recommended load/inference defaults travelling with the model definition* instead of living only in user folklore. The “Draft” label means the schema may still move; steal the idea, not necessarily the schema (see §8).

---

## 4. Chat / product features and developer surface

### 4.1 Chat client (official docs)

- **Interface:** “LM Studio has a ChatGPT-like interface for chatting with local LLMs. You can create many different conversation threads and manage them in folders.” New chat `⌘N` / `Ctrl+N`; new folder `⌘Shift+N` / `Ctrl+Shift+N`; drag-and-drop chats/folders (including folders into folders); duplicate via `•••` menu (files duplicated too). Conversations stored as JSON under `~/.lmstudio/conversations/` (macOS/Linux) or `%USERPROFILE%\.lmstudio\conversations` (Windows) — docs explicitly warn the format is not a stable API (“It is NOT recommended to edit them manually, nor to rely on their structure”). The model does not learn from chats; it knows only what is in the chat or configuration such as the system prompt (docs FAQ).
- **Split View (0.4.0):** two chats side by side by dragging tabs to a half or via the split-view icon; combined with parallel requests, two chats can generate simultaneously against the same loaded model — the GUI demonstration of continuous batching.
- **Export (0.4.0):** chats export to PDF, Markdown, or plain text via the chat `•••` → Export menu.
- **Context feedback:** 0.4.0 notes restore a context-fullness indicator and current input token counter; the Developer page shows live per-model processing status (prompt-processing % → generation count). Token/usage stats are also a first-class API output (see §4.3).
- **Speculative decoding** in the chat sidebar (see §3.2) and **MCP tools** in chat (see §4.5) round out the “chat is the product” surface.

### 4.2 Presets, system prompts, prompt templates (official docs)

- **Presets:** “Presets are a way to bundle together a system prompt and other parameters into a single configuration that can be easily reused across different chats.” Every parameter under the Advanced Configuration sidebar can be recorded (docs’ examples: Temperature, Top P, Max Tokens). Stored as JSON in `~/.lmstudio/config-presets` (macOS/Linux) / `%USERPROFILE%\.lmstudio\config-presets` (Windows); local and private by default; share by file, import from file or URL, or publish to the Hub (publish/pull/update flow since 0.3.15, marked “Feature In Preview” in docs). Hub-shared presets land in `~/.lmstudio/hub`. Fetchable via `lms get {author}/{preset-name}`.
  - **Critical scoping fact (official migration note):** “Notable difference: Load parameters are not included in the new preset format. Favor editing the model's default config in My Models.” I.e. the product *deliberately* separates “how I talk” (Preset: prompt + sampling, portable/shareable) from “how it loads” (per-model defaults: context/offload/Flash, machine-specific). Secondary guides confirm: load settings require a reload; inference settings take effect immediately. Any improved-Ollama design that merges the two into one profile must reckon with why LM Studio split them — load defaults are hardware-relative, presets are task-relative.
- **Prompt templates:** By default auto-configured from the model file’s metadata. Override per-model via My Models → gear. Two forms documented: **Jinja template** (the encoding used in several popular model formats) or **Manual** (message-role prefixes/suffixes). The config box surfaces automatically when a model lacks template metadata; “Always Show Prompt Template” is available via sidebar right-click. Documented reasons to edit: incorrect/incomplete/unrecognised metadata, missing template (custom/older models), or a use-case-specific template. `lms log stream` is the documented debugging aid for template/IO inspection (streams exact strings sent to/received from the model; `--source server|model`, `--filter input,output`, `--json`, `--stats`).
- **Sampling surface (inference parameters):** Temperature, Top P, Top K, Min P, Max Tokens, repeat penalty and system prompt appear across Presets, SDK prediction config, `model.yaml` operation fields, and API parameters. No exotic sampler zoo is documented; the set matches OpenAI-client expectations, which is the point (see §4.3).

### 4.3 Developer mode and APIs — three API families, one port

**Developer Mode (0.4.0):** Settings → Developer toggle replacing the 0.3-era User / Power User / Developer selector (0.4.0 Build 15 notes: it “combines the previous Developer and Power User modes into a single mode with all advanced features enabled”). It reveals advanced options app-wide (loader, sidebars, message insert/edit/continue affordances per secondary guides) and is the expected posture for server use. A separate **User mode** posture (chat-only, automatic configuration) is described in secondary setup guides for beginners; the official 0.4.0 text read frames the change as simplification to the single Developer Mode switch — treat any surviving “modes” description as version-dependent.

**Local server:** Started from the Developer tab or `lms server start` (flags in the official CLI reference: `--port` — default/last-used, canonical examples use **1234**; `--cors` off unless flagged; `--bind` — default `127.0.0.1`, `0.0.0.0` for all IPv4 interfaces, also settable via `LMS_SERVER_HOST`). Server therefore binds loopback by default; network exposure is an explicit act. Docs home summary: “Serve local models on OpenAI-like endpoints, locally and on the network.”

**API families (all documented; changelog in the docs dump):**

1. **OpenAI-compatible (`/v1/*`):** `GET /v1/models`, `POST /v1/chat/completions` (text + images, streaming, tool use via `tools` in OpenAI Function Calling format, structured output via `response_format` / JSON schema), `POST /v1/completions`, `POST /v1/embeddings`, `POST /v1/responses` (added 0.3.29, 2025-10-06: stateful via `previous_response_id`, custom tool calling + opt-in Remote MCP, `reasoning.effort` for gpt-oss, SSE streaming), plus tool-use docs confirming `/v1/chat/completions` and `/v1/responses` as the tool surfaces. Usage accounting includes system prompt + tool definitions in token counts (0.3.17) and supports `stream_options.include_usage` (0.3.18). Point any OpenAI SDK at `http://localhost:1234/v1` with any placeholder key when auth is off (secondary guides state the placeholder-key practice explicitly; official auth docs below govern when it stops being true).
2. **Anthropic-compatible:** `POST /v1/messages` added in **0.4.1** (API changelog in the dump: “New Anthropic-compatible endpoint: `POST /v1/messages`. Use Claude code models with LM Studio”). Docs integrations cover Claude Code via this endpoint and Codex via `/v1/responses`. This is compatibility as distribution: coding agents that speak Anthropic/OpenAI dialects need no LM Studio-specific client.
3. **Native REST (`/api/v1/*`, official in 0.4.0; earlier docs label it beta):** Stateful chats (`POST /api/v1/chat` — see below), model download / load / unload endpoints (e.g. `api/v1/models/unload` in 0.4.0 notes; load response field renamed `model_instance_id` → `instance_id` in beta — a reminder the native API is younger and has already broken once), MCP-via-API, and authentication configuration. The dump’s REST overview explicitly compares native vs. OpenAI-compatible endpoints — read that comparison before designing against either.
   - **Stateful chat semantics (0.4.0 announcement):** Unlike stateless chat APIs, `/v1/chat` (announcement path; native docs use `/api/v1/chat`) returns a `response_id`; continuing with `previous_response_id` keeps requests small and suits multi-step workflows. Responses include detailed stats (tokens in/out, speed, time to first token). Locally configured MCPs can be enabled through it, gated by permission keys.
   - **JIT loading + TTL/eviction:** Server docs (referenced from the systemd guide) provide Just-In-Time loading (a request for a downloaded-but-unloaded model can load it) and auto-eviction/TTL, so the server need not pin one model at boot. `/v1/models` behaviour under JIT (whether unloaded-but-downloaded models list) is described in secondary command references; treat listing semantics as version-checked behaviour, not a contract quoted here.
4. **Authentication / permission keys (0.4.0+):** Docs dump: “LM Studio supports API Tokens for authentication… By default, the LM Studio API runs **without enforcing authentication**. For production or shared environments, enable API Token authentication.” Tokens carry granular permissions (auth guide); the 0.4.0 announcement’s “permission keys” (Settings > Server) control which client may access the server / MCPs. Default-off auth on loopback is a deliberate local-first posture; the dossier flags it as a *risk to copy blindly* for any network-bound deployment (see §7/§8).

**SDKs:** Official Python (`pip install lmstudio`) and TypeScript (`lmstudio-js`) SDKs wrap the same host: load/configure/unload models, chat/completion prediction, embeddings, tool-defined local agents, scoped/async client forms (Python scoped + async APIs documented in the dump, async requiring SDK 1.5.0+, sync default 60 s inactivity timeout adjustable via `lmstudio.set_sync_api_timeout()`). SDK existence matters for ecosystem position (§6): LM Studio is programmable without shelling out to `lms`.

**Structured output, tool calling, vision:** Documented as endpoint capabilities (JSON-schema structured output; OpenAI-format tools; vision inputs on chat completions; vision-model awareness in the estimator). Whether a given *model* supports them depends on the model/template — the runtime surfaces the capability, the model provides it. The catalogue’s capability chips (Vision / Tool Use / Reasoning) exist precisely to keep that distinction visible at download time.

### 4.4 Documents / RAG and offline posture (official docs)

- **Attachments:** “You can attach document files (`.docx`, `.pdf`, `.txt`) to chat sessions in LM Studio.” Drag-and-drop / attach in chat; processing is local.
- **Two strategies, chosen by size (official RAG docs):** If the document fits the model’s context, “LM Studio will add the file contents to the conversation in full.” If very long, it “will opt into using ‘Retrieval Augmented Generation’” — fishing out relevant bits to provide as reference. Docs are candid that RAG “sometimes works really well, but sometimes it requires some tuning and experimentation,” and advise verbose, term-rich queries. No chunking/embedding parameters are exposed in the text read — RAG is a chat feature, not a retrieval-tuning workbench.
- **Offline (official “Offline” docs in the dump):** “In general, LM Studio does not require the internet in order to work. This includes core functions like chatting with models, chatting with documents, or running a local server.” “Nothing you enter into LM Studio when chatting with LLMs leaves your device.” / “that document stays on your machine.” Operations that *do* require connectivity are enumerated: searching for models (HF requests), downloading models, Discover catalogue stats/options, downloading runtimes, and checking for app updates (macOS/Windows updater; “The linux in-app updater \[is in the works\]” per the dump — version-dependent, secondary sources report in-place Linux updates since 0.4.22; do not cite the dump line as current for 0.4.28). Privacy-policy specifics (telemetry, anonymised search) were **not** read as a primary source in this pass beyond the offline docs; secondary summaries of the June 2026 policy claim no telemetry / no user-specific tracking — marked **unverified-primary** in §9 and not relied on for any conclusion here.

### 4.5 MCP and integrations (official docs, brief)

- **MCP host since 0.3.17:** local and remote MCP servers via `mcp.json` (Cursor notation, per docs) or one-click “Add to LM Studio” deeplinks (`lmstudio://add_mcp?…` with base64 config). Docs warn plainly: “Some MCP servers can run arbitrary code, access your local files, and use your network connection.” OAuth-backed MCPs are supported (browser authorisation, token stored, tools available in chat; custom OAuth apps use callback `http://127.0.0.1:33389/mcp-oauth-callback`).
- **MCP via API (0.4.0+):** per-request ephemeral MCPs (`integrations: [{type: "ephemeral_mcp", …}]`, requires “Allow per-request MCPs” in Server Settings) vs. pre-configured `mcp.json` plugins (`type: "plugin"`, `allowed_tools` gating).
- **Integrations docs:** Codex, Claude Code, OpenClaw, Hermes Agent and others are given first-party integration pages in the current docs index (found via the docs home / dump). Their presence signals where LM Studio expects its server to be consumed: coding agents first.

---

## 5. Performance character

**Honest headline: LM Studio inherits its engines’ performance. No LM Studio-specific inference breakthrough is documented, and none should be claimed.**

- **What the vendor actually claims (0.4.0 announcement, read 2026-11-15):** qualitative throughput language only — parallel requests with continuous batching “for high throughput serving,” requests processed in parallel “instead of queueing,” the server “dynamically combine\[s\] multiple requests into a single batch. This enables concurrent workflows and results in higher throughput.” **No tokens/second figures, no comparative benchmarks, and no latency numbers appear in the official announcement or docs sections read for this dossier.** Any tok/s number attributed to “LM Studio” in secondary comparisons is a measurement of llama.cpp or MLX on specific hardware/model/quantisation, not a vendor claim.
- **Mechanism attribution is explicit in the vendor text:** “Parallel requests work thanks to llama.cpp's open-source continuous batching implementation, adopted in LM Studio's llm-engine.” At 0.4.0 launch the capability was llama.cpp-engine only, “has not yet made it into our MLX engine, but it is actively in the works.” Secondary coverage reports MLX continuous batching following in 0.4.2 (February 2026) — plausible and consistent with the announcement’s roadmap language, but **secondary** in this dossier’s evidence base.
- **Expected parity, with packaging caveats:** For the same model file, same runtime version, same backend, same context/offload/KV settings, LM Studio should perform within measurement noise of direct llama.cpp / MLX-LM, because it *is* those engines, packaged. Real-world deltas, where secondary comparisons find them (typically single- to low-double-digit percent, direction varying by version), are attributable to: (a) runtime version lag/lead vs. upstream (runtimes update on their own cadence — see §2.3), (b) default load choices (context length, unified KV, parallel slots = 4 preallocating/ sharing differently than a single-slot `llama-server`), (c) Flash/KV settings, and (d) GUI/daemon overhead, which is small next to inference but non-zero. None of those is an engine advantage; all are configuration/packaging effects. **[Assessment, grounded in the documented engine identity — not a measured result.]**
- **Where LM Studio can be *effectively* faster for a user:** speculative decoding (documented, draft-model dependent, can also be slower — vendor warns so), Flash Attention, full GPU offload vs. an accidentally partial CLI invocation, MLX vs. GGUF choice on Apple Silicon, and the estimator preventing an OOM/spill configuration that collapses to single-digit tok/s. These are *avoided-slowness* wins from ergonomics, not kernel wins. Low-VRAM secondary guides illustrate the cliff (full-VRAM tens of tok/s vs. spilled low single digits on the same model) — numbers are guide-specific and not reproduced as benchmarks here; the cliff shape is the transferable fact.
- **Concurrency ceiling:** Continuous batching with default 4 slots targets single-user / small-team / agent workloads. Nothing in the docs read positions `llmster` against high-concurrency serving systems (paged-KV, large-batch schedulers) and no multi-user throughput claim is made by the vendor in the sources read. Treat “competitive for small concurrent workloads” (secondary phrasing) as the ceiling of any fair claim.
- **What to steal from this section is a negative:** do not chase LM Studio on kernels. Chase it on the configuration surface that decides which kernel path the user actually lands on (see §8).

---

## 6. Ecosystem position

- **The first-run product.** Secondary guides converge on the same positioning, in near-identical words across independent sites read for this dossier: “the friendly way to run AI models,” “the local-models tool for people who want a window, not a command line,” “the closest thing the local-AI world has to a ‘just works’ desktop app,” “its real superpower is the built-in model browser.” The vendor’s own July 2025 post supplies the scale/context in its own words: “millions of downloads worldwide, and dozens of enterprise deployments” by mid-2025, with the observed adoption pattern that “people use LM Studio at home, and at some point see value in bringing it to their team at work” — the friction of the old commercial-licence step was measurably suppressing that home→work carryover, which is why it was removed. **[Characterisation:]** LM Studio owns the *top of funnel* for local LLMs: for many users it is the first local model they ever run, the place they learn what quantisation/context/offload mean, and the baseline against which CLI tools feel either “powerful” or “unfinished.” That teaching role is a competitive moat no engine benchmark displaces.
- **Catalogue gravity:** Discover (HF-backed, staff-picked, fit-checked) + Hub (presets, `model.yaml`, plugins) + HF’s reciprocal “Use this model → LM Studio” handoff make LM Studio a *distribution channel* for model publishers, not just a player. Qwen’s official guide, for example, treats LM Studio as a primary run path and notes Qwen models “frequently get featured in Staff Picks.” Publishers optimise listings for it; users start there; the loop reinforces.
- **The `lms` CLI as documented (official CLI reference):** beyond §2.1’s core verbs, the dump documents: `lms get` (download, quantisation `@` syntax, format filters), `lms ls [--llm|--embedding|--json|--detailed|--variants]`, `lms ps [--json]` (loaded models; 0.3.27 adds generation status + queued-request counts), `lms load [--gpu|--context-length|--ttl|--identifier|--estimate-only]`, `lms unload [--all]`, `lms import`, `lms server start [--port|--cors|--bind] / stop`, `lms chat` (0.4.0 refresh: slash commands `/model`, `/download`, `/system-prompt`, `/help`, `/exit`; `Ctrl+C` interrupts prediction per 0.3.27), `lms log stream`, `lms runtime …` (§2.3), `lms daemon up/down`, `lms link …`, `lms login`, `lms clone / push / dev` (Hub/plugin workflows). Most model commands accept `--host` to operate on a remote LM Studio instance. The CLI is the bridge that lets the GUI product participate in scripts, systemd units and CI without pretending the GUI is the automation surface.
- **Agent-tool gravity (2026 docs):** First-party integration docs for Claude Code (Anthropic endpoint), Codex (Responses endpoint), OpenClaw, Hermes Agent (with JIT loading notes) and MCP generally show LM Studio deliberately courting the “local backend for a coding agent” slot — the same slot Ollama targets. Its differentiator there is not the API (everyone speaks OpenAI dialect now) but that the user *already* has the model downloaded and tuned from desktop use.
- **Community/support shape:** Discord community (linked throughout docs), public bug tracker on GitHub (`lmstudio-ai/lmstudio-bug-tracker`) despite the closed core, community localisation (docs list 15+ languages with named community localisers). Bug *reporting* is open; code *contribution* to the core is not — a support posture an evaluator should note accurately rather than rounding to “open” or “closed” simpliciter.

---

## 7. Strengths / weaknesses

### Strengths (each tied to documented behaviour above)

1. **Discovery-to-chat in one window.** Search (keyword / `user/model` / HF URL) → quantisation choice with plain-language guidance → fit/estimate signals → download → load → chat, without a terminal, config file, or separate registry account. No competitor surface read for this corpus collapses the funnel as completely for a beginner.
2. **Load ergonomics with an estimate contract.** Auto-decide by default; manual + advanced on demand; per-model defaults; `--estimate-only` / loader estimate reporting GPU + total memory *before* commitment, honouring the very knobs (context, offload, Flash, vision) that change the bill. This prevents the dominant beginner failure (OOM / spill collapse) at the moment it is still free to avoid.
3. **Runtime packaging.** Engines as downloadable, selectable, updatable modules decoupled from app releases (§2.3). New upstream capability reaches users without an app reinstall; GPU survey + runtime manager make backend selection inspectable.
4. **Compatibility breadth as adoption strategy.** OpenAI-compatible + Anthropic-compatible + native stateful REST + Python/TS SDKs + MCP host, all on one local port/host the user already runs. Each dialect removes a reason to choose a different backend for a specific client (notably coding agents).
5. **Headless graduation without re-platforming.** `llmster` + `lms` + systemd docs let a desktop prototype become a server deployment with the same model store, defaults and catalogue definitions (`model.yaml`). The 0.4.0 re-architecture (GUI/core separation) is the vendor’s most consequential engineering move in the sources read.
6. **Offline/privacy posture, documented operationally.** The docs enumerate exactly what needs network and what does not (§4.4) instead of offering a vague “private” slogan. For regulated/internal use, that enumeration is auditable in a way marketing copy is not.
7. **Licence friction removed for internal use.** Since 2025-07-08, home→work adoption needs no procurement step for the core app (§1.2). For a free product, removing the *permission* bottleneck mattered more than any feature in the announcement’s own account.

### Weaknesses (including closed-source consequences)

1. **No auditability of the core.** Source is a contractual trade secret; reverse engineering is prohibited except where law overrides. Security review, reproducibility, and “what exactly does the daemon do with my prompts/files” questions stop at the vendor’s docs and privacy policy. For an Ollama-improvement project the consequence is direct: **ideas may be studied, code may not be consulted, borrowed, or verified.** Any claim in this dossier about *how* a feature is implemented internally would violate its own discipline note.
2. **Licence ceiling for builders.** “Personal and / or internal business purposes” + no service-bureau/SaaS/distribution means LM Studio cannot lawfully be embedded as the runtime of a product offered to third parties, resold, or hosted for others under the desktop terms. Ollama’s MIT grant has no equivalent ceiling. Teams standardising on LM Studio for *internal* use are fine; anyone shipping *on* it needs Enterprise/order-form terms or a different runtime. Model licences stack on top (§1.2).
3. **Vendor-control risks inherent to closed distribution:** Paid Features clause reserves fee-bearing features; terms/pricing for Enterprise/Teams are order-form/contact, not public; runtime/catalogue freshness depends on the vendor’s packaging cadence (a runtime can lag upstream — secondary checkers explicitly compare runtime build numbers to upstream HEAD); app/catalogue stats require vendor/HF network calls. None of this is alleged misconduct — it is the structural price of a closed, curated channel.
4. **Platform gaps (documented):** No Intel Macs at all; Linux is AppImage-first with the vendor’s own “newer than 22 not well tested” Ubuntu caveat; Windows x64 without AVX2 is excluded. Cross-platform *breadth* is real (Mac/Win/Linux, x64+ARM) but the edges are rougher than the marketing silhouette, especially Linux.
5. **Documentation gaps where the product is deepest.** The KV-quantisation surface gap (§3.3) is exemplary: advanced users are offered consequential, quality-affecting controls that the public docs dump does not name or default. Preset/load split (§4.2), native-API beta history and field renames (§4.3), and `model.yaml`’s “Draft” status similarly tax anyone automating against the product. Polish at the happy path coexists with thin contracts at the power path.
6. **Concurrency / serving ceiling.** Default 4 parallel slots, continuous batching inherited from llama.cpp, no documented large-fleet scheduling, load-balancing or multi-GPU serving story in the sources read (LM Link routes to a preferred device; it is not documented as a balancer). Small-team serving is the honest envelope.
7. **Default-off API authentication.** Correct for loopback-only local use, hazardous if a user flips `--bind 0.0.0.0` / network serving without enabling tokens — the docs provide the control, but the safe path requires the user to know they need it. A product that makes network serving one toggle away carries this footgun structurally.
8. **RAG shallowness.** Document chat is deliberately simple (full-context else retrieval, no exposed retrieval tuning in docs read). Users needing chunking/embedding control, corpora, or citations must bring another tool. Simplicity is the feature; it is still a ceiling.

---

## 8. IDEAS TO STEAL (ideas only — no code, no assets, no text reuse)

Each idea is stated as a transferable product/engineering pattern for a Go Ollama-improvement, with the gain and the cost/risk of adopting it. “Steal” here means *learn from observable behaviour and reimplement independently* — the only lawful reading given §7, Weakness 1.

### Idea 1 — The offload slider as a memory-budget metaphor

- **Pattern:** Present GPU residency as *one* comprehensible fraction (“how much of this model lives on the GPU: off / fraction / max”) bound to a live memory estimate, with auto-decide as the default and manual override one disclosure-level deeper. CLI twin: a single `--gpu 0.5|max|off`-style flag.
- **Gain:** Users who cannot define “layer offload” can still reason “more on GPU = faster, if it fits,” and the paired estimate turns a guess into a budget. It directly attacks the spill-collapse failure (the steepest tok/s cliff a beginner hits) and gives support/forums a shared vocabulary (“what’s your offload + context?” diagnoses most “slow” reports).
- **Cost/risk:** The fraction hides heterogeneity (embeddings, KV, compute buffers, MoE experts do not scale like uniform layers), so the estimate must be honest about what it includes (LM Studio’s estimator explicitly accounts for Flash/vision — copy the honesty, not just the slider). Auto-decide needs guardrails and an override that *sticks* per model, or experts will route around it. If the underlying Go runner cannot offload fractionally with the same granularity, do not fake the slider — expose the granularity you have.

### Idea 2 — Estimate before load, as a contract

- **Pattern:** A dry-run (`--estimate-only` equivalent + GUI estimate) that, given model + context + offload + attention/KV choices, reports estimated GPU memory, estimated total memory, and a plain verdict against the machine’s guardrails — *before* allocating.
- **Gain:** Converts OOM from a crash into a choice (“reduce context to X or offload to Y to fit”). Enables scripting/CI to preflight fleets, and gives a future fit-badge (Idea 4) a single estimator to share instead of three inconsistent heuristics.
- **Cost/risk:** Estimators lie at the edges (vision towers, MoE expert residency, fragmentation, other GPU tenants). LM Studio labels the GUI figure an estimate and secondary guides warn it may under-account KV growth during long generations. Ship confidence language, measure estimator error against real loads, and never let the estimate *block* an expert who wants to try anyway — advise, don’t gate, except where allocation would destabilise the host.

### Idea 3 — Engines as downloadable, selectable runtime modules

- **Pattern:** Package each engine/backend build (llama.cpp-CUDA, llama.cpp-Vulkan, llama.cpp-ROCm, MLX, CPU) as a versioned module the client can list, download, select, update and remove independently of the app binary (`lms runtime ls/get/select/update/remove` + a manager UI + a GPU survey verb).
- **Gain:** Engine fixes and new-architecture support ship at engine cadence, not app cadence; users on exotic hardware select the backend that matches their driver instead of reinstalling the world; support can ask “which runtime?” as a precise question. For a Go project, it also isolates CGO/native blast radius: a bad engine module need not brick the CLI/daemon shell.
- **Cost/risk:** This is the most expensive idea on the list. It needs signing, version compatibility matrices (app ↔ runtime ↔ model format), atomic swap/rollback, and a support matrix that grows combinatorially. LM Studio can amortise it across a large user base; a smaller project should consider a *coarse* version first (two or three blessed runtime bundles, manual selection, no hot-swap) before committing to a full module store. Unsigned or unversioned “download a binary” is a supply-chain vulnerability, not a feature.

### Idea 4 — Model discovery inside the product, with fit judged at download time

- **Pattern:** An in-product catalogue over Hugging Face (search by keyword / `publisher/model` / pasted HF URL), curated staff-picks for the first run, per-variant quantisation listings with size + capability chips (vision/tools/reasoning) + a hardware fit signal per variant, and one-click download into a preserved `publisher/model` store. CLI twin with quantisation pinning (`get model@q4_k_m`) and format filters.
- **Gain:** Discovery is where users are won or lost; sending a beginner to HF’s website + a wiki + a file manager leaks most of them. Fit-at-download prevents the multi-GB wrong download, and capability chips prevent the subtler wrong download (a base model for a tool-use job). Curation (staff picks) is editorial leverage no registry dump provides.
- **Cost/risk:** A catalogue is an ongoing editorial + infrastructure commitment (metadata freshness, takedown/licence hygiene, HF rate limits/outages, “why was *my* model not picked” politics). Fit signals need the Idea-2 estimator and detected-hardware truth, or they become confident nonsense. Mitigation: start as a thin HF search + local fit check over *user-chosen* repos, add curation only when someone owns it weekly.

### Idea 5 — Split “how it loads” from “how it talks”

- **Pattern:** Two distinct saved-object types: per-model *load defaults* (context, offload, Flash, concurrency — hardware-relative, stored with the model) vs. shareable *presets* (system prompt + sampling — task-relative, JSON, importable/publishable, explicitly excluding load parameters).
- **Gain:** Presets become safely shareable across machines with different GPUs (a preset that pinned 32K context + max offload would be a trap on a smaller laptop); load defaults become safely sticky per machine. The split also clarifies APIs: load config is a residency decision, preset is a conversation decision.
- **Cost/risk:** Users *will* expect one “profile” that does both, and will file the split as a bug (LM Studio’s own docs must call the exclusion out as a “notable difference”). Mitigate with a combined *view* (show effective load + preset together at chat start) while keeping the stored objects separate, and with one-click “save current load as this model’s default” at load time (LM Studio does exactly this).

### Idea 6 — One logical model, many physical variants (`model.yaml` pattern)

- **Pattern:** A portable manifest naming a logical `publisher/model`, enumerating its concrete GGUF/MLX variants with sources, carrying catalogue metadata (params, context lengths, vision/reasoning/tool flags, minimum memory) plus baked load/inference defaults and model-specific custom toggles (e.g. thinking on/off via template variable).
- **Gain:** Clients resolve “run Qwen3-8B” to the right file for *this* OS/chip/runtime without the user knowing formats exist; publishers ship recommended defaults once instead of repeating them in every README; catalogues render rich cards from data, not scraped prose.
- **Cost/risk:** Schema governance. LM Studio’s own docs mark `model.yaml` “Draft.” A competing manifest fragments the ecosystem unless it maps cleanly to what registries already emit. Adopt the *resolution idea* internally first (logical → variant resolution + travelling defaults); publish a schema only with versioning, a validator, and a migration story.

### Idea 7 — Headless graduation on the same store and defaults

- **Pattern:** Separate GUI from core early enough that the daemon (`llmster` analogue) serves the *same* model store, load defaults, presets and APIs as the desktop app, installable by one script and supervisable by systemd, driven by the same CLI that drives the GUI.
- **Gain:** Prototype-to-server stops being a migration. Users keep their downloaded models and tuned defaults; the project gets one bug surface for loading/serving instead of two diverging ones.
- **Cost/risk:** GUI/core separation is an architecture tax paid on every feature (state ownership, lifecycle, “who ejects the model?”). Retroactively splitting a monolith costs more than designing the seam early — which is the actual lesson of 0.4.0 arriving nearly three years after launch. For a Go daemon-first project (Ollama’s shape), the cheaper direction is the inverse: keep the daemon canonical and make any GUI a client of it from day one.

### Idea 8 — Stateful chat + stats as the native API’s differentiator

- **Pattern:** Keep OpenAI/Anthropic compatibility for reach, but make the *native* API earn its existence: stateful continuation via `previous_response_id`-style handles, per-response stats (tokens in/out, speed, TTFT) for tuning, and gated tool/MCP access via permission keys — rather than a native API that merely renames the stateless one.
- **Gain:** Gives client authors a reason to integrate deeply (smaller continuation requests, observable performance, local-tool access) without breaking the “any OpenAI client works” promise that drives adoption.
- **Cost/risk:** Stateful handles are a lifecycle/security surface (expiry, cross-client leakage, eviction interaction with TTL/JIT). Stats must be defined precisely or clients will depend on noise. And a native API that breaks field names during beta (as LM Studio’s did) teaches clients to stay on the compatible surface — version the native API conservatively from its first public release.

*Ideas deliberately NOT listed:* LM Studio’s visual design, copy, icons, catalogue text, preset files, or any implementation detail are not transferable — they are the vendor’s IP and, for code, uninspectable in any case. The transferable assets are the eight interaction/architecture patterns above, reimplemented independently.

---

## 9. Sources with dates accessed

All web sources below were accessed **2026-11-15** (crawl timestamps returned by the fetcher: “Page crawled … (2026-11-15 07:01 UTC)” for the lmstudio.ai pages). “Primary” = published by Element Labs / LM Studio. “Secondary” = independent guide/comparison describing observable behaviour; used only where labelled as such in the text.

### Primary sources actually read

1. LM Studio Docs home — https://lmstudio.ai/docs/app?ref=tako-analytics — platforms, llama.cpp + MLX statement, runtime-manager shortcut, Discover/RAG/`llmster`/API overview.
2. LM Studio docs full text — https://lmstudio.ai/llms-full.txt (26,423 lines as crawled) — CLI reference (`lms get/load/ls/ps/server/runtime/log`), load flags (`--gpu`, `--context-length`, `--ttl`, `--estimate-only`), presets storage/scope, prompt templates, per-model defaults, parallel requests, RAG strategy, offline enumeration, systemd headless guide, `model.yaml`, API changelog (0.4.1 Anthropic endpoint; 0.4.0 native `/api/v1`; 0.3.29 Responses; 0.3.27 estimator), SDKs, MCP. Full-text finds performed on this dump are reported in §3.3.
3. LM Studio App Terms of Service, Version: August 23, 2026 — https://lmstudio.ai/app-terms — licence grant, restrictions, Paid Features, third-party-model disclaimer, $50 liability cap. Read lines 0–181+ (grant/restrictions/billing/disclaimers in full).
4. “LM Studio is free for use at work,” Published: 2025-07-08 — https://lmstudio.ai/blog/free-for-work — removal of the separate commercial licence, Enterprise description (SSO, model/MCP gating, private collaboration), Hub organisations/Teams context.
5. “Introducing LM Studio 0.4.0” — https://lmstudio.ai/blog/0.4.0 — `llmster`, install scripts, parallel requests / continuous batching via llama.cpp, Max Concurrent Predictions + Unified KV Cache, Developer Mode, Split View, export, stateful `/v1/chat` + permission keys, full Build 8–17 release notes (incl. `n_cpu_moe` slider, `lms chat`, `lms runtime survey`).
6. “LM Studio, llmster, and lms” — https://lmstudio.ai/docs/app/basics/lmstudio-vs-llmster-vs-lms — three-tool framing, command list, `localhost:1234` server note.
7. System Requirements — https://lmstudio.ai/docs/app/system-requirements — §1.1 platform table (Apple Silicon/macOS 14, Windows AVX2/Snapdragon X Elite, Linux AppImage/Ubuntu 20.04+ caveats).
8. Enterprise Terms, Version: January 28, 2025 — https://lmstudio.ai/business-terms (via search excerpt + terms summary) — order-form licence scope and fee structure. *Partial read via search results; grant/fee clauses quoted from the returned text.*
9. Hub Terms, Version: August 23, 2026 — https://www.lmstudio.ai/hub-terms (via search excerpt) — existence/version only; no substantive claim in this dossier depends on Hub Terms detail.
10. Bionic “Understand Credits and Usage” — https://lmstudio.ai/docs/bionic/accounts-plans-and-billing/credits-and-usage (via search excerpt) — credits consumed only for Cloud models; local / LM Link models consume no credits.

### Secondary sources consulted (behaviour corroboration only)

11. Load-screen / tuning guides for KV/offload field names and defaults discourse: Herding Bots, “LM Studio's Load screen, demystified”; InsiderLLM, “LM Studio Tips & Tricks” (GPU offload CLI forms, KV-offload toggles); CanRunLLM GPU-offload guide (`--gpu` fraction semantics); WindowsForum / TheGeekPage low-VRAM guides (Q8_0 KV practice, estimator caveats). Accessed via search 2026-11-15. Used *only* as labelled in §3.2–§3.3.
12. Version/pricing checkers citing official changelog/download/pricing pages: GPUWerk comparison (LM Studio 0.4.28, 31 Oct 2026; runtime 2.50.0 / b11337 for 0.4.26), checked 7 Nov 2026; RefusalRate Linux guide (0.4.28 download links, .deb + AppImage, checked 12 Nov 2026); multiple pricing summaries of lmstudio.ai/pricing (Free $0 / Bionic+ $20 / Pro $100), checked Oct–Nov 2026. Used *only* as labelled in §1.1–§1.2.
13. Preset/chat walkthroughs: LLM Configurator “Complete LM Studio Bible,” Urhoba chat-settings guide, MarkAI preset guide. Accessed via search 2026-11-15. Used to corroborate the load-vs-inference settings split already stated in primary docs.
14. Qwen LM Studio guide — https://qwen.readthedocs.io/en/latest/run_locally/lmstudio.html (via search excerpt) — HF “Use this model → LM Studio” handoff, Staff Picks presence.

### Unverifiable / limits (explicit)

- **Latest-version string (0.4.28):** secondary-verified only (see §1.1). No official changelog page body was fetched in this pass; the API changelog *inside* the primary docs dump was read and anchors all API-version claims independently of the app-version string.
- **Pricing page body:** not fetched as a primary source (see §1.2). Bionic $20/$100 figures are secondary summaries of that page. Core-app $0 / internal-use licence *is* primary-verified via Terms + July 2025 announcement.
- **KV-cache quantisation field names/defaults:** not present in the primary docs dump (full-text find: no “KV Cache” matches). Existence in the product rests on multiple secondary load-screen guides; exact labels/defaults per build/runtime remain **unverified-primary** (see §3.3). Hands-on inspection of a current build is the required follow-up.
- **GPU backend matrix (CUDA/Vulkan/ROCm variants):** secondary/observed (runtime-manager guides), not enumerated on the primary System Requirements page read. Verify per-machine via Runtime Manager / `lms runtime survey`.
- **Privacy-policy telemetry specifics:** not read as a primary source in this pass; no conclusion in this dossier depends on them. The offline enumeration (§4.4) *is* primary (docs dump).
- **No hands-on testing:** no LM Studio binary was installed or run for this dossier. All behaviour claims are documentation/observed-behaviour claims, per the assignment’s discipline.

---

*End of OR-2 dossier — LM Studio. Prepared 2026-11-15 for the Ollama Research Forge (RuneForgeAI-Ollama-Experiments research corpus). Closed-source subject: public documentation and observable behaviour only; no source was read and no internals beyond the documents are asserted.*
