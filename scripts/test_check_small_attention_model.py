"""Reduced default-closed small-model/source contracts; never physical GPU proof."""
import hashlib
import json
import sys
import unittest
from unittest.mock import patch

import check_turing_model_prefill as check
import check_turing_down_source as source_check
import check_turing_decode_quality as decode
import check_turing_checkpoint_replay as checkpoint
import check_turing_fixture_controls as controls
import test_check_fused_attention_controls_model as original_contracts
from test_check_fused_attention_model import fixture as original

MARKER = 'ATTENTION,rope_cache_elementwise_down128_small,1,32'


def fixture():
    text = original().replace('ATTENTION,rope_cache_elementwise_down128_fused,1,32', MARKER).replace('ADMISSION,4,3,0', 'ADMISSION,5,12,0')
    for i in range(4):
        text = text.replace(f'FUSED_ATTENTION,{i},0,56\n', f'SMALL_ATTENTION,{i},0,56\nFUSED_ATTENTION,{i},0,56\n')
    return text


class Contracts(unittest.TestCase):
    def setUp(self):
        original_contracts.Contracts.setUp(self)
        p = patch.object(source_check, 'VOCABULARY', 4);p.start();self.addCleanup(p.stop)

    def parse(self, text):
        p = self.root/'capture';p.write_text(text);return check.parse(p, allow_small=True)

    def proof(self):
        return original_contracts.Contracts.proof(self)

    def test_default_closed_and_source_derived_counters(self):
        data = self.parse(fixture());self.assertEqual(data['attention_variant'], 5)
        self.assertFalse(data['control_capable']);self.assertEqual([c['small_attention_host_enqueues'] for c in data['cases']], [0]*4)
        self.assertEqual([check.fused_attention_calls(n) for n in (30,37,31,1070)], [(196,56),(56,28),(196,84),(1008,56)])
        path = self.root/'capture'
        for kwargs in ({}, {'allow_fused': True}, {'allow_fused': True, 'allow_small': True}, {'allow_small': 1}, {'allow_fused_controls': True, 'allow_small': True}):
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError):check.parse(path, **kwargs)
        for module in (decode, checkpoint, controls):
            with self.assertRaises(ValueError):module.attention_variant(MARKER.split(','))
        with self.assertRaises(ValueError):source_check.accepted_model(path, self.root/'unused', 'a'*64, fused=True, binary=self.previous_binary)

    def test_complete_mode_admission_counters_and_closed_capabilities(self):
        for a,b in [('ADMISSION,5,12,0', 'ADMISSION,5,11,0'), ('ADMISSION,5,12,0\n',''),
                    ('ADMISSION,5,12,0\n','ADMISSION,5,12,0\nCONTROL_CAPABLE,4,1\n'),
                    ('SMALL_ATTENTION,0,0,56', 'SMALL_ATTENTION,0,1,56'), ('SMALL_ATTENTION,0,0,56', 'SMALL_ATTENTION,0,0,55'),
                    ('FUSED_ATTENTION,0,0,56','FUSED_ATTENTION,0,1,56'), ('SMALL_ATTENTION,0,0,56\n',''),
                    ('SMALL_ATTENTION,0,0,56\n','SMALL_ATTENTION,0,0,56\nSMALL_ATTENTION,0,0,56\n'),
                    ('DOWN_ROWS128,0,0','DOWN_ROWS128,0,1'), ('LOGIT,0,0,0,0\n','')]:
            self.assertIn(a,fixture())
            with self.subTest(a=a), self.assertRaises((ValueError, StopIteration)):self.parse(fixture().replace(a,b,1))
        with self.assertRaises(ValueError):self.parse(fixture().rstrip('\n'))

    def test_exact_current_vectors_cache_and_ids_bind_actual_original4(self):
        csv,path,_ = self.proof();data = self.parse(fixture())
        proof = check.fixture_reference(data, csv, path, 'a'*64, reference_binary=self.previous_binary)
        self.assertTrue(proof['passed']);self.assertFalse(proof['control_capable']);self.assertEqual(proof['attention_variant'], 4)
        self.assertEqual(proof['binary_sha256'], hashlib.sha256(self.previous_binary.read_bytes()).hexdigest())
        for a,b in [('LOGIT,0,0,0,0','LOGIT,0,0,0,-0.0'), ('LOGIT,0,1,1,1','LOGIT,0,1,1,1.125'), ('CACHE,0,176160832,'+'a'*64,'CACHE,0,176160832,'+'b'*64), ('INPUT,0,0,1','INPUT,0,0,2')]:
            self.assertIn(a,fixture());changed = self.parse(fixture().replace(a,b,1));self.assertFalse(check.fixture_reference(changed,csv,path,'a'*64,reference_binary=self.previous_binary)['passed'])
        data = self.parse(fixture());data['cases'][-1]['small_attention_host_enqueues'] = 1
        with self.assertRaises(ValueError):check.fixture_reference(data,csv,path,'a'*64,reference_binary=self.previous_binary)

    def test_full_source_cpu_scope_binary_and_predecessor_required(self):
        csv,path,report = self.proof();data = self.parse(fixture())
        for mutate in (lambda r:r.update(binary_sha256='0'*64), lambda r:r['independent_reference'].update(requested_gpu_layers=1),
                       lambda r:r['independent_reference']['cases'][-1]['matrix'].update(rms_error=.00501),
                       lambda r:r['fixture_reference']['cases'][-1].update(matrix_f32_bytes_equal=False),
                       lambda r:r['cases'][-1].update(fused_attention_host_enqueues=1)):
            modified = json.loads(json.dumps(report));mutate(modified);path.write_text(json.dumps(modified))
            with self.assertRaises(ValueError):check.fixture_reference(data,csv,path,'a'*64,reference_binary=self.previous_binary)
        path.write_text(json.dumps(report))
        with self.assertRaises(ValueError):check.fixture_reference(data,csv,path,'a'*64)
        csv.write_text(original().replace('ADMISSION,4,3,0\n','ADMISSION,4,3,0\nCONTROL_CAPABLE,4,1\n'))
        with self.assertRaises(ValueError):check.fixture_reference(data,csv,path,'a'*64,reference_binary=self.previous_binary)

    def test_complete_numeric_and_nonfinite_score_failure_atomically_clears(self):
        data = self.parse(fixture());r = check.summarize(data);r.update(independent_reference={'passed': True},fixture_reference={'passed': True})
        r['cases'][-1]['native_comparison']['passed'] = False;check.score(r)
        self.assertFalse(r['passed']);self.assertEqual(len(r['cases']), 4);self.assertTrue(all(c['prefill_speed_ratio'] is None for c in r['cases']))
        r = check.summarize(self.parse(fixture()));r.update(independent_reference={'passed':True},fixture_reference={'passed':True})
        for t in r['cases'][-1]['timings']:t['seconds'] = 1e308 if t['mode'] == 0 else 5e-324
        check.score(r);self.assertFalse(r['passed']);self.assertTrue(all(c['prefill_speed_ratio'] is None and 'native_prefill_median_seconds' not in c for c in r['cases']))

    def run_main(self,change=None,interrupt=False,explicit=True):
        capture = self.root/'capture';capture.write_text(fixture());data = check.parse(capture,allow_small=True)
        model = self.root/'model';model.write_bytes(b'x');derived = self.root/'derived';derived.write_bytes(b'y');csv,path,_ = self.proof()
        out = self.root/f'report-{change}-{interrupt}-{explicit}'
        values = ['a'*64,'e'*64,'f'*64,'a'*64,'e'*64,data['csv_sha256'],'d'*64,'b'*64,'c'*64,'f'*64,'9'*64]
        if change is not None:values[change] = '0'*64
        args = ['check',str(capture),'--model',str(model),'--model-sha256','a'*64,'--reference-model',str(derived),'--reference-sha256','e'*64,'--reference-provenance',str(self.root/'provenance'),'--reference-csv',str(csv),'--reference-report',str(path),'--output',str(out)]
        if explicit:args += ['--small-attention','--binary',str(self.root/'binary'),'--binary-sha256','f'*64,'--reference-binary',str(self.previous_binary)]
        with patch.object(sys,'argv',args),patch.object(check,'digest',side_effect=values),patch.object(check,'provenance',return_value={'derived_bytes':1,'snapshot_sha256':'d'*64}),patch.object(check,'fixture_reference',return_value={'passed':True,'csv_sha256':'b'*64,'report_sha256':'c'*64,'binary_sha256':'9'*64}),patch.object(check,'independent',side_effect=KeyboardInterrupt if interrupt else None,return_value={'passed':True}):
            status = check.main()
        return status,json.loads(out.read_text()),args,out

    def test_every_after_hash_and_interrupt_keep_complete_failed_evidence(self):
        for index in range(3,11):
            status,r,_,_ = self.run_main(change=index);self.assertEqual(status,1);self.assertTrue(r['collection_complete']);self.assertFalse(r['speed_scored']);self.assertEqual(len(r['cases']),4);self.assertTrue(all(c['prefill_speed_ratio'] is None for c in r['cases']))
        status,r,_,_ = self.run_main(interrupt=True);self.assertEqual(status,1);self.assertTrue(r['collection_complete']);self.assertIn('KeyboardInterrupt',r['error'])

    def test_explicit_cli_source_triplet_exclusive_and_success(self):
        status,r,_,_ = self.run_main(explicit=False);self.assertEqual(status,1);self.assertFalse(r['collection_complete'])
        status,r,args,out = self.run_main();self.assertEqual(status,0);self.assertTrue(r['speed_scored']);before = out.read_bytes()
        with patch.object(sys,'argv',args), self.assertRaises(FileExistsError):check.main()
        self.assertEqual(before,out.read_bytes())
        for defect in ('source','exclusive'):
            changed = args.copy()
            if defect == 'source':changed = changed[:-2]
            else:changed += ['--fused-attention']
            with patch.object(sys,'argv',changed),patch.object(check,'digest') as digest,self.assertRaises(SystemExit):check.main()
            digest.assert_not_called()


if __name__ == '__main__':
    unittest.main()
