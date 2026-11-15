# Research Corpus — Index

The RuneForgeAI Ollama Experiments research library: how LLM model runners work, how memory
works, and what our own Ollama experiments should learn from both. Built 2026-11-15 onward,
at Volmarr's commission, so that hard-won field knowledge lives in one sourced, dated,
usable place.

## How this library is organised

The corpus holds **134 files** in total (**~5.6 MB** — 5,640,721 bytes of Markdown),
counted 2026-11-15: 4 at the root, 35 in `runners/`, 78 in `papers/`, 15 in `memory/`,
1 in `aesir/`, and 1 in `synthesis/`. Branch head at this count: `6ac985f`
(`yrsa/research-corpus`).
Every file is listed exactly once below, under the section where it lives.

### Root volumes (4)

- `00-INDEX.md` — this index: the corpus's front door, its organisation, discipline, and
  maintenance rules.
- `00-FIELD-MAP.md` — OR-1 field map of model runners, inference engines, and serving
  systems (Version 4, 2026-11-15; 54 enumerated entries), each with licence, language,
  backend, and a one-line essence. Living document: the sweep keeps adding finds —
  sweep #3 added 7 entries (incl. DeepInfer, TokenSpeed, ExLlamaV3, Magnitude),
  recorded TensorRT-LLM's move to a PyTorch sole backend and Triton's rename to
  Dynamo-Triton, and marked ExLlamaV2 archived-for-now.
- `BIBLIOGRAPHY.md` — the living bibliography for the whole corpus: full citations, with
  canonical links, for the papers and systems the dossiers rest on. Merges per wave;
  additions sections now run through wave 31 — sampling & decoding (wave 9), measurement
  methodology (wave 10), disaggregation & migration (wave 11), energy & efficiency
  (wave 12), speculative decoding II (wave 13), agent-memory ancestors (wave 14),
  KV in motion (wave 15), the rotation lineage (wave 16), sparse attention (wave 17),
  guided generation (wave 18), multi-LoRA serving (wave 19), low-bit serving systems
  (wave 20), long-context evaluation (wave 21), model-zoo economics (wave 22),
  decoding for truth (wave 23), early exit (wave 24), offload & heterogeneous
  (wave 25), and speculation at long context (wave 26).
- `MASTER-COMPENDIUM.md` — the distilled state of the art: how LLMs run, and how runners
  make them fast, lean, and truthful. Living document — second draft banked 2026-11-15,
  with third-, fourth-, fifth- and sixth-cut amendments appended 2026-11-15, the third
  folding batch 4, the fourth folding batches 5–6, the fifth folding the eleven deep-dive
  and wave-27/28/30/31 dossiers, and the sixth folding the five runner dossiers banked
  since the fifth cut and field map v4 (54 entries, sweep #3) into the volume.

### `runners/` — one dossier per runner (35)

Clean-room dossiers (OR-2): architecture, scheduling, KV design, memory management,
quantization, kernels, session/prefix handling — in our own words, licence recorded,
an ideas-to-steal section in each.

- `runners/aphrodite.md` — Aphrodite Engine (PygmalionAI): a datacentre engine re-aimed
  at roleplay; covers the Aphrodite era and its rename to Sonar.
- `runners/candle.md` — Candle: Hugging Face's Rust machine-learning framework
  (`candle-core`, `candle-nn`, `candle-transformers`), Rust throughout with optional
  Python bindings.
- `runners/deepinfer.md` — DeepInfer (DeepSeek): Apache-2.0 — DeepSeek's one-model
  co-designed engine core, built for exactly one checkpoint; the production
  disaggregated system it was extracted from is described in detail but not shipped.
- `runners/deepspeed-fastgen.md` — DeepSpeed-FastGen / DeepSpeed-MII (Microsoft): the
  training library's inference line rebuilt for LLM serving — MII's deployment shell over
  DeepSpeed-Inference kernels, re-scheduled around Dynamic SplitFuse, continuous
  batching, and a blocked KV cache.
- `runners/exllamav2.md` — ExLlamaV2: the single-user speed specialist — Python
  orchestration over a PyTorch C++/CUDA extension.
- `runners/exllamav3.md` — ExLlamaV3: the successor volume to the ExLlamaV2 dossier —
  MIT-licensed; EXL3/QTIP trellis quantisation.
- `runners/exllamav3-session-pass.md` — ExLlamaV3 session / prefix pass (OR-2 addendum):
  closes the V3 dossier's session/prefix questions — chained prefix hash, retention,
  and tiers: 256-token pages keyed by a chained hash, retained across jobs in VRAM,
  pinned-memory, and disk tiers.
- `runners/ggml-backend-internals.md` — ggml backend and graph-allocator internals
  (OR-2 deep-dive addendum): how ggml assigns tensors to device buffers, places a
  compute graph's tensors, and pools CUDA/HIP memory — the layer beneath the
  llama.cpp / ggml dossier.
- `runners/gpt4all.md` — GPT4All (Nomic AI): desktop application, embeddable inference
  library, and language bindings for running LLMs locally.
- `runners/ipex-llm.md` — Intel IPEX-LLM: Intel's LLM library for PyTorch, descended
  from BigDL via `bigdl-llm`.
- `runners/jan.md` — Jan (Jan Desktop, Menlo Research): a public-documentation behaviour
  dossier on the desktop app.
- `runners/koboldcpp.md` — KoboldCpp: a public-documentation behaviour dossier on the
  personal / character-chat runner.
- `runners/lemonade.md` — AMD Lemonade: AMD's local AI server — the `lemond` daemon and
  `lemonade` command, implemented in C++.
- `runners/llamacpp-ggml.md` — llama.cpp / ggml: the gravity well of local inference —
  the inference engine and its tensor library together.
- `runners/llamacpp-kv-internals.md` — llama.cpp KV-cache and slot internals (OR-2
  deep-dive addendum): how the KV cache is organised, how sequences share it, and how
  llama-server's slots sit on top of it — companion to the llama.cpp / ggml dossier.
- `runners/llamacpp-server-ecosystem.md` — the server frontends, proxies, routers, and
  packaged distributions that grew around `llama-server` and the ggml core — not the core
  itself.
- `runners/llamafile.md` — llamafile: Mozilla AI's single-executable distribution of
  llama.cpp.
- `runners/llm-d.md` — llm-d: not an inference engine but the Kubernetes-native
  orchestration layer above inference engines — a Go Endpoint Picker (EPP) owning only
  the placement decision, over machinery borrowed from Kubernetes and the Gateway API;
  a CNCF Sandbox project since March 2026, at v1.0.0 (October 2026).
- `runners/lm-studio.md` — LM Studio (Element Labs): a closed-source desktop application
  for running local LLMs.
- `runners/lmdeploy.md` — LMDeploy: a toolkit for compressing, deploying, and serving
  LLMs and vision-language models, with TurboMind and PyTorch backends.
- `runners/magnitude.md` — Magnitude: Apache-2.0, Rust — a local agent-serving engine
  whose kernels are tuned per-hardware at download time, spending up to about a minute
  on the user's own chip trying configurations and keeping the fastest
  output-identical one.
- `runners/mistral-rs.md` — mistral.rs: a Rust inference engine whose Rust crate and
  Python package are both first-class SDKs over the same core.
- `runners/mlc-llm.md` — MLC-LLM and MLCEngine: the compile-anywhere pole of the MLC /
  Apache TVM line; its browser sibling WebLLM is covered inside the same dossier.
- `runners/mlx.md` — MLX + MLX-LM: Apple's unified-memory array framework and its LLM
  package — the unified-memory exemplar.
- `runners/nvidia-dynamo.md` — NVIDIA Dynamo: not an inference engine but the
  orchestration layer above inference engines — a Rust frontend and KV-aware router,
  worker processes wrapping vLLM, SGLang, or TensorRT-LLM, a planner that resizes
  prefill and decode pools against latency targets, and the NIXL transfer library
  moving KV cache between workers and memory tiers.
- `runners/ollama-internals.md` — Ollama internals (OR-2 deep-dive addendum):
  scheduling, memory estimation, and context handling read from Ollama's own source —
  the deep companion to the Ollama dossier.
- `runners/ollama.md` — Ollama itself: the deep dossier at the centre of our work,
  written for the engineer of an improved Ollama fork.
- `runners/onnx-runtime-genai.md` — ONNX Runtime GenAI (ORT GenAI): Microsoft's
  generative-AI library — a C++ core with Python, C#, C/C++, Java, and Objective-C
  surfaces.
- `runners/openvino-genai.md` — OpenVINO GenAI (Intel): the generative-AI pipeline
  library built on top of the OpenVINO Runtime.
- `runners/powerinfer.md` — PowerInfer and PowerInfer-2: sparsity-aware hybrid inference.
- `runners/ramalama.md` — RamaLama: the model-as-container runner, written in Python.
- `runners/sglang.md` — SGLang: a fast inference framework for large language,
  vision-language, and diffusion models, with its SRT runtime.
- `runners/tensorrt-llm.md` — TensorRT-LLM (NVIDIA): the vendor-native, compile-first
  pole of serving.
- `runners/tokenspeed.md` — TokenSpeed (LightSeek Foundation): MIT — an agentic-serving
  engine maximising tokens-per-minute per GPU under a per-user speed floor;
  suspend-by-image retraction and a typed FSM scheduler whose types make unsafe
  KV reuse unrepresentable.
- `runners/vllm.md` — vLLM: the serving engine whose name glosses as "virtual LLM" —
  Python engine, scheduler, and API server over C++ / CUDA / Triton kernels.

### `papers/` — one dossier per research paper (78)

Paper dossiers (OR-3): full citation, the core idea in our own words, the paper's measured
claims **as reported** (with their hardware context), and applicability notes for
Ollama-on-a-6 GB-GPU and for Project Aesir.

- `papers/atom.md` — Atom: low-bit quantization for efficient and accurate LLM serving —
  W4A4 (4-bit weights, 4-bit activations, 4-bit KV cache) held accurate by segregating
  the top outlier activation channels, profiled on calibration data, to INT8.
- `papers/awq.md` — AWQ: activation-aware weight quantization for LLM compression and
  acceleration.
- `papers/burstgpt.md` — BurstGPT: a real-world workload dataset to optimize LLM
  serving systems — request-level traces from a production Azure OpenAI service
  (arrivals, request/response lengths, failures), showing real LLM traffic is bursty
  and time-varying in ways synthetic workloads miss.
- `papers/cacheblend.md` — CacheBlend: fast LLM serving for RAG with cached knowledge
  fusion, reusing precomputed KV for chunks in any position.
- `papers/cachegen.md` — CacheGen: KV cache compression and streaming for fast LLM
  serving — compression to move, not to keep: delta encoding against group anchors plus
  layer-wise quantisation, streamed chunk-by-chunk at bandwidth-adaptive quality levels.
- `papers/contrastive-decoding.md` — Contrastive Decoding: open-ended text generation
  as optimization — a search method scoring candidate tokens by an expert model's
  log-probability minus a smaller amateur model's, restricted to a plausibility set.
- `papers/deepseek-v2-mla.md` — DeepSeek-V2: a strong, economical, efficient
  mixture-of-experts model, and its Multi-head Latent Attention (MLA).
- `papers/distserve.md` — DistServe: disaggregating prefill and decoding for
  goodput-optimized LLM serving.
- `papers/dola.md` — DoLa: decoding by contrasting layers improves factuality in large
  language models — the final layer's distribution contrasted against an earlier,
  premature layer's, both read through the same vocabulary head; no extra model.
- `papers/duoattention.md` — DuoAttention: efficient long-context LLM inference with
  retrieval and streaming heads — only retrieval heads keep the full KV cache, while
  streaming heads keep attention sinks plus a recent window, cutting KV memory.
- `papers/eagle-2.md` — EAGLE-2: faster inference with dynamic draft trees — EAGLE's
  feature-level drafting restructured per step into a context-aware tree, expanded and
  pruned by confidence.
- `papers/eagle-3.md` — EAGLE-3: scaling up inference acceleration via training-time test.
- `papers/eagle.md` — EAGLE: speculative sampling by predicting the target's next
  feature rather than its next token.
- `papers/fastserve.md` — FastServe: fast distributed inference serving for large
  language models — token-level preemptive scheduling with a skip-join multi-level
  feedback queue, plus proactive KV-cache swapping so preemption stays affordable.
- `papers/flashattention.md` — FlashAttention: fast, memory-efficient exact attention
  with IO-awareness.
- `papers/flashattention-2.md` — FlashAttention-2: faster attention with better
  parallelism and work partitioning.
- `papers/flashattention-3.md` — FlashAttention-3: fast, accurate attention with
  asynchrony and low precision.
- `papers/flashinfer.md` — FlashInfer: an efficient, customizable attention engine for
  LLM inference serving.
- `papers/flexgen.md` — FlexGen: high-throughput generative inference of large language
  models with a single GPU — exact inference under a searched placement policy that
  assigns fractions of weights, activations, and KV cache across GPU, CPU/DRAM, and disk.
- `papers/gptq.md` — GPTQ: accurate post-training quantization for generative
  pre-trained transformers.
- `papers/gqa.md` — GQA: training generalized multi-query transformer models from
  multi-head checkpoints (grouped-query attention).
- `papers/h2o.md` — H2O: the Heavy-Hitter Oracle for efficient generative inference —
  KV eviction by accumulated attention.
- `papers/infbench.md` — ∞Bench: extending long context evaluation beyond 100K tokens —
  12 tasks across retrieval, code, math, novels, and dialogue, with average data length
  surpassing 100K tokens.
- `papers/infini-attention.md` — Infini-attention: Leave No Context Behind — efficient
  infinite-context transformers pairing masked local attention with a compressive
  long-term memory, so context grows without bound inside a bounded memory budget.
- `papers/infinigen.md` — InfiniGen: efficient generative inference with dynamic KV
  cache management — the whole KV cache lives in CPU memory, and each layer's needed
  entries are predicted by a cheap rehearsal on the previous layer's input and
  prefetched to the GPU.
- `papers/kivi.md` — KIVI: a tuning-free asymmetric 2-bit quantization for the KV cache.
- `papers/kvquant.md` — KVQuant: KV cache quantization towards 10 million context length
  inference.
- `papers/layerskip.md` — LayerSkip: enabling early exit inference and self-speculative
  decoding — depth-graded layer-dropout training, so a checkpoint can exit early or
  draft from its own early layers and verify with its full depth.
- `papers/llumnix.md` — Llumnix: dynamic scheduling for LLM serving — running requests
  are live-migrated between instances, KV cache and all, by a multi-stage pipeline
  overlapped with continued decoding; load balancing, de-fragmentation, and
  prioritisation are policies over that one primitive.
- `papers/longrope.md` — LongRoPE: extending the LLM context window beyond 2 million
  tokens.
- `papers/lookahead-decoding.md` — Lookahead Decoding: breaking the sequential dependency
  of LLM inference with Jacobi-style lookahead, no draft model.
- `papers/mamba.md` — Mamba: linear-time sequence modeling with selective state spaces.
- `papers/mamba-2.md` — Mamba-2: "Transformers are SSMs" — generalized models and
  efficient algorithms through structured state space duality.
- `papers/medusa.md` — Medusa: a simple inference-acceleration framework with multiple
  decoding heads on the target model itself.
- `papers/melange.md` — Mélange: cost efficient large language model serving by
  exploiting GPU heterogeneity — an offline allocator that profiles per-(GPU,
  request-size, SLO) capacity and solves a bin-packing optimisation to provision the
  cheapest GPU mix.
- `papers/min-p-sampling.md` — Min-p sampling ("Turning Up the Heat"): the sampling
  pool is cut at a threshold set relative to the top token's probability, so the pool
  tightens when the model is confident and widens when it is not.
- `papers/minference.md` — MInference 1.0: accelerating pre-filling for long-context
  LLMs via dynamic sparse attention — each head's sparsity falls into one of three
  stable shapes (A-shape, vertical-slash, block-sparse), so the sparse pattern is
  estimated per head rather than per token.
- `papers/mirostat.md` — Mirostat: a decoding algorithm that directly controls
  perplexity — a feedback controller wrapped around top-k sampling, holding the
  generated text's observed surprise at a user-set target.
- `papers/mixtral.md` — Mixtral of Experts: the Mixtral 8×7B sparse mixture-of-experts
  language model.
- `papers/mixture-of-depths.md` — Mixture-of-Depths: dynamically allocating compute
  in transformer-based language models — a router passes only a capacity-limited
  subset of tokens through each block, the rest travelling the residual path, so
  compute is allocated per token by depth.
- `papers/mlperf-inference.md` — MLPerf Inference: the benchmark's scenarios,
  tail-latency rules, and anti-gaming machinery — the corpus's measurement-methodology
  anchor: no number without its conditions.
- `papers/moe-infinity.md` — MoE-Infinity: efficient MoE inference on personal machines
  with a sparsity-aware expert cache.
- `papers/mooncake.md` — Mooncake: a KVCache-centric disaggregated architecture for LLM
  serving (Moonshot AI's Kimi fleet) — prefill and decode clusters over a shared
  disaggregated KV pool built from the fleet's otherwise-idle CPU, DRAM, SSD, and NIC
  capacity.
- `papers/native-sparse-attention.md` — Native Sparse Attention (NSA): hardware-aligned
  and natively trainable sparse attention — three gated parallel branches (compression,
  selection, sliding window) with independent keys and values; an architecture a model
  is trained with, not a serving retrofit.
- `papers/ntk-aware-scaling.md` — NTK-aware scaling: a lineage dossier (community
  origin — bloc97, with emozilla's Dynamic NTK; no paper) — RoPE context extension by
  raising the base so high-frequency dimensions extrapolate while low-frequency
  dimensions interpolate, formalised inside YaRN.
- `papers/online-speculative-decoding.md` — Online Speculative Decoding: adapting the
  draft model to live query traffic.
- `papers/orca.md` — Orca: a distributed serving system for transformer-based generative
  models — iteration-level scheduling and selective batching.
- `papers/outlines-guided-generation.md` — Outlines / efficient guided generation
  (Willard & Louf): guided generation as an index over the vocabulary — regular
  expressions compiled to finite-state machines, so the set of legal next tokens is
  indexed in advance rather than rescanned at every step.
- `papers/pagedattention-vllm.md` — PagedAttention: efficient memory management for LLM
  serving, managing the KV cache as OS-style paged memory (the vLLM paper).
- `papers/position-interpolation.md` — Position Interpolation: extending context
  window of large language models via positional interpolation — RoPE position
  indices rescaled by L/L′ so longer sequences stay inside the trained angle range,
  extended with only brief fine-tuning.
- `papers/power-hungry-processing.md` — Power Hungry Processing: watts driving the cost
  of AI deployment? — measured energy and carbon costs of inference across tasks and
  model sizes.
- `papers/powerinfer-2.md` — PowerInfer-2: fast large language model inference on a
  smartphone — neuron clusters as the single unit of computation scheduling, storage
  layout, and NPU/CPU placement, with hot clusters materialised dense and cold clusters
  kept sparse.
- `papers/prompt-cache.md` — Prompt Cache: modular attention reuse for low-latency
  inference, from reusable prompt segments with precomputed attention states.
- `papers/punica.md` — Punica: multi-tenant LoRA serving — one resident copy of the
  backbone for the whole batch, with each request's adapter computed on the fly by the
  SGMV (segmented gather matrix-vector multiplication) kernel.
- `papers/pyramidkv.md` — PyramidKV: dynamic KV cache compression based on pyramidal
  information funneling.
- `papers/qserve.md` — QServe: W4A8KV4 quantization and system co-design for efficient
  LLM serving — the QoQ algorithm (4-bit weights, 8-bit activations, 4-bit KV cache)
  with progressive group quantisation, its GEMMs running on INT8 tensor cores.
- `papers/quarot.md` — QuaRot: outlier-free 4-bit inference in rotated LLMs —
  computational-invariance rotations remove the activation outliers, so weights,
  activations, and KV cache can all run at 4-bit.
- `papers/quip-sharp.md` — QuIP#: even better LLM quantization with Hadamard incoherence
  and lattice codebooks.
- `papers/radixattention-sglang.md` — the SGLang paper: efficient execution of structured
  language model programs, with RadixAttention's radix-tree KV reuse.
- `papers/ruler.md` — RULER: what's the real context size of your long-context language
  models? — synthetic, configurable tasks (hardened needle retrieval, multi-hop
  tracing, aggregation, question answering) that measure effective context length
  inside the claimed window.
- `papers/s-lora.md` — S-LoRA: serving thousands of concurrent LoRA adapters —
  adapters never merged; all of them resident in host memory with the active ones
  fetched to the GPU, and the base computation batched across every request regardless
  of adapter.
- `papers/sarathi-serve.md` — Sarathi-Serve: taming the throughput–latency tradeoff in
  LLM inference with chunked prefill and stall-free batching.
- `papers/sequoia.md` — Sequoia: scalable, robust, and hardware-aware speculative
  decoding — draft trees constructed by dynamic programming under a positional
  acceptance model, with tree size chosen against a measured hardware cost model.
- `papers/serverlessllm.md` — ServerlessLLM: low-latency serverless inference for large
  language models — a loading-optimised checkpoint format, live migration that makes
  server locality usable without punishing running work, and a scheduler that prices
  both.
- `papers/skipdecode.md` — SkipDecode: autoregressive skip decoding with batching and
  caching for efficient LLM inference — a single exit layer per sequence position,
  shared by the whole batch and monotonically decreasing along the sequence.
- `papers/smoothquant.md` — SmoothQuant: accurate and efficient post-training
  quantization for LLMs by smoothing activation outliers.
- `papers/snapkv.md` — SnapKV: the LLM knows what you are looking for before generation —
  prompt-selected KV compression.
- `papers/specinfer.md` — SpecInfer: tree-based speculative inference and verification —
  the verifier judges a tree of candidate continuations from boosted small speculators
  in a single pass, instead of one linear chain.
- `papers/speculative-decoding.md` — the founding pair, treated as one family:
  speculative decoding and speculative sampling, introduced independently in 2023.
- `papers/spinquant.md` — SpinQuant: LLM quantization with learned rotations — QuaRot's
  fixed rotations made learnable, optimised for low-bit weight-and-activation
  quantization.
- `papers/splitwise.md` — Splitwise: efficient generative LLM inference using phase
  splitting of prefill and decode.
- `papers/streamingllm.md` — StreamingLLM: efficient streaming language models with
  attention sinks.
- `papers/titans.md` — Titans: learning to memorize at test time — a neural long-term
  memory module that learns from the sequence itself during inference, paired with
  short-term attention, for very long contexts.
- `papers/triforce.md` — TriForce: lossless acceleration of long sequence generation
  with hierarchical speculative decoding — the target model drafts for itself against
  a small retrieved subset of its KV cache, and a small draft model drafts for that
  in turn.
- `papers/vidur.md` — Vidur: a large-scale simulation framework for LLM inference —
  profile the operators once, predict the unprofiled sizes, and simulate scheduling,
  batching, and KV-cache management as discrete events, validated against real vLLM.
- `papers/words-to-watts.md` — From Words to Watts: benchmarking the energy costs of LLM
  inference — joules per token across model sizes, hardware generations, sharding, and
  batching, every figure carrying its conditions.
- `papers/xgrammar.md` — XGrammar: flexible and efficient structured generation engine
  for large language models — context-free grammars compiled to a byte-level pushdown
  automaton, so nested structures (JSON and kin) are constrained with a stack rather
  than a flat finite-state machine.
- `papers/yarn.md` — YaRN: efficient context window extension of large language models.

### `memory/` — the memory corpus (15)

The memory corpus (OR-6): memory as a science, from KV caches to DRAM to allocators,
each dossier carrying applicability notes for Ollama, for Project Aesir, and for our own
hardware.

- `memory/00-MEMORY-FIELD-MAP.md` — OR-6 memory field map: the topic tree for memory
  researched as a science in its own right (Version 1, 2026-11-15).
- `memory/MEMORY-COMPENDIUM.md` — the OR-6 crown volume: the distilled state of the art
  for memory for AI systems, for computers, and for the allocators between them. Living
  document — second draft banked 2026-11-15, with third-, fourth-, fifth- and sixth-cut
  amendments appended 2026-11-15 folding batches 4–6's memory dossiers, the fifth
  cut's memory-bearing dossiers, and the sixth cut's memory-bearing dossiers into the
  volume.
- `memory/agent-memory-architectures.md` — agent memory architectures (dossier A5): what
  persists between sessions, how it is retrieved, and how it is corrected.
- `memory/allocator-lineages.md` — allocator lineages and designs: the discipline of
  allocation itself.
- `memory/generative-agents.md` — Generative Agents (dossier A8-1): the memory-stream
  ancestor — a chronological stream of observations, retrieval scored on recency,
  importance, and relevance, and reflection synthesising higher-level memories from the
  stream.
- `memory/gpu-memory-internals.md` — GPU memory internals: how VRAM is actually
  allocated, moved, and fragmented beneath a runner.
- `memory/kv-cache-design.md` — KV-cache design: a synthesis dossier on the design space
  of the cache itself, drawn from the corpus's own banked dossiers.
- `memory/memory-technologies-dram-cxl.md` — memory technologies: DRAM generations and
  CXL — the datasheet layer.
- `memory/memory-wall-and-roofline.md` — the memory wall and the roofline method: why
  decode is bandwidth-bound, and how to prove it.
- `memory/memorybank.md` — MemoryBank (dossier A8-2): Ebbinghaus forgetting as a memory
  update rule — memories decay unless life rehearses them — together with the summarised
  user profile, from the SiliconFriend long-term companion.
- `memory/mimiralloc-our-own-proven-work.md` — MimirAlloc: a first-hand record of our own
  proven allocator work — our own project, read freely, no clean-room restriction.
- `memory/npu-memory-and-dataflows.md` — NPU memory and dataflow architectures: when
  SRAM, not DRAM, is the centre of the design.
- `memory/numa.md` — NUMA: non-uniform memory access, for engineers building LLM runners
  and allocators.
- `memory/unified-memory.md` — unified memory architectures: one pool, new physics — a
  synthesis dossier with a first-hand case study.
- `memory/virtual-memory-and-caches.md` — virtual memory, paging, and the cache / TLB
  hierarchy: the classical foundations.

### `aesir/` — the Project Aesir study (1)

Project Aesir study (OR-4). Aesir is ours, so it is read freely; it is written in Mojo
while Ollama is Go, so every idea is translated into Go/Ollama terms.

- `aesir/aesir-ideas-for-ollama.md` — Project Aesir ideas dossier for Ollama (OR-4):
  the first of the Aesir study files, dated 2026-11-15.

### `synthesis/` — synthesis (1)

- `synthesis/IDEA-LEDGER.md` — the ranked idea ledger handed to the Ollama build
  campaign: the cross-corpus ranking, its rejected/deferred list, and its open
  questions. **SIXTH CUT — 2026-11-15: 59 ranked ideas, 29 rejected/deferred,
  35 open questions.** New entries #57 (suspend-by-image), #58 (typed scheduler
  ownership), and #59 (single-flight shared prefill); the top five stand a fifth
  time. Living document: later dossiers and the build campaign's own
  measurements will re-rank it.

## Discipline

- Every claim carries its source and a date; the field moves fast, and a 2023 claim and a
  2026 claim are different animals.
- Other projects are studied clean-room: behaviour and ideas only, never lifted code or
  text. Each project's licence is recorded in its dossier.
- Reported numbers are always labelled with the hardware and conditions they were
  measured under. Our own measurements are labelled as ours.
- Speculation is marked as speculation.

## How this corpus is maintained

- Dossiers bank individually, as each one is finished and verified.
- The bibliography merges per wave, gathering the citations of the dossiers that landed
  in that wave.
- The compendia and the ledger are revised in dated cuts; each cut states its date and
  what it supersedes.
- Corrections are made in place, with a dated note at the point of correction — never
  silently.

*Started 2026-11-15. Status as of 2026-11-15: corpus banked — 134 files (~5.6 MB),
branch head `6ac985f`: field maps, 35 runner dossiers, 78 paper dossiers, the 15-file
memory corpus, the Aesir study, both compendia carrying sixth-cut amendments, the
idea ledger at its sixth cut (59 ideas / 29 rejected / 35 questions), and waves
banked through 33, plus the sweep-#3-entrant dossiers TokenSpeed/DeepInfer/Magnitude
and the ExLlamaV3 session pass.*
