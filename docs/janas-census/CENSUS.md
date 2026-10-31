# Janas Census (J-002–J-011)

**Ground:** the 13 public documents in `CENSUS_CHARTER.md`, retrieved 2026-10-31. Every row cites its document. Janas's figures are its own, from its development laptop (Core Ultra 9 185H, 32 GB RAM, NVMe ~5.7 GB/s, Debian 13) unless a row says otherwise — published claims, not Aesir facts.

## §0 — Where the full documentation goes beyond the roadmap's opening summary

1. **A services family**: beside the engine, Janas ships nine MCP domain services (`janas-flights`, `-weather`, `-maps`, `-prices`, `-github`, `-git`, `-quakes`, `-system`, `-wiki`), auto-started by the chat, loaded on demand (features.md, chat.md §"Janas's services").
2. **Cache-conditional expert dropping**: when the expert cache holds less than a fifth of a model's experts, light experts not in memory are skipped and their share redistributed (features.md) — an accuracy-for-speed lever with published agreement tables, governed by the quality tiers (chat.md).
3. **The server surface is far larger than "OpenAI-compatible API"**: 100 of OpenAI API 2.3.0's 345 operations served — Responses API, Files, Uploads, Batches, Vector Stores, Evals, Assistants, code interpreter in a self-built sandbox, embeddings, Whisper speech-to-text with diarization, moderations (serving.md).
4. **More converters than the summary named**: vision-encoder, Whisper, Silero-VAD and WeSpeaker converters beside `hf2gguf`/`gguf2jns`/`hf2jns_mtp` (models.md).
5. **Two experimental architectures** beyond the summary's matrix: NVIDIA Nemotron 3.5 Bolt (Mamba-2/MoE hybrid, on an unmerged branch) and Qwen3.8-Flash-Next (hyper-connections, sparse attention, 512 experts) (features.md).

## J-002 — Engine census I: streaming and memory

Source: README, features.md, INSTALL.md, chat.md.

| Behaviour | What the documents say |
|---|---|
| Expert streaming | Weights stay on disk (NVMe); the experts each token routes to are read from the file; hot experts stay in an in-memory cache. Headline: Qwen3-Next-80B-A3B (48.4 GB) on a 32 GB laptop: 26.4 tok/s writing vs llama.cpp 3.0; 68.4 reading vs 17.7 (README table, 21 Oct 2026). |
| Cache sizing | The cache takes the memory free at model open, less a reserve (default: a fifth of the machine's memory left to other programs, `--reserve`). `--cache <GiB>` is a hard cap. Resident weights ~2 GB for the 80B (INSTALL.md). |
| Disk discipline | Experts read with `O_DIRECT` at full disk speed (README "Read this first"); conversion lays experts out by co-activation so reads fall near each other (MODELS.md). Degradation under load is gentle: with browser+editor open, ~¾ speed kept, 5× longer disk waits (README). The same README warns the cache can push a low-headroom desktop into swap. |
| Read-ahead prefetch | Next layer's router applied early; missing experts read while the current layer computes. Auto-on only when misses are many (80B, 4 GiB cache: +6%). Prefill variant reads the block's likely experts ahead (80B reading 4,096 tokens: 36.8→42.0 tok/s at 4 GiB; 48.5→50.0 at 16 GiB). `JANAS_PREFETCH=0` / `JANAS_PREFETCH_PREFILL=0` disable (features.md). |
| Cache-conditional dropping | Cache < ⅕ of experts: an expert weighted below 0.8/k (0.95/k under a tenth) that is not in memory is not read; the token's other experts take its share (Skliar et al. cache-conditional routing). Published agreement/speed tables at 2/4/8 GiB caches (features.md). `/experts n` overrides; any n turns dropping off. |
| Bit-plane experts | `jns_planes` rewrites the experts' down matrix as three 2-bit planes; the engine may read 4 or 2 bits instead of 6 under memory pressure (`--bits <2\|4\|6>`), losslessly recombinable (models.md, chat.md). |
| Quality tiers | `--quality high\|medium\|low` (default low): low = 4-bit expert reads where experts don't all fit + light-expert dropping under ⅕; medium = 4-bit only; high = nothing lowered. Per-model *fast profiles* (measured lever combinations: `--head 4`, `--attention fast`, `--bits 4`) ship in the catalog; a lever joins a profile only at ≥2% measured gain, with published agreement costs per model (chat.md). |
| Head requant lever | `--head 4` requantizes a Q6_K output head to Q4_K at open (~1–2 s): +2.8–4.6% writing on measured models, published agreement cost (chat.md). |
| Fast attention lever | `--attention fast`: int16 query scores (exact integer sums), later also int16 value weighting; +5–11% attention cost at long context; auto only above 16,384 context (chat.md). |
| Cache-dir manners | Writes only to `~/.cache/janas` (learned config, read-ahead system messages ≤2 GiB, NPU graphs, MCP logs) and chosen output locations; model files never modified (README). |

## J-003 — Engine census II: placement

Source: README §"Choosing what runs where", chat.md options table, INSTALL.md.

| Behaviour | What the documents say |
|---|---|
| Pass taxonomy | Prompt passes ≥17 tokens (`--prompt-on`); draft-check passes 2–16 tokens (`--drafts-on`); reply passes 1 token (`--reply-on`). The NPU takes prompt passes of ≥64 tokens only. |
| Value forms | Each option takes `auto` (default; engine measures and chooses), a single device (`cpu`/`gpu`/`npu`), `a+b` co-work in one pass (`npu+gpu`), or a comma list (`npu,gpu`) the engine measures among and keeps the fastest of. |
| CPU's standing role | The CPU takes part in every pass; devices are added beside it, never instead of it. |
| Refusals by name | NPU asked for drafts/reply is left out with a warning; a device the machine lacks likewise. `--reply-on gpu` is the only way an integrated GPU gets single tokens. A hand choice holds over `--mode` presets. |
| Env equivalents | `JANAS_PROMPT_ON`, `JANAS_DRAFTS_ON`, `JANAS_REPLY_ON`; kill switches `--no-gpu`, `JANAS_GPU=0`, `JANAS_NPU=0`. |
| Persistence | Choices persist via `/save-config` (chat) and the learned tuning files in `~/.cache/janas` (see J-003b). |
| Power modes | `--mode auto\|eco\|max`; eco never uses the GPU for speed alone. |
| J-003b: self-tuning | The engine tries thread counts (all usable threads vs performance-core threads) and device mixes on real first passes, keeps the fastest per pass kind, re-tries alternatives occasionally (rarer as they keep losing, responsive to heat/power), and persists the result per machine+model. Published outcome: the self-chosen chat configuration landed within 1.5% of best reading and 2.6% of best writing on every compared model (README). On an i9-14900HX, all threads replied at <½ the speed of the performance cores' 16 (README). |
| J-003c: per-model tune | First terminal start of a model offers a measurement (drafts from prediction file / draft model / conversation / none; head bits under low quality) on three prompts at temperature 0, alternating order to defeat cache-warming bias; a rival way must win by ≥3% to be kept; the result (or a "no") persists to `~/.cache/janas/tune-<name>-<profile>.conf`. `--tune` re-measures; `--no-tune` opts out (chat.md). |

## J-004 — Engine census III: the NPU

Source: README §"Intel's NPU", features.md, INSTALL.md.

| Behaviour | What the documents say |
|---|---|
| What it takes | Prompt blocks ≥64 tokens. Never a reply token, never a draft check. |
| Dense-whole placement | A dense model whose layers fit NPU memory (≥9 in 10 layers; ~3.7 GB) goes layer by layer, whole: Qwen3, Qwen3.5, Gemma 4 dense. Published: Qwen3-0.6B reading 1,024 tokens 1,421 vs 974 tok/s without; Qwen3-4B 333 vs 201; Gemma-4-E2B 508 vs 196 (README table). |
| Split-block co-processing | Each prompt block in two halves: NPU computes a layer on one half while the CPU computes attention (or Qwen3.5 recurrence) on the other. Leftover layers stay on the CPU. |
| Resident-products placement | Larger/dense-too-big and MoE models give the NPU the products of weights that stay in memory (attention, recurrent layers, shared experts); routed experts stay CPU/GPU. On the dev laptop the GPU's fast prompt beat this on mixtures (30B-A3B: 133 vs 90–110 tok/s), and the engine kept the GPU. |
| Weight copies | NPU weights are 8-bit copies with a per-row scale, computed in f16, norms in f32. `--npu-int8` optionally takes 8-bit activations on dense Qwen3 (faster, less exact). |
| Preparation | One-time per session: copies + graph compilation, 7.5–53 s by model; progress reported on the chat status line ("preparing the NPU 12/25, 8 s"); compiled graphs cached in `~/.cache/janas/npu` (Nemotron: 36 s first, 3.8 s after). `janas-bench` prepares before measuring. |
| How graphs are made | Janas writes OpenVINO IR graphs itself and opens Intel's Level Zero driver at model open; nothing is linked against OpenVINO/Level Zero; without the driver nothing changes. |
| Contention closure | Where the expert cache cannot hold all feed-forward weights (larger mixtures, Qwen3.8-27B), the NPU stays closed unless `--prompt-on` names it — its 8-bit copies' memory is the cache's memory (27B wrote 1.7 vs 4.4 tok/s with the copies taken). |
| Agreement evidence | vs llama.cpp on two texts: most-likely-token agreement with the NPU as with the CPU, ±7 of 512, on eight models; Gemma-4-26B (product placement) agreed less (363 vs 398), so there the NPU reads only when asked. |
| Requirements | Linux, Intel Core Ultra NPU (only Meteor Lake tried), linux-npu-driver 1.38.0 packages + Level Zero loader libze1 1.32.0, user in `render` group; `JANAS_NPU_LOADER` names an off-path loader. No Windows NPU path. `janas-bench` prints an `NPU:` line or the reason there is none. |

## J-005 — Engine census IV: the GPU

Source: README, features.md, hardware.md, INSTALL.md.

| Behaviour | What the documents say |
|---|---|
| One GPU road | Vulkan 1.3, integrated or discrete, for every quantized type the CPU reads. Used only where measurement says it helps. A reply's tokens are bit-identical with and without the GPU. |
| Fast prompt (default on) | Prompt blocks go to the GPU's tiled products (Q4_K, Q5_K, Q6_K, Q8_0, Q3_K, IQ4_XS, IQ3_S, IQ4_NL, MXFP4; MoE experts one launch per layer: Q4_K, Q6_K, MXFP4, Q3_K; f32/bf16 weights). Sums rounded group by group: a prompt is *not* read bit-as-CPU. Published cost: 8–27 of 256 positions change most-likely token vs the exact way, falling on either side; mean score difference ≤3%. Qwen3-4B read 256 tokens at 220 vs 85 tok/s (GPU vs no GPU). `JANAS_GPU_FAST_PROMPT=0` = exact way. |
| MoE fast-prompt caveat | On a mixture larger than its cache, group rounding varies as the cache fills → the same prompt can read differently run to run, and replies can differ. `JANAS_GPU_REPEATABLE=1` keeps expert products on the CPU (exact, repeatable to the last digit) at the price of the experts' GPU speed. Draft chains ≥13 tokens stay off the rounded one-launch expert products. |
| Whole-layer dense | On dense Qwen3/Qwen3.5 the whole block (every layer, attention, recurrent layers) goes to the GPU in one submission while the CPU rests. Gemma 4 (since 26 Oct 2026): all four models run whole on the GPU — sliding-window rings, 512-wide heads, 16-bit KV, sandwich norms, per-layer-embedding branch, Q5_1 experts — with GPU norms/quantizations giving the CPU's bits (agreement vs llama.cpp on 400 tokens: 12B GPU 367 / CPU 362; 26B 321/321; E2B 386/391; E4B 392/394). |
| MoE prompt division | On Qwen3/Qwen3.6 mixtures a layer per submission; the CPU only routes and reads the next layer's experts ahead — where the cache holds ≥½ the experts (`JANAS_GPU_MOE=0\|1` overrides). |
| Discrete-card whole passes | A card with its own memory runs every pass whole (prompt, draft checks, single tokens) with state in its memory; a mixture keeps a VRAM tier of most-used experts, the CPU computing the rest between layers; tier size does not change the answer for Q3_K/Q4_K/Q6_K/Q6_K_P/MXFP4 experts (MXFP4, Q2_0, IQ, Q5_K still round differently). Checked only via an integrated GPU simulating a card; speeds there say nothing of a discrete card (hardware.md, honest). `JANAS_GPU_WHOLE=0`, `JANAS_GPU_TIER=0`, `JANAS_GPU_TIER_MB=<n>`. |
| Single tokens on GPU | An integrated GPU is not given reply tokens by itself (kept awake only for passes it takes — power lesson from testers, hardware.md); a discrete GPU is tried for single tokens and kept where faster (`--reply-on gpu`, `JANAS_GPU_MIN_N=1` history). |
| Self-check at open | Opening the GPU runs a product of every type against the CPU's; shaders the driver gets wrong are left out (once per driver, kept in `~/.cache/janas/gpu_selfcheck`). The `fma()` rounding check: Mesa RADV splits fma on pre-RDNA2 AMD; there the engine builds its own once-rounded fma through float64, keeping products the CPU's to the bit. `gpu_check`/`vkcheck` are standalone diagnostics that isolate a wrong shader by itself. |
| Requirements | Vulkan 1.3 driver; shaders need glslang ≥15.2 at build time or the build goes on without GPU support and says why (INSTALL.md). |

## J-006 — Engine census V: drafts

Source: chat.md §"On --mtp, --draft and --no-spec", README §"The drafts", features.md.

| Behaviour | What the documents say |
|---|---|
| Invariant | Speculation never changes the text: a guess is kept only where the token the model itself sampled is the same; first disagreement discards the guess. Proven in its test runs (256 tokens with/without from one seed identical; a 3-reply, 600-token chat identical). On CPU alone drafts never change the text. |
| Source 1 — MTP heads | The model's own multi-token prediction block: Qwen3.5/3.6 (block in the GGUF/checkpoint), Qwen3-Next (block converted separately), Qwen3.8-Flash-Next (block as its own GGUF; draft = the model's own next token at 130/158 positions of code; 29/40 drafts kept on a chat reply). `--mtp <file>`, auto-found beside the model by header fit; `--no-mtp` refuses even a found one. |
| Source 2 — assistant drafter | Gemma 4's assistant: a small drafting model of the family that reads the main model's KV, taken as its `--mtp` file. Published gains (Italian chat reply, greedy): E2B 34.7→51.0, E4B 18.3→26.3, 12B 8.5→12.9, 26B 16.9→24.5 tok/s. |
| Source 3 — cross-model draft | `--draft <file>`: a small model of the same family sharing the vocabulary (catalog pairs Qwen3-4B ← Qwen3-0.6B automatically). Right ~¾ of the time; second token in a pass costs ~6% (dense) vs ~28% (MoE), so it pays on dense (0.6B→4B: 1.14×, 23.0→26.3 tok/s) and not on the 30B mixture. |
| Source 4 — conversation drafts | Where no block exists, guesses are copied from the conversation itself: right ~¼ of the time; worth it on dense, barely on mixtures. |
| Published acceptance | English explanation text: 74–89% kept on Qwen models and Gemma's larger two, 63–72% on E2B/E4B; Italian prose collapsed Qwen3.5-2B to ~⅓ kept and next to no gain. Drafts give nothing where the expert cache is much smaller than the model (extra tokens call more experts; disk is already the limit). |
| Verification sizing | How many guesses a pass checks is decided from what passes have cost on this machine; a guess-pass is still tried occasionally after the engine stops guessing, so a busy-disk moment doesn't disable drafts for the session. |
| Headline gains | Qwen3-Next-80B: 23→36 tok/s with `--mtp`; 37 tok/s in bench with warm cache; Qwen3.5-9B 13→22. `--no-spec` / `/spec off` exist only to measure with. |

## J-007 — Engine census VI: context and KV

Source: README §"Long contexts", features.md, chat.md.

| Behaviour | What the documents say |
|---|---|
| 8-bit KV | Keys and values at 8 bits on the Qwen line (the comparison condition both engines shared). Gemma 4 keeps KV at **16 bits** — "far more sensitive to them than Qwen" (features.md); its sliding-window layers keep only visible positions (~16 KB/token + 0.5 GB fixed for the 12B vs 175 KB/token full). |
| Long-context table (published) | Qwen3-4B Q4_K_M, CPU both sides, 12 threads, 8-bit KV both engines: reading 118/96/74/56/35 tok/s at 1k/4k/8k/16k/32k (llama.cpp 54/32/20/<9.1/—); writing after 27.6/22.0/18.2/15.0/10.7 (llama.cpp 12.1/7.5/4.9/—/—). llama.cpp had not finished reading 16k after 30 min, so its 16k writing and all 32k figures are absent — recorded as its result. |
| Attention's share | At 32k, attention takes 59 of the 93 ms a written token costs; the 32k prompt takes 15 minutes to read; peak memory grows 2.6 GiB (1k) → 4.9 GiB (32k). |
| Method | `tests/bench_long`: prompt read in blocks from position 0, then 64 greedy tokens; llama.cpp via `llama-bench -p n -n 0` / `-p 0 -n 64 -d n`, runs stopped at 30 min; same file, same mixed texts, machine otherwise idle. With a 16-bit cache llama.cpp read faster (67/55/44/31) and wrote about the same — published alongside, not hidden. |
| Context behaviour | Default context 16,384, never more than the model was trained for (`--ctx`); a full context *slides* instead of ending; on sliding, oldest turns are dropped, by default after being summed up (`--no-recap` drops without the summary). `max_input` refuses an over-long prompt with its numbers, never cuts it. |
| Prefix reuse | The server/library keep a conversation's computed prefix: same messages + a new one cost only the new one; `usage.prompt_tokens_details.cached_tokens` reports the reused share; up to N conversations kept (`--keep`, plus `--keep-disk`/`--keep-memory` tiers, persisted across restarts). Recurrent-state models (Qwen3-Next/3.5/3.6) re-read from the start when a conversation differs earlier. |

## J-008 — Tool census I: chat, get, bench

Source: chat.md, models.md, hardware.md, INSTALL.md.

| Behaviour | What the documents say |
|---|---|
| `janas-chat` | Terminal chat with its own line editor (multi-line box, history kept between sessions, completion), colours + status line, markdown *read* rather than printed (with careful non-mark rules: `snake_case`, `2*3` stay literal; `--no-markdown` prints raw), plain-text when piped (scriptable). `/image <file>` attaches PNG/JPEG for vision models. Reasoning shown apart in grey; `--think on\|off\|N` (N = reasoning budget, closed with a written sentence). |
| Slash commands | `/help` `/about` (version, author, licence + live model/machine/engine — "the three things a report of a problem needs") `/stats` `/context` (fullness broken down by parts) `/reset` `/system` `/temp` `/spec` `/think` `/image` `/mode` `/experts` `/markdown` `/gpu` `/save-config` `/load-config` `/del-config` `/mcp` `/quit`. Changes last the conversation only unless saved. |
| Settings layers | Catalog profile → machine measure → chat config file → per-model config file → command line; each over the one before. Config files hold command-line words, one option a line; unknown words refused with the nearest match ("did you mean --temp?"); bad values refused, never reinterpreted (`--ctx 32k`, `--temp 0,7` refused); an env var named almost like a real one is reported at start instead of silently doing nothing. The same refusal discipline in server, mcp and bench. |
| Model picker | No model named → the catalog lists, marks what's downloaded, asks which; a missing pick offers download+convert via `janas-get`. Qwen3.5-0.8B is excluded from the picker (a test model that calls tools badly and invents facts — 7/15 right tool calls vs the 2B's 14/15) but opens by name with a warning. |
| `janas-get` | Downloads converted models from the project's HF repos with their prediction files; SHA-256 checked against MODELS.md fingerprints; resumable; an existing file is checked, not re-fetched. `--from-gguf` downloads the catalog's original GGUF and converts locally to the same fingerprints. Arbitrary `hf:<owner>/<repo>/<file>` accepted, checked against HF's listed SHA-256. |
| `janas-bench` | Sweeps the configurations the engine may choose (threads × cores × GPU/NPU per pass kind), with settle (300 ms in the published runs) and rounds; writes the learned profile into `~/.cache/janas` so chat starts tuned, and leaves a machine report (`janas-bench-<date>.txt`: CPU name, core layout, GPU, every configuration's speeds, the `NPU:` line or its refusal reason). Published method: `--prompt 1024 --gen 16 --rounds 2 --no-mtp --settle 300`. |
| Prompt watching | Long prompts read in blocks of 256 (512 where the GPU takes feed-forwards whole); the library returns control between blocks; chat shows progress in the status line (or `--progress <s>` lines on stderr); the time-left estimate fits the per-token cost as a line in position (R² 0.99999 on a 260,954-token prompt, where a rate-based estimate promised 2.5× too little). `JANAS_PROGRESS=<s>` gives any library program the same lines; `JANAS_METRICS=<file>` appends JSONL events (open/prompt/progress/first_token/reply/refused) — counters and times only, never text. |
| System-message read-ahead | The chat reads the system message + tools at start, while the user types; the computed read is cached in `~/.cache/janas` so the next chat on the model finds it ready. Services' tools are *not* all written into the system message (4,057 tokens → a 616-token catalog, one line per service, opened on demand; opening weather costs ~1,000 tokens once). |

## J-009 — Tool census II: serving

Source: serving.md, code-completion.md, chat.md (MCP client).

| Behaviour | What the documents say |
|---|---|
| `janas-server` | OpenAI-following HTTP API at `127.0.0.1:8080/v1`: chat completions (streamed SSE, tools held to a grammar so arguments are always schema-valid JSON, JSON output held to a schema token-by-token incl. bounds/formats/patterns, logprobs ≤20, `n` replies, penalties, logit_bias), raw completions (`echo`, `best_of`, `suffix`), `/infill` (llama.cpp's route), models list, `/health`. Reasoning separated into `reasoning_content`; reasoning budgets close reasoning with a written sentence; `max_tokens` (answer-only) vs `max_completion_tokens` (incl. reasoning) distinction honoured as clients mean it. A `janas` usage object adds context + timing truth beyond OpenAI's fields. |
| The wider surface | Responses API (items, conversations, background, cancel, compact), Conversations (7 ops), Files (4 ops) + Uploads (3 ops, chunked to 8 GiB with MD5 check), Batches (background JSONL, resumable across restarts, never starving live requests), Vector Stores (chunking, embedding or BM25 search, filters), Evals (string/text-similarity/model graders; python graders refused), Assistants API (23 ops, threads/runs/steps, streaming events), stored completions — 100 of the spec's 345 operations served; **every other operation has a route answering 501 with its reason** (not written yet / needs another model kind / trains models / OpenAI administration). |
| Server manners | One request at a time (the model holds one sequence); queue (16) with 429 when full; streamed requests report queue position; a closed connection stops its reply. API key (`--api-key`/`JANAS_API_KEY`); TLS 1.2/1.3 with own cert/key (key checked against cert at start); browser `Origin` refused except its own page or `--allow-origin` entries (a page must not drive a local model); `--max-input` refuses with numbers, never truncates. Listen is localhost unless `--host` says otherwise, with a warning if there's no key. |
| Server extras | Embeddings from a second small model (`--embedding-model`; cosine 0.98–0.996 vs llama.cpp on the same file). Speech-to-text from a Whisper model (`--speech-model`): every audio format OpenAI lists read by Janas's own decoders, word timestamps, streaming segments, Silero-VAD chunking, WeSpeaker diarization (`diarized_json`). Moderations asked of the chat model at temperature 0 against a held schema (a general model, not a trained classifier — said plainly). Pictures in messages for vision models (`image_url`/`input_image`, data: or public http(s) only, private addresses refused). Code interpreter OFF by default: model-written Python in a self-built unprivileged sandbox (user namespaces, no network, read-only /usr, 256 MiB tmp, seccomp) + Containers API. |
| `janas-mcp` (server) | The model as MCP tools over stdio: `generate` (prompt, optional system/max/temp) and `embed` (with `--embedding-model`). Speaks both protocol eras (stateless 2026-07-28 via `_meta`; initialize handshakes 2025-11-25 → 2024-11-05); ping answered mid-generation; `notifications/cancelled` stops a generation; each call is its own conversation; reasoning never returned. Run against Claude Code 2.1.282 (both tools listed and called) and Janas's own chat as client. |
| MCP client (in chat) | Servers from `~/.config/janas/mcp.json` in the other clients' format; tools namespaced `server__tool`; every call shown with arguments and confirmed by key (`y`/`n`/`a`) before it runs; `--mcp-auto` for pipes; servers' instructions kept out of the system message unless `--mcp-instructions`; stdio and Streamable HTTP(S) transports, both eras; server stderr logged per server. Near-miss config keys refused with the intended one (`arg` → `args`). |
| MCP in Responses | A request may name MCP servers (`type: mcp`): the server connects (public addresses only — every resolved address checked and pinned; loopback/private/link-local/reserved refused as `not a public address`; `--mcp-allow` names local exceptions; `--no-mcp` disables), lists tools once per conversation, and either returns an `mcp_approval_request` (default `always`) or runs calls in-response (≤8 rounds). |
| Janas's services | Nine MCP services (flights, weather, maps, prices, github, git, quakes, system, wiki) from free/keyless sources mostly; each with its own page; auto-started by chat (or `--no-services`); git service's writes (commit/pull/push/branch) each shown whole and asked first, nothing destructive offered; system service reads only and never reaches the network; wiki shows the user the page as-is while the model reads only a note. |
| Code completion | Through the server: `/v1/completions` with `suffix` or `/infill`; FIM models (Qwen3-Coder family); the sliding-window discipline — prefix capped (`--fim-prefix` 2048, cut at a line to ¾), window starts remembered per file so a slid window keeps its anchor, suffix cut at 8 lines, output capped (`--fim-max` 256) whatever the editor asks; greedy (same place → same proposal). Published: after a window's first read, requests answered in 1.5–2.2 s with ~90 new tokens read (llama.vscode + Continue both driven). Recurrent models can't rewind, so every keystroke re-reads their window — named as their limit. |

## J-010 — Tool census III: converters, library, research tools

Source: tools.md, library.md, models.md, MODELS.md.

| Behaviour | What the documents say |
|---|---|
| `gguf2jns` | GGUF → `.jns`: one slot per (layer, expert) so needed experts read without reading anything else; experts laid out by co-activation; metadata byte-for-byte; MXFP4 resident tensors re-encoded as Q8_0 exactly; deterministic — same GGUF, same bytes, on any machine (fingerprints in MODELS.md). |
| `jns_planes` | Down-matrix bit planes (see J-002); deterministic; fingerprints published per model. |
| `hf2gguf` | HF safetensors (Llama 3) → bf16 GGUF, with a PEFT LoRA adapter merged in if given; the merged weights verified bit-identical to an independent merge; llama.cpp's `llama-quantize` then quantizes. |
| `hf2jns_mtp` | The MTP block from the original checkpoint: whole shards, just the block's tensors fetched from HF by range requests (487 MB instead of 14 GB of shards for Qwen3.5-9B), or copied as-is from a GGUF of the block alone (unsloth's `mtp-*.gguf`, minus its embeddings/head). Deterministic. |
| Vision converter | `hf2jns_vision`: the vision tower from an HF checkpoint dir (Qwen3.5; of Gemma's whole-model checkpoint only the tower). Published agreement vs llama.cpp mmproj from the same checkpoint: cosine 0.999997 avg (Qwen3.5-0.8B), 0.999999 avg Gemma E2B, 1.000000 Gemma 12B. The engine finds `.vision.jns` beside the model by longest-prefix name. |
| Speech converters | `hf2jns_whisper` (HF Whisper → engine file; logits cosine 1.000000 avg vs whisper.cpp), `silero2jns` (Silero VAD ONNX; speech probability agrees with onnxruntime to 1.7e-6), `wespeaker2jns` (WeSpeaker ResNet34 ONNX; embedding cosine 0.9999993 vs onnxruntime). |
| `jns_check` | Model file inspection; `--verify` checks every expert's checksum. A `.jns` carries per-expert + metadata checksums, so a damaged copy is caught locally. |
| Checkers/benches | `llm_eval` (logits vs a reference dump), `vocab_check` (vocab-restricted head gives the whole head's logits to the bit), `bench_kernels`/`bench_gemm`/`bench_attn`/`bench_long` (piece measurements), `gpu_check`/`vkcheck` (see J-005), `mcp_fake_server` (protocol test double, both eras), `openapi_routes` (the server's route table generated from OpenAI's spec — also counts what's served), `gen_unicode`, `gen_geo`. |
| C library | `libjanas_llm`: opaque handles, fixed-width types, size-carrying parameter blocks, int32 error codes, whole-UTF-8 reply pieces. `chat_load` hands over a whole conversation (shared prefix not re-read); `chat_keep` keeps several conversations computed; `chat_prepare` reads system+tools ahead; `chat_vocab` restricts the output head to a vocabulary subset (its rows alone computed); `chat_image` queues a picture; speech handle separate (`janas_llm_speech_*`: transcribe/translate, segments, word times, logprobs, VAD chunking, diarization turns). `libjanas_mcp` is the MCP client as its own library. |
| Node/TypeScript | `janas.node` (Node-API 8, written in C, no Node build deps): async streaming pieces (text/reasoning/progress), `chat.load`, stop via loop-exit/`stop()`/AbortSignal, `reply.stats()`, per-model engine thread, error codes mirroring the C library's. Not built for Windows yet. A full TypeScript chat example (model inside the server process, replies streamed to a browser) ships as an example. |
| FreeBASIC / BASIC MODERN | `llm.bi` declares the same C library; `janas_oop.bi` adds classes (Model, Chat, options, ReplyStats, Conversation, ReplyHandler/Printer, McpServer); a 100-line FreeBASIC chat example; byte-identical replies to the C library's in its checks. BASIC MODERN is the author's own platform — the binding exists because Janas is meant to sit inside it (library.md). |
| `janas-nsm` | Research tool: NSM explications from a trained model (DeepNSM, Llama-3.2-1B + the arXiv 2505.11764 adapter), scored as the paper scores (primes/molecules shares, legality, circularity; reproduces the paper's figures on its 1,341 published records); `--strict` restricts output to primes + function words + a molecules list (~3,800 of 128,257 tokens) — measured: legality +0.15, but neighbour-discrimination −6.0 points, so the default writes freely. The weights/data are CC BY-NC-SA and Janas does not ship them. |

## J-011 — Model breadth census

Source: features.md (the matrix), models.md, MODELS.md, reports.md, ChangeLog (through 2026-10-30).

**Architectures Janas documents as running** (arch name; status):

| Arch | Models named | Notes from the documents |
|---|---|---|
| `qwen3` dense | 0.6B, 4B run here; 1.7B/8B/14B/32B "should convert and run the same way — none has been tried here" (models.md, said plainly) | MTP: none (0.6B drafts for 4B) |
| `qwen3moe` | Qwen3-30B-A3B (+Coder-30B) | imatrix and UD-Q3_K_XL files both measured |
| `qwen35` dense | 0.8B, 2B, 9B run + checked vs llama.cpp | recurrent (hybrid) layers; MTP block in checkpoint |
| `qwen35moe` | Qwen3.6-35B-A3B; Qwen3.5-MoE class | GGUF keeps its MTP block |
| `qwen3next` | Qwen3-Next-80B-A3B-Instruct, Qwen3-Coder-Next | hybrid recurrence; the engine's shaping model; MTP from checkpoint |
| `gemma4` | 12B dense, 26B-A4B MoE (128 experts + dense FFN), E2B, E4B | 16-bit KV; sliding-window layers; per-layer embeddings streamed row-at-a-time (E2B in 1.5 GB); assistants as drafters; tools in Gemma's own notation, template-exact |
| `llama` | Llama 3 / 3.2 checkpoints via hf2gguf (+LoRA merge) | DeepNSM-1B the checked witness (Q8_0: 466/477 agreement vs llama.cpp, CPU and GPU) |
| `nemotron_h_moe` | Nemotron-3.5-Bolt-74B-A9B (NVIDIA's 24 GB GGUF: IQ2_XXS experts, NVFP4 Mamba, Q8_0 embed/head) | **on the `nemotron` branch until merged** (28 Oct 2026); 395/400 agreement vs llama.cpp on C; sigmoid routing with bias, per-layer expert counts to 496, latent-space experts |
| `qwen4exp` | Qwen3.8-Flash-Next (177B, 512 experts, ISTA GSQ-RCO Q2_0 66.4 GB) | hyper-connections (4 residual streams), n-gram embeddings streamed, sparse attention past 2,051 positions; 2,171/2,200 agreement; experimental by its own naming |
| dense (speech) | Whisper family (small, large-v3-turbo named) | separate speech pipeline (see J-009/J-010) |
| embedding | Qwen3-Embedding-0.6B (Q8_0) | for server embeddings + MCP `embed` |

**Quant/type breadth documented as read:** Q4_K_M primary; Q3_K, IQ3_S, IQ4_NL, IQ4_XS, Q4_0, Q4_1, Q5_1, Q2_0, Q2_K, IQ1/IQ2 family kernels (ChangeLog 2026-10-24: Q2_K + IQ1/IQ2/IQ3 GPU kernels; features.md kernel table incl. IQ2_XXS in Nemotron's file), MXFP4 (resident + MXFP4_MOE experts), NVFP4 (Nemotron Mamba), unsloth UD dynamic mixes, bartowski importance-matrix Q4_K_M. Refused: a GGUF carrying types outside the read set is refused rather than guessed at (models.md); IQ2/IQ1 *conversion* "not yet" (models.md — read support exists for IQ2_XXS in Nemotron's file; the conversion line in models.md predates it — recorded as documented tension, not resolved from docs alone).

**Cross-machine evidence:** reports.md logs 22 tester reports (i7-1365U, Ryzen AI 9 HX 370, Ryzen 9 9950X3D + RTX 5080, i9-14900HX + RTX 4070, Radeon 780M, i5-1135G7, Ryzen 7 7840HS on Windows): bigger-than-RAM operation witnessed at 142 GB on 62.5 GiB and 48 GB on 15.4 GiB; several Windows prompt reads "far slower… being looked into" — published, unresolved.

**Platforms:** Linux x86-64 + Windows 10/11 x86-64 (same laptop; Windows NPU absent; Windows chat console in any language). macOS NOT supported (hardware.md).
