# tests/test_big_model_placement_a104.mojo
# A-104: Big-model placement. The layer-split solver in
# core/big_model_placement.mojo must reproduce the pinned
# Llama-3.1-8B geometry exactly, split at a prefix boundary
# under a byte budget, account every byte (weights + KV,
# both devices), gate on the 128 GB pool, and take its GPU
# budget from the A-076 governor's effective room.

from core.big_model_placement import (
    LLAMA31_8B_EMBED_BYTES,
    LLAMA31_8B_HEAD_DIM,
    LLAMA31_8B_KV_HEADS,
    LLAMA31_8B_NON_LAYER_BYTES,
    LLAMA31_8B_OUTPUT_BYTES,
    POOL_128GB_BYTES,
    budget_from_pressure,
    kv_bytes_for_layers,
    llama31_8b_q4km_layer_bytes,
    plan_layer_split,
)


alias CTX = 4096

alias LAST16 = 2109440000


def test_big_model_geometry() raises:
    print("--- Testing A-104 pinned fixture geometry ---")
    var layers = llama31_8b_q4km_layer_bytes()
    if len(layers) != 32:
        raise Error("A-104 Llama-3.1-8B must have 32 layers")
    var total = 0
    for i in range(len(layers)):
        total += layers[i]
    if total != 4186439680:
        raise Error("A-104 layer spans must sum to 4,186,439,680")
    if LLAMA31_8B_NON_LAYER_BYTES != 726458624:
        raise Error("A-104 non-layer span drifted")
    if total + LLAMA31_8B_NON_LAYER_BYTES != 4912898304:
        raise Error("A-104 tensor payload total drifted")
    var last16 = 0
    for i in range(16, 32):
        last16 += layers[i]
    if last16 != LAST16:
        raise Error("A-104 last-16 layer span drifted")
    if LLAMA31_8B_EMBED_BYTES + LLAMA31_8B_OUTPUT_BYTES != LLAMA31_8B_NON_LAYER_BYTES:
        raise Error("A-104 embed + output must equal the non-layer span")
    print("A-104 geometry: PASS")


def test_big_model_kv_accounting() raises:
    print("--- Testing A-104 KV cache accounting ---")
    # Per token per layer: 8 KV heads * 128 dim * (K+V) * f16
    # = 4096 bytes; 32 layers * 4096 ctx = 536,870,912.
    if kv_bytes_for_layers(32, CTX, LLAMA31_8B_KV_HEADS, LLAMA31_8B_HEAD_DIM) != 536870912:
        raise Error("A-104 full KV must be 536,870,912 bytes")
    if kv_bytes_for_layers(16, CTX, LLAMA31_8B_KV_HEADS, LLAMA31_8B_HEAD_DIM) != 268435456:
        raise Error("A-104 half KV must be 268,435,456 bytes")
    if kv_bytes_for_layers(0, CTX, LLAMA31_8B_KV_HEADS, LLAMA31_8B_HEAD_DIM) != 0:
        raise Error("A-104 zero layers means zero KV")
    print("A-104 KV accounting: PASS")


def test_big_model_split_half() raises:
    print("--- Testing A-104 half split under exact budget ---")
    var layers = llama31_8b_q4km_layer_bytes()
    var budget = LLAMA31_8B_EMBED_BYTES + LAST16
    var plan = plan_layer_split(
        layers, LLAMA31_8B_EMBED_BYTES, LLAMA31_8B_OUTPUT_BYTES, budget, POOL_128GB_BYTES,
        CTX, LLAMA31_8B_KV_HEADS, LLAMA31_8B_HEAD_DIM,
    )
    if plan.gpu_layers != 16 or plan.cpu_layers != 16:
        raise Error("A-104 exact-16 budget must split 16/16")
    if plan.gpu_weight_bytes != budget:
        raise Error("A-104 GPU weights must consume the exact budget")
    if plan.gpu_weight_bytes + plan.cpu_weight_bytes != plan.total_weight_bytes:
        raise Error("A-104 weight accounting must sum to the total")
    if plan.kv_gpu_bytes != 268435456 or plan.kv_cpu_bytes != 268435456:
        raise Error("A-104 KV must follow its layers 16/16")
    if not plan.fits_pool:
        raise Error("A-104 the 8B split must fit the 128 GB pool")
    print("A-104 half split: PASS")


def test_big_model_split_edges() raises:
    print("--- Testing A-104 split edges: zero and full ---")
    var layers = llama31_8b_q4km_layer_bytes()
    var zero = plan_layer_split(
        layers, LLAMA31_8B_EMBED_BYTES, LLAMA31_8B_OUTPUT_BYTES, 0, POOL_128GB_BYTES,
        CTX, LLAMA31_8B_KV_HEADS, LLAMA31_8B_HEAD_DIM,
    )
    if zero.gpu_layers != 0 or zero.gpu_weight_bytes != 0:
        raise Error("A-104 zero budget must be all-CPU")
    if zero.cpu_weight_bytes != zero.total_weight_bytes:
        raise Error("A-104 all-CPU accounting must hold the total")
    var embed_only = plan_layer_split(
        layers, LLAMA31_8B_EMBED_BYTES, LLAMA31_8B_OUTPUT_BYTES,
        LLAMA31_8B_EMBED_BYTES, POOL_128GB_BYTES,
        CTX, LLAMA31_8B_KV_HEADS, LLAMA31_8B_HEAD_DIM,
    )
    if embed_only.gpu_layers != 0 or embed_only.gpu_weight_bytes != 0:
        raise Error("A-104 embedding-only budget is not a split")
    var full = plan_layer_split(
        layers, LLAMA31_8B_EMBED_BYTES, LLAMA31_8B_OUTPUT_BYTES,
        POOL_128GB_BYTES, POOL_128GB_BYTES,
        CTX, LLAMA31_8B_KV_HEADS, LLAMA31_8B_HEAD_DIM,
    )
    if full.gpu_layers != 32 or full.cpu_weight_bytes != 0:
        raise Error("A-104 pool-sized budget must place all 32 on GPU")
    if full.kv_cpu_bytes != 0 or full.kv_gpu_bytes != 536870912:
        raise Error("A-104 full placement KV must be all GPU")
    print("A-104 split edges: PASS")


def test_big_model_pool_gate() raises:
    print("--- Testing A-104 pool gate (A-049 class) ---")
    var layers = llama31_8b_q4km_layer_bytes()
    var small_pool = plan_layer_split(
        layers, LLAMA31_8B_EMBED_BYTES, LLAMA31_8B_OUTPUT_BYTES,
        POOL_128GB_BYTES, 4000000000,
        CTX, LLAMA31_8B_KV_HEADS, LLAMA31_8B_HEAD_DIM,
    )
    if small_pool.fits_pool:
        raise Error("A-104 a 4 GB pool must refuse the 8B accounting")
    # Exact boundary: weights + KV exactly equal to the pool fits.
    var exact = 4912898304 + 536870912
    var edge = plan_layer_split(
        layers, LLAMA31_8B_EMBED_BYTES, LLAMA31_8B_OUTPUT_BYTES, 0, exact,
        CTX, LLAMA31_8B_KV_HEADS, LLAMA31_8B_HEAD_DIM,
    )
    if not edge.fits_pool:
        raise Error("A-104 exact-fit accounting must fit its pool")
    if edge.total_accounted_bytes() != exact:
        raise Error("A-104 accounted total must equal weights + KV")
    print("A-104 pool gate: PASS")


def test_big_model_pressure_budget() raises:
    print("--- Testing A-104 A-076 pressure budget + monotonicity ---")
    var gib = 1024 * 1024 * 1024
    if budget_from_pressure(4 * gib, 10 * gib, 1 * gib, 0) != 4 * gib:
        raise Error("A-104 pressure budget must honour the cap")
    if budget_from_pressure(4 * gib, 3 * gib, 1 * gib, 0) != 2 * gib:
        raise Error("A-104 pressure budget must honour available-reserve")
    if budget_from_pressure(4 * gib, -1, 1 * gib, 0) != 4 * gib:
        raise Error("A-104 unknown availability must leave the cap alone")
    if budget_from_pressure(4 * gib, 10 * gib, 1 * gib, 1 * gib) != 3 * gib:
        raise Error("A-104 pressure budget must subtract live GPU bytes")
    var layers = llama31_8b_q4km_layer_bytes()
    var prev = -1
    var budgets = List[Int]()
    budgets.append(0)
    budgets.append(1 * gib)
    budgets.append(2 * gib)
    budgets.append(3 * gib)
    budgets.append(4 * gib)
    budgets.append(8 * gib)
    for i in range(len(budgets)):
        var plan = plan_layer_split(
            layers, LLAMA31_8B_EMBED_BYTES, LLAMA31_8B_OUTPUT_BYTES,
            budgets[i], POOL_128GB_BYTES,
            CTX, LLAMA31_8B_KV_HEADS, LLAMA31_8B_HEAD_DIM,
        )
        if plan.gpu_layers < prev:
            raise Error("A-104 GPU layers must be monotone in the budget")
        prev = plan.gpu_layers
    print("A-104 pressure budget: PASS")
