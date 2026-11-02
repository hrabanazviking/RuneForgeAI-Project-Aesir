# J-092 — Attention's Growing Share

**Slice:** J-092 (Part VI — Long Context and the 8-Bit KV, J-087–J-098), Project Aesir Janas clean-room road.
**Roadmap text:** "Per-token time split (attention vs the rest) across the ladder; where attention crosses half the token cost, the optimisation target named for later roads."
**Executed:** 2026-11-01 ~13:36–13:54 EST, in fresh worktree `~/workspace/aesir-janas-j092` on branch `yrsa/janas-j092`, from the verified tip of `yrsa/janas-j091` (`0abf7be670de6e20b0d48fe4a11023ea9aba1ec2`, local == ls-remote at slice start). Origin/main untouched at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`. The J-091 worktree and the canonical checkout were not worked in. Design + pre-registered definitions and crossing rule committed FIRST @ `1b54cfe2` (module + tests + harness), before any build or run of this slice.
**Machine state (VM, stated for every number below):** KVM, 4 vCPU, kernel 7.0.0-39-generic. MemAvailable ~0.69–1.6 GB across the slice (688,032 kB at the first check) — **far below the 5,500 MB inference gate at every moment**, so no model inference ran anywhere; lightest compiles only, one at a time. Load average up to ~12.4 (other campaigns); **no wall is filed anywhere in this slice**, so contention touches no number. purplelongship was **not used at all** — unreachable (last_seen 2026-11-01T02:07:13Z) and owned by the 204 road when it returns. /tmp healthy.
**Clean-room record:** no Janas material was consulted in this slice and no Janas source code was opened, in this slice or any other. Every quantity is Aesir's own accounting, defined through Aesir's own prior slices.

---

## 1. The question — and the honest shape, stated up front

**Question.** Across J-091's context ladder, how does a token's cost split between attention and the rest — and where does attention cross half the token cost? The roadmap asks for a *time* split; §2 states what this slice can and cannot file under that word.

**The shape this slice can honestly take, decided from evidence before building.** A per-token *time* split needs live runs with attention-vs-rest attribution. This tick no machine can run the witness (the VM is far below its inference gate; purplelongship is unreachable), and the tree has no attention-phase timer (J-053 §3's census stands). The Part VI pattern therefore governs, exactly as in J-091: **build the split machinery offline from the ladder's own accounted frame, file every split as ACCOUNTED work share (and, separately, traffic share), and file every TIME split as NOT PROVEN / DEFERRED-WITH-REASON to the J-098 gate with an exact live recipe (§7).** A MAC share is not a time share, and this slice never lets one wear the other's name.

**The findings, in one paragraph.** Attention's accounted work share grows linearly per token and quadratically per prompt, exactly as J-091's frame implies. For a **decode token** it reaches 48.19% at the profile cap (32,768) and **crosses half at context 35,228 — 2,460 tokens beyond the cap**: within every context Aesir can run this model today, attention is the largest *growing* cost but not yet half the token. For a **prefill token at the margin** (the last token of a prompt) it crosses at **exactly 32,512** — inside the cap — so the top rung's final token is already attention-majority (50.20%). For a **whole prompt on average** it crosses only at **65,024** — never on the ladder (33.51% at 32,768). The **traffic** split tells a different story and is never conflated with work: a decode token's KV reads are only 28.63% of its byte traffic at the cap (weights dominate until context 81,667 at f16), while prefill traffic splits by line — KV-dominated almost immediately on the host's batched path (permanent crossing at 808 tokens), weight-dominated throughout on the GPU's width-1 Coder prefill (crossing at 163,332). The optimisation target these crossings name is filed in §5.

## 2. Definitions and the crossing rule (pre-registered)

Stated in `core/attention_share.mojo`'s header and committed (@ `1b54cfe2`) before the harness was built or run. The witness is J-091's: Qwen2.5-Coder-7B-Instruct-heretic **Q4_K_M**, sha256 `8053aeda222ba79e865a6eddd268332fd4e4dbe406371318d6df1f9beae9502b`, 4,683,074,688 B; 28 layers, hidden 3,584, ffn 18,944, 28 query heads, 4 kv heads, head_dim 128, vocab 152,064, context cap 32,768.

- **Attention** = J-053's pair work only: per attended (query, key) pair per layer, q_width MACs for the score + q_width for the weighted value sum. One token attending at context C pays **unit × C** with unit = 28 × 3,584 × 2 = **200,704 MACs**. The Q/K/V and output projections are **not** attention in this account — J-053 prices them as projections, and this slice keeps that split so no number can drift from the frame it splits.
- **The rest** = everything else the MAC account prices: the per-token projection + FFN total (Q/K/V, attention output, gate/up/down) = **6,525,288,448 MACs/token** (J-053's filed Coder figure), plus — where the token pays it — one LM-head pass of **544,997,376**. A *prefill* token's rest is the projections alone (a prompt pays the head once); a *decode* token's rest is projections + head = **7,070,285,824** (every generated token pays the head). The two rests are never mixed.
- **Unpriced work is in neither side, and is named:** softmax (per-pair, non-MAC — its omission makes every attention work share here a *lower bound* on attention's share of any future time split), norms, RoPE, sampler work, and int8 dequantization carry no MAC price in J-053's account.
- **Work forms** (exact integer pairs; share = attention / (attention + rest)): (a) **token-at-context** — the marginal form above, per leg (prefill rest vs decode rest); (b) **prompt-average** — the whole prompt's attention total vs its rest (projection × L + one head); (c) **write-leg average** — J-091's 128-token write leg: attention total on the decode context sum vs 128 × the decode rest. Work shares are **line-invariant by construction** (J-053's totals are surface-invariant; batching changes pass counts and weight re-reads, never pair or projection counts).
- **Traffic forms** (bytes, never conflated with work; each a by-construction *touch shape* in J-091's sense — caches sit between the shape and any device): (a) **decode, per token at C** — KV reads (per-token KV price × C, at the stated precision: 57,344 B/token f16, 29,568 B/token per-row int8) vs the weight set read once per token (the file's 4,683,074,688 B; width-1 decode streams the weights once per token on both lines, so this form is also line-invariant); (b) **prefill, per prompt** — KV-read shape (KV price × causal pairs) vs weight-pass bytes (J-053: passes × file bytes, passes from the surface's own plan). This is the one split that **differs by line**: the CPU line's host batched plan (chunk cap 256) amortizes the weights over a chunk; the GPU line's Coder prefill is **width-1** (J-091 §3).
- **Crossing rule:** a split *crosses half* at the smallest stated context/length where attention (or KV reads) ≥ the rest (or weight reads) — equality counts as crossed. Crossings are solved **exactly** from the closed forms (ceiling division for the linear forms, integer search for the quadratic and step forms) and filed as ACCOUNTED arithmetic. Where the host-batched prefill traffic's step-shaped weight term makes the share a **sawtooth**, both the *first* and the *permanent* crossing are filed and the re-dip between them named (§4.3).

## 3. Inspection — how each side scales, and what the record already holds (PROVEN from the tree)

- **Per-token scaling.** Attention work per token grows linearly with the context it attends at (unit × C); the rest is constant per token. Per prompt, attention grows quadratically (pairs) while the rest grows linearly. In decode, the write leg's average attention per token is unit × (rung + 63.5) over its 128 tokens (the context sum of J-091). Nothing here is a new model of the work — it is J-091's frame read as a split, and the tests' validation gate (§6) reproduces J-091's §5.1 columns exactly before any share is computed from them.
- **KV precision moves bytes, not MACs.** The attention MAC count is identical at f16 and int8 KV (the pair arithmetic is the same; J-088's dequantization is unpriced, §2). Precision therefore cannot move any *work* crossing; it moves the *traffic* crossings (decode 81,667 → 158,384) and admission (J-091 §5.3: int8 would hold the 16k GPU session whole). Any later claim that 8-bit KV "halves attention cost" is refused by this slice's accounting in advance: it halves KV *bytes* (roughly — 0.5156 with scales), priced where bytes are the currency.
- **The filed Coder walls cannot yield a time split — the refusal, stated as part of the record.** The only live Coder walls in the record are the wave/S-034-class rows re-cited in J-091 §3 (whole-GPU @4096 decode ≈17.5 tok/s; spilled @16384 decode ≈10.2 tok/s). A two-point fit of wall/token against context through those rows would attribute the **placement** change (whole-GPU → spilled) to attention. That fit is **refused**: no MEASURED-INDICATIVE time bound is filed in this slice, from those rows or any others. §7's recipe states the attribution method that *is* admissible (same-placement, multi-context, per leg).

## 4. The split (ACCOUNTED; every TIME split NOT PROVEN)

Shares are floored parts per million in the harness/tests; percents here are the same fractions to two decimals.

### 4.1 Work — token-at-context and the leg averages

| Rung (context) | Decode token (rest incl. head) | Prefill marginal token (rest = projections) | Write-leg average (128 tok) | Prompt average (whole prompt) |
|---|---|---|---|---|
| 1,024 | 205,520,896 / 2.82% | 3.05% | 2.99% | 105,329,459,200 / 1.55% |
| 4,096 | 822,083,584 / 10.42% | 11.19% | 10.56% | 1,684,038,221,824 / 5.93% |
| 8,192 | 1,644,167,168 / 18.87% | 20.13% | 18.99% | 6,735,330,803,712 / 11.19% |
| 16,384 | 3,288,334,336 / 31.74% | 33.51% | 31.83% | 26,939,679,047,680 / 20.13% |
| 32,768 | 6,576,668,672 / **48.19%** | **50.20%** | 48.24% | 107,755,427,856,384 / 33.51% |

(The first column's numerator is the token's attention MACs; the prompt-average column's numerator is the whole prompt's attention total. Rests: decode 7,070,285,824/token; marginal 6,525,288,448/token; prompt rest = 6,525,288,448 × L + 544,997,376.)

**The work crossings, exact:**

| Form | Crossing | Position vs the ladder/cap |
|---|---|---|
| Prefill marginal token | **32,512** — attention == rest *exactly* there (200,704 × 32,512 = 6,525,288,448) | Inside the cap, by 256 tokens; the 32,768 rung's marginal token is the ladder's only above-half work cell |
| Decode token | **35,228** — at 35,227 attention is still 86,016 MACs short of the rest | **Beyond the cap (32,768) by 2,460 tokens**; no runnable decode token today is attention-majority by work |
| Prompt average | **65,024** — at 65,023 the share is 499,999 ppm (below half by a hair the search, not rounding, decides) | Beyond 2× the cap; a prompt would need ~65k tokens before its *average* token is half attention |

### 4.2 Traffic — decode (per token at the rung's context; KV reads vs the file's bytes read once per token)

| Context | KV f16 | Share f16 | KV int8 | Share int8 |
|---|---|---|---|---|
| 1,024 | 58,720,256 | 1.24% | 30,277,632 | 0.64% |
| 4,096 | 234,881,024 | 4.78% | 121,110,528 | 2.52% |
| 8,192 | 469,762,048 | 9.12% | 242,221,056 | 4.92% |
| 16,384 | 939,524,096 | 16.71% | 484,442,112 | 9.37% |
| 32,768 | 1,879,048,192 | 28.63% | 968,884,224 | 17.14% |

**Decode traffic crossings, exact:** f16 at context **81,667**; int8 at **158,384** — both far beyond the cap. Throughout the runnable range, a decode token's byte traffic is dominated by its **weights** (71.37% even at the cap, f16), not its KV reads. This is a bandwidth statement about shapes, not about work — §4.1 and §4.2 measure different currencies and neither may be quoted as the other.

### 4.3 Traffic — prefill (per prompt; KV-read shape vs weight-pass bytes, per surface)

| Rung | KV shape f16 | Host batched f16 | GPU width-1 f16 | Host batched int8 | GPU width-1 int8 |
|---|---|---|---|---|---|
| 1,024 | 30,094,131,200 | 61.63% | 0.62% | 45.31% | 0.32% |
| 4,096 | 481,153,777,664 | 86.53% | 2.45% | 76.80% | 1.28% |
| 8,192 | 1,924,380,229,632 | 92.78% | 4.78% | 86.88% | 2.52% |
| 16,384 | 7,697,051,156,480 | 96.25% | 9.12% | 92.98% | 4.92% |
| 32,768 | 30,787,265,101,824 | 98.09% | 16.71% | 96.36% | 9.38% |

**Prefill traffic crossings, exact:** on the **host batched** surface the weight term jumps by a whole file-read at each chunk boundary, so the share is a sawtooth near the crossing — f16: **first crossing at 700, re-dip at 769** (pass count 3 → 4), **permanent crossing at 808**; int8: **first at 1,259, re-dip at 1,281** (passes 5 → 6), **permanent at 1,379**. (Permanence is scanned in the module to 8,192, extended by the inspect in Python to 1,000,000 with no further dip, and closed by the bound in §6: past 8,192 the share's closed-form lower bound is already above half and increasing.) On the **GPU width-1** surface the ratio grows monotonically (kv_pt × (L+1) / (2 × weights)), so first == permanent: **163,332** (f16) / **316,766** (int8) — beyond any runnable prompt. The line difference is the finding: batched prefill amortizes the weights 256-fold, so its traffic is KV-shaped almost from the start; width-1 prefill re-reads the whole file per token, so its traffic is weight-shaped at every length — which is a *traffic* statement about the Coder GPU path's pass structure, and one more reason (beside J-053's pass counts) its prefill *time* cannot be read off the work shares.

## 5. The optimisation target named for later roads (recommendation, not built)

Per the roadmap's ask, the crossings name the target — stated here as a written recommendation to the roads that own the work (Part VI's remaining slices, the J-098 gate, and Part IX), in Aesir's accelerator-first order (NPU → GPU → CPU spill only):

1. **Primary target: the decode attention path at long context.** Accounted decode work is 31.74% attention at 16k and 48.19% at 32k, growing linearly, and crosses half at 35,228 — the *first* context beyond today's profile cap. Any later road that lifts the cap (a J-098 gate decision) or lengthens runnable context makes attention the majority decode cost immediately, with no further change in the model. Later roads should therefore spend their attention effort on the accelerator-side decode attention leg — fused / GQA-aware attention over the resident KV — before further projection-side micro-optimisation, whose ceiling is the shrinking rest.
2. **The int8 KV leg is a traffic and admission lever, not a work lever — fund it for what it does.** Integrating J-088's store (its §7 recipe) moves the decode *traffic* crossing from 81,667 to 158,384 and, per J-091, holds the 16k GPU session whole; it does not move any work crossing (MAC counts are precision-invariant, §3). It is recommended on those grounds, in that order of reasons — and never sold as halving attention's work.
3. **Prefill: projections first on average, attention first only at the tail.** The prompt average stays projection-dominated at every rung (33.51% at 32k; crossing at 65,024), so prefill optimisation remains the batched projection/FFN path's game on average — while the marginal token at the top rung is already attention-majority (50.20%), so long-prompt work aimed at the *tail* of a 32k read should be attention-shaped. On the GPU line, the width-1 pass structure (§4.3) is itself the standing prefill defect to retire before either.
4. **Not named as an attention fix: decode weight streaming.** Weights still carry 71.37% of a decode token's traffic bytes at the cap; weight-side work (quant decode, residency) remains the bandwidth co-target until ~81k context. The work crossing at 35,228 must not be misread as a bandwidth verdict — the two crossings are 46,439 contexts apart, and later roads are asked to keep them apart in every citation.

## 6. Tests and inspect (PROVEN, VM, lightest target)

Filed as `j092_test_output.txt` (build recipe and machine state in its header):

- **`test_attention_share` (new): 10/10 groups PASS** — endpoints reproducing J-053's projection figure and J-087/J-088's KV prices through the ladder; the **validation gate** (J-091 §5.1's prefill attention, projection + head, and write-leg attention totals EXACT at all five rungs); the decode, marginal, write-leg and prompt-average splits pinned in floored ppm at every rung; the three work crossings with their edge facts (exact equality at 32,512; the 86,016-MAC shortfall at 35,227; the search-decided pair 65,023/65,024); decode traffic at both precisions with crossings 81,667 / 158,384; prefill traffic per surface with the sawtooth facts (re-dips at 769 and 1,281 asserted below half); 10 refusals.
- **Neighbours rebuilt from this tree:** `test_kv_ladder` (J-091) **8/8 PASS**; `test_kv_mixed` (J-090) **6/6 PASS**; `test_kv_int8` (J-088) **8/8 PASS**; `test_kv_account` (J-087) **10/10 PASS**; `test_kv_faith` (J-089) **6/6 PASS** — unchanged.
- **Share harness: two runs byte-identical** (sha256 `18c6f279…eed`), exit 0 both.
- **Inspect: `j092_inspect.py`** — checks the module's structure (counts defined through J-091/J-053; rule pre-registered in the header), **re-derives every field of every filed SHARE line and every CROSS field in Python and compares exactly** (crossings re-derived from the closed forms with full scans of the sawtooth forms), the validation gates against J-091's filed harness output parsed field-by-field, the host permanence extension to 1,000,000 with the closed-form bound (share ≥ kv_pt·128·L² / (kv_pt·128·L² + (L+255)·weights) — above half at 8,192 and increasing, since passes = ⌈L/256⌉ ≤ (L+255)/256 while pairs > L²/2), and this doc's honesty content. Its count is filed in `j092_inspect_output.txt`.

## 7. Deferred legs — the live TIME split (DEFERRED-WITH-REASON; recipe for the J-098 gate to re-cite)

**Why deferred:** the VM stayed far below the 5,500 MB inference gate all tick (MemAvailable ~0.69–1.6 GB) and purplelongship is unreachable and 204-owned when it returns — no ladder run, and therefore no time split, could be taken on any box. The tree also has no attention-phase timer today, so the attribution method must be the one stated in step 3, chosen in advance.

**The recipe, in dependency order:**

1. **Window and machine discipline:** purplelongship in a guarded idle gap (204 state heartbeat checked first; yield to a live 204 run); one heavy run at a time; per run file load, MemAvailable/VRAM, Tctl, and `nvidia-smi` state. Median of 3 runs per cell is the filed wall; a single run files as MEASURED-INDICATIVE.
2. **Re-pin before running:** sha256 of the Coder Q4_K_M file on the box must equal `8053aeda222ba79e865a6eddd268332fd4e4dbe406371318d6df1f9beae9502b` (4,683,074,688 B) before any leg; a file that does not verify does not run.
3. **Attribution method (stated in advance; the only admissible one):** per leg and line, measure walls at **three or more contexts within one placement** (whole-GPU rungs separately from spilled rungs; CPU rungs within the host cap), and fit wall/token = rest-rate + attention-rate × context by least squares over those same-placement points; the fitted attention-rate × context is the measured attention time at that context, filed **beside** this slice's accounted work share at the same context, with the divergence named, never smoothed. Cross-placement fits are refused (§3), ablations that change the output are refused, and **never `llama-cli --single-turn`** or any template-rendering comparator anywhere in the leg. If the tree gains an attention-phase timer before the gate, the timer's split may be filed instead, with the fit kept as its cross-check.
4. **Legs:** the ACCOUNTED cells of J-091 §5.2 (CPU read/write through 8,192; GPU reads at all rungs; GPU writes through 16,384; the GPU 32k write in its cap-adjusted 32,640 + 128 form, named as adjusted). The accounted decode work crossing (35,228) lies beyond the profile cap, so **no live time crossing is observable within the cap**: the gate files measured time shares at the runnable contexts and extrapolates nothing; a time crossing may be filed only if the gate first lands its own explicit cap decision (J-091 §7 step 4) and runs beyond it.
5. **Faithfulness of every Aesir row:** ids-first, then teacher-forcing rank + logit gap against the ggml CPU comparator on the raw prompt (CPU engine vs CPU comparator only), per J-089 §7 / J-091 §7 step 7; a reference that fails files COMPARATOR_ARTIFACT with its kind named.
6. **Int8 rows:** only after J-088 §7's integration lands per line; until then the int8 time question does not exist as a run, exactly as its ladder cells are INTEGRATION_BLOCKED.
7. **Registration:** with the counted live run, register `test_attention_share` in `tests/run_all.mojo` and re-account the pin (J-031 §10's rule).

## 8. Defects found

- **No defect found in prior work.** The validation gate reproduced J-091's §5.1 columns exactly at every rung (attention, projection, write-leg attention), and the neighbour suites rebuilt from this tree all pass unchanged (8/8, 6/6, 8/8, 10/10, 6/6) — J-053's, J-087's and J-088's filed figures are this slice's endpoints by construction and by measurement of the code alike.
- **Own-work defects, found and fixed in-slice (inspect script only; no filed number rested on either):** the inspect's first draft priced the host plan by replaying its chunk loop per length, making its million-length permanence scan quadratic (it was stopped, unfiled); the scan now uses the plan's closed form (passes = ⌈L/256⌉) only under an explicit equivalence check against the loop form (every length to 8,192 plus every chunk boundary to 1,000,000 — inspect-asserted). The accounting module and tests needed no fix: first builds passed and the harness was deterministic on its first pair of runs. One apparent anomaly is recorded so nobody re-hunts it: the tooling's display layer masked the harness's two rest totals in rendered output (the known transcript-masker phantom); the filed bytes were verified directly (sha256 + byte-level check) and are correct — no file content was ever affected.

## 9. NOT PROVEN list

- **Every per-token TIME split — reading and writing, every rung, line, and precision: NOT PROVEN.** No live run executed in this slice on any hardware. §§4–5 are exact arithmetic over J-091's frame (PROVEN as arithmetic) and a recommendation; they contain no speed, and no tok/s or wall figure is filed anywhere in this slice.
- **Any MEASURED-INDICATIVE time bound** — none is filed, deliberately: the record's only Coder walls sit under different placements at their two contexts, and a fit through them would attribute placement cost to attention (§3).
- **That work shares predict time shares** — per-MAC costs differ between the attention and projection paths, between lines, and with batching (the GPU line's width-1 Coder prefill inflates the rest's *time* without changing its MAC count). The §7 recipe exists precisely to measure the divergence; until it runs, the work split is a prior, not a prediction.
- **Traffic shapes as measured bytes** — §§4.2–4.3 are by-construction touch shapes; device caches sit between every shape and any real byte count.
- **The split for any other model** — filed for the Coder witness alone, as the ladder was; other profiles' units and rests differ (the module is shape-generic, but no other model's split is filed or claimed here).
- Janas's published attention-share or long-context numbers as evidence about Aesir — none are cited as such anywhere in this slice.

## 10. Banking

Filed on branch `yrsa/janas-j092` (worktree `~/workspace/aesir-janas-j092`, base `0abf7be6`): commits — design + accounting + harness first (@ `1b54cfe2`, pre-registered), then this doc, the inspect script and the filed outputs. In the tree: `aesir_engine/core/attention_share.mojo` (new) and `aesir_engine/tests/test_attention_share.mojo` (10 groups); in `docs/janas/`: `J092_ATTENTION_SHARE.md` (this doc), `j092_share.mojo`, `j092_inspect.py`, `j092_inspect_output.txt`, `j092_test_output.txt`. **No existing module was modified.** Campaign copies of the doc + evidence in `~/workspace/model-tests/janas/`, sha-identical (verified by hash). Push by explicit refspec `git push origin <sha>:refs/heads/yrsa/janas-j092`, foreground, with `git ls-remote` verification that the branch moved and origin/main stayed at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`; the commit hashes and ls-remote lines are recorded in the campaign state entry for J-092 and the slice worker's report (a doc cannot contain its own commit hash). No README touched. Hailo untouched/parked. No Docker.
