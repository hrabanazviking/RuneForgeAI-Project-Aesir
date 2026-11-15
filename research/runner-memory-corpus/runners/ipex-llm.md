# OR-2 — Intel IPEX-LLM

**Corpus:** Ollama Research Forge — model runners dossier
**Subject:** Intel IPEX-LLM (Intel LLM Library for PyTorch)
**Licence (verified):** Apache License 2.0 (Apache-2.0), as shown on the GitHub repository page and in the repository `LICENSE` file listing, accessed 2026-11-15.
**Lineage:** BigDL (Intel's distributed deep-learning project, repository history dating to 2016-08-29) → `bigdl-llm` → renamed `ipex-llm` in March 2024.
**Repository homes (verified 2026-11-15, see §7 for the full picture):**

- Canonical Intel home at the time of study: `github.com/intel/ipex-llm`
- Historical home, still referenced throughout the project's own documentation and redirecting to the Intel home: `github.com/intel-analytics/ipex-llm`
- A separate, small community fork under a dedicated organisation: `github.com/ipex-llm/ipex-llm` (created 2025-04-20)

**Documentation:** project docs under `docs/mddocs` in the repository (quickstarts for Ollama, llama.cpp, vLLM, installation, benchmarking), plus Intel developer articles on intel.com.
**As of:** 2026-11-15. All web sources were accessed on 2026-11-15 unless a source's own date is given. A post-cutoff health development reported by 2026-dated independent coverage is flagged explicitly in §7 rather than silently folded into the as-of picture.

**Essence.** IPEX-LLM is Intel's PyTorch-native answer to a simple commercial problem: most of the world's PCs and a large share of its servers already contain Intel silicon, and none of it could run modern LLMs well through the CUDA-centred toolchain. Rather than building a new compiled runtime (that is OpenVINO's job, covered elsewhere in this corpus), Intel extended the ecosystem developers already use — Hugging Face Transformers on PyTorch — with an in-place, low-bit conversion layer: load a stock Hugging Face model, ask for a 4-bit (or 8-bit, or small-float) representation, and run it on an Intel CPU, integrated GPU, Arc discrete GPU, datacentre Flex/Max GPU, or Core Ultra NPU. The same project also ships a C++ side that plugs SYCL-accelerated llama.cpp and Ollama binaries into Intel GPUs, which is how most end users actually met it. For this corpus it is the third Intel data point: OpenVINO GenAI compiles models into a vendor runtime, ONNX Runtime's OpenVINO provider routes a standard graph format to Intel hardware, and IPEX-LLM instead meets the model where it already lives, inside PyTorch.

---

## 1. What it is, and what it is not

Three naming traps matter before anything else, because Intel's own materials blur them:

1. **IPEX-LLM is not IPEX.** Intel Extension for PyTorch (package name `intel-extension-for-pytorch`, import name `ipex`) is a general PyTorch accelerator with its own LLM helper (`ipex.llm.optimize`). IPEX-LLM (package name `ipex-llm`, import name `ipex_llm`) is a separate, LLM-specific library descended from BigDL. Intel's own August 2024 inference whitepaper states plainly that the two are different libraries and pins a specific IPEX version for use alongside IPEX-LLM. This dossier covers IPEX-LLM only; where a source turned out to describe IPEX proper, it was excluded or is labelled as such.
2. **IPEX-LLM is not a model format.** Its "low-bit" representations are a runtime conversion applied to ordinary PyTorch weights, with an option to save and reload the converted model. There is no separate model zoo a user must download models from — the Hugging Face Hub is the zoo.
3. **IPEX-LLM is not only the Ollama zip.** The Ollama/llama.cpp binaries are its C++ distribution channel (§4.3). The centre of gravity is the Python library (§2).

The project describes itself, in its repository summary, as accelerating local LLM inference and fine-tuning for a long list of model families (Llama, Mistral, ChatGLM, Qwen, DeepSeek, Mixtral, Gemma, Phi, MiniCPM, and vision variants among them) on what Intel calls XPU — its umbrella term for CPU, integrated GPU, NPU and discrete GPU — with integrations into llama.cpp, Ollama, Hugging Face, LangChain, LlamaIndex, vLLM, DeepSpeed and Axolotl. The README states that more than 70 models had been optimised or verified. Both figures are the project's own claims, recorded here as such.

Fine-tuning is part of the pitch and should not be forgotten when comparing it with pure inference runners: the update history lists LoRA, QLoRA, DPO, QA-LoRA and ReLoRA support on Intel GPUs, and QLoRA on CPU. That breadth is a direct inheritance from the BigDL training-era codebase.

---

## 2. Architecture: a PyTorch extension, not a runtime

### 2.1 The conversion model

OpenVINO GenAI (see its dossier in this corpus) asks the user to export a model into Intel's IR and then run it in Intel's engine. IPEX-LLM inverts that relationship. The documented flow, in the project's own quickstarts and Intel's developer articles, is:

1. The user writes ordinary Hugging Face code, except that the model class is imported from the `ipex_llm.transformers` namespace instead of from `transformers` itself.
2. At load time the user passes a low-bit selector — most simply a boolean 4-bit flag, or an explicit `load_in_low_bit` value naming a format such as symmetric INT4 — together with the usual Hugging Face arguments.
3. The library loads the stock checkpoint, replaces the model's linear layers with its own low-bit implementations, converts the weights in place, moves the result to the target device (`xpu` for Intel GPUs in PyTorch's device naming, or CPU), and applies further operator-level optimisations.
4. Generation then proceeds through the familiar Transformers interface: the same tokenizer, the same generate call, the same sampling arguments the user already knows.

For models that do not come through the Transformers wrapper, the library documents a second entry point, an `optimize_model` function that takes an already-constructed PyTorch model plus a low-bit choice and returns the converted model. The practical difference between the two doors is small — both express the same idea: **conversion is a load-time transformation of a living PyTorch object, not an offline export to a foreign artefact.**

Converted models can be saved in their low-bit form and reloaded later, so the conversion cost does not have to be paid on every start. The library also documents direct loading of already-quantised community artefacts — GGUF files, and AWQ- and GPTQ-quantised checkpoints (initial support announced November 2023) — which makes the PyTorch path a consumer of the existing quantisation ecosystem rather than a competitor to it.

### 2.2 What sits underneath

Public documentation describes the execution layer only at a coarse level, and this dossier stays at that level:

- On **Intel GPUs**, execution goes through PyTorch's `xpu` device, which in turn rests on Intel's oneAPI stack — SYCL as the programming model and Level Zero as the low-level driver interface. The Ollama/llama.cpp quickstart's troubleshooting section makes the dependency visible to end users: the oneAPI environment script must be sourced on Linux, SYCL runtime libraries must be present on Windows, and settings such as immediate command lists and device selection are exposed as environment variables.
- On **Intel CPUs**, Intel's whitepaper attributes the acceleration to the AVX-512 VNNI and AMX (Advanced Matrix Extensions) instruction sets, with the library using oneDNN-family kernels underneath PyTorch. *(Attribution note: that whitepaper discusses IPEX and IPEX-LLM together; the instruction-set claim is Intel's description of its combined PyTorch stack, not an IPEX-LLM-only benchmark.)*
- On **Intel GPUs**, the corresponding matrix hardware is the XMX (Xe Matrix Extensions) engine in Xe-architecture GPUs. Intel's gaming/developer article on running LLMs with IPEX-LLM explicitly credits the Xe-cores' XMX acceleration on Arc A-series cards. A community gist describing INT4 micro-kernels distinguishes two INT4 encodings (a clipped range and a full range); that level of kernel detail rests on a single unofficial source and is recorded here as indicative, not established.

The library also carries inference techniques beyond quantisation: self-speculative decoding (announced February 2024, with a vendor claim of roughly 30% latency improvement for FP16/BF16 — see §6), pipeline parallelism across multiple Intel GPUs (June 2024), and, in May 2025, a feature the project calls FlashMoE for running very large mixture-of-experts models across one or two consumer Arc cards by keeping most experts out of VRAM (vendor claim, §6).

### 2.3 What the PyTorch-native choice buys

- **Ecosystem compatibility for free.** Any workflow already expressed in Transformers — LangChain, LlamaIndex, PEFT/TRL fine-tuning, Text Generation WebUI, custom research code — keeps working with an import change and a load flag. The project's integration list (LangChain, LlamaIndex, AutoGen, ModelScope, DeepSpeed-AutoTP, Axolotl, and more) is long precisely because it did not have to re-implement any of those tools.
- **Model coverage tracks the Hub, not a conversion pipeline.** When a new open model appears on Hugging Face, the marginal work is verification, not a new exporter. The README's verified-model table (70+ entries spanning Llama generations, Qwen generations, ChatGLM/GLM, Baichuan, Mistral/Mixtral, Gemma, Phi, vision and audio models, and others) is the visible result.
- **One library spans laptop to datacentre.** The same conversion API targets a laptop iGPU, a desktop Arc card, a Xeon CPU and a Max-series datacentre GPU, because PyTorch's device abstraction hides the difference.

### 2.4 What it costs

- **PyTorch dependency weight.** The user inherits the full PyTorch + Intel Extension for PyTorch + oneAPI runtime stack: large installs, version pinning (the August 2024 whitepaper notes IPEX-LLM then supported exactly one IPEX release, 2.2.0; GPU install guides are organised around specific PyTorch releases, with a separate guide for PyTorch 2.6 and for Arc B-series), conda environments in the official quickstarts, and driver minimums. Nothing about it resembles downloading a single static binary — which is exactly why the project felt obliged to build the portable-zip C++ channel in §4.3.
- **Version-skew exposure everywhere.** Because IPEX-LLM is a layer over fast-moving projects (PyTorch, Transformers, vLLM, Ollama, llama.cpp), each integration is pinned to a specific upstream version, and the pins visible in the documentation are consistently behind upstream (§4). A layered library inherits every layer's release cadence as a liability.
- **Intel-only by construction.** The optimisations target Intel instruction sets and Intel GPU architecture. There is no NVIDIA or AMD path and no Apple Silicon path; the library's value exists only inside the Intel installed base.

---

## 3. Low-bit formats: the core technology

Low-bit conversion is not one feature among many in IPEX-LLM; it is the product. The founding pitch, carried over verbatim in spirit from the BigDL-LLM era, is that **any PyTorch model can be run in INT4/FP4/INT8/FP8-class representations with low latency** — the quantisation is something the library does to your model, not something a model publisher must have done for you.

### 3.1 The documented format family

From the README, the quickstarts and the vLLM integration guide, the formats a user can select at load time include:

| Family | Documented variants (as named in project docs) | Documented reach |
|---|---|---|
| INT4 | symmetric INT4 (`sym_int4`, the default in the project's benchmark configuration), asymmetric INT4, NF4-style 4-bit | CPU and GPU |
| INT8 | symmetric INT8 | CPU and GPU |
| Small floats | FP4; FP6; FP8 in both E4M3 and E5M2 encodings; mixed-precision FP4/FP8 options in the Transformers API | GPU (FP8/FP6/FP4 examples are GPU-scoped in the README's example index) |
| GGUF types | the llama.cpp quantisation family (e.g. Q4_K) when loading GGUF models or running the C++ path | CPU and GPU via the C++ interface |
| INT2 | an IQ2-based mode borrowed from llama.cpp (announced February 2024) | GPU; positioned for squeezing oversized models (the announcement's example is Mixtral-8x7B in 16 GB of VRAM) |
| Full precision | FP16 on GPU, BF16 on CPU | baseline and speculative-decoding modes |

Three observations for a runner engineer:

1. **The default matters more than the menu.** The project's own benchmark configuration defaults to symmetric INT4, and its demos overwhelmingly show INT4 or GGUF Q4_K. The exotic formats (FP6, the two FP8 encodings) read as hardware-showcase options — FP6 support was announced as a GPU feature in July 2024 — rather than the common path.
2. **Weight-only is the operative idea.** At these bit-widths the win is memory capacity and memory bandwidth: weights shrink roughly 4× against FP16 at INT4, so a model that cannot fit, or cannot be fed fast enough, in FP16 becomes viable on a 16 GB card or in system RAM. Compute follows the bandwidth. This is the same physics every runner in this corpus exploits; IPEX-LLM's distinction is applying it automatically to unmodified checkpoints.
3. **Accuracy is published, and it is honest-looking.** The README carries a WikiText perplexity table across its formats (vendor-produced, §6). Symmetric INT4 is consistently the worst of the listed formats and FP6/FP8 sit close to FP16 — the expected ordering, with no format magically beating full precision. For Llama-2-7B-chat, for example, Intel lists FP16 at 6.096 perplexity against 6.364 for symmetric INT4 and 6.218 for Q4_K. A Go runner should note the practice, not just the numbers: shipping a per-format accuracy table next to the speed claims is what makes a low-bit default defensible.

### 3.2 The kernel story, at public level

The documentation does not publish a kernel catalogue. What can be said from public sources:

- GPU low-bit matrix multiplication is aimed at the XMX units in Xe GPUs (Intel's developer article, §2.2), with SYCL as the implementation language on the C++ side — the Ollama quickstart identifies the IPEX-LLM Ollama build by its single `ipex_llm` runner entry, and the llama.cpp build reports a SYCL device.
- CPU low-bit execution leans on AVX-512 VNNI for integer work and AMX tiles where the processor offers them (Intel whitepaper, §2.2), which is why Intel's CPU story is strongest on recent Xeons and weakest on older consumer parts without those instructions.
- First-token versus next-token behaviour follows the usual shape for weight-only schemes and is not separately documented in the sources read; any stronger claim would be speculation and is not made here.

---

## 4. Serving paths

IPEX-LLM never settled on one serving story. It accumulated four, and the differences between them are the most instructive part of this dossier for anyone building a runner.

### 4.1 Direct Python use (the native path)

The Transformers-style API of §2 is itself the primary "serving" surface for application builders: LangChain and LlamaIndex integrations, example chatbots, and the project's own demos all sit directly on it. There is no mandatory server process, no model registry, and no HTTP layer in the core library. Serving, in the API sense, is delegated to whatever framework the user wraps around the model object.

### 4.2 Framework serving: FastChat, vLLM, DeepSpeed

- **FastChat** support arrived in October 2023 for both CPU and GPU, giving IPEX-LLM models FastChat's controller/worker serving shape and its OpenAI-compatible endpoints.
- **vLLM** is the more significant integration and the more revealing one. Continuous batching support was announced in November 2023. The current quickstart (accessed 2026-11-15) shows the shape of the integration honestly:
  - It is **Linux-only**.
  - It supports only **four model families**: Qwen, Llama, ChatGLM and Baichuan.
  - It requires a **separately maintained vLLM fork/branch** that works only on Intel GPUs; the install transcript in the guide clones a specific old branch (0.5.4) from an Analytics Zoo organisation repository, while the README's news list records later support points (vLLM 0.6.2 in November 2024, 0.6.6 in February 2025) — either way, a pinned fork well behind vLLM upstream's own cadence.
  - The OpenAI-compatible server is launched from an IPEX-LLM module path, takes the same `load_in_low_bit` selector (documented values: symmetric INT4, FP6, FP8, FP8-E4M3, FP16), and supports tensor parallelism across multiple Intel GPUs.
  - Prebuilt serving container images exist under the project's Docker Hub organisation for users who do not want the source install.
  
  In other words: the vLLM path delivers the right API and the right batching behaviour, but only inside a fenced garden of versions, models and one operating system. That is the recurring price of the layered strategy (§2.4).
- **Multi-GPU serving** is also offered through DeepSpeed-AutoTP with a FastAPI front, per the README's quickstart index — a third serving shape, aimed at splitting one model across several Arc cards.

### 4.3 The C++ path: llama.cpp and Ollama as distribution channels

In April 2024 the project announced a C++ interface usable as an accelerated backend for llama.cpp and Ollama on Intel GPUs. Mechanically, the `ipex-llm[cpp]` pip package installs Intel's SYCL-based builds of those tools' backends; an initialisation command materialises an `ollama` executable whose server log shows the single IPEX-LLM runner instead of upstream Ollama's dynamic-library list. The user experience from that point is stock Ollama: `ollama serve`, `ollama pull`, the same HTTP API on port 11434, the same GGUF Modelfile flow. One documented quirk exposes the seam: the guide instructs users to set the GPU-layer count variable to 999 so that all layers land on the Intel GPU rather than spilling to CPU.

Two distribution forms exist:

- **The pip route** (conda environment, `ipex-llm[cpp]`, initialisation script) — the full quickstart path, for Linux and Windows.
- **The Portable Zips** (February–April 2025): prebuilt Ollama and llama.cpp packages for Windows and Linux that run on Intel GPUs with no manual installation. The llama.cpp zip additionally covers the Core Ultra NPU on Windows. Release 2.2.0 (April 2025) bundled both zips as headline features.

Version alignment on this path deserves exact recording, because it is the project's most visible weakness:

- The Ollama quickstart states its current build is consistent with **Ollama v0.9.3**, and that the `ipex-llm[cpp]` build dated 2025-06-29 was consistent with **Ollama v0.6.2**.
- The llama.cpp quickstart similarly pins its latest build to a specific upstream llama.cpp commit, with the June 2025 build pinned to an earlier commit.
- A community guide for Windows/Lunar Lake (accessed as a public gist) reports that the downloadable Ollama Portable Zip itself remained frozen at the much older **Ollama v0.5.4** bundle — the version first announced in January 2025 — and that models published after mid-2025 failed against it, forcing users onto the pip route. This is a single community source and is flagged as such, but it is consistent with the zip's announcement history in the README, which shows no zip version bump after the 2.2.0 release.

The strategic reading: Intel correctly identified that Ollama's interface was where users already were, and that stock Ollama had no Intel GPU backend worth the name at the time. Shipping a drop-in accelerated Ollama was the fastest possible route to those users. But a forked binary distribution inherits a permanent re-basing treadmill, and the public record shows the treadmill winning: each documented build lags its upstream by one to several releases.

### 4.4 Everything else

The integration tail is long and mostly shallow by design: Text Generation WebUI via an Intel-maintained fork branch, Open WebUI on top of the Ollama path, plus application recipes (GraphRAG, RAGFlow, PrivateGPT, Dify and others listed in the README). These are evidence for §2.3's ecosystem point rather than separate serving architectures.

---

## 5. Hardware matrix, as documented

| Target | Status in project docs (accessed 2026-11-15) | Notes |
|---|---|---|
| Intel CPU only (client + Xeon) | First-class: INT4/INT8/FP16-class inference, BF16 mode, QLoRA fine-tuning | Performance story depends on AVX-512 VNNI / AMX presence; older CPUs without them get the formats without the flagship speed claims |
| Integrated GPU (Core Ultra Series 1 and 2, Meteor Lake and successors) | First-class: headline demo target ("local PC with iGPU") | Linux GPU install guide verifies specific kernel versions for Meteor Lake (e.g. Ubuntu 22.04, kernel 6.5); shared-memory iGPUs make low-bit fitting the whole game |
| Arc A-series discrete (Alchemist, e.g. A770 16 GB) | First-class: the reference discrete card across demos, guides and benchmarks | Minimum Windows driver versions are specified in the llama.cpp guide; outdated drivers are called out as a gibberish-output risk |
| Arc B-series discrete (Battlemage, e.g. B580) | Supported via a dedicated quickstart (January 2025) | Requires the newer PyTorch 2.6 install path — a separate guide, signalling a distinct support tier rather than seamless continuity |
| Datacentre GPU Flex Series | Named as a supported target in the repository summary and install guides | No Flex-specific performance material was found in the sources read |
| Datacentre GPU Max Series (e.g. Max 1550) | Named as a supported target; appears in the fine-tuning claim of §6 | Treated by the docs as part of the same XPU family rather than a separate product |
| Core Ultra NPU (100H, 200V, 200K, 200H series) | Supported from December 2024 in both Python and C++; llama.cpp NPU path is Windows-only | The verified-model table's NPU column is short and small-model-shaped (Llama 3.2-class, Qwen2/2.5, MiniCPM-class entries) — an efficiency showcase, not a general LLM target |
| Non-Intel hardware | **Not supported** | No NVIDIA, AMD or Apple Silicon path exists or is documented |
| Operating systems | Windows and Linux for the Python and C++ paths; **Linux-only for vLLM** | macOS is absent entirely |

**The honest gaps.** (1) The breadth of the matrix is real but uneven: CPU and Arc A-series carry the documentation, the demos and the benchmarks; Flex is a name on a list; the NPU column is a subset of small models. (2) Every GPU path carries environmental fragility that the project's own troubleshooting sections document at unusual length — driver floors, kernel-version sensitivities (including a noted hang issue on a much newer kernel), SYCL library errors when the oneAPI environment is not loaded, and a Windows first-run hang. This is the lived cost of the SYCL/oneAPI substrate. (3) There is no story at all for the hardware most local-LLM users actually benchmark on (NVIDIA), which caps the project's mindshare regardless of its technical merit.

---

## 6. Performance character

**Framing rule for everything in this section:** IPEX-LLM's published numbers are Intel's, produced on Intel hardware, frequently against Intel-chosen baselines. They establish what Intel claims its stack does on its own silicon. They do not establish standing against a current CUDA stack, and the independent numbers that do exist are thinner and less flattering. Both kinds are given, labelled.

### 6.1 Vendor numbers

- **Headline generation claim (Intel developer/gaming article):** Mistral-7B on an Arc A770 16 GB via IPEX-LLM at **70 tokens/second**, presented as roughly 70% ahead of an RTX 4060 8 GB running CUDA. The article discloses internal testing and the usual results-may-vary language. Treat as a best-case vendor datapoint: the comparison card has half the VRAM, the quantisation and prompt shape are Intel-chosen, and no independent replication was found in the sources read.
- **README performance section:** token-generation-speed charts for Core Ultra and Arc systems are presented as images with footnoted links to Intel pages; the underlying numbers are not in the text layer and could not be verified from the fetched pages. The project does publish a reproducible benchmark guide (an all-in-one configuration defaulting to symmetric INT4 across CPU/GPU APIs), which is the right practice even where the headline charts are opaque.
- **Accuracy (vendor, WikiText perplexity, README):** symmetric INT4 costs roughly 0.25–0.45 perplexity points against FP16 on the listed 7–14B models; Q4_K sits between symmetric INT4 and the small-float formats; FP6 and FP8-E4M3 are within ~0.05–0.1 of FP16 on most rows. Example rows (Llama-2-7B-chat / Llama-3.1-8B-Instruct): FP16 6.096 / 6.267; symmetric INT4 6.364 / 6.705; Q4_K 6.218 / 6.566.
- **Self-speculative decoding:** ~30% latency improvement claimed for FP16 (GPU) and BF16 (CPU) inference (February 2024 announcement; no methodology in the sources read).
- **Fine-tuning (vendor):** QLoRA fine-tuning of Llama-2-7B in 21 minutes and Llama-2-70B in 3.14 hours on eight Max 1550 GPUs (January 2024, via an Intel blog). A datacentre claim, not a consumer one.
- **FlashMoE (vendor, May 2025):** DeepSeek V3/R1 at 671B parameters and a 235B Qwen3 MoE described as runnable on one or two consumer Arc cards (A770/B580 class). No configuration detail or independent test was found in the sources read; recorded as an unverified vendor capability claim. The March 2025 news entry makes the narrower, more plausible version of the same point for a Q4_K_M-quantised DeepSeek-R1 on a Xeon host with one or two A770s — i.e. a large-RAM CPU host doing most of the holding, with the GPUs accelerating part of the work.

### 6.2 Independent coverage

Independent, IPEX-LLM-specific benchmarking is scarce — itself a finding. What was found:

- **A 2026 synthesis of IPEX-LLM + Ollama Docker use (SpecPicks)** reports 7–8B models at Q4 running at roughly **20–40 tokens/second** across Arc/Iris Xe targets, with its own table putting an A770 at ~42 tok/s and a B580 at ~38 tok/s on Llama-3.1-8B Q4_K_M, against ~48 tok/s for an RTX 3060 12 GB on CUDA — i.e. usable, and consistently **20–40% behind a modest CUDA card**. These figures post-date this dossier's cutoff in publication terms and are included as the clearest independent characterisation available; treat the exact numbers as one outlet's test bench, not a standard.
- **A hobbyist comparison on a Core Ultra 5 iGPU (Medium)** ran Llama-3 at 8B and 70B (Q4_K_M-class) three ways on the same machine and found the IPEX-LLM Python path modestly ahead of the IPEX-LLM llama.cpp path (70B: ~1.86 vs ~1.44 tok/s), with OpenVINO also in the comparison. Absolute speeds are tiny — a 70B model on shared-memory integrated graphics is a stunt configuration — but the within-machine ordering is the useful signal: the native PyTorch path was not embarrassed by the C++ path on its home hardware.
- **Community Ollama-on-Arc guides** (2024–2025) consistently frame IPEX-LLM as the way that made Arc work with Ollama at all in that period, while complaining about exactly the frictions §5 records: driver sensitivity, environment setup, and portable-zip staleness (§4.3).

**Character summary.** On its home hardware, in its best configurations, IPEX-LLM delivers genuinely usable interactive speeds for 7–8B models at 4-bit — the difference between "this laptop cannot run a local LLM" and "it can". It does not, on any evidence found, beat a comparable NVIDIA setup, and Intel's own most aggressive comparison (against a half-VRAM RTX 4060) should be read as marketing framing rather than measurement. The performance story is a *viability* story, and it is strongest when told that way.

---

## 7. Project health, as public fact

The repository situation requires care, because three addresses tell three different stories:

1. **`intel-analytics/ipex-llm`** is the historical home. The project's own documentation files still link to it throughout (every quickstart read for this dossier carries `intel-analytics` URLs), and fetching it returns the Intel repository — it functions as a redirect/legacy address.
2. **`intel/ipex-llm`** is the canonical Intel repository as fetched on 2026-11-15: ~8,800 stars, ~1,400 forks, 4,113 commits, 22 releases, repository creation date of 2016-08-29 inherited from BigDL, Apache-2.0. Its news list shows a decelerating cadence through 2025: release 2.2.0 in April 2025, a FlashMoE announcement in May 2025, and nightly C++ builds pinned to mid-2025 upstream versions (the June 2025 build stamps in §4.3). No 2025 feature release after 2.2.0 appears in the material read.
3. **`ipex-llm/ipex-llm`** is a fork under a purpose-created organisation, created 2025-04-20, with ~157 stars, 11 forks and 2 releases as fetched — the same codebase and README lineage, without Intel's organisational home and with a fraction of the traction. Its existence suggests an attempted community continuation; the sources read do not establish who operates it or whether Intel endorsed the move, and this dossier makes no claim either way.

**Post-cutoff note (flagged, not folded in).** The live Intel repository page, as fetched for this dossier, already displays an archive banner stating that Intel will not provide development or support, that patches are no longer accepted, and that the project has known security issues. Independent coverage published in 2026 dates the formal archiving of the repository to **28 January 2026** — after this dossier's 2026-11-15 cutoff — and directs Arc users to llama.cpp's SYCL/Vulkan backends and OpenVINO as the maintained Intel paths. The coordinator should treat the archival as confirmed-by-fetch but dated after the cutoff: as of 2026-11-15 the accurate statement is that the project was in visible late life (slowing releases, ageing integration pins, a community fork appearing), and it was subsequently archived. Either way, no engineering plan in this corpus should assume future IPEX-LLM releases.

Two softer health signals from the record itself: the documentation's centre of gravity stopped moving in early 2025 (the guides' internal version references cluster around late 2024 to mid 2025), and the project's energy visibly shifted over its last year from the Python library to the C++ portable packages — the library that was the product became the backend for two borrowed interfaces.

---

## 8. Strengths and weaknesses

### Strengths

- **The conversion UX is the best in this corpus at its moment.** One import change and one load flag turn any verified Hugging Face model into a low-bit Intel-accelerated model. No export step, no separate artefact pipeline, no model zoo lock-in.
- **Genuine hardware breadth from one API:** CPU, iGPU, two Arc generations, Flex/Max, and an NPU path — a wider Intel matrix than OpenVINO GenAI presents to LLM users, and far wider than stock Ollama offered Intel users in 2024.
- **Format breadth with published accuracy:** INT4/INT8/FP4/FP6/FP8/INT2 plus GGUF/AWQ/GPTQ ingestion, with a per-format perplexity table in the README.
- **It met users at Ollama's interface** when Intel hardware had no other route there, and shipped no-install portable packages for both Ollama and llama.cpp.
- **Fine-tuning included** (LoRA family on GPU and CPU), which pure runners do not offer.

### Weaknesses

- **Layered-version fragility everywhere:** pinned PyTorch/IPEX releases, a Linux-only four-family vLLM fork, Ollama/llama.cpp builds trailing upstream by multiple releases, a portable zip reported frozen at a January 2025 Ollama. The architecture guarantees this failure mode; the record confirms it.
- **Install and runtime friction:** oneAPI environment loading, conda-based quickstarts, driver floors, kernel sensitivities — all documented at length in the project's own troubleshooting pages. The distance from Ollama's single-binary experience is the product's defining UX gap, and the portable zips were a partial patch over it.
- **Intel-only ceiling:** no answer for NVIDIA/AMD/Apple hardware, which confined its community and its benchmark culture.
- **Vendor-only performance evidence:** headline numbers are Intel's, against Intel-chosen baselines; independent benchmarking is thin, and what exists is less flattering (§6.2).
- **Terminal project health:** decelerating releases through 2025 and subsequent archival (§7). The ideas outlive the project; the binaries will age out as GGUF and drivers move on.

---

## 9. Ideas to steal for a Go runner

Each idea is stated with its gain and its cost or risk, in the corpus's usual form. Nothing here requires adopting IPEX-LLM's stack — the borrowable assets are postures and interfaces, not code (and the licence, Apache-2.0, would in any case require attribution discipline this clean-room corpus avoids needing).

### 9.1 Low-bit-first as the default posture for commodity hardware

**The idea.** Treat 4-bit-class weights not as an optimisation the user opts into, but as the assumed default representation for local inference, with higher precision as the opt-out. IPEX-LLM's entire design — default symmetric INT4 in its own benchmark configuration, 4-bit flags in every quickstart — embodies this.

**Gain.** It aligns the default with the hardware the target users actually own: integrated graphics with shared memory, 8–16 GB cards, laptops. A runner whose default fits is a runner whose first run succeeds, and first-run success is the whole adoption game for a local tool. It also simplifies the performance story: one default path gets the kernel-tuning effort.

**Cost / risk.** A low-bit default is a quality decision made on the user's behalf; it must ship with IPEX-LLM's one honest habit — a published per-format accuracy table — or it will be discovered as silent degradation. In Go, it also commits the project to maintaining good dequantisation kernels for the chosen default format on every target, which is precisely the kernel burden §3.2 shows Intel spreading across XMX/AMX/SYCL. Pick the default format for kernel simplicity across CPU and GPU, not for fashion.

### 9.2 In-place conversion UX: any model, one call

**The idea.** Let the user name any model in the ecosystem's canonical catalogue (for a Go Ollama-descendant: any GGUF, and aspirationally any Hugging Face checkpoint) and have the runner perform whatever conversion is needed at load time, caching the result — rather than requiring a pre-converted artefact from a project-run zoo. This is the PyTorch cousin of the in-situ quantisation idea seen elsewhere in this corpus (mistral.rs's ISQ): conversion as a load-time service, not a publishing pipeline.

**Gain.** Coverage stops being gated on the runner team's conversion labour; the long tail of community models works on day one; users keep one mental model ("name a model, run it") regardless of source format.

**Cost / risk.** Load-time conversion costs startup latency and a cache-management problem (converted artefacts need invalidation, disk budgets, and provenance). It also moves correctness risk into the runner: a bad automatic conversion produces subtly wrong output that users will blame on the model. IPEX-LLM mitigated this with a verified-model list alongside the any-model promise — a Go runner should copy that pairing: automatic conversion for everything, an explicit verified tier for what has been tested, and the tier visible in the UI/API.

### 9.3 "Runs on what you already own" as an explicit market position

**The idea.** IPEX-LLM's real product was never speed; it was *viability on the installed base* — the laptop iGPU, the office Xeon, the cheap 16 GB Arc card. Its demos lead with a Core Ultra iGPU and an NPU, not a flagship. A Go runner aimed at improved-Ollama territory can adopt the same positioning honestly: benchmark and advertise on commodity hardware, publish the modest absolute numbers, and frame them as "your existing machine, now useful".

**Gain.** It competes where the CUDA incumbents are weakest (they optimise for hardware their users bought on purpose; the much larger population owns whatever came with the laptop), and it is a claim that survives scrutiny because it does not require winning a single flagship benchmark.

**Cost / risk.** Commodity-hardware positioning means supporting the messiest matrix — shared-memory iGPUs, driver variance, thermal limits — which is exactly where IPEX-LLM's troubleshooting pages grew. The position is only honest if the support burden is budgeted. It also caps the headline numbers marketing can use; teams must resist inflating them the way §6.1's 4060 comparison does, because the audience for this position checks.

### 9.4 (Secondary) Borrow interfaces, but budget the re-basing treadmill

**The idea.** IPEX-LLM's Ollama-compatible binary won it users no library could have reached. Compatibility with the dominant local interface is worth having — as an API surface the Go runner implements natively, not as a forked binary it must perpetually re-base.

**Gain.** Users bring their existing tools, scripts and muscle memory.

**Cost / risk.** §4.3 is the cautionary tale: every externally-owned interface adopted as a *binary* becomes a version-skew liability with a visible expiry date. Implement the compatibility; do not inherit the upstream.

---

## 10. Sources

All accessed 2026-11-15 unless otherwise dated. Vendor sources are Intel's; independent sources are labelled.

1. Intel IPEX-LLM repository, canonical home — README, repository metadata (licence Apache-2.0, stars/forks/commits/releases, creation date 2016-08-29), news list 2023-09 → 2025-05, verified-model table, perplexity table. `github.com/intel/ipex-llm`. The same content is served from the legacy address `github.com/intel-analytics/ipex-llm`, which the project's own docs link to throughout.
2. Community fork repository — metadata (created 2025-04-20, ~157 stars, 2 releases, not archived) and README. `github.com/ipex-llm/ipex-llm`.
3. IPEX-LLM Ollama quickstart (project docs) — C++ backend model, `ipex-llm[cpp]` install route, Ollama version alignment (current build consistent with Ollama v0.9.3; 2025-06-29 build with v0.6.2), GPU-layer environment variable, troubleshooting record. `docs/mddocs/Quickstart/ollama_quickstart.md` in the repository.
4. IPEX-LLM llama.cpp quickstart (project docs) — SYCL backend, portable zip, upstream commit pins, driver minimum. `docs/mddocs/Quickstart/llama_cpp_quickstart.md` in the repository.
5. IPEX-LLM vLLM quickstart (project docs) — Linux-only scope, four supported model families, maintained-fork install, OpenAI-compatible server entry point, documented `load_in_low_bit` values, tensor parallelism. `docs/mddocs/Quickstart/vLLM_quickstart.md` in the repository.
6. IPEX-LLM Linux GPU install guide (project docs) — Flex/Max/Arc/iGPU scope, Ubuntu/kernel verification notes, oneAPI requirement, pip install shapes. `docs/mddocs/Quickstart/install_linux_gpu.md` in the repository.
7. IPEX-LLM benchmark quickstart (project docs) — all-in-one benchmark configuration, symmetric INT4 as the default low-bit value. `docs/mddocs/Quickstart/benchmark_quickstart.md` in the repository.
8. Intel, "Accelerate LLM Inference on Your Local PC" (developer article, intel.com) — Transformers-API flow with the 4-bit load flag, in-place conversion description, GGUF/AWQ/GPTQ loading.
9. Intel, LLM inference whitepaper on IPEX and IPEX-LLM (PDF, August 2024) — the two-libraries distinction and version pin, AVX-512 VNNI / AMX / XMX attribution for the combined PyTorch stack.
10. Intel gaming/developer article on running LLMs locally with IPEX-LLM (game.intel.com) — XMX credit for Arc A-series; the 70 tok/s Mistral-7B A770 claim against an RTX 4060 8 GB, labelled internal testing. **Vendor numbers.**
11. BigDL project site (bigdl-project.github.io) — `bigdl-llm` → `ipex-llm` rename notice (March 2024) and the original INT4/FP4/INT8/FP8 any-PyTorch-model pitch.
12. Intel Open Edge Platform documentation mirror of the IPEX-LLM overview (2025.1/2025.2 editions) — XPU scope (CPU, iGPU, NPU, dGPU), low-bit family (FP8/FP6/FP4/INT4), integration list, 2.2.0b2 install pin.
13. Independent: SpecPicks, IPEX-LLM + Ollama Docker review (published 2026-07-21, updated 2026-09-25; post-cutoff, used only for independent performance character) — ~20–40 tok/s range for 7–8B Q4 on Arc/Iris Xe; A770 ~42 tok/s vs RTX 3060 ~48 tok/s on Llama-3.1-8B Q4_K_M. **Independent numbers, single outlet.**
14. Independent: SpecPicks and RefusalRate Intel-Arc coverage (2026; post-cutoff, used only for the §7 archival dating and migration-path context) — repository archived 2026-01-28, no further maintenance/releases, known-security-issues wording, llama.cpp SYCL/Vulkan and OpenVINO named as maintained paths.
15. Independent: hobbyist Core Ultra 5 comparison (Medium, undated in fetched copy) — Llama-3 8B/70B via llama.cpp vs IPEX-LLM Python vs OpenVINO on one iGPU machine; IPEX-LLM Python ahead of its llama.cpp path at 70B (~1.86 vs ~1.44 tok/s).
16. Independent: community gist, Windows + Lunar Lake IPEX-LLM/Ollama working notes (accessed 2026-11-15) — portable zip frozen at Ollama v0.5.4, post-mid-2025 model failures, pip-route workaround with a late-2025 nightly C++ build. **Single community source; flagged in text.**
17. Secondary (used sparingly, flagged in text): a GigaGPU Arc Pro B60 setup guide for the `optimize_model` entry-point shape alongside the Transformers API; a community gist on INT4 kernel encodings for the §3.2 note. Neither is load-bearing for any claim in this dossier.

**Unverifiable / not established from sources read:** Flex- and Max-series performance figures; FlashMoE throughput at 671B scale; the operator of, and any Intel relationship to, the `ipex-llm` organisation fork; FP6/FP8 real-world speed (as opposed to perplexity) on consumer Arc parts; any macOS story (none is documented).
