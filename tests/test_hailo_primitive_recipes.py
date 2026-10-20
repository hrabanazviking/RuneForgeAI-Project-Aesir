#!/usr/bin/env python3
"""Compiler structure + tiny primitive math only. No layer/model execution."""
import argparse
from collections import Counter
from decimal import Decimal, localcontext
import hashlib
import json
import math
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
from test_hailo_semantic_plan import dense_fixture

CONFIG=argparse.Namespace()
NORM=['multiply','reduce_sum_last','divide_by_width','add_epsilon',
      'reciprocal_sqrt','multiply_row_scale','multiply_source_vector']
SILU=['abs','negate','exp','add_one','reciprocal','multiply',
      'compare_nonnegative','select','multiply']


def evaluate_tiny(recipe,x,weights=None):
    """Test-only interpreter of ONE isolated primitive, synthetic numbers only."""
    values=[list(x)]
    if recipe['kind']=='rms_norm':
        values.append(list(weights))
    for op in recipe['operations']:
        arrays=[values[i] for i in op['inputs']]
        kind=op['kind']
        if kind=='multiply': out=[a*b for a,b in zip(*arrays)]
        elif kind=='reduce_sum_last':
            width=recipe['divisor']
            out=[sum(arrays[0][i:i+width]) for i in range(0,len(arrays[0]),width)]
        elif kind=='divide_by_width': out=[a/recipe['divisor'] for a in arrays[0]]
        elif kind=='add_epsilon':
            epsilon=struct.unpack('<f',struct.pack('<I',recipe['epsilon_bits']))[0]
            out=[a+epsilon for a in arrays[0]]
        elif kind=='reciprocal_sqrt': out=[1/math.sqrt(a) for a in arrays[0]]
        elif kind=='multiply_row_scale':
            out=[a*arrays[1][i//recipe['divisor']] for i,a in enumerate(arrays[0])]
        elif kind=='multiply_source_vector':
            out=[a*arrays[1][i%recipe['divisor']] for i,a in enumerate(arrays[0])]
        elif kind=='abs': out=list(map(abs,arrays[0]))
        elif kind=='negate': out=[-a for a in arrays[0]]
        elif kind=='exp':
            assert all(a<=0 for a in arrays[0])
            out=list(map(math.exp,arrays[0]))
        elif kind=='add_one': out=[1+a for a in arrays[0]]
        elif kind=='reciprocal': out=[1/a for a in arrays[0]]
        elif kind=='compare_nonnegative': out=[a>=0 for a in arrays[0]]
        elif kind=='select': out=[yes if p else no for p,yes,no in zip(*arrays)]
        else: raise AssertionError(kind)
        assert len(out)==recipe['values'][op['output']]['elements']
        assert op['output']==len(values)
        values.append(out)
    return values[recipe['result']]


class PrimitiveRecipes(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary=str(Path(CONFIG.binary).resolve(strict=True))
        cls.graph=str(Path(CONFIG.graph_binary).resolve(strict=True))
        cls.api=str(Path(CONFIG.api_binary).resolve(strict=True))
        cls.temp=tempfile.TemporaryDirectory(prefix='aesir-primitive-recipes-')
        cls.root=Path(cls.temp.name)
        cls.evidence=Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True,exist_ok=True)
        cls.records=[]
        cls.math_records=[]

    @classmethod
    def tearDownClass(cls):
        (cls.evidence/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
        (cls.evidence/'tiny-primitive-results.json').write_text(json.dumps(cls.math_records,indent=2)+'\n')
        cls.temp.cleanup()
        print('Native child scopes: '+str(dict(Counter(x['scope'] for x in cls.records))))

    def run_child(self,command,source,scope):
        before=hashlib.sha256(source.read_bytes()).hexdigest()
        result=subprocess.run(command,capture_output=True,text=True,timeout=15,
                              stdin=subprocess.DEVNULL,check=False)
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(),before)
        self.records.append({'scope':scope,'source_sha256':before,'returncode':result.returncode,
                             'stdout':result.stdout,'stderr':result.stderr})
        return result

    def accepts(self,fixture=None,session=(2,0,16),trace=False):
        raw,_,_=fixture or dense_fixture()
        source=self.root/f'fixture-{len(self.records)}.gguf'
        source.write_bytes(raw)
        command=[self.binary,str(source),*map(str,session)]
        if trace:
            command=[CONFIG.strace,'-y','-o',str(self.evidence/'recipes.strace'),
                     '-e','trace=openat,close,mmap,munmap,ioctl',*command]
        result=self.run_child(command,source,'recipes')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        recipes=json.loads(result.stdout)
        result=self.run_child([self.graph,str(source),*map(str,session)],source,'source_graph')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        graph=json.loads(result.stdout)
        self.check_recipes(recipes,graph)
        return recipes,graph

    def check_recipes(self,data,graph):
        for flag in ('executable_program','device_execution_verified','source_fingerprint_verified','lowered_storage_recomputed'):
            self.assertIs(data[flag],False)
        self.assertTrue(data['unresolved_gates'])
        targets=[i for i,op in enumerate(graph['operations']) if op['kind'] in ('rms_norm','silu')]
        self.assertEqual([r['source_operation'] for r in data['recipes']],targets)
        self.assertEqual(data['remaining_source_operations'],
            [{'id':i,'kind':op['kind']} for i,op in enumerate(graph['operations']) if i not in targets])
        for r in data['recipes']:
            original=graph['operations'][r['source_operation']]
            shape=graph['tensors'][r['source_input']]['shape']
            self.assertEqual(r['source_input'],original['inputs'][0])
            self.assertEqual(r['source_output'],original['output'])
            self.assertEqual(r['values'][0]['shape'],shape)
            kinds=NORM if r['kind']=='rms_norm' else SILU
            self.assertEqual([op['kind'] for op in r['operations']],kinds)
            edges=[[0,0],[2],[3],[4],[5],[0,6],[7,1]] if r['kind']=='rms_norm' else [[0],[1],[2],[3],[4],[3,5],[0],[7,5,6],[0,8]]
            self.assertEqual([op['inputs'] for op in r['operations']],edges)
            if r['kind']=='rms_norm':
                self.assertEqual(r['weight_name'],original['weight'])
                self.assertEqual(r['weight'],graph['weights'][original['weight']])
                self.assertEqual(r['divisor'],shape[-1])
                expected_bits=struct.unpack('<I',struct.pack('<f',graph['parameters']['rms_epsilon']))[0]
                self.assertEqual(r['epsilon_bits'],expected_bits)
                self.assertEqual([v['shape'] for v in r['values']],
                                 [shape,[shape[-1]],shape,*([[shape[0],1]]*4),shape,shape])
            else:
                self.assertEqual(r['weight_name'],'')
                self.assertEqual(r['divisor'],0)
                self.assertEqual(r['epsilon_bits'],0)
                self.assertTrue(all(v['shape']==shape for v in r['values']))
            uses={i:[] for i in range(len(r['values']))}
            for step,op in enumerate(r['operations']):
                self.assertEqual(r['values'][op['output']]['producer'],step)
                for i in op['inputs']:
                    self.assertLess(r['values'][i]['producer'],step)
                    uses[i].append(step)
            for i,v in enumerate(r['values']):
                self.assertEqual(v['elements'],math.prod(v['shape']))
                end=len(r['operations']) if i==r['result'] else max(uses[i],default=v['producer'])
                self.assertEqual(v['last_use'],end)
                self.assertEqual(v['domain'],'predicate' if r['kind']=='silu' and i==7 else 'real')
            self.assertEqual(r['values'][r['result']]['shape'],shape)

    def test_source_recipes_exact_structures_sessions_and_layers(self):
        for layers in (1,2):
            for session in ((2,0,16),(1,7,16),(3,4,16)):
                data,_=self.accepts(dense_fixture(layers=layers,tied=True,value=3),session)
                self.assertEqual(len(data['recipes']),3*layers+1)
                self.assertEqual(sum(len(r['operations']) for r in data['recipes']),23*layers+7)

    def test_exact_epsilon_and_source_kind_binding(self):
        for epsilon in (0.00003125,0.0003):
            self.accepts(dense_fixture(overrides={'llama.attention.layer_norm_rms_epsilon':(6,epsilon)}))
        self.accepts(dense_fixture(hidden=256,key=64,value=64,ff=512,matrix_kind=12))

    def test_isolated_rmsnorm_against_high_precision_math(self):
        data,_=self.accepts(dense_fixture(overrides={'llama.attention.layer_norm_rms_epsilon':(6,0.0003)}))
        recipe=next(r for r in data['recipes'] if r['kind']=='rms_norm')
        weights=[0.5,-0.75,1.,1.25,0.25,-1.,2.,-2.]
        epsilon=struct.unpack('<f',struct.pack('<I',recipe['epsilon_bits']))[0]
        for x in ([0.]*16,[float(i-7)/4 for i in range(16)],[(-1.)**i*(i%5) for i in range(16)]):
            actual=evaluate_tiny(recipe,x,weights)
            expected=[]
            with localcontext() as ctx:
                ctx.prec=80
                for row in (x[:8],x[8:]):
                    scale=(sum(Decimal.from_float(v)**2 for v in row)/8+Decimal.from_float(epsilon)).sqrt()
                    expected.extend(float(Decimal.from_float(v)*Decimal.from_float(w)/scale) for v,w in zip(row,weights))
            for a,b in zip(actual,expected):
                self.assertTrue(math.isclose(a,b,rel_tol=3e-15,abs_tol=1e-300),(a,b))
            self.math_records.append({'primitive':'rms_norm','input':x,'synthetic_weights':weights,'epsilon':epsilon,'actual':actual,'decimal_reference':expected})

    def test_isolated_silu_large_finite_inputs_without_positive_exponential(self):
        data,_=self.accepts()
        recipe=next(r for r in data['recipes'] if r['kind']=='silu')
        x=[-1000.,-100.,-50.,-10.,-2.,-1.,-0.,0.,0.1,0.5,1.,2.,10.,50.,100.,1000.,-0.25,0.25,-4.,4.,-20.,20.,-80.,80.]
        actual=evaluate_tiny(recipe,x)
        with localcontext() as ctx:
            ctx.prec=80
            expected=[float(Decimal.from_float(v)/(1+(-Decimal.from_float(v)).exp())) for v in x]
        for a,b in zip(actual,expected):
            self.assertTrue(math.isfinite(a))
            self.assertTrue(math.isclose(a,b,rel_tol=3e-15,abs_tol=1e-300),(a,b))
        self.math_records.append({'primitive':'silu','input':x,'actual':actual,'decimal_reference':expected})

    def test_malformed_source_graph_refusals_and_owned_snapshot(self):
        source=self.root/'api.gguf'; source.write_bytes(dense_fixture()[0])
        modes=['input_count','negative_input','bad_output','forward_input','producer_mismatch',
               'short_lifetime','shape_mismatch','wrong_product','missing_weight','weight_shape',
               'weight_extent','zero_epsilon','nan_epsilon','silu_weight']
        for mode in modes:
            result=self.run_child([self.api,str(source),mode],source,'api_refusal:'+mode)
            self.assertNotEqual(result.returncode,0)
            self.assertEqual(result.stdout,'')
            self.assertIn('PrimitiveRecipe:',result.stderr)
        result=self.run_child([self.api,str(source),'ownership'],source,'ownership')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(result.stdout.strip(),'owned-recipe-values-pass')

    def test_read_only_no_model_execution(self):
        self.accepts(trace=True)
        trace=(self.evidence/'recipes.strace').read_text()
        self.assertIn('O_RDONLY',trace)
        self.assertIn('PROT_READ, MAP_PRIVATE',trace)
        for forbidden in ('/dev/h1x-','libcuda','libhailort'):
            self.assertNotIn(forbidden,trace)


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    for name in ('binary','graph-binary','api-binary','strace','evidence'):
        parser.add_argument('--'+name,required=True)
    CONFIG,remaining=parser.parse_known_args()
    unittest.main(argv=[sys.argv[0],*remaining])
