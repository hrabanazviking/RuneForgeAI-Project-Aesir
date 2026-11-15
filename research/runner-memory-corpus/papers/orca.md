# Orca — Orca: A Distributed Serving System for Transformer-Based Generative Models

## 1. Full citation

- **Title:** Orca: A Distributed Serving System for Transformer-Based Generative Models
- **Authors:** Gyeong-In Yu, Joo Seong Jeong, Geon-Woo Kim, Soojeong Kim, Byung-Gon Chun
- **Affiliations (as listed by USENIX):** Seoul National University; FriendliAI
- **Venue / year:** 16th USENIX Symposium on Operating Systems Design and Implementation (OSDI '22), Carlsbad, CA, USA, 11–13 July 2022, pp. 521–538. ISBN 978-1-939133-28-1
- **Link:** https://www.usenix.org/conference/osdi22/presentation/yu (open-access proceedings page, including PDF and BibTeX)
- **arXiv:** none — Orca was published through USENIX only; there is no arXiv preprint. (Verified 2026-11-15: citation is via the USENIX proceedings record.)

## 2. The problem it attacks

Transformer generation is iterative: a request needs one model execution per output token, and different requests need very different numbers of iterations. Request-level (static) batching locks a batch together until its slowest member finishes, so requests that finish early cannot return to their clients and newly arrived requests cannot join — GPU slots sit idle inside a half-empty batch. Existing inference servers of the time (built for single-pass models) had no scheduling unit smaller than a whole request, which is exactly the wrong granularity for autoregressive generation.

## 3. Core idea in our own words

Schedule at the iteration, not at the request. The scheduler hands the execution engine a batch, asks it to run **exactly one iteration** (one new token for each sequence in the batch), takes control back, and immediately re-decides the batch: finished sequences leave and return to their clients at once, waiting requests join at once. Batch membership becomes a per-token decision. This is the technique the field now usually calls **continuous batching** or in-flight batching; the paper's own term is **iteration-level scheduling**.

The companion mechanism is **selective batching**. In a Transformer, most operations (linear projections, layer norms, MLPs) are position-wise and can be batched across sequences of different lengths and phases, but attention operates over each sequence's own variable-length history and cannot be naively batched the same way. Orca batches the position-wise operations across the whole mixed batch and processes the attention operations per sequence, so a batch may freely mix requests that are in prefill (processing a prompt) with requests that are mid-decode.

## 4. Key design details a runner engineer needs

- **Control loop:** scheduler → engine runs one iteration → scheduler retires finished requests, admits new ones, subject to a cap on concurrent requests (the real memory governor, since KV footprint scales with live sequences).
- **Selective batching split:** batch everything that is token-wise independent; keep attention per-sequence. Any reimplementation needs kernels / data layouts that tolerate ragged sequence lengths inside one step.
- **KV handling:** Orca manages per-request KV state across iterations (requests persist in the system between steps), but it allocates KV in the conventional contiguous style — the fragmentation problem PagedAttention later solved. The two techniques are complementary and modern stacks use both.
- **Distributed design:** the system is built to scale to models with hundreds of billions of parameters, combining intra-layer (tensor) and inter-layer (pipeline) parallelism with the iteration-level scheduler, plus a scheduling policy that accounts for distributed execution.
- **Where it hooks in:** entirely in the serving layer — request admission, batch formation, and the step loop. No model changes.

## 5. Reported results — as reported, with context

- **Headline (USENIX abstract, paper's own claim):** on a **GPT-3 175B** model, Orca **significantly outperforms NVIDIA FasterTransformer in both latency and throughput, with a 36.9× throughput improvement at the same level of latency**.
- The 36.9× figure is a peak / operating-point comparison against a static-batching baseline under variable-length generation load — it measures how badly request-level batching wastes capacity when output lengths vary, not a kernel speedup. Secondary summaries of the paper report the same 36.9× figure in connection with large GPT-3-class evaluations; the verifiable primary claim is the GPT-3 175B result above.
- Baseline named throughout: NVIDIA FasterTransformer (the state-of-the-art static-batching serving library at the time).

## 6. Limitations / what it does not solve

- No KV-cache memory management advance: contiguous allocation still fragments and still caps concurrency (fixed a year later by PagedAttention / vLLM, which explicitly builds on Orca's scheduling).
- Iteration-level admission can still head-of-line block on memory: a new long request waits if live sequences hold the KV budget.
- The paper predates prefix caching, structured generation, and speculative decoding; none are addressed.
- The system was not open-sourced by its authors; the ideas entered practice through reimplementations (vLLM, TGI, TensorRT-LLM and successors).
- Evaluation is datacentre-scale (GPT-3 175B-class serving). It says nothing directly about single-request latency on small hardware, where there is no queue to smooth.

## 7. Applicability

### (a) Ollama on a 6 GB consumer GPU running long character chats

- Honest scope first: with one user and usually one active generation, there is no batch to continuously refill, so Orca's throughput result does not transfer. Do not cite 36.9× in any Ollama context.
- What *does* transfer is the step-loop shape: run one token, then re-decide. That loop is the natural place to (i) stream the token to the client immediately, (ii) check stop conditions / user interrupt between tokens rather than at request end, and (iii) interleave a second lightweight job (e.g. a background summarisation or a second character's turn in a group chat) without waiting for the first to finish.
- Selective batching matters if Ollama ever serves a character chat *plus* side calls (embeddings for memory recall, a classifier, a second persona) on the same GPU: batch the shared position-wise work, keep attention separate per sequence.
- The concurrency cap lesson also transfers in miniature: bound live sequences by KV bytes, not by request count.

### (b) Project Aesir (Mojo runner — sessions, prefix memory, hybrid SSM models)

- Aesir's session engine should be an iteration-level scheduler from day one: sessions join, pause, resume, and retire per token step, never per request. That is what makes multi-character scenes, interrupted generations, and background sessions composable in one runner.
- Selective batching generalises to hybrid models: batch the per-token dense work across sessions; keep per-session stateful work (attention over that session's KV, SSM recurrent update) separate and state-owned. The split line Orca drew inside the Transformer is the same split Aesir needs between stateless and stateful ops.
- Pair this dossier with PagedAttention: Orca supplies Aesir's scheduling granularity, vLLM supplies its memory granularity. Neither alone is a complete serving design.
- For SSM layers there is no KV growth, so the memory cap that throttles admission in Orca becomes, for hybrid models, a mixed budget: paged KV bytes for attention layers + fixed state bytes per live session. The scheduler should account both.

## 8. Access

- Date accessed: **2026-11-15**
- USENIX proceedings page (abstract, PDF, BibTeX): https://www.usenix.org/conference/osdi22/presentation/yu
- Note: no arXiv version exists; cite the USENIX record.
