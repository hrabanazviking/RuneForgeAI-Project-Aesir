# 02 — Weights as Inputs: One Compiled Block, Every Model

## The idea in one paragraph

Every route that compiles a *model* pays the compiler's toll per model: parse, calibrate, allocate, wait. This route compiles a **shape** instead. A transformer block graph is written once with its weight matrices as ordinary graph **inputs** — tensors that arrive at run time like activations do — and the Dataflow Compiler is run once per *shape-class* (a bucket of hidden size, head geometry, and FFN width), not once per model. At run time Aesir pours a stock model's actual weights into those inputs, layer by layer, exactly as it pours activations. The compiled artifact knows nothing about Qwen or Llama or Gemma; it knows "a decoder block of these dimensions." Any stock model whose dimensions fit a compiled class runs — including models published after the class was compiled, with zero compilation, zero catalogue, and zero vendor involvement at model-install time. The compiler was operated a handful of times, on shapes; the models were never compiled at all.

## Why it needs no precompiled or modified LLM

- The stock GGUF is read by `loader/gguf.mojo` and its tensors are *transcribed* — dequantized/repacked by Aesir's own `core/compute.mojo` machinery into the input-plane format (§3) — in memory, at load time. The file is untouched; no derived model file is distributed or required.
- The HEFs in this route encode **no model's weights**. They are dimensioned machinery, like Aesir's CUDA kernels: `core/cuda_compute.mojo`'s GEMM does not contain Gemma's weights either, and nobody calls the kernel a modified model.
- Calibration — the step that usually ties a compile to one model — is done against the *weight distribution itself* for the weight inputs (§4), and against generic text activations for the activation paths. The class is calibrated once, for the class.

## Architecture

```
        OFFLINE (once per shape-class, on a build host)
   class spec (H, Hkv, I, V-free) ──► block graph with W as inputs
                                   ──► DFC: translate → calibrate → compile
                                   ──► class HEF set {block_hef, attn_hef, head_hef}

        ONLINE (per model, on the serving host — seconds, no compiler)
   stock GGUF ──► loader ──► per-layer weight transcription (planes + scales)
                          ──► WeightDeck: all layers resident in host RAM / module-adjacent
                          ──► HailoBlockSession: pour layer i, run block, pour layer i+1 …
```

Two graphs per class keep the attention bookkeeping honest: `block_hef` (norm → QKV projection → RoPE → MLP → residuals, with K/V for the *current* positions emitted) and `attn_hef` (scores/weighted-sum over the cache window), because attention over a growing cache has a different shape signature than the per-token block body. The final norm + LM head is a third small graph (`head_hef`) whose weight input is the (possibly tied) embedding matrix transposed.

### The shape-class system

A class is a tuple `(H, Hq, Hkv, I)` — hidden, query width, KV width, FFN intermediate — compiled at exact sizes. Models map to a class by **padding**: Aesir allocates the class's buffers and zero-pads weight rows/columns and activation lanes beyond the model's true dims, with a tail mask applied to logits (padded vocab lanes are forced to −inf before sampling — sampling is host-side in Aesir, so the mask is exact). Classes are few by design: the world's open LLMs cluster hard (512/1024/2048/2560/3072/4096 hidden covers nearly everything ≤8B). A model whose true dims exceed the largest class raises `ShapeClassOverflow` at load — a named refusal with the needed class spec printed, so the missing class can be compiled deliberately rather than the model silently cropped.

## The pseudocode

### 1. What a "weight input" costs — the honest arithmetic first

The compiler quantizes graph inputs as *activations*: an input tensor gets a scale/zero-point fixed at compile time from calibration [documented mechanics of input vstream quantization]. So a weight matrix arriving as an input is, to the chip, an activation-shaped tensor that happens to change rarely. Three consequences, each handled below:

1. **Weight precision through an input port is activation precision** — 8-bit (or 16-bit where pinned), not the 4-bit weight compression compiled weights enjoy. A W4 catalogue advantage does not survive this port; what survives is universality. The route's numerics therefore target A8W8-equivalent fidelity for poured weights, with the two-plane trick (§2) recovering an effective second byte where a model's accuracy demands it.
2. **Input quantization parameters are compiled constants.** The scale that maps a poured matrix's floats to input integers is chosen at class-compile time. Per-layer, per-model scales cannot ride *in* the quantization parameter — so they ride **in the data**: §2's format makes every poured matrix carry its own scale as a separate small input, and the graph's first operation dequantizes explicitly.
3. **Every pour is a PCIe transfer.** Re-binding a layer's weights costs the matrix's bytes over the link. §5 prices this and schedules around it; it is the route's true tax, stated before the design, not after.

### 2. The poured-weight format: planes and scales

```text
struct PouredMatrix:                 # one weight matrix, ready for the input port
    plane_lo:  Tensor[UInt8]         # low byte (or low nibble pair) of int16 codes
    plane_hi:  Tensor[UInt8]         # high byte — present only in TWO_PLANE mode
    scales:    Tensor[Float32]       # per-output-channel scale, length = rows
    mode:      ONE_PLANE | TWO_PLANE

procedure transcribe_matrix(W_fp, mode) -> PouredMatrix:
    # Aesir-side, using core/compute.mojo dequantizers for GGUF K-quants first
    # if the stock tensor is Q4_K/Q5_K/etc: W_fp is the dequantized matrix.
    for each row r:
        s[r] := max(abs(W_fp[r])) / 32767.0        # int16 range across two planes
        code := round(W_fp[r] / s[r])              # int16 codes
        plane_lo[r] := code & 0xFF ; plane_hi[r] := (code >> 8) & 0xFF
    GATE("transcribe-roundtrip", max_err(W_fp, decode(PouredMatrix)) <= budget(mode))
        # budget declared per mode in the ledger before any model is admitted

# Inside the compiled block graph, the first ops for each weight input are:
#   W_int  := (plane_hi << 8) | plane_lo              (int16 reconstruction)
#   W      := W_int * scales  (broadcast per row)      (explicit dequantize)
# after which the block body is ordinary matmul math. The dequantize is part
# of the graph — visible, inspectable, and identical for every model.
```

ONE_PLANE mode (int8 codes, one scale per row) halves transfer bytes and is the default; TWO_PLANE is admitted per-matrix by the roundtrip gate when a matrix's dynamic range makes int8 codes fail its budget — the decision is per-matrix, recorded in the model's admission report, never global and never silent.

### 3. The block graph (compiled once per class)

```text
graph block_graph[H, Hq, Hkv, I]:            # all dims are compile-time literals
    inputs:
        x            [1, S, H]  Float32-via-vstream   # hidden states (S = 1 decode,
                                                      #  S = bucket for prefill)
        wq, wk, wv, wo           PouredMatrix inputs  # attention projections
        wgate, wup, wdown        PouredMatrix inputs  # MLP
        n1_g, n2_g   [H]         # norm gains (weights too — poured, not baked)
        cos_t, sin_t [S, head_dim/2]                  # RoPE tables from the SESSION
                                                      # (constants would bake one theta)
        attn_mask    [S, S] or [1, C]                 # session-supplied
    outputs:
        y            [1, S, H]
        k_new, v_new [1, S, Hkv]                      # to the session's KV store

    body: (the standard block, written in the DFC-friendly dialect —
           explicit norm subgraph, no Sin/Cos nodes, no dynamic dims)
        h  := rmsnorm(x, n1_g)
        q  := matmul(h, dequant(wq)); k := matmul(h, dequant(wk)); v := matmul(h, dequant(wv))
        q, k := rope(q, k, cos_t, sin_t)
        emit k_new, v_new                              # session appends to cache
        ...

graph attn_graph[H, Hq, Hkv]:                # cache-window attention, per step
    inputs: q [1, S, Hq], k_cache [1, C, Hkv], v_cache [1, C, Hkv], mask [S, C]
    output: attn_out [1, S, Hq]
```

RoPE tables as inputs deserve the emphasis: the catalogue bakes one model's θ into its HEF; this graph takes θ from the session, so **the class serves models with different RoPE bases and scaling** — one of the quiet ways "one graph per model" smuggles model identity into a compile, removed here by construction.

### 4. Calibrating a graph whose inputs include weights

```text
procedure calibrate_class(class_spec) -> calib_set:
    # The calibration set must span BOTH input families:
    #  (a) activation inputs x: hidden states from real text, harvested by
    #      running Aesir's CPU forward over the bundled corpus for a spread of
    #      REAL models in this class (their layer-i inputs are drawn from the
    #      same distribution family the graph will see in service);
    #  (b) weight inputs: the actual transcribed matrices of those same models —
    #      the weight-input ports' calibration data IS weights, so their input
    #      ranges cover the true operating range by construction.
    acts := []
    for model in class_reference_models(class_spec):       # 3–5 stock models
        acts += harvest_layer_inputs(model, corpus, layers = all)
        acts += transcribe_all_matrices(model)             # as weight-input samples
    GATE("calib-count", len(acts) >= 1024)                 # the documented floor
    return acts
```

Quantization parameters for the *activation* ports come out of this calibration in the ordinary way. The weight ports' explicit-dequantize design (§2) means their input scale only needs to cover the int-code planes' byte range — a range that is [0, 255] by construction, so the port quantization is near-lossless for the planes themselves; the precision story lives in the codes, where the roundtrip gate polices it.

### 5. The run-time engine: pouring, pipelining, and the tax

```text
struct HailoBlockSession : ControlledTextSession:
    cls:     ClassHefs                 # block/attn/head HEFs for the model's class
    deck:    WeightDeck                # every layer transcribed, host-RAM resident
    kv:      KVCache                   # Aesir-owned (host RAM or module DRAM staging)
    dev:     HailoGate.VDevice

    def step_decode(token) raises:
        h := embed(token)
        for i in 0 ..< n_layers:
            job := dev.submit(cls.block, bindings(
                        x = h, weights = deck.layer[i].attn_mlp_planes(),
                        cos_t = rope_table(pos, model.theta), ...))
            (h, k_new, v_new) := job.wait()          # sequential per layer in v1:
                                                     # the pour of layer i+1 CANNOT
                                                     # overlap layer i's compute on
                                                     # one configured group [unknown —
                                                     # see §Unknowns]; the pipeline
                                                     # below is the admitted design
                                                     # target once overlap is proven
            kv.append(i, pos, k_new, v_new)
            h := dev.run(cls.attn, {q: h.q_part, k_cache: kv.k[i], v_cache: kv.v[i]})
                        # NOTE: block/attn split means q leaves block before scores;
                        # the block graph emits q alongside k_new/v_new (see graph def)
        logits := dev.run(cls.head, {x: final_norm(h), w: deck.lm_head_planes()})
        return sampler.sample(mask_padded_vocab(logits), sampling)
```

**The tax, priced.** Per decode token, the poured bytes equal the model's full weight bytes in the chosen plane mode (int8 codes: ≈1 byte/param; a 1.5B model ≈ 1.5 GB) — against PCIe Gen3 x1 on the Pi (≈0.8 GB/s effective [inferred from link rate]) that is a hard ceiling near **0.5 tok/s** in ONE_PLANE, and x4 hosts (≈3.2 GB/s) near **2 tok/s**, before compute. This route does **not** beat a resident-weights design on raw decode speed, and the document does not pretend otherwise. Its wins are elsewhere: (a) **zero per-model compile** — a new model runs the minute its GGUF lands; (b) **memory** — the chip holds machinery, not a model, so model size is bounded by host RAM and transfer patience, not by what one compile could fit; (c) **prefill batching amortizes the pour**: at batch/bucket S, one pour serves S positions, so throughput-bound workloads (bulk summarization, multi-user serving with continuous batching) divide the tax by S. The session therefore admits a `pour_policy`: `PER_TOKEN` for interactive single-stream (accept the ceiling, it is printed in the admission report), `PER_BUCKET` for batched work, and `LAYER_RESIDENT` — a refinement where the deck pins the K layers whose pour cost dominates into *separately compiled weight-baked graphs* for a hot model, which is this route deliberately degenerating toward route 01 for models that earn it, by measurement, with the degeneration recorded in the ledger. A route that knows its own ceiling and names its successor is worth more than a route that hides both.

### 6. Error and gate discipline

```text
on_load(model):
    cls := class_for(model.dims) or raise ShapeClassOverflow(needed = model.dims)
    for each matrix: transcribe with roundtrip GATE (above) or raise PrecisionRefused(matrix)
    admission_report := { class, plane_modes, pour_bytes_per_token,
                          ceiling_tok_s := link_bw / pour_bytes }   # printed, always
    LEDGER.record("AES-H10-WAI-ADMIT", model.sha, class.id, admission_report.hash)

on_step_fault(completion.exception != None): raise HailoFault — never retry-pour
    silently; a torn transfer must surface, because a half-poured matrix computes
    a wrong model very confidently.
```

## How it plugs into Aesir as it exists

- **Transcription** reuses `core/compute.mojo`'s dequantizers (Q2_K–Q6_K already implemented and oracle-tested) and `loader/packed_gguf.mojo`'s packed-offset reading; the WeightDeck is a new resident structure beside `core/dense_buffers.mojo`.
- **Class compilation** is build tooling under a `hailo/` package (same DFC-driving discipline as any Aesir-operated compile: version-pairing gate, log capture, `.auto.alls` archived) — but it runs **once per class**, so its products ship *with Aesir* as data files beside the engine, versioned like the tokenizer tables.
- **Runtime**: `core/hailo_gate.mojo` (FFI, the `CUDAGate` shape) + `core/hailo_block_session.mojo` implementing `ControlledTextSession`, admitted by `core/runtime_plan.mojo` with the pour ceiling in the plan's cost fields — `serve_loaded[T]` hosts it unchanged.
- **Ledger**: `AES-H10-WAI-CLASS-<id>` per compiled class (born on its compile gates), `AES-H10-WAI-ADMIT` per model admission.

## Pseudocode annex A — class enumeration and the padding contract

```text
procedure enumerate_classes(catalogue: List[ModelDims]) -> List[ClassSpec]:
    # Classes are compiled for the dims the world actually ships. The builder
    # takes a census of target families (Aesir's model_registry knows them)
    # and emits EXACT classes for the common geometries plus PADDED classes
    # at powers-of-two-ish landings for the long tail.
    exact := unique(catalogue.dims where census_count >= 2)
    padded := { (2048, …), (4096, …), (8192, …) }        # tail catchers
    return exact ∪ padded

procedure map_to_class(dims) -> (ClassSpec, PadPlan) raises ShapeClassOverflow:
    for cls in classes_ascending:
        if dims.H <= cls.H and dims.Hkv <= cls.Hkv and dims.I <= cls.I
           and dims.vocab <= cls.vocab_cap:
            pad := { H: cls.H - dims.H, rows: per-matrix row padding,
                     logits_mask: lanes [dims.vocab, cls.vocab_cap) := -inf }
            return (cls, pad)
    raise ShapeClassOverflow(dims)     # the report names the class to compile

# Padding exactness rules the planner enforces mechanically:
#  - weight matrices: zero rows/cols appended; a zero row contributes exactly 0
#    to any dot product — padding is arithmetic identity, not approximation
#  - activations in padded lanes: forced 0 after every block (lane scrub in the
#    session loop) so stale values can never leak into a real lane via norm
#    statistics — RMSNorm over padded lanes would NOT be identity, hence the
#    scrub + the norm computed over TRUE lanes only (norm subgraph variant per
#    class carries the true-H as a compiled constant per MODEL BINDING —
#    classes compile norm in true-H-parameterized sub-variants; the admission
#    report states which variant served the model)
```

## Pseudocode annex B — the transcription pipeline at working depth

```text
procedure transcribe_all(model) -> WeightDeck raises PrecisionRefused:
    deck := WeightDeck(model.sha)
    parallel for tensor in model.tensors where tensor.is_weight:
        # parallelism: host-side worker pool (build/load time is CPU-rich);
        # each worker is independent; failures are collected, never swallowed
        w := compute.dequantize(tensor)              # Q2_K..Q6_K / F16 / F32 paths
        mode := deck.default_mode
        pm := transcribe_matrix(w, mode)
        if roundtrip_err(pm, w) > budget(mode):
            pm := transcribe_matrix(w, TWO_PLANE)   # escalate THIS matrix only
            if roundtrip_err(pm, w) > budget(TWO_PLANE):
                raise PrecisionRefused(tensor.name, errs)   # named, fatal, logged
            deck.note_escalation(tensor.name)
        deck.set(tensor.name, pm)
    deck.freeze()                                    # decks are immutable in service
    LEDGER.record("AES-H10-WAI-DECK", model.sha, deck.stats.hash)
    return deck

struct WeightDeck:
    layers: List[LayerPlanes]        # attn {wq,wk,wv,wo}, mlp {gate,up,down},
                                     # norms as plain FP32 tensors (small)
    lm_head: PouredMatrix
    stats: { bytes_per_token_pass, escalations: List[name], modes: histogram }
```

## Pseudocode annex C — a worked admission (the arithmetic, printed for a real shape)

```text
# TinyLlama-1.1B, ONE_PLANE: 22 layers × (attn 4×2048² + mlp 3×2048×5504) int8
#   attn/layer  ≈ 16.8 MB ; mlp/layer ≈ 33.8 MB ; total ≈ 1.11 GB/token-pass
# link x1 ≈ 0.80 GB/s → ceiling ≈ 0.72 tok/s single-stream (printed, not hidden)
# link x4 ≈ 3.2  GB/s → ≈ 2.9 tok/s
# batched B=32 on x1: pour amortizes → bound moves to compute; plan prints the
# crossover batch where max(Tc,Tt) flips from transfer-bound to compute-bound.
# The admission report is GENERATED from the deck's real byte counts by
# price_model() — the numbers above are the shape of its output, recomputed
# per model from measured link probes, never copied from this document.
procedure price_model(deck, link_bw, tc_profile) -> AdmissionReport:
    for B in [1, 4, 16, 64]:
        step := Σ_layers max(tc(layer, B), bytes(layer) / link_bw)   # per STEP of B
        rows[B] := { tok_s: B / step, bound_by: argmax_side }
    return AdmissionReport(rows, deck.stats)
```

## Pseudocode annex D — the session loop with prefill, batching, and cancellation

```text
def run_prefill(mut self, tokens: List[Int]) raises:
    # Prefill in buckets S ∈ {64, 256, 1024}: for each bucket, ONE weight pass
    # serves S positions — the pour tax divides by S (the route's best case,
    # and the reason bulk-ingest workloads are its home turf).
    pos := 0
    for bucket in bucketize(tokens, self.cls.buckets):
        h := embed(bucket)
        for i in layers:
            (h, k, v) := dev.run(cls.block[S = len(bucket)],
                        weights = deck.layer[i], x = h,
                        rope = rope_tables(pos .. pos + len(bucket)))
            kv.append_range(i, pos, k, v)          # attention vs cache runs in
            h := attention_over_cache(i, h, upto = pos + len(bucket))
                        # chunked by cache window tiles so a 32k context never
                        # materializes a [S × C] score matrix at once: tiles of
                        # 1024 columns, online-softmax accumulation — the same
                        # tiling Aesir's CPU flash attention uses, so the ORACLE
                        # and the chip path agree by construction
        pos += len(bucket)
        if cancel_requested(): raise Cancelled   # generation_control's contract:
                        # cancellation lands at bucket boundaries, the KV state
                        # remains consistent (positions < pos are complete) and
                        # the session can resume or snapshot from exactly there

def continuous_batch_step(mut self, sessions: List[Session]):
    # Sessions sharing a class step in lockstep by LAYER: pour layer i once,
    # run every session's block for layer i against the same bound weights,
    # then advance. Weight traffic per token falls as 1/sessions — the deck
    # pour is the shared cost this design exists to share.
    for i in layers:
        dev.bind_weights(deck_any_session.layer[i])      # same model required:
        for s in sessions: s.partial[i] := dev.run_block(s.h)   # class-level
        for s in sessions: s.h := s.partial[i]                  # batching only
    # (batching across DIFFERENT models is refused by construction: the pour
    #  serves one model's layer; sessions are grouped by model at admission)
```

## Pseudocode annex E — the class compile gate (how a class earns admission)

```text
procedure admit_class(cls) raises ClassRefused:
    # A class is admitted on SYNTHETIC weights first: random matrices with
    # controlled dynamic ranges poured through every block — the class must
    # be numerically tame for ARBITRARY weights in range, not just lucky
    # for the reference models it was calibrated with.
    for trial in 1..8:
        W := synthetic_weights(cls, seed = trial, range_profile = trial)
        out_chip := run_block(cls, W, probe_activations)
        out_cpu  := cpu_block(W, probe_activations)
        GATE("class-fidelity", rel_err(out_chip, out_cpu) <= CLASS_TOL)
    # then on the reference models' real weights (calibration donors):
    for m in cls.reference_models:
        GATE("class-model-" + m.name, block_parity(m) <= CLASS_TOL)
    LEDGER.record("AES-H10-WAI-CLASS", cls.id, gate_report.hash)
    # A class that passes synthetics but fails a real model indicts the
    # CALIBRATION (activations out of family), not the machinery — the
    # report distinguishes the two, because the remedies differ entirely.
```

## Pseudocode annex F — the deck's memory residency policy

```text
# Decks live in host RAM; on small hosts (Pi 8 GB) a big model's deck is
# the RAM budget. Policy, enforced at admission:
procedure deck_residency(model, host_ram) -> Policy raises DeckTooLarge:
    bytes := deck.bytes
    if bytes <= 0.5 × host_ram: return RESIDENT          # the normal case
    if bytes <= 0.85 × host_ram: return RESIDENT_PINNED_CRITICAL
        # resident, but the admission report warns the host is committed;
        # other sessions on this host are refused until release
    return STREAMED_DECK   # matrices paged from the GGUF mmap on demand:
        # transcription becomes per-layer lazy (dequantize on first use,
        # LRU eviction of cold layers) — slower first pass per layer, same
        # steady state; the GGUF is ALREADY mmap'd by the loader, so the
        # "stream" is page cache + dequant workers, no new IO machinery
    # bytes > disk-backed feasibility: raise DeckTooLarge with the numbers
```

## Pseudocode annex G — norm-over-true-lanes, the one subtle correctness point

```text
# Padding safety proof sketch, enforced by construction (annex A) and
# restated here because it is the class design's easiest bug to reintroduce:
#  - MATMUL with zero-padded weight columns/rows: EXACT (zeros contribute 0)
#  - ELEMENTWISE ops on padded lanes: values there are garbage-shaped but
#    DISCARDED — safe iff every consumer either masks or re-derives
#  - RMSNORM: NOT lane-local (mean over lanes) → padded lanes pollute the
#    statistic → therefore norm runs in a TRUE-H-parameterized sub-variant
#    (compiled per class with the model's true H bound at session setup
#    from a small variant family), and attention softmax denominators are
#    computed over true heads only by the same mechanism
#  - LOGITS: padded vocab lanes masked to -inf host-side before sampling
# The admission gate runs a PADDED-vs-EXACT differential: the same model
# served through its exact class (if one exists) and through the padded
# class must agree token-for-token on the frozen suite. Padding earns its
# place by passing, per model, not by the argument above alone.
```

## Honest unknowns and risks

- **[unknown] Compute/transfer overlap on one configured group.** The async InferModel API is forum-attested with a finite queue [documented pattern in corpus 03]; whether pours for layer i+1 can DMA while layer i computes inside the *same* group is not publicly established. v1 is sequential and honest; the pipelined variant is gated on a measurement prototype, not on hope.
- **[inferred] Input-port throughput.** VStream input bandwidth for large weight tensors (vs the vision-sized tensors the API examples use) is unmeasured in public sources; the ceiling math assumes the link is the limit, which the prototype verifies or refutes.
- **[documented risk] Multi-context partitioning of the block graph** could split the block across contexts with per-switch traffic; `context_switch_param` and the profiler decide, and the class compile gate includes a context-count budget (a class whose block lands in >2 contexts is re-cut — e.g. attention fully into `attn_graph` — before admission).
- **[inferred] Accuracy of activation-quantized weight planes.** The explicit-dequantize design keeps the port quantization near-lossless for codes, but the block's *internal* activations still quantize in the ordinary DFC way; per-class KL gates against Aesir's CPU forward (frozen suite, budget predeclared) are the admission test for the class itself.

## Smallest first prototype, gate declared in advance

**Build**: one class, `(H=2048, Hq=2048, Hkv=256, I=5504)` (TinyLlama-1.1B's geometry: hidden 2048, 32 layers — the family Aesir's ARMVEGR stack already oracles), block + head graphs only, attention run on Aesir's CPU `flash_attention_gqa` for the prototype (the split is admitted in the prototype's own ledger entry).

**Gate — PASS requires**: (1) the same compiled block HEF executes layer weights from **two different stock models** of that geometry (TinyLlama-1.1B and one other 2048-hidden model), each producing block outputs within the predeclared tolerance of Aesir's CPU block forward; (2) the transcribe roundtrip gate passes for every matrix of both models in ONE_PLANE mode, or the failures are exactly the matrices TWO_PLANE was admitted for; (3) measured pour+compute per token is within 25% of the §5 ceiling model. If (1) fails, the route's premise — weights as inputs at usable fidelity — is false on this silicon and the document is retired to the evidence pile, not patched into a quieter claim.
