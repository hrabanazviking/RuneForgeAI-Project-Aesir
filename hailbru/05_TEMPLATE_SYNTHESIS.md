# 05 — Template Synthesis: The Block Is a Formula, Not a File

## The idea in one paragraph

Every decoder LLM is the same block, repeated, with different numbers. Exporting *the model's own graph* — the industry default — means asking a pattern-matching compiler to rediscover that fact from an arbitrary exporter's arbitrary spelling of it, which is where parses go to die (the Hailo corpus documents transformer graphs failing at parse time on LayerNorm/Transpose *spellings*, while mathematically identical Hailo-internal builds ship). This route never exports the model's graph at all. Aesir **synthesizes** the decoder block programmatically from the model's dimensions — hidden size, head counts, FFN width, vocabulary, RoPE parameters, norm epsilon, activation family — using a block factory whose output dialect Aesir controls completely, tuned once to what the compiler accepts. It then pours the stock model's weights into the synthesized blocks by tensor name. One parametric block-compiler serves every decoder architecture in the world whose block shape the factory knows — and the factory learns new families by gaining a template, not by each model negotiating with the parser alone.

## Why it needs no precompiled or modified LLM

- The model contributes **only its dimensions and its weights** — both read from the stock GGUF by Aesir's loader. The graph is Aesir's own composition, written from the architecture's public definition (the same definition Aesir's own CPU `forward_pass` implements and oracle-tests).
- No vendor artifact, no vendor conversion of *this* model, no modified checkpoint: the pour map (§3) is a name-by-name transcription, verified tensor-by-tensor against the stock file's directory and hashes.
- A model whose family the factory knows runs the day it publishes. A model of a *new* family needs a new template — honest, bounded work in Aesir's code — and until then the loader refuses it by name, exactly as `core/model_registry.mojo` already refuses unclassified architectures.

## Architecture

```
 stock GGUF ──► loader ──► Dims + TensorDirectory
                              │
        TemplateFactory ──────┤  family registry (mirrors model_registry):
                              │    llama_block, gemma_block, qwen_block, …
                              ▼
                     SynthesizedGraph (HN authored directly — §2)
                              │  blocks × N, prefill + decode variants
        WeightPourer ─────────┤  GGUF tensor ──► template slot, dequantized,
                              │  shape-checked, hash-logged
                              ▼
                     HAR (HN JSON + NPZ) ──► DFC optimize/compile
                              │                 (the compiler as back-end only)
                              ▼
                     HEF pair ──► HailoSession (ControlledTextSession)
```

### The load-bearing choice: author the HAR, skip the export

A HAR's graph is a **textual JSON document (HN)** and its weights a NumPy archive (NPZ) [documented]. The optimize stage consumes HARs (`hailo optimize <har>`, `ClientRunner(har=...)`) — parsing from ONNX is merely the *usual* way a HAR is born, not the only door into the pipeline. This route walks through the HAR door: the factory emits HN for the block stack directly, in the exact layer vocabulary the compiler's own tables document, and the pourer writes the NPZ. Everything fragile about ONNX export — exporter version drift, unfused activations falling off pattern matches, dynamic-shape residue [all documented failure classes] — is designed out, because there is no exporter. What remains is a contract Aesir can unit-test: *factory output HN → DFC accepts, quantizes, compiles* — tested per template, once, in Aesir's test suite (`aesir_engine/tests/run_all.mojo` gains factory golden tests: synthesized HN for a fixture dims set must diff-clean against the archived golden HN).

## The pseudocode

### 1. Dimensions and the family registry

```text
struct BlockDims:                      # everything a template may know
    hidden, n_layers, n_heads, n_kv_heads, head_dim, ffn_hidden, vocab: Int
    norm_eps: Float32
    rope:     RopeSpec                 # theta, style (neox|interleaved), scaling (none|yarn|…)
    act:      Activation               # SILU_GATED (SwiGLU) | GELU_GATED (GeGLU) | …
    attn:     AttnSpec                 # bias on/off, logit_softcap (0 = none), sliding window (0 = full)
    tie_embeddings: Bool
    final_logit_softcap: Float32       # 0 = none (Gemma-2-style families)

struct Template:                       # one per family, in a registry like model_registry
    name: String
    def emit_block(d: BlockDims, idx: Int, w: WeightSlots) -> HNFragment
    def emit_head(d: BlockDims, w: WeightSlots) -> HNFragment
    def tensor_map(d: BlockDims) -> List[(gguf_name_pattern, slot_name)]
```

The registry is deliberately boring: families differ in a *parameter table* (activation, caps, window, norm placement — pre-norm is near-universal in modern decoders; the table says so per family) and rarely in structure. A family whose block genuinely differs (state-space hybrids, MoE routing) does not fit the decoder template and is refused by name — the template's honesty is its boundary, printed in the registry.

### 2. The block factory

```text
procedure emit_block(t: Template, d: BlockDims, i: Int, w) -> HNFragment:
    f := HNFragment(prefix = "layer%d/" % i)
    # --- attention sub-block (pre-norm) ---
    f.add("ew_add",        ins=[x, attn_out_prev_residual_path...])   # wiring per template
    f.add("norm",          ins=[x], params={eps: d.norm_eps, gain: w.attn_norm})       # RMSNorm
    f.add("matmul",        ins=[h, w.wq], out="q")        # shapes literal: [S,H]×[H,Hq]
    f.add("matmul",        ins=[h, w.wk], out="k")
    f.add("matmul",        ins=[h, w.wv], out="v")
    f.add("rope_apply",    ins=[q, k, CONST_TABLES])      # emitted as Mul/Add over
                                                          # precomputed cos/sin constants —
                                                          # constants the FACTORY writes into
                                                          # the NPZ from d.rope, never Sin/Cos
                                                          # nodes [documented: trig unsupported]
    if d.attn.logit_softcap > 0:
        f.add("tanh_softcap", ins=[scores_path], params={cap: d.attn.logit_softcap})
    f.add("attention",     ins=[q, k, v, kv_ports], params={window: d.attn.window})
    f.add("matmul",        ins=[attn_out, w.wo], out="attn_proj")
    f.add("ew_add",        ins=[x, attn_proj], out="x1")                    # residual
    # --- MLP sub-block ---
    f.add("norm",          ins=[x1], params={gain: w.ffn_norm})
    match d.act:
        SILU_GATED: f.add("matmul",[h,w.gate]); f.add("silu"); f.add("matmul",[h,w.up]);
                    f.add("ew_mul",[silu_gate, up]); f.add("matmul",[prod, w.down])
        GELU_GATED: (same shape, gelu in place of silu — GELU is preview-grade in the
                    compiler's tables [documented]; the template's golden tests carry
                    the risk openly, per family)
    f.add("ew_add",        ins=[x1, mlp_out], out="y")
    return f

procedure synthesize_model(t, d, variant) -> HN:
    # variant ∈ {PREFILL(bucket S), DECODE(ctx C)}: identical block emission;
    # only the graph's boundary tensors differ (KV as outputs vs in/out ports,
    # sequence width S vs 1) — one factory, two boundary wirings.
    hn := HN(header = {target: "hailo10h", version: FACTORY_VERSION})
    hn.add_input("hidden_in", shape(variant))
    for i in 0 ..< d.n_layers: hn.stitch(emit_block(t, d, i, slots(i)))
    hn.stitch(emit_head(t, d, slots(head)))
    return hn
```

Every shape in the emitted HN is a literal computed from `d` — no dynamic dims exist to leak through [documented failure class, designed out]. Every operator name is drawn from the compiler's documented supported-layer vocabulary; the factory's golden tests diff against the documented tables when the factory is edited.

### 3. The weight pourer

```text
procedure pour_weights(bp, t, d) -> NPZ raises PourError:
    npz := NPZBuilder()
    for (pattern, slot) in t.tensor_map(d):
        for layer in expand(pattern, d.n_layers) ∪ {global tensors}:
            src := bp.tensors.require(layer.gguf_name)     # missing tensor = the stock
                                                           # file isn't this family:
                                                           # raise, never substitute
            w := compute.dequantize(src)                   # Q2_K..Q6_K etc — existing,
                                                           # oracle-tested dequantizers
            expect_shape(w, slot.shape(d)) or raise PourError("shape", layer, slot)
            npz.add(slot.hn_name, w)
            pour_log.append(layer.gguf_name, slot.hn_name, sha256(w))
    # factory constants join the pour: rope cos/sin tables from d.rope,
    # computed by Aesir (libm on host), written as ordinary weight tensors.
    npz.add("rope/cos", cos_table(d)); npz.add("rope/sin", sin_table(d))
    GATE("pour-complete", npz.names == hn.required_weight_names)   # exact set equality:
                                                           # no missing, no orphan
    return npz
```

The pour log — every tensor's stock name, slot name, and post-dequant hash — is the audit trail that makes "the model's weights, all of them, and nothing else's" a checkable sentence rather than a promise. It files with the build's evidence bundle.

### 4. Back-end compile and gates (the compiler, demoted to back-end)

```text
procedure compile_synthesized(t, d, req) -> HefPair raises BuildFailed:
    for variant in [PREFILL(buckets...), DECODE(ctx)]:
        har := pack_har(synthesize_model(t, d, variant), pour_weights(...))
        runner := ClientRunner(har = har)                  # enter at the HAR door
        runner.load_model_script(forge_script(d))          # machine-written .alls:
                                                           # same discipline as any
                                                           # Aesir-operated compile —
                                                           # flavor, equalization,
                                                           # per-layer a16_w16 pins from
                                                           # the family's sensitivity profile
        runner.optimize(calib)                             # calibration synthesized
                                                           # from Aesir's corpus using
                                                           # the model's OWN tokenizer —
                                                           # the intake pipeline's set
        GATE("kl-" + variant, emulator_kl(SDK_QUANTIZED) <= budget(family))
        hef := runner.compile()
    smoke_gate_on_device(pair, frozen_prompts)             # token parity vs CPU oracle
    LEDGER.record("AES-H10-TPL-<family>", dims_hash, hef_hashes, gate_report)
```

Note the division of labor: the compiler never sees a *model* — it sees Aesir's template output, a graph whose every spelling the factory chose. When a family's compile fails, the failure is in the factory's dialect, fixable in the factory, once, for every model of that family forever. That is the route's compounding advantage, and it is why the factory's golden tests matter more than any single model's success.

## How it plugs into Aesir as it exists

- **New package** `aesir_engine/hailo_tpl/` (factory, registry, pourer) beside `loader/`; the registry pattern copies `core/model_registry.mojo`'s classify/inspect discipline, and `ModelBlueprint` extraction is shared with any other Hailo route.
- **Dequantizers** are `core/compute.mojo`'s existing, oracle-tested ones — the pourer is a consumer, not a new numerics surface. (Where a *quantization-preserving* pour is wanted — keeping W4 codes rather than dequantizing to FP — that is the numeric laboratory's recipe work, deliberately not smuggled into this document.)
- **Build/serve wiring** mirrors the self-compiler route's: `cli/commands.mojo` gains `aesir hailo build --template`; the HEF cache lives in `cli/storage.mojo` keyed by (model sha, template version, ctx); runtime is the `ControlledTextSession` Hailo session behind `core/runtime_plan.mojo` admission.
- **Tests**: factory golden tests + pour-completeness tests join `aesir_engine/tests/run_all.mojo` under the fail-closed `TestLedger`.

## Pseudocode annex A — the tensor map (Llama family, complete)

```text
# tensor_map(d) for the llama template — GGUF names → factory slots.
# Gemma/Qwen maps differ in the obvious places (biases, tied head, norm
# placement) and live beside this one in the registry, same shape.
GLOBAL:
    "token_embd.weight"        -> slots.embedding        (and lm_head if tied)
    "output_norm.weight"       -> slots.final_norm_gain
    "output.weight"            -> slots.lm_head          (untied families)
PER LAYER i:
    "blk.{i}.attn_norm.weight" -> slots[i].attn_norm_gain
    "blk.{i}.attn_q.weight"    -> slots[i].wq
    "blk.{i}.attn_k.weight"    -> slots[i].wk
    "blk.{i}.attn_v.weight"    -> slots[i].wv
    "blk.{i}.attn_output.weight" -> slots[i].wo
    "blk.{i}.ffn_norm.weight"  -> slots[i].ffn_norm_gain
    "blk.{i}.ffn_gate.weight"  -> slots[i].wgate
    "blk.{i}.ffn_up.weight"    -> slots[i].wup
    "blk.{i}.ffn_down.weight"  -> slots[i].wdown
FACTORY CONSTANTS (computed, not poured from the file):
    rope cos/sin tables from d.rope.theta & style; attention scale 1/sqrt(head_dim)

procedure expand_map(map, d) -> List[(gguf_name, slot_name)]:
    out := map.GLOBAL
    for i in 0 ..< d.n_layers: out += map.PER_LAYER.substitute(i)
    GATE("map-total", len(out) == model.tensors.weight_count)
        # the map must account for EVERY weight tensor in the stock file —
        # an unmapped tensor means the template doesn't know this model,
        # and the pour refuses (a silently ignored tensor is a wrong model)
```

## Pseudocode annex B — RoPE tables from the factory

```text
procedure rope_tables(d: BlockDims, max_pos) -> (cos, sin):
    inv_freq[j] := 1 / d.rope.theta ^ (2j / d.head_dim)      # j in [0, head_dim/2)
    match d.rope.scaling:
        NONE: freqs := inv_freq
        YARN | LLAMA3: freqs := scaled(inv_freq, d.rope.factor, d.rope.orig_ctx)
            # the scaling variants are closed-form in the architecture's public
            # definition; each is a named branch with its own golden test vector
            # checked against Aesir's CPU rope (core/rope.mojo) — agreement with
            # the CPU implementation is the spec, per family
    for pos in 0 ..< max_pos: cos[pos] := cos(pos × freqs) ; sin[pos] := sin(...)
    return interleave_per_style(cos, sin, d.rope.style)   # neox vs interleaved
        # layout differs; the factory writes the layout the emitted rope_apply
        # subgraph consumes — one source of truth (this procedure), two
        # consumers (emitted graph; CPU-oracle comparison in the golden tests)
```

## Pseudocode annex C — HN emission helpers (the factory's hands)

```text
struct HNFragment:
    nodes: List[HNNode]            # {name, layer_type, inputs, outputs, params}
    ins, outs: List[String]        # boundary tensor names, namespaced by prefix

    def add(type, ins, params) -> String:      # returns the output tensor name
        n := "%s%s%d" % (prefix, type, counter++)
        nodes.append({n, type, ins, [n + "/out"], params})
        return n + "/out"
    def stitch(other):             # fragment composition: other's inputs must
        assert other.ins ⊆ self.outs ∪ graph_globals   # resolve — compile-time
        nodes += other.nodes                           # checked in the factory,
                                                       # not by the DFC
# The factory's HN writer is deliberately a string-builder over a checked IR:
# JSON is emitted from the node list in one pass, and the golden tests parse
# it back and compare node-for-node against the archived expectation.
```

## Pseudocode annex D — a second family at the table (Gemma-class deltas)

The registry earns its keep when a family's block genuinely differs. Gemma-class deltas against the Llama template, expressed as the parameter table + two emission branches — this is what "add a family" concretely costs:

```text
GEMMA_TEMPLATE.deltas:
    act:              GELU_GATED                 # GeGLU
    attn.bias:        False ; qk_norm: True      # per-head Q/K RMSNorm — an
                        # emission branch: norm nodes inside attention,
                        # gains poured from attn_q_norm / attn_k_norm tensors
    norm.style:       (1 + gain) scaling         # Gemma norm multiplies by
                        # (1+w): a factory constant-fold in the norm emitter
    attn.logit_softcap: 30.0 (early gens) | 0 (later)   # per-MODEL value from
                        # dims, not per-family: the emitter reads d.attn
    final_logit_softcap: 30.0 | 0                # head emitter branch
    embedding_scale:  sqrt(hidden)               # embed output multiplier —
                        # emitted as a constant mul at the graph boundary
    sliding_window:   alternating layers (local/global pattern) — the block
                        # emitter takes idx parity into its attention params

procedure emit_block_gemma(t, d, i, w):
    f := base_skeleton(t, d, i, w)           # shared residual scaffolding
    ... (attention with qk_norm branch; softcap where d.attn.cap > 0;
         window per parity(i); MLP with gelu branch; norms with (1+g) fold)
    return f
# Every delta above corresponds to a field Aesir's CPU forward already
# implements for the family (gemma4_profile.mojo carries the constants) —
# the template is a TRANSLATION of tested semantics into graph dialect,
# and its golden tests diff emitted-graph emulator outputs against the
# CPU forward's per-layer activations for a fixture model of the family.
```

## Pseudocode annex E — the factory's release discipline

```text
# A template is code, and ships like code:
#  - version constant in every emitted HN header (FACTORY_VERSION + template
#    name/version): a HEF built by template v3 is identifiable forever
#  - golden HN archives per (template, fixture dims): factory edits that
#    change emission for EXISTING dims fail CI unless the golden is updated
#    in the same commit with the reason in the commit body
#  - a template's SUPPORTED list (families × variants × ctx buckets it has
#    passed device smoke for) is data shipped with Aesir; admission checks
#    the list, so "the factory can emit it" never overclaims "it ran"
```

## Pseudocode annex F — decode-variant boundary wiring (the KV ports)

```text
# The decode variant's graph boundary is where synthesis earns its rigor:
# KV enters and leaves as GRAPH PORTS, sized by the compiled ctx C —
# the factory emits the port table mechanically from d:
procedure decode_boundary(d, C) -> PortTable:
    ports := [ in  hidden_in      [1, H],
               in  rope_cos_t     [1, hd/2], in rope_sin_t [1, hd/2] ]
    for i in layers:
        ports += [ in  k_cache_i  [1, C, Hkv], in v_cache_i [1, C, Hkv],
                   out k_new_i    [1, 1, Hkv], out v_new_i [1, 1, Hkv] ]
    ports += [ out logits [1, vocab] ]
    return ports
# Port count grows with layers (2 + 4L + 1): at 80 layers that is 323 named
# ports — the factory generates the table, the session binds it from the
# same table data (single source), and the pour/bind cross-check compares
# the session's binding list against this table by hash before activation.
# Hand-maintained port lists are how off-by-one-layer bugs are born; here
# the list is a FUNCTION, tested like one.
```

## Pseudocode annex G — dims extraction: where BlockDims comes from

```text
procedure extract_dims(bp: ModelBlueprint) -> BlockDims raises DimsError:
    # Every field is read from the stock GGUF's metadata keys (the names
    # below are the GGUF schema's, as the loader already parses them):
    d.hidden   := meta.require("<arch>.embedding_length")
    d.n_layers := meta.require("<arch>.block_count")
    d.n_heads  := meta.require("<arch>.attention.head_count")
    d.n_kv     := meta.require("<arch>.attention.head_count_kv", default = n_heads)
    d.ffn      := meta.require("<arch>.feed_forward_length")
    d.vocab    := tokenizer.tokens.count            # from the tokenizer table,
                                                    # cross-checked vs the
                                                    # embedding tensor's rows:
    GATE("dims-vocab", d.vocab == tensors["token_embd.weight"].rows)
    d.rope     := { theta: meta.get("rope.freq_base", family_default),
                    scaling: meta.get("rope.scaling.type", NONE), … }
    # Any require() failure = the stock file doesn't describe a model the
    # factory can synthesize: DimsError names the missing key. A model is
    # never synthesized from HALF a description.
```

## Pseudocode annex H — the synthesized-graph lint (factory self-check)

```text
procedure lint_hn(hn: HN) raises SynthError:
    # Rules the factory imposes on its own output BEFORE the DFC sees it —
    # each rule is a documented failure class, encoded once, forever:
    for node in hn.nodes:
        if node.type in [SIN, COS, LSTM, GRU]: raise SynthError("banned-op", node)
        if any(dim <= 0 or dim == DYNAMIC for dim in node.shapes):
            raise SynthError("nonstatic-shape", node)
        if node.type == TRANSPOSE and node.perm not in SAFE_PERMS:
            raise SynthError("risky-transpose", node)   # the forum-documented
                        # parse-killer patterns are lint errors here, with the
                        # factory's approved rewrite (reshape+permute via the
                        # NHWC-safe set) applied at EMISSION time instead
    GATE("hn-closed", hn.tensor_refs.all_defined)       # no dangling names
    GATE("hn-weights", hn.weight_names == pour.expected)  # pre-pour agreement
```

## Honest unknowns and risks

- **[unknown] Hand-authored HAR acceptance.** The HAR format's openness is documented (HN is JSON; optimize consumes HARs), but whether the 5.x toolchain accepts a HAR whose HN was authored outside its own parser — version stamps, internal fields, checksum conventions — is an empirical question the prototype answers. If the door is shut, the factory emits ONNX instead (same factory, different serializer — the templates survive; only §2's entry point changes), and the document's design notes say which serializer is live.
- **[inferred] Attention as an emitted subgraph.** The guide documents multi-head attention translation ("currently entire block is translated") for *parsed* graphs; the factory instead emits attention from documented primitives (matmul, softmax, reshape/transpose in the NHWC-safe patterns) — the patterns whose exotic cousins failed in forum reports are avoided by construction, but the emitted form must still prove itself at the optimize stage, per family, in golden tests.
- **[documented risk] Family drift.** New families add block variations (deepseek-style MLA, sliding-window hybrids, MoE). The registry grows by templates; a family without one is refused loudly. The route's coverage is exactly its registry — printed in the admission report, never implied to be universal.
- **[inferred] Softcap/window features** (Gemma-class) are expressible as emitted subgraphs (tanh softcap as documented composition ops), at compute cost inside the graph; families requiring them pay it, and the template says so per family.

## Smallest first prototype, gate declared in advance

**Build**: the Llama template only; synthesize a **2-layer** model at TinyLlama dims with **random fixed weights** (no real model at all — the factory is the subject), pour, enter at the HAR door, compile prefill-128 + decode-256.

**Gate — PASS requires**: (1) the hand-authored HAR is accepted by `optimize` (the §Unknowns question, answered by experiment); (2) the compiled pair's on-device forward over a fixed input matches Aesir's CPU forward *of the same synthesized graph semantics* within float-quantization tolerance on every layer output the harness samples; (3) the pour-completeness gate demonstrably fails when one tensor is deliberately omitted. Passing (1)–(3) promotes the route to a real model (TinyLlama full depth) as its second step, with the KL and token-parity gates of the standard build pipeline.
