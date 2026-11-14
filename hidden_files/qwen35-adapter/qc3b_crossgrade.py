#!/usr/bin/env python3
"""QC-3b cross-grade: teacher-forcing rank + logit gap, RAW token-ID
streams, campaign discipline identical to QC-3a (grade_quantize_qc_3):
record = rank + gap of the COMPARATOR's argmax in the CANDIDATE's
logit row; band = rank <= 2 AND gap_milli < 1000 (rank 0-based);
gap_milli = int(gap * 1000) truncated toward zero, as the Mojo
harness files it. Streams are the QC-3a streams (prompt + Aesir
source greedy 16), so all 157 records line up 1:1 with qc-3-grade.csv.
Usage:
  qc4_crossgrade.py --cand rows.bin --comp rows.bin --label NAME
  qc4_crossgrade.py --cand rows.bin --aesir-csv qc-3-grade.csv --label NAME
Also verifies: candidate argmax stream vs comparator argmax stream
agreement, and (with --aesir-csv) that the CSV true_next column
reproduces the filed token streams exactly."""
import argparse, csv, struct, sys
import numpy as np

def read_rows(path):
    with open(path, 'rb') as f:
        data = f.read()
    nprompts, nvocab = struct.unpack_from('<ii', data, 0)
    off = 8
    prompts = []
    for _ in range(nprompts):
        (nrows,) = struct.unpack_from('<i', data, off); off += 4
        arr = np.frombuffer(data, dtype='<f4', count=nrows * nvocab, offset=off)
        off += 4 * nrows * nvocab
        prompts.append(arr.reshape(nrows, nvocab).astype(np.float64))
    assert off == len(data), (off, len(data))
    return prompts

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--cand', required=True)
    ap.add_argument('--comp')
    ap.add_argument('--aesir-csv')
    ap.add_argument('--streams', default='qc-3b-streams.txt')
    ap.add_argument('--prompts', default='qc-3b-prompts.txt')
    ap.add_argument('--label', required=True)
    a = ap.parse_args()
    streams = [[int(x) for x in ln.split()] for ln in open(a.streams) if ln.strip()]
    plen = [len([int(x) for x in ln.split()]) for ln in open(a.prompts) if ln.strip()]
    cand = read_rows(a.cand)
    comp_argmax = None
    if a.comp:
        comp = read_rows(a.comp)
        comp_argmax = [[int(np.argmax(comp[p][i])) for i in range(len(comp[p]))] for p in range(len(comp))]
    else:
        rows = list(csv.DictReader(open(a.aesir_csv)))
        pass  # record count is stream-derived for QC-3b
        comp_argmax = [[None] * (len(streams[p]) - 1) for p in range(len(streams))]
        for r in rows:
            p, pos = int(r['prompt']), int(r['pos'])
            assert int(r['true_next']) == streams[p][pos + 1], (p, pos)
            comp_argmax[p][pos] = int(r['src_argmax'])
        print('AESIR_CSV_STREAM_CHECK: true_next column reproduces the filed stream positions')
    recs = []
    for p in range(len(streams)):
        for pos in range(len(streams[p]) - 1):
            row = cand[p][pos]
            ca = comp_argmax[p][pos]
            cand_am = int(np.argmax(row))
            rank = int(np.sum(row > row[ca]))
            gap = float(row[cand_am] - row[ca])
            gap_milli = int(gap * 1000.0)
            seg = 1 if pos + 1 >= plen[p] else 0
            recs.append(dict(prompt=p, pos=pos, segment=seg, comp_argmax=ca,
                             cand_argmax=cand_am, agree=1 if cand_am == ca else 0,
                             rank=rank, gap_milli=gap_milli))
    def report(rs, name):
        n = len(rs)
        exact = sum(1 for r in rs if r['rank'] == 0)
        band = [r for r in rs if r['rank'] <= 2 and r['gap_milli'] < 1000]
        near = len(band) - exact
        div = n - len(band)
        agree = sum(r['agree'] for r in rs)
        worst = max(rs, key=lambda r: (r['rank'], r['gap_milli']))
        maxgap = max(r['gap_milli'] for r in rs)
        print('%s: records %d exact %d near_tie %d divergent %d in_band %d/%d = %.2f%% agree %d/%d = %.2f%% worst_rank %d worst_gap_milli %d max_gap_milli %d' % (
            name, n, exact, near, div, len(band), n, 100.0 * len(band) / n, agree, n, 100.0 * agree / n, worst['rank'], worst['gap_milli'], maxgap))
        print('  worst_record: prompt %d pos %d comp_argmax %d cand_argmax %d rank %d gap_milli %d' % (
            worst['prompt'], worst['pos'], worst['comp_argmax'], worst['cand_argmax'], worst['rank'], worst['gap_milli']))
        return div
    print('PAIRING:', a.label)
    div = report(recs, 'AGGREGATE')
    for p in range(len(streams)):
        report([r for r in recs if r['prompt'] == p], 'prompt %d' % p)
    report([r for r in recs if r['segment'] == 0], 'prompt_segment')
    report([r for r in recs if r['segment'] == 1], 'continuation_segment')
    print('VERDICT:', 'FAITHFUL' if div == 0 else 'DIVERGENT (%d records out of band)' % div)

if __name__ == '__main__':
    main()
