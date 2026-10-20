#!/usr/bin/env python3
"""Independent interval-sweep resource oracle. No numerical model forward."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from test_hailo_semantic_plan import dense_fixture, MAX

CONFIG = argparse.Namespace()
DEFAULT = (2,2,4,64,65536,256,1048576,'synthetic test assumptions; not measured hardware')


def oracle(graph,policy):
    act,kv,index,alignment,weights,workspace,budget,provenance = policy
    sizes = []
    kv_bytes = input_bytes = 0
    activations = []
    for t in graph['tensors']:
        if t['alias_of'] >= 0:
            sizes.append(0)
            continue
        width = kv if t['persistent'] else index if t['producer'] == -1 else act
        size = (math.prod(t['shape'])*width + alignment-1)//alignment*alignment
        sizes.append(size)
        if t['persistent']:
            kv_bytes += size
        elif t['producer'] == -1:
            input_bytes += size
        else:
            activations.append((t['producer'],t['last_use'],size))
    # Independent brute-force inclusive interval sweep, not event bookkeeping.
    live = [sum(size for birth,death,size in activations if birth<=i<=death)
            for i in range(len(graph['operations'])+1)]
    peak = max(live)
    total = kv_bytes + input_bytes + peak + weights + workspace
    return {'tensor_bytes':sizes,'activation_live_bytes':live,'persistent_kv_bytes':kv_bytes,
        'input_bytes':input_bytes,'peak_activation_bytes':peak,'peak_step':live.index(peak),
        'total_bytes':total,'within_supplied_budget':total<=budget}


class StorageEstimate(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.graph_binary = str(Path(CONFIG.graph_binary).resolve(strict=True))
        cls.api_binary = str(Path(CONFIG.api_binary).resolve(strict=True))
        cls.temp = tempfile.TemporaryDirectory(prefix='aesir-storage-estimate-')
        cls.root = Path(cls.temp.name)
        cls.evidence = Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True,exist_ok=True)
        cls.records = []
        cls.graphs = {}

    @classmethod
    def tearDownClass(cls):
        (cls.evidence/'fixture-runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
        cls.temp.cleanup()

    def run_child(self,command,source,scope):
        before = hashlib.sha256(source.read_bytes()).hexdigest()
        result = subprocess.run(command,capture_output=True,text=True,timeout=15,
                                stdin=subprocess.DEVNULL,check=False)
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(),before)
        self.records.append({'scope':scope,'source_sha256':before,
            'returncode':result.returncode,'stdout':result.stdout,'stderr':result.stderr})
        return result

    def invoke(self,generated=None,session=(3,0,16),policy=DEFAULT,trace=False):
        raw,_,_ = generated or dense_fixture()
        source = self.root/f'fixture-{len(self.records)}.gguf'
        source.write_bytes(raw)
        command = [self.binary,str(source),*map(str,session),*map(str,policy)]
        if trace:
            command = [CONFIG.strace,'-y','-o',str(self.evidence/'storage.strace'),
                       '-e','trace=openat,close,mmap,munmap,ioctl',*command]
        result = self.run_child(command,source,'storage_estimate')
        return result,source

    def accepts(self,generated=None,session=(3,0,16),policy=DEFAULT,trace=False):
        result,source = self.invoke(generated,session,policy,trace)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        actual = json.loads(result.stdout)
        key = (hashlib.sha256(source.read_bytes()).hexdigest(),session)
        if key not in self.graphs:
            result = self.run_child([self.graph_binary,str(source),*map(str,session)],source,'semantic_graph')
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.graphs[key] = json.loads(result.stdout)
        graph = self.graphs[key]
        expected = oracle(graph,policy)
        for name,value in expected.items():
            self.assertEqual(actual[name],value,name)
        names = ['activation_width','kv_width','index_width','alignment','device_weight_bytes',
                 'workspace_bytes','budget_bytes','provenance']
        self.assertEqual(actual['assumptions'],dict(zip(names,policy)))
        self.assertEqual(actual['source_packed_weight_bytes'],graph['weight_bytes'])
        for flag in ('hardware_fit_verified','device_allocation_performed','complete_lowering_resource_plan'):
            self.assertIs(actual[flag],False)
        self.assertTrue(actual['unresolved_costs'])
        return actual,graph

    def test_exact_live_intervals_and_aliases_with_explicit_widths_and_alignment(self):
        for session in ((3,0,16),(1,7,16),(4,5,16)):
            for act,kv,index,alignment in ((1,2,8,1),(2,1,4,16),(4,4,8,64),(8,2,8,4096)):
                result,graph = self.accepts(dense_fixture(layers=2,value=3),session,
                    (act,kv,index,alignment,*DEFAULT[4:]))
                aliases = [i for i,t in enumerate(graph['tensors']) if t['alias_of'] >= 0]
                self.assertEqual(len(aliases),4)
                self.assertTrue(all(result['tensor_bytes'][i] == 0 for i in aliases))
                all_activations = sum(result['tensor_bytes'][i] for i,t in enumerate(graph['tensors'])
                                      if t['producer'] >= 0)
                self.assertLess(result['peak_activation_bytes'],all_activations)

    def test_exact_budget_boundary_is_only_a_scenario(self):
        result,_ = self.accepts()
        required = result['total_bytes']
        for budget in (required-1,required,required+1):
            policy = (*DEFAULT[:6],budget,DEFAULT[7])
            actual,_ = self.accepts(policy=policy)
            self.assertEqual(actual['within_supplied_budget'],budget>=required)
            self.assertFalse(actual['hardware_fit_verified'])

    def test_tied_source_weights_not_counted_as_converted_device_weights(self):
        separate,_ = self.accepts(dense_fixture(tied=False))
        tied,_ = self.accepts(dense_fixture(tied=True))
        self.assertLess(tied['source_packed_weight_bytes'],separate['source_packed_weight_bytes'])
        self.assertEqual(tied['total_bytes'],separate['total_bytes'])
        self.assertEqual(tied['assumptions']['device_weight_bytes'],65536)

    def test_invalid_missing_assumptions_and_overflow_refuse(self):
        cases = [(0,0),(1,0),(2,0),(3,0),(3,3),(4,0),(5,-1),(6,0),(7,''),
                 (0,MAX),(1,MAX),(2,MAX),(3,1<<62),(4,MAX),(5,MAX)]
        for index,value in cases:
            policy = list(DEFAULT)
            policy[index] = value
            result,_ = self.invoke(policy=policy)
            self.assertNotEqual(result.returncode,0)
            self.assertEqual(result.stdout,'')

    def test_mutated_graph_and_arithmetic_api_refusals(self):
        raw,_,_ = dense_fixture()
        source = self.root/'api-fixture.gguf'
        source.write_bytes(raw)
        cases = ['short_lifetime','forward_input','negative_input','bad_output','producer_mismatch',
                 'short_persistent','alias_cycle','alias_extent','wrong_elements','empty_shape',
                 'lost_result','round_overflow','product_overflow','sum_overflow']
        for case in cases:
            result = self.run_child([self.api_binary,str(source),case],source,'api_refusal:'+case)
            self.assertNotEqual(result.returncode,0,case)
            self.assertEqual(result.stdout,'')
            self.assertTrue('StorageEstimate:' in result.stderr or 'SemanticPlan:' in result.stderr)

    def test_quantization_does_not_invent_device_conversion_sizes(self):
        totals = []
        source_sizes = []
        for kind in (12,13,14,30):
            result,_ = self.accepts(dense_fixture(hidden=256,key=64,value=64,ff=512,matrix_kind=kind))
            totals.append(result['total_bytes'])
            source_sizes.append(result['source_packed_weight_bytes'])
        self.assertEqual(len(set(totals)),1)
        self.assertEqual(len(set(source_sizes)),4)

    def test_read_only_no_device_or_inference_library(self):
        self.accepts(trace=True,policy=(*DEFAULT[:7],'test "quotes" / Æsir\nprovenance'))
        trace = (self.evidence/'storage.strace').read_text()
        self.assertIn('O_RDONLY',trace)
        self.assertIn('PROT_READ, MAP_PRIVATE',trace)
        self.assertIn('munmap(',trace)
        for forbidden in ('/dev/h1x-','libcuda','libhailort'):
            self.assertNotIn(forbidden,trace)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    for name in ('binary','graph-binary','api-binary','strace','evidence'):
        parser.add_argument('--'+name,required=True)
    CONFIG,remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0],*remaining])
