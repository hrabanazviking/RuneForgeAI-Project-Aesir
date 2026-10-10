# H021 — ARMVEGR package root (Domain D1: ARM64 CPU kernels, pure Mojo).
#
# ARMVEGR ("ARM-vegr", way/power of ARM) is the hand-tuned NEON/SIMD kernel
# library and CPU inference backend for the Hailo-10 campaign's F1 fallback
# engine. Pure Mojo only: Mojo stdlib + POSIX via external_call. No PCIe,
# no device nodes, no CUDA anywhere in this package (H021 acceptance).

from std.ffi import external_call


def armvegr_version() -> String:
    return "0.2.0"


def neon_available() -> Bool:
    # Runtime NEON/ASIMD check via getauxval(AT_HWCAP). AT_HWCAP = 16;
    # HWCAP_ASIMD is bit 1 on AArch64. No file I/O, no libraries.
    var hwcap = external_call["getauxval", UInt64, UInt64](UInt64(16))
    return (hwcap & UInt64(2)) != UInt64(0)
