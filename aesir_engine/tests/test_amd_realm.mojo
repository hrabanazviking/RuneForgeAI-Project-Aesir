# tests/test_amd_realm.mojo
# Verification of AMD ROCm / HIP GPU Acceleration Gateway & Memory Management

from core.amd_gate import (
    AMDGate,
    HIP_GATE_ABSENT,
    HIP_GATE_ERROR,
    HIP_GATE_PRESENT,
)
from core.hardware_census import format_gfx_target
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
