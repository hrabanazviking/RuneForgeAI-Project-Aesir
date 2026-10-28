# CLI TRUTHFUL-BOUNDARIES FIX — notes (branch platform/cli-truthful-boundaries)

Base: platform/case75-suite-segfault @ 30d28af7 (counted run 269/1/1).
Fix commit: 19092e35 (aesir_engine/tests/test_cli.mojo only; engine untouched).

## Target 1 — cli.truthful_command_boundaries: TEST was wrong, engine right

Failure was: "unsupported CLI command returned successfully: ps".

- `ps` and `stop` are implemented service-lifecycle commands:
  `dispatch_command` routes them to `dispatch_service_command`
  (aesir_engine/cli/commands.mojo), backed by cli/service_lifecycle.mojo.
  Bare `ps` succeeds BY DESIGN — it prints the store snapshot
  ("No live service owns this model store" when nothing is live).
- Bare `stop` is rejected, but with "Usage: aesir stop <exact-model> ..."
  — a truthful fail-closed rejection whose text the test helper's
  accepted-substring list ("not implemented"/"unsupported"/"unknown"/…)
  does not cover. The `stop` assertion was therefore equally stale; it
  was masked only because the `ps` assertion ran first.

Fix (test only; the engine boundary was NOT weakened):
- Removed `assert_cli_command_unsupported("ps")` and `("stop")`.
- Added truthful implemented-surface assertions against a never-created
  test store (`.aesir-test-service-store`):
  ps succeeds (text + `--format json`); `ps --bogus` rejected with
  "Usage: aesir ps"; bare `stop` rejected with "Usage: aesir stop";
  `stop demo-model --model-store <empty>` raises
  "no live service owns this model store".
- Unknown-command coverage preserved and extended: push, swarm, plus a
  new genuinely unimplemented verb `restart` (falls through to
  "unknown command: restart"). `restart` is in neither the catalog list
  (list/ls/show/create/verify/catalog/gc/cp/rm/delete) nor the
  preference list (alias/favorite/… family).

## Target 2 — cli.flag_options_parser CWD sensitivity: non-hermetic TEST

- The engine is not at fault: `load_config_file(path)` (config.mojo)
  reads exactly the caller-selected path; the CLI passes the user's
  `--config` or the documented default. The CASE passed the bare
  relative path "aesir.config.json" in three places (tracked load,
  `config` command dispatch in the dispatch case, and the `--config`
  value later loaded via `effective_config`), so it failed from any
  CWD that was not the repository root (e.g. the case-75 hunt-build dir:
  268/2/1 there vs 269/1/1 at root).
- Fix: `_tracked_config_path()` helper ascends from the CWD (bounded,
  12 parents, `access()` probe) to locate the tracked file. From the
  repository root it returns the bare "aesir.config.json", so the
  documented invocation behaves byte-identically. The loader assertion
  now compares `config_path` against the located path actually given.
- Remaining literal loads in the file are negative tests
  (missing file / NUL path) or parse-only assertions — CWD-independent.

## Proof (2026-10-28, this worktree)

- Scratch driver (both cases called directly; built but NOT banked):
  PASS from the repository root AND from a subdirectory with no
  aesir.config.json in the CWD. First subdir run caught the third
  bare-path load (`effective_config`); fixed by locating the path once
  at the top of the flag-parser case.
- Standalone test_cli binary (its own main subset): exit 0, 7/7 PASS.
- FULL COUNTED RUN (run_all, AOT build with the documented command:
  staged hailo10h/thread_par shims, `-I .`, `--target-accelerator
  sm_89`, -Xlinker flags before the file), run from the worktree root:
  **Passed 270, Failed 0, Skipped 1, Total 271 — RUN_EXIT=0.**
  The one skip is the expected rag.real_engine_integration (external
  GGUF fixture). [CASE PASS] cli.truthful_command_boundaries,
  [CASE PASS] cli.flag_options_parser, [CASE PASS]
  rag.cosine_similarity all present; zero [CASE FAIL] lines.
- Logs: ~/workspace/.verify-tmp/cli-boundary/ (build_run_all.log,
  run_all_root.log, scratch + standalone logs).
