# 04 — The Weight-Streaming Pipeline: The Chip as a Layer-at-a-Time Engine

## The idea in one paragraph

A decoder LLM does not need its whole self on the chip at once; it needs **one layer at a time, in order, forever**. This route compiles a single generic dense-layer graph — parameterized by inputs, resident on the device for the whole session — and turns Aesir into a streaming engine: layer *i*'s weights flow across PCIe into the graph's weight ports while layer *i−1* is still computing, the token's hidden state walks the layer stack as a baton, and the only things that ever live on the chip are the machinery and one or two layers of weights. The engineering heart is not the graph; it is the **pipeline**: double-buffered weight slots, prefetch scheduling against a measured bandwidth model, and token batching that amortizes each layer's single crossing over many positions. Model size stops being a compile property entirely — a model's ceiling is the host's RAM and the user's patience for its per-token weight traffic, both of which Aesir can print before the first token is generated.

## Why it needs no precompiled or modified LLM

- The resident graph contains **no model's weights** — it is dimensioned machinery (a layer-shaped engine), compiled per shape-class on Aesir's build hosts and shipped as data with Aesir.
- Weights are transcribed from the stock GGUF in memory at load (`core/compute.mojo` dequantizers → weight planes), streamed, and discarded; the stock file is never written, and no per-model artifact of any kind is produced, cached, or required.
- Swapping models is swapping a stream source. A model released an hour ago streams the hour it lands.

## Architecture

```
   HOST                                    CHIP (resident all session)
 ┌───────────────────────────────┐        ┌──────────────────────────────┐
 │ WeightDeck (transcribed       │  PCIe  │  layer_graph (one class)     │
 │  planes, pinned staging ring)  │ ═════► │   slot A weights ─┐          │
 │ Prefetcher (lookahead queue)   │ ═════► │   slot B weights ─┴─► compute│
 │ Hidden-state baton buffer      │ ◄════► │   KV window port (per layer) │
 │ KV cache (Aesir-owned)         │        └──────────────────────────────┘
 └───────────────────────────────┘
   token step = L × (wait slot ready → run layer → hand baton onward)
   while prefetch of layer i+1..i+D overlaps compute of layer i
```

### The resident layer graph

One graph per shape-class, with **two weight slots** expressed as two input sets (A and B) and a slot-select input; the session alternates slots so a layer's weights are never being written while they are being read. Attention is inside the layer graph with the KV window arriving as inputs from Aesir's cache (the cache is Aesir's, as in any design where context is a runtime quantity rather than a compile-time bake [contrast documented: catalogue KV is baked at 2,048]). The LM head is a second tiny resident graph at the end of the walk; the embedding lookup is a host gather, per platform precedent.

### The bandwidth model — the route lives or dies by arithmetic

```text
per-token weight bytes   Wtok  = Σ_layers bytes(layer planes)          [one plane mode]
link effective bandwidth BW    = measured at session open (probe transfer), not datasheet
compute time per layer   Tc(i) = measured per class at calibration, per bucket size B
transfer time per layer  Tt(i) = bytes(i) / BW
sustainable step time          = Σ_i max(Tc(i), Tt(i))   when prefetch depth D ≥ 1
                                 (perfect overlap) — real target: ≥ 70% of this bound
decode ceiling (B = 1)         ≈ 1 / Σ max(Tc, Tt)
amortization                   : a weight crossing serves B positions at once;
                                 Tt per position = Tt / B  → prefill and batched
                                 decode divide the tax; single-stream decode pays it
```

Reference points, computed from documented hardware: PCIe Gen3 ≈ 0.985 GB/s per lane theoretical; Pi-class x1 effective ≈ 0.8 GB/s [inferred]; x4 ≈ 3.2 GB/s [inferred]. A 1.5B model in int8 planes (1.5 GB/token at B=1) ceilings near 0.5 tok/s on x1 and ~2 tok/s on x4 single-stream — and near **8+ tok/s at B=16 on x1**, because the crossing is shared. The route's honest home is therefore *batched and prefill-heavy work and patient interactive use*, with the admission report printing the user's own numbers from their own link probe. A design that publishes its ceiling on the tin is the opposite of the marketing this project exists to replace.

## The pseudocode

### 1. Session open: probe, don't assume

```text
procedure open_stream_session(model, device) raises StreamError:
    cls    := class_for(model.dims) or raise ShapeClassOverflow(model.dims)
    deck   := transcribe_all(model)                 # planes in host RAM, per layer
    bw     := probe_bandwidth(device)               # timed pinned transfers, 3 sizes,
                                                    # median taken; recorded
    tc     := class_compute_profile(cls)            # from the class's calibration bundle
    report := price_model(deck, bw, tc)             # §architecture formulas, per B ∈
                                                    # {1, 4, 16, 64}: ceiling table
    GATE("admission", report.ceiling[B=1] > 0)      # always true — the gate is that
                                                    # the report EXISTS and is shown;
                                                    # refusal is the user's, informed
    LEDGER.record("AES-H10-STREAM-ADMIT", model.sha, report.hash)
    ring   := PinnedRing(buffers = D + 2, size = max_layer_bytes(cls))
                                                    # mirror core/cuda_upload.mojo's
                                                    # bounded pinned-staging discipline
    return StreamSession(cls, deck, ring, bw)
```

### 2. The prefetch scheduler

```text
struct Prefetcher:
    deck: WeightDeck
    ring: PinnedRing            # slots cycle FREE → FILLING → READY → IN_USE → FREE
    jobs: AsyncJobTable         # HailoRT async submissions [documented pattern]

    def ensure_ahead(layer_index, depth D):
        for j in layer_index ..< min(layer_index + D, n_layers):
            slot := ring.claim(FREE) or return      # ring exhausted = compute is
                                                    # ahead of transfer; that's fine,
                                                    # the layer step will wait on j
            if slot.state == FREE:
                slot.begin_fill(deck.layer[j])      # DMA host→device weight port
                slot.mark_on_complete(READY)        # completion callback flips state;
                                                    # exception → session fault, §4

    def acquire(layer_index) -> Slot raises StreamFault:
        slot := ring.find(layer = layer_index)
        if slot == none:                            # prefetch fell behind (cold start,
            slot := ring.claim_any()                # mispredicted branch): synchronous
            slot.fill_now(deck.layer[layer_index])  # fill — slower, never wrong
        slot.wait_ready(TIMEOUT) or raise StreamFault("weight DMA timeout, layer %d")
        return slot
```

### 3. The token step (batched form; B=1 is the degenerate case)

```text
def step_batch(mut self, tokens[B]) raises:            # one step = B positions
    h := embed(tokens)                                  # host gather [B, H]
    for i in 0 ..< n_layers:
        self.prefetch.ensure_ahead(i, D = PREFETCH_DEPTH)
        slot := self.prefetch.acquire(i)
        with slot.held():                               # slot cannot recycle mid-run
            (h, k_new, v_new) := device.run(layer_graph,
                slot_select = slot.parity,
                weights     = slot.weights,
                x           = h,
                kv_window   = kv.window(i, positions),  # Aesir cache slice
                rope        = rope_tables(positions, model.theta))
        kv.append(i, positions, k_new, v_new)
    logits := device.run(head_graph, {x: final_norm(h), w: deck.lm_head})
    return sampler.sample_batch(logits)                 # core/sampler.mojo
```

Note what the loop *doesn't* do: it never touches a compiler, never names a model-specific artifact, and never waits for a whole-model load — the 8–17 s catalogue load times [documented] become a first-token cost of one layer's transfer (~tens of ms), because the stream starts at layer 0 while the rest is still "loading" in the only sense that matters: not yet transferred, already scheduled.

### 4. Fault discipline

```text
on DMA completion exception (slot):     raise StreamFault(slot.layer)
        # a torn weight plane computes a wrong layer confidently; the step dies,
        # the session closes, the fault is ledgered with the slot's byte counts.
on compute completion exception:        raise HailoFault (propagate, never re-pour
                                        and retry silently — a retry that succeeds
                                        hides a transport that is dying)
on baton checksum mismatch (debug builds): hidden-state spot checksums vs the CPU
        oracle for the first N sessions of a class — the streaming engine earns
        trust the way every Aesir subsystem does: measured, bundled, kept.
```

### 5. Prefetch depth and slot sizing — the tuning core

```text
procedure tune_pipeline(cls, bw, tc) -> (D, slot_bytes):
    # D must cover the transfer of the largest layer inside the compute of the
    # layers ahead of it:  D* = min{ d : Σ_{j<d} Tc(j) >= max_i Tt(i) }
    D := smallest d satisfying the cover inequality over the class profile
    if D > MAX_SLOTS: raise ClassUnstreamable("layer transfer cannot hide behind
        compute at any depth on this link — class requires a wider link or "
        "weight-resident route")            # named refusal, with the arithmetic
    slot_bytes := max layer plane bytes in class
    return (D, slot_bytes)
```

## How it plugs into Aesir as it exists

- **Pinned staging discipline** is ported from `core/cuda_upload.mojo` (bounded pinned buffers, 64 MiB cap thinking) to a `core/hailo_stream.mojo` ring sized by §5 instead of by habit.
- **The deck** is the shared transcription layer (`core/compute.mojo` dequantizers → planes) any weights-as-input design needs; **the session** is `core/hailo_stream_session.mojo : ControlledTextSession`, admitted by `core/runtime_plan.mojo` with the probe report as its plan evidence, and hosted by `serve_loaded[T]` unchanged.
- **Batching** hooks the engine's existing static-batching experience (`armvegr/batch.mojo`) and the serve layer's FIFO pending queue (`cli/native_serve.mojo`): queued requests are exactly the batch a stream wants.
- **Ledger**: `AES-H10-STREAM-CLASS-<id>` (class compile + profile) and per-admission reports under `AES-H10-STREAM-ADMIT`.

## Pseudocode annex A — the ring slot state machine, fully

```text
enum SlotState: FREE → FILLING → READY → IN_USE → DRAINING → FREE

struct RingSlot:
    state: SlotState
    layer: Int                  # which layer's planes it currently carries
    parity: Int                 # 0/1 → the graph's A/B weight-port select
    bytes: Int
    dma: AsyncJob               # the in-flight transfer, when FILLING

transitions (each guarded; an illegal transition is a StreamFault, not a no-op):
    claim(FREE, layer)            → FILLING   (begin DMA from deck)
    dma.complete & ok             → READY
    dma.complete & exception      → FAULT     (session-level: §4 of main text)
    acquire(READY)                → IN_USE    (held() guard during compute)
    release(IN_USE) after downstream slot acquired → DRAINING
    drain complete                → FREE      (buffer reusable for layer + stride)

invariant checked in debug builds after every step:
    no two slots hold the same layer; slot layers are a contiguous window
    [current, current + D]; parities strictly alternate along the window.
```

## Pseudocode annex B — the bandwidth probe (measured, never datasheet)

```text
procedure probe_bandwidth(dev) -> Float64:        # bytes/sec, effective
    results := []
    for size in [1 MiB, 8 MiB, 32 MiB]:
        buf := pinned_alloc(size); fill_pattern(buf)
        t0 := now()
        for rep in 1..5: dev.dma_write_scratch(buf) ; dev.dma_barrier()
        results.append(size * 5 / (now() - t0))
    bw := median(results)
    LEDGER.record("AES-H10-STREAM-PROBE", dev.id, bw, results)
    return bw
    # The probe runs at session open AND is re-run if a step's measured
    # transfer time exceeds the model by > 50% (thermal/link renegotiation
    # shows up as model error first — the session says so in its log).
```

## Pseudocode annex C — prefill chunking over the stream

```text
procedure prefill_stream(session, prompt_tokens) raises:
    # Prefill processes the prompt in position-chunks of C (e.g. 256):
    # each layer's weights cross ONCE per chunk, so per-token transfer cost
    # divides by C — prefill is where streaming is nearly free.
    for chunk in chunks(prompt_tokens, C):
        h := embed(chunk)
        for i in layers:
            slot := prefetch.acquire(i)
            (h, k, v) := device.run(layer_graph, slot, x = h,
                                    kv_append = positions(chunk))
            kv.append_range(i, chunk.positions, k, v)
        session.note_prefill_progress(chunk.end)      # resumable: a cancelled
            # prefill leaves the KV cache consistent at chunk boundaries —
            # the session can resume or discard by whole chunks only
```

## Pseudocode annex D — session telemetry and the soak discipline

```text
struct StepTelemetry:                  # written per step (ring log, sampled)
    layer_times: List[Duration]        # compute per layer
    wait_times:  List[Duration]        # time the step WAITED on slots —
                                       # the overlap's report card: waits
                                       # near zero = the pipeline is fed;
                                       # waits growing = the link is losing
    dma_bytes: Int; step_total: Duration

procedure session_watchdog(mut self):        # vordr's spirit, engine-side:
    every 64 steps:
        eff := overlap_efficiency(self.telemetry_window)
        if eff < 0.5 × self.admission_expectation:
            self.log_degradation(eff)        # said out loud in the session
                                             # log + plan evidence — streaming
                                             # sessions DEGRADE (thermal,
                                             # link renegotiation) and the
                                             # design's answer is to notice
                                             # and report, never to quietly
                                             # keep a stale promise in the UI
        if eff < 0.25 × expectation: raise StreamDegraded(eff)
                        # a session at quarter-efficiency is a fault, not a
                        # mood: fail-closed applies to performance claims too

procedure soak_profile(cls) -> Bundle:       # at class calibration time:
    run 10_000 steps of the layer loop; record step-time drift curve,
    device-reported temperature/utilization where hailortcli exposes them;
    the class profile carries the drift curve so admission reports quote
    SUSTAINED rates, not sprint rates.
```

## Pseudocode annex E — multi-model interleave on one stream

```text
# Two sessions (two models) on one device interleave by STEP, not by layer:
# the resident graph is class-shared; swapping models swaps the DECK, and a
# deck swap costs one full layer-window refill (D+2 layer transfers) — the
# scheduler therefore quantizes service in step quanta (e.g. 16 steps) and
# accounts swap costs in its fairness math explicitly.
procedure interleave(sessions, quantum = 16):
    while any_active(sessions):
        s := pick_next_fair(sessions)          # weighted fair queue over
                                               # accumulated step debt
        deck.activate(s.model)                 # no-op if already resident
        for _ in 1..quantum: s.step() or break
        s.debt += quantum × s.weight
```

## Pseudocode annex F — cold start and first-token path

```text
procedure first_token(session, prompt) -> Token:
    # The stream's structural gift: time-to-first-token is ONE layer's
    # transfer + the prefill of layer 0's chunk — not a whole-model load.
    t0 := now()
    prefetch.fill_sync(layer 0)                     # the only synchronous
                                                    # fill on the hot path
    h := run_layer(0, embed(prompt_chunk_0))
    telemetry.note("ttft-partial", now() - t0)      # reported honestly as
        # PARTIAL: the full prefill still owes (L-1) layer passes; the
        # session streams them while the user reads the first chunk's
        # logits only if the serving policy allows speculative decode —
        # default: NO speculation; TTFT is quoted for the complete
        # prefill, and the partial number is logged as engineering data.
    complete_prefill(prompt)                        # annex C's chunking
    return decode_step()
```

## Pseudocode annex G — the layer graph's port contract

```text
# The resident layer graph's ports, fixed at class compile (the session
# and the graph agree by construction — one PortTable data structure
# generates both the graph's inputs and the session's bindings):
PORTS(layer_graph):
    in  x            [B, H]              # baton
    in  w_slot_A     planes(scales…)     # slot A weight ports (per matrix)
    in  w_slot_B     planes(scales…)     # slot B — parity-selected inside
    in  slot_sel     scalar int          # 0 = A, 1 = B
    in  kv_win_k     [B, W, Hkv]         # Aesir cache window slice
    in  kv_win_v     [B, W, Hkv]
    in  rope_cos/sin [B, hd/2]
    out y            [B, H]              # baton, next layer
    out k_new/v_new  [B, Hkv]
# If a future HailoRT binding model cannot express dual slots in ONE
# graph, the fallback shape is two configured groups (A-graph, B-graph)
# with identical topology — the session logic is unchanged because it
# already speaks in parities; the class compile gate records which
# shape was built. (Recorded here so the design's assumption has a
# named contingency instead of a surprise.)
```

## Pseudocode annex H — worked numbers for two real shapes (the admission report's voice)

```text
# Qwen2.5-1.5B-class (28 layers, H 1536, I 8960), ONE_PLANE int8:
#   per-layer ≈ attn 9.4 MB + mlp 41 MB ≈ 50 MB → 1.41 GB/token-pass
#   x1 (0.8 GB/s eff): Tt/layer ≈ 63 ms; Tc/layer (B=1, est.) ≈ 6–10 ms
#     → transfer-bound; ceiling ≈ 0.55 tok/s single-stream (printed)
#   B=16 batch: Tt per position ≈ 4 ms; step bound flips to compute ≈
#     Σ Tc(B=16) → ≈ 4–6 tok/s aggregate (printed, from the class profile)
# TinyLlama-1.1B on x4 (3.2 GB/s): 1.11 GB → ceiling ≈ 2.9 tok/s B=1.
# Every number in an admission report is recomputed from the deck's real
# bytes, the session's probed bandwidth, and the class's measured compute
# profile — this annex shows the SHAPE of the output, with estimates
# labeled as estimates (Tc) and measurements labeled as measurements.
```

## Honest unknowns and risks

- **[unknown] True DMA/compute overlap within one configured group.** The async API's queue and callbacks are documented patterns; whether a weight-port transfer for slot B genuinely proceeds while slot A computes — rather than serializing inside the runtime — is the route's core empirical question. The prototype (§below) is built to answer it before anything else is built on top.
- **[inferred] Layer-graph input bandwidth.** Weight ports are activation ports; sustained bulk input streaming at link rate through vstreams is assumed by the model and must be measured (the probe does exactly this at the tensor level, not the marketing level).
- **[documented risk] Multi-context partitioning** of the layer graph would insert context switches *inside* every layer step; the class compile gate budgets contexts (≤1 target, ≤2 admitted with the cost printed) — a class that cannot fit its layer in budget is re-cut (attention split out) or refused for this route.
- **[inferred] Thermal/power under sustained streaming**: the chip's 2.5 W typical figure is documented for catalogue-style resident workloads; a permanently saturated link+core is a different duty cycle. The session logs `hailortcli`-visible utilization and the class profile includes a soak measurement (the gauntlet discipline: measure, don't fix).

## Smallest first prototype, gate declared in advance

**Build**: the streaming harness alone — class `(H=2048, I=5504)` layer graph with dual slots, a WeightDeck transcribed from TinyLlama-1.1B (Aesir's F1 fixture family), and a driver that streams **four layers in a loop** (layers 0–3, baton discarded each pass) while logging per-phase timings.

**Gate — PASS requires**: (1) measured overlap efficiency ≥ 70%: `(Σ max(Tc,Tt)) / (measured step time)` over 200 steps, from the harness's own phase logs; (2) baton outputs for a real 4-layer prefix match Aesir's CPU forward of the same prefix within the class tolerance; (3) the fault path proven by injection — a deliberately corrupted slot raises `StreamFault` and produces **no token**. If (1) fails, the overlap premise is false on this transport and the route contracts to its sequential form with its ceilings reprinted — a result, not a rescue.
