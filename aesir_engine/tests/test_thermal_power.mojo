"""Thermal & power sensing proof (roadmap slice A-018).

Fixture groups run on kernel-shaped texts. The live group observes
this machine (purpleraider, Z13) twice, contemporaneously, and
asserts the two captures track each other within stated tolerances
(temp +/-3 C; power within 5 W or 30% -- amdgpu PPT moves fast, as
the 2026-11-12 capture showed: sysfs 8.936 W vs `sensors` 10.74 W
moments apart), that readings are plausible, and that RAPL is
honest: its package domain is present here but energy_uj is
permission-restricted, so the reading must say unreadable-with-
reason, never a fabricated zero.
"""

from core.thermal_power import (
    ThermalPower,
    fan_plausible_rpm,
    format_power_microwatts,
    format_temp_milli_c,
    observe_thermal_power,
    parse_sysfs_uint,
    power_plausible_microwatts,
    power_within_tolerance,
    temp_plausible_milli_c,
    temp_within_tolerance,
    thermal_power_lines,
)


def expect_true(v: Bool, what: String) raises:
    if not v:
        raise Error("ThermalPower " + what + ": expected true")


def expect_eq(a: Int, b: Int, what: String) raises:
    if a != b:
        raise Error("ThermalPower " + what + ": expected " + String(b) + ", got " + String(a))


def test_thermal_parsers_and_formats() raises:
    expect_eq(parse_sysfs_uint("36000\n"), 36000, "amdgpu temp1_input millidegree")
    expect_eq(parse_sysfs_uint("8936000\n"), 8936000, "amdgpu power1_average microwatts")
    expect_eq(parse_sysfs_uint("0\n"), 0, "fan zero rpm is a real reading")
    if format_temp_milli_c(36000) != "36.0°C":
        raise Error("ThermalPower temp format drifted: " + format_temp_milli_c(36000))
    if format_temp_milli_c(38100) != "38.1°C":
        raise Error("ThermalPower temp format drifted (k10temp capture)")
    if format_power_microwatts(8936000) != "8.9 W":
        raise Error("ThermalPower power format drifted: " + format_power_microwatts(8936000))
    if format_temp_milli_c(-1) != "unknown" or format_power_microwatts(-1) != "unknown":
        raise Error("ThermalPower unknown values must render unknown, not zero")
    expect_true(temp_plausible_milli_c(36000), "36 C plausible")
    expect_true(not temp_plausible_milli_c(65261800), "sensors overflow sentinel implausible")
    expect_true(power_plausible_microwatts(8936000), "8.9 W plausible")
    expect_true(not power_plausible_microwatts(999000000), "999 W implausible")
    expect_true(fan_plausible_rpm(0), "0 RPM plausible (fans stopped at idle)")
    var refused = False
    try:
        _ = parse_sysfs_uint("plenty\n")
    except:
        refused = True
    expect_true(refused, "non-numeric sysfs integer refused")
    print("PASS: thermal parsers/formats (kernel units, plausible bands, refusals)")


def test_thermal_tolerance_tracking() raises:
    expect_true(temp_within_tolerance(36000, 38100, 3000), "gpu 36.0 vs cpu 38.1 within 3 C")
    expect_true(not temp_within_tolerance(36000, 46000, 3000), "36 vs 46 outside 3 C")
    expect_true(power_within_tolerance(8936000, 10740000), "sysfs 8.936 W tracks sensors 10.74 W")
    expect_true(not power_within_tolerance(8936000, 60000000), "8.9 vs 60 W does not track")
    print("PASS: thermal tolerance (temp +/-3 C; power 5 W or 30%)")


def test_thermal_lines_fixture() raises:
    var r = ThermalPower()
    r.gpu_present = True
    r.gpu_hwmon = String("hwmon13")
    r.gpu_temp_label = String("edge")
    r.gpu_temp_milli_c = 36000
    r.gpu_power_label = String("PPT")
    r.gpu_power_microwatts = 8936000
    r.gpu_reason = String("")
    r.cpu_temp_present = True
    r.cpu_hwmon = String("hwmon8 (k10temp)")
    r.cpu_temp_label = String("Tctl")
    r.cpu_temp_milli_c = 38000
    r.cpu_reason = String("")
    r.fan_present = True
    r.fan_hwmon = String("hwmon9 (asus)")
    r.fan_label = String("cpu_fan")
    r.fan_rpm = 0
    r.fan_reason = String("")
    r.rapl_present = True
    r.rapl_domain = String("intel-rapl:0")
    r.rapl_name = String("package-0")
    r.rapl_energy_uj = -1
    r.rapl_reason = String("fixture: permission denied")
    var lines = thermal_power_lines(r)
    expect_eq(len(lines), 4, "one line per thermal kind")
    var joined = String("")
    for i in range(len(lines)):
        joined += lines[i] + "\n"
    for needle in ["gpu thermal:", "36.0", "8.9 W", "cpu thermal:", "Tctl", "fan:", "0 RPM", "energy_uj unreadable"]:
        if needle not in joined:
            raise Error("ThermalPower lines missing '" + needle + "': " + joined)
    var absent = thermal_power_lines(ThermalPower())
    expect_eq(len(absent), 4, "absent reading still renders every kind")
    var aj = String("")
    for i in range(len(absent)):
        aj += absent[i] + "\n"
    if "not observed" not in aj or "RAPL): absent" not in aj:
        raise Error("ThermalPower absent lines must state absence with reason: " + aj)
    print("PASS: thermal lines (present quantified, RAPL unreadable honest, absent with reason)")


def test_thermal_live_this_machine() raises:
    var a = observe_thermal_power()
    var b = observe_thermal_power()
    var lines = thermal_power_lines(a)
    for i in range(len(lines)):
        print("THERMAL: " + lines[i])
    expect_true(a.gpu_present, "live amdgpu hwmon present")
    expect_true(temp_plausible_milli_c(a.gpu_temp_milli_c), "live gpu temp plausible")
    expect_true(power_plausible_microwatts(a.gpu_power_microwatts), "live gpu PPT plausible")
    expect_true(a.cpu_temp_present, "live k10temp present")
    expect_true(temp_plausible_milli_c(a.cpu_temp_milli_c), "live cpu Tctl plausible")
    expect_true(temp_within_tolerance(a.gpu_temp_milli_c, b.gpu_temp_milli_c, 3000), "live gpu temp tracks contemporaneous capture within 3 C")
    expect_true(temp_within_tolerance(a.cpu_temp_milli_c, b.cpu_temp_milli_c, 3000), "live cpu temp tracks contemporaneous capture within 3 C")
    expect_true(power_within_tolerance(a.gpu_power_microwatts, b.gpu_power_microwatts), "live gpu power tracks contemporaneous capture (5 W or 30%)")
    expect_true(a.fan_present and fan_plausible_rpm(a.fan_rpm), "live fan reading present and plausible")
    expect_true(a.rapl_present, "live RAPL package domain present")
    if a.rapl_energy_uj < 0:
        expect_true(a.rapl_reason.byte_length() > 0, "unreadable RAPL energy carries its reason, never fabricated")
    print("PASS: live thermal on this machine (hwmon + RAPL, tracked within tolerance)")


def main() raises:
    test_thermal_parsers_and_formats()
    test_thermal_tolerance_tracking()
    test_thermal_lines_fixture()
    test_thermal_live_this_machine()
    print("ALL PASS: thermal & power sensing (4 groups)")
