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

- Banked: **61 of 216** (A-001..A-061). A-061 banked at the
  seat 2026-11-12 (team-02 commit fdbbfba4 cherry-picked
  as 43c1e902; Vulkan elementwise + softmax, run_all pin
  unioned 474 -> 480 and vulkan_buffer_shim.c composed at
  banking: seat shim + A-061 elementwise/softmax block
  appended, A-060 RMSNorm/RoPE sections intact). A-060
  banked at the
  seat 2026-11-12 (team-05 commit 8de19201 cherry-picked
  as bb41ed4a; Vulkan RMSNorm + RoPE, run_all pin unioned
  468 -> 474 and vulkan_buffer_shim.c composed at banking:
  seat shim + A-060 RMSNorm/RoPE block appended, A-059 IQ
  sections intact). A-059 banked at the
  seat 2026-11-12 (team-01 commit 2d555a80 cherry-picked
  as 944bccc2; Vulkan IQ GEMV, run_all pin unioned
  463 -> 468 and vulkan_buffer_shim.c composed at banking:
  seat shim + A-059 IQ block appended, A-058 Q6/Q5 sections
  intact). A-058 banked at the
  seat 2026-11-12 (team-09 commit f397e1c6 cherry-picked
  as 278199de; Vulkan Q6_K + Q5_K GEMV, run_all pin unioned
  458 -> 463 and vulkan_buffer_shim.c composed at banking:
  seat shim + A-058 Q6/Q5 block appended, A-057 Q4_K section
  intact). A-057 banked at the
  seat 2026-11-12 (team-08 commit 056bf09d cherry-picked
  as 066eca4f; Vulkan Q4_K GEMV, run_all pin unioned
  455 -> 458 and vulkan_buffer_shim.c composed at banking).
  A-056 banked at the seat 2026-11-12 (team-07 commit
  45ba57e6 cherry-picked as 99323c17; Vulkan Q8_0 GEMV,
  run_all pin unioned 450 -> 455 at banking).
  A-055 banked at the seat 2026-11-12 (team-04 commit
  5d96a54b cherry-picked as c86433da; SPIR-V build
  pipeline, pin 445 -> 450).
  **Wave 3 (A-019..A-027) is COMPLETE. Wave 4
  (A-028..A-036) is COMPLETE. Wave 5 (A-037..A-045)
  is COMPLETE. Wave 6 (A-046..A-054) is COMPLETE.
  Wave 7 (A-055..A-063) is IN PROGRESS (7 of 9).**
- Seat gate after this banking: A-061 (seat_gate_a061.log)
  477 passed / 1 failed / 2 skipped / 480 total, exact on
  the first run. Sole failure the pre-existing
  gguf.tensor_directory_interface (J-022 drift), skips the
  2 pre-declared. Known intermittents (proven pre-existing
  at base b62b1481 by the A-055 base bisect, NOT caused by
  these slices): gguf.weight_residency_gpu_visibility
  (A-055 ledger bug B1) and
  resilience.state_vault_rejects_growth (bug B2) - neither
  appeared in the accepted gate run.
- Queue: teams take slices in roadmap order as theirs
  bank (keeper flow): team-06 A-062 (in flight), then
  team-03 A-063, team-04 A-064, team-01 A-065.
  Sole failure in every suite =
  pre-existing gguf.tensor_directory_interface J-022 drift
  (roads A-165 primary / A-121); skips = the 2 pre-declared.
- A-007 caveat: unprivileged xrt-smi is blocked by RLIMIT_MEMLOCK
  (8192 kB vs the 64 MiB locked map XRT wants) - NPU tools run via
  sudo until Volmarr rules on raising the user memlock limit;
  xrt-smi validate needs the Xilinx VTD archive, first step of A-092.
