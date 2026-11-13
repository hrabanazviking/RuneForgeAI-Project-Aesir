"""HIP attention + norms (A-084): RMSNorm, RoPE and decode
attention executed on the Radeon 8060S (gfx1151) by Mojo-native
HIP kernels through the A-010-A-012 gate, judged per op against
sequential Float32 CPU oracles in this file implementing the
identical math as shaders/rmsnorm.comp, rope.comp and
attention_decode.comp (serial path) / core/compute.mojo.
Tolerances are small accumulation bounds (both sides Float32,
same order for RMSNorm/attention dots; RoPE differs only in
transcendental evaluation order). Device evidence (law 6): per-
op shim dispatch counters advance by exactly the dispatches."""
from std.math import cos, exp, sin, sqrt
from core.hip_attention_norms import HipAttnNorms


struct _Lcg:
    var state: UInt64
    def __init__(out self, seed: UInt64):
        self.state = seed
    def next(mut self) -> UInt64:
        self.state = self.state * 6364136223846793005 + 1442695040888963407
        return self.state >> 11
    def unit(mut self) -> Float32:
        return Float32(self.next() & 0xFFFFFF) / Float32(16777216.0)
    def val(mut self) -> Float32:
        return self.unit() * Float32(3.0) - Float32(1.5)


def _abs(v: Float32) -> Float32:
    return -v if v < 0 else v


def _rms_oracle(x: List[Float32], g: List[Float32], rows: Int, n: Int, eps: Float32) -> List[Float32]:
    var out = List[Float32](capacity=rows * n)
    for r in range(rows):
        var ss: Float32 = 0.0
        for i in range(n):
            ss += x[r * n + i] * x[r * n + i]
        var sc = Float32(1.0) / sqrt(ss / Float32(n) + eps)
        for i in range(n):
            out.append(x[r * n + i] * sc * g[i])
    return out^


def _rope_oracle(x: List[Float32], head_dim: Int, rows: Int, position: Int, base: Float32) -> List[Float32]:
    var out = List[Float32](capacity=rows * head_dim)
    for i in range(rows * head_dim):
        out.append(x[i])
    var half = head_dim // 2
    for r in range(rows):
        for i in range(half):
            var theta = Float32(position) * (base ** (Float32(-2.0) * Float32(i) / Float32(head_dim)))
            var c = cos(theta)
            var s = sin(theta)
            var off = r * head_dim + i
            var a = x[off]
            var b = x[off + half]
            out[off] = a * c - b * s
            out[off + half] = b * c + a * s
    return out^


def _attn_oracle(q: List[Float32], k: List[Float32], v: List[Float32], head_dim: Int, kv_len: Int, num_heads: Int, kv_per_query: Int) -> List[Float32]:
    var nkv = num_heads // kv_per_query
    _ = nkv
    var out = List[Float32](capacity=num_heads * head_dim)
    var scale = Float32(1.0) / sqrt(Float32(head_dim))
    for h in range(num_heads):
        var kvh = h // kv_per_query
        var mx = Float32(-3.4028235e38)
        var scores = List[Float32](capacity=kv_len)
        for t in range(kv_len):
            var sc: Float32 = 0.0
            var kb = (kvh * kv_len + t) * head_dim
            for d in range(head_dim):
                sc += q[h * head_dim + d] * k[kb + d]
            scores.append(sc * scale)
            if scores[t] > mx:
                mx = scores[t]
        var denom: Float32 = 0.0
        var ws = List[Float32](capacity=kv_len)
        for t in range(kv_len):
            var w = exp(scores[t] - mx)
            ws.append(w)
            denom += w
        for lane in range(head_dim):
            var acc: Float32 = 0.0
            for t in range(kv_len):
                acc += ws[t] * v[(kvh * kv_len + t) * head_dim + lane]
            out.append(acc / denom)
    return out^


def _fill(mut lcg: _Lcg, count: Int) -> List[Float32]:
    var out = List[Float32](capacity=count)
    for _ in range(count):
        out.append(lcg.val())
    return out^


def _gate_absent_ok() -> Bool:
    if HipAttnNorms.gate_ok():
        return False
    var x = List[Float32](capacity=4)
    for _ in range(4):
        x.append(Float32(1.0))
    var g = List[Float32](capacity=4)
    for _ in range(4):
        g.append(Float32(1.0))
    var rejected = False
    try:
        _ = HipAttnNorms.rmsnorm(x, g, 1, 4, Float32(1e-5))
    except:
        rejected = True
    return rejected


def test_hip_attn_norms_rmsnorm_oracle() raises:
    print("--- Testing HIP RMSNorm oracle parity (A-084) ---")
    if not HipAttnNorms.gate_ok():
        if not _gate_absent_ok():
            raise Error("HIP gate failed but rmsnorm succeeded (fabricated)")
        print("HIP UNAVAILABLE: RMSNorm fail-closed: PASS (honest-absent)")
        return
    var lcg = _Lcg(0xA084)
    var worst: Float32 = 0.0
    var cfgs_r = [1, 3, 8]
    var cfgs_n = [64, 128, 37]
    for c in range(3):
        var rows = cfgs_r[c]
        var n = cfgs_n[c]
        var x = _fill(lcg, rows * n)
        var g = _fill(lcg, n)
        var got = HipAttnNorms.rmsnorm(x, g, rows, n, Float32(1e-5))
        var want = _rms_oracle(x, g, rows, n, Float32(1e-5))
        for i in range(rows * n):
            var d = _abs(got[i] - want[i])
            if d > worst:
                worst = d
        print("A084_RMS rows=", rows, " n=", n, " max_abs_so_far=", worst)
    if worst > Float32(0.0001):
        raise Error("HIP RMSNorm parity exceeded bound: " + String(worst))
    print("HIP RMSNorm oracle parity (worst max_abs=", worst, "): PASS")


def test_hip_attn_norms_rope_oracle() raises:
    print("--- Testing HIP RoPE oracle parity (A-084) ---")
    if not HipAttnNorms.gate_ok():
        print("HIP UNAVAILABLE: RoPE case not run (honest-absent)")
        return
    var lcg = _Lcg(0xA085)
    var worst: Float32 = 0.0
    var dims = [32, 64, 128]
    var poss = [0, 1, 17]
    for c in range(3):
        var hd = dims[c]
        var rows = 4
        var x = _fill(lcg, rows * hd)
        var got = HipAttnNorms.rope(x, hd, rows, poss[c], Float32(10000.0))
        var want = _rope_oracle(x, hd, rows, poss[c], Float32(10000.0))
        for i in range(rows * hd):
            var d = _abs(got[i] - want[i])
            if d > worst:
                worst = d
        print("A084_ROPE head_dim=", hd, " pos=", poss[c], " max_abs_so_far=", worst)
    if worst > Float32(0.0001):
        raise Error("HIP RoPE parity exceeded bound: " + String(worst))
    print("HIP RoPE oracle parity (worst max_abs=", worst, "): PASS")


def test_hip_attn_norms_attention_oracle() raises:
    print("--- Testing HIP decode attention oracle parity (A-084) ---")
    if not HipAttnNorms.gate_ok():
        print("HIP UNAVAILABLE: attention case not run (honest-absent)")
        return
    var lcg = _Lcg(0xA086)
    var worst: Float32 = 0.0
    # (head_dim, kv_len, num_heads, kv_per_query): MHA, GQA x2, GQA x4
    var hd_l = [32, 64, 32]
    var kl_l = [16, 33, 8]
    var nh_l = [4, 8, 8]
    var kp_l = [1, 2, 4]
    for c in range(3):
        var hd = hd_l[c]
        var kl = kl_l[c]
        var nh = nh_l[c]
        var kp = kp_l[c]
        var nkv = nh // kp
        var q = _fill(lcg, nh * hd)
        var k = _fill(lcg, nkv * kl * hd)
        var v = _fill(lcg, nkv * kl * hd)
        var got = HipAttnNorms.decode_attention(q, k, v, hd, kl, nh, kp)
        var want = _attn_oracle(q, k, v, hd, kl, nh, kp)
        for i in range(nh * hd):
            var d = _abs(got[i] - want[i])
            if d > worst:
                worst = d
        print("A084_ATTN hd=", hd, " kv_len=", kl, " heads=", nh, " gqa=", kp, " max_abs_so_far=", worst)
    if worst > Float32(0.0001):
        raise Error("HIP attention parity exceeded bound: " + String(worst))
    print("HIP decode attention oracle parity (worst max_abs=", worst, "): PASS")


def test_hip_attn_norms_rejection() raises:
    print("--- Testing HIP attention+norms rejection (A-084) ---")
    var br0 = HipAttnNorms.rmsnorm_dispatch_count()
    var bp0 = HipAttnNorms.rope_dispatch_count()
    var ba0 = HipAttnNorms.attn_dispatch_count()
    var x = List[Float32](capacity=64)
    for _ in range(64):
        x.append(Float32(1.0))
    var g = List[Float32](capacity=64)
    for _ in range(64):
        g.append(Float32(1.0))
    var fails = 0
    try:
        _ = HipAttnNorms.rmsnorm(x, g, 0, 64, Float32(1e-5))
    except:
        fails += 1
    try:
        _ = HipAttnNorms.rmsnorm(x, g, 1, 64, Float32(0.0))
    except:
        fails += 1
    try:
        _ = HipAttnNorms.rmsnorm(x, g, 2, 64, Float32(1e-5))
    except:
        fails += 1
    try:
        _ = HipAttnNorms.rmsnorm(x, g, 1, 64, Float32(1e30) * Float32(1e30))
    except:
        fails += 1
    try:
        _ = HipAttnNorms.rope(x, 64, 1, 0, Float32(1e30) * Float32(1e30))
    except:
        fails += 1
    try:
        _ = HipAttnNorms.rope(x, 63, 1, 0, Float32(10000.0))
    except:
        fails += 1
    try:
        _ = HipAttnNorms.rope(x, 64, 1, -1, Float32(10000.0))
    except:
        fails += 1
    try:
        _ = HipAttnNorms.decode_attention(x, x, x, 32, 2, 3, 2)
    except:
        fails += 1
    try:
        _ = HipAttnNorms.decode_attention(x, x, x, 32, 0, 2, 1)
    except:
        fails += 1
    if fails != 9:
        raise Error("rejection: only " + String(fails) + " of 9 bad shapes raised")
    if HipAttnNorms.rmsnorm_dispatch_count() != br0 or HipAttnNorms.rope_dispatch_count() != bp0 or HipAttnNorms.attn_dispatch_count() != ba0:
        raise Error("rejection: a dispatch counter advanced on a rejected call")
    print("HIP attention+norms rejection (9 bad shapes, counters unmoved): PASS")


def test_hip_attn_norms_dispatch_evidence() raises:
    print("--- Testing HIP attention+norms dispatch evidence (A-084) ---")
    if not HipAttnNorms.gate_ok():
        print("HIP UNAVAILABLE: dispatch evidence not run (honest-absent)")
        return
    var name = HipAttnNorms.device_name()
    if name.byte_length() == 0:
        raise Error("HIP device name empty on a gated device")
    var lcg = _Lcg(0xA087)
    var x = _fill(lcg, 128)
    var g = _fill(lcg, 64)
    var br = HipAttnNorms.rmsnorm_dispatch_count()
    var bp = HipAttnNorms.rope_dispatch_count()
    var ba = HipAttnNorms.attn_dispatch_count()
    _ = HipAttnNorms.rmsnorm(x, g, 2, 64, Float32(1e-5))
    _ = HipAttnNorms.rope(x, 64, 2, 3, Float32(10000.0))
    var q = _fill(lcg, 128)
    var kv = _fill(lcg, 256)
    _ = HipAttnNorms.decode_attention(q, kv, kv, 32, 4, 4, 2)
    var dr = HipAttnNorms.rmsnorm_dispatch_count() - br
    var dp = HipAttnNorms.rope_dispatch_count() - bp
    var da = HipAttnNorms.attn_dispatch_count() - ba
    if dr != 1 or dp != 1 or da != 1:
        raise Error("dispatch counters advanced rms=" + String(dr) + " rope=" + String(dp) + " attn=" + String(da) + " for 1 dispatch each")
    print("HIP attention+norms dispatch evidence (device \"", name, "\", each counter +1): PASS")
