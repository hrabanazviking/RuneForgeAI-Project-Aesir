#!/usr/bin/env python3
"""Compare captured apply_rope output with an independent Python scalar oracle."""
import math
import re
import struct
from pathlib import Path

ROOT = Path(__file__).parent

def f16(x):
    return struct.unpack('<e', struct.pack('<e', x))[0]

def values(lines, label, stop_labels):
    start = lines.index(label) + 1
    end = next((i for i in range(start, len(lines)) if lines[i] in stop_labels), len(lines))
    return [float(v) for v in lines[start:end] if re.fullmatch(r'-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?', v)]

def compare(layout, neox):
    lines = (ROOT / 'raw-output.txt').read_text().splitlines()
    start = lines.index('LAYOUT  ' + layout)
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith('LAYOUT  ')), len(lines))
    block = lines[start:end]
    q_in, k_in = values(block, 'Q_INPUT', {'K_SHAPE 3 4'}), values(block, 'K_INPUT', {'Q_OUTPUT'})
    q_out, k_out = values(block, 'Q_OUTPUT', {'K_OUTPUT'}), values(block, 'K_OUTPUT', set())
    def oracle(inp, rows, cols):
        out = inp[:]
        head_dim, half = 4, 2
        heads = cols // head_dim
        for row in range(rows):
            pos = 5 + row
            for head in range(heads):
                base = row * cols + head * head_dim
                for i in range(half):
                    angle = float(pos) * (10000.0 ** (-float(2*i)/head_dim))
                    c, s = f16(math.cos(angle)), f16(math.sin(angle))
                    i0 = base + (i if neox else 2*i)
                    i1 = i0 + (half if neox else 1)
                    x0, x1 = inp[i0], inp[i1]
                    # Match the kernel's ordered f16 multiply then f16 add/subtract operations.
                    out[i0] = f16(f16(f16(x0*c) - f16(x1*s)))
                    out[i1] = f16(f16(f16(x0*s) + f16(x1*c)))
        return out
    for name, inp, out, rows, cols in [('Q', q_in, q_out, 2, 8), ('K', k_in, k_out, 2, 4)]:
        ref = oracle(inp, rows, cols)
        mismatches = [(i, a, b) for i, (a,b) in enumerate(zip(out,ref)) if f16(a) != f16(b)]
        print(f'{layout} {name}: {len(out)} values; exact f16 mismatches={len(mismatches)}')
        if mismatches:
            print('  first mismatches:', mismatches[:5])

if __name__ == '__main__':
    compare('interleaved', False)
    compare('neox', True)
