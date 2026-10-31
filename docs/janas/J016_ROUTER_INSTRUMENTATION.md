# J-016 — Router Instrumentation, Measured

**Slice:** J-016 (Part II — Models Bigger Than Memory), Project Aesir Janas clean-room road.
**Roadmap text:** "Aesir logs, per token, which experts the router chooses (offline analysis build only): hit distribution, reuse distance, working-set size over real prompts. The measurements every cache decision below stands on."

**Measured:** 2026-10-31 ~02:15 EDT, on **purplelongship** (AMD Ryzen 9 4900HS, 16 threads, 39,517 MB RAM, RTX 2060 Max-Q 6 GB — GPU unused; CPU only). Machine state: **contended, stated** — the 204 road's S-087 grading run (`tf_oracle`, ~198 % CPU) was live throughout; this slice's runs were capped at 2 threads, `nice -n 10`, and never touched `~/s087`. Load average ≈ 2.0–2.9, Tctl 66 °C at start, peaking at 81.1 °C during the main run, 71.1 °C at its end. Wall times below are therefore **not baselines** — they are run records on a shared machine. VM state: MemAvailable ≈ 0.57 GB — no VM inference, per the machine-decoupling law.
**Honesty classes:** trace statistics are **MEASURED** from the named reference instrument (§3) on the named hardware — they are *not* Aesir engine output, because Aesir has no MoE code to instrument (§1). The forward's correctness evidence is **MEASURED-INDICATIVE** (coherence witnesses, §4) — no independent oracle graded this forward, and a llama.cpp cross-check is **NOT PROVEN** (no llama.cpp exists on purplelongship; §7). The in-Aesir hook specification (§2) is a design deliverable. The analyser is **PROVEN** against a labelled synthetic trace (§3.3). No Janas material was used in this slice; the clean-room law was not engaged.

---

## 1. What exists in Aesir to instrument — the tree, re-inspected

Re-inspected this slice in a fresh worktree from origin/main `caec4149b2523d71153abd41736de443bb7b11de` (ls-remote verified before branching):

- **No MoE code at all** (J-012's ledger truth, re-verified by grep over `aesir_engine/`): no router, no expert execution, no MoE architecture profile. The strings `olmoe`, `granitemoe`, `qwen2moe`, `qwen3moe` appear nowhere in the engine.
- **The one MoE surface is a refusal:** `aesir_engine/core/gemma4_profile.mojo` lines 161–162 detect `ffn_gate_inp.weight` in a model's tensor directory and raise `Error("Gemma 4 MoE is not supported by the dense CUDA path")`. Aesir today *recognises* a routed model only to refuse it.
- The GGUF loader (`PackedGGUF`) is architecture-generic (J-015 §1), so the *files* parse; nothing downstream of the loader can route.

Consequence, stated plainly: **there is no Aesir router to attach a logger to yet.** This slice therefore delivers (a) the instrumentation *design* for the MoE forward Part II builds later (§2), (b) the offline trace format + analysis tooling, proven (§3), and (c) real router traces over real prompts from a legitimate reference instrument built from the GGUF tensors themselves (§§3–5) — the measurements J-017 / J-018 / J-024 stand on, with the instrument named on every number.

## 2. The in-Aesir instrumentation design (hook specification)

For the MoE block when it is built (the streaming slices of this part), the offline instrumentation is specified as:

- **Hook point:** exactly one site — where the MoE block has computed router probabilities and chosen top-k for a token, before expert computation. The hook receives `(layer, token_position, token_id, experts[k], weights[k], margin)` where `margin = p[k-th] − p[k+1-th]` (the selection's softness, which §5.5 shows is load-bearing information, not decoration).
- **Build gating:** compiled in only under an offline-analysis flag (working name `--router-trace <path>`, off by default, refused in server mode) — the roadmap's "offline analysis build only". Zero trace code paths in a normal build.
- **Format:** the J-016 trace format implemented by this slice's tools (§3.1) — JSON Lines, one header record (model, sha256, arch, layer/expert/top-k counts, per-layer per-expert byte sizes, instrument name), one record per token, one end record. The format is deliberately engine-agnostic so traces from this slice's reference instrument and from Aesir's future MoE build analyse through the *same* tool.
- **Cost accounting:** the hook is O(top-k) integer copies per token-layer (128 per token for OLMoE-class shapes) plus buffered writes; it must never synchronise on the token path. (Cost is a design statement here, not a measurement — Aesir's MoE block does not exist to measure against.)

## 3. The tools

### 3.1 Trace format

As specified in §2 and implemented identically by the generator and the analyser: header / per-token records (`prompt_id`, `phase` = prompt|gen, `pos`, `token_id`, `layers` = top-k expert ids per layer, plus `weights` and `margins` per layer) / end. The header carries `trace_kind` (`measured` | `synthetic-validation`) and the analyser repeats that label in its output, so a validation trace can never be silently promoted to a measurement downstream.

### 3.2 The analysis tool — `j016_analyze_trace.py`

Pure-Python (stdlib only). Per trace it computes, in aggregate and per layer: expert **hit distribution** (counts, shares, entropy, dead experts, top-10); **reuse distance** (LRU stack distance over the (layer, expert) access stream, computed with a Fenwick tree, plus the token gap between successive uses of a pair); **working-set size** over sliding windows of 32 / 128 / 512 tokens (distinct (layer, expert) pairs, and bytes when the header supplies per-expert sizes); **cold vs repeated** accounting per prompt and globally; **per-token routed counts** (integrity: every token must carry exactly `n_layer` selections of `top_k` distinct in-range experts, or the tool exits 2 and refuses to analyse); and offline **LRU / LFU cache simulations** at capacities 128–4096 pairs — policy evidence for J-018 / J-024, labelled simulation-on-a-recorded-trace.

### 3.3 Analyser validation — synthetic trace (SIMULATED, by construction)

A deterministic synthetic trace (invented Zipf-like process, seed 16016; 210 tokens, 16 layers, top-8 of 64; `j016_make_synthetic_trace.py`) was generated **only** to prove the tool. The analyser's outputs on it are internally exact where exactness is checkable: cold accesses = 1024 = the full pair universe; LRU hit rate at capacity 1024 = 0.961905 = 1 − cold fraction, to all printed digits; integrity check PASS. The Fenwick-tree stack-distance rewrite (§8) reproduces the original slice-method statistics **byte-identically** on this trace. No number from the synthetic trace is a measurement of any model, and none is quoted as one anywhere in this document.

### 3.4 The reference forward — `j016_router_forward.py`

Since neither Aesir nor llama.cpp can produce OLMoE routing on purplelongship (no MoE code in Aesir; no llama.cpp binary exists on the machine — searched), the trace generator is a purpose-built forward pass implemented **from the GGUF file's own tensors**: gguf-py dequantization (the `~/j015` venv, gguf 0.19.0) + numpy 2.5.4 float32, full causal prefill, prompts processed layer-major so each weight dequantizes once. Model: OLMoE-1B-7B Q4_K_M, sha256 `8c310f1435a1222338fd2d3d974975be9cd908180b644bab0c2a94da1ac32f3f` (J-015's pin, re-verified on the device copy's directory during the run — the per-layer per-expert bytes the instrument computed from the file, [4,079,616 / 3,538,944 by layer], reproduce J-015 §3's Q6_K-down layer pattern `6644644644644666` exactly).

Method choices a reader needs in order to judge the traces:

- **Routing rule** (published OLMoE semantics): router logits from `ffn_gate_inp`, softmax, top-8, weights renormalized to sum 1; expert = `down(silu(gate(x)) · up(x))`; RoPE base 10000, NeoX rotate-half; RMSNorm eps 1e-5 — all read from the GGUF metadata where the file declares them.
- **QK-norm — an ambiguity found in the file, resolved by experiment.** The file stores a **2048-wide** `attn_q_norm` / `attn_k_norm` per layer (verified not a tiled 128-vector: tiles differ). Two readings exist: per-head RMS over 128 with the vector viewed as (16, 128), or one RMS over the full 2048-wide projection. Both were run on the prose prompt (identical everything else): **per-head** gives a flat last-token distribution (top-1 `'\n'` p = 0.086, top-5 all ≤ 0.061); **full-width** gives a decisive one (top-1 `'\n'` p = 0.226). The full-width reading was adopted for the measured trace. The two readings' *routing* differs materially — mean top-8 set overlap 47.6 %, identical sets in only 29 of 1072 token-layers — which is itself a finding: **router traces are only as good as the forward that produced them, and the forward's conventions must be pinned before traces are compared.** This experiment is recorded here so J-022's execution work re-checks it against a graded oracle rather than inheriting it on faith.
- **Tokenizer:** GPT-2 byte-level BPE rebuilt from the GGUF vocab + merges, with an ASCII-safe approximation of the file's declared `olmo` pre-tokenizer split. The file declares `add_bos_token = false`, so no BOS is added. Every prompt round-trips (`decode(encode(x)) = x`) before the forward runs; a mismatch aborts. Prompts are ASCII-only by construction, which keeps the pre-tokenizer approximation in its safe region; a canonical-tokenizer cross-check is NOT PROVEN (§7).

## 4. The run

**Prompts** (`j016_prompts.txt`, six, varied by design): prose 67 tokens · code (a merge-sort function) 100 · structured (inventory + JSON summary) 129 · numbers (arithmetic word problem) 91 · instructions (net-mending steps) 91 · technical prose (tides) 95 — **573 prompt tokens**, plus a 4-token greedy continuation of the prose prompt recorded in the trace as phase `gen` — **577 tokens, 73,856 router accesses** total. Main run wall 259.9 s at 2 threads under the contention stated above (a run record, not a benchmark).

**Coherence witnesses** (MEASURED-INDICATIVE — the forward behaving like the model, not a graded proof): last-token top-1 predictions are the natural continuation for every prompt type — prose `'\n'` p = 0.226; code `'\n'` p = 0.561; structured `'\n'` p = 0.344 with `'-'` next at 0.159 (another inventory line); numbers `'\n'` p = 0.610; instructions `' The'` p = 0.172; technical `'\n'` p = 0.157 — and the greedy continuation of the prose prompt is fluent: `"\n\nThe question"`. No NaNs; the analyser's integrity check passes on all 577 tokens.

## 5. Measurements (OLMoE-1B-7B Q4_K_M, 577 tokens)

### 5.1 Hit distribution — there is no hot set

Aggregate entropy **5.9836 bits of a 6.0-bit maximum**: routing is close to uniform, exactly what OLMoE's load-balancing training aims for. All 64 experts are hit in **every** layer (per-layer distinct = 64, dead = 0, per-layer entropy 5.4349–5.8502 bits). The single hottest expert overall (expert 6) takes 1,749 of 73,856 accesses = **2.37 %**; the top 10 together take under a fifth. A token touches a mean of **56.5 distinct expert ids** (of 64) somewhere across its 16 layers (min 48, max 61).

### 5.2 Working set — it saturates almost immediately

| Window | Distinct (layer, expert) pairs (mean / max) | Expert bytes (mean) |
|---|---|---|
| 32 tokens | 805.4 / 953 of 1024 | 3,068,393,899 B (2.86 GiB) |
| 128 tokens | 980.7 / 1023 of 1024 | 3,736,582,662 B (3.48 GiB) |
| 512 tokens | 1024 / 1024 | 3,900,702,720 B (3.63 GiB) |
| Full trace | 1024 / 1024 | **3,900,702,720 B** |

The full-trace byte total equals J-015's measured routed-expert byte count for this file **to the byte** — over 577 tokens, every expert in every layer is used, so the trace's working set *is* the model's whole expert body. Within 32 tokens the demand already averages 79 % of all pairs.

### 5.3 Reuse — frequent, but at long stack distance

Cold accesses are only 1,024 of 73,856 (**1.39 %**) — everything recurs. But because each token touches 128 pairs, recurrence happens at a **median stack distance of 298 pairs** (mean 357.3, p90 716, max 1023): an expert reused after a median gap of **3 tokens** (mean 7.6, p90 16) has nonetheless had ~300 other expert-pairs flow past it. Cache *capacity in pairs*, not time, is the binding constraint — the number J-018's sizing must respect.

### 5.4 Cold vs repeated, by text type — code is the local one

Distinct pairs touched (of 1024), per prompt: prose 975 / 71 tokens · **code 700 / 100 tokens** · structured 912 / 129 · numbers 1010 / 91 · instructions 1009 / 91 · technical 994 / 95. Code routes far more locally than any prose class; numbers and instructions saturate the pair space fastest. Any cache policy tuned on prose alone will be mis-tuned for code, and vice versa — J-024's tournament has per-type traces to answer to, not just the aggregate.

### 5.5 The boundary is soft — margins

Across 9,232 token-layers, the margin between the 8th and 9th router probabilities has mean 0.0021, median 0.0012; **97.8 % of selections have margin < 0.01 and 43.3 % have margin < 0.001**. The 8th seat is routinely a near-tie. Two consequences, both recorded for later slices: (a) exact top-8 membership at the boundary will differ between any two honest implementations (quantization, summation order) — traces must be compared as *distributions*, not token-exact sets; (b) a cache design should treat the router's tail as a probability mass to cover, not a hard set to match.

### 5.6 Cache simulations on this trace (offline; policy evidence for J-018 / J-024)

| Capacity (pairs) | ≈ bytes at mean expert size | LRU hit | LFU hit | Streamed bytes/token at LRU (vs 487,587,840 B cold ceiling, J-015) |
|---|---|---|---|---|
| 128 | 0.49 GB | 0.186 | 0.302 | 396.9 MB |
| 256 | 0.98 GB | 0.453 | 0.496 | 266.9 MB |
| 512 | 1.95 GB | 0.741 | 0.748 | 126.4 MB |
| 1024 (= all experts) | 3.90 GB | 0.986 | 0.986 | 6.8 MB |

LFU beats LRU clearly at small capacities (0.302 vs 0.186 at 128 pairs) and the two converge by 512. The remaining 1.39 % miss at full capacity is exactly the cold fraction — compulsory misses only.

## 6. What this means for the slices that stand on it

Readings of §5, labelled as readings (the designs themselves are J-017's and J-018's to make):

- **For a model of this size class, caching is nearly all-or-nothing.** OLMoE's whole expert body is 3.90 GB; a half-body cache (512 pairs) still streams ~126 MB per token. The streaming design (J-017) earns its keep on models whose expert body is many times RAM — this model's traces set the *shape* of the demand curve (fast saturation, long stack distance, soft boundary), and the same instrument must be re-run on the J-022-class model before its cache numbers are trusted there.
- **Frequency information is worth real bytes at small capacities** (LFU's +11.6 points at 128 pairs), so J-018's policy choice is not LRU-by-default; J-024's tournament starts from these two curves as its floor.
- **Per-text-type tuning is real** (§5.4): the cache sees a different workload in code than in prose.
- **Prefetch (J-025) faces a hard target:** with a 32-token working set already at 805 pairs, one-layer-ahead prefetch is chasing a set that is most of the model; the trace gives J-025 the exact per-layer transition data to prove or kill the idea cheaply.

## 7. What this slice does not prove

- **Granite-3.1-3B-A800M and Qwen1.5-MoE traces: NOT PROVEN.** Only OLMoE was traced (one model, one quant, 577 tokens). The instrument is OLMoE-specific; Granite (`granitemoe`, GQA, scalar multipliers, partial rotary) and `qwen2moe` (shared experts — whose routing includes the always-on shared path) each need their own forward conventions pinned the same way before their traces mean anything. Road: extend the instrument per family when J-022/J-032 pick their models, reusing the trace format and analyser unchanged.
- **No independent-oracle grade of the forward.** The QK-norm A/B (§3.4) and the coherence witnesses (§4) are indicative, not a teacher-forcing grade; when Aesir's own MoE forward or a ggml comparator exists on this road (J-022), the trace's conventions get re-graded there. The margins finding (§5.5) bounds how much any re-grade can move the *aggregate* statistics: hit distribution, working set, and stack distance are population statistics over 73,856 accesses, insensitive to boundary flips; exact per-token sets are not claimed stable.
- **Decode-phase routing is thin:** 4 generated tokens against 573 prompt tokens. A decode-heavy trace (hundreds of generated tokens) is future work for the soak slice (J-033) shape; prompt-phase (prefill) routing is what this slice measured, and it says so.
- **Aesir itself still cannot log a router** — §2 is a specification, and stays one until the MoE block exists. Nothing in this slice changes the engine tree; the only repo artefacts are documents and offline tools.

## 8. Defects found and fixed in scope; evidence

Instrument defects (all in this slice's own tools; each fixed, hash-verified after patching, before the measured run):

1. `j016_router_forward.py` — GGUF scalar metadata read as raw numpy arrays (`TypeError` on first run): scalar accessor now unwraps via `np.asarray(...).reshape(-1)[0]`.
2. Same file — a leftover dead code path computed a `(k+1)`-th expert with mismatched dimensions and crashed the router block: removed; the margin is computed exactly from the sorted probabilities.
3. Same file — the BPE decoder raised `KeyError` on special tokens (stored literally, not byte-mapped, e.g. `<|endoftext|>`): decoder now passes unmapped characters through; prompt round-trips and top-5 printing both exercise it.
4. `j016_analyze_trace.py` — the original stack-distance computation was O(n · window) by set-slicing; rewritten on a Fenwick tree and verified to reproduce the original statistics **byte-identically** on the synthetic trace (and ~2× faster there; the difference grows with trace size).

Final instrument hashes (identical copies on purplelongship `~/j016/` and in the campaign records): forward `998abe006a774f720f53481e80a47ee731af620cd9f94b5e893372efec60b6d3`, analyser (see repo copy), prompts `7204e567751656a2cbe7876ed0e706f367e84e29067703c2e05facf06f807f86`.

**Evidence files.** Campaign records `~/workspace/model-tests/janas/`: this document; `j016_router_forward.py`; `j016_analyze_trace.py`; `j016_make_synthetic_trace.py`; `j016_prompts.txt`; `j016_trace_olmoe.jsonl` (the measured trace, sha256 `85e1d2413cbfcd43516a03d8463c7266d486cf0f0d0a6ed3104d09111facf99a`; also held on purplelongship at `~/j016/trace_olmoe.jsonl`); `j016_olmoe_stats.json` (analyser output); `j016_trace_ab_perhead.jsonl` + `j016_trace_ab_full.jsonl` and their run logs (the §3.4 experiment); `j016_run_full.log` (the measured run's log); `j016_synthetic_trace.jsonl` + `j016_synthetic_stats.json` (validation only). Filed in the repo under `docs/janas/` (document, tools, prompts, statistics, synthetic-validation pair, run log; the 1.2 MB measured trace itself is kept in the campaign records and on purplelongship under its sha256 pin above, not committed — the statistics and the tools that regenerate and analyse it are what the repo carries).
