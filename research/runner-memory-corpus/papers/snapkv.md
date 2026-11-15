# SnapKV — SnapKV: LLM Knows What You are Looking for Before Generation

## 1. Full citation

- **Title:** SnapKV: LLM Knows What You are Looking for Before Generation
- **Authors:** Yuhong Li, Yingbing Huang, Bowen Yang, Bharat Venkitesh, Acyr Locatelli, Hanchen Ye, Tianle Cai, Patrick Lewis, Deming Chen
- **Affiliations (as listed in the paper):** University of Illinois Urbana-Champaign; Cohere; Princeton University
- **Venue / year:** Advances in Neural Information Processing Systems 37 (NeurIPS 2024), pp. 22947–22970
- **arXiv:** arXiv:2404.14469 [cs.CL] — v1 22 April 2024; v2 17 June 2024 — https://arxiv.org/abs/2404.14469
- **Proceedings record:** https://proceedings.neurips.cc/paper_files/paper/2024/hash/28ab418242603e0f7323e54185d19bde-Abstract-Conference.html

## 2. The problem it attacks

In real deployments — chatbots, agents, RAG — the *prompt* is the long part and the generation is comparatively short, yet the prompt's KV cache is what decoding must drag through memory at every step: per-token decode latency grows linearly with prompt length and the cache itself caps how long a prompt can be served at all. Prior eviction work (H2O, StreamingLLM, Scissorhands, FastGen) mostly compresses the tokens *appended during generation* and was lightly evaluated on long prompts. SnapKV targets the neglected half: compress the **prompt's** KV cache, once, before generation begins — if, and only if, you can know in advance which prompt tokens generation will actually need.

## 3. Core idea in our own words

The paper's empirical claim, tested on UltraChat dialogues (prompts > 3K, responses > 512 tokens), is that you *can* know: **each attention head's allocation over prompt positions is consistent throughout generation, and that allocation is already visible from the prompt itself.** Specifically, if you take the last window of the prompt — the **observation window** — and look at where *its* queries attend in the preceding prefix, the high-attention positions overlap heavily with the positions generation will later treat as important, in every layer, and the pattern persists across generation windows. The model, in the title's phrase, knows what you are looking for before generation.

SnapKV turns that into a one-shot compression at the end of prefill:

1. **Vote.** For each head separately, sum the attention weights from the observation window's queries over all prefix positions. The summed score is each prefix position's predicted importance *for that head*.
2. **Cluster.** Apply 1D max-pooling over the vote sequence before selecting, so selection favours *neighbourhoods* of important tokens rather than isolated spikes (see §4 for why this matters).
3. **Select and rebuild.** Keep the top-k prefix positions per head (k set by the target cache capacity), plus **all** observation-window KVs unconditionally. The concatenation [selected prefix; observation window] is the entire prompt cache for generation; everything else is discarded before the first generated token. The prompt cache size is then constant no matter how long the prompt was.

It is fine-tuning-free, needs no calibration, and is a per-head decision — different heads keep different tokens, which matches the observation that heads specialise.

## 4. Key design details a runner engineer needs

- **Where it hooks in:** exactly once, at the prefill→decode boundary. Prefill itself is untouched and full-cost: SnapKV does not reduce time-to-first-token or the peak memory of prefill (see Limitations). After the snap, decode attends only to the compressed cache plus newly generated tokens, which append normally.
- **Hyperparameters (paper's settings):** observation window 32 and pooling kernel 7 for the LongBench suite; window 16 and kernel 5 for the LWM Needle-in-a-Haystack pressure test (cache capacity 1024); window 64 and kernel 13 for Command-R (capacity 4096). Window and kernel are model/task-tunable, not universal constants.
- **Why pooling is not decoration:** naive top-k keeps isolated high-attention tokens and severs the local context that induction heads copy from — the paper's example is retrieving a phone number's country code and hallucinating the rest. The ablation on LongEval-Lines (Mistral-7B-Instruct-v0.2, kernel 5, window 16) shows the pooled variant retrieving correctly out to ~16K inputs where the unpooled variant fails much earlier. Max- vs average-pooling made no significant difference.
- **The selection is instruction-sensitive — by design and by risk.** The paper's hit-rate analysis shows different instructions over the *same* document select different prefix features (hit rates between instruction variants fall), and that selection quality is invariant to whether the instruction sits before or after the context. SnapKV therefore works because the instruction is normally inside or beside the observation window at the prompt's end. A prompt whose tail does not express the eventual task gives the voter the wrong ballot.
- **Per-head storage consequence:** after the snap, each head's cache has different *positions* in it. In a paged/block cache this means per-head gather lists — the cache is no longer a simple shared row range across heads. Budget the cache-manager complexity accordingly (this is the same integration shape PyramidKV inherits).

## 5. Reported results — as reported, with context

All figures are the paper's own measurements.

- **Decode speed and capacity (LWM-Text-Chat-1M, 7B, single A100-80GB, HuggingFace implementation, generation length fixed at 512, SnapKV capacity 2048):** at 16K input tokens and batch size 2, baseline decode latency exceeds 100 ms/token vs below 40 ms/token with SnapKV — the **~3.6× generation speedup** of the abstract; at the same batch size the baseline OOMs beyond 16K input while SnapKV reaches 131K — the **8.2× memory-efficiency** figure. Decode latency stays flat as input length grows because the prompt cache size is fixed.
- **Needle-in-a-Haystack pressure test (same model/GPU, capacity 1024, window 16, kernel 5):** SnapKV processes up to **380K context tokens on the single A100-80GB** with what the paper reports as negligible accuracy drop; the unmodified implementation OOMs at 33K. The paper frames this operating point as a 380× compression ratio (380K tokens of prompt served from a 1024-entry cache).
- **LongBench quality (16 datasets; models LWM-Text-Chat-1M, LongChat-7b-v1.5-32k, Mistral-7B-Instruct-v0.2, Mixtral-8x7B-Instruct-v0.1; mean input ~13K tokens; window 32, kernel 7):** prompt caches of 1024 / 2048 / 4096 entries correspond to ~92% / ~84% / ~68% compression at that mean length, with what the table shows as small, task-dependent deltas vs full KV. Example (Mistral-7B-Instruct-v0.2, HotpotQA): full KV 42.77 → SnapKV-1024 40.94 → SnapKV-4096 42.32, vs H2O at capacity 4096 scoring 36.54; the paper notes SnapKV-1024 beats H2O-4096 on 11 of 16 datasets for Mistral. The weak spot is summarisation of long single documents: LWM-Text-Chat-1M GovReport falls from 27.97 (full) to 19.79 (SnapKV-1024), recovering only to 25.34 at 4096.
- **Command-R (35B, 128K context; capacity 4096, window 64, kernel 13):** modified Needle-in-a-Haystack score 9.866 (baseline) vs 9.819 (SnapKV), −0.5%, at up to 32× compression at 128K; Cohere-internal RAG benchmarks: citation F1 −1.2%, end-to-end F1 −2.1% at 5–10× compression over 20K–40K-token contexts.
- **Composition with speculative decoding:** SnapKV + Medusa on Mistral-7B-Instruct-v0.2 (Qasper prompts) gives 1.3× over Medusa alone and 2.2× over native decoding at 10K prompt length — the fixed-size prompt cache removes the long-prompt tiling bottleneck that slows tree verification.

## 6. Limitations / what it does not solve

- **Prefill is untouched (authors' own §6).** SnapKV cannot ingest a prompt that does not fit for prefill in the first place, does not cut time-to-first-token, and cannot extend a model that is intrinsically weak at long contexts — it preserves access to a prompt the model already processed, nothing more.
- **One-shot and irreversible.** The snap happens before generation with no mechanism to recover a discarded token if generation pivots — a follow-up question about a discarded passage, a topic change mid-chat, an instruction that only emerges in turn three. The paper's setting is single-turn long-prompt QA/RAG, where the task is fully expressed in the prompt; multi-turn chat violates that assumption structurally (see §7a).
- **Vote quality depends on the tail.** If the prompt's final window is boilerplate, a system suffix, or an unrelated last document in a RAG pack, the observation window votes for the wrong prefix. The paper shows robustness to instruction *position*, but the vote is still computed from the last window only.
- Summarisation-style tasks that genuinely need broad coverage (GovReport numbers above) degrade more than retrieval/QA — compression by importance is biased toward tasks whose answers live in a few places.
- Headline efficiency numbers come from a HuggingFace baseline implementation on one model; against an already-optimised server (paged cache, fused attention) the 3.6×/8.2× should be read as "the effect of a constant-size prompt cache", not as a promised multiplier over production stacks.

## 7. Applicability

### (a) Ollama on a 6 GB consumer GPU

- **Runtime policy, retrofittable to any existing GGUF model** — no training, no calibration, no weight changes. The work is in the runner: materialise (or accumulate) the observation window's attention over the prefix at end of prefill, pool, select per head, and rebuild the cache as [selected; window]. On fused-attention stacks the voting pass is the integration cost, as with H2O — it needs the last window's attention weights, which flash-style kernels do not normally emit.
- **Fit to the 6 GB chat workload is partial, and honesty matters here.** SnapKV's home ground is the *long static prompt*: a big character card + world book + pasted document, questioned once. There it is close to free memory — a 13K-token prompt served from a 1–2K cache. But an ongoing character chat is not a static prompt: the "prompt" grows every turn and the important tokens change with the conversation. Snapping once at session start freezes a judgement made by the opening exchange about the whole future conversation. The safe chat adaptation is to snap *per turn* over the accumulated history (re-vote with the latest user message as the observation window) and to always pin the persona/system block outside the vote — i.e. use SnapKV as a history-compaction step between turns, not as a one-time gate at prefill. That adaptation is ours, not the paper's, and needs its own quality testing.
- Combined arithmetic: SnapKV (fewer tokens) × KIVI/KVQuant (cheaper tokens) × StreamingLLM pinning (protected head) is the full small-card stack; the three compose because they act on different axes (selection, precision, eviction floor).

### (b) Project Aesir (Mojo runner — sessions, prefix memory, hybrid SSM models)

- Aesir's session model is the natural home for the per-turn re-snap described above: at each turn boundary, the session's cache can be re-voted using the newest exchange as observation window, and the *discarded* positions are exactly the candidates for eviction from Aesir's persisted prefix store as well. SnapKV scores thus become a session-storage policy, not only a VRAM policy: keep on disk what heads keep voting for.
- Kernel requirement to record: Aesir's prefill attention should expose the final window's per-head attention sums over the prefix as a first-class output (a small reduction epilogue), so voting costs no extra pass over the prompt. Retrofitting that output onto a fused prefill kernel later is the kind of change that stalls; specifying it now is cheap.
- Per-head selection vs block storage: Aesir's block/prefix machinery wants shared position sets; SnapKV wants per-head sets. The reconciliation used by later work is to aggregate votes to a shared set (union or head-averaged top-k) at block granularity — accept the small quality cost for a large storage simplification, and measure it rather than assuming it.
- For hybrid SSM models, SnapKV applies only to attention layers; SSM layers compress by state, not selection. A unified Aesir "session compaction" step would snap attention caches and checkpoint SSM states at the same turn boundary, keeping the two memory systems' notions of "what survives" in sync.

## 8. Access

- Date accessed: **2026-11-15**
- arXiv abstract: https://arxiv.org/abs/2404.14469
- arXiv HTML (read for method + evaluation detail): https://arxiv.org/html/2404.14469v2
- NeurIPS 2024 proceedings: https://proceedings.neurips.cc/paper_files/paper/2024/hash/28ab418242603e0f7323e54185d19bde-Abstract-Conference.html
