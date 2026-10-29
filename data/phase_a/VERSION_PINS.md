# Version Pins — Phase A (MÍMISBRUNNR)

**Recorded:** 2026-10-10
**Host:** purpleviking1 (Mimir), Raspberry Pi 5, aarch64 (user `pi`)

Every version below was read from the machine, with the command that
produced it. Re-verification procedure at the bottom.

| Item | Version | Read from |
|---|---|---|
| Mojo toolchain | 1.1.0 (8189361e) | `mojo --version` → `Mojo 1.1.0 (8189361e)` |
| pixi (package manager) | 0.81.0 | `pixi --version` → `pixi 0.81.0` |
| Mojo channel | `https://conda.modular.com/max` (+ conda-forge) | `~/mojo-dev/pixi.toml` |
| OS | Debian GNU/Linux 12 (bookworm) | `cat /etc/os-release` |
| Kernel | 6.12.109+rpt-rpi-2712 | `uname -a` / `/proc/version` (built 2026-09-11, gcc 12.2.0) |
| Kernel config source | `/boot/config-6.12.109+rpt-rpi-2712` | file presence + greps |
| Python (tests only) | 3.11.2 | `python3 --version` on Mimir |
| Python (forge host) | 3.12.3 | `python3 --version` on forge VM |
| hailo1x_pci driver | 5.3.0, GPL v2, via DKMS | `modinfo hailo1x_pci` → `version: 5.3.0`, `filename: .../updates/dkms/hailo1x_pci.ko.xz` |
| Firmware set | 17 files, 112295583 bytes under `/lib/firmware/hailo/hailo10h/` | `find` + `sha256sum` (see `data/phase_a/firmware_catalogue.json`) |
| fitImage contents | Yocto Poky / kernel 5.15.32 / board hailo10-m2 | `strings fitImage` |
| gcc (host tool) | 12.2.0 (Debian 12.2.0-14+deb12u1) | `gcc --version` |
| GNU ld (host tool) | 2.40 | `ld --version` |
| git (host tool) | 2.39.5 | `git --version` |
| hailort-drivers (study only) | commit `309eb10` ("Update third-party-packages.md for v5.4.0") | `git log --oneline -1` in study clone |
| HailoRT (study only) | commit `f519590` ("v5.4.0") | `git log --oneline -1` in study clone |

## Firmware catalogue

`/lib/firmware/hailo` holds only the `hailo10h/` subdirectory (17 files).
Each file is catalogued by filename, byte size, and SHA-256 in
`data/phase_a/firmware_catalogue.json`. No firmware bytes are copied into
the repo (L7) — hashes and sizes only. Total: 112295583 bytes.

## Re-verification procedure (under 5 minutes)

Run on Mimir (each under a minute):

1. `mojo --version` → expect `Mojo 1.1.0 (8189361e)`
2. `uname -r` → expect `6.12.109+rpt-rpi-2712`
3. `cat /etc/os-release | grep VERSION_ID` → expect `12`
4. `python3 --version` → expect `3.11.2`
5. `modinfo hailo1x_pci | grep '^version'` → expect `5.3.0`
6. `find /lib/firmware/hailo -type f | wc -l` → expect `17`
7. `sha256sum /lib/firmware/hailo/hailo10h/fitImage | cut -d' ' -f1` →
   expect `47bf94a076349631162f97708dd1647d1cd452dafc1a67393cd7e42f2bdbedd5`
8. `grep -E '^#? ?CONFIG_VFIO |^#? ?CONFIG_UIO_PCI_GENERIC' /boot/config-$(uname -r)` →
   expect both `is not set` (mechanism verdict unchanged)
9. `ls /dev/hailo* /dev/vfio` → expect "no such file" for both
   (driver state unchanged since census)
