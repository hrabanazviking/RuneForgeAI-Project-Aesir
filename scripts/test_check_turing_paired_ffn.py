"""Reduced portable pair admission contracts, never physical GPU evidence."""
from contextlib import ExitStack
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import check_turing_paired_ffn as check


def fixture():
    text='MODE,turing_pair_gate_up,64,32\nSPANS,12,0\n[CUDA] api=cuda cpu_offload=0\nSYNTHETIC,144,0\n'
    for i,b in enumerate(check.BATCHES):
        text+=f'CASE,{i},{b},2,256,12,32,4096\n'
        for side in range(2):
            for token in range(b):
                for row in range(2):text+=f'VALUE,{i},{side},{token},{row},1,1,1\n'
        text+=f'GUARD,{i},{292*b},0\n'
        for sample in range(10):
            for step in range(3):text+=f'TIME,{i},{(sample+step)%3},{sample},3,0.001\n'
    return text+'COMPLETE,pair,4,240,120\n'


def oracle():
    metric=dict(passed=True,maximum_scaled_error=0,normalized_rms=0)
    return [dict(index=i,sides=[dict(name=n,outputs=2*b,native=metric.copy(),candidate=metric.copy(),original=metric.copy()) for n in check.NAMES]) for i,b in enumerate(check.BATCHES)]


class Contracts(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name);self.path=self.root/'pair.csv'
        for name,value in [('ROWS',2),('COLUMNS',256)]:
            p=patch.object(check,name,value);p.start();self.addCleanup(p.stop)
        self.text=fixture();self.path.write_text(self.text)

    def parse(self,text=None):
        if text is not None:self.path.write_text(text)
        return check.parse(self.path)

    def test_complete_two_outputs_three_owners_and_timing_rotation(self):
        data=self.parse();r=check.summarize(data,oracle());self.assertTrue(r['passed']);self.assertEqual(r['values_per_owner'],240)
        self.assertEqual(len(r['cases']),4);self.assertEqual(r['independent_outputs'],240);self.assertFalse(r['full_model_speed_claim']);self.assertFalse(r['speed_promoted'])
        self.assertTrue(all(c['original_f32_bits_equal']==[True,True] and c['original_to_pair_ratio']==1 for c in r['cases']))

    def test_geometry_actual_span_cuda_descriptor_identity(self):
        for before,after in [('turing_pair_gate_up,64,32','turing_pair_gate_up,128,32'),('SPANS,12,0','SPANS,11,0'),('cpu_offload=0','cpu_offload=1'),('SYNTHETIC,144,0','SYNTHETIC,143,0'),('CASE,0,4,2,256,12,32,4096','CASE,0,4,2,256,13,32,4096'),('32,4096','32,33'),('CASE,1,8','CASE,1,16')]:
            with self.subTest(before=before),self.assertRaises((ValueError,StopIteration)):self.parse(self.text.replace(before,after,1))

    def test_missing_duplicate_unknown_signed_order_and_total(self):
        for text in [self.text.replace('VALUE,0,0,0,0,1,1,1\n','',1),self.text.replace('VALUE,0,0,0,0,1,1,1','VALUE,0,1,0,0,1,1,1',1),self.text+'EXTRA\n',self.text.replace('COMPLETE,pair,4,240,120','COMPLETE,pair,4,239,120'),self.text.replace('GUARD,0,1168,0','GUARD,0,1168,1'),self.text.rstrip('\n')]:
            with self.assertRaises((ValueError,StopIteration)):self.parse(text)

    def test_full_signed_zero_and_numeric_failures_clear_every_ratio(self):
        for values in ('0,-0.0,0','1,1.125,1'):
            r=check.summarize(self.parse(self.text.replace('VALUE,0,0,0,0,1,1,1','VALUE,0,0,0,0,'+values,1)),oracle())
            self.assertFalse(r['passed']);self.assertTrue(r['collection_complete']);self.assertEqual(r['values_per_owner'],240)
            self.assertTrue(all(c['original_to_pair_ratio'] is None and c['native_to_pair_ratio'] is None for c in r['cases']))

    def test_nonfinite_nonexact_f32_and_integer_grammar(self):
        for a,b in [('VALUE,0,0,0,0,1,1,1','VALUE,0,0,0,0,1,nan,1'),('VALUE,0,0,0,0,1,1,1','VALUE,0,0,0,0,1,2.1,1'),('32,4096','-1,4096'),('32,4096','032,4096'),('32,4096','12345678901234567890,4096')]:
            with self.assertRaises(ValueError):self.parse(self.text.replace(a,b,1))

    def test_timing_ownership_counts_underflow_and_overflow(self):
        for a,b in [('TIME,0,2,0,3,0.001','TIME,0,1,0,3,0.001'),('TIME,0,0,0,3,0.001','TIME,0,0,0,4,0.001'),('TIME,0,0,0,3,0.001','TIME,0,0,0,3,5e-324')]:
            with self.assertRaises(ValueError):self.parse(self.text.replace(a,b,1))
        data=self.parse(self.text)
        for c in data['cases']:c['timings'][1]=[1e-323]*10
        r=check.summarize(data,oracle());self.assertFalse(r['passed']);self.assertEqual(len(r['cases']),4);self.assertIn('Nonfinite',r['error']);self.assertTrue(all(c['original_to_pair_ratio'] is None for c in r['cases']))

    def test_independent_failure_is_complete_and_unscored(self):
        o=oracle();o[-1]['sides'][-1]['original']['passed']=False;r=check.summarize(self.parse(),o)
        self.assertFalse(r['passed']);self.assertEqual(len(r['cases']),4);self.assertEqual(len(r['oracle']),4)
        self.assertTrue(all(c['original_to_pair_ratio'] is None for c in r['cases']))

    def test_special_and_oversized_input(self):
        import os
        p=self.root/'fifo';os.mkfifo(p)
        with self.assertRaises(ValueError):check.parse(p)
        p=self.root/'link';p.symlink_to(self.path)
        with self.assertRaises(OSError):check.parse(p)
        with self.assertRaises(ValueError):self.parse(self.text+'x'*1025+'\n')

    def arguments(self,out):
        return ['check',str(self.path),'--model',str(self.root/'model'),'--model-sha256','a'*64,'--binary',str(self.root/'binary'),'--binary-sha256','b'*64,'--output',str(out)]

    def test_all_after_hash_changes_keep_complete_failure(self):
        for changed in ('model','binary','pair.csv'):
            out=self.root/(changed+'.json');counts={};self.path.write_text(self.text)
            hashes={self.root/'model':'a'*64,self.root/'binary':'b'*64,self.path:hashlib.sha256(self.text.encode()).hexdigest()}
            def digest(p):
                counts[p]=counts.get(p,0)+1
                return 'c'*64 if p.name==changed and counts[p]>=(1 if changed=='pair.csv' else 2) else hashes[p]
            with patch.object(sys,'argv',self.arguments(out)),patch.object(check,'digest',side_effect=digest),patch.object(check,'independent',return_value=oracle()):self.assertEqual(check.main(),1)
            r=json.loads(out.read_text());self.assertTrue(r['collection_complete']);self.assertFalse(r['passed']);self.assertIn('changed during',r['error']);self.assertEqual(len(r['cases']),4);self.assertTrue(all(c['original_to_pair_ratio'] is None for c in r['cases']))

    def test_initial_identity_interrupt_and_exclusive_report(self):
        for name,side_effect in [('identity',lambda _: 'c'*64),('interrupt',KeyboardInterrupt)]:
            out=self.root/name
            with patch.object(sys,'argv',self.arguments(out)),patch.object(check,'digest',side_effect=side_effect),patch.object(check,'independent') as o:
                self.assertEqual(check.main(),1);o.assert_not_called()
            r=json.loads(out.read_text());self.assertFalse(r['passed']);self.assertFalse(r['full_model_speed_claim']);before=out.read_bytes()
            with patch.object(sys,'argv',self.arguments(out)),self.assertRaises(FileExistsError):check.main()
            self.assertEqual(before,out.read_bytes())


if __name__=='__main__':unittest.main()
