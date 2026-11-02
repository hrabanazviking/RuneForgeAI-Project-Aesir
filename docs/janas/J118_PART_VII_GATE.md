# J-118 — Part VII Gate: Tool-Family Evidence Pack

**Slice:** J-118 (Part VII — The Tool Family, J-099–J-118), Project Aesir Janas clean-room road.
**Roadmap text:** "Part VII gate. Tool-family evidence pack: every tool behaviour demonstrated live, the refusal list restated with its reasons."
**Executed:** 2026-11-02 ~09:0x EST onward, in fresh worktree `~/workspace/aesir-janas-j118` on branch `yrsa/janas-j118`, from `yrsa/janas-j117` tip `570c9f060c530aa08c95b13ffa91e0a58b57cac6` (verified by `git ls-remote` at gate start; no remote `yrsa/janas-j118` and no j118 worktree existed before this slice — duplicate guard passed first-hand). Origin/main untouched at `4ca75cc237de872a7e69777872ec1077f9e93e92` (ls-remote verified at gate start). Worktree shape: no-cone sparse checkout of `aesir_engine/` + `docs/janas/` only (full checkouts hit `Disk quota exceeded`; ~100 prior worktrees stand; nothing deleted).
**Machine state (VM, stated for every number below):** MemAvailable ~3.5 GB at gate start — below the 5,500 MB inference gate at every moment. No model inference, no live server, no live generation ran anywhere in this gate; lightest text/inspect work only. purplelongship was not used — the 204 road's S-104 run owns it; yielded.

---

## 0. Gate protocol (committed first, before any re-verification run)

This section was committed before any gate evidence work, in the road's design-first shape (the J-098/J-086 gate pattern). It states what the gate re-verifies, the pass rules, and the verdict forms; the remaining sections are then filed from the runs, under these rules and no others.

**What the gate re-verifies (offline, from disk and from this tree only):**

1. **Branch chain.** Every Part VII branch tip J-099–J-117 is re-read by `git ls-remote` and must equal the tip its keeper closure recorded; consecutive tips must stand in ancestor order in this tree's history; origin/main must equal `4ca75cc237de872a7e69777872ec1077f9e93e92`.
2. **Filed inspect outputs.** Each slice's filed inspect output (J-099–J-117) is re-read: its summary must state ALL PASS with 0 FAIL, at the count its keeper closure recorded (92 / 42 / 63 / 56 / 75 / 53 / 47 / 38 / 30 / 39 / 65 / 49 / 61 / 109 / 52 / 62 / 42 / 36 / 29).
3. **Filed test outputs.** Each slice's filed test output is re-read for its ALL PASS verdict line(s); no tally is taken from prose.
4. **Campaign copies.** Every Part VII slice doc, inspect script, and inspect output in this tree must be sha256-identical to its campaign copy in `~/workspace/model-tests/janas/`. Location note, pre-registered: J-100–J-117 docs live under `aesir_engine/docs/janas/` in this tree; J-099's doc/inspect/output live under the root `docs/janas/` (its slice's filing); both locations are checked, the difference is recorded, not smoothed.
5. **Deferred legs.** Every deferred leg recorded in the keeper closures of J-100–J-117 (and in J-117 doc §7) is re-cited in the gate doc with its recipe pointer and its owning future gate/home. No deferral may be dropped, and none may be upgraded: a leg that was NOT PROVEN in its slice stays NOT PROVEN at this gate.
6. **The J-116 open item.** J-116's adapter-side progress-frame fix (Yggdrasil `aesir_adapter.py` stream loop skipping event records, recipe J-116 doc §1.3, re-cited J-117 doc §7.1) is carried as **OPEN**. This gate must NOT claim Part VII complete on that point, and must NOT claim the adapter consumes streamed generation over watched prompts. Nothing is written into Yggdrasil's tree.
7. **The J-099 ownership gaps.** G-099-1 (chat-side progress, J-059 W2), G-099-2 (non-config slash family), and G-099-3 (recap-summarised context sliding, T05 / Concordance row 38) each receive an explicit gate disposition on record (kept / refused / deferred-with-reason).
8. **The refusal list.** Every refusal filed in Part VII is restated with its reasons — at minimum: FreeBASIC REFUSED (J-115), NSM dressing REFUSED (J-113), C ABI DEFERRED (J-115), Node/TypeScript native DEFERRED (J-115), embed REFUSED where filed (J-109/J-112/J-115/J-116).

**Verdict forms (pre-registered):**

- **Gate verdict** is one of: Part VII CLOSED (no deferred leg survives), Part VII CLOSED-WITH-DEFERRED-LEGS (the offline evidence pack passes in full and every surviving leg is re-cited with its recipe), or Part VII NOT CLOSED (any pass rule above fails on a number, a suite, or a module — the failure is the headline).
- **Per-slice verdicts** restate each slice's own filed keeper-closure state (CLOSED / CLOSED-WITH-DEFERRED-LEG(S)) with its banked tip, verified against `git ls-remote` at this gate.
- **Honesty:** live legs that were NOT PROVEN in their slices stay NOT PROVEN at this gate — no live server, no live generation, and no facade compile on a GPU host was run at this gate. Numbers come only from filed outputs re-read at this gate and from `git ls-remote`.

**No Janas material is used at this gate** — it re-verifies Aesir's own filed Part VII evidence (clean-room law unengaged; no Janas source opened). No README is touched. Hailo stays parked (no finish-line branch contact, no chip run or probe). No Docker. Nothing is deleted to free disk.

*(The remaining sections are filed below from the gate runs, under this protocol.)*

---

## 1. Gate verdict

**Part VII CLOSED-WITH-DEFERRED-LEGS — with one OPEN cross-road item (§5 item 23) on which Part VII is expressly NOT complete.**

- All 19 Part VII slices (J-099–J-117) were re-verified from disk at this gate: branch tips by `git ls-remote`, filed inspect outputs re-read (1,040 PASS lines in total, 0 FAIL lines), filed test outputs re-read (every one carries ALL PASS), and slice docs / inspect scripts / inspect outputs / test outputs sha-compared against their campaign copies (§2).
- No live leg ran at this gate, and none is claimed. The roadmap's gate text asks for "every tool behaviour demonstrated live"; the honest record is that Part VII's behaviours were demonstrated in their owning slices in the strongest form each slice's machine bounds allowed (unit suites, real MCP client sessions, a real consumer session, headless execution of the example page's own script, a replica proof of the adapter friction), while every genuinely live leg — a running server, live generation, a live download, a GPU-host facade compile — was deferred-with-reason by its owning slice and is re-cited in §5 with its recipe. This gate does not upgrade any of them: **no live server, no live generation, and no facade compile on a GPU host was run, in the slices or at this gate; those legs stay NOT PROVEN.**
- The J-116 adapter-side progress-frame fix is **OPEN** (§5 item 23): this gate must NOT claim the adapter consumes streamed generation over watched prompts, and does not. Part VII is not complete on that point until Yggdrasil's own road lands the filed recipe.
- Counts: 19 slices — 4 CLOSED (J-099, J-112, J-115, J-116, each with its deferred legs or dispositions re-cited in §5 where its record files them), 15 CLOSED-WITH-DEFERRED-LEG(S). The deferred/open list in §5 has 26 items, each with its recipe pointer and owning future home.

No README touched. Hailo untouched/parked. No Docker. No Janas source opened.

## 2. Re-verification at the gate (PROVEN, offline sense)

Performed by `docs/janas/j118_inspect.py` from this gate tree (filed output: `j118_inspect_output.txt`; the test-output re-read is filed as `j118_test_output.txt`).

- Branch chain: `git ls-remote` at this gate shows every Part VII branch at exactly the tip its keeper closure recorded (table in §4), origin/main unchanged at `4ca75cc237de872a7e69777872ec1077f9e93e92`, and each tip is an ancestor of the next in this tree's history, with the J-117 tip an ancestor of the gate HEAD.
- Filed inspect outputs re-read, PASS-line counts exactly as filed, 0 FAIL lines in every file: J-099 92, J-100 42, J-101 63, J-102 56, J-103 75, J-104 53, J-105 47, J-106 38, J-107 30, J-108 39, J-109 65, J-110 49, J-111 61, J-112 109, J-113 52, J-114 62, J-115 42, J-116 36, J-117 29 — **1,040 checks in total**.
- Filed test outputs re-read: every Part VII test output (filed by J-100–J-114 and J-117; J-099 filed none — its inspect is its suite, as its doc states — and the audit/re-proof slices J-115/J-116 filed none, their evidence being their inspect outputs and, for J-116, its replica output) carries its ALL PASS verdict line(s), including J-109's client proof (27 OK, 0 FAIL), J-110's consumer proof (14 OK, 0 FAIL), J-112's client session (40 OK, 0 FAIL), and J-117's web check (20/20) and tier-2 embedding execution (ALL PASS, 3 groups).
- Campaign copies: every slice doc, inspect script, inspect output, and (where filed) test output in this tree is sha256-identical to its campaign copy in `~/workspace/model-tests/janas/`. Location difference recorded per the protocol: J-099's artefacts live under the root `docs/janas/` in this tree, J-100–J-117's under `aesir_engine/docs/janas/`; both locations were checked.
- The suites were not rebuilt at this gate: the gate's pre-registered method is re-derivation from the filed evidence (branch tips, filed outputs, sha identity), under this VM's bounds (MemAvailable ~3.5 GB, lightest work only). Each slice's own filed suite results stand as its record, re-read — not re-run — here, and the gate claims nothing stronger.

## 3. Per-slice verdict table (J-099–J-117)

Final states restate each slice's keeper closure; tips verified by `git ls-remote` at this gate (§2).

| Slice | Final state (keeper closure) | Branch @ tip (short) | Inspect |
|---|---|---|---|
| J-099 Tool census reconciliation | CLOSED | `yrsa/janas-j099` @ `ceec2765` | 92 PASS, 0 FAIL |
| J-100 Bench configurations | CLOSED-WITH-DEFERRED-LEG | `yrsa/janas-j100` @ `de9213cb` | 42 PASS, 0 FAIL |
| J-101 Machine report | CLOSED-WITH-DEFERRED-LEG | `yrsa/janas-j101` @ `ba7ff3bc` | 63 PASS, 0 FAIL |
| J-102 Chat picker | CLOSED-WITH-DEFERRED-LEG | `yrsa/janas-j102` @ `7526ecd9` | 56 PASS, 0 FAIL |
| J-103 Model getting | CLOSED-WITH-DEFERRED-LEG | `yrsa/janas-j103` @ `dca5ec05` | 75 PASS, 0 FAIL |
| J-104 Saved configuration | CLOSED-WITH-DEFERRED-LEG | `yrsa/janas-j104` @ `8e9da526` | 53 PASS, 0 FAIL |
| J-105 Chat manners | CLOSED-WITH-DEFERRED-LEG | `yrsa/janas-j105` @ `fde78060` | 47 PASS, 0 FAIL |
| J-106 OpenAI-shape audit | CLOSED-WITH-DEFERRED-LEG | `yrsa/janas-j106` @ `ddec27dc` | 38 PASS, 0 FAIL |
| J-107 Server streaming + progress | CLOSED-WITH-DEFERRED-LEGS | `yrsa/janas-j107` @ `68c78d6c` | 30 PASS, 0 FAIL |
| J-108 Server browser page | CLOSED-WITH-DEFERRED-LEG | `yrsa/janas-j108` @ `5b520613` | 39 PASS, 0 FAIL |
| J-109 MCP model-as-tools | CLOSED-WITH-DEFERRED-LEGS | `yrsa/janas-j109` @ `52258cd8` | 65 PASS, 0 FAIL |
| J-110 MCP in the ecosystem | CLOSED-WITH-DEFERRED-LEGS | `yrsa/janas-j110` @ `0d601c87` | 49 PASS, 0 FAIL |
| J-111 Code completion | CLOSED-WITH-DEFERRED-LEGS | `yrsa/janas-j111` @ `cdf70d7a` | 61 PASS, 0 FAIL |
| J-112 Services surface | CLOSED (deferred legs in §5) | `yrsa/janas-j112` @ `0a52d915` | 109 PASS, 0 FAIL |
| J-113 The NSM question | CLOSED-WITH-DEFERRED-LEG | `yrsa/janas-j113` @ `5ddf1946` | 52 PASS, 0 FAIL |
| J-114 Constrained generation | CLOSED-WITH-DEFERRED-LEGS | `yrsa/janas-j114` @ `e3d093b3` | 62 PASS, 0 FAIL |
| J-115 Library surface audit | CLOSED | `yrsa/janas-j115` @ `640d6479` | 42 PASS, 0 FAIL |
| J-116 Yggdrasil binding | CLOSED (adapter fix OPEN, §5 item 23) | `yrsa/janas-j116` @ `982275a7` | 36 PASS, 0 FAIL |
| J-117 Examples that run | CLOSED-WITH-DEFERRED-LEGS | `yrsa/janas-j117` @ `570c9f06` | 29 PASS, 0 FAIL |

Discharged since filing, recorded so it is not double-counted as owed: J-100's deferred live driver smoke was discharged by J-101's VM live example (same dispatch, real inventory, filed verbatim in J-101's record).

## 4. The refusal list, restated with its reasons

- Speech (J-099 rows T19/T28, standing from the J-014 gate): REFUSED. Speech routes stay out of the engine's server shape by that gate's refusal; no Part VII slice re-opened it.
- Domain services (J-099 row T23): REFUSED. Host-layer services (flights, weather, maps and their kin) belong to hosts, not the engine; the transferable core was taken up as the services surface (J-112), the domain services themselves were not.
- The `.jns` converter, gguf2jns (J-099 row T24): REFUSED. Its output is the `.jns` format, itself refused; Aesir reads GGUF natively. The converter rows that remain open belong to Part VIII (J-119 onward), not to this gate.
- NSM dressing is REFUSED (J-113, the final concordance form of row 69; not a deferred leg). Reasons as filed there: its trained artefacts are CC BY-NC-SA research material Janas itself does not ship, so Aesir could neither redistribute them nor build a shippable feature on them, and re-training an equivalent from the paper alone would be a research programme, not clean-room parity; it is a single-paper instrument bound to one model and one adapter, not an engine capability; and no consumer in Volmarr's stack requests it. Its transferable core — output restricted to a permitted vocabulary — was built instead (J-113's restrictor, J-114's sampler enforcement). Re-open criteria are filed in J-113's doc §0.2/§2.
- FreeBASIC is REFUSED (J-099 row T35, confirmed J-115 §5). No `.bi` artefact exists anywhere in the tree, no consumer in Volmarr's stack waits for one, and its substrate — the C ABI — is itself deferred (below), so a FreeBASIC binding would have nothing to bind to.
- Embed is REFUSED where filed (J-109, J-112, J-115, J-116). The MCP `aesir_embed` tool refuses always and honestly as a proper tool error, the J-112 services registry classes embed REFUSED, and J-116 re-verified the refusal is aligned on both sides (the Yggdrasil adapter likewise): no embedding data path exists in the engine, and no vector is ever returned or faked.
- Vision through the adapter/serve doors is likewise refused by name on both sides (J-115 §6, J-116 §3), aligned, for the same reason: no such data path is wired there.
- C ABI: DEFERRED, not refused and not built (J-115 §3). The standing named consumer, Yggdrasil, consumes the native HTTP door by its own design; no named consumer requires the in-process C form. The exact future shape, three named blockers, and the reopen condition (a named consumer requiring in-process C) are filed in J-115 §3. The only C ABIs in the tree face downward (engine to device/helper), none host-facing.
- Node/TypeScript native form: DEFERRED-WITH-REASON (J-115 §5). No artefact and no consumer exist; the HTTP and MCP doors are its answer today, and Node-client interop is NOT PROVEN (no Node proof filed in J-115; J-117's Node run was a headless check of the example page's own script, not a Node binding).

## 5. Deferred legs re-cited at this gate (all NOT PROVEN / DEFERRED-WITH-REASON unless marked OPEN)

None of these ran at this gate. Common blockers, stated once: the VM below its 5,500 MB inference gate (MemAvailable ~3.5 GB at this gate), no CUDA device on the VM, and purplelongship yielded to the 204 road's live work — every live recipe runs in a guarded purplelongship window, checking the 204 road's heartbeat first, one heavy run at a time, with model pins re-verified by sha256 and grading ids-first under the raw-oracle discipline (teacher-forcing rank + logit gap against the ggml CPU comparator on the raw prompt; never `llama-cli --single-turn`).

1. **J-101 purplelongship machine-report example** — the filed example from the laptop line was never captured (the 204 road owned the box). Recipe: `j101_example_purplelongship.txt` as filed, guarded window. Owning home: the first guarded purplelongship window after this gate.
2. **J-102/J-103 live model download** — no catalogue entry was ever downloaded live (smallest pin 2,016,888,384 B). Recipe: J-103 doc §5 (standalone `get`, picker fetch, corrupted-pin negative legs). Carries J-102's deferred fetch leg with it.
3. **J-104 live chat behaviour** — `/save-config` in a live chat session. Recipe: J-104 doc §5 (7 steps).
4. **J-105 live interactive chat** — the manners behaviours in a live interactive session. Recipe: J-105 doc §5.
5. **J-106 live server leg** — the audited OpenAI shape against a running serve. Recipe: J-106 doc's deferred-leg filing; runs with items 7–8's window where possible.
6. **J-107 in-read interleave (J-059 W1)** — progress frames are batched after the blocking read in the filed build; the session sink that interleaves them is unbuilt. Recipe: J-107 doc §5/§7, standing on J-059 §7's build order (W2, then W1, then W3).
7. **J-107 live server streaming leg** — streamed progress against a running serve. Recipe: J-107 doc §5.
8. **J-108 live browser leg** — the served page, and J-117's example page as a saved file, in a real browser against a live serve. Recipe: J-108 doc §5 steps 1–5 (J-117 doc §7.2 re-cites it unamended).
9. **J-109/J-110/J-112 live generate-through-MCP** — generation through an engine-bound MCP host; the consumer (Rúnmál) closes its share by re-running unchanged against a bound host. Recipe: J-109 doc §5, unchanged.
10. **J-110 in-Rúnmál registration** — the proven contract-boundary wiring registered inside Rúnmál's own tree, deliberately untouched by this road. Recipe: J-110 doc §3. Owning home: Rúnmál's own road.
11. **J-110 Hermes-side MCP wiring** — no runnable probe-seam harness existed on disk to wire against. Recipe: J-110 doc's deferred filing; stands until such a harness exists.
12. **J-111 live completion latency** — the latency leg against Janas's published 1,500–2,200 ms band on the laptop line. Recipe: J-111 doc §5.
13. **J-111 / J-097 live window consumption** — J-097's sliding-window service consumed live, inherited by J-111 by name. Recipe: J-111 doc §5, standing on J-097 doc §7.
14. **J-111 true FIM for any arch** — no arch carries true fill-in-the-middle (no FIM spelling or tokenizer control exists); needs its own tokenizer wiring slice. Recipe: J-111 doc §5.
15. **J-112 MCP tokenize through a tokenizer-bound host** — the bound-host completion of `aesir_tokenize`. Recipe: J-112 doc §5.
16. **J-112 live chat exchange** — a live chat session, including a live `/services tokenize`, with the filed transcript list. Recipe: J-112 doc §5 leg 2.
17. **J-112 T22 in-chat MCP client door** — dispositioned, not built (J-112 §0.4): no tool-call channel exists in the chat generation loop and no named external MCP server waits. Named future home: a dedicated slice once a named external server is a real consumer requirement and a guarded window can prove the loop live.
18. **J-113/J-114 live constrained generation** — constrained generation against a live model, emitted text graded by the filed audit, plus the quiet-machine cost re-run. Recipe: J-114 doc §5 (standing on J-113 doc §5).
19. **J-114 CUDA-session binding for constrained generation** — the configure seam, host-logits selection, and state commit that let resident CUDA sessions enforce the restriction instead of refusing at 400. Recipe: J-114 doc §5.
20. **J-115 C ABI build** — DEFERRED per §4 above; the build itself is ordinary slice work once the reopen condition (a named in-process C consumer) is met. Recipe and blockers: J-115 doc §3.
21. **J-115 Node/TypeScript native binding** — DEFERRED per §4 above; the doors are today's answer. Reopen condition and record: J-115 doc §5.
22. **J-117 facade tier on a GPU-present host** — the embedding example's own compile (failed on this GPU-less VM in the MAX pass manager, control-proven an environment class) and its model-bound run. Recipe: J-117 doc §7.3.
23. **J-116 adapter-side progress-frame fix — OPEN, not merely deferred** — in Yggdrasil's `src/yggdrasil/aesir_adapter.py`, the stream loop must skip records carrying a string `event` field immediately after `json.loads` succeeds and before the text-string test (the final progress frame carries `done: true` and must never reach the terminal test), with the two tests J-116 §1.3 names. Evidence: J-116 doc §§1.1–1.2 (Aesir-side contract proof plus a faithful replica proof: the current rule raises `engine_error` on the real long-prompt shape; the filed recipe completes the same stream exactly and weakens no other rule). Owning home: Yggdrasil's own road — nothing was written into Yggdrasil's tree by this road. Until that road lands it, the adapter does not consume streamed native generation over watched (long) prompts, and no Part VII claim says otherwise.
24. **G-099-1 chat-side progress (J-059 W2)** — gate disposition: DEFERRED-WITH-REASON beyond Part VII. J-107 owned progress through the server API and expressly did not absorb the CLI host-loop leg; it remains unbuilt, with J-059 §7's build order as its recipe. Owning home: a future slice commissioned for it, or the Part IX proof spine if the keeper so directs.
25. **G-099-2 non-config slash family** — gate disposition: DEFERRED-WITH-REASON beyond Part VII. The family (`/stats`, `/context`, `/experts`, `/think`, `/mode`, `/image`, `/markdown`, `/gpu`) was confirmed owed by J-112 by name in J-099's disposition, but J-112's filed work dispositioned the services surface and T22, not this family by name; it therefore falls to this gate as still unowned and unbuilt (the `/services` family is a different surface and does not discharge it; `/image` rides the vision path owned by the 204 road). Owning home: a future slice commissioned for it.
26. **G-099-3 recap-summarised context sliding (T05, Concordance row 38)** — gate disposition: DEFERRED-WITH-REASON beyond this road. It remains PARTIAL and unowned: no slice in the 150 names recap or summarisation, J-097's sliding window is a different mechanism (divergence-based re-read avoidance, not recap summarisation), and this gate builds nothing. It is not refused — it is recorded as an explicit deferral beyond the road for Volmarr's or the keeper's future commissioning.

Also recorded, not counted in the 26: vendor-editor MCP interop is NOT PROVEN (J-110) with no recipe filed — it is a gap in proof, not a deferred leg of this road.

## 6. Defects and anomalies found at this gate

- No defect was found in any Part VII module, number, or slice record: every re-read count, tip, and sha agreed with its keeper closure.
- Immediate next item (never-leave-a-bug, discovery already filed by J-109 §7 and carried by its keeper): `cli/repl.mojo`'s `read_line()` returns `String(buffer)` over a `List[Byte]` — the debug-representation idiom J-109 measured as defective on this toolchain — in pre-existing code. Its live path is docstring-marked unsupported and no Part VII surface imports it. The fix is not made in this gate slice (it changes chat-adjacent behaviour and wants its own tests, exactly as J-109 filed); it is recorded here as the immediate next item for the keeper to commission as its own slice, with J-109 doc §7 as the discovery record.
- Shared-repo anomaly (recorded by J-106 and J-112, unchanged): two pre-existing 0-byte stray files `c4.txt`/`c5.txt` in the shared canonical `.git/refs/heads/yrsa/` make `git fetch origin` report `fatal: bad object refs/heads/yrsa/c4.txt`; `git ls-remote` is authoritative and pushes are unaffected. Nothing was deleted — a repair inside the shared `.git` is for Volmarr's word or an explicitly scoped repair, not this gate.

## 7. Honesty ledger and banking

- Every number in §2 was re-derived at this gate by `j118_inspect.py` from the filed artefacts and `git ls-remote` — not taken from prose. Filed evidence: `docs/janas/j118_inspect.py`, `docs/janas/j118_inspect_output.txt`, `docs/janas/j118_test_output.txt`, with sha-identical campaign copies in `~/workspace/model-tests/janas/`.
- Protocol (§0) was committed first and push-verified before any evidence work: commit `49bf6381aa29f6cdd1a27f130c408a47448bb64a`, `git ls-remote` remote == local before the gate doc was completed.
- Machine state at this gate (VM): MemAvailable ~3.5 GB at start — below the 5,500 MB inference gate throughout; text/inspect work only, no inference, no live server, no browser; purplelongship not used (204 road's live S-104 run there — yielded). Worktree shape: no-cone sparse checkout of `aesir_engine/` + `docs/janas/`.
- No README touched. Hailo untouched/parked (no finish-line branch contact, no chip run or probe). No Docker. Nothing deleted. No Janas material used; no Janas source opened.
