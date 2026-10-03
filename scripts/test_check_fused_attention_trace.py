"""Reduced hostile owned fused trace contracts; never physical GPU proof."""
from contextlib import closing
import copy
import json
import sqlite3
import sys
import unittest
from unittest.mock import patch

import check_turing_prefill_trace as check
import check_cuda_trace as cuda
import check_turing_down_source as source_check
from cuda_fused_attention_ranges import attribute, FUSED_PREFIX
from cuda_projection_ranges import RESOURCE_FIELDS, STAGES
import test_check_turing_down_projection_trace as down_contracts
import test_check_fused_attention_controls_model as model_contracts


class Contracts(unittest.TestCase):
    def setUp(self):
        down_contracts.Contracts.setUp(self)
        self.text = self.text.replace('TRACE,1,3', 'TRACE,1,4').replace(
            'DOWN_TILE,128,32\n', 'DOWN_TILE,128,32\nFUSED_ATTENTION,56,28\n')
        self.path.write_text(self.text)

    def parse(self, text=None):
        if text is not None: self.path.write_text(text)
        return check.parse(self.path, self.golden, 1, True, allow_fused=True)

    def arguments(self, out):
        args = down_contracts.Contracts.arguments(self, out)
        args.remove('--down128')
        return args+['--fused-attention', '--reference-binary', str(self.root/'source-binary')]

    def test_explicit_capability_and_actual_source_bits_counts(self):
        r = self.parse()
        self.assertTrue(r['passed'])
        self.assertEqual((r['attention_variant'], r['fused_attention_host_enqueues'], r['original_attention_queries']), (4,56,28))
        for kwargs in ({}, dict(allow_down=True), dict(allow_fused=1), dict(allow_down=True, allow_fused=True)):
            with self.assertRaises(ValueError): check.parse(self.path, self.golden, 1, True, **kwargs)
        with self.assertRaises(ValueError): check.parse(self.path, self.golden, 1, False, allow_fused=True)
        for a,b in [('FUSED_ATTENTION,56,28','FUSED_ATTENTION,55,28'), ('FUSED_ATTENTION,56,28','FUSED_ATTENTION,56,29'),
                    ('FUSED_ATTENTION,56,28\n',''), ('FUSED_ATTENTION,56,28','FUSED_ATTENTION,56,28\nFUSED_ATTENTION,56,28'),
                    ('DOWN_ROWS128,28','DOWN_ROWS128,27'), ('STATE,37,37,37,37','STATE,37,37,36,37'),
                    ('INPUT,0,1','INPUT,0,2'), ('ENQUEUE,252,421','ENQUEUE,252,420'), ('STAGES,1\n','')]:
            with self.subTest(a=a), self.assertRaises((ValueError, StopIteration)): self.parse(self.text.replace(a,b))

    def test_signed_zero_cache_numeric_complete_failure(self):
        down_contracts.Contracts.test_complete_signed_zero_cache_and_numeric_failures_retained(self)

    def test_cli_requires_exclusive_ranges_actual_source_binary(self):
        for i, omission in enumerate(('ranges', 'binary', 'exclusive', 'source')):
            args = self.arguments(self.root/f'failed-{i}')
            if omission=='ranges': args.remove('--projection-ranges')
            elif omission=='binary': args=args[:-2]
            elif omission=='exclusive': args.append('--down128')
            with patch.object(sys,'argv',args), patch.object(check,'digest',return_value='b'*64), patch.object(check,'accepted_model',side_effect=ValueError('source refused')) as source, patch.object(check,'analyze') as trace:
                self.assertEqual(check.main(),1)
                trace.assert_not_called()
                if omission!='source': source.assert_not_called()
                else: self.assertEqual(source.call_args.kwargs, dict(fused=True,binary=self.root/'source-binary'))

    def test_after_hash_each_artifact_interrupt_and_exclusive(self):
        proof=dict(attention_variant=4,csv_sha256='b'*64,report_sha256='b'*64,binary_sha256='b'*64)
        parsed=self.parse()
        for i in range(8):
            out=self.root/f'changed-{i}'
            hashes=['b'*64]*11;hashes[3+i]='c'*64
            with patch.object(sys,'argv',self.arguments(out)), patch.object(check,'digest',side_effect=hashes), patch.object(check,'accepted_model',return_value=(dict(csv_sha256='b'*64,cases=[self.golden]*4),proof)), patch.object(check,'parse',return_value=dict(parsed,csv_sha256='b'*64)), patch.object(check,'analyze',return_value=dict(gpu=dict(compute='7.5'))) as trace:
                self.assertEqual(check.main(),1)
                self.assertTrue(trace.call_args.kwargs['fused_attention'])
                self.assertTrue(trace.call_args.kwargs['down128'])
            r=json.loads(out.read_text());self.assertTrue(r['collection_complete']);self.assertFalse(r['passed']);self.assertIn('artifact changed',r['error'])
        out=self.root/'interrupt'
        with patch.object(sys,'argv',self.arguments(out)), patch.object(check,'digest',side_effect=KeyboardInterrupt): self.assertEqual(check.main(),1)
        self.assertIn('KeyboardInterrupt',json.loads(out.read_text())['error']);before=out.read_bytes()
        with patch.object(sys,'argv',self.arguments(out)), self.assertRaises(FileExistsError): check.main()
        self.assertEqual(out.read_bytes(),before)

    add = down_contracts.Contracts.add

    def geometry(self):
        self.outer=(100,100000,16777217);self.tiles={1:1,4:1,32:1}
        self.rows=[];self.launches={};self.kernels=[];self.resources={}
        for size in (32,4,1):
            for _ in range(28):
                for stage in STAGES:
                    self.add(stage,size)
                    if stage=='value' and size!=1:
                        start=110+len(self.rows)*100
                        self.rows.append((start,start+50,59,self.outer[2],None,f'aesir.attend.fused.b{size}',None))
                        c=len(self.kernels)+1
                        self.launches[c]=(start+1,start+2,self.outer[2])
                        self.kernels.append((c,FUSED_PREFIX+'mock',start+70,start+80))
                        self.resources[c]=dict(zip(RESOURCE_FIELDS,(64,16384,0,0,999,24,size,1,128,1,1),strict=True))
        self.add('head',1)

    def attribute(self):
        return attribute(self.rows,{},self.outer,self.launches,self.kernels,self.tiles,self.resources)

    def test_exact_counts_geometry_resources_and_async_interval(self):
        self.geometry();r=self.attribute()
        self.assertEqual((r['cpu_range_count'],r['kernel_count'],r['attention_variant']),(56,56,4))
        d=r['groups']['fused.b32']['recorded_resource_distributions'][0]
        self.assertEqual(d['resources']['grid_y'],32);self.assertEqual(d['resources']['static_shared_bytes'],16384)
        self.assertEqual(d['gpu_total_ns'],280)  # GPU begins after CPU child exits; retained whole.

    def test_range_owner_order_count_overlap_and_namespace(self):
        for defect in ('missing','duplicate','overlap','order','thread','endthread','kind','textid','namespace','bounds','foreign-batch'):
            self.geometry();i=next(i for i,r in enumerate(self.rows) if r[5]=='aesir.attend.fused.b32');row=list(self.rows[i])
            if defect=='missing':self.rows.pop(i)
            elif defect=='duplicate':self.rows.append(tuple(row))
            elif defect=='overlap':row[0]=self.rows[i-1][0]
            elif defect=='order':row[:2]=[self.rows[i+1][0]+51,self.rows[i+1][0]+99]
            elif defect=='thread':row[3]+=1
            elif defect=='endthread':row[4]=row[3]+1
            elif defect=='kind':row[2]=59.0
            elif defect=='textid':row[6]=True
            elif defect=='namespace':row[5]='aesir.attend.unowned.b32'
            elif defect=='bounds':row[0]=99
            else:row[5]='aesir.attend.fused.b1'
            if defect not in ('missing','duplicate'):self.rows[i]=tuple(row)
            with self.subTest(defect=defect), self.assertRaises(ValueError):self.attribute()

    def test_actual_kernel_correlations_identity_thread_and_geometry(self):
        for defect in ('prefix','missing','duplicate','api','thread','unowned','grid','block','float','second'):
            self.geometry();i=next(i for i,r in enumerate(self.kernels) if r[1].startswith(FUSED_PREFIX));c,name,start,end=self.kernels[i]
            if defect=='prefix':self.kernels[i]=(c,'foreign_kernel',start,end)
            elif defect=='missing':self.kernels.pop(i)
            elif defect=='duplicate':self.kernels.append(self.kernels[i])
            elif defect=='api':a,b,t=self.launches[c];self.launches[c]=(a,b+100,t)
            elif defect=='thread':a,b,t=self.launches[c];self.launches[c]=(a,b,t+1)
            elif defect=='unowned':self.launches[c]=(101,102,self.outer[2])
            elif defect=='grid':self.resources[c]['grid_y']=4
            elif defect=='block':self.resources[c]['block_x']=64
            elif defect=='float':self.resources[c]['grid_x']=24.0
            else:
                d=len(self.kernels)+1;self.kernels.append((d,name,start,end));self.launches[d]=self.launches[c];self.resources[d]=copy.deepcopy(self.resources[c])
            with self.subTest(defect=defect), self.assertRaises(ValueError):self.attribute()

    database=down_contracts.Contracts.database

    def analyze(self,p):
        return cuda.analyze(p,'aesir',expected_pid=1,nvtx_range=check.RANGE,projection_tiles={1:1,4:0,32:0},down128=True,record_resources=True,fused_attention=True)

    def test_full_session_before_both_attributions_and_default_closed(self):
        p=self.database()
        with patch('cuda_projection_ranges.attribute',return_value=dict(passed=True)), patch('cuda_fused_attention_ranges.attribute',return_value=dict(passed=True)) as a:
            r=self.analyze(p);self.assertEqual(r['projection_attribution']['attention_variant'],4)
            self.assertEqual(set(a.call_args.args[-1]),{1,2})
        self.assertNotIn('fused_attention_attribution',cuda.analyze(p))
        for kwargs in (dict(fused_attention=1),dict(fused_attention=True),dict(fused_attention=True,down128=True,record_resources=True)):
            with self.assertRaises(ValueError):cuda.analyze(p,**kwargs)
        with closing(sqlite3.connect(p)) as db:
            db.execute('INSERT INTO CUPTI_ACTIVITY_KIND_RUNTIME VALUES(510,520,16777217,4,1,0)')
            db.execute('INSERT INTO CUPTI_ACTIVITY_KIND_KERNEL SELECT 530,630,deviceId,contextId,streamId,4,globalPid,shortName,registersPerThread,staticSharedMemory,dynamicSharedMemory,localMemoryPerThread,localMemoryTotal,gridX,gridY,gridZ,blockX,blockY,blockZ FROM CUPTI_ACTIVITY_KIND_KERNEL WHERE correlationId=1')
            db.commit()
        with patch('cuda_projection_ranges.attribute',return_value=dict(passed=True)),patch('cuda_fused_attention_ranges.attribute',return_value=dict(passed=True)) as a:
            r=self.analyze(p);self.assertEqual(r['excluded_kernel_count'],1);self.assertEqual(set(a.call_args.args[-1]),{1,2,4})
        for column,value in [('registersPerThread',256),('globalPid',33554432),('blockX',0)]:
            with closing(sqlite3.connect(p)) as db:
                db.execute('UPDATE CUPTI_ACTIVITY_KIND_KERNEL SET registersPerThread=255,globalPid=16777216,blockX=128 WHERE correlationId=4')
                db.execute('UPDATE CUPTI_ACTIVITY_KIND_KERNEL SET '+column+'=? WHERE correlationId=4',(value,));db.commit()
            with patch('cuda_projection_ranges.attribute') as a,patch('cuda_fused_attention_ranges.attribute') as b,self.assertRaises(ValueError):self.analyze(p)
            a.assert_not_called();b.assert_not_called()

    def test_real_source_requires_closed_capability_complete_cpu_prior_binary(self):
        harness=model_contracts.Contracts('test_source_complete_predecessor_and_cpu_scope');harness.setUp();self.addCleanup(harness.doCleanups)
        p=patch.object(source_check,'VOCABULARY',4);p.start();self.addCleanup(p.stop)
        csv,path,proof=harness.proof()
        self.assertTrue(source_check.accepted_model(csv,path,'a'*64,fused=True,binary=harness.previous_binary)[1]['passed'])
        for mutate in (lambda r:r.update(control_capable=True),lambda r:r.update(binary_sha256='0'*64),
                       lambda r:r['independent_reference'].update(threads=8),lambda r:r['fixture_reference'].update(attention_variant=4),
                       lambda r:r['fixture_reference']['cases'][0].update(matrix_f32_bytes_equal=False),
                       lambda r:r['cases'][0].update(fused_attention_host_enqueues=1)):
            r=copy.deepcopy(proof);mutate(r);path.write_text(json.dumps(r))
            with self.assertRaises(ValueError):source_check.accepted_model(csv,path,'a'*64,fused=True,binary=harness.previous_binary)


if __name__=='__main__': unittest.main()
