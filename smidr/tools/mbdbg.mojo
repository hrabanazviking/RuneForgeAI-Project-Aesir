# H102 debug tool: single IDENTIFY with full register visibility.
# Usage: mbdbg <sysfs_root> <bdf>
# Dumps pre/post register state around one mailbox transaction so the
# exact firmware reaction (or lack thereof) is observable.

from hailbru.errors import herror
from hailbru.regs import (
    BarMapping,
    map_sysfs_resource,
    reg_read32,
    unmap_bar,
)
from hailbru.syscall import os_sleep_ms, proc_cmdline
from smidr.mailbox import (
    MB_CMD_SLOT,
    MB_FWCTL_DONE_BIT,
    MB_IRQ_STATUS_REG,
    MB_READY_FLAG_10H,
    MB_RESP_SLOT,
    build_identify_request,
)


def _hex(v: UInt32) -> String:
    var s = String("")
    var x = Int(v)
    for i in range(8):
        var d = (x >> (28 - 4 * i)) & 0xF
        var ch = UInt8(48 + d) if d < 10 else UInt8(87 + d)
        s += String(chr(Int(ch)))
    return "0x" + s


def _dump(bar0: BarMapping, bar4: BarMapping, tag: String) raises:
    print(
        tag + " 018C=" + _hex(reg_read32(bar0, MB_IRQ_STATUS_REG()))
        + " 0188=" + _hex(reg_read32(bar0, 0x0188))
        + " B4+1754=" + _hex(reg_read32(bar4, MB_READY_FLAG_10H()))
        + " B4+0000=" + _hex(reg_read32(bar4, MB_CMD_SLOT()))
        + " B4+0640=" + _hex(reg_read32(bar4, MB_RESP_SLOT()))
    )


def main() raises:
    var args = proc_cmdline("aarch64")
    if len(args) < 3:
        raise herror("BadArgs", "usage: mbdbg <sysfs_root> <bdf>")
    var arch = "aarch64"
    var bar0 = map_sysfs_resource(arch, args[1], args[2], 0, 16384, True)
    var bar4 = map_sysfs_resource(arch, args[1], args[2], 4, 16384, True)
    _dump(bar0, bar4, "pre ")
    var req = build_identify_request()
    # command slot: len + payload
    from hailbru.regs import reg_write32
    reg_write32(bar4, MB_CMD_SLOT(), UInt32(len(req)))
    var p = bar4.ptr()
    for i in range(len(req)):
        p[unsafe_offset=MB_CMD_SLOT() + 4 + i] = req[i]
    _dump(bar0, bar4, "cmd ")
    reg_write32(bar4, MB_READY_FLAG_10H(), UInt32(1))
    print("doorbell rung (0x1 to BAR4+0x1754)")
    for i in range(30):
        os_sleep_ms(arch, 100)
        var w = reg_read32(bar0, MB_IRQ_STATUS_REG())
        var mark = String("")
        if (w & MB_FWCTL_DONE_BIT()) != 0:
            mark = "  <-- COMPLETION BIT"
        print("t=" + String((i + 1) * 100) + "ms 018C=" + _hex(w) + mark)
        if (w & MB_FWCTL_DONE_BIT()) != 0:
            break
    _dump(bar0, bar4, "post")
    # response payload peek (first 32 bytes)
    var rp = bar4.ptr()
    var hx = String("")
    for i in range(32):
        var b = rp[unsafe_offset=MB_RESP_SLOT() + 4 + i]
        var hi = Int(b >> 4)
        var lo = Int(b & 15)
        hx += String(chr(48 + hi if hi < 10 else 87 + hi))
        hx += String(chr(48 + lo if lo < 10 else 87 + lo))
    print("resp+4: " + hx)
    unmap_bar(arch, bar0)
    unmap_bar(arch, bar4)
