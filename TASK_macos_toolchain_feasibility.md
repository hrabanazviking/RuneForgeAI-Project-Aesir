# AES500-351 — macOS toolchain feasibility contract

## Objective and owner

Determine whether macOS can be declared a supported build target using a native
macOS runner and the pinned Pixi/Mojo/MAX toolchain. The owner is
portability/build engineering.

## Decision rules

- The current project declares `linux-64`; Linux evidence does not establish
  macOS support.
- Feasibility requires native Apple Silicon and/or Intel runner identities,
  successful pinned-toolchain install, clean CLI and test builds, test
  execution, and platform-specific FFI/filesystem/process/socket evidence.
- Do not infer Metal execution, CUDA absence behavior, or accelerator support
  from compile success alone.
- Until those gates run, leave macOS unsupported/unverified and do not edit the
  declared platform list.

## Exclusions and acceptance

This slice is an availability and evidence contract only. Record runner and
toolchain gaps; make no compatibility claim or production change. Revisit when
native macOS runners are available.
