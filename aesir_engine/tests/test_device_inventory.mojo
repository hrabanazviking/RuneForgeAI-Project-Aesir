"""Device inventory and truth (J-037): cpuinfo topology parsing,
machine-stated hybrid splits only, the nvidia-smi-class GPU probe's
parse and failure shapes, the DRM cross-check, the parked-ledger
NPU entry, the completeness of the bench-style device line, and the
live probe on this machine.

The injected cpuinfo / cpulist / nvidia-smi / DRM texts are written
in the exact shapes the kernel and the tool emit (the VM's own
/proc/cpuinfo shape is group 1's fixture). The live group runs the
real probes on the machine executing the test: on this VM that is
a genuine absent-GPU case (no nvidia-smi, no DRM card), exercised
as truth, not mocked around. No GPU-present live claim is made
anywhere: the present path is proven on injected probe output only.
"""
from core.device_inventory import (
    DeviceInventory,
    NPU_LEDGER_NOT_PRESENT,
    NPU_LEDGER_NOT_PROBED,
    NPU_LEDGER_PARKED,
    apply_hybrid_split,
    count_cpulist,
    cpu_entry,
    gpu_absent_entry,
    gpu_entry,
    npu_entry,
    observe_device_inventory,
    parse_cpuinfo,
    parse_drm_listing,
    parse_nvidia_smi_csv,
    require_device_present,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "DeviceInventory "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("DeviceInventory " + what + ": expected true")


def expect_contains(text: String, needle: String, what: String) raises:
    if needle not in text:
        raise Error(
            "DeviceInventory "
            + what
            + ": expected to contain '"
            + needle
            + "', got '"
            + text
            + "'"
        )


def _vm_cpuinfo() -> String:
    # The VM's /proc/cpuinfo shape: 4 processors on one package,
    # distinct core ids 0..3, no hybrid information anywhere.
    var text = String("")
    for i in range(4):
        text += "processor\t: " + String(i) + "\n"
        text += "model name\t: AMD EPYC 9D64 88-Core Processor\n"
        text += "physical id\t: 0\n"
        text += "core id\t\t: " + String(i) + "\n"
        text += "cpu cores\t: 4\n\n"
    return text


def test_cpuinfo_topology() raises:
    var facts = parse_cpuinfo(_vm_cpuinfo())
    expect_eq(facts.logical, 4, "logical count")
    expect_eq(facts.physical_cores, 4, "physical cores from pairs")
    expect_eq(facts.packages, 1, "package count")
    expect_true(not facts.has_hybrid_split(), "no split without a source")
    expect_contains(facts.model, "AMD EPYC 9D64", "model name")
    var entry = cpu_entry(facts)
    expect_true(entry.present, "cpu entry present")
    expect_contains(entry.detail, "4 logical", "line states logical")
    expect_contains(entry.detail, "4 physical cores", "line states physical")
    expect_contains(
        entry.detail,
        "performance/efficiency split not reported",
        "line refuses to guess a split",
    )
    print("PASS: cpuinfo topology (logical/physical/packages, no guessed split)")


def test_cpuinfo_topology_poor() raises:
    # A source with processors but no topology pairs: the physical
    # count is NOT derived from anything -- stated as not reported.
    var facts = parse_cpuinfo(
        "processor\t: 0\nHardware\t: BCM2835\n\nprocessor\t: 1\n"
    )
    expect_eq(facts.logical, 2, "logical count, topology-poor")
    expect_eq(facts.physical_cores, -1, "physical unknown, not derived")
    expect_eq(facts.packages, -1, "packages unknown")
    var entry = cpu_entry(facts)
    expect_contains(
        entry.detail,
        "physical core count not reported by cpuinfo",
        "line states the missing topology",
    )
    var refused = False
    try:
        _ = parse_cpuinfo("model name\t: nothing else\n")
    except:
        refused = True
    expect_true(refused, "cpuinfo with no processors is refused")
    print("PASS: cpuinfo topology-poor source states what it does not know")


def test_hybrid_split_machine_stated_only() raises:
    var facts = parse_cpuinfo(_vm_cpuinfo())
    apply_hybrid_split(facts, "0-7", "8-11")
    expect_eq(facts.perf_cores, 8, "performance cores from cpu_core list")
    expect_eq(facts.eff_cores, 4, "efficiency cores from cpu_atom list")
    var entry = cpu_entry(facts)
    expect_contains(
        entry.detail,
        "performance 8 + efficiency 4",
        "line states the machine-stated split",
    )
    var plain = parse_cpuinfo(_vm_cpuinfo())
    apply_hybrid_split(plain, "", "")
    expect_true(not plain.has_hybrid_split(), "empty lists state no split")
    apply_hybrid_split(plain, "0-3", "")
    expect_true(not plain.has_hybrid_split(), "one list states no split")
    expect_eq(count_cpulist("0-3,8,10-11"), 7, "cpulist ranges and singles")
    expect_eq(count_cpulist(""), 0, "empty cpulist")
    var refused = False
    try:
        _ = count_cpulist("7-2")
    except:
        refused = True
    expect_true(refused, "backwards cpulist range is refused")
    print("PASS: hybrid split only when the machine states it")


def test_gpu_probe_parse() raises:
    var facts = parse_nvidia_smi_csv("NVIDIA GeForce RTX 2060, 6144, 1024\n")
    expect_eq(facts.count, 1, "one gpu")
    expect_eq(facts.vram_total_bytes, 6144 * 1048576, "vram total bytes")
    expect_eq(facts.vram_free_bytes, 1024 * 1048576, "vram free bytes")
    expect_contains(facts.name, "RTX 2060", "gpu name")
    var entry = gpu_entry(facts)
    expect_true(entry.present, "gpu entry present")
    expect_contains(entry.detail, "RTX 2060", "line states the gpu")
    expect_contains(entry.detail, "VRAM", "line states vram")
    var two = parse_nvidia_smi_csv("Card A, 8192, 4096\nCard B, 8192, 8192\n")
    expect_eq(two.count, 2, "two gpus counted")
    expect_contains(
        gpu_entry(two).detail, "2 devices probed", "line counts the rest"
    )
    print("PASS: gpu probe parse (name, VRAM bytes, device count)")


def test_gpu_probe_refusals() raises:
    var empty_refused = False
    try:
        _ = parse_nvidia_smi_csv("\n")
    except:
        empty_refused = True
    expect_true(empty_refused, "empty probe output is refused")
    var shape_refused = False
    try:
        _ = parse_nvidia_smi_csv("Some GPU, 6144\n")
    except:
        shape_refused = True
    expect_true(shape_refused, "short row is refused")
    var number_refused = False
    try:
        _ = parse_nvidia_smi_csv("Some GPU, plenty, 1024\n")
    except:
        number_refused = True
    expect_true(number_refused, "non-numeric VRAM is refused")
    print("PASS: gpu probe refusals (empty, malformed, non-numeric)")


def test_drm_cross_check() raises:
    expect_true(
        parse_drm_listing("version\ncard0\ncard0-DP-1\n"),
        "card device seen",
    )
    expect_true(
        not parse_drm_listing("version\n"), "no card in an empty drm class"
    )
    expect_true(
        not parse_drm_listing("card0-DP-1\n"),
        "a connector entry alone is not a card",
    )
    print("PASS: drm listing cross-check (card vs connector entries)")


def test_npu_ledger() raises:
    var parked = npu_entry(NPU_LEDGER_PARKED, String(""))
    expect_true(not parked.present, "parked npu is not present")
    expect_contains(parked.reason, "parked", "reason states the park")
    expect_contains(parked.reason, "not probed", "reason states no probe")
    expect_contains(parked.reason, "never run", "reason states never run")
    var absent = npu_entry(NPU_LEDGER_NOT_PRESENT, String(""))
    expect_contains(absent.reason, "no NPU in Aesir's ledgers", "not-present")
    var unprobed = npu_entry(NPU_LEDGER_NOT_PROBED, String(""))
    expect_contains(unprobed.reason, "not probed", "not-probed state")
    print("PASS: npu entry is the ledger state, never a live chip claim")


def test_device_line_completeness() raises:
    var inv = DeviceInventory()
    inv.cpu = cpu_entry(parse_cpuinfo(_vm_cpuinfo()))
    inv.gpu = gpu_entry(parse_nvidia_smi_csv("Card A, 6144, 1024\n"))
    inv.npu = npu_entry(NPU_LEDGER_PARKED, String(""))
    var line = inv.device_line()
    expect_contains(line, "cpu present", "line carries cpu")
    expect_contains(line, "gpu present", "line carries gpu")
    expect_contains(line, "npu absent", "line carries npu with reason")
    expect_contains(line, " | ", "line is one bench-style line")
    # The all-absent shape: every kind still on the line, each with
    # its reason -- a missing kind would be this slice's defect.
    var bare = DeviceInventory()
    bare.gpu = gpu_absent_entry("no GPU probe answered: test double")
    var bare_line = bare.device_line()
    expect_contains(bare_line, "cpu absent", "bare line carries cpu")
    expect_contains(bare_line, "gpu absent", "bare line carries gpu")
    expect_contains(bare_line, "npu absent", "bare line carries npu")
    expect_contains(
        bare_line, "test double", "bare line carries the gpu reason"
    )
    # The J-047 feed point: present passes, absent refuses with the
    # inventory's own reason.
    require_device_present(inv, "cpu")
    require_device_present(inv, "gpu")
    var refused = False
    try:
        require_device_present(inv, "npu")
    except refusal:
        refused = True
        expect_contains(
            String(refusal), "parked", "refusal carries the ledger reason"
        )
    expect_true(refused, "absent device use is refused with its reason")
    print("PASS: device line completeness + require_device_present feed point")


def test_live_probe_this_machine() raises:
    # The real probes, on the machine running this test. This VM
    # has no GPU: the absent-with-reason gpu entry is the genuine
    # expected truth here, asserted as such.
    var inv = observe_device_inventory()
    expect_true(inv.cpu.present, "live cpu present")
    var facts_line = inv.cpu.render()
    expect_contains(facts_line, "logical", "live cpu line quantified")
    expect_true(not inv.gpu.present, "live gpu absent on this VM")
    expect_true(
        inv.gpu.reason.byte_length() > 0, "live gpu carries its reason"
    )
    expect_true(not inv.npu.present, "live npu not present (parked ledger)")
    expect_contains(inv.npu.reason, "parked", "live npu states the park")
    var line = inv.device_line()
    expect_contains(line, "cpu", "live line carries cpu")
    expect_contains(line, "gpu", "live line carries gpu")
    expect_contains(line, "npu", "live line carries npu")
    print("LIVE DEVICE LINE: " + line)
    print("PASS: live probe on this machine (cpu present, gpu absent-with-reason, npu parked)")


def main() raises:
    test_cpuinfo_topology()
    test_cpuinfo_topology_poor()
    test_hybrid_split_machine_stated_only()
    test_gpu_probe_parse()
    test_gpu_probe_refusals()
    test_drm_cross_check()
    test_npu_ledger()
    test_device_line_completeness()
    test_live_probe_this_machine()
    print("ALL PASS: device inventory (9 groups)")
