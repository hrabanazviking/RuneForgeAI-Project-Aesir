"""Portable adversarial strategy3 trace/resource contracts; never physical proof."""
from array import array
from contextlib import closing
import copy
import hashlib
import json
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest
from unittest.mock import patch

import check_turing_prefill_trace as check
import check_cuda_trace as cuda
from cuda_projection_ranges import attribute, resource_records, RESOURCE_FIELDS, PREFIXES, LARGE_PREFIX, STAGES, GEOMETRY
from test_check_cuda_trace import fixture as sqlite_fixture


class Contracts(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        self.path=self.root/'probe.csv';p=patch.object(check,'VOCABULARY',4);p.start();self.addCleanup(p.stop)
        self.golden=dict(input_ids=[1]*37,logits=array('f',[0,-0.,1,2]),guarded_cache_sha256='a'*64)
        self.text='[CUDA] api=cuda cpu_offload=0\nTRACE,1,3,1,123,aesir.fixture.prefill\nSTAGES,1\nSTATE,37,37,37,37\n'
        self.text+=''.join(f'INPUT,{i},1\n' for i in range(37))
        self.text+='LOGIT,0,0\nLOGIT,1,-0.0\nLOGIT,2,1\nLOGIT,3,2\nENQUEUE,252,421\nDOWN_ROWS128,28\nDOWN_TILE,128,32\nCACHE,176160832,'+'a'*64+'\nGUARD,1088,0\nCOMPLETE,prefill_trace,4\n'
        self.path.write_text(self.text)

    def parse(self,text=None):
        if text is not None:self.path.write_text(text)
        return check.parse(self.path,self.golden,1,True,allow_down=True)

    def test_only_explicit_down_source_with_complete_bits_and_counts(self):
        r=self.parse();self.assertTrue(r['passed']);self.assertEqual(r['attention_variant'],3);self.assertEqual(r['down128_host_enqueues'],28)
        with self.assertRaises(ValueError):check.parse(self.path,self.golden,1,True)
        with self.assertRaises(ValueError):check.parse(self.path,self.golden,1,False,allow_down=True)
        for before,after in [('TRACE,1,3','TRACE,1,2'),('DOWN_ROWS128,28','DOWN_ROWS128,27'),('DOWN_TILE,128,32','DOWN_TILE,256,32'),('STAGES,1\n',''),('STATE,37,37,37,37','STATE,37,36,37,37'),('INPUT,0,1','INPUT,0,2'),('ENQUEUE,252,421','ENQUEUE,252,420'),('DOWN_ROWS128,28\n',''),('DOWN_TILE,128,32','DOWN_TILE,128,32\nDOWN_TILE,128,32')]:
            with self.subTest(before=before),self.assertRaises((ValueError,StopIteration)):self.parse(self.text.replace(before,after))

    def test_complete_signed_zero_cache_and_numeric_failures_retained(self):
        for a,b in [('LOGIT,1,-0.0','LOGIT,1,0'),('LOGIT,3,2','LOGIT,3,2.125'),('a'*64,'c'*64)]:
            r=self.parse(self.text.replace(a,b));self.assertFalse(r['passed']);self.assertEqual(r['values'],4)
        with self.assertRaises(ValueError):self.parse(self.text.rstrip('\n'))

    def arguments(self,out):
        return ['check','--unprofiled',str(self.path),'--profiled',str(self.path),'--sqlite',str(self.path),'--binary',str(self.path),'--binary-sha256','b'*64,'--model',str(self.path),'--model-sha256','b'*64,'--reference-csv',str(self.path),'--reference-report',str(self.path),'--case','1','--projection-ranges','--down128','--output',str(out)]

    def test_source_gate_before_trace_and_explicit_range_before_source(self):
        for omit in (False,True):
            out=self.root/str(omit);args=self.arguments(out)
            if omit:args.remove('--projection-ranges')
            with patch.object(sys,'argv',args),patch.object(check,'digest',return_value='b'*64),patch.object(check,'accepted_model',side_effect=ValueError('independent source refused')) as source,patch.object(check,'analyze') as trace:
                self.assertEqual(check.main(),1);trace.assert_not_called()
                if omit:source.assert_not_called()
            self.assertFalse(json.loads(out.read_text())['speed_scored'])

    def test_every_after_hash_interrupt_and_exclusive_failed_report(self):
        proof=dict(attention_variant=3,csv_sha256='b'*64,report_sha256='b'*64)
        parsed=self.parse()
        for index in range(7):
            out=self.root/f'changed-{index}'
            hashes=['b'*64]*10;hashes[3+index]='c'*64
            with patch.object(sys,'argv',self.arguments(out)),patch.object(check,'digest',side_effect=hashes),patch.object(check,'accepted_model',return_value=(dict(csv_sha256='b'*64,cases=[self.golden]*4),proof)),patch.object(check,'parse',return_value=dict(parsed,csv_sha256='b'*64)),patch.object(check,'analyze',return_value=dict(gpu=dict(compute='7.5'))):
                self.assertEqual(check.main(),1)
            r=json.loads(out.read_text());self.assertTrue(r['collection_complete']);self.assertFalse(r['passed']);self.assertFalse(r['speed_scored']);self.assertIn('artifact changed',r['error'])
        out=self.root/'interrupted'
        with patch.object(sys,'argv',self.arguments(out)),patch.object(check,'digest',side_effect=KeyboardInterrupt):self.assertEqual(check.main(),1)
        r=json.loads(out.read_text());self.assertIn('KeyboardInterrupt',r['error']);before=out.read_bytes()
        with patch.object(sys,'argv',self.arguments(out)),self.assertRaises(FileExistsError):check.main()
        self.assertEqual(before,out.read_bytes())

    def geometry(self):
        self.outer=(100,100000,16777217);self.tiles={1:1,4:1,32:1};self.rows=[];self.launches={};self.kernels=[];self.resources={}
        for size in (32,4,1):
            for _ in range(28):
                for stage in STAGES:self.add(stage,size)
        self.add('head',1)

    def add(self,stage,size):
        start=110+len(self.rows)*100;self.rows.append((start,start+50,59,self.outer[2],None,f'aesir.project.{stage}.b{size}',None))
        prefix=LARGE_PREFIX if stage=='down' and size==32 else PREFIXES[0] if size==32 and stage not in ('key','value') else PREFIXES[1] if size in (4,32) else PREFIXES[2]
        tile=128 if prefix==LARGE_PREFIX else 64 if prefix==PREFIXES[0] else 4
        for _ in range(8 if size==32 and stage in ('key','value') else 1):
            c=len(self.kernels)+1;self.launches[c]=(start+1,start+2,self.outer[2]);self.kernels.append((c,prefix+'mock',start+70,start+80))
            self.resources[c]=dict(zip(RESOURCE_FIELDS,(255,19008 if prefix==LARGE_PREFIX else 10560,0,0,999,(GEOMETRY[stage][0]+tile-1)//tile,1,1,256 if prefix==LARGE_PREFIX else 128,1,1),strict=True))

    def attribute(self):return attribute(self.rows,{},self.outer,self.launches,self.kernels,self.tiles,down128=True,resources=self.resources)

    def test_source_selected_geometry_and_resource_distribution(self):
        self.geometry();r=self.attribute();g=r['groups']['down.b32'];self.assertEqual(g['kernel_count'],28)
        dist=g['recorded_resource_distributions'];self.assertEqual(len(dist),1);self.assertEqual(dist[0]['resources']['block_x'],256);self.assertEqual(dist[0]['resources']['legacy_local_bytes_total_deprecated'],999)
        self.assertEqual(r['groups']['key.b32']['kernel_count'],224)
        with self.assertRaises(ValueError):attribute(self.rows,{},self.outer,self.launches,self.kernels,self.tiles)

    def test_wrong_prefix_stage_geometry_and_order(self):
        for defect in ('prefix','block','grid','order','missing','thread','api','noninteger'):
            self.geometry();down=next(c for c,n,s,e in self.kernels if n.startswith(LARGE_PREFIX))
            if defect=='prefix':self.kernels[down-1]=(down,PREFIXES[0]+'mock',*self.kernels[down-1][2:])
            elif defect=='block':self.resources[down]['block_x']=128
            elif defect=='grid':self.resources[down]['grid_x']+=1
            elif defect=='order':
                a,b=self.rows[0],self.rows[1];self.rows[0]=(*a[:5],b[5],None);self.rows[1]=(*b[:5],a[5],None)
            elif defect=='missing':self.kernels.pop(down-1)
            elif defect=='noninteger':a=self.rows[0];self.rows[0]=(*a[:2],59.0,*a[3:])
            elif defect=='thread':a,b,c=self.launches[down];self.launches[down]=(a,b,c+1)
            else:a,b,c=self.launches[down];self.launches[down]=(a,b+100,c)
            with self.subTest(defect=defect),self.assertRaises(ValueError):self.attribute()

    def test_resource_integer_bounds_and_complete_correlations(self):
        row=(1,255,19008,0,0,999,24,1,1,256,1,1)
        self.assertEqual(resource_records([row],{1})[1]['block_x'],256)
        for i,value in [(1,256),(1,True),(2,-1),(4,1.5),(5,-1),(6,0),(9,0),(9,1025),(10,8)]:
            bad=list(row);bad[i]=value
            with self.subTest(i=i,value=value),self.assertRaises(ValueError):resource_records([bad],{1})
        for rows,correlations in [([], {1}),([row,row],{1}),([row],{1,2}),([row],{2})]:
            with self.assertRaises(ValueError):resource_records(rows,correlations)

    def database(self):
        dbpath=self.root/'capture.sqlite';sqlite_fixture(dbpath)
        with closing(sqlite3.connect(dbpath)) as db:
            db.executescript("CREATE TABLE NVTX_EVENTS(start,end,eventType,globalTid,endGlobalTid,text,textId); INSERT INTO NVTX_EVENTS VALUES(100,500,59,16777217,NULL,'aesir.fixture.prefill',NULL);")
            for k,value in zip(('registersPerThread','staticSharedMemory','dynamicSharedMemory','localMemoryPerThread','localMemoryTotal','gridX','gridY','gridZ','blockX','blockY','blockZ'),(255,10560,0,0,999,1,1,1,128,1,1),strict=True):
                db.execute('ALTER TABLE CUPTI_ACTIVITY_KIND_KERNEL ADD COLUMN '+k);db.execute('UPDATE CUPTI_ACTIVITY_KIND_KERNEL SET '+k+'=?',(value,))
            db.commit()
        return dbpath

    def analyze(self,p):return cuda.analyze(p,'aesir',expected_pid=1,nvtx_range=check.RANGE,projection_tiles={1:1,4:0,32:0},down128=True,record_resources=True)

    def test_full_session_resources_before_attribute_and_default_schema_preserved(self):
        p=self.database()
        with patch('cuda_projection_ranges.attribute',return_value=dict(passed=True)) as a:
            r=self.analyze(p);self.assertEqual(r['recorded_resource_kernel_count'],2);self.assertEqual(set(a.call_args.kwargs['resources']),{1,2})
        self.assertEqual(cuda.analyze(p)['kernel_count'],2)
        with closing(sqlite3.connect(p)) as db:db.execute('UPDATE CUPTI_ACTIVITY_KIND_KERNEL SET registersPerThread=256 WHERE correlationId=2');db.commit()
        with patch('cuda_projection_ranges.attribute') as a,self.assertRaises(ValueError):self.analyze(p)
        a.assert_not_called()

    def test_excluded_resources_and_foreign_owner_never_hidden(self):
        p=self.database()
        with closing(sqlite3.connect(p)) as db:
            db.execute('INSERT INTO CUPTI_ACTIVITY_KIND_RUNTIME VALUES(510,520,16777217,4,1,0)')
            db.execute('INSERT INTO CUPTI_ACTIVITY_KIND_KERNEL SELECT 530,630,deviceId,contextId,streamId,4,globalPid,shortName,registersPerThread,staticSharedMemory,dynamicSharedMemory,localMemoryPerThread,localMemoryTotal,gridX,gridY,gridZ,blockX,blockY,blockZ FROM CUPTI_ACTIVITY_KIND_KERNEL WHERE correlationId=1')
            db.commit()
        with patch('cuda_projection_ranges.attribute',return_value=dict(passed=True)) as a:
            r=self.analyze(p);self.assertEqual(r['excluded_kernel_count'],1);self.assertEqual(set(a.call_args.kwargs['resources']),{1,2,4})
        for column,value in [('registersPerThread',256),('globalPid',33554432)]:
            with closing(sqlite3.connect(p)) as db:
                db.execute('UPDATE CUPTI_ACTIVITY_KIND_KERNEL SET registersPerThread=255,globalPid=16777216 WHERE correlationId=4')
                db.execute('UPDATE CUPTI_ACTIVITY_KIND_KERNEL SET '+column+'=? WHERE correlationId=4',(value,));db.commit()
            with patch('cuda_projection_ranges.attribute') as a,self.assertRaises(ValueError):self.analyze(p)
            a.assert_not_called()

    def test_missing_resource_schema_fails_before_attribution(self):
        p=self.root/'missing.sqlite';sqlite_fixture(p)
        with closing(sqlite3.connect(p)) as db:
            db.executescript("CREATE TABLE NVTX_EVENTS(start,end,eventType,globalTid,endGlobalTid,text,textId); INSERT INTO NVTX_EVENTS VALUES(100,500,59,16777217,NULL,'aesir.fixture.prefill',NULL);")
        with patch('cuda_projection_ranges.attribute') as a,self.assertRaises(sqlite3.Error):self.analyze(p)
        a.assert_not_called()


if __name__=='__main__':unittest.main()
