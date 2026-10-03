#!/usr/bin/env python3
"""Bound narrow down128 activation evidence to accepted original real F32 sources."""
import argparse
from array import array
import csv
import hashlib
import io
import json
import math
from pathlib import Path

import check_turing_activations as old
from check_packed_matrix import errors, MAX_ERROR, MAX_RMS
from launch import digest
from profile_native_cuda import read_text

META = ['META','1','turing_native_f32_down_rows','128','32','12']
COUNTS = (1990656,114688,2520)


def bits(values):
    return array('f',values).tobytes()


def case(reader,state,index,sources):
    row=next(reader)
    if len(row)!=10 or row[:4]!=['CASE',str(index),str(state),old.TENSORS[index%7]]:
        raise ValueError('Down activation case identity/order mismatch')
    kind,columns,rows,batch,offset,identity=map(int,row[4:])
    if (kind not in (12,14) or batch!=(4 if index%14<7 else 32) or identity!=old.SOURCE_IDS[index%7]
        or not 1<=rows<=128256 or offset<0 or columns*4!=len(sources[state,identity])):
        raise ValueError('Down activation descriptor/source mismatch')
    c=dict(index=index,state=state,name=row[3],kind=kind,columns=columns,rows=rows,batch=batch,
           offset=offset,source=identity,actual=array('d'),reference=array('d'),original=array('d'),
           matrix_rows=128 if index%14==13 else 64)
    for position in range(rows*batch):
        row=next(reader)
        if len(row)!=7 or row[:4]!=['VALUE',str(index),str(position//rows),str(position%rows)]:
            raise ValueError('Incomplete/duplicate/out-of-order three-owner activation output')
        for key,value in zip(('reference','actual','original'),row[4:],strict=True):c[key].append(old.f32(value))
    span=(rows+31)//32*32
    guards=batch*(columns+2*span+43-2*rows)
    if next(reader)!=['GUARD',str(index),str(guards),'0']:raise ValueError('Down activation guards failed')
    row=next(reader);numeric=errors(c['actual'],c['reference'])
    if len(row)!=4 or row[:2]!=['METRIC',str(index)]:raise ValueError('Missing down activation metrics')
    for value,key in zip(row[2:],('maximum_scaled_error','normalized_rms'),strict=True):
        if not math.isfinite(float(value)) or not math.isclose(float(value),numeric[key],rel_tol=1e-12,abs_tol=1e-15):
            raise ValueError('Declared down metric disagrees with complete values')
    c.update(guards=guards,native_error=numeric,original_native_error=errors(c['original'],c['reference']),
             original_f32_bits_equal=bits(c['actual'])==bits(c['original']))
    return c


def parse(path):
    text=read_text(path,256*1024*1024)
    if len(text.encode('utf-8'))>256*1024*1024 or not text.endswith('\n'):raise ValueError('Incomplete/unbounded activation capture')
    reader=iter(csv.reader(io.StringIO(text)));cuda=next(reader)
    if not cuda or not cuda[0].startswith('[CUDA]') or 'api=cuda' not in cuda[0] or 'cpu_offload=0' not in cuda[0]:
        raise ValueError('Missing actual CUDA identity')
    if next(reader)!=META:raise ValueError('Unsupported down-only row mode')
    sources={};states=[];cases=[]
    for state in range(2):
        row=next(reader)
        if len(row)<7 or row[:2]!=['STATE',str(state)]:raise ValueError('Wrong down replay state')
        position=int(row[2]);tokens=list(map(int,row[3:]))
        if len(tokens)!=position or not 4<=position<=512 or position%4 or any(not 0<=t<128256 for t in tokens):
            raise ValueError('Invalid down source causal IDs/count')
        states.append(dict(position=position,replayed_tokens=tokens))
        for identity in range(3):sources[state,identity]=old.source(reader,state,identity)
        if len(sources[state,0])!=len(sources[state,1]):raise ValueError('Down source width mismatch')
        for _ in range(14):cases.append(case(reader,state,len(cases),sources))
    outputs=sum(len(c['actual']) for c in cases);inputs=sum(len(s) for s in sources.values())
    if next(reader)!=['COMPLETE','activation','28',str(outputs),str(inputs),'12'] or next(reader,None) is not None:
        raise ValueError('Incomplete/trailing down activation totals')
    return dict(cases=cases,sources=sources,states=states,activation_precision=0,native_outputs=outputs,
                source_values=inputs,csv_sha256=hashlib.sha256(text.encode('utf-8')).hexdigest())


def unique(pairs):
    result={}
    for key,value in pairs:
        if key in result:raise ValueError('Duplicate accepted-source JSON key')
        result[key]=value
    return result


def budget(value):
    if not isinstance(value,dict) or value.get('passed') is not True:return False
    for key,limit in [('maximum_scaled_error',MAX_ERROR),('normalized_rms',MAX_RMS)]:
        n=value.get(key)
        if isinstance(n,bool) or not isinstance(n,(int,float)) or not math.isfinite(n) or not 0<=n<=limit:return False
    return True


def same_sources(data,base):
    if data['states']!=base['states'] or data['sources'].keys()!=base['sources'].keys():
        raise ValueError('Changed accepted causal source states')
    if any(bits(v)!=bits(base['sources'][key]) for key,v in data['sources'].items()):
        raise ValueError('Changed actual accepted F32 operands')
    if len(data['cases'])!=len(base['cases']):raise ValueError('Changed accepted source cases')
    for c,b in zip(data['cases'],base['cases'],strict=True):
        keys=('index','state','name','kind','columns','rows','batch','offset','source','guards')
        if any(c[k]!=b[k] for k in keys) or bits(c['reference'])!=bits(b['reference']) or bits(c['original'])!=bits(b['actual']):
            raise ValueError('Changed accepted original/native projection bytes or descriptors')


def reference(data,csv_path,report_path,model_sha):
    text=read_text(report_path,16*1024*1024)
    def nonfinite(value):raise ValueError('Nonfinite accepted-source JSON')
    r=json.loads(text,object_pairs_hook=unique,parse_constant=nonfinite);base=old.parse(csv_path)
    if (r.get('passed') is not True or r.get('collection_complete') is not True
        or type(r.get('activation_precision')) is not int or r['activation_precision']!=0
        or r.get('speed_claim') is not False or r.get('full_model_quality_claim') is not False
        or r.get('model_sha256')!=model_sha or r.get('csv_sha256')!=base['csv_sha256']
        or base['activation_precision']!=0 or r.get('states')!=base['states']
        or (r.get('native_outputs'),r.get('source_values'),r.get('independent_outputs'))!=COUNTS
        or (base['native_outputs'],base['source_values'])!=COUNTS[:2] or r.get('invalid_spans')!=12
        or len(r.get('cases',[]))!=28 or len(r.get('oracle',[]))!=28):
        raise ValueError('Accepted original activation report scope/totals/hash mismatch')
    independent_outputs=0
    for c,b,o in zip(base['cases'],r['cases'],r['oracle'],strict=True):
        keys=('index','state','name','kind','columns','rows','batch','offset','source','guards')
        selected=sorted({0,1,17,c['rows']//2,c['rows']-1})
        if (any(c[k]!=b.get(k) for k in keys) or c['native_error']!=b.get('native_error')
            or not budget(c['native_error']) or o.get('case')!=c['index'] or o.get('rows')!=selected
            or o.get('outputs')!=len(selected)*c['batch'] or not budget(o.get('candidate')) or not budget(o.get('reference'))):
            raise ValueError('Accepted source numerical coverage/budget mismatch')
        independent_outputs+=o['outputs']
    if independent_outputs!=COUNTS[2]:raise ValueError('Accepted independent source total mismatch')
    same_sources(data,base)
    return dict(csv_sha256=base['csv_sha256'],report_sha256=hashlib.sha256(text.encode('utf-8')).hexdigest(),
                native_outputs=COUNTS[0],source_values=COUNTS[1],independent_outputs=COUNTS[2],bytes_identical=True)


def independent(data,model):
    candidate=old.independent(data,model)
    original=dict(data,cases=[dict(c,actual=c['original']) for c in data['cases']])
    previous=old.independent(original,model)
    for a,b in zip(candidate,previous,strict=True):
        if a['case']!=b['case'] or a['rows']!=b['rows'] or a['outputs']!=b['outputs']:raise ValueError('Independent owner coverage mismatch')
        a['original']=b['candidate']
    return candidate


def summary(data):
    safe=dict(data,cases=[{k:v for k,v in c.items() if k!='original'} for c in data['cases']])
    result=old.summary(safe)
    result.update(candidate='down_only_rows128',matrix_rows=128,original_bits_required=True,
                  limits=result['limits']+' Exact original64/native/actual input source binding; only batch32 down uses128 rows.')
    return result


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('csv',type=Path);p.add_argument('--model',type=Path,required=True)
    p.add_argument('--model-sha256',required=True);p.add_argument('--reference-csv',type=Path,required=True)
    p.add_argument('--reference-report',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args()
    with a.output.open('x',encoding='utf-8') as stream:
        report=dict(schema=1,passed=False,collection_complete=False,speed_claim=False,full_model_quality_claim=False)
        try:
            if digest(a.model)!=a.model_sha256:raise ValueError('Down original model checksum mismatch')
            data=parse(a.csv);report=summary(data)
            report.update(model_sha256=a.model_sha256,accepted_reference=reference(data,a.reference_csv,a.reference_report,a.model_sha256))
            report['oracle']=independent(data,a.model);report['independent_outputs']=sum(r['outputs'] for r in report['oracle'])
            ref=report['accepted_reference']
            if (digest(a.model)!=a.model_sha256 or digest(a.csv)!=data['csv_sha256'] or digest(a.reference_csv)!=ref['csv_sha256']
                or digest(a.reference_report)!=ref['report_sha256']):raise ValueError('Down source/model/capture changed during validation')
            report['passed']=(report['independent_outputs']==COUNTS[2] and (data['native_outputs'],data['source_values'])==COUNTS[:2]
                and all(c['original_f32_bits_equal'] and budget(c['native_error']) and budget(c['original_native_error']) for c in data['cases'])
                and all(budget(r['candidate']) and budget(r['reference']) and budget(r['original']) for r in report['oracle']))
            if not report['passed']:report['error']='Complete fixed down activation/original-bit/independent gates failed'
        except (Exception,KeyboardInterrupt) as error:
            report.update(passed=False,error=f'{type(error).__name__}: {error}')
        json.dump(report,stream,indent=2);stream.write('\n')
    print('PASS: down-only real F32 activation gate' if report['passed'] else 'FAIL: '+report['error'])
    return 0 if report['passed'] else 1


if __name__=='__main__':raise SystemExit(main())
