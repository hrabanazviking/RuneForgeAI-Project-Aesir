#!/usr/bin/env python3
"""Independent sealed ordinary JSON ownership checks; no inference/device work."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import random
import subprocess
import sys
import tempfile
import unittest

CONFIG = argparse.Namespace()
POLICY = {'config': (1048576, 10000, 10000000, 64),
          'index': (1048576, 10000, 10000, 10000000, 64)}


def encode(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':')).encode()


class SealedMetadata(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='aesir-sealed-metadata-')
        cls.root = Path(cls.temp.name)
        cls.evidence = Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True, exist_ok=False)
        cls.records, cls.images, cls.expected = [], [], []
        for name in ('binary', 'api', 'config_control', 'index_control',
                     'faults', 'copy_faults', 'mutation_faults'):
            setattr(cls, name, str(Path(getattr(CONFIG, name)).resolve(strict=True)))

    @classmethod
    def tearDownClass(cls):
        for name, value in [('runs', cls.records), ('images', cls.images), ('independent', cls.expected)]:
            (cls.evidence / (name + '.json')).write_text(json.dumps(value, indent=2) + '\n')
        counts = Counter('accepted' if r['returncode'] == 0 else 'refused' for r in cls.records)
        (cls.evidence / 'summary.json').write_text(json.dumps(dict(counts), indent=2) + '\n')
        print('Native outcomes:', dict(counts))
        cls.temp.cleanup()

    def fixture(self, raw):
        path = self.root / ('source-%04d.json' % len(self.records))
        path.write_bytes(raw)
        self.images.append(dict(path=str(path), before_hex=raw.hex(), sha256=hashlib.sha256(raw).hexdigest()))
        return path

    def child(self, command, env=None, trace=False):
        command = list(map(str, command))
        trace_path = None
        if trace:
            trace_path = self.evidence / ('run-%04d.strace' % len(self.records))
            command = [CONFIG.strace, '-f', '-yy', '-s', '4096', '-o', str(trace_path),
                       '-e', 'trace=%file,%desc,%memory,%network,%process', *command]
        result = subprocess.run(command, capture_output=True, text=True, stdin=subprocess.DEVNULL,
                                timeout=30, env=env, check=False)
        self.records.append(dict(arguments=command, returncode=result.returncode,
                                 stdout=result.stdout, stderr=result.stderr,
                                 trace=str(trace_path) if trace_path else None,
                                 fault_environment={k: v for k, v in (env or {}).items()
                                                    if k.startswith('AESIR_') or k == 'LD_PRELOAD'}))
        return result

    def call(self, kind, path, mode='normal', label=None, byte_bound=1048576,
             digest_bound=16384, policy=None, env=None, trace=True):
        return self.child([self.api, kind, mode, path, str(path) if label is None else label,
                           byte_bound, digest_bound, *(policy or POLICY[kind])], env, trace)

    def reference(self, kind, path, policy=None):
        result = self.child([getattr(self, kind + '_control'), path, *(policy or POLICY[kind])])
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def exact(self, result, raw, reference, label=None):
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = result.stdout.splitlines()
        self.assertEqual(len(lines), 3)
        self.assertEqual(lines[0], hashlib.sha256(raw).hexdigest())
        self.assertEqual(bytes.fromhex(lines[2]), raw)
        if label is None:
            self.assertEqual(lines[1], reference.stdout.rstrip('\n'))
        else:
            expected = json.loads(reference.stdout); expected['source_path'] = label
            self.assertEqual(json.loads(lines[1]), expected)
        self.assertEqual(result.stderr, '')
        return json.loads(lines[1])

    def refused(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn('Unhandled exception caught during execution:', result.stderr)
        self.assertNotIn('sealed_metadata_bytes_bound', result.stdout)

    def test_complete_fields_raw_spans_and_independent_counters(self):
        rng = random.Random(777)
        for i in range(24):
            # Raw spellings, Unicode/NUL decoded keys, null/default modifiers and
            # nested unknown values remain metadata, with no normalization.
            fields = [('model_type', '"llama"'), ('rope_scaling', 'null'),
                      ('head_dim', 'null'), ('hidden_size', str(rng.randrange(1, 8193))),
                      ('κ\0' + str(i), '[1, 2.5e+2, {"x":false}]'),
                      ('unknown', '{ "default" : null, "items" : [true, "λ"] }')]
            raw = ('{ ' + ', '.join(json.dumps(k, ensure_ascii=False) + ' : ' + v for k,v in fields) + ' }\n').encode()
            path = self.fixture(raw); reference = self.reference('config', path)
            report = self.exact(self.call('config', path, trace=i < 2), raw, reference)
            self.assertEqual(report['fields_raw'], dict(fields))
            self.assertEqual(report['root_fields'], len(fields))
            self.assertEqual(report['work_units'], 4*len(raw) + len(fields))
            self.expected.append(dict(kind='config', source_hex=raw.hex(), fields_raw=dict(fields),
                                      work_units=4*len(raw)+len(fields)))
            mapping = {'layer.λ\0.' + str(i): 'ordinary-1.safetensors', 'q.weight': '../unopened.bin'}
            meta = [('total_size', str(i*17)), ('custom', '[null, {"λ":1}]')]
            unknown = [('extension', '{ "keep": null }')]
            raw = ('{"weight_map":' + encode(mapping).decode() + ',"metadata":{' +
                   ','.join(json.dumps(k)+':'+v for k,v in meta) + '},' +
                   ','.join(json.dumps(k)+':'+v for k,v in unknown) + '}').encode()
            path = self.fixture(raw); reference = self.reference('index', path)
            report = self.exact(self.call('index', path, trace=i < 2), raw, reference)
            self.assertEqual(report['weight_map'], mapping)
            self.assertEqual(report['metadata_raw'], dict(meta))
            self.assertEqual(report['unknown_fields_raw'], dict(unknown))
            members = 3 + len(mapping) + len(meta)
            self.assertEqual(report['schema_fields'], members)
            self.assertEqual(report['work_units'], 4*len(raw)+members)
            self.expected.append(dict(kind='index', source_hex=raw.hex(), weight_map=mapping,
                                      metadata_raw=dict(meta), unknown_fields_raw=dict(unknown),
                                      schema_fields=members, work_units=4*len(raw)+members))

    def test_minimal_boundaries_and_full_tool_flags(self):
        for kind, base in [('config', b'{}'), ('index', b'{"weight_map":{}}')]:
            for size in (len(base), 4095, 4096, 4097, 8191, 8192, 8193, 16383, 16384, 16385):
                raw = base + b' '*(size-len(base)); path = self.fixture(raw)
                reference = self.reference(kind, path)
                self.exact(self.call(kind, path, byte_bound=size), raw, reference)
                result = self.child([self.binary, kind, path, size, 64, 64, 64, *POLICY[kind]], trace=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                report = json.loads(result.stdout)
                self.assertTrue(report['sealed_metadata_bytes_bound'])
                self.assertEqual(report['parsed'], json.loads(reference.stdout))
                self.assertEqual(report['source_bytes'], size)
                self.assertEqual(report['digest_hex'], hashlib.sha256(raw).hexdigest())
                for key, value in report.items():
                    if key.endswith('_verified') or key in ('execution_tested', 'device_access'):
                        self.assertIs(value, False, key)
            raw = base; path = self.fixture(raw); ref = self.reference(kind, path)
            for label in ('diagnostic-label-without-a-file', 'κ\nlabel'):
                self.exact(self.call(kind, path, label=label), raw, ref, label)

    def test_move_close_copied_values_cache_and_bad_owners(self):
        for kind, raw in [('config', b'{"x":null}'), ('index', b'{"weight_map":{"x":"shard.bin"}}')]:
            path = self.fixture(raw); reference = self.reference(kind, path)
            for mode in ('normal', 'move', 'retained', 'cache', 'recover'):
                self.exact(self.call(kind, path, mode), raw, reference)
            for mode in ('closed', 'bad_size', 'bad_arch', 'bad_fd', 'unsealed'):
                self.refused(self.call(kind, path, mode))
                self.exact(self.call(kind, path), raw, reference)
            for mode in ('closed_fd', 'large_fd'):
                result = self.call(kind, path, mode)
                self.assertEqual((result.returncode,result.stdout,result.stderr),(0,'refused\n',''))
            for bound in (0, -1, len(raw)-1):
                self.refused(self.call(kind, path, byte_bound=bound))
            for bound in (0, -1):
                self.refused(self.call(kind, path, digest_bound=bound))

    def test_actual_original_mutations_with_independent_repeats(self):
        for kind, raw in [('config', b'{"x":null}\n'), ('index', b'{"weight_map":{"x":"a.bin"}}\n')]:
            path = self.fixture(raw); reference = self.reference(kind, path)
            for mode in ('truncate', 'mutate', 'replace', 'same_extent'):
                results = []
                posts = []
                for repeat in range(2):
                    path.write_bytes(raw)
                    env = None
                    if mode == 'same_extent':
                        env = dict(os.environ, LD_PRELOAD=self.mutation_faults,
                                   AESIR_SAFETENSORS_MUTATION_PATH=str(path))
                    result = self.call(kind, path, 'normal' if env else mode, env=env)
                    self.exact(result, raw, reference)
                    post = path.read_bytes(); posts.append(post)
                    results.append((result.returncode,result.stdout,result.stderr))
                    expected = (raw[:1] if mode == 'truncate' else b'' if mode in ('mutate','replace')
                                else raw[:-1]+bytes([raw[-1]^0x40]))
                    self.assertEqual(post, expected)
                    self.images.append(dict(path=str(path), mode=mode, repeat=repeat,
                                            before_hex=raw.hex(), after_hex=post.hex()))
                self.assertEqual(results[0], results[1]); self.assertEqual(posts[0], posts[1])
                path.write_bytes(raw)
                self.exact(self.call(kind, path), raw, reference)

    def test_parser_refusals_and_policy_recovery(self):
        # Large exponents are valid JSON metadata spellings; no numeric
        # conversion occurs. Overflow refusal belongs to typed total_size.
        raw = b'{"x":1e999999999999999999999999}'
        path = self.fixture(raw); reference = self.reference('config',path)
        parsed = self.exact(self.call('config',path),raw,reference)
        self.assertEqual(parsed['fields_raw'], {'x':'1e999999999999999999999999'})
        common = [b'', b'null', b'0', b'[]', b'{}x', b'{"x":}', b'{"x":1,}',
                  b'{"x":1,"\\u0078":2}', b'{"x":{"a":1,"a":2}}', b'{"x":"\xff"}',
                  b'{"x":"\\ud800"}', b'{"x":"a\x00b"}',
                  b'{"x":'+b'['*65+b'0'+b']'*65+b'}']
        for kind in ('config','index'):
            candidates = list(common)
            if kind == 'index':
                candidates += [b'{}', b'{"weight_map":null}', b'{"weight_map":{"x":1}}',
                               b'{"weight_map":{},"metadata":{"total_size":9223372036854775808}}',
                               b'{"weight_map":{},"metadata":{"total_size":null}}',
                               b'{"weight_map":{"x":"a","\\u0078":"b"}}']
            for raw in candidates:
                self.refused(self.call(kind, self.fixture(raw)))
            raw = b'{"a":0,"b":1}' if kind == 'config' else b'{"weight_map":{"a":"x","b":"y"}}'
            path = self.fixture(raw); reference = self.reference(kind,path)
            for pos in range(len(POLICY[kind])):
                for bound in (0, -1):
                    policy = list(POLICY[kind]); policy[pos] = bound
                    self.refused(self.call(kind,path,policy=policy))
            for policy in ([len(raw)-1,*POLICY[kind][1:]],
                           [*POLICY[kind][:-2],len(raw)*4-1,64],
                           [*POLICY[kind][:-1],65],
                           [*POLICY[kind][:1],1,*POLICY[kind][2:]]):
                self.refused(self.call(kind,path,policy=policy))
            self.exact(self.call(kind,path),raw,reference)
            self.refused(self.child([self.binary,kind,path,len(raw)-1,64,64,64,*POLICY[kind]],trace=True))
            large = raw+b' '*8192; path = self.fixture(large)
            self.refused(self.call(kind,path,digest_bound=1))

    def test_injected_copy_hash_seal_and_metadata_fault_recovery(self):
        for kind, raw in [('config',b'{"x":null}'),('index',b'{"weight_map":{}}')]:
            path = self.fixture(raw); reference = self.reference(kind,path)
            for mode in ('parser_digest','metadata_error','metadata_eintr','metadata_eof',
                         'metadata_extra','metadata_lookahead','after_metadata','metadata_short'):
                log = self.evidence / (kind+'-'+mode+'.jsonl')
                env = dict(os.environ,LD_PRELOAD=self.faults,AESIR_METADATA_FAULT=mode,AESIR_METADATA_LOG=str(log))
                result = self.call(kind,path,env=env)
                events = [json.loads(x) for x in log.read_text().splitlines()]
                self.assertTrue(any(e['op']=='read' and e['phase']>=2 for e in events))
                if mode == 'metadata_short': self.exact(result,raw,reference)
                else: self.refused(result)
                self.exact(self.call(kind,path),raw,reference)
            for mode in ('create','read_error','read_eof','write_error','write_zero',
                         'seal','seal_after','missing_seals','digest_error','digest_eof'):
                log = self.evidence / (kind+'-copy-'+mode+'.jsonl')
                env = dict(os.environ,LD_PRELOAD=self.copy_faults,AESIR_SEAL_FAULT_MODE=mode,
                           AESIR_SEAL_FAULT_PATH=str(path),AESIR_SEAL_FAULT_LOG=str(log))
                self.refused(self.call(kind,path,env=env))
                self.assertTrue(log.read_text())
                self.assertEqual(path.read_bytes(),raw)
                self.exact(self.call(kind,path),raw,reference)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    for name in ('binary','api','config-control','index-control','faults','copy-faults',
                 'mutation-faults','strace','evidence'):
        parser.add_argument('--'+name, required=True)
    CONFIG, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
