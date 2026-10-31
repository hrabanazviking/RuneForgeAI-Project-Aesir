# J-026 real-module replay: feeds the J-016 measured OLMoE trace,
# pre-flattened to the interleaved two-tenant schedule
# (j026_flatten.py: tenant,layer,expert,scaled_size rows in token
# round-robin order, plus X,<tenant> exhaustion markers; tenant
# A = prose+code+technical, tenant B = structured+numbers+
# instructions), through TWO real ExpertCache instances (fsketch,
# the shipping default) driven by the real SharedExpertBudget
# arbiter exactly as the J-026 host loop prescribes: cap applied
# before every access (resize_budget, with floor enforcement
# against the peer first when the raw cap would break the floor),
# lending reclaim after an admission that breaks the pool total
# against an inactive lender (shed_to_resident toward
# lender_reclaim_target).
#
# The counters printed here must reproduce j026_multi.py's
# interleaved pool-scheme counters EXACTLY (the simulator is the
# validated one from J-024/J-025; this replay is the cross-check
# that the pool machinery in the real module behaves identically).
# Sizes are the header's per-layer expert bytes divided by 1024
# (exact for both layer classes); budgets scale by the same factor.
from core.expert_cache import ExpertCache, SharedExpertBudget


def run_pool(access_text: String, total_budget: Int) raises:
    var pool = SharedExpertBudget(total_budget, 2)
    var caches = List[ExpertCache]()
    caches.append(ExpertCache(total_budget, String("fsketch")))
    caches.append(ExpertCache(total_budget, String("fsketch")))
    var actives = List[Bool]()
    actives.append(True)
    actives.append(True)
    for line in access_text.split("\n"):
        if line.byte_length() == 0:
            continue
        var parts = line.split(",")
        if String(parts[0]) == "X":
            if String(parts[1]) == "A":
                actives[0] = False
            else:
                actives[1] = False
            continue
        var tenant = 0
        if String(parts[0]) == "B":
            tenant = 1
        var other = 1 - tenant
        var layer = atol(String(parts[1]))
        var expert = atol(String(parts[2]))
        var size = atol(String(parts[3]))
        var residents = List[Int]()
        residents.append(caches[0].snapshot().bytes_resident_now)
        residents.append(caches[1].snapshot().bytes_resident_now)
        var prot = pool.protected_bytes(residents[other], actives[other])
        var raw_cap = total_budget - prot
        var cap = raw_cap
        if raw_cap < pool.floor_bytes:
            var target = pool.floor_bytes
            if actives[other]:
                target = total_budget - pool.floor_bytes
            if residents[other] > target:
                _ = caches[other].shed_to_resident(target)
            cap = pool.floor_bytes
        _ = caches[tenant].resize_budget(cap)
        _ = caches[tenant].access(layer, expert, size)
        var summed = caches[0].snapshot().bytes_resident_now + caches[1].snapshot().bytes_resident_now
        if summed > total_budget and not actives[other]:
            var lender_resident = caches[other].snapshot().bytes_resident_now
            if lender_resident > pool.floor_bytes:
                var target = pool.lender_reclaim_target(
                    lender_resident, summed
                )
                _ = caches[other].shed_to_resident(target)
                summed = caches[0].snapshot().bytes_resident_now + caches[1].snapshot().bytes_resident_now
        if summed > total_budget:
            raise Error("pool invariant broken in real-module replay")
    print("pool total_budget", total_budget)
    print(" tenant A", caches[0].snapshot().describe())
    print(" tenant B", caches[1].snapshot().describe())


def main() raises:
    var text: String
    with open("j026_accesses.csv", "r") as source:
        text = source.read()
    # Mean scaled pair size is 3720; totals are pair-class x mean,
    # the same construction as J-016/J-018/J-024.
    run_pool(text, 256 * 3720)
    run_pool(text, 512 * 3720)
