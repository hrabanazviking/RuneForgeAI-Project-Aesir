# J-022 — First Bigger-Than-RAM Proof (attempted; proof NOT PROVEN, blockers named)

**Slice:** J-022 (Part II — Models Bigger Than Memory), Project Aesir Janas clean-room road.
**Roadmap text:** "First bigger-than-RAM proof. A sha-pinned MoE model larger than purplelongship's free GPU+RAM working set (chosen at the slice from the J-011 matrix — a Qwen3-MoE or Gemma-4-MoE file) runs end-to-end on the laptop line, coherent output, faithfulness graded against the ggml CPU comparator on the raw prompt."
**Worked:** 2026-10-31 — opening worker ~05:57–06:23 EDT (loader admission + the streamed OLMoE session + the 80B acquisition + the token-57 defect and its fix, commits `2ce6c843`…`880a585c`), continuation worker ~06:36–06:55 EDT (fix verification, comparator grade, bisection control, admission attempt, this doc). All runs on **purplelongship** (Ryzen 9 / RTX 2060 6 GB, kernel 7.0.0-38-generic) in guarded gaps of the 204 road (S-092 closed ~06:4x; S-093's build arrived 06:44 and was live during the grade/bisection legs — those legs are 2-thread/nice-10 or token-deterministic, so contention touches walls only, never tokens or ranks; walls are classed accordingly). VM: no build, no inference (MemAvailable ~525 MB; the session test target pulls the full engine graph — verification was done on-box from the identical tree instead, §1). **No Janas material used** — the clean-room law was not engaged. Hailo untouched/parked.

**Headline, plainly:** the streamed MoE session — the first MoE forward in Aesir — now runs end-to-end without crashing (the token-57 defect is fixed and the fix is **PROVEN**, §1–§2). But the run is **not faithful**: graded against the ggml CPU comparator on the raw prompt, Aesir's greedy picks are exact for the first five generated tokens and then diverge with growing logit gaps (§3). A control run exonerates the streaming machinery — the deviation lives in the new forward's core maths (§4). And the bigger-than-RAM leg itself **cannot run today**: the chosen 80B file is sha-pin-verified and genuinely larger than the machine's whole GPU+RAM, but Aesir's loader refuses it and no `qwen3next` forward exists (§5). **J-022 does not close.** The two named blockers are the road forward: (B1) the OLMoE forward deviation (immediate next item, §4), (B2) the `qwen3next` architecture (roaded to J-123; the 80B-class attempt to J-032).

---

## 1. Inheritance and the token-57 fix — verified, not trusted (PROVEN)

The opening worker's last commit, `880a585c`, fixes a `DictKeyError` that killed the streamed run at prompt step 57 (`run_trace2.log`, on-box `~/j022/`): an expert evicted and later re-admitted left its key twice in `payload_keys` — the readmission's reconcile ran after `ExpertCache.access` had already re-admitted the key, so the stale entry survived and the admission appended a second one; the next eviction popped the same key twice. The fix makes `_reconcile_payloads` duplicate-safe (keep once, pop at most once) and guards the admission append.

The continuation worker verified it from the tree, not from the report:

- Worktree `~/workspace/aesir-janas-j022` clean at `880a585c`; on-box tree `~/aesir-j022-tree` at the same commit, clean.
- **Fresh build from that tree** (purplelongship, `CUDA_VISIBLE_DEVICES=` stated): C shims first (`hailo10h_stub.c` → `libaesir_hailo10h.so`, `thread_par.c` → `libaesir_par.so`), then `pixi run mojo build --mcpu znver2 --target-accelerator sm_75 -I . -I aesir_engine … -Xlinker -L<stage> -Xlinker -laesir_hailo10h -Xlinker -laesir_par`. **0 errors** (`build_v3.log` on-box). Two harness lessons worth keeping: a borrowed tree's `mojo` binary invoked bare cannot locate `std` (the pixi environment is the invocation, not just the binary), and without `-I . -I aesir_engine` the package roots (`loader`, `core`) do not resolve; without the two shim libraries the link fails on `aesir_par_for` / `aesir_par_cpu_count`. All three failures were this worker's build invocation, not tree defects.
- **Full run, fresh binary** (§2): 67 prompt + 24 generated = 91 steps, **no DictKeyError**, and the output is **identical to the opening worker's post-fix run** (`run_cap512.log`, 06:24) — same generated ids, same cache statistics to the byte (bytes_streamed 34,741,125,120; admissions 1,367; evictions 1,226), same reader counters (27,387 reads). Two independently built binaries, one behaviour: the fix is the cause, and it holds. **PROVEN.**

## 2. The streamed OLMoE run (MEASURED, purplelongship)

Vehicle: `test_olmoe_stream` (this slice) over `MoEStreamSession` — resident set via the ordinary GGUF mmap, routed experts only through the J-018 `ExpertCache` + J-019 `StreamReader` path. Model: OLMoE-1B-7B Q4_K_M, the J-015 pin (sha256 `8c310f14…f3f`, 4,213,512,672 B). Prompt: the J-020 lighthouse prose text, 67 ids from the model's own tokenizer stack (decode-checked: the ids decode to the prompt text exactly). Context 512. Machine state at run start: loadavg 0.22, GPU idle (1 MiB), Tctl 38 °C → 65.4 °C after the run, MemAvailable 37,385 MB. The session is **CPU-only** (host primitives; GPU unused) — the accelerator-first gap is recorded in §6, not hidden.

| Run | Cache budget | Hit rate | Bytes streamed | Generated ids | Prefill | Decode |
|---|---|---|---|---|---|---|
| cap-512MiB (fresh build) | 536,870,912 | 0.216 | 34,741,125,120 | see §3 | 27.38 s | 9.25 s (24 tok) |
| cap-512MiB (opening worker) | 536,870,912 | 0.216 | 34,741,125,120 | identical | 27.23 s | 9.30 s |
| cap-4GiB control (§4) | 4,294,967,296 | 0.843 | 6,943,555,584 | **identical** | 23.36 s | 6.71 s |

Walls are single runs on a box whose load varied (S-093 arrived mid-sequence): **MEASURED-INDICATIVE**. Ids and counters are deterministic and reproduced exactly: **MEASURED**.

## 3. The comparator grade — the forward diverges (MEASURED; faithfulness NOT PROVEN)

Grading per the raw-oracle discipline: `tf_oracle` (the 204 road's teacher-forcing oracle over libllama, **ggml CPU comparator only**, 2 threads) on the same file and the **raw prompt** (no template, no `llama-cli --single-turn` anywhere). Alignment verified, not assumed: the oracle's own tokenization of the prompt file reports `prompt_tokens=67`, exactly the ids the session consumed. Forced sequence = Aesir's 24 generated ids; full table filed as `j022_tf_grade.txt`.

- **Rank 0 (comparator argmax = Aesir's pick): 8/24** — steps 0,1,2,3,4,7,19,22.
- **Rank ≤ 2 (the near-tie band): 10/24** — plus step 10 (rank 1, gap 0.064) and step 17 (rank 2, gap 1.138).
- **First divergence: step 5** — Aesir's pick 13 at rank 5, gap 2.479. Then it worsens: step 6 rank 57 / gap 5.430; step 8 rank 176 / 7.531; step 9 rank 367 / 7.573; step 14 rank 4300 / 12.516; step 23 rank 512 / 8.532. These are not near-ties and not a boundary effect.
- **Coherence, honestly:** the generated ids decode to `"\n\nThe lighthouse, and the first to be seen for the common orchids on the land of the W"` — a fluent, on-topic opening that degenerates into word salad, exactly what the ranks say.
- **Comparator-artifact check (the verdict class, excluded one by one):** CPU-vs-CPU only ✓; raw prompt, no template rendering ✓; tokenization count-verified identical ✓; no BOS mismatch (both sides consume the same 67 ids; the oracle's step-0 top-1 is Aesir's first pick with gap 0.000) ✓. The divergence is in Aesir's forward, not in the comparison.

**Verdict: the streamed session's output is NOT faithful beyond the opening tokens. Faithfulness for J-022's small-model leg is NOT PROVEN.**

## 4. Bisection: the streaming machinery is exonerated; the defect is in the forward (MEASURED)

Before naming the forward, the slice bisected its own machinery. The cap-4GiB control (§2) changes the streaming regime drastically — hit rate 0.216 → 0.843, bytes streamed 34.74 GB → 6.94 GB, evictions 1,226 → 599, 987/1024 experts resident at end — and the generated ids **do not change by one token**. If payload handling, eviction, the scratch path, or slab reading corrupted state, the corruption would have to be identical under two disjoint cache regimes; the parsimonious reading is that it is not in the streaming layer at all. (The 512 MiB run's cache behaviour is itself consistent with J-016/J-020's measured expectations for cap-512 — hit 0.216 over a mixed prefill+decode stream vs the trace sims' 0.74 steady-state class is a different, decode-inclusive mix; no cache anomaly is claimed or needed.)

What remains is the new forward's core maths in `core/moe_session.mojo` — the parts the dense engine proves separately but this module re-expresses: full-width Q/K RMSNorm (J-016's adopted reading), NeoX RoPE through `apply_rope`, KV append/slice through `KVCache`, `flash_attention_gqa` over the growing cache, router softmax/top-k/renormalize, and the per-layer well mark/reset discipline. The grade's shape — exact while the state is young (steps 0–4 include margins of 4.0 and 4.8 logits, not coin flips), then a moderate miss (gap 2.479) compounding under teacher forcing — is the signature of a small persistent state error, not of a wrong tensor or a wrong route (either would fail at step 0). **Root cause NOT FOUND in this slice** — per the never-leave-a-bug law the discovery is recorded here as **the immediate next item**, ahead of J-023 (which stands on this same model and session): bisect by grading the session's per-step picks on the 8-token prefix prompt (does the deviation exist at position ~8, or only past ~70?), and by a layer-wise logit comparison against the J-016 numpy instrument, whose own conventions were A/B-pinned in J-016. No fix is claimed; none was attempted blind.

## 5. The bigger-than-RAM leg — file verified, machine measured, run refused (NOT PROVEN)

**The file (pin PROVEN).** `Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf`, acquired by the opening worker to `~/j022/` on purplelongship: **48,506,100,512 B, sha256 `f73551b55e3796526c37772c96227151fa11af328802b8f9865d635104e280fd`** — matches the HuggingFace LFS pin of `unsloth/Qwen3-Next-80B-A3B-Instruct-GGUF` exactly (size and sha256 both; checked against the HF API this slice). It is *not* the official Qwen repo's Q4_K_M (48,410,988,384 B, sha256 `d103b273…c061a`) — unsloth's dynamic-quant recipe is a different file; the pin that matches is the one recorded.

**The machine (MEASURED).** purplelongship at attempt time: RAM total 39,517 MiB, MemAvailable 37,465 MB; GPU 6,144 MiB total, 1 MiB used. The file (48.51 GB) exceeds **total** GPU+RAM (39,517 + 6,144 = 45,661 MiB ≈ 47.88 GB), and therefore exceeds the free GPU+RAM working set by a wider margin. The roadmap's size condition is met with room to spare — this is the right file class (and J-032's named 80B class).

**The file's anatomy (header-read, gguf-py):** architecture `qwen3next`; 48 blocks; hidden 2048; **512 experts, top-10**; a shared expert (`expert_shared_feed_forward_length` 512); and a hybrid SSM (Gated DeltaNet) recurrence — `ssm.conv_kernel` 4, `ssm.state_size` 128, `ssm.group_count` 16, `ssm.time_step_rank` 32, `ssm.inner_size` 4096; 843 tensors. A third of the blocks are not attention blocks at all.

**The attempt (MEASURED refusal).** The §1 binary against the file (context 512, cache 512 MiB, two prompt ids, gen 1) exits 1 in under a second, before any stepping (`j022_qwen3next_attempt.txt`):

```
Unhandled exception caught during execution: GGUF is missing required tensor: blk.0.attn_q.weight
```

The loader's dense-shaped tensor requirements refuse the hybrid layout (block 0 is an SSM block and carries no `attn_q`), and behind that refusal stands the session's own by-name gate: `MoEStreamSession` implements the `olmoe` block only and refuses every other architecture rather than running it dense-shaped. Both refusals are the engine working as designed — fail closed, nothing partial, nothing faked.

**Blockers, named:** (B2a) no `qwen3next` loader admission (tensor directory expectations are dense-shaped); (B2b) no `qwen3next` forward — hybrid Gated-DeltaNet recurrence + shared experts + 512-expert routing is unbuilt architec
...[truncated 2829 chars]
---

## 7. B1 addendum (2026-10-31, continuation worker ~07:45–08:35 EDT) — ROOT CAUSE FOUND AND FIXED; faithfulness PROVEN for the small-model leg

**Plainly:** the OLMoE forward deviation (blocker B1) is **solved**. One routing rule was wrong: the session (and the J-016 instrument before it) **renormalized the top-8 router weights to sum 1**; the ggml comparator's OLMoE graph does **not** renormalize — the experts are weighted by their **raw softmax probabilities**. Removing the renormalization makes the streamed session reproduce the comparator: the re-grade below is rank 0 at 23 of 24 steps with the last step a rank-1 near-tie (gap 0.108), and the decoded output is fully coherent prose. **B1 is closed.** J-022's remaining blocker is B2 only (`qwen3next`, roaded to J-123/J-032); the slice still does not close, and the frontier stays J-022 until the keeper rules otherwise — but the forward this road stands on is now faithful.

### 7.1 How the bisection narrowed (all MEASURED, purplelongship, guarded gaps beside the 204 road's S-093; 2-thread/nice-10 CPU legs; walls under contention are not used as evidence anywhere here)

Inherited evidence (verified first-hand, not re-run): experiment A prefix grades (deviation present at every prefix length, growing with N), experiment B layer dumps (Aesir vs the J-016 numpy instrument agree to relL2 0.0008 at position 0, 0.006 at position 7, but diverge to 0.287 at position 71 with the jump at ffn11), the QK-norm A/B, and two partial convention sweeps (sweep1 truncated after 2 combos; the lean seq8 sweep finished 8 combos; **sweep2 — the single-axis variants — was banked but never run**, found missing this dispatch and run in trimmed form, §7.2).

New evidence this dispatch, in the order it discriminated:

1. **Tokenization is id-identical, not just count-identical** (`tf_tokdump`, the oracle's own tokenize call): prompt_8 = `510,1708,5967,43775,21863,253,6891,16303` — exactly the session's ids. The last comparator-artifact sub-class (same count, different ids) is excluded.
2. **Progression fingerprints** (new prompt files N=2..7 built by exact decode of the id prefixes, each tokdump-verified; `j022_b1_prompts.py`): the comparator's step-0 argmax runs 5967 (N=2), 310, 434, 253, 22377, 22377, 281 (N=8). The instrument (renormalized baseline) already misses at **N=2** (its 5967 logit 6.616 vs the comparator's 9.780) while **agreeing at N=1** (47111: 7.685 vs 7.852, full probe set within ~0.4 RMS — `j022_b1_diag1.txt`). At N=1 attention is trivial (single key, RoPE-invariant), so a real per-token error of ~0.4 logits exists *before* any position effect — and it compounds with context exactly as §3's grade shape showed.
3. **Convention sweeps completed** (`j022_b1_seq2sweep.txt`: qknorm {full, perhead} × rope {NeoX, interleaved, sign-flipped, none} at seq2+seq8 — none within 3 logits of the comparator on its top token; metadata re-checked: `rope_base=10000`, `eps=1e-5`, no `rope.dimension_count`, no logit-scale keys; the file's QK-norm vector is genuinely 2048-wide, not a tiled 128). Attention-side conventions are **exonerated as a class**: every variant shares the same MoE block, so the shared error had to live there (or in the final head).
4. **The comparator's own graph, read** (llama.cpp's OLMoE builder + `build_moe_ffn`, from the reference source tree on the box — not Janas material; the clean-room law is not engaged): QK-norm is applied **full-width before the head reshape** (the adopted reading — correct), scale `1/sqrt(head_dim)` (correct), gating `SOFTMAX` — and the builder passes **`norm_w=false`** with **`expert_weights_scale=0`**: after top-k selection the weights are used **raw, never renormalized**. HF's OLMoE description renormalizes (`norm_topk_prob`); ggml's graph does not. J-016 adopted the HF reading, and `moe_session.mojo` copied it. That is the whole defect: every layer's MoE output was shrunk by the top-8 probability mass (~0.5–0.8×), per token, compounding through 16 layers and through the KV context.
5. **Instrument-side confirmation before touching the engine** (`j022_b1_sweep2lean.txt`, the missing sweep2 run trimmed to seq2+seq8): with `router_no_renorm`, the instrument's last-position top-5 becomes seq2 `5967:9.865 273:9.344 369:9.189 310:9.178 432:9.030` vs comparator `5967:9.780 273:9.278 310:9.262 369:9.197 432:8.975`, and seq8 `281:16.549 13:14.734 273:14.541 4283:14.463 598:14.034` vs comparator `281:16.634 13:14.750 273:14.680 4283:14.433 598:14.013` — same set, same order, max |Δ| 0.139. (The same run's other single-axis variants — attn_scale ×2/½ — stayed ≥3 logits off, closing those axes.)

### 7.2 The fix (in scope, banked)

`aesir_engine/core/moe_session.mojo` (commit `69aeaf01` on `yrsa/janas-j022`): the renormalization loop and its `wsum` accumulator are removed; `chosen_w` now carries the raw softmax probabilities; the module docstring and the router comments record the comparator's rule and the defect history so the renorm is not re-added. No other forward maths changed. The J-016 instrument and the B1 scripts that replicate its MoE block (`j022_b1_layer_dump.py`, `j022_b1_convention_sweep*.py`) still carry the renormalized reading — they are evidence tooling, not the engine; their *selection* data (top-8 sets) is unaffected by the renorm (it does not change rankings), but any *weight* or *logit* figure they produced pre-fix is superseded by §7.3. `j022_b1_convention_sweep2.py`'s `router_no_renorm` variant is the corrected reference behaviour.

### 7.3 Re-grade after the fix (MEASURED → faithfulness PROVEN under the near-tie discipline)

Fresh build from the fixed tree (on-box, `CUDA_VISIBLE_DEVICES=` stated, BUILD_EXIT=0; driver `j022_b1_verify.sh`), streamed session, same file/prompt/context/cache as §2–§3 (`j022_b1_run_fix.txt`). Machine state: S-093 live throughout (load ~13–15, Tctl to 83.1 °C) — walls (prefill 47.32 s, decode 14.42 s) are **MEASURED-INDICATIVE only**; ids, ranks and gaps are deterministic and unaffected.

- **Aesir's 24 greedy picks** (`tf_oracle` grade, raw prompt, tokenization 67 == 67; full table `j022_b1_tf_grade_fix.txt`): **rank 0 at 23/24 steps**; the single exception is step 23, rank 1 with gap **0.108** — inside the near-tie band (rank ≤2, sub-logit gap). Pre-fix (§3): rank 0 at 8/24, first divergence step 5 (rank 5, gap 2.479), worsening to rank 4300.
- **Free-running cross-check** (`fr_oracle`, ggml's own greedy continuation, `j022_b1_fr_fix.txt`): ggml generates `187 187 510 1708 5967 6225 327 247 33848 562 68 1658 13 253 760 581 323 6574 1475 15 733 369 247 41789` — **identical to Aesir's fixed run for the first 23 tokens**, differing only at token 24, the same near-tie step (41789 by 0.108 over Aesir's 10086).
- **Coherence:** the fixed run decodes to `"\n\nThe lighthouse stood on a rocky outcrop, the only one for miles around. It was a tall"` — fluent, on-topic, no degeneration (pre-fix: fluent opening collapsing to word salad, §3).
- The token-57 regression stays fixed: the 67+24 run completes with no DictKeyError (cache counters in `j022_b1_run_fix.txt`; note hit rate moved 0.216 → 0.258 because the corrected routing selects different experts — expected, not an anomaly).

**Verdict class:** B1 root cause **PROVEN** (single-axis change, predicted by the comparator's graph, confirmed instrument-side to ≤0.14 logits before the engine was touched, then confirmed in the engine by a 23/24 rank-0 teacher-forcing grade plus a 23-token free-running identity with the comparator's own greedy). The OLMoE small-model leg's faithfulness, **NOT PROVEN** in §3, is now **PROVEN** under the road's near-tie discipline. What remains NOT PROVEN for J-022 is unchanged: the bigger-than-RAM leg (B2, §5) and the accelerator-first gap (§6) — the session is still CPU-only.
