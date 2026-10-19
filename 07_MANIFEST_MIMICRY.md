# 07 — Manifest Mimicry: The Format Without the Catalogue

## The idea in one paragraph

Hailo's GenAI distribution format is, at bottom, a **package**: a HEF (or a small set of them) plus a JSON manifest that names the files, pins their SHA-256 hashes, and carries the chat template and generation parameters an LLM needs to be *served* rather than merely *run* [documented structure]. The catalogue's power was never the format — it was that only Hailo's models were ever packaged in it. This route separates the two: Aesir studies the shipped packages as inspectable artifacts on disk, reimplements the package **format** in its own code, and manufactures its own packages for stock models — HEFs produced by Aesir's own compile intake, manifest written by Aesir, tokenizer and template taken from the stock model itself — then serves them through **Aesir's own loader and server**. No hailo-ollama process, no Hailo catalogue entry, no vendor in the loop at run time. If the format later proves useful for interoperability (tools that already speak it), Aesir's packages conform — but conformance is a courtesy Aesir extends, not a cage it lives in.

## Why it needs no precompiled or modified LLM

- The package's HEF is compiled by Aesir's own operated toolchain from the stock model at install time on the user's machine (the self-compiler intake: exported graph, machine-written `.alls`, synthesized calibration, KL gate). Nothing precompiled exists anywhere in the story.
- The manifest is **metadata Aesir authors about its own build**: hashes of files Aesir just made, the model's own chat template read from the stock GGUF, generation defaults Aesir sets. Authoring a manifest modifies the model no more than writing a Modelfile does — and Aesir already authors model manifests of its own (`cli/manifest.mojo`).
- The stock file remains the source of truth: every package records the stock file's SHA-256, and the loader verifies package↔source correspondence before serving (see §4 — this is what keeps "package" from decaying into "someone's modified copy").

## Architecture

```
   STUDY PHASE (once, offline, evidence-bundled)
   hailo-apps / GenAI model dirs on disk ──► ArtifactReader
        ├─ manifest.json instances → field census (names, types, optionality)
        ├─ HEF inventory → parse-hef records (roles: prefill/decode, arch strings)
        └─ template_params / generation_params shapes → FormatSpec v1
                        (Aesir's own document, graded field by field)

   PACKAGE PHASE (per stock model, install time)
   stock GGUF ──► Aesir compile intake ──► HEF set
              ──► PackageWriter ──► <model>.aesirpkg/
                        manifest.json   (format-conformant, Aesir-authored)
                        *.hef           (hashes pinned in the manifest)
                        build_report.json (Aesir's own evidence: gates, versions)
                        SOURCE.sha256    (the stock file this package serves)

   SERVE PHASE (run time — Aesir only)
   Aesir loader ──► verify hashes ──► HailoSession ──► native_serve (18434 /
              Ollama-compat 11434 — Aesir's own listeners, both already built)
```

### What the manifest carries [documented fields]

From the corpus's study of the shipped format: per model/size directory, `manifest.json` with `hef_h10h` (the HEF filename **and its SHA-256**), `template_params`, `generation_params`, `details`, and optional `license` and `system_prompt`; HEF sets realize the prefill + decode split; the ollama-style server that consumes the format listens on port 8000 with `/hailo/v1/list`, `/api/pull`, `/api/chat` [all documented]. Aesir's writer emits the same field names with the same types — learned from artifacts, graded in the FormatSpec — while `details` gains an `origin` block the catalogue's manifests don't have: `{packager: "project-aesir", source_sha256, dfc_version, hailort_version, build_gates: {...}}`. Extra fields in a JSON object are how formats grow without breaking; Aesir's additions are additive and ignorable by any other reader.

## The pseudocode

### 1. The study: from artifacts to a graded FormatSpec

```text
procedure study_shipped_packages(roots: List[Path]) -> FormatSpec raises StudyError:
    census := {}                       # field -> {seen_in, types, required?}
    for pkg in enumerate_packages(roots):            # hailo-apps trees, GenAI caches
        m := json.parse(pkg / "manifest.json") or raise StudyError("unreadable manifest")
        for (field, value) in m:
            census[field].note(type(value), pkg.id)
        for role in model_roles(pkg):
            hefs[role] := hailortcli.parse_hef(pkg / file_for(role))
                        # arch string, net names, shapes — the HEF side of the format
        templates.note(pkg, m.template_params)       # delimiters, roles, stop strings
        genparams.note(pkg, m.generation_params)     # temperature/top_p/context defaults
    spec := FormatSpec(fields = census,
                       grades = {field: DOCUMENTED if in vendor docs
                                       else OBSERVED if in >= 2 packages
                                       else SINGLE_OBSERVATION})
    if spec.required_fields_missing_evidence: raise StudyError(spec.gaps)
    write("docs/evidence/genai-format-spec/", spec)  # bundled, hashed, kept
    return spec
```

The census discipline matters: a field seen in every shipped package is ground; a field seen once is a rumor, and the writer treats the two differently (rumor fields are emitted only when Aesir independently knows their value — e.g. `license` is copied from the stock model's own metadata, never invented).

### 2. The package writer

```text
struct AesirPackage:
    dir: Path
    manifest: Manifest

procedure write_package(model, hefs: HefSet, gates: BuildGates) raises PackageError:
    dir := store.package_dir(model.sha)              # DurableModelStore territory:
                                                     # cli/storage.mojo — content-
                                                     # addressed, digest-verified
    manifest := {
        hef_h10h: { file: hefs.primary.name, sha256: sha256(hefs.primary) },
        hefs:     [ {role, file, sha256} for hefs.all ],   # prefill/decode/etc
        template_params:   template_from_stock(model),     # loader/chat_template.mojo
                                                           # output — the model's own
        generation_params: aesir_defaults(model),          # temp/top_p/ctx: Aesir's
                                                           # serving defaults, from the
                                                           # model's own config where set
        details: { family, params, quant: "A8W4 (Aesir build)",
                   origin: { packager: "project-aesir",
                             source_sha256: model.sha,
                             dfc_version, hailort_version,
                             gates: gates.summary } },
    }
    atomic_write(dir / "manifest.json", json(manifest))    # durable-store write rules:
    for f in hefs.all: atomic_copy(f, dir)                 # fsync + rename, verify hash
    write(dir / "SOURCE.sha256", model.sha)
    GATE("package-self-check", verify_package(dir).ok)     # §3, run before the package
                                                           # is visible to the loader
```

### 3. Verification — the package's immune system

```text
procedure verify_package(dir) -> VerifyReport raises PackageError:
    m := json.parse(dir / "manifest.json")
    src := read(dir / "SOURCE.sha256")
    model := store.find_by_digest(src) or raise PackageError("source model not in store")
    for entry in m.hefs:
        actual := sha256(dir / entry.file)
        if actual != entry.sha256: raise PackageError("HEF hash mismatch", entry.file)
        hef := hailo.hef_parse(dir / entry.file)
        if hef.hw_arch != "hailo10h": raise PackageError("wrong target", hef.hw_arch)
    if m.template_params.hash != template_from_stock(model).hash:
        raise PackageError("template drifted from stock model")
    return ok(model, m)
```

Verification is what makes the format safe to imitate: a package is servable exactly while it provably corresponds to a stock model in the user's own store and to HEFs that hash as recorded. A hand-edited or corrupted package refuses to load — the same fail-closed posture as `DurableModelStore`'s digest checks.

### 4. The serve path

```text
# cli/commands.mojo: `aesir pull <model>` / `aesir run <model>` gain a package branch:
procedure load_for_serving(name) raises:
    if store.has_package(name):
        rep := verify_package(store.package_dir(name))      # §3 — always, cheap
        session := HailoSession(rep.hefs, template = rep.manifest.template_params,
                                gen_defaults = rep.manifest.generation_params)
        return serve_loaded(session)          # Aesir's server: /v1/generate,
                                              # /v1/chat/completions, /api/chat —
                                              # the routes already implemented
    else: (existing paths: CUDA session, CPU session … unchanged)
```

The served API is Aesir's own (`cli/native_serve.mojo`, loopback-hardened protocol in `server/local_transport.mojo`). The one deliberate echo of the catalogue's server is *shape compatibility where free*: Aesir's Ollama-mode listener already answers Ollama-style routes on 11434 for its own reasons, so tools written against the catalogue's ollama dialect find a familiar door — held by Aesir, on Aesir's port, serving Aesir's packages.

## How it plugs into Aesir as it exists

- **Store**: packages live in `cli/storage.mojo`'s `DurableModelStore` beside the models they serve (content-addressed layout, lock discipline, GC rules all inherited — a package whose source model is collected becomes unservable by §3 and is itself collected).
- **Manifest kinship**: `cli/manifest.mojo`'s `ModelManifest`/`RuneModelStore` already model Aesir-native manifests; the GenAI-format manifest is a *second serialization* of build facts, generated from the same in-memory build record — one truth, two documents.
- **Compile intake** is the Aesir-operated DFC pipeline (machine `.alls`, calibration synthesis, KL gates, version-pairing gate) — this route adds the packaging and serving layers around it, and is explicit that its compile core is that shared machinery.
- **Templates** come from `loader/chat_template.mojo` (already extracts and normalizes stock templates, including stop conditions) — the writer consumes its output, never a second implementation.
- **Ledger**: `AES-H10-PKG-FORMAT` (the FormatSpec study) and `AES-H10-PKG-<model hash>` per package.

## Pseudocode annex A — the FormatSpec as a data structure

```text
struct FieldSpec:
    name: String
    types_seen: Set[String]            # JSON types across all censused packages
    presence: (count, of_total)        # in how many packages the field appears
    grade: DOCUMENTED | OBSERVED | SINGLE_OBSERVATION
    semantics: Prose                   # what the field DOES, from docs + behavior
    aesir_writer: EmitRule             # how Aesir's writer produces this field:
        #   FROM_BUILD   — value from the build record (hashes, sizes)
        #   FROM_STOCK   — value copied from the stock model's own metadata
        #   AESIR_POLICY — value set by Aesir's serving policy (defaults)
        #   OMIT         — Aesir doesn't know a true value; field is omitted
        #                  (a missing optional field is honest; an invented
        #                  value is a lie in JSON)

struct FormatSpec:
    version: DateOrTag                 # the studied GenAI release line
    fields: Map[String, FieldSpec]
    roles: List[HefRole]               # prefill / decode / (vlm extras) as seen
    gaps: List[String]                 # questions the census could NOT answer —
                                       # published with the spec, not smoothed
```

## Pseudocode annex B — package lifecycle in the store

```text
state machine: BUILT → VERIFIED → SERVABLE → (STALE | ORPHANED) → COLLECTED
    BUILT:      writer finished; self-check gate passed
    VERIFIED:   a cold-process verify_package() passed (different code path
                than the writer's self-check — the verifier shares no state)
    SERVABLE:   loader may open sessions from it
    STALE:      toolchain versions moved, or the recipe/profile that built
                its HEFs was superseded → loader refuses, offers rebuild
    ORPHANED:   source model left the store → unservable by §3, collectable
    COLLECTED:  bytes removed by store GC under lock (audit line kept)

procedure on_serve_request(pkg):
    match pkg.state:
        SERVABLE: verify_light(pkg)      # hashes only — full verify is for
                                         # state transitions, not every request
        STALE:    raise PackageStale(pkg.build_versions, current_versions)
        _:        raise PackageNotServable(pkg.state)
```

## Pseudocode annex C — what Aesir does NOT imitate (deliberate non-goals)

```text
# Recorded so the format's gravity doesn't quietly widen the route:
#  - the /api/pull DOWNLOAD protocol: Aesir packages are built locally from
#    local stock models; there is nothing to "pull". (A future package
#    EXPORT/IMPORT between a user's own machines is a store feature, specced
#    in the store's terms, not in the vendor's protocol terms.)
#  - the vendor server's per-model KV-cache layout on disk: Aesir's session
#    state is Aesir's (conversation snapshots, cli/conversation.mojo).
#  - any licence/DRM semantics: `license` is copied FROM_STOCK or OMIT —
#    Aesir packages carry the stock model's own licence text, verbatim,
#    and add no restrictions of their own.
```

## Pseudocode annex D — template_params, produced from the stock model

```text
procedure template_from_stock(model) -> TemplateParams raises PackageError:
    ct := chat_template.extract(model)        # loader/chat_template.mojo:
                        # declared template if the GGUF carries one; else the
                        # family's structural fallback, named as fallback in
                        # the build report (a synthesized template is labeled
                        # synthesized — the manifest never dresses a guess
                        # as the model's own words)
    return {
        format:        ct.dialect,                    # chatml | llama3 | gemma…
        bos, eos:      model.tokenizer.specials,
        stop_strings:  ct.stop_strings ∪ [ct.eos_text],
        roles:         ct.role_markers,               # system/user/assistant
        hash:          sha256(ct.canonical_text),
    }
    # The hash is the point: verify_package recomputes it from the stock
    # model in the store; a package whose template was edited after build
    # fails verification (§3) — templates steer generation too much to be
    # mutable metadata.

procedure generation_params_from(model) -> GenParams:
    # Model-card defaults where the stock metadata declares them
    # (temperature/top_p/repeat penalties in GGUF metadata), else Aesir's
    # serving policy defaults — the origin of every value is recorded
    # per-field in build_report.json (FROM_STOCK vs AESIR_POLICY), so a
    # user auditing why their model samples as it does gets an answer,
    # not a shrug.
```

## Pseudocode annex E — conformance self-test against shipped packages

```text
procedure conformance_check(spec: FormatSpec) -> Report:
    # Read-only differential: for every shipped package the study censused,
    # parse its manifest with AESIR'S reader (the loader's parser) and diff
    # the understood-fields set against the spec's census. Any field Aesir's
    # reader would DROP is listed — unknown fields are preserved as opaque
    # JSON on read (never silently discarded), and the check proves the
    # preservation works on real artifacts before Aesir writes its own.
```

## Pseudocode annex F — a worked package (the artifact, whole)

```text
tinyllama-1.1b.aesirpkg/
├── manifest.json
│     { "hef_h10h": {"file": "decode-2048.hef", "sha256": "9be2…"},
│       "hefs": [ {"role":"prefill","file":"prefill-256.hef","sha256":"41aa…"},
│                 {"role":"decode","file":"decode-2048.hef","sha256":"9be2…"} ],
│       "template_params": {"format":"llama3-style","hash":"c771…", …},
│       "generation_params": {"temperature":0.7,"top_p":0.9,"context":2048},
│       "details": {"family":"llama","params":"1.1B",
│                   "origin": {"packager":"project-aesir",
│                              "source_sha256":"55d0…",
│                              "dfc_version":"5.3.0","hailort_version":"5.3.0",
│                              "gates": {"kl":0.0137,"smoke":"31/32"}} } }
├── prefill-256.hef   decode-2048.hef
├── build_report.json     ← Aesir's full evidence (stages, repairs, hashes)
└── SOURCE.sha256         ← "55d0…" — the stock GGUF this package serves
# Everything Hailo's format carries, Aesir's carries; everything Aesir
# ADDS (origin, build_report) is the difference between a package and a
# package with a chain of custody.
```

## Pseudocode annex G — the reader: parsing packages Aesir didn't write

```text
procedure read_foreign_manifest(path) -> ForeignPackage raises ManifestError:
    # The loader can also READ a shipped-format manifest (study/serving
    # diagnostics) — with a stranger's-manifest discipline:
    m := json.parse(path)                     # strict: duplicate keys refuse
    for f in m.fields:
        spec_f := SPEC.fields.get(f)
        if spec_f == none: opaque[f] := m[f]  # preserved verbatim, never
                                              # interpreted — unknown fields
                                              # are data, not instructions
        else: check_type(f, spec_f.types_seen) or raise ManifestError(f)
    hashes := verify_listed_hefs(m, dir)      # same hash law as our own
    return ForeignPackage(known = m.known, opaque, hashes)
    # A foreign package is READABLE and INSPECTABLE; whether it is SERVABLE
    # by Aesir's session is a separate, gated question (its HEFs' roles and
    # shapes must match a session profile) — reading never implies serving,
    # and the type system keeps the two results distinct.
```

## Pseudocode annex H — rebuild economics (when a package goes STALE)

```text
procedure on_toolchain_upgrade(old_tc, new_tc):
    # A DFC/RT upgrade marks every package STALE (their HEFs' toolchain
    # pairing is a build fact, not an eternal truth) — but rebuilds are
    # TRIAGED, not stampeded:
    for pkg in store.packages.by_use_frequency:
        verdict := revalidate_cheap(pkg, new_tc)
            # parse-hef the existing HEFs under the NEW runtime; run the
            # on-device smoke suite against them READ-ONLY: a surprising
            # share of upgrades leave working HEFs working, and the
            # smoke gate — not the version string — is the authority
        if verdict.smoke_ok: pkg.restamp(new_tc, evidence = verdict.bundle)
        else: queue_rebuild(pkg, priority = pkg.use_rank)
    # Restamping without a smoke pass is forbidden by construction: the
    # restamp procedure REQUIRES a fresh bundle id as an argument.
```

## Honest unknowns and risks

- **[unknown] Load-time validation inside Hailo's own stack.** This route deliberately does **not** serve through Hailo's GenAI runtime or hailo-ollama — Aesir loads HEFs through HailoRT directly. Whether Hailo's ollama server would accept an Aesir-authored package dropped into its model tree is *not* claimed: its loader may validate more than hashes (layout rings, internal naming, cache-state conventions — the corpus notes the server keeps per-model KV caches in its own layout). If a user wants that interop, it is a separate experiment with its own gate; the route's promise stops at Aesir's own loader, and says so.
- **[inferred] Format drift.** The manifest format is a vendor's living format; new fields will appear. The census re-runs as a maintenance task (on GenAI updates), and the FormatSpec is versioned; Aesir's writer targets the studied version and records which in every package's `origin` block.
- **[documented risk] Template semantics.** `template_params` in shipped packages encode Hailo's runtime's expectations (its tokenizer and chat handling live host-side in HailoRT's Rust [documented]). Aesir's writer emits the fields for format conformance, but Aesir's *behavior* comes from its own `chat_template.mojo` semantics — where the two disagree, Aesir follows its own, and the build report notes the divergence rather than letting a metadata field silently steer generation.
- **[inferred] The format study requires artifacts**: a GenAI installation (or hailo-apps checkout) on a study host to census. Lawful inspection of files on one's own machine; the study bundles its evidence like every Aesir study (`docs/evidence/` discipline).

## Smallest first prototype, gate declared in advance

**Build**: the study + writer + verifier only — no new compile work. Package an *existing* Aesir-built HEF pair (from any prior compile-route prototype) for TinyLlama-1.1B, with the manifest written from the FormatSpec.

**Gate — PASS requires**: (1) the FormatSpec's required-field census covers every field in at least three distinct shipped packages, each field graded; (2) the written package passes `verify_package` from a cold process; (3) deliberate corruptions — one flipped HEF byte, one edited template field, one swapped SOURCE hash — each raise their named `PackageError` and the loader serves nothing; (4) the packaged HEFs serve 32 greedy tokens through Aesir's own server identical to the same HEFs loaded unpackaged. The route is proven as a *format* before a single new model depends on it.
