#!/usr/bin/env python3
"""Complete source-bound paired gate/up primitive evidence; no model speed claim."""
import argparse
from array import array
import csv
import hashlib
import importlib.metadata
import io
import json
import math
from pathlib import Path
import re
import statistics

from launch import digest
from profile_native_cuda import read_text
from check_turing_activations import f32
from check_packed_matrix import errors, number

ROWS = 8192
COLUMNS = 3072
BATCHES = (4,8,16,32)
NAMES = ('blk.0.ffn_gate.weight','blk.0.ffn_up.weight')


def integer(value):
    if not re.fullmatch(r'0|[1-9][0-9]{0,18}',value):
        raise ValueError('Noncanonical bounded pair integer')
    return int(value)


def parse(path):
    text=read_text(path,256*1024**2)
    if not text.endswith('\n') or any(len(line)>1024 for line in text.splitlines()):
        raise ValueError('Incomplete/oversized pair CSV line')
    reader=iter(csv.reader(io.StringIO(text),strict=True))
    if next(reader)!=['MODE','turing_pair_gate_up','64','32'] or next(reader)!=['SPANS','12','0']:
        raise ValueError('Missing explicit pair geometry/preload span refusals')
    row=next(reader)
    if not row or not row[0].startswith('[CUDA]') or 'api=cuda' not in row[0] or 'cpu_offload=0' not in row[0]:
        raise ValueError('Missing actual native CUDA pair identity')
    if next(reader)!=['SYNTHETIC','144','0']:raise ValueError('Incomplete synthetic pair cases')
    cases=[]
    for index,batch in enumerate(BATCHES):
        row=next(reader)
        if len(row)!=8 or row[:2]!=['CASE',str(index)] or list(map(integer,row[2:6]))!=[batch,ROWS,COLUMNS,12]:
            raise ValueError('Wrong ordered actual pair descriptor')
        left,right=map(integer,row[6:]);span=ROWS*(COLUMNS//256)*144
        if left<right+span and right<left+span:raise ValueError('Pair weights intersect')
        owners=[dict(native=array('f'),candidate=array('f'),original=array('f')) for _ in range(2)]
        for side in range(2):
            for token in range(batch):
                for output in range(ROWS):
                    row=next(reader)
                    if len(row)!=8 or row[:5]!=['VALUE',str(index),str(side),str(token),str(output)]:
                        raise ValueError('Incomplete/duplicate/out-of-order paired values')
                    for owner,value in zip(('native','candidate','original'),row[5:],strict=True):owners[side][owner].append(f32(value))
        padded=(ROWS+31)//32*32
        expected_guards=batch*(112+6*(padded-ROWS))
        if next(reader)!=['GUARD',str(index),str(expected_guards),'0']:raise ValueError('Pair guard count/failure changed')
        timings={0:[],1:[],2:[]}
        for sample in range(10):
            for step in range(3):
                mode=(sample+step)%3;row=next(reader)
                if len(row)!=6 or row[:5]!=['TIME',str(index),str(mode),str(sample),'3']:
                    raise ValueError('Wrong pair timing ownership/rotation/count')
                value=number(row[5])/3
                if value<=0 or not math.isfinite(value):raise ValueError('Pair timing underflow/nonfinite')
                timings[mode].append(value)
        bits=[v['candidate'].tobytes()==v['original'].tobytes() for v in owners]
        native=[errors(v['candidate'],v['native']) for v in owners]
        original=[errors(v['original'],v['native']) for v in owners]
        cases.append(dict(index=index,batch=batch,rows=ROWS,columns=COLUMNS,kind=12,offsets=[left,right],owners=owners,
            original_f32_bits_equal=bits,native_error=native,original_native_error=original,guards=expected_guards,timings=timings,
            passed=all(bits) and all(v['passed'] for v in native+original)))
    values=sum(2*c['batch']*ROWS for c in cases)
    if next(reader)!=['COMPLETE','pair',str(len(BATCHES)),str(values),str(len(BATCHES)*30)] or next(reader,None) is not None:
        raise ValueError('Incomplete/trailing pair capture')
    return dict(cases=cases,csv_sha256=hashlib.sha256(text.encode()).hexdigest(),values_per_owner=values,
        guards=sum(c['guards'] for c in cases),span_refusals=12,synthetic_pairs=144)


def independent(data,model):
    if importlib.metadata.version('gguf')!='0.19.0' or importlib.metadata.version('numpy')!='2.4.4':
        raise ValueError('Pair oracle requires gguf0.19/NumPy2.4.4')
    import numpy as np
    from gguf import GGUFReader
    from gguf.quants import dequantize
    reader=GGUFReader(str(model));tensors={t.name:t for t in reader.tensors};result=[]
    for c in data['cases']:
        inputs=np.array([[((col*7+token*13)%29-14)/16 for col in range(COLUMNS)] for token in range(c['batch'])],dtype=np.float64)
        selected=sorted({0,ROWS//4,ROWS//2,3*ROWS//4,ROWS-1})
        sides=[]
        for side,name in enumerate(NAMES):
            t=tensors[name]
            if tuple(map(int,t.shape))!=(COLUMNS,ROWS) or int(t.tensor_type)!=12 or t.data_offset!=c['offsets'][side]:
                raise ValueError('Pair GGUF descriptors differ from actual capture')
            weights=dequantize(t.data,t.tensor_type).reshape(ROWS,COLUMNS)[selected].astype(np.float64)
            expected=(inputs@weights.T).reshape(-1).tolist()
            metrics={}
            for owner in ('native','candidate','original'):
                actual=[c['owners'][side][owner][token*ROWS+row] for token in range(c['batch']) for row in selected]
                metrics[owner]=errors(actual,expected)
            sides.append(dict(name=name,selected_rows=selected,outputs=len(expected),**metrics))
        result.append(dict(index=c['index'],sides=sides))
    return result


def summarize(data,oracle):
    independent_ok=len(oracle)==len(BATCHES) and all(len(c['sides'])==2 and all(s[o]['passed'] is True for s in c['sides'] for o in ('native','candidate','original')) for c in oracle)
    passed=independent_ok and all(c['passed'] for c in data['cases'])
    report=dict(schema=1,passed=passed,collection_complete=True,full_model_speed_claim=False,speed_promoted=False,
        values_per_owner=data['values_per_owner'],guards=data['guards'],span_refusals=12,synthetic_pairs=144,
        csv_sha256=data['csv_sha256'],oracle=oracle,independent_outputs=sum(s['outputs'] for c in oracle for s in c['sides']),cases=[])
    for c in data['cases']:
        native,paired,original=[c['timings'][i] for i in range(3)]
        report['cases'].append({k:c[k] for k in ('index','batch','rows','columns','kind','offsets','original_f32_bits_equal','native_error','original_native_error','guards')})
        r=report['cases'][-1];r.update(native_seconds=native,candidate_seconds=paired,original_seconds=original,
            native_to_pair_ratio=statistics.median(native)/statistics.median(paired) if passed else None,
            original_to_pair_ratio=statistics.median(original)/statistics.median(paired) if passed else None)
    if passed and any(not math.isfinite(c[k]) or c[k]<=0 for c in report['cases'] for k in ('native_to_pair_ratio','original_to_pair_ratio')):
        report.update(passed=False,error='Nonfinite paired ratio; complete cases retained')
    if not report['passed']:
        report.setdefault('error','Complete pair numerical/independent/original-bit gate failed')
        for c in report['cases']:c['native_to_pair_ratio']=c['original_to_pair_ratio']=None
    return report


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('csv',type=Path)
    p.add_argument('--model',type=Path,required=True);p.add_argument('--model-sha256',required=True)
    p.add_argument('--binary',type=Path,required=True);p.add_argument('--binary-sha256',required=True)
    p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    report=dict(schema=1,passed=False,collection_complete=False,full_model_speed_claim=False,speed_promoted=False)
    with a.output.open('x',encoding='utf-8') as stream:
        try:
            if any(not re.fullmatch(r'[0-9a-f]{64}',v) for v in (a.model_sha256,a.binary_sha256)):
                raise ValueError('Pair model/binary hashes must be exact SHA256')
            if digest(a.model)!=a.model_sha256 or digest(a.binary)!=a.binary_sha256:raise ValueError('Pair model/binary changed before admission')
            data=parse(a.csv);oracle=independent(data,a.model);report=summarize(data,oracle)
            report.update(model_sha256=a.model_sha256,binary_sha256=a.binary_sha256,
                limits='Original strict3B gate/up same-kind Q4, paired64 rows per tensor/32 columns, warmed primitive one session. Synthetic same-kind Q4/Q5/Q6 distinct from real pair. Inputs use natively checked deterministic public pattern. Exact original F32 bits plus fixed native/selected CPU Float64 budgets, complete guard/span/timing gates. No model-level/default/provider promotion.')
            if any(digest(path)!=sha for path,sha in ((a.model,a.model_sha256),(a.binary,a.binary_sha256),(a.csv,data['csv_sha256']))):
                raise ValueError('Pair model/binary/capture changed during validation')
        except (Exception,KeyboardInterrupt) as error:
            report.update(passed=False,error=f'{type(error).__name__}: {error}')
            for c in report.get('cases',[]):c['native_to_pair_ratio']=c['original_to_pair_ratio']=None
        json.dump(report,stream,indent=2,allow_nan=False);stream.write('\n')
    return 0 if report['passed'] else 1


if __name__=='__main__':raise SystemExit(main())
