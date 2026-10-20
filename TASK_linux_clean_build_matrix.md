# AES500-331 — Linux clean-build matrix contract

## Objective and owner

Define reproducible clean compile smoke targets for the native CLI and master
test runner on the project's declared Linux x86-64 toolchain. The owner is the
build/portability domain.

## Supported evidence scope

- The checkout declares Pixi platform `linux-64` and CI uses one
  `ubuntu-latest` runner with a pinned Pixi release.
- Clean CLI and master-runner builds use the repository's pinned Mojo toolchain
  and explicit output paths outside the repository.
- This is one-host Linux build evidence. It does not establish a multi-distro,
  libc, CPU-generation, macOS, Windows, or cross-compilation matrix.
- Runtime hardware probing and physically available CUDA remain separate from
  successful compilation with target `sm_89`.

## Acceptance and exclusions

Record OS/kernel, architecture, Pixi/Mojo versions, exact commands, exit status,
and artifact hashes. Build from a clean temporary output location, run repo
truth/docs checks, and keep any missing platform rows marked unsupported or
unverified. Do not broaden compatibility claims from one host.
