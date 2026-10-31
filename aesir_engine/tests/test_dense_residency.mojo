"""Dense-layer residency (J-021): sizing parity with the J-018 expert
contract, spill-plan derivation, and the demand cache over layer units
-- including the cyclic-scan behaviour that makes the static pinned
partition the shipping dense form.
"""
from core.dense_residency import (
    ACCESS_HIT,
    ACCESS_MISS_ADMITTED,
    ACCESS_MISS_BYPASSED,
    ACCESS_MISS_TOO_LARGE,
    DenseLayerCache,
    describe_dense_spill,
    parse_byte_size,
    plan_dense_layer_budget,
    plan_dense_spill,
    resolve_hard_cap,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "DenseResidency "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def test_dense_residency_sizing() raises:
    # Term-for-term the J-018 sizing test's numbers: reserve = resident
    # 300 + KV allowance 200 + scratch 100 + OS headroom (10000 // 5 =
    # 2000) = 2600; free 10000 - 2600 = 7400. The dense floor is the
    # largest layer (1000 here), where J-018's floor is one token's
    # routed demand -- the arithmetic around it is identical.
    var sizing = plan_dense_layer_budget(10000, 10000, 0, 300, 200, 100, 1000)
    expect_eq(sizing.reserve_bytes, 2600, "reserve composition")
    expect_eq(sizing.budget_bytes, 7400, "budget from free memory")
    if sizing.capped or sizing.below_floor:
        raise Error("DenseResidency sizing flags wrong for the roomy case")

    var capped = plan_dense_layer_budget(10000, 10000, 4096, 300, 200, 100, 1000)
    expect_eq(capped.budget_bytes, 4096, "hard cap honoured at sizing")
    if not capped.capped:
        raise Error("DenseResidency sizing did not report the cap")

    var tight = plan_dense_layer_budget(3000, 10000, 0, 300, 200, 100, 1000)
    expect_eq(tight.budget_bytes, 400, "tight budget arithmetic")
    if not tight.below_floor:
        raise Error("DenseResidency sizing missed the below-floor case")

    var broke = plan_dense_layer_budget(1000, 10000, 0, 300, 200, 100, 1000)
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
        raise Error("DenseResidency accepted a non-numeric byte size")
    print("PASS: dense residency sizing, cap resolution and size parsing")


def test_dense_residency_plan() raises:
    # 32 uniform layers of 100 bytes, always-resident 50.
    var sizes = List[Int]()
    for _ in range(32):
        sizes.append(100)

    # A chosen split, stated: 31/32 front -- the proven spill shape.
    # Front always-resident 50 rides with the device; tail-resident 20
    # (final norm + untied head) rides with the host.
    var chosen = describe_dense_spill(sizes, 31, 50, 20)
    expect_eq(chosen.gpu_layers, 31, "chosen split gpu layers")
    expect_eq(chosen.host_layers, 1, "chosen split host layers")
    expect_eq(chosen.gpu_layer_bytes, 3100, "chosen split gpu bytes")
    expect_eq(chosen.host_layer_bytes, 100, "chosen split host bytes")
    expect_eq(chosen.total_layer_bytes, 3200, "chosen split total bytes")
    expect_eq(chosen.device_resident_bytes(), 3150, "device resident bytes")
    expect_eq(chosen.host_total_bytes(), 120, "host total bytes")
    if not chosen.spilled:
        raise Error("31/32 split must report spilled")

    # Derived splits: the budget buys whole layers only, in order.
    var derived = plan_dense_spill(sizes, 50, 3150)
    expect_eq(derived.gpu_layers, 31, "budget 3150 derives 31 front layers")
    var one_less = plan_dense_spill(sizes, 50, 3149)
    expect_eq(one_less.gpu_layers, 30, "one byte less derives 30 layers")
    var whole = plan_dense_spill(sizes, 50, 3250)
    expect_eq(whole.gpu_layers, 32, "full budget derives all layers")
    if whole.spilled:
        raise Error("full residency must not report spilled")
    var starved = plan_dense_spill(sizes, 50, 49)
    expect_eq(starved.gpu_layers, 0, "budget below always-resident admits none")
    expect_eq(starved.host_layer_bytes, 3200, "starved plan hosts everything")

    # Non-uniform sizes: the prefix stops at the first layer that does
    # not fit whole; it never skips ahead to a smaller later layer.
    var ragged = List[Int]()
    ragged.append(500)
    ragged.append(100)
    ragged.append(100)
    var ragged_plan = plan_dense_spill(ragged, 0, 550)
    expect_eq(ragged_plan.gpu_layers, 1, "ragged prefix stops at first misfit")
    expect_eq(ragged_plan.host_layer_bytes, 200, "ragged host bytes")

    var refused = False
    try:
        _ = describe_dense_spill(sizes, 33, 50, 20)
    except:
        refused = True
    if not refused:
        raise Error("DenseResidency accepted gpu_layers beyond the layer count")
    print("PASS: dense residency spill plan derivation and statement")


def test_dense_residency_cache() raises:
    # Full residency under LRU: 8 layers of 100 bytes, budget exactly
    # the body. A cyclic scan then pays cold once per layer and hits
    # forever -- the degenerate case J-017 section 4.3 names for
    # experts, here exact for layers.
    var full = DenseLayerCache(800, String("lru"))
    for _ in range(10):
        for layer in range(8):
            _ = full.access(layer, 100)
    var full_stats = full.snapshot()
    expect_eq(full_stats.accesses, 80, "full-residency accesses")
    expect_eq(full_stats.cold_misses, 8, "full-residency cold = layer count")
    expect_eq(full_stats.hits, 72, "full-residency hits after cold")
    expect_eq(full_stats.bytes_streamed, 800, "full-residency streams body once")
    expect_eq(full_stats.bytes_resident_now, 800, "full-residency resident bytes")

    # The same full budget under the segmented shipping policy scores
    # ZERO hits: promotion needs a second touch while the layer is
    # still in probation, probation holds one eighth of the budget
    # (one layer here), and the scan's cycle length is the whole body
    # -- every layer is evicted from probation before its next turn.
    # Promotion starvation, measured in the machinery itself; it is
    # why the dense shipping form is the pinned static partition.
    var seg = DenseLayerCache(800, String("segmented"))
    for _ in range(10):
        for layer in range(8):
            _ = seg.access(layer, 100)
    var seg_stats = seg.snapshot()
    expect_eq(seg_stats.hits, 0, "segmented starves promotion on a cyclic scan")
    expect_eq(seg_stats.promotions, 0, "no promotion ever fires on the scan")
    expect_eq(seg_stats.bytes_streamed, 8000, "segmented streams the body per token")

    # The cyclic scan at half budget: LRU's textbook failure, measured
    # in Aesir's own machinery. Every access misses; nothing is ever
    # resident when its turn comes round again.
    var lru = DenseLayerCache(400, String("lru"))
    for _ in range(4):
        for layer in range(8):
            _ = lru.access(layer, 100)
    var lru_stats = lru.snapshot()
    expect_eq(lru_stats.accesses, 32, "scan accesses")
    expect_eq(lru_stats.hits, 0, "LRU scores zero hits on a cyclic scan")
    expect_eq(lru_stats.cold_misses, 8, "scan cold count")
    expect_eq(lru_stats.bytes_streamed, 3200, "scan streams the body per token")
    if lru_stats.evicted_before_reuse == 0:
        raise Error("scan thrash must count evicted-before-reuse")

    # Oversize refusal and the cap invariant under churn.
    var churn = DenseLayerCache(1000, String("segmented"))
    expect_eq(
        churn.access(0, 2000),
        ACCESS_MISS_TOO_LARGE,
        "a layer larger than the budget is refused by code",
    )
    var state = 12345
    for _ in range(200):
        state = (state * 1103515245 + 12345) % 2147483648
        var layer = state % 12
        _ = churn.access(layer, 100 + (state % 3) * 50)
        var now = churn.snapshot()
        if now.bytes_resident_now > 1000:
            raise Error("DenseLayerCache exceeded its hard cap during churn")
    var churn_stats = churn.snapshot()
    expect_eq(
        churn_stats.hits + churn_stats.misses,
        churn_stats.accesses,
        "hit/miss accounting closes",
    )
    expect_eq(
        churn_stats.admissions + churn_stats.bypasses + churn_stats.too_large,
        churn_stats.misses,
        "every miss is admitted, bypassed, or refused",
    )

    # Pinning: a pinned layer survives a shrink that sheds the rest.
    var pinned = DenseLayerCache(400, String("lru"))
    for layer in range(4):
        _ = pinned.access(layer, 100)
    if not pinned.pin(1):
        raise Error("pin of a resident layer failed")
    _ = pinned.shrink(100)
    if not pinned.contains(1):
        raise Error("shrink evicted a pinned layer")
    var pinned_stats = pinned.snapshot()
    expect_eq(pinned_stats.bytes_resident_now, 100, "shrink sheds to the pin")
    pinned.unpin(1)
    _ = pinned.shrink(100)
    print("PASS: dense layer cache scan behaviour, cap, pinning, shrink")


def test_dense_residency() raises:
    test_dense_residency_sizing()
    test_dense_residency_plan()
    test_dense_residency_cache()


def main() raises:
    test_dense_residency()
