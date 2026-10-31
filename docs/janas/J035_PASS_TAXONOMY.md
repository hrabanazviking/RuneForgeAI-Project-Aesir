# J-035 — The Pass Taxonomy in Aesir

**Slice:** J-035 (Part III — Choosing What Runs Where: placement and auto-configuration, J-035–J-052), Project Aesir Janas clean-room road.
**Roadmap text:** "The pass taxonomy in Aesir. Aesir's execution named in three pass kinds with measured token bands: prompt (batched prefill), draft-check (small batch verification), reply (single-token decode). Current Aesir behaviour per kind documented from the tree."
**Executed:** 2026-10-31 ~13:2x EDT. **Closure shape: tree-inspection / documentation only.** Every claim below is graded from first-hand reading of this tree; no inference ran (VM MemAvailable ~2.3 GB, below the 5,500 MB gate; purplelongship is owned by the 204 road's live work — untouched), and no code was changed. The reproducible inspection is filed as `j035_inspect.py` / `j035_inspect_output.txt` beside this doc.
**Base:** branch `yrsa/janas-j035` in fresh worktree `~/workspace/aesir-janas-j035`, from `yrsa/janas-j034` tip `71ef9b774eca2f27ba3847ef9a716da5151ac57c`. Origin/main untouched at `ba7ee09b6b4d09967b571f2f39714e9119dc3772` (ls-remote verified at slice start and at banking, §8).

---

## 1. Question and method

**Question.** Janas classifies every forward pass by width and places each kind separately (J-003 census): prompt passes ≥17 tokens, draft-check passes 2–16 tokens, reply passes 1 token. What are Aesir's three pass kinds *as built today* — which entry points execute them, at what widths, and where (if anywhere) does a token count decide which path runs?

**Method.** First-hand inspection of this tree's four generation surfaces and its one speculative module:

- the host engine — `aesir_engine/aesir.mojo` (`AesirEngine._run_generation`, `_forward_position`, `_forward_batch`, `_prefill_batch_cap`) over `aesir_engine/core/inference.mojo` (`forward_pass`, `forward_pass_batched`, and the Gemma 4 / Qwen3.5 single + batched twins);
- the native CUDA sessions — `core/llama3_cuda.mojo` (`Llama3CUDASession`) and `core/gemma4_cuda.mojo` (`Gemma4CUDASession`), the surfaces `cli/native_serve.mojo` serves;
- the streamed MoE session — `core/moe_session.mojo` (`MoEStreamSession`, Part II's vehicle);
- the speculative module — `core/speculative.mojo`, plus a wiring sweep for its importers.

A threshold sweep (`j035_inspect.py`) checked whether any token count routes execution anywhere in the engine. **No Janas material was needed or opened in this slice** — the census bands are taken from the filed J-003 census (`~/workspace/model-tests/janas/CENSUS.md`, J-003 row) and the roadmap's Part III intro; clean-room law unengaged beyond that.

## 2. The bands: Janas documented vs Aesir as-built

| Pass kind | Janas (documented, J-003 census) | Aesir as-built (this tree, PROVEN by inspection) |
|---|---|---|
| **prompt** | width ≥17 tokens, one placement option (`--prompt-on`) | **Role exists, width discipline does not match.** Host engine: prefill is chunked batched passes of width 2…256 (cap §3.1), falling back to width-1 passes when batching is disabled. Llama 3 CUDA: width-4 tiles where admitted, else width-1 passes. Gemma 4 CUDA: width-1 passes only. MoE session: width-1 passes only. No surface routes by a ≥17 threshold; a 3-token prompt and a 300-token prompt take the same code path, differing only in chunk count. |
| **draft-check** | width 2–16 tokens, one placement option (`--drafts-on`) | **Does not exist.** No session executes a multi-token verification pass. The only speculative code is acceptance arithmetic over caller-supplied probabilities (`core/speculative.mojo`), wired to nothing (§3.3); the engine's speculative entry point raises. There is no draft-check pass to place — this is Part III's named gap, owned by Part V. |
| **reply** | width 1 token, one placement option (`--reply-on`) | **Exists exactly, everywhere.** Every surface decodes one token per forward pass (§3.2). Width is always exactly 1; there is no multi-token decode anywhere in the tree. |

The one-line summary: **Aesir today has two of the three kinds — prompt and reply — and its prompt kind is executed at four different width disciplines depending on surface, while its draft-check kind is absent entirely.**

## 3. Per-kind as-built behaviour

### 3.1 Prompt passes (prefill)

**Host engine (`AesirEngine`, all dense archs).** `_run_generation` (`aesir.mojo:680`) owns prefill. With batching on, the prompt is consumed by `_forward_batch` (`aesir.mojo:481`) in chunks: every chunk but the last is a pure-prefill pass (`is_prefill=True` — fills KV, returns 0), and the final chunk (width = the remainder, 1…cap) also yields the first sampled token (`aesir.mojo:727–737`). The chunk cap is `_prefill_batch_cap` (`aesir.mojo:453`): `AESIR_PREFILL_BATCH`, **default 256**, further clamped by arena workspace (`min(cap, by_workspace)`); cap ≤1 disables batching. With batching disabled, prefill is a per-token loop of `_forward_position` (`aesir.mojo:388`) with `is_prefill=True` for all but the last prompt token (`aesir.mojo:738–743`). The docstring at `aesir.mojo:454–464` records the cap's provenance: S-033 evidence on purplelongship (a 213-token prompt; chunk 32→256 cut walls 9–14 % with bit-identical ids) — the only *measured* band fact in the tree, and it concerns chunk size, not a kind threshold.

Underneath, `core/inference.mojo` carries both shapes per architecture: `forward_pass` (width 1, `inference.mojo:1068`) and `forward_pass_batched` (width = chunk, `inference.mojo:1232`), with `TransformerBlock.forward` (`:281`) / `forward_batched` (`:639`), and the same pairing for Gemma 4 (`forward_pass_gemma4` `:1917` / `forward_pass_gemma4_batched` `:1984`, block twin `:1770`) and Qwen3.5 (`forward_pass_qwen35` `:2802` / `forward_pass_qwen35_batched` `:2725`, block twin `:2482`). Batched numerics are stated bit-identical to per-token passes in the `forward_pass_batched` docstring, with attention still computed per row under each row's own causal bound (`forward_batched` docstring, `inference.mojo:639`). One honest limit: `TransformerBlock.forward_batched` **raises** on the sharded multi-device body (`topology.num_devices > 1` — "sharded multi-device path is single-row only"), so batched prefill exists only on the single-device body.

**Llama 3 CUDA session.** `begin_turn` (`llama3_cuda.mojo:496`) prefills token by token through `forward(token, need_logits)` (`:387`), with one exception: when the session was admitted with `prefill_batch == 4` and at least 4 prompt tokens remain before the last, `prefill_four` (`:435`) consumes a **width-4 tile** — four embeddings, batched projections via `project_four`, per-token causal attention inside the tile (`llama3_cuda.mojo:554`; same branch in conversation restore, `:603`). Admission is narrow by design: `core/dense_buffers.mojo:17` (`effective_prefill_batch`) accepts only requested ∈ {0=auto, 1, 4}, and width 4 is admitted **only for the exercised Llama-3B profile** (hidden 3072, 28 layers); `cli/native_serve.mojo:666–667,724` enforces the same {1,4} set and the llama3-3B restriction at the server surface. So the CUDA line's prompt widths are exactly {1, 4}.

**Gemma 4 CUDA session.** `begin_turn` (`gemma4_cuda.mojo:287`) is a pure per-token loop: `pending_token = forward(tokens[i], i == len(tokens) − 1)` (`:332`, read raw — see §7 note) — width 1 for every prompt token, logits only on the last. **No batched or tiled prefill exists on this surface**, although the host engine's Gemma 4 path has one (§ above). This asymmetry is a named gap (§4, G2), roaded to Part IV (J-054/J-055), not a defect in what exists: the per-token path is the session's documented shape.

**MoE streamed session (Part II).** `MoEStreamSession` has exactly one forward entry, `step(token)` (`moe_session.mojo:552`) — width 1, greedy argmax, no sampling, no batched form. A prompt is therefore N width-1 passes driven by the host harness (the J-022/J-030 runs: 67 prompt tokens stepped one at a time; prefill 2.3894 tok/s vs decode 2.5563 tok/s MEASURED-INDICATIVE in J-030 — the near-equality of those two rates is exactly what width-1 prefill predicts). Prefill and decode are *the same pass shape* on this surface; only the caller's intent differs.

### 3.2 Reply passes (decode)

Width exactly 1 on every surface, with no exceptions found:

- Host engine: the generation loop in `_run_generation` evaluates exactly the newly generated token per step via `_forward_position` at its absolute position (`aesir.mojo:754` onward) — one position, one sampled successor.
- CUDA sessions: `next_chunk` advances one token per call via `forward(token, need_logits)` (`llama3_cuda.mojo:676`, `gemma4_cuda.mojo:451`).
- MoE session: `step` (§3.1) — the same width-1 pass serves as decode.

There is no speculative, batched, or multi-token decode anywhere in the tree (the sweep in `j035_inspect.py` finds no other generation entry point).

### 3.3 Draft-check passes — the gap, stated plainly

**Aesir has no draft-check pass.** The evidence, all PROVEN by inspection:

- `core/speculative.mojo` (142 lines) is acceptance *arithmetic only*. Its own header and `SpeculativeEngine` docstring state it "does not run a draft model, batch target verification, sample the residual correction distribution, or mutate KV caches." `evaluate_acceptance` computes the `min(1, p_target/p_draft)` prefix over caller-supplied probabilities; the three integration-shaped methods **fail closed**: `propose_draft_tokens` raises "draft proposal requires a real draft-model decoding loop" (`:118`), `verify_and_reconcile` raises "speculative reconciliation requires per-step normalized distributions, residual sampling, and KV coordination" (`:130`), `verify_tokens` raises "legacy speculative token verification is unsupported" (`:142`).
- Wiring sweep: outside the module and its tests, the only reference in the engine is `AesirEngine.speculative_generate` (`aesir.mojo:617`), a reserved facade that raises "speculative model generation and KV reconciliation are not implemented" (`:626`). No session — host, CUDA, or MoE — imports or calls `SpeculativeEngine`. (This confirms the J-014 concordance's record: "speculative acceptance arithmetic exists unintegrated.")
- The module's one width-like number is its own proposal bound: `num_draft_tokens` default **4**, valid range 1…64 (`speculative.mojo:47–74`) — a limit on the arithmetic's inputs, exercised only by `tests/test_speculative.mojo` and `tests/test_multi_engine.mojo`. It is not a pass, and no verification batch of any width is ever executed.

So under Janas's bands, Aesir's draft-check row is not "2–16, placed on X" — it is **absent**, and J-036's `--drafts-on` option (next slice) will parse against a kind that Part V (J-071/J-072) must first bring into existence. Recording that now, before the options are built, is this slice's main service to Part III.

## 4. Gaps named exactly

- **G1 — No draft-check pass exists** (§3.3). No proposer, no verification batch, no KV rollback in any session. Owner: Part V (J-071 verification-first design, J-072 draft loop); Part III's J-042 measures placement for this kind only once it exists, or records the deferral there.
- **G2 — Prompt width discipline is per-surface, not per-kind.** Host ≤256 chunks / CUDA tile 4 / Gemma-CUDA and MoE width 1. A prompt's cost shape today depends on which surface serves it, not on its length. Owners: Part IV (J-053 prefill anatomy, J-054 GPU block prefill, J-055 whole-layer dense GPU); J-036's options must therefore describe *role* placement, not assume a uniform prompt width.
- **G3 — No token-count routing anywhere.** The threshold sweep finds no place where a pass's width selects a path, a device, or a kind (the literal-17 hits are GGML quant type codes and an errno check — `j035_inspect_output.txt`). Janas's bands are, in Aesir today, a naming scheme with no mechanism underneath. Part III builds the mechanism (J-038 harness, J-040–J-042 auto choice).
- **G4 — Batched prefill is single-device only.** `TransformerBlock.forward_batched` refuses the sharded multi-device body (§3.1). Named here because Part III's co-work slices (J-043) meet it first.

**Defect check.** No defect in existing code was found by this inspection: every surface behaves as its own docstrings/contracts state (the batched-refusal and the speculative fail-closed raises are deliberate, documented behaviour). The gaps above are absences with named owners, not misbehaving code — per the road's rule, nothing here was "noted and dropped": each gap names the slice that owns it.

## 5. The taxonomy Aesir adopts for Part III

Aesir adopts Janas's three **names** — **prompt**, **draft-check**, **reply** — because J-036's option surface is specified in that shape and the names are honest. It does **not** adopt Janas's width-only band edges, because Aesir's own tree shows width alone misclassifies Aesir's real passes (a width-5 final prefill chunk is prompt work; a width-1 Gemma-CUDA prefill pass is prompt work at reply width). Aesir's taxonomy is **role first, width second**:

| Kind (adopted) | Definition (role) | Widths as built today | Width band for Part III reporting |
|---|---|---|---|
| **prompt** | Any pass (or pass sequence) whose job is to fill KV / recurrent state for prompt positions; only the final prompt pass may sample. | 1 (Gemma-CUDA, MoE, host fallback), 4 (Llama-CUDA tile), 2…256 (host chunks) | multi-token chunk: **≥2**; the kind also covers width-1 prefill sequences, reported as "prompt at width 1" so the inefficiency stays visible |
| **draft-check** | A pass whose job is to verify a proposed token sequence against the target model in one batch. | **none — does not exist (G1)** | **2…16** adopted as the design band (Janas's documented band; consistent with the arithmetic's default draft of 4 → verify width 5, well inside it; the module's hard limit is 64). To be re-measured when Part V builds the pass. |
| **reply** | A pass whose job is to advance generation by exactly one position and sample its successor. | exactly 1, all surfaces | **1** (identical to Janas) |

Justification, from Aesir's own tree rather than Janas's numbers: (a) the role split is the split Aesir's code already makes — `is_prefill` is a real flag with real behavioural difference (KV-fill-only, no sampling) in `forward_pass`/`forward_pass_batched`, while no width threshold exists anywhere (G3); (b) the prompt chunk cap of 256 and the CUDA tile of 4 are Aesir's measured/admitted widths (S-033 evidence; `dense_buffers.mojo` admission), so a ≥17 edge would slice through the middle of Aesir's most common prompt passes and classify identical work two ways depending on remainder size; (c) the draft-check band is the one place Janas's documented band is adopted outright, because Aesir has no as-built width to measure yet and the band must exist before J-036 can parse `--drafts-on` — it is adopted as a *design* band and labelled as such, not as an Aesir measurement.

## 6. Answered-locally records (clean-room)

- **Q: Should Aesir copy Janas's 17 / 2–16 / 1 edges?** The Janas docs (as censused) state the bands but not a derivation Aesir could re-check without opening source — which the clean-room law forbids. Answered locally from Aesir's tree (§5): role-primary taxonomy; Janas's edges kept only where Aesir has no width of its own (draft-check, as a design band).
- **Q: Is Aesir's 256 chunk a "prompt band"?** Answered locally: no — it is a workspace/evidence-tuned chunk cap inside the prompt kind (§3.1), not a kind boundary; prompts shorter than the cap still execute as prompt passes.

## 7. NOT PROVEN list

- **Any speed, wall, or tok/s figure per pass kind on any surface.** This slice ran nothing (memory gate + coordination, header). J-030's MoE prefill/decode rates and the S-033 chunk note are prior slices' MEASURED-INDICATIVE records, cited as such, not re-measured here. Part III's own measurements belong to J-038–J-042 and Part IV's anatomy to J-053.
- **Batched-vs-per-token bit-identity on this tree state.** Stated in `forward_pass_batched`'s docstring and proven by earlier slices on earlier trees; not re-run here.
- **Whether a width-1 prompt sequence on the CUDA/MoE surfaces is slower per token than batched prefill on the same model/hardware** — strongly suggested by the shapes (§3.1) and by J-030's near-equal MoE prefill/decode rates, but no same-model head-to-head exists; NOT PROVEN, owned by J-053.
- **The draft-check design band (2…16) as an Aesir operating band** — adopted as design (§5); it becomes measurable only when Part V builds the pass.
- *Reading note:* two source lines cited above (`gemma4_cuda.mojo:332`, `llama3_cuda.mojo:559`) render truncated in ordinary tool output (a display-layer masking of the assignment); both were verified by raw codepoint readback during this slice and say exactly what §3 quotes.

## 8. Banking

Filed on branch `yrsa/janas-j035` (worktree `~/workspace/aesir-janas-j035`, base `71ef9b77`): this doc, `j035_inspect.py`, `j035_inspect_output.txt` — all under `docs/janas/`, with sha-identical campaign copies in `~/workspace/model-tests/janas/`. Push is by explicit refspec (`git push origin HEAD:refs/heads/yrsa/janas-j035`, foreground) with `git ls-remote` verification that the branch moved and origin/main stayed at `ba7ee09b6b4d09967b571f2f39714e9119dc3772`; the commit hash and ls-remote lines are recorded in the campaign state file entry for J-035 and in the slice worker's report (a doc cannot contain its own commit hash). No README touched. Hailo untouched/parked. No Docker. No Janas source opened.
