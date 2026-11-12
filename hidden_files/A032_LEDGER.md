# A-032 Ledger — Backend config surface (team-09)

## Slice

- **Slice:** A-032 — Backend config surface (Wave 4, Build & target hygiene)
- **Roadmap text:** "`auto/cpu/vulkan/hip/npu` selection in config + CLI, fail-closed on unavailable requests. Acceptance: config tests incl. requesting an absent backend = clear named error, never a silent CPU fallback presented as the requested backend."
- **Worktree:** /home/volmarr/aesir-team-09, branch yrsa/aesir-team-09
- **Base:** banked seat main c9f0047ecd117d623bf72d22d38421ae853532eb (A-031; 31 of 216). Branch reset --hard onto it; CAMPAIGN_STATE.md/hidden_files backed up to /tmp/t09_a032_backup first and verified preserved.
- **Team:** lead + 6 Mythic Engineering sub-agents, all mustered (no rate limit). Workers covered registry/policy recon, surface design, test plan, honesty review, ledger/state templates, banking checklist; the lead integrated and wrote all code.

## What was built

- aesir_engine/core/backend_config.mojo (new, 262 lines): the A-032 surface proper.
  - One vocabulary — auto/cpu/vulkan/hip/npu — with is_backend_selection (exact), normalize_backend_selection (trim + lowercase, then validate; anything else raises a named error listing the valid set; legacy/foreign names cuda/metal/amd/hailo10h/max are NOT Z13 selections on this surface), and backend_selection_values.
  - apply_backend_override: config + CLI precedence — explicit CLI > config file > built-in auto default; only the winning value is validated, returned canonical.
  - resolve_backend_selection(selection, registry, npu_execution_proven) — pure/deterministic resolution over the A-009 registry (never re-probes). Explicit cpu/vulkan/hip resolve only to that backend and only when present/degraded; absent raises `backend '<name>' unavailable: <Runtime> <status> (<detail>); no fallback applied -- the requested backend was not substituted`. Software-only Vulkan stays absent via the A-009 llvmpipe refusal, reason carried.
  - NPU honesty gate (from A-017): explicit npu with XRT present but execution unproven raises the named honesty error ("NPU execution is not proven -- XRT presence only, no NPU execution is claimed; no fallback applied"); with the proven flag set it resolves to XRT and says why.
  - auto follows the A-017 accelerator-first order (NPU -> HIP -> Vulkan -> CPU, GPU class preferring HIP as in the placement policy), skips the NPU while execution is unproven, records every skip in the resolution reason, discloses CPU as "spillover", and raises only when no backend at all is available.
  - BackendResolution.line() always ends "[selection only; execution not claimed]" — selection is intent, never execution evidence.
- aesir_engine/config.mojo: hardware.acceleration_backend now also accepts vulkan and hip (the two Z13 selections the file vocabulary was missing); all previously valid values unchanged.
- aesir_engine/cli/options.mojo: validate_acceleration_backend accepts vulkan/hip; the --accel error message now lists the Z13 selections first.
- aesir_engine/cli/help.mojo: --accel help line lists auto|cpu|vulkan|hip|npu first.
- aesir_engine/tests/test_backend_config.mojo (new, 245 lines): six E-MASTER cases (below), all against fake registries + the real config parser and CLI parser.
- aesir_engine/tests/run_all.mojo: import + six run_case registrations (cli.backend_config_*) after the device_policy group; finish pin re-pinned 362 -> 368 with the A-032 comment.
- No README touched. No Docker. No merge/push to main (keeper banks in roadmap order).

## Cases (all PASS in hidden_files/a032_run_all.log)

1. cli.backend_config_vocabulary — the 5-value set exact; canonical/case/whitespace normalization; cuda/metal/amd/hailo10h/max/gpu/xrt/empty all rejected with the valid set named.
2. cli.backend_config_file_and_cli_surface — config file parses all five selections via parse_config_json and rejects `tpu` by name; CLI --accel vulkan parses, --accel tpu rejected listing vulkan+hip; precedence CLI > file > auto proven via apply_backend_override.
3. cli.backend_config_explicit_resolution — cpu/vulkan/hip resolve to CPU/Vulkan/HIP on an all-present fake registry; hip line carries device identity + the selection-only marker; a degraded HIP record resolves as degraded and the line discloses it.
4. cli.backend_config_absent_fail_closed — vulkan/hip/npu/cpu against an all-absent registry each raise the named unavailable error (request + status + registry detail + no-fallback wording); auto with zero backends fails closed; software-only (llvmpipe) Vulkan fails closed with the software reason.
5. cli.backend_config_npu_honesty_gate — XRT present + unproven: explicit npu raises the honesty error (not proven / no execution claimed / no fallback); auto never lands on XRT and logs the presence-only skip; with the proven flag, npu and auto resolve to XRT with the reason stated.
6. cli.backend_config_auto_order — HIP preferred over Vulkan; Vulkan when HIP absent (skip logged); CPU only as disclosed spillover; identical inputs produce an identical resolution line (determinism).

## Suite counts (read from log files, never memory)

- Baseline on base c9f0047 (per task pin): 359 passed / 1 failed / 2 skipped / 362 total; sole failure the pre-existing gguf.tensor_directory_interface (J-022 drift, tolerated); skips the 2 pre-declared.
- A-032 run (hidden_files/a032_run_all.log, sha256 ec0ce92ce74d151129f71c745c1f2cc8e443f7987b455c7fc023ec7ca8a528c0): **365 passed / 1 failed / 2 skipped / 368 total** — exactly baseline plus the six new cases, all PASS; sole failure the same tolerated J-022 drift; zero regressions; no rotating-flake failure occurred this run. Seat-gate shape: all 6 shims staged incl. libaesir_aff, target gfx1151. MOJO_EXIT=1 is the suite normal signal for the one tolerated failure.
- First attempt note: the first launch failed at parse time (0 cases run) because the lead's sed insertion of the new import block landed inside the test_device_policy import parentheses; fixed by moving the closing paren, relaunched — the log above is the corrected full run. Recorded here, not hidden.

## Bugs found / fixed

- Lead tooling bug (not product code): run_all import insertion misplacement, above — fixed in-slice before the real run.
- No product bugs discovered. No unfixed bugs; no new next-work items. (Carried item from A-023 remains open and is restated in CAMPAIGN_STATE.md: the A-019 zero-copy shim 4096-slot accounting hole, belonging to a zero-copy/shim slice.)

## Files

- aesir_engine/core/backend_config.mojo sha256 dfa3545e2e8d6b28e94756c6149c024a947548e9e98ceeced5444136c3d5e0fe
- aesir_engine/tests/test_backend_config.mojo sha256 767163c5f8d3f3ec8e42872e8455dc0295aa94bbdd2533524b28af7aa4866e1b
- Log: hidden_files/a032_run_all.log; runner: hidden_files/run_a032.sh (seat-gate A-031 shape, team-09 paths)
