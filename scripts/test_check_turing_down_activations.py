"""Down-only real-F32 admission contracts; synthetic fixtures do not prove GPU work."""
from pathlib import Path
import tempfile
import unittest
import json
import copy
from unittest.mock import patch
import check_turing_down_activations as check
from test_check_turing_activations import fixture as legacy


def fixture(actual=1.0):
    lines=legacy(actual).replace('META,1,turing_native_f32,64,32,12',','.join(check.META)).splitlines()
    return '\n'.join(line+',1' if line.startswith('VALUE,') else line for line in lines)+'\n'


class Contracts(unittest.TestCase):
    def parse(self,text):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'capture';p.write_text(text);return check.parse(p)

    def test_complete_three_owner_mode_and_down_only_identity(self):
        data=self.parse(fixture())
        self.assertEqual((len(data['cases']),data['native_outputs'],data['source_values']),(28,504,6144))
        self.assertEqual([c['index'] for c in data['cases'] if c['matrix_rows']==128],[13,27])
        self.assertTrue(all(c['original_f32_bits_equal'] for c in data['cases']))
        r=check.summary(data);self.assertFalse(r['passed']);self.assertFalse(r['speed_claim'])
        self.assertFalse(r['full_model_quality_claim']);json.dumps(r)

    def test_complete_numeric_failure_and_signed_zero_retain_all_cases(self):
        data=self.parse(fixture(1.125));self.assertEqual(len(data['cases']),28)
        self.assertTrue(all(not c['original_f32_bits_equal'] and not c['native_error']['passed'] for c in data['cases']))
        text=fixture().replace('VALUE,0,0,0,1,1.0,1','VALUE,0,0,0,0,-0,0').replace('METRIC,0,0,0.0','METRIC,0,0,0.0')
        self.assertFalse(self.parse(text)['cases'][0]['original_f32_bits_equal'])

    def test_geometry_legacy_duplicate_late_metadata_refuse(self):
        marker=','.join(check.META)
        for text in [fixture().replace('128,32','256,32'),fixture().replace(marker,'META,1,turing_native_f32,64,32,12'),
                     fixture().replace(marker,marker+'\n'+marker),fixture().replace('STATE,0',marker+'\nSTATE,0',1),fixture().rstrip('\n')]:
            with self.assertRaises((ValueError,StopIteration)):self.parse(text)

    def test_missing_original_nonfinite_and_inexact_values_refuse(self):
        for replacement in ['VALUE,0,0,0,1,1.0','VALUE,0,0,0,1,1.0,nan','VALUE,0,0,0,1,1.0,0.1']:
            with self.assertRaises(ValueError):self.parse(fixture().replace('VALUE,0,0,0,1,1.0,1',replacement))

    def test_actual_guards_metrics_order_totals_and_trailing_refuse(self):
        for old,new in [('GUARD,0,1444,0','GUARD,0,1444,1'),('METRIC,0,0,0.0','METRIC,0,0.1,0.0'),
                        ('VALUE,0,0,0,1,1.0,1','VALUE,0,1,0,1,1.0,1'),('COMPLETE,activation,28,504,6144,12','COMPLETE,activation,28,505,6144,12')]:
            with self.assertRaises(ValueError):self.parse(fixture().replace(old,new))
        with self.assertRaises(ValueError):self.parse(fixture()+'extra\n')

    def test_full_source_bytes_states_and_original_descriptors_refuse(self):
        data=self.parse(fixture());base=copy.deepcopy(data)
        for c in base['cases']:c['actual']=c['original']
        check.same_sources(data,base)
        for edit in ['state','source','native','original','descriptor']:
            other=copy.deepcopy(base)
            if edit=='state':other['states'][0]['replayed_tokens'][0]=9
            if edit=='source':other['sources'][0,0][0]=-0.0
            if edit=='native':other['cases'][0]['reference'][0]=0
            if edit=='original':other['cases'][0]['actual'][0]=0
            if edit=='descriptor':other['cases'][0]['offset']=33
            with self.subTest(edit=edit),self.assertRaises(ValueError):check.same_sources(data,other)

    def test_strict_source_json_fixed_budget_and_totals(self):
        self.assertFalse(check.budget(dict(passed=True,maximum_scaled_error=True,normalized_rms=0)))
        self.assertFalse(check.budget(dict(passed=True,maximum_scaled_error=0,normalized_rms=float('nan'))))
        self.assertFalse(check.budget(dict(passed=True,maximum_scaled_error=.003,normalized_rms=0)))
        with self.assertRaises(ValueError):check.unique([('a',1),('a',2)])
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'source.json';csv=Path(d)/'source.csv';csv.write_text(legacy())
            for text in ['{"passed":true,"passed":false}','{"passed":NaN}','{}']:
                p.write_text(text)
                with self.assertRaises((ValueError,KeyError)):check.reference(self.parse(fixture()),csv,p,'a'*64)

    def run_main(self,directory,*,text=None,mutation=False,interrupt=False):
        import sys
        p=directory/'capture';p.write_text(text or fixture());out=directory/'report'
        data=check.parse(p)
        # Mock the parser's physical totals only to exercise orchestration; no device claim.
        data['native_outputs'],data['source_values']=check.COUNTS[:2]
        ref=dict(csv_sha256='b'*64,report_sha256='c'*64,bytes_identical=True)
        good=dict(passed=True,maximum_scaled_error=0,normalized_rms=0)
        oracle=[dict(outputs=check.COUNTS[2],candidate=good,reference=good,original=good)]
        values=['a'*64,'a'*64,data['csv_sha256'],'b'*64,'c'*64]
        if mutation:values[-1]='d'*64
        args=['check',str(p),'--model',str(directory/'model'),'--model-sha256','a'*64,'--reference-csv',str(directory/'base'),'--reference-report',str(directory/'base.json'),'--output',str(out)]
        with patch.object(sys,'argv',args),patch.object(check,'parse',return_value=data),patch.object(check,'reference',return_value=ref),patch.object(check,'independent',side_effect=KeyboardInterrupt if interrupt else None,return_value=oracle),patch.object(check,'digest',side_effect=values):status=check.main()
        return status,json.loads(out.read_text()),args

    def test_complete_success_no_speed_and_failed_numeric_metrics(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);status,r,_=self.run_main(root)
            self.assertEqual(status,0);self.assertFalse(r['speed_claim']);self.assertTrue(r['collection_complete'])
        with tempfile.TemporaryDirectory() as d:
            status,r,_=self.run_main(Path(d),text=fixture(1.125))
            self.assertEqual(status,1);self.assertEqual(len(r['cases']),28);self.assertIn('oracle',r)
            self.assertFalse(r['speed_claim'])

    def test_post_oracle_mutation_and_interrupt_preserve_failure(self):
        for mutation,interrupt in [(True,False),(False,True)]:
            with tempfile.TemporaryDirectory() as d:
                status,r,_=self.run_main(Path(d),mutation=mutation,interrupt=interrupt)
                self.assertEqual(status,1);self.assertTrue(r['collection_complete']);self.assertEqual(len(r['cases']),28)
                self.assertIn('changed' if mutation else 'KeyboardInterrupt',r['error']);self.assertFalse(r['speed_claim'])

    def test_exclusive_report_never_overwrites(self):
        import sys
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);_,_,args=self.run_main(root);before=(root/'report').read_bytes()
            with patch.object(sys,'argv',args),self.assertRaises(FileExistsError):check.main()
            self.assertEqual((root/'report').read_bytes(),before)


if __name__=='__main__':unittest.main()
