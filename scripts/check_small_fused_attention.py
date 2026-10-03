#!/usr/bin/env python3
"""Complete bounded small-score GQA primitive evidence; profile timings unscored."""
import argparse
from array import array
import csv
import hashlib
import importlib.metadata
import io
import json
import math
from pathlib import Path
import statistics

from launch import digest
from profile_native_cuda import read_text
from check_turing_activations import f32
from check_turing_paired_ffn import integer
from check_packed_matrix import errors,number

BATCHES=(1,4,32)
ENDPOINTS=(1,31,32,33,37,255,256,257,1070,1535,1536)
HEADS=24
KV_HEADS=8
DIM=128


def geometry():
    return [(batch,end,min(batch,end),(4096 if end==1536 else min(4096,end+13))) for batch in BATCHES for end in ENDPOINTS]


def guard_count(batch,tokens,capacity,end):
    return batch*9276+70+24*capacity-tokens*9216


def parse(path):
    text=read_text(path,256*1024**2)
    if not text.endswith('\n') or any(len(line)>1024 for line in text.splitlines()):raise ValueError('Incomplete/oversized attention CSV')
    reader=iter(csv.reader(io.StringIO(text),strict=True))
    if next(reader)!=['MODE','small_shared_attention','24','8','128','1536','4096'] or next(reader)!=['SPANS','17','0'] or next(reader)!=['CUDA','0','cuda','1','0']:
        raise ValueError('Attention mode/span/actual CUDA scope changed')
    row=next(reader)
    if len(row)!=2 or row[0]!='PID':raise ValueError('Missing actual attention process')
    pid=integer(row[1])
    if not 1<=pid<=2**31-1:raise ValueError('Invalid attention process')
    cases=[];values=0
    for index,(batch,end,tokens,capacity) in enumerate(geometry()):
        prefix=end-tokens;mode=index%3
        if next(reader)!=['CASE',str(index),str(batch),str(tokens),str(capacity),str(prefix),str(mode)]:raise ValueError('Wrong ordered causal attention case')
        native=array('f');candidate=array('f')
        for token in range(tokens):
            for head in range(HEADS):
                for col in range(DIM):
                    row=next(reader)
                    if len(row)!=7 or row[:5]!=['VALUE',str(index),str(token),str(head),str(col)]:raise ValueError('Incomplete/duplicate/out-of-order attention output')
                    native.append(f32(row[5]));candidate.append(f32(row[6]))
        if next(reader)!=['INPUT',str(index),str(tokens*3072),str(2*capacity*1024),'0']:raise ValueError('Incomplete immutable attention inputs')
        guards=guard_count(batch,tokens,capacity,end)
        if next(reader)!=['GUARD',str(index),str(guards),'0']:raise ValueError('Incomplete attention ownership guards')
        times={0:[],1:[]}
        for sample in range(10):
            for step in range(2):
                owner=(sample+step)%2;row=next(reader)
                if len(row)!=6 or row[:5]!=['TIME',str(index),str(owner),str(sample),'3']:raise ValueError('Wrong attention timing ownership/rotation/count')
                elapsed=number(row[5])/3
                if elapsed<=0 or not math.isfinite(elapsed):raise ValueError('Attention per-call timing underflow/nonfinite')
                times[owner].append(elapsed)
        cases.append(dict(index=index,batch=batch,tokens=tokens,capacity=capacity,prefix=prefix,mode=mode,native=native,candidate=candidate,
            original_f32_bits_equal=native.tobytes()==candidate.tobytes(),guards=guards,query_cells=tokens*3072,kv_cells=2*capacity*1024,times=times))
        values+=len(native)
    if next(reader)!=['COMPLETE','attention',str(len(cases)),str(values),str(len(cases)*20)] or next(reader,None) is not None:raise ValueError('Incomplete/trailing attention capture')
    return dict(pid=pid,cases=cases,values_per_owner=values,csv_sha256=hashlib.sha256(text.encode()).hexdigest())


def independent(data):
    if importlib.metadata.version('numpy')!='2.4.4':raise ValueError('Attention oracle requires NumPy2.4.4')
    import numpy as np
    result=[]
    columns=np.arange(DIM);kv_heads=np.arange(KV_HEADS)
    for c in data['cases']:
        tokens=c['tokens'];capacity=c['capacity'];mode=c['mode'];t=np.arange(capacity)
        q=((columns[None,None,:]*7+np.arange(tokens)[:,None,None]*13+np.arange(HEADS)[None,:,None]*3)%29-14).astype(np.float64)/16
        k=((t[:,None,None]*5+kv_heads[None,:,None]*11+columns[None,None,:]*3)%31-15).astype(np.float64)/32
        v=((t[:,None,None]*7+kv_heads[None,:,None]*13+columns[None,None,:]*5)%37-18).astype(np.float64)/8
        if mode==1:q.fill(0);k.fill(0);v.fill(0)
        elif mode==2:q*=16;k*=8
        # The native pattern's dyadic values are exactly representable in F16.
        if not np.array_equal(k,k.astype(np.float16).astype(np.float64)) or not np.array_equal(v,v.astype(np.float16).astype(np.float64)):raise ValueError('Attention pattern not exact F16')
        expected=np.empty((tokens,HEADS,DIM),dtype=np.float64)
        for head in range(HEADS):
            kv_head=head*KV_HEADS//HEADS
            scores=q[:,head,:]@k[:,kv_head,:].T/math.sqrt(DIM)
            for token in range(tokens):
                count=c['prefix']+token+1
                logits=scores[token,:count];prob=np.exp(logits-np.max(logits));prob/=np.sum(prob)
                expected[token,head,:]=prob@v[:count,kv_head,:]
        expected=expected.reshape(-1).tolist()
        result.append(dict(index=c['index'],outputs=len(expected),native=errors(c['native'],expected),candidate=errors(c['candidate'],expected)))
    return result


def summarize(data,oracle,*,unscored=False):
    if type(unscored) is not bool:raise ValueError("Invalid profile timing scope")
    expected=sum(len(c['native']) for c in data['cases'])
    independent_ok=len(oracle)==len(data['cases']) and all(o['index']==c['index'] and o['outputs']==len(c['native']) and all(o[n]['passed'] is True for n in ('native','candidate')) for c,o in zip(data['cases'],oracle))
    passed=independent_ok and all(c['original_f32_bits_equal'] for c in data['cases'])
    report=dict(schema=1,passed=passed,collection_complete=True,speed_promoted=False,full_model_speed_claim=False,speed_scored=not unscored,pid=data["pid"],
        values_per_owner=data['values_per_owner'],independent_outputs=sum(o['outputs'] for o in oracle),csv_sha256=data['csv_sha256'],oracle=oracle,cases=[])
    for c in data['cases']:
        r={k:c[k] for k in ('index','batch','tokens','capacity','prefix','mode','guards','query_cells','kv_cells','original_f32_bits_equal')}
        r.update(native_seconds=c['times'][0],candidate_seconds=c['times'][1],original_to_small_ratio=statistics.median(c['times'][0])/statistics.median(c['times'][1]) if passed and not unscored else None)
        report['cases'].append(r)
    if passed and not unscored and any(not math.isfinite(c['original_to_small_ratio']) or c['original_to_small_ratio']<=0 for c in report['cases']):report.update(passed=False,error='Nonfinite attention ratio; full cases retained')
    if not report['passed']:
        report.setdefault('error','Complete attention original-bit/independent gate failed')
        for c in report['cases']:c['original_to_small_ratio']=None
    return report


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('csv',type=Path);p.add_argument('--binary',type=Path,required=True);p.add_argument('--binary-sha256',required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--unscored',action='store_true',help='Profiled capture: validate values but clear every speed ratio');a=p.parse_args()
    report=dict(schema=1,passed=False,collection_complete=False,speed_promoted=False,full_model_speed_claim=False,speed_scored=not a.unscored)
    with a.output.open('x',encoding='utf-8') as stream:
        try:
            import re
            if not re.fullmatch(r'[0-9a-f]{64}',a.binary_sha256) or digest(a.binary)!=a.binary_sha256:raise ValueError('Attention binary identity changed before admission')
            data=parse(a.csv);report=summarize(data,independent(data),unscored=a.unscored)
            report.update(binary_sha256=a.binary_sha256,oracle_versions=dict(numpy='2.4.4'),limits='Opt-in24/8/128 GQA, bounded shared1536 scores/actual KV capacity up to4096, deterministic inputs natively checked immutable in full, not actual model Q/K/V. Every causal output original F32 bits and independent Float64 fixed .002/.0002 budgets; all guards/inputs/rotated timings. Original16KiB and candidate6KiB kernel, same primitive session. Profile timing ratios suppressed. No model/production/provider promotion.')
            if digest(a.binary)!=a.binary_sha256 or digest(a.csv)!=data['csv_sha256']:raise ValueError('Attention binary/capture changed during validation')
        except (Exception,KeyboardInterrupt) as error:
            report.update(passed=False,error=f'{type(error).__name__}: {error}')
            for c in report.get('cases',[]):c['original_to_small_ratio']=None
        json.dump(report,stream,indent=2,allow_nan=False);stream.write('\n')
    return 0 if report['passed'] else 1


if __name__=='__main__':raise SystemExit(main())
