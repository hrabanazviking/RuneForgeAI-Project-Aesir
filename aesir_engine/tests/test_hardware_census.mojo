"""Hardware census proof (roadmap slice A-001).

Parser groups run on injected texts written in the exact shapes the
kernel emits (the fixture values below were captured from this
machine's own sysfs/proc files on 2026-11-11 and are filed here as
test data -- the census code itself contains no machine strings).
The live group runs observe_hardware_census() on the machine
executing the test and asserts the acceptance facts for the Z13:
Zen 5-class CPU at 16 physical / 32 logical, a gfx1151 GPU whose
memory is the unified pool, the XDNA NPU device present via its
accel node with the amdxdna driver, ~128 GB of memory, an NVMe
namespace over 1 TB, and a 7.3 kernel. Absent hardware is asserted
as reported-absent, never as an error: this machine has no CUDA
device, and the census plus the CUDA gate must both say so without
raising.
"""

from core.cuda_gate import CUDAGate
from core.hardware_census import (
    HardwareCensus,
    census_lines,
    format_gfx_target,
    nvme_capacity_bytes,
    observe_hardware_census,
    parse_kfd_gfx_target_version,
    parse_mem_bank_clock_mhz,
    parse_mem_bank_width,
    parse_os_release_pretty,
    parse_sysfs_int,
    parse_uevent_value,
)


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("HardwareCensus " + what + ": expected true")


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "HardwareCensus "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_contains(text: String, needle: String, what: String) raises:
    if needle not in text:
        raise Error(
            "HardwareCensus "
            + what
            + ": expected to contain '"
            + needle
            + "', got '"
            + text
            + "'"
        )


def _kfd_gpu_properties() -> String:
    # Shape exactly as the kernel emits it in
    # /sys/class/kfd/kfd/topology/nodes/1/properties on this machine
    # (values captured 2026-11-11; filed as fixture data only).
    return (
        "cpu_cores_count 0\n"
        + "simd_count 80\n"
        + "mem_banks_count 1\n"
        + "gfx_target_version 110501\n"
        + "vendor_id 4098\n"
        + "device_id 5510\n"
        + "wave_front_size 32\n"
    )


def test_kfd_gfx_parser() raises:
    var version = parse_kfd_gfx_target_version(_kfd_gpu_properties())
    expect_eq(version, 110501, "gfx_target_version read verbatim")
    var name = format_gfx_target(version)
    if name != "gfx1151":
        raise Error("HardwareCensus gfx format: expected gfx1151, got " + name)
    if format_gfx_target(0) != "unknown" or format_gfx_target(-7) != "unknown":
        raise Error("HardwareCensus gfx format claimed an unread target")
    var cpu_node = "cpu_cores_count 32\ngfx_target_version 0\n"
    expect_eq(
        parse_kfd_gfx_target_version(cpu_node), 0, "cpu node states zero"
    )
    expect_eq(
        parse_kfd_gfx_target_version("simd_count 0\n"),
        -1,
        "missing gfx key is unknown, not zero",
    )
    print("PASS: kfd gfx parser (verbatim version, formatted target, unknowns)")


def test_os_release_and_uevent_parsers() raises:
    var os_release = (
        'NAME="Ubuntu"\n'
        + 'PRETTY_NAME="Ubuntu 26.10"\n'
        + 'VERSION_ID="26.10"\n'
    )
    var pretty = parse_os_release_pretty(os_release)
    if pretty != "Ubuntu 26.10":
        raise Error("HardwareCensus os-release: expected 'Ubuntu 26.10', got '" + pretty + "'")
    expect_true(
        parse_os_release_pretty("NAME=\"Ubuntu\"\n").byte_length() == 0,
        "missing PRETTY_NAME stays empty",
    )
    var uevent = (
        "DRIVER=amdxdna\n"
        + "PCI_CLASS=118000\n"
        + "PCI_ID=1022:17F0\n"
        + "PCI_SLOT_NAME=0000:c5:00.1\n"
    )
    if parse_uevent_value(uevent, "DRIVER") != "amdxdna":
        raise Error("HardwareCensus uevent: driver not read")
    if parse_uevent_value(uevent, "PCI_ID") != "1022:17F0":
        raise Error("HardwareCensus uevent: PCI_ID not read")
    expect_true(
        parse_uevent_value(uevent, "MODALIAS").byte_length() == 0,
        "missing uevent key stays empty",
    )
    print("PASS: os-release + uevent parsers (quoted pretty name, KEY=value)")


def test_sysfs_number_parsers() raises:
    expect_eq(parse_sysfs_int("4294967296\n"), 4294967296, "vram aperture")
    expect_eq(
        nvme_capacity_bytes("3907029168\n"),
        3907029168 * 512,
        "nvme sectors to bytes",
    )
    var bank = "heap_type 1\nsize_in_bytes 65227026432\nwidth 256\nmem_clk_max 1000\n"
    expect_eq(parse_mem_bank_clock_mhz(bank), 1000, "mem bank clock")
    expect_eq(parse_mem_bank_width(bank), 256, "mem bank width")
    expect_eq(parse_mem_bank_clock_mhz("width 256\n"), -1, "unstated clock")
    var refused = False
    try:
        _ = parse_sysfs_int("plenty\n")
    except:
        refused = True
    expect_true(refused, "non-numeric sysfs integer is refused")
    print("PASS: sysfs number parsers (ints, nvme capacity, mem bank, refusals)")


def test_census_lines_fixture() raises:
    var present = HardwareCensus()
    present.cpu_model = String("Fixture CPU")
    present.cpu_logical = 32
    present.cpu_physical = 16
    present.cpu_packages = 1
    present.cpu_reason = String("")
    present.gpu_present = True
    present.gpu_driver = String("fixturegpu")
    present.gpu_pci_id = String("0000:0000")
    present.gpu_gfx_target = String("gfx0000")
    present.gpu_vram_total_bytes = 4294967296
    present.gpu_gtt_total_bytes = 65227026432
    present.gpu_unified = True
    present.gpu_reason = String("")
    present.npu_present = True
    present.npu_node = String("/dev/accel/accel0")
    present.npu_driver = String("fixturexdna")
    present.npu_pci_id = String("0000:0000")
    present.npu_fw_version = String("0.0.0")
    present.npu_reason = String("")
    present.mem_total_bytes = 127396540 * 1024
    present.mem_available_bytes = 118699688 * 1024
    present.mem_clk_max_mhz = 1000
    present.mem_bank_width = 256
    present.mem_reason = String("")
    present.nvme_present = True
    present.nvme_model = String("Fixture NVMe")
    present.nvme_firmware = String("F0")
    present.nvme_capacity_bytes = 2000398688256
    present.nvme_reason = String("")
    present.kernel_release = String("0.0.0-fixture")
    present.os_pretty = String("Fixture OS")
    present.product_name = String("Fixture Product")
    present.rocm_present = False
    present.rocm_detail = String("fixture: not installed")
    present.xrt_present = False
    present.xrt_detail = String("fixture: not installed")
    var lines = census_lines(present)
    expect_eq(len(lines), 8, "one line per census kind")
    var joined = String("")
    for i in range(len(lines)):
        joined += lines[i] + "\n"
    expect_contains(joined, "cpu:", "lines carry cpu")
    expect_contains(joined, "gpu: present", "lines carry gpu present")
    expect_contains(joined, "unified pool", "gpu line states the unified pool")
    expect_contains(joined, "npu: present", "lines carry npu present")
    expect_contains(joined, "memory:", "lines carry memory")
    expect_contains(joined, "storage: NVMe", "lines carry storage")
    expect_contains(joined, "kernel 0.0.0-fixture", "lines carry kernel")
    expect_contains(joined, "rocm: absent", "lines carry rocm absent")
    expect_contains(joined, "xrt: absent", "lines carry xrt absent")

    var absent = HardwareCensus()
    absent.cpu_reason = String("fixture: cpuinfo unreadable")
    absent.gpu_reason = String("fixture: no card")
    absent.npu_reason = String("fixture: no accel device")
    absent.mem_reason = String("fixture: meminfo unreadable")
    absent.nvme_reason = String("fixture: no controller")
    absent.rocm_detail = String("fixture: not installed")
    absent.xrt_detail = String("fixture: not installed")
    var absent_lines = census_lines(absent)
    expect_eq(len(absent_lines), 8, "absent census still renders every kind")
    var absent_joined = String("")
    for i in range(len(absent_lines)):
        absent_joined += absent_lines[i] + "\n"
    expect_contains(absent_joined, "gpu: absent", "absent gpu stated")
    expect_contains(absent_joined, "npu: absent", "absent npu stated")
    expect_contains(
        absent_joined, "fixture: no card", "absent gpu carries its reason"
    )
    print("PASS: census lines (present quantified, absent with reason, none omitted)")


def test_live_census_this_machine() raises:
    # The real probes, on the machine running this test (purpleraider,
    # the Z13). Acceptance facts from the roadmap's verified table,
    # asserted against values the census READ at runtime.
    var census = observe_hardware_census()
    var lines = census_lines(census)
    for i in range(len(lines)):
        print("CENSUS: " + lines[i])
    expect_true(census.cpu_logical == 32, "live cpu logical count is 32")
    expect_true(census.cpu_physical == 16, "live cpu physical cores are 16")
    expect_contains(census.cpu_model, "AMD", "live cpu model read from cpuinfo")
    expect_true(census.gpu_present, "live gpu present via DRM")
    if census.gpu_gfx_target != "gfx1151":
        raise Error(
            "HardwareCensus live gfx target: expected gfx1151, got "
            + census.gpu_gfx_target
        )
    expect_true(census.gpu_unified, "live gpu memory is the unified pool")
    expect_true(
        census.gpu_gtt_total_bytes > census.gpu_vram_total_bytes,
        "live unified pool exceeds the VRAM aperture",
    )
    expect_true(census.npu_present, "live npu present via accel node")
    if census.npu_driver != "amdxdna":
        raise Error(
            "HardwareCensus live npu driver: expected amdxdna, got "
            + census.npu_driver
        )
    expect_true(
        census.mem_total_bytes > 100 * 1024 * 1024 * 1024,
        "live memory total is ~128 GB class",
    )
    expect_true(
        census.mem_total_bytes < 140 * 1024 * 1024 * 1024,
        "live memory total is not beyond 128 GB class",
    )
    expect_true(census.nvme_present, "live nvme present")
    expect_true(
        census.nvme_capacity_bytes > 1024 * 1024 * 1024 * 1024,
        "live nvme capacity exceeds 1 TB",
    )
    expect_true(
        census.kernel_release.startswith("7.3"),
        "live kernel is 7.3 series",
    )
    expect_true(
        census.os_pretty.byte_length() > 0, "live OS pretty name populated"
    )
    expect_true(
        census.rocm_detail.byte_length() > 0
        and census.xrt_detail.byte_length() > 0,
        "userland absence/presence stated, not silent",
    )
    print("PASS: live census on this machine (Z13 acceptance facts, all read at runtime)")


def test_cuda_absent_is_not_an_error() raises:
    # This machine has no CUDA device. The gate must report that as
    # an absent status with zero devices -- and the census, which
    # never touches CUDA, must still complete beside it.
    var discovery = CUDAGate.discover_physical_devices()
    expect_true(
        len(discovery.devices) == 0,
        "cuda discovery reports zero devices on this machine",
    )
    expect_true(
        discovery.status.name().byte_length() > 0,
        "cuda absence carries a named status",
    )
    var census = observe_hardware_census()
    expect_true(
        census.cpu_logical > 0,
        "census completes on a CUDA-less machine",
    )
    print("PASS: absent CUDA reported as absent, census unaffected")


def main() raises:
    test_kfd_gfx_parser()
    test_os_release_and_uevent_parsers()
    test_sysfs_number_parsers()
    test_census_lines_fixture()
    test_live_census_this_machine()
    test_cuda_absent_is_not_an_error()
    print("ALL PASS: hardware census (6 groups)")
