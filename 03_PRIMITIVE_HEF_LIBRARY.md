# 03 — The Primitive HEF Library: Aesir Interprets the Model

## The idea in one paragraph

Do not compile models at all — compile **verbs**. Aesir builds, once, a small fixed library of primitive graphs for the Hailo-10: a tiled matmul, an attention step, an MLP block, RMSNorm, RoPE application, softmax, and the sampling helpers that fit the chip. An LLM then stops being a graph the compiler must swallow whole and becomes a **program Aesir interprets**: a per-model execution plan — derived from the stock GGUF's own metadata — that calls the primitives in transformer order, token after token, while Aesir itself owns the KV cache in module/host memory and moves only activations and weight tiles between the chip and its own stores. The compiler's whole-model contract (one architecture, one compile, one bake) is sidestepped by never presenting it with a whole model. Where the whole-block route compiles a shape, this route compiles a *vocabulary* — and any sentence ever written in that vocabulary runs.

## Why it needs no precompiled or modified LLM

- The library contains **no model**: primitives are dimensioned machinery with weight *inputs* where a primitive needs weights (matmul, MLP), exactly as a CPU instruction contains no program.
- The **plan** for a model is data Aesir derives at load time from the stock file's metadata and tensor directory — the same act of reading Aesir's loader already performs. Nothing about the model is transformed, baked, or precompiled by anyone.
- A model published tomorrow runs if its architecture decomposes into the vocabulary — and when one doesn't, the failure is a *named missing primitive* in the ledger, an invitation to extend the library, not a dead end disguised as success.

## Architecture

```
   FIXED LIBRARY (compiled once, ships with Aesir, versioned like code)
   ┌ prim_matmul_tiled   [M-tile × K × N]   weights as input planes
   ├ prim_attn_step      q + KV window → out      (KV arrives as inputs)
   ├ prim_mlp_swiglu     x + 3 weight inputs → y
   ├ prim_rmsnorm        x + gain input → y
   ├ prim_rope           x + cos/sin inputs → y
   ├ prim_softmax        x → y        (row-wise, numerically guarded)
   └ prim_embed_head     x + head weight input → logits (top-k pre-trim on chip)

   PER MODEL (load time, milliseconds)
   stock GGUF ──► metadata ──► PlanCompiler ──► ExecutionPlan
                                                  (a flat list of PrimCalls
                                                   with buffer wiring)

   PER TOKEN (run time)
   PlanExecutor ──► HailoRT async jobs, double-buffered activation slots
   KVCache      ──► Aesir-owned: paged, in host RAM, window slices fed to
                    prim_attn_step as inputs; growth = plan-level concern
```

### The primitive signatures (the whole contract)

Shapes are class-bucketed like all static-shape work on this chip [documented: HEFs are fixed-shape]; each primitive is compiled for a small ladder of sizes and the planner picks the smallest covering bucket, masking tails host-side where the primitive's math allows exact masking (norm, softmax, attention) and raising where it does not (matmul N-dimension: padded weight columns produce padded output lanes that the *next* primitive's mask discards — safe only because every consumer in the plan is mask-aware; the planner proves this per plan, §3).

```text
PrimId :: MATMUL | ATTN_STEP | MLP_SWIGLU | RMSNORM | ROPE | SOFTMAX | EMBED_HEAD

struct PrimSignature:
    id: PrimId
    in_shapes:  List[Shape]        # bucketed literals, per compiled variant
    out_shapes: List[Shape]
    weight_inputs: List[String]    # which ports take poured weights (planes+scales)
    kv_inputs:     Bool            # ATTN_STEP only
    maskable_tails: List[Bool]     # per-output: may the planner pad this dim?
```

### The KV cache is Aesir's — that is the point

In the catalogue design the KV cache is baked into the HEF at a compiled capacity [documented]. Here it is an ordinary Aesir data structure — the same engineering object as `armvegr/kv_cache.mojo` and the engine's per-request `KVCache` — paged in host RAM (with an optional module-DRAM staging tier), grown, evicted, snapshotted, and shared by Aesir's existing conversation machinery (`cli/conversation.mojo`'s checksummed exact-token snapshots work unchanged, because the cache is *ours*). Context length becomes a memory budget, not a compile: 2,048 or 32,768 is a plan parameter, paid for in RAM and attention-step time, decided per request by `core/inference_memory.mojo`'s planner. Attention cost per step grows with the window — the plan reports it, the admission gate prices it, nothing hides it.

## The pseudocode

### 1. The plan compiler: model → program

```text
struct PrimCall:
    prim:     PrimId
    variant:  Int                  # bucket index into the compiled ladder
    inputs:   List[BufferRef]      # ACT slots, WEIGHT refs, KV refs, CONST refs
    outputs:  List[BufferRef]
    tail_mask: Optional[MaskSpec]  # exact masking where the planner proved it safe

struct ExecutionPlan:
    calls_prefill: List[PrimCall]  # per layer, parameterized by position window
    calls_decode:  List[PrimCall]
    buffers:       BufferTable     # every intermediate, sized, owned, lifetime-ranged
    kv_layout:     KVLayout        # pages, per-layer offsets, dtype (fp16 store)
    report:        PlanReport      # per-token bytes moved, per-token prim calls,
                                   # attention growth curve — computed, not promised

procedure compile_plan(bp: ModelBlueprint) -> ExecutionPlan raises PlanError:
    plan := ExecutionPlan()
    for layer in 0 ..< bp.n_layers:
        emit(plan, RMSNORM,  x = ACT.cur,        w = WEIGHT(layer.attn_norm))
        emit(plan, MATMUL,   x = ACT.cur,        w = WEIGHT(layer.wqkv_fused_or_split))
        emit(plan, ROPE,     x = ACT.qk,         w = CONST(rope_table(bp.theta)))
        emit(plan, ATTN_STEP,x = ACT.q,          kv = KV(layer), mask = MASK.causal_from(pos))
        emit(plan, MATMUL,   x = ACT.attn,       w = WEIGHT(layer.wo))
        emit(plan, RESIDUAL_ADD)               # fused into MATMUL epilogue where the
                                               # primitive offers it; else host-side —
                                               # a [H] add is cheaper on host than a
                                               # PCIe round trip; the planner decides
                                               # by the byte model, and says which
        emit(plan, RMSNORM,  ...)
        emit(plan, MLP_SWIGLU, x = ACT.cur, w = WEIGHT(layer.gate, layer.up, layer.down))
    emit(plan, RMSNORM, final)
    emit(plan, EMBED_HEAD, x = ACT.cur, w = WEIGHT(lm_head or tied embedding))
    plan.verify()      # every buffer defined before use; every tail mask proven;
                       # every weight ref exists in the model's tensor directory —
                       # or raise PlanError naming the exact call
    plan.report := plan.price()                # bytes/token on the wire, prim calls/token
    return plan
```

Fusions (QKV as one matmul vs three; norm folded into the following matmul's input stage) are *planner choices among primitives*, recorded in the plan — the library stays small and orthogonal; the cleverness lives in Aesir's planner, where it can be tested against Aesir's CPU oracle layer by layer.

### 2. The executor: a token step as a scheduled job graph

```text
struct PlanExecutor:
    dev:   HailoGate.VDevice
    lib:   PrimLibrary              # configured groups, one per primitive variant
    slots: [ActivationSlot; 2]      # double-buffered activation arena (host pinned)
    inflight: JobTable

    def decode_step(mut self, plan, token) raises HailoFault:
        act := slots.current()
        act.write_embed(embed_lookup(token))            # host gather (mmap table)
        for call in plan.calls_decode:
            job := self.dispatch(call, act)             # binds weight planes from the
                                                        # WeightDeck (host-RAM resident,
                                                        # transcribed once at load)
            if call.prim == ATTN_STEP:
                job.bind_kv_window(plan.kv_layout.window(pos))   # slice, not copy:
                                                        # pinned subrange registration
            job.submit_async()
            act := slots.flip_after(job)                # next call consumes on completion
            self.reap_oldest_if(queue_depth > ASYNC_BUDGET)     # documented finite
                                                        # queue: wait_for_async_ready
                                                        # discipline, never HAILO_QUEUE_IS_FULL
        logits := act.read_logits()
        return sampler.sample(logits, sampling)         # core/sampler.mojo

    def dispatch(call, act) -> Job raises:
        grp := self.lib.group(call.prim, call.variant)
        b := grp.create_bindings()
        for (port, ref) in zip(call.inputs, act.refs()): b.input(port).set_buffer(ref)
        return grp.run_async(b, completion_guard)       # guard raises on
                                                        # completion.exception — a torn
                                                        # primitive is a failed step,
                                                        # never a plausible token
```

Prefill is the same executor with the prefill call list (bucketed sequence tiles through the same primitives; attention over the prompt window in tiles). One executor, two programs — the prefill/decode distinction is data, which is precisely the freedom the compiled-model routes don't have.

### 3. The planner's safety proofs (plan-time, fail-closed)

```text
procedure plan.verify(plan):
    for call in plan.all_calls:
        for ref in call.inputs:
            if ref.kind == WEIGHT and ref.name not in model.tensors:
                raise PlanError("call %d wants tensor %s; stock file has no such tensor")
            if ref.kind == ACT and not plan.buffers.defined_before(ref, call):
                raise PlanError("call %d reads undefined buffer %s")
        if call.tail_mask and not prim(call).maskable_tails[call.masked_output]:
            raise PlanError("call %d pads a dimension its primitive cannot mask exactly")
    if plan.kv_layout.bytes > memory_budget: raise PlanError("KV plan exceeds budget")
    LEDGER.record("AES-H10-PRIM-PLAN", model.sha, plan.report.hash)
```

### 4. What a token costs, in the open

Per decode token, wire traffic = Σ (activation buffers between primitives that cross the link) + Σ (weight planes for primitives whose weights aren't already device-side). With weights poured per call, a 1.5B model moves ≈ its int8 weight bytes per token in the worst arrangement — the same physics any weight-streaming design pays (priced honestly in the streaming route's terms). The mitigations are planner-level and measurable: (a) **weight residency windows** — the executor keeps the *current layer's* planes bound while consecutive calls consume them (QKV + O + MLP of one layer ≈ 1/L of the model per layer-step, poured once per layer, not once per call); (b) **activation locality** — consecutive primitives in a layer share the activation slot with zero re-upload where binding lifetimes allow [unknown — binding lifetime semantics across calls in one group; the plan prices both the optimistic and pessimistic case and the admission report prints the measured one after the load test]; (c) batching across requests divides weight traffic by batch width. The plan report exists so these are numbers, not adjectives.

## How it plugs into Aesir as it exists

- **Planner inputs** are the `ModelBlueprint` facts Aesir already extracts: `core/model_registry.mojo`'s classification, `loader/gguf.mojo`'s tensor directory, the family profiles (`core/dense_gqa_profile.mojo`, `core/gemma4_profile.mojo`) whose comptime constants are exactly the dims the planner consumes.
- **The WeightDeck** (transcribed weight planes, host-resident) is shared engineering with any weights-as-inputs work — it lives in `core/` beside `dense_buffers.mojo` and reuses `compute.mojo`'s dequantizers.
- **KV cache** extends the engine's existing per-request `KVCache` discipline and `armvegr/kv_cache.mojo`'s paged layout experience; conversation snapshots (`cli/conversation.mojo`) keep working because the cache is Aesir's.
- **Runtime**: `core/hailo_gate.mojo` + `core/hailo_prim_session.mojo` : `ControlledTextSession`; admission via `core/runtime_plan.mojo`; serving via `serve_loaded[T]` unchanged.
- **Ledger**: `AES-H10-PRIM-LIB` (the library, per variant) and `AES-H10-PRIM-PLAN-<family>`; a missing-primitive refusal names the primitive to build — the ledger becomes the library's roadmap.

## Pseudocode annex A — the buffer table: lifetimes solved at plan time

```text
struct BufferTable:
    slots: List[BufferSlot]            # (size, dtype, device_side: HOST_PINNED)
    # Intermediate activations live host-side between primitive calls (each call
    # is a device round trip); the table is the plan's memory proof.

procedure allocate_buffers(plan) raises PlanError:
    live := {}                          # buffer -> last use index
    for (i, call) in enumerate(plan.calls):
        for b in call.outputs: live[b].born := i
        for b in call.inputs:  live[b].last := i
    # interval-graph coloring over lifetimes: two buffers share a slot iff
    # their [born, last] intervals are disjoint — classic, exact, small
    slots := color_intervals(live)
    GATE("buffer-budget", Σ slots.size <= ARENA_BUDGET) or raise PlanError(
        "activation arena exceeds budget: split the plan or shrink the bucket")
    plan.buffers := slots
    # The KV cache is NOT in this table: it is a separate, persistent structure
    # (§annex B) — activations are per-step weather; KV is climate.
```

## Pseudocode annex B — the KV cache manager (Aesir-owned, paged)

```text
struct KVCache:
    pages: PagePool                    # fixed-size pages (e.g. 16 positions/layer)
    index: Map[(layer, position) -> PageAddr]
    store_dtype: FP16                  # host store; fed to ATTN_STEP per window

    def append(layer, pos, k, v): page := index.page_for(layer, pos) or pool.alloc()
                                  page.write(pos % PAGE, k, v)
    def window(layer, upto, max_len) -> (Kwin, Vwin, mask):
        lo := max(0, upto - max_len)   # sliding policy is a PLAN parameter:
                                       # full history, sliding window, or
                                       # attention-sink + window — chosen per
                                       # model family by the planner, printed
                                       # in the plan report
        return gather(index, layer, lo..upto), mask_for(lo..upto)
    def snapshot() -> Bytes:           # conversation snapshots (cli/conversation
        return checksummed_serialize(pages, index)   # .mojo) work because this
    def restore(bytes): verify_checksum or raise SnapshotCorrupt   # is ours

# Sizing honesty: KV bytes = 2 × layers × Hkv × ctx × 2 (fp16). A 28-layer,
# Hkv 1024, ctx 32768 model = 3.7 GB host RAM. The plan report prints the
# number for the requested ctx BEFORE admission; inference_memory.mojo's
# planner arbitrates against the host's real RAM.
```

## Pseudocode annex C — continuous batching over the plan executor

```text
struct BatchScheduler:                       # serve-time, above PlanExecutor
    active: List[Session]                    # each with its own plan + KV cache
    def tick():
        # one decode step for every active session, but PRIMITIVE CALLS are
        # coalesced across sessions where prim + variant match: the weight
        # pour for (MATMUL, layer i, variant v) is shared by all sessions
        # stepping layer i in this tick — the deck pours once, N sessions eat.
        groups := group_by(active.next_calls(), key = (prim, variant, weights_ref))
        for g in groups:
            out := executor.run_group(g)     # one submission, per-session
                                             # activation slots, shared weights
            advance_all(g.sessions, out)
        reap_finished(); admit_waiting()     # serve layer's FIFO queue feeds in
# The coalescing is why a primitive library can beat its per-call overhead:
# overhead is paid per GROUP, tokens are produced per SESSION.
```

## Pseudocode annex D — the primitive variant ladders and selection

```text
# Every primitive is compiled across a LADDER of shapes; the planner picks
# the smallest covering variant per call. Ladders are few and shared:
MATMUL variants:  (M ∈ {1, 8, 32, 128, 512}) × (K, N ∈ class dims)
                  — K, N are NOT free per call: matmul variants are compiled
                  per (class, role) like the block routes' dims, because a
                  matmul's weight shape IS its dims. What the ladder buys is
                  the M (sequence) axis — decode M=1, prefill M=bucket —
                  and a small set of (K,N) tiles for the MLP's three shapes.
ATTN_STEP variants: window W ∈ {512, 2048, 8192, 32768} — the window is a
                  SHAPE here, so context growth crosses variants at powers;
                  between rungs, the KV slice is padded with masked pages
                  (exact: masked scores are -inf before softmax — the
                  primitive's mask input is load-bearing, and its golden
                  tests cover padded-window equivalence explicitly)
RMSNORM / ROPE / SOFTMAX variants: H ∈ class dims; sequence ∈ {1, buckets}

procedure pick_variant(prim, need) -> Variant raises PlanError:
    for v in ladder(prim).ascending:
        if v.covers(need): return v        # smallest cover — the allocator's
                                           # friend and the bandwidth budget's
    raise PlanError("no variant covers", prim, need)
        # a model needing an off-ladder shape refuses AT PLAN TIME with the
        # missing variant named — compiling a new variant is a library
        # release event, never a runtime surprise
```

## Pseudocode annex E — why the library stays honest: the missing-primitive protocol

```text
# When a new architecture arrives (a new norm kind, a new attention form):
procedure admit_model(bp) -> Plan | MissingPrimitive:
    needs := decompose(bp)                  # the family's op inventory, from
                                            # its profile in dense_gqa_profile /
                                            # gemma4_profile terms
    for op in needs:
        if op not in LIBRARY and op not in PLANNER_EMULATIONS:
            # planner emulations are compositions of primitives whose
            # equivalence the library's golden tests PROVE (e.g. GeGLU from
            # matmul + gelu-prim + mul) — an emulation is a theorem with a
            # test attached, not a hope
            return MissingPrimitive(op, family = bp.family)
    return compile_plan(bp)
# MissingPrimitive is a first-class admission outcome: the user sees
# "this family needs a `moe_route` primitive" — a work item with a name,
# filed to the ledger as the library's growth queue.
```

## Pseudocode annex F — the library's golden tests (each primitive, proven alone)

```text
# Before any plan runs, every primitive variant passes against Aesir's CPU
# implementation of the same op, on adversarial inputs:
test_matrix(prim):
    cases := [ zeros, ones, gaussian(σ=1), gaussian_with_outlier_channel(×60),
               denormal-adjacent smalls, alternating-sign patterns,
               the recorded activation tensors from a REAL model's layer ]
               # real activations are in the suite because synthetic data
               # has never once reproduced a quantization failure on demand
    for v in variants(prim): for c in cases:
        GATE(prim.name, v.id, c.id, rel_err(chip(prim, v, c), cpu(prim, c)) <= tol(prim))
# Tolerances are PER PRIMITIVE and predeclared in the library manifest:
# matmul looser (accumulation), norm tighter (it feeds everything),
# softmax tightest in the tail (small probabilities steer sampling).
# The manifest — variants, tolerances, gate results — ships with Aesir:
# the library's claims are inspectable data, like everything else here.
```

## Pseudocode annex G — the executor's job table and backpressure

```text
struct JobTable:                        # HailoRT async discipline, explicit
    slots: Ring[ASYNC_BUDGET]           # bounded — the documented finite queue
    def submit(job) raises QueueFull:   # never blocks silently: a full table
        s := slots.claim() or raise QueueFull   # is BACKPRESSURE the planner
        s.arm(job, completion_guard)            # must respect — plans carry a
        return s                                # max-inflight field, verified
    def reap_oldest():                  # in plan order (completions may land
        s := slots.oldest_outstanding   # out of order; the EXECUTOR consumes
        s.wait()                        # strictly in plan order — determinism
        s.release()                     # of the token stream is not left to
                                        # the device's completion ordering
# Why in-order consumption matters: greedy decoding must be reproducible
# run-to-run for the gate suites; async completion order is a device mood,
# so the executor absorbs it and presents plan order to the session.
```

## Pseudocode annex H — plan caching (programs are data; cache them like it)

```text
# A plan depends on (model sha, library version, memory budget, batching
# policy) — all hashed into the plan key; plans persist in the store
# beside the model's other derived data (they are small: KBs).
procedure get_plan(bp, lib, budget, policy) -> ExecutionPlan:
    key := hash(bp.sha, lib.version, budget, policy.id)
    if p := store.plans.get(key): return p.verify_against(bp)   # cheap
        # structural re-check — a cached plan is never trusted on its
        # own say-so; verify() re-runs (it is milliseconds) every load
    p := compile_plan(bp); store.plans.put(key, p); return p
# Plan compile is pure Aesir computation (no device, no DFC): worst case
# it costs a second at load. The cache exists for fleet consistency
# (identical plans across a user's machines), not for speed.
```

## Honest unknowns and risks

- **[unknown] Per-call overhead.** HailoRT calls are documented for whole-network inference; the fixed cost of a *primitive-sized* submission (binding, activation, transfer setup) is not publicly characterized. If per-call overhead is ~milliseconds, per-token call counts (~7 × layers) kill the route for small models; if ~tens of microseconds, it sings. The prototype measures this first — it is the route's existential number, and the document says so.
- **[inferred] Activation quantization seams.** Every primitive boundary quantizes/dequantizes through vstream formats [documented mechanics]; error accumulates across ~7 seams per layer instead of 1–2 in a whole-block compile. The FP32 vstream trick (`quantized=False, FormatType.FLOAT32` [documented]) at seams keeps seam error at conversion cost, not integer cost — at bandwidth price. The plan prices both; the KL gate adjudicates.
- **[documented risk] Context-switch and group-switch costs.** Many configured groups on one VDevice is the scheduler's home turf [documented ROUND_ROBIN model scheduling], but switch frequency here is per-token-per-primitive, far beyond the pose+face+landmarks pattern the scheduler is documented for. Mitigation designed in: variants grouped so a decode step's calls stay within as few groups as possible; measured, not assumed.
- **[inferred] Attention over host-resident KV** means the window crosses the link every step: at ctx 8192, KV bytes/step for a 1.5B-class GQA model are modest (tens of MB worst case in fp16 [computed from dims]) and grow linearly — the plan report prints the curve; long-context economics are the user's informed choice at admission.

## Smallest first prototype, gate declared in advance

**Build**: four primitives only (MATMUL, RMSNORM, ROPE, ATTN_STEP with host softmax admitted and ledgered as a prototype simplification), a hand-written plan for a **2-layer toy transformer** (dims 256/4 heads, weights random-but-fixed), executed against Aesir's CPU forward of the identical toy.

**Gate — PASS requires all three**: (1) 32 greedy tokens **identical** to the CPU oracle's sequence (toy scale admits exactness as the standard); (2) measured per-call overhead published in the evidence bundle — whatever it is — with the route's viability recomputed from the *measured* number for a 28-layer model and recorded next to the gate result; (3) the plan verifier demonstrably refuses a doctored plan (one call rewired to an undefined buffer) with the named error. A pass on (1) with a bad (2) retires the route honestly — the library then serves as the primitive substrate for coarser-grained routes, and nothing was wasted but nothing is oversold either.
