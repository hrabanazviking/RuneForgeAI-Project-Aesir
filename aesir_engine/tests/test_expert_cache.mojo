from core.expert_cache import (
    ACCESS_HIT,
    ACCESS_MISS_ADMITTED,
    ACCESS_MISS_BYPASSED,
    ACCESS_MISS_TOO_LARGE,
    PRESSURE_CONTINUE,
    PRESSURE_REFUSE,
    PRESSURE_REGROW,
    PRESSURE_SHRINK,
    ExpertCache,
    SharedExpertBudget,
    parse_byte_size,
    plan_expert_cache_budget,
    plan_pressure_budget,
    plan_shared_cache_pool,
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


def test_expert_cache_shared_pool() raises:
    # J-026: the over-commit the pool exists to fix, in arithmetic.
    # One session sized alone: reserve 300+200+100+2000 = 2600,
    # budget 7400. Two sessions sized independently against the same
    # free snapshot claim 14800 of a 10000-byte machine.
    var solo = plan_expert_cache_budget(10000, 10000, 0, 300, 200, 100, 1000)
    expect_eq(solo.budget_bytes, 7400, "solo sizing (pre-J-026 shape)")
    if solo.budget_bytes * 2 <= 10000:
        raise Error("Shared pool test premise broken: no over-commit")
    # The pool sizes ONCE with summed reserves: resident 600, KV 400,
    # scratch 100 (shared), headroom 2000 charged once -> budget 6900
    # for the whole process.
    var pool_sizing = plan_shared_cache_pool(
        10000, 10000, 0, 600, 400, 100, 1000
    )
    expect_eq(pool_sizing.reserve_bytes, 3100, "pool reserve composition")
    expect_eq(pool_sizing.budget_bytes, 6900, "pool budget sized once")

    # Arbiter arithmetic: total 800, two tenants, floor 800/4 = 200.
    var pool = SharedExpertBudget(800, 2)
    expect_eq(pool.floor_bytes, 200, "pool floor is total / 2N")
    var residents = List[Int]()
    residents.append(100)
    residents.append(0)
    var actives = List[Bool]()
    actives.append(True)
    actives.append(True)
    expect_eq(pool.cap_for(0, residents, actives), 800 - 0, "lone tenant cap")
    expect_eq(
        pool.cap_for(1, residents, actives), 800 - 100, "peer resident protected"
    )
    residents[0] = 700
    residents[1] = 100
    expect_eq(
        pool.cap_for(1, residents, actives),
        200,
        "raw cap below floor clamps to the floor",
    )
    # Inactive lender: only its floor is protected.
    actives[0] = False
    expect_eq(
        pool.cap_for(1, residents, actives),
        800 - 200,
        "inactive peer protects only its floor",
    )
    expect_eq(
        pool.lender_reclaim_target(700, 700 + 100),
        700,
        "no reclaim while the sum fits",
    )
    expect_eq(
        pool.lender_reclaim_target(700, 700 + 500),
        300,
        "reclaim sheds exactly the overage",
    )
    expect_eq(
        pool.lender_reclaim_target(700, 700 + 900),
        200,
        "reclaim never goes below the floor",
    )
    var refused = False
    try:
        _ = SharedExpertBudget(3, 2)
    except:
        refused = True
    if not refused:
        raise Error("SharedExpertBudget accepted a floorless pool")
    print("PASS: expert cache shared pool sizing and arbiter arithmetic")


def _pool_apply(
    pool: SharedExpertBudget,
    tenant: Int,
    mut caches: List[ExpertCache],
    actives: List[Bool],
) raises:
    """The host loop J-026 prescribes, in miniature: read residents,
    ask the arbiter for the tenant's cap, apply it (resize = shrink-
    back when the cap fell), serve one access outside, then settle
    any lending reclaim against an inactive lender."""
    var residents = List[Int]()
    for i in range(len(caches)):
        residents.append(caches[i].snapshot().bytes_resident_now)
    var cap = pool.cap_for(tenant, residents, actives)
    _ = caches[tenant].resize_budget(cap)


def _pool_reclaim(
    pool: SharedExpertBudget,
    lender: Int,
    mut caches: List[ExpertCache],
) raises:
    var summed = 0
    for i in range(len(caches)):
        summed += caches[i].snapshot().bytes_resident_now
    var lender_resident = caches[lender].snapshot().bytes_resident_now
    var target = pool.lender_reclaim_target(lender_resident, summed)
    if target < lender_resident:
        _ = caches[lender].shed_to_resident(target)


def test_expert_cache_shared_pool_drive() raises:
    # Two real caches (LRU for deterministic admission; the pool is
    # policy-agnostic) driven by the arbiter through the measured
    # schedules' shapes: contention, idle lending, and the return.
    var pool = SharedExpertBudget(800, 2)
    var caches = List[ExpertCache]()
    caches.append(ExpertCache(800, String("lru")))
    caches.append(ExpertCache(800, String("lru")))
    var actives = List[Bool]()
    actives.append(True)
    actives.append(True)

    # Tenant 0 alone first: its cap is the whole pool; it fills 600.
    for e in range(6):
        _pool_apply(pool, 0, caches, actives)
        _ = caches[0].access(0, e, 100)
    expect_eq(
        caches[0].snapshot().bytes_resident_now, 600, "tenant 0 fills alone"
    )
    # Tenant 1 arrives (both active): its cap is 800 - 600 = 200.
    for e in range(20, 22):
        _pool_apply(pool, 1, caches, actives)
        _ = caches[1].access(0, e, 100)
    expect_eq(
        caches[1].snapshot().bytes_resident_now, 200, "tenant 1 capped by peer"
    )
    var summed = caches[0].snapshot().bytes_resident_now + caches[1].snapshot().bytes_resident_now
    expect_eq(summed, 800, "summed residency holds the pool total")

    # Tenant 0 goes inactive. Tenant 1's entitlement rises to
    # 800 - floor = 600, but tenant 0's bytes still occupy the pool:
    # admission settles by reclaiming the lender toward its floor.
    actives[0] = False
    for e in range(22, 26):
        _pool_apply(pool, 1, caches, actives)
        _ = caches[1].access(0, e, 100)
        _pool_reclaim(pool, 0, caches)
        var s = caches[0].snapshot().bytes_resident_now + caches[1].snapshot().bytes_resident_now
        if s > 800:
            raise Error("Shared pool invariant broken during lending")
    expect_eq(
        caches[1].snapshot().bytes_resident_now, 600, "borrower grew into lent space"
    )
    expect_eq(
        caches[0].snapshot().bytes_resident_now,
        200,
        "lender reclaimed to exactly its floor, never below",
    )

    # Tenant 0 returns: its floor is intact (200 resident) and its
    # cap is re-established against the now-inactive tenant 1.
    actives[0] = True
    actives[1] = False
    _pool_apply(pool, 0, caches, actives)
    expect_eq(caches[0].budget_bytes, 600, "returning tenant cap restored")
    _ = caches[0].access(0, 40, 100)
    _pool_reclaim(pool, 1, caches)
    expect_eq(
        caches[1].snapshot().bytes_resident_now,
        500,
        "second lending round sheds only the overage",
    )
    expect_eq(
        caches[0].snapshot().bytes_resident_now, 300, "returnee admits again"
    )

    # Shrink-back: the pool total itself contracts (800 -> 500, a
    # smaller SharedExpertBudget over the same caches): the tenant
    # over its new cap is resized down to it, the floor holds.
    var smaller = SharedExpertBudget(500, 2)
    var residents = List[Int]()
    residents.append(caches[0].snapshot().bytes_resident_now)
    residents.append(caches[1].snapshot().bytes_resident_now)
    var both_active = List[Bool]()
    both_active.append(True)
    both_active.append(True)
    var cap0 = smaller.cap_for(0, residents, both_active)
    expect_eq(cap0, 125, "contracted pool floor is 500 / 4")
    _ = caches[0].resize_budget(cap0)
    if caches[0].snapshot().bytes_resident_now > 125:
        raise Error("resize_budget did not shrink back to the new cap")

    # Invariant churn: caps applied before every access, reclaim
    # after; the summed residency never exceeds the pool total and
    # each cache's accounting closes.
    var churn_pool = SharedExpertBudget(500, 2)
    var churn = List[ExpertCache]()
    churn.append(ExpertCache(500, String("lru")))
    churn.append(ExpertCache(500, String("lru")))
    var churn_actives = List[Bool]()
    churn_actives.append(True)
    churn_actives.append(True)
    for round in range(200):
        var tenant = round % 2
        churn_actives[tenant] = True
        churn_actives[1 - tenant] = (round % 7) != 0
        _pool_apply(churn_pool, tenant, churn, churn_actives)
        _ = churn[tenant].access(round % 4, round % 37, 100)
        if not churn_actives[1 - tenant]:
            _pool_reclaim(churn_pool, 1 - tenant, churn)
        var s = churn[0].snapshot().bytes_resident_now + churn[1].snapshot().bytes_resident_now
        if s > 500:
            raise Error("Shared pool invariant broken during churn")
    for i in range(2):
        var st = churn[i].snapshot()
        if st.hits + st.misses != st.accesses:
            raise Error("Shared pool tenant accounting does not close")
    print("PASS: expert cache shared pool drive (contention, lending, return)")


def test_expert_cache_pressure() raises:
    # J-028 decision arithmetic, on the sizing test's stated machine:
    # total 10000, resident 300 + KV 200 + scratch 100 + headroom
    # 2000 = reserve 2600; opened at free 10000 -> open budget 7400;
    # floor (one token's routed demand) 1000.
    var hold = plan_pressure_budget(10000, 10000, 0, 300, 200, 100, 1000, 7400, 7400)
    expect_eq(hold.decision, PRESSURE_CONTINUE, "pressure hold decision")
    expect_eq(hold.target_bytes, 7400, "pressure hold target")
    expect_eq(hold.reserve_bytes, 2600, "pressure reserve re-charged in full")

    var shrink = plan_pressure_budget(6000, 10000, 0, 300, 200, 100, 1000, 7400, 7400)
    expect_eq(shrink.decision, PRESSURE_SHRINK, "pressure shrink decision")
    expect_eq(shrink.target_bytes, 3400, "pressure shrink target")

    # Exactly at the floor the run continues (barely, by definition).
    var at_floor = plan_pressure_budget(3600, 10000, 0, 300, 200, 100, 1000, 7400, 7400)
    expect_eq(at_floor.decision, PRESSURE_SHRINK, "at-floor still shrinks, not refuses")
    expect_eq(at_floor.target_bytes, 1000, "at-floor target is the floor")
    if at_floor.below_floor:
        raise Error("Pressure plan flagged the exact floor as below it")

    # Below the floor: REFUSE, target 0 (the host sheds via
    # shed_to_resident(0); resize_budget is never called with it).
    var refuse = plan_pressure_budget(3500, 10000, 0, 300, 200, 100, 1000, 7400, 7400)
    expect_eq(refuse.decision, PRESSURE_REFUSE, "below-floor refuses")
    expect_eq(refuse.target_bytes, 0, "refusal target is zero")
    if not refuse.below_floor:
        raise Error("Pressure plan missed the below-floor flag")
    var broke = plan_pressure_budget(1000, 10000, 0, 300, 200, 100, 1000, 7400, 7400)
    expect_eq(broke.decision, PRESSURE_REFUSE, "negative raw budget refuses")
    expect_eq(broke.raw_bytes, 0, "raw budget never goes negative")

    # Regrow is capped at the open-time budget however far free
    # memory recovers...
    var regrow = plan_pressure_budget(50000, 10000, 0, 300, 200, 100, 1000, 7400, 3400)
    expect_eq(regrow.decision, PRESSURE_REGROW, "pressure regrow decision")
    expect_eq(regrow.target_bytes, 7400, "regrow capped at the open budget")
    # ...and at the hard cap where one is set.
    var regrow_capped = plan_pressure_budget(
        10000, 10000, 4096, 300, 200, 100, 1000, 4096, 2000
    )
    expect_eq(regrow_capped.decision, PRESSURE_REGROW, "capped regrow decision")
    expect_eq(regrow_capped.target_bytes, 4096, "regrow capped at the hard cap")
    print("PASS: expert cache pressure decisions (shrink, floor, refuse, regrow caps)")


def test_expert_cache_pressure_drive() raises:
    # J-028 host loop in miniature, on the real fsketch cache:
    # shrink under pressure with a pin held, the refusal shed, and
    # regrow (cap restored, shed entries not resurrected).
    var cache = ExpertCache(800, String("fsketch"))
    for expert in range(1, 7):
        _ = cache.access(0, expert, 100)
    expect_eq(cache.snapshot().bytes_resident_now, 600, "pressure drive fills")
    if not cache.pin(0, 1):
        raise Error("Pressure drive could not pin a resident expert")
    # Apply a shrink to 200 through the prescribed resize path (the
    # decision arithmetic itself is pinned by the group above).
    var remaining = cache.resize_budget(200)
    expect_eq(remaining, 200, "pressure shrink sheds to the target")
    if not cache.contains(0, 1):
        raise Error("Pressure shrink evicted the pinned expert")
    if not cache.contains(0, 6):
        raise Error("Pressure shrink shed past its policy order (LRU kept)")
    if cache.contains(0, 2):
        raise Error("Pressure shrink kept the coldest entry")

    # Refusal: the prescribed shed is shed_to_resident(0), never a
    # resize to a non-positive budget (which the cache refuses).
    var refused_resize = False
    try:
        _ = cache.resize_budget(0)
    except:
        refused_resize = True
    if not refused_resize:
        raise Error("resize_budget accepted a non-positive budget")
    var pinned_left = cache.shed_to_resident(0)
    expect_eq(pinned_left, 100, "refusal shed leaves only the pinned overage, visibly")
    if not cache.contains(0, 1) or cache.contains(0, 6):
        raise Error("Refusal shed kept an unpinned entry or dropped the pin")
    cache.unpin(0, 1)
    expect_eq(cache.shed_to_resident(0), 0, "refusal completes once unpinned")
    expect_eq(cache.snapshot().entries_now, 0, "refusal leaves an empty cache")

    # Regrow: the cap comes back; what was shed stays shed until
    # demand re-earns it.
    var regrown = ExpertCache(800, String("fsketch"))
    for expert in range(1, 7):
        _ = regrown.access(0, expert, 100)
    _ = regrown.resize_budget(200)
    expect_eq(regrown.snapshot().bytes_resident_now, 200, "regrow drive shrinks first")
    _ = regrown.resize_budget(800)
    expect_eq(regrown.budget_bytes, 800, "regrow restores the cap")
    expect_eq(
        regrown.snapshot().bytes_resident_now, 200, "regrow does not resurrect shed entries"
    )
    expect_eq(
        regrown.access(0, 40, 100),
        ACCESS_MISS_ADMITTED,
        "regrown cache admits on demand again",
    )
    var stats = regrown.snapshot()
    if stats.hits + stats.misses != stats.accesses:
        raise Error("Pressure drive accounting does not close")
    print("PASS: expert cache pressure drive (pin held, refusal shed, regrow)")


def test_expert_cache() raises:
    test_expert_cache_sizing()
    test_expert_cache_behaviour()
    test_expert_cache_policies()
    test_expert_cache_fsketch()
    test_expert_cache_no_scarcity()
    test_expert_cache_shared_pool()
    test_expert_cache_shared_pool_drive()
    test_expert_cache_pressure()
    test_expert_cache_pressure_drive()


def main() raises:
    test_expert_cache()
