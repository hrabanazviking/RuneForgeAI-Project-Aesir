# QC-6 crossgrade summary: product grade CSVs (rank/gap of the SOURCE
# argmax in the PRODUCT row, computed by grade_qwen35_qc_6) + source
# CSVs (for argmax agreement). Campaign band: rank <= 2 AND gap < 1.0.
# Verdict by the strict gate rule: FAITHFUL iff every record in band.
import csv, glob, sys
src_dir, prod_dir = sys.argv[1], sys.argv[2]
def load(pattern):
    rows = []
    for path in sorted(glob.glob(pattern)):
        with open(path) as f:
            for row in csv.DictReader(f):
                rows.append({k: int(v) for k, v in row.items()})
    return rows
src = {(r['prompt'], r['pos']): r for r in load(src_dir)}
prod = load(prod_dir)
prod.sort(key=lambda r: (r['prompt'], r['pos']))
assert len(prod) == len(src), (len(prod), len(src))
in_band = agree = 0
worst = []
per = {}
for r in prod:
    s = src[(r['prompt'], r['pos'])]
    band = r['rank_comp'] <= 2 and r['gap_comp_milli'] < 1000
    in_band += band
    agree += (r['aesir_argmax'] == s['aesir_argmax'])
    p = per.setdefault(r['prompt'], [0, 0, 0])
    p[0] += 1; p[1] += band; p[2] += (r['aesir_argmax'] == s['aesir_argmax'])
    worst.append((r['gap_comp_milli'], r['rank_comp'], r['prompt'], r['pos'], r['true'], s['aesir_argmax'], r['aesir_argmax'], band))
n = len(prod)
print('RECORDS', n)
print('IN_BAND %d/%d = %.2f%%' % (in_band, n, 100.0 * in_band / n))
print('ARGMAX_AGREEMENT %d/%d = %.2f%%' % (agree, n, 100.0 * agree / n))
from collections import Counter
print('RANK_DIST', dict(sorted(Counter(r['rank_comp'] for r in prod).items())))
print('PER_PROMPT prompt records in_band agree')
for p in sorted(per):
    c, b, a = per[p]
    print('  p%d %d %d %d' % (p, c, b, a))
worst.sort(reverse=True)
print('WORST_RECORDS gap_milli rank prompt pos true src_argmax prod_argmax in_band')
for w in worst[:10]:
    print('  %d %d p%d pos%d true=%d src=%d prod=%d %s' % (w[0], w[1], w[2], w[3], w[4], w[5], w[6], w[7]))
print('VERDICT', 'FAITHFUL' if in_band == n else 'DIVERGENT (not FAITHFUL) -- %d of %d records out of band' % (n - in_band, n))
