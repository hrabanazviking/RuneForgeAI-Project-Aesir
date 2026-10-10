# Final H102 probe: IDENTIFY via the CORE doorbell (flag 0x2).
# Same mechanism as mbping, single iteration, app_cpu=False.
# Result 2026-10-10: completed=False — firmware silent on the core
# doorbell too. See docs/smidr/H102_ATTEMPT_RECORD.md.

from hailbru.errors import herror
from hailbru.regs import BarMapping, map_sysfs_resource, unmap_bar
from hailbru.syscall import proc_cmdline
from smidr.mailbox import (
    MB_DEFAULT_TIMEOUT_MS,
    build_identify_request,
    mailbox_submit,
)


def main() raises:
    var args = proc_cmdline("aarch64")
    if len(args) < 3:
        raise herror("BadArgs", "usage: coreprobe <sysfs_root> <bdf>")
    var bar0 = map_sysfs_resource("aarch64", args[1], args[2], 0, 16384, True)
    var bar4 = map_sysfs_resource("aarch64", args[1], args[2], 4, 16384, True)
    var req = build_identify_request()
    var res = mailbox_submit(
        "aarch64", bar0, bar4, req, False, MB_DEFAULT_TIMEOUT_MS()
    )
    print(
        "COREPROBE completed=" + String(res.completed)
        + " elapsed_ms=" + String(res.elapsed_ms)
    )
    unmap_bar("aarch64", bar0)
    unmap_bar("aarch64", bar4)
    if not res.completed:
        raise herror("CoreSilent", "no completion via core doorbell")
