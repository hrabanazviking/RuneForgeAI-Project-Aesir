# core/scheduler_telemetry.mojo
# A-106: Scheduler telemetry - per-device utilisation +
# placement decisions exposed in status/doctor.
#
# Roadmap acceptance: telemetry matches external observation
# (GPU/NPU utilisation tools) within tolerance. This module
# is the single source both doctor renderings (text + JSON)
# consume, so the numbers a user sees are the numbers the
# tests grade - there is no second, divergent telemetry path.
#
# Sources, all READ at runtime from kernel interfaces, the
# same discipline as A-001 (hardware census) and A-018
# (thermal/power); nothing is hardcoded or fabricated:
# - GPU (Radeon 8060S, gfx1151, amdgpu): utilisation from
#   /sys/class/drm/card*/device/gpu_busy_percent (the
#   kernel's own interval-averaged busy counter, percent);
#   memory from mem_info_vram_used/total and
#   mem_info_gtt_used/total. On this unified-memory part the
#   GTT pool is the memory story (A-001): the telemetry
#   reports the GTT figures and says so in its source label.
# - CPU: memory from /proc/meminfo (MemTotal/MemAvailable);
#   utilisation is a TWO-SAMPLE quantity - /proc/stat jiffy
#   deltas via read_cpu_times() + cpu_util_x10_between().
#   A single snapshot states util unknown (-1) rather than
#   inventing a number from boot-cumulative jiffies.
# - NPU (XDNA 2, amdxdna): presence is the /sys/class/accel
#   device node (A-001 discipline). The kernel exposes NO
#   utilisation counter for this device on this machine -
#   xrt-smi is the external observer - so NPU utilisation is
#   reported unknown (-1) with that reason stated, never a
#   fabricated percentage. Its placement decisions ARE
#   telemetry and are reported in full.
# - Placement decisions: the A-100 planner's verdicts on the
#   12 standard fixtures under the standard context
#   (plan_op over standard_fixtures()), tallied by device
#   class with each decision line preserved verbatim and an
#   FNV-1a digest (A-102) as the reproducibility anchor.
#   A-103 replans and A-105 fairness act on these decisions;
#   telemetry only observes and reports them.
#
# Tolerance law (the acceptance comparison): GPU utilisation
# is compared in tenths of a percent with
# TOL_GPU_UTIL_X10 = 150 (15.0 percentage points) - both
# gpu_busy_percent and external tools (rocm-smi --showuse)
# interval-average over different windows, so back-to-back
# samples of a changing load legitimately differ; memory is
# compared with mem_within_tolerance() (256 MiB absolute or
# 5% relative, whichever is larger - allocator granularity
# on a 128 GiB unified pool). A comparison outside tolerance
# is a telemetry defect, not a rounding note.
#
# Honesty: accelerator-visible is not accelerator-run.
# Utilisation here is the kernel's record of device busy
# time and allocated pool bytes; the A-106 bench drives a
# real RADV Vulkan workload and watches these counters move
# (and return), which is the device-execution evidence for
# the telemetry itself. llvmpipe has no amdgpu sysfs node
# and can never move these counters.

from std.ffi import external_call

from core.backend_registry import BackendRegistry, observe_backend_registry
from core.device_policy import DEVICE_CPU, DEVICE_GPU, DEVICE_NONE, DEVICE_NPU
from core.native_diagnostics import human_bytes
from core.observation_integer import bounded_decimal
from core.placement_planner import plan_op, standard_context, standard_fixtures
from core.spillover_policy import fnv1a64

comptime TOL_GPU_UTIL_X10 = 150
comptime TOL_MEM_ABS_BYTES = 256 * 1024 * 1024


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


def parse_sysfs_percent(text: String) raises -> Int:
    """Parse one sysfs percent file (decimal, stripped)."""
    return bounded_decimal(_stripped(text))


def parse_sysfs_bytes(text: String) raises -> Int:
    """Parse one sysfs byte-count file (decimal, stripped)."""
    return bounded_decimal(_stripped(text))


def clamp_util_x10(value: Int) -> Int:
    """Clamp a utilisation in tenths of a percent to the
    physical band. Unknown (-1) stays unknown: clamping an
    absent reading to 0 would fabricate an idle device."""
    if value < 0:
        return -1
    if value > 1000:
        return 1000
    return value


def util_within_tolerance(a_x10: Int, b_x10: Int, tol_x10: Int) -> Bool:
    """True when two utilisation readings (tenths of a
    percent) differ by at most tol_x10. An unknown reading
    matches nothing, not even another unknown."""
    if a_x10 < 0 or b_x10 < 0:
        return False
    var diff = a_x10 - b_x10
    if diff < 0:
        diff = -diff
    return diff <= tol_x10


def mem_within_tolerance(a_bytes: Int, b_bytes: Int) -> Bool:
    """True when two byte counts agree within the A-106
    memory tolerance: 256 MiB absolute or 5% of the larger
    figure, whichever is greater. Unknown (-1) matches
    nothing."""
    if a_bytes < 0 or b_bytes < 0:
        return False
    var diff = a_bytes - b_bytes
    if diff < 0:
        diff = -diff
    if diff <= TOL_MEM_ABS_BYTES:
        return True
    var larger = a_bytes if a_bytes > b_bytes else b_bytes
    return diff * 20 <= larger


def format_util_x10(value: Int) -> String:
    """123 -> '12.3%'; unknown (-1) -> 'unknown'."""
    if value < 0:
        return String("unknown")
    return String(value // 10) + "." + String(value % 10) + "%"


struct CpuTimes(Copyable, ImplicitlyCopyable):
    """One /proc/stat aggregate sample: total and idle
    jiffies. Utilisation exists only between two samples."""

    var total: Int
    var idle: Int

    def __init__(out self, total: Int, idle: Int):
        self.total = total
        self.idle = idle


def parse_proc_stat_cpu(text: String) raises -> CpuTimes:
    """Parse the aggregate 'cpu ' line of /proc/stat text.

    total is the sum of every jiffy column; idle is the
    idle + iowait columns (the kernel's own split). A text
    with no aggregate line raises - the observation failed,
    it is never reinterpreted as zeros."""
    for raw_line in text.split("\n"):
        var line = String(raw_line.strip())
        if not line.startswith("cpu "):
            continue
        var parts = line.split()
        # parts[0] is 'cpu'; columns follow in kernel order:
        # user nice system idle iowait irq softirq steal
        # guest guest_nice (guest already counted in user).
        if len(parts) < 6:
            raise Error("/proc/stat cpu line has too few columns")
        var total = 0
        for i in range(1, len(parts)):
            total += bounded_decimal(String(parts[i]))
        var idle = bounded_decimal(String(parts[4])) + bounded_decimal(
            String(parts[5])
        )
        return CpuTimes(total, idle)
    raise Error("/proc/stat text has no aggregate cpu line")


def cpu_util_x10_between(prev: CpuTimes, cur: CpuTimes) -> Int:
    """Utilisation in tenths of a percent between two
    samples: busy delta over total delta. -1 when the
    interval carries no time (equal or rewound counters)."""
    var total_delta = cur.total - prev.total
    if total_delta <= 0:
        return -1
    var idle_delta = cur.idle - prev.idle
    if idle_delta < 0:
        idle_delta = 0
    if idle_delta > total_delta:
        idle_delta = total_delta
    var busy_delta = total_delta - idle_delta
    return clamp_util_x10(busy_delta * 1000 // total_delta)


def read_cpu_times() -> CpuTimes:
    """Live aggregate /proc/stat sample; CpuTimes(-1, -1)
    when unreadable (utilisation then reports unknown)."""
    try:
        return parse_proc_stat_cpu(_read_text("/proc/stat"))
    except:
        return CpuTimes(-1, -1)


struct DeviceTelemetry(Copyable, ImplicitlyCopyable):
    """One device's telemetry row. util_x10 / byte fields
    are -1 when the kernel states no value; note names the
    source (or the reason there is none) beside every row."""

    var name: String
    var present: Bool
    var util_x10: Int
    var mem_used_bytes: Int
    var mem_total_bytes: Int
    var source: String

    def __init__(
        out self,
        name: String,
        present: Bool,
        util_x10: Int,
        mem_used_bytes: Int,
        mem_total_bytes: Int,
        source: String,
    ):
        self.name = name
        self.present = present
        self.util_x10 = util_x10
        self.mem_used_bytes = mem_used_bytes
        self.mem_total_bytes = mem_total_bytes
        self.source = source

    @staticmethod
    def absent(name: String, source: String) -> DeviceTelemetry:
        return DeviceTelemetry(name, False, -1, -1, -1, source)


struct PlacementTally(Copyable):
    """The A-100 planner's standard-fixture decisions,
    tallied by device class, lines preserved verbatim."""

    var total: Int
    var gpu: Int
    var npu: Int
    var cpu: Int
    var none_count: Int
    var digest: UInt64
    var lines: List[String]

    def __init__(
        out self,
        total: Int,
        gpu: Int,
        npu: Int,
        cpu: Int,
        none_count: Int,
        digest: UInt64,
        lines: List[String],
    ):
        self.total = total
        self.gpu = gpu
        self.npu = npu
        self.cpu = cpu
        self.none_count = none_count
        self.digest = digest
        self.lines = lines.copy()


def tally_placements(registry: BackendRegistry) -> PlacementTally:
    """Decide every standard fixture on this registry under
    the standard context and tally by device class. Pure
    function of the registry: the same registry yields the
    same lines and the same digest on every call."""
    var context = standard_context()
    var total = 0
    var gpu = 0
    var npu = 0
    var cpu = 0
    var none_count = 0
    var lines = List[String]()
    var joined = String("")
    for fixture in standard_fixtures():
        var decision = plan_op(registry, context, fixture.request)
        total += 1
        if decision.device_class == DEVICE_GPU:
            gpu += 1
        elif decision.device_class == DEVICE_NPU:
            npu += 1
        elif decision.device_class == DEVICE_CPU:
            cpu += 1
        else:
            none_count += 1
        var line = fixture.name + ": " + decision.line()
        lines.append(line)
        joined += line + "\n"
    return PlacementTally(
        total, gpu, npu, cpu, none_count, fnv1a64(joined), lines^
    )


struct SchedulerTelemetry(Copyable):
    """The full A-106 snapshot: one row per device plus
    the placement tally. observe_scheduler_telemetry()
    never raises; an unreadable source leaves its row
    absent/unknown with the reason in its source label."""

    var cpu: DeviceTelemetry
    var gpu: DeviceTelemetry
    var npu: DeviceTelemetry
    var placements: PlacementTally

    def __init__(
        out self,
        cpu: DeviceTelemetry,
        gpu: DeviceTelemetry,
        npu: DeviceTelemetry,
        placements: PlacementTally,
    ):
        self.cpu = cpu
        self.gpu = gpu
        self.npu = npu
        self.placements = placements.copy()

    @staticmethod
    def empty() -> SchedulerTelemetry:
        """The no-device snapshot: every row absent, no
        placements. Renders without crashing - doctor on a
        machine with no accelerator still diagnoses."""
        return SchedulerTelemetry(
            DeviceTelemetry.absent(
                String("cpu"), String("not observed")
            ),
            DeviceTelemetry.absent(
                String("gpu"), String("no amdgpu sysfs node observed")
            ),
            DeviceTelemetry.absent(
                String("npu"), String("no accel sysfs node observed")
            ),
            PlacementTally(0, 0, 0, 0, 0, UInt64(0), List[String]()),
        )


def _gpu_card_base() -> String:
    """The first DRM card exposing amdgpu busy accounting,
    or '' when no card does."""
    for card in List[String]([String("card1"), String("card0"), String("card2")]):
        var base = "/sys/class/drm/" + card + "/device"
        if _path_exists(base + "/gpu_busy_percent"):
            return base
    return String("")


def _meminfo_value(text: String, key: String) -> Int:
    """One 'Key: N kB' value from /proc/meminfo text, in
    bytes; -1 when the key is absent or unparsable."""
    var prefix = key + ":"
    for raw_line in text.split("\n"):
        var line = String(raw_line.strip())
        if not line.startswith(prefix):
            continue
        var parts = line.split()
        if len(parts) < 2:
            return -1
        try:
            return bounded_decimal(String(parts[1])) * 1024
        except:
            return -1
    return -1


def observe_scheduler_telemetry() -> SchedulerTelemetry:
    """Collect one telemetry snapshot from the live kernel
    interfaces and the live backend registry. Never raises."""
    # CPU row: memory from /proc/meminfo; utilisation needs
    # a two-sample delta, so a snapshot states it unknown
    # and names the two-sample path in the source label.
    var cpu = DeviceTelemetry.absent(
        String("cpu"), String("/proc/meminfo not readable")
    )
    var meminfo = _read_or_empty("/proc/meminfo")
    if meminfo.byte_length() > 0:
        var mem_total = _meminfo_value(meminfo, "MemTotal")
        var mem_avail = _meminfo_value(meminfo, "MemAvailable")
        if mem_total > 0 and mem_avail >= 0:
            cpu = DeviceTelemetry(
                String("cpu"),
                True,
                -1,
                mem_total - mem_avail,
                mem_total,
                String(
                    "/proc/meminfo; utilisation via /proc/stat"
                    " two-sample delta (read_cpu_times)"
                ),
            )
    # GPU row: amdgpu sysfs. Unified memory reports the GTT
    # pool; fall back to the VRAM aperture when no GTT pool
    # is stated.
    var gpu = DeviceTelemetry.absent(
        String("gpu"), String("no amdgpu sysfs node observed")
    )
    var base = _gpu_card_base()
    if base.byte_length() > 0:
        var util = -1
        try:
            util = clamp_util_x10(
                parse_sysfs_percent(_read_text(base + "/gpu_busy_percent"))
                * 10
            )
        except:
            util = -1
        var used = -1
        var total_b = -1
        var pool = String("gtt (unified)")
        try:
            used = parse_sysfs_bytes(_read_text(base + "/mem_info_gtt_used"))
            total_b = parse_sysfs_bytes(
                _read_text(base + "/mem_info_gtt_total")
            )
        except:
            used = -1
            total_b = -1
        if total_b <= 0:
            pool = String("vram aperture")
            try:
                used = parse_sysfs_bytes(
                    _read_text(base + "/mem_info_vram_used")
                )
                total_b = parse_sysfs_bytes(
                    _read_text(base + "/mem_info_vram_total")
                )
            except:
                used = -1
                total_b = -1
        gpu = DeviceTelemetry(
            String("gpu"),
            True,
            util,
            used,
            total_b,
            String("amdgpu sysfs ") + base + String("; pool ") + pool,
        )
    # NPU row: presence is the accel device node; the
    # kernel states no utilisation counter for it here.
    var npu = DeviceTelemetry.absent(
        String("npu"), String("no accel sysfs node observed")
    )
    if _path_exists("/sys/class/accel/accel0/device/fw_version"):
        npu = DeviceTelemetry(
            String("npu"),
            True,
            -1,
            -1,
            -1,
            String(
                "/sys/class/accel/accel0; kernel states no"
                " utilisation counter (xrt-smi is the external"
                " observer) - reported unknown, never invented"
            ),
        )
    var registry = observe_backend_registry()
    var placements = tally_placements(registry)
    return SchedulerTelemetry(cpu, gpu, npu, placements)


def _device_line(device: DeviceTelemetry) -> String:
    if not device.present:
        return device.name + ": absent (" + device.source + ")"
    var line = device.name + ": util " + format_util_x10(device.util_x10)
    if device.mem_total_bytes > 0:
        line += (
            " | mem "
            + human_bytes(device.mem_used_bytes)
            + " of "
            + human_bytes(device.mem_total_bytes)
        )
    else:
        line += " | mem unknown"
    line += " | source " + device.source
    return line


def scheduler_telemetry_lines(telemetry: SchedulerTelemetry) -> List[String]:
    """The doctor/status text rendering: one utilisation
    row per device, then the placement decisions verbatim."""
    var lines = List[String]()
    lines.append(String("scheduler telemetry (A-106): per-device utilisation + placement decisions"))
    lines.append(_device_line(telemetry.cpu))
    lines.append(_device_line(telemetry.gpu))
    lines.append(_device_line(telemetry.npu))
    var tally = telemetry.placements.copy()
    lines.append(
        "placement decisions (A-100 planner, standard fixtures): total "
        + String(tally.total)
        + " | gpu "
        + String(tally.gpu)
        + " | npu "
        + String(tally.npu)
        + " | cpu "
        + String(tally.cpu)
        + " | none "
        + String(tally.none_count)
        + " | digest "
        + String(tally.digest)
    )
    for line in tally.lines:
        lines.append(String("  ") + line)
    return lines^


def scheduler_telemetry_summary(telemetry: SchedulerTelemetry) -> String:
    """One-line summary (doctor JSON rendering anchor)."""
    return (
        "A-106 scheduler telemetry: gpu util "
        + format_util_x10(telemetry.gpu.util_x10)
        + ", placements "
        + String(telemetry.placements.total)
        + " (gpu "
        + String(telemetry.placements.gpu)
        + "/npu "
        + String(telemetry.placements.npu)
        + "/cpu "
        + String(telemetry.placements.cpu)
        + "), tolerance gpu util +/"
        + String(TOL_GPU_UTIL_X10 // 10)
        + " pp, mem 256 MiB or 5%"
    )


def _json_int(value: Int) -> String:
    """Unknown measurements are null, never negative."""
    return "null" if value < 0 else String(value)


def scheduler_telemetry_json(telemetry: SchedulerTelemetry) -> String:
    """The doctor JSON rendering of one snapshot."""
    var tally = telemetry.placements.copy()
    var out = String('{"summary":')
    out += '"' + scheduler_telemetry_summary(telemetry) + '"'
    out += ',"tolerance":{"gpu_util_x10":' + String(TOL_GPU_UTIL_X10)
    out += ',"mem_abs_bytes":' + String(TOL_MEM_ABS_BYTES) + "}"
    out += ',"cpu":{"present":' + ("true" if telemetry.cpu.present else "false")
    out += ',"util_x10":' + _json_int(telemetry.cpu.util_x10)
    out += ',"mem_used_bytes":' + _json_int(telemetry.cpu.mem_used_bytes)
    out += ',"mem_total_bytes":' + _json_int(telemetry.cpu.mem_total_bytes) + "}"
    out += ',"gpu":{"present":' + ("true" if telemetry.gpu.present else "false")
    out += ',"util_x10":' + _json_int(telemetry.gpu.util_x10)
    out += ',"mem_used_bytes":' + _json_int(telemetry.gpu.mem_used_bytes)
    out += ',"mem_total_bytes":' + _json_int(telemetry.gpu.mem_total_bytes) + "}"
    out += ',"npu":{"present":' + ("true" if telemetry.npu.present else "false")
    out += ',"util_x10":' + _json_int(telemetry.npu.util_x10) + "}"
    out += ',"placements":{"total":' + String(tally.total)
    out += ',"gpu":' + String(tally.gpu)
    out += ',"npu":' + String(tally.npu)
    out += ',"cpu":' + String(tally.cpu)
    out += ',"none":' + String(tally.none_count)
    out += ',"digest":' + String(tally.digest) + "}}"
    return out
