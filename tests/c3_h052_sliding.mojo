# tests/c3_h052_sliding.mojo
# H052 — sliding-window eviction (TEST-ONLY driver, not shipped).
#
# max_ctx=512, sink=4. Appends 600 positions; verifies the cache holds
# logical positions [0..3] (sinks) + [92..599] (most recent 508), that
# seq_len == 512, and that OOB access fails closed.
# Usage: c3_h052_sliding   (run from the repo root)

from armvegr.kv_cache import KVCache


def main() raises:
    var n_layers = 2
    var n_heads = 2
    var head_dim = 16
    var max_ctx = 512
    var sink = 4
    var total_appends = 600
    var cache = KVCache(n_layers, n_heads, head_dim, max_ctx)
    cache.enable_sliding_window(sink)
    var w = n_heads * head_dim

    for t in range(total_appends):
        var pos = cache.prepare_position()
        for layer in range(n_layers):
            var k = List[Float16]()
            var v = List[Float16]()
            for i in range(w):
                # Identifiable: logical position t encoded in the data.
                k.append(Float16(Float32(t) + Float32(layer) * Float32(0.01)))
                v.append(Float16(Float32(t) * Float32(2.0) + Float32(layer)))
            cache.write_kv(layer, pos, k, v)
        cache.commit_position()

    if cache.seq_len != max_ctx:
        print("H052-FAIL seq_len", cache.seq_len)
        return

    # Expected logical positions: [0,1,2,3] + [92..599].
    var bad = 0
    for phys in range(max_ctx):
        var expect_logical = phys
        if phys >= sink:
            expect_logical = (total_appends - (max_ctx - sink)) + (phys - sink)
        for layer in range(n_layers):
            var kk = cache.read_k(layer, phys)
            var vv = cache.read_v(layer, phys)
            var ek = Float32(expect_logical) + Float32(layer) * Float32(0.01)
            var ev = Float32(expect_logical) * Float32(2.0) + Float32(layer)
            # Compare in FP32 with tolerance for FP16 quantization.
            if abs(Float32(kk[0]) - ek) > Float32(0.02):
                bad += 1
            if abs(Float32(vv[0]) - ev) > Float32(0.05):
                bad += 1
    print("H052 window check mismatches:", bad)
    if bad > 0:
        print("H052-FAIL")
        return

    # OOB fail-closed: read past seq_len, bad layer, write past max.
    var oob_ok = 0
    try:
        var _a = cache.read_k(0, max_ctx)
    except:
        oob_ok += 1
    try:
        var _b = cache.read_k(99, 0)
    except:
        oob_ok += 1
    try:
        var k = List[Float16](length=w, fill=Float16(0.0))
        var v = List[Float16](length=w, fill=Float16(0.0))
        cache.write_kv(0, max_ctx, k, v)
    except:
        oob_ok += 1
    # Full without eviction must fail closed.
    var c2 = KVCache(1, 1, 8, 4)
    for t in range(4):
        var k = List[Float16](length=8, fill=Float16(1.0))
        var v = List[Float16](length=8, fill=Float16(1.0))
        var p = c2.prepare_position()
        c2.write_kv(0, p, k, v)
        c2.commit_position()
    try:
        var _c = c2.prepare_position()
    except:
        oob_ok += 1
    print("H052 OOB fail-closed:", oob_ok, "/4")
    if oob_ok == 4:
        print("H052-ALL-PASS")
    else:
        print("H052-FAIL")
