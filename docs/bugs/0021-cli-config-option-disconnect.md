# Bug 0021: CLI Configuration and Option Connections Are Unreachable or Ignored

## Severity

P0 truth-boundary defect and P1 CLI usability defect.

## Owning Domains

- `aesir_engine/main.mojo` — process entry behavior
- `aesir_engine/cli/commands.mojo` — command grammar and dispatch
- `aesir_engine/cli/options.mojo` — option parsing and explicit-value tracking
- `aesir_engine/config.mojo` — configuration loading and validation
- `aesir_engine/cli/help.mojo` — public command contract

## Symptom

The repository ships `aesir.config.json`, a configuration parser, a documented
`aesir config` help entry, `--config`, and `--accel`, but the built CLI does not
connect those surfaces:

1. `aesir config` exits with `unknown command: config`.
2. `--config <path>` is parsed but no file is opened or validated.
3. `--accel <backend>` is parsed but does not control or reject the runtime
   path. A non-CPU request can reach the CPU single-shot path, violating the
   fail-closed hardware truth boundary.
4. General command dispatch only removes `--max-tokens` from prompt assembly;
   other recognized options can become literal prompt text.
5. Invoking `aesir` without arguments silently rewrites the request to `serve`,
   which is explicitly unsupported, so the default invocation crashes instead
   of presenting an actionable interface.
6. Help describes configuration and acceleration intent inconsistently across
   `cli/commands.mojo` and `cli/help.mojo`.

## Reproduction

From a clean checkout:

```text
pixi run mojo build aesir_engine/main.mojo -o /tmp/aesir-cli-audit
/tmp/aesir-cli-audit config
```

Observed result:

```text
Unhandled exception caught during execution: unknown command: config
```

Static dispatch tracing shows `CLIOptions.config_path` and
`CLIOptions.accel_backend` are populated by `parse_cli_options()` but never
read before `run_single_shot()`.

## Violated Invariants

- Parsed public options must either affect the stated operation or be rejected.
- Explicit accelerator selection must never execute on a different backend.
- Documented commands must be reachable through the process entry point.
- CLI control tokens must never leak into model prompt text.
- Default invocation must produce a stable, useful result.

## Desired End State

1. No-argument invocation prints general help and exits successfully.
2. `aesir config [--config <path>] [--format text|json]` reads the selected
   relative or caller-supplied path, validates the full tracked schema, and
   prints the normalized effective configuration.
3. Missing, unreadable, malformed, unknown-key, and invalid-range configuration
   values fail nonzero with contextual errors.
4. Command parsing separates flags and their values from positional model and
   prompt arguments for the documented grammar.
5. `auto` and `cpu` resolve to the verified CPU path on the current build;
   explicit CUDA, Metal, Intel, AMD, NPU, or MAX requests fail closed before
   model loading until a real backend is connected and proved.
6. A caller-supplied `--config` is loaded and its acceleration intent is
   enforced. CLI `--accel` explicitly overrides that file value.
7. Help, tests, ledger evidence, TODO, and DEVLOG describe the same behavior.

## Boundaries

- This slice does not claim a physical accelerator, live TUI telemetry,
  experimental inference integration, or general persistent settings storage.
- This slice does not add a general JSON library. It hardens and connects the
  tracked configuration schema, with strict rejection outside that schema.
- No source, artifact, or historical file is deleted.

## Verification

- Unit tests for explicit option tracking, configuration parsing, file loading,
  override precedence, invalid values, and prompt-token separation.
- Built-CLI smoke tests for no arguments, `config`, explicit config path,
  invalid config path, CPU selection, and unsupported backend rejection.
- Full counted suite, native build, deliberate negative control, repository
  consistency check, `git diff --check`, and hosted CI.
