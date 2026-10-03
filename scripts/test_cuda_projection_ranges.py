"""Synthetic portable attribution contracts, separate from actual GPU proof."""
import copy
import unittest
from cuda_projection_ranges import attribute, STAGES


class Contracts(unittest.TestCase):
    def setUp(self):
        self.outer=(100,2000,16777217);self.tiles={1:1,4:0,32:0}
        self.rows=[];self.launches={};self.kernels=[]
        for i,stage in enumerate((*STAGES,"head")):
            start=110+i*100
            self.rows.append((start,start+20,59,self.outer[2],None,f'aesir.project.{stage}.b1',None))
            self.launches[i+1]=(start+1,start+2,self.outer[2])
            self.kernels.append((i+1,'core_packed_projection_block_mock',start+50,start+60))
        # Physical model has28 independently labelled layers for each stage.
        for layer in range(1,28):
            for stage in STAGES:
                i=len(self.rows);start=110+i*30
                self.rows.append((start,start+20,59,self.outer[2],None,f'aesir.project.{stage}.b1',None))
                self.launches[i+1]=(start+1,start+2,self.outer[2])
                self.kernels.append((i+1,'core_packed_projection_block_mock',start+22,start+25))
        # Reorder first eight ranges to the same disjoint30ns spacing.
        self.outer=(100,10000,16777217)
        for i,row in enumerate(self.rows):
            start=110+i*30
            self.rows[i]=(start,start+20,*row[2:])
            self.launches[i+1]=(start+1,start+2,self.outer[2])
            self.kernels[i]=(i+1,'core_packed_projection_block_mock',start+22,start+25)

    def check(self):return attribute(self.rows,{},self.outer,self.launches,self.kernels,self.tiles)

    def test_complete_asynchronous_projection(self):
        result=self.check();self.assertTrue(result['passed'])
        self.assertEqual(result['cpu_range_count'],197)
        self.assertEqual(result['kernel_count'],197)
        self.assertEqual(result['groups']['head.b1']['rows'],128256)

    def test_missing_duplicate_and_wrong_plan(self):
        before=copy.deepcopy(self.rows)
        for rows in [before[:-1],before+[before[-1]]]:
            self.rows=rows
            with self.assertRaises(ValueError):self.check()
        self.rows=before;self.tiles={1:True,4:0,32:0}
        with self.assertRaises(ValueError):self.check()

    def test_wrong_label_batch_type_thread_boundary(self):
        before=self.rows[0]
        for row in [(before[0],before[1],60,*before[3:]),
                    (*before[:3],16777218,*before[4:]),
                    (*before[:4],16777218,*before[5:]),
                    (*before[:5],'aesir.project.query.b32',None),
                    (*before[:5],'aesir.project.unknown.b1',None),
                    (99,*before[1:])]:
            self.rows[0]=row
            with self.assertRaises(ValueError):self.check()
        self.rows[0]=before

    def test_overlapping_ranges(self):
        self.rows[1]=(111,*self.rows[1][1:])
        with self.assertRaises(ValueError):self.check()

    def test_missing_unattributed_or_nonprojection_kernel(self):
        original=self.kernels.copy()
        for kernels in [original[:-1],original+[(999,'core_packed_projection_block_matvec_extra',7000,7010)],
                        [(original[0][0],'embedding',*original[0][2:])]+original[1:]]:
            self.kernels=kernels
            if len(kernels)>len(original):self.launches[999]=(7000,7001,self.outer[2])
            with self.assertRaises(ValueError):self.check()

    def test_launch_end_and_thread_containment(self):
        start,end,tid=self.launches[1]
        for launch in [(start,end,tid+1),(start,self.rows[0][1]+1,tid)]:
            self.launches[1]=launch
            with self.assertRaises(ValueError):self.check()

    def test_registered_labels(self):
        strings={}
        for i,row in enumerate(self.rows):
            strings[i]=row[5];self.rows[i]=(*row[:5],None,i)
        self.assertTrue(attribute(self.rows,strings,self.outer,self.launches,self.kernels,self.tiles)['passed'])

    def test_batch32_key_value_requires_eight_actual_launches(self):
        self.tiles={1:0,4:0,32:1};self.rows=[];self.launches={};self.kernels=[]
        for stage in STAGES:
            for layer in range(28):
                start=110+len(self.rows)*30
                self.rows.append((start,start+20,59,self.outer[2],None,f'aesir.project.{stage}.b32',None))
                for _ in range(8 if stage in ('key','value') else 1):
                    c=len(self.kernels)+1;self.launches[c]=(start+1,start+2,self.outer[2])
                    self.kernels.append((c,'core_packed_projection_four_matvec',start+21,start+22))
        start=110+len(self.rows)*30
        self.rows.append((start,start+20,59,self.outer[2],None,'aesir.project.head.b1',None))
        c=len(self.kernels)+1;self.launches[c]=(start+1,start+2,self.outer[2]);self.kernels.append((c,'core_packed_projection_block_matvec',start+21,start+22))
        self.assertEqual(self.check()['groups']['key.b32']['kernel_count'],224)
        self.kernels.pop(0)
        with self.assertRaises(ValueError):self.check()


if __name__=='__main__':unittest.main()
