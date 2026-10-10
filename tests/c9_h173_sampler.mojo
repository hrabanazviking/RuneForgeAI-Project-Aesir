# tests/c9_h173_sampler.mojo
# H173 — fused sampler token-identity test (TEST-ONLY driver, not shipped).
#
# Asserts that Sampler.sample_fast() (fused zero-allocation path) and
# Sampler.sample_fast_ptr() produce BIT-IDENTICAL tokens to the classic
# Sampler.sample() for identical inputs and RNG seeds, across the
# production config and edge cases. A faster wrong sampler is a failure.
# Usage: c9_h173_sampler   (run from the repo root; runs on Mimir)

from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from std.origin import MutUntrackedOrigin

from armvegr.sampler import Sampler


def _lcg_next(mut st: UInt64) -> UInt64:
    st += 0x9E3779B97F4A7C15
    var z = st
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9
    z = (z ^ (z >> 27)) * 0x94D049BB133111EB
    return z ^ (z >> 31)


def _rand_logits(n: Int, mut st: UInt64, lo: Float32, hi: Float32) -> List[Float32]:
    var out = List[Float32]()
    for _ in range(n):
        var u = Float32(_lcg_next(st) >> 40) / Float32(16777216.0)
        out.append(lo + (hi - lo) * u)
    return out.copy()


def _rand_hist(n: Int, vocab: Int, mut st: UInt64) -> List[Int]:
    var out = List[Int]()
    for _ in range(n):
        out.append(Int(_lcg_next(st) % UInt64(vocab)))
    return out.copy()


def main() raises:
    var fails = 0

    # Test 1: small-logit identity across a parameter grid (200 trials).
    var st = UInt64(20261010)
    for trial in range(200):
        var n = 8 + Int(_lcg_next(st) % 120)
        var logits = _rand_logits(n, st, Float32(-5.0), Float32(5.0))
        var temp = Float32(0.5) + Float32(_lcg_next(st) % 100) / Float32(100.0)
        var top_k = Int(_lcg_next(st) % 12)
        var top_p = Float32(0.5) + Float32(_lcg_next(st) % 49) / Float32(100.0)
        var hn = Int(_lcg_next(st) % 20)
        var hist = _rand_hist(hn, n, st)
        var pen = Float32(1.0) + Float32(_lcg_next(st) % 50) / Float32(100.0)
        var seed = _lcg_next(st)
        var a = Sampler(seed)
        var ta = a.sample(logits, temp, top_k, top_p, hist, pen)
        var b = Sampler(seed)
        var tb = b.sample_fast(logits, temp, top_k, top_p, hist, pen)
        if ta != tb:
            print("T1-FAIL trial " + String(trial) + ": classic=" + String(ta) + " fused=" + String(tb))
            fails += 1
    if fails == 0:
        print("T1 small-logit grid (200 trials): PASS")
    else:
        print("T1 FAILURES: " + String(fails))
        return

    # Test 2: production shape (n=32000) + production config, 10 seeds.
    # This exercises the O(n^2)->partial-selection top-p change.
    var st2 = UInt64(777)
    for trial in range(10):
        var n = 32000
        var logits = _rand_logits(n, st2, Float32(-8.0), Float32(8.0))
        var hist = _rand_hist(600, n, st2)
        var seed = _lcg_next(st2)
        var a = Sampler(seed)
        var ta = a.sample(
            logits, Float32(0.7), 40, Float32(0.95), hist, Float32(1.1)
        )
        var b = Sampler(seed)
        var tb = b.sample_fast(
            logits, Float32(0.7), 40, Float32(0.95), hist, Float32(1.1)
        )
        if ta != tb:
            print("T2-FAIL trial " + String(trial) + ": classic=" + String(ta) + " fused=" + String(tb))
            fails += 1
    if fails == 0:
        print("T2 production shape/config (10 trials, n=32000): PASS")
    else:
        print("T2 FAILURES: " + String(fails))
        return

    # Test 3: sample_fast_ptr identity vs sample_fast (List API).
    var st3 = UInt64(4242)
    for trial in range(50):
        var n = 64 + Int(_lcg_next(st3) % 256)
        var logits = _rand_logits(n, st3, Float32(-6.0), Float32(6.0))
        var hn = Int(_lcg_next(st3) % 30)
        var hist = _rand_hist(hn, n, st3)
        var seed = _lcg_next(st3)
        var lp = unsafe_alloc[Float32](n)
        var hp = unsafe_alloc[Int](hn if hn > 0 else 1)
        for i in range(n):
            lp.unsafe_offset(i).unsafe_store(logits[i])
        for i in range(hn):
            hp.unsafe_offset(i).unsafe_store(hist[i])
        var b = Sampler(seed)
        var tb = b.sample_fast(
            logits, Float32(0.7), 40, Float32(0.95), hist, Float32(1.1)
        )
        var c = Sampler(seed)
        var tc = c.sample_fast_ptr(
            lp, n, Float32(0.7), 40, Float32(0.95), hp, hn, Float32(1.1)
        )
        lp.unsafe_free()
        hp.unsafe_free()
        if tb != tc:
            print("T3-FAIL trial " + String(trial))
            fails += 1
    if fails == 0:
        print("T3 sample_fast_ptr identity (50 trials): PASS")
    else:
        print("T3 FAILURES: " + String(fails))
        return

    # Test 4: edge cases — greedy, top_p=1.0 (skip), top_k>=n, no penalty.
    var st4 = UInt64(99)
    var logits4 = _rand_logits(128, st4, Float32(-4.0), Float32(4.0))
    var hist4 = _rand_hist(10, 128, st4)
    # 4a: temp=0 -> greedy
    var g1 = Sampler(5)
    var g2 = Sampler(5)
    if g1.sample(logits4, Float32(0.0), 40, Float32(0.95), hist4, Float32(1.1)) != g2.sample_fast(
        logits4, Float32(0.0), 40, Float32(0.95), hist4, Float32(1.1)
    ):
        print("T4a-FAIL greedy")
        return
    # 4b: top_p=1.0 (top-p skipped), top_k=0 (skipped)
    var p1 = Sampler(6)
    var p2 = Sampler(6)
    if p1.sample(logits4, Float32(1.0), 0, Float32(1.0), hist4, Float32(1.0)) != p2.sample_fast(
        logits4, Float32(1.0), 0, Float32(1.0), hist4, Float32(1.0)
    ):
        print("T4b-FAIL no top-k/top-p")
        return
    # 4c: top_k >= n (no-op), top_p active without preceding top-k
    var q1 = Sampler(7)
    var q2 = Sampler(7)
    if q1.sample(logits4, Float32(0.8), 500, Float32(0.9), hist4, Float32(1.0)) != q2.sample_fast(
        logits4, Float32(0.8), 500, Float32(0.9), hist4, Float32(1.0)
    ):
        print("T4c-FAIL top_k>=n")
        return
    # 4d: empty history
    var e1 = Sampler(8)
    var e2 = Sampler(8)
    if e1.sample(logits4, Float32(0.7), 40, Float32(0.95), List[Int](), Float32(1.2)) != e2.sample_fast(
        logits4, Float32(0.7), 40, Float32(0.95), List[Int](), Float32(1.2)
    ):
        print("T4d-FAIL empty history")
        return
    print("T4 edge cases (greedy/no-topk/no-topp/empty-hist): PASS")

    print("H173-SAMPLER-IDENTITY-ALL-PASS")
