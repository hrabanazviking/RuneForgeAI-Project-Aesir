# tests/c3_h053_sampler.mojo
# H053-H057 — sampler check (TEST-ONLY driver, not shipped).
#
# Verifies greedy argmax, temperature determinism, top-k/top-p masking
# (only allowed tokens ever sampled over 2000 draws), repetition penalty
# direction, and seed determinism.
# Usage: c3_h053_sampler   (run from the repo root)

from armvegr.sampler import Sampler, softmax


def main() raises:
    var logits: List[Float32] = [1.0, 2.0, 3.0, 0.5, -1.0, 2.5, 0.0, 1.5, -0.5, 2.2]
    # H053 greedy: argmax is index 2 (3.0).
    var s = Sampler(12345)
    if s.greedy(logits) != 2:
        print("H053-FAIL greedy")
        return
    print("H053 greedy: PASS (argmax=2)")

    # H054 temperature: temp<=0 -> greedy; determinism with fixed seed.
    var s2 = Sampler(999)
    var a = s2.sample(logits, Float32(1.0), 0, Float32(1.0), List[Int](), Float32(1.0))
    var s3 = Sampler(999)
    var b = s3.sample(logits, Float32(1.0), 0, Float32(1.0), List[Int](), Float32(1.0))
    if a != b:
        print("H054-FAIL determinism")
        return
    var s4 = Sampler(1)
    if s4.sample(logits, Float32(0.0), 0, Float32(1.0), List[Int](), Float32(1.0)) != 2:
        print("H054-FAIL temp=0 greedy")
        return
    print("H054 temperature: PASS (deterministic, temp=0->greedy)")

    # H055 top-k=3: only indices {2, 5, 9} (values 3.0, 2.5, 2.2) ever sampled.
    var s5 = Sampler(777)
    var seen = List[Bool]()
    for _ in range(10):
        seen.append(False)
    for _ in range(2000):
        var t = s5.sample(logits, Float32(1.0), 3, Float32(1.0), List[Int](), Float32(1.0))
        seen[t] = True
    if not (seen[2] and seen[5] and seen[9]):
        print("H055-FAIL top-k missing")
        return
    for i in range(10):
        if seen[i] and i != 2 and i != 5 and i != 9:
            print("H055-FAIL top-k leaked", i)
            return
    print("H055 top-k: PASS (only {2,5,9} sampled in 2000 draws)")

    # H056 top-p=0.5: nucleus should be a subset; verify no leak outside top few.
    # Compute expected nucleus via softmax.
    var probs = softmax(logits)
    # Find smallest set with cumsum >= 0.5 (sorted desc).
    var order = List[Int]()
    for i in range(10):
        order.append(i)
    for i in range(10):
        for j in range(i + 1, 10):
            if probs[order[j]] > probs[order[i]]:
                var tmp = order[i]
                order[i] = order[j]
                order[j] = tmp
    var cumsum = Float32(0.0)
    var nucleus = List[Bool]()
    for _ in range(10):
        nucleus.append(False)
    for r in range(10):
        nucleus[order[r]] = True
        cumsum += probs[order[r]]
        if cumsum >= Float32(0.5):
            break
    var s6 = Sampler(4242)
    var seen6 = List[Bool]()
    for _ in range(10):
        seen6.append(False)
    for _ in range(2000):
        var t2 = s6.sample(logits, Float32(1.0), 0, Float32(0.5), List[Int](), Float32(1.0))
        seen6[t2] = True
    for i in range(10):
        if seen6[i] and not nucleus[i]:
            print("H056-FAIL top-p leaked", i)
            return
    print("H056 top-p: PASS (no leak outside nucleus in 2000 draws)")

    # H057 repetition penalty: penalized token's logit decreases.
    var hist: List[Int] = [2, 5]
    var s7 = Sampler(0)
    var pen = s7.repetition_penalty(logits, hist, Float32(1.5))
    # logits[2]=3.0 >0 -> 3.0/1.5=2.0; logits[5]=2.5 -> 2.5/1.5.
    if abs(pen[2] - Float32(2.0)) > Float32(1e-5):
        print("H057-FAIL penalty", pen[2])
        return
    if abs(pen[5] - Float32(2.5) / Float32(1.5)) > Float32(1e-5):
        print("H057-FAIL penalty5")
        return
    # Negative logit: -1.0 * 1.5 = -1.5 (more negative).
    var hist2: List[Int] = [4]
    var pen2 = s7.repetition_penalty(logits, hist2, Float32(1.5))
    if abs(pen2[4] - Float32(-1.5)) > Float32(1e-5):
        print("H057-FAIL neg penalty")
        return
    print("H057 repetition penalty: PASS")

    print("H053-H057-ALL-PASS")
