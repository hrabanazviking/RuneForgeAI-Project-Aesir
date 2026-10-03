"""Portable token-partition evidence contracts; no GPU execution claim."""
from pathlib import Path
import json
import sys
import tempfile
import unittest
from unittest.mock import patch

import check_packed_matrix as check
from test_check_packed_matrix import header_fixture

MODE='MODE,turing_mma_token_partition_f16_f32,64,8,32'


def fixture(rows=64,tokens=8):
    lines=header_fixture().replace('MODE,turing_mma_staged_header_cache_f16_f32,64,32',f'MODE,turing_mma_token_partition_f16_f32,{rows},{tokens},32').splitlines()
    out=[]
    for line in lines:
        if line.startswith('GUARD,'):
            index=int(line.split(',')[1]);batch=check.BATCHES[index//7]
            line=f'GUARD,{index},{batch*378},0'
        out.append(line)
        if line.startswith('CASE,'):
            parts=line.split(',');index=int(parts[1]);batch=int(parts[6])
            out.extend([f'PARTITION,{index},{rows},{tokens},1,{(batch+tokens-1)//tokens},{rows//16*32},1',f'SELECTED,{index},64,32'])
    return '\n'.join(out)+'\n'


class Contracts(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.csv=self.root/'capture';self.model=self.root/'model';self.binary=self.root/'binary'
        self.model.write_bytes(b'model');self.binary.write_bytes(b'binary')
        self.sequence=0

    def parse(self,text):
        self.csv.write_text(text)
        return check.parse(self.csv,allow_partition=True)

    def test_four_explicit_geometries_and_selected_scope(self):
        for rows in (64,128):
            for tokens in (8,16):
                data=self.parse(fixture(rows,tokens))
                self.assertEqual(len(data),28);self.assertTrue(all(c['original_f32_bits_equal'] for c in data))
                self.assertEqual(data[-1]['partition_dispatch'],dict(token_tile=tokens,grid_x=1,grid_y=(32+tokens-1)//tokens,block_x=rows//16*32,host_enqueues=1))
                self.assertEqual(data[-1]['selected_original_rows'],64)
        with self.assertRaises(ValueError):check.parse(self.csv)
        with self.assertRaises(ValueError):check.parse(self.csv,allow_partition=1)
        with self.assertRaises(ValueError):self.parse(header_fixture())

    def test_geometry_marker_owner_counts_and_dispatch_before_values(self):
        text=fixture()
        for a,b in [(MODE,MODE.replace('64,8,32','32,8,32')),(MODE,MODE.replace('64,8,32','64,4,32')),
                    (MODE,MODE.replace('64,8,32','64,8,16')),('PARTITION,0,64,8,1,1,128,1','PARTITION,0,64,8,1,2,128,1'),
                    ('PARTITION,0,64,8,1,1,128,1','PARTITION,0,64,8,1,1,256,1'),('PARTITION,0,64,8,1,1,128,1','PARTITION,0,64,8,1,1,128,2'),
                    ('PARTITION,0,64,8,1,1,128,1\n',''),('SELECTED,0,64,32\n',''),('SELECTED,0,64,32','SELECTED,0,128,32'),
                    ('SELECTED,0,64,32','SELECTED,0,64,32\nSELECTED,0,64,32'),('SELECTED,0,64,32\n','VALUE,0,0,0,1,1,1\nSELECTED,0,64,32\n'),
                    ('GUARD,0,1512,0','GUARD,0,1511,0'),('PASS,matrix,28,420,840','PASS,matrix,28,420,560')]:
            with self.subTest(a=a),self.assertRaises(ValueError):self.parse(text.replace(a,b,1))
        with self.assertRaises(ValueError):self.parse(text.rstrip('\n'))

    def test_selected_down128_only_at_canonical_actual_shape(self):
        text=fixture();start=text.index('CASE,27,');end=text.index('TIME,27,',start)
        replacement='CASE,27,blk.0.ffn_down.weight,12,8192,3072,32,32\nPARTITION,27,64,8,48,4,128,1\nSELECTED,27,128,32\n'
        replacement+=''.join(f'VALUE,27,{t},{r},1,1,1\n' for t in range(32) for r in range(3072))+'GUARD,27,264064,0\n'
        text=(text[:start]+replacement+text[end:]).replace('PASS,matrix,28,420,840','PASS,matrix,28,98692,840')
        self.assertEqual(self.parse(text)[-1]['selected_original_rows'],128)
        with self.assertRaises(ValueError):self.parse(text.replace('SELECTED,27,128,32','SELECTED,27,64,32'))

    def test_full_f32_signed_zero_and_nonfinite_order_sample(self):
        text=fixture()
        for a,b in [('VALUE,0,0,0,1,1,1','VALUE,0,0,0,0,-0,0'),('VALUE,0,0,0,1,1,1','VALUE,0,0,0,1,2,1')]:
            data=self.parse(text.replace(a,b,1));self.assertFalse(data[0]['original_f32_bits_equal']);self.assertEqual(len(data),28)
        for a,b in [('VALUE,0,0,0,1,1,1','VALUE,0,0,0,1,0.1,1'),('VALUE,0,0,0,1,1,1','VALUE,0,0,0,1,nan,1'),
                    ('TIME,0,0,0,3,0.001','TIME,0,0,0,3,5e-324'),('TIME,0,0,0,3,0.001','TIME,0,1,0,3,0.001')]:
            with self.assertRaises(ValueError):self.parse(text.replace(a,b,1))

    def run_main(self,text=None,change=None,interrupted=False,omit=False):
        self.csv.write_text(fixture() if text is None else text)
        self.sequence+=1
        out=self.root/f'report-{self.sequence}'
        hashes=['a'*64,'a'*64,'a'*64,check.digest(self.csv),'a'*64]
        if change is not None:hashes[change]='b'*64
        argv=['checker',str(self.csv),'--partition-tokens','--binary',str(self.binary),'--binary-sha256','a'*64,
              '--model',str(self.model),'--model-sha256','a'*64,'--output',str(out)]
        if omit:argv.remove('--partition-tokens')
        oracle=[dict(candidate=dict(passed=True),reference=dict(passed=True),original=dict(passed=True),outputs=1) for _ in range(28)]
        with patch.object(sys,'argv',argv),patch.object(check,'digest',side_effect=KeyboardInterrupt if interrupted else hashes),patch.object(check,'independent',return_value=oracle):
            result=check.main()
        return result,json.loads(out.read_text()),out,argv

    def test_current_binary_model_csv_hashes_and_explicit_required(self):
        status,r,_,_=self.run_main();self.assertEqual(status,0);self.assertEqual(r['partition_tokens'],8)
        for index in (0,1,2,3,4):
            status,r,_,_=self.run_main(change=index);self.assertEqual(status,1)
            if index>=2:
                self.assertTrue(r['collection_complete']);self.assertEqual(len(r['cases']),28)
                self.assertTrue(all(c['speed_ratio'] is None and c['original_to_candidate_ratio'] is None for c in r['cases']))
        status,r,_,_=self.run_main(omit=True);self.assertEqual(status,1)

    def test_complete_numeric_bit_failure_and_ratio_overflow_atomic(self):
        status,r,_,_=self.run_main(text=fixture().replace('VALUE,0,0,0,1,1,1','VALUE,0,0,0,1,2,1',1));self.assertEqual(status,1)
        self.assertEqual(len(r['cases']),28);self.assertTrue(all(c['speed_ratio'] is None and c['original_to_candidate_ratio'] is None for c in r['cases']))
        text=fixture()
        for line in text.splitlines():
            if line.startswith('TIME,'):
                parts=line.split(',');parts[-1]='1e308' if parts[2]!='1' else '5e-323';text=text.replace(line,','.join(parts))
        status,r,_,_=self.run_main(text=text);self.assertEqual(status,1);self.assertTrue(r['collection_complete']);self.assertEqual(len(r['cases']),28)
        self.assertIn('Nonfinite matrix ratio',r['error']);self.assertTrue(all(c['speed_ratio'] is None and c['original_to_candidate_ratio'] is None for c in r['cases']))

    def test_interrupt_and_exclusive_output_preserves_failure(self):
        status,r,out,argv=self.run_main(interrupted=True);self.assertEqual(status,1);self.assertIn('KeyboardInterrupt',r['error']);before=out.read_bytes()
        with patch.object(sys,'argv',argv),self.assertRaises(FileExistsError):check.main()
        self.assertEqual(out.read_bytes(),before)


if __name__=='__main__': unittest.main()
