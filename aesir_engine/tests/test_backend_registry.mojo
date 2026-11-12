# tests/test_backend_registry.mojo
# A-009: typed backend registry -- present/absent/degraded combos
# are proven with injectable fake probes (nothing is uninstalled),
# and the live-text parsers are proven on captured probe shapes.

from core.backend_registry import (
    BACKEND_ABSENT,
    BACKEND_DEGRADED,
    BACKEND_PRESENT,
    RawBackendProbe,
    backend_capability_from_probe,
    build_backend_registry,
    parse_hip_version_header,
    parse_rocminfo_device,
    parse_vulkan_summary,
    parse_xrt_package_version,
)


def _fake(found: Bool, version: String, device: String) -> RawBackendProbe:
    return RawBackendProbe(found, False, version, device, "fake probe")


def test_backend_registry_all_present() raises:
    var reg = build_backend_registry(
        _fake(True, "7.15.0", "AMD Radeon 8060S Graphics"),
        _fake(True, "1.4.354", "AMD Radeon 8060S Graphics (RADV STRIX_HALO)"),
        _fake(True, "2.25.0", "NPU via /dev/accel/accel0"),
        _fake(True, "", "AMD RYZEN AI MAX+ 395 w/ Radeon 8060S"),
    )
    if reg.count_available() != 4:
        raise Error("all-present registry did not count 4 available")
    for name in ["HIP", "Vulkan", "XRT", "CPU"]:
        var cap = reg.capability_named(name)
        if cap.status != BACKEND_PRESENT or cap.status_name() != "present":
            raise Error("all-present registry marked " + name + " not present")
    if reg.hip.version != "7.15.0" or "8060S" not in reg.hip.device:
        raise Error("HIP record lost version/device identity")
    if reg.xrt.version != "2.25.0":
        raise Error("XRT record lost version identity")
    if "Vulkan present" not in reg.vulkan.line():
        raise Error("Vulkan record line does not state present")


def test_backend_registry_absent_combinations() raises:
    # Every subset pattern: HIP/Vulkan/XRT/CPU absent in turn, then all.
    for mask in range(16):
        var reg = build_backend_registry(
            _fake((mask & 1) != 0, "1", "hip-dev"),
            _fake((mask & 2) != 0, "1", "vk-dev"),
            _fake((mask & 4) != 0, "1", "xrt-dev"),
            _fake((mask & 8) != 0, "", "cpu-dev"),
        )
        var expected = 0
        if (mask & 1) != 0:
            expected += 1
        if (mask & 2) != 0:
            expected += 1
        if (mask & 4) != 0:
            expected += 1
        if (mask & 8) != 0:
            expected += 1
        if reg.count_available() != expected:
            raise Error("absent-combination count drifted for a mask")
        if ((mask & 1) != 0) != (reg.hip.status == BACKEND_PRESENT):
            raise Error("HIP status disagrees with fake probe")
        if ((mask & 4) != 0) != (reg.xrt.status == BACKEND_PRESENT):
            raise Error("XRT status disagrees with fake probe")
        if (mask & 8) == 0 and reg.cpu.status != BACKEND_ABSENT:
            raise Error("absent CPU fake probe was reported present")


def test_backend_registry_degraded_and_software_vulkan() raises:
    var degraded = RawBackendProbe(
        True, True, "", "NPU via /dev/accel/accel0", "version not observed"
    )
    var cap = backend_capability_from_probe("XRT", degraded)
    if cap.status != BACKEND_DEGRADED or cap.status_name() != "degraded":
        raise Error("degraded probe was not recorded as degraded")
    if not cap.is_available():
        raise Error("degraded runtime must still count as available")
    var software = backend_capability_from_probe(
        "Vulkan", _fake(True, "1.4", "llvmpipe (LLVM 22.1.8, 256 bits)")
    )
    if software.status != BACKEND_ABSENT or software.is_available():
        raise Error("llvmpipe was counted as a Vulkan GPU device")
    if "software" not in software.detail:
        raise Error("llvmpipe refusal lost its reason")


def test_backend_registry_parsers() raises:
    var hip_h = (
        "#define HIP_VERSION_MAJOR 7\n#define HIP_VERSION_MINOR 15\n"
        + "#define HIP_VERSION_PATCH 0\n"
    )
    if parse_hip_version_header(hip_h) != "7.15.0":
        raise Error("HIP version header parser drifted")
    if parse_hip_version_header("no defines\n") != "":
        raise Error("HIP parser invented a version")
    var roc = (
        "  Marketing Name:          AMD RYZEN AI MAX+ 395 w/ Radeon 8060S\n"
        + "  Marketing Name:          AMD Radeon 8060S Graphics\n"
    )
    if parse_rocminfo_device(roc) != "AMD Radeon 8060S Graphics":
        raise Error("rocminfo parser picked the wrong device line")
    var vk = (
        "GPU0:\n\tapiVersion         = 1.4.354\n"
        + "\tdeviceName         = AMD Radeon 8060S Graphics (RADV STRIX_HALO)\n"
        + "GPU1:\n\tapiVersion         = 1.4.354\n"
        + "\tdeviceName         = llvmpipe (LLVM 22.1.8, 256 bits)\n"
    )
    var vk_probe = parse_vulkan_summary(vk)
    if not vk_probe.found or "RADV" not in vk_probe.device:
        raise Error("Vulkan parser did not select the RADV GPU")
    if vk_probe.version != "1.4.354":
        raise Error("Vulkan parser lost the apiVersion")
    var vk_sw = parse_vulkan_summary(
        "\tapiVersion         = 1.4.354\n"
        + "\tdeviceName         = llvmpipe (LLVM 22.1.8, 256 bits)\n"
    )
    var vk_sw_cap = backend_capability_from_probe("Vulkan", vk_sw)
    if vk_sw_cap.status != BACKEND_ABSENT:
        raise Error("software-only Vulkan summary was counted present")
    if parse_xrt_package_version("1:2.25.0-4ubuntu1\n") != "2.25.0":
        raise Error("XRT package version parser drifted")
