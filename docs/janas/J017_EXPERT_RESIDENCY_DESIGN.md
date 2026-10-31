# J-017 — Expert Residency Design

**Slice:** J-017 (Part II — Models Bigger Than Memory), Project Aesir Janas clean-room road.
**Roadmap text:** "Expert residency design. The streaming design in Aesir's terms: what stays resident always (attention, norms, shared experts, embeddings), what streams (routed experts), granularity (whole expert vs block rows), and the failure modes (thrash, cold start) named with their counters."
**Gate input:** GATE_RECORD.md adjustment **A1** — this design must name cache-conditional expert dropping as a policy candidate and take a decided position on it (§7).

**Designed:** 2026-10-31 ~02:35 EDT. **Design slice — no code built, no inference run, no heavy run anywhere.** This document decides what J-018 (cache), J-019 (disk discipline) and J-020 (cold/warm) will build; it does not build the engine. Aesir's engine core still has **no MoE code at all** (J-012, re-verified J-016 §1) — every statement below about "the engine" is a contract on future work, not a description of existing behaviour.
**Evidence base (the only numbers this design stands on):** J-015 (`J015_MOE_ANATOMY.md` — GGUF anatomy measured from sha-pinned files: OLMoE-1B-7B Q4_K_M, Granite-3.1-3B-A800M Q4_K_M, Qwen1.5-MoE-A2.7B-Chat Q2_K `qwen2moe` witness) and J-016 (`J016_ROUTER_INSTRUMENTATION.md` — OLMoE router traces, 577 tokens / 73,856 accesses, measured on purplelongship with a named GGUF-tensor reference forward; cache figures are offline simulations on that recorded trace). Janas material used: only the Part I census rows for the behaviours this design answers (cache sizing shape, dropping rule) — public documentation as recorded in `CENSUS.md` J-002; **no Janas source was opened**, and no Janas number is quoted as an Aesir expectation.
**Honesty classes:** file byte counts cited are **MEASURED** (J-015). Trace statistics cited are **MEASURED** (J-016) or **SIMULATED** where they come from J-016's offline cache simulations — labelled per figure. Design decisions are recorded as **DECIDED** (a decision is not a measurement). Anything this design cannot ground is **NOT PROVEN** and named as such with its owning slice.

---

## 0. Decisions at a glance

| # | Decision | Short form |
|---|---|---|
| D1 | Resident set | Everything except routed experts is resident for the life of the model open: embeddings (+ output head where untied), attention, all norms, routers, and — where the family has them — shared experts + their gate vectors. Budgets per witness in §2. Resident means *loaded once, never evicted, never counted against the expert-cache budget*. |
| D2 | Streamed set | Routed experts only. Nothing else streams in Part II's design. |
| D3 | Granularity | **Cache unit = whole expert** (its 3 slabs admitted/evicted atomically); **read unit = one slab** (3 seeks per expert per layer); layer-run and block-row units are rejected with reasons (§3). All extents come from the file's tensor directory, never from a family layout assumption. |
| D4 | Cache sizing shape | Sized once at open from free memory minus a reserve, under a hard cap (flag + env) that is never exceeded, accounted **in bytes** with per-(layer, expert) sizes from the directory. The reserve fraction and the eviction-policy winner are J-018/J-024's to measure; the contract they must honour is §4. |
| D5 | Expected performance, stated honestly | On the one traced model, a half-body cache still streams ≈126 MB/token and a fifth-body cache ≈350–400 MB/token class (§4.3). There is **no hot set** to exploit (entropy 5.9836/6.0). This design promises bounded, honest degradation — not Janas's headline speeds, which are its numbers on its machine with its native layout. |
| D6 | Dropping (A1) | **Default OFF, opt-in only, never silent, never in a faithfulness-graded run.** A dropped run computes a different function and cannot be graded faithful. Dropping is a named candidate for J-024's tournament, which must report its teacher-forcing agreement cost beside any speed gain before any default can change (§7). |
| D7 | Residency ≠ placement | Residency is a memory-lifetime property; placement (CPU/GPU/NPU per pass) is Parts III/IV's. The cache holds device-agnostic bytes; streamed experts are computed where later slices measure they should land (J-031). |

---

## 1. The shape of the problem, in the measured numbers

Three witnessed family shapes (J-015, MEASURED from the files):

| | OLMoE-1B-7B Q4_K_M | Granite-3.1-3B-A800M Q4_K_M | Qwen1.5-MoE-A2.7B Q2_K (`qwen2moe`) |
|---|---|---|---|
| Layers / experts / top-k | 16 / 64 / 8 | 32 / 40 / 8 | 24 / 60 / 4 |
| Routed-expert bytes | 3,900,702,720 (92.62 % of tensor bytes) | 1,828,454,400 (90.74 %) | 5,060,689,920 (86.03 %) |
| Resident bytes | 311,027,712 (7.38 %) | 186,689,220 (9.26 %) | 823,519,232 (13.97 %) |
| Per-expert bytes (per layer) | 3,538,944 / 4,079,616 (by down-quant) | 1,327,104 / 1,529,856 | 3,514,368 (uniform) |
| Cold per-token routed bytes (all layers, exact) | 487,587,840 | 365,690,880 | 337,379,328 |
| Shared experts | none | none | **present** — 12,525,568 B/layer + gate vector |
| Expert layout on disk | one contiguous run per layer | split run (up_exps after router+norm) | interleaved with shared-expert tensors |

And the demand the router actually makes (J-016, OLMoE, MEASURED unless noted):

- **No hot set.** Aggregate router entropy 5.9836 of 6.0 bits; hottest expert 2.37 % of accesses; every expert hit in every layer.
- **The working set saturates.** Mean distinct (layer, expert) pairs: 805 of 1024 within a 32-token window; 1024 of 1024 over the full 577-token trace — byte-equal to the whole expert body (3,900,702,720 B).
- **Reuse is frequent but far away.** Cold fraction only 1.39 % of accesses, yet median reuse stack distance is 298 pairs (median token gap 3): capacity in pairs, not time, binds.
- **The selection boundary is soft.** Margin between the 8th and 9th router probabilities < 0.01 in 97.8 % of token-layers, < 0.001 in 43.3 %.
- **Locality is per text type.** Code touched 700 pairs in 100 tokens; numbers 1010 in 91; instructions 1009 in 91. One workload's tuning is another's mistuning.
- Cache simulations on this trace (**SIMULATED**): LRU/LFU hit 0.186/0.302 at 128 pairs, 0.741/0.748 at 512 pairs, 0.986 at 1024 pairs (full body; the residual 1.4 % is exactly the cold fraction).

**Scope limit, stated once and binding on every later citation of this design:** the demand measurements are one model (OLMoE), one quant, prompt-heavy (573 prompt / 4 generated tokens), from a reference forward whose conventions J-022 must re-grade. Granite and `qwen2moe` *anatomies* are measured; their *router demand* is **NOT PROVEN**. The anatomies of `qwen3moe`, `qwen3next` and Gemma-4-MoE are **NOT PROVEN** (J-076 / Part VIII own them). This design is therefore written parameterised — by layer count, expert count, top-k, per-(layer, expert) byte sizes, and shared-expert presence, all read from the file at open — and no OLMoE constant may be hard-coded into an engine contract below.

---

## 2. The resident set (D1) — what never streams

### 2.1 Membership rule

A tensor is **resident** if any of these holds:

1. It is read on **every token** regardless of routing (attention, norms, routers, embeddings, output head).
2. It fires on every token **by construction** (shared experts and their gate vectors, where present).
3. It is small and on the routing critical path (router tensors are F32 and read before any expert can be chosen — streaming the router to decide what to stream is a circularity this design refuses).

A tensor is **streamed** iff it is a routed expert slab: read only when the router selects that (layer, expert) for that token. In all three witnesses the classification is decidable from tensor names + metadata at load (`*_exps` fused triples = streamed; `*shexp*`, `ffn_gate_inp*`, attention, norms, embeddings = resident). **Fail-safe direction (binding):** any expert-shaped tensor the loader cannot positively classify as routed is treated as **resident** until a later slice proves it routed. Misclassifying a shared expert as streamed would tax every token with a needless read and a possible cache miss on the always-on path; misclassifying a routed expert as resident costs memory once, visibly, at open. The errors are not symmetric, so the default is not symmetric.

### 2.2 Byte budgets per witnessed family (MEASURED, J-015 §3/§7)

| Resident category | OLMoE | Granite | Qwen1.5-MoE (`qwen2moe`) |
|---|---:|---:|---:|
| Token embedding | 57,950,208 | 61,935,300 | 102,100,992 |
| Output (head + output norm) | 84,518,912 (separate Q6_K head) | 6,144 (**tied** — norm only) | 255,260,672 (separate Q6_K head) |
| Attention (all layers, incl. attention-side norms) | 160,038,912 | 116,686,848 | 153,354,240 |
| Shared-expert FFN (all layers) | — (none) | — (none) | 300,613,632 (12,525,568 × 24) |
| Routers (+ shared gate vectors) | 8,388,608 (524,288/layer) | 7,864,320 (245,760/layer) | 11,993,088 (499,712/layer: 491,520 router + 8,192 shared gate) |
| Norms (non-attention) | 131,072 | 196,608 | 196,608 |
| **Resident total** | **311,027,712** | **186,689,220** | **823,519,232** |
| Per-layer resident (attention+norms+router[+shared]) | ≈10,534,912 | ≈3,898,368 | ≈19,423,232 (of which shared 12,525,568) |

Design readings of the table:

- **The resident set is the small part in every witnessed family** — 7–14 % of tensor bytes against 86–93 % routed. Even the largest witnessed resident set (823.5 MB, `qwen2moe`) is a one-time load that fits the machines this road targets; the expert body is the workload. This is the quantitative ground for the whole streaming design, and it is why D1 spends memory on residency without apology.
- **Tied vs untied embeddings move real money.** Granite's tied head makes its output category ~zero; `qwen2moe`'s untied Q6_K head (255,260,672 B) is the largest single resident tensor in any witness — bigger than its whole attention stack. The loader must derive the budget from the directory (presence/absence of `output.weight`), never from a family default.
- **Shared experts are resident-side, full stop.** In `qwen2moe` the shared FFN is 4× a routed expert's width (5632 vs 1408), fires every token, and alone is 300,613,632 B — 36.5 % of that family's resident set. Any design that streamed it would pay a guaranteed read per token per layer to save one-time memory: the worst trade on the table. (This is the resident-side correction J-015's verification pass added Witness C to establish, and it generalises: *presence* of shared experts is a per-file fact, checked at open.)
- **Routers stay resident even though they are F32 and not tiny** (7.9–12.0 MB total): they are read for every token-layer before any streaming decision exists, and at ≤0.4 % of file bytes they are the cheapest insurance in the design.

### 2.3 Runtime-resident structures that are not file bytes

The file budget above is necessary but not sufficient. At open the engine also holds, resident for the session: the KV cache (Aesir's KV is f16 today, J-012; its per-token cost per arch is **NOT PROVEN** in this evidence base — J-087 owns the KV census), per-layer activation/scratch space, the router workspace, and the expert cache itself (§4). **Binding contract:** the cache-sizing computation (§4) must subtract a *stated* allowance for these structures — resident weights (measured, §2.2) + a KV allowance for the configured context length + scratch — and must name the allowance in its open-time report. A sizing that budgets only file bytes will oversubscribe exactly when context grows; §5.3's shrink path is the mid-run correction, not an excuse to skip the allowance. Exact KV bytes are J-087's to measure; J-018 must not invent them — until J-087 lands, the allowance is a named, conservative configuration value, labelled as such.

### 2.4 What residency does not decide

Residency says where bytes *live* (memory, for the session), not where they *compute*. Whether resident products execute on CPU, GPU or NPU per pass kind is Part III/IV placement (D7). The one accelerator-first consequence recorded here: the resident set is the natural accelerator-resident candidate (it is small, always used, and Janas's documented resident-products NPU placement takes exactly this class) — but no placement is decided by this slice, and J-061's NPU design inherits residency as its input, not its conclusion.

---

## 3. The streamed set and its granularity (D2, D3)

### 3.1 What streams

Routed experts only: the fused triples `ffn_gate_exps` / `ffn_up_exps` / `ffn_down_exps`, per layer. Per-token demand at the cold ceiling (all top-k distinct, no hits) is **MEASURED** arithmetic (J-015 §4): 487,587,840 B/token (OLMoE), 365,690,880 B/token (Granite), 337,379,328 B/token (`qwen2moe`). Real demand is the cold ceiling scaled by the cache miss rate (§4.3) — there is no other streamed traffic in this design.

### 3.2 The unit decisions

**Cache unit = the whole expert (DECIDED).** One cache entry = one (layer, expert) pair = the expert's three slabs, admitted together, evicted together, accounted at that pair's true byte size for its layer.

**Read unit = one slab (DECIDED).** A routed expert is physically three slabs at three offsets in three fused tensors (J-015 §5) — e.g. OLMoE layer 0 expert 0: down slab 1,720,320 B at offset 59,740,640; gate slab 1,179,648 B at 169,841,120; up slab 1,179,648 B at 245,338,592. A miss therefore costs exactly **3 reads**, each a contiguous ≥442,368 B extent in every witness (smallest slab: Granite gate/up) — sequential-friendly sizes, random only at slab granularity. J-019 inherits this access pattern (§8).

Justification, tied to the measurements rather than to taste:

- **The trace evidence exists at exactly this granularity.** J-016 measured hit distribution, stack distance (median 298 pairs), working set and cache simulations over (layer, expert) pairs. There is **no** sub-expert reuse evidence anywhere in the base — no measurement says gate slabs are reused differently from down slabs, or that some block rows of an expert are hot while others are cold. Finer granularity would be designed on no data; coarser granularity is refuted by data (below). If a later instrument ever measures intra-expert structure, J-024's tournament is where a finer unit may argue its case with numbers.
- **Compute needs the whole expert.** An expert's output is `down(silu(gate(x)) · up(x))`: all three slabs participate in every firing. A cache that admits slabs independently can hold 2 of 3 slabs of an expert — bytes that compute nothing until the third arrives — and its hit accounting stops meaning "this firing needs no disk". Atomic admission keeps the invariant *hit ⇒ zero reads for that firing*, which is what makes J-016-style simulation comparable to live statistics at all.
- **Per-expert sizes are layer-dependent, and the pair is where that is true.** Q4_K_M up-quantises `down_exps` to Q6_K in exactly half the layers in both Q4_K_M witnesses (OLMoE per-expert total 3,538,944 vs 4,079,616 B by layer; Granite 1,327,104 vs 1,529,856 B). Byte accounting at pair granularity with directory-derived sizes is exact; any design that assumes a uniform expert size miscounts by up to 15 % per pair.

**Rejected: whole-layer streaming.** Reading a layer's full expert extent per token over-reads by exactly expert_count ÷ top-k: 8× for OLMoE (226,492,416–261,095,424 B read for 28,311,552–32,636,928 B used per layer), 5× for Granite, 15× for `qwen2moe`. The contiguous OLMoE run makes this *easy* to implement and *wrong* to choose: at the cold ceiling it turns 487.6 MB/token into 3.90 GB/token. Layer extents remain useful to J-019 only as a layout fact (prefetch locality), never as the read unit.

**Rejected (for now): block-row / sub-expert granularity.** Splitting an expert's slabs into row blocks would multiply the read count per firing (each slab is already a single contiguous extent of quant blocks; a row split fragments it), complicate dequant block alignment (Q4_K/Q6_K blocks are 256-element units — a split must at minimum respect block boundaries), and — decisively — answers a question no measurement has asked (§3.2, first bullet). Status: **NOT PROVEN** as a need; not built; revisit only on intra-expert trace evidence.

**Rejected: slab-independent caching** — see the atomicity argument above. The three slabs of one expert may be *read* in file order (J-019's choice) but are *cached* as one entry.

### 3.3 Layout: the directory is the only truth (binding)

The three witnesses have three different on-disk layouts (J-015 §5/§7): OLMoE's expert triple is one contiguous run per layer in file order down→gate→up (note: not compute order); Granite's run is split — `up_exps` sits after router + FFN norm, a 251,904 B span excess in every layer; `qwen2moe` interleaves expert tensors with shared-expert tensors (span 220,110,848 B for 210,862,080 B of experts per layer). **Binding contract:** every offset, extent and per-pair size used by the cache or the reader is computed from the opened file's tensor directory (name → offset, dims, quant → slab offset = tensor offset + expert index × slab bytes). No family name, architecture string or prior witness may supply a layout. A reader built on "one layer = one run" silently over-reads on Granite and mis-seeks on `qwen2moe`; this class of bug is designed out here, at the contract level, because it would not fail loudly.

---

## 4. The cache: sizing shape and honest expectations (D4, D5)

*The build is J-018's. This section is the contract J-018 must honour, plus the expectations the J-016 numbers actually justify.*

### 4.1 Sizing contract (binding on J-018)

1. **Sized at open, from free memory.** Budget = min(hard cap if set, free-at-open − reserve). Free memory is measured at model open, not assumed from total RAM.
2. **The reserve is real and stated.** Reserve = resident set (§2.2, measured from the directory) + runtime allowances (§2.3: KV allowance for the configured context, scratch) + memory left for the OS and other programs. The census records Janas's shape — free-at-open less a reserve (its default leaves a fifth of machine memory), `--cache` as hard cap (CENSUS.md J-002) — and Aesir adopts the *shape*; the reserve's exact composition and any default fraction are J-018's measured decision, reported at open. What is not permitted: a cache that sizes itself against total memory, or one whose reserve is zero.
3. **Hard cap, honoured exactly.** An Aesir flag + env equivalent (names are J-018/J-036's surface work) sets a byte cap the cache never exceeds — including transiently during admission (admit-then-evict over the cap is a violation; evict-then-admit, or refuse admission, is the contract).
4. **Bytes govern, pairs derive.** Capacity is a byte budget spent on pair entries of directory-true, layer-dependent sizes (§3.2). Any pair-count figure in statistics is derived and labelled with the mean pair size it implies.
5. **Resident bytes are never in the budget** — not counted, not evictable, not borrowable (§2).
6. **Shrinkable after open.** The cache exposes a reduce-budget operation that sheds entries without corrupting in-flight work (experts in use by the current token are pinned until that token's layer computation completes). J-028 owns the pressure policy; the mechanism contract is set here so J-018 builds it the first time.
7. **Statistics out, from day one.** Hits, misses, admissions, evictions, bytes streamed, per-policy counters — in the J-016 trace vocabulary ((layer, expert) pairs) so live runs and offline simulations stay comparable. J-024's tournament and J-020's cold/warm accounting both consume these; a cache without them cannot be graded and will not be accepted at J-034's gate.
8. **Policy is pluggable and frequency-informed.** J-016's simulations show frequency information is worth +11.6 hit points at 128 pairs (LFU 0.302 vs LRU 0.186, SIMULATED) and nothing at 512 (0.748 vs 0.741). J-018 must therefore ship a policy interface where eviction can see access frequency (a frequency-sketch or LFU-class policy must be *implementable* without restructuring), and must not hard-wire LRU as the permanent default. The default itself is J-024's tournament verdict, not this design's.

### 4.2 What size means, in pairs and bytes

Mean pair size on the traced model: 3,900,702,720 B ÷ 1024 pairs = 3,809,280 B (≈3.81 MB). J-016's simulated capacities translate as: 128 pairs ≈ 0.49 GB · 256 pairs ≈ 0.98 GB · 512 pairs ≈ 1.95 GB · 1024 pairs = 3.90 GB (the whole body). For other families the same *fractions of the expert body* are the transferable figure — ⅛, ¼, ½, all — because §1's saturation is a fraction phenomenon (79 % of pairs touched within 32 tokens), not an absolute-size one. State expectations as fractions first, bytes second, per model.

### 4.3 Expected hit rates and streamed bytes — the honest table

From J-016 §5.6 (SIMULATED on the recorded OLMoE trace; miss bytes = (1 − hit) × the 487,587,840 B cold ceiling):

| Cache (fraction of expert body) | LRU hit | LFU hit | Streamed/token at LRU |
|---|---:|---:|---:|
| 128 pairs (⅛, ≈0.49 GB) | 0.186 | 0.302 | ≈396.9 MB |
| 256 pairs (¼, ≈0.98 GB) | 0.453 | 0.496 | ≈266.9 MB |
| 512 pairs (½, ≈1.95 GB) | 0.741 | 0.748 | ≈126.4 MB |
| 1024 pairs (all, 3.90 GB) | 0.986 | 0.986 | ≈6.8 MB (cold misses only) |

What this table does and does not license:

- **Caching is nearly all-or-nothing on this size class** (J-016 §6's reading, adopted). Half the body still streams ~126 MB/token; an eighth streams ~397 MB/token — 81 % of the no-cache ceiling. Any Aesir claim of the form "small cache, big speedup" on an OLMoE-shaped workload is contradicted by this road's own measurements.
- **The real target class is harsher, not kinder.** Part II exists for models whose expert body is *many times* the cache (J-022/J-032 class). There the operating point is the table's left edge or beyond it — hit rates in the 0.19–0.30 class and streamed bytes in the hundreds of MB per token — where disk bandwidth, not cache cleverness, sets the token rate. J-019's disk discipline and J-023's under-load behaviour are therefore first-order slices, not polish. This design sets no tok/s expectation for that class: **NOT PROVEN** until J-022/J-032 measure it.
- **These are prompt-phase, single-model, single-trace figures.** Decode-heavy demand is **NOT PROVEN** (4 generated tokens in the trace). Per-type spread is real (§1): a code workload at the same budget should beat the table, a numbers workload should miss it. J-024 re-runs the tournament per text type; J-033's soak owns the decode-heavy trace.
- **Full residency is a legitimate configuration, not a cheat.** Where the expert body fits beside the resident set (OLMoE's 3.90 GB on a 39.5 GB machine), the cache degenerates to "everything resident after first touch" at hit 0.986 — the design must handle the degenerate case gracefully (it is the J-030 CPU-line shape) and must never *require* streaming to be exercised for correctness.

---

## 5. Failure modes, named, with their counters

### 5.1 Thrash — the central risk, and it is measured, not hypothetical

**Mechanism.** Thrash needs a working set larger than the cache and reuse distances longer than the cache can hold. J-016 measured both on this road's only trace: the 32-token working set already averages 805 of 1024 pairs, and the median reuse arrives after 298 other pairs have flowed past. A 128-pair cache therefore evicts the median expert ~170 pair-accesses before its reuse; a 512-pair cache holds the median reuse but not the p90 (716). With routing entropy at 5.9836/6.0 there is **no hot subset whose protection rescues a small cache** — the classic "pin the hot 10 %" counter does not exist for this workload shape. Any cache smaller than roughly half the expert body on an OLMoE-shaped demand curve lives in the thrash regime by construction.

**Counters (binding where marked).**

- *(Binding)* **Admission discipline:** an expert is not automatically admitted on first touch. J-018/J-024 must evaluate a probationary scheme (e.g. frequency-sketch admission, or a probationary segment that an expert leaves only on second touch) — the LFU-over-LRU gap at small capacities (+11.6 points at 128 pairs, SIMULATED) is the measured evidence that *refusing* admissions is worth bytes exactly where thrash lives. The tournament (J-024) picks the scheme; designing a cache with unconditional admit-on-miss is ruled out here.
- *(Binding)* **Bypass is a first-class outcome:** a miss may be served from disk *without* admission when the policy judges admission harmful, and statistics must count bypasses separately (a bypassed miss is the policy working, not failing).
- *(Binding)* **No silent collapse:** statistics (§4.1.7) must make thrash *visible* — hit rate, streamed bytes/token and eviction-before-reuse counts reported per run — because J-023's under-load test grades "no thrash collapse" from exactly these numbers.
- **Segmented protection (candidate for J-024):** a protected segment for experts proven recurrent, sized as a fraction of budget; its value on a no-hot-set workload is genuinely uncertain — it protects *recurrence*, not *hotness* — and it enters only through tournament evidence.
- **What does not counter thrash:** prefetch (§5.5 — it competes for the same budget), dropping (§7 — it changes the model, and is off by default), and larger readahead (J-019 reads what is asked; reading more of a saturating working set is reading the whole body sooner).

### 5.2 Cold start

**Mechanism.** The cache opens empty. The first token of the first prompt can owe the full cold ceiling (487.6 MB OLMoE / 365.7 MB Granite / 337.4 MB `qwen2moe`, MEASURED ceilings), and the first 32 tokens already demand ~79 % of all pairs (OLMoE) — cold cost is not a first-token wrinkle, it is a first-prompt regime. The compulsory-miss floor is 1.39 % of accesses even at full capacity.

**Counters.**

- *(Binding)* **Cold is reported, never averaged away.** Every number this road publishes separates cold-cache from warm-cache behaviour (J-020 owns the measurements; J-069 owns the same honesty for prefill). A steady-state tok/s quoted over a run whose cold prompt is inside the average is a misquote by this road's standards.
- **Warm-up is a measured option, not a promise.** J-020 designs the warm-up pass (predictable early experts prefetched during prompt reading). This design records the constraint J-020 must design against: on a saturating working set, "the predictable early experts" for OLMoE-class demand is most of the model — warm-up pays only where demand is genuinely narrower than the body (larger models, code-like local workloads at 700 pairs/100 tokens) — and J-020 must show the narrowing on traces before warming anything.
- **Persistence of the warm *map* (which experts, not bytes) is J-027's question**, decided there on measured benefit. This design neither requires nor forbids it; it requires only that a cold start with no map remains fully correct.

### 5.3 Memory-pressure shrink

**Mechanism.** Free memory at open is not free memory forever: another process takes RAM mid-run and a cache sized to the open moment becomes an overcommit. Janas's own README warns its cache can push a low-headroom desktop into swap (CENSUS.md J-002, documented behaviour of the mirror, recorded here as the failure being engineered against — not as an Aesir measurement).

**Counters.**

- *(Binding)* The shrink mechanism of §4.1.6: budget reduction sheds coldest/least-valuable entries first (policy-ordered), pins in-flight experts, and completes within the current token — the run continues at a smaller cache, it does not die with the allocator.
- *(Binding)* **The cache sheds before anything else does.** Under pressure the order is fixed: expert cache shrinks → (at the floor) the run refuses cleanly with the reason stated. The resident set and the KV cache are never cannibalised to feed the expert cache, and the expert cache is never defended at the cost of swapping the machine. J-028 builds and measures this behaviour; the *ordering* is decided here.
- **A floor exists.** Below a minimum useful budget (J-018 sets the number; a cache smaller than one token's full routed demand — 128 pairs OLMoE-class — cannot even hold a single token's working set) the honest behaviour is to say so at open rather than to stream-thrash silently.

### 5.4 The soft selection boundary

**Mechanism (MEASURED, J-016 §5.5).** The router's 8th seat is a near-tie: margin < 0.01 in 97.8 % of token-layers, < 0.001 in 43.3 %. Consequences this design treats as facts:

1. **Exact top-k membership is not a stable cross-implementation quantity.** Quantisation and summation order flip boundary seats between two honest engines. Faithfulness grading on this road is therefore distributional by construction (teacher-forcing rank + logit gap on the raw prompt, per the road's raw-oracle discipline) — never "did both engines pick the identical 8 experts", which would manufacture failures in neither engine's maths (the comparator-artifact verdict class).
2. **Prefetch must cover probability mass, not chase a predicted set.** A one-layer-ahead prefetch (J-025) that bets its bytes on an exact predicted top-k spends the cache budget on seats that are coin-flips. *(Binding on J-025's design input from here):* prefetch candidates are ranked by router probability mass with a margin-aware cutoff, prefetch bytes are capped as a fraction of budget, and prefetched-but-unused bytes are a reported statistic — J-025 keeps the feature only if it pays on the real traces, per its roadmap text.
3. **Cache statistics must not read boundary flips as policy signal.** An expert entering/leaving the top-k across near-identical runs is workload weather, not evidence about the eviction policy; J-024's tournament compares policies on hit/streamed aggregates over whole traces, per text type.
4. **The boundary is where dropping does its damage** — see §7: "light" experts cluster exactly at the near-tie mass, so a dropping threshold selects differently under every honest implementation. The softness is a load-bearing argument in the A1 decision, not a footnote to it.

### 5.5 Secondary failure modes, designed out or handed on

- **Slab stranding** (holding 2 of 3 slabs of an expert): designed out by atomic pair admission (§3.2). If a future sub-expert unit is ever proposed, it must re-argue against this mode with trace evidence.
- **Layout assumption** (one-run-per-layer): designed out by the directory-truth contract (§3.3).
- **Size miscount from mixed quant layers** (uniform-expert-size assumption errs up to 15 %/pair): designed out by directory-true per-pair sizes (§4.1.4).
- **Shared-expert misclassification:** designed out by the fail-safe residency default (§2.1).
- **Disk-queue contention** (streaming reads fighting the OS and other work — the machine must never be choked, per the accelerator-first law's standing rider): J-019 owns the read discipline and J-023 measures degradation under load; this design's contribution is the demand shape they must serve (3 seeks per miss, ≥442 KB extents, miss bursts at layer boundaries).
- **Speculative-verification demand spikes** (draft-check batches change expert demand per token): named here as a Part V interaction (J-080 owns measuring it); the cache contract's pin/bypass semantics (§4.1.6, §5.1) are the interface it will meet.

---

## 6. Interfaces handed to the next slices

*(Binding = J-018/J-019/J-020 must honour it or return to this design with measured counter-evidence. Open = theirs to decide and record.)*

### 6.1 J-018 — The expert cache

**Inherits as binding:** the pair as cache unit with atomic 3-slab admission (§3.2); byte-budget accounting at directory-true per-pair sizes (§4.1.4); open-time sizing from free memory minus a stated reserve under an exactly-honoured hard cap (§4.1.1–3); resident bytes excluded and non-evictable (§2, §4.1.5); the shrink mechanism with in-flight pinning (§4.1.6); statistics in J-016 trace vocabulary (§4.1.7); a pluggable, frequency-capable policy interface with no hard-wired LRU default (§4.1.8); admission discipline as a design requirement — unconditional admit-on-miss is ruled out (§5.1).
**Open for J-018:** flag/env names for the cap; the reserve's default composition/number; the initial shipping policy (LRU baseline for comparability is acceptable *as a baseline*, with the frequency-informed candidate beside it); segment structure, if any.
**Explicitly not J-018's:** the policy *verdict* (J-024), dropping (off; §7), warm-up (J-020).

### 6.2 J-019 — Disk reading discipline

**Inherits as binding:** the read pattern — 3 slab reads per missed expert, offsets/extents computed from the tensor directory only (§3.2, §3.3); slab extents are contiguous and ≥442,368 B in every witness; file order within a layer (e.g. OLMoE down→gate→up) is a layout fact, not a required read order. The comparison J-019 owes (streaming reads vs plain mmap paging on the same files, per its roadmap text) must use this design's miss stream — whole-expert demand at cache-dictated miss points — not a synthetic sequential read, or the verdict will not describe the system J-018 builds.
**Open for J-019:** I/O mechanism (direct/async vs buffered, as Mojo and the platform allow), readahead depth, queue depth, read ordering within a token's miss set. All measured, none pre-decided here.

### 6.3 J-020 — Cold and warm runs

**Inherits as binding:** cold and warm are separate published numbers everywhere (§5.2); the cold ceilings per family (§3.1) are the reference the cold measurements are read against; any warm-up prefetch spends from the same byte budget under the same hard cap (no warm-up memory outside the cap) and is margin-aware per §5.4.2; a no-map cold start remains fully correct (§5.2).
**Open for J-020:** the warm-up trigger and its expert-selection source (prompt-prefix routing statistics vs router-shadow — with §5.2's narrowing constraint as the evidence bar), and whether warm-up runs during prompt reading or before first token.

### 6.4 Later slices that consume this design (noted, not specified)

J-021 (dense spill re-expressed through residency: dense layers become the streaming unit — the residency/cache contracts above are written to admit a second unit type without redesign, but the unit-type extension is J-021's to specify); J-024 (policy tournament: §4.1.8, §5.1, §5.4.3 and the dropping trial of §7.3); J-025 (prefetch: §5.4.2); J-027 (warm-map persistence: §5.2); J-028 (pressure policy on §5.3's ordering); J-031 (streamed experts' compute placement: D7); Part III (the cap/reserve surface joins the placement option surface at J-036; the quality-tier surface that would carry any dropping knob is J-036's, per gate adjustment A2).

---

## 7. The A1 question — cache-conditional expert dropping (DECIDED)

### 7.1 The documented behaviour being answered

From the census (public documentation only; CENSUS.md J-002, delta row 5): when Janas's expert cache holds less than a fifth of a model's experts, a routed expert whose router weight falls below 0.8/k (0.95/k when the cache holds under a tenth), and which is not already in memory, is **not read**; its share is redistributed over the token's kept experts. Janas publishes agreement/speed tables for it at 2/4/8 GiB caches, governs it through its quality tiers, and offers a chat override that turns dropping off. Gate adjustment A1 named this behaviour into this slice: Aesir's design must take a position, not discover the question at J-024.

### 7.2 Aesir's position

**Dropping is OFF by default, available only as an explicit opt-in, never engaged silently or by cache pressure alone, and never present in any run whose output is graded for faithfulness or quoted as the model's speed.** Concretely, as binding contracts:

1. **Default off in every configuration** — every quality tier, every preset, every auto-choice. A future default change requires the §7.3 evidence and a state-file decision recorded against it; no slice may flip the default as a side effect.
2. **Opt-in surface only.** When the knob exists (its surface belongs to J-036's option family, per gate adjustment A2's one-surface ruling), enabling it requires the user to ask for it by name; a small cache, a slow disk, or a quality tier named "low" must never imply it.
3. **A dropped run is labelled, in its own output statistics, as approximate.** Drop count, dropped probability mass per token, and the cache fraction that triggered eligibility are reported (§4.1.7's statistics grow these fields when the feature is built). Any tok/s figure produced with dropping on carries the label wherever it is quoted.
4. **Never dropped:** resident-class tensors (the question does not arise — shared experts are resident, §2); the token's top-ranked expert; any expert already resident in cache (dropping a cached expert saves nothing and is incoherent — the documented rule agrees on this point).
5. **If built, the rule shape follows the evidence, not the mirror.** Threshold and cache-fraction triggers are parameters for J-024 to fit on Aesir's traces; the documented 0.8/k and ⅕ figures are the tournament's *starting candidate*, recorded here as Janas's published values, not adopted as Aesir constants.

### 7.3 Why — the reasons, in the order they bind

1. **Faithfulness is this road's currency, and dropping spends it by definition.** A run that skips a routed expert computes a *different function* from the model in the file. Under the road's raw-oracle discipline, faithfulness means teacher-forcing rank + logit gap against the true model's outputs; a dropped run's gap measures deliberate self-divergence, so its outputs can never carry a "faithful" verdict, and its speed can never be quoted as the model's speed. Janas accepts this trade inside published agreement tables; Aesir's stricter grading culture accepts the trade only where a user has explicitly bought it (contract 2) and only with the label on (contract 3).
2. **The soft boundary (§5.4) makes "light" an unstable set.** Dropping thresholds live exactly in the near-tie mass: 97.8 % of token-layers have their boundary margin under 0.01, and the weights just under a 0.8/k line are the same weights whose top-k membership flips between honest implementations. Two correct Aesir builds could therefore drop *different experts* on the same token — dropping is not merely approximate, it is implementation-dependent approximate, the least reproducible kind. (Dropping only *non-resident* experts adds a second instability: the dropped set depends on cache history.)
3. **The dropped experts are not dead weight.** J-016's cold fraction is 1.39 % and the median dropped-class expert recurs within a median of 3 tokens; the workload has no class of experts that are chosen rarely *and* lightly *and* never matter again. The saving per drop is one slab-triple read; the cost is a per-token error injected at every layer where the trigger fires, compounding across 16–32 layers.
4. **The regime where dropping triggers is the regime where its gain is least proven.** Eligibility (cache < ⅕ of the body) is the table's left edge (§4.3), where hit rates are already 0.19–0.30 and the binding constraint is disk bandwidth. Whether skipping the lightest non-resident experts buys meaningful tok/s there — after redistribution arithmetic and with code/numbers locality differences (§1) — is an empirical question with no Aesir measurement behind it today: **NOT PROVEN** either way, which is precisely why it goes to a tournament instead of into a default.

### 7.4 What would change this position

J-024's tournament, extended by this design into a **dropping trial**: on the J-016 traces plus live runs of the J-022 model, per text type, dropping on vs off at matched cache budgets, reporting (a) streamed bytes/token and wall tok/s gained, and (b) the agreement cost measured Aesir's way — teacher-forcing rank + logit gap of dropped vs undropped outputs on raw prompts. If a threshold exists where the gain is large and the gap stays inside the road's near-tie band (rank ≤2, sub-logit gap), the trial's record is the evidence a future decision may cite to offer dropping more prominently — still opt-in, still labelled. If the trial shows small gains or gaps outside the band, the refusal hardens and J-024 records dropping as measured-and-rejected. Either outcome closes A1 with evidence; this design's default stands until then.

---

## 8. What this slice does not prove, and open questions carried forward

- **No cache, reader or MoE execution exists because of this document.** Every performance figure is J-015/J-016 evidence or arithmetic on it, labelled as such. The first Aesir MoE run is J-022's to prove.
- **Router demand for Granite, `qwen2moe`, and all Part VIII families: NOT PROVEN** (§1). The design is parameterised so their traces, when J-022/J-032 extend the instrument, can contradict its expectations without contradicting its contracts; if a family shows a genuinely hot router (low entropy), §5.1's probationary machinery still applies but J-024's tournament gains a pinning candidate this design currently rules out for OLMoE-shaped demand.
- **Decode-phase demand: NOT PROVEN** (prompt-heavy trace). If decode routing is materially more local, cache expectations at decode improve; J-033's soak re-measures.
- **KV byte allowance: NOT PROVEN** (§2.3) — J-087 owns it; until then it is a named configuration value, not a measurement.
- **Dropping's gain and cost on Aesir: NOT PROVEN** both ways (§7.4) — J-024's trial owns the verdict.
- **Open questions recorded for their owners:** reserve default (J-018), I/O mechanism verdict (J-019), warm-up source and trigger (J-020), policy winner (J-024), warm-map persistence (J-027), streamed-expert compute placement (J-031), dropping knob's exact surface (J-036).

**Evidence files.** This document is the slice's deliverable; its evidence is the J-015/J-016 record (`~/workspace/model-tests/janas/J015_MOE_ANATOMY.md`, `J016_ROUTER_INSTRUMENTATION.md`, and their filed data). Filed in the repo under `docs/janas/`. No model files, no README, and no engine code are touched by this slice.
