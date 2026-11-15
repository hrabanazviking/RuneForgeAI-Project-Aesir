# OR-2 — PowerInfer and PowerInfer-2: Sparsity-Aware Hybrid Inference

> Ollama Research Forge dossier OR-2. Written in our own words from primary sources read on 2026-11-15. No code reproduced. Short factual labels (model names, numbers, hardware) are reported with their source context.

## 1. Header

| Field | Value (as verified 2026-11-15) |
|---|---|
| Name | PowerInfer (PC) and PowerInfer-2 (smartphone) |
| Origin | Institute of Parallel and Distributed Systems (IPADS), Shanghai Jiao Tong University |
| Paper 1 | Song, Mi, Xie & Chen, "PowerInfer: Fast Large Language Model Serving with a Consumer-grade GPU", SOSP '24 (ACM SIGOPS 30th Symposium on Operating Systems Principles, Austin, TX, 4–6 Nov 2024), DOI 10.1145/3694715.3695964; arXiv:2312.12456 (v1 16 Dec 2023, v2 12 Dec 2024). Note: the commissioning brief said "Zhang et al." — the byline on both arXiv and the SOSP proceedings is Song et al.; no Zhang author appears on this paper. |
| Paper 2 | Xue, Song, Mi, Zheng, Xia & Chen, "PowerInfer-2: Fast Large Language Model Inference on a Smartphone", arXiv:2406.06282 (v1 10 Jun 2024, v3 12 Dec 2024). No peer-reviewed venue is claimed on the arXiv record as read. |
| Code | Originally `SJTU-IPADS/PowerInfer` on GitHub; the README's current clone URL points to `Tiiny-AI/PowerInfer` (the project later commercialised under Tiiny AI). Both names resolve to the same project lineage as of the README read on 2026-11-15. |
| Licence | **MIT** — verified three ways on 2026-11-15: (a) the MIT badge in the repository README, (b) the README text and multiple independent catalogue listings describing the core engine as MIT-licensed. The raw `LICENSE` file itself was not fetched line-by-line in this pass, so the copyright holder line in that file is unverified; the licence *type* (MIT) is not in doubt. Model weights and predictors hosted on Hugging Face carry their own licences and are not covered by the engine's MIT licence. |
| Languages / implementation | C++ and CUDA core, built as an extension of llama.cpp / ggml (paper: ~4,200 added lines of C++/CUDA for the online engine, ~400 lines of Python on top of Hugging Face `transformers` for the offline profiler/solver). Later additions: ROCm/HIP for AMD GPUs (May 2024, per README news). PowerInfer-2 adds ~12,000 further lines of C++ on top of PowerInfer and runs on rooted Android. |
| Platforms (per README, 2026-11-15) | Linux and Windows on x86-64 with AVX2, with or without NVIDIA GPU; CPU-only on Apple silicon macOS (explicitly "not optimised", Metal backend listed as not done); multi-GPU listed as not done. |
| Model format | "PowerInfer GGUF" — a GGUF variant bundling the LLM weights together with per-layer predictor weights, plus a sidecar directory of profiled activation statistics used for fine-grained FFN offloading. INT4 (`Q4_0`) is the one optimised quantisation path documented. |
| Status note | Research prototype, self-described in the README as "Experimental and without warranties". Predictor *training* code is still listed as unreleased in the README TODO list as read on 2026-11-15 — a material reproducibility gap (see §7). |
| As of | 2026-11-15 |

**Essence.** PowerInfer starts from an empirical property of transformer feed-forward networks rather than from hardware: for a single token, most FFN neurons do nothing, and *which* neurons do nothing is both predictable per-token and heavily skewed across tokens — a small "hot" set fires for almost every input while a large "cold" set fires rarely and input-dependently. PowerInfer turns that statistical shape into a memory placement: hot neurons live permanently in VRAM and are computed on the GPU, cold neurons live in system RAM and are computed *in place* on the CPU, and a small learned predictor per layer decides, before the layer runs, which neurons are worth computing at all. The model therefore never needs to fit in VRAM, and — unlike layer-offload — its weights never cross PCIe during decode; only small activation vectors do. PowerInfer-2 carries the same bet to a phone, where the fast/slow pair is NPU/CPU and the slow tier below RAM is UFS flash, and the placement unit becomes a "neuron cluster" so that flash I/O can be pipelined at sub-matrix granularity.

---

## 2. The founding observation: activation sparsity and the hot/cold split

### 2.1 What a "neuron" means here

PowerInfer defines a neuron as one row (or the matching column) of a weight matrix. In an FFN block with two matrices (FC1/gate-up and FC2/down in the paper's notation), a hidden unit is "activated" for a token if its post-activation value is non-zero (for ReLU-family models) — equivalently, if its row of the first matrix and its column of the second matrix actually contribute to the output. Skipping an inactive neuron therefore skips both a row-read and a column-read, which is exactly the unit of memory traffic that dominates batch-1 decode. The same framing is applied, secondarily, to attention heads.

### 2.2 Per-token sparsity: most neurons are off

The background the paper builds on (DejaVu, Liu et al., ICML 2023, and the "lazy neuron" line of work) is that per-token FFN activation is sparse in ReLU models: the paper cites DejaVu's figure that roughly 80% of neurons in OPT-30B stay inactive during inference, and DejaVu's own OPT-175B measurements (as summarised in secondary sources read for this dossier) put prunable MLP neurons above 95% per token at no accuracy loss. PowerInfer's own evaluation table (its Table 3) reports average MLP sparsity — the share of neurons inactive per token — as follows:

| Model family (evaluation set) | Activation | Reported MLP sparsity |
|---|---|---|
| OPT 7B–175B | ReLU | 96–98% |
| Falcon-40B (ReLU version) | ReLU | 95% |
| Bamboo-7B | dReLU | 90% |
| LLaMA2 7B / 13B / 70B (ReGLU versions) | ReGLU | 70% / 78% / 82% |
| Yi-34B | SwiGLU | 53% |
| LLaMA2-13B (original) | SwiGLU | 43% |
| Qwen1.5-4B | SwiGLU | 40% |

Two different sparsity definitions are in play and a careful reader must not merge them. For ReLU-family models, sparsity is the fraction of *exact zeros*. For SwiGLU models there are almost no exact zeros, so the paper's Table 1 defines sparsity as the fraction of neurons that can be *dynamically pruned with less than 1% perplexity impact* — an approximate, thresholded notion. The 97% headline for OPT-30B (Table 1) and the 43–53% for SwiGLU models are therefore not measurements of the same quantity, even though they sit in the same table in the paper.

### 2.3 The power law: sparsity alone is not the insight, skew is

Sparsity by itself had already been exploited by DejaVu — but DejaVu assumed a data-centre GPU that holds the whole model, fetching activated neurons on demand. PowerInfer's additional, load-bearing measurement is the *distribution* of activation frequency across neurons:

- Method: profile activations over about 1M tokens from Wikipedia for the distribution plots (the offline profiler more generally uses general corpora such as C4 and Wikipedia), count per-neuron activation frequency, and plot the cumulative share.
- Result, per single MLP block: the neurons responsible for 80% of all activations are 26% of neurons in OPT-30B (ReLU), 43% in LLaMA2-70B converted to ReGLU, and 69% in LLaMA2-70B in its original SwiGLU form.
- Result, whole model: the corresponding shares are 17% (OPT-30B), 26% (ReGLU-70B) and 75% (SwiGLU-70B).
- Stability: the hot set is largely task-independent. Profiling across knowledge, truthfulness and reasoning task sets, the paper reports over 90% overlap in the top-20% most-activated neurons between domains, and per-layer plots for OPT-30B showing every layer carries a small hot core (its first 24 layers are extreme: under 1% of neurons active per token).

This skew is what converts "sparsity" into "locality" in the cache sense: a small working set (hot neurons) deserves the small fast store (VRAM), and the long tail can live in the large slow store (RAM) because any given token touches very little of it. Without the skew — if activations were uniformly random at the same average sparsity — placement would be worthless and only per-token skipping would remain.

### 2.4 The second insight: cold work is cheaper at home

The paper's Insight-2 is a small benchmark with large consequences: for the small activated sets typical of local decode (it tests 10% of an MLP block and 60% of an attention block of OPT-30B resident on the CPU side), *computing the neurons on the CPU where they already sit* is faster than copying their weights to an RTX 4090 and computing there, for all batch sizes under 32, using AVX2 CPU kernels. The reason is arithmetic: at batch 1 a neuron's weight is read once and used once, so the job is pure data movement; PCIe transfer of the weight costs more than the local RAM read plus a vector dot product. This is the exact opposite of the GPU-centric offload design (FlexGen-style, and DejaVu adapted with Unified Memory), where the paper measures over 99.5% of iteration time spent moving weights CPU→GPU. It is also different from llama.cpp-style layer offload, where whole layers sit on one side or the other: the paper's analysis of OPT-30B on a 24 GB RTX 4090 under layer offload has only ~37% of the model GPU-resident and ~98% of compute time landing on the CPU.

### 2.5 The caveat that governs everything: activation family

PowerInfer's gains scale with sparsity, and sparsity is a property of the *activation function and training*, not of transformers in general:

- **ReLU / ReGLU / Squared ReLU / dReLU models** produce exact zeros and 70–98% sparsity. These are PowerInfer's home turf — and, notably, they are mostly *not* the models vendors ship. OPT and the original Falcon are ReLU; mainstream LLaMA, Mistral, Qwen and Gemma releases are SwiGLU/GeGLU (SiLU-gated). The README's FAQ is blunt: only ReLU/ReGLU/Squared-ReLU models are supported in sparse mode; Mistral, original LLaMA and Qwen are explicitly listed as unsupported. The supported zoo is therefore a set of *converted* models (ReLUfied LLaMA-2, ProSparse LLaMA-2, ReLU Falcon-40B, Bamboo-7B) published by the PowerInfer/SparseLLM ecosystem itself.
- **SwiGLU/GELU models** show only "near-sparsity": gate outputs cluster near zero but rarely equal zero (the CATS paper's central observation). PowerInfer still runs them in a thresholded mode and reports 1.47×–1.7× speedups (see §6) — real, but an order of magnitude below the ReLU headlines, with the CPU becoming the bottleneck because roughly half the neurons remain live.

### 2.6 Follow-up work on sparsity in gated models (verified to exist)

Because the SwiGLU caveat is the idea's main threat, an ecosystem grew up specifically to manufacture or recover sparsity in gated models. All of the following were verified from sources read for this dossier:

- **DejaVu (Liu et al., ICML 2023)** — the predecessor: contextual sparsity exists in attention heads and MLP neurons, is predictable from earlier-layer inputs (adjacent-layer embeddings are highly similar due to residual connections), and can be exploited with asynchronous low-cost predictors. Data-centre setting, whole model on GPUs.
- **CATS — Contextually-Aware Thresholding for Sparsity (Lee et al., 2024; arXiv:2404.08763)** — training-free: calibrate a per-layer magnitude threshold on a small dataset, zero the SwiGLU gate activations below it, and skip the corresponding up/down rows. Reports ~50% MLP sparsity on Mistral-7B and LLaMA-2-7B with ~1.5% average downstream drop and no fine-tuning, and ~15% end-to-end generation latency improvement with custom kernels. Important for us: CATS needs *no learned predictor* — the gate projection itself, which must be computed anyway, is the predictor.
- **ProSparse (Song et al., 2024)** — ReLUfication done carefully: substitute ReLU for the gated activation, then apply progressive sparsity regularisation and activation-threshold shifting during continued training. Reports 89.32% sparsity for LLaMA2-7B and 88.80% for LLaMA2-13B at performance comparable to the SwiGLU originals. PowerInfer added ProSparse models to its supported zoo in March 2024.
- **TurboSparse (Song et al., 2024; arXiv:2406.05955)** — the PowerInfer team's own answer: a "dReLU" activation (ReLU applied on both branches of the gated unit, so a unit survives only if *both* its gate and up pre-activations are positive), plus a curated data mixture for the sparsification run (<150B tokens). Applied to Mistral-7B and Mixtral-8×7B: ~90% average FFN sparsity for TurboSparse-Mistral-7B (2.5B parameters active per token) and ~85% per expert FFN for TurboSparse-Mixtral-47B (4.3B active per token; the paper also describes overall MoE-layer activation falling to ~3% once expert routing and neuron sparsity compound). Reported 2–5× decoding speedups, and these are the models PowerInfer-2's phone headlines use.
- **"ReLU Strikes Back" / Squared ReLU line (cited within the PowerInfer paper as Zhang et al., 2024)** — evidence that retraining gated models with ReLU-family activations costs little quality, which the PowerInfer paper leans on when arguing its applicability will grow (it also points to newly *trained* ReLU-family models such as NVIDIA's Nemotron line).

Honest summary of §2: the founding observation is solid and multiply replicated *for ReLU-family FFNs*. For the SwiGLU models that dominate today's open-weights releases, exact sparsity does not exist; what exists is a heavy near-zero tail that can be thresholded at a quality price (CATS-style, ~50%) or trained-in at a retraining price (ProSparse/TurboSparse-style, ~90%). Any reuse of PowerInfer's design must state which of those three regimes it is in.

---

## 3. Architecture

PowerInfer is two systems: an offline pipeline that decides placement and trains predictors, and an online engine (a llama.cpp fork) that executes under those decisions. Neither half works without the other.

### 3.1 Offline: profiler

- A monitoring kernel is inserted after each block of each transformer layer and activation counts are accumulated per neuron while the model serves requests drawn from general corpora (C4, Wikipedia are named). The premise, backed by the >90% hot-set overlap measurement in §2.3, is that a general corpus is enough — the profiler deliberately does not need the user's actual workload, and predictor training likewise deliberately excluded downstream task datasets.
- Output: per-neuron activation frequencies for every layer, shipped alongside the model as activation-statistic files (one per layer in the Hugging Face repos) and used both by the placement solver and by the runtime's automatic FFN offloading.

### 3.2 Offline: placement solver (the policy)

Placement is per-neuron, not per-layer and not per-tensor — this is the sharpest structural difference from Ollama/llama.cpp `-ngl` offload.

- **Objective.** Each neuron gets an "impact" score defined, deliberately simply, as its profiled activation frequency. The solver maximises the total impact of the neurons placed on the GPU.
- **Constraints.** (a) Memory: summed neuron sizes on each device must fit that device's capacity. (b) Communication: a layer may only be split across GPU/CPU if the GPU side receives at least a minimum neuron count for that layer — derived from measured per-neuron compute time (modelled as weight size ÷ device bandwidth, since decode is bandwidth-bound) versus the measured fixed cost of one intra-layer CPU↔GPU synchronisation. Below that count, splitting costs more than it saves, so the layer goes entirely to one side (modelled with an auxiliary binary variable per layer). (c) Every neuron is placed exactly once.
- **Solving.** Formulated as integer linear programming, made tractable by grouping 64 neurons of similar impact within a layer into one placement batch — reducing millions of variables to tens of thousands and bringing solve time to roughly 10 seconds (paper's figure).
- **Effect.** In the paper's ablation (§6.4), replacing random placement with this policy is the single largest step for the big model: it is what balances GPU load against synchronisation cost instead of merely filling VRAM with nominally-hot neurons.

### 3.3 Online: adaptive sparsity predictors

Placement decides *where* a neuron lives; prediction decides *whether it runs at all* for this token.

- **Form.** Following DejaVu, each transformer layer carries two small predictors — one for the attention block, one for the MLP block — each a multi-layer perceptron with a single hidden layer, taking the block input and outputting a per-neuron (or per-head) activation forecast. Only predicted-active neurons are computed, on whichever device hosts them.
- **Why "adaptive".** Fixed-size DejaVu-style predictors do not fit the setting: the paper gives the example that fixed predictors for OPT-175B would need ~27 GB — more than an RTX 4090 holds. It also shows predictor accuracy is load-bearing: shrinking one model's predictors from 480 MB to 320 MB dropped prediction accuracy from 92% to 84% and Winogrande accuracy from 72.77% to 67.96%. PowerInfer therefore sizes each layer's predictor to that layer's measured sparsity and internal skew: sparse, skewed layers are easy to predict and get small predictors; dense, flat layers get larger ones. Sizing is iterative — start from the sparsity-implied size, adjust the hidden width until model perplexity on WikiText-2 with the predictor in the loop is within 0.1% of the dense baseline.
- **Resulting budget.** Predictors end up at ~5–9% of model parameters across the evaluated models (paper Table 6: OPT-13B 6.71%, OPT-66B 4.88%, Falcon-40B 8.68%, LLaMA-ReGLU-70B 8.08%; ~7.09% on average), resident on the GPU, and their runtime cost is under 10% of total inference time (paper's ablation). Per-layer prediction accuracy is reported above 95%.
- **Failure character.** Mispredictions are mostly harmless by construction: the neurons predictors miss tend to be ones whose contribution to the layer output is tiny. The paper quantifies this as ~0.4% cosine-similarity deviation between dense and predicted-sparse outputs on OPT-7B, and end-task accuracy deltas within noise on most benchmarks (§6.5). This is a *statistical* safety argument, not a bound — see §7.

### 3.4 Online: hybrid engine and neuron-aware operators

- **Execution model.** The engine builds the inference computation as a DAG in a host-side queue. Two executor thread pools (pthreads) pull ready operators: a GPU executor that launches kernels, and a CPU executor that spreads work over free cores and picks thread counts per operator. Dependencies crossing devices are handled with barriers; when a layer's activated neurons are split, both sides compute concurrently and the partial results are merged on the GPU (the GPU side is merged into, because it usually holds the majority of activated work).
- **Neuron tables.** Because a layer's neurons are now physically split, each side keeps an index table mapping its local neurons back to their original row/column positions, so the split computation reassembles into the correct output vector. Cost is trivial: ~9 MB of tables for OPT-175B in the paper's accounting.
- **Operators.** General sparse libraries (cuSPARSE and contemporaries) were rejected for a concrete reason: they want sparse-format conversion and per-nonzero indexing, which is pure overhead when the sparsity pattern changes every token. PowerInfer instead writes "neuron-aware" operators that work directly at row/column granularity: check the prediction bit for a neuron, and if active, do its vector–vector product in place. On the GPU each thread block owns a disjoint neuron set (no cross-block synchronisation or divergence); on the CPU the same operator batches neurons across cores and uses AVX2. The paper's microbenchmark (4,096×4,096 matrix–vector) claims the CPU operator beats dense multiplication at essentially all sparsity levels (dense only wins back below ~10% sparsity for conventional sparse libraries, which need >87% sparsity to break even), and the GPU operator roughly matches the specialised PIT compiler while also existing on the CPU side — the hybrid support being the actual point.
- **Prefill is treated differently.** When many prompt tokens are processed together, the union of their activations is nearly dense, so sparsity buys little. For long inputs PowerInfer falls back to dense GPU computation in the prompt phase and applies the sparse hybrid path in the generation phase, where batch-1 sparsity returns. The README's runtime description matches: dense blocks are offloaded to the GPU first, then the FFN is split if VRAM allows, under a single `--vram-budget` knob that replaces llama.cpp's `-ngl` in the sparse path.

### 3.5 I/O design (PC version)

PowerInfer's PC I/O design is mostly a refusal to do I/O:

- Cold weights are **not** streamed from disk or copied to the GPU at inference time. They are loaded once into system RAM at startup and computed there. The only per-token PCIe traffic is the input activation vector going to the CPU-side computation and the (model-width-sized) partial output coming back for the merge — kilobytes per layer, against megabytes-to-gigabytes of weights in a streaming design.
- The SSD plays no role in steady-state PC inference in the paper's design. (Flash as a live tier is PowerInfer-2's problem, §5.) This is a deliberate consequence of Insight-2: the moment cold weights must move to be computed, the design's advantage collapses, as the paper's own FlexGen/DejaVu-UM analysis shows.

---

## 4. Memory design

### 4.1 What lives where, and why

| Resident | Where | Why |
|---|---|---|
| Hot FFN (and hot attention) neurons | VRAM | They serve the large majority (~80%) of activations; VRAM bandwidth is spent only on work that is almost always needed. |
| Cold neurons (the bulk of parameters) | System RAM | Touched rarely per token; RAM capacity is plentiful (64–192 GB in the test PCs) and CPU compute in place avoids transfer. |
| Predictors (all layers) | VRAM | Invoked every layer, every token; latency-critical and small after adaptive sizing (~7% of model size). |
| Neuron index tables | Both (per-side tables) | Needed to reassemble split-layer outputs; negligible size. |
| KV cache | **System RAM** (in the paper's implementation, inherited from llama.cpp's default at the time) | Explicitly noted in the paper: leaving KV on the CPU side frees VRAM for hot neurons. This is a real trade — long contexts then pay CPU-side attention memory traffic — and it is a 2023-era llama.cpp inheritance, not a principled PowerInfer claim. A modern reimplementation should re-decide it (see §8). |
| Attention / "dense" blocks generally | GPU first (per README runtime behaviour) | Attention is dense per token; there is no sparsity win to split it by, beyond head-level prediction. |

### 4.2 The budget arithmetic, in the paper's own examples

The design only makes sense against concrete budgets:

- An OPT-66B at 4-bit still needs ~40 GB just for weights — over a 24 GB RTX 4090 and far over an 11 GB RTX 2080 Ti. Quantisation alone does not close the gap at this scale; placement is what closes it.
- OPT-30B on the 24 GB card under layer offload: ~37% resident. Under PowerInfer the same VRAM holds the hot core of *every* layer instead of *all* of 37% of layers, and the measured GPU share of activated-neuron compute rises from ~20% (llama.cpp) to ~70% on the high-end PC. When the model dwarfs VRAM (a ~60 GB model on the 11 GB card), the GPU share falls to ~42% — the solver cannot place hot neurons that do not fit, and the CPU absorbs the overflow. This graceful degradation, rather than a cliff, is a genuine property of per-neuron placement.
- Predictor tax must be paid out of the same VRAM: ~7% of model size on average. For a 70B FP16 model that is ~5.66B predictor parameters — itself a multi-GB resident that competes directly with hot neurons. Adaptive sizing is therefore not an optimisation detail; at small VRAM it is the difference between the scheme fitting and not fitting.
- Worked small-GPU translation [our arithmetic, from the paper's ratios]: a 7B model at INT4 is ~4 GB of weights. At 90% sparsity with the paper's whole-model hot shares (17–26% of neurons carrying 80% of activations), the hot core is on the order of 0.7–1.1 GB of weights, plus ~0.3 GB of predictors at the paper's ~7% ratio, plus KV and runtime — comfortably inside a 6 GB budget with room to spare. At SwiGLU-grade "sparsity" (~50% prunable, hot share ~70%+ by the paper's CDF), the hot core is ~3 GB and the win shrinks accordingly. The arithmetic works at 6 GB; the *speedup* is what varies with activation family.

### 4.3 Composition with quantisation

- PowerInfer is explicitly quantisation-compatible and evaluates INT4 (`Q4_0`) throughout: quantisation shrinks every tier (hot set, cold set, and therefore how much hot fits), and the sparse path's speedups persist in INT4 form (§6.2). The two techniques multiply rather than substitute: quantisation reduces bytes-per-neuron; sparsity reduces neurons-touched-per-token.
- One friction: predictor weights are an additional quantisation question the paper does not dwell on. [Speculation, marked as such: at 6 GB scale, storing predictors at FP16 while weights are INT4 would roughly double the predictor tax estimated above; a reimplementation should budget predictors in INT8/INT4 from the start and validate the accuracy sensitivity, which the paper's 480 MB→320 MB experiment suggests is real.]

### 4.4 Composition with KV caching

- Sparsity in PowerInfer is an FFN (and secondarily attention-head) phenomenon. It does nothing for KV-cache growth: cache size per token is unchanged, and in the reference implementation the cache sits in RAM, so long-context decode pays host-memory bandwidth for attention. The paper treats attention sparsity (head skipping, KV eviction lines such as H2O/InfiniGen) as orthogonal and composable, but does not implement it.
- Interaction worth noting for a reimplementation: because cold FFN work runs on the CPU, the CPU is already a loaded participant in every token. Adding CPU-resident KV attention on top competes for the same cores and the same RAM bandwidth. The paper's PC-Low results (weaker CPU, less RAM bandwidth: 38.4 GB/s vs 67.2 GB/s) show visibly smaller speedups, consistent with host-side contention being the scaling limit.

---

## 5. PowerInfer-2: the same idea at the phone tier

PowerInfer-2 (Xue et al., 2024) is not a port; it is a redesign forced by three measured differences between a phone and a PC, each documented in the paper:

1. **The sparse-compute gap.** A phone NPU (Qualcomm Hexagon in the test devices) is excellent at dense matrix work and poor at unstructured sparse work — the paper reports its own sparse primitives on the NPU running *slower* than on CPU, the reverse of the PC GPU situation. Mobile GPUs were measured slowest of the three for matrix–vector work and are also needed for rendering, so the design ignores them. Result: the fast/slow pair becomes **NPU (dense) / CPU (sparse)**, not GPU/CPU.
2. **Unified memory.** There is no VRAM; CPU and NPU share DRAM and its bandwidth. Measured on a OnePlus 12 with a 7B model: CPU-only matmul bandwidth 43.9 GB/s, NPU-only 56 GB/s, both together 59.6 GB/s — running both concurrently literally widens the memory pipe, which rewards hybrid execution beyond the compute split alone.
3. **UFS flash is a bad disk.** UFS 4.0 sequential reads reach ~4 GB/s only at large (512 KB) blocks and fall to ~450 MB/s at 4 KB; random reads are ~12× worse in IOPS than a PC NVMe drive, degrade as the read range grows, depend on which CPU core drives them (big core 1,076 MB/s vs little core 762 MB/s for 4 KB random reads in the paper's table), and UFS has a single command queue, so parallel I/O from multiple cores can *lose* up to 40%. When the authors put PC-style PowerInfer and LLMFlash on a phone with 50% of FFN weights offloaded to flash, decode collapsed (PowerInfer 12.4 → 1.4 tok/s; I/O was 81.9% of latency). The flash tier must be designed for, not mmap'd and hoped for.

### 5.1 The neuron cluster

The unit of everything — compute scheduling, caching, I/O — becomes a **neuron cluster**: a group of neurons from one FFN layer with similar activation behaviour, sized adaptively. Large, frequently-activated clusters are materialised as dense matrices for the NPU; small, rarely-activated clusters stay as individually-managed sparse units for the CPU. Clustering is what lets an NPU that cannot do sparse work still participate in a sparse model: it only ever sees the dense hot core, pre-packed.

### 5.2 The adaptive neuron engine

- **Prefill:** NPU-centric and dense. Prompt tokens jointly activate nearly everything (the paper notes activation probability approaching 99.99% at batch 128 for TurboSparse-Mixtral), so prediction is skipped, whole layers are read from flash with large sequential reads, a dedicated big CPU core prefetches the next layer while the NPU computes the current one, and I/O is reported fully hidden behind compute in the measured layers.
- **Decode:** hybrid. Attention heads are split across CPU and NPU. Each FFN matrix is split along the neuron dimension between NPU (hot clusters, dense matmul) and CPU (cold neurons, predictor-gated, ARM Neon kernels, chunked e.g. 512 rows at a time for parallelism). The split ratio is *dynamic*: it tracks effective batch size, because batching densifies activation (in the paper's Bamboo-7B layer-10 measurement, the highly-activated share rises from under 1% at batch 1 to ~75% at batch 32). At batch 1 the example FFN (14,336×4,096) is split 50/50; at larger batches the NPU share grows to ~70%. Ratio changes are implemented by swapping among pre-generated NPU graphs (each ~10 KB) loaded asynchronously during attention computation, so reconfiguration costs no stall.
- Predictors survive from PowerInfer, on the CPU side, gating cold-neuron computation (and, in the I/O path, cold-neuron *loading*).

### 5.3 Storage engine: cache, pipeline, loading

- **Segmented neuron cache (in DRAM).** Three regions: a fixed region (attention weights + KV cache, pinned), a hot region (clusters, managed as dense matrices, LRU at cluster granularity), and a cold region (individual neurons, LRU at neuron granularity). Eviction is free — weights are read-only, so evicted entries are simply dropped. The hot/cold region boundary itself moves with batch size. Reported cache hit rate in the ablation: ~95%, worth a 2.82× step.
- **Cluster-level I/O pipeline.** Instead of finishing one matrix before starting the next (which leaves cores idle whenever any cluster in the matrix is still in flash), the pipeline works cluster-by-cluster *across* matrices: a core that finishes a cluster immediately takes an in-memory cluster from the next matrix while the I/O thread fetches the missing ones. Each cluster's work is decomposed into five stages (predict → Gate I/O → Gate compute → Up/Down I/O → Up/Down compute) spread over compute threads plus one dedicated I/O thread. In the paper's critical-path breakdown this drops I/O's share of decode time from 76.7% (LLMFlash) to 13.7% (PowerInfer-2) on Bamboo-7B.
- **Differentiated loading.** Attention and hot weights: sequential reads, hot weights asynchronously preloaded during the preceding attention block (the planner sizes the hot set so this prefetch provably fits inside attention compute time at the device's I/O bandwidth). Cold weights: small random reads, but **bundled across matrices** — the Gate, Up and Down rows for the same neuron index co-activate ~80% of the time (while distinct cold neurons within one matrix co-activate <20% once hot neurons are removed), so storage is laid out by neuron index across the three matrices rather than by matrix. For FP16 a bundle is one 24 KB read; for INT4 the bundle is ~7.5 KB, padded to 8 KB and split into two 4 KB reads (measured faster on UFS), with a two-phase refinement: load Gate first, and only fetch Up/Down if the gate output is actually non-zero — declining to spend I/O on the ~20% of bundles that do not fully co-activate.
- **Offline planner.** Profiles activation across batch sizes 1–4 (and beyond) over 10M+ tokens (Wikipedia + RefinedWeb), profiles the specific device's NPU/CPU/bandwidth/UFS behaviour, and emits per-batch-size execution plans: cluster assignments, cache region ratios, NPU graphs, thread/core assignments. Device-specificity is a feature here, not an accident.

### 5.4 What PowerInfer-2 proves for desktop design

Even if phones are out of scope, PowerInfer-2 contributes three transferable results: (1) a *cache* with hot/cold regions and free eviction beats a static placement when a third tier (flash) exists; (2) sub-matrix pipelining, not matrix-level double-buffering, is what actually hides slow-tier latency; (3) batch size is a *sparsity variable*, and any static hot/cold policy is silently a batch-1 policy. All three apply directly to a 6 GB GPU + RAM + NVMe hierarchy.

---

## 6. Reported results — with hardware, model and era context

All numbers below are the authors' own, from the two papers (2023–2024 era, against the llama.cpp of that period). Baselines have moved since; treat speedups as evidence about the *mechanism*, not as current competitive standings. Batch size is 1 unless stated — the local-deployment regime both papers target.

### 6.1 Test hardware (PowerInfer)

- **PC-High:** Intel i9-13900K, 192 GB RAM (67.2 GB/s), NVIDIA RTX 4090 24 GB, PCIe 4.0 (~64 GB/s).
- **PC-Low:** Intel i7-12700K, 64 GB RAM (38.4 GB/s), NVIDIA RTX 2080 Ti 11 GB, PCIe 3.0 (~32 GB/s).
- Prompts sampled from Alpaca and ChatGPT-prompt collections, input lengths 8–128 for the main results; a separate long-input test uses 1.5K in / 256 out.

### 6.2 End-to-end, FP16 (PowerInfer vs llama.cpp)

- PC-High: average generation 8.32 tok/s across models, average speedup 7.23× over llama.cpp (6.19× over SpecInfer); maximum 11.69× on Falcon(ReLU)-40B. The README's demo headline — Falcon(ReLU)-40B FP16 at ~11× on the 4090 — is this configuration.
- PC-Low: average speedup 4.71×–5.97× depending on input length, peaking at ~7.1×–7.5×. Smaller VRAM → fewer hot neurons placed → more CPU work → smaller win. The gap between PC-High and PC-Low is itself a result: the design's ceiling is set by host CPU/RAM bandwidth once VRAM is exhausted.
- GPU share of activated-neuron compute: ~70% under PowerInfer vs ~20% under llama.cpp layer offload (PC-High average).
- Long inputs (1.5K/256): speedups 2.50× (LLaMA-ReGLU-70B) to 5.69× (Falcon-40B) — prefill is dense and merely matches llama.cpp; the win is earned back in decode.
- Short-output/long-prompt corner: with outputs under 8 tokens, gains shrink to 1.07×–4× — the workload is prefill-dominated and sparsity never gets to speak.

### 6.3 End-to-end, INT4 (PowerInfer vs llama.cpp)

- PC-High: average 13.20 tok/s, peak 29.08 tok/s; average speedup 2.89×, max 4.28×. Smaller than the FP16 speedups because quantised llama.cpp is a stronger baseline and the models fit "less badly" to begin with.
- PC-Low: average speedup 5.01×, peak 8.00× (the low-end card benefits most — consistent with the README's 2080 Ti chart claiming up to 8× on Falcon-40B INT4).
- OPT-175B INT4 on PC-High: just under 2 tok/s, 2.66× over llama.cpp. Reported as a capability proof (a 175B model served interactively-ish on one consumer card), not as a practical speed.

### 6.4 Ablations (what each piece is worth)

On Falcon-40B (PC-High) / Bamboo-7B (PC-Low), building up from llama.cpp:

1. Predictors + neuron-aware operators alone (still layer-wise placement): 3.32× / 1.87×.
2. Plus the hybrid intra-layer engine with *random* placement: 7.80× / 2.60×.
3. Plus the ILP placement policy (full PowerInfer): 11.69× / 3.62×.

Predictor overhead: <10% of inference time; predictor size ~7.09% of model parameters on average. Batch scaling (Falcon-40B, PC-High): average 6.08× for batch <32, still 4.38× at batch 32 — degrading exactly as the union-of-activations argument predicts, but not collapsing, because at batch 32 on a *single-user-serving* workload the comparison baseline suffers too. (Contrast PowerInfer-2's finding that activation itself densifies sharply with batch — the two are compatible: relative speedup can persist while absolute sparsity falls.)

### 6.5 Accuracy (PowerInfer)

Across PIQA, Winogrande, ARC-Challenge, MMLU and GSM8K, PowerInfer versions of OPT-7B/13B, LLaMA-ReGLU-13B/70B and Falcon-40B sit within ~1 point of their dense originals on the five-task average (e.g. Falcon-40B 56.23% dense vs 55.95% PowerInfer; LLaMA-ReGLU-13B 51.73% vs 50.79% is the largest average drop in the table). Individual cells move both directions, consistent with the "missed neurons are low-impact neurons" account and its ~0.4% output-deviation measurement. Caveat the paper itself flags in the repo FAQ, separate from prediction loss: the *ReLUfied 70B model itself* underperforms its SwiGLU ancestor because its conversion fine-tune used only ~5B tokens against a ~2T-token original pretrain. System accuracy and converted-model accuracy are different line items and must not be conflated.

### 6.6 Server-GPU comparison

OPT-30B generation on PC-High (RTX 4090 + PowerInfer) reaches 82% of vLLM on a single 80 GB A100 (input length 1); at input length 64 the gap widens (PowerInfer ~28–29% behind for OPT-30B/Falcon-40B) because prompt-phase processing weighs more. llama.cpp on the same 4090 trails the A100 by 92–93% in the same test. The honest reading: PowerInfer closes most, not all, of the consumer/server gap, for decode-heavy chat-shaped work, on ReLU models, in 2024.

### 6.7 SwiGLU models under PowerInfer (the control experiment)

Yi(SwiGLU)-34B on PC-High: 1.7 tok/s vs llama.cpp 1.0 (1.7×). LLaMA(SwiGLU)-2-13B on PC-Low: 3.1 vs 2.1 (1.5×). Against OPT-30B's 10.9× on the same PC-High table, this is the cleanest single exhibit of the activation-family caveat in the whole paper.

### 6.8 PowerInfer-2 results (phones)

Hardware: OnePlus 12 (Snapdragon 8 Gen 3, 24 GB DRAM / 19 GB usable, UFS 4.0) and OnePlus Ace 2 (Snapdragon 8+ Gen 1, 16 GB / 11 GB usable, UFS 3.1). Models: Mistral(SiLU)-7B, sparse Qwen2-7B, Bamboo-7B, sparse LLaMA-13B, TurboSparse-Mixtral-47B. Unless noted, 50% of FFN weights are offloaded to flash (75% for Mixtral on the Ace 2).

- **Decode:** OnePlus 12 — average 24.6× (max 27.8×) over llama.cpp, average 3.84× (max 4.63×) over the authors' reimplementation of LLMFlash. Ace 2 — 14.1× and 2.93× respectively. Headline: TurboSparse-Mixtral-47B at 11.68 tok/s with full memory available — billed, plausibly for its date (June 2024), as the first 47B-class model served on a phone.
- **Memory scaling (Mixtral-47B, OnePlus 12):** at only 7 GB available, 2.13 tok/s — the budget there is instructive: ~1 GB non-FFN weights, 2.6 GB predictor weights, 2.7 GB of INT4 *quantisation scales* for the FFN, 0.3 GB runtime, leaving 0.4 GB of neuron cache (1.8% of FFN weights). Speed then scales roughly linearly with memory to 11.68 tok/s at 19 GB. Two lessons hide in that budget: predictors and scales are first-class memory citizens at small budgets, and the pipeline keeps the system *functional* (2 tok/s) in a regime where the cache is nearly vestigial.
- **Prefill:** with 512-token prompts on OnePlus 12, up to ~49× over LLMFlash and ~44× over llama.cpp, ~2× over Qualcomm's QNN; in-memory prefill exceeds 700 tok/s, comparable to QNN. This is the NPU-dense + sequential-prefetch design working exactly as intended.
- **In-memory decode (Bamboo-7B):** 2.24× over llama.cpp, 2.48× over MLC-LLM, 1.86× over QNN; and with 50% FFN offloaded to flash it uses 1.5 GB (40%) less memory than the in-memory frameworks at comparable speed.
- **Ablation (Bamboo-7B decode, OnePlus 12, 50% offloaded):** CPU baseline 0.4 tok/s → +bundling 1.1 → +neuron cache (95% hit) ~4.2 (the paper prints both a 2.82× step and the 4.181 figure; the sequence is as reported) → +cluster pipeline ~9.6 → +XPU co-processing 11.07 tok/s. I/O's share of the critical path: 13.7% vs LLMFlash's 76.7%.
- **SiLU control (again):** Mistral(SiLU)-7B decode 5.3 tok/s vs LLMFlash 2.18 (2.4×), against Bamboo-7B's 4.6× over the same baseline — the family caveat reproduces on phones.
- **Energy:** 0.257 J/token vs QNN 0.373 and llama.cpp 0.672, at similar peak power (~5.1 W) — the saving is purely "finish sooner", not a lower power draw.
- **Latency spread:** task-level decode stays ≥11.4 tok/s across roleplay/dialogue/math/code for Mixtral-47B, but token-level P99 is ~41% slower than mean, driven by cache-miss variance (average miss 3.5%, P99 miss 18.9%). Sparsity systems have *jitter* as a native property; averages flatter them.

---

## 7. Strengths, weaknesses, and where the idea dies

### Strengths

- **It attacks the actual bottleneck.** Batch-1 decode is weight-bandwidth-bound. PowerInfer reduces *bytes touched per token* (skipping) and *bytes that must live in the fast tier* (placement) simultaneously — the two levers that matter — rather than only compressing bytes (quantisation) or only reordering them (paging).
- **No weight traffic in steady state (PC).** Computing cold neurons in place in RAM removes PCIe from the decode loop entirely, sidestepping the failure mode the paper measures in GPU-centric offload (>99.5% of time in transfers).
- **Per-neuron granularity degrades gracefully.** VRAM shortfall costs speed proportionally (70% → 42% GPU share) instead of causing OOM or thrash cliffs, and the same policy machinery spans an 11 GB and a 24 GB card unchanged.
- **Composability.** Orthogonal to quantisation (demonstrated INT4), to MoE routing (TurboSparse-Mixtral compounds both sparsities), and in principle to attention-side sparsity and speculative decoding (both noted as compatible, neither implemented).
- **The offline/online split is operationally sane.** Profiling and ILP solving happen once per model (~10 s solve; predictor training is the expensive part, below); the runtime artefact (PowerInfer GGUF + activation stats) is a single distributable package, and the runtime knob collapses to one VRAM budget.

### Weaknesses

- **The model zoo problem is existential, not incidental.** Sparse mode requires ReLU-family models. As of the README read on 2026-11-15 the supported list is Falcon-40B, LLaMA-2 (converted), ProSparse LLaMA-2, and Bamboo-7B; Mistral, stock LLaMA and Qwen are named as unsupported. Every headline number depends on converted models produced by a small research ecosystem, whose own quality caveat (5B-token conversion fine-tunes) is documented in the project's FAQ. A general-purpose runner cannot adopt PowerInfer whole; it can only adopt it *per-model-family*.
- **Predictor supply chain.** Predictors are per-model, per-layer trained artefacts; training takes "several hours" (paper, with multi-GPU speed-up suggested), and the README TODO still lists predictor training code as unreleased. In practice you can only run models whose predictors someone has published. This is the single largest practical barrier to reuse.
- **Predictor tax scales with the model, not with VRAM.** ~7% of parameters, GPU-resident, plus — in PowerInfer-2's 7 GB Mixtral budget — quantisation scales alone reaching 2.7 GB. On small-memory targets the auxiliary state can rival the hot set it exists to serve.
- **Accuracy safety is statistical.** The defence is "missed neurons are usually unimportant" plus benchmark deltas. There is no per-token guarantee, and the failure mode (a predictor systematically missing a neuron class that matters for an unusual input distribution — code-switching, rare languages, adversarial prompts) is exactly the kind that benchmark averages hide. The >90% cross-task hot-set overlap mitigates the *placement* half of this risk; the *prediction* half remains empirical.
- **Synchronisation is a fixed tax per split layer.** The ILP's minimum-split constraint exists because intra-layer CPU↔GPU merging costs real time on every layer, every token. On slower interconnects or with more, thinner layers, the tax grows relative to the win.

### Where the idea dies

- **Dense phases: prefill and large-batch serving.** Sparsity is a per-token property; the union over a prompt or a batch densifies rapidly (PowerInfer-2: highly-activated share <1% → ~75% from batch 1 to 32 in its measured layer; activation probability ~99.99% at batch 128). PowerInfer itself retreats to dense compute for prefill. In a throughput-oriented multi-user server (the vLLM regime), the design's premises invert: weights are amortised across the batch, compute binds instead of bandwidth, and per-token prediction becomes overhead. Both papers are explicit that the target is *low-latency, small-batch, local* serving; outside that regime, expect the advantage to shrink toward the SwiGLU-control numbers or below.
- **Truly dense models.** A model trained to be dense (or a SwiGLU model one refuses to threshold) gives the predictor nothing to skip and the solver nothing to exploit: the system degenerates into an awkwardly-split dense engine paying predictor and synchronisation taxes for nothing. The 1.5×–1.7× SwiGLU results are the *good* version of this failure, obtained with thresholded approximate sparsity at a small quality price.
- **CPU-poor hosts.** The cold side is not free storage; it is a co-processor. PC-Low's smaller gains, and PowerInfer-2's care in reserving big cores for I/O and compute, both show the design assuming a competent modern CPU with wide SIMD. On a weak host CPU the cold path becomes the critical path.
- **Very small models.** If the whole model already fits in VRAM with room for KV, placement is moot and only skipping remains — worth having, but the full PowerInfer machinery (ILP, tables, hybrid DAG) is a heavy price for it when a CATS-style gate-threshold kernel gets much of the same skip with no trained artefacts.

---

## 8. Ideas to steal for a 6 GB Go runner

Context for all estimates: a hypothetical improved-Ollama-class runner written in Go, targeting a single ~6 GB VRAM GPU, batch-1 interactive decode, GGUF-style INT4 models in the 7B–14B class (with occasional larger models via offload), host RAM plentiful, NVMe present. Gains are stated against a llama.cpp-style layer-offload (`-ngl`) baseline. Items are ordered by value-per-risk. Anything not directly supported by the sources above is marked [Speculation].

### 8.1 Tiered weight residency as an explicit policy (steal the solver, simplify it)

- **What:** Replace "N whole layers on GPU" with a residency policy computed at load time from (a) a per-tensor — or per-FFN-neuron-block — activation-frequency profile shipped as model metadata, and (b) the actual VRAM budget. Fill VRAM by impact-per-byte, subject to a minimum-chunk rule (do not split a matrix below the size where merge/sync cost eats the win — PowerInfer's communication constraint, restated).
- **Expected gain:** Even *without* prediction/skipping, hot-first placement of FFN blocks should recover a meaningful fraction of the placement step's value (in the paper's ablation, policy-over-random was worth ~1.5× on Falcon-40B on top of an already-hybrid engine; against naive layer offload the structural advantage is that every layer keeps its hot core on the GPU instead of 37% of layers being wholly resident). [Speculation: expect the practical effect at 6 GB to show up less as peak tok/s and more as the *size of model that stays interactive* — e.g. a 13B INT4 behaving like a resident model instead of a swapped one.]
- **Cost/risk:** Low engineering risk (a load-time knapsack/greedy pass in Go is a few hundred lines; no ILP solver needed — the paper's own grouping trick shows coarse batches suffice). The real cost is *profile data*: someone must profile each model once and ship the statistics. Mitigation: ship profiles for popular models as sidecar files, fall back to layer offload when absent. Risk of stale profiles is low given the measured cross-task stability of hot sets.

### 8.2 Sparsity-aware offload vs naive `-ngl` (steal the split direction)

- **What:** When a model does not fit, split *within* the FFN (hot rows/columns to GPU, cold to CPU, computed in place) rather than *between* layers. Keep attention and norms wholly on the GPU — they are small, dense, and latency-critical.
- **Expected gain:** This is the core PowerInfer mechanism; on ReLU-family models the paper's full-system numbers (up to 11.69× FP16, up to 8× INT4 on an 11 GB card) are the ceiling. On SwiGLU models with thresholded sparsity, budget for the control-group outcome: ~1.5×, not 10×. State this per-model in the UI/metadata rather than promising a global speedup.
- **Cost/risk:** High implementation cost in a Go runner — it requires neuron-granular kernels on both sides and a split-merge per layer per token, i.e. real GPU kernel work (via the runner's existing ggml/CUDA path, not pure Go). Synchronisation tax is per-layer and unforgiving on slow PCIe. Recommend prototyping on one ReLU-family model first to validate the ceiling before generalising.

### 8.3 Prefer gate-first / threshold prediction over learned predictors (steal CATS, not DejaVu)

- **What:** For SwiGLU models, use the gate projection — which must be computed anyway — as its own predictor: calibrate a per-layer magnitude threshold offline (CATS method), zero sub-threshold gate outputs, and skip the matching up/down work. For ReLU models, the activation itself is the predictor (exact zeros, zero cost, zero error).
- **Expected gain:** CATS reports ~50% MLP sparsity at ~1.5% quality cost with *no fine-tuning and no extra parameters*, translating to ~40% MLP-layer efficiency and ~15% end-to-end latency improvement with custom kernels in their setup. Combined with 8.1/8.2 placement, the skip also halves the cold-side traffic. [Speculation: in an offload setting the end-to-end effect should be larger than CATS's in-VRAM 15%, because skipped cold neurons are precisely the ones that would have consumed host bandwidth and CPU time.]
- **Cost/risk:** No predictor weights (saves the entire ~7% VRAM tax), no training pipeline, calibration is a small offline pass over a few thousand tokens. Risk is quality: threshold choice is a per-model, per-layer quality/speed dial and must be validated per model release, with a conservative default. This is the only prediction scheme in the dossier that is realistically shippable in Go without an ML training stack.

### 8.4 What a learned predictor would actually cost in Go (priced, and mostly rejected)

- **What it would take:** Per layer, a single-hidden-layer MLP from model width to FFN width. For a 7B-class model (32 layers, width 4,096, FFN 11,008) at the paper's ~7% parameter ratio, that is ~0.5B predictor parameters — ~0.5 GB at INT8, ~1 GB at FP16 — resident in a 6 GB budget, plus two small matmuls per layer per token on the critical path, plus a training pipeline (hours per model, per the paper) that a Go project does not otherwise need, plus distribution of per-model predictor files. Inference of the predictor itself is cheap in Go only if it rides the GPU; a CPU-side Go implementation would put dozens of small matmuls per token on the host critical path. [Speculation on the Go-specific costing; the parameter/VRAM figures follow the paper's ratios.]
- **Verdict:** Reject learned predictors for the 6 GB Go target except possibly in one narrow form: a *low-rank* gate approximator (predict the gate from a down-projected input), which later predictor research (e.g. the low-rank/SVD predictor line noted in §2.6 sources) suggests can be far smaller. Even then, 8.3's free gate-first signal should be exhausted first. The predictor is the part of PowerInfer that does not survive contact with a small-VRAM, no-training-pipeline product.

### 8.5 An LRU neuron cache for the flash/RAM tier (steal from PowerInfer-2)

- **What:** If the runner ever serves models larger than RAM (or wants RAM headroom back), adopt PowerInfer-2's three-region cache — pinned attention+KV region, hot region managed as dense blocks, cold region managed per-neuron-block with LRU — with eviction-by-dropping (weights are immutable), and lay the model file out *by neuron index across Gate/Up/Down* so one cold fetch brings the whole co-activated bundle.
- **Expected gain:** PowerInfer-2's cache step alone was worth 2.82× in its ablation (95% hit rate), and its two-phase Gate-then-Up/Down loading avoids ~20% of bundle I/O. On NVMe (faster and multi-queue, unlike UFS) the same layout should perform at least as well. [Speculation: the larger win on desktop may be *latency jitter reduction* — P99, not mean — since cache misses are what produced PowerInfer-2's 41% P99 penalty.]
- **Cost/risk:** Moderate: a cache manager and a file-layout converter. No model changes, no quality risk (caching is exact). This is the safest item in this section after 8.1.

### 8.6 Pipeline across matrices, not within them (steal the cluster pipeline)

- **What:** When any tier below RAM is in play, schedule fetch+compute at sub-matrix granularity and let compute for the next matrix's resident blocks overlap the current matrix's outstanding fetches — never barrier on a whole matrix.
- **Expected gain:** In PowerInfer-2 this is the difference between I/O being 76.7% and 13.7% of the critical path. On desktop the analogue is overlapping cold-neuron CPU compute with GPU work and with any NVMe prefetch, using the attention block's compute time as the prefetch window for the following FFN (PowerInfer-2 sizes its hot prefetch to fit exactly that window — steal the sizing rule too).
- **Cost/risk:** Concurrency engineering in Go (goroutine-per-stage with bounded queues maps naturally onto the paper's thread-per-stage design). Risk is complexity/deadlock surface, not correctness of results.

### 8.7 Dense prefill, sparse decode — as a mode switch, not a compromise

- **What:** Keep two execution modes and switch by phase and by observed batch size: dense (current engine) for prefill and for any batched serving; sparse-hybrid for batch-1 decode. Track effective sparsity at runtime (fraction of FFN work skipped) and fall back to dense if it drops below a threshold — PowerInfer-2's dynamic NPU/CPU ratio is the same idea in continuous form.
- **Expected gain:** Avoids the known failure corners (long-prompt/short-output at 1.07×, batch densification) instead of averaging them into every request.
- **Cost/risk:** Low; mostly policy code around kernels that 8.2 already requires. Also gives an honest telemetry signal ("this model/phase is running dense") that per-model marketing claims cannot.

### 8.8 Explicit non-goals (what not to steal)

- **Do not** ship converted/ReLUfied model variants as the runner's primary catalogue to chase the headline numbers; the conversion-quality caveat (5B-token fine-tunes) makes that a model-quality liability the runner would own.
- **Do not** put the KV cache in host RAM to save VRAM as a default (the reference implementation's inheritance, §4.1): at 6 GB with modern long contexts, KV placement deserves its own policy (GPU-resident with paged eviction to RAM), decided independently of FFN placement.
- **Do not** adopt per-neuron placement without the minimum-split constraint; a naive "fill VRAM with hottest rows" policy recreates the random-policy ablation and pays sync costs for layers that should never have been split.

---

## 9. Sources (all accessed 2026-11-15)

Primary:

1. Song, Mi, Xie & Chen — "PowerInfer: Fast Large Language Model Serving with a Consumer-grade GPU", SOSP '24 / arXiv:2312.12456v2 (HTML full text read in full for §§1–8). https://arxiv.org/html/2312.12456v2 — abstract record: https://arxiv.org/abs/2312.12456
2. Xue, Song, Mi, Zheng, Xia & Chen — "PowerInfer-2: Fast Large Language Model Inference on a Smartphone", arXiv:2406.06282v3 (HTML full text read for §§1–7). https://arxiv.org/html/2406.06282v3 — abstract record: https://arxiv.org/abs/2406.06282
3. PowerInfer repository README (raw, `main` branch as served 2026-11-15) — licence badge (MIT), supported models/platforms, PowerInfer GGUF format, `--vram-budget` interface, INT4 path, FAQ (activation-family support limits; ReLU 70B conversion-quality note), TODO list (predictor training code unreleased; Metal and multi-GPU not done), evaluation summaries for RTX 4090 and RTX 2080 Ti. https://raw.githubusercontent.com/SJTU-IPADS/PowerInfer/main/README.md

Follow-up / context (read via search results and abstracts/summaries as noted in §2.6):

4. Song et al. — "Turbo Sparse: Achieving LLM SOTA Performance with Minimal Activated Parameters", arXiv:2406.05955 (abstract, introduction and sparsity results read). https://arxiv.org/html/2406.05955
5. Song et al. — "ProSparse: Introducing and Enhancing Intrinsic Activation Sparsity within Large Language Models", arXiv:2402.13516 (abstract/results via search extract: 89.32% / 88.80% sparsity figures).
6. Lee et al. — "CATS: Contextually-Aware Thresholding for Sparsity in Large Language Models", arXiv:2404.08763; and the CATS project summary (Stanford Scaling Intelligence) — ~50% sparsity, ~1.5% downstream drop, ~15% end-to-end latency improvement. https://scalingintelligence.stanford.edu/blogs/cats.pdf
7. Liu et al. — "Deja Vu: Contextual Sparsity for Efficient LLMs at Inference Time", ICML 2023 (abstract and secondary summaries read).
8. PyTorch blog — "Beyond Quantization: Bringing Sparse Inference to PyTorch" (read 2026-11-15) — for the later predictor landscape (low-rank predictors, CATS/CETT thresholding) cited in §8.4.

Unverifiable / not verified in this pass (flagged honestly):

- The `LICENSE` file's copyright-holder line (licence type MIT is verified; the file itself was not opened line-by-line).
- PowerInfer-2 has no public code release that this pass could verify; all PowerInfer-2 claims rest on the paper alone.
- Post-2024 maintenance state of the original SJTU-IPADS repository versus the Tiiny-AI organisation (the README as served mixes both names; the project's later commercial releases noted in its news section were not investigated — out of scope for this dossier).
- All performance numbers are the authors' own measurements against 2023–2024 baselines; no independent replication was located or attempted in this pass.

*End of dossier OR-2.*
