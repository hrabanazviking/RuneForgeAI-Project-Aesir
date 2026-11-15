# StreamingLLM — Efficient Streaming Language Models with Attention Sinks

## 1. Full citation

- **Title:** Efficient Streaming Language Models with Attention Sinks
- **Authors:** Guangxuan Xiao, Yuandong Tian, Beidi Chen, Song Han, Mike Lewis
- **Affiliations (as listed in the paper):** Massachusetts Institute of Technology; Meta AI; Carnegie Mellon University; NVIDIA (Han)
- **Venue / year:** International Conference on Learning Representations (ICLR 2024). arXiv v1 29 September 2023; v4 7 April 2024.
- **arXiv:** arXiv:2309.17453 [cs.CL] — https://arxiv.org/abs/2309.17453
- **Code (as reported in the paper):** https://github.com/mit-han-lab/streaming-llm

## 2. The problem it attacks

Streaming use — an assistant that stays up for hours or days of dialogue — breaks standard decoding twice. First, the KV cache grows without bound, so memory and per-token latency grow with conversation length. Second, models degrade sharply on inputs longer than their training window. The obvious fix, window attention (keep only the most recent KVs in a fixed-size cache), fails catastrophically: the paper shows the model collapses as soon as the cache starts evicting, i.e. as soon as the *first* tokens fall out of the window — long before recent context is lost.

## 3. Core idea in our own words

The collapse is not about losing old *information*; it is about losing the **attention sink**. Across layers and heads, autoregressive models dump a large share of their attention mass onto the first few tokens regardless of what those tokens say. The paper's explanation: softmax attention must sum to one, so when no previous token is a strong match the model still has to put the probability somewhere, and the initial tokens — visible to every later position during training — become the learned dumping ground. Evict them and the attention distribution itself is distorted, which is why perplexity explodes.

StreamingLLM therefore splits the cache in two and never mixes the policies: **permanently pin the KV of the first few tokens** (four initial tokens suffice in the paper's ablations) and run an ordinary sliding window over everything else, evicting only from the window. Memory and per-token cost become constant, no fine-tuning is needed, and the attention distribution stays anchored. The paper also shows a cleaner long-term fix: pre-train with one extra placeholder token at the start of every sequence as a *dedicated* sink, after which a single sink token does the job (demonstrated on 160M-parameter models trained from scratch).

## 4. Key design details a runner engineer needs

- **Cache layout:** `[sink tokens (first ~4)] + [rolling window of most recent L tokens]`. Eviction is FIFO inside the window only. Positions for window tokens must be handled so the model sees them within its trained relative-distance range (the implementation keeps positional indices consistent with a cache of bounded size rather than ever-growing absolute positions).
- **Sink count:** ablation on Llama-2-7B (4,096-token cache, as reported in the paper's analysis) shows 1 sink token is not enough, 2 helps, **4 reaches essentially full quality**, and more gives diminishing returns. Treat 4 as the starting point, re-ablate per model family.
- **Compatibility:** orthogonal to quantisation, paged allocation, and prefix caching — it is purely an eviction policy. The paper notes adoption in production stacks (TensorRT-LLM, HF Transformers, MLC LLM, Intel Extension for Transformers, as listed in its impact statement).
- **What it is not:** it does not extend usable context. Anything evicted from the window is gone for good; the model can only attend to sinks + recent window. The authors are explicit that streaming stability ≠ long-range recall.
- **Where it hooks in:** the KV-cache eviction policy in the decode loop — a few lines in most runners, provided the runner can pin arbitrary early positions instead of assuming the cache is a pure FIFO queue.

## 5. Reported results — as reported, with context

All figures are the paper's own measurements.

- **Headline:** StreamingLLM enabled **Llama-2, MPT, Falcon, and Pythia** models to perform stable language modelling over **4 million tokens and more**, with **no fine-tuning**, and ran up to **22.2× faster per token** than the sliding-window-with-recomputation baseline (the only baseline with acceptable quality) in streaming settings.
- **The failure it fixes (PG-19, first book, 65K tokens, Llama-2-13B):** window attention perplexity **5158** (collapse) vs **5.43** for full recomputation and **5.40** for StreamingLLM — i.e. sink + window matched the expensive method's quality at window-method cost. A related measurement reported for Llama-2-7B: evicting the first tokens sends perplexity from ~9.59 into the thousands.
- **Efficiency setup:** decoding latency / memory benchmarked against sliding-window recomputation, both implemented in HuggingFace Transformers, on a **single NVIDIA A6000 GPU** with **Llama-2-7B and Llama-2-13B**. StreamingLLM's per-token latency grows linearly with cache size where recomputation grows quadratically; memory footprint matched the recomputation baseline.
- **Streaming QA behaviour:** on the paper's StreamEval benchmark (queries every 10 new lines, answers ~20 lines back), StreamingLLM maintained reasonable accuracy out to ~120K input tokens where dense attention failed at the pre-training length and window attention failed at cache size; it also composed with 32K context-extended models (LongChat-7B-v1.5-32K, Llama-2-7B-32K-Instruct) by enlarging the window.
- **Cache-size caveat (paper's own ablation):** increasing the window does *not* monotonically improve perplexity (e.g. Llama-2-7B on 400K PG-19 tokens: 9.32 at 4+1020 vs 9.59 at 4+4092) — models do not necessarily use a bigger window better.

## 6. Limitations / what it does not solve

- **No long-range memory.** Evicted tokens can never be attended again. A fact stated an hour ago in a chat is unrecoverable from the cache; any "the character remembers" behaviour must come from an external memory / summarisation system, not from StreamingLLM.
- Quality is "stable", not "equal to full attention over everything": tasks needing exact recall beyond the window score zero by construction.
- Sink behaviour is an empirical property of today's autoregressive Transformers; models trained with explicit sink tokens, different position schemes, or non-softmax attention may behave differently. Per-model verification (evict-test the first tokens, watch perplexity) is cheap and necessary.
- The 4M-token result is a language-modelling stability result on streamed text (PG-19), not a demonstration of coherent 4M-token *generation* or dialogue memory.

## 7. Applicability

### (a) Ollama on a 6 GB consumer GPU running long character chats

- This is the single most directly deployable idea in the wave for the stated workload. Long character chats on a small card *will* hit the context / memory wall; the naive behaviours are (i) stop, (ii) truncate the oldest turns (pure window — the paper shows this collapses quality the moment the opening tokens, which in chat are the character card itself, fall out), or (iii) StreamingLLM: **pin the opening tokens forever, roll the rest**.
- The chat mapping is unusually favourable: the tokens that must be pinned for stability (the first few) sit inside the segment that must be pinned for *product* reasons anyway — the system prompt / character definition at the head of the prompt. Pinning the full persona block (not just 4 tokens) plus a rolling window of recent turns gives both attention stability and persona persistence in one policy.
- Honesty requirement for the UI: with a rolling window, the character has *not* "remembered everything". Anything that scrolled out is gone. Pair this policy with an explicit memory mechanism (rolling summary re-injected inside the window, or retrieval) and tell the user which is in force; do not let "infinite chat" marketing imply infinite recall.
- Cost: essentially zero extra memory (4 pinned slots beyond the persona block) and no speed cost — it *removes* the recomputation alternative. There is no reason for a long-chat mode in Ollama to use plain FIFO truncation once this is understood.

### (b) Project Aesir (Mojo runner — sessions, prefix memory, hybrid SSM models)

- Aesir's session eviction policy should be sink-aware from the start: the cache manager needs a "pinned" class of blocks (session head / persona) distinct from the LRU / FIFO pool, and the attention kernels must tolerate a cache that is [pinned head] + [window] rather than one contiguous range. Retrofitting non-contiguity later is painful; PagedAttention's block table makes it natural.
- The sink phenomenon is also a diagnostic for Aesir: when a new model family misbehaves at long lengths, the first test is the sink test (does evicting token 0 explode perplexity?) before suspecting kernels or quantisation.
- For hybrid SSM models the picture differs by layer type: SSM layers carry a fixed-size state and do not "evict" at all — they forget gradually by construction. Attention layers in a hybrid still exhibit sinks and still need pinning. Aesir should therefore apply StreamingLLM policy per attention layer while leaving SSM state management to its own checkpointing rules, and should measure whether hybrids need fewer sink tokens (their attention layers carry less of the long-range load).
- If Aesir ever pre-trains or fine-tunes its own small models, the paper's dedicated sink token is a one-line training change with a measured streaming payoff — worth recording in the model-design notes now.

## 8. Access

- Date accessed: **2026-11-15**
- arXiv abstract: https://arxiv.org/abs/2309.17453
- arXiv HTML (read for method + evaluation detail): https://arxiv.org/html/2309.17453v4
- ICLR 2024 proceedings PDF: https://proceedings.iclr.cc/paper_files/paper/2024/file/5e5fd18f863cbe6d8ae392a93fd271c9-Paper-Conference.pdf
