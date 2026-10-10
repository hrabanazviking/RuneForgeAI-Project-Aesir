# macOS toolchain feasibility baseline — 2026-10-10

AES500-352 baseline at source revision
`f46bc896714f39cfac164eb2e69af7f86b3fde02`.

- Project Pixi platforms: `linux-64` only.
- GitHub Actions workflow: `ubuntu-latest` only; no macOS runner or matrix
  entry.
- Current host reports Linux x86-64; no native macOS runner is available in
  this execution environment.
- No macOS Pixi/Mojo/MAX install, build, tests, Metal, filesystem, process,
  socket, or FFI evidence is present in this checkout.

macOS remains unverified. This is source/environment inventory only; it makes
no claim about current external toolchain support.
