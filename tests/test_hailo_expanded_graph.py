#!/usr/bin/env python3
"""Independent source/local/global edge and interval checks, no math execution."""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from test_hailo_semantic_plan import dense_fixture

CONFIG=argparse.Namespace()


class ExpandedGraph(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary=str(Path(CONFIG.binary).resolve(strict=True))
        cls.source_binary=str(Path(CONFIG.source_binary).resolve(strict=True))
        cls.recipe_binary=str(Path(CONFIG.recipe_binary).resolve(strict=True))
        cls.api=str(Path(CONFIG.api_binary).resolve(strict=True))
        cls.temp=tempfile.TemporaryDirectory(prefix='aesir-expanded-graph-')
        cls.root=Path(cls.temp.name)
        cls.evidence=Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True,exist_ok=True)
        cls.records=[]

    @classmethod
    def tearDownClass(cls):
        (cls.evidence/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
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

    def accepts(self,fixture=None,session=(2,0,16),trace=False,repeat=False):
        raw,bindings,_=fixture or dense_fixture()
        source=self.root/f'fixture-{len(self.records)}.gguf'
        source.write_bytes(raw)
        command=[self.binary,str(source),*map(str,session)]
        if trace:
            command=[CONFIG.strace,'-y','-o',str(self.evidence/'expanded.strace'),
                     '-e','trace=openat,close,mmap,munmap,ioctl',*command]
        result=self.run_child(command,source,'expanded')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        actual=json.loads(result.stdout)
        if repeat:
            again=self.run_child([self.binary,str(source),*map(str,session)],source,'expanded_repeat')
            self.assertEqual(again.stdout,result.stdout)
            self.assertEqual(again.returncode,0,again.stderr)
        originals=[]
        for binary,scope in ((self.source_binary,'source'),(self.recipe_binary,'recipes')):
            result=self.run_child([binary,str(source),*map(str,session)],source,scope)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            originals.append(json.loads(result.stdout))
        self.check_integration(actual,*originals,bindings)
        return actual,originals[0]

    def check_integration(self,actual,source,recipes,bindings):
        values,ops,mapping=actual['values'],actual['operations'],actual['source_to_global']
        for flag in ('executable_program','device_execution_verified','source_fingerprint_verified','expanded_storage_recomputed'):
            self.assertIs(actual[flag],False)
        self.assertTrue(actual['unresolved_gates'])
        self.assertEqual(len(mapping),len(source['tensors']))
        self.assertEqual(len(set(mapping)),len(mapping))
        self.assertEqual(actual['result'],mapping[source['logits']])
        self.assertEqual(set(actual['weights']),set(bindings))
        self.assertEqual(actual['unexpanded_source_operations'],recipes['remaining_source_operations'])
        for old,tensor in enumerate(source['tensors']):
            mapped=values[mapping[old]]
            self.assertEqual(mapped['source_tensor'],old)
            self.assertEqual(mapped['name'],tensor['name'])
            self.assertEqual(mapped['shape'],tensor['shape'])
            self.assertEqual(mapped['elements'],tensor['elements'])
            if tensor['alias_of']!=-1:
                self.assertEqual(mapped['alias_of'],mapping[tensor['alias_of']])
                self.assertEqual(mapped['storage'],'kv_view')
            if tensor['persistent']:
                self.assertEqual(mapped['storage'],'persistent_kv')
            elif tensor['producer']==-1:
                self.assertEqual(mapped['storage'],'index')
                self.assertEqual(mapped['domain'],'index')
        norm_weights={r['weight_name'] for r in recipes['recipes'] if r['weight_name']}
        for name,binding in bindings.items():
            entry=actual['weights'][name]
            self.assertEqual({k:v for k,v in entry.items() if k!='value'},binding)
            constant=values[entry['value']]
            self.assertEqual(constant['source_weight'],name)
            self.assertEqual(constant['storage'],'source_weight')
            shape=[binding['columns']] if name in norm_weights else [binding['rows'],binding['columns']]
            self.assertEqual(constant['shape'],shape)
        by_source={}
        for step,op in enumerate(ops):
            self.assertEqual(op['id'],step)
            by_source.setdefault(op['source_operation'],[]).append(op)
        # Entire source traversal order and local recipe order must survive.
        recipe_map={r['source_operation']:r for r in recipes['recipes']}
        expected_order=[]
        for i,source_op in enumerate(source['operations']):
            group=by_source[i]
            expected_order.extend([i]*len(group))
            if i not in recipe_map:
                self.assertEqual(len(group),1)
                op=group[0]
                expected_inputs=[mapping[t] for t in source_op['inputs']]
                if source_op['weight']:
                    expected_inputs.append(actual['weights'][source_op['weight']]['value'])
                self.assertEqual(op['inputs'],expected_inputs)
                self.assertEqual(op['output'],mapping[source_op['output']])
                self.assertEqual(op['kind'],source_op['kind'])
                self.assertEqual(op['recipe_step'],-1)
                self.assertEqual(op['source_weight'],source_op['weight'])
                self.assertEqual(op['runtime_preconditions'],[])
            else:
                recipe=recipe_map[i]
                self.assertEqual(len(group),len(recipe['operations']))
                local={0:mapping[recipe['source_input']]}
                if recipe['weight_name']:
                    local[1]=actual['weights'][recipe['weight_name']]['value']
                for j,(op,original) in enumerate(zip(group,recipe['operations'])):
                    self.assertEqual(op['recipe_step'],j)
                    self.assertEqual(op['kind'],original['kind'])
                    self.assertEqual(op['inputs'],[local[t] for t in original['inputs']])
                    local[original['output']]=op['output']
                    self.assertEqual(values[op['output']]['shape'],recipe['values'][original['output']]['shape'])
                    self.assertEqual(values[op['output']]['domain'],recipe['values'][original['output']]['domain'])
                    self.assertEqual(op['width'],recipe['divisor'])
                    self.assertEqual(op['epsilon_bits'],recipe['epsilon_bits'])
                    self.assertEqual(op['runtime_preconditions'],recipe['runtime_preconditions'])
                self.assertEqual(local[recipe['result']],mapping[source_op['output']])
        self.assertEqual([op['source_operation'] for op in ops],expected_order)
        uses={i:[] for i in range(len(values))}
        produced={}
        for step,op in enumerate(ops):
            self.assertNotIn(op['output'],produced)
            produced[op['output']]=step
            for input_id in op['inputs']:
                self.assertLess(values[input_id]['producer'],step)
                uses[input_id].append(step)
        for i,value in enumerate(values):
            self.assertEqual(value['id'],i)
            self.assertEqual(value['elements'],math.prod(value['shape']))
            self.assertEqual(value['producer'],produced.get(i,-1))
            retained=value['storage'] in ('persistent_kv','source_weight') or i==actual['result']
            expected_end=len(ops) if retained else max(uses[i],default=value['producer'])
            self.assertEqual(value['last_use'],expected_end)
            if value['alias_of']>=0:
                base=values[value['alias_of']]
                self.assertEqual(base['storage'],'persistent_kv')
                self.assertGreaterEqual(base['elements'],value['elements'])
        layers=source['parameters']['layers']
        self.assertEqual(len(ops),45*layers+9)
        self.assertEqual(len(values),len(ops)+2+2*layers+len(bindings))
        self.assertEqual(sum(v['domain']=='predicate' for v in values),layers)

    def test_global_edges_constants_aliases_and_new_lifetimes(self):
        for layers in (1,2):
            for session in ((2,0,16),(1,7,16),(3,4,16)):
                self.accepts(dense_fixture(layers=layers,value=3,tied=True),session)

    def test_separate_output_and_deterministic_repetition(self):
        self.accepts(repeat=True)

    def test_exact_source_kinds_and_scalar_parameters(self):
        self.accepts(dense_fixture(overrides={'llama.attention.layer_norm_rms_epsilon':(6,0.0003)}))
        self.accepts(dense_fixture(hidden=256,key=64,value=64,ff=512,matrix_kind=12))

    def test_native_mutation_refusals_and_returned_ownership(self):
        source=self.root/'api.gguf'; source.write_bytes(dense_fixture()[0])
        for mode in ('bad_output','duplicate_output','unmapped_input','short_index_lifetime',
                     'index_shape','external_domain','persistent_lifetime','alias_self','alias_extent',
                     'bad_weight','weight_extent','orphan','lost_export'):
            result=self.run_child([self.api,str(source),mode],source,'api_refusal:'+mode)
            self.assertNotEqual(result.returncode,0,mode)
            self.assertEqual(result.stdout,'')
            self.assertTrue(any(prefix in result.stderr for prefix in ("SourceInventory:", "ExpandedGraph:", "PrimitiveRecipe:")), result.stderr)
        result=self.run_child([self.api,str(source),'ownership'],source,'ownership')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(result.stdout.strip(),'owned-expanded-graph-pass')

    def test_read_only_without_device_or_model_math(self):
        self.accepts(trace=True)
        trace=(self.evidence/'expanded.strace').read_text()
        self.assertIn('O_RDONLY',trace)
        self.assertIn('PROT_READ, MAP_PRIVATE',trace)
        for forbidden in ('/dev/h1x-','libcuda','libhailort'):
            self.assertNotIn(forbidden,trace)


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    for name in ('binary','source-binary','recipe-binary','api-binary','strace','evidence'):
        parser.add_argument('--'+name,required=True)
    CONFIG,remaining=parser.parse_known_args()
    unittest.main(argv=[sys.argv[0],*remaining])
