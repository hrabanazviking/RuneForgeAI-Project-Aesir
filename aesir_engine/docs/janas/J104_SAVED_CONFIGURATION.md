# J-104 — Chat: Saved Configuration

**Slice:** J-104 (Part VII — The Tool Family, J-099–J-118), Project Aesir Janas clean-room road.
**Roadmap text:** "`/save-config` analogue: placement choices, draft settings, cache cap persist per user and are shown on demand; the learned file (J-044) and saved config reconciled as one story."
**Owns (J-099 census):** rows **T04 + T02's config trio** — "Built since J-012: `core/learned_file.mojo` (J-044, placement+thread choices persisted in Aesir's cache home), the draft section persisted through it (J-083, `core/draft_config.mojo`), `cli/native_settings.mojo` resolution with `--show-settings` preview. Absent: any `/save-config`-family command (tree-wide scan: none) and the one-story reconciliation of learned file vs saved config" (verdict at J-099: PARTIAL). This slice lands exactly the absent half: the `/save-config` command family and the one-story reconciliation. It does not rebuild the learned file, the draft surface, or the placement surface — it binds them.
**Base:** branch `yrsa/janas-j104` in fresh worktree `~/workspace/aesir-janas-j104`, from `yrsa/janas-j103` tip `dca5ec058fc57da6cbff067ebf6423fe08893e2d` (ls-remote verified at slice start: remote `yrsa/janas-j104` absent — the duplicate guard; remote `yrsa/janas-j103` == that hash). **Origin/main observation (recorded per dispatch, not acted on):** `origin/main` has moved to `4ca75cc237de872a7e69777872ec1077f9e93e92` (it stood at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5` in every prior filing on this road). This slice does **not** rebase onto it and does not touch main; the campaign chain continues from the j103 tip, as with every prior slice.
**Clean-room record:** no Janas material was consulted in this slice beyond the road's own already-filed clean-room records — the roadmap text, the J-099 census (rows T04/T02 and its §3 J-104 line), and the road's prior slice docs (J-036, J-044, J-047, J-083). No Janas source code was opened, in this slice or any other. Every design question those records do not answer is answered from Aesir's own architecture and recorded as answered-locally in §8.

---

## 0. Protocol (committed first, before any code was built)

This section was committed before the saved-config store, the command family, or any test existed. It states the store's shape and location, its field set, the one-story reconciliation rule, the slash-command surface, the refusal behaviour, and the verdict rule for the slice; everything after §0 is filed under these rules and no others.

### 0.1 What exists, and the exact delta

Re-verified first-hand in this tree at the base tip (the inspect script re-finds each fact):

- **The learned file exists and is not this slice's store.** `core/learned_file.mojo` (J-044, extended by J-083) persists *measured* placement + thread choices and one draft configuration per machine+model key, in Aesir's cache home (`learned_file_path()`: `AESIR_LEARNED_FILE` → `$AESIR_CACHE_HOME/learned-placement.v1` → `$HOME/.cache/aesir/learned-placement.v1` → `.aesir-cache/learned-placement.v1`), with MISSING / LOADED / REFUSED load honesty, atomic saves, whole-file and per-key erasure, and a show-on-request report.
- **The placement grammar exists.** `core/placement_options.mojo` (J-036) parses `--prompt-on` / `--drafts-on` / `--reply-on` values (`auto`, a single device, `a+b` co-work, a comma race list) with refusal-by-name; J-047 (`core/manual_override.mojo`) fixes the precedence **hand > preset > learned > auto** and the per-kind resolver.
- **The draft surface exists.** `core/draft_config.mojo` (J-083) resolves `--mtp` / `--no-mtp` / `--draft <model>` / `--draft-k` (cli > env > default, contradictions refused by name) and persists a validated configuration into the learned file's draft section. Its use gate stands (G-PROPOSER + G-EXECUTOR): a stored draft configuration records intent only.
- **The cache-cap grammar exists.** `core/expert_cache.mojo` (J-018) parses `--expert-cache-bytes` / `AESIR_EXPERT_CACHE_BYTES` via `parse_byte_size` and resolves flag-over-env via `resolve_hard_cap` (0 = unset). No per-user persisted home for a cap statement exists.
- **Absent (the delta):** any `/save-config`-family command anywhere in the tree, any per-user store for *explicit* statements (as opposed to measured ones), and any surface that tells the learned file and a saved config as one story.

### 0.2 The saved-config store — shape and location

- **A new pure module, `aesir_engine/core/saved_config.mojo`**, owns the store, following the tree's persisted-record pattern (the learned file's discipline: versioned human-readable line format, fixed field order, FNV-1a checksum over the whole body, atomic stage-fsync-rename saves, strict parse — any unknown, missing, reordered, or extra line is a refusal, so no field can smuggle itself in).
- **One record per user, not per key.** The learned file is keyed by machine+model because its contents are *measured on* a machine for a model shape. A saved config is a user's *statements*; it is keyed by nothing — it lives in the same cache home and applies on that machine for that user until changed or erased. The file name is `saved-config.v1`; the header is `AESIR_SAVED_CONFIG_V1`.
- **Path rule (the learned file's shape, its own env first):** `AESIR_SAVED_CONFIG_FILE` names the file itself and wins; else `$AESIR_CACHE_HOME/saved-config.v1`; else `$HOME/.cache/aesir/saved-config.v1`; else `.aesir-cache/saved-config.v1`. `resolve_saved_path()` is the pure, unit-tested form; `saved_config_path()` reads the live environment. An env set empty counts as unset (the learned file's rule).
- **Load honesty, the same three states:** MISSING (no file — the clean no-saved state, data, never an error), LOADED (parsed whole, checksum verified, every field validated), REFUSED (exists but corrupt / truncated / unknown version / oversized / unreadable — clean refusal with the reason, zero fields carried, file left untouched; storing into a REFUSED file raises rather than silently overwriting evidence of corruption).
- **An empty saved config is refused at save** (the learned file's rule for an entry that learns nothing): a config stating no field is not a config. Having no saved config is expressed by erasure, never by an empty file.

### 0.3 The field set — what a saved config may state

Exactly these fields, each independently present or absent (absent carries canonical empty values, validated as such):

- **Placement choices, per pass kind:** `prompt_on`, `drafts_on`, `reply_on` — each a J-036 placement value in canonical written form (validated by re-parsing with `parse_placement_value` for its kind and requiring the canonical rendering to round-trip, exactly as the learned file validates a learned choice's option provenance). This includes the pass-kind legality J-036 already enforces (the NPU is refused for drafts and reply at parse).
- **Draft settings:** one draft statement in J-083's vocabulary — source (`none` / `mtp-head` / `draft-model`), mtp state (`unset` / `on` / `off`), draft model file (`-` when none), and k — structurally validated by the same rules the learned file's `validate_draft` pins (canonical empties when absent; an mtp-head statement names no separate file and records mtp on; a draft-model statement must name its file; k within the J-071 draft-check band 1..15 when present). Contradictions J-083 refuses at its surface (two sources; mtp on beside a draft model) are refused here by construction of the same rules.
- **The cache cap:** `cache_cap_bytes`, a positive byte count. Its grammar at the command surface is J-018's `parse_byte_size` (plain bytes or a binary K/M/G suffix); 0 is not a statable cap (0 is `resolve_hard_cap`'s *unset* sentinel — stating "no cap" is done by clearing the field, never by saving 0).
- **A saved-at stamp** (unix seconds, the record's provenance; supplied by the host at save, from the learned file's clock read).

Nothing else may be stated. In particular: **no expert map** (J-027's measured rejection binds every persistence surface on this road), no sampling settings (the chat's `/set` owns those per session), no model choice (the picker's domain).

### 0.4 The one-story reconciliation — which store owns what

The two stores are two kinds of statement about the same session, and the story is told per field:

| Field | Saved config (explicit, hand) | Learned file (measured) | Effective rule |
|---|---|---|---|
| placement, per kind | the user's stated option for the kind | the chooser's measured choice + its option provenance, for the exact machine+model key | J-047's order (§0.5) |
| draft settings | the user's stated draft statement | the entry's J-083 draft section, for the exact key | saved (hand) over learned (measured); a session's own draft flags over both |
| cache cap | the user's stated cap — **the only store that owns this field** | no field exists (none may be added) | the saved cap, or unset |
| thread counts | not stated (a placement option fixes no thread count) | the measured choice's thread count, per kind | learned only, as J-044 states it |

- **Provenance on show.** The one-story report (`config_story_report`) renders, for every field above: the saved statement (or its absence), the learned statement for the caller's exact key (or the lookup's named non-apply outcome — machine mismatch, model mismatch, no entry, not loaded — never silently "nothing"), and the **effective** value with the layer that supplied it named (session hand / saved hand / preset / learned / auto-default). A field no layer states is shown as unstated, with the auto behaviour named. The report carries its standing sentences on its face: hand supremacy, learned values are defaults only, the two erasure paths are separate, and no expert map exists in either store.
- **Precedence per field (J-047, with the saved layer placed):** for a placement kind, the governing layer is the first that states the kind in this order — **(1) a session explicit option** (this session's `--prompt-on` etc., the freshest hand statement), **(2) the saved config** (a persisted hand statement), **(3) a `--mode` preset** (J-047's preset intent, where it fixes the kind), **(4) the learned choice** (measured, exact key only), **(5) auto** (measure at open). Placing the saved config in the hand layer — above preset — is this slice's answered-locally ruling (§8): J-047 ranks *hand* over preset without distinguishing a fresh hand statement from a persisted one, and a user's own saved words are a hand statement; within the hand layer the fresher statement (this session's) wins. The reconciliation function takes the session options, the preset mode, the saved load, and the learned lookup as inputs and returns the per-kind resolution; it imports no session and fakes no consumption.
- **The draft field** resolves in the same shape: session draft configuration > saved draft statement > learned draft section (exact key) > no draft configuration. The J-083 use gate is untouched by any of this: resolution states *intent and provenance*, and using a draft configuration still stands or falls at `require_draft_config_use()`.
- **Separate erase paths, stated on the report's face:** erasing the saved config (`erase_saved_config`, or `/save-config erase`) removes the saved file only — learned entries are untouched; erasing learned state is J-044's `erase_learned_file` / `erase_learned_entry` only — the saved config is untouched. Neither erase path calls the other, ever.
- **A REFUSED store never participates:** if either file loads REFUSED, the story reports that store as refused with its reason and resolves the field from the remaining layers; a refused store is never partially read and never silently treated as missing.

### 0.5 The slash-command surface — `/save-config`

Chat's slash dispatch lives in `cli/cuda_chat.mojo`'s `chat_control` (one per session type), as an if/elif chain over exact and prefix matches, refusing unknown commands by name. This slice adds the family **before** the existing `/save` branch in both `chat_control` bodies — a load-bearing ordering fact, recorded here: the existing `/save` branch matches by the prefix `/save`, so a `/save-config` command reaching it would be misread as a conversation save and refused with `/save`'s usage error; the config family must be matched first. (This is a trap in the existing dispatch shape, not a defect in `/save` itself; the fix is the ordering, in this slice's wiring, not a change to `/save`.)

The grammar (parsed purely by `parse_config_command` in the core module; the chat layer only executes the parsed action against the disk surface and emits the result):

- `/save-config` — show the one story (the §0.4 report for the session's key context the host supplies; in the chat wiring, the no-key form: both stores' states and the saved fields, with the learned side rendered from the file's own report — the wiring states plainly which form it shows).
- `/save-config <field> <value>` — state one field and save: fields `prompt-on`, `drafts-on`, `reply-on` (a J-036 value), `draft-source` (`mtp-head` / `draft-model` / `none`), `draft-mtp` (`on` / `off` / `unset`), `draft-model` (a file name, or `-` for none), `draft-k` (an unsigned decimal), `cache-cap` (a J-018 byte size). The assembled config is validated whole before it is written; an invalid assembled config refuses and nothing is saved.
- `/save-config clear <field>` — unstate one field and save (clearing the last stated field refuses with the reason: an empty config is not saved — erase instead).
- `/save-config erase` — erase the saved config file only (the §0.4 separate path), reporting the erasure outcome as data.
- `/save-config help` — the family's usage, field list, and the one-story summary in brief.

The chat help (`cli/chat_history.mojo`'s `chat_command_help`) gains the family in both its widths. No other slash command changes; `/save`, `/load`, `/export`, `/set` keep their exact current behaviour.

### 0.6 Refusal behaviour — by name, with the reason

Every refusal names the field and the reason, in the tree's established shapes (J-036/J-047/J-083): an unknown field, an unknown action, a missing value, a duplicated or extra token; a placement value J-036's grammar refuses (its reason carried verbatim); a draft value outside its vocabulary or band; a cache cap `parse_byte_size` refuses, or a stated cap of 0; an assembled configuration that fails whole-config validation (the contradiction named); clearing a field that is not stated; clearing the last stated field (erase instead); saving into a REFUSED saved file (erase it explicitly first). A refusal never writes anything: the file on disk after a refused command is byte-identical to the file before it.

### 0.7 Verdict rule for this slice (pre-registered)

The slice **passes** iff all of the following hold, each filed:

(a) **Store:** `test_saved_config` PASSes at the lightest target: serialise/parse round trip byte-identical; strict-parse refusals (unknown line, bad checksum, unknown version, non-canonical placement text, NPU-for-drafts placement, draft contradictions, cap 0, empty config at save); the pure path rule; disk surface (save / MISSING as the clean state / corrupt + truncated files REFUSED whole with reasons and left untouched / store-into-refused raises / whole-file erasure and its already-absent outcome).
(b) **Reconciliation:** the same suite PASSes the story rules: per-kind resolution across all five layers in §0.4's order (session hand > saved hand > preset > learned > auto), the learned side honouring the exact-key lookup outcomes by name, the draft field's order, the cache cap's single ownership, a REFUSED store reported and skipped (never partially read), and the report carrying its standing sentences.
(c) **Command family:** the same suite PASSes the parse + apply rules of §0.5/§0.6 — every action parsed, every refusal named, apply validating the assembled config whole, a refused apply writing nothing.
(d) **Wiring:** `cli/cuda_chat.mojo`'s two `chat_control` bodies match the config family before `/save`, and `chat_command_help` names it; proven by compiling a suite that imports `cli/cuda_chat` (the standing `test_cuda_chat_admission`, rebuilt from this tree) plus the inspect re-finding the branch order in both bodies. The live chat leg (a real CUDA session driven through `/save-config`) is **not** part of the pass rule: no CUDA device exists on this VM and the VM memory gate bars inference — it is filed DEFERRED-WITH-REASON with its exact recipe in §5, re-cited at the J-118 Part VII gate.
(e) **Neighbours:** the suites in this slice's import graph rebuilt from this tree PASS at their filed counts — `test_learned_file`, `test_draft_config`, `test_manual_override`, `test_placement_options`, `test_expert_cache`, `test_cuda_chat_admission`, plus the standing Part VII neighbours `test_model_get` 5/5, `test_chat_picker` 7/7, `test_machine_report` 6/6, `test_bench_configurations` 8/8, `test_placement_harness` 10/10, `test_thread_topology` 10/10. Any suite not rebuilt is named with its reason, never silently skipped.
(f) **Inspect:** `docs/janas/j104_inspect.py` re-derives every load-bearing claim in this doc from the tree and PASSes; every FAIL is disposed in the doc, never hidden.

**Honesty classes.** The store, reconciliation, and command logic are **PROVEN** by the unit suites and the inspect where they pass. The chat wiring's composition (branch order, the helper each body calls, the help text) is **PROVEN (inspection sense)** from the tree plus the admission suite's compilation of `cli/cuda_chat`. A live chat session exercising `/save-config` against a real model, and any session *consuming* a resolved configuration (placement/draft execution), are **NOT PROVEN** by this slice and are named in §9 — consumption remains the host surfaces' later work, exactly as J-036/J-044/J-047/J-083 each stated for their layers.

**No README is touched. Hailo stays parked (no finish-line branch contact, no chip run or probe). No Docker. Nothing is deleted to free disk.**

*(§§1–10 are filed below from the build, under this protocol.)*

---
