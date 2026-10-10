#!/usr/bin/env python3
"""Compare pre-change attention capture with independent causal/full oracles."""
import math
import re
import struct
from pathlib import Path

RAW = Path(__file__).with_name('raw-output.txt').read_text().splitlines()

def f16(x):
    return struct.unpack('<e', struct.pack('<e', x))[0]

def vals(name, stops):
    start = RAW.index(name) + 1
    end = next((i for i in range(start, len(RAW)) if RAW[i] in stops), len(RAW))
    return [float(v) for v in RAW[start:end] if re.fullmatch(r'-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?', v)]

def oracle(q, k, v, causal):
    rows, cols, d = 3, 4, 2
    scale = 1 / math.sqrt(d)
    out = []
    for i in range(rows):
        for h in range(cols // d):
            scores = []
            stop = i + 1 if causal else rows
            for j in range(stop):
                dot = sum(q[i*cols+h*d+x] * k[j*cols+h*d+x] for x in range(d))
                scores.append(dot * scale)
            top = max(scores)
            probs = [math.exp(x-top) for x in scores]
            denom = sum(probs)
            for x in range(d):
                out.append(f16(sum(p * v[j*cols+h*d+x] for j,p in enumerate(probs)) / denom))
    return out

q = vals('Q', {'K'})
k = vals('K', {'V'})
v = vals('V', {'OUT'})
out = vals('OUT', set())
causal = oracle(q,k,v,True)
full = oracle(q,k,v,False)
for label, ref in [('causal prefix', causal), ('all rows/full attention', full)]:
    diffs = [abs(a-b) for a,b in zip(out,ref)]
    print(f'{label}: max_abs_error={max(diffs):.8g}; differing F16 outputs={sum(a != b for a,b in zip(out,ref))}/{len(out)}')
print('The row-0 outputs must be unchanged if only future V rows are perturbed under the causal contract.')
