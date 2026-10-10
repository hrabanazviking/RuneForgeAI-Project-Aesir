# HAILBRU package root (Domain D2: Hailo-10 userspace driver, pure Mojo).
#
# HAILBRU ("Hail-brú", hail-bridge) is the userspace PCIe driver for the
# Hailo-10 NPU on Mimir. Per L12 it is the ONLY domain that opens /dev
# nodes, mmaps PCI BARs, or issues ioctls — all through hailbru/syscall.
# Pure Mojo only: Mojo stdlib + POSIX via external_call. No model
# semantics, no compute math, no CUDA anywhere in this package.
#
# Mechanism status (H004 NO-GO): VFIO/UIO paths are implemented but
# F3-banked on Mimir's kernel; the sysfs-recon paths execute for real.


def hailbru_version() -> String:
    return "0.4.0"


def hailbru_domain() -> String:
    return "D2"
