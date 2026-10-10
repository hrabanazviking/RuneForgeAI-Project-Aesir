# VÖRÐR health observers (H087 hooks, adopted by VÖRÐR in H141).
#
# MOVED (not copied) from hailbru/health_obs.mojo in H141 per the C8
# roadmap. Owned by VÖRÐR (D6). L12-clean: read-only observers using
# only the HAILBRÚ public API — no direct register access of their own.
#
# Read-only observers owned by HAILBRÚ (L12-clean). health_sample()
# returns a structured sample: Pi SoC temperature (documented units —
# /sys/class/thermal/thermal_zone0/temp is millidegrees Celsius; the
# Hailo-10 die temperature is NOT readable on the current kernel and is
# reported as unavailable, never fabricated), the BAR0 host-interrupt
# status register via the H079 public API only, and a monotonic
# timestamp. H141 adopts these into vordr/ (move, not copy); that
# relocation will be recorded in the H087 DEVLOG entry.

from hailbru.syscall import os_clock_ms, read_file_str
from hailbru.util import trim
from hailbru.errors import herror
from hailbru.api import map_sysfs_resource, reg_read32, unmap_bar


struct HealthSample:
    var ts_ms: Int64
    var soc_temp_millic: Int
    var soc_temp_source: String
    var irq_status_0x18c: Int
    var device_temp_note: String

    def __init__(
        out self, ts_ms: Int64, soc_temp_millic: Int, soc_temp_source: String,
        irq_status_0x18c: Int, device_temp_note: String,
    ):
        self.ts_ms = ts_ms
        self.soc_temp_millic = soc_temp_millic
        self.soc_temp_source = soc_temp_source
        self.irq_status_0x18c = irq_status_0x18c
        self.device_temp_note = device_temp_note

    def to_json(self) -> String:
        return (
            "{\"ts_ms\": " + String(self.ts_ms)
            + ", \"soc_temp_millic\": " + String(self.soc_temp_millic)
            + ", \"soc_temp_c\": " + String(Float64(self.soc_temp_millic) / 1000.0)
            + ", \"soc_temp_source\": \"" + self.soc_temp_source + "\""
            + ", \"irq_status_0x18c\": " + String(self.irq_status_0x18c)
            + ", \"device_temp\": \"" + self.device_temp_note + "\"}"
        )


def health_sample(
    arch: String, sysfs_root: String, bdf: String, thermal_path: String
) raises -> HealthSample:
    # Read-only: no device writes, no state changes. Caller must hold D0
    # for the BAR0 read to be meaningful (in D3hot it reads 0xFFFFFFFF).
    var ts = os_clock_ms(arch)
    var temp_raw = trim(read_file_str(arch, thermal_path, 32))
    var temp_mc = 0
    for b in temp_raw.bytes():
        if b >= 48 and b <= 57:
            temp_mc = temp_mc * 10 + (Int(b) - 48)
        else:
            raise herror(
                "BadSysfs",
                "non-numeric thermal reading from " + thermal_path,
            )
    var m = map_sysfs_resource(arch, sysfs_root, bdf, 0, 0x4000, False)
    var status = Int(reg_read32(m, 0x018C))
    unmap_bar(arch, m)
    return HealthSample(
        ts, temp_mc, thermal_path, status,
        "unavailable: no Hailo-10 die-temperature register is documented "
        "or readable on the current kernel; Pi SoC temperature is a host "
        "proxy, NOT the device temperature",
    )
