"""Thermal & power sensing for the Z13 campaign (roadmap slice A-018).

Every value is READ at runtime from kernel interfaces: amdgpu and
k10temp/zenpower hwmon under /sys/class/hwmon (temperatures in
millidegree Celsius, power in microwatts, fans in RPM -- the kernel's
own units) and CPU package power domains under /sys/class/powercap
(RAPL energy_uj in microjoules). No reading is hardcoded or
fabricated: a source that is missing or unreadable (RAPL energy_uj
is commonly permission-restricted) leaves its field unknown (-1)
with the reason recorded beside it. These readings feed the later
self-throttling slices; this module chooses and gates nothing.

HOST CONTRACT: observe_thermal_power() never raises.
"""

from std.ffi import external_call

from core.observation_integer import bounded_decimal
from core.posix_process import run_checked_argv


def _read_text(path: String) raises -> String:
    var text: String
    with open(path, "r") as source:
        text = source.read()
    return text


def _read_or_empty(path: String) -> String:
    try:
        return _read_text(path)
    except:
        return String("")


def _stripped(text: String) -> String:
    return String(text.strip())


def parse_sysfs_uint(text: String) raises -> Int:
    """Parse one unsigned sysfs integer file (decimal, stripped)."""
    return bounded_decimal(_stripped(text))


def format_temp_milli_c(milli_c: Int) -> String:
    """36000 -> '36.0 C' style with degree sign; unknown -> 'unknown'."""
    if milli_c < 0:
        return String("unknown")
    var tenth = (milli_c + 50) // 100
    return String(tenth // 10) + "." + String(tenth % 10) + "°C"


def format_power_microwatts(microwatts: Int) -> String:
    """8936000 -> '8.9 W'; unknown (<0) -> 'unknown'."""
    if microwatts < 0:
        return String("unknown")
    var tenth = (microwatts + 50000) // 100000
    return String(tenth // 10) + "." + String(tenth % 10) + " W"


def temp_plausible_milli_c(milli_c: Int) -> Bool:
    """Plausible silicon temperature band: -20 C to +115 C."""
    return milli_c >= -20000 and milli_c <= 115000


def power_plausible_microwatts(microwatts: Int) -> Bool:
    """Plausible package/GPU power band: 0 to 250 W."""
    return microwatts >= 0 and microwatts <= 250000000


def fan_plausible_rpm(rpm: Int) -> Bool:
    return rpm >= 0 and rpm <= 10000


def temp_within_tolerance(a_milli_c: Int, b_milli_c: Int, tol_milli_c: Int) -> Bool:
    var diff = a_milli_c - b_milli_c
    if diff < 0:
        diff = -diff
    return diff <= tol_milli_c


def power_within_tolerance(a_uw: Int, b_uw: Int) -> Bool:
    """Power tracks if within 5 W or 30% -- PPT readings move fast."""
    var diff = a_uw - b_uw
    if diff < 0:
        diff = -diff
    if diff <= 5000000:
        return True
    return b_uw > 0 and diff * 100 <= b_uw * 30


struct ThermalPower(Copyable, ImplicitlyCopyable):
    """Runtime-observed thermal/power truth; -1 means not observed."""

    var gpu_present: Bool
    var gpu_hwmon: String
    var gpu_temp_label: String
    var gpu_temp_milli_c: Int
    var gpu_power_label: String
    var gpu_power_microwatts: Int
    var gpu_reason: String
    var cpu_temp_present: Bool
    var cpu_hwmon: String
    var cpu_temp_label: String
    var cpu_temp_milli_c: Int
    var cpu_reason: String
    var fan_present: Bool
    var fan_hwmon: String
    var fan_label: String
    var fan_rpm: Int
    var fan_reason: String
    var rapl_present: Bool
    var rapl_domain: String
    var rapl_name: String
    var rapl_energy_uj: Int
    var rapl_reason: String

    def __init__(out self):
        self.gpu_present = False
        self.gpu_hwmon = String("")
        self.gpu_temp_label = String("")
        self.gpu_temp_milli_c = -1
        self.gpu_power_label = String("")
        self.gpu_power_microwatts = -1
        self.gpu_reason = String("not probed")
        self.cpu_temp_present = False
        self.cpu_hwmon = String("")
        self.cpu_temp_label = String("")
        self.cpu_temp_milli_c = -1
        self.cpu_reason = String("not probed")
        self.fan_present = False
        self.fan_hwmon = String("")
        self.fan_label = String("")
        self.fan_rpm = -1
        self.fan_reason = String("not probed")
        self.rapl_present = False
        self.rapl_domain = String("")
        self.rapl_name = String("")
        self.rapl_energy_uj = -1
        self.rapl_reason = String("not probed")


def thermal_power_lines(r: ThermalPower) -> List[String]:
    """One line per kind; every kind renders, quantified or honest-absent."""
    var lines = List[String]()
    if r.gpu_present:
        var gpu = "gpu thermal: " + (r.gpu_temp_label if r.gpu_temp_label.byte_length() > 0 else String("temp"))
        gpu += " " + format_temp_milli_c(r.gpu_temp_milli_c)
        gpu += ", power " + (r.gpu_power_label if r.gpu_power_label.byte_length() > 0 else String("power"))
        gpu += " " + format_power_microwatts(r.gpu_power_microwatts)
        gpu += " (amdgpu hwmon " + r.gpu_hwmon + ")"
        lines.append(gpu)
    else:
        lines.append("gpu thermal: not observed — " + r.gpu_reason)
    if r.cpu_temp_present:
        var cpu = "cpu thermal: " + (r.cpu_temp_label if r.cpu_temp_label.byte_length() > 0 else String("temp"))
        cpu += " " + format_temp_milli_c(r.cpu_temp_milli_c)
        cpu += " (hwmon " + r.cpu_hwmon + ")"
        lines.append(cpu)
    else:
        lines.append("cpu thermal: not observed — " + r.cpu_reason)
    if r.fan_present:
        var fan = "fan: " + (r.fan_label if r.fan_label.byte_length() > 0 else String("fan1"))
        fan += " " + String(r.fan_rpm) + " RPM (hwmon " + r.fan_hwmon + ")"
        lines.append(fan)
    else:
        lines.append("fan: not observed — " + r.fan_reason)
    if r.rapl_present and r.rapl_energy_uj >= 0:
        lines.append("cpu power (RAPL): domain " + r.rapl_name + " energy " + String(r.rapl_energy_uj) + " uJ (powercap " + r.rapl_domain + ")")
    elif r.rapl_present:
        lines.append("cpu power (RAPL): domain " + r.rapl_name + " present — energy_uj unreadable: " + r.rapl_reason)
    else:
        lines.append("cpu power (RAPL): absent — " + r.rapl_reason)
    return lines^


def _read_int_or_neg(path: String) -> Int:
    try:
        return parse_sysfs_uint(_read_text(path))
    except:
        return -1


def _colon_count(text: String) -> Int:
    var n = 0
    for byte in text.as_bytes():
        if byte == 58:
            n += 1
    return n


def observe_thermal_power() -> ThermalPower:
    """Probe hwmon + powercap at call time. Never raises."""
    var r = ThermalPower()
    var listing = String("")
    try:
        listing = run_checked_argv(["ls", "/sys/class/hwmon"], 4096)
    except:
        listing = String("")
    if listing.byte_length() == 0:
        r.gpu_reason = "no hwmon devices listed under /sys/class/hwmon"
        r.cpu_reason = r.gpu_reason
        r.fan_reason = r.gpu_reason
    else:
        r.gpu_reason = "no amdgpu hwmon device found"
        r.cpu_reason = "no k10temp/zenpower hwmon device found"
        r.fan_reason = "no fan*_input hwmon file found"
        for raw in listing.split("\n"):
            var entry = String(raw.strip())
            if entry.byte_length() == 0:
                continue
            var base = "/sys/class/hwmon/" + entry
            var name = _stripped(_read_or_empty(base + "/name"))
            if name == "amdgpu":
                r.gpu_hwmon = entry
                r.gpu_temp_label = _stripped(_read_or_empty(base + "/temp1_label"))
                r.gpu_temp_milli_c = _read_int_or_neg(base + "/temp1_input")
                r.gpu_power_label = _stripped(_read_or_empty(base + "/power1_label"))
                r.gpu_power_microwatts = _read_int_or_neg(base + "/power1_average")
                if r.gpu_power_microwatts < 0:
                    r.gpu_power_microwatts = _read_int_or_neg(base + "/power1_input")
                if r.gpu_temp_milli_c >= 0 or r.gpu_power_microwatts >= 0:
                    r.gpu_present = True
                    r.gpu_reason = String("")
            elif name == "k10temp" or name == "zenpower":
                r.cpu_hwmon = entry + " (" + name + ")"
                r.cpu_temp_label = _stripped(_read_or_empty(base + "/temp1_label"))
                r.cpu_temp_milli_c = _read_int_or_neg(base + "/temp1_input")
                if r.cpu_temp_milli_c >= 0:
                    r.cpu_temp_present = True
                    r.cpu_reason = String("")
            if not r.fan_present:
                var rpm = _read_int_or_neg(base + "/fan1_input")
                if rpm >= 0:
                    r.fan_present = True
                    r.fan_hwmon = entry + " (" + name + ")"
                    r.fan_label = _stripped(_read_or_empty(base + "/fan1_label"))
                    r.fan_rpm = rpm
                    r.fan_reason = String("")
    var domains = String("")
    try:
        domains = run_checked_argv(["ls", "/sys/class/powercap"], 4096)
    except:
        domains = String("")
    r.rapl_reason = "no powercap domain listed under /sys/class/powercap"
    for raw in domains.split("\n"):
        var entry = String(raw.strip())
        if entry.byte_length() == 0 or _colon_count(entry) != 1:
            continue
        var base = "/sys/class/powercap/" + entry
        r.rapl_present = True
        r.rapl_domain = entry
        r.rapl_name = _stripped(_read_or_empty(base + "/name"))
        try:
            r.rapl_energy_uj = parse_sysfs_uint(_read_text(base + "/energy_uj"))
            r.rapl_reason = String("")
        except e:
            r.rapl_energy_uj = -1
            r.rapl_reason = "energy_uj could not be read or parsed: " + String(e)
        break
    return r
