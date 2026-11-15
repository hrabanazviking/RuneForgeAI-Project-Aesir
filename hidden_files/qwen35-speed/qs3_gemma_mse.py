#!/usr/bin/env python3
"""Weight-space A/B: total MSE of two F16 dequantized weight sets
against the source's dequantized weight set, tensor by tensor.
All three files share the source directory (dequantize_model_qc_5
preserves names/shapes/order); tensors are read as float16."""
import struct, sys
import numpy as np

def tensors(path):
    with open(path, 'rb') as f:
        data = f.read()
    magic, ver, nt, nkv = struct.unpack_from('<4sIQQ', data, 0)
    off = 24
    def rd_str(o):
        n, = struct.unpack_from('<Q', data, o)
        return data[o+8:o+8+n].decode(), o+8+n
    for _ in range(nkv):
        _, o = rd_str(off); off = o
        vt, = struct.unpack_from('<I', data, off); off += 4
        sizes = {0:1,1:1,2:2,3:2,4:4,5:4,6:4,7:1,10:8,11:8,12:8}
        if vt == 8:
            _, off = rd_str(off)
        elif vt == 9:
            et, cnt = struct.unpack_from('<IQ', data, off); off += 12
            off += cnt * sizes[et]
        else:
            off += sizes[vt]
    infos = []
    for _ in range(nt):
        name, o = rd_str(off); off = o
        nd, = struct.unpack_from('<I', data, off); off += 4
        dims = struct.unpack_from('<'+'Q'*nd, data, off); off += 8*nd
        gt, rel = struct.unpack_from('<IQ', data, off); off += 12
        infos.append((name, dims, gt, rel))
    data_off = (off + 31) // 32 * 32
    out = {}
    for name, dims, gt, rel in infos:
        n = int(np.prod(dims))
        assert gt == 0, (name, gt)
        arr = np.frombuffer(data, dtype=np.float16, count=n, offset=data_off+rel)
        out[name] = arr.astype(np.float64)
    return out

src = tensors(sys.argv[1])
for label, path in [('legacy', sys.argv[2]), ('searched', sys.argv[3])]:
    cand = tensors(path)
    tot_se, tot_n, worst = 0.0, 0, ('', 0.0)
    for name, ref in src.items():
        d = cand[name] - ref
        se = float(np.dot(d, d)); tot_se += se; tot_n += d.size
        mse = se / d.size
        if mse > worst[1]: worst = (name, mse)
    print(f"{label}: total_MSE={tot_se/tot_n:.6e} elements={tot_n} worst_tensor={worst[0]} mse={worst[1]:.6e}")
