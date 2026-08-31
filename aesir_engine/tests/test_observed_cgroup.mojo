"""Opt-in kernel-enforced cgroup test; run inside a 256 MiB memory scope."""
from core.native_hardware import observe_host_memory
from core.inference_memory import InferenceMemoryPlan


def main() raises:
    var host = observe_host_memory()
    print("effective_total=", host.total_bytes, "effective_available=", host.available_bytes,
          "source=", host.source, "levels=", host.cgroup_levels)
    if host.total_bytes != 268435456 or host.available_bytes > host.total_bytes or host.cgroup_levels < 1:
        raise Error("Expected a real kernel-enforced 256 MiB cgroup scope")
    var rejected = False
    try:
        var plan = InferenceMemoryPlan(536870912, 1024, 1024)
        plan.admit(2147483648, host.available_bytes, 0)
    except:
        rejected = True
    if not rejected:
        raise Error("Model admission ignored the enforced cgroup limit")
    print("PASS physical cgroup v2 observation and host-memory rejection")
