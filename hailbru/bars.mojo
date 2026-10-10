# HAILBRU BAR info parsing (H063).
#
# Parses BAR start/size/flags from the sysfs `resource` file. Handles the
# classic 64-bit BAR pairing bug explicitly (a 64-bit memory BAR consumes
# two resource entries; the upper-half entry is zero-sized and must be
# paired, not treated as a separate BAR).

from hailbru.errors import herror
from hailbru.syscall import read_file_str
from hailbru.util import (
    is_power_of_two,
    parse_u64_hex,
    split_lines,
    split_ws,
)


# linux/ioport.h IORESOURCE bits (public UAPI constants).
def IORESOURCE_IO() -> UInt64:
    return UInt64(0x100)


def IORESOURCE_MEM() -> UInt64:
    return UInt64(0x200)


def IORESOURCE_PREFETCH() -> UInt64:
    return UInt64(0x1000)


def IORESOURCE_MEM_64() -> UInt64:
    return UInt64(0x100000)


struct BarInfo:
    var index: Int
    var start: UInt64
    var size: UInt64
    var flags: UInt64
    var present: Bool

    def __init__(
        out self, index: Int, start: UInt64, size: UInt64,
        flags: UInt64, present: Bool,
    ):
        self.index = index
        self.start = start
        self.size = size
        self.flags = flags
        self.present = present

    def is_mem(self) -> Bool:
        return (self.flags & IORESOURCE_MEM()) != UInt64(0)

    def is_io(self) -> Bool:
        return (self.flags & IORESOURCE_IO()) != UInt64(0)

    def is_64bit(self) -> Bool:
        return (self.flags & IORESOURCE_MEM_64()) != UInt64(0)

    def is_prefetch(self) -> Bool:
        return (self.flags & IORESOURCE_PREFETCH()) != UInt64(0)


def _parse_resource_line(line: String, index: Int) raises -> BarInfo:
    # Parses one "start end flags" line into a FRESH BarInfo (move, no copy).
    var parts = split_ws(line)
    if len(parts) != 3:
        raise herror(
            "BarParseFailed",
            "resource line " + String(index) + " has "
            + String(len(parts)) + " fields (want 3): '" + line + "'",
        )
    var start: UInt64
    var end: UInt64
    var flags: UInt64
    try:
        start = parse_u64_hex(parts[0])
        end = parse_u64_hex(parts[1])
        flags = parse_u64_hex(parts[2])
    except e:
        raise herror(
            "BarParseFailed",
            "resource line " + String(index) + ": " + String(e),
        )
    var size = UInt64(0)
    var present = False
    if end >= start and not (start == UInt64(0) and end == UInt64(0)):
        size = end - start + UInt64(1)
        present = True
    return BarInfo(index, start, size, flags, present)


def parse_resource(
    arch: String, sysfs_root: String, bdf: String
) raises -> List[BarInfo]:
    # Raises BarParseFailed on malformed content.
    var path = sysfs_root + "/bus/pci/devices/" + bdf + "/resource"
    var text: String
    try:
        text = read_file_str(arch, path, 4096)
    except e:
        raise herror(
            "BarParseFailed",
            "cannot read " + path + ": " + String(e),
        )
    var lines = split_lines(text)
    # Collect non-empty lines with their BAR indices first (fresh
    # parsing per line keeps every BarInfo a move, never a copy).
    var wanted = List[Int]()
    var ltexts = List[String]()
    for i in range(len(lines)):
        if lines[i].byte_length() > 0:
            wanted.append(i)
            ltexts.append(lines[i])
    # 64-bit pairing: a 64-bit memory BAR at index i consumes entry i+1
    # (the upper half, conventionally zero-sized). Pair them; never emit
    # the upper half as its own BAR. Lookahead parses the next line
    # fresh — the classic pairing bug is tested explicitly (H063).
    var out = List[BarInfo]()
    var k = 0
    while k < len(wanted):
        var idx = wanted[k]
        var b = _parse_resource_line(ltexts[k], idx)
        var consumed_pair = False
        if b.present and b.is_mem() and b.is_64bit() and k + 1 < len(wanted):
            var upper = _parse_resource_line(ltexts[k + 1], wanted[k + 1])
            if upper.start == UInt64(0) and upper.size == UInt64(0):
                consumed_pair = True
        out.append(b^)
        k += 1
        if consumed_pair:
            k += 1
    return out^


def bars_sane(bars: List[BarInfo]) raises -> Bool:
    # Sanity per H063: every present memory BAR is power-of-two and >= 4KB.
    # Raises BarParseFailed naming the offending BAR.
    for i in range(len(bars)):
        ref b = bars[i]
        if b.present and b.is_mem():
            if not is_power_of_two(b.size):
                raise herror(
                    "BarParseFailed",
                    "BAR" + String(b.index) + " size "
                    + String(b.size) + " not power-of-two",
                )
            if b.size < UInt64(4096):
                raise herror(
                    "BarParseFailed",
                    "BAR" + String(b.index) + " size "
                    + String(b.size) + " < 4KB",
                )
    return True
