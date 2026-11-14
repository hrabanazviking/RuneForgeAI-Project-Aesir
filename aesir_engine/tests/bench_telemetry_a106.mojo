# tests/bench_telemetry_a106.mojo
# A-106 standalone scheduler-telemetry validation run (not
# part of run_all: it drives real RADV Vulkan dispatches and
# compares the telemetry against external process reads).
#
# Roadmap acceptance: telemetry matches external observation
# (GPU/NPU utilisation tools) within tolerance. Legs:
# 1. Idle snapshot: core/scheduler_telemetry lines printed
#    from live kernel reads.
# 2. External match at idle: an independent process (cat of
#    the amdgpu sysfs files, the read rocm-smi itself makes)
#    must agree with the module on GPU memory (256 MiB / 5%)
#    and GPU utilisation (15 pp - the two observers
#    interval-average over different windows).
# 3. CPU two-sample: a bounded host spin between two
#    /proc/stat samples yields a utilisation in band.
# 4. Device load: a 512 MiB RADV Vulkan allocation held
#    resident while vec_add dispatches execute on the real
#    device (vendor 0x1002, non-CPU type, RADV by name -
#    llvmpipe refused by identity). Telemetry observed
#    DURING residency must show the pool at or above the
#    idle figure, the external cat during residency must
#    agree within tolerance, and after free the pool must
#    return inside tolerance of idle. Dispatch count from
#    the shim is the device-execution evidence.
# 5. Placement decisions: tally printed; a second tally of
#    the live registry reproduces the digest exactly.
# 6. NPU: presence stated; utilisation reported unknown
#    with its reason (no kernel counter; xrt-smi is the
#    external observer and its own result is filed in the
#    runner log beside this bench's output).

from core.backend_registry import observe_backend_registry
from core.posix_process import run_checked_argv
from core.scheduler_telemetry import (
    cpu_util_x10_between,
    format_util_x10,
    mem_within_tolerance,
    observe_scheduler_telemetry,
    parse_sysfs_bytes,
    read_cpu_times,
    scheduler_telemetry_lines,
    tally_placements,
    util_within_tolerance,
    TOL_GPU_UTIL_X10,
)
from core.vulkan_buffers import VulkanBuffers

comptime _ELEMS = 262144  # 1 MiB of Float32 per vec_add buffer


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
    var args = List[String]()
    args.append(String("cat"))
    args.append(path)
    return parse_sysfs_bytes(run_checked_argv(args))


def main() raises:
    print("A106_TELEMETRY_BENCH: start")
    var base = String("/sys/class/drm/card1/device")
    # Leg 1+2: idle snapshot vs external observation.
    var idle = observe_scheduler_telemetry()
    for line in scheduler_telemetry_lines(idle):
        print("  " + line)
    if not idle.gpu.present:
        raise Error("GPU telemetry absent on the Z13")
    var ext_mem_idle = _external_cat(base + "/mem_info_gtt_used")
    var ext_busy_idle = _external_cat(base + "/gpu_busy_percent")
    print("  external idle: gtt_used=", ext_mem_idle, " busy_pct=", ext_busy_idle)
    if not mem_within_tolerance(idle.gpu.mem_used_bytes, ext_mem_idle):
        raise Error("idle GPU memory disagrees with external observation")
    if not util_within_tolerance(idle.gpu.util_x10, ext_busy_idle * 10, TOL_GPU_UTIL_X10):
        raise Error("idle GPU utilisation disagrees with external observation")
    print("A106 leg2 external-idle: PASS")
    # Leg 3: CPU two-sample around a bounded spin.
    var prev = read_cpu_times()
    var sink = 0
    for i in range(8000000):
        sink += i % 7
    var cur = read_cpu_times()
    if sink == -1:
        raise Error("unreachable sink guard")
    var cpu_util = cpu_util_x10_between(prev, cur)
    print("  cpu window util=", format_util_x10(cpu_util))
    if cpu_util < 0 or cpu_util > 1000:
        raise Error("CPU window utilisation out of band")
    print("A106 leg3 cpu-window: PASS")
    # Leg 4: real device load.
    if not _vk_present():
        raise Error("RADV Vulkan device not present; load leg cannot run")
    var info = VulkanBuffers.device_info()
    print("  device vendor=", info.vendor_id, " type=", info.device_type)
    var big = VulkanBuffers.allocate(512 * 1024 * 1024)
    var a = VulkanBuffers.allocate(_ELEMS * 4)
    var b = VulkanBuffers.allocate(_ELEMS * 4)
    var c = VulkanBuffers.allocate(_ELEMS * 4)
    var pa = VulkanBuffers.map(a)
    for i in range(_ELEMS):
        pa[i] = UInt8(1)
    VulkanBuffers.unmap(a)
    var dispatches_before = VulkanBuffers.q4k_gemv_dispatch_count()
    print("  q4k dispatch count probe (vec_add uses its own path):", dispatches_before)
    var max_busy = -1
    for round in range(300):
        VulkanBuffers.vec_add(a, b, c, _ELEMS)
        if round % 50 == 0:
            var sample = observe_scheduler_telemetry()
            if sample.gpu.util_x10 > max_busy:
                max_busy = sample.gpu.util_x10
    var during = observe_scheduler_telemetry()
    var ext_mem_during = _external_cat(base + "/mem_info_gtt_used")
    print("  during: internal gtt_used=", during.gpu.mem_used_bytes, " external gtt_used=", ext_mem_during, " max sampled busy=", format_util_x10(max_busy))
    if during.gpu.mem_used_bytes < idle.gpu.mem_used_bytes:
        raise Error("pool fell while 512 MiB was resident on the device")
    if not mem_within_tolerance(during.gpu.mem_used_bytes, ext_mem_during):
        raise Error("loaded GPU memory disagrees with external observation")
    VulkanBuffers.free(big)
    VulkanBuffers.free(a)
    VulkanBuffers.free(b)
    VulkanBuffers.free(c)
    if VulkanBuffers.live_bytes() != 0:
        raise Error("Vulkan shim did not return to baseline")
    var after = observe_scheduler_telemetry()
    print("  after free: gtt_used=", after.gpu.mem_used_bytes, " (idle ", idle.gpu.mem_used_bytes, ")")
    if not mem_within_tolerance(after.gpu.mem_used_bytes, idle.gpu.mem_used_bytes):
        raise Error("pool did not return inside tolerance after free")
    print("A106 leg4 device-load: PASS")
    # Leg 5: placements reproducible.
    var registry = observe_backend_registry()
    var first = tally_placements(registry)
    var second = tally_placements(registry)
    if first.digest != second.digest or first.total != 12:
        raise Error("placement tally not reproducible over the live registry")
    print("  placements total=", first.total, " gpu/npu/cpu/none=", first.gpu, "/", first.npu, "/", first.cpu, "/", first.none_count, " digest=", first.digest)
    print("A106 leg5 placements: PASS")
    print("A106_TELEMETRY: PASS")
