# tests/c3_h051_kvcheck.mojo
# H051 — KV cache vs recompute (TEST-ONLY driver, not shipped).
#
# 256 decode steps. Cached path: FP16 K/V appended to armvegr/kv_cache.mojo.
# Recompute path: FP32 K/V kept in full lists. At each step, single-head
# causal attention is computed both ways; max abs err over all steps must be
# <= 1e-3 (FP16 quantization noise only).
# Usage: c3_h051_kvcheck   (run from the repo root)

from armvegr.kv_cache import KVCache
from std.math import exp


def _lcg(mut state: Int) -> Int:
    state = (state * 6364136223846793005 + 1442695040888963407) & 0x7FFFFFFFFFFFFFFF
    return state


def main() raises:
    var n_layers = 2
    var n_heads = 4
    var head_dim = 32
    var steps = 256
    var cache = KVCache(n_layers, n_heads, head_dim, steps)
    print("H051 byte_count:", cache.byte_count(), "allocated:", cache.allocated_bytes())
    if cache.byte_count() != cache.allocated_bytes():
        print("H051-FAIL byte count mismatch")
        return

    var state = 0x12345678
    # FP32 reference K/V per layer: [step][head*dim]
    var ref_k = List[List[List[Float32]]]()
    var ref_v = List[List[List[Float32]]]()
    for _ in range(n_layers):
        ref_k.append(List[List[Float32]]())
        ref_v.append(List[List[Float32]]())

    var max_err = Float32(0.0)
    var w = n_heads * head_dim
    for t in range(steps):
        var pos = cache.prepare_position()
        if pos != t:
            print("H051-FAIL pos")
            return
        for layer in range(n_layers):
            # Random FP32 k/v, quantized to FP16 for the cache.
            var kf32 = List[Float32]()
            var vf32 = List[Float32]()
            var k16 = List[Float16]()
            var v16 = List[Float16]()
            for i in range(w):
                state = _lcg(state)
                var r = Float32(Int(state & 0xFFFF)) / Float32(65535.0) - Float32(0.5)
                kf32.append(r)
                k16.append(Float16(r))
                state = _lcg(state)
                var r2 = Float32(Int(state & 0xFFFF)) / Float32(65535.0) - Float32(0.5)
                vf32.append(r2)
                v16.append(Float16(r2))
            # pos already obtained above; write at pos.
            cache.write_kv(layer, pos, k16, v16)
            ref_k[layer].append(kf32.copy())
            ref_v[layer].append(vf32.copy())
        cache.commit_position()

        # Attention at step t, layer 0, head 0 (cached vs recompute).
        var layer = 0
        var q = List[Float32]()
        for i in range(head_dim):
            state = _lcg(state)
            q.append(Float32(Int(state & 0xFFFF)) / Float32(65535.0) - Float32(0.5))
        # Cached.
        var out_c = List[Float32]()
        for i in range(head_dim):
            out_c.append(Float32(0.0))
        var scores_c = List[Float32]()
        for s in range(t + 1):
            var kk = cache.read_k(layer, s)
            var dot = Float32(0.0)
            for i in range(head_dim):
                dot += q[i] * Float32(kk[i])
            scores_c.append(dot / Float32(5.656854249492381))  # sqrt(32)
        var mx = Float32(-1e30)
        for s in range(t + 1):
            if scores_c[s] > mx:
                mx = scores_c[s]
        var denom = Float32(0.0)
        for s in range(t + 1):
            # exp via Taylor? Use builtin exp on Float32.
            var e = exp(scores_c[s] - mx)
            scores_c[s] = e
            denom += e
        for s in range(t + 1):
            var wt = scores_c[s] / denom
            var vv = cache.read_v(layer, s)
            for i in range(head_dim):
                out_c[i] += wt * Float32(vv[i])
        # Recompute.
        var out_r = List[Float32]()
        for i in range(head_dim):
            out_r.append(Float32(0.0))
        var scores_r = List[Float32]()
        for s in range(t + 1):
            var kr = ref_k[layer][s].copy()
            var dot2 = Float32(0.0)
            for i in range(head_dim):
                dot2 += q[i] * kr[i]
            scores_r.append(dot2 / Float32(5.656854249492381))
        var mx2 = Float32(-1e30)
        for s in range(t + 1):
            if scores_r[s] > mx2:
                mx2 = scores_r[s]
        var denom2 = Float32(0.0)
        for s in range(t + 1):
            var e2 = exp(scores_r[s] - mx2)
            scores_r[s] = e2
            denom2 += e2
        for s in range(t + 1):
            var wt2 = scores_r[s] / denom2
            var vr = ref_v[layer][s].copy()
            for i in range(head_dim):
                out_r[i] += wt2 * vr[i]
        for i in range(head_dim):
            var e = out_c[i] - out_r[i]
            if e < 0:
                e = -e
            if e > max_err:
                max_err = e

    print("H051 steps:", steps, "max abs err:", String(max_err))
    if max_err <= Float32(0.001):
        print("H051-ALL-PASS")
    else:
        print("H051-FAIL")
