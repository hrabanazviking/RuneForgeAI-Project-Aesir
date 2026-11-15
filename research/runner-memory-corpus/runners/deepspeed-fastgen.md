# DeepSpeed-FastGen / DeepSpeed-MII — Microsoft's Dynamic-Split Inference Line

## 1. Header

- **Names:** DeepSpeed-FastGen (the serving system and its release name); DeepSpeed-MII — "Model Implementations for Inference" (the serving library FastGen ships inside); DeepSpeed-Inference (the kernel / model-parallel engine underneath both); DeepSpeed-Kernels (the precompiled kernel wheel FastGen distributes through).
- **Owner / lineage:** Microsoft's DeepSpeed team. Lineage in one line: **DeepSpeed the training library** (ZeRO, 3D parallelism, mixed precision — the project's centre of gravity from 2020 onward) → **DeepSpeed-Inference** (2022: inference-optimised transformer kernels, tensor parallelism, quantisation, MoE inference) → **MII** (announced 10 October 2022 as a few-lines-of-code deployment layer over DeepSpeed-Inference) → **DeepSpeed-FastGen** (November 2023: MII rebuilt for LLM text generation around continuous batching, a blocked KV cache, and the new **Dynamic SplitFuse** scheduler; described by the DeepSpeed-Inference tutorial page, in the wording read for this dossier, as "DeepSpeed-Inference v2").
- **Licences — as verified from sources read on 2026-11-15:**
  - **DeepSpeed (main library): Apache-2.0.** Verified three ways from sources read: the PyPI listing states Apache Software License 2.0; the DeepSpeed project charter states that all outbound code is made available under Apache License 2.0 and that documentation is received and made available under Creative Commons Attribution 4.0 International; the charter also records the project's later governance home (LF Projects / PyTorch Foundation hosting — see §5).
  - **DeepSpeed-MII: Apache-2.0.** Verified from the MII README's Apache-2.0 licence badge (which links to the DeepSpeed LICENSE file) and from the GitHub API licence field for the repository (`apache-2.0` / SPDX `Apache-2.0`) surfaced in search results read for this dossier. MII contributions additionally require a Developer Certificate of Origin sign-off, per its README.
  - **DeepSpeed-Kernels: not separately verified.** The FastGen paper says the kernel binaries are distributed as a precompiled wheel through this library; the sources read describe it as open-source and "not intended to be an independent user package," but no licence text for that repository was read directly. Treat its licence as **unverified in this dossier**.
  - **Third-party kernels inside the stack:** the FastGen paper's acknowledgements state that the system extensively leverages FlashAttention kernels (with modifications, acknowledged in file headers) and FasterTransformer-derived kernels in its MoE path. Those components carry their own terms; they were not re-verified for this dossier.
- **Primary links (verbatim from sources read):**
  - Paper: https://arxiv.org/html/2401.08671v1 (PDF: https://arxiv.org/pdf/2401.08671) — arXiv:2401.08671, submitted 9 January 2024.
  - Release blog (November 2023, in the DeepSpeed repo): https://github.com/microsoft/DeepSpeed/tree/master/blogs/deepspeed-fastgen
  - January 2024 update blog: https://github.com/deepspeedai/DeepSpeed/tree/master/blogs/deepspeed-fastgen/2024-01-19
  - MII repository README (canonical raw form read): https://raw.githubusercontent.com/microsoft/DeepSpeed-MII/main/README.md
  - MII original announcement (10 October 2022): https://www.deepspeed.ai/2022/10/10/mii.html
  - PyPI release record used for dating: https://pypi.org/project/deepspeed-mii/0.2.0/
- **As of:** 2026-11-15. All claims below are tied to sources actually read on that date (§8); launch-era numbers are framed as launch-era numbers throughout.

**Essence.** DeepSpeed-FastGen is what happened when a training-framework team rebuilt its inference library for the LLM-serving race of late 2023: MII's deployment shell (an in-process pipeline or a persistent gRPC server, with replica load balancing) fused to DeepSpeed-Inference's kernels and tensor parallelism, with the whole system re-scheduled around one idea — **Dynamic SplitFuse**, a policy that composes every forward pass to the same target number of tokens, splitting long prompts across passes and fusing short prompts together to fill the budget exactly. The product did not win the serving market; the scheduling idea did, under the generic name "chunked prefill." This dossier exists to complete a pair: the corpus's Sarathi dossier (`papers/sarathi-serve.md`) covers the other independent invention of the same mechanism, and §2 records the priority question between them honestly, from the published dates and from FastGen's own citation of its rival.

---

## 2. The SplitFuse mechanism

### 2.1 The problem it answers

A text-generation request has two phases with opposite shapes. Prompt processing (prefill) runs the whole prompt through the model in parallel to build the KV cache: one long, compute-heavy forward pass. Token generation (decode) then runs one token per sequence per pass: short passes, memory-bound, individually inefficient. In the continuous-batching systems FastGen was measured against, the phases took turns badly — in the FastGen paper's framing, vLLM-style systems run either a generation pass or a prompt pass, so admitting a long prompt preempts every ongoing generation for the duration of that prompt's processing, and the perceived generation rate of every other client stutters; Orca-style systems run a whole prompt alongside generation, which avoids the preemption but makes that one pass arbitrarily long. Either way, pass duration — and therefore inter-token latency for everyone already generating — is hostage to the longest prompt anyone submits. This is the same prefill/decode interference problem the Sarathi line attacks; FastGen's diagnosis and prescription were developed in parallel (§2.4).

### 2.2 Three published observations the design rests on

The FastGen paper (§3.1 of arXiv:2401.08671v1) grounds SplitFuse in three empirical claims about forward passes, stated here in our own words:

1. **Token count is the pass's price tag.** For a given model, how long a forward pass takes is determined predominantly by how many tokens are in the pass — not by how many sequences those tokens belong to. A scheduler therefore needs only one signal to control: tokens per pass.
2. **Throughput saturates in tokens.** As tokens per pass grow, the model moves from a memory-bound region (throughput rising with token count, because each pass re-reads the weights for little arithmetic) into a compute-bound region where throughput flattens near its peak. Passes sized below the knee waste the weight reads; passes at or above it run at near-peak efficiency.
3. **Equal splits win.** The throughput-versus-tokens curve is concave, and for a concave curve, splitting a fixed pool of tokens evenly across passes yields at least as much total throughput as any uneven split. Uniform pass sizes are not just tidier; on the paper's argument they are the throughput-optimal way to consume a token pool.

### 2.3 The mechanism, in our own words

Dynamic SplitFuse is a **token-budget composition rule** applied at every forward pass:

- The scheduler holds a **target token budget** — a fixed number of tokens that each forward pass should contain — chosen so passes sit in the throughput-saturating region identified in observation 2.
- **Split (the long-prompt half).** A prompt longer than the remaining budget is not admitted whole. It is decomposed into smaller chunks, each chunk scheduled in a separate forward pass, spread across as many passes as the prompt needs. Only the pass carrying a prompt's final chunk produces that sequence's first generated token; the earlier chunks exist purely to extend its KV cache incrementally.
- **Fuse (the short-prompt half).** Short prompts are not run as small, inefficient passes. Multiple short prompts — together with the single decode tokens of sequences already generating — are composed into one pass that fills the target budget *exactly*. The paper is explicit that even a short prompt may itself be split so the budget is met precisely and pass sizes stay aligned.
- **Mixed passes, always.** Every pass is therefore a blend of prompt-chunk tokens and decode tokens at (near-)constant total size. There is no pure-prefill pass to stall decodes and no decode-only pass wasting the weight reads while prompt work waits.
- **Joining and leaving (the continuous-batching substrate).** SplitFuse sits on top of iteration-level scheduling with a blocked (non-contiguous) KV cache — the same substrate the paper credits to the Orca/vLLM generation of systems. Scheduling decisions are remade at every pass: a finished sequence leaves the batch at the next pass boundary and its place and cache blocks are reclaimed; a newly arrived request joins by contributing prompt chunks under the same budget rule. The "early exit" property is thus not a SplitFuse invention but a property of the continuous-batching loop SplitFuse composes within — recorded here because it is half of why the budget rule works: the population of generating sequences changes every pass, and exact-fill composition is what keeps pass size constant *despite* that churn.

The claimed consequences, in the paper's own framing: responsiveness improves because no single pass is ever very long, so more passes complete in any time window; efficiency improves because passes consistently run in the saturated region; and variance collapses because pass duration — the main determinant of generation cadence — is nearly constant, which is where the headline tail-latency number (§4) comes from.

### 2.4 What SplitFuse is not: the honest contrast with Sarathi

The two systems solve the same problem with the same core move — cut prefill into budget-sized pieces and mix the pieces with decodes — but the published formulations differ in ways worth keeping distinct, because a Go implementation will have to choose:

- **Currency.** Sarathi's published scheduler is built around a *chunk size* (tokens of prefill per hybrid batch) plus decode-maximal filling: one prefill chunk per batch, remaining slots filled with decodes. SplitFuse's currency is the *total tokens in the pass*, filled exactly from any mixture of sources — several prompts' chunks and many decodes in a single pass.
- **The fuse half has no Sarathi counterpart.** Sarathi splits; it does not fuse. Splitting a short prompt purely to align pass sizes, and packing several short prompts into one saturated pass, are SplitFuse-specific refinements aimed at the low end of the prompt-length distribution, where Sarathi-style chunking leaves passes under-filled.
- **Priority order.** Sarathi-Serve publishes an explicit fill order (running decodes first, then the in-progress prefill's continuation, then new admissions). **The FastGen paper publishes no equivalent priority algorithm** — it specifies the composition target (fixed-size mixed passes) and the two decomposition/composition behaviours, but not a decode-first admission order. Any claim that SplitFuse "prioritises decodes" in Sarathi's algorithmic sense goes beyond the published record read for this dossier; its latency guarantee is argued from bounded pass size, not from priority.
- **Numeric budget.** Sarathi's papers publish concrete budgets used in evaluation (the corpus's Sarathi dossier records 512 / 2,048). **The FastGen paper publishes no numeric token budget** — it gives the selection principle (operate in the saturating region; split evenly) without a number. Searches run for this dossier found no published SplitFuse budget figure. This is flagged again in §7 and in the unverifiables: steal FastGen's *method for choosing* the budget, not a value.

### 2.5 Priority: the record, without a winner declared

Both teams were Microsoft-affiliated but organisationally distinct — Sarathi from Microsoft Research India (with Georgia Tech), FastGen from the DeepSpeed product/research team — and the public record, as read for this dossier, is:

| Date | Event |
|---|---|
| 31 August 2023 | **SARATHI** preprint submitted to arXiv (arXiv:2308.16369v1, 31 Aug 2023 00:03 UTC per the submission history read): chunked prefills + decode-maximal batching, publicly described in full. |
| November 2023 (on or before 14 November) | **DeepSpeed-FastGen** publicly released: DeepSpeed's README news list dates the release blog to [2023/11]; the vLLM team's response post of 14 November 2023 already discusses it as recently published. Exact day not verified (see unverifiables). MII v0.1 ships Dynamic SplitFuse as a headline feature. |
| 9 January 2024 | **DeepSpeed-FastGen** paper submitted to arXiv (arXiv:2401.08671v1). Its reference [11] is the SARATHI preprint, and its §3.2 states, in substance, that a similar approach has been proposed in Sarathi, where prompts are split into smaller chunks to combine generation with prompt processing at consistent batch sizes. |
| 19 January 2024 | FastGen update (MII v0.2.0 on PyPI, dated 19 Jan 2024): Mixtral, Phi-2, Falcon support and further performance claims (§4). |
| 4 March 2024 | **Sarathi-Serve** preprint submitted (arXiv:2403.02310v1): the full stall-free scheduler with token budget τ, SLO framing, and pipeline-parallel results; later OSDI '24. |

What the record supports, stated plainly: **the first full public description of chunked prefill is SARATHI's August 2023 preprint; the first shipment of the mechanism inside a supported serving library is FastGen's November 2023 MII release; FastGen's own paper acknowledges Sarathi rather than claiming the idea ex nihilo; and the Sarathi line's complete scheduler formulation (Sarathi-Serve) was published after both.** Independent near-simultaneous invention by two teams in the same company, attacking the same well-known stall, is the honest summary. This dossier declares no winner beyond that record — and notes for the corpus's credit conventions that when later systems cite one ancestor, vLLM's current optimisation documentation cites *both* papers (arXiv:2401.08671 and arXiv:2308.16369) as the references for its chunked-prefill implementation, which is the fairest single summary of the shared parentage.

---

## 3. The rest of FastGen, as published

### 3.1 System shape

FastGen is explicitly a composition, not a new engine: **DeepSpeed-MII provides the front end** (user APIs, server, load balancing) and **DeepSpeed-Inference provides the back end** (the batch scheduler's host/device machinery, optimised kernel implementations, and the tools to build model implementations). Installation was a single PyPI package (`deepspeed-mii`) with the custom kernels arriving as the precompiled DeepSpeed-Kernels wheel — the paper states the wheel targets NVIDIA GPUs of compute capability 8.0+ (Ampere and later), CUDA 11.6+, Ubuntu 20+, precisely to spare users the long kernel compile times common in this space; manual compilation was documented for other environments.

At the November 2023 launch the supported model families were three: **LLaMA / LLaMA-2, Mistral, and Facebook OPT**, all sourced through Hugging Face weights and tokenisers. The January 2024 v0.2 update added **Falcon, Mixtral (MoE) 8×7B, Phi-2, and Qwen** in the update's own framing (the later README's supported-models table lists eight architectures including Qwen2, and quotes counts of "over 37,000 models" — a count of Hugging Face variants across those architectures, not of architectures; the v0.1-era text quoted over 20,000 across three architectures on the same counting basis). MII's *legacy* APIs (the pre-FastGen MII of 2022) separately claimed support for over 50,000 models across encoder/decoder/diffusion tasks — BERT, RoBERTa, Stable Diffusion, BLOOM, GPT-J and kin — a different, older surface that the FastGen line superseded for LLM text generation.

### 3.2 The two deployment modes (MII's duality)

FastGen inherited from MII the deployment duality that is, for this corpus, its second-most-stealable idea (§7):

- **Non-persistent pipeline.** The model is loaded inside the caller's own Python process via a pipeline call, exists only for the duration of that script or interactive session, and is explicitly destroyed to free resources. Positioned by the docs for experimentation, one-off inference, and embedding into batch jobs. Four lines of code in the README's example.
- **Persistent deployment.** A serve call stands up a long-running deployment behind a lightweight **gRPC** server; separate client objects (from any process) connect and generate concurrently. The persistent mode carries the production furniture: a built-in **load balancer** distributing requests across **model replicas**, **tensor parallelism** as a configuration knob (splitting one model across GPUs), an optional **RESTful API** gateway alongside gRPC, and shutdown issued from any client. Positioned for long-running and production applications.

An older MII distinction is worth recording for lineage completeness: the 2022 MII split deployments into **MII-Public** (the open-source DeepSpeed-Inference, on-premises or any cloud) and **MII-Azure** (a tighter Azure Machine Learning integration with a Microsoft-internal DeepSpeed variant, offered to Azure customers). By the FastGen era the public documentation leads with the non-persistent/persistent split instead; the Azure variant belongs to the earlier MII generation.

### 3.3 Continuous batching and KV cache — the implementation claims

As published, FastGen's serving loop claims: iteration-level (continuous) batching as the scheduling substrate; a **blocked KV cache** — the KV cache held in fixed-size blocks rather than per-sequence contiguous allocations, the same anti-fragmentation idea as PagedAttention, which the paper credits to vLLM's line of work while implementing its own version; **tensor parallelism** across GPUs for models that do not fit or need lower latency on one device; and replica-level load balancing (§3.2) as the scale-out story. The paper's scalability exhibit (§4) is a load-balancing result, not a single-node one — an honest marker of the intended deployment shape: fleets of replicas in a data centre, not a single workstation.

### 3.4 Kernel and fusion claims, in their original framing

FastGen's kernel story is inherited from DeepSpeed-Inference, whose published framing (2022 tutorials and the SC22 DeepSpeed-Inference paper, as read for this dossier) rests on:

- **Kernel injection:** at initialisation, compatible transformer layers in a PyTorch/Hugging Face model are replaced in place by DeepSpeed's fused implementations — presented as requiring no model-code changes for supported architectures, with an injection-policy mechanism for models supported only for model parallelism.
- **DeepFusion-style fusion:** the stated goal of fusing "all the kernels we can" — multi-operation fused kernels (for example GEMM+bias+activation combinations) plus optimised GEMM kernels — to cut launch overhead and memory traffic in the transformer block.
- **Quantisation:** inference in FP32/FP16/INT8, with INT8 weight quantisation via the project's **Mixture-of-Quantization (MoQ)** scheme, presented as shrinking the model and reducing serving cost.
- **MoE inference optimisations:** specialised gating/MLP paths and expert parallelism for sparse models, in the lineage of the DeepSpeed-MoE work that advertised trillion-parameter MoE inference; in FastGen proper, the MoE kernels are acknowledged as derived from NVIDIA's FasterTransformer kernels, and the attention path as built on modified FlashAttention kernels.
- The vLLM team's contemporaneous comparison table (an interested source, but a useful checklist of the launch-era claim surface) lists FastGen's custom LLaMA kernels as attention, RoPE, RMS norm, SiLU, and embedding — i.e., the standard fused set of its generation, no more exotic than its rivals'.

Nothing in the FastGen paper claims a new kernel as the source of its headline gains; the gains are attributed to scheduling (SplitFuse) on top of this inherited kernel base. That attribution discipline is itself worth noting: the paper sells a scheduler, not a kernel.

---

## 4. Reported results — as reported, launch-era vendor numbers

**Framing law for this whole section:** every number below is from the FastGen paper (arXiv:2401.08671v1, January 2024, whose text is the November 2023 release blog in paper form) or the January 2024 update, measured by the DeepSpeed team against the vLLM of late 2023 — a vLLM that did **not** yet ship chunked prefill. They are launch-era vendor numbers in their original frame and are not comparable to any modern engine. The contemporaneous rebuttal is recorded at the end of the section, because a dossier that prints only the claimant's numbers is advertising.

### 4.1 Headline claims

- **Up to 2.3× higher "effective throughput"** than vLLM (abstract and §4.3).
- **2× lower latency on average** (abstract).
- **Up to 3.7× lower (token-level) tail latency** — specified in the body as P95 generation latency (§3.2, §4.4).

### 4.2 What "effective throughput" meant in their frame

The 2.3× figure is not raw tokens/second. The paper defines an SLA framework for chat-like serving: a request counts as successfully served only if its prompt latency meets a rate SLA (prompt tokens ÷ 512 seconds, i.e. 512 tokens/second) **and** its generation rate, smoothed as an exponential moving average, meets 2, 4, or 6 tokens/second. "Effective throughput" is the throughput of SLA-meeting requests only. The metric is defensible — it prices the stalls SplitFuse exists to remove — but it is the claimant's own metric, constructed so that a system which stalls generations scores zero on stalled requests regardless of raw speed. Any reuse of the 2.3× figure without its definition is a misquote.

### 4.3 Method and hardware context

- **Baselines:** vLLM only, in the paper's main evaluation.
- **Models / hardware:** Llama-2 7B, 13B, and 70B across NVIDIA A100 (including 4× A100-80GB tensor-parallel for 70B), H100 (8× for 70B exhibits), and A6000 (7B exhibits).
- **Load shape:** 512 requests total, 1–32 concurrent clients; prompt and generation lengths drawn from normal distributions with means such as 2,600 prompt / 60 generation tokens (the effective-throughput exhibit), 1,200/128 and 2,600/60 (the throughput–latency exhibits), 30% variance. Note the shape: **long prompts, short generations** — precisely the regime SplitFuse targets.
- **Named data points:** on Llama-2 70B over 4× A100-80GB, FastGen is reported at up to 2× vLLM's throughput at identical latency (1.36 vs 0.67 requests/second at 9 seconds), or at up to 50% lower latency at identical throughput (7 vs 14 seconds at 1.2 requests/second). P50 generation latencies of the two systems are reported as similar; the 3.7× is a P95 effect, attributed to vLLM's generation-latency spikes when it preempts generation to process new prompts.
- **Load-balancing exhibit:** 16 replicas of Llama-2 70B (each replica tensor-parallel over 4 A100s; 8 nodes, 64 GPUs total in the setup as described) scaling from 1.46 queries/second (one replica) to 23.7 queries/second — presented as near-linear 16× scaling. This is a fleet result; it says nothing about single-machine serving.
- **January 2024 update frame:** the MII README's v0.2 text raises the headline to "**up to 2.5 times higher effective throughput** compared to leading systems such as vLLM" alongside the Mixtral/Phi-2/Falcon additions. Recorded here as the update's own claim, in its own frame, superseding the 2.3× in Microsoft's marketing while the paper's 2.3× remains the citable research figure.

### 4.4 The contemporaneous rebuttal (vLLM team, 14 November 2023)

The vLLM team answered within days of the November 2023 blog, benchmarking on a single A100-80GB with LLaMA-7B. Their claims, recorded as theirs: the SplitFuse advantage appears **only** when prompts are much longer than outputs; in their long-prompt/short-output scenario the observed gain was smaller than the claimed 2×; in other scenarios vLLM was up to **1.8× faster** than FastGen; FastGen's KV-cache allocation was characterised as conservative/suboptimal, wasting memory when output lengths are large; and the launch feature set was thin — three model architectures, EOS-only stopping (no stop strings), random sampling only (no parallel sampling / beam search), against vLLM's sixteen architectures and fuller sampling surface at that date. The rebuttal is itself a vendor document and is framed accordingly in this dossier; its narrow-regime finding, however, is consistent with the claimant's own workload choices in §4.3, and no source read for this dossier contradicts it.

---

## 5. What happened after

### 5.1 The product line went quiet; the parent went back to training

The public record read for this dossier shows FastGen's feature story ending where it began: the MII README's "Latest News" list stops at the January 2024 FastGen update, and the PyPI record shows deepspeed-mii 0.2.0 released 19 January 2024 as the FastGen-era release. No FastGen successor release, new model-family wave, or v0.3 appears in the sources read. (A full commit-by-commit audit of the MII repository was not performed; the claim here is about the *release and news record*, which is the record users adopt from.) Meanwhile the main DeepSpeed library continued on its original centre of gravity — training: its news list around and after FastGen is dominated by training work (ZeRO variants, offload, sequence parallelism), its releases continued through 2025–2026, and the project's governance moved outward from Microsoft alone — the DeepSpeed charter read for this dossier places the project under LF Projects, and a project-history source read records contribution to LF AI & Data in February 2025 and hosted-project status under the PyTorch Foundation from May 2025. The DeepSpeed-Inference tutorial page now introduces FastGen in the past-facing frame of a redirect ("DeepSpeed-Inference v2 is here and it's called DeepSpeed-FastGen!") — the wording of a landing page pointing at a release, not of a living product line. **Assessment (marked as this dossier's inference from the record above, not a published fact):** FastGen was a feature wave inside a training framework's release cycle; when the wave passed, the framework's attention returned to training, and the serving library was left at its January 2024 state.

### 5.2 The idea was absorbed everywhere

The mechanism's afterlife is the opposite of the product's:

- **vLLM** — the system FastGen benchmarked against, and whose team had replied that SplitFuse was "on vLLM's roadmap" — shipped chunked prefill, and in its current (V1-engine) documentation chunked prefill is **enabled by default whenever possible**, the scheduler prioritises decode requests and fills the remaining `max_num_batched_tokens` budget with (chunked) prefill, and the documentation's own related-papers pointers cite **both** arXiv:2308.16369 (Sarathi) and arXiv:2401.08671 (FastGen). The token budget became a first-class, user-facing tuning knob with hardware-dependent defaults.
- **The wider field** standardised on the pattern under the generic name: chunked prefill / stall-free scheduling is now a baseline expectation in production serving stacks (the corpus's vLLM, SGLang, and TensorRT-LLM dossiers record their respective implementations), and later scheduling research treats the token budget as the scheduler's basic currency.
- **OpenVINO kept the name.** Intel's OpenVINO GenAI continuous-batching scheduler implements the same split-and-fuse scheduling and calls it, verbatim, **Dynamic Split Fuse**: the OpenVINO Model Server documentation lists "Dynamic Split Fuse" alongside continuous batching and paged attention as a headline GenAI serving technique, exposes it as the `dynamic_split_fuse` scheduler option **enabled by default (true)**, and pairs it with a `max_num_batched_tokens` budget (default 256 in the Model Server configuration read). This corpus's OpenVINO dossier (`runners/openvino-genai.md`) documents that surface in full; the naming is a direct homage to — and the clearest surviving fingerprint of — the DeepSpeed-FastGen line, on hardware (Intel CPU/GPU/NPU) that FastGen itself never targeted. **This dossier closes that reference loop:** OpenVINO's term is DeepSpeed's coinage, for Sarathi-and-FastGen's shared mechanism.

### 5.3 Net trajectory

FastGen's arc, as public fact: a training framework fielded a genuinely competitive serving system for one release cycle (November 2023 – January 2024), contributed — jointly with the Sarathi line — the scheduling mechanism that became universal, and then ceded the serving field to dedicated serving projects (vLLM, SGLang, TensorRT-LLM) whose whole organisational attention is serving. The name survives in OpenVINO; the mechanism survives everywhere; the product survives as a maintained-in-name library whose README still advertises January 2024 as its latest news.

---

## 6. Strengths and weaknesses

### 6.1 Strengths

- **A one-knob scheduler with a principled setting method.** Reducing pass composition to a single signal (tokens per pass), with a published argument for why uniform passes are optimal (concavity) and where to set the budget (the saturation knee), is an unusually clean design artefact. It ports across models and hardware in a way multi-heuristic schedulers do not.
- **The fuse half.** Splitting long prompts was in the air in 2023; systematically *composing* short prompts and decodes to an exact budget — attacking under-filled passes as seriously as over-long ones — was FastGen's distinctive refinement, and it is the half most directly relevant to mixed real-world traffic.
- **Shipped, not just published.** Whatever the priority record (§2.5), FastGen put the mechanism into a supported, pip-installable library with servers, load balancing, and tensor parallelism within months — the form in which ideas actually get used.
- **Deployment duality done in a handful of lines.** Non-persistent embedding and persistent serving as two faces of one API (§3.2) remains a model of how to serve both the notebook and the fleet without forking the product.
- **Large-model credibility from the parent.** Tensor parallelism and kernels inherited from a team that routinely ran 100B+ models gave FastGen a top-end story (70B exhibits, Falcon-180B in the supported table) that younger serving projects took longer to match.

### 6.2 Weaknesses

- **A library feature inside a training framework — the adoption consequence.** FastGen's fate was decided by its home. Installing it meant adopting the DeepSpeed stack (with its kernel wheel constraints: Ampere-or-newer NVIDIA, CUDA/Ubuntu envelope); its release cadence, documentation, and roadmap were those of a training project for which serving was one initiative among many; and when the initiative's champions moved on, there was no serving-focused organisation to carry it. Dedicated serving projects — with serving as their entire identity, broader hardware ambitions, and faster model-support cycles — absorbed its best idea and its users. **The generalisable lesson for this corpus: a runner feature's survival depends on the survival incentives of the project that hosts it.**
- **Narrow winning regime, by its own evidence.** The headline gains live in long-prompt/short-output traffic (§4.3); the contemporaneous rebuttal found the advantage absent or reversed elsewhere (§4.4), and the paper's own P50 parity concedes the median request saw little difference. SplitFuse is a tail-latency and regime-specific throughput mechanism, not a universal speedup.
- **Thin serving surface at launch.** Three model families, EOS-only stopping, random-only sampling (§4.4) — the profile of a research release wearing a product's clothes. The January 2024 update widened models but the surface gap against dedicated servers was never closed in the record read.
- **Conservative memory behaviour.** The rebuttal's charge of suboptimal KV allocation (wasting memory on long outputs) was not answered in any source read; for a system whose pitch is occupancy, an unrebutted memory-efficiency charge matters.
- **Data-centre-only framing.** Every exhibit is A100/H100/A6000-class, multi-GPU or multi-node. Nothing in the FastGen record addresses single-user, consumer-GPU, CPU, or edge serving — the regimes this corpus's Go runner targets. Its ideas transfer (§7); its engineering evidence does not.
- **Underspecified scheduler.** The missing published priority order and missing numeric budget (§2.4) mean SplitFuse cannot be reimplemented from the paper alone with confidence that the result *is* SplitFuse; Sarathi-Serve's paper is the more complete specification of the shared mechanism. For a system whose contribution is a scheduler, that is a real scholarly and practical defect.

---

## 7. Ideas to steal for a Go runner

Context for all four: the corpus's idea ledger (`synthesis/IDEA-LEDGER.md`, entry #18) already carries chunked prefill sourced from Sarathi-Serve — cap new tokens per engine step, split long prefills across steps, yield and check cancellation between slices. This dossier's job is the second-source confirmation and the SplitFuse-specific deltas. Each idea below states what FastGen adds beyond the Sarathi entry, then gain and cost/risk.

### 7.1 Make the token budget the scheduler's *only* currency — and fill it exactly (the fuse half)

- **What FastGen adds:** Sarathi's formulation spends the budget on one prefill chunk plus decodes. SplitFuse generalises the fill: any mixture — several short prompts, parts of prompts, and all pending decodes — composed to hit the budget exactly, including splitting a short prompt solely for alignment. The budget is not a cap that work happens to fit under; it is a target that every pass is *composed to meet*.
- **Gain:** passes run at near-constant size, so inter-token latency variance collapses (the mechanism behind FastGen's P95 claim) and the accelerator stays in its saturating region even under short-prompt-heavy traffic — the common local case of many small chats, where pure chunking does nothing. In a Go runner this is a small, testable scheduler invariant: *every step's token count equals the budget, or the queue is empty.*
- **Cost / risk:** exact-fill composition complicates the attention bookkeeping — a step may contain fragments of many sequences at different prefix offsets, so position/mask correctness across fragments must be proven (the ledger's existing acceptance test applies: chunked vs whole-prompt logits must match exactly). It also spends scheduler effort to save accelerator idle time; on a single-user local workload with an empty queue most passes will be decode-only anyway, and the invariant buys nothing. Apply exact-fill only when a queue exists.

### 7.2 Choose the budget by profiling the saturation knee — FastGen's selection method, since it published no number

- **What FastGen adds:** a *method* where Sarathi gives values. Profile the target model on the target hardware: throughput rises with tokens-per-pass, then flattens; the budget belongs at the knee — the smallest pass size that reaches near-peak throughput — further bounded above by the inter-token latency the product promises. The concavity argument (§2.2) then justifies uniform passes at that size. FastGen published no numeric budget (§2.4), so there is no SplitFuse number to copy; Sarathi's 512–2,048 evaluation range (already in ledger #18) is the starting bracket, and the knee method is how a Go runner should localise it per model/device instead of hard-coding either paper's regime.
- **Gain:** one profiling run per (model, device) replaces a magic constant with a measured one, and the same profile doubles as the runner's honest capacity statement.
- **Cost / risk:** the knee moves with batch composition, KV pressure, and quantisation; a budget profiled on an idle machine mis-serves a loaded one. Mitigation is procedural: profile under representative concurrency, re-profile on model load (cheap, seconds), and expose the budget as the user-facing "maximum inter-token gap during ingestion" dial the ledger already specifies — not as a raw token count.

### 7.3 Deployment-mode duality as an explicit product decision: ephemeral library vs persistent daemon

- **What FastGen adds:** the cleanest published statement of the duality in the field. One engine, two lifecycles, chosen at the call site: **non-persistent** (in-process, model lives and dies with the embedding program — notebooks, batch jobs, tests, embedded features) and **persistent** (a daemon serving many clients, with replication and load balancing as daemon-only furniture). MII kept the two surfaces to a few lines each and shared everything underneath.
- **Gain for a Go runner:** Go is unusually well placed to honour both modes from one binary — a library import for embedding (the `ollama`-as-a-library use case that daemon-only designs serve badly) and a daemon mode for the shared local server — without a Python-style process split. Deciding the duality *up front*, as FastGen did, prevents the daemon's assumptions (global model registry, long-lived caches, port ownership) from leaking into the library surface.
- **Cost / risk:** two lifecycles means two shutdown stories, two cache-ownership stories, and a test matrix that covers both; the persistent mode's extras (client protocol, load balancing) are dead weight in library mode and must be genuinely optional, not stubbed. MII's own history warns about surface sprawl: its legacy API generation (MII-Public/Azure, 50,000-model claims) had to be quarantined as "legacy" when FastGen arrived. Keep the duality to exactly two modes.

### 7.4 Count only SLA-meeting requests: "effective throughput" as the local benchmark discipline

- **What FastGen adds:** a measurement ethic, not a mechanism. Raw tokens/second rewarded systems that stalled users; FastGen's effective-throughput definition (§4.2) counts a request only if its time-to-first-token rate and its generation rate both met stated SLAs. Whatever its self-serving edge in a vendor comparison, as a *local* discipline it is the right way for a Go runner to benchmark itself: publish the SLA pair (e.g. prompt-processing rate, minimum sustained generation rate) and report the fraction of a standard workload meeting both, alongside raw throughput.
- **Gain:** benchmarks that track what a user feels — no generation stalls hidden inside a good average — and a regression gate that catches scheduler changes which trade tails for means.
- **Cost / risk:** SLA parameters are choices, and a chosen SLA can be gamed exactly as FastGen's critics implied his was. Defence: fix the SLA pair in the test suite, version it, and never tune it to a result.

**Explicitly not stolen:** FastGen's kernel-injection architecture (a PyTorch-ecosystem answer with no Go analogue worth imitating), its gRPC-first client protocol (the local-runner field has settled on HTTP/OpenAI-shaped APIs), and its fleet load balancer (no fleet in the local product; revisit only if the Go runner grows a multi-replica server mode).

---

## 8. Sources

All sources accessed 2026-11-15 via web search and text fetch. Paper and documentation claims are from the sources themselves; the vLLM response is a contemporaneous interested-party document and is framed as such wherever used.

1. Holmes, Tanaka, Wyatt, Awan, Rasley, Rajbhandari, Aminabadi, Qin, Bakhtiari, Kurilenko, He — *DeepSpeed-FastGen: High-throughput Text Generation for LLMs via MII and DeepSpeed-Inference*, arXiv:2401.08671v1 (submitted 9 January 2024). Read in full HTML: https://arxiv.org/html/2401.08671v1 — mechanism (§3), evaluation (§4), implementation/deployment (§5), release and acknowledgements (§6). PDF record: https://arxiv.org/pdf/2401.08671
2. DeepSpeed-MII repository README (current main, read via raw form): https://raw.githubusercontent.com/microsoft/DeepSpeed-MII/main/README.md — licence badge (Apache-2.0), latest-news list (FastGen release [2023/11]; v0.2 update [2024/01] with Mixtral/Phi-2/Falcon), deployment modes, supported-models tables and counts, DCO note.
3. DeepSpeed-MII on PyPI, release 0.2.0 (file dated 19 January 2024): https://pypi.org/project/deepspeed-mii/0.2.0/ — v0.1/v0.2 feature framing, earlier supported-model counts; the 0.0.8 listing was also read for the 2022-era MII (MII-Public / MII-Azure split, legacy model support).
4. vLLM team — *Notes on vLLM v.s. DeepSpeed-FastGen*, 14 November 2023: https://vllm.ai/blog/2023-11-14-notes-vllm-vs-deepspeed — the contemporaneous rebuttal (§4.4) and launch-era feature/kernel comparison table.
5. Agrawal et al. — *SARATHI: Efficient LLM Inference by Piggybacking Decodes with Chunked Prefills*, arXiv:2308.16369v1, submitted 31 August 2023 (submission history and abstract read): http://arxiv.org/abs/2308.16369v1
6. Agrawal et al. — *Taming Throughput-Latency Tradeoff in LLM Inference with Sarathi-Serve*, arXiv:2403.02310 (v1 submitted 4 March 2024; v3 17 June 2024): https://arxiv.org/abs/2403.02310v3 — priority-record dating only; the mechanism is covered by this corpus's own dossier, `papers/sarathi-serve.md`.
7. OpenVINO Model Server documentation — *Efficient LLM Serving* (2025 doc set): https://docs.openvino.ai/2025/model-server/ovms_docs_llm_reference.html — "Dynamic Split Fuse" listed as a GenAI technique; `dynamic_split_fuse` option, default true; `max_num_batched_tokens` default 256. Corroborated inside this corpus by `runners/openvino-genai.md`.
8. vLLM documentation — *Optimization and Tuning* (V1 engine): https://docs.vllm.ai/en/v0.16.0/configuration/optimization/ — chunked prefill enabled by default in V1, decode-priority budget filling via `max_num_batched_tokens`, and related-papers pointers citing both arXiv:2401.08671 and arXiv:2308.16369.
9. DeepSpeed-Inference tutorial page: https://www.deepspeed.ai/tutorials/inference-tutorial/ — kernel injection, model parallelism, MoQ/INT8 framing, and the "DeepSpeed-Inference v2 is here and it's called DeepSpeed-FastGen" redirect wording.
10. DeepSpeed main repository README / PyPI news list (read via search results) — FastGen blog dated [2023/11], January 2024 update, surrounding training-focused news; DeepSpeed project charter (LF Projects) for the Apache-2.0 outbound-licence and CC-BY-4.0 documentation terms. Release-blog locations: https://github.com/microsoft/DeepSpeed/tree/master/blogs/deepspeed-fastgen and https://github.com/deepspeedai/DeepSpeed/tree/master/blogs/deepspeed-fastgen/2024-01-19
11. MII original announcement (10 October 2022), linked from the MII README: https://www.deepspeed.ai/2022/10/10/mii.html — lineage dating (announcement itself not separately fetched; date and existence verified through the README's link and news list).

### Unverifiables and gaps (recorded, not papered over)

- **No numeric SplitFuse token budget** was found in the FastGen paper or in targeted searches; §2.4 and §7.2 treat this as a genuine absence in the published record, not a missed detail.
- **Exact publication day of the November 2023 FastGen blog** was not verified; the record brackets it to on/before 14 November 2023 (vLLM's dated response) and the DeepSpeed news list's [2023/11].
- **DeepSpeed-Kernels' licence** was not directly verified (§1).
- **MII's post-2024 maintenance** is characterised from its README news list and PyPI release record, not from a full commit-history audit (§5.1).
- The January 2024 update blog's full text was characterised through the MII README's summary and the PyPI 0.2.0 record, not read line-by-line.
