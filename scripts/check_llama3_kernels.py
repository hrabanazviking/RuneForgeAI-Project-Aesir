"""Compare physical native CUDA output with independent vectorized NumPy math.

Input: stdout from inspect_llama3_kernels.mojo. Test-only; never imported by Aesir.
"""
import argparse
import csv
import numpy as np

p = argparse.ArgumentParser(description=__doc__)
p.add_argument("csv")
args = p.parse_args()
base = (np.arange(40000) % 97 - 48) / 16.0
expected = {}
for position in (0, 1, 127, 8191):
    pairs = base[:4096].reshape(32, 64, 2)
    angles = position / np.power(500000.0, np.arange(64) / 64.0)
    rotated = np.stack((pairs[..., 0] * np.cos(angles) - pairs[..., 1] * np.sin(angles),
                        pairs[..., 0] * np.sin(angles) + pairs[..., 1] * np.cos(angles)), axis=-1)
    expected['rope', position] = rotated.ravel()
expected['silu', 0] = base[:14336] / (1 + np.exp(-base[:14336])) * base[16000:30336]
keys, values = [], []
for t in range(7):
    row = ((np.arange(40000) + t * 13) % 97 - 48) / 16.0
    keys.append(row[4096:5120].reshape(8, 128).astype(np.float16).astype(np.float64))
    values.append(row[5120:6144].reshape(8, 128).astype(np.float16).astype(np.float64))
k = np.repeat(np.array(keys), 4, axis=1)
v = np.repeat(np.array(values), 4, axis=1)
q = base[:4096].reshape(32, 128)
scores = np.einsum('hd,thd->ht', q, k) / np.sqrt(128.0)
prob = np.exp(scores - scores.max(axis=1, keepdims=True))
prob /= prob.sum(axis=1, keepdims=True)
expected['attention', 0] = np.einsum('ht,thd->hd', prob, v).ravel()
actual = {key: {} for key in expected}
with open(args.csv, encoding='utf-8') as source:
    for stage, position, index, value in csv.reader(source):
        key = stage, int(position)
        index = int(index)
        if index in actual[key]:
            raise AssertionError('duplicate output')
        actual[key][index] = float(value)
count = 0
for key, values in expected.items():
    if set(actual[key]) != set(range(len(values))):
        raise AssertionError(f'incomplete output: {key}')
    observed = np.array([actual[key][i] for i in range(len(values))])
    np.testing.assert_allclose(observed, values, atol=0.00001, rtol=0.00001)
    print(f'PASS {key}: {len(values)} values; max_absolute_error={np.max(np.abs(observed-values)):.8g}')
    count += len(values)
print(f'PASS: {count} physical CUDA values versus independent NumPy')
