# 08 — The Numeric Recipe: Aesir's Own Weight Laboratory

## The idea in one paragraph

The catalogue's quality advantage was never a permission — it was a **recipe**: rotation before quantization (QuaROT-style), second-order weight quantization (GPTQ), and per-layer precision judgment, applied by Hailo's engineers to a handful of models [documented as Hailo's own LLM stage: QuaROT + GPTQ; weights 4-bit, activations 8-bit]. Recipes are math, and math can be re-derived. This route builds Aesir its own **weight laboratory**: the rotation and GPTQ implemented in Aesir's own code, a calibration harness that scores every candidate transform at the **logit level** against the FP reference running in Aesir's own engine, and per-layer precision pinning exported into whatever compile machinery consumes it. A stock model enters; a *quantization-surviving* model — same weights' information, re-parameterized by published mathematics — is what the chip receives, at catalogue-grade fidelity, through any compile route that follows. The other routes argue about compilers and formats; this one argues that the real moat was numerics, and numerics can be owned.

## Why it needs no precompiled or modified LLM

Precision of language matters here, because this route touches weights: it **transforms** them, in memory and in build artifacts, by exact mathematical operations whose entire purpose is that the *model's function* is preserved (rotations are orthogonal re-parameterizations — the FP function is identical before quantization error, by construction; GPTQ's compensations minimize the quantization error they respond to). The stock file is never altered; what Aesir serves is always derived from the user's own stock model, on the user's machine, with every transform logged and every fidelity claim gated against the FP reference. That is the same sense in which Aesir's GGUF dequantizers "modify" nothing: the model is the function; the laboratory protects the function through a hostile numeric format. No vendor checkpoint, no catalogue, no one else's tuning — the recipe re-implemented from the published method (QuaROT: Ashkboos et al.; GPTQ: Frantar et al. — papers, not code).

## Architecture

```
   THE LABORATORY (build-time, on the user's host, inside Aesir)
 ┌────────────────────────────────────────────────────────────────┐
 │ FP reference: Aesir CPU forward (oracle-tested)                │
 │ Calibration corpus ──► activation harvester (per-layer inputs) │
 │ Rotation stage: Hadamard construction + fusion into weights    │
 │ GPTQ stage: per-layer Hessian-quantization with compensation   │
 │ Precision planner: per-layer pin table (a8w4 / a8w8 / a16w16)  │
 │ Gate rig: logit KL + top-k agreement + frozen-suite scoring    │
 └────────────────────────────────────────────────────────────────┘
        output: RecipeBundle { transformed weights (in chosen layout),
                               pin table (.alls-ready), gate report }
        consumers: any Aesir-operated compile (DFC intake consumes the
        bundle: transformed weights pour into the graph; pins become
        quantization_param lines) — the lab is compile-route-agnostic.
```

### The mathematics in one breath

**Rotation (QuaROT-style).** Multiply the hidden stream by an orthogonal matrix **R** (block-diagonal randomized Hadamard), and counter-multiply the adjacent weight matrices by **R⁻¹ = Rᵀ**. The network's FP function is unchanged — R and Rᵀ cancel at every seam — but the activation *distribution* changes: outlier channels (the few huge activations that wreck per-tensor INT8 ranges) are smeared across all channels, so quantization ranges tighten dramatically. Online (per-block) rotations at attention's V/O seam and the MLP down-projection input use *fixed* Hadamard matrices applied inside the graph (Hadamard is multiply-by-±1 patterns — cheap, exact, and expressible in the compiler's vocabulary as structured matmuls with ±1/scale constants [inferred viability — a graph-level claim the lab's first prototype proves or kills]).

**GPTQ.** For each linear layer, quantize columns left-to-right; after each column's quantization error is known, adjust the *remaining* columns by the inverse Hessian of the layer's calibration inputs to compensate (optimal-brain-surgeon lineage). The result: W4 error that behaves like a much wider format on real activation distributions — the difference between "4-bit" as a file-size brag and 4-bit as a quality result.

## The pseudocode

### 1. Hadamard construction and the rotation plan

```text
procedure hadamard(n) -> Matrix:                  # n a power of two
    H := [[1]]                                     # Sylvester construction
    while H.dim < n: H := kron(H, [[1,1],[1,-1]]) / sqrt(2)
    return H

procedure randomized_hadamard(n, seed) -> Matrix:
    R := hadamard(n) ; D := diag(random_signs(seed, n))   # fixed by seed,
    return D @ R                                          # recorded in the bundle

struct RotationPlan:
    residual_R: Matrix            # one global R for the residual stream
    folds: List[(weight_name, multiply_by, side)]   # the exact counter-folds:
        # embedding      : E ← E @ Rᵀ        (row space rotated into the stream)
        # per layer: wq,wk,wv ← R @ W  (input side)   [reads the rotated stream]
        #            wo       ← W @ Rᵀ      (output side, returns to stream)
        #            gate,up  ← R @ W ;  down ← W @ Rᵀ
        #            norm gains: RMSNorm is NOT rotation-equivariant — gains are
        #            re-fit by calibration (§3) or norms run unrotated per block
        #            with R applied at block seams; the plan states its choice
        #            per family, and the gate (§4) adjudicates the claim.
    online_hadamards: List[(site, size)]   # V/O seam + down-proj input (QuaROT's
                                           # online pair), emitted into the graph

procedure apply_rotation(model_weights, plan) -> weights' raises RecipeError:
    w' := copy(model_weights)
    for (name, M, side) in plan.folds:
        w'[name] := fold(w'[name], M, side)
        GATE("rotation-exactness",                       # FP identity, machine-checked
             max_err(forward_fp(w', probe) , forward_fp(w, probe)) < 1e-4)
             # run ONCE per model on a probe batch: rotation must be a no-op
             # in floating point, or the fold table is wrong — raise, don't tune
    return w'
```

### 2. GPTQ in Aesir's code

```text
procedure gptq_layer(W [out,in], H2 [in,in], group, bits) -> (Wq, scales):
    # H2 = 2 * Σ x xᵀ over calibration inputs (+ dampening) — the layer's Hessian
    Hinv := cholesky_inverse(cholesky(H2 + λI))          # λ = 0.01 * mean(diag)
                                                         # [published practice]
    Wc := copy(W);  Q := zeros_like(W)
    for col_block in blocks(cols, BLOCK = 128):
        for j in col_block:
            q := quantize_column(Wc[:,j], scales[group(j)], bits)
            err := (Wc[:,j] - dequant(q)) / Hinv[j,j]
            Wc[:, j+1:] -= outer(err, Hinv[j, j+1:])     # the compensation that
                                                         # IS gptq: error is pushed
                                                         # into unquantized columns
            Q[:,j] := q
        Wc[:, after_block] -= (Wc[:, block] - Q[:, block]) @ Hinv[block, after:]
    return (Q, scales)

procedure run_gptq(model, calib_acts, recipe) -> bundle_weights:
    for layer in model.layers: for lin in layer.linears:
        H2 := hessian(calib_acts[layer, lin])            # harvested per-layer inputs
        (Q, s) := gptq_layer(dequantized(lin.W), H2, recipe.group, recipe.bits)
        bundle.set(lin, Q, s)
    # Act-order (permutation by Hessian diagonal) is a recipe switch, recorded.
```

### 3. The calibration harness (shared spine with every Aesir build)

```text
procedure harvest_activations(model_fp, corpus, layers) -> Acts:
    acts := {}; hooks := attach(model_fp.forward, capture = layers.inputs)
    for batch in corpus.batches(1024+ sequences):        # the documented floor is
        model_fp.forward(batch)                          # honored for the SAME data
        acts.accumulate(hooks.drain())                   # the compile calibrates with
    return acts                                          # (calibration-set synthesis)

procedure refit_norm_gains(model_rot, acts) -> gains:
    # where the rotation plan chose stream-rotated norms: per-channel gain that
    # best matches FP pre-rotation norm outputs on calibration data, least
    # squares per channel; recorded per layer; gated like everything else.
```

### 3. The precision planner

```text
procedure plan_precision(model, bundle_draft, budget) -> PinTable:
    sens := {}
    for layer, lin in all_linears:
        sens[lin] := kl_delta(quantize_only(lin, candidate_bits))   # leave-one-out
                    # cost of each candidate precision, measured on the gate suite
    pins := default_all(a8_w4)
    # spend precision where sensitivity buys it, under a total-cost budget:
    for lin in sens.descending:
        if sens[lin].kl > budget.per_layer: pins[lin] := a8_w8
        if still > budget.hard:            pins[lin] := a16_w16   # restricted cases
                    # [documented]; if the compiler refuses the pin, the planner
                    # reallocates: neighboring layer rises instead — recorded
    return PinTable(pins)     # serialized to .alls quantization_param lines by
                              # the compile consumer, verbatim, machine-written
```

### 4. The gates — where claims go to be proven

```text
procedure gate_recipe(model_fp, bundle, suite) -> GateReport raises RecipeRefused:
    ref := logits_of(model_fp, suite.prompts)             # Aesir CPU forward — the
    got := logits_of(bundle_as_fp_model, suite.prompts)   # transformed weights run
                # through the SAME CPU forward in FP: measures the RECIPE alone,
                # before any compiler quantization enters the story
    kl := mean_kl(ref, got); agree := top1_agreement(ref, got)
    GATE("recipe-kl",    kl <= 0.02)      or raise RecipeRefused("recipe", kl)
    GATE("recipe-top1",  agree >= 0.99)   or raise RecipeRefused("top1", agree)
    # budgets declared in the recipe file BEFORE the run — moving them after
    # seeing numbers is the one sin the laboratory does not forgive itself
```

Then the compiled artifact faces the standard second gate (on-device token parity vs CPU reference) under the consuming route — recipe gates and compile gates are separate bundles, so a failure is attributable: numerics or toolchain, never a fog.

## How it plugs into Aesir as it exists

- **New package `aesir_engine/lab/`** (rotation, GPTQ, harness, planner), built on the engine's existing numerics: matrix ops from `core/compute.mojo`'s tested paths (Cholesky/GEMM-class work rides the same kernels the CPU forward uses, or the CUDA backend where available — build-time speed is a convenience, never a correctness dependency), calibration harvesting hooks into `core/inference.mojo`'s `forward_pass`.
- **Existing quant groundwork**: `core/quantization.mojo`, `core/quantization_autotuner.mojo`, `loader/external_quantization.mojo`, `loader/extreme_quantization.mojo`, and `core/iq_codebooks.mojo` already carry Aesir's quantization thinking; the lab consolidates the *recipe* above them (the autotuner's sensitivity experience feeds the planner's defaults).
- **Consumers**: the bundle contract is consumed by the Aesir-operated DFC intake (pins → `.alls`; transformed weights → graph pour), giving every compile route the same numerics instead of each route improvising its own.
- **Ledger**: `AES-H10-LAB-RECIPE-<model hash>` with the gate report hash; recipes are versioned like code (a recipe change re-gates every model built with it — the bundle records recipe version, and stale-recipe packages are re-derivable, never silently trusted).

## Pseudocode annex A — quantize_column and the activation-side of the recipe

```text
procedure quantize_column(w_col, group_stats, bits) -> codes:
    # symmetric per-group W4 [the lab's default; asymmetric is a recipe switch]:
    # groups run ALONG the input dimension (group size 128 default), each with
    # its own FP16 scale — the layout the compile consumer's graph expects.
    for g in groups(w_col):
        s := max(abs(w_col[g])) / (2^(bits-1) - 1)
        codes[g] := clamp(round(w_col[g] / s), -8, 7)         # int4 range
        scales[g] := s
    return codes

struct RecipeFile:                          # versioned, hashed, human-readable
    rotation: { seed, online_sites: [V_O_SEAM, DOWN_IN], fold_norms: SEAM|REFIT }
    gptq:     { bits: 4, group: 128, act_order: Bool, dampening: 0.01,
                block: 128 }
    pins:     { default: a8_w4, budget_kl_per_layer, hard_kl }
    gates:    { recipe_kl: 0.02, recipe_top1: 0.99 }     # declared BEFORE runs
    corpus:   { id, sha, sequences: 2048 }               # calibration identity —
                # a bundle that can't name its calibration data is not a bundle
```

## Pseudocode annex B — Hessian harvesting without drowning the host

```text
procedure hessian(inputs_stream, in_dim) -> H2:
    # H2 is [in_dim × in_dim] FP32: at in_dim 8192 that's 256 MB per linear —
    # fine one layer at a time, fatal if all layers are held at once.
    H := zeros(in_dim, in_dim, FP32)
    n := 0
    for x in inputs_stream:                  # x: [tokens, in_dim] batches
        H += xᵀ @ x                          # rank-k updates; GPU backend used
        n += tokens(x)                       # when present (build-time only)
    return (2.0 / n) * H
# Memory discipline: the GPTQ pass walks layers in order, harvesting H for
# layer i's linears from the PREVIOUS stage's transformed forward — outputs
# of layer i-1 under the recipe are layer i's true inputs (sequential
# dependence is GPTQ's nature: quantize, then propagate, then harvest).
# Peak host RAM = one layer's Hessians + one layer's activations window;
# the runner prints the peak estimate before starting.
```

## Pseudocode annex C — the sensitivity sweep behind the pin planner

```text
procedure sensitivity_sweep(model, suite) -> Table[layer, lin, bits -> KL]:
    base := logits(model.recipe_default_all_a8w4, suite)
    for each linear lin:
        for bits in [a8_w8, a16_w16]:
            trial := model.with_single_change(lin, bits)
            T[lin][bits] := KL(base, logits(trial, suite))
    # One-change-at-a-time is O(linears × precisions) emulator/CPU runs —
    # run on the FP+simulated-quant harness (fast), spot-verified on the
    # quantized emulator for the top-decile sensitive layers only.
    # The planner then spends pins greedily by KL-recovered per unit cost —
    # and the sweep TABLE ships in the bundle: the pin choices are auditable
    # arithmetic, not taste.
```

## Pseudocode annex D — end-to-end recipe run, as the operator sees it

```text
$ aesir lab run --model tinyllama-1.1b-q8_0.gguf --recipe a8w4-std.toml
  [1/6] FP reference logits ............ frozen suite (64 prompts)   OK
  [2/6] calibration harvest ............. 2048 sequences, corpus h4sh…  OK
  [3/6] rotation fold .................. exactness max_err 3.1e-5    OK
  [4/6] GPTQ pass ...................... 22 layers × 7 linears       OK
  [5/6] sensitivity sweep .............. 154 linears, table h4sh…    OK
  [6/6] precision plan + gates ......... pins: 9×a8w8, 2×a16w16
        recipe KL 0.011 (budget 0.02) .... PASS
        top-1 agreement 0.994 (≥ 0.99) ... PASS
  bundle: tinyllama-1.1b.recipe.bndl (weights + pins + reports, h4sh…)
# The transcript format is itself a spec: every stage prints its artifact
# hash, and a FAILED stage prints the gate name and the measured value —
# the bundle is only written when all six stages pass (atomic: partial
# bundles do not exist on disk; a failed run leaves its LOG as evidence
# and no bundle at all).

procedure run_recipe(model, recipe_file) raises RecipeRefused:
    preflight: print time/RAM estimates from dims; require corpus present
               and hash-matching the recipe file's declared corpus id —
               a recipe run against the wrong calibration data refuses
               BEFORE the expensive stages, with both hashes shown
```

## Pseudocode annex E — what the lab deliberately does not do

```text
#  - It does not TRAIN or fine-tune weights toward a task (no QAT/LoRA
#    fitting): the recipe preserves the stock model's function; it does
#    not improve, align, or steer it. (A fine-tune stage exists in the
#    vendor compiler's own post-quantization options — a different tool
#    for a different job, consumed as-is by compile routes, not rebuilt
#    here under a false name.)
#  - It does not prune or distill: output size is the recipe's format,
#    full stop. A smaller model is a different model — the lab's honesty
#    is that its bundles are THIS model, surviving quantization.
#  - It does not chase sub-4-bit weights for the chip path (IQ-codebook
#    territory belongs to Aesir's CPU/ARM engines): the chip's documented
#    floor is W4; the lab works the floor well rather than wishing below it.
```

## Pseudocode annex F — the outlier story, told in numbers the harness prints

```text
# Why rotation works, as the lab's own diagnostic output (per model, in the
# bundle): activation channel statistics before/after rotation —
procedure activation_report(model, acts, plan) -> Report:
    for layer in sampled_layers:
        before := channel_max_abs(acts[layer])          # per-channel peaks
        after  := channel_max_abs(rotate(acts[layer], plan.R))
        rep[layer] := { kurtosis_before, kurtosis_after,
                        int8_range_utilization_before,    # worst channel's
                        int8_range_utilization_after }    # share of the scale
    # A healthy rotation: kurtosis collapses toward gaussian, the max
    # channel's dominance (often 30–100× the median in unrotated LLMs)
    # falls below ~4×, and range utilization evens out — which is
    # precisely the headroom A8 activations were starving for.
    # The report is a GATE INPUT, not decoration: if rotation does not
    # move these numbers for a family, annex-E honesty applies and the
    # rotation stage is skipped for that family by the planner, openly.
```

## Pseudocode annex G — bundle format and consumer contract

```text
struct RecipeBundle:                       # one file, sections hashed
    header:  { model_sha, recipe_file_hash, lab_version, created }
    weights: transformed tensors in the consumer-neutral layout
             (per linear: codes or FP, scales, group geometry) —
             consumers (graph pours) read THIS, never the lab's working files
    pins:    PinTable (per linear: target precision + the .alls line text
             the DFC consumer will emit, pre-rendered and diffable)
    reports: { rotation_exactness, activation_report, sensitivity_table,
               gate_report }               # the evidence, embedded
    apply_log: every transform applied, in order, with parameters —
               the bundle is REPRODUCIBLE from (stock sha + recipe file)
               and the log is how a skeptic checks that claim
procedure verify_bundle(b) -> Bool:
    return all section hashes match header AND
           replay_check(b.apply_log, sample = 3 linears)  # re-derive three
               # tensors from the stock file and compare hashes — spot
               # proof that the log describes the weights it ships with
```

## Pseudocode annex H — rotation seeds and reproducibility

```text
# The randomized Hadamard's sign diagonal is drawn from a seed recorded
# in the recipe file; the SAME (model, recipe) must produce the SAME
# bundle on any host, forever — reproducibility is a gate, not a hope:
procedure derive_signs(seed, n) -> List[±1]:
    rng := PCG64(seed)                       # a NAMED, implemented-in-Aesir
    return [rng.choice(±1) for _ in n]       # generator — stdlib RNGs whose
                                             # streams differ across versions
                                             # are forbidden here for the same
                                             # reason the cache keys hash
                                             # everything: silent drift is
                                             # the enemy this project fights
GATE("bundle-repro", rebuild(model, recipe).hash == bundle.hash)
    # run in CI for one fixture model per lab release; a lab version that
    # cannot reproduce its own bundles does not ship
```

## Honest unknowns and risks

- **[unknown] Online Hadamard inside a compiled graph.** The residual-stream rotation folds into weights for free; the *online* pair (V/O seam, down-input) must execute per token inside the graph as structured ±1 matmuls. Whether the allocator treats these kindly (fusion vs materialization) decides whether rotation's full QuaROT benefit survives compilation, or only its foldable half does. The first prototype measures exactly this, at one layer, before the lab scales.
- **[inferred] Which catalogue claims to target.** Hailo's own sources disagree on scheme details (white paper vs catalogue: symmetric group-wise vs channel-wise [documented conflict]) — so the lab targets *outcomes* (KL and agreement budgets against FP) rather than aping a described scheme. That is the stronger discipline anyway.
- **[documented risk] Calibration sensitivity.** GPTQ and rotation quality ride on calibration representativeness; the harness uses the model's own tokenizer over a general corpus and the gates are computed on held-out prompts — a recipe that only passes on its own calibration data fails the held-out gate by construction.
- **[inferred] Cost.** GPTQ over a 7B model is hours-class host compute (Hessian accumulation + Cholesky per layer) — acceptable as install-time work on a desktop host, heavy on a Pi-class host; the recipe runner reports its estimate up front and can run on any Aesir host, bundles being portable data.

## Smallest first prototype, gate declared in advance

**Build**: the rotation fold + gate rig only (no GPTQ yet), applied to TinyLlama-1.1B in FP on Aesir's CPU forward: fold the global residual rotation through embedding, all block weights, and final head; re-fit or seam-handle norms per the plan's stated choice.

**Gate — PASS requires**: (1) rotation-exactness gate green (FP outputs move < 1e-4 — the fold is mathematically identity, machine-verified); (2) after naive INT8 per-tensor activation quantization *simulated* in the harness, the rotated model beats the unrotated model's logit KL by ≥ 5× on the frozen suite — rotation must pay for its complexity in measured error, or the laboratory's founding hypothesis is wrong for these models and the route narrows to GPTQ + pins with the rotation stage retired by evidence.
