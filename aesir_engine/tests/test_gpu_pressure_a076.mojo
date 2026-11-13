"""GPU memory pressure (A-076): when the unified pool is
squeezed, the engine spills to CPU paths gracefully.

Acceptance shape (roadmap A-076): pressure test - no crash, no
corruption, degradation is logged and bounded.

The governor (core/gpu_pressure) decides routing BEFORE any GPU
allocation exists: a weight is admitted to GPU residency only
when it fits both the configured GPU cap and the live effective
room (MemAvailable - reserve, A-023 semantics). Under measured
pressure a spillable weight routes to the CPU path
(ROUTE_SPILL_CPU, accounted on a bounded spill ledger); a
non-spillable weight that does not fit is REFUSED
(ROUTE_REFUSE, MEM-003 class) - an explicit logged refusal,
never a crash, never silent corruption. Releases are checked
and return both ledgers to baseline exactly, so when pressure
lifts the GPU route opens again (degradation is a state, not
a ratchet).

Cases prove the routing arithmetic exactly on handed pressure
figures, the live /proc/meminfo reading on this machine, the
bounded decision log under a decision storm, and - on the real
device - one bounded 8 MiB Vulkan allocation admitted under
the governor on the AMD Radeon 8060S (RADV STRIX_HALO),
llvmpipe refused by identity, freed back to the shim baseline.
Real external pool pressure (a separate balloon process) is
exercised by tests/bench_gpu_pressure_a076.mojo under
 hidden_files/run_a076_pressure.sh, not in run_all.
"""
from core.gpu_pressure import (
    LOG_MAX,
    PRESSURE_CRITICAL,
    PRESSURE_HIGH,
    PRESSURE_MODERATE,
    PRESSURE_NONE,
    PRESSURE_UNKNOWN,
    ROUTE_GPU,
    ROUTE_REFUSE,
    ROUTE_SPILL_CPU,
    GpuPressureConfig,
    GpuPressureGovernor,
    classify_pressure,
    live_pressure,
    parse_meminfo_total_bytes,
    pressure_name,
)
from core.vulkan_buffers import VulkanBuffers

comptime _MB = 1024 * 1024
comptime _GB = 1024 * 1024 * 1024


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


def test_gpu_pressure_classification() raises:
    print("--- Testing pressure classification boundaries (A-076) ---")
    if classify_pressure(64 * _GB, 128 * _GB) != PRESSURE_NONE:
        raise Error("half-available pool is not NONE")
    if classify_pressure(127 * _GB, 128 * _GB) != PRESSURE_NONE:
        raise Error("near-full availability is not NONE")
    if classify_pressure(32 * _GB, 128 * _GB) != PRESSURE_MODERATE:
        raise Error("quarter-available pool is not MODERATE")
    if classify_pressure(16 * _GB, 128 * _GB) != PRESSURE_HIGH:
        raise Error("eighth-available pool is not HIGH")
    if classify_pressure(8 * _GB, 128 * _GB) != PRESSURE_CRITICAL:
        raise Error("sixteenth-available pool is not CRITICAL")
    if classify_pressure(0, 128 * _GB) != PRESSURE_CRITICAL:
        raise Error("zero availability is not CRITICAL")
    if classify_pressure(-1, 128 * _GB) != PRESSURE_UNKNOWN:
        raise Error("unknown availability invented a pressure")
    if classify_pressure(10 * _GB, 0) != PRESSURE_UNKNOWN:
        raise Error("unknown total invented a pressure")
    if pressure_name(PRESSURE_NONE) != String("NONE"):
        raise Error("pressure naming drift")
    print("PASS: classification exact at every boundary, unknown stays unknown")


def test_gpu_pressure_gpu_route_baseline() raises:
    print("--- Testing GPU route under no pressure + baseline (A-076) ---")
    var gov = GpuPressureGovernor(GpuPressureConfig(1024 * _MB, 32 * _MB, 16 * _MB))
    var v = gov.route(8 * _MB, True, 100 * _GB, 128 * _GB)
    if v != ROUTE_GPU:
        raise Error("roomy pool did not route to GPU (accelerator-first)")
    if gov.gpu_live_bytes != 8 * _MB or gov.gpu_admit_count != 1:
        raise Error("GPU ledger mismatch after admit")
    var v2 = gov.route(8 * _MB, False, 100 * _GB, 128 * _GB)
    if v2 != ROUTE_GPU:
        raise Error("second admit under no pressure did not route GPU")
    gov.release_gpu(8 * _MB)
    gov.release_gpu(8 * _MB)
    if not gov.at_baseline():
        raise Error("ledgers not at baseline after releases")
    if gov.spill_count != 0 or gov.refusal_count != 0:
        raise Error("no-pressure run recorded degradation")
    print("PASS: accelerator-first admit, exact accounting, baseline return")


def test_gpu_pressure_squeeze_spill_refuse() raises:
    print("--- Testing squeeze: spillable spills, non-spillable refused (A-076) ---")
    # Reserve fixed so the live effective room is exactly zero:
    # available 40 GiB of 128 GiB, reserve 40 GiB.
    var gov = GpuPressureGovernor(GpuPressureConfig(1024 * _MB, 32 * _MB, 40 * _GB))
    if gov.config.effective_gpu_room(40 * _GB, 0) != 0:
        raise Error("squeezed effective room is not zero")
    var v1 = gov.route(8 * _MB, True, 40 * _GB, 128 * _GB)
    if v1 != ROUTE_SPILL_CPU:
        raise Error("spillable weight under squeeze did not spill to CPU")
    if gov.spilled_live_bytes != 8 * _MB or gov.gpu_live_bytes != 0:
        raise Error("spill ledger mismatch under squeeze")
    var v2 = gov.route(8 * _MB, False, 40 * _GB, 128 * _GB)
    if v2 != ROUTE_REFUSE:
        raise Error("non-spillable weight under squeeze was not refused")
    if gov.refusal_count != 1:
        raise Error("refusal under squeeze was not counted")
    if len(gov.log) != 2:
        raise Error("degradation decisions were not logged")
    gov.release_spilled(8 * _MB)
    if not gov.at_baseline():
        raise Error("ledgers not at baseline after squeeze released")
    print("PASS: squeeze degrades by spill/refusal, logged, no crash, no charge")


def test_gpu_pressure_bounded_degradation() raises:
    print("--- Testing degradation is bounded (spill cap, sizes, releases) (A-076) ---")
    var gov = GpuPressureGovernor(GpuPressureConfig(16 * _MB, 32 * _MB, 40 * _GB))
    # GPU room is zero (reserve == available); spill cap is 32 MiB.
    for _ in range(4):
        if gov.route(8 * _MB, True, 40 * _GB, 128 * _GB) != ROUTE_SPILL_CPU:
            raise Error("spillable request within spill cap did not spill")
    if gov.spilled_live_bytes != 32 * _MB:
        raise Error("spill ledger does not equal the spill cap")
    if gov.route(8 * _MB, True, 40 * _GB, 128 * _GB) != ROUTE_REFUSE:
        raise Error("spillable request beyond the spill cap was not refused")
    if gov.route(0, True, 40 * _GB, 128 * _GB) != ROUTE_REFUSE:
        raise Error("zero-size request was not refused")
    if gov.route(-4096, True, 40 * _GB, 128 * _GB) != ROUTE_REFUSE:
        raise Error("negative-size request was not refused")
    if gov.refusal_count != 3:
        raise Error("bounded-degradation refusal counter mismatch")
    var over = False
    try:
        gov.release_spilled(64 * _MB)
    except:
        over = True
    if not over:
        raise Error("over-release of spilled bytes was not refused")
    if gov.spilled_live_bytes != 32 * _MB:
        raise Error("a refused over-release changed the spill ledger")
    for _ in range(4):
        gov.release_spilled(8 * _MB)
    if not gov.at_baseline():
        raise Error("ledgers not at baseline at end of bounded case")
    print("PASS: spill cap bounds degradation; bad sizes and over-release refused")


def test_gpu_pressure_recovery() raises:
    print("--- Testing recovery after pressure releases (A-076) ---")
    var gov = GpuPressureGovernor(GpuPressureConfig(1024 * _MB, 32 * _MB, 64 * _MB))
    # Squeezed: 32 MiB available against a 64 MiB reserve -> room 0.
    if gov.route(8 * _MB, True, 32 * _MB, 128 * _GB) != ROUTE_SPILL_CPU:
        raise Error("weight did not spill while squeezed")
    gov.release_spilled(8 * _MB)
    # Pressure lifts: 100 GiB available -> the same request routes GPU.
    if gov.route(8 * _MB, True, 100 * _GB, 128 * _GB) != ROUTE_GPU:
        raise Error("weight did not return to GPU after pressure lifted")
    if gov.route(8 * _MB, False, 100 * _GB, 128 * _GB) != ROUTE_GPU:
        raise Error("non-spillable weight did not route GPU after recovery")
    gov.release_gpu(8 * _MB)
    gov.release_gpu(8 * _MB)
    if not gov.at_baseline():
        raise Error("ledgers not at baseline after recovery")
    if gov.spill_count != 1 or gov.gpu_admit_count != 2:
        raise Error("recovery counters mismatch (degradation became a ratchet)")
    print("PASS: degradation is a state, not a ratchet - GPU route reopens")


def test_gpu_pressure_live_and_log_bound() raises:
    print("--- Testing live meminfo reading + bounded log storm (A-076) ---")
    var fixture = String("MemTotal:       127396532 kB\nMemFree:        107833404 kB\nMemAvailable:   123626384 kB\n")
    if parse_meminfo_total_bytes(fixture) != 127396532 * 1024:
        raise Error("meminfo MemTotal fixture parse mismatch")
    var bad = 0
    try:
        _ = parse_meminfo_total_bytes(String("MemAvailable: 1 kB\n"))
    except:
        bad += 1
    try:
        _ = parse_meminfo_total_bytes(String("MemTotal: plenty kB\n"))
    except:
        bad += 1
    if bad != 2:
        raise Error("malformed meminfo total was not refused")
    var r = live_pressure()
    if r.total_bytes <= 0 or r.available_bytes <= 0:
        raise Error("live pressure could not be read on this machine")
    if r.available_bytes > r.total_bytes:
        raise Error("live availability exceeds the total pool")
    if r.level != classify_pressure(r.available_bytes, r.total_bytes):
        raise Error("live level inconsistent with its own figures")
    print(
        "MEASURED live pool: total " + String(r.total_bytes)
        + " available " + String(r.available_bytes)
        + " level " + pressure_name(r.level)
    )
    var gov = GpuPressureGovernor(GpuPressureConfig(1024 * _MB, 32 * _MB, 0))
    for _ in range(LOG_MAX + 40):
        _ = gov.route(1024, True, 100 * _GB, 128 * _GB)
        gov.release_gpu(1024)
    if len(gov.log) != LOG_MAX:
        raise Error("decision log grew past its bound under a storm")
    if gov.log_dropped != 40:
        raise Error("dropped-log accounting mismatch under a storm")
    if not gov.at_baseline():
        raise Error("ledgers not at baseline after the storm")
    print("PASS: live reading is real; the log itself cannot become a leak")


def test_gpu_pressure_device_buffer() raises:
    print("--- Testing governor over a real RADV buffer (A-076) ---")
    if not _vk_present():
        print("Vulkan RADV device absent: honest-absent PASS")
        return
    var gov = GpuPressureGovernor(GpuPressureConfig(1024 * _MB, 32 * _MB, 0))
    var r = live_pressure()
    var verdict = gov.route(8 * _MB, False, r.available_bytes, r.total_bytes)
    if verdict != ROUTE_GPU:
        raise Error("real-device weight was not admitted under live pressure")
    var before = VulkanBuffers.live_bytes()
    var alloc = VulkanBuffers.allocate(8 * _MB)
    var during = VulkanBuffers.live_bytes()
    if during - before != alloc.alloc_size:
        VulkanBuffers.free(alloc)
        raise Error("shim live delta does not equal the allocation")
    VulkanBuffers.free(alloc)
    if VulkanBuffers.live_bytes() != before:
        raise Error("shim live bytes did not return to baseline after free")
    gov.release_gpu(8 * _MB)
    if not gov.at_baseline():
        raise Error("governor not at baseline after device buffer freed")
    print("PASS: real RADV STRIX_HALO buffer admitted, freed, both accounts at baseline")
