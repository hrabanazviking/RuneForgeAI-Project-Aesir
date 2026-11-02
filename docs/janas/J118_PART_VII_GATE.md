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
