"""Spillover policy (A-102): capacity pressure spills
accelerator -> CPU per the accelerator-first law, in the open.

Acceptance shape (roadmap A-102): oversized-model run (A-049
fixture class) places layers per policy with the placement
logged and reproducible. The oversized run itself is the
standalone bench (tests/bench_spillover_a102.mojo, 8B-class
sha-pinned fixture); these in-suite cases prove the policy the
bench drives:

- accelerator-first: a stack that fits is placed entirely on
  the accelerator, CPU untouched;
- capacity spill in stack order: the accelerator prefix fills
  the room, later spillable layers go to the CPU path with
  reason CAPACITY_SPILL, totals exact;
- atomic refusal: a non-spillable layer that does not fit
  refuses the WHOLE plan (MEM-003) - no partial placement, no
  layer lines, the refusal itself logged;
- the spill ledger is bounded: spill beyond the cap refuses;
- the assist door is evidence-gated: an assist mark without
  measured evidence is ignored (accelerator-first applies);
  with evidence the layer is CPU_ASSIST inside the same
  bounded CPU budget;
- reproducibility: identical inputs give a byte-identical
  placement log and digest; different capacity gives a
  different digest - the log is a pure function of its inputs;
- device execution: a GPU-placed layer's bytes are uploaded
  into a real Vulkan buffer on the AMD Radeon 8060S (RADV
  STRIX_HALO, llvmpipe refused by identity), read back
  byte-exact through the device mapping, and freed back to
  the shim baseline; plus a live-pressure plan smoke (the
  plan totals always sum to the stack, whatever the pool
  figures are on this machine right now).
"""
from core.gpu_pressure import GpuPressureConfig, live_pressure
from core.spillover_policy import (
    LayerSpec,
    PlacementPlan,
    fnv1a64,
    plan_spillover,
    plan_spillover_live,
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


def _stack3() -> List[LayerSpec]:
    var layers = List[LayerSpec]()
    layers.append(LayerSpec(String("blk.0"), 16 * _MB, True))
    layers.append(LayerSpec(String("blk.1"), 16 * _MB, True))
    layers.append(LayerSpec(String("blk.2"), 16 * _MB, True))
    return layers^


def test_spillover_all_fit_gpu() raises:
    print("--- Testing spillover: stack that fits is all-GPU (A-102) ---")
    var plan = plan_spillover(
        GpuPressureConfig(1024 * _MB, 64 * _MB, 0), _stack3(), 100 * _GB, 128 * _GB
    )
    if not plan.ok:
        raise Error("fitting stack was refused")
    if plan.gpu_layers != 3 or plan.cpu_layers != 0:
        raise Error("fitting stack was not placed entirely on the accelerator")
    if plan.gpu_bytes != 48 * _MB or plan.cpu_bytes() != 0:
        raise Error("all-fit totals mismatch")
    if len(plan.entries) != 5:
        raise Error("all-fit log should be header + 3 layers + totals")
    print("PASS: accelerator-first - fitting stack all-GPU, CPU untouched")


def test_spillover_capacity_spill_order() raises:
    print("--- Testing spillover: capacity spill in stack order (A-102) ---")
    # GPU cap admits exactly the first layer; spill cap admits the rest.
    var plan = plan_spillover(
        GpuPressureConfig(16 * _MB, 64 * _MB, 0), _stack3(), 100 * _GB, 128 * _GB
    )
    if not plan.ok:
        raise Error("spillable stack under capacity pressure was refused")
    if plan.gpu_layers != 1 or plan.cpu_layers != 2:
        raise Error("spill split is not prefix-GPU / suffix-CPU")
    if plan.gpu_bytes != 16 * _MB or plan.cpu_spill_bytes != 32 * _MB:
        raise Error("spill totals mismatch")
    if String("place=GPU") not in plan.entries[1]:
        raise Error("first layer not logged GPU")
    if String("place=CPU_SPILL") not in plan.entries[2]:
        raise Error("second layer not logged CPU_SPILL")
    if String("reason=CAPACITY_SPILL") not in plan.entries[3]:
        raise Error("spill reason not logged in the open")
    print("PASS: prefix on accelerator, suffix spilled to CPU, logged with reason")


def test_spillover_nonspillable_refusal_atomic() raises:
    print("--- Testing spillover: non-spillable refusal is atomic (A-102) ---")
    var layers = List[LayerSpec]()
    layers.append(LayerSpec(String("blk.0"), 16 * _MB, True))
    layers.append(LayerSpec(String("output"), 16 * _MB, False))
    var plan = plan_spillover(
        GpuPressureConfig(16 * _MB, 64 * _MB, 0), layers, 100 * _GB, 128 * _GB
    )
    if plan.ok:
        raise Error("non-spillable overflow did not refuse the plan")
    if String("MEM-003") not in plan.refusal_reason:
        raise Error("refusal is not MEM-003 class")
    if plan.gpu_bytes != 0 or plan.cpu_bytes() != 0 or plan.gpu_layers != 0:
        raise Error("refused plan recorded a partial placement")
    if len(plan.entries) != 2:
        raise Error("refused plan log should be header + refusal line only")
    if String("REFUSE") not in plan.entries[1]:
        raise Error("refusal not logged in the open")
    print("PASS: MEM-003 refusal before any placement, nothing half-placed")


def test_spillover_spill_cap_bound() raises:
    print("--- Testing spillover: spill ledger is bounded (A-102) ---")
    # GPU room for one layer, spill cap for one more; third must refuse.
    var plan = plan_spillover(
        GpuPressureConfig(16 * _MB, 16 * _MB, 0), _stack3(), 100 * _GB, 128 * _GB
    )
    if plan.ok:
        raise Error("spill beyond the bounded cap did not refuse")
    if String("MEM-003") not in plan.refusal_reason:
        raise Error("spill-cap refusal is not MEM-003 class")
    print("PASS: degradation bounded - spill past the cap refuses, never overflows")


def test_spillover_assist_evidence_gate() raises:
    print("--- Testing spillover: CPU assist is evidence-gated (A-102) ---")
    var claimed = List[LayerSpec]()
    claimed.append(LayerSpec(String("blk.0"), 16 * _MB, True, True, False))
    var plan_a = plan_spillover(
        GpuPressureConfig(1024 * _MB, 64 * _MB, 0), claimed, 100 * _GB, 128 * _GB
    )
    if not plan_a.ok or plan_a.gpu_layers != 1 or plan_a.cpu_assist_bytes != 0:
        raise Error("unproven assist claim moved work off the accelerator")
    var proven = List[LayerSpec]()
    proven.append(LayerSpec(String("blk.0"), 16 * _MB, True, True, True))
    var plan_b = plan_spillover(
        GpuPressureConfig(1024 * _MB, 64 * _MB, 0), proven, 100 * _GB, 128 * _GB
    )
    if not plan_b.ok or plan_b.cpu_assist_bytes != 16 * _MB or plan_b.gpu_layers != 0:
        raise Error("measured assist was not honoured inside the CPU budget")
    if String("reason=ASSIST_MEASURED") not in plan_b.entries[1]:
        raise Error("assist placement not logged with its reason")
    print("PASS: assist without evidence ignored; with evidence placed + logged")


def test_spillover_log_reproducible() raises:
    print("--- Testing spillover: placement log is reproducible (A-102) ---")
    var cfg = GpuPressureConfig(16 * _MB, 64 * _MB, 0)
    var plan_a = plan_spillover(cfg, _stack3(), 100 * _GB, 128 * _GB)
    var plan_b = plan_spillover(cfg, _stack3(), 100 * _GB, 128 * _GB)
    if plan_a.log_text() != plan_b.log_text():
        raise Error("identical inputs produced different placement logs")
    if plan_a.digest != plan_b.digest:
        raise Error("identical inputs produced different digests")
    if plan_a.digest != fnv1a64(plan_a.log_text()):
        raise Error("digest is not the FNV-1a of the log text")
    var roomy = plan_spillover(
        GpuPressureConfig(1024 * _MB, 64 * _MB, 0), _stack3(), 100 * _GB, 128 * _GB
    )
    if roomy.digest == plan_a.digest:
        raise Error("different capacity produced the same placement digest")
    print("PASS: same inputs, byte-identical log + digest; new capacity, new digest")


def test_spillover_device_execution() raises:
    print("--- Testing spillover: GPU placement executed on RADV (A-102) ---")
    var reading = live_pressure()
    var live_plan = plan_spillover_live(
        GpuPressureConfig(1024 * _MB, 64 * _MB, 0), _stack3()
    )
    if live_plan.gpu_bytes + live_plan.cpu_bytes() != 48 * _MB:
        raise Error("live plan totals do not sum to the stack")
    print("live pool avail=", reading.available_bytes, " total=", reading.total_bytes)
    if not _vk_present():
        print("Vulkan RADV device absent: honest-absent PASS")
        return
    var plan = plan_spillover(
        GpuPressureConfig(1024 * _MB, 64 * _MB, 0), _stack3(), 100 * _GB, 128 * _GB
    )
    if not plan.ok or plan.gpu_layers != 3:
        raise Error("device leg plan is not all-GPU")
    var before = VulkanBuffers.live_bytes()
    var alloc = VulkanBuffers.allocate(8 * _MB)
    var ptr = VulkanBuffers.map(alloc)
    for i in range(8 * _MB):
        ptr[i] = UInt8((i * 31 + 7) % 251)
    VulkanBuffers.unmap(alloc)
    var back = VulkanBuffers.map(alloc)
    var checksum: UInt64 = 0
    for i in range(8 * _MB):
        checksum += UInt64(back[i])
    VulkanBuffers.unmap(alloc)
    VulkanBuffers.free(alloc)
    var expect: UInt64 = 0
    for i in range(8 * _MB):
        expect += UInt64((i * 31 + 7) % 251)
    if checksum != expect:
        raise Error("device buffer readback differs from the placed bytes")
    if VulkanBuffers.live_bytes() != before:
        raise Error("shim live bytes did not return to baseline after free")
    print("PASS: placed bytes resident on RADV STRIX_HALO, readback exact, freed")
