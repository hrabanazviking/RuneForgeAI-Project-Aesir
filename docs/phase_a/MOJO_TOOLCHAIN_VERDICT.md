# Mojo Toolchain Verdict — H001

**Verdict: NATIVE-WORKS**

**Date:** 2026-10-10
**Machine:** Mimir (purpleviking1), Raspberry Pi 5, aarch64
**OS:** Debian GNU/Linux 12 (bookworm)
**Kernel:** 6.12.109+rpt-rpi-2712

## Toolchain provenance

The official Mojo toolchain is installed natively for linux-aarch64 via
Modular's official pixi channel (`https://conda.modular.com/max`):

- **Mojo version:** 1.1.0 (8189361e)
- **Package manager:** pixi 0.81.0 (`~/.pixi/bin/pixi`)
- **Project:** `~/mojo-dev/pixi.toml` — platforms `["linux-aarch64"]`,
  dependency `mojo = ">=1.1.0,<2"`, channels `conda.modular.com/max` + conda-forge
- **Shim:** `/usr/local/bin/mojo` (99-byte shell script, installed 2026-10-10
  02:33, before this campaign):
  `exec ~/.pixi/bin/pixi run --manifest-path ~/mojo-dev/pixi.toml mojo "$@"`

## Proof

`hello.mojo` (using Mojo 1.1.0 `def` syntax — the `fn` keyword was removed in
Mojo 1.x):

```mojo
def main():
    print("hailo hello from mojo on mimir")
```

- `mojo build -o hello hello.mojo` → exit 0, wall-clock 2860 ms
- Binary: ELF 64-bit LSB pie executable, ARM aarch64, dynamically linked
- `./hello` → printed `hailo hello from mojo on mimir`, exit 0

## Attempted alternative (failed, documented)

The `get.modular.com` magic bootstrapper was also attempted on the same date.
It failed: the bootstrapper depends on an apt package named `modular`, which
is not locatable on this Debian system (no Modular apt source configured), so
`magic` was never installed. Exit code was 0 but no installation occurred.
Full transcript in `data/phase_a/toolchain_native_attempt.log`.

## Consequence for the campaign

- D1 (ARMVEGR kernels), the HAILBRÚ driver work, and all Mojo-on-Pi slices
  proceed on the native toolchain. No cross-compilation is *required*, but H002
  still documents the fallback so the project is never single-pathed.
- Mojo language note: this is Mojo 1.1.0 — write `def`, not `fn`.
