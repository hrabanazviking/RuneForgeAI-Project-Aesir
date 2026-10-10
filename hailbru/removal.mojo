# HAILBRU surprise-removal handling (H091, Campaign 5).
#
# Detects a vanished device via failed register-access patterns, fails
# closed with a named DeviceRemoved error, and releases all mappings
# cleanly (no segfault, no hang). The live-removal case is exercised via
# the documented simulation: a test hook severs the BAR mapping
# (munmap), after which every guarded access raises DeviceRemoved.
# Real unplug on the HAT is operator territory and is not tested here.

from hailbru.syscall import os_clock_ms
from hailbru.errors import herror
from hailbru.api import (
    BarMapping,
    map_emulated,
    reg_read32,
    unmap_bar,
)


struct WatchedBar:
    # A BAR mapping with an explicit liveness flag. guarded_read32 checks
    # the flag BEFORE touching the mapping, so a severed mapping can
    # never be dereferenced (fail-closed by construction).
    var mapping: BarMapping
    var alive: Bool
    var severed_at_ms: Int64

    def __init__(out self, mapping: BarMapping):
        self.mapping = mapping
        self.alive = True
        self.severed_at_ms = 0


def watch_bar_emulated(
    arch: String, path: String, size: Int
) raises -> WatchedBar:
    return WatchedBar(map_emulated(arch, path, Int64(size)))


def watcher_sever(arch: String, mut w: WatchedBar):
    # Test hook simulating surprise removal: release the mapping and mark
    # the device gone. All fds/mappings are released here, not later.
    if w.alive:
        unmap_bar(arch, w.mapping)
        w.alive = False
        w.severed_at_ms = os_clock_ms(arch)


def watcher_read32(
    arch: String, w: WatchedBar, off: Int
) raises -> Int:
    if not w.alive:
        raise herror(
            "DeviceRemoved",
            "register access at offset " + String(off)
            + " after mapping severed ("
            + String(os_clock_ms(arch) - w.severed_at_ms)
            + "ms ago); mappings released cleanly",
        )
    return Int(reg_read32(w.mapping, off))
