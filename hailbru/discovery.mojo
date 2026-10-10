# HAILBRU PCI discovery (H061).
#
# Enumerates <sysfs_root>/bus/pci/devices via getdents64 and matches the
# Hailo device by vendor/device ID — zero hardcoded addresses. The sysfs
# root is injectable so the negative tests run against scratch trees with
# no hardware (H061 acceptance criteria).

from hailbru.errors import herror
from hailbru.syscall import errno_name, errno_now, list_dir, read_file_str
from hailbru.util import is_hex_digit, parse_u16_hex, trim


struct Bdf:
    var domain: Int
    var bus: Int
    var dev: Int
    var func: Int
    var text: String

    def __init__(
        out self, domain: Int, bus: Int, dev: Int, func: Int, text: String
    ):
        self.domain = domain
        self.bus = bus
        self.dev = dev
        self.func = func
        self.text = text


def _hexn(bs: List[UInt8], pos: Int, count: Int) -> Int:
    var v = 0
    for i in range(count):
        var b = bs[pos + i]
        var c = Int(b)
        var d = 0
        if c >= 48 and c <= 57:
            d = c - 48
        elif c >= 65 and c <= 70:
            d = c - 55
        else:
            d = c - 87
        v = (v << 4) | d
    return v


def parse_bdf(s: String) raises -> Bdf:
    # Strict DDDD:BB:DD.F, lowercase or uppercase hex. Raises BadBdf.
    var t = trim(s)
    var bs = List[UInt8]()
    for b in t.bytes():
        bs.append(b)
    if len(bs) != 12:
        raise herror("BadBdf", "wrong length: '" + s + "'")
    for i in range(4):
        if not is_hex_digit(bs[i]):
            raise herror("BadBdf", "bad domain digit: '" + s + "'")
    if bs[4] != 58:
        raise herror("BadBdf", "expected ':' at 4: '" + s + "'")
    for i in [5, 6]:
        if not is_hex_digit(bs[i]):
            raise herror("BadBdf", "bad bus digit: '" + s + "'")
    if bs[7] != 58:
        raise herror("BadBdf", "expected ':' at 7: '" + s + "'")
    for i in [8, 9]:
        if not is_hex_digit(bs[i]):
            raise herror("BadBdf", "bad device digit: '" + s + "'")
    if bs[10] != 46:
        raise herror("BadBdf", "expected '.' at 10: '" + s + "'")
    if not is_hex_digit(bs[11]):
        raise herror("BadBdf", "bad function digit: '" + s + "'")
    return Bdf(
        _hexn(bs, 0, 4),
        _hexn(bs, 5, 2),
        _hexn(bs, 8, 2),
        _hexn(bs, 11, 1),
        t,
    )


def discover(
    arch: String, sysfs_root: String, vendor: UInt16, device: UInt16
) raises -> String:
    # Returns the BDF text of the single device matching vendor:device.
    # Raises DeviceNotFound (zero matches) or MultipleDevices (>1).
    # Malformed directory names are skipped, never fatal (H061).
    var devdir = sysfs_root + "/bus/pci/devices"
    var names: List[String]
    try:
        names = list_dir(arch, devdir)
    except e:
        raise herror(
            "BadSysfs",
            "cannot enumerate " + devdir + ": " + String(e),
        )
    var hits = List[String]()
    for i in range(len(names)):
        var name = names[i]
        var bdf: Bdf
        try:
            bdf = parse_bdf(name)
        except:
            continue
        var vpath = devdir + "/" + name + "/vendor"
        var dpath = devdir + "/" + name + "/device"
        var v: UInt16
        var d: UInt16
        try:
            v = parse_u16_hex(read_file_str(arch, vpath, 16))
            d = parse_u16_hex(read_file_str(arch, dpath, 16))
        except:
            continue
        if v == vendor and d == device:
            hits.append(bdf.text)
    if len(hits) == 0:
        raise herror(
            "DeviceNotFound",
            "no PCI device with vendor:device "
            + String(Int(vendor)) + ":" + String(Int(device))
            + " under " + devdir,
        )
    if len(hits) > 1:
        raise herror(
            "MultipleDevices",
            "expected exactly one matching device, found "
            + String(len(hits)),
        )
    return hits[0]
