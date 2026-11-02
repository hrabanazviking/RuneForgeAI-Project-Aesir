# J-074 — Cross-Model Drafts

**Slice:** J-074 (Part V — Drafts: speculative decoding, J-071–J-086), Project Aesir Janas clean-room road.
**Roadmap text:** "Cross-model drafts. A small model drafts for a large one (`--draft` analogue): pairing rules (tokenizer identity required — verified, not assumed), the Qwen3-0.6B→4B pattern from Janas's docs as the first pair."
**Executed:** 2026-11-01, by the keeper's dispatched worker. **No model inference ran anywhere** — the live pairing leg is deferred with its exact recipe (§6), for the same stated reasons as J-073's deferred leg.
**Base:** worktree `~/workspace/aesir-janas-j074` on branch `yrsa/janas-j074`, from `yrsa/janas-j073` tip `452a2eb8` (verified by `git ls-remote` at slice start by the keeper; origin/main untouched at `605562f6`; no remote `yrsa/janas-j074` existed before this slice).
**Machine state (VM, stated for every number below):** KVM, 4 vCPU. MemAvailable ~1.24 GB at slice start — **far below the 5,500 MB inference gate at every moment**, so no VM inference was attempted; lightest compiles only, one at a time. purplelongship was **not used at all** — unreachable tonight (204 road: device offline, last seen 2026-11-01T02:07:13Z), and yielded to under the coordination law in any case.
**Clean-room record:** no Janas material was consulted in this slice beyond what the road already filed: the cross-model pattern and the first pair come from the J-006 census record (`~/workspace/model-tests/janas/CENSUS.md`, from Janas's public docs) and the roadmap text. No Janas source code was opened, in this slice or any other.

---

## 1. Verdict — and the rules, stated before building

**J-074 closes CLOSED-WITH-DEFERRED-LEG:** the pairing rules are built and proven as an account, the tokenizer-verification machinery is built and validated on real GGUF files on this VM, and the first pair is named and accounted at the honesty class its evidence supports. The live pairing leg (a real draft round from the pair) cannot run tonight (§6) and is deferred with its exact recipe, re-cited at the **J-086** gate.

- The mechanical half is built and proven: `core/cross_model_pairing.mojo` — tokenizer tables compared token-for-token over their full length; six pairing rules each refusing mechanically with a named reason, in stated order; the pair's k cap read from J-071's account, never restated; the pair's memory sized **once** through J-026's shared pool over the summed quantities. **10/10 test groups PASS** (§5). Neighbour suites rebuilt from this tree: identity **8/8**, loop **12/12**, verify **13/13**, pre-existing acceptance arithmetic **2/2** (§5).
- The verification machinery is validated on real files (§3): the wave's Qwen3-4B file's tokenizer fingerprint is pinned; identity **passes** for the same model across two quants; identity **refuses** — at a named index — for a same-vocab-size relative and for a different family. The machinery therefore demonstrably does the thing the rule requires: it verifies, it does not assume.
- **The first pair's verdict is split into its three honest classes (§4):** rules-admissible on paper (PROVEN as an account over the documented pattern), target-side tokenizer fingerprint PROVEN from the real file, pair tokenizer identity **NOT PROVEN** (the drafter file is not on this VM), live pairing **NOT PROVEN**.
- **No acceptance or speed claim is made anywhere in this doc** — acceptance measurement is J-075, and this account contains no acceptance statistic by construction.

**The pairing rules (pre-registered; the module header is their normative text).** A (drafter, target) pair is admissible only when all six hold; the first failure is the verdict's named reason:

1. **Files present** — both model files exist (`REFUSE_MISSING_FILE`).
2. **Known family pairing** — drafter and target are the same known architecture family, the census's documented cross-model form (`REFUSE_UNKNOWN_FAMILY_PAIRING` for cross-family or any unknown family).
3. **Materially smaller** — drafter resident bytes at most half the target's (`REFUSE_DRAFTER_NOT_SMALLER`; also covers drafter ≥ target). The documented first pair sits far inside the bound (≈0.6B against 4B parameters).
4. **Tokenizer identity, verified not assumed** — a comparison actually run over both files' tokenizer sections: same tokenizer-model string, same vocab length, every token equal at every index, merges equal at every index where both carry them (one-sided merges is itself a mismatch), equal BOS/EOS. No run → `REFUSE_TOKENIZER_UNVERIFIED`; a divergent run → `REFUSE_TOKENIZER_MISMATCH` with the first divergence index carried in the verdict.
5. **k inside the cross-model slot's cap** — 1..15, read from `plan_proposer(PROPOSER_CROSS_MODEL).max_k` (J-071), the draft-check band's cap (`REFUSE_K_OVER_CAP`).
6. **One budget for both models** — both sides' resident bytes, KV allowances, and scratch are summed and sized once through `plan_shared_cache_pool` (J-026, Part II/III accounting — OS headroom charged once for the process, exactly as that function exists to do); a summed reserve leaving no pool budget, or one below the one-token floor, refuses (`REFUSE_BUDGET_EXCEEDED`).

---

## 2. Inspection — what the tree holds, and why the live form cannot run tonight (PROVEN by inspection)

Re-verified first-hand on this tree (the inspection recount, §5, asserts each line):

- J-071's account (`core/speculative_verify.mojo`) states the cross-model slot exactly as this slice consumes it: `PROPOSER_CROSS_MODEL` in `SLOT_CROSS_MODEL`, `requires_tokenizer_match = True`, `carries_own_kv = True`, `max_k = 15` — with the requirement's verification expressly assigned to this slice ("tokenizer identity required and verified, J-074").
- J-072's loop (`core/speculative_loop.mojo`) dispatches the cross-model slot and rolls back the proposer's own KV beside the target's; nothing in the loop needed changing for pairing — pairing is the gate *before* a proposer may occupy the slot, which is this slice's module.
- **No proposer implementation, no verify-pass executor, and no session wiring exist** — unchanged from J-072/J-073: `require_draft_check_use()` still fails closed, the engine facade's `speculative_generate` still raises not-implemented, the loop and pairing modules are imported only by their own tests, and the MoE session carries no loop state. A live draft round therefore has nothing to run on, on any machine, tonight.
- Memory accounting to bind to exists and is used, not paralleled: J-018/J-026's `plan_shared_cache_pool` in `core/expert_cache.mojo` (one pool, summed quantities, headroom once).
- Local GGUF reality (this VM): the wave's Qwen3-4B files are present (`~/workspace/model-tests/wave/zen-4b-i1/`, seven quants); **no Qwen3-0.6B file exists on this VM** (the wave's 0.6B file lives on purplelongship, unreachable); vocab-only fixtures (`ggml-vocab-*.gguf`) and a Llama-family file (TinyLlama) are present and serve the machinery validation in §3.

---

## 3. Tokenizer identity, verified not assumed — the real-file evidence (PROVEN, VM)

**Tool:** `docs/janas/j074_tokenizer_probe.py` — reads only GGUF metadata (no tensor data), compares two files' tokenizer sections token-for-token over the full tables, and fingerprints a file's tokenizer section as the sha256 of a canonical serialization (model string, vocab length, every token, merges length, every merge, BOS/EOS). Full record: `docs/janas/j074_probe_output.txt`.

**File pins (sha256, computed this slice):**

| File | Role | sha256 |
|---|---|---|
| `zen-4b.i1-Q4_K_M.gguf` | Qwen3-4B wave file — the first pair's target side | `9190094f771de3d8ceb8051224e2742813b34bd35080713a9373011e303f1547` |
| `zen-4b.i1-Q6_K.gguf` | same model, other quant | `8b05ff93285f1447b5746c39179a2b9b337a1b70446249755761dac2d5660be4` |
| `ggml-vocab-qwen2.gguf` | vocab-only fixture, same-size relative | `44c2f46b715f585c6ab513970e8a006bfa5badd6108560054921cf598d154d8c` |
| `tinyllama.Q4_0.gguf` | Llama-family full file | `da3087fb14aede55fde6eb81a0e55e886810e43509ec82ecdc7aa5d62a03b556` |

**Target-side fingerprint (PROVEN from the real file):** the Qwen3-4B file's tokenizer is arch `qwen3`, tokenizer model `gpt2`, vocab **151,936**, merges **151,387**, BOS = EOS = **151643**, tokenizer-section sha256 `2e7e49d0c49e3cce1e5ecb05e2d99c77900a3364ad19ca4d20bbe7c2ebcdf80f`.

**Comparisons run (all four, full tables):**

| Pair | Verdict | Evidence |
|---|---|---|
| Q4_K_M vs itself | **IDENTICAL** | first token divergence −1, first merge divergence −1 |
| Q4_K_M vs Q6_K (same model, cross-quant) | **IDENTICAL** | divergences −1 / −1 over 151,936 tokens and 151,387 merges |
| Q4_K_M vs `ggml-vocab-qwen2` | **REFUSED — mismatch** | first token divergence at index **151,646** — *same vocab length (151,936), same tokenizer-model string (`gpt2`), still not identical* |
| Q4_K_M vs TinyLlama | **REFUSED — mismatch** | first token divergence at index **0**; vocab 151,936 vs 32,000 |

The third row is the slice's load-bearing witness: vocabulary **size** equality plus the same tokenizer-model string plus family resemblance would pass any assumed check — and the tables still diverge. That is why rule 4 requires the run comparison and refuses the unverified pair even when a comparison in hand happens to be identical (§5, tokenizer-gate group).

**Probe-set statement:** the comparison's probe set is the entire vocabulary and merges, index by index — a superset of any text probe (any encoded text is a sequence of these indices under these merges). No weaker probe is accepted by the account.

---

## 4. The first pair, named and accounted — Qwen3-0.6B → Qwen3-4B

Per the roadmap and the J-006 census record (public docs): Janas's catalogue pairs Qwen3-4B ← Qwen3-0.6B automatically as its cross-model `--draft` pattern; the census records the pair as same-family, sharing the vocabulary, paying on dense (its published 1.14× is **Janas's number on Janas's machine** — a target to test at J-075/J-086, never quoted here as Aesir's). In Aesir's terms the pair files as: drafter Qwen3-0.6B in `SLOT_CROSS_MODEL` (own KV, k ≤ 15), target Qwen3-4B, both family `qwen3`.

Its verdict, at the three classes kept separate:

- **Rules-admissible on paper — PROVEN as an account.** Same known family (rule 2 ✓ on the documented pattern); materially smaller (rule 3 ✓ — 0.6B against 4B is far inside the half bound); k and budget rules are mechanical and were exercised on the pair's shape in §5's fixtures (stated scenario sizes, labelled as such — not measurements). Rules 1, 4, and the live half of 6 cannot be discharged on paper.
- **Target side, verified on files — PROVEN.** The target's tokenizer fingerprint is pinned from the real wave file (§3), and its file is present on this VM (rule 1, target half ✓).
- **Pair tokenizer identity — NOT PROVEN.** The drafter file is not on this VM; no comparison between the 0.6B and 4B tokenizer sections has been run by this road. The census's "sharing the vocabulary" is a documented claim about Janas's catalogue, **not** a verification — under rule 4 the pair, if proposed tonight from these two files' names alone, refuses `REFUSE_TOKENIZER_UNVERIFIED`, and if proposed with the drafter file absent, refuses `REFUSE_MISSING_FILE` first. The on-box recipe that discharges it is §6 step 2.
- **Live pairing — NOT PROVEN** (§6).

---

## 5. Tests (PROVEN, VM, lightest target)

Build route as filed in `docs/janas/j074_test_output.txt`: the tree's `thread_par.c` compiled with cc, then each suite built with the same pixi environment's Mojo 1.0.0 binary directly (`pixi run` remains blocked on this VM — the J-072-recorded activation failure — so the activation variables the tree's own activate script sets were exported and the env's binary invoked, exactly as J-071–J-073 filed). Full outputs in the test-evidence file; counts:

- **test_cross_model_pairing (J-074, new) — 10/10 groups PASS:** tokenizer identity exact over full fixture tables; a single differing token refused at its index; length divergence at the shorter length; merges mismatch / one-sided / both-absent handled as ruled; model/BOS/EOS inequality each breaking identity; an admissible pair with its k cap proven equal to J-071's cross-model cap (15) and its sizing proven identical to a direct `plan_shared_cache_pool` call over the summed quantities (OS headroom 3,200,000,000 charged once); missing-file refusals (either side); family refusals (cross-family, unknown) with a same-family Llama 3 pairing admitted; size refusals (equal, 60%) with exactly-half admitted; the tokenizer gate (unverified refused even with an identical comparison in hand; mismatch refused carrying divergence index 3, budget unreached); k refusals (0, 16) with k=15 admitted; and the starved-pool budget refusal from the sizing itself.
- **test_speculative_identity (J-073 neighbour, rebuilt from this tree) — 8/8 PASS** (7 long configurations, 2842 tokens, 797 rounds — the filed J-073 totals, reproduced).
- **test_speculative_loop (J-072 neighbour, rebuilt) — 12/12 PASS.**
- **test_speculative_verify (J-071 neighbour, rebuilt) — 13/13 PASS.**
- **test_speculative (pre-existing, rebuilt) — 2/2 PASS.**
- **Inspection recount** (`docs/janas/j074_inspect.py`, filed as `j074_inspect_output.txt`): every inspection, probe-record, and deferred-recipe claim in this doc as an assertion over the tree and the filed probe record.

**Own-build defect, fixed before filing:** the first compile of the new test failed on its fixture helpers — `List[String]` is not implicitly copyable, so the vocab/merges builders must return `.copy()` (the neighbouring suites' `List[Int]` fixtures never showed this). The helpers were corrected; every filed run is from the fixed tree, and the failed attempt produced no binary and no number.

---

## 6. NOT PROVEN — the live pairing leg, DEFERRED-WITH-REASON, with its exact recipe

- **Live cross-model pairing (Qwen3-0.6B drafting for Qwen3-4B, or any pair) — NOT PROVEN.** No cross-model draft round has run on any hardware. §5 proves the pairing gate over stated fixtures; §3 proves the verification machinery on real files; neither proves, and neither may be quoted as proving, that the pair drafts, that its tokenizer sections agree, or that it pays.
- **Why deferred, exactly:** (i) no proposer implementation, no verify-pass executor, and no session wiring exist (§2) — the leg has nothing to run on; (ii) the drafter file is not on this VM and purplelongship is unreachable tonight; the VM is below its inference gate in any case. All reasons stated; none is a verdict against the leg.
- **Dependencies, named honestly:** the wiring/executor gap named in J-073 §7 (no slice of their own yet in Part V); J-077/J-078 build sibling proposer forms; acceptance instrumentation is J-075.
- **The recipe (binding on the worker who runs the live leg):**
  1. **Machine and gap:** run on purplelongship in a guarded idle gap — check `ROADMAP_204_STATE.md`'s heartbeat first, yield to any live 204 run, one heavy run at a time, load and temperature stated. The VM may host a leg only behind MemAvailable > 5,500 MB at run time.
  2. **Re-pin, then probe, before any draft round:** re-pin both files by full sha256 (the target's VM-side pin is §3's `9190094f…1547` for the Q4_K_M file; the executing worker files the 0.6B file's pin from the box). A file whose pin does not verify does not run. Then run the tokenizer probe (`j074_tokenizer_probe.py`, or the host's extraction feeding `compare_tokenizers`) over **both files' full tokenizer sections** and file the comparison: the pair proceeds only on an identical comparison; a divergence files the pair REFUSED with its index, and no round runs "to see".
  3. **Pairing verdict on the real quantities:** `evaluate_pair` over the files' real resident/KV/scratch quantities (resident measured from each file's tensor directory, per J-018's discipline), k at the session's stated depth inside the cap, the pair charged through the verdict's single shared sizing. An inadmissible verdict ends the leg for that pair — it is filed, not worked around.
  4. **Rounds under J-073 §7's ids-first identity criterion:** plain greedy ids filed first; speculative ids over the same raw prompt (never template-rendered) compared by J-071's checker — token-for-token identity over the full stated generation length, divergence index −1, or the pair's rounds file DIVERGENT with the index and Part V reopens on that row at the gate. Every round's account filed per J-071's host contract step (6).
  5. **Acceptance is not this leg's to claim:** acceptance rates by text type are measured by J-075's permanent instrumentation; any wall taken here is MEASURED-INDICATIVE and grounds no speed claim.
- **Re-cite point:** the **J-086 Part V gate** re-cites this deferred leg with this recipe, beside J-073's. If the dependencies still do not exist at the gate, the gate records the live pairing claim NOT PROVEN again — it is not waived and not inherited from this slice's account-level proof.
- **Also NOT PROVEN here, for the record:** the 0.6B file's tokenizer fingerprint and resident bytes (no file on this VM); any other pair's admissibility on real files (only this pair is named by the roadmap; other same-family pairings are admitted by the rules when their own evidence is filed, and none was); the full counted suite (`run_all`) on this tree — not run, per the standing gate precedent; the standalone suites in §5 are the filed evidence.

---

## 7. Answered-locally / exclusions (clean-room)

- No Janas material was consulted; every design question was answered from Aesir's tree and the road's filed records, and is recorded here as answered-locally: (a) the materially-smaller bound (half the target's resident bytes) is Aesir's own stated threshold — the docs name the pattern, not a ratio; the documented pair passes any plausible bound by a wide margin, and the bound's job is refusing near-equal "drafters", stated in the module header; (b) the probe set is the full tables, not a text sample — Aesir's stricter reading of the roadmap's "token-for-token agreement on a stated probe set", stated in §3; (c) pair memory binds to J-026's shared pool rather than a new pairing-specific account, per the road's bind-don't-duplicate law; (d) merges one-sidedness is a mismatch — derived from the tokenizer forms Aesir's wave actually carries (BPE tables carry merges; SPM tables do not), and an SPM/BPE pair is not one tokenizer.
- **Stated exclusions from this slice's scope:** no proposer was implemented, no gate was lifted, no session was wired, no live run was attempted or simulated-as-live, no pair beyond the roadmap's first was named, and no prior slice's doc was edited. J-075 is not started here.

## 8. Banking

Filed on branch `yrsa/janas-j074` (worktree `~/workspace/aesir-janas-j074`, base `452a2eb8`): `docs/janas/J074_CROSS_MODEL_DRAFTS.md` (this doc), `docs/janas/j074_tokenizer_probe.py`, `docs/janas/j074_probe_output.txt`, `docs/janas/j074_inspect.py`, `docs/janas/j074_inspect_output.txt`, `docs/janas/j074_test_output.txt`; in the tree: `aesir_engine/core/cross_model_pairing.mojo` (new pairing account), `aesir_engine/tests/test_cross_model_pairing.mojo` (new suite, 10 groups). Campaign copies of the doc + evidence files in `~/workspace/model-tests/janas/`, sha-identical. Push by explicit refspec, foreground, with `git ls-remote` verification that the branch moved and origin/main stayed at `605562f6`; the commit hash and ls-remote lines are recorded in the campaign state entry for J-074 and the slice worker's report (a doc cannot contain its own commit hash). No README touched. Hailo untouched/parked. No Docker.
