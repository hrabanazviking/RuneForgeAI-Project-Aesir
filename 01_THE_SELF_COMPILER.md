# 01 — The Self-Compiler: Aesir Drives the Dataflow Compiler Itself

## The idea in one paragraph

The Dataflow Compiler was never locked. What Hailo locked was a *catalogue* — a shelf of models Hailo compiled, on Hailo's machines, with Hailo's choices baked in. The compiler itself is a public, general tool with a documented contract: give it a trained network (ONNX/TF/TFLite), a calibration set, and a model script, and it returns a HEF for a named target. This route makes **Aesir the operator of that compiler**: when a user installs a stock model, Aesir's own build pipeline intakes the GGUF, exports the model's graph in the two shapes LLM inference actually needs (a prefill graph and a token-by-token decode graph), machine-writes the `.alls` model script, synthesizes a calibration set from data Aesir controls, drives the DFC stages on the user's host at install time, gates the result against Aesir's own CPU oracle, and caches the HEF under a content hash. From then on the model is served by Aesir's own Hailo session. The compiler runs once per model, on the user's machine, under Aesir's discipline — the same relationship Aesir already has with every other tool it drives.

## Why it needs no precompiled or modified LLM

- **Input**: the untouched stock GGUF, loaded by the existing `loader/gguf.mojo` mmap loader. Weights are exported *from* it by Aesir; the file itself is never altered, and nothing in the flow requires a vendor-touched variant of the model.
- **The compiled artifact is Aesir's own work product**: an HEF compiled locally from the stock weights, with a calibration set and model script Aesir generated and can show. It is "precompiled" only in the trivial sense that compilation happens before serving — the same sense in which Aesir's own engine binary is precompiled. No third party's choices are inside it.
- **No catalogue, no manifest whitelist, no `hailo-ollama`** appears anywhere in the route. Serving is Aesir's `HailoSession` (§5), a `ControlledTextSession` like the CUDA sessions.
- **Reproducibility**: the DFC emits an automatic model script (`.auto.alls`) with each compile that reproduces the same binary for the same DFC version [documented]. Aesir stores it beside the HEF, so any cached artifact can be re-derived and audited.

## Architecture

```
 stock GGUF ──► loader/gguf.mojo (mmap, existing)
                    │  tensors + metadata (dims, family, tokenizer)
                    ▼
        hailo/intake ──► ModelBlueprint        (family, dims, tensor map)
                    │
        hailo/graph_export ──► prefill.onnx    (static seq bucket, KV out)
                          └──► decode.onnx     (1 token, KV in/out, ctx cap)
                    │
        hailo/calib_synth ──► calib.npy        (>=1024 sequences, model-own tokenizer)
        hailo/script_forge ─► model.alls       (machine-written, hashed)
                    │
        hailo/dfc_driver ──► parse → HAR → optimize → HARq → compile → HEF ×2
                    │            (stage machine, log-captured, resumable)
                    ▼
        hailo/gates ── emulator KL gate → parse-hef gate → on-device smoke gate
                    │
        DurableModelStore ──► HEF cache entry  (key: model sha + arch + ctx +
                                                dfc ver + alls hash + calib hash)
                    │
        core/hailo_session.mojo ──► ControlledTextSession over core/hailo_gate.mojo
                                    (libhailort C API via FFI, the CUDAGate pattern)
```

New code lives where Aesir's conventions put it: a `hailo/` build package beside `loader/` and `core/` (build-time tooling, driven from `cli/commands.mojo` as `aesir hailo build <model>`), and the runtime pair `core/hailo_gate.mojo` + `core/hailo_session.mojo` beside `core/cuda_gate.mojo` and the CUDA sessions. The build runs on an x86 host (the DFC is an x86 host tool [documented]); the Pi-class target only ever receives finished HEFs, exactly as the Hailo corpus's checklist demands.

### The two graphs, and why two

An LLM on this silicon is not one network [documented, Hailo's own packaging]: a **prefill** configuration processes the whole prompt and populates the KV cache; a **decode** (token-by-token) configuration consumes one token plus the cache and emits logits plus the updated cache. Both are static-shape objects [documented: HEFs are fixed-shape; a `-1` dimension reaching the quantizer is a demonstrated failure]. Aesir therefore exports:

- **Prefill graph**: input `tokens[1, S]` for a bucket size S ∈ {128, 512, 1024, 2048}; outputs `K_all`, `V_all` for positions `[0, S)`. Prompts are right-padded to the next bucket with a position mask folded into the attention bias; prompts longer than the largest bucket are processed in bucket-sized chunks by the session (chunked prefill, cache carried between chunks — a session-level loop, not a graph feature).
- **Decode graph**: inputs `token[1, 1]`, `K_in`, `V_in` at the full compiled context capacity C, and `pos[1]`; outputs `logits[1, V]`, `K_out`, `V_out`. Unused cache slots are masked by `pos`. Context length is a *compile parameter* chosen at build time (default 4096 on 8 GB modules, 2048 on 4 GB — the catalogue's own bake proves 2048 compiles [documented]; larger is a build-time experiment the gates adjudicate, not an assumption).

Both graphs come from the *same* exported block stack; the split is a slicing operation on one ONNX, performed by Aesir's exporter with start/end node selection — the compiler's own documented mechanism for cutting graphs.

## The pseudocode

Conventions: `raise` is fail-closed — a named error, a ledger entry, no fallback. `GATE(name, condition)` evaluates a predeclared acceptance condition and raises `GateFailed(name)` on false. All hashes are SHA-256, matching `cli/storage.mojo`'s digest discipline.

### Data structures

```text
struct ModelBlueprint:
    family:        FamilyId            # from core/model_registry classify()
    n_layers:      Int
    hidden:        Int                 # d_model
    n_heads:       Int
    n_kv_heads:    Int
    head_dim:      Int
    ffn_hidden:    Int
    vocab:         Int
    rope_theta:    Float32
    rope_style:    RopeStyle           # interleaved | half-split | neox
    norm_eps:      Float32
    tie_embeddings: Bool
    tensors:       Map[String, TensorRef]   # name -> (gguf offset, shape, gguf type)
    tokenizer_id:  String              # which of loader/'s tokenizers owns this family

struct BuildRequest:
    model_path:    Path
    model_sha256:  Hash
    arch:          String = "hailo10h"          # hw_arch, fixed at translate time
    ctx_len:       Int                          # decode capacity C
    prefill_buckets: List[Int] = [128, 512, 1024, 2048]
    opt_level:     Int = 4                      # production advice: highest [documented]
    compression:   Int                          # 4-bit weight share dial, per size class
    calib_target:  Int = 2048                   # >= 1024 hard floor; 2048 = QFT default appetite

struct BuildKey:                                # the HEF cache key — all of it, or rebuild
    model_sha256, arch, ctx_len, dfc_version, hailort_version,
    alls_hash, calib_hash, exporter_version

struct HefPair:
    prefill_hef:   Path                # one per bucket actually compiled (see policy below)
    decode_hef:    Path
    auto_alls:     Path                # DFC-emitted reproducibility script
    build_log:     Path
    gate_report:   GateReport
```

### Stage 0 — environment proof (before any model work)

```text
procedure prove_toolchain() raises ToolchainError:
    dfc_ver  := run_capture("hailo --version")            # DFC CLI present
    rt_ver   := hailortcli("--version")                   # runtime present
    GATE("version-pairing", compatible(dfc_ver, rt_ver))  # 5.x pairs with 5.x [documented lockstep]
    dev      := hailortcli("scan")
    GATE("device-present", dev.contains(arch = HAILO10H))
    ident    := hailortcli("fw-control identify --extended")
    record ident.firmware, ident.board, ident.serial into build_log
    if host.arch != x86_64: raise ToolchainError("DFC is a host tool; build on x86, deploy the HEF")
    LEDGER.note("toolchain", dfc_ver, rt_ver, ident.firmware)
```

### Stage 1 — intake and graph export

```text
procedure intake(model_path) -> ModelBlueprint raises IntakeError:
    gguf := loader.gguf.open_mmap(model_path)             # existing loader, zero-copy
    meta := gguf.metadata()
    bp   := ModelBlueprint(
               family      = model_registry.classify(meta),        # existing classifier
               n_layers    = meta.require("*.block_count"),
               hidden      = meta.require("*.embedding_length"),
               ... )                                               # every field required;
    if any required key missing: raise IntakeError("stock file lacks <key>; refusing to guess")
    bp.tensors := gguf.tensor_directory()                 # names/shapes/types, offsets only
    return bp

procedure export_graphs(bp, req) -> (prefill_onnx, decode_onnx) raises ExportError:
    # Build ONE ONNX (opset 16 — inside the documented 8, 11..17 window) whose
    # block stack is written in the DFC-friendly dialect Aesir controls:
    #   - RoPE applied via precomputed cos/sin CONSTANT tensors and Mul/Add,
    #     never Sin/Cos nodes            [documented: trig ops unsupported]
    #   - RMSNorm as explicit ReduceMean/Mul/Div/Add/Sqrt subgraph with the
    #     norm folded adjacent to its consumer where the folder requires it
    #   - GELU/SiLU as native nodes (SiLU documented; GELU is preview —
    #     prefer the family's own activation exactly as the checkpoint defines it)
    #   - NO dynamic dims anywhere: every shape literal
    g := GraphBuilder(opset = 16)
    embed := g.add_embedding_lookup(bp)                    # host-side in session;
                                                           # graph starts at hidden states
    blocks := [g.add_decoder_block(bp, i) for i in 0 ..< bp.n_layers]
    prefill := g.finalize(inputs  = [hidden_in[1, S, H] for S in req.prefill_buckets],
                          outputs = [K_all, V_all, hidden_out])
    decode  := g.finalize(inputs  = [hidden_in[1, 1, H], K_in[.., C, ..], V_in[.., C, ..], pos],
                          outputs = [logits, K_out, V_out])
    for f in [prefill, decode]: onnx_check(f); assert_no_dynamic_dims(f)
    return (prefill, decode)
```

The graph starts at hidden states, not token ids: embedding lookup is a gather from an mmap'd table — cheap, exact, and (per Hailo's own Whisper precedent [forum-reported, staff]) the kind of step this platform routinely leaves on the host. The session does lookup; the chip does the transformer.

### Stage 2 — calibration synthesis

```text
procedure synthesize_calibration(bp, req) -> Path raises CalibError:
    # Calibration data decides quantized accuracy [documented]; distribution
    # match matters more than count [forum-reported field data: 1.5% vs 8% drop].
    # Sources, in priority order — all text Aesir ships or the user supplies:
    corpus := []
    corpus += load_bundled_corpus()            # public-domain text packed with Aesir
    corpus += user_prompt_history_if_consented()   # optional; absent is fine
    corpus += self_generated_text(bp)          # Aesir's CPU path generates continuations
                                               # from seed prompts — model-flavoured text
    seqs := []
    tok := loader.tokenizer_for(bp)            # Aesir's own hand-rolled tokenizer
    for text in corpus:
        ids := tok.encode(text)
        for chunk in sliding_windows(ids, len = 256, stride = 192):
            seqs.append(embed_lookup(chunk))   # calibration feeds hidden states,
                                               # the graph's actual input format
        if len(seqs) >= req.calib_target: break
    if len(seqs) < 1024: raise CalibError("starved: %d < 1024 floor" % len(seqs))
        # NEVER let the DFC's silent downgrade fire: levels 2/4 require >=1024
        # and the tool only warns while it weakens your model [documented].
    save_npy("calib.npy", stack(seqs)); return hash_of("calib.npy")
```

### Stage 3 — the machine-written model script

```text
procedure forge_script(bp, sensitivity) -> (alls_text, alls_hash):
    # sensitivity: per-layer table from a noise-analysis pass over the FP model,
    #              or the conservative default profile for the family.
    lines := []
    lines += "model_optimization_flavor(optimization_level=%d, compression_level=%d)"
             % (req.opt_level, req.compression)
    lines += "model_optimization_config(calibration, calibset_size=%d)" % calib_count
    lines += "pre_quantization_optimization(equalization, policy=enabled)"
    lines += "pre_quantization_optimization(quarot, policy=enabled)"
             # quarot is a named pre-quantization algorithm in the guide [documented]
    for layer in sensitivity.layers where layer.snr_db < PIN_THRESHOLD:
        lines += "quantization_param(%s, precision_mode=a16_w16)" % layer.name
             # per-layer 16-bit pinning is THE documented remedy for sensitive
             # layers — the same surgery Hailo's own Whisper scripts perform
    lines += "post_quantization_optimization(finetune, policy=enabled,
                  dataset_size=%d, epochs=4, learning_rate=1e-5)" % calib_count
    lines += "context_switch_param(mode=allowed)"
    lines += "allocator_param(automatic_ddr=True)"
    return (join(lines), sha256(join(lines)))
```

### Stage 4 — the DFC stage machine

```text
procedure drive_dfc(bp, req) -> HefPair raises BuildFailed:
    key := BuildKey(...)
    if cache.contains(key): return cache.load(key)         # content-addressed, like the store
    work := scratch_dir(key)                               # resumable: every stage leaves a HAR
    runner := ClientRunner(hw_arch = req.arch)             # via the DFC Python API [documented]

    for graph_name in ["prefill", "decode"]:
        har := work / (graph_name + ".har")
        if not har.exists:
            runner.translate_onnx_model(graph_file(graph_name),
                                        start_node = "hidden_in", end_node = "out")
            runner.save_har(har)
        GATE("parse-" + graph_name, emulator_match(runner, SDK_NATIVE,
                     reference = aesir_cpu_block_forward(bp), tol = EXACTISH))
             # a bad parse is NOT fixable downstream; stop here [documented practice]
        runner.load_model_script(alls_text)
        log := runner.optimize(calib_dataset)              # GPU used if present
        if "Reducing optimization level" in log:
            raise BuildFailed("DFC silently downgraded optimization — "
                              "calibration or GPU precondition failed; refusing the weak HEF")
        runner.save_har(work / (graph_name + "_quantized.har"))
        kl := emulator_kl(runner, SDK_QUANTIZED, frozen_prompt_suite(bp))
        GATE("quantized-logits-" + graph_name, kl <= KL_BUDGET[bp.family])
             # KL_BUDGET is declared in the ledger BEFORE the build, not fitted after
        hef_bytes := runner.compile()
        write(work / (graph_name + ".hef"), hef_bytes)
        extract_auto_alls(work)                            # reproducibility artifact
    pair := HefPair(...)
    GATE("parse-hef", hailortcli_parse_hef(pair).arch == HAILO10H
                     and shapes_match(pair, bp, req))
    cache.store(key, pair); LEDGER.record_build(key, pair.gate_report)
    return pair
```

### Stage 5 — the runtime session

`core/hailo_gate.mojo` mirrors `core/cuda_gate.mojo`'s proven shape: `external_call` FFI into the vendor C library (libhailort's C API exists and mirrors the C++ example set [documented as example tree; signatures verified against installed headers at build time — see Unknowns]). `core/hailo_session.mojo` implements the same `ControlledTextSession` trait the CUDA sessions implement, so `cli/native_serve.mojo`'s `serve_loaded[T]` hosts it unchanged.

```text
struct HailoSession : ControlledTextSession:
    dev: HailoGate.VDevice          # ONE per process, process-lifetime
                                    # [field report: treat VDevice as a singleton]
    prefill: ConfiguredGroup        # per compiled bucket
    decode:  ConfiguredGroup
    kv:      KVCache                # Aesir-owned layout; device-resident tensors
    pos:     Int

    def begin(prompt_ids) raises:
        h := embed_lookup(prompt_ids)                    # host gather, mmap table
        for chunk in chunks_of(h, largest_bucket):
            (K, V) := run_group(self.prefill[bucket_of(chunk)], {hidden_in: chunk})
            self.kv.absorb(chunk_range, K, V)            # scatter into cache layout
        self.pos := len(prompt_ids)

    def next(sampling) -> TokenId raises:
        (logits, K1, V1) := run_group(self.decode,
            {hidden_in: embed(last_token), K_in: self.kv.k, V_in: self.kv.v, pos: self.pos})
        self.kv.absorb(self.pos, K1, V1); self.pos += 1
        if self.pos >= self.kv.capacity: raise ContextExhausted   # fail-closed,
                                    # exactly like the CPU path's context_exhausted
        return sampler.sample(logits, sampling)          # core/sampler.mojo, host-side

    def run_group(group, inputs) raises HailoFault:
        with group.activate():
            job := group.run_async(bindings(inputs), on_complete)
            job.wait(TIMEOUT_MS)
            if completion.exception != None: raise HailoFault(completion.exception)
            # queue discipline: never submit past wait_for_async_ready [documented pattern]
```

## How it plugs into Aesir as it exists

- **CLI**: `aesir hailo build <model.gguf> [--ctx 4096]` and `aesir hailo doctor` (Stage 0) join `cli/commands.mojo`'s dispatch; `aesir chat --accel hailo10` and `serve` admit the new session through `core/runtime_plan.mojo`, which gains `choose_hailo_plan` beside `choose_native_cuda_plan` — admission decided by the same memory-plan discipline (`core/inference_memory.mojo` extended with the module's DRAM size).
- **Config**: `AesirConfig.target_npu = "hailo10"` already parses; `validate_runtime_backend_config`'s raise for `enable_npu` is replaced by a dispatch to the plan *only after* the session's ledger capability flips to verified — until then the raise stays, because an unproven path must refuse, not simulate.
- **Store**: HEF pairs are derived artifacts in `cli/storage.mojo`'s `DurableModelStore`, digest-verified like models, garbage-collected under the same lock.
- **Ledger**: new entries `AES-H10-COMPILE-<family>` and `AES-H10-RUNTIME-<family>`, born `missing`, promoted only by the gates in Stages 4–5, with the build log and gate report filed under `docs/evidence/` in the repo's bundle style.
- **SKIPTI**: on the Mimir form factor, `armvegr/backend.mojo`'s `NpuUnavailable` is the honest answer until a Hailo session exists for that stack too; this route lands in the engine first.

## Pseudocode annex A — the `.alls` generator, in full

The script generator is the route's quality heart; it is written out here at working depth because "generate a reasonable .alls" is exactly the sentence that hides a month of tuning in other projects.

```text
struct AllsProfile:                     # per-family, versioned with the builder
    flavor:        {optimization_level: Int, compression_level: Int}
    equalization:  Bool                 # pre_quantization_optimization
    rotation_hint: Bool                 # quarot in the flavor line when the
                                        # numeric-lab recipe (external to this
                                        # document) supplies rotated weights
    a16_pins:      List[PinRule]        # which layer patterns get a16_w16
    finetune:      {enabled: Bool, epochs: Int, lr: Float}
    context:       {contexts_per_boundary: Int}

PinRule :: (layer_name_pattern, precision_mode)     # e.g. ("lm_head", a16_w16),
                                                    # ("layer0/*", a16_w16)

procedure write_alls(req, dims, prof) -> String:
    L := []
    L += "model_optimization_flavor(optimization_level=%d, compression_level=%d)"
            % (prof.flavor.level, prof.flavor.compression)      # level >= 2 needs
                                                                 # the 1024+ calib
    if prof.equalization:
        L += "pre_quantization_optimization(equalization, policy=layers, weights_ratio=0.25)"
    for pin in prof.a16_pins.expanded_over(dims):               # name expansion is
        L += "quantization_param(%s, precision_mode=a16_w16)" % pin.name
                                                                 # MECHANICAL: every
    if dims.vocab >= 100_000:                                    # layer the rule
        L += "quantization_param(lm_head, precision_mode=a16_w16)"   # matches
    if prof.finetune.enabled:
        L += "post_quantization_optimization(finetune, epochs=%d, learning_rate=%g)"
    L += "allocator_param(automatic_ddr=True)"
    L += "context_switch_param(max_compute_utilization=0.9, max_memory_utilization=0.9, max_control_utilization=0.9)"
    return "\n".join(L)

# Sensitivity-driven pin growth: the loop that LEARNS the profile for a family.
procedure grow_profile(family, probe_models) -> AllsProfile:
    prof := BASE_PROFILE                        # levels + equalization, no pins
    for m in probe_models:
        kl_by_layer := per_layer_kl_attribution(m, prof)
                        # compile once unpinned; then for each layer, re-run the
                        # quantized emulator with ONLY that layer at a16_w16 and
                        # record the KL recovery — the layers whose pinning buys
                        # the recovery are the family's sensitive layers
        prof.a16_pins += rules_for(top_recoveries(kl_by_layer, budget = 12))
    prof.frozen := True                          # a profile is frozen per family
    LEDGER.record("AES-H10-ALLS-PROFILE", family, prof.hash)   # version; changes
                                                 # re-run this procedure in the open
    return prof
```

## Pseudocode annex B — the HEF cache as a store citizen

```text
# Layout inside DurableModelStore (cli/storage.mojo), digest-addressed:
#   store/hef/<cache_key>/ { prefill-<S>.hef, decode-<C>.hef, build_report.json,
#                            source.sha256, dfc.version, rt.version }
procedure cache_gc(store, keep_per_model = 2):
    for key in store.hef_keys(oldest_first):
        if key.model not in store.models: store.drop(key)          # orphan
        elif store.hef_keys(model = key.model).count > keep_per_model
             and key not in active_sessions: store.drop(key)       # evict LRU
        # a key referenced by a live session is never dropped mid-session:
        # sessions hold store leases (DurableModelStore's lock discipline)

procedure cache_lookup(req) -> HefPair | NEEDS_BUILD:
    key := cache_key(req)
    dir := store.hef_dir(key)
    if dir exists and sha256(dir/prefill) == dir.build_report.hef_hashes.prefill
       and dir.dfc_version == toolchain.dfc and dir.rt_version == toolchain.rt:
        return load(dir)
    if dir exists: store.quarantine(dir, reason = "stale-or-corrupt")
                       # quarantined, never silently overwritten: the report in
                       # the old dir is evidence of what the old toolchain did
    return NEEDS_BUILD
```

## Pseudocode annex C — the repair loop's full decision table

```text
procedure repair(err: BuildError, req, attempt) -> RepairAction:
    match err.kind:
        PARSE(node = n, reason = r):
            if rewrite_rule_exists(n): return RETRY_WITH(rewrite(n))
            return REFUSE("parse", n, r)            # unknown spelling: refuse and
                                                    # REPORT — the rewrite library
                                                    # grows from refusals, attended
        ALLOC(shape = s):      return RETRY_WITH(alls += resources_hint(s))
        QUANT(reason = "too little data"):
            if calib.count < 4096: return RETRY_WITH(more_calibration(×2))
            return REFUSE("quant", reason)          # data is not the problem twice
        KL(layer = l, kl = k):
            if unpinned(l):    return RETRY_WITH(pin(l, a16_w16))
            if k <= 2 × budget: return RETRY_WITH(finetune(more_epochs))
            return REFUSE("kl", l, k)
        COMPILE_TIMEOUT:       return RETRY_WITH(smaller_bucket_or_split)
        _:                     return REFUSE("unclassified", err)
    # Every REFUSE files: {stage, node/layer, toolchain versions, har hash,
    # alls hash, calib hash} into the build report — a refusal is a document,
    # so the NEXT model of this family starts smarter than this one did.
```

## Pseudocode annex D — calibration-set synthesis, in full

Calibration quality decides quantization quality, and the synthesized set is the one dataset Aesir fully controls. It is built to *cover the model's own activation distribution*, not to be generically "text-like":

```text
procedure synthesize_calibration(model, corpus_root) -> CalibSet raises BuildFailed:
    tok := tokenizer_for(model)              # Aesir's own (loader/tokenizer.mojo)
    pool: List[String] := []
    # Strata, with quotas — a calibration set of pure prose starves code and
    # math activations; pure code starves dialogue. The quotas are the recipe:
    pool += sample(corpus.prose,     40%)
    pool += sample(corpus.dialogue,  20%)    # chat-formatted THROUGH the model's
                                             # own chat template: special tokens
                                             # and role markers are activations too
    pool += sample(corpus.code,      15%)
    pool += sample(corpus.math,      10%)
    pool += sample(corpus.lists_tables_structured, 10%)
    pool += sample(corpus.multilingual, 5%)  # where the model family claims it
    seqs := [tok.encode(t)[:model.max_calib_len] for t in pool]
    seqs := dedupe_near(seqs)                # near-duplicate sequences waste the
                                             # sample budget silently
    GATE("calib-count", len(seqs) >= 1024)   # [documented floor for levels 2/4]
    emit_activations := run_through_har_embedding_stage(seqs)
                        # the ONNX-stage calibration consumes raw sequences via
                        # the runner; where the DFC wants post-embedding tensors,
                        # Aesir's export carries the embedding INSIDE the graph
                        # for calibration builds (a compile-time variant, noted
                        # in the build report — the serving HEF's boundary is
                        # the same either way because the split happens at the
                        # hidden state)
    return CalibSet(seqs, hash = sha256(concat(seqs)), corpus_ids = pool.ids)
```

The set's hash enters the cache key (§Stage 1): change the corpus or the quotas and old HEFs stop matching — deliberately. A silent calibration change producing a silently different model is exactly the failure the key exists to prevent.

## Pseudocode annex E — the version-pairing gate and toolchain manifest

```text
struct ToolchainManifest:               # written by stage-0 intel, read by all
    dfc_version: String                 # e.g. "5.3.0" [documented-era line]
    rt_version: String                  # must share the major (lockstep)
    driver_present: Bool
    suite_present: Bool                 # full suite vs runtime-only install:
                                        # a runtime-only host CANNOT build —
                                        # the route says so at stage 0, not at
                                        # the user's first model install
    hw_seen: List[String]               # hailortcli scan result, verbatim

procedure stage0_intel() -> ToolchainManifest raises BuildFailed:
    m := probe_all()
    if m.dfc_major != m.rt_major:
        raise BuildFailed("version-lockstep", m.dfc_version, m.rt_version)
    if "hailo10h" not in dfc_targets(m.dfc_version):
        raise BuildFailed("target-missing", "this DFC cannot emit hailo10h")
    if not m.driver_present and target_is_local:
        raise BuildFailed("no-driver", "smoke gate will have nowhere to run")
    LEDGER.record("AES-H10-TOOLCHAIN", m.hash)
    return m
```

## Pseudocode annex F — one install, end to end (the operator's trace)

```text
$ aesir pull qwen2.5-3b-instruct-q4_k_m.gguf        # stock file, from disk/HF
  [intel]   dfc 5.3.0 / rt 5.3.0 — lockstep OK · target hailo10h OK
  [plan]    arch qwen2 · 36 layers · split: prefill{256,1024} decode{4096}
  [export]  graph written · 214 nodes · unsupported spellings: 0
  [calib]   2 048 sequences synthesized (corpus 9f3c…) · strata quotas met
  [build]   translate OK · optimize lvl 2 (47 min, est. shown first)
            kl vs CPU reference: 0.0137 (budget 0.020) ✓
  [compile] prefill-256.hef · decode-4096.hef · contexts 3+4 (budget ≤ 8) ✓
  [smoke]   device run · 31/32 tokens match CPU oracle (gate ≥ 28) ✓
  [cache]   key 7be1… stored · ledger AES-H10-BUILD-7be1 written
$ aesir run qwen2.5-3b-instruct        # every later run: cache hit, seconds
# The trace IS the interface contract: each bracket is a stage with a log
# file under the build's evidence dir; a failure prints its stage and the
# repair table's verdict (retry-with-what, or refuse-with-report).
```

## Pseudocode annex G — the build lock and partial-build recovery

```text
procedure acquire_build_slot(store, key):
    # Compiles are hours-class; two builds of the same key must never run.
    # The store's lock discipline (DurableModelStore GC locking) extends:
    lease := store.lease("build:" + key, ttl = 6h, heartbeat = true)
    if lease.held_by_live_builder: return ALREADY_BUILDING(lease.owner)
    if lease.stale: store.quarantine(partial_dir(key), "dead-builder")
        # a crashed builder leaves: partial HEFs + stage logs. The partials
        # are QUARANTINED as evidence; the retry starts from the last GATE-
        # PASSED stage whose artifacts hash-verify (translate is cheap to
        # redo; optimize is resumed only from a verified HAR + alls pair)
    return lease

procedure resume_point(key) -> Stage:
    for stage in [SMOKE, COMPILE, OPTIMIZE, TRANSLATE] descending:
        if artifacts(stage).hashes_verify(build_report): return stage.next
    return INTAKE
```

## Pseudocode annex H — what the user can tune (and what they cannot)

```text
# Exposure discipline: knobs that change SEMANTICS are user-facing;
# knobs that change only COST are policy; knobs that could break the
# fail-closed contract do not exist as knobs at all.
USER:    --ctx (context cap), --prefill-bucket, quality tier
         (fast | balanced | faithful → optimization/compression levels +
          calibration size + pin budget, as one named bundle per tier —
          tiers are RECORDED in the cache key via the alls hash)
POLICY:  compile parallelism, cache retention counts, corpus quotas
FIXED:   gates (KL budget, smoke threshold, calibration floor) — these
         live in the builder's source and the ledger, not in flags:
         a "--skip-kl-gate" flag is a loaded gun in a config file, and
         this route does not ship one. Testing hooks may relax gates in
         TEST PROCESSES ONLY (the TestLedger context), never in builds
         whose HEFs a serving session can load — enforced by a build
         provenance bit the loader checks.
```

## Honest unknowns and risks

- **[unknown]** Whether DFC 5.x translates a full decoder-block stack (RMSNorm + GQA attention + RoPE-by-constants + SwiGLU) without parser surgery. The 3.29 supported-layers table covers the pieces [documented]; DFC 5.2 forum reports show LayerNorm/Transpose patterns killing ViT-class graphs at parse [forum-reported]. Aesir's exporter writes a deliberately plain dialect to stay inside the pattern-matcher's reach, but the first real parse is an experiment, not a certainty.
- **[inferred]** Chunked prefill with cache carried between separately-compiled bucket graphs: the graphs are independent HEFs whose K/V output layouts must agree byte-for-byte. Both come from one exporter and one compile key, which makes agreement likely — but it is verified by the parse-hef/shape gate and the smoke gate, not assumed.
- **[documented risk]** Compile time. The partition/allocation search for one vision model is forum-logged at ~26 + ~29 minutes; a 40+-layer decoder stack at optimization level 4 (guide's own ResNet-50 figure: ~3 hours at level 4 on an A4000) makes install-time builds an hours-scale, resumable, background operation — hence the HAR checkpointing and the cache. This route trades install patience for runtime freedom, openly.
- **[documented risk]** Quantization quality is earned per model (file 09's whole lesson). The KL gate is the route's conscience: a model that cannot pass it is *refused for this backend* with the reason recorded — never shipped weak under a green label.
- **[unknown]** libhailort C API signature stability across 5.x point releases; the gate module reads installed headers at build time (the corpus's own rule for the C++ surface) and the version-pairing gate refuses mismatched sets.

## Smallest first prototype, gate declared in advance

**Build**: TinyLlama-1.1B-Chat Q8_0 GGUF (the model family the ARMVEGR F1 pipeline already serves on Mimir, so Aesir has tokenizers, fixtures, and a CPU oracle for it) → prefill bucket 256 + decode graph at ctx 1024, optimization level 2, compression 0.

**Gate — PASS requires all four**: (1) both graphs parse with `SDK_NATIVE` emulator outputs matching Aesir's CPU block forward within float tolerance; (2) quantized-emulator KL over the frozen 32-prompt suite ≤ the budget recorded in the ledger *before* the build starts; (3) `hailortcli parse-hef` confirms `hailo10h` and the declared shapes; (4) on-device greedy generation of 32 tokens from a fixed prompt reproduces the CPU oracle's token sequence exactly for ≥28 of 32 positions, with every divergence logged. Any failure → the capability stays `missing`, the build log is filed as evidence, and the route's next action is chosen from the failure — not from hope.
