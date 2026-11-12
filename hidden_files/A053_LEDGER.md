# A-053 Ledger — State on Z13 storage (team-06)

- Slice: A-053 (Wave 6) — Conversation autosave + catalog state verified
  on this filesystem. Acceptance: the existing crash-recovery batteries
  pass against the Z13 build.
- Base: 9167a21f (seat main, 51 of 216 banked, A-001..A-051). A-044
  verified banked in the seat log (40ce2d88) before starting.
- Worktree reset --hard onto 9167a21f before work; CAMPAIGN_STATE.md
  preserved (untracked).

## The filesystem fact this slice proves

- The pre-existing state batteries root their files in /tmp, which on
  purpleraider is tmpfs (63 GB RAM disk): fsync/rename there prove
  nothing about durable storage. The Z13 checkout lives on btrfs
  /dev/nvme0n1p3 (subvol /@home, nvme SSD, 1.5 TB free). /mnt/vault is
  a separate btrfs device (nvme1n1p1, zstd:3) and is NOT where the
  checkout or default state roots live, so it is out of scope here.
- A-053 re-verifies the same state invariants on the btrfs checkout
  filesystem, with an in-case device assertion (st_dev of the state
  root == st_dev of "." and != st_dev of /tmp) so the proof cannot
  silently fall back to tmpfs.

## New in-suite cases (aesir_engine/tests/test_state_storage_a053.mojo)

Pin 435 -> 439 (run_all.mojo re-pin comment filed). All four PASS:

- storage.z13_autosave_generations — full ConversationAutosave cycle
  on a 0700 root in the working directory (btrfs): 3 checkpoints with
  retention 2 (gen-1 pruned, gen-2/3 present, foreign sentinel file
  untouched), fresh-owner recovery of the latest generation with exact
  token IDs 200/201/202, interrupted begin(4) reported as
  generation/turn 4 with committed state intact, discard removes only
  owned files.
- storage.z13_state_vault_disk — StateVault.save_checkpoint_to_disk at
  a working-directory path (384/48/7000), st_dev != tmpfs, fresh-vault
  load returns the exact marker (checksum + timestamp identical),
  on-disk corruption rejected without mutating the active checkpoint.
- storage.z13_catalog_restart — DurableModelStore on a
  working-directory root: create_model writes catalog.v1; a fresh
  store instance (restart) lists exactly 1 model and get_model returns
  the identical digest.
- storage.z13_conversation_snapshot — save_conversation /
  load_conversation round-trip on a working-directory path: exact
  tokens, 3 turns, sampler_draws preserved; on-disk tampering rejected
  by the record checksum.

## Existing crash-recovery batteries vs the Z13 build

Probe binary built per the Capability Ledger E-AUTOSAVE command
(pixi run mojo build --target-accelerator gfx1151
aesir_engine/tests/test_conversation_autosave.mojo; gfx1151 is a
compile target only — the probe executes on host CPU; no accelerator
execution is claimed):

- E-AUTOSAVE (scripts/test_conversation_autosave.py, SIGKILL battery)
  with TMPDIR on the btrfs worktree: PASS
  (hidden_files/a053_eautosave_btrfs.log) — private no-symlink root;
  committed turn survived SIGKILL; interrupted generation identified;
  lock contention, owned-only cleanup, corruption refusal.
- E-AUTOSAVE with stock TMPDIR (/tmp tmpfs), for comparison: PASS
  (hidden_files/a053_eautosave_tmpfs.log).
- E-CONVERSATIONS (scripts/test_conversation_library.py, 5
  separate-process named-library cases) with TMPDIR on btrfs: PASS
  (hidden_files/a053_econversations_btrfs.log, "Ran 5 tests ... OK").
- In-suite crash-recovery cases also pass in the full run below:
  cli.conversation_autosave_generations,
  cli.conversation_autosave_corrupt_records, cli.chat_recovery_policy,
  cli.chat_recovery_snapshot_validation, resilience.state_vault_*,
  cli.catalog_schema_* (verdicts in hidden_files/a053_run_all.log).

## Full suite (E-MASTER, gate_fast.sh, CPU path)

- Run 1 (hidden_files/a053_run_all_run1.log): 435 passed / 2 failed /
  2 skipped / 439 total. Second failure =
  gguf.weight_residency_gpu_visibility (MEM-004 USE_AFTER_FREE) — the
  known A-035-filed HIP host-registered-mapping flake, not an A-053
  regression (no engine or HIP code changed). Per the A-035 guidance
  filed in team-06's CAMPAIGN_STATE.md, the suite was re-run once.
  Run 1 also ran concurrently with team-02's A-052 suite (shared
  machine contention; no wall-times are claimed from it).
- Run 2 (hidden_files/a053_run_all.log, sha256
  218ed6f8e509f088be2a635a9b88650a953bf971c97c2de63ef35f323bca650e):
  436 passed / 1 failed / 2 skipped / 439 total; GATE_FAST RESULT:
  PASS. Sole failure = pre-existing gguf.tensor_directory_interface
  (J-022 drift, roads A-165/A-121). Exactly baseline
  (432/1/2/435 at 9167a21f) + the 4 new cases, all passing.

## Bugs found

- None new. The run-1 gguf.weight_residency_gpu_visibility recurrence
  is the already-filed A-020/A-035 HIP flake (team-06's standing
  follow-up: minimal Mojo repro bisection); it passed on the single
  re-run, as filed guidance prescribes. No engine code changed in
  this slice.

## Files

- aesir_engine/tests/test_state_storage_a053.mojo (new, 4 cases)
- aesir_engine/tests/run_all.mojo (imports + 4 run_case + pin 439)
- hidden_files/A053_LEDGER.md, hidden_files/run_a053.sh,
  hidden_files/a053_*.log
