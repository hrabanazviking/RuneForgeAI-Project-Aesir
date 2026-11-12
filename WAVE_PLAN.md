# Aesir Z13 Forge — Wave Plan

Campaign: Project Aesir on purpleraider (ASUS ROG Flow Z13, AMD Strix Halo).
Roadmap: `docs/AESIR_Z13_MASSIVE_ROADMAP.md` — 216 slices, A-001…A-216,
24 waves of 9. Filed at commit 00a66e35 (2026-11-11).

## Layout (all on purpleraider)

- Main checkout (banking seat): `/home/volmarr/aesir-forge` (branch `main`)
- Team worktrees: `/home/volmarr/aesir-team-01` … `/home/volmarr/aesir-team-09`,
  branches `yrsa/aesir-team-NN`, each with its own `CAMPAIGN_STATE.md` and
  `hidden_files/` logs. Never share a checkout between teams.
- Structure: 9 teams × (1 lead + 6 Mythic Engineering sub-agents) = 63 workers.
  Each team works ONE slice at a time, in roadmap order.

## Slice queue

Slices are taken strictly in roadmap order (A-numbers ascending) and bank
only in roadmap order. Wave 1 assignments:

| Team | First slice |
|---|---|
| team-01 | A-001 |
| team-02 | A-002 |
| team-03 | A-003 |
| team-04 | A-004 |
| team-05 | A-005 |
| team-06 | A-006 |
| team-07 | A-007 |
| team-08 | A-008 |
| team-09 | A-009 |

After a team's slice banks, it takes the next unbuilt slice in order.

## Muster order (spawn-staggering law)

Probe with team-01 FIRST. Then muster 2–3 additional teams per keeper tick
(team-02+03, then 04+05, then 06+07, then 08+09) — never launch all teams at
once (platform rate limits, 2026-11-06 lesson). A team counts as mustered
when its lead is live on its assigned slice in its own worktree.

## Banking rules (per slice, in roadmap order, on purpleraider)

1. Full test suite green in the team's worktree (counts read back from log
   files, never memory; the fast gate A-035/A-080 applies once those exist —
   until then the repo's E-MASTER suite is the gate).
2. Merge the team branch into the main checkout (`~/aesir-forge`).
3. `git fetch` + remote-diff before any push.
4. Push explicit refspec `HEAD:refs/heads/main` — never force-push.
5. Verify the remote moved with `git ls-remote`.
6. Append the slice entry to `PROJECT_MEMORY_MAP.md` and update this file
   (banked count + next assignments). One slice per commit,
   subject `A-NNN: <title>`.

## Hard bounds

- NO Docker, ever. Native installs only.
- Never touch any README.md.
- Trust only disk: counts come from git + test-runner logs on purpleraider.
- Raw-oracle discipline for all correctness work (roadmap law 3); comparator
  artifacts are a verdict class (law 4); accelerator-visible ≠ accelerator-run
  (law 6) — every accelerator claim needs device-execution evidence.
- Never leave a discovered bug unfixed: fix inside the slice's scope, or
  record it as the immediate next work in the team's CAMPAIGN_STATE.md.
- Pause only at the Forge pause-lines (data destruction, irreversible
  infrastructure, cost, public publishing beyond this repo's own pushes,
  sending as Volmarr, exposing secrets, weakening security).

## State

- Banked: **21 of 216** (A-001..A-021). A-020 + A-021 banked at
  the seat 2026-11-12 (team commits cherry-picked in roadmap
  order, one commit per slice; run_all pin unioned to 338:
  A-020 +4 weight-residency cases on top of the A-019 pin
  328 -> 332, A-021 +6 kv_unified cases 332 -> 338). Wave 2
  (A-010..A-018) is COMPLETE; Wave 3 (A-019..A-027) in progress.
- Seat gate after this banking: A-021 (seat_gate_a021.log)
  335 passed / 1 failed / 2 skipped / 338 total - run 1
  (preserved as seat_gate_a021_run1.log) showed 334/2/2 with
  one extra failure (resilience.state_vault_rejects_growth);
  the re-run was exact, filed as a flake per the A-017/A-019
  precedent. Sole failure the pre-existing J-022 drift, skips
  the 2 pre-declared.
- Queue: A-022 in flight (team-08), A-023 in flight (team-09);
  teams then take slices in roadmap order as theirs bank
  (keeper flow): team-01 A-024, team-02 A-025, team-03
  A-026, team-04 A-027, team-05 A-028, team-06 A-029,
  team-07 A-030, team-08 A-031, team-09 A-032. Sole
  failure in every suite = pre-existing
  gguf.tensor_directory_interface J-022 drift (roads A-165
  primary / A-121); skips = the 2 pre-declared.
- A-007 caveat: unprivileged xrt-smi is blocked by RLIMIT_MEMLOCK
  (8192 kB vs the 64 MiB locked map XRT wants) - NPU tools run via
  sudo until Volmarr rules on raising the user memlock limit;
  xrt-smi validate needs the Xilinx VTD archive, first step of A-092.
