# tests/test_amd_realm.mojo
# Verification of AMD ROCm / HIP GPU Acceleration Gateway & Memory Management

from core.amd_gate import (
    AMDGate,
    HIP_GATE_ABSENT,
    HIP_GATE_ERROR,
    HIP_GATE_PRESENT,
)
from core.hardware_census import format_gfx_target
from core.hip_memory import HipMemory
from std.memory.alloc import alloc
from core.mimir_well import MimirWell, RuneTensor, GPURealmType, f16, Scalar
from core.compute import gemm_f16_gpu

def test_amd_gate_availability() raises:
    print("--- Testing AMDGate driver & runtime availability ---")
    var avail = AMDGate.is_available()
    var count = AMDGate.get_device_count()

    if avail:
        print(
            "AMD HIP runtime library: LOADABLE; device count queried"
            " live through the runtime:",
            count,
        )
    else:
        print("AMD ROCm HIP: UNAVAILABLE on current host platform (Fail-Closed)")
    if count < 0:
        raise Error("AMDGate reported a negative device count")
    if not avail and count != 0:
        raise Error("AMDGate reported devices without a loadable HIP runtime")

    print("AMDGate driver & runtime availability: PASS")


def test_amd_hip_device_gate() raises:
    print("--- Testing AMDGate HIP device gate (A-010) ---")
    var status = AMDGate.gate_status()

    if status == HIP_GATE_ABSENT:
        # Honest-absent: no runtime or no device, and the gate must
        # not invent either a count or a properties record.
        if AMDGate.get_device_count() != 0:
            raise Error("AMDGate absent yet reported a nonzero device count")
        var absent_props = AMDGate.get_device_properties(0)
        if absent_props.plausible():
            raise Error("AMDGate absent yet produced plausible properties")
        print("AMD HIP device gate: ABSENT (honest, no device claimed)")
        print("AMDGate HIP device gate: PASS")
        return

    if status == HIP_GATE_ERROR:
        raise Error("AMD HIP gate errored against a loadable runtime")
    if status != HIP_GATE_PRESENT:
        raise Error("AMD HIP gate returned an unknown status")

    # Device-present path (A-010 acceptance): exactly one gfx1151
    # device whose runtime-reported properties are plausible.
    var count = AMDGate.get_device_count()
    if count != 1:
        raise Error(
            "A-010 expects exactly one HIP device on this host, runtime"
            " reported "
            + String(count)
        )
    var props = AMDGate.get_device_properties(0)
    if not props.plausible():
        raise Error(
            "HIP device 0 properties implausible: name="
            + props.name
            + " gfx_arch="
            + props.gfx_arch
            + " total_memory_bytes="
            + String(props.total_memory_bytes)
            + " wavefront_size="
            + String(props.wavefront_size)
        )
    if props.gfx_arch != "gfx1151":
        raise Error(
            "A-010 expects a gfx1151 device, runtime reported "
            + props.gfx_arch
        )
    print(
        "AMD HIP device 0:",
        props.name,
        "| arch",
        props.gfx_arch,
        "| total_memory_bytes",
        props.total_memory_bytes,
        "| wavefront",
        props.wavefront_size,
        "| multi_processors",
        props.multi_processor_count,
        "| runtime_version",
        AMDGate.runtime_version(),
    )
    print("AMDGate HIP device gate: PASS")


def test_amd_hip_properties_parser() raises:
    print("--- Testing AMDGate HIP properties parser (A-010) ---")
    # The gate reads the gfx target from the kernel KFD topology
    # properties text. On the Z13 the kernel states
    # gfx_target_version 110501 (team-01 ground truth,
    # hidden_files/a010_offset_check.log), which the A-001 census
    # formatter renders as gfx1151; the gate's own properties record
    # must agree with both.
    var version = AMDGate.kfd_gfx_target_version()
    if version <= 0:
        print("KFD topology states no gfx target on this host (honest)")
        print("AMDGate HIP properties parser: PASS")
        return
    if version != 110501:
        raise Error(
            "KFD gfx_target_version changed on this host: "
            + String(version)
        )
    if format_gfx_target(version) != "gfx1151":
        raise Error("gfx_target_version 110501 did not render as gfx1151")
    var props = AMDGate.get_device_properties(0)
    if props.gfx_arch != "gfx1151":
        raise Error(
            "gate gfx_arch disagrees with KFD topology: " + props.gfx_arch
        )
    if props.gcn_arch != 1151:
        raise Error(
            "gate gcn_arch disagrees with KFD topology: "
            + String(props.gcn_arch)
        )
    # The KFD decomposition must match the runtime's own compute
    # capability: 110501 encodes major 11, minor 5, stepping 1.
    if props.compute_major != 11 or props.compute_minor != 5:
        raise Error(
            "runtime compute capability disagrees with KFD gfx target: "
            + String(props.compute_major)
            + "."
            + String(props.compute_minor)
        )
    if props.memory_bus_width_bits != 256:
        raise Error(
            "gate memory bus width disagrees with KFD mem_banks: "
            + String(props.memory_bus_width_bits)
        )
    if props.memory_clock_rate_khz != 1000000:
        raise Error(
            "gate memory clock disagrees with KFD mem_banks: "
            + String(props.memory_clock_rate_khz)
        )
    print("AMDGate HIP properties parser: PASS")


def test_amd_gemm_dispatch_bounds() raises:
    print("--- Testing gemm_f16_gpu AMD shape mismatch handling ---")
    var well = MimirWell(1024 * 1024)
    var a_ptr = well.allocate(4 * 32)
    var A = RuneTensor[f16](4, 32, a_ptr)
    var b_ptr = well.allocate(4 * 16)
    var B = RuneTensor[f16](4, 16, b_ptr)
    var c_ptr = well.allocate(4 * 4)
    var C = RuneTensor[f16](4, 4, c_ptr)

    var shape_rejected = False
    try:
        AMDGate.launch_gemm_amd(A, B, C)
    except error:
        shape_rejected = True
        if "GEMM shape mismatch" not in String(error):
            raise Error("AMDGate shape mismatch check produced unexpected error text: " + String(error))

    if not shape_rejected:
        raise Error("AMDGate failed to reject mismatched GEMM shapes")

    print("gemm_f16_gpu AMD shape mismatch handling: PASS")


def test_amd_realm_unsupported_gateways() raises:
    print("--- Testing AMD ROCm HIP realm error gateways ---")
    var well = MimirWell(1024 * 1024)
    var a_ptr = well.allocate(4 * 32)
    var A = RuneTensor[f16](4, 32, a_ptr)
    var b_ptr = well.allocate(4 * 32)
    var B = RuneTensor[f16](4, 32, b_ptr)
    var c_ptr = well.allocate(4 * 4)
    var C = RuneTensor[f16](4, 4, c_ptr)

    var rejected = False
    try:
        AMDGate.launch_gemm_amd(A, B, C)
    except error:
        rejected = True
        if "not implemented" not in String(error):
            raise Error("AMD gateway rejection omitted stable error text: " + String(error))
    if not rejected:
        raise Error("AMD gateway reported execution without a physical kernel")

    print("AMD ROCm HIP realm error gateways: PASS")


# --- A-011: HIP memory (HipMemory) -------------------------------------
# Present/absent discipline matches the house style of the gate tests
# above: on a HIP host every case verifies real device memory; on a host
# without the HIP runtime every case asserts fail-closed behaviour and
# passes as honest-absent. No case ever claims iterations it did not run.


def _hip_present() -> Bool:
    if not HipMemory.runtime_available():
        return False
    try:
        return HipMemory.device_count() >= 1
    except:
        return False


def _expect_hip_fail_closed() raises:
    var alloc_rejected = False
    try:
        var p = HipMemory.allocate(4096)
        HipMemory.free(p)
    except:
        alloc_rejected = True
    if not alloc_rejected:
        raise Error(
            "HIP unavailable but HipMemory.allocate succeeded (fabricated"
            " allocation)"
        )
    var managed_rejected = False
    try:
        var m = HipMemory.allocate_managed(4096)
        HipMemory.free(m)
    except:
        managed_rejected = True
    if not managed_rejected:
        raise Error(
            "HIP unavailable but HipMemory.allocate_managed succeeded"
            " (fabricated allocation)"
        )
    var info_rejected = False
    try:
        _ = HipMemory.mem_info()
    except:
        info_rejected = True
    if not info_rejected:
        raise Error(
            "HIP unavailable but HipMemory.mem_info succeeded (fabricated"
            " accounting)"
        )


def test_hip_malloc_free_round_trip() raises:
    print("--- Testing HIP hipMalloc/hipFree round trips (A-011) ---")
    if not _hip_present():
        _expect_hip_fail_closed()
        print("HIP UNAVAILABLE: hipMalloc round trip fail-closed: PASS")
        return
    var sizes = [1, 4096, 1048576]
    for s in range(len(sizes)):
        var n = sizes[s]
        var host = alloc[UInt8](n)
        for i in range(n):
            host.unsafe_store(i, UInt8((i * 31 + 7) % 251))
        var dev = HipMemory.allocate(n)
        HipMemory.memcpy_host_to_device(dev, host, n)
        for i in range(n):
            host.unsafe_store(i, UInt8(0))
        HipMemory.memcpy_device_to_host(host, dev, n)
        HipMemory.free(dev)
        for i in range(n):
            if host.unsafe_load(i) != UInt8((i * 31 + 7) % 251):
                host.unsafe_free()
                raise Error(
                    "HIP malloc round trip byte mismatch at size "
                    + String(n) + " index " + String(i)
                )
        host.unsafe_free()
    print("HIP hipMalloc/hipFree round trips (1B/4KiB/1MiB, byte-exact): PASS")


def test_hip_alloc_rejection() raises:
    print("--- Testing HIP allocation rejection (A-011) ---")
    var bad_sizes = [0, -4096]
    for b in range(len(bad_sizes)):
        var size = bad_sizes[b]
        var rejected = False
        try:
            var p = HipMemory.allocate(size)
            HipMemory.free(p)
        except error:
            rejected = True
            if "must be positive" not in String(error):
                raise Error(
                    "HIP alloc rejection produced unexpected error text: "
                    + String(error)
                )
        if not rejected:
            raise Error("HipMemory.allocate accepted a non-positive size")
        var m_rejected = False
        try:
            var m = HipMemory.allocate_managed(size)
            HipMemory.free(m)
        except error:
            m_rejected = True
            if "must be positive" not in String(error):
                raise Error(
                    "HIP managed alloc rejection produced unexpected error"
                    " text: " + String(error)
                )
        if not m_rejected:
            raise Error(
                "HipMemory.allocate_managed accepted a non-positive size"
            )
    if _hip_present():
        var info = HipMemory.mem_info()
        var oversize = info.total_bytes * 4
        var o_rejected = False
        try:
            var p = HipMemory.allocate(oversize)
            HipMemory.free(p)
        except:
            o_rejected = True
        if not o_rejected:
            raise Error(
                "HipMemory.allocate accepted an oversize request beyond"
                " device memory"
            )
        var ok = HipMemory.allocate(4096)
        HipMemory.free(ok)
    print(
        "HIP allocation rejection (non-positive local, oversize"
        " fail-closed): PASS"
    )


def test_hip_malloc_managed_round_trip() raises:
    print("--- Testing HIP hipMallocManaged round trip (A-011) ---")
    if not _hip_present():
        _expect_hip_fail_closed()
        print("HIP UNAVAILABLE: hipMallocManaged round trip fail-closed: PASS")
        return
    var n = 65536
    var mp = HipMemory.allocate_managed(n)
    for i in range(n):
        mp.unsafe_store(i, UInt8((i * 17 + 3) % 241))
    HipMemory.device_synchronize()
    for i in range(n):
        if mp.unsafe_load(i) != UInt8((i * 17 + 3) % 241):
            HipMemory.free(mp)
            raise Error(
                "HIP managed round trip byte mismatch at index " + String(i)
            )
    HipMemory.free(mp)
    print(
        "HIP hipMallocManaged round trip (64KiB host-written/host-read,"
        " synced): PASS"
    )


def test_hip_mem_get_info_accounting() raises:
    print("--- Testing HIP hipMemGetInfo accounting (A-011) ---")
    if not _hip_present():
        _expect_hip_fail_closed()
        print("HIP UNAVAILABLE: hipMemGetInfo accounting fail-closed: PASS")
        return
    var warm = HipMemory.allocate(1048576)
    HipMemory.free(warm)
    var warm_m = HipMemory.allocate_managed(1048576)
    HipMemory.free(warm_m)
    HipMemory.device_synchronize()
    var base = HipMemory.mem_info()
    if base.total_bytes <= 0:
        raise Error("hipMemGetInfo reported a non-positive total")
    if base.free_bytes < 0 or base.free_bytes > base.total_bytes:
        raise Error("hipMemGetInfo free bytes outside [0, total]")
    var held = HipMemory.allocate(1048576)
    var mid = HipMemory.mem_info()
    if mid.total_bytes != base.total_bytes:
        HipMemory.free(held)
        raise Error("hipMemGetInfo total changed while an allocation was held")
    if mid.free_bytes > base.free_bytes:
        HipMemory.free(held)
        raise Error("hipMemGetInfo free grew while an allocation was held")
    HipMemory.free(held)
    HipMemory.device_synchronize()
    var end = HipMemory.mem_info()
    if end.free_bytes != base.free_bytes or end.total_bytes != base.total_bytes:
        raise Error(
            "hipMemGetInfo accounting did not return to baseline after"
            " free: free " + String(base.free_bytes) + " -> "
            + String(end.free_bytes)
        )
    print(
        "HIP hipMemGetInfo accounting (total stable, free returns to"
        " baseline): PASS"
    )


def test_hip_no_leak_1000() raises:
    print("--- Testing HIP zero-leak accounting, 1000 iterations (A-011) ---")
    if not _hip_present():
        _expect_hip_fail_closed()
        print(
            "HIP UNAVAILABLE: leak battery fail-closed, no iterations"
            " claimed: PASS"
        )
        return
    var n = 4096
    var host = alloc[UInt8](n)
    for i in range(n):
        host.unsafe_store(i, UInt8((i * 31 + 7) % 251))
    # Warm-up first: the HIP runtime reserves a one-time context/pool
    # block on first use (measured on purpleraider and filed in the
    # A-011 ledger); the leak baseline is taken only after it settles.
    for _warm in range(10):
        var wd = HipMemory.allocate(n)
        HipMemory.memcpy_host_to_device(wd, host, n)
        HipMemory.memcpy_device_to_host(host, wd, n)
        HipMemory.free(wd)
        var wm = HipMemory.allocate_managed(n)
        HipMemory.free(wm)
    HipMemory.device_synchronize()
    var base = HipMemory.mem_info()
    for it in range(1000):
        var dev = HipMemory.allocate(n)
        HipMemory.memcpy_host_to_device(dev, host, n)
        HipMemory.memcpy_device_to_host(host, dev, n)
        HipMemory.free(dev)
        for i in range(n):
            if host.unsafe_load(i) != UInt8((i * 31 + 7) % 251):
                host.unsafe_free()
                raise Error(
                    "HIP leak battery round trip mismatch at iteration "
                    + String(it)
                )
    for it in range(1000):
        var mp = HipMemory.allocate_managed(n)
        mp.unsafe_store(0, UInt8(165))
        mp.unsafe_store(n - 1, UInt8(90))
        HipMemory.device_synchronize()
        if mp.unsafe_load(0) != UInt8(165) or mp.unsafe_load(n - 1) != UInt8(90):
            HipMemory.free(mp)
            host.unsafe_free()
            raise Error(
                "HIP leak battery managed mismatch at iteration " + String(it)
            )
        HipMemory.free(mp)
    HipMemory.device_synchronize()
    var end = HipMemory.mem_info()
    host.unsafe_free()
    var leaked = base.free_bytes - end.free_bytes
    if end.total_bytes != base.total_bytes:
        raise Error(
            "HIP leak battery: device total changed "
            + String(base.total_bytes) + " -> " + String(end.total_bytes)
        )
    if leaked != 0:
        raise Error(
            "HIP leak battery: leaked_bytes = " + String(leaked)
            + " across 1000+1000 iterations"
        )
    print(
        "HIP zero-leak battery: 1000 hipMalloc + 1000 hipMallocManaged"
        " iterations, leaked = 0 bytes: PASS"
    )
