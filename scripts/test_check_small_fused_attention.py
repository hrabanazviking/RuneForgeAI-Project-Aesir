"""Reduced adversarial attention evidence contracts; not physical GPU proof."""
import hashlib,json,os
from pathlib import Path
import sys,tempfile,unittest
from unittest.mock import patch
import check_small_fused_attention as check


def fixture():
    text='MODE,small_shared_attention,24,8,128,1536,4096\nSPANS,17,0\nCUDA,0,cuda,1,0\nPID,123\n';values=0
    for i,(b,end,tokens,cap) in enumerate(check.geometry()):
        text+=f'CASE,{i},{b},{tokens},{cap},{end-tokens},{i%3}\n'
        for token in range(tokens):
            for head in range(check.HEADS):
                for col in range(check.DIM):text+=f'VALUE,{i},{token},{head},{col},1,1\n';values+=1
        text+=f'INPUT,{i},{tokens*3072},{2*cap*1024},0\nGUARD,{i},{check.guard_count(b,tokens,cap,end)},0\n'
        for sample in range(10):
            for step in range(2):text+=f'TIME,{i},{(sample+step)%2},{sample},3,0.001\n'
    return text+f'COMPLETE,attention,{len(check.geometry())},{values},{len(check.geometry())*20}\n'


def oracle(data):
    metric=dict(passed=True,maximum_scaled_error=0,normalized_rms=0)
    return [dict(index=c['index'],outputs=len(c['native']),native=metric.copy(),candidate=metric.copy()) for c in data['cases']]


class Contracts(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name);self.path=self.root/'capture.csv'
        for name,value in [('BATCHES',(1,4)),('ENDPOINTS',(1,3,4)),('HEADS',2),('KV_HEADS',1),('DIM',2)]:
            p=patch.object(check,name,value);p.start();self.addCleanup(p.stop)
        self.text=fixture();self.path.write_text(self.text)

    def parse(self,text=None):
        if text is not None:self.path.write_text(text)
        return check.parse(self.path)

    def test_complete_ownership_and_rotated_timing(self):
        data=self.parse();r=check.summarize(data,oracle(data));self.assertTrue(r['passed']);self.assertEqual(len(r['cases']),6);self.assertEqual(r['values_per_owner'],44);self.assertEqual(r['independent_outputs'],44)
        self.assertFalse(r['speed_promoted']);self.assertFalse(r['full_model_speed_claim']);self.assertTrue(all(c['original_to_small_ratio']==1 and c['original_f32_bits_equal'] for c in r['cases']))

    def test_profile_is_unscored_and_capacity_independent(self):
        data=self.parse();r=check.summarize(data,oracle(data),unscored=True)
        self.assertTrue(r['passed']);self.assertFalse(r['speed_scored']);self.assertTrue(all(c['original_to_small_ratio'] is None for c in r['cases']))
        with self.assertRaises(ValueError):check.summarize(data,oracle(data),unscored=1)
        with patch.object(check,'ENDPOINTS',(1536,)):
            self.assertTrue(all(c[3]==4096 for c in check.geometry()))

    def test_geometry_causal_mode_and_scope(self):
        for a,b in [('small_shared_attention,24,8,128,1536,4096','fused_shared_attention,24,8,128,4096,1'),('SPANS,17,0','SPANS,16,0'),('PID,123','PID,0'),('PID,123','PID,1.0'),('PID,123\n',''),('CUDA,0,cuda,1,0','CUDA,0,cuda,1,1'),('CASE,0,1,1,14,0,0','CASE,0,1,1,14,1,0'),('CASE,3,4,1,14,0,0','CASE,3,4,2,14,0,0')]:
            with self.subTest(a=a),self.assertRaises((ValueError,StopIteration)):self.parse(self.text.replace(a,b,1))

    def test_missing_duplicate_order_total_and_full_inputs(self):
        for text in [self.text.replace('VALUE,0,0,0,0,1,1\n','',1),self.text.replace('VALUE,0,0,0,0,1,1','VALUE,0,0,1,0,1,1',1),self.text+'EXTRA\n',self.text.rstrip('\n'),self.text.replace('INPUT,0,3072,28672,0','INPUT,0,3072,28672,1'),self.text.replace('COMPLETE,attention,6,44,120','COMPLETE,attention,6,43,120'),self.text.replace(f'GUARD,0,{check.guard_count(1,1,14,1)},0',f'GUARD,0,{check.guard_count(1,1,14,1)},1'),self.text.replace(f'GUARD,0,{check.guard_count(1,1,14,1)},0',f'GUARD,0,{check.guard_count(1,1,14,1)-24},0')]:
            with self.assertRaises((ValueError,StopIteration)):self.parse(text)

    def test_signed_zero_and_independent_failure_clear_all_scores(self):
        data=self.parse(self.text.replace('VALUE,0,0,0,0,1,1','VALUE,0,0,0,0,0,-0.0',1));r=check.summarize(data,oracle(data));self.assertFalse(r['passed']);self.assertTrue(r['collection_complete']);self.assertEqual(len(r['cases']),6);self.assertTrue(all(c['original_to_small_ratio'] is None for c in r['cases']))
        data=self.parse(self.text);o=oracle(data);o[-1]['candidate']['passed']=False;r=check.summarize(data,o);self.assertFalse(r['passed']);self.assertEqual(len(r['oracle']),6);self.assertTrue(all(c['original_to_small_ratio'] is None for c in r['cases']))

    def test_independent_case_identity_and_count(self):
        data=self.parse()
        for key,value in [('index',99),('outputs',1)]:
            o=oracle(data);o[-1][key]=value;self.assertFalse(check.summarize(data,o)['passed'])
        self.assertFalse(check.summarize(data,oracle(data)[:-1])['passed'])

    def test_nonfinite_nonexact_and_timing_underflow(self):
        for a,b in [('VALUE,0,0,0,0,1,1','VALUE,0,0,0,0,1,nan'),('VALUE,0,0,0,0,1,1','VALUE,0,0,0,0,1,2.1'),('TIME,0,0,0,3,0.001','TIME,0,0,0,3,5e-324'),('TIME,0,0,0,3,0.001','TIME,0,1,0,3,0.001'),('TIME,0,0,0,3,0.001','TIME,0,0,0,4,0.001')]:
            with self.assertRaises(ValueError):self.parse(self.text.replace(a,b,1))
        data=self.parse(self.text)
        for c in data['cases']:c['times'][1]=[1e-323]*10
        r=check.summarize(data,oracle(data));self.assertFalse(r['passed']);self.assertIn('Nonfinite',r['error']);self.assertTrue(all(c['original_to_small_ratio'] is None for c in r['cases']))

    def test_special_files_size_and_line_bounds(self):
        fifo=self.root/'fifo';os.mkfifo(fifo)
        with self.assertRaises(ValueError):check.parse(fifo)
        link=self.root/'link';link.symlink_to(self.path)
        with self.assertRaises(OSError):check.parse(link)
        with self.assertRaises(ValueError):self.parse(self.text+'x'*1025+'\n')
        big=self.root/'big'
        with big.open('wb') as f:f.truncate(256*1024**2+1)
        with self.assertRaises(ValueError):check.parse(big)

    def arguments(self,out):return ['check',str(self.path),'--binary',str(self.root/'binary'),'--binary-sha256','b'*64,'--output',str(out)]

    def test_after_binary_and_capture_changes_keep_full_failure(self):
        data=self.parse();expected=hashlib.sha256(self.text.encode()).hexdigest()
        for changed in ('binary','capture.csv'):
            out=self.root/(changed+'.json');counts={}
            def digest(p):
                counts[p.name]=counts.get(p.name,0)+1
                return 'c'*64 if p.name==changed and counts[p.name]>=(2 if changed=='binary' else 1) else ('b'*64 if p.name=='binary' else expected)
            with patch.object(sys,'argv',self.arguments(out)),patch.object(check,'digest',side_effect=digest),patch.object(check,'independent',return_value=oracle(data)):self.assertEqual(check.main(),1)
            r=json.loads(out.read_text());self.assertFalse(r['passed']);self.assertTrue(r['collection_complete']);self.assertIn('changed during',r['error']);self.assertEqual(len(r['cases']),6);self.assertTrue(all(c['original_to_small_ratio'] is None for c in r['cases']))

    def test_before_identity_interrupt_and_exclusive_report(self):
        for name,effect in [('identity',lambda _: 'c'*64),('interrupt',KeyboardInterrupt)]:
            out=self.root/name
            with patch.object(sys,'argv',self.arguments(out)),patch.object(check,'digest',side_effect=effect),patch.object(check,'independent') as o:self.assertEqual(check.main(),1);o.assert_not_called()
            r=json.loads(out.read_text());self.assertFalse(r['passed']);self.assertFalse(r['full_model_speed_claim']);before=out.read_bytes()
            with patch.object(sys,'argv',self.arguments(out)),self.assertRaises(FileExistsError):check.main()
            self.assertEqual(before,out.read_bytes())


if __name__=='__main__':unittest.main()
