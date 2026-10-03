"""Synthetic matrix evidence rejection contracts; no GPU execution claim."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import check_packed_matrix as check


def fixture():
    records = ["[CUDA] synthetic api=cuda cpu_offload=0", "SYNTHETIC,144,0"]
    count = 0
    for batch in check.BATCHES:
        for name in check.NAMES:
            records.append(f"CASE,{count},{name},12,256,1,{batch},32")
            records.extend(f"VALUE,{count},{token},0,1,1" for token in range(batch))
            records.append(f"GUARD,{count},20,0")
            records.extend(f"TIME,{count},{mode},{sample},3,0.001" for mode in (0, 1) for sample in range(10))
            count += 1
    records.append("PASS,matrix,28,420,560")
    return "\n".join(records) + "\n"


def header_fixture():
    records=["[CUDA] synthetic api=cuda cpu_offload=0","MODE,turing_mma_staged_header_cache_f16_f32,64,32","SYNTHETIC,144,0"]
    count=0
    for batch in check.BATCHES:
        for name in check.NAMES:
            records.append(f"CASE,{count},{name},12,256,1,{batch},32")
            records.extend(f"VALUE,{count},{token},0,1,1,1" for token in range(batch))
            records.append(f"GUARD,{count},20,0")
            for sample in range(10):
                for step in range(3):records.append(f"TIME,{count},{(sample+step)%3},{sample},3,0.001")
            count+=1
    records.append("PASS,matrix,28,420,840")
    return "\n".join(records)+"\n"


class Contracts(unittest.TestCase):
    def parse(self, text):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "matrix.csv"
            path.write_text(text)
            return check.parse(path)

    def test_complete_synthetic_schema(self):
        self.assertEqual(len(self.parse(fixture())), 28)

    def test_complete_header_three_owner_bits_and_rotation(self):
        cases=self.parse(header_fixture())
        self.assertTrue(all(c['original_f32_bits_equal'] and len(c['timings'])==30 for c in cases))
        zero=header_fixture().replace('VALUE,0,0,0,1,1,1','VALUE,0,0,0,0,-0,0')
        self.assertFalse(self.parse(zero)[0]['original_f32_bits_equal'])
        failed=header_fixture().replace('VALUE,0,0,0,1,1,1','VALUE,0,0,0,1,2,1')
        self.assertEqual(len(self.parse(failed)),28)
        self.assertFalse(self.parse(failed)[0]['original_f32_bits_equal'])

    def test_header_mode_values_timings_and_totals_refuse(self):
        for old,new in [('64,32','32,32'),('VALUE,0,0,0,1,1,1','VALUE,0,0,0,1,1'),
                        ('VALUE,0,0,0,1,1,1','VALUE,0,0,0,1,1,0.1'),
                        ('TIME,0,2,0,3,0.001','TIME,0,2,1,3,0.001'),
                        ('PASS,matrix,28,420,840','PASS,matrix,28,420,560')]:
            with self.subTest(old=old),self.assertRaises(ValueError):self.parse(header_fixture().replace(old,new,1))
        with self.assertRaises(ValueError):self.parse(header_fixture().rstrip('\n'))

    def run_header_main(self,text,output,*,changed=False,interrupted=False):
        import sys
        import json
        csv=output.parent/'input.csv';csv.write_text(text)
        digest=check.digest(csv)
        oracle=[dict(candidate=dict(passed=True),reference=dict(passed=True),original=dict(passed=True),outputs=1) for _ in range(28)]
        argv=['check',str(csv),'--model',str(csv),'--model-sha256',digest,'--output',str(output)]
        values=[digest,digest,digest]
        if changed:values[-1]='c'*64
        side_effect=KeyboardInterrupt if interrupted else values
        with patch.object(sys,'argv',argv),patch.object(check,'digest',side_effect=side_effect),patch.object(check,'independent',return_value=oracle):
            status=check.main()
        return status,json.loads(output.read_text())

    def test_header_complete_failure_retains_metrics_clears_all_ratios(self):
        with tempfile.TemporaryDirectory() as d:
            status,r=self.run_header_main(header_fixture().replace('VALUE,0,0,0,1,1,1','VALUE,0,0,0,1,2,1'),Path(d)/'failed.json')
            self.assertEqual(status,1);self.assertTrue(r['collection_complete']);self.assertEqual(len(r['cases']),28)
            self.assertTrue(all(c['speed_ratio'] is None and c['original_to_cached_ratio'] is None for c in r['cases']))

    def test_header_changed_capture_interrupt_and_exclusive(self):
        with tempfile.TemporaryDirectory() as d:
            output=Path(d)/'changed.json';status,r=self.run_header_main(header_fixture(),output,changed=True)
            self.assertEqual(status,1);self.assertTrue(r['collection_complete'])
            self.assertTrue(all(c['speed_ratio'] is None and c['original_to_cached_ratio'] is None for c in r['cases']))
            before=output.read_bytes()
            with self.assertRaises(FileExistsError):self.run_header_main(header_fixture(),output)
            self.assertEqual(output.read_bytes(),before)
            status,r=self.run_header_main(header_fixture(),Path(d)/'interrupt.json',interrupted=True)
            self.assertEqual(status,1);self.assertIn('KeyboardInterrupt',r['error'])

    def test_large_rows_complete_bits_metadata_and_rotation(self):
        for rows in (128,):
            text=header_fixture().replace('turing_mma_staged_header_cache_f16_f32,64,32',f'turing_mma_staged_large_rows_f16_f32,{rows},32')
            cases=self.parse(text)
            self.assertTrue(all(c['paired_original'] and not c['cached_headers'] and c['original_f32_bits_equal'] for c in cases))
            self.assertEqual(cases[0]['tile'],(rows,8))
            for old,new in [(f'{rows},32','64,32'),(f'{rows},32','256,32'),(f'{rows},32',f'{rows},64'),('VALUE,0,0,0,1,1,1','VALUE,0,0,0,1,1'),('TIME,0,2,0,3,0.001','TIME,0,1,0,3,0.001')]:
                with self.subTest(rows=rows,old=old),self.assertRaises(ValueError):self.parse(text.replace(old,new,1))
            with self.assertRaises(ValueError):self.parse(text.rstrip('\n'))

    def test_large_rows_complete_failure_and_source_mutation_withhold_ratios(self):
        text=header_fixture().replace('turing_mma_staged_header_cache_f16_f32,64,32','turing_mma_staged_large_rows_f16_f32,128,32')
        with tempfile.TemporaryDirectory() as d:
            status,r=self.run_header_main(text,Path(d)/'pass.json')
            self.assertEqual(status,0);self.assertTrue(r['paired_original']);self.assertFalse(r['cached_headers'])
            self.assertTrue(all(c['original_to_candidate_ratio']==1 and 'original_to_cached_ratio' not in c for c in r['cases']))
            for name,t,changed in [('bits',text.replace('VALUE,0,0,0,1,1,1','VALUE,0,0,0,1,2,1'),False),('changed',text,True)]:
                status,r=self.run_header_main(t,Path(d)/(name+'.json'),changed=changed)
                self.assertEqual(status,1);self.assertEqual(len(r['cases']),28)
                self.assertTrue(all(c['speed_ratio'] is None and c['original_to_candidate_ratio'] is None for c in r['cases']))

    def test_incomplete_and_trailing(self):
        for text in (fixture().replace("PASS,matrix,28,420,560\n", ""), fixture() + "extra\n", fixture().replace("[CUDA] synthetic api=cuda cpu_offload=0\n", ""),
                     fixture().replace("VALUE,0,0,0,1,1\n", ""),
                     fixture().replace("TIME,0,0,0,3,0.001\n", "")):
            with self.assertRaises(ValueError):
                self.parse(text)

    def test_duplicate_values_timings_and_guards(self):
        for record in ("VALUE,0,0,0,1,1", "TIME,0,0,0,3,0.001", "GUARD,0,20,0"):
            with self.assertRaises(ValueError):
                self.parse(fixture().replace(record + "\n", (record + "\n") * 2))

    def test_wrong_identity_counts_and_nonfinite(self):
        for old, new in (("CASE,0,blk.0.attn_q.weight", "CASE,0,wrong"),
                         ("VALUE,0,0,0,1,1", "VALUE,0,0,0,1,nan"),
                         ("TIME,0,0,0,3,0.001", "TIME,0,0,0,3,-1"),
                         ("GUARD,0,20,0", "GUARD,0,20,1"),
                         ("PASS,matrix,28,420,560", "PASS,matrix,28,421,560")):
            with self.assertRaises(ValueError):
                self.parse(fixture().replace(old, new))

    def test_fixed_error_budgets(self):
        self.assertTrue(check.errors([1, 0], [1, 0])["passed"])
        self.assertFalse(check.errors([1.1, 0], [1, 0])["passed"])
        self.assertFalse(check.errors([1.001, .001], [1, 0])["passed"])
        with self.assertRaises(ValueError):
            check.errors([float("inf")], [1])

    def test_tile_identity_and_legacy_compatibility(self):
        legacy = self.parse(fixture())
        self.assertEqual(legacy[0]["tile"], (32, 32))
        new = fixture().replace("SYNTHETIC,144,0", "TILE,16,128\nSYNTHETIC,144,0")
        self.assertEqual(self.parse(new)[0]["tile"], (16, 128))
        for text in (new.replace("TILE,16,128", "TILE,7,128"),
                     new.replace("TILE,16,128", "TILE,16,128\nTILE,16,128"),
                     new.replace("TILE,16,128", "TILE,16,99999999")):
            with self.assertRaises(ValueError):
                self.parse(text)

    def test_versions_rejected_before_import(self):
        with patch.object(check.importlib.metadata, "version", return_value="unsupported"):
            with self.assertRaises(ValueError):
                check.independent([], Path("unused"))

    def test_turing_mode_and_mixed_layout_rejection(self):
        marker = "MODE,turing_mma_split_weight_f16_f32"
        new = fixture().replace("SYNTHETIC,144,0", marker+"\nSYNTHETIC,144,0")
        cases = self.parse(new)
        self.assertEqual(cases[0]["candidate"], marker.split(",")[1])
        self.assertEqual(cases[0]["tile"], (16, 8))
        for text in (new.replace(marker,"MODE,unknown"),
                     new.replace(marker,marker+"\n"+marker),
                     new.replace(marker,"TILE,32,32\n"+marker),
                     new.replace(marker,marker+"\nTILE,32,32"),
                     new.replace("SYNTHETIC,144,0","SYNTHETIC,144,0\n"+marker)):
            with self.assertRaises(ValueError):
                self.parse(text)

    def test_staged_turing_geometry_and_mode_rejection(self):
        for rows in (16,32,64):
            marker = f"MODE,turing_mma_staged_f16_f32,{rows}"
            text = fixture().replace("SYNTHETIC,144,0",marker+"\nSYNTHETIC,144,0")
            self.assertEqual(self.parse(text)[0]["tile"],(rows,8))
        for marker in ("MODE,turing_mma_staged_f16_f32,8", "MODE,turing_mma_staged_f16_f32,128",
                       "MODE,turing_mma_staged_f16_f32,99999999", "MODE,turing_mma_staged_f16_f32,32,extra",
                       "MODE,turing_mma_staged_f16_f32,16\nMODE,turing_mma_split_weight_f16_f32",
                       "MODE,turing_mma_staged_f16_f32,16\nTILE,32,32"):
            with self.assertRaises(ValueError):
                self.parse(fixture().replace("SYNTHETIC,144,0",marker+"\nSYNTHETIC,144,0"))

    def test_wide_geometry_bounds_and_legacy_stage(self):
        for rows in (32,64):
            for columns in (64,128):
                marker = f"MODE,turing_mma_staged_wide_f16_f32,{rows},{columns}"
                c = self.parse(fixture().replace("SYNTHETIC,144,0",marker+"\nSYNTHETIC,144,0"))[0]
                self.assertEqual(c["tile"],(rows,8))
                self.assertEqual(c["staged_input_columns"],columns)
        for marker in ("MODE,turing_mma_staged_wide_f16_f32,16,128",
                       "MODE,turing_mma_staged_wide_f16_f32,64,32",
                       "MODE,turing_mma_staged_wide_f16_f32,128,128",
                       "MODE,turing_mma_staged_wide_f16_f32,64,256",
                       "MODE,turing_mma_staged_wide_f16_f32,32,128\nMODE,turing_mma_staged_f16_f32,32"):
            with self.assertRaises(ValueError):
                self.parse(fixture().replace("SYNTHETIC,144,0",marker+"\nSYNTHETIC,144,0"))


if __name__ == "__main__":
    unittest.main()
