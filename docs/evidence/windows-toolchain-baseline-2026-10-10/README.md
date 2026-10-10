# Windows toolchain feasibility baseline — 2026-10-10

AES500-342 baseline at source revision
`a5aba963f332ce5efd785209f471880bef456090`.

- Pixi workspace declares only `linux-64`.
- GitHub Actions uses one `ubuntu-latest` runner; no Windows job or matrix
  entry exists in `.github/workflows/ci.yml`.
- This host has a Wine executable but no `pwsh` or MinGW cross compiler.
  Wine does not provide a native Windows runner or establish Mojo/MAX support.
- There is no Windows build, test, DLL, path, socket, subprocess, signal, or
  CUDA evidence in this checkout.

This baseline is repository/host inventory only. Windows remains unverified;
no Windows compatibility claim or platform edit follows from these facts.
