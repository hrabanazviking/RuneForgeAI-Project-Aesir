"""Synthetic hostile small-score resource/source contracts; no physical proof."""
from contextlib import closing
import copy
import hashlib
import json
import sqlite3
import sys
import unittest
from unittest.mock import patch

import check_cuda_trace as cuda
import check_small_attention_resources as check
from cuda_projection_ranges import RESOURCE_FIELDS
import test_check_small_fused_attention as source_contracts
from test_check_cuda_trace import fixture as sqlite_fixture


class Contracts(unittest.TestCase):
    def setUp(self):
        source_contracts.Contracts.setUp(self)
        self.data = check.attention.parse(self.path)
        self.cpu = check.attention.summarize(self.data, source_contracts.oracle(self.data))
        self.cpu.update(binary_sha256='b'*64, oracle_versions={'numpy': '2.4.4'})
        self.db = self.root/'capture.sqlite'
        sqlite_fixture(self.db)
        with closing(sqlite3.connect(self.db)) as db:
            db.execute('DELETE FROM CUPTI_ACTIVITY_KIND_KERNEL')
            db.execute('DELETE FROM CUPTI_ACTIVITY_KIND_RUNTIME')
            db.execute("UPDATE StringIds SET value=? WHERE id=2", (check.PREFIXES[0]+'mock',))
            db.execute("INSERT INTO StringIds VALUES(4,?)", (check.PREFIXES[1]+'mock',))
            db.execute('UPDATE ANALYSIS_DETAILS SET duration=999900,stopTime=1000000')
            for field in ('registersPerThread', 'staticSharedMemory', 'dynamicSharedMemory', 'localMemoryPerThread', 'localMemoryTotal', 'gridX', 'gridY', 'gridZ', 'blockX', 'blockY', 'blockZ'):
                db.execute('ALTER TABLE CUPTI_ACTIVITY_KIND_KERNEL ADD COLUMN '+field)
            index = 0
            for case in self.data['cases']:
                for owner in range(2):
                    for _ in range(33):
                        index += 1
                        start = 100+index*10
                        db.execute('INSERT INTO CUPTI_ACTIVITY_KIND_RUNTIME VALUES(?,?,?,?,?,0)', (start, start+1, 16777217, index, 1))
                        resources = (46, 16384 if owner == 0 else 6144, 0, 0, 999, 24, case['tokens'], 1, 128, 1, 1)
                        db.execute('INSERT INTO CUPTI_ACTIVITY_KIND_KERNEL VALUES('+','.join(['?']*19)+')', (start+2, start+3, 0, 1, 1, index, 16777216, 2 if owner == 0 else 4, *resources))
            db.commit()
        self.trace = self.analyze()

    def analyze(self, **kwargs):
        return cuda.analyze(self.db, expected_pid=1, record_resources=True, fused_primitive=True, **kwargs)

    def test_complete_sources_and_observed_resources(self):
        check.validate_oracle(self.data, self.cpu)
        check.same_vectors(self.data, copy.deepcopy(self.data))
        r = check.validate_resources(self.trace, self.data)
        self.assertEqual(r['kernel_count'], 396)
        self.assertEqual(r['static_shared_bytes'], {'original': 16384, 'small': 6144})
        self.assertTrue(all(g['resources']['legacy_local_bytes_total_deprecated'] == 999 for g in r['recorded_resource_distributions']))
        self.assertNotIn('primitive_resource_distributions', cuda.analyze(self.db))

    def test_actual_pid_and_exclusive_explicit_admission(self):
        for kwargs in ({}, {'fused_primitive': True}, {'record_resources': True}, {'fused_primitive': 1, 'record_resources': True},
                       {'fused_primitive': True, 'record_resources': True, 'down128': True},
                       {'fused_primitive': True, 'record_resources': True, 'fused_attention': True},
                       {'fused_primitive': True, 'record_resources': True, 'projection_tiles': {1: 1}},
                       {'fused_primitive': True, 'record_resources': True, 'nvtx_range': 'x'}):
            if not kwargs:
                self.assertNotIn('primitive_resource_distributions', cuda.analyze(self.db));continue
            with self.assertRaises(ValueError):cuda.analyze(self.db, **kwargs)
        with self.assertRaises(ValueError):cuda.analyze(self.db, expected_pid=2, record_resources=True, fused_primitive=True)

    def test_full_session_bad_resources_and_correlations(self):
        for field, value in [('registersPerThread', -1), ('staticSharedMemory', 1.5), ('dynamicSharedMemory', -1), ('localMemoryPerThread', -1), ('localMemoryTotal', -1), ('gridX', 0), ('blockX', 1025)]:
            with closing(sqlite3.connect(self.db)) as db:
                original = db.execute('SELECT '+field+' FROM CUPTI_ACTIVITY_KIND_KERNEL WHERE correlationId=396').fetchone()[0]
                db.execute('UPDATE CUPTI_ACTIVITY_KIND_KERNEL SET '+field+'=? WHERE correlationId=396', (value,));db.commit()
            with self.subTest(field=field), self.assertRaises(ValueError):self.analyze()
            with closing(sqlite3.connect(self.db)) as db:db.execute('UPDATE CUPTI_ACTIVITY_KIND_KERNEL SET '+field+'=? WHERE correlationId=396', (original,));db.commit()
        for sql in ('UPDATE CUPTI_ACTIVITY_KIND_RUNTIME SET returnValue=1 WHERE correlationId=396',
                    'DELETE FROM CUPTI_ACTIVITY_KIND_KERNEL WHERE correlationId=396',
                    'UPDATE CUPTI_ACTIVITY_KIND_KERNEL SET globalPid=33554432 WHERE correlationId=396'):
            backup = self.db.read_bytes()
            with closing(sqlite3.connect(self.db)) as db:db.execute(sql);db.commit()
            with self.assertRaises(ValueError):self.analyze()
            self.db.write_bytes(backup)

    def test_source_geometry_footprint_count_and_identity(self):
        for defect in ('grid', 'block', 'shared', 'dynamic', 'name', 'missing', 'duplicate', 'count', 'scope', 'excluded', 'duration'):
            trace = copy.deepcopy(self.trace);group = trace['primitive_resource_distributions'][-1]
            if defect == 'grid':group['resources']['grid_y'] += 1
            elif defect == 'block':group['resources']['block_x'] = 64
            elif defect == 'shared':group['resources']['static_shared_bytes'] += 4
            elif defect == 'dynamic':group['resources']['dynamic_shared_bytes'] = 4
            elif defect == 'name':group['kernel'] = 'unexpected'
            elif defect == 'missing':trace['primitive_resource_distributions'].pop()
            elif defect == 'duplicate':trace['primitive_resource_distributions'].append(copy.deepcopy(group))
            elif defect == 'count':group['kernel_count'] -= 1
            elif defect == 'scope':trace['scope'] = 'owned_nvtx_prefill'
            elif defect == 'excluded':trace['excluded_kernel_count'] = 1
            else:group['gpu_total_ns'] = 0
            with self.subTest(defect=defect), self.assertRaises(ValueError):check.validate_resources(trace, self.data)

    def test_every_profile_value_bit_and_source_guard(self):
        for defect in ('count', 'candidate', 'native', 'guards', 'mode', 'bits'):
            data = copy.deepcopy(self.data)
            if defect == 'count':data['cases'].pop()
            elif defect in ('candidate', 'native'):data['cases'][-1][defect][-1] = -0.
            elif defect == 'bits':data['cases'][-1]['original_f32_bits_equal'] = False
            else:data['cases'][-1][defect] += 1
            with self.subTest(defect=defect), self.assertRaises(ValueError):check.same_vectors(self.data, data)
        a = copy.deepcopy(self.data);b = copy.deepcopy(self.data)
        a['cases'][-1]['native'][-1] = 0.;b['cases'][-1]['native'][-1] = -0.
        with self.assertRaises(ValueError):check.same_vectors(a, b)

    def test_cpu_json_duplicate_and_nonfinite_refusal(self):
        with self.assertRaises(ValueError):json.loads('{"passed":true,"passed":true}', object_pairs_hook=check.unique_object)
        with self.assertRaises(ValueError):json.loads('{"value":NaN}', parse_constant=check.reject_constant)

    def test_cpu_budget_identity_and_atomic_ratios(self):
        for defect in ('version', 'count', 'index', 'maximum', 'rms', 'boolean', 'timing', 'hash', 'passed'):
            cpu = copy.deepcopy(self.cpu)
            if defect == 'version':cpu['oracle_versions']['numpy'] = '0'
            elif defect == 'count':cpu['oracle'][-1]['outputs'] -= 1
            elif defect == 'index':cpu['oracle'][-1]['index'] = True
            elif defect == 'maximum':cpu['oracle'][-1]['candidate']['maximum_scaled_error'] = .002001
            elif defect == 'rms':cpu['oracle'][-1]['native']['normalized_rms'] = .0002001
            elif defect == 'boolean':cpu['oracle'][-1]['candidate']['maximum_scaled_error'] = False
            elif defect == 'timing':cpu['cases'][-1]['original_to_small_ratio'] = 2
            elif defect == 'hash':cpu['csv_sha256'] = 'a'*64
            else:cpu['passed'] = False
            with self.subTest(defect=defect), self.assertRaises(ValueError):check.validate_oracle(self.data, cpu)

    def arguments(self, out):
        return ['check', '--unprofiled', str(self.path), '--profiled', str(self.path), '--reference-report', str(self.root/'cpu.json'),
                '--sqlite', str(self.db), '--binary', str(self.root/'binary'), '--binary-sha256', 'b'*64, '--output', str(out)]

    def test_all_after_hashes_interrupt_and_exclusive_receipts(self):
        (self.root/'cpu.json').write_text(json.dumps(self.cpu))
        csvhash = hashlib.sha256(self.text.encode()).hexdigest()
        before = ['b'*64, csvhash, csvhash, 'c'*64, 'd'*64]
        for index in range(5):
            out = self.root/f'changed-{index}.json';after = before.copy();after[index] = 'e'*64
            with patch.object(sys, 'argv', self.arguments(out)), patch.object(check, 'digest', side_effect=before+after), patch.object(check, 'analyze', return_value=self.trace):
                self.assertEqual(check.main(), 1)
            r = json.loads(out.read_text());self.assertFalse(r['passed']);self.assertTrue(r['collection_complete']);self.assertFalse(r['speed_scored']);self.assertIn('artifact changed', r['error'])
        out = self.root/'interrupt.json'
        with patch.object(sys, 'argv', self.arguments(out)), patch.object(check, 'digest', side_effect=KeyboardInterrupt):self.assertEqual(check.main(), 1)
        saved = out.read_bytes();self.assertIn('KeyboardInterrupt', json.loads(saved)['error'])
        with patch.object(sys, 'argv', self.arguments(out)), self.assertRaises(FileExistsError):check.main()
        self.assertEqual(saved, out.read_bytes())


if __name__ == '__main__':
    unittest.main()
