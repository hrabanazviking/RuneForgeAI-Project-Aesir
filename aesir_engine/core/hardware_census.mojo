"""Hardware census for the Z13 campaign (roadmap slice A-001).

Every value in this census is READ at runtime from the machine's own
kernel interfaces -- /proc, /sys (sysfs), /dev device nodes, and
/etc/os-release. No machine fact (model names, core counts, gfx
targets, capacities, versions) is hardcoded anywhere in this module:
the only literals are the kernel ABI paths themselves and the field
labels. A source that cannot be read leaves its field unknown
(-1 / empty) with the reason recorded beside it; an absent device is
reported as absent-with-reason, never as an error and never as a
fabricated presence.

Sources, per kind:
- CPU -- /proc/cpuinfo via core.device_inventory.parse_cpuinfo
  (logical processors, distinct physical cores, packages, model).
- GPU -- the DRM card under /sys/class/drm: driver and PCI identity
  from the device uevent + vendor/device files, the VRAM aperture
  from mem_info_vram_total, and the unified-memory (GTT) pool from
  mem_info_gtt_total. On unified-memory parts the GTT pool IS the
  memory story: the aperture is a window, the pool is shared with
  the CPU. The gfx target (e.g. the string rendered from the KFD
  topology's gfx_target_version integer) comes from
  /sys/class/kfd/kfd/topology/nodes/*/properties -- the kernel's own
  number, formatted, never a lookup table.
- NPU -- the accel device under /sys/class/accel with its device
  node under /dev/accel: driver and PCI identity from the device
  uevent, firmware from the device fw_version file. Presence is the
  device node's existence (access(2)), not a name claim.
- Memory -- /proc/meminfo via core.native_hardware.parse_linux_memory,
  plus the memory bank clock/width the KFD topology states for the
  GPU node (mem_banks properties). Where no readable source states
  a memory speed, the census says so instead of guessing one.
- Storage -- the first NVMe controller under /sys/class/nvme
  (model, firmware) and its namespace capacity from
  /sys/block/<ns>/size (512-byte sectors, the kernel's unit).
- System -- kernel release from /proc/sys/kernel/osrelease, OS from
  /etc/os-release PRETTY_NAME, product name from DMI sysfs.
- Accelerator userlands -- ROCm and XRT are reported by the
  presence of their install roots (/opt/rocm, /opt/xilinx/xrt).
  Absence is a normal census result on a machine whose userland
  slices have not landed yet, stated plainly, never an error.
  Deeper runtime probes belong to the bring-up slices (A-005/A-007).

HOST CONTRACT: observe_hardware_census() never raises. Surfaces
(doctor, hardware list) call it once and render census_lines() or
the structured fields; the census chooses nothing and gates nothing.
"""

from std.ffi import external_call

from core.device_inventory import parse_cpuinfo
from core.native_diagnostics import human_bytes
from core.native_hardware import parse_linux_memory
from core.observation_integer import bounded_decimal
from core.posix_process import run_checked_argv


def _path_exists(path: String) -> Bool:
    var encoded = List[Int8]()
    for byte in path.as_bytes():
        encoded.append(Int8(byte))
    encoded.append(0)
    return external_call["access", Int32](encoded.unsafe_ptr(), 0) == 0


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


def parse_os_release_pretty(text: String) -> String:
    """Extract PRETTY_NAME from /etc/os-release text (quotes removed).

    Returns "" when the file states no PRETTY_NAME -- the caller
    renders that as not reported, never as an invented OS name.
    """
    for raw_line in text.split("\n"):
        var line = String(raw_line.strip())
        if not line.startswith("PRETTY_NAME="):
            continue
        var value = String(line[byte=12:])
        if (
            value.byte_length() >= 2
            and value.startswith('"')
            and value.endswith('"')
        ):
            var inner = String(value[byte=1 : value.byte_length() - 1])
            value = inner
        return value
    return String("")


def parse_uevent_value(text: String, key: String) -> String:
    """Extract one KEY=value from a sysfs uevent file, "" if absent."""
    var prefix = key + "="
    for raw_line in text.split("\n"):
        var line = String(raw_line.strip())
        if line.startswith(prefix):
            return String(line[byte=prefix.byte_length() :])
    return String("")


def _properties_value(text: String, key: String) -> String:
    """Extract one value from 'key value' properties text (KFD shape)."""
    for raw_line in text.split("\n"):
        var parts = String(raw_line.strip()).split()
        if len(parts) == 2 and String(parts[0]) == key:
            return String(parts[1])
    return String("")


def parse_kfd_gfx_target_version(text: String) raises -> Int:
    """The gfx_target_version integer from KFD node properties.

    -1 when the properties state none. A stated non-numeric value is
    refused (bounded_decimal raises): the kernel's number is read
    verbatim or the observation fails, never reinterpreted.
    """
    var value = _properties_value(text, "gfx_target_version")
    if value.byte_length() == 0:
        return -1
    return bounded_decimal(value)


def format_gfx_target(version: Int) -> String:
    """Format a KFD gfx_target_version integer as a gfx name.

    The encoding is major * 10000 + minor * 100 + stepping, so
    110501 renders as gfx1151. An unknown version (<= 0) renders as
    "unknown" -- the census never invents a target it did not read.
    """
    if version <= 0:
        return String("unknown")
    var major = version // 10000
    var minor = (version // 100) % 100
    var step = version % 100
    return "gfx" + String(major) + String(minor) + String(step)


def parse_sysfs_int(text: String) raises -> Int:
    """Parse one sysfs integer file's contents (decimal, stripped)."""
    return bounded_decimal(_stripped(text))


def nvme_capacity_bytes(sectors_text: String) raises -> Int:
    """/sys/block/<ns>/size counts 512-byte sectors; return bytes."""
    var sectors = bounded_decimal(_stripped(sectors_text))
    if sectors > 9223372036854775807 // 512:
        raise Error("HardwareCensus: NVMe capacity overflows bytes")
    return sectors * 512


def parse_mem_bank_clock_mhz(text: String) raises -> Int:
    """mem_clk_max from KFD mem-bank properties; -1 when unstated."""
    var value = _properties_value(text, "mem_clk_max")
    if value.byte_length() == 0:
        return -1
    return bounded_decimal(value)


def parse_mem_bank_width(text: String) raises -> Int:
    """width from KFD mem-bank properties; -1 when unstated."""
    var value = _properties_value(text, "width")
    if value.byte_length() == 0:
        return -1
    return bounded_decimal(value)


def _hex_id(text: String) -> String:
    """Render a sysfs hex id ('0x1002') without its prefix ('1002')."""
    var value = _stripped(text)
    if value.startswith("0x") or value.startswith("0X"):
        return String(value[byte=2:])
    return value


def _is_card_entry(entry: String) -> Bool:
    """True for an exact DRM 'card<digits>' listing entry."""
    if not entry.startswith("card"):
        return False
    var rest = String(entry[byte=4:])
    if rest.byte_length() == 0:
        return False
    for byte in rest.as_bytes():
        if byte < 48 or byte > 57:
            return False
    return True


def _is_accel_entry(entry: String) -> Bool:
    """True for an exact 'accel<digits>' listing entry."""
    if not entry.startswith("accel"):
        return False
    var rest = String(entry[byte=5:])
    if rest.byte_length() == 0:
        return False
    for byte in rest.as_bytes():
        if byte < 48 or byte > 57:
            return False
    return True


def _first_listing_entry(listing: String, kind: String) -> String:
    """First card/accel entry in an `ls` listing, "" when none."""
    for raw in listing.split("\n"):
        var entry = String(raw.strip())
        if kind == "card" and _is_card_entry(entry):
            return entry
        if kind == "accel" and _is_accel_entry(entry):
            return entry
    return String("")


struct HardwareCensus(Copyable, ImplicitlyCopyable):
    """The whole runtime-observed truth for this machine.

    Counts and byte sizes are -1 when their source stated nothing;
    strings are empty when unstated; every absent kind carries the
    reason it is absent. Nothing here is filled in by assumption.
    """

    var cpu_model: String
    var cpu_logical: Int
    var cpu_physical: Int
    var cpu_packages: Int
    var cpu_reason: String
    var gpu_present: Bool
    var gpu_driver: String
    var gpu_pci_id: String
    var gpu_gfx_target: String
    var gpu_vram_total_bytes: Int
    var gpu_gtt_total_bytes: Int
    var gpu_unified: Bool
    var gpu_reason: String
    var npu_present: Bool
    var npu_node: String
    var npu_driver: String
    var npu_pci_id: String
    var npu_fw_version: String
    var npu_reason: String
    var mem_total_bytes: Int
    var mem_available_bytes: Int
    var mem_clk_max_mhz: Int
    var mem_bank_width: Int
    var mem_reason: String
    var nvme_present: Bool
    var nvme_model: String
    var nvme_firmware: String
    var nvme_capacity_bytes: Int
    var nvme_reason: String
    var kernel_release: String
    var os_pretty: String
    var product_name: String
    var rocm_present: Bool
    var rocm_detail: String
    var xrt_present: Bool
    var xrt_detail: String

    def __init__(out self):
        self.cpu_model = String("")
        self.cpu_logical = -1
        self.cpu_physical = -1
        self.cpu_packages = -1
        self.cpu_reason = String("not probed")
        self.gpu_present = False
        self.gpu_driver = String("")
        self.gpu_pci_id = String("")
        self.gpu_gfx_target = String("")
        self.gpu_vram_total_bytes = -1
        self.gpu_gtt_total_bytes = -1
        self.gpu_unified = False
        self.gpu_reason = String("not probed")
        self.npu_present = False
        self.npu_node = String("")
        self.npu_driver = String("")
        self.npu_pci_id = String("")
        self.npu_fw_version = String("")
        self.npu_reason = String("not probed")
        self.mem_total_bytes = -1
        self.mem_available_bytes = -1
        self.mem_clk_max_mhz = -1
        self.mem_bank_width = -1
        self.mem_reason = String("not probed")
        self.nvme_present = False
        self.nvme_model = String("")
        self.nvme_firmware = String("")
        self.nvme_capacity_bytes = -1
        self.nvme_reason = String("not probed")
        self.kernel_release = String("")
        self.os_pretty = String("")
        self.product_name = String("")
        self.rocm_present = False
        self.rocm_detail = String("not probed")
        self.xrt_present = False
        self.xrt_detail = String("not probed")


def census_lines(census: HardwareCensus) -> List[String]:
    """Render the census as one line per kind, bench style.

    Every kind appears exactly once: quantified from its observed
    fields, or absent/not-reported with its recorded reason.
    """
    var lines = List[String]()
    if census.cpu_logical > 0:
        var cpu = "cpu: " + census.cpu_model + " — " + String(
            census.cpu_logical
        ) + " logical"
        if census.cpu_physical > 0:
            cpu += ", " + String(census.cpu_physical) + " physical cores"
            if census.cpu_packages > 0:
                cpu += (
                    " in "
                    + String(census.cpu_packages)
                    + " package"
                    + (String("s") if census.cpu_packages != 1 else String(""))
                )
            if census.cpu_logical % census.cpu_physical == 0:
                cpu += (
                    ", "
                    + String(census.cpu_logical // census.cpu_physical)
                    + " thread(s) per core"
                )
        else:
            cpu += ", physical core count not reported by cpuinfo"
        lines.append(cpu)
    else:
        lines.append("cpu: not observed — " + census.cpu_reason)
    if census.gpu_present:
        var gpu = "gpu: present — " + census.gpu_gfx_target
        gpu += ", driver " + census.gpu_driver
        gpu += ", PCI " + census.gpu_pci_id
        gpu += ", VRAM aperture " + human_bytes(census.gpu_vram_total_bytes)
        if census.gpu_gtt_total_bytes > 0:
            gpu += ", unified pool (GTT) " + human_bytes(
                census.gpu_gtt_total_bytes
            )
        if census.gpu_unified:
            gpu += "; memory = unified pool shared with CPU"
        lines.append(gpu)
    else:
        lines.append("gpu: absent — " + census.gpu_reason)
    if census.npu_present:
        var npu = "npu: present — node " + census.npu_node
        npu += ", driver " + census.npu_driver
        npu += ", PCI " + census.npu_pci_id
        if census.npu_fw_version.byte_length() > 0:
            npu += ", firmware " + census.npu_fw_version
        lines.append(npu)
    else:
        lines.append("npu: absent — " + census.npu_reason)
    if census.mem_total_bytes > 0:
        var mem = "memory: " + human_bytes(census.mem_total_bytes) + " total"
        mem += ", " + human_bytes(census.mem_available_bytes) + " available"
        if census.mem_clk_max_mhz > 0:
            mem += (
                "; memory clock "
                + String(census.mem_clk_max_mhz)
                + " MHz (KFD memory bank)"
            )
            if census.mem_bank_width > 0:
                mem += ", bank width " + String(census.mem_bank_width)
        else:
            mem += "; memory speed not reported by readable sources"
        lines.append(mem)
    else:
        lines.append("memory: not observed — " + census.mem_reason)
    if census.nvme_present:
        var storage = "storage: NVMe " + census.nvme_model
        storage += " — " + human_bytes(census.nvme_capacity_bytes)
        if census.nvme_firmware.byte_length() > 0:
            storage += ", firmware " + census.nvme_firmware
        lines.append(storage)
    else:
        lines.append("storage: absent — " + census.nvme_reason)
    var system = "system: "
    system += (
        census.product_name
        if census.product_name.byte_length() > 0
        else String("product name not reported")
    )
    system += ", kernel " + (
        census.kernel_release
        if census.kernel_release.byte_length() > 0
        else String("not reported")
    )
    system += ", OS " + (
        census.os_pretty
        if census.os_pretty.byte_length() > 0
        else String("not reported")
    )
    lines.append(system)
    lines.append(
        "rocm: "
        + (String("present") if census.rocm_present else String("absent"))
        + " — "
        + census.rocm_detail
    )
    lines.append(
        "xrt: "
        + (String("present") if census.xrt_present else String("absent"))
        + " — "
        + census.xrt_detail
    )
    return lines^


def observe_hardware_census() -> HardwareCensus:
    """Probe this machine at call time and return its census.

    Never raises: each kind's probe failure becomes that kind's
    absent/not-observed fields with the reason recorded, because
    the honest output is the census itself, reasons included.
    """
    var census = HardwareCensus()

    try:
        var facts = parse_cpuinfo(_read_text("/proc/cpuinfo"))
        census.cpu_model = facts.model
        census.cpu_logical = facts.logical
        census.cpu_physical = facts.physical_cores
        census.cpu_packages = facts.packages
        census.cpu_reason = String("")
    except cpu_error:
        census.cpu_reason = "cpuinfo could not be read or parsed: " + String(
            cpu_error
        )

    try:
        var host = parse_linux_memory(_read_text("/proc/meminfo"))
        census.mem_total_bytes = host.total_bytes
        census.mem_available_bytes = host.available_bytes
        census.mem_reason = String("")
    except mem_error:
        census.mem_reason = "meminfo could not be read or parsed: " + String(
            mem_error
        )

    census.kernel_release = _stripped(
        _read_or_empty("/proc/sys/kernel/osrelease")
    )
    census.os_pretty = parse_os_release_pretty(_read_or_empty("/etc/os-release"))
    census.product_name = _stripped(
        _read_or_empty("/sys/class/dmi/id/product_name")
    )

    # GPU: DRM card identity/aperture, then the KFD topology for the
    # gfx target and the memory-bank clock (same probe pass).
    var card = String("")
    try:
        card = _first_listing_entry(
            run_checked_argv(["ls", "/sys/class/drm"], 4096), "card"
        )
    except:
        card = String("")
    if card.byte_length() > 0:
        var base = "/sys/class/drm/" + card + "/device"
        census.gpu_present = True
        census.gpu_reason = String("")
        census.gpu_driver = parse_uevent_value(
            _read_or_empty(base + "/uevent"), "DRIVER"
        )
        var vendor = _hex_id(_read_or_empty(base + "/vendor"))
        var device = _hex_id(_read_or_empty(base + "/device"))
        if vendor.byte_length() > 0 and device.byte_length() > 0:
            census.gpu_pci_id = vendor + ":" + device
        try:
            census.gpu_vram_total_bytes = parse_sysfs_int(
                _read_text(base + "/mem_info_vram_total")
            )
        except:
            census.gpu_vram_total_bytes = -1
        try:
            census.gpu_gtt_total_bytes = parse_sysfs_int(
                _read_text(base + "/mem_info_gtt_total")
            )
        except:
            census.gpu_gtt_total_bytes = -1
        census.gpu_unified = census.gpu_gtt_total_bytes > 0
    else:
        census.gpu_reason = (
            "no DRM card device listed under /sys/class/drm"
        )
    try:
        var nodes = run_checked_argv(
            ["ls", "/sys/class/kfd/kfd/topology/nodes"], 4096
        )
        for raw_node in nodes.split("\n"):
            var node = String(raw_node.strip())
            if node.byte_length() == 0:
                continue
            var props = _read_or_empty(
                "/sys/class/kfd/kfd/topology/nodes/"
                + node
                + "/properties"
            )
            if props.byte_length() == 0:
                continue
            var version = -1
            try:
                version = parse_kfd_gfx_target_version(props)
            except:
                version = -1
            if version > 0:
                census.gpu_gfx_target = format_gfx_target(version)
                var bank = _read_or_empty(
                    "/sys/class/kfd/kfd/topology/nodes/"
                    + node
                    + "/mem_banks/0/properties"
                )
                try:
                    census.mem_clk_max_mhz = parse_mem_bank_clock_mhz(bank)
                except:
                    census.mem_clk_max_mhz = -1
                try:
                    census.mem_bank_width = parse_mem_bank_width(bank)
                except:
                    census.mem_bank_width = -1
                break
    except:
        pass
    if census.gpu_present and census.gpu_gfx_target.byte_length() == 0:
        census.gpu_gfx_target = String(
            "unknown (KFD topology did not state a gfx target)"
        )

    # NPU: the accel device node is the presence fact; sysfs carries
    # the driver, PCI identity, and firmware beside it.
    var accel = String("")
    try:
        accel = _first_listing_entry(
            run_checked_argv(["ls", "/sys/class/accel"], 4096), "accel"
        )
    except:
        accel = String("")
    if accel.byte_length() > 0:
        census.npu_node = "/dev/accel/" + accel
        var abase = "/sys/class/accel/" + accel + "/device"
        var uevent = _read_or_empty(abase + "/uevent")
        census.npu_driver = parse_uevent_value(uevent, "DRIVER")
        census.npu_pci_id = parse_uevent_value(uevent, "PCI_ID")
        census.npu_fw_version = _stripped(_read_or_empty(abase + "/fw_version"))
        if _path_exists(census.npu_node):
            census.npu_present = True
            census.npu_reason = String("")
        else:
            census.npu_reason = (
                "sysfs lists "
                + accel
                + " but "
                + census.npu_node
                + " does not exist"
            )
    else:
        census.npu_reason = "no accel device listed under /sys/class/accel"

    # Storage: first NVMe controller + its first namespace.
    var nvme = String("")
    try:
        var controllers = run_checked_argv(["ls", "/sys/class/nvme"], 4096)
        for raw_ctl in controllers.split("\n"):
            var ctl = String(raw_ctl.strip())
            if ctl.startswith("nvme"):
                nvme = ctl
                break
    except:
        nvme = String("")
    if nvme.byte_length() > 0:
        census.nvme_model = _stripped(
            _read_or_empty("/sys/class/nvme/" + nvme + "/model")
        )
        census.nvme_firmware = _stripped(
            _read_or_empty("/sys/class/nvme/" + nvme + "/firmware_rev")
        )
        try:
            var blocks = run_checked_argv(["ls", "/sys/block"], 8192)
            for raw_block in blocks.split("\n"):
                var block = String(raw_block.strip())
                if block.startswith(nvme) and block.byte_length() > nvme.byte_length():
                    census.nvme_capacity_bytes = nvme_capacity_bytes(
                        _read_text("/sys/block/" + block + "/size")
                    )
                    break
        except:
            census.nvme_capacity_bytes = -1
        census.nvme_present = True
        census.nvme_reason = String("")
    else:
        census.nvme_reason = "no NVMe controller listed under /sys/class/nvme"

    # Accelerator userlands: install-root presence, stated as such.
    census.rocm_present = _path_exists("/opt/rocm")
    census.rocm_detail = (
        String("install root /opt/rocm present")
        if census.rocm_present
        else String(
            "install root /opt/rocm absent (ROCm userland not installed)"
        )
    )
    census.xrt_present = _path_exists("/opt/xilinx/xrt")
    census.xrt_detail = (
        String("install root /opt/xilinx/xrt present")
        if census.xrt_present
        else String(
            "install root /opt/xilinx/xrt absent (XRT userland not installed)"
        )
    )
    return census
