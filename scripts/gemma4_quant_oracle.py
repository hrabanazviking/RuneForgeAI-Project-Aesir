"""Create independent real-weight CUDA matvec expectations using gguf 0.19.0.

Test tooling only. No production model loading or inference imports this script.
Install gguf==0.19.0 and numpy in a test environment, then provide the downloaded
model and an output CSV path. GGUFReader supplies an independent tensor index.
"""
import argparse
import csv
import numpy as np
from gguf import GGUFReader
from gguf.constants import GGMLQuantizationType, GGML_QUANT_SIZES
from gguf.quants import dequantize


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--model', required=True)
    p.add_argument('--output', required=True)
    p.add_argument('--profile', choices=['gemma4', 'llama3'], default='gemma4')
    args = p.parse_args()
    reader = GGUFReader(args.model)
    by_name = {t.name: t for t in reader.tensors}
    names = ['token_embd.weight', 'per_layer_token_embd.weight',
             'per_layer_model_proj.weight', 'blk.0.attn_v.weight',
             'blk.0.inp_gate.weight', 'blk.5.attn_q.weight',
             'blk.41.ffn_down.weight']
    if args.profile == 'llama3':
        names = ['token_embd.weight', 'output.weight', 'blk.0.attn_v.weight',
                 'blk.0.ffn_down.weight', 'blk.5.attn_q.weight',
                 'blk.17.ffn_gate.weight', 'blk.31.ffn_down.weight']
    with open(args.model, 'rb') as model, open(args.output, 'x', newline='', encoding='utf-8') as out:
        writer = csv.writer(out, lineterminator='\n')
        for name in names:
            t = by_name[name]
            width, rows = map(int, t.shape)
            kind = GGMLQuantizationType(t.tensor_type)
            block, size = GGML_QUANT_SIZES[kind]
            row_bytes = width // block * size
            vector = (((np.arange(width, dtype=np.int64) * 7) % 29 - 14) / 16).astype(np.float32)
            for row in sorted({0, 1, 17, rows // 2, rows - 1}):
                model.seek(t.data_offset + row * row_bytes)
                data = model.read(row_bytes)
                if len(data) != row_bytes:
                    raise ValueError('truncated real model')
                weights = dequantize(np.frombuffer(data, dtype=np.uint8).reshape(1, -1), kind).reshape(-1)
                expected = float(np.dot(weights.astype(np.float64), vector.astype(np.float64)))
                writer.writerow([name, row, f'{expected:.9f}'])
                print(f'{name} kind={kind.name} row={row} expected={expected:.9f}')


if __name__ == '__main__':
    main()
