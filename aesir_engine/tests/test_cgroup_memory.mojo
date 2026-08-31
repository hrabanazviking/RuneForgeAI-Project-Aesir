"""Injected cgroup v2 parsing and hierarchical admission invariants."""
from core.linux_cgroups import cgroup_directories, CgroupMemoryBudget, unified_membership


def test_cgroup_paths() raises:
    var mounts = "29 1 0:25 /team /narrow rw - cgroup2 cgroup2 rw\n30 1 0:25 / /sys/fs/cgroup rw - cgroup2 cgroup2 rw\n"
    var paths = cgroup_directories("0::/team/job\n", mounts)
    if len(paths) != 3 or paths[0] != "/sys/fs/cgroup/team/job" or paths[2] != "/sys/fs/cgroup":
        raise Error("Did not select most inclusive visible cgroup mount")
    paths = cgroup_directories("0::/team/job\n", "29 1 0:25 /team /a\\040b rw - cgroup2 cgroup2 rw\n")
    if len(paths) != 2 or paths[0] != "/a b/job" or paths[1] != "/a b":
        raise Error("Cgroup subtree mount or escape mapping failed")
    paths = cgroup_directories("0::/\n", "29 1 0:25 / /sys/fs/cgroup rw - cgroup2 cgroup2 rw\n")
    if len(paths) != 1 or paths[0] != "/sys/fs/cgroup":
        raise Error("Namespace-root cgroup resolution failed")


def test_cgroup_hierarchy() raises:
    var budget = CgroupMemoryBudget()
    budget.include("max\n", "100\n")
    budget.include("1000\n", "300\n")
    budget.include("2000\n", "1800\n")
    if budget.limit_bytes != 1000 or budget.available_bytes != 200 or budget.observed_levels != 3:
        raise Error("Parent usage or child limit ignored")
    budget.include("100\n", "101\n")
    if budget.available_bytes != 0:
        raise Error("Over-limit usage underflowed")
    budget.include("0", "0")
    if budget.limit_bytes != 0:
        raise Error("Zero cgroup budget ignored")


def test_cgroup_rejection() raises:
    var bad: List[String] = ["0::/a/../b", "0::relative", "0::/a//b", "0::/a\n0::/b", "3:memory:/a", "broken", "x:cpu:/a", "1::/a", "0:cpu:/a"]
    for value in bad:
        var rejected = False
        try:
            _ = unified_membership(value)
        except:
            rejected = True
        if not rejected:
            raise Error("Ambiguous or unsupported cgroup membership accepted")
    var limits: List[String] = ["", "-1", "NaN", "MAX", "9223372036854775808"]
    for value in limits:
        var rejected = False
        try:
            var budget = CgroupMemoryBudget()
            budget.include(value, "0")
        except:
            rejected = True
        if not rejected:
            raise Error("Malformed cgroup limit accepted")
    var rejected = False
    try:
        _ = cgroup_directories("0::/outside", "29 1 0:25 /team /narrow rw - cgroup2 cgroup2 rw\n")
    except:
        rejected = True
    if not rejected:
        raise Error("Unresolvable cgroup mount accepted")


def main() raises:
    test_cgroup_paths()
    test_cgroup_hierarchy()
    test_cgroup_rejection()
    print("PASS cgroup path, hierarchy and malformed-observation checks")
