# J-036 — Placement Options

**Slice:** J-036 (Part III — Choosing What Runs Where, J-035–J-052), Project Aesir Janas clean-room road.
**Roadmap text:** "Aesir flags in Janas's shape, Aesir's words: `--prompt-on`, `--drafts-on`, `--reply-on`, each taking `auto` (default), a single device, `a+b` co-work, or a comma list to race; env equivalents (`AESIR_PROMPT_ON` etc.); `--no-gpu` / device kill switches. Parsing + refusal of impossible requests with reasons."
**Executed:** 2026-10-31 ~13:4x–13:5x EDT. **Closure shape: parsing / validation / storage only** — exactly the slice's scope. No placement is executed, no device is chosen, nothing was measured: auto-choice is J-038–J-042, co-work execution is J-043, and §7 names everything that remains NOT PROVEN.
**Base:** branch `yrsa/janas-j036` in fresh worktree `~/workspace/aesir-janas-j036`, from `yrsa/janas-j035` tip `9a0358ad2d8bda35c062bcbda0a8304cd6650670`. Origin/main untouched at `ba7ee09b6b4d09967b571f2f39714e9119dc3772` (ls-remote verified at slice start and at banking, §8).
**Coordination:** purplelongship untouched (the 204 road's S-098 live there); VM MemAvailable ~0.9 GB — far below the 5,500 MB inference gate; lightest compiles only, no inference anywhere.

---

## 1. Question and ground

**Question.** J-035 left Aesir with three named pass kinds and no mechanism underneath them (its gap G3: no token-count routing, no placement anywhere). What is the option surface through which a user states — and Aesir validates, stores, and reports — where each kind of pass should run, in Janas's documented shapes but Aesir's own words and rules?

**Ground, and only that ground.** The value forms, env equivalents, and kill switches are the J-003 census row (filed from Janas's public documentation): each of `--prompt-on` / `--drafts-on` / `--reply-on` takes `auto` (default), a single device (`cpu`/`gpu`/`npu`), `a+b` co-work, or a comma list the engine measures among; env equivalents `JANAS_PROMPT_ON` etc.; kill switches `--no-gpu`, `JANAS_GPU=0`, `JANAS_NPU=0`; the NPU refused for drafts/reply; a device the machine lacks likewise refused. The pass kinds and the two binding constraints are J-035's taxonomy (filed at `J035_PASS_TAXONOMY.md` in this tree): role-primary kinds, **G1 — no draft-check pass exists** (Part V J-071/J-072 own building it), **G3 — no token-count routing exists** (measurement/choice are J-038–J-042). The quality-tier family's place on this surface is the J-014 gate's adjustment A2 (§5). No Janas source was opened; nothing in this slice needed more than the filed census.

## 2. Where the code lives, and why

Inspection of this tree found three precedents, and the slice follows all three:

- **Value grammars live in `core/` as standalone modules.** `core/sampling_options.mojo` is "pure native sampling value grammar shared by CLI, sessions and protocols"; the Janas road's own planning modules (`core/expert_cache.mojo` J-018, `core/moe_gpu_plan.mojo` J-031) are deliberately standalone so later slices integrate a proven layer instead of designing one under load, with the host contract written in the module. → **New module `aesir_engine/core/placement_options.mojo`** (~700 lines, no device/OS calls except the env read), tests at **`aesir_engine/tests/test_placement_options.mojo`** as a standalone lightest-target suite in the `test_moe_gpu_plan.mojo` shape.
- **Raw option state is string + `*_was_set`.** `cli/options.mojo`'s `CLIOptions` keeps every option as a value beside a was-set flag; precedence is decided by the consumer, not the container. → `RawPlacementInputs` mirrors that shape exactly, one raw layer per source (argv scan, env read).
- **Env reading is the tree's own FFI shape.** `core/parallel.mojo`'s `_env_int` stages the name in a fixed buffer for `getenv`; `_env_str` in the new module is the same pattern returning the string.

**Wiring — minimal and honest.** The module exposes the entry point a surface calls at startup: `scan_placement_args(argv)` → `placement_env_inputs()` → `resolve_placement_options(cli, env)` (raises on the first refusal, with its reason) → `PlacementOptions.describe()` for the startup report. A comment block above `AesirEngine._prefill_batch_cap` in `aesir_engine/aesir.mojo` records this contract and the consumption gap at the engine's own prefill surface. **No session consumes a placement choice yet** — prompt and reply passes still run where their surfaces have always run them; claiming otherwise would fake an integration that does not exist. The consumption gap is this slice's named remainder, roaded to J-038+ (§7). The module is not registered in `tests/run_all.mojo`: per the J-031 precedent, registration rides with the counted run that exercises the full suite, which this VM's memory gate does not permit; the standalone suite is the filed evidence, and registration is a J-038 wiring step.

## 3. The grammar

Devices are Aesir's own words: `cpu`, `gpu`, `npu` (the tree's session vocabulary; the census's spellings agree). Spellings are exact and lower-case — a bad value is refused, never reinterpreted (the census's settings discipline, J-008 row, and this tree's strict value grammars agree).

| Form | Written as | Meaning (stored, not yet executed) |
|---|---|---|
| auto | `auto` — also the value when the option is unset | the engine measures and chooses (J-038–J-042); stored with source `default` when unset, or the supplying layer when written explicitly |
| single | `gpu` | that one device takes the pass (beside the CPU's standing role, §6) |
| co-work | `npu+gpu` | exactly two distinct devices work one pass together (execution: J-043) |
| race | `npu,gpu` / `cpu,gpu,npu` | two or three distinct devices; a later slice measures among them and keeps the fastest |

Whitespace around the whole value and around separators is trimmed; the stored form is canonical (`describe()` re-renders it, and the tests pin the canonical strings). Each option records its **source** — `cli`, `env`, or `default` — on the resolved struct.

**Precedence, stated once:** command line over environment over default, per option independently (a CLI prompt value does not shadow an env reply value). **Kill switches are not under precedence** (§4).

**Env equivalents:** `AESIR_PROMPT_ON`, `AESIR_DRAFTS_ON`, `AESIR_REPLY_ON`; quality fields `AESIR_QUALITY`, `AESIR_HEAD`, `AESIR_ATTENTION`, `AESIR_BITS` (§5); kill switches `AESIR_GPU`, `AESIR_NPU` (§4). An env var set to an empty value counts as set and is refused by the parser as an empty value — stated, never silent.

**Argv forms:** `--flag value` and `--flag=value` both parse. The scan ignores flags outside this surface's namespace (other surfaces own them) but refuses any flag that reaches into the namespace and misses (`--prompt-onn` → unknown option, with the surface's option list in the reason) — a typo'd placement flag must not become a silently unplaced run. The same option set twice is refused ("state it once"), a value flag with no following value is refused, and a value handed to a kill switch (`--no-gpu=1`) is refused.

## 4. Kill switches

`--no-gpu`, `--no-npu` on the command line; `AESIR_GPU=0` / `AESIR_NPU=0` in the environment (`=1` states explicitly that the device lives; any other value is refused at resolve time with the reason, even if nothing names the device — a bad switch value is never reinterpreted).

Semantics, all unit-tested:

- A kill from **any** source applies to **every** option. A placement — from either layer, in any form — that names a killed device is **refused**, and the reason names both the placement and the switch (`--prompt-on 'gpu' names gpu, which is killed by --no-gpu`).
- `auto` is never refused by a kill: its **effective field** shrinks. The resolved surface reports it (`[auto field: cpu, npu]` under `--no-gpu`), and the CPU always remains in the field, so `auto` always has a meaning.
- **`--no-cpu` is refused outright**: the CPU takes part in every pass (the census's standing role for Janas; for Aesir it is also the oracle line every grade stands on), so there is no CPU kill switch. This is Aesir's conscious shape, recorded here, not an omission.

## 5. The quality-tier family on this surface (Gate A2, honoured)

The J-014 gate ruled: *the quality-tier family (delta row 7: `--quality` tiers, head-requant lever, fast-attention lever) executes inside J-036's option surface — placement options and quality options are one surface in Janas and will be one surface in Aesir; the levers' agreement evidence is produced under J-091's ladder where context is involved.*

J-036's surface therefore **carries the family in full** — grammar, storage, precedence, and the use gate — in the same module, the same raw layers, the same `describe()` report:

| Field | Values | Default | Census ground |
|---|---|---|---|
| `--quality` / `AESIR_QUALITY` | `high` \| `medium` \| `low` | **`high`** (see below) | tiers: low = 4-bit expert reads where experts don't all fit + light-expert dropping under ⅕ cache; medium = 4-bit only; high = nothing lowered |
| `--head` / `AESIR_HEAD` | `4` (the only lever value; the native head is the option's absence) | native | `--head 4` requantizes a Q6_K output head to Q4_K at open |
| `--attention` / `AESIR_ATTENTION` | `fast` \| `exact` | `exact` | `--attention fast`: int16 query scores; Janas applies it automatically only above 16,384 context — Aesir stores the stated value only; auto-application is a measurement question for J-091's ladder, not a parse rule |
| `--bits` / `AESIR_BITS` | `2` \| `4` \| `6` (native read is the option's absence) | native | `--bits <2\|4\|6>`: bit-plane expert reads under memory pressure |

Two recorded decisions:

- **Aesir's default tier is `high`, Janas's documented default is `low` — a conscious difference.** Aesir's levers do not exist yet, and this road's discipline (J-017 D6, on the sibling dropping lever) is that a quality-lowering behaviour is never silent and never the default before its agreement cost is measured. A default of `low` on a surface whose levers are unbuilt would either silently change the function every faithfulness grade stands on, or silently do nothing; both are refused shapes. When J-091's ladder produces the agreement evidence, the default is re-openable on evidence.
- **Use fails closed, exactly like drafts (§6).** `require_quality_use()` passes only for `high` with no lever engaged — which is precisely Aesir's behaviour today — and raises with the reason for any lowered tier or engaged lever: the levers are not built, and their agreement evidence is produced under J-091. A stored `--quality medium` is therefore honest state, not a no-op pretending to be a tier.

The census's per-model *fast profiles* (catalogued lever combinations) are **not** part of this surface: they are catalogue data plus measured gains per model, owned by the catalogue/profile work (J-103's catalogue, J-046/J-091's measurements). This surface carries the levers those profiles will set. Recorded here so the boundary is explicit, per the gate's instruction to record exactly how the surface carries the family.

## 6. The two fail-closed use gates

**Drafts (binding from J-035 G1).** Aesir has no draft-check pass: no proposer, no verification batch, no KV rollback in any session; `core/speculative.mojo` is acceptance arithmetic that fails closed itself. `--drafts-on` therefore parses, validates (including the NPU refusal below), and stores exactly like the other two options — and `require_draft_check_use()` **raises, always**, naming G1 and its road (Part V J-071/J-072). A drafts placement is never silently ignored and never silently honoured; the stored value is what Part V will consume when the pass exists. The `describe()` report prints the gate on the drafts line itself, so no reader can mistake a stored drafts placement for a live one.

**NPU for draft-check and reply (the generalised refusal).** The census records that Janas leaves the NPU out of drafts/reply *with a warning* — i.e., it silently trims the named device and proceeds. The roadmap's J-047 names "the NPU-for-reply refusal pattern, generalised" as Aesir's intended shape. **Aesir refuses, whole value, at parse/validation**: `npu` in any form (single, co-work, race) for `--drafts-on` or `--reply-on` raises with the reason ("names the npu, which never takes a reply pass"). A named device is never dropped from a list so the rest can race — that is the same silent-ignore shape the drafts gate exists to prevent. For prompt passes the NPU is a first-class value in every form (the census's own `npu+gpu` example parses and stores). A hand choice's supremacy over presets (J-047's full subject) is untouched by this: the refusal is of an *impossible* request, stated with its reason, which is the roadmap's J-036 text itself.

**The CPU's standing role.** Janas's documents state the CPU takes part in every pass and devices are added beside it, never instead of it. Aesir's stored grammar adopts this as a reading rule, recorded here: a single/co-work/race value names the *added* placement; it does not evict the CPU from the pass. (What that means in execution is J-040–J-043's to build; the parse layer's only hard consequence today is the `--no-cpu` refusal, §4.)

## 7. Refusal table (all rows unit-tested)

| # | Request | Refused where | Reason (as raised, abridged) |
|---|---|---|---|
| 1 | `--prompt-on ""` | parse | "value must not be empty (auto, a device, a+b, or a,b)" |
| 2 | `--prompt-on tpu` / `GPU` | parse | "unknown device 'tpu' (devices are cpu, gpu, npu, spelled lower-case)" |
| 3 | `gpu+gpu` | parse | "names gpu twice; co-work needs two distinct devices" |
| 4 | `gpu+cpu+npu` | parse | "must name exactly two devices joined by '+'" |
| 5 | `gpu+` / `+gpu` | parse | "has an empty side; both sides must name a device" |
| 6 | `auto+gpu`, `auto,gpu` | parse | "names 'auto', which is a whole value, not a device" |
| 7 | `gpu,,cpu`, `gpu,` | parse | "has an empty entry; every entry must name a device" |
| 8 | `gpu,cpu,gpu` | parse | "names gpu twice; race candidates must be distinct" |
| 9 | `gpu+cpu,gpu` | parse | "mixes co-work '+' and race ','; write one form" |
| 10 | `--reply-on npu` (any form) | parse | "names the npu, which never takes a reply pass" |
| 11 | `--drafts-on npu+gpu` (any form) | parse | "names the npu, which never takes a drafts pass" |
| 12 | `--prompt-on gpu` with `--no-gpu` (either layer's kill) | resolve | "names gpu, which is killed by --no-gpu" / "by AESIR_GPU=0" |
| 13 | `AESIR_GPU=2` | resolve | "not a kill-switch value (0 kills the device, 1 does not)" |
| 14 | `--no-cpu` | scan | "the cpu takes part in every pass and cannot be killed" |
| 15 | `--no-gpu=1` | scan | "is a switch and takes no value" |
| 16 | `--prompt-on` with no following value | scan | "requires a value, but none follows it" |
| 17 | `--prompt-on` set twice | scan | "is set twice; state it once" |
| 18 | `--prompt-onn gpu` | scan | "unknown option '--prompt-onn' in the placement surface (options are …)" |
| 19 | using any drafts placement | use gate | "draft-check passes do not exist in Aesir yet (J-035 gap G1) … refused until Part V (J-071/J-072)" |
| 20 | `--quality ultra` | resolve | "is not a tier (tiers are high, medium, low)" |
| 21 | `--head 8`, `--bits 5`, `--attention medium` | resolve | "is not a lever value (…)" with the field's grammar |
| 22 | using `--quality medium\|low`, `--head 4`, `--attention fast`, `--bits 2\|4\|6` | use gate | "the quality levers are not built yet; their agreement evidence is produced under J-091's ladder" |

**Not refusals, by design:** a device the machine happens to lack is *not* refused here — this layer has no machine state, and inventing an inventory would fake J-037's subject. Placement against the real inventory is J-037 (device truth) meeting J-047 (invalid devices refused with the reason, at open). A parse that names a real device word on a machine without it stores honestly and is refused later, by the slice that owns the machine's truth, with that slice's reason.

## 8. Tests and banking

**Unit tests PROVEN (VM, lightest target):** `test_placement_options.mojo` built standalone (`mojo build -I . -I aesir_engine`, pixi Mojo 1.0.0) and run with the shell's `AESIR_*` placement/quality vars unset (the env-layer group sets its own via `setenv` and unsets them after): **10/10 groups PASS** — forms; grammar refusals; pass-kind legality; precedence cli > env > default with sources; kill switches (refusals, auto-field shrink, `AESIR_GPU=1`, bad-value refusal); drafts store + fail-closed use; quality surface (defaults, per-field precedence, use refusals, bad-value refusals); argv scan (both forms, duplicate, missing value, typo, `--no-cpu`, valued switch); env layer end-to-end (read → resolve → kill conflict → clean resolve); `describe()` report contents. **Neighbouring suite rebuilt from this tree: `test_moe_gpu_plan.mojo` 7/7 PASS** (the J-031 module this slice's shape follows). Full output filed as `j036_test_output.txt` beside this doc, sha-identical in the campaign copies. No inference ran; no other suite was rebuilt (memory gate), and none is claimed.

**Banking:** filed on `yrsa/janas-j036`: `aesir_engine/core/placement_options.mojo` (new), `aesir_engine/tests/test_placement_options.mojo` (new), the comment block in `aesir_engine/aesir.mojo`, this doc and `j036_test_output.txt` under `docs/janas/` — with sha-identical campaign copies of doc + test output in `~/workspace/model-tests/janas/`. Push by explicit refspec (`git push origin HEAD:refs/heads/yrsa/janas-j036`, foreground) with `git ls-remote` verification that the branch moved and origin/main stayed at `ba7ee09b`; the commit hash and ls-remote lines are recorded in the campaign state file entry for J-036 (a doc cannot contain its own commit hash). No README touched. Hailo untouched/parked. No Docker.

## 9. Answered-locally records (clean-room)

- **Q: Should Aesir copy Janas's warn-and-trim for the NPU in drafts/reply?** The census documents the behaviour (left out with a warning) but the roadmap's J-047 already names the refusal pattern as Aesir's intended shape. Answered locally (§6): refuse whole, with the reason — a named device is never silently dropped.
- **Q: What is Aesir's default quality tier?** Janas's documented default (`low`) cannot be checked against Aesir's unbuilt levers from the docs. Answered locally from Aesir's own discipline (§5): `high`, re-openable when J-091's agreement evidence exists.
- **Q: Is there a `--mode` preset surface (census: `--mode auto|eco|max`, hand choice holds over presets)?** Not built here. J-036's roadmap text does not name it; manual-override supremacy is J-047's named subject, and a preset layer without the measurement engine (J-038+) would be storage for its own sake. Recorded as J-047's to build or refuse; nothing in this surface blocks it (presets would resolve into these same raw layers, below CLI precedence).
- **Q: Env names for the quality fields and the `=1` kill-switch form?** The census names Janas's env kill switches (`JANAS_GPU=0`, `JANAS_NPU=0`) but no env names for quality fields. Answered locally by Aesir's own naming rule (`AESIR_` + the flag's name): `AESIR_QUALITY`, `AESIR_HEAD`, `AESIR_ATTENTION`, `AESIR_BITS`; and `AESIR_GPU=1`/`AESIR_NPU=1` accepted as the explicit not-killed statement, every other value refused.
- **Q: Duplicate flags and typo'd flags — last-wins, ignore, or refuse?** The census documents refusal discipline for Janas's config files (unknown words refused with the nearest match; bad values refused, never reinterpreted). Answered locally in that spirit, minus the nearest-match machinery (a chat-config feature, not an argv one): refuse both, with reasons (§3, table rows 17–18).

## 10. NOT PROVEN list

- **Any consumption of a placement choice.** No session places any pass by these options yet (J-038+ own wiring consumption; J-040–J-042 own choosing). The parsed surface is proven; its effect on any run is NOT PROVEN because no run uses it.
- **Any speed, wall, or tok/s consequence of any placement value.** Nothing was measured; the race form stores candidates only.
- **Co-work execution** (`a+b` as one split pass) — J-043. **Learned persistence of these choices** — J-044 (this surface's resolved struct is the shape it will persist; the file does not exist yet).
- **Device-inventory truth** (which named devices this machine actually has) — J-037; this layer refuses nothing on inventory grounds (§7 note).
- **The quality levers themselves** (head requant, fast attention, bit-plane reads) and their agreement costs — J-091's ladder; the tiers' behavioural content beyond the census's definitions is NOT PROVEN for Aesir.
- **Server-surface parity for these options** — J-049. The scan/resolve entry point is surface-agnostic by construction, but no server code calls it yet, and none is claimed.
- **The full counted suite (`run_all`) on this tree** — not run (memory gate); registration of the new suite in `run_all` is a J-038 wiring step (§2).

## 11. Defects

No defect in existing code was found by this slice: the inspection confirmed the precedents the design stands on behave as documented (`_env_int`'s unset/invalid → default contract, `forward_batched`'s sharded refusal and the speculative module's fail-closed raises, both re-read for §6). The new module's own first build needed no repair (the pixi env of a sibling worktree supplied the toolchain; the direct binary could not locate its stdlib outside the env — an environment fact, recorded here, not a tree defect). Nothing was noted-and-dropped: every gap found is an absence with a named owner in §10.
