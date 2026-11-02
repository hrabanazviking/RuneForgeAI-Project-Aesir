# J-121 — MTP Preservation

**Slice:** J-121 (Part VIII — Conversion and Model Breadth, J-119–J-136), Project Aesir Janas clean-room road.
**Roadmap text:** "MTP preservation. Conversion keeps prediction-head tensors intact and labelled (feeds J-077); a converted file and its source checkpoint agree tensor-for-tensor in the census."
**Governing handoff:** J-119 doc §3 (C06 → J-121): two documented input forms — (a) extraction from the original checkpoint (J-120's safetensors reader plus range-request fetching of just the block's tensors), (b) copy-as-is from a block-only GGUF through the J-120 writer. The output contract is already built and waiting: the emitted file's head tensors must classify under `core/mtp_census.mojo`'s pre-registered name rules (`nextn`/`mtp`/`assistant`, J-076) and admit under `core/mtp_head_support.mojo` (J-077); the acceptance test is the roadmap's own — converted file and source checkpoint agree tensor-for-tensor in the census. Determinism (same input, same bytes) is J-122's to verify and this slice's to keep.
**Base:** branch `yrsa/janas-j120` tip `b96bec6edb76fc2a9768da052711176150d1c9fc` (the J-120 banked tip `f67747a3` plus the verified post-banking correction of `j120_test_output.txt`, adopted and ls-remote verified by this slice's Job A before this worktree was cut). Origin/main untouched at `4ca75cc237de872a7e69777872ec1077f9e93e92` — this branch line does not rebase onto it.
**Machine state (VM, stated for every claim):** MemAvailable ~4.4 GB at dispatch — below the 5,500 MB inference gate, so no inference runs and none is in scope; lightest compiles only, staged, one at a time. purplelongship is **not used at all** — owned by the 204 road's live S-104 under the coordination law. Synthetic fixtures are the honest scale for this VM; no real MTP-carrying checkpoint exists in any Aesir record to convert (J-076 §3, J-077 §5), and none is downloaded.
**Clean-room record:** no Janas material is consulted in this slice beyond the road's own already-filed clean-room records (J-119's census + handoff, J-076's classifier rules, J-077's admission contract, J-120's converter). The head-tensor naming rules are Aesir's own pre-registered rules from J-076, answered-locally there and bound here. No Janas source code is opened, in this slice or any other.

---

## 0. Protocol (committed first, before any converter extension was built)

This section is committed and pushed (ls-remote verified) before the build (§§1+ are filed after, under these rules and no others).

### 0.1 Head identification (binding J-076, answered-locally there, bound here)

A checkpoint tensor is a **prediction-head tensor** iff J-076's pre-registered substring rules classify its name, first match in this order: contains `nextn` → NEXTN; else contains `mtp` → MTP; else contains `assistant` → ASSISTANT; else no head. The rules are J-076's (`core/mtp_census.mojo`'s `classify_tensor_name`); they are the same rules the converted file's labelling must satisfy (§0.3) and the same rules J-077's admission reads. J-120's converter layer imports nothing (its §0.1 purity), so the conversion-side test is implemented inside `core/lora_convert.mojo` as `lc_mtp_head_kind` — a stated mirror, not a silent restatement: the unit suite (§0.7) proves the mirror and `classify_tensor_name` agree on every fixture name and a fixed probe set including the first-match order, and the file-level evidence (§0.6) classifies the converted directory with J-076's own classifier through J-077's admission path. Any disagreement between mirror and classifier fails the slice.

**Scope of the identification, stated plainly:** the rules classify *names*. Real MTP-carrying families' exact HF tensor names are **not proven** by anything in this road's records (J-076 found zero readable head-carrying files); the synthetic fixture names in §0.6 are chosen to exercise the three classes, and are labelled synthetic wherever they appear. A real checkpoint whose head tensors carry none of the three markers is refused by name at conversion under §0.2's non-head refusal — never silently dropped, never silently carried.

### 0.2 The preservation rule (what changes in the converter, and what does not)

In the strict-naming path (`lc_convert_base`, J-120 §0.4), a base tensor whose name has **no** llama mapping but **does** classify as a head tensor under §0.1 is carried **verbatim**: its GGUF tensor name is its HF name, unchanged, and its values pass through the unchanged J-120 storage rule (2-D → BF16 round-to-nearest-even; 1-D → F32). "Intact" means exactly that: same name, same shape (modulo the GGUF 2-D dim reversal every tensor undergoes), same values after the one storage rounding every converted tensor undergoes — no merging, no renaming, no re-derivation. Everything else about J-120 is unchanged:

- a name with no mapping and no head classification is **still refused by name**, with J-120's exact refusal text;
- a tensor of more than 2 dimensions is still refused by name, head tensors included;
- the merge (J-120 §0.2–0.3) runs in HF space before naming, exactly as before; an adapter pair targeting a head tensor would merge under those rules — stated here, **not** separately proven in this slice (the §0.6 fixture is adapter-free; the combination files as NOT PROVEN in the honesty ledger);
- the C05 BF16-only scope decision stands untouched: a quantized anything is still refused by name.

The conversion result (`LcConversion`) additionally records the carried head tensors (GGUF names + J-076 kinds, census order) so hosts and drivers report the label from the conversion itself, not by re-classifying.

### 0.3 Labelling (two labels, both mechanical)

A converted file labels its head tensors twice:

1. **The names themselves** — verbatim carry (§0.2) means every carried head name classifies under J-076's rules in the converted directory, which is the label `core/mtp_head_support.mojo`'s admission reads (J-119 §3's output contract).
2. **Explicit metadata**, emitted **only when at least one head tensor is present**: `aesir.mtp.head_count` (u32, the number of carried head tensors) and `aesir.mtp.head_tensors` (string array, the carried GGUF names in census order). A conversion with no head tensors emits exactly J-120's 19 metadata entries and no `aesir.mtp.*` key — head-free conversions stay byte-for-byte what J-120 proved (the neighbour re-run of J-120's suite and file evidence, §0.7, is the regression proof). With heads present the metadata count is 21.

### 0.4 The census-agreement rule (the acceptance test, pre-registered)

A converted file and its source checkpoint **agree tensor-for-tensor in the census** iff all of the following hold, checked element-for-element, never sampled:

- equal tensor counts (source checkpoint tensors == converted census entries);
- a bijection by name: every source tensor appears exactly once in the converted census, under its §J-120-0.4 mapped name (ordinary tensors) or its verbatim name (head tensors), and no converted entry is left over;
- shapes agree (converted dims == source dims, reversed for 2-D as the GGUF directory writes them);
- every element agrees after the storage rule: the converted value equals the BF16 round-to-nearest-even of the source Float32 value (2-D) or the source value bit-exactly (1-D). The §0.6 fixture values are BF16-exact by construction (the J-120 fixture discipline), so exact agreement is the honest demand;
- the head census agrees as a census: per-kind counts (nextn / mtp / assistant) computed by J-076's classifier over the source names equal those over the converted names, and both directories verdict **WITH_MTP**.

The rule is proven three independent ways: the unit suite (in-layer, §0.7), an independent pure-stdlib verifier at file level (§0.6, sharing no code with the converter), and the converter's own GGUF reader re-reading the emitted file.

### 0.5 Admission agreement (J-119 §3's output contract, made a test)

The converted file's tensor directory (names only, directory read) fed through `core/mtp_head_support.mojo`'s `evaluate_mtp_admission` must return **ADMITTED**, with the head tensors named in directory order and per-kind counts equal to the source checkpoint's; the source directory admitted the same way must agree. A converted file that its own road's admission gate refuses would fail this slice on its face.

### 0.6 Extraction and the block-only forms (J-119 forms (a) and (b), disposed)

- **Local extraction (built):** `lc_extract_mtp_block(tensors)` returns exactly the head-classified tensors of a checkpoint, in source order, values untouched. Emitting that list through the same writer with the source geometry produces a **block-only GGUF** whose census is exactly the head census of the source — the second road to a WITH_MTP file that J-077 §5 names. A checkpoint with **zero** head tensors presented for extraction is **refused by name** (nothing to extract is not a silent empty block file).
- **Copy from a block-only GGUF (built, via J-120's C10 mode):** the from-gguf path already carries unmapped names verbatim; this slice proves an MTP-carrying GGUF round-trips through it **byte-identically** with its head census unchanged (§0.7 group 8).
- **Range-request fetching (DEFERRED-WITH-REASON, stated in the protocol, not discovered later):** J-119 form (a)'s remote half — fetching only the block's tensor ranges from a hosted checkpoint (the documented 487 MB-instead-of-14 GB behaviour) — is **not built** in this slice. Reason, exact: no sha-pinned MTP-carrying checkpoint exists in any Aesir record (J-076 §3 graded every named case ABSENT-FILE / NOT PROVEN; J-077 §5 carries the same leg deferred), so range machinery would have no pinned target to be proven against — building it unproven would violate the road's pin-first discipline. Recipe, binding on the worker who builds it: when a sha-pinned MTP-carrying checkpoint exists, extend `loader/huggingface.mojo` with range requests for (i) the safetensors header and (ii) exactly the byte ranges the header assigns to §0.1-classified tensors, verify the assembled block against the pin, then feed it to this slice's local extraction unchanged. Re-cited at the J-131 refusal ledger and the J-136 Part VIII gate if still unbuilt there.

### 0.7 File-level evidence (independent, synthetic, honest scale)

`docs/janas/j121_fixtures.py` (pure stdlib) writes a synthetic HF checkpoint — J-120's 1-layer llama toy at its protocol geometry (vocab 8, hidden 8, heads 2, KV heads 1, ffn 16) **plus four head tensors** exercising all three classes: `model.nextn.eh_proj.weight` [8, 16] (NEXTN, 2-D), `model.nextn.shared_head_norm.weight` [8] (NEXTN, 1-D), `model.mtp.fc.weight` [8, 8] (MTP, 2-D), `model.assistant.head_norm.weight` [8] (ASSISTANT, 1-D) — 16 source tensors in all, per-kind source census nextn 2 / mtp 1 / assistant 1, verdict WITH_MTP. Deterministic dyadic values, BF16-exact by construction (the J-120 discipline). `docs/janas/j121_convert.mojo` converts with `lc_convert_base` (no adapter — §0.2's stated scope), prints the census and the carried-head label, converts **twice** and compares the bytes (determinism kept, per the handoff), and runs the C10 from-gguf round-trip over the result. `docs/janas/j121_verify.py` (pure stdlib, independent implementations of both formats) re-reads the GGUF and the fixture checkpoint and checks §0.4's rule in full: bijection, shapes, every element, the §0.3 metadata labels, and the per-kind head census on both sides. No number in this slice is a wall, a rate, or a latency; no live model runs.

### 0.8 Unit suite and neighbours (pre-registered)

New suite `aesir_engine/tests/test_mtp_preservation.mojo`, groups in order: (1) mirror/classifier agreement (§0.1, incl. first-match order and ordinary names); (2) strict conversion carries heads verbatim (names, census, values after storage); (3) unmapped non-head name still refused by name; (4) metadata labels present iff heads (21 vs 19 entries, label contents exact); (5) census agreement §0.4 in-layer (bijection + per-kind counts via `MtpCensus` on both sides); (6) admission agreement §0.5 (converted + source directories ADMITTED, heads named, counts equal); (7) extraction (§0.6: exact head set, order, zero-head refusal by name, block-only emission census == head census, WITH_MTP); (8) from-gguf MTP round-trip byte-identical, census unchanged; (9) head-free conversion unchanged (19 metadata entries, no `aesir.mtp.*` label, census as J-120). Neighbours re-run from this tree: `test_lora_convert` (J-120, 9 groups), `test_mtp_census` (J-076, 8 groups), `test_mtp_head_support` (J-077, 10 groups). A loader-machinery re-read of the MTP file (the J-120 §0.6 three-level pattern) is attempted as `docs/janas/j121_reread.mojo`; if the loader refuses a head-carrying file, that refusal is disposed in the doc as a discovered defect with its fix or its recorded next item — never silently dropped from the evidence.

### 0.9 Carried items (re-cited, not this slice's scope)

- **`cli/repl.mojo` `read_line()`'s defective `String(List[Byte])` idiom** (discovery J-109 §7, re-cited J-118 gate §6, J-119 §6, J-120 §0.8/§10) remains the road's immediate next item for its own fix slice with tests. It is not a converter defect and is not fixed here.
- **G-119-1** (vision conversion C07 has no Part VIII owner) stands routed to **J-131's** refusal ledger. Re-cited here so the routing is not lost; nothing in this slice touches it.
- **J-077's deferred live drafter leg** (J-077 §5) is *fed* by this slice, not closed by it: a converted WITH_MTP file produced here is synthetic; the live leg still needs a real head-carrying file and its head executor, per J-077 §5's recipe.

**No README is touched. Hailo stays parked (no finish-line branch contact, no chip run or probe). No Docker. Nothing is deleted to free disk.**

*(§§1+ are filed below from the build, under this protocol.)*
