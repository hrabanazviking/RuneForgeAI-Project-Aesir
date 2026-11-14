# CAMPAIGN_STATE - team-27 (Aesir Z13 forge)

- Team: team-27 (1 lead + 6 Mythic Engineering sub-agents)
- Worktree: /home/volmarr/aesir-team-27, branch yrsa/aesir-team-27
- Base: 57f2e2da73cb25183fe08dc5b288263fee0b62bf (banked main, 114 of 216, A-114 closure; seat == ls-remote verified by the keeper this tick). HEAD verified by the lead on this worktree. Untracked scratch/a097/ (old, not this slice's) left in place.
- Prior slices (team-27): A-100, A-103, A-106, A-111, A-114 DONE (banked).
- Assigned slice: A-117 - Local gate script (Wave 13, Oracle infrastructure). The whole matrix as one local command (no GitHub Actions - house law). Acceptance: script + timing filed; keeper can run it as the full-tier gate.
- Builds on banked: A-114 full matrix runner (core/matrix_runner.mojo + tests/bench_matrix_a114.mojo, 228 cells, verdict per cell), A-109..A-113 oracle infrastructure, E-MASTER suite (pin 727).
- A-115 / A-116 DEPENDENCY (honest): A-115 (team-25) and A-116 (team-26) build in parallel and have NOT banked. A-117 is built against the banked A-114 runner + E-MASTER surfaces only; integration points named in core/local_gate.mojo header and scripts/gate_local.sh (A-115 policy can refine suite judging; A-116 localisation is the tool the gate points at on failure) - no unbanked code depended on.
- Status: IN PROGRESS 2026-11-13. Commit on team branch only, subject exactly "A-117: Local gate script"; keeper banks after A-115 and A-116 in roadmap order (Wave 13 closer). Never merge or push. Never touch README.md. No Docker, ever. Never run a full suite concurrently with another team or a seat gate (check ps first).
- Suite baseline on this base: 724 passed / 1 failed / 2 skipped / 727 total; sole failure pre-existing gguf.tensor_directory_interface (J-022 drift); skips the 2 pre-declared. Known named intermittents: resilience.state_vault_rejects_growth, gpu.amd_hip_stream_async_round_trip, gguf.weight_residency_gpu_visibility, memory.budget_live_meminfo_pressure - a suite showing only J-022 (+ at most one named intermittent that clears on a solo re-run) is green-to-baseline.
- Raw-oracle discipline: teacher-forcing rank + logit gap on RAW prompts only, CPU engine vs CPU comparator only, near-tie band rank <= 2 with sub-logit gap = faithful, IQ graded on coherence never token-exactness, comparator artifacts are a verdict class; accelerator-visible is not accelerator-run.

## Team-27 outcome 2026-11-13 - A-117 DONE (PASS)
- Slice: A-117 - Local gate script (Wave 13 closer). Base 57f2e2da (114 of 216).
- Gate: scripts/gate_local.sh - one local command (no GitHub Actions): collision preflight, seat staging, A-114 matrix phase (228 cells), E-MASTER phase, strict judges, timed verdict in hidden_files/a117_gate.log, exit 0/1/2. Policy encoded once in core/local_gate.mojo; 10 cases gate.local_* in tests/test_local_gate_a117.mojo, all PASS. run_all pin 727 -> 737.
- Gate run (acceptance, solo, ps-checked): GATE_LOCAL RESULT: PASS (239s); matrix COMPLETE (digest 9653520459811539623, as A-114); suite 734/1/2/737 green-to-baseline (sole failure J-022; baseline 724/1/2/727 + 10 new). Timing: matrix 1s, suite 238s, total 239s.
- Docs: docs/bench/A117_LOCAL_GATE_SCRIPT.md; hidden_files/A117_LEDGER.md; CAPABILITY_LEDGER.md section 26 (Z13-P5-117) + E-MASTER count 727 -> 737.
- Bugs: none. Next: keeper banks A-117 after A-115 and A-116 in roadmap order.
