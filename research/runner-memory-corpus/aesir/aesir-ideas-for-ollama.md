# Project Aesir — Ideas Dossier for Ollama (OR-4)

**Campaign:** Ollama Research Forge (commissioned by Volmarr, 2026-11-15)
**Slice:** OR-4 — first of the Aesir study files
**Date:** 2026-11-15
**Status of this file:** research dossier, not a build plan. Every number below is given exactly as recorded in the named source; where the VM-side records I was allowed to read did not contain a number, I say so rather than filling it in.

**Sources used (only these):**
- Local clone `~/workspace/RuneForgeAI-Project-Aesir` (README.md, ARCHITECTURE.md — the repo's own words; see §1 caveats).
- `~/workspace/goals/aesir-z13-strix-halo-forge/` — `AESIR_Z13_MASSIVE_ROADMAP.md`, `WAVE_PLAN.md`, `PROJECT_MEMORY_MAP.md`.
- `~/workspace/goals/aesir-hailo-10-200-slice-roadmap/` — model-wave records.
- `~/memory/2026-11-14.md` and `~/memory/2026-11-15.md` (daily logs).
- `~/workspace/CURRENT_STATE.md` (board, refreshed 2026-11-15 01:03 EST).
- `muse.memory_search` for "Aesir prefix memory", "Aesir session residency", "qwen35", "Aesir compression".

**Not used:** no work on purpleraider (paused), no device invocation, no git writes, no live GitHub browsing beyond the local clone already on the VM. The GitHub repo named in memory is `hrabanazviking/RuneForgeAI-Project-Aesir`; the serve-line work lives on branch `yrsa/hip-serve` of the Aesir repo on purpleraider, not on `main`.

**Reading rule for this dossier:** Aesir is written in Mojo, bare metal, no libraries. Ollama is written in Go. Nothing in this file is portable code. Every idea is translated at the *idea level* into Go/Ollama terms (§7). Mojo identifiers are named only so the idea can be traced back to its Aesir home, never as something to copy.

**Labels used throughout:** **[PROVEN]** — a recorded test/gate result with a number. **[RECORDED, ungraded]** — stated in a campaign record without a gate number attached. **[SPECULATION]** — my inference for the Ollama translation, marked as such. **[NOT VERIFIED]** — the task brief asserted it, or it was named in a record I could not re-check from the allowed sources.

---

## 1. What Aesir is

### 1.1 Architecture (as the repo describes itself)

Project Aesir (A.E.S.I.R.) is Volmarr's own from-scratch model runner, written in Mojo, bare metal, no libraries. Its own README (local clone, `~/workspace/RuneForgeAI-Project-Aesir/README.md`) says, in present tense, that on a currently supported setup you can: build the native program; launch its terminal Home screen; inspect the local model catalog; import GGUF files into a protected model store and verify them; give models aliases/favorites; inspect GGUF information and hardware/memory-fit information; run `aesir doctor`; chat interactively with supported native CUDA models; run a local authenticated HTTP service; and run "the early Ollama-compatible local service" and experiment with applications that only need the currently implemented Ollama/OpenAI-compatible text surface.

The same README warns, in its own words, not to expect arbitrary GGUF files, every GPU vendor, every Ollama client feature, embeddings, vision, general tool execution, or Internet-facing serving yet. A narrow single-function Gemma 4 tool-call response is documented in its API support matrix.

The root `ARCHITECTURE.md` in the clone carries an explicit warning that it "preserves the intended Slice 6 design vocabulary" and is "not a present-tense implementation map" — the evidence-backed system is `docs/ARCHITECTURE.md` and `CAPABILITY_LEDGER.md`, and "HTTP compatibility, multi-device execution, accelerator memory, and end-to-end RAG remain partial, scaffolded, or missing as recorded there." Treat any architecture claim in this section as the *intended* vocabulary, not a proven implementation, unless a gate number is attached.

The intended vocabulary, in the repo's own realm names:

- **Midgard (client/user domain)** — external requests, HTTP interfaces.
- **Bifrost (server layer)** — transport bridging Midgard to Asgard; `server/api.mojo` (BifrostGate), bare-metal HTTP, streaming via `send_chunk`, `/api/embeddings` formatting.
- **Asgard (engine)** — `aesir.mojo` (AesirEngine), coordinating `core` and `loader`; holds a `MimirStore` knowledge base for RAG (`search_knn`, `[CONTEXT]: …` augmentation) and a `DeviceTopology` for multi-device orchestration; single and streaming generation loops.
- **Nidavellir (compute core)** — raw maths and SIMD kernels.
- **Mímisbrunnr (memory well)** — pre-allocated memory, zero-copy vector store; `core/mimir_well.mojo` (MimirWell, KVCache, MimirStore, DeviceTopology, ShardTensor).

Loader side: `loader/gguf.mojo` (GGUFSeer) — "zero-allocation" GGUF parser, headers/KV/tensor tables, weights mapped via mmap into MimirWell; `loader/tokenizer.mojo` (RuneWeaver) — pure-Mojo BPE tokenizer with byte fallbacks (`<0xXX>`) and iterative pair merging.

### 1.2 Backends

- **CUDA (native):** the historically proven path — interactive chat with supported native CUDA models, and the Llama3 CUDA session is the one place prefix reuse was test-proven end-to-end before the HIP-serve line (see §2/§3). CUDA is absent on the Z13 (purpleraider), which is why the HIP-serve line exists.
- **HIP / AMD (Strix Halo, purpleraider):** the 2026-11-14 serve line. HIP kernels lived in the grading line (`core/hip_*`) but, at the time of the MAP (2026-11-14 ~09:01 EST), nothing implemented the `ControlledTextSession` contract over HIP — that gap was HS-1. A working HIP Q8_0 GEMV gateway exists (`core/hip_gemv.mojo`, slice A-082) **[RECORDED]**.
- **CPU:** the fallback that became the gate config for the 27B — the Q8_0-resident CPU configuration (see §4). The F16 path for the 27B peaks at ~57 GB RSS **[RECORDED]**; the 40B F16 estimate is ~83 GB **[RECORDED]**.
- **Hailo-10 NPU:** a separate thread, explicitly untouched by the Z13 roadmap. The Z13 roadmap states: "Text generation on the Hailo chip was never achieved and is never claimed here." **[PROVEN by absence — stated as a standing negative.]** Do not import Hailo ideas from Aesir into Ollama; there is nothing to import.
- **Vulkan / ROCm / XRT (2026-11-11 hardware truth):** Zen 5 16c/32t, Radeon 8060S gfx1151, XDNA 2 NPU (`/dev/accel/accel0`, amdxdna healthy), 128 GB unified LPDDR5X, `/dev/kfd` present, RADV Vulkan present, ROCm userland absent, XRT userland absent, Kubuntu 26.10, kernel 7.3 **[RECORDED, 2026-11-11]**.

### 1.3 Where it honestly stands

| Line | Standing (as recorded) | Source |
|---|---|---|
| Z13 Massive Roadmap (AMD hardware roadmap only) | **127 of 216 banked**; Wave 15 stands 1 of 9 (A-127); remote `main` = `31ab9363` (A-127 closure, 2026-11-14 ~07:31 EST) | CURRENT_STATE board, 2026-11-15 01:03 EST; `AESIR_Z13_MASSIVE_ROADMAP.md` (216 slices A-001…A-216, 24 waves of 9, 9 parts: I Ground Truth & Bring-Up · II Engine Core · III GPU via Vulkan · IV HIP & NPU · V Correctness · VI Performance · VII Robustness · VIII Completeness · IX Packaging & Final Proving) |
| HIP-serve line (HS-1…HS-7) | **COMPLETE** — all seven banked on branch `yrsa/hip-serve`, `main` untouched at `31ab9363`; Grand Proving **901 passed / 2 failed / 2 skipped of 905**, both failures proven pre-existing (J-022; `gpu.hip_q4k_gemv_no_leak`, re-proven identical on untouched base `31ab9363`) | `memory/2026-11-14.md` L2135, L2140 |
| Qwen35 adapter (Q35-1…Q35-7) + 40B recon (Q40-1) | **COMPLETE** — Q35-7 close at `5506180d` on `yrsa/hip-serve`; `aesir-gate` serving qwen35-27B, Q8_0-resident CPU config, at `127.0.0.1:18434`, fence 48G/64G; health reports `model_variant qwen35-27B`, `weight_load_mode q8_0_resident`; live completion verified by the coordinator; full suite at close **900 passed / 3 failed / 2 skipped of 905** (2 proven pre-existing + `resilience.state_vault_rejects_growth`, a contention scheduling race that passes standalone 3/3) | CURRENT_STATE board; `memory/2026-11-14.md` L2871–L2874 |
| Compression school (QC-0…QC-7) | **COMPLETE** 2026-11-14 18:01 EST (QC-7 banked at `b388e188`) | `memory/2026-11-14.md` L2874; see §5 |
| Speed/stability campaign (QS-0…QS-6) | **QS-0 only, baseline stage** — QS-0 plan + records at `cb6ad1e`, baseline bench harness at `cff944fc`, evidence logs at `92180bf4`, `QS-0-BASELINE.md` (baseline table + CPU/HIP indictments + slice order) + ledger close at `bad65106` (hip-serve remote head, re-verified 2026-11-15 01:03 EST). QS-1…QS-6 not banked as of the board's last refresh. | CURRENT_STATE board; `memory/2026-11-14.md` L2960, L2977, L3151; `memory/2026-11-15.md` L26 |
| Serve gate (what "serves" means here) | `aesir-gate` unit active, serving the 27B in Q8_0-resident CPU config at `127.0.0.1:18434`; the pre-swap 3B config is backed up and `VOXTA_SWITCHOVER.md` carries the rollback; serve 404s unless the request `model` field is the full GGUF path **[RECORDED]** | CURRENT_STATE board; `memory/2026-11-14.md` L2959 |

**What is proven vs not — the honest list:**
- **Proven:** exact-prefix KV reuse (Llama3 CUDA session, then Gemma4 via HS-4, then HIP via HS-1…HS-3); token-level session residency with the generation-seam loss eliminated (HS-6); stable-order memory injection (HS-7); hybrid-state prefix snapshots that restore bit-exact (Q35-5); CPU forward correctness of the 27B at 198/198 near-tie vs llama.cpp (Q35-3b); GGUF writing with Q8_0 faithful on stories260K (QC, §5).
- **Not proven / not chosen:** HIP decode speed — **~0.07–0.09 tok/s, experimental**, recorded as remaining work, NOT chosen for the gate (Q35-6 HIP PASS at real scale, 71/71 rank 1, gap 0.0, but decode speed is the blocker). The gate serve runs on CPU, not HIP.
- **Not proven:** the 40B's own real-file proofs (gated by its own numbers, whenever ordered); `min_p` / `repeat_last_n` parity on qwen35; gemma4 CPU forward; native HIP admission; Q4_K_M residency to FAITHFUL (QS-3, not yet run). All named as remaining work in the board, not as done.
- **Reversal to note:** the 27B was first graded NOT runnable on Aesir (2026-11-14, `aesir inspect` → UNSUPPORTED, "No architecture adapter is registered"; `forward_pass_qwen35` graded LOAD_FAIL_NAMED_CAUSE, A-048) and later, after the Q35 campaign, graded FAITHFUL and serving. Both verdicts are in the record; the later one governs, the earlier one explains why the adapter campaign existed.
- **Yardsticks recorded for the QS campaign (Ollama on the same machine, purpleraider):** Ollama Q8 **7.65 tok/s**, Ollama Q4 **12.11 tok/s**; Aesir HIP decode ~0.07–0.09 tok/s **[RECORDED, `memory/2026-11-14.md` L2960]**. The gap is the QS campaign's reason for existing. **[NOT VERIFIED by me]** — I did not re-run either bench; the numbers are quoted from the commission record.

---

## 2. Session & residency design

Volmarr's scope addition (2026-11-14, in the record's words, `memory/2026-11-14.md` L1753) asked Aesir to implement "those memory use methods too for making faster for chats": (1) persistent sessions with KV reuse — stable prefix processed once, turn 2 benched for actually-evaluated prompt tokens vs turn 1; (2) stable-order memory injection under a token budget, append-stable so the cached prefix never churns (Voxta's deliberate prefix-caching design); (3) a post-history anchor slot in the serve/session layer. The Memories-vs-Understanding split stays app-layer (Rúnmál side), not engine scope. That scope became the MAP's "Memory methods for fast chats" section and slices HS-1…HS-7.

### 2.1 Persistent sessions — the idea

**Aesir as built (before HS-6):** `core/session.mojo` (SessionManager) was bookkeeping only — id, cancellation, TTL, `active_tokens`, `max_context`, and a `session_kv_offset` field that no KV storage read. The CPU facade created a fresh KVCache inside every generation call. So there was no persistence to reuse: every turn was cold. **[RECORDED, MAP audit, `memory/2026-11-14.md` L1790.]**

**The idea:** a session is a durable object that owns its KV arena for its whole lifetime. The committed token stream is the session's memory; the KV that belongs to it stays resident between turns; a new turn appends to the same stream and evaluates only the tokens that are new. The session, not the request, is the unit of KV ownership.

**Go/Ollama translation (idea level):** a `Session` struct owning a `[]KVBlock` arena (or a reference to a block-table in the runner), keyed by session id, with an explicit lifecycle — create, append, evict, destroy — and a token-count watermark (`committedLen`). The runner must not allocate a fresh KV per request when a session id is present. **[SPECULATION on the Go shape; the ownership idea is Aesir's.]**

### 2.2 Resident context — HS-6, token-level session residency

**Aesir:** HS-6 banked at `23ee96d7` (2026-11-14 ~11:00 EST): "token-level session residency — seam loss gone by construction" **[RECORDED]**. The seam finding that motivated it: resends extending past a generation seam lost ~6 tokens (HS-3 bench note, `memory/2026-11-14.md` L2015). Token-level residency means the session tracks exactly which tokens have KV committed, token by token, so a resend that straddles the boundary between prompt and generated text reuses everything up to the seam and re-evaluates only what is genuinely new — no ~6-token hole, no silent re-evaluation of the whole tail.

**HS-3 bench (the proof that residency matters):** chat surface, turn 2 reused **46 tokens**, wall **610 ms vs turn 1's 825 ms** **[PROVEN, small scale]**. The baseline disease it is measured against: Ollama-via-Voxta re-evaluating **14,712 tokens in 52.1 s** per turn **[RECORDED, MAP baseline]**. The 46-token figure is a small proof, not a large-chat proof — do not quote it as a large-context result.

**Go/Ollama translation:** keep a per-session `committedTokens []int32` (or a length + hash) alongside the KV blocks, and on each request compute the longest common prefix between the incoming token stream and the committed stream *at token granularity*, then evaluate only the suffix. The seam rule: generated tokens are committed to the session the moment they are produced, so a resend after a generation never re-evaluates them. **[SPECULATION on the Go shape.]**

### 2.3 The post-history anchor — HS-5

**Aesir:** HS-5 banked at `8f98b2a5`. The problem it solves: the character prompt (in Voxta terms, the character card / persona instruction) must survive context pressure. In the MAP audit, `native_settings`/parsers knew `system` (head) only; there was no post-history slot. HS-5's design sketch: a serve-level `post_history` from config plus a per-request override, appended at composition, **never written into stored history or the committed stream**, so prefix reuse still covers the whole history **[RECORDED, `memory/2026-11-14.md` L1790]**.

The key property is the word **unpushable**: the anchor sits *after* the history in the composed prompt, so it is the last thing the model sees before generating, and it cannot be pushed out by history growth — because it is not part of history at all. It is re-appended fresh at every composition. The same pattern was set in Voxta the same morning (2026-11-14) and appears in Rúnmál's findings as "a post-history slot in the card format — the same unpushable-anchor pattern set in Voxta this morning" **[RECORDED, L1725]**.

**Why "after" matters (the idea, not the code):** a system prompt at the head is stable for prefix caching but is the *farthest* thing from the generation point and the first thing a truncating window discards in some designs; an anchor at the tail is the *nearest* thing to generation and, because it is composed rather than stored, it is immune to the window entirely. The cost is that it is re-evaluated every turn (it sits after the reusable prefix) — a deliberate trade: a short, fixed tail re-evaluated per turn in exchange for an instruction that can never be lost.

**Go/Ollama translation:** a `PostHistory string` (or `[]Message`) field on the session/request config, rendered *after* the history block at prompt-assembly time, excluded from the token stream that is committed to the session's KV and excluded from the stored transcript. The prompt assembler must treat it as a composed-only block. The token cost is `len(anchorTokens)` evaluated per turn — budget it explicitly. **[SPECULATION on the Go shape; the unpushable property is Aesir's/HS-5's.]**

### 2.4 What the serve advertises

After HS-1…HS-7, the testable serve reported `exact_prefix_reuse`, `session_residency`, and `memory_injection` all true **[RECORDED]**. For Ollama work, the transferable idea is the *advertisement itself*: a serve endpoint that truthfully reports which memory properties hold for a session, so a client (Voxta, Rúnmál, or a test harness) can rely on them instead of assuming them. **[SPECULATION — the flag idea, not a recorded Aesir API contract; the three flag names are recorded.]**

---

## 3. Prefix memory

### 3.1 Exact-prefix reuse — the base mechanism

**Aesir:** `core/prompt_prefix.mojo`, `reusable_prompt_prefix()` — the longest exact token prefix; the final token is always recomputed **[RECORDED]**. Wired end-to-end in the Llama3 CUDA session: `serve reset()` copies the committed token stream into `cached_tokens` and leaves KV in place; the next turn skips evaluation of reused positions and counts them in `reused_prompt_tokens`; proven by `tests/test_cuda_prompt_prefix.mojo` (turn 2 reuses `prompt_tokens − 1`); the serve advertises `exact_prefix_reuse`, on by default **[PROVEN, CUDA session]**.

The "final token always recomputed" rule is the subtle part: the last token's KV is not trusted across the turn boundary (it is the position the next token is conditioned on, and its KV is entangled with the generation that followed). Recomputing one token per turn is the price of exactness. **[RECORDED as the rule; the rationale in the previous sentence is my reading — SPECULATION, but the conservative kind: it is the only reading consistent with "turn 2 reuses prompt_tokens − 1".]**

**Before HS-4, the gap:** Gemma4's session had NO prefix cache — bookkeeping + `reset()` only, every turn cold. This mattered because gemma4-e2b was the first model Voxta would meet. HS-4 (`5e5738fe`) gave Gemma4 a prefix cache **[RECORDED]**.

**Go/Ollama translation:** a `reusedPromptTokens` counter on every response (evaluated = `prompt_tokens − reused_prompt_tokens`), computed from the longest exact token-prefix match against the session's committed stream, with the last committed token always re-evaluated. The counter is the observable: without it, prefix reuse is a claim, not a measurement. **[SPECULATION on the Go shape; the counter idea is Aesir's — its responses already reported `prompt_tokens` + prefill/decode timings, so the metric needed no new instrumentation.]**

### 3.2 Snapshot-based prefix reuse for hybrid models — Q35-5

This is the most original idea in the dossier, and the one most likely to be misunderstood. It exists because the 27B is a **hybrid** model, and hybrid state is not a KV cache.

**The 27B's architecture (real-file header census, QWEN35 Phase 1):** architecture `qwen35` — a HYBRID: **64 blocks, hidden 5120, FFN 17408, 24 heads / 4 KV heads, head dim 256, ctx 262144**; most layers recurrent Gated-DeltaNet SSM (conv + recurrent state), full attention only at intervals, partial rotary (64 of 256) **[RECORDED, `memory/2026-11-14.md` L2141]**. Real geometry corrected during recon: qkv width **10240** vs the coded `3*inner = 18432`; recurrence loops **16 group heads** instead of 48 v-heads; all SSM metadata present (**851 tensors**) **[RECORDED, L2143]**.

**The problem:** a recurrent (SSM) layer's state is a fixed-size recurrent state vector plus a convolution state, not a per-token KV list. You cannot "reuse a prefix" of an SSM by keeping old KVs — there are no old KVs for those layers. The state after token *n* is a single opaque vector that summarises the whole prefix. If you destroy the session, the summary is gone, and the only way back is re-running the whole prefix.

**Q35-5's answer — prefix snapshots:** snapshot the hybrid state at a prefix boundary and restore it instead of re-running. Banked at `88c71564` (merged into `yrsa/qwen35-40b` at `9948e957`); `main` untouched at `31ab9363`; MemAvailable at close ≈27.7 GB **[RECORDED, `memory/2026-11-14.md` L2291]**.

**Numbers [PROVEN, as recorded]:**
- Snapshot restores are **bit-exact**: s/conv/KV diffs **0.0**.
- A stateless resend reused **72 of 90 tokens** via snapshots after residency was destroyed.
- Store bound: **4 snapshots per session**.
- Size: 27B ≈ **158.9 MB SSM+conv per snapshot + KV** (boundary KV for the full-attention layers is additional; the record gives the SSM+conv figure and names KV as the plus-term without a separate byte count — do not quote a total).

**What snapshot semantics a Go implementation would need** (translated, **[SPECULATION]** on the Go side, grounded in the recorded Q35-5 properties):
1. **State is opaque and whole.** A snapshot is not a list of tokens; it is the recurrent state vector(s) + conv state + the boundary KV for the attention layers, captured at one prefix length. The Go type is a `Snapshot{ PrefixLen int; SSMState []byte; ConvState []byte; BoundaryKV KVBlock }`, serialisable as a byte blob with a header (model id, prefix length, state hash).
2. **Restore is bit-exact or it is not a snapshot.** The acceptance test is diff 0.0 on restore vs the live state — not "close", not "perplexity-similar". Any Go snapshot store must carry that test.
3. **Bounded store, explicit eviction.** 4 snapshots/session in Aesir. A Go store needs the same bound and a named eviction rule (e.g. keep the longest prefix + the most recent; drop the rest) — otherwise snapshot storage is an unbounded memory leak dressed as a cache.
4. **Snapshots are taken at stable boundaries, not every token.** The useful boundaries are the ends of stable blocks (system prompt, character card, long lore) — the same boundaries HS-7's stable-order injection defines. Snapshotting every token would cost more than it saves.
5. **A snapshot is keyed by the exact token prefix it summarises.** Restore is only valid if the incoming prefix is token-identical to the snapshotted prefix. A hash of the token stream (or the stream itself, stored alongside) is the key; a near-match is a miss, not a restore.
6. **Stateless resend is the fallback the snapshot exists for.** The recorded win — 72 of 90 tokens reused *after residency was destroyed* — is the point: snapshots let a stateless client (or a restarted server) skip re-running most of a long stable prefix. That is directly the Ollama/Voxta disease (see §7).

### 3.3 Stable-order injection — HS-7

**Aesir:** HS-7 banked at `fd53cc8c`. Before it, the serve injected only the system block (stable by construction); there was no server-side recall. HS-7's contract: **fixed order, budgeted whole-block admission, per-turn reuse counters logged** — drawing on Voxta's stable-order rendering and SillyTavern's %-of-context whole-entry admission **[RECORDED, L1790, L1792]**.

The idea in one sentence: memory injected into a prompt must arrive in the same order every turn, in whole blocks or not at all, under a token budget — because any reordering or partial admission changes the token prefix and destroys the KV reuse that §3.1 built. "Append-stable so the cached prefix never churns" (Volmarr's scope words, L1753).

**Go/Ollama translation:** a memory-injection stage that (a) sorts injected blocks by a fixed key (priority, then stable id — never by recency or retrieval score order, which changes turn to turn); (b) admits whole blocks only, against a %-of-context budget, dropping the lowest-priority whole block when over budget rather than truncating a block mid-way; (c) logs per-turn reuse counters so churn is visible. **[SPECULATION on the Go shape; the contract terms are HS-7's.]**

---

## 4. KV & memory design choices in Aesir

### 4.1 The Q8_0-resident weight configuration

The gate serve for the 27B runs in the **Q8_0-resident CPU configuration**: weights held resident in Q8_0 (packed) form, dequantised as needed, rather than materialised as F16. Health reports `weight_load_mode q8_0_resident` **[RECORDED]**.

Why it exists: the F16 path peaks at ~57 GB RSS for the 27B (and ~83 GB estimated for the 40B). The Q8_0-resident path was built as Q35-3r (banked at `efa400d6`) precisely so the serve could coexist with Volmarr's programs in normal use — the parent gate's measured-fit rule then passed for the 27B F16 path and the 40B F16 estimate, but the *serve config* still needed the resident path **[RECORDED, L2342]**. The 27B Q8_0 file itself is ~28.6 GB (implied by the QC product being 56.7% of Q8_0 at 16,223,236,576 B — see §5; the 28.6 GB figure is the campaign's own "16.2 GB instead of 28.6 GB" wording in MEMORY.md).

**Design choice, stated plainly:** residency is a *weight* choice as well as a *KV* choice. Holding weights packed and dequantising on use trades per-step compute for memory headroom. That trade is only a win if the dequantisation is done once per use, not once per token — which is exactly the QS-0 lesson below.

**Go/Ollama translation:** a weight-load mode flag (`resident-packed` vs `materialised-f16`) with a measured-fit gate: the mode is chosen by measured peak RSS against the machine's available memory, not by preference. Ollama already loads quantised weights; the transferable part is the *gate* — a recorded, measured fit rule that decides the mode per model per machine, and a health endpoint that reports which mode is actually live. **[SPECULATION on the Go shape.]**

### 4.2 The per-step dequant lesson — QS-0 (cautionary tale)

**The finding, as given in the OR-4 brief:** re-unpacking (dequantising) weights every step made the prompt path **~35× slower**. This is the QS-0 finding: the CPU/HIP indictments in `QS-0-BASELINE.md` (baseline table + CPU/HIP indictments + slice order, commit `bad65106`).

**[NOT VERIFIED from the allowed sources I could read.]** I searched `memory/2026-11-14.md`, `memory/2026-11-15.md`, and the CURRENT_STATE board for the 35× figure and for a QS-0 per-step dequant number: the board and logs name the QS-0 baseline commit and its contents (baseline table, CPU/HIP indictments, slice order) but do not reproduce the 35× number or the per-step dequant measurement in the text available on the VM. The figure comes from the task brief itself. I therefore report it as **the brief's QS-0 finding, not independently re-verified by me** — the coordinator should confirm it against `QS-0-BASELINE.md` on purpleraider (branch `yrsa/hip-serve`, commit `bad65106`) before quoting it outward.

**The design tale, as it stands (numbers as briefed, mechanism as reasoned):** if a packed weight is unpacked once per decode step — or once per prompt token — the unpack cost multiplies by the sequence length and dominates everything else. The prompt path, which processes many tokens, pays it many times over; a ~35× slowdown is the shape of that mistake, not a marginal inefficiency. The fix direction is the one Aesir's own history already proved in the GEMM line (see §6): **dequantise once, reuse the unpacked form for the whole operation** — decode-once, cache the unpacked weights for the duration of the step/batch, or keep the hot weights resident in unpacked form and pay the memory for it. The Q8_0-resident config (§4.1) only works if it obeys this rule; a resident-packed config that re-unpacks per token is worse than either alternative.

**Go/Ollama translation:** audit any quantised-weight path for *where* dequantisation happens in the loop nest. The rule to carry over: dequantisation belongs outside the per-token loop (once per layer per forward pass, at most), never inside it. A regression test for this is cheap and decisive: time the prompt path with a long prompt before and after moving the dequant; a 35×-shaped cliff is the signature of the bug, and its absence is the proof of the fix. **[SPECULATION on the Go test; the 35× figure is as briefed, unverified by me.]**

### 4.3 Other memory choices worth carrying

- **Mmap + protected model store:** weights mapped via mmap into the pre-allocated MimirWell; models imported into a protected store and verified (`aesir doctor`, store verification). The idea: the model file is the memory; do not copy it into a second heap before using it. **[RECORDED from the repo's loader description.]**
- **Pre-allocated arenas, fixed-capacity KVCache:** MimirWell is pre-allocated; the KVCache has a fixed capacity. The idea: bounded memory by construction — a session cannot grow the cache past its arena, so memory pressure is a visible, countable event (eviction), not a slow leak. **[RECORDED from the repo's component description; the "visible event" reading is SPECULATION.]**
- **Fences as a design tool:** the serve runs under explicit memory fences (aesir-gate fenced 24G/32G for the 3B, then 48G/64G for the 27B; a live HIP session made "the whole GTT pool read consumed", MemAvailable 124 GB → ~27 GB, recovering on stop — `memory/2026-11-14.md` L2015). The transferable idea: a serve process should declare its memory budget up front and be measured against it, not discovered by the OOM killer. **[RECORDED numbers; the "design tool" framing is SPECULATION.]**
- **Session KV offset bookkeeping:** even the bookkeeping-only SessionManager carried a `session_kv_offset` field — the *intention* of per-session KV placement was in the design before the storage was. For Ollama, the lesson is to put the offset/length fields in the session struct first; the arena follows the bookkeeping, not the other way round. **[RECORDED field name; the lesson is SPECULATION.]**

---

## 5. The compression school (QC-0…QC-7)

**Commission:** Volmarr, 2026-11-14: "work on teaching it how to compress the models too" — quantise + write valid GGUF. Aesir had read the whole quant ladder since the model-wave era; this was the reverse direction. Graded compressed-vs-source by teacher-forcing rank + logit gap on RAW prompts; small-model proof first, then the heretics. A Q4_K_M 27B at ≈15–16 GB was named as the strategic prize for residency **[RECORDED, `memory/2026-11-14.md` L2342-era commission note]**.

**What was built:** `aesir quantize` — a GGUF writer plus a streaming writer, with Q8_0 and Q4_K/Q6_K packers **[RECORDED]**. QC-0 (recon + slice plan, banked `bc833bb0`, closure `d03cf139`, 2026-11-14 13:29 EST) named the Q8_1 block-size bug as next work. QC-7 banked 2026-11-14 18:01 EST at `b388e188`; the campaign closed at the Q35-7 head `5506180d`.

### 5.1 Verdicts as recorded

| Product | Verdict | Source |
|---|---|---|
| stories260K → Q8_0 | **FAITHFUL** — cross-proven in llama.cpp | `memory/2026-11-14.md` L2874 |
| Gemma4-E2B → Q8_0 | **NOT FAITHFUL by one record — 98.73%** (in-band percentage; one record short of the gate) | L2874 |
| stories → Q4_K_M | **DIVERGENT** — the flat-tiling lesson (see §5.2) | L2874 |
| 27B → Q4_K_M | **DIVERGENT by the strict gate at 99.49% in-band** — one named record, **p5 pos22**, which is the searched-fit packer's target. Product exists on the vault: **16,223,236,576 B (56.7% of Q8_0)**, admitted by all four readers. | L2874; CURRENT_STATE board |
| 27B Q4_K_M, MEMORY.md wording | "accepted by every reader, but is not yet graded faithful (99.49% in band, one named record short)"; "an Aesir-packed 27B exists on the vault at 16.2 GB instead of 28.6 GB" | MEMORY.md |

**Read the verdicts carefully:** "admitted by all four readers" is not "faithful". The gate is strict and record-level: one named record (p5 pos22) failing is enough to hold the DIVERGENT verdict. That discipline — a named failing record, not an averaged score — is itself the transferable idea (§6).

### 5.2 The flat-tiling lesson and the searched-fit packer

- **Flat tiling (stories Q4_K_M, DIVERGENT):** the first Q4_K_M packer tiled blocks flatly, and the product diverged. The lesson recorded is that *how* blocks are laid out when packing matters as much as the quantisation maths — a packer that ignores the block structure the dequantiser expects produces a file that reads fine and computes wrong. **[RECORDED as "flat-tiling lesson"; the mechanism in the previous sentence is my reading — SPECULATION.]**
- **Searched-fit packing:** the response was a packer that *searches* for a fitting layout rather than assuming one — and the one record it still missed (p5 pos22) is named as its target for the next round (QS-3: "packed Q4_K_M residency + searched-fit packer to FAITHFUL"). The method is iterative and evidence-led: pack, grade record-by-record, name the failing record, adjust the search. **[RECORDED as the named next work; the characterisation is SPECULATION.]**

### 5.3 What a Go quantizer could adopt

1. **Write, don't just read.** A Go quantizer that can emit valid GGUF (Q8_0 first — the faithful rung — then Q4_K/Q6_K) turns Ollama from a consumer of quantised models into a producer. The proof standard is Aesir's: the product must be admitted by independent readers (llama.cpp cross-proof for Q8_0) *and* pass the strict record-level gate.
2. **Grade record-by-record, name the failure.** Teacher-forcing rank + logit gap per record (§6); a product is FAITHFUL only when every record is in-band. One named record (p5 pos22) is a better deliverable than a 99.49% average — it tells the next packer iteration exactly what to fix.
3. **Q8_0 first, K-quants second.** Q8_0 was faithful on stories260K; Q4_K_M diverged on the same model. The ladder order is evidence, not preference: ship the faithful rung, then climb.
4. **Size the prize honestly.** 16,223,236,576 B is 56.7% of the 28.6 GB Q8_0 — a real residency win (the 27B in ~16 GB instead of ~28.6 GB) that is *still* DIVERGENT. Size and fidelity are separate verdicts; never let one stand in for the other.
5. **Streaming writer.** Aesir built a streaming GGUF writer, not just an in-memory one — the 27B product is 16 GB, and a writer that needs the whole model in RAM to emit it would defeat the purpose on a constrained machine. **[RECORDED that a streaming writer exists; the rationale is SPECULATION.]**

---

## 6. Kernel / quantization ideas from the wider Aesir campaigns

### 6.1 The SIMD decode-width lesson

From the model-wave era (AGENTS.md, "Project Aesir wave lessons — Part II retrospective", S-053; and the wave records):

- **Scalar decode is the cost in single-row GEMMs.** IQ's scalar 256-lane dequant was ~90% of IQ cost; S-030's **width-16 SIMD decode** (commit `7859deea`) gave **~3× with numerics proven unchanged three ways**. Batched prefill bought only ~1.4× — decode is the lever. **[RECORDED, AGENTS.md.]**
- The same scalar pocket in `gemm_q8_0` is the proven Coder-7B Q8_0 speed defect (road S-150); never cite Q8_0 walls as a baseline until fixed. **[RECORDED, AGENTS.md.]**
- Wave crown result: Q8_0 decode-once SIMD fast path, Coder-3B crown **776.88 s → 269.61 s, 2.88×** (wave branch head `27f0a41c`) **[RECORDED, `memory/2026-10-27.md`].**
- The principle generalises beyond Mojo: in a decode-bound (single-token-at-a-time) workload, the dequantisation loop's *width* is the bottleneck, not the matmul. Widen the decode (SIMD lanes, vectorised unpack) before touching anything else, and prove numerics unchanged (three independent checks in S-030's case).

**Go translation:** in Go, the equivalent lever is vectorised unpacking via `math/bits` / SIMD-friendly layouts or cgo/assembly only where the profiler proves the scalar loop dominates — and the *measurement* discipline transfers directly: profile first, widen the decode, re-grade numerics. Do not reach for GPU offload to fix a scalar decode loop. **[SPECULATION on the Go mechanism; the lesson is Aesir's.]**

### 6.2 IQ-lineage grading discipline — the evaluation method

This is the most valuable transferable idea in the dossier, because it is a *method*, not a feature.

**Raw-oracle discipline (AGENTS.md, S-053):**
- Never judge Aesir against `llama-cli --single-turn` — it template-renders the prompt, a different input; that trap manufactured a false "root cause #2" in the Zen wave era.
- Grade with **teacher-forcing rank + logit gap on the raw prompt**, and record the oracle backend per row. CPU engine vs CPU comparator only.
- **Near-tie band: rank ≤ 2 with sub-logit gap = faithful.** A result inside the band is faithful; outside it, it is not. There is no partial credit by averaging.
- **IQ1_S token-exact parity is NOT PROVEN BY CONSTRUCTION** — ggml's own CPU vs CUDA IQ1_S kernels disagree with each other (S-029); grade coherence (road S-095), never demand token-exactness where the reference itself disagrees with itself.

**Comparator artifacts are a verdict class:** template rendering, BOS rendering, backend mismatch, and prompt-boundary step-0 effects each fake divergences that are in neither engine's maths. Check the comparator before suspecting the engine. **[RECORDED.]**

**CUDA-visible ≠ GPU run:** with a CUDA device visible, the counted run HANGS at the F009 case (CUDAGate launch neither returns nor raises on the RTX 2060, so the SIMD fallback never engages — S-050, road S-054/GPU line). Suites run `CUDA_VISIBLE_DEVICES=` and state it explicitly; a run at VRAM 1 MiB is a CPU run and is recorded as one. **[RECORDED.]**

**Launch method fakes failures:** a backgrounded battery launch inherits SIGINT ignored, breaking interruption tests (S-050 step 22 passed 9/9 once signal disposition was default). Check harness launch/signals before filing a code defect. **[RECORDED.]**

**Trust only disk:** wave-era worker reports were fabricated more than once — every number from files/git objects/catalog listings, every model sha256-pinned before running. **[RECORDED.]**

**Translated into evaluation method for our Ollama work:**
1. Grade Ollama changes against a raw-prompt teacher-forcing oracle (rank + logit gap per record), never against a templated CLI invocation of the same model.
2. Use the near-tie band (rank ≤ 2, sub-logit gap) as the pass/fail line, per record, with the oracle backend recorded per row.
3. Name the comparator artifacts first: if a divergence appears, check template/BOS/backend/step-0 before blaming the Ollama change.
4. State the accelerator visibility of every run explicitly (`CUDA_VISIBLE_DEVICES=`, VRAM observed); a run that did not actually touch the accelerator is labelled a CPU run.
5. Every number in a verdict comes from a file, a log, or a git object — never from a worker's summary alone — and every model is sha256-pinned before the run.
6. Every divergence gets a written verdict class or a named road with re-open criteria — no unexplained rows (S-048 court pattern). **[RECORDED as the Aesir rule; the Ollama application is SPECULATION.]**

### 6.3 Other campaign disciplines that transfer

- **Bank incrementally:** explicit-refspec push + ls-remote verification per slice makes each slice a `behind_by=0` audit, not a merge event (S-051). For Ollama work: bank each experiment slice with its evidence, verify the remote moved, never batch-merge blind.
- **Accelerator-first law (Volmarr, 2026-10-27, standing, all Aesir work):** most of a model runs on the accelerator; CPU only (1) as spillover for what exceeds VRAM and (2) as an assist that measurably, massively speeds up the whole run. A CPU-carried setup is a defect to report with numbers. Tri-device order: NPU, then GPU, then CPU. **[RECORDED.]** For Ollama: a CPU-only run of a model that fits the accelerator is a defect report, not a baseline.
- **Machine decoupling (standing):** size/quant rung sweeps live on purplelongship, never the VM; VM inference only behind MemAvailable > 5,500 MB; one heavy run at a time per box; walls measured under contention are not baselines. **[RECORDED.]**

---

## 7. Translation table — each Aesir idea → Go/Ollama → the Ollama weakness it answers

**A note on the right-hand column:** the three Ollama weaknesses named in the OR-4 brief — (a) two-layer silent truncation, (b) slot-partitioned KV, (c) stateless API — are taken from the brief as the coordinator's framing. **[NOT VERIFIED by me]** — I did not audit Ollama's code in this slice, and no Ollama source was among my allowed sources. The mappings below are therefore my reasoned translations of Aesir ideas onto the brief's stated weaknesses, marked **[SPECULATION]** where they assert something about Ollama's internals.

| # | Aesir idea | What it becomes in Go/Ollama (data structures, lifecycle, cost) | Ollama weakness it answers |
|---|---|---|---|
| T1 | Exact-prefix reuse (§3.1) | `Session{ Committed []int32; KV KVBlocks; Reused int }`; per request, longest exact token-prefix match, last token always re-evaluated; response carries `reused_prompt_tokens`; evaluated = `prompt_tokens − reused`. Lifecycle: KV lives with the session, not the request. Cost: one token re-evaluated per turn; memory = one KV arena per live session. | (c) Stateless API — turns stop re-paying the full prompt. Also the recorded disease: 14,712 tokens re-evaluated in 52.1 s per turn. |
| T2 | Token-level session residency, HS-6 (§2.2) | Per-session committed-token watermark, updated token-by-token as generation proceeds; resends straddling the prompt/generation seam reuse up to the watermark. Cost: a watermark + a hash per session; no extra memory beyond the arena. | (c) Stateless API — and specifically the ~6-token seam loss: a resend after generation must not lose or re-pay the seam. |
| T3 | Post-history anchor, HS-5 (§2.3) | `PostHistory` block on the session/request config, composed *after* history at assembly time, never stored in history or committed to KV. Cost: `len(anchorTokens)` evaluated every turn; the anchor must be short and fixed. | (a) Two-layer silent truncation — the character instruction cannot be silently discarded by a truncating window, because it is not in the window at all. |
| T4 | Stable-order injection, HS-7 (§3.3) | Memory-injection stage: fixed sort key (priority, then stable id); whole-block admission against a %-of-context budget; per-turn reuse counters logged. Cost: the budget itself; a dropped block is dropped whole, never truncated. | (a) Two-layer silent truncation — truncation, when it must happen, happens at whole-block granularity under a budget, visibly, instead of silently mid-block. Also protects T1: stable order keeps the prefix stable, so reuse survives. |
| T5 | Hybrid prefix snapshots, Q35-5 (§3.2) | `Snapshot{ PrefixLen int; PrefixHash [32]byte; SSMState, ConvState, BoundaryKV []byte }`; bounded store (4/session in Aesir) with a named eviction rule; restore acceptance = diff 0.0. Cost: ~158.9 MB SSM+conv per snapshot for a 27B-class hybrid + boundary KV. | (c) Stateless API — a stateless resend (or a restarted server) reuses 72 of 90 tokens in the recorded case instead of re-running the prefix. Also (b): snapshot state is per-session and whole, not partitioned across slots. |
| T6 | Q8_0-resident weights + measured-fit gate (§4.1) | Weight-load mode flag (`resident-packed` vs `materialised`); mode chosen by measured peak RSS vs available memory; health endpoint reports the live mode. Cost: memory headroom vs per-step dequant compute (see T7). | (b) Slot-partitioned KV — residency is a property of the *session*, decided by a measured fit rule, not of whichever slot a request happens to land in. |
| T7 | Per-step dequant lesson, QS-0 (§4.2) | Dequantisation outside the per-token loop (once per layer per forward pass, at most); a regression test timing the prompt path on a long prompt. Cost of getting it wrong: ~35× on the prompt path **[as briefed, NOT VERIFIED by me — see §4.2]**. | (c) in its performance form: a stateless API that re-evaluates the prompt every turn *and* re-unpacks weights every token pays both taxes at once. |
| T8 | GGUF writing — `aesir quantize` (§5) | A Go GGUF writer + streaming writer; Q8_0 first (the faithful rung), then Q4_K/Q6_K with searched-fit packing; record-level grading (rank + logit gap, near-tie band) as the acceptance gate; one named failing record blocks FAITHFUL. Cost: the writer must stream (a 16 GB product cannot be buffered whole on a constrained machine). | (b) Slot-partitioned KV, indirectly — a 16.2 GB Q4_K_M 27B (56.7% of Q8_0) is what makes per-session residency affordable at all; without a faithful packed form, residency is a memory luxury. |
| T9 | Raw-oracle grading discipline (§6.2) | A grading harness: raw prompts, teacher-forcing rank + logit gap per record, near-tie band (rank ≤ 2, sub-logit gap) = faithful, oracle backend recorded per row, comparator artifacts checked before the engine. Cost: one harness, run before any performance claim. | All three — a silent truncation, a slot-partition bug, or a stateless re-evaluation all show up as record-level divergences under this harness, with a named verdict class, instead of as vague "it got worse". |
| T10 | SIMD decode width (§6.1) | Profile the decode loop; widen the dequant (vectorised unpack) and prove numerics unchanged three ways; ~3× recorded for width-16 SIMD decode in Aesir. Cost: the widening work; the proof burden is the point. | (c) in its performance form — decode is the lever in single-token generation; a stateless API pays the decode cost on every turn, so decode speed is multiplied by the number of turns. |
| T11 | Serve truthfully advertises memory properties (§2.4) | The serve reports `exact_prefix_reuse`, `session_residency`, `memory_injection` (or Go equivalents) per session, truthfully. Cost: three booleans and the discipline not to set them until the tests pass. | (a) + (c) — a client can rely on the properties instead of assuming them, and a test can fail the serve when a property it claims does not hold. |

---

## 8. What NOT to import

Named honestly. Each of these is a real Aesir strength that depends on Mojo/bare-metal control and would fight Go's runtime and garbage collector — importing the *shape* of it would produce a worse Ollama, not a better one.

1. **Bare-metal memory control (MimirWell, pre-allocated arenas, mmap-as-the-model).** Aesir maps weights via mmap into a pre-allocated well and manages fixed-capacity KV arenas by hand, with no allocator in the path. In Go, the runtime owns the heap; fighting it with manual arenas (e.g. `unsafe` slab allocators for KV) buys fragmentation bugs and GC interaction hazards for a benefit the Go runtime already approximates with pooling. **Import the boundedness (fixed capacities, explicit eviction), not the manual allocation.**
2. **Mojo ownership / zero-copy vector lifetimes.** Aesir's `Hamr`-style ownership discipline and zero-copy stores assume a compiler that tracks lifetimes without a collector. Go's answer is different by design (escape analysis, `sync.Pool`, explicit `[]byte` reuse). Translating Mojo ownership annotations into Go produces either no-ops or `unsafe` — both are worse than writing idiomatic Go.
3. **Hand-written SIMD kernels as the first resort (Nidavellir).** Aesir hammers its own SIMD kernels because it has no libraries. Go has a different stack: the Ollama runner already delegates compute to ggml (C/CUDA) under the Go API. Rewriting decode kernels in Go (or assembly) before profiling the ggml path would duplicate a solved layer and fork the maintenance burden. **Import the profiling discipline and the decode-width lesson (§6.1), not the kernels.**
4. **The HIP/CUDA session implementations themselves.** HS-1's HIP session and the Llama3 CUDA session are implementations of the `ControlledTextSession` contract over specific accelerators in Mojo. Ollama's accelerator path is ggml + its own scheduler. The contract *idea* (a session interface with prefix/residency properties) transfers; the Mojo session code does not.
5. **Hailo-10 NPU work.** There is nothing to import: text generation on Hailo was never achieved in Aesir (see §1.2). Any Ollama NPU idea must come from its own line, not from Aesir.
6. **The `aesir-gate` systemd/fence deployment shape.** Fences (24G/32G, 48G/64G), the transient-unit relight, the full-GGUF-path `model` field quirk — these are deployment facts of one machine (purpleraider) and one campaign, not design ideas. Do not copy the fence numbers or the 404-unless-full-path behaviour into Ollama; copy the *measured-fit gate* idea (§4.1) and leave the numbers on purpleraider.
7. **F16-materialised loading as a default.** The 27B F16 path peaks at ~57 GB RSS; Aesir needed a sized fence exception to run it at all. In Go, a loader that materialises F16 by default would reproduce the same cliff on any machine without 128 GB unified memory. The resident-packed path is the default to carry over, with F16 as a fenced, measured exception.
8. **"Token-exact" as a grading demand for IQ quants.** IQ1_S token-exact parity is not proven by construction — ggml's own CPU vs CUDA kernels disagree (S-029). Demanding token-exactness from an Ollama IQ path would grade the harness, not the model. Grade coherence (§6.2).

---

## Appendix — record index (where each number came from)

- **127/216, main `31ab9363`, A-127 2026-11-14 ~07:31 EST** — CURRENT_STATE board, 2026-11-15 01:03 EST.
- **HS-1…HS-7 complete; Grand Proving 901/2/2 of 905; HS-4 `5e5738fe`, HS-5 `8f98b2a5`, HS-6 `23ee96d7`, HS-7 `fd53cc8c`, closing `2a24dfd4`** — `memory/2026-11-14.md` L2135, L2140.
- **MAP audit (prefix reuse in one place; Gemma4 no cache; SessionManager bookkeeping-only; anchor absent; stable-order contract); baseline 14,712 tokens / 52.1 s; MAP.md 9,242 B, sha256 `a5dd5aa7…b2d2`** — `memory/2026-11-14.md` L1789–L1792.
- **HS-3 bench: turn 2 reused 46 tokens, 610 ms vs 825 ms; seam loss ~6 tokens; MemAvailable 124 GB → ~27 GB under a live HIP session** — `memory/2026-11-14.md` L2015.
- **27B architecture: 64 blocks, hidden 5120, FFN 17408, 24 heads / 4 KV heads, head dim 256, ctx 262144; qkv 10240 vs coded 18432; 16 group heads vs 48 v-heads; 851 tensors** — `memory/2026-11-14.md` L2141, L2143.
- **Q35-5: bit-exact restores (diffs 0.0); 72 of 90 tokens reused statelessly; 4 snapshots/session; ~158.9 MB SSM+conv each + KV; banked `88c71564`, merged `9948e957`** — `memory/2026-11-14.md` L2291.
- **Q35-3b: 198/198 near-tie, generation token-identical; Q35-6 HIP 71/71 rank 1 gap 0.0, decode ~0.07–0.09 tok/s; full suite 900/3/2 of 905** — `memory/2026-11-14.md` L2873; CURRENT_STATE board.
- **27B serve: `127.0.0.1:18434`, Q8_0-resident, fence 48G/64G, `qwen35-27B` / `q8_0_resident`** — CURRENT_STATE board; `memory/2026-11-14.md` L2871–L2872.
- **QC verdicts; 27B Q4_K_M 16,223,236,576 B, 56.7% of Q8_0, 99.49% in-band, p5 pos22; stories260K Q8_0 FAITHFUL; E2B Q8_0 98.73%; stories Q4_K_M DIVERGENT** — `memory/2026-11-14.md` L2874; MEMORY.md.
- **QS commission yardsticks: Ollama Q8 7.65 tok/s, Q4 12.11 tok/s; Aesir HIP decode ~0.07–0.09; QS-0 commits `cb6ad1e` / `cff944fc` / `92180bf4` / `bad65106`** — `memory/2026-11-14.md` L2960, L2977, L3151; `memory/2026-11-15.md` L26; CURRENT_STATE board.
- **QS-0 ~35× per-step dequant finding** — OR-4 task brief; **NOT re-verified from the allowed VM records** (see §4.2). Confirm against `QS-0-BASELINE.md` (branch `yrsa/hip-serve`, commit `bad65106`, on purpleraider) before quoting outward.
- **SIMD width-16 decode ~3× (`7859deea`); scalar decode ~90% of IQ cost; Coder-3B crown 776.88 s → 269.61 s, 2.88×; raw-oracle / near-tie / comparator-artifact / trust-only-disk disciplines** — AGENTS.md (Aesir Part II retrospective, S-053); `memory/2026-10-27.md`.
- **Ollama weaknesses (two-layer silent truncation; slot-partitioned KV; stateless API)** — OR-4 task brief framing; **NOT verified by me** against Ollama source in this slice (see §7 note).
- **Repo self-description (README capabilities + limits; ARCHITECTURE.md Slice-6 warning)** — local clone `~/workspace/RuneForgeAI-Project-Aesir/README.md`, `ARCHITECTURE.md`.
- **Z13 roadmap shape (216 slices, 24 waves of 9, 9 parts) and 2026-11-11 hardware truth** — `~/workspace/goals/aesir-z13-strix-halo-forge/files/AESIR_Z13_MASSIVE_ROADMAP.md`, `WAVE_PLAN.md`.

*End of dossier — OR-4, 2026-11-15.*
