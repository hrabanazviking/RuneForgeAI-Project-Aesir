# 09 — The Clean-Room Compiler: HAILBRÚ's Heir

## The idea in one paragraph

Every other route in this set negotiates with some part of Hailo's software — the compiler, the runtime, the format. This route negotiates with **physics only**. Aesir's MÍMISBRUNNR campaign already built, from clean-room study, a hand-written userspace PCIe driver (HAILBRÚ) that carries the Hailo-10 to its **firmware-ready gate** (H095 PASS: firmware staged and SHA-256-verified, 100 power-management cycles clean), and a configuration generator (SMIÐR) that produced valid noop/memcpy/vecadd descriptors — and stopped at the **firmware wall** (H111 NO-GO), the undocumented activation contract between "firmware ready" and "network loaded and running," with the full clean-room record banked in `docs/plunder/` as the foundation for a future attempt. This route is that future attempt, designed in full: Aesir's own compiler from its internal graph IR down to chip configuration — context construction, action-list assembly, descriptor generation, activation submission — transported by HAILBRÚ, validated by a differential-testing harness against reference executions at every layer of the stack. No DFC, no HailoRT compile path, no vendor binary in the chain of custody between a stock model and a running chip. It is the longest road in this set, and the only one whose destination is *ownership of the whole stack* — which is why it is designed now, in full, before the first new line is cut: the campaign discipline that produced HAILBRÚ and SMIÐR (slices, gates, evidence bundles, laws) is the method, and this document is its campaign plan.

## Why it needs no precompiled or modified LLM

- The route *is* the refusal of precompiled anything: the compiler is Aesir's code, the transport is Aesir's code, the model is the user's stock GGUF read by Aesir's loader. The only vendor bytes in the system are the chip's own firmware image — the silicon's bootloader payload, staged by HAILBRÚ exactly as the vendor's driver stages it [plunder-documented behavior], whose SHA-256 HAILBRÚ verifies before boot. Firmware is the chip being the chip; everything above it is ours.
- Model semantics enter through Aesir's IR, lowered from the same blueprint facts Aesir's CPU forward executes — so the chip runs *Aesir's understanding of the model*, differentially tested against Aesir's own reference, never a conversion of a conversion.

## Architecture — and where the wall stands in it

```
 stock GGUF ──► Aesir IR (graph of ops over RuneTensors)
                    │  lowering passes (tiling, precision, scheduling)
                    ▼
             NetworkPlan: contexts[], action lists, buffer map, KV map
                    │  SMIÐR-descendant codegen
                    ▼
             ConfigBytes + DescriptorStreams  ──► Activation Protocol ◄── THE WALL
                    │                                 (firmware contract:
                    │                                  load → validate → run)
                    ▼  HAILBRÚ transport (proven to firmware-ready)
             Hailo-10 silicon
                    ▲
             Differential harness: every stage's outputs vs reference
             executions (CPU forward / emulator-class references / the
             vendor stack used ONLY as a test oracle, never in the path)
```

**The wall, stated precisely** [from the campaign record]: HAILBRÚ reaches the state where firmware is booted and the device reports ready. SMIÐR's descriptors are well-formed by every clean-room check. What is missing is the **activation contract**: the exact sequence — configuration upload format and chunking, validation handshake, context activation, stream binding, completion semantics — by which a booted device accepts a network and runs it. The vendor path that performs this (HailoRT + the closed components around HEF loading) is the thing the campaign's clean-room studies (`docs/plunder/`: hailort-drivers @ `309eb10`, HailoRT @ `f519590`, studied, no code taken) describe from the outside. This route's campaign is therefore front-loaded with *contract discovery by observation*: the vendor stack, run on Aesir's own hardware against Aesir's own known models, is a **legal oracle to observe** (bus-level and ioctl-level traces of one's own machine running one's own workloads) — clean-room method: specifications written from observation by the study side, implementation written from specifications by the build side, the plunder discipline (campaign law L3: HEF internals of vendor models forbidden as a code source; observation of *protocols on one's own device* is the HAILBRÚ precedent — HAILBRÚ itself was built exactly this way against the drivers).

## The pseudocode

### 1. The IR and its lowering

```text
struct IRGraph:                       # Aesir's own graph form (above core/compute)
    nodes: List[IRNode]               # op kind, input/output tensor ids, attrs
    tensors: TensorTable              # shapes, dtypes, lifetimes — static, whole model

struct NetworkPlan:
    contexts: List[ContextPlan]       # the chip executes networks as contexts;
                                      # contexts are the compilation unit [the
                                      # vendor format's own structure, observed]
    buffers: BufferMap                # every tensor → (DDR region | on-chip | stream)
    kv: KVCMap                        # cache regions per layer, capacity = PLAN choice
                                      # (2,048 is a number here, not a law of nature)

procedure lower(graph: IRGraph, target: ChipFacts) -> NetworkPlan raises LowerError:
    tiled := tile_pass(graph, target.tile_geometry)       # conv/matmul tiling to the
                                                          # fabric's native granules
    prec  := precision_pass(tiled, recipe_pins)           # A8W4/A8W8/A16W16 per tensor —
                                                          # the numeric laboratory's
                                                          # output, consumed as data
    sched := schedule_pass(prec, target.context_budget)   # partition into contexts,
                                                          # minimizing boundary traffic
    plan  := place_pass(sched, target.memory_map)         # DDR/on-chip placement,
                                                          # KV regions, stream endpoints
    plan.verify()        # every tensor placed; every context's IO closed; lifetimes
                         # disjoint where buffers alias — raise LowerError otherwise
    return plan
```

`ChipFacts` — tile geometry, context budget, memory map — is a *measured* document, grown by the gauntlet discipline (measure-only harnesses) on Aesir's own device: where a fact is unknown, the plan carries it as a named unknown with the experiment that would settle it, rather than a guess wearing a constant's clothes.

### 2. Code generation: from plan to bytes

```text
procedure emit_config(plan) -> ConfigBytes raises CodegenError:
    # The SMIÐR lineage: descriptor.mojo (H103 PASS: noop/memcpy/vecadd descriptors
    # generated and well-formed) and config_gen.mojo's CFG v1 format are the seed
    # code — this procedure is their generalization from three op kinds to the
    # lowered op set, driven by the banked descriptor studies.
    bytes := ConfigBuilder()
    for ctx in plan.contexts:
        bytes.begin_context(ctx.id, ctx.entry_points)
        for action in ctx.actions:                 # the action-list concept: ordered
            bytes.emit(descriptor_for(action))     # primitive ops the fabric executes
        bytes.end_context(ctx.checksum())
    bytes.set_buffer_map(plan.buffers)
    bytes.set_stream_table(plan.streams)
    GATE("config-self-check", parse_back(bytes) == plan)   # the emitter ships with
                         # its own parser; a config that doesn't round-trip to the
                         # plan that made it never leaves the process
    return bytes
```

### 3. The activation protocol — the wall, as a state machine with named unknowns

```text
enum ActivationStage:
    FW_READY            # HAILBRÚ's proven terminus (H095): firmware booted, verified
    CONFIG_ACCEPTED     # device has taken the config bytes      [UNKNOWN CONTRACT U1]
    CONTEXT_ACTIVE      # a context is resident and bound        [UNKNOWN CONTRACT U2]
    STREAMS_BOUND       # input/output streams mapped            [UNKNOWN CONTRACT U3]
    RUNNING             # descriptors executing, completions     [partly SMIÐR-known:
                        #  command slot BAR4+0x0, doorbell BAR4+0x1754, completion
                        #  BAR0+0x18C bit 26 — H102's mailbox map, 1 IDENTIFY
                        #  submitted / 0 completions: the shape of the door is
                        #  known; the knock sequence is the work]

procedure activate(dev: HailbruDevice, cfg: ConfigBytes) raises ActivationRefused:
    assert dev.state == FW_READY            # HAILBRÚ brings us here — proven ground
    for stage in [CONFIG_ACCEPTED, CONTEXT_ACTIVE, STREAMS_BOUND]:
        step := contract[stage]            # the ContractBook (§4): each step cites
                                            # its evidence — plunder note, trace id,
                                            # or experiment bundle
        if step.status != ESTABLISHED: raise ActivationRefused(stage, step.missing)
                                            # fail-closed at the frontier: the machine
                                            # stops exactly where knowledge stops,
                                            # and names the gap as its output
        step.execute(dev, cfg) or raise ActivationFault(stage)
    return RunningContext(dev)
```

### 4. The ContractBook: knowledge as a versioned artifact

```text
struct ContractStep:
    stage: ActivationStage
    status: ESTABLISHED | PARTIAL | UNKNOWN
    spec: Prose                   # written from observation (study side)
    evidence: List[BundleId]      # traces, plunder notes, experiment results
    impl: ProcedureRef            # written from spec only (build side)

# Campaign law, carried over: the study side and the build side are separate
# passes over separate documents; no implementation is written from driver
# source — only from ContractBook specs. docs/plunder/ is the existing study
# corpus this book grows from (hailort-drivers, HailoRT internals, SMIÐR
# descriptor analyses), and it grows by OBSERVATION EXPERIMENTS:

procedure observation_experiment(known_model) -> TraceBundle:
    # run the VENDOR stack on our own device, our own known model, capturing:
    #   - ioctl/syscall trace of the runtime process (strace-class observation)
    #   - PCIe-level observation where tooling allows (BAR access logging via
    #     the kernel driver's own debug surfaces)
    #   - timing + ordering of config upload vs activation vs first completion
    # then: redact to protocol facts (sequences, sizes, offsets, handshakes) —
    # the bundle stores FACTS, and the ContractBook cites bundle ids.
```

### 5. The differential harness — trust, built in layers

```text
procedure differential_suite(plan, cfg) raises DiffFailure:
    # L0: config round-trip (emitter parser == plan)         [no device]
    # L1: descriptor semantics — SMIÐR's gauntlet lineage: noop/memcpy/vecadd
    #     class micro-networks, outputs vs host-computed truth [needs U1–U3]
    # L2: single real layer (one block, tiny dims) vs Aesir CPU forward, tight tol
    # L3: full small model (TinyLlama depth at reduced width) 32 tokens vs CPU
    #     oracle sequence — the campaign's definition of "running"
    # L4: the gauntlet proper (existing campaign machinery): throughput, soak,
    #     PM-cycle survival — measured, judged, never self-fixed (vordr watches,
    #     gauntlet judges, smidr/hailbru own their domains — the campaign's
    #     separation of powers is inherited, not reinvented)
```

## How it plugs into Aesir as it exists

This route lives where the campaign already lives — the MÍMISBRUNNR stack — and grows its existing domains rather than founding new ones:

- **`hailbru/`** — transport, unchanged in law (sole device-touch domain; SessionGuard; firmware staging with SHA-256 verification). The compiler's activation steps call `hailbru.api` — the API H079 froze; new verbs arrive as campaign slices under the same freeze discipline.
- **`smidr/`** — the compiler proper grows here: `descriptor.mojo` + `config_gen.mojo` generalize into the lowering/codegen pipeline of §1–2; `mailbox.mojo`'s map anchors §3's RUNNING stage.
- **`armvegr/backend.mojo` (SKIPTI)** — the dispatch layer that today honestly raises `NpuUnavailable` gains its Hailo arm when, and only when, the differential suite's L3 passes: the raise becomes a route, by gate, not by announcement.
- **`vordr/` + `gauntlet/`** — watchdog and measurement, existing campaign organs, extended (never given fix-it powers).
- **Engine side**: the IR lowers from the same blueprint the engine's other backends consume; the session surfaces as a `ControlledTextSession` behind `core/runtime_plan.mojo` admission — the campaign stack and the engine meet at the same facade the CUDA backend meets it at.
- **Campaign law inheritance**: slices with predeclared gates, evidence bundles in `docs/evidence/`, rejected attempts retained, CAPABILITY_LEDGER entries written by gates (today: 119 entries — this route's entries are born as it passes them, in order).

## Pseudocode annex A — the tiling pass at working depth

```text
procedure tile_pass(g: IRGraph, geo: TileGeometry) -> IRGraph raises LowerError:
    out := IRGraph()
    for node in g.nodes:
        match node.op:
            MATMUL(M, K, N):
                # split K into reduction tiles, N into output tiles sized to
                # geo; partial sums become explicit ACC tensors with named
                # lifetimes (the place pass needs them visible)
                for nt in tiles(N, geo.n_tile):
                    acc := out.emit(ZERO, [M, nt])
                    for kt in tiles(K, geo.k_tile):
                        acc := out.emit(MATMUL_TILE, [x[:, kt], w[kt, nt], acc])
                    out.emit(STORE, [acc -> node.out[nt]])
            CONV(...) | ATTENTION(...) | ELEMENTWISE(...) | NORM(...):
                analogous decomposition per op family; any op the pass does
                not know RAISES — an unlowerable op is a campaign datum
                (the op-coverage ledger grows), never a silent CPU detour:
                house law in its strictest form, enforced by the pass itself
    return out

# TileGeometry is a ChipFacts section: every number in it cites a gauntlet
# bundle (measured) or is marked ESTIMATE with the experiment that replaces
# it. Lowering quality is bounded by these facts; the campaign grows the
# facts and the lowering improves — in that order.
```

## Pseudocode annex B — the observation experiment, protocol form

```text
procedure observation_program():
    # Sequenced experiments; each ends in ContractBook entries (spec text +
    # evidence ids) or in a recorded null result. Nulls are kept: an
    # experiment that shows the knock is NOT at BAR4+0x1754 saves the next
    # engineer a month, and the campaign keeps its dead ends on file
    # (docs/evidence discipline: rejected candidates retained).
    E1: vendor-stack load of a KNOWN tiny model; ioctl trace diffed between
        "device open" and "first inference" → the upload phase's syscall
        skeleton (sizes, order, fd choreography)
    E2: same, with config sizes varied (two models of different size) →
        which transfers scale with config, which are fixed handshakes
    E3: activation-phase isolation: trace window between upload-complete
        and first completion interrupt → the U2/U3 candidate sequences
    E4: HAILBRÚ-side replay: reproduce E1's skeleton via hailbru.api on a
        SMIÐR CFG-v1 config (noop) → first differential at the protocol
        level: device response vs the vendor path's device response
    E5: completion semantics: poll/interrupt behavior on the known mailbox
        map (BAR0+0x18C bit 26 lineage) during a vendor-run inference →
        what "done" looks like electrically and in registers
    each E*: bundle → ContractBook update (study side) → only then may the
             build side write or change activation code (two-pass law)
```

## Pseudocode annex C — the campaign slice plan (how this document becomes work)

```text
# In the MÍMISBRUNNR manner: slices with predeclared gates, in order.
SLICE R1  L0 lowering + codegen round-trip (this document's prototype gate)
SLICE R2  Observation program E1–E3; ContractBook U1–U3 to PARTIAL or better
SLICE R3  E4 replay: noop config activation attempted via HAILBRÚ;
          gate = device accepts and completes a noop, or the refusal is
          characterized to a named missing step (a characterized refusal
          PASSES R3 — the campaign pays for knowledge, not for luck)
SLICE R4  Micro-networks (memcpy/vecadd class) end-to-end on device (L1)
SLICE R5  One transformer block on device vs CPU oracle (L2)
SLICE R6  TinyLlama-width-reduced full model, 32 tokens (L3) → SKIPTI's
          NpuUnavailable gains its gated Hailo arm
SLICE R7  Gauntlet: throughput/soak/PM survival (L4); LEDGER entries minted
# Each slice: findings MD first, code second, evidence bundle always —
# the repository's existing law (docs/evidence, CAPABILITY_LEDGER gates),
# not new ceremony invented for this route.
```

## Pseudocode annex D — the precision pass and what A16 means without a vendor

```text
procedure precision_pass(g: IRGraph, pins) -> IRGraph:
    # Precision on this route is a PROPERTY OF TENSORS, decided tensor by
    # tensor from the recipe pins (the numeric laboratory's output consumed
    # as data — any equivalent pin source works; the pass is source-blind):
    for t in g.tensors:
        t.fmt := pins.for(t)              # A8W4 | A8W8 | A16W16 | FP16-STREAM
    # Boundary rule, mechanically enforced: a tensor consumed at higher
    # precision than produced gets an explicit CONVERT node inserted by
    # the pass — conversions are visible in the plan, costed by the place
    # pass, and counted in the plan report. Silent widening/narrowing is
    # the classic clean-room compiler bug; the pass makes it unrepresentable.
    for edge in g.edges:
        if fmt(edge.src) != fmt(edge.dst): insert_convert(edge)
    return g

# KV precision is a plan choice with a quality dial the user can see:
# KV at A8 halves cache bandwidth vs FP16-stream at some attention cost —
# the plan report states the choice and the differential suite (L2/L3)
# runs the plan AT THE CHOSEN precision, so a quality regression from the
# KV dial shows up at the gate, not in a user's conversation.
```

## Pseudocode annex E — failure archaeology: the routes' shared graveyard, kept

```text
# The campaign record already contains the instructive failures, and this
# route's plan names them as assets rather than embarrassments:
#   H102 — 1 IDENTIFY submitted, 0 completions: the mailbox shape known,
#          the conversation unproven → Annex B's E5 exists because of it
#   H111 — SMIÐR NO-GO at the firmware wall: "The Wall held" → the entire
#          §3/§4 design (ContractBook, two-pass law) is this entry's child
#   The rejected/failed compile attempts across the plunder record →
#          retained per evidence law; the observation program cites them
#          as negative results (what the knock is NOT) before spending a
#          single new experiment.
# A compiler campaign that files its failures this way compounds; one
# that deletes them repeats them. The ledger is the method.
```

## Pseudocode annex F — the place pass and the memory map

```text
procedure place_pass(sched, mmap: MemoryMap) -> NetworkPlan raises LowerError:
    # mmap (ChipFacts): DDR regions with bases/sizes, on-chip SRAM budget,
    # stream endpoint table — every entry evidence-cited like all ChipFacts.
    alloc := RegionAllocator(mmap)
    for t in sched.tensors.by_lifetime:
        match t.kind:
            WEIGHT:  alloc.place(t, DDR, align = geo.align)     # streamed or
                        # resident per the schedule's residency decision —
                        # recorded per tensor (a "resident" weight the map
                        # can't fit RAISES here, at plan time)
            KV:      alloc.place(t, DDR, region = KV_REGION)    # capacity =
                        # plan.ctx × per-token KV bytes, computed & printed
            ACT:     alloc.place(t, SRAM if fits else DDR_SPILL)
                        # spills are COUNTED in the plan report with their
                        # bandwidth cost — a plan that spills silently is a
                        # plan that lies about its speed
            CONST:   alloc.place(t, DDR, readonly = True)
    GATE("map-closed", alloc.unplaced == ∅) or raise LowerError(alloc.unplaced)
    GATE("map-disjoint", alloc.overlaps == ∅)
    return NetworkPlan(..., buffer_map = alloc.map, spill_report = alloc.spills)
```

## Pseudocode annex G — IR node taxonomy (v1 coverage, honestly bounded)

```text
# The IR's op set is AESIR'S FORWARD, enumerated — v1 covers exactly what
# the dense decoder forward passes use, and the coverage list is a ledger:
COVERED (lowering designed in this document):
    MATMUL, CONV-free dense path, EW_ADD/MUL, RMSNORM, SOFTMAX,
    ROPE_APPLY (constant tables), SILU/GELU (pointwise), EMBED_GATHER,
    ATTENTION (as composed matmul/softmax/matmul at IR level),
    RESHAPE/TRANSPOSE (metadata-only where possible)
DEFERRED (named, with their admission condition):
    MOE_ROUTE      — when a MoE family enters Aesir's supported set
    RECURRENT_CELL — hybrid architectures; the compiler's sequential-state
                     contexts need their own campaign slice to design
    SPECULATIVE_DECODE graphs — a serving optimization, not a correctness
                     frontier; admitted only after L3 parity is boring
# An IR node outside COVERED ∪ DEFERRED cannot exist: blueprint lowering
# raises on unlisted ops at IR BUILD time (before any lowering begins) —
# the taxonomy is enforced at the door, not discovered at the wall.
```

## Pseudocode annex H — what "established" costs: the ContractBook's promotion rule

```text
procedure promote_step(step, bundle) raises ContractError:
    # A ContractStep moves UNKNOWN → PARTIAL → ESTABLISHED only via:
    PARTIAL:      ≥ 1 observation bundle whose facts constrain the step
                  (a candidate sequence, a size law, a register behavior)
                  + the spec text rewritten to state what is now believed
                  AND what remains open (both halves mandatory)
    ESTABLISHED:  ≥ 2 INDEPENDENT bundles agreeing (different experiments
                  or different models) + a successful build-side replay
                  (E4-class) whose device behavior matches the spec's
                  prediction on every recorded observable
    # Promotion is a ledgered event with the bundle ids attached; DEMOTION
    # is equally possible (a later bundle contradicting a step demotes it
    # and freezes dependent implementation work) — the book is a living
    # record of belief WITH receipts, and receipts can be revoked.
```

## Honest unknowns and risks

- **[unknown — the route's namesake] The activation contract (U1–U3).** Everything else in this document is engineering; this is discovery. It may fall to a fortnight of tracing or resist for far longer — the campaign record itself (H111: "The Wall held") is the honest prior. The design's answer is structural: every stage above the wall (IR, lowering, codegen, harness L0) is buildable *now* and useful regardless; every stage at the wall fails closed with the gap named; and the observation program is specified before it is needed.
- **[unknown] Context/action-list semantics in detail.** The config format's broad shape is study-supported; field-level semantics for the full op set (attention-class ops especially) are not. The lowering pass therefore begins with the SMIÐR-proven op classes and grows by differential evidence — op coverage is a ledger, grown entry by entry.
- **[documented risk] Clean-room hygiene is the route's license to exist.** The two-pass discipline (spec from observation, code from spec) is slower than reading source — deliberately. Any contamination of the build side voids the campaign's legal and moral footing; the ContractBook's citation discipline is the audit trail, and it is not bureaucracy, it is the point.
- **[inferred] Firmware version sensitivity.** The contract may shift across firmware/driver generations; HAILBRÚ already treats firmware as a verified, pinned input, and the ContractBook records the firmware identity every established step was proven against — a step proven on one firmware is *claimed* only for that firmware until re-proven.

## Smallest first prototype, gate declared in advance

**Build**: no device work at all — the **L0 layer**: the IR → NetworkPlan lowering for one transformer block at TinyLlama dims, plus `emit_config` with its round-trip parser, targeting the SMIÐR-proven descriptor classes only, with the ContractBook's U1–U3 written up from the existing plunder record as its first entries (statuses honestly UNKNOWN/PARTIAL).

**Gate — PASS requires**: (1) lowering + codegen round-trip green (`parse_back(emit(plan)) == plan`) on the block and on a full 32-layer plan; (2) the ContractBook's every step carries evidence citations or an explicit UNKNOWN with its designed observation experiment; (3) the plan verifier refuses a doctored plan (aliased lifetimes) by name. Passing L0 authorizes the observation program — the campaign's next slice — and nothing beyond it: the wall is approached in order, with the ledger as witness, the way HAILBRÚ itself was built.
