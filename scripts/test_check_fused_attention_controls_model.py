"""Reduced capable4/full-model/source contracts, never physical GPU proof."""
from pathlib import Path
import hashlib,json,sys,tempfile,unittest
from unittest.mock import patch
import check_turing_model_prefill as check
import check_llama3_logits as logits
import check_turing_decode_quality as decode
import check_turing_checkpoint_replay as checkpoint
import check_turing_fixture_controls as controls
from test_check_fused_attention_model import fixture as original

MARKER='ATTENTION,rope_cache_elementwise_down128_fused,1,32'


def fixture():
    return original().replace('ADMISSION,4,3,0\n','ADMISSION,4,3,0\nCONTROL_CAPABLE,4,1\n')


class Contracts(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name);self.previous_binary=self.root/'previous4';self.previous_binary.write_bytes(b'previous4')
        for module in (check,logits):
            p=patch.object(module,'VOCABULARY',4);p.start();self.addCleanup(p.stop)

    def parse(self,text):
        p=self.root/'capture';p.write_text(text);return check.parse(p,allow_fused=True,allow_fused_controls=True)

    def proof(self):
        csv=self.root/'source';csv.write_text(original());data=check.parse(csv,allow_fused=True);report=check.summarize(data)
        flags=('input_ids_equal','native_f32_bytes_equal','matrix_f32_bytes_equal','guarded_cache_identity_passed','passed')
        report.update(passed=True,speed_scored=True,model_sha256='a'*64,binary_sha256=hashlib.sha256(self.previous_binary.read_bytes()).hexdigest(),fixture_reference=dict(passed=True,attention_variant=3,csv_sha256='c'*64,report_sha256='d'*64,cases=[dict.fromkeys(flags,True) for _ in range(4)]),
            independent_reference=dict(passed=True,requested_gpu_layers=0,context=4096,kv='f16',batch=128,threads=4,weight_mode='dequantized_f32',numpy='2.4.4',llama_cpp_python='0.3.23',library_sha256='b'*64,
                cases=[dict(native=c['native_comparison'],matrix=c['native_comparison']) for c in data['cases']]))
        path=self.root/'source.json';path.write_text(json.dumps(report));return csv,path,report

    def test_explicit_default_closed_and_actual_counts(self):
        data=self.parse(fixture());self.assertEqual(data['attention_variant'],4)
        self.assertEqual([check.fused_attention_calls(n) for n in (30,37,31,1070)],[(196,56),(56,28),(196,84),(1008,56)])
        self.assertEqual([c['original_attention_queries'] for c in data['cases']],[56]*4)
        p=self.root/'capture'
        with self.assertRaises(ValueError):check.parse(p)
        self.assertEqual(check.attention_variant(MARKER.split(','),allow_fused=True),4)
        for module in (check,decode,checkpoint,controls):
            with self.assertRaises(ValueError):module.attention_variant(MARKER.split(','))

    def test_missing_marker_admission_counter_cache_scope(self):
        for a,b in [('ADMISSION,4,3,0\n',''),('ADMISSION,4,3,0','ADMISSION,4,2,0'),('FUSED_ATTENTION,0,0,56','FUSED_ATTENTION,0,1,56'),('FUSED_ATTENTION,0,0,56','FUSED_ATTENTION,0,0,55'),('FUSED_ATTENTION,0,0,56\n',''),('DOWN_ROWS128,0,0','DOWN_ROWS128,0,1'),(MARKER,MARKER+'\n'+MARKER)]:
            with self.assertRaises((ValueError,StopIteration)):self.parse(fixture().replace(a,b,1))
        with self.assertRaises(ValueError):self.parse(fixture().rstrip('\n'))
        p=self.root/'capture';p.write_text(fixture())
        with self.assertRaises(ValueError):check.parse(p,allow_fused=True)

    def test_source_complete_predecessor_and_cpu_scope(self):
        data=self.parse(fixture());csv,path,r=self.proof();self.assertTrue(check.fixture_reference(data,csv,path,'a'*64,reference_binary=self.previous_binary)['passed'])
        historical=json.loads(json.dumps(r));historical.pop('control_capable');path.write_text(json.dumps(historical));self.assertTrue(check.fixture_reference(data,csv,path,'a'*64,reference_binary=self.previous_binary)['passed'])
        changes=[lambda x:x.update(control_capable=True),lambda x:x['fixture_reference'].update(attention_variant=1),lambda x:x['fixture_reference']['cases'][-1].update(matrix_f32_bytes_equal=False),lambda x:x['independent_reference'].update(requested_gpu_layers=1),lambda x:x['cases'][0].update(down128_host_enqueues=1),lambda x:x.update(binary_sha256='e'*64),lambda x:x['independent_reference']['cases'][0]['matrix'].update(rms_error=.006)]
        for mutate in changes:
            changed=json.loads(json.dumps(r));mutate(changed);path.write_text(json.dumps(changed))
            with self.assertRaises(ValueError):check.fixture_reference(data,csv,path,'a'*64,reference_binary=self.previous_binary)

    def test_source_bits_signed_zero_ids_cache_and_duplicate_fields(self):
        csv,path,r=self.proof()
        for a,b in [('LOGIT,0,0,0,0','LOGIT,0,0,-0.0,0'),('INPUT,0,0,1','INPUT,0,0,2'),('a'*64,'c'*64)]:
            self.assertFalse(check.fixture_reference(self.parse(fixture().replace(a,b,1)),csv,path,'a'*64,reference_binary=self.previous_binary)['passed'])
        path.write_text(json.dumps(r).replace('"schema": 1','"schema": 1,"schema": 1'))
        with self.assertRaises(ValueError):check.fixture_reference(self.parse(fixture()),csv,path,'a'*64,reference_binary=self.previous_binary)

    def test_atomic_scoring_requires_all_gates(self):
        r=check.summarize(self.parse(fixture()));r['independent_reference']=dict(passed=True);check.score(r);self.assertFalse(r['passed'])
        r['fixture_reference']=dict(passed=True);check.score(r);self.assertTrue(r['speed_scored'])
        for t in r['cases'][-1]['timings']:t['seconds']=1e308 if t['mode']==0 else 5e-324
        check.score(r);self.assertFalse(r['passed']);self.assertTrue(all(c['prefill_speed_ratio'] is None and 'native_prefill_median_seconds' not in c for c in r['cases']))

    def run_main(self,change=None,interrupt=False,explicit=True):
        capture=self.root/'capture';capture.write_text(fixture());data=check.parse(capture,allow_fused=True,allow_fused_controls=True)
        model=self.root/'model';model.write_bytes(b'x');derived=self.root/'derived';derived.write_bytes(b'y');csv,path,_=self.proof();out=self.root/('report-'+str(change)+'-'+str(interrupt)+'-'+str(explicit))
        values=['a'*64,'e'*64,'f'*64,'a'*64,'e'*64,data['csv_sha256'],'d'*64,'b'*64,'c'*64,'f'*64,'9'*64]
        if change is not None:values[change]='0'*64
        args=['checker',str(capture),'--model',str(model),'--model-sha256','a'*64,'--reference-model',str(derived),'--reference-sha256','e'*64,'--reference-provenance',str(self.root/'provenance'),'--reference-csv',str(csv),'--reference-report',str(path),'--output',str(out)]
        if explicit:args+=['--fused-controls','--reference-binary',str(self.previous_binary),'--fused-attention','--binary',str(self.root/'binary'),'--binary-sha256','f'*64]
        with patch.object(sys,'argv',args),patch.object(check,'digest',side_effect=values),patch.object(check,'provenance',return_value=dict(derived_bytes=1,snapshot_sha256='d'*64)),patch.object(check,'fixture_reference',return_value=dict(passed=True,csv_sha256='b'*64,report_sha256='c'*64,binary_sha256='9'*64)),patch.object(check,'independent',side_effect=KeyboardInterrupt if interrupt else None,return_value=dict(passed=True)):
            status=check.main()
        return status,json.loads(out.read_text()),args,out

    def test_all_after_artifact_changes_and_interrupt_keep_full_failure(self):
        for change in range(3,11):
            status,r,_,_=self.run_main(change=change);self.assertEqual(status,1);self.assertTrue(r['collection_complete']);self.assertEqual(len(r['cases']),4);self.assertFalse(r['speed_scored']);self.assertTrue(all(c['prefill_speed_ratio'] is None for c in r['cases']))
        status,r,_,_=self.run_main(interrupt=True);self.assertEqual(status,1);self.assertTrue(r['collection_complete']);self.assertIn('KeyboardInterrupt',r['error'])

    def test_explicit_cli_and_exclusive_success(self):
        status,r,_,_=self.run_main(explicit=False);self.assertEqual(status,1);self.assertFalse(r['collection_complete'])
        status,r,args,out=self.run_main();self.assertEqual(status,0);self.assertTrue(r['speed_scored']);before=out.read_bytes()
        with patch.object(sys,'argv',args),self.assertRaises(FileExistsError):check.main()
        self.assertEqual(before,out.read_bytes())


if __name__=='__main__':unittest.main()
