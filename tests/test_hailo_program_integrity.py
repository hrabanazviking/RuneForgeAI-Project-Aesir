#!/usr/bin/env python3
"""Isolated host byte oracle, no model/device/production hash dependency."""
import argparse
from collections import Counter
import ctypes
import hashlib
import json
from pathlib import Path
import random
import struct
import subprocess
import sys
import unittest

CONFIG = argparse.Namespace()
U64 = (1 << 64) - 1
HEADER = struct.Struct('>IIIQQIQQQ')


class ProgramIntegrity(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.evidence = Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True, exist_ok=False)
        cls.records = []
        lib = Path(CONFIG.oracle).resolve(strict=True)
        # Installed oracle license is read/pinned in the pre-implementation facts.
        license_data = Path(CONFIG.oracle_license).read_bytes()
        assert b'BSD-2-clause' in license_data
        cls.lib = ctypes.CDLL(str(lib))
        cls.lib.XXH_versionNumber.restype = ctypes.c_uint
        assert cls.lib.XXH_versionNumber() == 801
        facts = json.loads((Path(__file__).resolve().parents[1]/'docs/evidence/program-integrity-facts-2026-10-20/provenance.json').read_text())
        assert hashlib.sha256(lib.read_bytes()).hexdigest() == facts['sha256']['oracle_library']
        assert hashlib.sha256(license_data).hexdigest() == facts['sha256']['oracle_license']
        cls.lib.XXH3_64bits.argtypes = (ctypes.c_void_p, ctypes.c_size_t)
        cls.lib.XXH3_64bits.restype = ctypes.c_uint64
        (cls.evidence / 'oracle-provenance.json').write_text(json.dumps({
            'version_number': cls.lib.XXH_versionNumber(),
            'library_sha256': hashlib.sha256(lib.read_bytes()).hexdigest(),
            'license_sha256': hashlib.sha256(license_data).hexdigest(),
            'license': 'BSD-2-Clause library only; installed license read before use',
            'scope': 'isolated test-only XXH3_64bits; no implementation source inspected',
            'production_dependency': False,
        }, indent=2)+'\n')

    @classmethod
    def tearDownClass(cls):
        counts = dict(Counter('accepted' if r['returncode'] == 0 else 'refused' for r in cls.records))
        (cls.evidence/'runs.json').write_text(json.dumps(cls.records, indent=2)+'\n')
        (cls.evidence/'summary.json').write_text(json.dumps(counts, indent=2)+'\n')
        print('Native outcomes:', counts)

    def oracle(self, data):
        owned = ctypes.create_string_buffer(data)
        return self.lib.XXH3_64bits(owned, len(data))

    def invoke(self, *args, trace=False):
        command = [self.binary, *map(str, args)]
        if trace:
            command = [CONFIG.strace, '-y', '-o', str(self.evidence/'integrity.strace'),
                       '-e', 'trace=openat,ioctl,mmap,munmap', *command]
        result = subprocess.run(command, capture_output=True, text=True, timeout=15,
                                stdin=subprocess.DEVNULL)
        record_args = list(map(str, args))
        if args[0] in ('hash', 'validate'):
            try:
                raw = bytes.fromhex(args[1])
                record_args[1] = {'bytes':len(raw), 'sha256':hashlib.sha256(raw).hexdigest()}
            except ValueError:
                pass
        self.records.append(dict(arguments=record_args, returncode=result.returncode,
                                 stdout=result.stdout, stderr=result.stderr))
        return result

    def accepted(self, result):
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        obj = json.loads(result.stdout)
        for flag in ('device_access', 'complete_program', 'execution_tested'):
            self.assertIs(obj[flag], False)
        return obj

    def refused(self, result):
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, '')
        self.assertTrue(any(name in result.stderr for name in
            ('BadProgramIntegrity', 'BadProgramHeader', 'BadArgs', 'BadRpcHex')), result.stderr)

    def check_hash(self, raw, offset=0, count=None, trace=False):
        count = len(raw)-offset if count is None else count
        obj = self.accepted(self.invoke('hash', raw.hex(), offset, count, max(1, count), trace=trace))
        self.assertEqual(obj['checksum'], self.oracle(raw[offset:offset+count]), (len(raw),offset,count))
        self.assertEqual((obj['offset'],obj['count'],obj['domain']), (offset,count,'raw-window'))
        return obj['checksum']

    def program(self, proto, padding, ccw, additional, protobuf_only):
        residue = proto+padding+ccw+additional
        selected = self.oracle(proto) if protobuf_only else 0
        assert not protobuf_only or selected != 0
        return HEADER.pack(0x01484546,3,len(proto),self.oracle(residue),len(padding)+len(ccw),
                           len(padding),len(additional),selected,0)+residue

    def test_literal_known_vectors(self):
        for raw, expected in ((b'',0x2d06800538d394c2), (b'a',0xe6c632b61e964e1f),
                              (b'abc',0x78af5f94892f3950)):
            self.assertEqual(self.oracle(raw), expected)
            self.assertEqual(self.check_hash(raw), expected)

    def test_every_small_medium_length_and_byte_patterns(self):
        for n in range(257):
            for raw in (bytes(n),b'\xff'*n,bytes(i%256 for i in range(n)),
                        bytes((i*197+n*13)%256 for i in range(n))):
                self.check_hash(raw)

    def test_all_large_stripe_and_block_boundaries(self):
        lengths = set()
        for boundary in range(256,4097,64):
            lengths.update((boundary-1,boundary,boundary+1))
        lengths.update((8191,8192,8193,16383,16384,16385,32767,32768))
        rng = random.Random(71031)
        for n in sorted(lengths):
            self.check_hash(rng.randbytes(n))
        for n in (241,1024,1025,2048,32768):
            self.check_hash(bytes(n))
            self.check_hash(b'\xff'*n)

    def test_generated_multimegabyte_window_without_cli_hex_cap(self):
        for n,offset in ((262143,0),(262144,1),(262145,3),(1048576,0),
                         (1048577,7),(4194304,15),(8388608,17)):
            raw = (bytes((i*197+73)%256 for i in range(256))*((n+255)//256))[:n]
            count = n-offset
            obj = self.accepted(self.invoke('generated',n,offset,count,count,73))
            self.assertEqual(obj['checksum'],self.oracle(raw[offset:]))
            self.assertEqual((obj['offset'],obj['count']),(offset,count))
        self.refused(self.invoke('generated',8388609,0,1,1,0))
        self.refused(self.invoke('generated',1,0,1,1,256))

    def test_random_inputs_and_unaligned_subwindows(self):
        rng = random.Random(981223)
        for _ in range(180):
            raw = rng.randbytes(rng.randrange(32769))
            start = rng.randrange(len(raw)+1)
            count = rng.randrange(len(raw)-start+1)
            self.check_hash(raw,start,count)
        for offset in range(17):
            for n in (0,1,3,4,8,9,16,17,32,33,64,65,128,129,239,240,241,1024,1025):
                self.check_hash(b'\xa5'*offset+bytes(i%251 for i in range(n))+b'\x5a'*17,offset,n)

    def test_full_product_fold_carries_and_modular_overflow(self):
        values = (0,1,(1<<32)-1,1<<32,(1<<32)+1,(1<<63)-1,1<<63,U64)
        pairs = [(a,b) for a in values for b in values]
        rng = random.Random(13443)
        pairs += [(rng.getrandbits(64),rng.getrandbits(64)) for _ in range(128)]
        for a,b in pairs:
            product = a*b
            actual = self.accepted(self.invoke('fold',a,b))['checksum']
            self.assertEqual(actual, (product&U64)^(product>>64))

    def test_window_bounds_negative_overflow_and_no_input_mutation(self):
        for off,count,bound in ((-1,0,1),(0,-1,1),(0,1,0),(0,1,-1),(0,4,3),
                                (5,0,1),(4,1,1),(1,4,4),(U64>>1,0,1),
                                (0,U64>>1,U64>>1),(-1<<63,0,1),(0,-1<<63,1)):
            self.refused(self.invoke('hash','01020304',off,count,bound))
        self.check_hash(b'\x01\x02\x03\x04',4,0)
        self.accepted(self.invoke('ownership'))
        for n in (1<<63,U64,U64+1):
            self.refused(self.invoke('hash','',n,0,1))

    def test_version_three_domain_selection_and_exact_sections(self):
        rng = random.Random(73031)
        for only in (False,True):
            for sizes in ((0,0,0,0),(1,0,0,0),(17,7,32,5),(240,16,128,81),
                          (1025,3,2048,16),(3,0,0,1024),(0,17,0,0)):
                parts = [rng.randbytes(n) for n in sizes]
                raw = self.program(*parts,only)
                obj = self.accepted(self.invoke('validate',raw.hex(),len(raw)))
                domain = parts[0] if only else b''.join(parts)
                self.assertEqual((obj['domain'],obj['offset'],obj['count'],obj['checksum']),
                    ('protobuf-only' if only else 'full-residue',56,len(domain),self.oracle(domain)))

    def test_selected_and_unselected_tamper_semantics(self):
        for only in (False,True):
            raw = self.program(b'protobuf',b'pad',b'not-instructions',b'extras',only)
            for index in range(56,len(raw)):
                modified = bytearray(raw);modified[index] ^= 1
                result = self.invoke('validate',modified.hex(),len(modified))
                if only and index >= 56+8:
                    self.accepted(result)
                else:
                    self.refused(result)
            # Residue field is not authenticated by the selected protobuf-only branch.
            modified = bytearray(raw);modified[12] ^= 1
            result = self.invoke('validate',modified.hex(),len(modified))
            self.accepted(result) if only else self.refused(result)
            modified = bytearray(raw);modified[40] ^= 1
            self.refused(self.invoke('validate',modified.hex(),len(modified)))

    def test_truncation_extra_bytes_bad_header_and_host_bounds(self):
        for only in (False,True):
            raw = self.program(b'protobuf',b'pad',b'not-instructions',b'extras',only)
            for bad in (raw[:-1],raw+b'\x00',raw[:55],b'',raw[:56]):
                self.refused(self.invoke('validate',bad.hex(),max(1,len(bad))))
            for bound in (0,len(raw)-1):
                self.refused(self.invoke('validate',raw.hex(),bound))
            for pos in (0,4,8,20,28,32,48,55):
                bad = bytearray(raw);bad[pos] ^= 0x80
                self.refused(self.invoke('validate',bad.hex(),U64))
            bad = bytearray(raw);bad[20:28] = b'\xff'*8
            self.refused(self.invoke('validate',bad.hex(),U64))
        for text in ('0','gg'):
            self.refused(self.invoke('hash',text,0,0,1))

    def test_trace_no_device_external_hash_or_inference_library(self):
        self.check_hash(bytes(range(256))*8,trace=True)
        trace = (self.evidence/'integrity.strace').read_text()
        for forbidden in ('h1x-','libxxhash','libhailort','libcuda','libggml','ioctl('):
            self.assertNotIn(forbidden, trace)
        linked = subprocess.check_output(['ldd',self.binary],text=True)
        self.assertNotIn('xxhash',linked)
        (self.evidence/'native-linked-libraries.txt').write_text(linked)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    for name in ('binary','oracle','oracle-license','strace','evidence'):
        parser.add_argument('--'+name,required=True)
    CONFIG,remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0],*remaining])
