# J-116 — The Yggdrasil Binding

**Slice:** J-116 (Part VII — The Tool Family, J-099–J-118), Project Aesir Janas clean-room road.
**Roadmap text:** "The Yggdrasil binding. Yggdrasil's Aesir adapter (its own road's Y-024) re-proven against this road's new surfaces (placement options, streaming, drafts) so the mesh inherits them by configuration, not by fork."
**Next slice (read before starting, not executed here):** J-117 — "Examples that run. Two worked examples in Janas's spirit, Aesir's stack: a chat-in-a-web-page against the server, and a program embedding the engine; both executed in their own verification, not just written." Then J-118, the Part VII gate, where this slice's deferred legs are re-cited.
**Base:** branch `yrsa/janas-j116` in fresh worktree `~/workspace/aesir-janas-j116`, from `yrsa/janas-j115` tip `640d64794368f01cf1befd528997deb76ab39e58` (duplicate guard verified first-hand at slice start: no `~/workspace/aesir-janas-j116` worktree, no local and no remote `yrsa/janas-j116` branch, no live J-116 process existed — the prior tick's "dispatched" record had no effect on disk; `git ls-remote` showed `yrsa/janas-j115` at that hash and origin/main at `4ca75cc237de872a7e69777872ec1077f9e93e92`, neither touched by this slice's pushes).
**Worktree shape (environment adaptation, recorded honestly):** a cone sparse checkout failed twice with `Disk quota exceeded` — the cone pattern writes the repo's root files (~73 MB of root documents and images) before it reaches `aesir_engine/`, and the workspace quota (the filesystem itself reports 39 GB free; ~100 prior slice worktrees stand on the quota) has no room for them. Nothing was deleted to free disk, per the road's law. The worktree instead carries a **no-cone sparse checkout of `aesir_engine/` only (8.8 MB)** — every file this slice reads in-tree, writes, or tests lives under `aesir_engine/`; the sparse state is a checkout shape, not a content change, and `git status` is clean.
**Builds on:** J-115's library surface audit, whose §6 is this slice's handoff record and checklist (its can/cannot record is re-derived here against the current tree, never copied); J-107 (server streaming + prefill progress frames); J-036/J-049 (placement grammar + the `core/server_placement.mojo` parity layer); Part V (drafts; J-083's `core/draft_config.mojo`); Part II (expert streaming, CLI/CPU door); J-109/J-112 (MCP services); J-111 (code completion / FIM, OpenAI shape); J-114 (constrained generation, OpenAI-shape `vocab_restriction` field). The adapter under proof is Yggdrasil's `src/yggdrasil/aesir_adapter.py` (its own road's Y-024) in `~/workspace/yggdrasil-build` — read for this slice as the standing consumer's contract.
**Clean-room record:** no Janas material of any kind is needed or consulted in this slice; the question is entirely between Aesir's own surfaces and Yggdrasil's own adapter. No Janas source code was opened, in this slice or any other.

---

## 0. Protocol (committed first, before the re-proof was run)

This section was committed and push-verified before the inspect script was written or run. It states the first item (the progress-frame friction, with its disposition rule pre-registered), the re-proof questions, the evidence method, the verdict rules, and what is deferred and why. Everything after §0 is filed under these rules and no others.

### 0.1 First item — the J-107 progress-frame friction (J-115 §6, never-leave-a-bug)

**The discovery, as filed by J-115 and re-verified by this slice before any disposition:** on a *streamed* native generate over a watched (long) prompt, Aesir's serve sends J-107 prefill-progress frames — `{"event":"prefill_progress",...}` records rendered by `core/prompt_progress.mojo`'s `render_progress_event`, carrying **no `text` field** — ahead of the text records. Yggdrasil's adapter stream loop raises `engine_error` on *any* record that is not a dict with a text string. A designed-shape long-prompt stream would therefore be failed by the adapter. Short prompts emit zero frames (silent reads) and unstreamed generation are unaffected.

**Disposition rule (pre-registered):** the friction must come out *dispositioned with evidence*, in exactly one of these forms, chosen on the evidence of both trees:

- **(A) Fix in the adapter tree** — only if Yggdrasil's tree is clean, free of live workers, and its own campaign state assigns no live slice to its working tree. The fix form: the adapter's stream loop skips records carrying an `event` field (progress records) instead of raising on them, proven by the adapter's own test suite plus a new test feeding the real frame shape.
- **(B) Adapter contract version advance** — the adapter's matrix/contract documents the progress records as a named, skippable record class. Same writability precondition as (A); without it, (B) cannot land from this slice either.
- **(C) Aesir-side proof + filed recipe, DEFERRED-WITH-REASON** — if the adapter tree is not safely writable from this slice: (i) an Aesir-side contract proof that the serve's streamed native shape is exactly {zero or more progress records} → {text records} → {exactly one terminal record}, derived from the serve/progress sources; (ii) a runnable adapter-shaped replica client proof — a faithful re-implementation of the adapter's stream loop (its record rule copied in behaviour, cited line-for-line in the replica's header) — demonstrating the failure on the real frame shape today, and demonstrating that the filed adapter-side change (skip `event` records) consumes the same stream to a correct terminal result; (iii) the exact adapter-side change filed as a recipe (the precise loop change + the test Yggdrasil's own suite should gain), recorded DEFERRED-WITH-REASON and re-cited to the **J-118 gate**, which must carry it as an open item until Yggdrasil's own road lands it.

Whichever form lands, the evidence must run against the **real frame shape** (the renderer's own field set, re-derived from `core/prompt_progress.mojo`, not a paraphrase) and the **real adapter contract** (the adapter source read first-hand in this slice). A bare note is a failure of this slice under the never-leave-a-bug law.

### 0.2 The re-proof questions

For each surface in J-115 §6's can/cannot record, re-derived against the CURRENT tree (which includes J-113/J-114/J-115's work):

1. **The four native routes** — `GET /health/live`, `GET /health/ready`, `GET /v1/models`, `POST /v1/generate` — still branched on by the live serve, in the shapes the adapter's matrix states?
2. **The generate whitelist** — the adapter's 9 option fields still exactly equal to the native parser's accepted field set (parser additionally taking `prompt` and `stream`)?
3. **The resident-model rule** — only the resident model may generate, still the serve's and the adapter's shared rule?
4. **Stream terminal contents** — the terminal record still carries the service timings (`timings_ms` prefill/decode), `model_digest`, and token counts the adapter reads?
5. **The cannot-consume set, each re-verified:** placement (J-036/J-049), draft configuration (J-083), expert streaming (Part II), constrained generation (J-114), code completion / FIM (J-111), the MCP services (J-109/J-112), and the embed/vision agreed refusals. For each: is the blocking fact still true in this tree, what is the exact missing wire, and which slice/gate owns it?
6. **The inheritance question (the roadmap's own words):** does the mesh inherit each new surface *by configuration, not by fork* — i.e., is there a field/route/door the adapter could consume with configuration alone — or is inheritance impossible today, and if so, exactly why?

### 0.3 Evidence method (from the trees, first-hand)

Every claim in §§1–6 is re-derived by `j116_inspect.py` from this tree at the base tip plus this slice's artefacts, and (read-only) from Yggdrasil's tree — never from prose, including J-115's, which the inspect treats as claims to check. The inspect:

- re-derives the progress frame's exact field set from `core/prompt_progress.mojo`'s renderer and the native framing in `core/stream_progress.mojo`, and confirms the serve's native branch sends progress frames on the streamed native generate (`cli/native_serve.mojo`);
- extracts the adapter's stream record rule from its source (the text-string requirement and the `engine_error` raise), its 4 routes, its 9-field whitelist, its resident-only enforcement, and its named embed/vision refusals;
- re-derives the native parser's accepted field set from `GenerateRequest` in `cli/native_serve.mojo` and compares it to the whitelist exactly;
- re-checks the cannot-consume set against the current tree: the placement layer's stated wiring state + the serve's flag handling + the absence of placement fields in the native parser; the draft layer's stated wiring state; the OpenAI-only doors of `vocab_restriction` (J-114) and FIM/suffix (J-111); the MCP tool table's door (the adapter speaking no MCP); the MoE door (CLI/CPU line only);
- runs the replica client proof (`j116_adapter_replica.py`): the adapter's stream loop behaviour, replicated faithfully, fed (a) a short-prompt stream (no progress frames) — expected to succeed today; (b) the real long-prompt stream shape (progress frames → text records → terminal record) — expected to raise `engine_error` under today's rule; (c) the same stream under the filed recipe's rule (skip `event` records) — expected to complete with the exact text, counts, digest, and timings of the terminal record;
- checks Yggdrasil tree writability as evidence (its `CAMPAIGN_STATE.md` live-slice record + `git status`), which decides §0.1's form;
- checks repo hygiene: the slice's diff is exactly its expected file set, no README is touched, no model file is present.

### 0.4 Verdict rules (pre-registered)

- **Honesty classes:** PROVEN / SIMULATED / MEASURED-INDICATIVE / NOT PROVEN, per the road's law. This is a re-proof slice: its numbers are tree counts and replica-run outcomes re-derived by the inspect, not performance figures; no tok/s, latency, or live-generation claim is made anywhere in it.
- **PROVEN (contract level)** requires the inspect to re-derive the claim from both trees' sources in this slice. A surface the adapter *could* consume by configuration alone, with both sides' sources agreeing, is PROVEN at contract level; its live leg (a running serve + the real adapter on hardware) is graded separately and is NOT PROVEN unless a filed proof ran it — this slice runs no live leg (§0.5), so live behaviour rests on the owning slices' and Yggdrasil's own filed proofs, cited, never re-claimed.
- **The replica is evidence about the adapter's rule, not about the adapter binary:** a replica PASS proves the *rule* fails/passes on the *shape*; it does not prove Yggdrasil's shipped code changed. The doc states this wherever the replica is cited.
- **Cannot-consume verdicts** must name the exact missing wire (the field, route, or door that does not exist) and the owning slice/gate — a verdict of "not consumable" without the missing wire named is incomplete.
- **Build rule:** no Aesir engine code is expected to change in this slice (the friction's fix, if form (A)/(B) is unavailable, lives in Yggdrasil's tree; the serve's frame shape is J-107's filed behaviour and is not this slice's to change unilaterally — changing the serve to stop sending designed progress frames would break J-107's own contract to fix another campaign's consumer). If the re-proof proves an Aesir-side defect *in Aesir's own terms* (a surface contradicting its own documented shape), it is fixed in scope with tests; a cross-tree disagreement where each side honours its own contract is dispositioned under §0.1, not "fixed" by bending either side silently.

### 0.5 Machine and coordination bounds

VM MemAvailable ~3.8 GB at dispatch — below the 5,500 MB inference gate: no inference, no live server, no compiled-module runs are attempted by this slice; the inspect and replica are Python text/tree audits and in-process simulations (the lightest check class, as at J-115). purplelongship is not used (the 204 road's S-104 is live there; yielded). One process at a time. Yggdrasil's tree is read-only unless §0.1 form (A)/(B)'s preconditions are proven — and its own campaign's live work is never stomped, dirtied, or raced.

---
