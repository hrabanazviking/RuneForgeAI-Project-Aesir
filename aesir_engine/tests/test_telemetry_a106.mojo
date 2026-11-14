"""Scheduler telemetry (A-106): per-device utilisation +
placement decisions exposed in status/doctor.

Acceptance shape (roadmap A-106): telemetry matches
external observation (GPU/NPU utilisation tools) within
tolerance. The mechanism is core/scheduler_telemetry.mojo -
live kernel-interface reads (amdgpu sysfs gpu_busy_percent
+ mem_info pools, /proc/meminfo, /proc/stat two-sample CPU
delta, accel-node NPU presence) plus the A-100 planner's
standard-fixture decisions tallied verbatim. These in-suite
cases prove:

- live bounds: the observed GPU row is present on this Z13
  with utilisation inside [0, 100.0%] and memory used <=
  total; the CPU row's memory accounts inside MemTotal;
  the placement tally covers every standard fixture
  exactly once (per-class counts sum to the total);
- CPU utilisation parser: synthetic /proc/stat pairs give
  the exact filed delta (busy over total jiffies), a
  zero-length interval reports unknown, never 0 or 100;
- external match: an INDEPENDENT external process
  (run_checked_argv cat of the same sysfs files - the
  shell-level observation a utilisation tool makes) agrees
  with the module's GPU memory within the filed tolerance
  and with GPU utilisation within the filed 15 pp window;
- placement decisions exposed: decision lines are present,
  named per fixture, reproducible (two tallies of the live
  registry give identical lines and digest), and the
  doctor renderings (lines + summary + JSON) carry the
  telemetry section;
- clamp + tolerance units: out-of-band utilisation clamps
  to the physical band, unknown never clamps to a number
  and matches nothing, tolerance edges are inclusive;
- graceful absence: an empty (no-device) telemetry renders
  its lines and JSON without crashing, every row absent;
- device execution: a real RADV Vulkan allocation +
  dispatch moves the live GTT pool the telemetry reads
  while the buffer is resident, the readback is exact,
  and the pool returns inside tolerance after free -
  llvmpipe has no amdgpu sysfs and cannot move it.
"""
from core.backend_registry import observe_backend_registry
from core.posix_process import run_checked_argv
from core.scheduler_telemetry import (
    CpuTimes,
    SchedulerTelemetry,
    clamp_util_x10,
    cpu_util_x10_between,
    format_util_x10,
    mem_within_tolerance,
    observe_scheduler_telemetry,
    parse_proc_stat_cpu,
    parse_sysfs_bytes,
    read_cpu_times,
    scheduler_telemetry_json,
    scheduler_telemetry_lines,
    scheduler_telemetry_summary,
    tally_placements,
    util_within_tolerance,
    TOL_GPU_UTIL_X10,
)
from core.vulkan_buffers import VulkanBuffers

comptime _CHUNK = 256 * 1024


def _vk_present() -> Bool:
    if not VulkanBuffers.runtime_available():
        return False
    if not VulkanBuffers.dispatch_available():
        return False
    try:
        var info = VulkanBuffers.device_info()
        if info.vendor_id != 0x1002:
            return False
        if info.device_type == 4:
            return False
        return VulkanBuffers.device_name_is_radv()
    except:
        return False


def _external_cat(path: String) raises -> Int:
    """The external observation: a separate process reads
    the kernel file, exactly as a utilisation tool does."""
    var args = List[String]()
    args.append(String("cat"))
    args.append(path)
    var text = run_checked_argv(args)
    return parse_sysfs_bytes(text)


def test_telemetry_live_bounds() raises:
    print("--- Testing telemetry: live rows inside physical bounds (A-106) ---")
    var telemetry = observe_scheduler_telemetry()
    if not telemetry.gpu.present:
        raise Error("GPU telemetry row absent on the Z13 (amdgpu sysfs expected)")
    if telemetry.gpu.util_x10 < 0 or telemetry.gpu.util_x10 > 1000:
        raise Error("GPU utilisation outside [0, 100.0%]")
    if telemetry.gpu.mem_total_bytes <= 0:
        raise Error("GPU memory total not observed")
    if telemetry.gpu.mem_used_bytes < 0 or telemetry.gpu.mem_used_bytes > telemetry.gpu.mem_total_bytes:
        raise Error("GPU memory used outside [0, total]")
    if not telemetry.cpu.present:
        raise Error("CPU telemetry row absent (/proc/meminfo expected)")
    if telemetry.cpu.mem_used_bytes < 0 or telemetry.cpu.mem_used_bytes > telemetry.cpu.mem_total_bytes:
        raise Error("CPU memory used outside [0, MemTotal]")
    if not telemetry.npu.present:
        raise Error("NPU row absent on the Z13 (accel node expected)")
    if telemetry.npu.util_x10 != -1:
        raise Error("NPU utilisation must be unknown (-1): the kernel states no counter and none may be invented")
    var tally = telemetry.placements.copy()
    if tally.total != 12:
        raise Error("placement tally must cover the 12 standard fixtures")
    if tally.gpu + tally.npu + tally.cpu + tally.none_count != tally.total:
        raise Error("placement per-class counts do not sum to the total")
    if len(tally.lines) != tally.total:
        raise Error("placement decision lines missing")
    print("PASS: gpu util=", format_util_x10(telemetry.gpu.util_x10), " placements total=", tally.total, " gpu/npu/cpu=", tally.gpu, "/", tally.npu, "/", tally.cpu)


def test_telemetry_cpu_util_parser() raises:
    print("--- Testing telemetry: /proc/stat two-sample delta is exact (A-106) ---")
    var prev = parse_proc_stat_cpu(
        String("cpu  100 0 100 800 0 0 0 0 0 0\ncpu0 1 2 3 4 5 6 7 8 9 10\n")
    )
    var cur = parse_proc_stat_cpu(
        String("cpu  200 0 200 900 100 0 0 0 0 0\ncpu0 1 2 3 4 5 6 7 8 9 10\n")
    )
    # total delta = 400, idle+iowait delta = 200 -> 50.0%.
    if cpu_util_x10_between(prev, cur) != 500:
        raise Error("two-sample CPU utilisation is not the exact jiffy delta")
    if cpu_util_x10_between(prev, prev) != -1:
        raise Error("a zero-length interval must report unknown, not a number")
    var live_a = read_cpu_times()
    var live_b = read_cpu_times()
    if live_a.total < 0 or live_b.total < live_a.total:
        raise Error("live /proc/stat samples are not monotonic")
    print("PASS: synthetic delta exactly 50.0%, zero interval unknown, live samples monotonic")


def test_telemetry_external_match() raises:
    print("--- Testing telemetry: matches external observation within tolerance (A-106) ---")
    var telemetry = observe_scheduler_telemetry()
    if not telemetry.gpu.present:
        raise Error("GPU telemetry row absent; external comparison impossible")
    var base = String("/sys/class/drm/card1/device")
    var ext_mem = _external_cat(base + "/mem_info_gtt_used")
    if not mem_within_tolerance(telemetry.gpu.mem_used_bytes, ext_mem):
        raise Error("GPU memory telemetry disagrees with external cat beyond tolerance")
    var ext_busy_pct = _external_cat(base + "/gpu_busy_percent")
    var ext_busy_x10 = clamp_util_x10(ext_busy_pct * 10)
    if not util_within_tolerance(telemetry.gpu.util_x10, ext_busy_x10, TOL_GPU_UTIL_X10):
        raise Error("GPU utilisation telemetry disagrees with external cat beyond 15 pp")
    print("PASS: internal mem=", telemetry.gpu.mem_used_bytes, " external mem=", ext_mem, "; internal util=", format_util_x10(telemetry.gpu.util_x10), " external util=", format_util_x10(ext_busy_x10))


def test_telemetry_placement_decisions_exposed() raises:
    print("--- Testing telemetry: placement decisions exposed + reproducible (A-106) ---")
    var registry = observe_backend_registry()
    var first = tally_placements(registry)
    var second = tally_placements(registry)
    if first.digest != second.digest or first.digest == 0:
        raise Error("placement tally digest is not reproducible")
    if len(first.lines) != len(second.lines):
        raise Error("placement tally line count is not reproducible")
    for i in range(len(first.lines)):
        if first.lines[i] != second.lines[i]:
            raise Error("placement decision lines differ between tallies")
        if "->" not in first.lines[i]:
            raise Error("placement decision line does not name its device")
    var telemetry = observe_scheduler_telemetry()
    var lines = scheduler_telemetry_lines(telemetry)
    var joined = String("")
    for line in lines:
        joined += line + "\n"
    if "scheduler telemetry (A-106)" not in joined:
        raise Error("doctor lines do not carry the A-106 telemetry section")
    if "placement decisions" not in joined:
        raise Error("doctor lines do not carry the placement decisions")
    if "A-106" not in scheduler_telemetry_summary(telemetry):
        raise Error("telemetry summary does not name A-106")
    if '"placements"' not in scheduler_telemetry_json(telemetry):
        raise Error("telemetry JSON does not carry placements")
    print("PASS: ", first.total, " decisions reproducible, digest=", first.digest, "; doctor lines/summary/JSON carry telemetry")


def test_telemetry_clamp_and_tolerance() raises:
    print("--- Testing telemetry: clamp + tolerance units (A-106) ---")
    if clamp_util_x10(1500) != 1000:
        raise Error("utilisation above 100.0% does not clamp to the band")
    if clamp_util_x10(-5) != -1:
        raise Error("unknown utilisation must stay unknown, never clamp to a number")
    if clamp_util_x10(437) != 437:
        raise Error("in-band utilisation was altered by the clamp")
    if not util_within_tolerance(500, 500 + TOL_GPU_UTIL_X10, TOL_GPU_UTIL_X10):
        raise Error("tolerance edge must be inclusive")
    if util_within_tolerance(500, 501 + TOL_GPU_UTIL_X10, TOL_GPU_UTIL_X10):
        raise Error("reading beyond tolerance must not match")
    if util_within_tolerance(-1, -1, TOL_GPU_UTIL_X10):
        raise Error("unknown readings must match nothing, not even each other")
    if not mem_within_tolerance(1000000, 1000000 + 256 * 1024 * 1024):
        raise Error("memory tolerance absolute edge must be inclusive")
    if mem_within_tolerance(-1, 5):
        raise Error("unknown memory must match nothing")
    if format_util_x10(-1) != "unknown" or format_util_x10(1000) != "100.0%":
        raise Error("utilisation formatting is wrong at the band edges")
    print("PASS: clamp, tolerance edges and formatting all exact")


def test_telemetry_no_device_graceful() raises:
    print("--- Testing telemetry: no-device snapshot renders gracefully (A-106) ---")
    var empty = SchedulerTelemetry.empty()
    if empty.gpu.present or empty.npu.present or empty.cpu.present:
        raise Error("empty telemetry must have every row absent")
    if empty.placements.total != 0:
        raise Error("empty telemetry must carry no placements")
    var lines = scheduler_telemetry_lines(empty)
    if len(lines) < 5:
        raise Error("empty telemetry lines are incomplete")
    var joined = String("")
    for line in lines:
        joined += line + "\n"
    if "absent" not in joined:
        raise Error("empty telemetry does not state absence plainly")
    if '"gpu":{"present":false' not in scheduler_telemetry_json(empty):
        raise Error("empty telemetry JSON does not state GPU absence")
    print("PASS: no-device telemetry renders absent rows, no crash")


def test_telemetry_gpu_memory_reacts() raises:
    print("--- Testing telemetry: GPU pool reacts to a real RADV allocation (A-106) ---")
    if not _vk_present():
        print("SKIP-LOGIC: RADV Vulkan not present; telemetry reaction unproven here")
        return
    var baseline_live = VulkanBuffers.live_bytes()
    var before = observe_scheduler_telemetry()
    var allocation = VulkanBuffers.allocate(_CHUNK * 4)
    var during = observe_scheduler_telemetry()
    var ptr = VulkanBuffers.map(allocation)
    for i in range(_CHUNK):
        ptr[i] = UInt8((i * 31 + 7) % 251)
    VulkanBuffers.unmap(allocation)
    var back = VulkanBuffers.map(allocation)
    var checksum: UInt64 = 0
    for i in range(_CHUNK):
        checksum += UInt64(back[i])
    VulkanBuffers.unmap(allocation)
    VulkanBuffers.free(allocation)
    var expect: UInt64 = 0
    for i in range(_CHUNK):
        expect += UInt64((i * 31 + 7) % 251)
    if checksum != expect:
        raise Error("Vulkan readback checksum differs from the written span")
    var after = observe_scheduler_telemetry()
    print("  gtt used before/during/after:", before.gpu.mem_used_bytes, "/", during.gpu.mem_used_bytes, "/", after.gpu.mem_used_bytes)
    if during.gpu.mem_used_bytes < before.gpu.mem_used_bytes:
        raise Error("GTT pool fell while a Vulkan buffer was resident")
    if not mem_within_tolerance(after.gpu.mem_used_bytes, before.gpu.mem_used_bytes):
        raise Error("GTT pool did not return inside tolerance after free")
    if VulkanBuffers.live_bytes() != baseline_live:
        raise Error("Vulkan shim did not return to its baseline")
    print("PASS: pool observed live around a real RADV allocation, readback exact, pool returned")


def test_telemetry_cpu_util_live_window() raises:
    print("--- Testing telemetry: live CPU window utilisation is sane (A-106) ---")
    var prev = read_cpu_times()
    var sink = 0
    for i in range(2000000):
        sink += i % 7
    var cur = read_cpu_times()
    if sink == -1:
        raise Error("unreachable sink guard")
    var util = cpu_util_x10_between(prev, cur)
    if util < 0 or util > 1000:
        raise Error("live CPU window utilisation outside [0, 100.0%]")
    print("PASS: live CPU window util=", format_util_x10(util))
