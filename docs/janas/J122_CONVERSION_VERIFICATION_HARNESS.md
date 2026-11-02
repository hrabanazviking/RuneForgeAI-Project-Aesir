# J-122 — Conversion Verification Harness

**Slice:** J-122 (Part VIII — Conversion and Model Breadth, J-119–J-136), Project Aesir Janas clean-room road.
**Roadmap text:** "Conversion verification harness. Every conversion this road performs gets: tensor census diff, a short teacher-forcing grade of converted vs reference, and the pair filed. No silent conversions."
**Governing handoff:** J-119 doc §3 (C09 → J-122): J-122 owns C09's per-file census form — census diff + teacher-forcing grade + filed pairs for every conversion. J-120 §9 and J-121 §2/§9 both name this slice as the grading harness their conversions were built to be graded by.
**Base:** branch `yrsa/janas-j121` tip `aa30d898ec9516b5b6013fa1b311b886b0b92705` (ls-remote verified by the keeper at dispatch and re-verified by this worker before the worktree was cut). Origin/main untouched at `4ca75cc237de872a7e69777872ec1077f9e93e92` — this branch line does not rebase onto it.
**Machine state (VM, stated for every claim):** MemAvailable ~2.8 GB at this worker's first check — below the 5,500 MB inference gate, so no inference runs and none is claimed; the harness and its tests are pure-stdlib Python (no compile leg at all). purplelongship is **not used at all** — owned by the 204 road's live S-104 under the coordination law (yielded; its state file was not needed because the default is non-use). The J-120/J-121 converted files the harness grades are regenerated with the staged J-121-tree binaries already on disk (`~/workspace/.verify-tmp/j121build/`), so no Mojo build is forced under the memory gate.
**Clean-room record:** no Janas material is consulted in this slice beyond the road's own already-filed clean-room records (J-119's census + handoff, J-120's converter protocol, J-121's preservation protocol). The harness is Aesir's own, built against Aesir's own converter's stated rules. No Janas source code is opened, in this slice or any other.

---

## 0. Protocol (committed first, before any harness code was built)

This section is committed and pushed (ls-remote verified) before the build (§§1+ are filed after, under these rules and no others).

### 0.1 The harness (one artefact, pure stdlib, no silent conversions)

One new artefact, `docs/janas/j122_harness.py` — pure Python stdlib, sharing no code with the converter (`core/lora_convert.mojo`) or with the per-slice verifiers (`j120_verify.py`, `j121_verify.py`), with its own implementations of the safetensors and GGUF formats. It takes one conversion pair and produces one filed pair record (JSON). Three modes, one per conversion shape this road has performed:

- `hf-gguf` — source = an HF safetensors checkpoint (plus, when the conversion merged an adapter, the adapter safetensors + `adapter_config.json`); converted = the emitted GGUF.
- `gguf-gguf` — source and converted are both GGUF (the C10 `--from-gguf` re-emission shape).
- `hf-gguf-subset-head` — source = an HF checkpoint; converted = a block-only GGUF whose expected census is exactly the source's prediction-head subset (the J-121 extraction shape).

Usage: `j122_harness.py <mode> --source <path> [--adapter <path> --adapter-config <path>] --converted <path> --out <record.json>`. Exit 0 iff the pair's verdict is PASS; any FAIL or REFUSED verdict exits 1 and names every reason. A pair that cannot be parsed at all is REFUSED by name (the parse failure stated), never traceback-silenced into a pass. Every conversion this road performs from this slice on is expected to be filed through this harness; a conversion with no filed pair record is, by this slice's rule, a silent conversion and not a completed conversion.

### 0.2 The census diff (what the record contains, per pair)

For each pair the record files: both files' sha256 and byte sizes; both censuses in full (per tensor: name, shape as stored, type as stored — safetensors dtype / GGUF ggml type number and name — and element count); the metadata census of the converted file (entry count, and the `aesir.mtp.*` label contents when present); and a diff entry for **every** source tensor and **every** converted tensor, each classified exactly one of:

- `merged` — an adapter-targeted tensor (hf-gguf with adapter only): its converted values must equal the slow-way merge (§0.3) element for element after the storage rule;
- `pass-through` — an ordinary mapped tensor: name mapped by J-120 §0.4's table (implemented here independently), values equal to the source after the storage rule (2-D → BF16 round-to-nearest-even; 1-D → F32 bit-exact);
- `labelled-head` — a prediction-head tensor (J-076's substring rules, first match nextn → mtp → assistant, implemented here independently): name carried **verbatim**, values after the storage rule, **and** the converted file's `aesir.mtp.head_tensors` metadata lists it (both labels of J-121 §0.3 must agree — name classification and metadata);
- `carried-verbatim` — a gguf-gguf tensor: same name, same GGUF dims, same ggml type, values bit-exact as stored (BF16 bit patterns compared as bits, F32 as bits). A head tensor in this mode must additionally keep its metadata label, and is then classified `labelled-head` instead, so the label's survival is itself graded;
- `REFUSED-by-name` — a source tensor the conversion rules refuse: an HF name with no J-120 mapping and no head classification, or any converted tensor of a quantized ggml type (the C05 BF16-only scope, J-120 §0.4). Its presence in a pair — as an unexplained absence in the converted census, or as a quantized entry in it — makes the pair's verdict REFUSED, with the tensor named.

Difference entries that are not classifications but failures, each named in the record and fatal to the verdict: `missing-in-converted`, `extra-in-converted`, `shape-mismatch`, `type-mismatch`, `value-mismatch` (with the differing-element count and the first differing index), `label-mismatch` (metadata head label missing a census head, listing a non-head or absent name, or `head_count` disagreeing with the label list). Census order is part of the diff: the converted census must be the source census transformed in source order (subset mode: the head subsequence, in source order).

### 0.3 The grade (two legs, pre-registered, neither faked)

**(a) The synthetic-pair grade — element-exact agreement (executed in this slice).** For the synthetic pairs this road has produced, the honest grade is the census diff's own value agreement, stated as exactly that and never dressed as inference: per pair, total elements graded, differing elements (must be 0), and maximum absolute difference (must be 0.0) — for `merged` tensors against the slow-way merge recomputed by this harness (LoRA convention of J-120 §0.3: `merged = W + (alpha/r) * B·A`, Float32 intermediates rounded at every step), for all other classes against the storage rule of §0.2. This is the grade the filed pair records carry, under the label `element-exact (synthetic pair grade)`.

**(b) The live teacher-forcing leg — defined exactly, DEFERRED-WITH-REASON in this slice.** For any conversion of a real, inference-capable file, the pair record must additionally carry a teacher-forcing grade of converted vs reference under the road's raw-oracle discipline, exactly: a short fixed raw prompt (no chat template, no BOS rendering beyond what the file's own tokenizer record states), teacher-forcing rank of the reference's chosen token + logit gap at every graded step, CPU engine vs CPU comparator only, near-tie band rank ≤2 with sub-logit gap = faithful; `llama-cli --single-turn` is never a comparator (it template-renders the prompt — a different input). **This leg does not run in this slice**, for reasons stated now, not discovered later: (i) the VM is below the 5,500 MB inference gate (MemAvailable ~2.8 GB at dispatch); (ii) purplelongship is yielded to the 204 road's live S-104; (iii) the only converted files in existence are the synthetic J-120/J-121 toys (vocab 8, hidden 8) — no teacher-forcing grade over them would grade anything real, and inventing one would violate the no-faked-grade rule. The leg is re-cited to **J-128** (the first real conversion witness: the sha-pinned Llama-3-family file, where the J-120 merged conversion is graded end-to-end — its pair record, filed through this harness, must carry the live leg's numbers) and to the **J-136 Part VIII gate**, which must not close Part VIII with the leg still unexercised on a real pair.

### 0.4 Refusals and failures (the harness must be loud)

The test suite (§0.6) must prove, on tampered copies of real pair files (never on the filed originals): (1) a **flipped element** in the converted file → FAIL, the tensor named, differing count 1; (2) a **missing tensor** (converted census short by one) → FAIL, the missing name stated as `missing-in-converted`; (3) a **mislabelled head** (the metadata `aesir.mtp.head_tensors` entry altered so label and census disagree) → FAIL as `label-mismatch`, the head named; (4) an **extra tensor** in the converted census → FAIL as `extra-in-converted`; (5) a source tensor with no mapping and no head classification absent from the converted file → verdict REFUSED-by-name, the tensor named (this is the harness catching a silent drop — the exact failure this slice exists to prevent). A harness run that prints a verdict must print it in the record and on stdout; there is no quiet mode.

### 0.5 The pairs (every conversion that exists, filed)

The harness is run over all four conversions this road has performed, and each pair record is filed (`docs/janas/j122_pair_records.json`, one record per pair, produced by `docs/janas/j122_run_pairs.py` driving the staged J-121-tree convert binaries + the J-120/J-121 fixture writers, exactly as those slices' own evidence chains ran):

- **P1 — J-120 LoRA merge:** HF base + adapter → `merged.gguf` (expect: 2 `merged`, 10 `pass-through`, census 12);
- **P2 — J-120 C10 re-emission:** `merged.gguf` → `remitted.gguf` (expect: 12 `carried-verbatim`, byte-identical files);
- **P3 — J-121 MTP conversion:** HF checkpoint → `converted.gguf` (expect: 12 `pass-through`, 4 `labelled-head`, census 16, metadata 21);
- **P4 — J-121 block extraction:** HF checkpoint → `block.gguf` in subset mode (expect: 4 `labelled-head`, census 4).

The regenerated converted files must first reproduce their slices' banked sha256 pins (J-120 `merged.gguf` `c26af51d…`; J-121 `converted.gguf` `730dadae…`, `block.gguf` `7f8f0070…`) — a regeneration that misses its pin fails the run before the harness grades anything, so no pair record ever rests on an unpinned file.

### 0.6 Test suite and neighbours (pre-registered)

New suite `docs/janas/j122_test_harness.py` (pure stdlib, the established Python-harness pattern of J-120/J-121 — no Mojo is involved in this slice's own artefact, so no Mojo target is built), groups in order: (1) P1 census classification exact (counts per class, names); (2) P1 grade exact (merged elements vs slow way, 0 diffs); (3) P3 census classification exact (labelled-head set + per-kind counts); (4) P4 subset census exact; (5) P2 carried-verbatim exact + byte identity; (6) negative — flipped element FAILs loudly (§0.4.1); (7) negative — missing tensor FAILs (§0.4.2); (8) negative — mislabelled head FAILs (§0.4.3); (9) negative — extra tensor FAILs (§0.4.4); (10) refusal — silently dropped unmapped tensor REFUSED-by-name (§0.4.5); (11) determinism — the harness re-run over P1/P3 reproduces the filed pair records byte-for-byte except no field (records carry no timestamps, by design, so this is a strict equality). Neighbours re-run as filed-output checks in the inspect: the J-120 and J-121 verify chains are re-executed by §0.5's regeneration (their pins are the gate), and their banked verdicts are re-cited, not re-claimed.

### 0.7 Inspect (the J-119–J-121 pattern)

`docs/janas/j122_inspect.py` mechanically re-derives every load-bearing claim in this doc from the tree + the filed outputs (harness/test/record artefacts present, pair-record verdicts and class counts as filed, negative groups ALL PASS in the test output, doc honesty tokens, campaign copies sha-identical, no README touched). Campaign copies, sha-identical to the repo files, are filed in `~/workspace/model-tests/janas/`: this doc, `j122_harness.py`, `j122_run_pairs.py`, `j122_test_harness.py`, `j122_pair_records.json`, `j122_test_output.txt`, `j122_inspect.py`, `j122_inspect_output.txt`.

### 0.8 Carried items (re-cited, not this slice's scope)

- **`cli/repl.mojo` `read_line()`'s defective `String(List[Byte])` idiom** (discovery J-109 §7, re-cited J-118 gate §6, J-119 §6, J-120 §0.8/§10, J-121 §0.9/§10) remains the road's immediate next item for its own fix slice with tests. It is not a conversion defect and is not fixed here.
- **G-119-1** (vision HF-checkpoint conversion ABSENT, C07) and the **C05 ledger consequence** (the J-120 converter is BF16-only; file quantization unbuilt and refused by name) both stand routed to **J-131's** refusal ledger. Re-cited here so the routing is not lost; this harness *enforces* the C05 refusal (§0.2's quantized-type rule) but does not build the leg.
- **J-121's NOT PROVEN items stand as J-121 left them:** real (non-synthetic) MTP checkpoint conversion, adapter × MTP, inference on a converted head-carrying file, J-077's live drafter leg; range-request fetching DEFERRED-WITH-REASON to J-131 + the J-136 gate. This harness grades the synthetic pairs that exist; it does not promote any of those items.

**No README is touched. Hailo stays parked (no finish-line branch contact, no chip run or probe). No Docker. Nothing is deleted to free disk.**

*(§§1+ are filed below from the build, under this protocol.)*

---

## 1. Headline — what was built

The conversion verification harness C09 handed to this slice now exists and has graded every conversion this road has performed: one pure-stdlib artefact, `docs/janas/j122_harness.py`, taking a (source, converted) pair in three modes (`hf-gguf`, `gguf-gguf`, `hf-gguf-subset-head`) and producing a filed pair record containing the full census of both files, a **census diff** in which every tensor is classified `merged` / `pass-through` / `labelled-head` / `carried-verbatim` / `REFUSED-by-name` (protocol §0.2), and a **grade**. Run over all four existing conversions by `docs/janas/j122_run_pairs.py`, all four pairs **PASS** with the exact pre-registered classifications and element-exact grades (§4), after each regenerated converted file first reproduced its slice's banked sha256 pin. The test suite (`docs/janas/j122_test_harness.py`, **11 groups, 21 checks, ALL PASS**) proves the harness is loud where §0.4 demands: a flipped element, missing tensors, a mislabelled head, and extra tensors each FAIL with the tensor named, and a silently dropped unmapped tensor is REFUSED-by-name (§5). The live teacher-forcing leg is defined exactly in §0.3(b) and stands **DEFERRED-WITH-REASON**, re-cited to J-128 and the J-136 gate (§6) — no grade was faked and no number invented: the grades filed are the synthetic pairs' element-exact agreement, labelled as exactly that in every record.

## 2. Machine state and build

VM (KVM), no GPU device used. MemAvailable ~2.8 GB at dispatch — below the 5,500 MB inference gate at every observation; no inference ran anywhere and none is in scope. purplelongship was not used at all (owned by the 204 road's live S-104; yielded). The harness, pair runner, test suite and inspect are pure Python stdlib — **no compile leg exists in this slice**, so nothing was forced under the memory gate. The converted files were regenerated with the staged binaries built from the J-121 tree (`~/workspace/.verify-tmp/j121build/j120_convert`, `j121_convert`) driving the J-120/J-121 fixture writers, exactly as those slices' own evidence chains ran; all runs exit 0. Filed verbatim in `docs/janas/j122_test_output.txt`. No wall, rate, or latency number is in scope and none is claimed.

## 3. The harness as built (protocol §0.1–0.2, discharged)

`j122_harness.py` (independent implementations of both formats, the J-120 §0.4 name mapping, J-076's head rules, and the §0.3 slow-way merge — no code shared with the converter or the per-slice verifiers) emits, per pair: both files' sha256/bytes/full censuses (names, stored shapes, stored types, element counts), the converted file's metadata count and `aesir.mtp.*` label contents, one diff entry per tensor with its classification, the class counts, the grade block, the live-leg block (§6), and a verdict — `PASS`, `FAIL` (with every fatal difference named: `missing-in-converted`, `extra-in-converted`, `shape-mismatch`, `type-mismatch`, `value-mismatch` with differing count and first index, `label-mismatch`, `census-order-mismatch`), or `REFUSED` (REFUSED-by-name entries: an unmapped non-head source tensor absent from the converted census — the silent drop — or a quantized/unsupported ggml type under the C05 BF16-only scope). Census order is graded (the converted census must be the source census transformed in source order; subset mode: the head subsequence). An unparsable pair is REFUSED by name with the parse failure stated. Exit 0 iff PASS. Records carry no timestamps, so re-runs are byte-identical (proven, §5 group 11).

## 4. Pair verdicts (all four conversions that exist, filed in `j122_pair_records.json`)

| Pair | Conversion | Classes | Grade (element-exact, synthetic pair grade) | Verdict |
|---|---|---|---|---|
| P1 | J-120 LoRA merge: HF base + adapter → `merged.gguf` (sha256 `c26af51d…`, the banked pin) | merged 2 (`blk.0.attn_q.weight`, `blk.0.ffn_gate.weight`), pass-through 10; census 12 | 728 elements, 0 differing, max_abs_diff 0.0 — merged 192 elements vs this harness's slow-way merge | **PASS** |
| P2 | J-120 C10 re-emission: `merged.gguf` → `remitted.gguf` | carried-verbatim 12; census 12 | 728 elements, 0 differing, 0.0; source sha256 == converted sha256 (byte-identical) | **PASS** |
| P3 | J-121 MTP conversion: HF checkpoint → `converted.gguf` (sha256 `730dadae…`, the banked pin) | pass-through 12, labelled-head 4 (nextn 2 / mtp 1 / assistant 1, names in census order); census 16, metadata 21, label agrees | 936 elements, 0 differing, 0.0 | **PASS** |
| P4 | J-121 block extraction: HF checkpoint → `block.gguf` (sha256 `7f8f0070…`, the banked pin) | labelled-head 4; census 4 | 208 elements (the head elements), 0 differing, 0.0 | **PASS** |

Regeneration pins were checked before grading (run_pairs output, filed): `merged.gguf`, `converted.gguf`, `block.gguf` all reproduce their banked sha256 exactly from this tree — the J-120/J-121 neighbour chains therefore stand re-verified as this slice's gate, not merely re-cited.

## 5. Negative and refusal results (protocol §0.4, all proven on tampered copies)

`j122_test_harness.py` — 11 groups, 21 checks, ALL PASS, exit 0. Positive groups 1–5 re-derive §4's verdicts from the filed records (classifications, merged names, grades, label agreement, byte identity). Negative groups, each on a copy, never on a filed original: **(6) flipped element** — one byte flipped in the last tensor's data of a `merged.gguf` copy → FAIL, exit 1, differing count **exactly 1**, tensor named (`blk.0.ffn_down.weight`, `value-mismatch`); **(7) missing tensors** — the block file filed as the full J-121 conversion → FAIL, **12** `missing-in-converted` entries named; **(8) mislabelled head** — the metadata `aesir.mtp.head_tensors` occurrence of `model.mtp.fc.weight` altered in place (same length; census untouched) → FAIL as `label-mismatch`; **(9) extra tensors** — the full conversion filed as the block extraction → FAIL, **12** `extra-in-converted` entries named; **(10) silent drop** — a source checkpoint carrying `model.vision_tower.weight` (no mapping, no head classification) against a converted file that dropped it → verdict **REFUSED**, exit 1, the tensor named as REFUSED-by-name. Group 11 (determinism): direct harness re-runs over P1 and P3 reproduce the filed pair records exactly.

## 6. The live teacher-forcing leg (defined, DEFERRED-WITH-REASON)

Per §0.3(b): for a real, inference-capable conversion the pair record must additionally carry teacher-forcing rank + logit gap on the raw prompt, CPU vs CPU comparator, near-tie band rank ≤2 with sub-logit gap = faithful, never `llama-cli --single-turn`. **It did not run in this slice** — VM MemAvailable ~2.8 GB is below the 5,500 MB inference gate, purplelongship is yielded to the 204 road's live S-104, and the only converted files in existence are the synthetic vocab-8/hidden-8 toys, over which a teacher-forcing grade would grade nothing real. Every filed pair record carries the leg's definition, its deferred status and reason, and its re-citation: **J-128** (the first real conversion witness — its pair record, filed through this harness, must carry the live leg's numbers) and the **J-136 Part VIII gate** (which must not close Part VIII with the leg still unexercised on a real pair).

## 7. Defects found and fixed in-slice

None in pre-existing code, and none in this slice's filed artefacts: the harness, runner and suite passed as first written (pair run ALL PASS; suite 21/21). One working-method correction is recorded for honesty: the pair runner's first draft staged its per-pair temp records inside the worktree (`docs/janas/.j122_pair_tmp/`); the staging was moved to `~/workspace/.verify-tmp/j122pairtmp` before banking so the worktree carries only filed artefacts — no filed number was affected (the records are byte-identical either way, per group 11's strict-equality proof). The inspect script's fragility class recorded by the J-121 takeover (a missing campaign copy raising instead of FAILing) was avoided here by construction: copies are filed before the inspect runs, and the inspect's copy checks use existence-guarded comparisons.

## 8. Honesty ledger

**PROVEN** (runs actually executed on this VM, this slice): the harness exists in the §0.1 form (three modes, independent format/mapping/head/merge implementations); census diffs with the §0.2 classification over all four existing conversions, each regenerated file first reproducing its banked sha256 pin; the synthetic-pair grades exactly as filed (P1 728 / P2 728 / P3 936 / P4 208 elements, 0 differing, max_abs_diff 0.0 everywhere; P1's merged 192 elements against the harness's own slow-way merge); all five §0.4 loud cases (flipped element with differing count exactly 1 and the tensor named, missing, mislabelled head, extra, silent-drop REFUSED-by-name); determinism of the records (strict re-run equality). **NOT PROVEN**: any teacher-forcing grade of any converted file (the live leg, §6 — no inference ran; the synthetic toys cannot carry one honestly); the harness over any real (non-synthetic) conversion pair — J-128 is its first real witness; quantized converted files graded as anything but REFUSED-by-name (the C05 scope stands: quantization is unbuilt, and this harness enforces that refusal rather than grading around it). **DEFERRED-WITH-REASON**: the live teacher-forcing leg only (§6), re-cited to J-128 + the J-136 gate. No other leg is deferred.

## 9. Carried items (re-cited, not this slice's scope)

- **`cli/repl.mojo` `read_line()`'s defective `String(List[Byte])` idiom** (discovery J-109 §7, re-cited J-118 gate §6, J-119 §6, J-120 §0.8/§10, J-121 §0.9/§10, and §0.8 here) remains the road's immediate next item for its own fix slice with tests. It is not a conversion defect and is not fixed here.
- **G-119-1** (vision conversion C07 has no Part VIII owner) and the **C05 ledger consequence** (BF16-only converter, quantization refused by name) stand routed to **J-131's** refusal ledger, as §0.8 recorded. This harness enforces the C05 refusal (§3); it does not build the leg.
- **J-121's NOT PROVEN items stand as J-121 left them:** real (non-synthetic) MTP checkpoint conversion, adapter × MTP, inference on a converted head-carrying file, J-077's live drafter leg; range-request fetching DEFERRED-WITH-REASON to J-131 + the J-136 gate. J-122's live teacher-forcing leg (§6) joins the J-136 gate's re-cite list.

## 10. Banking

Branch `yrsa/janas-j122` from J-121 tip `aa30d898ec9516b5b6013fa1b311b886b0b92705`; protocol commit `3754494b0eec23203cf17ef8adac81cd6679efbb` (pushed, ls-remote verified before the build). The harness + runner + test suite + pair records + test output are banked on the same branch, and this doc's §§1+ and the inspect script/output are banked in the slice's closing commit. Campaign copies, sha-identical to the repo files, are filed in `~/workspace/model-tests/janas/` (this doc, `j122_harness.py`, `j122_run_pairs.py`, `j122_test_harness.py`, `j122_pair_records.json`, `j122_test_output.txt`, `j122_inspect.py`, `j122_inspect_output.txt`) and are re-derived mechanically by `j122_inspect.py`. Push is by explicit refspec with `git ls-remote` verification that the remote moved and origin/main is untouched (`4ca75cc237de872a7e69777872ec1077f9e93e92` at dispatch). **No README is touched. Hailo stayed parked. No Docker. Nothing was deleted to free disk.**
