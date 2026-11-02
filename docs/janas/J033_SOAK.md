# J-033 — Soak

**Slice:** J-033 (Part II — Models Bigger Than Memory), Project Aesir Janas clean-room road.
**Roadmap text:** "A long session (≥2,000 generated tokens across mixed prompts) on the J-022 model: cache behaviour, memory ceiling held, no degradation trend."
**Executed:** 2026-10-31 ~12:45–12:5x EDT. **Closure shape: CLOSED-WITH-DEFERRED-LEG — the soak leg is NOT PROVEN / DEFERRED-WITH-REASON to the J-034 gate.** The complete soak harness (guarded driver + analyser + prompt set) is built, its verdict rules were pre-registered in §4 of this doc before any soak measurement, and the analyser is PROVEN offline (§5). **No soak run happened this slice** — §1 states plainly why: the 204 road's S-098 was dispatched at ~12:43 EDT and owns purplelongship's next move, and a ≥2,048-token soak at the measured CPU-line rate needs ~17–20 minutes of genuinely idle box, which a just-dispatched 204 slice forecloses. The exact guarded run recipe for the J-034 gate is filed in §7. No soak number is claimed anywhere in this doc; every number quoted is either re-verified from filed J-022/J-023/J-030 artefacts or produced by the offline analyser exercises in §5, and is labelled as such.
**Base:** intended branch `yrsa/janas-j033` from `yrsa/janas-j032` tip `d405df13` — **the branch could not be created: the VM git-write interdict (§8) blocks ref writes**, so this slice's files are filed uncommitted in the artefact directory `~/workspace/aesir-janas-j033/docs/janas/` with sha-identical campaign copies in `~/workspace/model-tests/janas/`; the exact pending commits are listed in §8. The J-032 header correction is likewise still pending (§8). Origin/main untouched at `ba7ee09b`. No README touched. Hailo untouched/parked.

---

## 1. Coordination and environment (first-hand, this slice)

- **204 road, checked first (binding):** `ROADMAP_204_STATE.md` heartbeat at dispatch — S-097 DONE (fresh legs ran on purplelongship 12:26–12:32 EDT), and at **~12:43 EDT the 204 keeper dispatched a fresh worker for S-098** (Oprius full-ladder tuning + re-test, laptop line). S-098 is therefore the box's next heavy move.
- **On-box check (device route available to this worker), 2026-10-31 12:46:49 EDT:** purplelongship idle *at that instant* — loadavg 0.14 / 0.41 / 0.93, MemAvailable 37,431 MB, GPU 1 MiB / 36 °C / 0 %, no oracle/session compute process, no `s098` tmux session or `~/s098` directory yet (the S-098 worker had not started its on-box legs). The J-022 assets the soak needs are present: the model file at the pin's size (4,213,512,672 B) and the post-fix vehicle `~/j022/test_olmoe_stream_fix` (sha256 `124e89a3709b316a9df615cc3965aa08a184eb78ebda7c0f895392ae6032be6b`, measured this slice).
- **Why that idle instant is not a genuinely idle gap:** the J-030 CPU line measures decode at 2.5563 tok/s and prefill at 2.3894 tok/s on this configuration. A 2,048-token soak (8 windows × 256 gen, §3) therefore needs ≈ 801 s of decode plus ≈ 8 × 30–45 s of prefill — **~17–20 minutes of continuous idle box**. S-098's worker, dispatched two minutes before this slice began, will start its own guarded on-box legs inside that window; the two runs would contend, and contended walls are not baselines under this road's laws (both roads'). The dispatch instruction for this slice names the rule — yield to any live 204 run, no contention, soak runs idle — and the J-030/J-031/J-032 precedent is uniform: a dispatched 204 slice is yielded to, not raced. **The soak leg is deferred, not attempted-and-contended.**
- **VM:** MemAvailable measured 1,237 MB early in this slice and 6,149 MB later — a flickering gate is not a passed gate, the dispatch stated ~2,339 MB and ordered no VM inference, and the soak's named hardware is purplelongship in any case. No VM inference ran; VM work was file-building and offline analysis only.
- **Git/storage:** `/tmp` healthy (1 % of 512 MB tmpfs) this slice. The git-write interdict is live (§8) — it blocks banking, not this slice's file work.

## 2. Model, vehicle, configuration (the soak's subject)

- **Model (the J-022 model):** OLMoE-1B-7B-0924-Instruct Q4_K_M, sha256 pin `8c310f1435a1222338fd2d3d974975be9cd908180b644bab0c2a94da1ac32f3f` (J-015 pin, re-read from the J-015/J-030 docs this slice), 4,213,512,672 B.
- **Vehicle:** `test_olmoe_stream_fix` over `MoEStreamSession` — the post-B1-fix streamed session whose faithfulness J-022 §7.3 proved (rank 0 at 23/24, step-23 rank 1 gap 0.108, near-tie discipline). Usage (re-read from `aesir_engine/tests/test_olmoe_stream.mojo` this slice): `<model> <context> <cache_bytes> <tokens_csv> <gen_count>`; prompt ids are supplied externally (the model's own tokenizer stack) by design; generation stops early if the EOS token is produced.
- **Configuration (identical to the J-022/J-023/J-030 line):** context 512, expert-cache budget 536,870,912 B, `CUDA_VISIBLE_DEVICES=` (pure CPU line per J-030), `LD_LIBRARY_PATH=/home/volmarr/j022/stage`, `nice -n 10`.

## 3. Soak shape (pre-registered)

Stated plainly, as the dispatch requires: **a single session cannot reach 2,000 generated tokens** — the session's context is 512 tokens, so prompt + generation per invocation is bounded well under 2,000. The soak is therefore **repeated session invocations** of the same vehicle and configuration, which is also the honest shape for the question J-033 asks (cache behaviour and memory behaviour across a long working session, session boundaries included — J-027 measured that no expert map persists between sessions, so each window's cold start is part of the measured reality, not a defect of the design).

- **Windows:** 8 windows, one session each, sequential, no co-runner (idle box only).
- **Per window:** 256 generated tokens target; total 8 × 256 = **2,048 generated tokens ≥ 2,000**.
- **Prompts (mixed, per J-016's types):** w01 prose, w02 code, w03 structured, w04 numbers, w05 instructions, w06 technical — the J-016 texts verbatim (`j033_prompts.txt`); w07 prose2 and w08 code2 are J-033-authored additions, labelled in the file. Window 1's prompt is the J-022 lighthouse prose prompt itself, reusing its verified 67-id file, so window 1 doubles as the faithfulness spot grade (§4).
- **Prompt bound:** every prompt ≤ 200 ids (driver pre-flight refuses above it), so prompt + 256 gen stays inside context 512 with margin.
- **EOS shortfall rule:** if a window stops early on EOS, its actual generated count stands (never padded, never re-rolled). If the 8-window total is < 2,000, the driver is re-run for top-up windows (prose2/code2 alternating, `j033_run.sh` resume form) until ≥ 2,000 or 12 windows total; any remaining shortfall is reported as the soak's actual size, not rounded up.
- **Per window the driver records:** the session log (`Generated IDs`, `[CACHE]`, `[STREAM]`, `TIMING` lines), peak RSS + elapsed (`/usr/bin/time -v` into the window `.meta`), and machine state (loadavg, Tctl, MemAvailable, GPU) at window start and end.

## 4. Verdict definitions (pre-registered before measuring)

The analyser `j033_analyze.py` implements exactly these rules; they were written into this doc and the analyser together, before any soak run exists.

- **Windows for trend analysis:** the 8 (or top-up) sessions in execution order; every trend is over window index.
- **Wall/token drift:** per-window decode seconds per generated token (primary; decode is the soak's steady state) and wall per total token (reported). **Degradation** iff the least-squares slope of decode s/gen is > 0 **and** last window > 1.25 × first window. Thermal confound, named in advance: if Tctl climbs > 15 °C across the soak, a firing wall rule is reported as *thermally confounded*, not as engine degradation (J-023's loaded leg ended +82.4 °C under its co-runner's own heat; an idle soak should not, and the metas will show it either way).
- **Cache hit-rate trend:** per-window `[CACHE]` hit rate. **Degradation** iff last window < 0.8 × first window. Confound named in advance: prompt types differ per window, so per-window hit rates are not like-for-like; the cumulative hit rate over all windows is reported beside the trend and a firing rule must be read with the per-type table, not alone.
- **Streamed-bytes/token trend:** per-window streamed bytes per generated token (and per total token, for J-023 comparability). **Degradation** iff last window > 1.25 × first window.
- **Memory ceiling (held = every window):** (a) `[CACHE] bytes_resident_now` ≤ `budget_bytes` = 536,870,912 in every window — the J-018 hard cap, checked on the session's own counters; (b) peak RSS ≤ **2,132,266 KiB** in every window (the J-023 idle peak 1,938,424 KiB × 1.10, rounded up — the ceiling is stated here, before measuring, not fitted afterwards). The driver additionally aborts between windows if MemAvailable < 2,000 MB (J-028's pressure honesty: refuse cleanly rather than swap).
- **Faithfulness spot grade (ids-first, raw-oracle discipline):** (a) window 1's first 24 generated ids must equal J-022 §7.3's post-fix ids **exactly** (same prompt, same greedy vehicle, deterministic counters in every prior run of this line — a mismatch is a defect to bisect, never a shrug); (b) window 5 (instructions) gets a teacher-forcing grade of its first 24 generated ids against the ggml CPU comparator (`tf_oracle`, raw prompt, CPU vs CPU; never `llama-cli --single-turn`): PASS = rank ≤ 2 at ≥ 23/24 steps with sub-logit gaps (the near-tie band). The spot grade grades the soak's faithfulness; it does not re-prove J-022.
- **Completeness:** total generated < 2,000 ⇒ the soak is PARTIAL and every verdict is labelled provisional (the analyser prints this itself).
- **Overall verdict:** DEGRADATION TREND iff any trend rule fires or any ceiling breaches; otherwise NO DEGRADATION TREND. All component numbers are printed regardless of verdict.

## 5. Harness as built, and its offline proof (PROVEN)

Files (sha256, this slice; campaign copies identical, §8):

- `docs/janas/j033_run.sh` — `75bed07ca908a3a5a4d0751bfe36984ff211439a302357d6335eae75589284b7`: guarded driver. Pre-flight: model sha256 == pin (refuses on mismatch), vehicle present, every window's ids file present with ≤ 200 ids. Guard before **every** window (J-023 pattern, generalised from S-093 to the road's current slices): refuses while `tf_oracle`/`fr_oracle` or an `s098` process is live, while loadavg-1 > 4.0, while GPU used memory > 100 MiB, or while MemAvailable < 2,000 MB; a tripped guard stops the soak cleanly between windows (exit 3) leaving completed windows as valid partial evidence. `bash -n` clean.
- `docs/janas/j033_analyze.py` — `a348015cbb7f4f3534ba28bbacc7eabc20410dec58e83731b9fef5d1f1a30be4`: the §4 analyser.
- `docs/janas/j033_prompts.txt` — `cdf38eb60fccc071f44bbc4558da5ed14e8e79a1241d680cf3837fda47537e2b`: the 8 window prompts (§3).
- `docs/janas/j033_analyze_test.py` — `5fd3f753ac3dc77c5384f2c2455f6ef3954168190d2ad6b5c60cc641bba3d9ea`: the analyser's offline test (synthetic flat/drift/breach sets + the real J-023 logs), written for a normal filesystem.

**Offline exercises actually run this slice (VM, read-only inputs):** the test script's own fixture-writing step is blocked by the same exec-plane write interdict as git (§8 — `PermissionError: Operation not permitted` on its first fixture write), so its fixtures were written through the file-tool plane into `~/workspace/.verify-tmp/j033/fixtures/` and every one of its assertions was exercised by direct analyser runs:

1. **Flat synthetic (8 identical windows):** `total_generated=2048`, `cumulative_hit=0.258`, ceiling HELD, all three trends "no degradation", **VERDICT: NO DEGRADATION TREND** — PASS.
2. **Drift synthetic (decode s/gen ×1.10 per window):** wall slope +0.04315, last/first 1.331 → **DEGRADATION** fires on the wall rule exactly as pre-registered — PASS.
3. **Breach synthetic (RSS 3,000,000 KiB):** per-window `CEILING_BREACH … over ceiling 2132266 KiB`, ceiling BREACH, verdict DEGRADATION — PASS.
4. **Real J-023 harvest logs as a 2-window soak:** the analyser reproduces the filed J-023/J-030 numbers **exactly** — hit 0.258 both windows, bytes/total-token 362,073,616.9 both, wall/total-token 0.4113 idle / 0.4353 loaded, RSS 1,938,424 / 1,939,492 KiB, `total_generated=48`, PARTIAL SOAK label, wall ratio 1.080 → no degradation (consistent with J-023's own NO THRASH verdict) — PASS.

So: the analyser's parsing, arithmetic, ceiling checks, trend rules, and partial-soak labelling are **PROVEN** against both synthetic ground truth and the road's real filed logs. The driver is syntax-proven and inspection-verified against the J-023 pattern; its on-box execution is part of the deferred leg (§7), not claimed here.

## 6. What did not run (stated plainly)

No soak window ran. No session of any kind ran on purplelongship or the VM this slice. No tok/s, wall, hit-rate, or memory figure for a soak exists, and none is implied: the §5 numbers are the analyser's behaviour on synthetic and previously filed logs, labelled as such. The soak leg — ≥2,000 generated tokens, cache behaviour, ceiling, trend, spot grade — is **NOT PROVEN / DEFERRED-WITH-REASON to the J-034 gate**, reason: §1's coordination record (S-098 dispatched ~12:43 EDT owns the box's next move; no genuinely idle ~17–20-minute gap exists while it is inbound; contention would corrupt both roads' evidence).

## 7. The J-034 gate recipe (exact, for a device-capable worker)

1. **Coordinate:** read `ROADMAP_204_STATE.md`'s heartbeat; proceed only in a genuinely idle gap (no 204 slice dispatched-and-unreported on the laptop line). Re-check on-box: no `tf_oracle`/`fr_oracle` process, GPU ≤ 100 MiB used, loadavg-1 ≤ 4.0.
2. **Ids:** create `~/j033/ids/` on purplelongship. For windows 2–8, tokenize `j033_prompts.txt`'s texts with the model's own tokenizer stack via the tokdump route J-022 §7 proved id-identical (the 204 road's `tf_tokdump` tool over libllama, raw prompt, no template), writing `code_ids.csv`, `structured_ids.csv`, `numbers_ids.csv`, `instructions_ids.csv`, `technical_ids.csv`, `prose2_ids.csv`, `code2_ids.csv`. Decode-check every CSV with the `~/j022/decode.py` pattern (ids must decode to the prompt text exactly); record each count (each must be ≤ 200). Window 1 needs no tokenization (verified `~/j022/prompt_prose_ids.csv`).
3. **Stage the harness:** copy `j033_run.sh` + `j033_analyze.py` to `~/j033/` (sha256 must match §5's), `chmod +x j033_run.sh`.
4. **Run:** `cd ~/j033 && ./j033_run.sh` (foreground-observed or tmux; expected ~17–20 min at the J-030 CPU-line rates). Exit 3 = guard stopped it between windows: wait for the next genuinely idle gap and resume with `./j033_run.sh <next window>`. Exit 4 = pre-flight failure: fix the named cause, never bypass the pin check. Exit 5 = a window failed: file the window log and stop; that is a defect report, not a soak.
5. **Analyse:** `python3 j033_analyze.py run_w01.log … run_w08.log` (plus any top-up windows), file the output verbatim. Apply §4's thermal-confound reading using the `.meta` Tctl lines before quoting any wall verdict.
6. **Spot grade:** compare window 1's first 24 generated ids against J-022 §7.3's filed ids (`j022_b1_fr_fix.txt` on the branch line / J-030's re-verification); grade window 5's first 24 with `tf_oracle` under the raw-oracle discipline (ggml CPU comparator, raw prompt; rank + logit gap; near-tie band rank ≤ 2, sub-logit gap).
7. **File at the gate:** window logs + metas + analyser output + grade table into `docs/janas/` beside this doc, and re-cite this deferral in the J-034 gate record with its outcome — the same re-cite the gate already owes J-024 (live confirmation), J-026 (two-session leg), J-028 (mid-run pressure leg), J-030 (fresh CPU-line leg), J-031 (GPU leg), and J-032 (80B attempt, via J-123).

## 8. Banking, and the J-032 correction (blocked-with-reason: the interdict)

**The interdict is still live, verified three ways this slice (~12:47–12:54 EDT):**

1. `git add docs/janas/J032_80B_CLASS_TARGET.md` in `~/workspace/aesir-janas-j032` → `fatal: unable to write loose object file: Operation not permitted` (the change never staged; HEAD still `d405df13`).
2. `git hash-object -w` on a brand-new unique file → same fatal (exit 128). (An earlier hash-object call that appeared to succeed returned the empty-blob hash — that object already existed; it wrote nothing.)
3. `git worktree add -b yrsa/janas-j033 …` → `fatal: cannot update ref 'refs/heads/yrsa/janas-j033': couldn't write '…/.git/refs/heads/yrsa/janas-j033.lock'`. The exec plane's Python and shell-redirection writes fail the same way (`PermissionError`); the file-tool plane writes normally, and — refinement recorded the same hour — `cp` copies between workspace paths succeed (that is how the campaign copies below were made and sha-verified). The block is therefore mechanism-specific, but it covers every write git itself needs, which is what banking requires. **No evasion was attempted** (no hand-built git objects, no alternate object stores) — per the dispatch instruction, the block is recorded, not routed around.

**Pending commits (exact, for the keeper when the interdict lifts):**

- **P1 (J-032 correction, on `yrsa/janas-j032`):** commit the one-line header fix already sitting uncommitted in `~/workspace/aesir-janas-j032` (worktree file sha256 `d15dcb94d7e8bebc81aa85a4e2fe64a4d93316c5cd875d53e7784c730966c785` — re-verified this slice; execution range 12:30–13:0x → 12:30–12:4x EDT), push by explicit refspec `git push origin HEAD:refs/heads/yrsa/janas-j032`, verify `git ls-remote` shows the branch moved past `d405df13`, then sync the campaign copy `~/workspace/model-tests/janas/J032_80B_CLASS_TARGET.md` to the corrected bytes (it still holds the banked bytes, sha256 `d63af00b…e79`, deliberately, until the push lands).
- **P2 (J-033, new branch `yrsa/janas-j033` from `d405df13`):** create the worktree/branch, place the six files of this slice under `docs/janas/` (`J033_SOAK.md`, `j033_run.sh`, `j033_analyze.py`, `j033_prompts.txt`, `j033_analyze_test.py`, `j033_analyze_test_output.txt` — bytes identical to the campaign copies), commit, push by explicit refspec, verify with `git ls-remote`. Origin/main stays untouched at `ba7ee09b`.

Until P1/P2 land, the authoritative copies of this slice are the artefact directory `~/workspace/aesir-janas-j033/docs/janas/` and the sha-identical campaign copies in `~/workspace/model-tests/janas/`.

## 9. Defects and discoveries

- **No defect found** in the J-022/J-023/J-030 records or the session code: the analyser's exercise 4 (§5) re-derives J-023's filed counters and walls exactly from the harvest logs, a fourth independent re-verification of that line (after J-029's, J-030's, and J-032's).
- **Environment incident (not a code bug):** the VM write interdict covers git loose-object writes, git ref writes, and exec-plane Python/redirection writes, while the file-tool plane and `cp` write normally (§8). It has now blocked two consecutive slices' banking (J-032's correction, J-033's branch). Recorded here and in the state file as the keeper's standing immediate-next-item; nothing in this road can bank until git's own writes work again.
- **Answered-locally:** none required — this slice needed no Janas material (clean-room law unengaged) and no design question the road's own record did not already answer (window/session shape follows the vehicle's context bound, §3).
