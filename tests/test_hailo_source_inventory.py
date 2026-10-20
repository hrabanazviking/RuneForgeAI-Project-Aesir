#!/usr/bin/env python3
"""Independent tiny GGUF v3 byte fixtures. Metadata only, never LLM inference."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

CONFIG = argparse.Namespace()


def string(raw):
    if isinstance(raw, str):
        raw = raw.encode("utf-8")
    return struct.pack("<Q", len(raw)) + raw


def fixture(architecture="llama", tensors=None, overlap=False, extra_metadata=()):
    if tensors is None:
        tensors = [("matrix.weight", 4, 3, 1), ("norm.weight", 4, 1, 0)]
    metadata = string("general.architecture") + struct.pack("<I", 8) + string(architecture)
    metadata += string("general.alignment") + struct.pack("<II", 4, 32)
    for key, kind, value in extra_metadata:
        metadata += string(key) + struct.pack("<I", kind)
        if kind == 8:
            metadata += string(value)
        else:
            metadata += struct.pack({4:'<I', 5:'<i', 6:'<f', 7:'<?', 10:'<Q', 11:'<q'}[kind], value)
    directory, payload, expected = bytearray(), bytearray(), {}
    for name, columns, rows, kind in tensors:
        offset = (len(payload) + 31) // 32 * 32
        payload.extend(bytes(offset - len(payload)))
        size = columns * rows * (4 if kind == 0 else 2)
        if kind in (12, 13, 14):
            size = columns // 256 * {12:144, 13:176, 14:210}[kind] * rows
        dims = 1 if rows == 1 else 2
        relative = 0 if overlap else offset
        directory += string(name) + struct.pack("<I", dims) + struct.pack("<Q", columns)
        if dims == 2:
            directory += struct.pack("<Q", rows)
        directory += struct.pack("<IQ", kind, relative)
        payload.extend(bytes((index * 7) % 256 for index in range(size)))
        expected[name] = {"file_offset": relative, "columns":columns, "rows":rows,
                          "source_kind":kind, "byte_count":size}
    prefix = struct.pack("<IIQQ", 0x46554747, 3, len(tensors), 2 + len(extra_metadata)) + metadata + directory
    data_offset = (len(prefix) + 31) // 32 * 32
    raw = prefix + bytes(data_offset - len(prefix)) + payload
    for tensor in expected.values():
        tensor["file_offset"] += data_offset
    return raw, expected, data_offset


class SourceInventory(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.temp = tempfile.TemporaryDirectory(prefix="aesir-source-inventory-")
        cls.root = Path(cls.temp.name)
        cls.run_index = 0
        cls.records = []
        if CONFIG.evidence:
            cls.evidence = Path(CONFIG.evidence).resolve()
            cls.evidence.mkdir(parents=True, exist_ok=True)
        else:
            cls.evidence = None

    @classmethod
    def tearDownClass(cls):
        if cls.evidence:
            (cls.evidence / 'fixture-runs.json').write_text(json.dumps(cls.records, indent=2, ensure_ascii=True)+'\n')
        cls.temp.cleanup()

    def invoke(self, raw, trace=False):
        type(self).run_index += 1
        source = self.root / ('fixture-' + str(self.run_index) + '.gguf')
        source.write_bytes(raw)
        before = hashlib.sha256(raw).hexdigest()
        command = [self.binary, str(source)]
        trace_path = self.root / 'inventory.strace'
        if trace:
            command = [str(Path(CONFIG.strace).resolve(strict=True)), '-y', '-o', str(trace_path),
                       '-e', 'trace=openat,close,mmap,munmap,ioctl', *command]
        result = subprocess.run(command, capture_output=True, text=True, timeout=10,
                                stdin=subprocess.DEVNULL, check=False)
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), before)
        self.records.append({'fixture_sha256':before,'bytes':len(raw),'returncode':result.returncode,
                             'stdout':result.stdout,'stderr':result.stderr})
        raw_trace = trace_path.read_text() if trace else ''
        if trace and self.evidence:
            (self.evidence / 'read-only-inventory.strace').write_text(raw_trace)
        return result, raw_trace

    def accepts(self, architecture, tensors=None):
        raw, bindings, offset = fixture(architecture, tensors)
        result, _ = self.invoke(raw)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data, {'schema_version':1,'scope':'source_tensor_inventory',
            'architecture':architecture,'source_bytes':len(raw),'data_offset':offset,
            'weight_bytes':sum(t['byte_count'] for t in bindings.values()),
            'tensor_count':len(bindings),'execution_tested':False,'executable_program':False,
            'source_fingerprint_verified':False,'bindings':bindings})

    def test_exact_source_offsets_shapes_kinds_and_no_backend_allowlist(self):
        for architecture in ('llama', 'qwen3', 'new_architecture_not_in_backend_registry'):
            self.accepts(architecture)
        self.accepts('quantized_fixture', [('q4.weight',256,2,12),('q5.weight',256,1,13),('q6.weight',256,1,14)])
        self.accepts('bf16_fixture', [('bf16.weight',8,2,30)])

    def test_unicode_quotes_controls_and_length_prefixed_nul_preserved(self):
        self.accepts('arch_Æsir_🚀', [('name_é"\\\n.weight',4,2,1)])
        self.accepts('llama\0different', [('prefix\0suffix.weight',4,2,1)])

    def test_malformed_utf8_refuses_instead_of_unsafe_string_construction(self):
        raw, _, _ = fixture(b'bad\xffutf8')
        result, _ = self.invoke(raw)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('UTF', result.stdout + result.stderr)

    def test_truncation_overlap_duplicate_names_and_missing_source_facts_refuse(self):
        raw, _, _ = fixture()
        cases = [raw[:16], raw[:-1], fixture(overlap=True)[0], fixture('')[0], fixture(tensors=[])[0],
                 fixture(tensors=[('same',4,1,1),('same',4,1,1)])[0]]
        for raw in cases:
            result, _ = self.invoke(raw)
            self.assertNotEqual(result.returncode, 0)

    def test_read_only_mapping_cleanup_and_no_device_access(self):
        raw, _, _ = fixture()
        result, trace = self.invoke(raw, trace=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('O_RDONLY', trace)
        self.assertIn('PROT_READ, MAP_PRIVATE', trace)
        self.assertIn('munmap(', trace)
        self.assertNotIn('/dev/h1x-', trace)
        self.assertNotIn('libcuda', trace)
        self.assertNotIn('libhailort', trace)

    def test_unknown_tensor_layout_stays_explicit_importer_work(self):
        raw, _, _ = fixture(tensors=[('unknown.weight',256,1,99)])
        result, _ = self.invoke(raw)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('unsupported tensor type 99', result.stdout + result.stderr)


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--binary',required=True)
    parser.add_argument('--strace',required=True)
    parser.add_argument('--evidence')
    CONFIG,remaining=parser.parse_known_args()
    unittest.main(argv=[sys.argv[0],*remaining])
