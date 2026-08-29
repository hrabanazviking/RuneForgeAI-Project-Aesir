# Bug 0022: CLI Accepts Options That Have No Operational Effect

## Severity

P0 truth-boundary defect and P1 command-contract defect.

## Owning Domains

- `aesir_engine/cli/options.mojo` — accepted option grammar
- `aesir_engine/cli/commands.mojo` — command-specific applicability
- `aesir_engine/cli/repl.mojo` — single-shot execution and output
- `aesir_engine/config.mojo` — file-backed generation/safety intent
- owning runtime domains for Modelfile, TUI, thinking, SKÁLDBRØÐIR, and
  experimental paradigms

## Symptom

After Bug 0021, option tokens can no longer leak into prompt text and explicit
acceleration intent is enforced. However, the parser still accepts the
following values without their stated side effects on a single-shot run:

- `--verbose`
- `--format json`
- `--keepalive`
- `--modelfile`
- `--raw`
- `--insecure`
- `--skaldbrodir`
- `--thinking`
- `--cia`
- `--wic`
- `--nsfi`
- `--tui`

An explicitly loaded config validates sampling, safety, interface, and
experimental fields, but single-shot execution currently enforces only its
acceleration backend. This creates the same class of defect in a subtler form:
the command succeeds while caller intent is ignored.

## Violated Invariants

- Every accepted option must be applied by its owning operation or rejected
  before side effects begin.
- Machine-readable output must be valid for the selected format and must not be
  mixed with diagnostic text.
- Network/lifecycle flags must not imply meaning on a local one-shot command.
- Experimental or safety toggles must not imply engine integration when only a
  local primitive exists.
- Configuration precedence must be explicit and testable for every connected
  field.

## Desired End State

1. Track explicit presence separately from default values for every option.
2. Define a command-specific applicability matrix.
3. Connect `--verbose` to diagnostic emission and `--format` to stable text/JSON
   single-shot output with correct escaping.
4. Apply supported configuration sampling values through `GenerationConfig`
   and prove deterministic precedence and output.
5. Connect Modelfile settings only after the selected model/store semantics are
   real.
6. Reject `--keepalive` and `--insecure` on local single-shot execution; reserve
   them for process/service or distribution operations.
7. Connect or explicitly reject raw/chat-template, TUI, safety, thinking, and
   experimental intent until their real runtime owners exist.
8. Add table-driven tests covering every accepted option on every implemented
   command, including stable nonzero failures for inapplicable combinations.

## Boundaries

- Rejection is a truthful intermediate state, not completion of the feature
  named by an option.
- This bug does not promote service lifecycle, model storage, physical
  acceleration, TUI telemetry, or experimental inference capabilities.
- No function, file, module, or data is deleted.

## Verification Plan

- Command applicability matrix tests.
- Single-shot text/JSON output tests against a caller-controlled result
  formatter.
- Configuration-to-`GenerationConfig` conversion and precedence tests.
- Negative tests for every inapplicable option/command pairing.
- Master suite, native build, deliberate negative control, consistency check,
  `git diff --check`, built-CLI smoke tests, and hosted CI.

## Truth-Boundary Resolution — August 29, 2026

- `CLIOptions` now records explicit presence for every parsed option.
- Single-shot dispatch has a command-applicability gate. Every accepted option
  without a connected single-shot owner raises before model loading.
- Explicit config files must keep unsupported fields neutral; non-neutral
  sampling, safety, experimental, TUI, thread, NPU, or GPU-layer intent raises
  instead of being ignored.
- The tracked example now uses neutral values for all unconnected behavior.
- Master verification passed with **132 passed / 0 failed / 1 skipped / total
  133** and the native CLI builds cleanly.

The fabricated-success defect is resolved. The feature work remains open:
rejections are replaced only when each option's real owner is implemented and
verified.
