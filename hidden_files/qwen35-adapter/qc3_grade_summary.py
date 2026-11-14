#!/usr/bin/env python3
"""Independent re-grade of the QC-3a grade CSV (defense against
harness arithmetic drift): recomputes the near-tie account from
the filed per-position records with plain Python. Band rule
(core/near_tie_gate): rank <= 2 AND gap_milli < 1000, rank 0 =
comparator argmax is the candidate's top-1 (gap 0)."""
import csv, sys, collections
rows = list(csv.DictReader(open(sys.argv[1])))
print('records', len(rows))
band = [r for r in rows if int(r['rank_comp']) <= 2 and int(r['gap_comp_milli']) < 1000]
exact = [r for r in rows if int(r['rank_comp']) == 0]
near = [r for r in band if int(r['rank_comp']) > 0]
div = [r for r in rows if r not in band]
print('exact', len(exact), 'near_tie', len(near), 'in_band', len(band), 'band_pct %.2f' % (100.0*len(band)/len(rows)))
print('divergent', len(div))
agree = sum(int(r['agree']) for r in rows)
print('argmax_agreement %d/%d = %.2f%%' % (agree, len(rows), 100.0*agree/len(rows)))
print('rank_distribution', dict(sorted(collections.Counter(int(r['rank_comp']) for r in rows).items())))
worst = sorted(rows, key=lambda r: (int(r['rank_comp']), int(r['gap_comp_milli'])), reverse=True)[:5]
print('worst_records (prompt,pos,true_next,src_argmax,q8_argmax,rank_comp,gap_comp_milli):')
for r in worst:
    print(' ', r['prompt'], r['pos'], r['true_next'], r['src_argmax'], r['q8_argmax'], r['rank_comp'], r['gap_comp_milli'])
maxgap = max(rows, key=lambda r: int(r['gap_comp_milli']))
print('max_gap_record', maxgap['prompt'], maxgap['pos'], 'rank', maxgap['rank_comp'], 'gap_milli', maxgap['gap_comp_milli'])
for p in sorted(set(r['prompt'] for r in rows), key=int):
    pr = [r for r in rows if r['prompt'] == p]
    pb = [r for r in pr if int(r['rank_comp']) <= 2 and int(r['gap_comp_milli']) < 1000]
    pa = sum(int(r['agree']) for r in pr)
    print('prompt %s: steps %d in_band %d (%.1f%%) agree %d/%d worst_rank %d worst_gap_milli %d' % (p, len(pr), len(pb), 100.0*len(pb)/len(pr), pa, len(pr), max(int(r['rank_comp']) for r in pr), max(int(r['gap_comp_milli']) for r in pr)))
for seg, label in [('0','prompt'),('1','continuation')]:
    sr=[r for r in rows if r['segment']==seg]
    sb=[r for r in sr if int(r['rank_comp'])<=2 and int(r['gap_comp_milli'])<1000]
    sa=sum(int(r['agree']) for r in sr)
    print('%s_segment: steps %d in_band %d (%.2f%%) agree %d/%d worst_rank %d worst_gap_milli %d' % (label, len(sr), len(sb), 100.0*len(sb)/len(sr), sa, len(sr), max(int(r['rank_comp']) for r in sr), max(int(r['gap_comp_milli']) for r in sr)))
print('verdict_by_gate_rule:', 'FAITHFUL' if len(div) == 0 else 'DIVERGENT (divergent records exist; see worst list)')
