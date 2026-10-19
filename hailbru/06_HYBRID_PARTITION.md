# 06 — Hybrid Partition: Two Accelerators, One Model, No Refusals

## The idea in one paragraph

Aesir already owns a working Nvidia backend — a hand-written CUDA path (`core/cuda_gate.mojo`, cuBLAS underneath, real end-to-end generations on Gemma 4 and Llama 3) — and this route puts it to work alongside the Hailo-10 instead of treating the two as rivals. An automatic **partitioner** walks a model's graph, assigns every subgraph the Hailo compiler verifiably accepts to HEFs on the chip, and assigns the residue — the poison op, the exotic activation, the shape the allocator hates — to the CUDA backend, with a boundary-minimizing scheduler and explicit tensor marshaling between the two devices. The Hailo takes the dense transformer bulk it is good at, at its ~2.5 W; the GPU absorbs the long tail; and **no model is ever refused for one bad op**, because a bad op is a routing decision, not a verdict. This is also the only route in the set whose fallback hardware is already built, tested, and inside Aesir today.

## Why it needs no precompiled or modified LLM

- The stock model is decomposed by Aesir's own partitioner from the stock file's graph facts; the Hailo-side pieces are compiled by the same Aesir-operated DFC intake any compile route uses, and the GPU-side pieces run through Aesir's existing CUDA kernels. Nothing is bought, downloaded precompiled, or modified — the model file is read, never rewritten.
- Partitioning is **per-deployment, not per-model-release**: the same stock GGUF can partition differently on a Pi-only host (Hailo + ARM CPU covers the residue) and on a desktop host (Hailo + RTX), because the partition is computed from the host's actual device inventory at install time.

## Architecture

```
 stock GGUF ──► GraphView (Aesir IR over the model's ops)
                     │
              Partitioner ──► Assignment: each op → HAILO | CUDA | HOST
                     │         (legality from probed compiler facts, §2;
                     │          cost from measured transfer/compute tables)
        ┌────────────┴─────────────┐
   Hailo side                   CUDA side
   subgraphs → DFC → HEFs       op ranges → existing cuda_compute kernels
        └────────────┬─────────────┘
              Marshal Layer (boundary tensors: pinned staging,
              format conversion, async copies on both links)
                     │
              StepScheduler ──► per-token dataflow across both devices,
                                double-buffered boundaries, one token pipeline
```

### Residue classes the partitioner expects (from the documented trap list)

The compiler's documented/attested weaknesses define the residue the GPU must be ready to absorb: trig-based RoPE spellings (the partitioner simply routes RoPE to CUDA until Aesir's constant-table form compiles clean — both spellings describe the same math, and the partitioner chooses per model); recurrent cells if a hybrid model carries them [documented unsupported]; exotic normalizations the parser rejects; the **LM head over a huge vocabulary** (a 128k–256k-vocab logits matmul is memory-shaped in a way the GPU already handles, and top-k can be computed GPU-side so only candidate logits ever cross back); sampling itself (already host/CUDA-side in Aesir). None of these is exotic *to Aesir* — they are the ordinary ops of its CPU/CUDA forward passes, which is the point: the residue lands on code that already exists and is already oracle-tested.

## The pseudocode

### 1. Legality probing — never guess what the compiler accepts

```text
struct OpCaps:                       # per (op-kind, pattern) — PROBED, versioned
    compiles: Bool                   # did a probe graph with this op compile?
    cost_class: Int                  # measured relative efficiency on-chip
    evidence: String                 # probe bundle id (docs/evidence discipline)

procedure probe_compiler(dfc, rt) -> OpCapsTable:
    # One probe per (op pattern × shape family) that Aesir's models actually use;
    # probes are tiny graphs compiled at install of the ROUTE (and re-probed when
    # the DFC/runtime version pair changes — the lockstep gate).
    for pattern in PATTERN_SUITE:    # rope-const, rope-trig, layernorm variants,
                                     # gelu spellings, swiglu, softmax forms, …
        r := dfc.try_compile(probe_graph(pattern))
        table[pattern] := { compiles: r.ok, cost: bench(r), evidence: bundle(r) }
    LEDGER.record("AES-H10-HYB-CAPS", table.hash, dfc.version, rt.version)
    return table
```

Guessing compiler support from documentation is how models die at 3 a.m.; the caps table is *evidence*, regenerated when versions move, and the partitioner consumes only it.

### 2. The partitioner

```text
struct Assignment: op_id -> {HAILO, CUDA, HOST}
struct CostModel:
    t_compute[op][device]      # measured/modeled per shape class
    t_cross[tensor]            # bytes / min(link_bw) + conversion cost
    boundary_penalty           # per boundary: fixed marshaling overhead

procedure partition(graph, caps, host) -> (Assignment, PartitionReport) raises:
    # Dynamic programming over the layer-linear backbone (decoder graphs are
    # chains of blocks with local branches — DP over segments is exact here):
    #   state = device of the previous segment boundary
    #   cost(segment on device d) = Σ compute + internal crosses
    #   transition adds the boundary tensor's crossing cost
    dp := DP over segments(graph) × {HAILO, CUDA, HOST}
    for seg in segments:
        for d in devices_present(host):
            if d == HAILO and not all(caps.compiles(op) for op in seg): skip
            dp[seg][d] := min over prev ( dp[prev] + seg_cost(seg, d)
                                          + cross_cost(boundary_tensor(seg), prev, d) )
    a := dp.argmax_path()
    # Hard constraints applied as infinite costs, stated plainly:
    #   - a segment on HAILO must form a DFC-compilable SUBGRAPH (static shapes,
    #     supported boundary dtypes) — legality is subgraph-shaped, not op-shaped
    #   - HOST is a legal device only for glue ops (sampling, template, control):
    #     the CPU never silently becomes the transformer (house law, enforced here
    #     in code: a partition whose transformer FLOPs land >5% on HOST is refused)
    report := { crosses: dp.boundaries, bytes_per_token_crossed: dp.cross_bytes,
                hailo_share_of_flops: dp.share(HAILO) }
    GATE("host-share", report.host_flops_share <= 0.05) or raise PartitionRefused(report)
    return (a, report)
```

The 5% host cap deserves its sentence: this route's entire reason to exist is acceleration honesty. A partition that quietly parks half the transformer on the ARM cores is the CPU-fallback sin wearing a partition costume, and the gate makes that partition *unrepresentable* — it raises, with the report attached, and the user chooses a different route with open eyes.

### 3. Marshal layer

```text
struct BoundaryTensor:
    producer_dev, consumer_dev: Device
    shape, dtype_src, dtype_dst           # e.g. Hailo INT8 vstream ↔ CUDA FP16
    scale: Optional[Float32]              # dequant params when crossing off-chip
    slots: [PinnedBuf; 2]                 # double-buffered pinned staging

procedure cross(bt, token_step) -> Future:
    if bt.producer == bt.consumer: return ready(bt.tensor)
    job := async_copy(bt.producer_slot → bt.slots[parity], stream = producer)
    job.then(convert_in_staging(bt))      # dequantize / cast / NHWC↔NCHW reorder —
                                          # conversion happens ONCE, in staging,
                                          # never inside either device's hot path
    job.then(async_copy(bt.slots[parity] → bt.consumer_tensor))
    return job.future                     # scheduler awaits futures, never spins
```

### 4. The step scheduler

```text
def decode_step(mut self, token) raises PartitionFault:
    fut := ready(embed(token))                       # host gather
    for seg in plan.segments_in_order:
        in_tensors := await_all(fut[seg.inputs])     # boundary futures resolve here
        match seg.device:
            HAILO: out := hailo.run(seg.hef_group, in_tensors)      # InferVStreams job
            CUDA:  out := cuda.run_segment(seg.op_range, in_tensors) # existing
                        # kernels via CUDAGate: forward ranges over the model's
                        # CUDA-resident weight store (cuda_upload discipline)
            HOST:  out := host_glue(seg, in_tensors)  # sampling glue, template math
        fut[seg.outputs] := out.futures
    logits := await(fut[head_segment])
    return sampler.sample(logits, sampling)
```

Decode is latency-chained (segment *k+1* needs segment *k*'s output), so cross-device pipelining pays mainly at **prefill** (chunk the prompt; chunk *n+1*'s Hailo blocks overlap chunk *n*'s CUDA residue) and in **multi-request serving** (request B's Hailo segments fill request A's CUDA bubbles). The scheduler implements both, and the partition report prices the single-stream case honestly — including the transfers — so a user whose workload is single-stream chat on a Pi + modest GPU sees the real number before choosing this route.

### 5. Weight residency

Hailo-side segments carry compiled weights inside their HEFs (the compile-route norm). CUDA-side segments keep weights in Aesir's existing CUDA store: uploaded once at load through `core/cuda_upload.mojo`'s pinned-staging discipline (64 MiB cap, chunked), resident in VRAM for the session. A segment's weights therefore live exactly where its compute lives — no per-token weight traffic on either device; the only per-token crossings are boundary activations, which the DP minimized by construction.

## How it plugs into Aesir as it exists

- **CUDA side is not new work**: `core/cuda_gate.mojo` (device lifecycle), `core/cuda_compute.mojo` (kernels + cuBLAS GEMM), `core/cuda_resources.mojo`, `core/cuda_upload.mojo`, and the two proven session types (`Gemma4CUDASession`, `Llama3CUDASession`) define the segment executor's contract. New code is the *segment* abstraction over them (`core/cuda_segment.mojo`), not new kernels.
- **Partitioner + scheduler + marshal** form a new package `aesir_engine/hybrid/`; the resulting session (`HailoCudaSession : ControlledTextSession`) is admitted by `core/runtime_plan.mojo` **as an extension of the existing CUDA plan path** (`choose_native_cuda_plan` gains a partition sibling), and served by `serve_loaded[T]` unchanged.
- **Hailo side intake** reuses the Aesir-operated DFC pipeline discipline (machine `.alls`, synthesized calibration, HEF cache in `cli/storage.mojo`) applied to *subgraphs* — smaller compiles, faster, and individually re-compilable when a caps re-probe moves a boundary.
- **Ledger**: `AES-H10-HYB-CAPS` (probe table), `AES-H10-HYB-PART-<model hash>` (assignment + report), joining the CUDA ledger family the engine already keeps.

## Pseudocode annex A — the pattern suite (what the caps prober compiles)

```text
PATTERN_SUITE := [
    matmul_dense,            # plain GEMM shapes from real model dims
    matmul_with_bias,
    rmsnorm_variants,        # axis spellings ×2 (the documented parse-killers)
    layernorm_variants,
    rope_const_tables,       # RoPE via Mul/Add on constants (expected: pass)
    rope_trig,               # RoPE via Sin/Cos (documented unsupported: the
                             # prober CONFIRMS rather than trusts the paper)
    swiglu_fused, swiglu_unfused,
    gelu_exact, gelu_tanh,
    softmax_row, softmax_masked,
    attention_gqa_block,     # whole-block translation attempt
    attention_composed,      # matmul+softmax+matmul composition
    lm_head_wide,            # vocab 128k/256k logits shapes
    sliding_window_attn,
    tanh_softcap,            # Gemma-2-style logit capping
    embed_gather_wide,
]
# Each probe is a tiny standalone graph with fixed small shapes (and a second
# run at a REAL model shape for the patterns whose failure is shape-shaped,
# e.g. lm_head_wide). Probing at install-of-the-route AND on version change;
# a probe crash is recorded as compiles=False with the crash as evidence —
# the table never contains a guess.
```

## Pseudocode annex B — cost model calibration

```text
procedure calibrate_costs(host, caps) -> CostModel:
    cm := CostModel()
    for dev in [HAILO, CUDA]:
        for shape_class in SHAPE_CLASSES:
            cm.t_compute[op][dev][shape_class] := bench_median(
                run_reference_op(op, dev, shape_class), reps = 20)
    for tensor_class in BOUNDARY_CLASSES:
        cm.t_cross[tensor_class] := bench_median(cross_and_back(tensor_class))
            # a REAL marshal round trip through the staging buffers of §3 —
            # copies + conversion — not a bandwidth datasheet number
    cm.boundary_penalty := bench_median(empty_segment_switch_cost)
    LEDGER.record("AES-H10-HYB-COSTS", cm.hash, host.fingerprint)
    return cm
    # The model is calibrated per HOST (link widths differ; a Pi's numbers
    # are not a desktop's) and re-calibrated when the device inventory changes.
```

## Pseudocode annex C — prefill chunk pipelining across devices

```text
procedure prefill_pipelined(plan, chunks):
    # Chunk n+1's HAILO segments may start while chunk n's CUDA segments run:
    # the devices are independent; only same-chunk segment order is sacred.
    inflight := {}
    for n, chunk in enumerate(chunks):
        for seg in plan.segments:
            deps := [inflight[(n, p)] for p in seg.predecessors]
            if seg.chunk_local_predecessor: deps += [inflight[(n-1, seg.id)]]
                    # only where the op is position-local (true for all but
                    # attention, whose KV deps the plan encodes explicitly)
            inflight[(n, seg.id)] := submit_after(deps, seg, chunk)
    await_all(inflight[last_chunk])          # decode begins from final logits
```

## Pseudocode annex D — the CUDA segment executor

```text
struct CudaSegment:
    op_range: (layer_lo, layer_hi, ops: List[OpKind])   # a contiguous run
    weights: CudaWeightStore        # resident VRAM copies, uploaded at load
    session_kind: CUDA_SESSION      # reuses the proven session machinery

procedure cuda_run_segment(seg, inputs: BoundaryTensors) raises CudaFault:
    # The segment executor is a THIN adapter over the existing backend:
    #  - weights were uploaded via cuda_upload.mojo's chunked pinned staging
    #    at session open (cap-respecting, journaled like all CUDA uploads)
    #  - compute calls cuda_compute.mojo's kernels / cuBLAS GEMM through
    #    CUDAGate's device context — no new CUDA code paths are introduced
    #    by this route; the novelty is entirely in partitioning/scheduling
    for op in seg.ops:
        dispatch_existing_kernel(op, inputs, seg.weights)
    return BoundaryTensor(from = CUDA, values = seg.outputs)

# Weight-store sharing: when the SAME model also has a pure-CUDA session
# type (Llama3CUDASession et al), the segment store and the session store
# are the same allocation discipline — a model loaded for hybrid serving
# does not double-upload its GPU-side weights.
```

## Pseudocode annex E — partition stability and re-partition triggers

```text
# A partition is a cached decision (in the HEF/build cache, keyed by model
# hash + caps table hash + cost model hash + device inventory hash).
# It is recomputed ONLY when an input changes:
triggers:
    caps_table.hash changed      (DFC/RT upgraded → re-probe → new legality)
    cost_model.hash changed      (host recalibrated; devices added/removed)
    model changed                (different hash — a different partition)
# A re-partition that moves a boundary invalidates only the affected Hailo
# segments' HEFs (segment-granular cache keys) — the compile cost of a
# boundary move is one small subgraph, and the report diffs old vs new
# assignment so the user sees WHAT moved and WHY (which probe/cost changed).
```

## Pseudocode annex F — the partition report (what the user actually sees)

```text
PARTITION REPORT — llama-3.2-3b (host: Pi 5 + Hailo-10H, RTX 4070 attached)
  segments:  HAILO  embed→L21 (1 HEF pair, contexts 5)
             CUDA   L22 attention (rope-trig spelling refused by caps#47)
             HAILO  L22 mlp → L27
             CUDA   lm_head (vocab 128 256 — caps: compiles, cost class poor)
  crossings: 3 boundary tensors · 24 KB/token · est. +1.9 ms/token vs all-CUDA
  shares:    Hailo 71% FLOPs · CUDA 29% · HOST 0.4% (glue only) ✓ ≤ 5%
  verdict:   hybrid WINS on power (est. 2.5 W + GPU bursts) and ties on
             latency within noise; all-CUDA remains one flag away.
# The report is generated from the DP's own arithmetic + the caps/cost
# hashes — and the LAST line always names the best SINGLE-device option
# too, because an honest partitioner argues against itself in print.
```

## Pseudocode annex G — session teardown across two failure domains

```text
procedure close_session(sess) :     # order is load-bearing:
    1. stop admitting steps (scheduler quiesce)     # no new submissions
    2. drain or CANCEL in-flight: Hailo jobs awaited to completion or
       fault (never abandoned — an abandoned async job owns buffers);
       CUDA stream synchronized via CUDAGate's existing discipline
    3. release marshal staging (both parities)      # pinned memory freed
    4. deactivate Hailo groups (reverse activation order); VDevice kept
       as the process singleton per field reports (release at exit only)
    5. CUDA weight store: freed or retained per store policy (a model
       likely to be re-served keeps VRAM residency under store LRU —
       the same judgment DurableModelStore makes for host RAM)
    6. ledger the session's totals: tokens, crossings, faults (zero or
       otherwise — a clean session's zeros are evidence too)
# A fault DURING teardown is logged and teardown CONTINUES: wedging a
# process because cleanup hiccuped is how devices stay locked.
```

## Pseudocode annex H — when the answer is "don't hybrid" (the partitioner's negative space)

```text
# The DP's output includes three degenerate assignments, all legitimate:
#   ALL_HAILO — residue empty (caps all pass, costs favor the chip):
#               the route gracefully becomes the plain compile route and
#               the CUDA side never initializes (reported, not hidden)
#   ALL_CUDA  — the Hailo side wins nothing (e.g. model too wide for any
#               compilable segment): the session is the existing CUDA
#               session; the report says the chip was considered and lost
#               on MEASURED costs — a result Volmarr's fleet planning can
#               use (it prices the Hailo's marginal value per model)
#   REFUSED   — host-share gate trips (Pi-only host + heavy residue):
#               the honest dead end, with the residue list attached so
#               the user sees exactly which ops to blame
procedure publish_assignment(a, report):
    LEDGER.record("AES-H10-HYB-PART", model.sha, a.kind, report.hash)
    # a.kind ∈ {HYBRID, ALL_HAILO, ALL_CUDA, REFUSED} — degenerate outcomes
    # are first-class ledger citizens, not silent fallbacks (house law:
    # a fallback you don't announce is a lie you maintain)
```

## Honest unknowns and risks

- **[inferred] Boundary economics.** Activation crossings per token are small (hidden-size vectors, KBs), but each crossing pays two runtime submissions' fixed costs; on latency-chained decode the partition only wins if boundaries are few — the DP is told so via `boundary_penalty`, tuned from measured submission overheads. If measured overheads are high, optimal partitions degenerate to "all-Hailo except one op" or "all-CUDA" — both are *fine outcomes the machinery discovers*, and the report shows which and why.
- **[documented risk] Two runtimes, two failure domains.** A step can now fail in HailoRT, in CUDA, or in marshaling; the scheduler's fault model treats any segment fault as a step fault (fail-closed, no partial-token emission), and session teardown follows Aesir's existing device-lifecycle discipline on both sides (`CUDAGate.close`, VDevice release as process-lifetime singleton per the field reports).
- **[inferred] DFC subgraph compiles at segment granularity** inherit every compile-route unknown (allocator behavior on unusual shapes, context counts) — mitigated by segments being small and probes being first-class: a segment that won't compile moves its boundary in the next partition, automatically, because the caps table is an input, not a hope.
- **[unknown] Pi + discrete GPU hosts are rare**; the common Pi deployment has no CUDA device. On such hosts the partitioner's CUDA slot is filled by the Hailo+HOST configuration under the same 5% host cap — which will refuse transformer-heavy residue and thereby *correctly* narrow the route's promise there. The document states this rather than letting a Pi user discover it.

## Smallest first prototype, gate declared in advance

**Build**: one model Aesir already runs end-to-end on CUDA — Llama 3.2 1B (profile `llama3_2` exists; `Llama3CUDASession` proven) — with a *forced* two-segment partition: layers 0–13 compiled to HEF via the standard Aesir intake, layers 14–end + head on CUDA, one boundary tensor at the layer-14 hidden state.

**Gate — PASS requires**: (1) 32 greedy tokens identical to the pure-CUDA session's output for the frozen prompts (the partition must be *semantically invisible*); (2) the caps probe suite runs and its table is ledgered; (3) measured per-token latency and crossing bytes appear in the partition report and are within 30% of the DP's prediction — the cost model is itself under test. Only then does the partitioner get to choose boundaries on its own.
