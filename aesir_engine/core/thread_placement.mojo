# core/thread_placement.mojo
# Thread placement map (slice A-024): a Zen 5 topology-aware CPU
# affinity helper for CPU work. The Z13's Strix Halo part states its
# own topology in sysfs -- 16 physical cores / 32 logical CPUs in
# SMT pairs, two L3 domains (CCD0: cores 0-7, CCD1: cores 8-15) on
# one package / one NUMA node -- and this module turns those stated
# facts into a placement map: an ordered, deterministic assignment
# of worker threads to logical CPUs, plus the sched_setaffinity
# calls that apply it (via aesir_engine/affinity_shim.c).
#
# This is NOT core/thread_topology (J-039): that module derives a
# thread-COUNT ladder and grades scaling. This module owns WHICH
# CPUs those threads land on. The two compose: pick a count with
# the ladder, place those threads with this map.
#
# Policies (a policy is a full ordering of every logical CPU; a
# placement for N workers is the first N entries -- deterministic,
# distinct, never oversubscribed):
#   PLACEMENT_SPREAD (the default): one thread per physical core
#     first, cores interleaved across L3 domains (CCD0 core, CCD1
#     core, ...) so N <= core-count workers touch every domain's
#     L3 evenly and never share an SMT sibling; SMT siblings are
#     handed out only after every physical core carries one
#     thread, in the same core order.
#   PLACEMENT_PACK: fill each physical core completely (both SMT
#     siblings) before moving to the next core, cores in natural
#     order. For tightly-coupled workers that share data through
#     one core's L1/L2 -- measured on this machine it is WORSE for
#     independent CPU work (see the A-024 ledger); it is not the
#     default and exists for the coupled case and for measurement.
#   PLACEMENT_CCD_LOCAL: spread across one L3 domain's physical
#     cores first (then that domain's siblings), spilling to the
#     next domain only when the first is full. For work whose
#     shared data should stay inside one 32 MiB L3.
#
# Fail-closed discipline: every parser and builder validates --
# malformed CPU lists (empty, non-decimal, descending ranges,
# duplicates, absurd ids), sibling lists that do not partition
# the CPU set, L3 lists that split a physical core or leave a CPU
# uncovered, worker counts outside [1, logical], and unknown
# policy codes all raise. Nothing is clamped, nothing is guessed
# from a model name. observe_topology() never raises: a machine
# whose sysfs cannot be read yields observed=False and callers
# must treat placement as unavailable, never invent a topology.
#
# Affinity application is checked, never assumed: apply_affinity
# raises on any shim refusal, and current_affinity reads the real
# mask back so a caller (and the E-MASTER case) can verify the
# kernel state matches the map it asked for.

from std.ffi import external_call
from std.memory import Pointer
from std.collections import InlineArray

from core.observation_integer import bounded_decimal

comptime PLACEMENT_SPREAD = 0
comptime PLACEMENT_PACK = 1
comptime PLACEMENT_CCD_LOCAL = 2
comptime PLACEMENT_DEFAULT = PLACEMENT_SPREAD

comptime _MAX_CPU_ID = 8192
comptime _SYSFS_CPU_ROOT = "/sys/devices/system/cpu"


def parse_cpu_list(text: String) raises -> List[Int]:
    """Parse a Linux CPU list ("0-7,16-23", "5", "0,2,4").

    Order is preserved as written. Raises on empty text, empty
    elements, non-decimal characters, descending or open ranges,
    duplicate CPUs, and ids beyond the sanity bound -- a topology
    string the kernel did not write must never be half-parsed.
    """
    var stripped = String(text.strip())
    if stripped.byte_length() == 0:
        raise Error("ThreadPlacement: empty CPU list")
    var out = List[Int]()
    for raw_part in stripped.split(","):
        var part = String(raw_part.strip())
        if part.byte_length() == 0:
            raise Error("ThreadPlacement: empty element in CPU list")
        var dash = part.split("-")
        if len(dash) == 1:
            var v = bounded_decimal(part)
            if v > _MAX_CPU_ID:
                raise Error("ThreadPlacement: CPU id out of range")
            out.append(v)
        elif len(dash) == 2:
            var lo_s = String(dash[0].strip())
            var hi_s = String(dash[1].strip())
            if lo_s.byte_length() == 0 or hi_s.byte_length() == 0:
                raise Error("ThreadPlacement: open range in CPU list")
            var lo = bounded_decimal(lo_s)
            var hi = bounded_decimal(hi_s)
            if hi < lo:
                raise Error("ThreadPlacement: descending range in CPU list")
            if hi > _MAX_CPU_ID:
                raise Error("ThreadPlacement: CPU id out of range")
            for v in range(lo, hi + 1):
                out.append(v)
        else:
            raise Error("ThreadPlacement: malformed range in CPU list")
    for i in range(len(out)):
        for j in range(i + 1, len(out)):
            if out[i] == out[j]:
                raise Error("ThreadPlacement: duplicate CPU in list")
    return out^


def format_cpu_list(cpus: List[Int]) raises -> String:
    """Format a strictly ascending CPU list in kernel list style.

    Raises unless the input is sorted ascending with no duplicates
    (the exact inverse of parse_cpu_list on canonical text).
    """
    if len(cpus) == 0:
        raise Error("ThreadPlacement: cannot format an empty CPU list")
    for i in range(1, len(cpus)):
        if cpus[i] <= cpus[i - 1]:
            raise Error("ThreadPlacement: CPU list not strictly ascending")
    var out = String("")
    var run_start = cpus[0]
    var prev = cpus[0]
    for i in range(1, len(cpus)):
        if cpus[i] == prev + 1:
            prev = cpus[i]
            continue
        if run_start == prev:
            out += String(run_start)
        else:
            out += String(run_start) + "-" + String(prev)
        out += ","
        run_start = cpus[i]
        prev = cpus[i]
    if run_start == prev:
        out += String(run_start)
    else:
        out += String(run_start) + "-" + String(prev)
    return out


def _contains(cpus: List[Int], v: Int) -> Bool:
    for i in range(len(cpus)):
        if cpus[i] == v:
            return True
    return False


def _sorted_copy(cpus: List[Int]) -> List[Int]:
    var out = List[Int]()
    for i in range(len(cpus)):
        out.append(cpus[i])
    for i in range(len(out)):
        for j in range(i + 1, len(out)):
            if out[j] < out[i]:
                var tmp = out[i]
                out[i] = out[j]
                out[j] = tmp
    return out^


struct CpuTopology(Copyable, Movable):
    """Validated CPU topology: parallel arrays over sorted CPUs.

    cpus holds every logical CPU ascending; core_of[i] is the
    physical-core ordinal of cpus[i] (cores are numbered by their
    lowest CPU id); ccd_of[i] is the L3-domain (CCD) ordinal of
    cpus[i] (domains numbered by their lowest CPU id). observed is
    False for the empty topology observe_topology() returns when
    sysfs cannot be read.
    """

    var cpus: List[Int]
    var core_of: List[Int]
    var ccd_of: List[Int]
    var num_cores: Int
    var num_ccds: Int
    var observed: Bool

    def __init__(out self):
        self.cpus = List[Int]()
        self.core_of = List[Int]()
        self.ccd_of = List[Int]()
        self.num_cores = 0
        self.num_ccds = 0
        self.observed = False

    def logical_count(self) -> Int:
        return len(self.cpus)

    def core_cpus(self, core: Int) raises -> List[Int]:
        """Logical CPUs of one physical core, ascending (SMT set)."""
        if core < 0 or core >= self.num_cores:
            raise Error("ThreadPlacement: core ordinal out of range")
        var out = List[Int]()
        for i in range(len(self.cpus)):
            if self.core_of[i] == core:
                out.append(self.cpus[i])
        return out^

    def ccd_cores(self, ccd: Int) raises -> List[Int]:
        """Physical-core ordinals inside one L3 domain, ascending."""
        if ccd < 0 or ccd >= self.num_ccds:
            raise Error("ThreadPlacement: CCD ordinal out of range")
        var out = List[Int]()
        for i in range(len(self.cpus)):
            if self.ccd_of[i] == ccd:
                var core = self.core_of[i]
                if not _contains(out, core):
                    out.append(core)
        return out^

    def siblings_of(self, cpu: Int) raises -> List[Int]:
        """SMT siblings of one logical CPU (including itself)."""
        for i in range(len(self.cpus)):
            if self.cpus[i] == cpu:
                return self.core_cpus(self.core_of[i])
        raise Error("ThreadPlacement: CPU not in topology")


def build_topology(
    sibling_lists: List[String], l3_lists: List[String]
) raises -> CpuTopology:
    """Build a validated topology from sysfs list strings.

    sibling_lists carries ONE thread_siblings_list per physical
    core; l3_lists carries ONE L3 shared_cpu_list per L3 domain.
    The sibling lists must partition the CPU set exactly and every
    L3 list must be a union of whole cores covering every CPU --
    anything else raises (a core split across L3 domains is a
    contradiction in the source, never something to smooth over).
    """
    if len(sibling_lists) == 0:
        raise Error("ThreadPlacement: no sibling lists")
    if len(l3_lists) == 0:
        raise Error("ThreadPlacement: no L3 lists")
    var cores = List[List[Int]]()
    var all_cpus = List[Int]()
    for s in range(len(sibling_lists)):
        var parsed = parse_cpu_list(sibling_lists[s])
        var sorted_parsed = _sorted_copy(parsed)
        for i in range(len(sorted_parsed)):
            if _contains(all_cpus, sorted_parsed[i]):
                raise Error(
                    "ThreadPlacement: CPU in two sibling lists (not a"
                    " partition)"
                )
            all_cpus.append(sorted_parsed[i])
        cores.append(sorted_parsed^)
    # Number cores by their lowest CPU id.
    for i in range(len(cores)):
        for j in range(i + 1, len(cores)):
            if cores[j][0] < cores[i][0]:
                var tmp = cores[i].copy()
                cores[i] = cores[j].copy()
                cores[j] = tmp^
    var domains = List[List[Int]]()
    for s in range(len(l3_lists)):
        var parsed = parse_cpu_list(l3_lists[s])
        domains.append(_sorted_copy(parsed))
    for i in range(len(domains)):
        for j in range(i + 1, len(domains)):
            if domains[j][0] < domains[i][0]:
                var tmp = domains[i].copy()
                domains[i] = domains[j].copy()
                domains[j] = tmp^
    # Every CPU in exactly one domain; no core split across domains.
    for i in range(len(all_cpus)):
        var cpu = all_cpus[i]
        var hits = 0
        for d in range(len(domains)):
            if _contains(domains[d], cpu):
                hits += 1
        if hits != 1:
            raise Error(
                "ThreadPlacement: CPU covered by "
                + String(hits)
                + " L3 domains"
            )
    for c in range(len(cores)):
        var home = -1
        for i in range(len(cores[c])):
            for d in range(len(domains)):
                if _contains(domains[d], cores[c][i]):
                    if home == -1:
                        home = d
                    elif home != d:
                        raise Error(
                            "ThreadPlacement: physical core split across"
                            " L3 domains"
                        )
    var topo = CpuTopology()
    topo.cpus = _sorted_copy(all_cpus)
    for i in range(len(topo.cpus)):
        var cpu = topo.cpus[i]
        var core_idx = -1
        var ccd_idx = -1
        for c in range(len(cores)):
            if _contains(cores[c], cpu):
                core_idx = c
        for d in range(len(domains)):
            if _contains(domains[d], cpu):
                ccd_idx = d
        topo.core_of.append(core_idx)
        topo.ccd_of.append(ccd_idx)
    topo.num_cores = len(cores)
    topo.num_ccds = len(domains)
    topo.observed = True
    return topo^


def _read_or_empty(path: String) -> String:
    try:
        var text: String
        with open(path, "r") as source:
            text = source.read()
        return text
    except:
        return String("")


def observe_topology() -> CpuTopology:
    """Read the live topology from sysfs. Never raises.

    Sources, all stated by the machine itself: cpu/online for the
    logical set, each CPU's topology/thread_siblings_list for the
    physical cores, and each CPU's cache/index3/shared_cpu_list
    for the L3 domains. Any read or validation failure yields the
    empty topology with observed=False.
    """
    try:
        var online_text = _read_or_empty(_SYSFS_CPU_ROOT + "/online")
        if online_text.byte_length() == 0:
            return CpuTopology()
        var online = parse_cpu_list(online_text)
        var sib_distinct = List[String]()
        var l3_distinct = List[String]()
        for i in range(len(online)):
            var base = _SYSFS_CPU_ROOT + "/cpu" + String(online[i])
            var sib = String(
                _read_or_empty(base + "/topology/thread_siblings_list")
                .strip()
            )
            var l3 = String(
                _read_or_empty(base + "/cache/index3/shared_cpu_list")
                .strip()
            )
            if sib.byte_length() == 0 or l3.byte_length() == 0:
                return CpuTopology()
            var seen = False
            for k in range(len(sib_distinct)):
                if sib_distinct[k] == sib:
                    seen = True
            if not seen:
                sib_distinct.append(sib)
            seen = False
            for k in range(len(l3_distinct)):
                if l3_distinct[k] == l3:
                    seen = True
            if not seen:
                l3_distinct.append(l3)
        return build_topology(sib_distinct, l3_distinct)
    except:
        return CpuTopology()


def _spread_core_order(topo: CpuTopology) raises -> List[Int]:
    """Core ordinals interleaved across L3 domains: rank r of
    every domain before rank r+1 of any domain."""
    var per_ccd = List[List[Int]]()
    for d in range(topo.num_ccds):
        per_ccd.append(topo.ccd_cores(d))
    var max_rank = 0
    for d in range(len(per_ccd)):
        if len(per_ccd[d]) > max_rank:
            max_rank = len(per_ccd[d])
    var order = List[Int]()
    for rank in range(max_rank):
        for d in range(len(per_ccd)):
            if rank < len(per_ccd[d]):
                order.append(per_ccd[d][rank])
    return order^


def policy_order(topo: CpuTopology, policy: Int) raises -> List[Int]:
    """The policy's full ordering of every logical CPU."""
    if not topo.observed or topo.logical_count() == 0:
        raise Error("ThreadPlacement: topology not observed")
    var order = List[Int]()
    if policy == PLACEMENT_SPREAD:
        var cores = _spread_core_order(topo)
        var max_sib = 0
        for c in range(topo.num_cores):
            var n = len(topo.core_cpus(c))
            if n > max_sib:
                max_sib = n
        for rank in range(max_sib):
            for ci in range(len(cores)):
                var sibs = topo.core_cpus(cores[ci])
                if rank < len(sibs):
                    order.append(sibs[rank])
    elif policy == PLACEMENT_PACK:
        for c in range(topo.num_cores):
            var sibs = topo.core_cpus(c)
            for i in range(len(sibs)):
                order.append(sibs[i])
    elif policy == PLACEMENT_CCD_LOCAL:
        for d in range(topo.num_ccds):
            var cores = topo.ccd_cores(d)
            var max_sib = 0
            for ci in range(len(cores)):
                var n = len(topo.core_cpus(cores[ci]))
                if n > max_sib:
                    max_sib = n
            for rank in range(max_sib):
                for ci in range(len(cores)):
                    var sibs = topo.core_cpus(cores[ci])
                    if rank < len(sibs):
                        order.append(sibs[rank])
    else:
        raise Error("ThreadPlacement: unknown placement policy")
    if len(order) != topo.logical_count():
        raise Error("ThreadPlacement: policy order is not a permutation")
    return order^


def placement_map(
    topo: CpuTopology, workers: Int, policy: Int
) raises -> List[Int]:
    """The first `workers` CPUs of the policy order.

    Raises for worker counts outside [1, logical CPUs] -- an
    oversubscribed or empty placement is a caller bug, never
    something to clamp into a different map than was asked for.
    """
    if workers < 1:
        raise Error("ThreadPlacement: workers must be positive")
    if workers > topo.logical_count():
        raise Error("ThreadPlacement: workers exceed logical CPUs")
    var order = policy_order(topo, policy)
    var out = List[Int]()
    for i in range(workers):
        out.append(order[i])
    return out^


def default_placement(topo: CpuTopology, workers: Int) raises -> List[Int]:
    """placement_map with PLACEMENT_DEFAULT (SPREAD)."""
    return placement_map(topo, workers, PLACEMENT_DEFAULT)


def apply_affinity(cpus: List[Int]) raises:
    """Pin the calling thread to exactly `cpus` (sched_setaffinity
    via the affinity shim). Raises on an empty/out-of-range set or
    any kernel refusal -- a placement that did not take is an
    error to surface, never a silent no-op."""
    if len(cpus) == 0:
        raise Error("ThreadPlacement: empty affinity set")
    if len(cpus) > 1024:
        raise Error("ThreadPlacement: affinity set too large")
    var buf = List[Int64]()
    for i in range(len(cpus)):
        if cpus[i] < 0 or cpus[i] > _MAX_CPU_ID:
            raise Error("ThreadPlacement: affinity CPU out of range")
        buf.append(Int64(cpus[i]))
    var rc = external_call["aesir_aff_apply", Int64](
        buf.unsafe_ptr(), Int64(len(buf))
    )
    if rc == -1:
        raise Error("ThreadPlacement: affinity arguments refused by shim")
    if rc != 0:
        raise Error("ThreadPlacement: sched_setaffinity failed in shim")


def current_affinity() raises -> List[Int]:
    """The calling thread's real affinity mask, read back from the
    kernel (sched_getaffinity via the affinity shim), ascending."""
    var buf = InlineArray[Int64, 1024](fill=0)
    var n = external_call["aesir_aff_read", Int64](
        buf.unsafe_ptr(), Int64(1024)
    )
    if n < 0:
        raise Error("ThreadPlacement: sched_getaffinity failed in shim")
    var out = List[Int]()
    for i in range(Int(n)):
        out.append(Int(buf[i]))
    return out^
