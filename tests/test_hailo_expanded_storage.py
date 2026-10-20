#!/usr/bin/env python3
"""Independent inclusive interval sweep of expanded IR; no model execution."""
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
from test_hailo_semantic_plan import dense_fixture, MAX

CONFIG=argparse.Namespace()
DEFAULT=(2,1,2,4,64,65536,256,1048576,'synthetic assumptions; no measured hardware capacity')


def oracle(graph,policy):
    act,predicate,kv,index,alignment,weights,workspace,budget,provenance=policy
    sizes=[]
    intervals={'real':[],'predicate':[]}
    kv_bytes=input_bytes=0
    for value in graph['values']:
        role=value['storage']
        if role in ('source_weight','kv_view'):
            sizes.append(0)
            continue
        width=kv if role=='persistent_kv' else index if role=='index' else predicate if value['domain']=='predicate' else act
        size=(math.prod(value['shape'])*width+alignment-1)//alignment*alignment
        sizes.append(size)
        if role=='persistent_kv': kv_bytes+=size
        elif role=='index': input_bytes+=size
        else: intervals[value['domain']].append((value['producer'],value['last_use'],size))
    # Brute-force interval sums, independent of the production birth/death events.
    timeline={domain:[sum(size for start,end,size in rows if start<=i<=end)
                      for i in range(len(graph['operations'])+1)]
              for domain,rows in intervals.items()}
    live=[a+b for a,b in zip(timeline['real'],timeline['predicate'])]
    peak=max(live)
    total=kv_bytes+input_bytes+peak+weights+workspace
    return {'value_bytes':sizes,'real_live_bytes':timeline['real'],
        'predicate_live_bytes':timeline['predicate'],'activation_live_bytes':live,
        'persistent_kv_bytes':kv_bytes,'input_bytes':input_bytes,
        'peak_activation_bytes':peak,'peak_step':live.index(peak),
        'total_bytes':total,'within_supplied_budget':total<=budget}


class ExpandedStorage(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary=str(Path(CONFIG.binary).resolve(strict=True))
        cls.graph_binary=str(Path(CONFIG.graph_binary).resolve(strict=True))
        cls.api=str(Path(CONFIG.api_binary).resolve(strict=True))
        cls.temp=tempfile.TemporaryDirectory(prefix='aesir-expanded-storage-')
        cls.root=Path(cls.temp.name)
        cls.evidence=Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True,exist_ok=True)
        cls.records=[]
        cls.graphs={}

    @classmethod
    def tearDownClass(cls):
        (cls.evidence/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
        cls.temp.cleanup()
        print('Native child scopes: '+str(dict(Counter(x['scope'].split(':')[0] for x in cls.records))))

    def run_child(self,command,source,scope):
        before=hashlib.sha256(source.read_bytes()).hexdigest()
        result=subprocess.run(command,capture_output=True,text=True,timeout=15,
                              stdin=subprocess.DEVNULL,check=False)
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(),before)
        self.records.append({'scope':scope,'source_sha256':before,'returncode':result.returncode,
                             'stdout':result.stdout,'stderr':result.stderr})
        return result

    def invoke(self,generated=None,session=(3,0,16),policy=DEFAULT,trace=False):
        raw,weights,_=generated or dense_fixture()
        source=self.root/f'fixture-{len(self.records)}.gguf'
        source.write_bytes(raw)
        command=[self.binary,str(source),*map(str,session),*map(str,policy)]
        if trace:
            command=[CONFIG.strace,'-y','-o',str(self.evidence/'expanded-storage.strace'),
                     '-e','trace=openat,close,mmap,munmap,ioctl',*command]
        return self.run_child(command,source,'expanded_storage'),source,weights

    def accepts(self,generated=None,session=(3,0,16),policy=DEFAULT,trace=False):
        result,source,weights=self.invoke(generated,session,policy,trace)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        actual=json.loads(result.stdout)
        key=(hashlib.sha256(source.read_bytes()).hexdigest(),session)
        if key not in self.graphs:
            result=self.run_child([self.graph_binary,str(source),*map(str,session)],source,'expanded_graph')
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.graphs[key]=json.loads(result.stdout)
        graph=self.graphs[key]
        for name,value in oracle(graph,policy).items():
            self.assertEqual(actual[name],value,name)
        names=['activation_width','predicate_width','kv_width','index_width','alignment',
               'device_weight_bytes','workspace_bytes','budget_bytes','provenance']
        self.assertEqual(actual['assumptions'],dict(zip(names,policy)))
        self.assertEqual(actual['source_packed_weight_bytes'],sum(w['byte_count'] for w in weights.values()))
        self.assertEqual(actual['operation_count'],len(graph['operations']))
        self.assertEqual(actual['value_count'],len(graph['values']))
        self.assertTrue(actual['expanded_schedule_accounted'])
        self.assertTrue(actual['unresolved_costs'])
        for flag in ('hardware_fit_verified','device_allocation_performed','complete_lowering_resource_plan'):
            self.assertIs(actual[flag],False)
        return actual,graph

    def test_exact_expanded_intervals_widths_and_alignment(self):
        for session in ((3,0,16),(1,7,16),(4,5,16)):
            for act,pred,kv,index,alignment in ((1,1,2,8,1),(2,4,1,4,16),(4,2,4,8,64),(8,1,2,8,4096)):
                result,graph=self.accepts(dense_fixture(layers=2,value=3),session,
                    (act,pred,kv,index,alignment,*DEFAULT[5:]))
                self.assertEqual(len(result['activation_live_bytes']),100)
                for i,v in enumerate(graph['values']):
                    if v['storage'] in ('source_weight','kv_view'):
                        self.assertEqual(result['value_bytes'][i],0)
                self.assertEqual(sum(v['storage']=='kv_view' for v in graph['values']),4)
                self.assertEqual(sum(v['domain']=='predicate' for v in graph['values']),2)

    def test_predicates_are_charged_separately(self):
        a,graph=self.accepts(policy=(2,1,2,4,1,*DEFAULT[5:]))
        b,_=self.accepts(policy=(2,128,2,4,1,*DEFAULT[5:]))
        self.assertEqual(a['real_live_bytes'],b['real_live_bytes'])
        self.assertEqual([v*128 for v in a['predicate_live_bytes']],b['predicate_live_bytes'])
        self.assertGreater(b['total_bytes'],a['total_bytes'])
        for i,value in enumerate(graph['values']):
            if value['domain']=='predicate':
                self.assertEqual(b['value_bytes'][i],128*a['value_bytes'][i])

    def test_exact_budget_boundary_and_constant_sharing(self):
        base,_=self.accepts()
        for budget in (base['total_bytes']-1,base['total_bytes'],base['total_bytes']+1):
            actual,_=self.accepts(policy=(*DEFAULT[:7],budget,DEFAULT[8]))
            self.assertEqual(actual['within_supplied_budget'],budget>=base['total_bytes'])
        tied,_=self.accepts(dense_fixture(tied=True))
        self.assertLess(tied['source_packed_weight_bytes'],base['source_packed_weight_bytes'])
        self.assertEqual(tied['total_bytes'],base['total_bytes'])
        self.assertEqual(tied['activation_live_bytes'],base['activation_live_bytes'])

    def test_invalid_policy_and_product_rounding_aggregate_overflow(self):
        cases=[(0,0),(1,0),(2,0),(3,0),(4,0),(4,3),(5,0),(6,-1),(7,0),(8,''),
               (0,MAX),(1,MAX),(2,MAX),(3,MAX),(4,1<<62),(5,MAX),(6,MAX)]
        for index,value in cases:
            policy=list(DEFAULT); policy[index]=value
            result,_,_=self.invoke(policy=policy)
            self.assertNotEqual(result.returncode,0)
            self.assertEqual(result.stdout,'')

    def test_malformed_graph_refusals_and_returned_owner(self):
        source=self.root/'api.gguf'; source.write_bytes(dense_fixture()[0])
        modes=['unknown_domain','unknown_storage','hidden_predicate','false_predicate','select_domain','compare_arity',
               'alias_cycle','alias_extent','alias_role','alias_input','constant_identity','constant_map',
               'constant_activation','constant_shape','constant_extent','constant_packed_size','constant_total',
               'constant_kind','constant_domain','source_extent','source_map','missing_map','hidden_source_identity',
               'index_domain','persistent_lifetime','short_lifetime','long_lifetime','bad_producer','bad_input',
               'future_input','bad_output','duplicate_output','orphan','lost_export','export_lifetime','operation_weight','shape_product']
        for mode in modes:
            result=self.run_child([self.api,str(source),mode],source,'api_refusal:'+mode)
            self.assertNotEqual(result.returncode,0,mode)
            self.assertEqual(result.stdout,'')
            self.assertTrue(any(prefix in result.stderr for prefix in ("SourceInventory:", "ExpandedStorage:", "Packed GGUF:", "SemanticPlan:")),result.stderr)
        result=self.run_child([self.api,str(source),'ownership'],source,'ownership')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(result.stdout.strip(),'owned-expanded-storage-pass')

    def test_source_quantization_sizes_do_not_substitute_for_device_weights(self):
        totals=[]; source_sizes=[]
        for kind in (12,13,14,30):
            result,_=self.accepts(dense_fixture(hidden=256,key=64,value=64,ff=512,matrix_kind=kind))
            totals.append(result['total_bytes']); source_sizes.append(result['source_packed_weight_bytes'])
        self.assertEqual(len(set(totals)),1)
        self.assertEqual(len(set(source_sizes)),4)

    def test_read_only_no_inference_library_or_device(self):
        self.accepts(trace=True,policy=(*DEFAULT[:8],'test "quoted" / Æsir\nprovenance'))
        trace=(self.evidence/'expanded-storage.strace').read_text()
        self.assertIn('O_RDONLY',trace)
        self.assertIn('PROT_READ, MAP_PRIVATE',trace)
        self.assertIn('munmap(',trace)
        for forbidden in ('/dev/h1x-','libcuda','libhailort'):
            self.assertNotIn(forbidden,trace)


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    for name in ('binary','graph-binary','api-binary','strace','evidence'):
        parser.add_argument('--'+name,required=True)
    CONFIG,remaining=parser.parse_known_args()
    unittest.main(argv=[sys.argv[0],*remaining])
