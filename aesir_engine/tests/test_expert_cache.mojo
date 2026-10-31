from core.expert_cache import (
    ACCESS_HIT,
    ACCESS_MISS_ADMITTED,
    ACCESS_MISS_BYPASSED,
    ACCESS_MISS_TOO_LARGE,
    ExpertCache,
    parse_byte_size,
    plan_expert_cache_budget,
    resolve_hard_cap,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "ExpertCache "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def test_expert_cache_sizing() raises:
    # Reserve = resident 300 + KV allowance 200 + scratch 100 + OS
    # headroom (total 10000 // 5 = 2000) = 2600. Free 10000 - 2600 = 7400.
    var sizing = plan_expert_cache_budget(10000, 10000, 0, 300, 200, 100, 1000)
    expect_eq(sizing.reserve_bytes, 2600, "reserve composition")
    expect_eq(sizing.budget_bytes, 7400, "budget from free memory")
    if sizing.capped or sizing.below_floor:
        raise Error("ExpertCache sizing flags wrong for the roomy case")

    var capped = plan_expert_cache_budget(10000, 10000, 4096, 300, 200, 100, 1000)
    expect_eq(capped.budget_bytes, 4096, "hard cap honoured at sizing")
    if not capped.capped:
        raise Error("ExpertCache sizing did not report the cap")

    var tight = plan_expert_cache_budget(3000, 10000, 0, 300, 200, 100, 1000)
    expect_eq(tight.budget_bytes, 400, "tight budget arithmetic")
    if not tight.below_floor:
        raise Error("ExpertCache sizing missed the below-floor case")

    var broke = plan_expert_cache_budget(1000, 10000, 0, 300, 200, 100, 1000)
    expect_eq(broke.budget_bytes, 0, "budget never goes negative")

    expect_eq(resolve_hard_cap(2048, 1024), 2048, "flag beats env")
    expect_eq(resolve_hard_cap(0, 1024), 1024, "env used when flag unset")
    expect_eq(resolve_hard_cap(0, 0), 0, "both unset means no cap")
    expect_eq(parse_byte_size("1048576"), 1048576, "plain bytes parse")
    expect_eq(parse_byte_size("2GiB"), 2147483648, "GiB parse")
    expect_eq(parse_byte_size("512M"), 536870912, "M parse")
    expect_eq(parse_byte_size("256K"), 262144, "K parse")
    var rejected = False
    try:
        _ = parse_byte_size("lots")
    except:
        rejected = True
    if not rejected:
        raise Error("ExpertCache accepted a non-numeric byte size")
    print("PASS: expert cache sizing, cap resolution and size parsing")


def test_expert_cache_behaviour() raises:
    # Budget 800 with 100-byte experts: probation cap 100, main cap 700.
    var cache = ExpertCache(800, String("segmented"))
    expect_eq(
        cache.access(0, 1, 100), ACCESS_MISS_ADMITTED, "first touch admits"
    )
    expect_eq(cache.access(0, 1, 100), ACCESS_HIT, "second touch hits")
    var stats = cache.snapshot()
    expect_eq(stats.promotions, 1, "second touch promotes to main")
    expect_eq(stats.cold_misses, 1, "first touch is the cold miss")
    expect_eq(stats.bytes_streamed, 100, "one stream for one miss")

    # An expert larger than the whole budget is served, never admitted.
    expect_eq(
        cache.access(0, 2, 900), ACCESS_MISS_TOO_LARGE, "oversize refused"
    )
    if cache.contains(0, 2):
        raise Error("ExpertCache admitted an oversize expert")

    # Fill main through promotions, then shrink with a pin held.
    for expert in range(3, 9):
        _ = cache.access(0, expert, 100)
        _ = cache.access(0, expert, 100)
    if not cache.pin(0, 1):
        raise Error("ExpertCache could not pin a resident expert")
    var remaining = cache.shrink(200)
    if remaining > 200 and not cache.contains(0, 1):
        raise Error("ExpertCache shrink evicted a pinned expert")
    if cache.snapshot().bytes_resident_now > 800:
        raise Error("ExpertCache resident bytes exceeded the old budget")
    cache.unpin(0, 1)
    _ = cache.shrink(100)
    expect_eq(
        cache.snapshot().bytes_resident_now,
        100,
        "shrink sheds to the new budget once unpinned",
    )

    # Cap is never exceeded even transiently: after every access in a
    # long churn, resident bytes stay within budget.
    var churn = ExpertCache(500, String("segmented"))
    for round in range(200):
        _ = churn.access(round % 4, round % 37, 100)
        if churn.snapshot().bytes_resident_now > 500:
            raise Error("ExpertCache exceeded its budget during churn")
    var churn_stats = churn.snapshot()
    if churn_stats.hits + churn_stats.misses != churn_stats.accesses:
        raise Error("ExpertCache hit/miss accounting does not close")
    if churn_stats.misses != (
        churn_stats.cold_misses
        + (churn_stats.misses - churn_stats.cold_misses)
    ):
        raise Error("ExpertCache miss accounting does not close")
    print("PASS: expert cache admission, promotion, pinning, shrink, cap")


def test_expert_cache_policies() raises:
    # LRU baseline: capacity 3 experts of 100 bytes; the classic
    # 1 2 3 1 4 sequence evicts 2 (least recently used after the 1-hit).
    var lru = ExpertCache(300, String("lru"))
    _ = lru.access(0, 1, 100)
    _ = lru.access(0, 2, 100)
    _ = lru.access(0, 3, 100)
    expect_eq(lru.access(0, 1, 100), ACCESS_HIT, "lru keeps the hot expert")
    _ = lru.access(0, 4, 100)
    if lru.contains(0, 2):
        raise Error("LRU kept the least-recently-used expert")
    if not lru.contains(0, 1) or not lru.contains(0, 3):
        raise Error("LRU evicted the wrong expert")

    # LFU: a twice-touched expert survives a flood of one-touch experts.
    var lfu = ExpertCache(300, String("lfu"))
    _ = lfu.access(0, 1, 100)
    _ = lfu.access(0, 1, 100)
    _ = lfu.access(0, 2, 100)
    _ = lfu.access(0, 3, 100)
    _ = lfu.access(0, 4, 100)
    if not lfu.contains(0, 1):
        raise Error("LFU evicted its most frequent expert")
    print("PASS: expert cache LRU baseline and LFU policy modes")


def test_expert_cache_fsketch() raises:
    # fsketch (J-024): single segment, LRU victim, admission only when
    # the candidate's sketch frequency EXCEEDS the victim's.
    var cache = ExpertCache(300, String("fsketch"))
    expect_eq(
        cache.access(0, 1, 100), ACCESS_MISS_ADMITTED, "fsketch first admits"
    )
    expect_eq(cache.access(0, 1, 100), ACCESS_HIT, "fsketch second hits")
    _ = cache.access(0, 2, 100)
    _ = cache.access(0, 3, 100)
    # Cache full (300/300). Expert 1 is the LRU victim with frequency 2;
    # a first-touch candidate (frequency 1) and a second-touch one
    # (frequency 2, not exceeding) are both bypassed.
    expect_eq(
        cache.access(0, 4, 100), ACCESS_MISS_BYPASSED, "fsketch freq 1 bypass"
    )
    expect_eq(
        cache.access(0, 4, 100),
        ACCESS_MISS_BYPASSED,
        "fsketch freq 2 does not exceed victim freq 2",
    )
    if cache.contains(0, 4):
        raise Error("fsketch admitted a candidate that did not exceed")
    # Third touch: frequency 3 exceeds the victim's 2 -- evict and admit.
    expect_eq(
        cache.access(0, 4, 100), ACCESS_MISS_ADMITTED, "fsketch freq 3 admits"
    )
    if not cache.contains(0, 4) or cache.contains(0, 1):
        raise Error("fsketch evicted the wrong expert")
    var stats = cache.snapshot()
    expect_eq(stats.bypasses, 2, "fsketch bypass count")
    expect_eq(stats.evictions, 1, "fsketch eviction count")
    expect_eq(stats.promotions, 0, "fsketch has no promotions")
    expect_eq(
        cache.access(0, 9, 400), ACCESS_MISS_TOO_LARGE, "fsketch oversize"
    )
    # Cap invariant under churn, accounting closes.
    var churn = ExpertCache(500, String("fsketch"))
    for round in range(200):
        _ = churn.access(round % 4, round % 37, 100)
        if churn.snapshot().bytes_resident_now > 500:
            raise Error("fsketch exceeded its budget during churn")
    var churn_stats = churn.snapshot()
    if churn_stats.hits + churn_stats.misses != churn_stats.accesses:
        raise Error("fsketch hit/miss accounting does not close")
    print("PASS: expert cache fsketch sketch-admission policy")


def test_expert_cache_no_scarcity() raises:
    # J-024 starvation fix, pinned at the @1024 shape: the budget holds
    # the whole expert body (1024 pairs x 100 bytes = budget 102400),
    # so no filtering policy may refuse admission, evict, or lose a
    # single hit after the cold pass -- full residency, 0.986-style
    # ceiling (here: every post-cold access hits).
    _no_scarcity_for_policy(String("segmented"))
    _no_scarcity_for_policy(String("fsketch"))
    print("PASS: expert cache no-scarcity starvation fix (segmented, fsketch)")


def _no_scarcity_for_policy(policy: String) raises:
    var cache = ExpertCache(102400, policy)
    for _round in range(3):
        for layer in range(16):
            for expert in range(64):
                _ = cache.access(layer, expert, 100)
    var stats = cache.snapshot()
    expect_eq(stats.accesses, 3072, policy + " no-scarcity accesses")
    expect_eq(stats.cold_misses, 1024, policy + " no-scarcity cold")
    expect_eq(stats.misses, 1024, policy + " no-scarcity misses")
    expect_eq(stats.hits, 2048, policy + " no-scarcity hits")
    expect_eq(stats.bypasses, 0, policy + " no-scarcity bypasses")
    expect_eq(stats.evictions, 0, policy + " no-scarcity evictions")
    expect_eq(stats.entries_now, 1024, policy + " full residency")
    expect_eq(stats.bytes_resident_now, 102400, policy + " resident bytes")


def test_expert_cache() raises:
    test_expert_cache_sizing()
    test_expert_cache_behaviour()
    test_expert_cache_policies()
    test_expert_cache_fsketch()
    test_expert_cache_no_scarcity()


def main() raises:
    test_expert_cache()
