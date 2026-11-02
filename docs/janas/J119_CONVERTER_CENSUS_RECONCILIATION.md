# J-119 — Converter Census Reconciliation

**Slice:** J-119 (Part VIII — Conversion and Model Breadth, J-119–J-136), Project Aesir Janas clean-room road.
**Roadmap text:** "Converter census reconciliation. The J-010 rows against Aesir's existing conversion/import path: the exact delta (LoRA merge, MTP preservation, anything else documented)."
**Base:** branch `yrsa/janas-j118` tip `afc20e7e5c938806c04a7546a966e36eb18ab964` (ls-remote verified by the keeper at dispatch; no remote `yrsa/janas-j119` existed before this slice — the duplicate guard). Origin/main untouched at `4ca75cc237de872a7e69777872ec1077f9e93e92` — this branch line does not rebase onto it.
**Machine state (VM, stated for every claim below):** MemAvailable ~2.0 GB at dispatch — below the 5,500 MB inference gate, so no inference ran and none was needed: this is a census slice. No compile was needed either (pure tree inspection + a Python inspect script). purplelongship was **not used at all** — owned by the 204 road's live run under the coordination law.
**Clean-room record:** no Janas material was consulted in this slice beyond Part I's own already-filed clean-room records (`CENSUS.md` §J-010 and the Concordance `DELTA_TABLE.md`, campaign copies in `~/workspace/model-tests/janas/`, re-read first-hand this slice) and the later slices that already graded converter-adjacent rows (J-076/J-077 engine-side MTP, J-099 rows T24–T28, J-103's `--from-gguf` note, the J-118 gate's converter restatement). The Janas-side rows below are those filed rows, not a new study. No Janas source code was opened, in this slice or any other.

---

## 0. Reconciliation protocol (committed first, before the census was run)

This section was committed and pushed (ls-remote verified) before the reconciliation table (§§2–4) was filed. It states what is re-read, what counts as evidence, and the verdict forms; the table is then filed under these rules and no others.

**What is re-read.**

1. **The Part I converter rows.** The J-010 census converter family as filed in `CENSUS.md` §J-010 (`gguf2jns`, `jns_planes`, `hf2gguf` with its LoRA merge and post-conversion quantization leg, `hf2jns_mtp`, `hf2jns_vision`, the speech converters `hf2jns_whisper`/`silero2jns`/`wespeaker2jns`, and `jns_check`), graded by the Concordance in `DELTA_TABLE.md` rows **60, 61, 62, 63, 64, 66, 71**, plus two documented behaviours the J-010 text carries that no Concordance row isolates: `janas-get --from-gguf` (download the original GGUF and convert locally to the same fingerprints) and the documented IQ1/IQ2 *conversion* "not yet" tension beside Aesir's proven IQ *reading*.
2. **Aesir's existing conversion/import path, from this tree only.** The whole of `aesir_engine/` at the branch tip: the loader family (`loader/gguf.mojo`, `packed_gguf.mojo`, `huggingface.mojo`, `mmproj.mojo`, `quantization.mojo`, `exl2.mojo`, `onnx.mojo`), the CLI dispatch (`cli/commands.mojo` — every `cmd ==` arm), the engine-side MTP layers Parts V built (`core/mtp_census.mojo`, `core/mtp_head_support.mojo`), and tree-wide word scans (LoRA, GGUF-writer symbols, safetensors) over every `.mojo` file. Every claim in the table cites a file or a mechanically re-run scan. No claim is taken from memory or from a prior slice's prose where this tree can speak for itself.

**Verdict forms (pre-registered).** Each reconciled row takes exactly one verdict, in the dispatch's vocabulary:

- **HAVE** — Aesir's tree today performs this conversion/import behaviour in a form a user/host can use.
- **PARTIAL** — one side of the behaviour exists (typically the read side) and the conversion side does not; the missing half is named exactly.
- **ABSENT** — nothing in the tree answers to it (scan/inspect-verified absence, stated as such); the exact gap is named as the owning slice's build order.
- **REFUSED** — the J-013 Concordance / J-014 gate already refuses it, or the J-118 gate restated the refusal; this census restates it, never silently drops it.

Each row names **exactly one primary Part VIII owner slice** (J-120–J-136) that executes its delta, or **NONE** where the row is REFUSED/HAVE and only the J-136 gate restates it. A row whose delta has no owner anywhere in Part VIII is not smoothed over: it is filed as an ownership gap in §5.

**Pass rule for this slice.** `docs/janas/j119_inspect.py` mechanically re-derives every load-bearing claim in the table from this tree and the Part I records (row presence in the census/Concordance, absence scans, dispatch membership, module presence, the table's own tallies). The slice files its output (`j119_inspect_output.txt`); every FAIL must be disposed in §6, never hidden. Tallies in §1 are counted from the filed table by the inspect script, not by hand.

**Honesty classes.** This is a census slice: every verdict is **PROVEN from the tree** in the inspection sense (source read first-hand + mechanically re-checked), and nothing here grades a live run or a live conversion. No number in this doc is a wall, a rate, or a latency.

**Carried item (re-cited, not this slice's scope).** `cli/repl.mojo`'s `read_line()` returns `String(buffer)` over a `List[Byte]` — the debug-representation idiom J-109 §7 measured as defective on this toolchain, re-cited by the J-118 gate doc §6 as the road's immediate next item for its own fix slice with tests. It is re-cited in §6 of this doc so it is not lost; it is not a converter defect and is not fixed here.

**No README is touched. Hailo stays parked (no finish-line branch contact, no chip run or probe). No Docker. Nothing is deleted to free disk.**

*(§§1–7 are filed below from the census, under this protocol.)*

---

## 1. Headline — the converter delta in one breath

**11 reconciled converter rows: HAVE 0 · PARTIAL 3 · ABSENT 5 · REFUSED 3.**

The one-sentence finding: **Aesir has no conversion path at all — it has an import path.** Everything Aesir does with model files today is inbound reading of files that already exist in GGUF form (plus one pinned GGUF download leg). Nothing in the tree reads a Hugging Face checkpoint, nothing writes a GGUF, nothing merges an adapter, nothing extracts a prediction block, and no `convert` or `quantize` command exists in the CLI dispatch. The two tricks Part VIII wants from the Janas record — LoRA merge at conversion (J-120) and MTP preservation (J-121) — are therefore not deltas on an existing converter; each is a converter built from zero, standing on exactly three reusable pieces this census verified in the tree: the GGUF *reader* (`loader/gguf.mojo`, whose directory format the writer must mirror), the pinned/verified HF *download* machinery (`loader/huggingface.mojo`, whole-file today — J-121's shard-range fetch is new work on top of it), and the engine-side MTP *census/admission* layers (J-076/J-077) that already know how to find and label prediction-head tensors in a finished GGUF — the labelling J-121's output must satisfy.

The three PARTIAL rows are all read-side halves: the vision tower is *read* from an existing mmproj file but never *converted* from an HF checkpoint (C07); the model-file checker exists in user-facing pieces but not in the per-expert-checksum form (C09, mostly J-112's closed work — its Part VIII form is J-122's harness); IQ-family files are *read* and graded by the 204 road but cannot be *produced* (C11). The three REFUSED rows are the standing J-013/J-118 refusals, restated: `gguf2jns` (C01), `jns_planes` (C02), and the speech converters (C08).

**No defect in Aesir's code was found by this census** — the absences are unbuilt features, each refused-by-name or never claimed, not misbehaving code. One ownership gap in the *road* was found (§5): the vision converter's conversion half has no Part VIII owner slice.

---

## 2. The delta table — the exact per-row list Part VIII executes

Verdicts are per §0's pre-registered forms. Evidence is this tree's, at the branch tip; `j119_inspect.py` re-finds every load-bearing literal/scan (§6).

| ID | Converter row | Concordance | Verdict | Evidence (this tree) | Owner |
|---|---|---|---|---|---|
| C01 | `gguf2jns` — GGUF → `.jns` | 60 | REFUSED | Standing refusal (J-013, restated J-099 T24 and the J-118 gate): its output is the `.jns` format (row 66, refused); Aesir reads GGUF natively — there is nothing to convert *to* | NONE — J-136 restates |
| C02 | `jns_planes` — down-matrix bit planes | 66 (core) | REFUSED | A `.jns`-family artefact of the refused format; its transferable core (bit planes as a pressure lever) was graded on its own merits in Part I/II, not as a converter. No plane writer or reader exists in the tree, and none is wanted as conversion | NONE — J-136 restates |
| C03 | `hf2gguf` base conversion — HF safetensors → bf16 GGUF | 61 | ABSENT | No safetensors parser exists: the only safetensors text in the tree is `loader/exl2.mojo`'s explicit refusal boundary ("EXL2 byte parsing is not implemented… require validated… safetensors artifacts") and one EXL2 matrix helper in `core/external_quantization.mojo`. No GGUF writer exists anywhere (scan: no `GGUFWriter`/`write_gguf`/`gguf_write` in any `.mojo`). The dispatch has no `convert` arm. `loader/huggingface.mojo` downloads whole pinned GGUF files and contains no safetensors handling | J-120 |
| C04 | LoRA merge at conversion — PEFT adapter merged into base during `hf2gguf` | 61 | ABSENT | Tree-wide scan: **zero** hits for `lora` (case-insensitive) in any `.mojo` file under `aesir_engine/`. No adapter representation, no merge arithmetic (W + α/r·BA), no conversion point to merge at (C03). Janas's documented bar: merged weights verified bit-identical to an independent merge | J-120 |
| C05 | Post-conversion quantization — the `llama-quantize` leg of the documented pipeline | 61 (pipeline) | ABSENT | `loader/quantization.mojo` and the `core/*quantization*.mojo` family are read/inference-side type support (dequant kernels and descriptors); no command or module quantizes a model *file* — the dispatch has no `quantize` arm, and no GGUF writer exists to emit one (C03). A conversion pipeline that ships bf16 only must say so in its own slice | J-120 |
| C06 | `hf2jns_mtp` — MTP block extraction from the original checkpoint (range-fetched shards, or copied from a block-only GGUF minus embeddings/head), deterministic | 62 | ABSENT | No extraction exists: no shard/range fetch (`loader/huggingface.mojo` downloads one whole pinned file, resumable, sha-verified — no range requests), no tensor-copy path between files, no GGUF writer to emit a block file. The engine side is the opposite picture: `core/mtp_census.mojo` (J-076) classifies prediction-head tensors by name and `core/mtp_head_support.mojo` (J-077) admits them — in files that already carry them. J-121's output must be labelled so those two layers find it | J-121 |
| C07 | `hf2jns_vision` — vision tower from an HF checkpoint dir → engine vision file | 63 | PARTIAL | Read half HAVE: `loader/mmproj.mojo` reads an existing mmproj GGUF and finds the tower beside the model (`find_mmproj_beside`); the Gemma CUDA vision path is proven on existing files (Concordance row 63). Conversion half ABSENT: no HF-checkpoint tower read (no safetensors parser, C03) and no mmproj writer; `tests/encode_mmproj.mojo` is an encoder *proof* over existing weights, not a converter | NONE — gap G-119-1 (§5) |
| C08 | Speech converters — `hf2jns_whisper`, `silero2jns`, `wespeaker2jns` | 71 | REFUSED | Standing refusal with Concordance row 55 (the speech pipeline itself), restated at the J-118 gate: they exist only to feed a pipeline this road refuses; no speech model kind exists in the tree | NONE — J-136 restates |
| C09 | `jns_check` — model-file inspection with per-expert checksums | 64 | PARTIAL | User-facing pieces exist (`verify` rehashes catalog bytes, `doctor` diagnoses, `inspect` reports architecture/capabilities — J-099 T29, executed by J-112's services surface). Absent: a standalone per-tensor/per-expert checksum pass over one converted file — which is precisely the census-diff half of J-122's harness, so Part VIII's form of this row is owned there | J-122 |
| C10 | `janas-get --from-gguf` — fetch the original GGUF and convert locally to the same result | — (J-010/J-103) | ABSENT | The getting half landed in Part VII: `get`/`pull` download a pinned GGUF, sha-verified and resumable, with catalogue data (J-103). The local-convert leg does not exist because no converter exists (C03) — J-103's doc already assigned it here ("it belongs to the converter family (J-119 per J-099 §2)"). Once J-120 lands, this leg is a flag on it, not a new tool | J-120 |
| C11 | IQ1/IQ2 *conversion* — documented "not yet" beside proven IQ reading | — (J-010 tension) | PARTIAL | Read half HAVE: IQ-family kernels and files are read and graded (204 road crowns on IQ1_S/IQ2_M; `tests/test_iq1m_quantization.mojo`, `tests/test_iq4_quantization.mojo` in this tree). Production half ABSENT: no file writer of any quant type exists (C05). Aesir's position matches the documented Janas tension rather than resolving it; production of IQ files is not promised by any Part VIII slice and files as a J-131 refusal-ledger candidate if still true at the gate | J-131 (ledger) |

---

## 3. The handoffs — exactly what J-120, J-121 and J-122 inherit

**J-120 — LoRA merge at conversion (from C03 + C04 + C05 + C10).** Build order implied by the census, each step an absence verified above: (1) a safetensors reader for an HF checkpoint dir (config + shard index + tensor data) — nothing reusable exists except `loader/exl2.mojo`'s refusal boundary, which names the requirement; (2) the LoRA merge arithmetic over the base tensors (adapter tensors by name, W + (α/r)·BA in bf16/f32 as the documented behaviour states), with the roadmap's own verification: merged weights checked against the unmerged pair computed the slow way; (3) a GGUF writer mirroring `loader/gguf.mojo`'s directory format (metadata byte-faithful where the format demands it), emitting the merged bf16 GGUF; (4) a scope decision on C05, stated in J-120's own doc: either a quantize leg or an explicit bf16-only scope — silence is not an option, per J-122's "no silent conversions"; (5) C10's `--from-gguf`-style leg is a flag on this converter once it exists, not separate work. Witness slice: J-128 grades the merged conversion end-to-end on a sha-pinned Llama-3-family file.

**J-121 — MTP preservation (from C06).** Two documented input forms, both absent: (a) extraction from the original checkpoint — J-120's safetensors reader plus *range-request* fetching of just the block's tensors (the documented 487 MB-instead-of-14 GB behaviour), which `loader/huggingface.mojo` does not do today (whole pinned file only) and which is new machinery, not a flag; (b) copy-as-is from a block-only GGUF (the unsloth `mtp-*.gguf` form, minus its embeddings/head) — a tensor-directory copy through the C03/J-120 GGUF writer. The output contract is already built and waiting: the emitted file's head tensors must classify under `core/mtp_census.mojo`'s pre-registered name rules (`nextn`/`mtp`/`assistant`) and admit under `core/mtp_head_support.mojo` (J-077) — J-121's acceptance test is the roadmap's: converted file and source checkpoint agree tensor-for-tensor in the census. Determinism (same input, same bytes) is a documented property of the Janas behaviour and is J-122's to verify, J-121's to keep.

**J-122 — Conversion verification harness (from C09 + all rows).** The harness grades every conversion J-120/J-121 (and any later Part VIII slice) performs: tensor census diff (source directory vs converted directory — the per-file checksum/census form C09 names as absent), a short teacher-forcing grade of converted vs reference under the road's raw-oracle discipline (teacher-forcing rank + logit gap, CPU-vs-CPU comparator, never `llama-cli --single-turn`), and the pair filed. Its inputs are exactly this census: any conversion whose behaviour is not in §2's table is an unowned conversion and must be reconciled before it ships.

---

## 4. Aesir's existing import path — the inventory the delta was measured against

For the record, what "existing conversion/import path" concretely is at this tip (all PROVEN from the tree, §6):

- **GGUF reading** — `loader/gguf.mojo` (header, metadata, tensor directory), `loader/packed_gguf.mojo`; the engine's one native format. Read-only: no writer symbol exists anywhere in the tree.
- **Model getting** — `pull`/`get` in the dispatch (`cli/commands.mojo`), via `loader/huggingface.mojo`'s `download_hf_model`: one whole GGUF file per pull, pinned by repo/filename/revision/sha256/size, resumable, verified, optionally catalog-registered (J-099 T10, J-102/J-103).
- **Vision reading** — `loader/mmproj.mojo`: an existing mmproj GGUF read and discovered beside its model; no authoring path.
- **Neighbouring formats, honestly bounded** — `loader/exl2.mojo` and `loader/onnx.mojo` are metadata parsers with explicit execution/refusal boundaries (`exl2`/`onnx` dispatch arms exist and refuse by name); neither converts anything into GGUF.
- **Quantization** — extensive read/inference-side type support (`loader/quantization.mojo`, `core/external_quantization.mojo`, `core/extreme_quantization.mojo`, `core/packed_quantization.mojo` and their tests); no file-level quantization.
- **Engine-side MTP** — census + admission (J-076/J-077) over GGUFs that already carry heads; J-076's filed census found no prediction head in any VM-readable wave file, so no Part VIII conversion has a local head-carrying witness until J-123/J-124's files land — J-121's tensor-for-tensor census agreement is therefore its first proof form, exactly as the roadmap states it.

---

## 5. Ownership gap

- **G-119-1 — the vision converter's conversion half (C07) has no Part VIII owner.** The roadmap's Part VIII list (J-120–J-136) names no slice that converts a vision tower from an HF checkpoint; J-127 (Gemma 4 E-variants) grades the E-variants and names their efficiency-feature *gaps*, which is the nearest home, and J-131's refusal ledger is the other honest destination (convert refused/named with its blocker). Filed here as the immediate next item for the keeper's disposition — extend J-127's scope, commission a slice, or route to J-131 — per the never-leave-a-bug rule applied to the roadmap itself. The read half is HAVE and unaffected.

---

## 6. Verification, defects, and the carried item

**Inspect.** `docs/janas/j119_inspect.py` re-derives the table's load-bearing claims from the tree and the Part I records: the J-010 converter names and Concordance grades in the campaign copies; the LoRA and GGUF-writer absence scans over every `.mojo`; dispatch membership (`pull`/`get` present, `convert`/`quantize` absent); loader module presence; the exl2 safetensors refusal; the HF loader's whole-file, safetensors-free shape; the MTP census/admission modules; the mmproj beside-model read; and this doc's own tallies counted from its table. Filed output: `docs/janas/j119_inspect_output.txt` — **TOTAL 38 PASS 38 FAIL 0** (run at the branch tip before banking; any FAIL would be disposed here, never hidden — there were none).

**Defects found.** None in Aesir's code. The census's absences are unbuilt, never-claimed features (several explicitly refused-by-name at their boundaries, e.g. `loader/exl2.mojo`). The one road-level defect is G-119-1 (§5), filed as the immediate next item for the keeper.

**Carried item (re-cited per the dispatch, not fixed in this slice).** `cli/repl.mojo`'s `read_line()` returns `String(buffer)` over a `List[Byte]` — the debug-representation idiom J-109 §7 measured as defective on this toolchain. The J-118 gate doc §6 records it as the road's immediate next item for its own fix slice with tests (it changes chat-adjacent behaviour; its live path is docstring-marked unsupported and no Part VII surface imports it). It is **not** a converter defect, is not conflated with this census's scope, and remains open for the keeper to commission.

**Environment incident (recorded honestly).** This run began under a VM-wide write failure on the home filesystem (`Disk quota exceeded`, os error 122, on every write under `~/workspace` while `/tmp` stayed writable and the filesystem reported 39 GB free — the same transient interdict class this road recorded in J-025 and J-032). The fresh worktree's first checkout was interrupted by it mid-flight; the census inventory was therefore gathered read-only from the J-118 worktree (identical tree content at the same tip `afc20e7e`), the artefacts were drafted in `/tmp`, and the worktree was completed and all banking performed only after writes recovered, with the inspect run against the J-119 worktree itself before banking. Nothing was deleted to free disk, per the bound.

---

## 7. Banking

Branch `yrsa/janas-j119` from `yrsa/janas-j118` tip `afc20e7e5c938806c04a7546a966e36eb18ab964`, fresh sparse worktree `~/workspace/aesir-janas-j119` (`aesir_engine/` + `docs/janas/`). Commits: (1) this doc's §0 protocol, committed and pushed first, ls-remote verified before the census table was filed; (2) the full doc + `j119_inspect.py` + `j119_inspect_output.txt`. Push by explicit refspec; `git ls-remote` verified remote `yrsa/janas-j119` == local HEAD, with `yrsa/janas-j118` and origin/main unchanged at their dispatch-time hashes. Campaign copies (this doc, the inspect script, its output) sha-identical in `~/workspace/model-tests/janas/`. No README touched. Hailo untouched/parked.
