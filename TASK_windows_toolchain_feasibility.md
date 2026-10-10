# AES500-341 — Windows toolchain feasibility contract

## Objective and owner

Determine whether Windows can be declared as a supported build target, using
repository metadata, CI runners, and actual native toolchain availability. The
owner is portability/build engineering.

## Decision rules

- Do not add Windows to supported platforms based on Wine or source inspection.
- Feasibility requires an available native Windows runner and the pinned Pixi,
  Mojo, and MAX toolchain; a clean CLI build; a master test execution; and
  platform-specific subprocess/path/FFI coverage.
- Until those gates run, record Windows as unverified and keep the current
  `linux-64` platform declaration unchanged.
- Any eventual Windows support requires a separate CI matrix change and
  runtime evidence for DLL loading, filesystem semantics, sockets, signals,
  process control, and CUDA/MAX availability.

## Exclusions and acceptance

This feasibility slice does not add Windows support or change platform
metadata. Record available host tools and workflow platforms; identify the
missing native runner/toolchain as the blocking evidence; do not treat Wine as
native execution. Revisit only when a Windows runner can run the pinned toolchain.
