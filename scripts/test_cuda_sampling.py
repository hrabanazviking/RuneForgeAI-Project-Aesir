"""Independent stdlib CPU probability oracle for the physical Mojo CUDA probe.

Usage: python scripts/test_cuda_sampling.py --binary .aesir/test-cuda-sampling
The production engine does not import or execute this test-only sampler.
"""
import argparse
from collections import Counter, deque
import math
import struct
import subprocess


def f32(value):
    try:
        return struct.unpack("f", struct.pack("f", value))[0]
    except OverflowError:
        return math.copysign(math.inf, value)


def settings(case):
    vocab, temp, k, p, minimum, penalty, window, seed = 4099, .7, 17, .9, .04, 1.2, 7, 42
    if case == 0:
        vocab, temp, k, p, minimum, penalty, window = 257, 0, 40, .95, 0, 1, 64
    elif case == 2:
        vocab, temp, k, p, minimum, penalty, seed = 19, 1, 40, 1, 0, 1, 0
    elif case == 3:
        vocab, temp, k, p, minimum, penalty, seed = 257, .00001, 256, 1, 0, 1, 2**64-1
    elif case == 4:
        temp, p, minimum, penalty = 0, 1, 0, 1.5
    elif case == 5:
        temp, k, p, minimum, penalty = 1, 1, 1, 0, 1
    elif case == 6:
        vocab = 270
    elif case == 7:
        vocab, temp, k, p, minimum, penalty, seed = 8201, 2, 256, 1, 0, .8, 12345
    elif case == 8:
        minimum = 1
    elif case == 13:
        temp, k, p, minimum, penalty, window = 0, 40, .95, 0, 1, 64
    return vocab, f32(temp), k, f32(p), f32(minimum), f32(penalty), window, seed


def reference(case):
    vocab, temp, k, p, minimum, penalty, window, seed = settings(case)
    history = deque(((i * 7) % min(vocab, 19) for i in range(11)), maxlen=window)
    logits = [(i * 37 + 11) % 101 / 8 - 50 / 8 for i in range(vocab)]
    if case == 2:
        logits = [2.] * vocab
    elif case == 3:
        logits = [f32(3e38 if i % 2 else -3e38) for i in range(vocab)]
    elif case == 9:
        logits = [x - 100 for x in logits]
    for draw in range(32):
        if case in (10, 11, 12, 13):
            yield -1
            continue
        counts = Counter(history)
        adjusted = [f32(x * penalty if x < 0 else x / penalty) if counts[i] else x
                    for i, x in enumerate(logits)]
        candidates = sorted((i for i in range(vocab) if case != 6 or i < 257 or i in (260, 269)),
                            key=lambda i: (-adjusted[i], i))[:k if temp else 1]
        if temp == 0:
            chosen = candidates[0]
        else:
            weights = [f32(math.exp(f32((adjusted[i] - adjusted[candidates[0]]) / temp))) for i in candidates]
            filtered = [(i, w) for i, w in zip(candidates, weights) if w >= minimum]
            total = 0.
            for _, weight in filtered:
                total = f32(total + weight)
            nucleus, total_n = [], 0.
            for i, weight in filtered:
                nucleus.append((i, weight))
                total_n = f32(total_n + weight)
                if total_n >= f32(p * total):
                    break
            mask = 2**64 - 1
            random = (seed + (draw + 1) * 0x9E3779B97F4A7C15) & mask
            random = ((random ^ (random >> 30)) * 0xBF58476D1CE4E5B9) & mask
            random = ((random ^ (random >> 27)) * 0x94D049BB133111EB) & mask
            random ^= random >> 31
            target = f32((random >> 40) / 2**24 * total_n)
            cumulative = 0.
            chosen = nucleus[-1][0]
            for i, weight in nucleus:
                cumulative = f32(cumulative + weight)
                if target < cumulative:
                    chosen = i
                    break
        history.append(chosen)
        yield chosen


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True)
    args = parser.parse_args()
    result = subprocess.run([args.binary], text=True, capture_output=True, timeout=180)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    actual = {}
    for line in result.stdout.splitlines():
        if line.startswith("SAMPLE "):
            case, epoch, draw, token = map(int, line.split()[1:])
            key = case, epoch, draw
            assert key not in actual, ("duplicate", key)
            actual[key] = token
    expected = {(case, epoch, draw): token for case in range(14) for epoch in range(2)
                for draw, token in enumerate(reference(case))}
    assert actual.keys() == expected.keys(), "Missing or extra physical sampler observations"
    for key, token in expected.items():
        assert actual[key] == token, (key, "CUDA", actual[key], "independent oracle", token)
    print(f"PASS: {len(actual)} physical CUDA selections match independent CPU oracle; 14 cases, clear/replay, nonfinite rejection")


if __name__ == "__main__":
    main()
