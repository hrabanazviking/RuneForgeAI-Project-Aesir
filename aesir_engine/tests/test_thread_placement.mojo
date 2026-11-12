"""Thread placement map (A-024): Zen 5 topology-aware affinity.

Parser cases pin the Linux CPU-list grammar (ranges, singletons,
round-trip formatting) and prove every malformed shape fails
closed. Map cases build the Z13's stated topology from the exact
sysfs strings this machine reports (SMT pairs (n, n+16); L3
domains 0-7,16-23 and 8-15,24-31) and pin each policy's map
against hand-derived orders: SPREAD interleaves physical cores
across L3 domains before touching SMT siblings, PACK fills SMT
pairs core by core, CCD_LOCAL exhausts one L3 domain first.

The live case reads the real sysfs topology on the host: on the
Z13 it asserts 32 logical / 16 cores / 2 L3 domains and the
(n, n+16) pairing; on a host without readable sysfs topology it
passes as honest-absent (observed=False), never inventing facts.
The affinity case applies a one-CPU placement through the shim,
reads the kernel mask back, and restores the original mask --
application is verified from sched_getaffinity, never assumed.
"""
from core.thread_placement import (
    CpuTopology,
    build_topology,
    observe_topology,
    parse_cpu_list,
    format_cpu_list,
    placement_map,
    default_placement,
    policy_order,
    apply_affinity,
    current_affinity,
    PLACEMENT_SPREAD,
    PLACEMENT_PACK,
    PLACEMENT_CCD_LOCAL,
)


def _z13_sibling_lists() -> List[String]:
    var out = List[String]()
    for core in range(16):
        out.append(String(core) + "," + String(core + 16))
    return out^


def _z13_l3_lists() -> List[String]:
    var out = List[String]()
    out.append(String("0-7,16-23"))
    out.append(String("8-15,24-31"))
    return out^


def _z13_topo() raises -> CpuTopology:
    return build_topology(_z13_sibling_lists(), _z13_l3_lists())


def _eq_list(got: List[Int], want: List[Int], what: String) raises:
    if len(got) != len(want):
        raise Error(
            what + ": length " + String(len(got)) + " != " + String(len(want))
        )
    for i in range(len(want)):
        if got[i] != want[i]:
            raise Error(
                what + ": index " + String(i) + " got " + String(got[i])
                + " want " + String(want[i])
            )


def _parse_raises(text: String) -> Bool:
    try:
        _ = parse_cpu_list(text)
        return False
    except:
        return True


def test_thread_placement_list_parse() raises:
    print("--- Testing CPU list parsing (A-024) ---")
    _eq_list(parse_cpu_list("5"), [5], "single")
    _eq_list(parse_cpu_list("0,2,4"), [0, 2, 4], "singletons")
    _eq_list(
        parse_cpu_list("0-7,16-23"),
        [0, 1, 2, 3, 4, 5, 6, 7, 16, 17, 18, 19, 20, 21, 22, 23],
        "ranges",
    )
    _eq_list(parse_cpu_list(" 3-4 "), [3, 4], "stripped range")
    if format_cpu_list(parse_cpu_list("0-7,16-23")) != "0-7,16-23":
        raise Error("round-trip 0-7,16-23")
    if format_cpu_list([0, 1, 2, 4, 6, 7]) != "0-2,4,6-7":
        raise Error("format runs")
    if format_cpu_list([9]) != "9":
        raise Error("format single")
    for bad in [
        "",
        " ",
        "a",
        "1,a",
        "3-1",
        "1,,2",
        "1,1",
        "0-3,2",
        "-3",
        "1-",
        "-",
        "1-2-3",
        "99999",
    ]:
        if not _parse_raises(bad):
            raise Error("parse accepted malformed list: '" + bad + "'")


def test_thread_placement_topology_build() raises:
    print("--- Testing topology build + validation (A-024) ---")
    var topo = _z13_topo()
    if not topo.observed:
        raise Error("synthetic topology not marked observed")
    if topo.logical_count() != 32 or topo.num_cores != 16:
        raise Error("Z13 shape: logical/cores")
    if topo.num_ccds != 2:
        raise Error("Z13 shape: CCDs")
    _eq_list(topo.siblings_of(0), [0, 16], "siblings of cpu0")
    _eq_list(topo.siblings_of(23), [7, 23], "siblings of cpu23")
    _eq_list(topo.core_cpus(8), [8, 24], "core 8 cpus")
    _eq_list(topo.ccd_cores(0), [0, 1, 2, 3, 4, 5, 6, 7], "CCD0 cores")
    _eq_list(topo.ccd_cores(1), [8, 9, 10, 11, 12, 13, 14, 15], "CCD1 cores")
    # Overlapping sibling lists are not a partition: raise.
    var bad_sib = List[String]()
    bad_sib.append(String("0,16"))
    bad_sib.append(String("16,17"))
    var raised = False
    try:
        _ = build_topology(bad_sib, _z13_l3_lists())
    except:
        raised = True
    if not raised:
        raise Error("overlapping sibling lists accepted")
    # An L3 list that splits core (0,16) across domains: raise.
    var bad_l3 = List[String]()
    bad_l3.append(String("0-15"))
    bad_l3.append(String("16-31"))
    raised = False
    try:
        _ = build_topology(_z13_sibling_lists(), bad_l3)
    except:
        raised = True
    if not raised:
        raise Error("core-splitting L3 lists accepted")
    # A CPU missing from every L3 list: raise.
    var short_l3 = List[String]()
    short_l3.append(String("0-7,16-23"))
    short_l3.append(String("8-15,24-30"))
    raised = False
    try:
        _ = build_topology(_z13_sibling_lists(), short_l3)
    except:
        raised = True
    if not raised:
        raise Error("L3 lists with a missing CPU accepted")


def test_thread_placement_map_spread() raises:
    print("--- Testing SPREAD placement map (A-024) ---")
    var topo = _z13_topo()
    _eq_list(
        default_placement(topo, 8),
        [0, 8, 1, 9, 2, 10, 3, 11],
        "spread 8",
    )
    _eq_list(
        placement_map(topo, 16, PLACEMENT_SPREAD),
        [0, 8, 1, 9, 2, 10, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15],
        "spread 16 = one per physical core",
    )
    var m17 = placement_map(topo, 17, PLACEMENT_SPREAD)
    if m17[16] != 16:
        raise Error("spread 17: first SMT sibling handed out is cpu16")
    var full = policy_order(topo, PLACEMENT_SPREAD)
    if len(full) != 32:
        raise Error("spread full order length")
    var seen = List[Int]()
    for i in range(len(full)):
        for j in range(len(seen)):
            if seen[j] == full[i]:
                raise Error("spread full order has a duplicate CPU")
        seen.append(full[i])


def test_thread_placement_map_pack_ccd() raises:
    print("--- Testing PACK + CCD_LOCAL placement maps (A-024) ---")
    var topo = _z13_topo()
    _eq_list(
        placement_map(topo, 4, PLACEMENT_PACK),
        [0, 16, 1, 17],
        "pack 4 = two full cores",
    )
    _eq_list(
        placement_map(topo, 8, PLACEMENT_CCD_LOCAL),
        [0, 1, 2, 3, 4, 5, 6, 7],
        "ccd_local 8 = CCD0 physical cores",
    )
    _eq_list(
        placement_map(topo, 16, PLACEMENT_CCD_LOCAL),
        [0, 1, 2, 3, 4, 5, 6, 7, 16, 17, 18, 19, 20, 21, 22, 23],
        "ccd_local 16 = all of CCD0",
    )
    var m20 = placement_map(topo, 20, PLACEMENT_CCD_LOCAL)
    _eq_list(
        [m20[16], m20[17], m20[18], m20[19]],
        [8, 9, 10, 11],
        "ccd_local spill into CCD1",
    )


def test_thread_placement_reject() raises:
    print("--- Testing placement rejection paths (A-024) ---")
    var topo = _z13_topo()
    for workers in [0, -1, 33, 1000]:
        var raised = False
        try:
            _ = placement_map(topo, workers, PLACEMENT_SPREAD)
        except:
            raised = True
        if not raised:
            raise Error("worker count accepted: " + String(workers))
    var raised = False
    try:
        _ = placement_map(topo, 4, 9)
    except:
        raised = True
    if not raised:
        raise Error("unknown policy accepted")
    var empty = CpuTopology()
    raised = False
    try:
        _ = placement_map(empty, 1, PLACEMENT_SPREAD)
    except:
        raised = True
    if not raised:
        raise Error("unobserved topology accepted")
    raised = False
    try:
        apply_affinity(List[Int]())
    except:
        raised = True
    if not raised:
        raise Error("empty affinity set accepted")


def test_thread_placement_live_affinity() raises:
    print("--- Testing live topology + affinity apply (A-024) ---")
    var topo = observe_topology()
    if not topo.observed:
        print("live topology: sysfs not readable here - honest-absent")
        return
    if topo.logical_count() < 1 or topo.num_cores < 1:
        raise Error("live topology shape")
    for i in range(topo.logical_count()):
        var sibs = topo.siblings_of(topo.cpus[i])
        var found = False
        for j in range(len(sibs)):
            if sibs[j] == topo.cpus[i]:
                found = True
        if not found:
            raise Error("live: CPU missing from its own sibling set")
    # The Z13's stated shape, asserted when this is the Z13.
    if topo.logical_count() == 32 and topo.num_cores == 16:
        if topo.num_ccds != 2:
            raise Error("live Z13: expected 2 L3 domains")
        _eq_list(topo.siblings_of(0), [0, 16], "live Z13 siblings of cpu0")
        _eq_list(
            default_placement(topo, 16),
            [0, 8, 1, 9, 2, 10, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15],
            "live Z13 spread 16",
        )
    # Apply + verify + restore, all read back from the kernel.
    var before = current_affinity()
    if len(before) == 0:
        raise Error("live: empty starting affinity")
    var target = List[Int]()
    target.append(before[0])
    apply_affinity(target)
    var during = current_affinity()
    _eq_list(during, target, "affinity readback after apply")
    apply_affinity(before)
    var after = current_affinity()
    _eq_list(after, before, "affinity restored")
