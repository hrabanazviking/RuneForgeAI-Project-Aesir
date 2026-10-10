# HAILBRU mechanism probing + selection (H064/H065).
#
# Probes VFIO and uio_pci_generic availability and selects the driver
# mechanism per the H004 fallback order: VFIO first, UIO second, never UIO
# when VFIO works. On Mimir's kernel both are absent (H004 NO-GO,
# H012/H013 probes); the selector then returns "sysfs-recon" — the
# recon-only posture H004 permits, honestly NOT named a driver mechanism.

from hailbru.errors import herror
from hailbru.syscall import file_exists, list_dir


struct MechReport:
    var name: String
    var available: Bool
    var reason: String

    def __init__(out self, name: String, available: Bool, reason: String):
        self.name = name
        self.available = available
        self.reason = reason


def probe_vfio(arch: String, dev_root: String) -> MechReport:
    # dev_root is normally "/dev" (injectable for tests).
    if file_exists(arch, dev_root + "/vfio/vfio"):
        return MechReport("vfio", True, "/dev/vfio/vfio present")
    return MechReport(
        "vfio",
        False,
        "no /dev/vfio — CONFIG_VFIO not set on this kernel "
        "(H004 MECHANISM_VERDICT.md, H012 vfio_probe.json)",
    )


def probe_uio(arch: String, dev_root: String) -> MechReport:
    var names: List[String]
    try:
        names = list_dir(arch, dev_root)
    except e:
        return MechReport(
            "uio", False, "cannot list " + dev_root + ": " + String(e)
        )
    var found = List[String]()
    for i in range(len(names)):
        var n = names[i]
        if n.byte_length() >= 4:
            var is_uio = True
            var want = "uio"
            var nb = List[UInt8]()
            for b in n.bytes():
                nb.append(b)
            var wb = List[UInt8]()
            for b in want.bytes():
                wb.append(b)
            for k in range(4):
                if nb[k] != wb[k]:
                    is_uio = False
                    break
            if is_uio:
                found.append(n)
    if len(found) > 0:
        return MechReport(
            "uio", True,
            "found " + String(len(found)) + " /dev/uio node(s)",
        )
    return MechReport(
        "uio",
        False,
        "no /dev/uio* nodes — CONFIG_UIO_PCI_GENERIC not set "
        "(H004 MECHANISM_VERDICT.md, H013 uio_probe.json)",
    )


def select_mechanism(vfio_ok: Bool, uio_ok: Bool) -> String:
    # Pure decision function (H065 acceptance: ordering tested with mocked
    # availability). VFIO tried first, UIO second, never UIO when VFIO
    # works.
    if vfio_ok:
        return "vfio"
    if uio_ok:
        return "uio"
    return "sysfs-recon"
