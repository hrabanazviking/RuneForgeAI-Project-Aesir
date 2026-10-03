"""Narrow down128 complete model/source/scoring admission; no physical GPU claim."""
from pathlib import Path
import json
import tempfile
import unittest
from unittest.mock import patch
import check_turing_model_prefill as check
import check_llama3_logits as logits
import check_turing_decode_quality as decode
import check_turing_checkpoint_replay as checkpoint
import check_turing_fixture_controls as controls
from test_check_turing_grid_metadata import grid

MARKER='ATTENTION,rope_cache_elementwise_down128,1,32'


def fixture():
    text=grid(2).replace('ATTENTION,rope_cache_elementwise_grid,1,32',MARKER)
    text=text.replace('META,1,4,1536,32,f16,8\n','META,1,4,1536,32,f16,8\nADMISSION,3,2,0\n')
    for i in range(4):text=text.replace(f'ELEMENTWISE,{i},281\n',f'ELEMENTWISE,{i},281\nDOWN_ROWS128,{i},0\n')
    return text


class Contracts(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        for obj in (check,logits):
            p=patch.object(obj,'VOCABULARY',4);p.start();self.addCleanup(p.stop)

    def parse(self,text):
        p=self.root/'capture';p.write_text(text);return check.parse(p)

    def proof(self,variant=2):
        csv=self.root/'baseline';csv.write_text(grid(variant));data=check.parse(csv)
        report=check.summarize(data)
        report.update(passed=True,model_sha256='a'*64,independent_reference=dict(passed=True,
            requested_gpu_layers=0,context=4096,kv='f16',batch=128,weight_mode='dequantized_f32',numpy='2.4.4',
            llama_cpp_python='0.3.23',library_sha256='b'*64,cases=[dict(native=c['native_comparison'],matrix=c['native_comparison']) for c in data['cases']]))
        path=self.root/'baseline.json';path.write_text(json.dumps(report));return csv,path,report

    def test_complete_model_only_opt_in_and_actual_selected_counts(self):
        data=self.parse(fixture());self.assertEqual(data['attention_variant'],3)
        self.assertEqual([c['down128_host_enqueues'] for c in data['cases']],[0]*4)
        self.assertFalse(check.summarize(data)['passed'])
        self.assertEqual([((n-1)//32)*28 for n in (30,37,31,1070)],[0,28,0,924])
        self.assertEqual(check.attention_variant(MARKER.split(','),allow_down=True),3)
        for module in (check,decode,checkpoint,controls):
            with self.subTest(module=module.__name__),self.assertRaises(ValueError):module.attention_variant(MARKER.split(','))

    def test_missing_duplicate_geometry_admission_counters_refuse(self):
        for old,new in [('ADMISSION,3,2,0\n',''),('ADMISSION,3,2,0','ADMISSION,3,1,0'),
                        ('DOWN_ROWS128,0,0','DOWN_ROWS128,0,1'),('DOWN_ROWS128,0,0\n',''),
                        ('ELEMENTWISE,0,281','ELEMENTWISE,0,282'),(MARKER,MARKER.replace('128','256')),
                        (MARKER,MARKER+'\n'+MARKER)]:
            with self.subTest(old=old),self.assertRaises((ValueError,StopIteration)):self.parse(fixture().replace(old,new))
        with self.assertRaises(ValueError):self.parse(fixture().rstrip('\n'))

    def test_source_requires_explicit_strategy2_and_complete_numeric_scope(self):
        data=self.parse(fixture());csv,path,r=self.proof()
        self.assertTrue(check.fixture_reference(data,csv,path,'a'*64)['passed'])
        for key,value in [('requested_gpu_layers',1),('weight_mode','packed'),('library_sha256','bad')]:
            changed=json.loads(json.dumps(r));changed['independent_reference'][key]=value;path.write_text(json.dumps(changed))
            with self.subTest(key=key),self.assertRaises(ValueError):check.fixture_reference(data,csv,path,'a'*64)
        changed=json.loads(json.dumps(r));changed['independent_reference']['cases'][0]['matrix']['maximum_absolute_error']=.06;path.write_text(json.dumps(changed))
        with self.assertRaises(ValueError):check.fixture_reference(data,csv,path,'a'*64)
        for variant in (0,1):
            csv,path,_=self.proof(variant)
            with self.assertRaises(ValueError):check.fixture_reference(data,csv,path,'a'*64)

    def test_full_source_signed_zero_cache_ids_and_report_identity(self):
        csv,path,r=self.proof()
        for old,new in [('LOGIT,0,0,0,0','LOGIT,0,0,-0.0,0'),('a'*64,'c'*64),('INPUT,0,0,1','INPUT,0,0,2')]:
            changed=self.parse(fixture().replace(old,new));self.assertFalse(check.fixture_reference(changed,csv,path,'a'*64)['passed'])
        path.write_text(json.dumps(r).replace('"schema": 1','"schema": 1,"schema": 1'))
        with self.assertRaises(ValueError):check.fixture_reference(self.parse(fixture()),csv,path,'a'*64)

    def test_ratio_requires_all_sources_and_quality_and_rescore_clears(self):
        r=check.summarize(self.parse(fixture()));r['independent_reference']=dict(passed=True)
        check.score(r);self.assertFalse(r['speed_scored']);self.assertTrue(all(c['prefill_speed_ratio'] is None for c in r['cases']))
        r['fixture_reference']=dict(passed=True);check.score(r);self.assertTrue(r['speed_scored'])
        r['fixture_reference']['passed']=False;check.score(r);self.assertFalse(r['speed_scored'])
        self.assertTrue(all(c['prefill_speed_ratio'] is None and 'native_prefill_median_seconds' not in c for c in r['cases']))

    def test_nonfinite_ratio_withholds_all_cases_atomically(self):
        r=check.summarize(self.parse(fixture()));r.update(independent_reference=dict(passed=True),fixture_reference=dict(passed=True))
        for s in r['cases'][-1]['timings']:s['seconds']=1e308 if s['mode']==0 else 5e-324
        check.score(r);self.assertFalse(r['passed']);self.assertFalse(r['speed_scored'])
        self.assertTrue(all(c['prefill_speed_ratio'] is None and 'matrix_prefill_median_seconds' not in c for c in r['cases']))

    def run_main(self,*,mutate=False,interrupt=False):
        import sys
        capture=self.root/'capture';capture.write_text(fixture());data=check.parse(capture)
        model=self.root/'model';model.write_bytes(b'x');derived=self.root/'derived';derived.write_bytes(b'y')
        output=self.root/'report';csv,path,_=self.proof()
        ref=dict(passed=True,csv_sha256='b'*64,report_sha256='c'*64)
        prov=dict(derived_bytes=1,snapshot_sha256='d'*64)
        values=['a'*64,'e'*64,'a'*64,'e'*64,data['csv_sha256'],'d'*64,'b'*64,'c'*64]
        if mutate:values[5]='f'*64
        args=['checker',str(capture),'--model',str(model),'--model-sha256','a'*64,'--reference-model',str(derived),
              '--reference-sha256','e'*64,'--reference-provenance',str(self.root/'provenance'),'--reference-csv',str(csv),
              '--reference-report',str(path),'--output',str(output)]
        with patch.object(sys,'argv',args),patch.object(check,'digest',side_effect=values),patch.object(check,'provenance',return_value=prov),patch.object(check,'fixture_reference',return_value=ref),patch.object(check,'independent',side_effect=KeyboardInterrupt if interrupt else None,return_value=dict(passed=True)):
            result=check.main()
        return result,json.loads(output.read_text()),args

    def test_complete_provenance_mutation_or_interrupt_retains_unscored_metrics(self):
        for interrupt in (False,True):
            if (self.root/'report').exists():(self.root/'report').unlink()
            result,r,_=self.run_main(mutate=not interrupt,interrupt=interrupt)
            self.assertEqual(result,1);self.assertTrue(r['collection_complete']);self.assertEqual(len(r['cases']),4)
            self.assertIn('provenance changed' if not interrupt else 'KeyboardInterrupt',r['error'])
            self.assertFalse(r['speed_scored']);self.assertTrue(all(c['prefill_speed_ratio'] is None for c in r['cases']))

    def test_complete_score_is_exclusive(self):
        import sys
        result,r,args=self.run_main();self.assertEqual(result,0);self.assertTrue(r['speed_scored'])
        before=(self.root/'report').read_bytes()
        with patch.object(sys,'argv',args),self.assertRaises(FileExistsError):check.main()
        self.assertEqual((self.root/'report').read_bytes(),before)


if __name__=='__main__':unittest.main()
