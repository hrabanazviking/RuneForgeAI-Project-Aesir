#!/usr/bin/env python3
"""Independent synthetic outer serialization oracle; no executable programs."""
import argparse
from collections import Counter
import ctypes
import hashlib
import itertools
import json
from pathlib import Path
import random
import struct
import subprocess
import sys
import unittest

CONFIG = argparse.Namespace()
U32 = (1 << 32)-1
U64 = (1 << 64)-1
INT_MAX = (1 << 63)-1
HEADER = struct.Struct('>IIIQQIQQQ')


class ProgramEnvelope(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.evidence = Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True, exist_ok=False)
        cls.records = []
        facts = json.loads((Path(__file__).resolve().parents[1]/'docs/evidence/program-integrity-facts-2026-10-20/provenance.json').read_text())
        lib = Path(CONFIG.oracle).resolve(strict=True)
        license_bytes = Path(CONFIG.oracle_license).read_bytes()
        assert hashlib.sha256(lib.read_bytes()).hexdigest() == facts['sha256']['oracle_library']
        assert hashlib.sha256(license_bytes).hexdigest() == facts['sha256']['oracle_license']
        cls.lib = ctypes.CDLL(str(lib))
        cls.lib.XXH3_64bits.argtypes = (ctypes.c_void_p,ctypes.c_size_t)
        cls.lib.XXH3_64bits.restype = ctypes.c_uint64
        cls.lib.XXH_versionNumber.restype = ctypes.c_uint
        assert cls.lib.XXH_versionNumber() == 801
        (cls.evidence/'oracle-provenance.json').write_text(json.dumps(dict(
            version_number=801, library_sha256=facts['sha256']['oracle_library'],
            license_sha256=facts['sha256']['oracle_license'], license='BSD-2-Clause',
            scope='isolated test-only XXH3 and independent big endian struct',
            production_dependency=False),indent=2)+'\n')

    @classmethod
    def tearDownClass(cls):
        counts = dict(Counter('accepted' if x['returncode'] == 0 else 'refused' for x in cls.records))
        (cls.evidence/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
        (cls.evidence/'summary.json').write_text(json.dumps(counts,indent=2)+'\n')
        print('Native outcomes:', counts)

    def hash(self, data):
        owned = ctypes.create_string_buffer(data)
        return self.lib.XXH3_64bits(owned,len(data))

    def invoke(self, *args, trace=False):
        command = [self.binary,*map(str,args)]
        if trace:
            command = [CONFIG.strace,'-y','-o',str(self.evidence/'envelope.strace'),
                       '-e','trace=openat,ioctl,mmap,munmap',*command]
        result = subprocess.run(command,capture_output=True,text=True,timeout=15,stdin=subprocess.DEVNULL)
        # Keep complete results for small cases, hashes for large synthetic output.
        record = dict(mode=args[0],returncode=result.returncode,stderr=result.stderr)
        if len(result.stdout) > 4096:
            record['stdout_bytes'] = len(result.stdout)
            record['stdout_sha256'] = hashlib.sha256(result.stdout.encode()).hexdigest()
        else:
            record['stdout'] = result.stdout
        self.records.append(record)
        return result

    def accepted(self, result):
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        obj = json.loads(result.stdout)
        for flag in ('device_access','complete_program','execution_tested'):
            self.assertIs(obj[flag],False)
        return obj

    def refused(self,result):
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(result.stdout,'')
        self.assertTrue(any(x in result.stderr for x in ('BadProgramEnvelope','BadProgramHeader','BadArgs','BadRpcHex')),result.stderr)

    def check(self, proto, ccws, extra, padding, mode, trace=False):
        total = 56+len(proto)+padding+len(ccws)+len(extra)
        obj = self.accepted(self.invoke('build',proto.hex(),ccws.hex(),extra.hex(),padding,mode,total,trace=trace))
        residue = proto+bytes(padding)+ccws+extra
        expected = HEADER.pack(0x01484546,3,len(proto),self.hash(residue),padding+len(ccws),
                               padding,len(extra),self.hash(proto) if mode == 'protobuf-only' else 0,0)+residue
        self.assertEqual(bytes.fromhex(obj['envelope_hex']),expected)
        self.assertEqual(obj['domain'],mode)
        self.assertEqual((obj['protobuf_offset'],obj['padding_offset'],obj['ccw_offset'],
                          obj['additional_offset'],obj['total_bytes']),
                         (56,56+len(proto),56+len(proto)+padding,56+len(proto)+padding+len(ccws),total))
        return obj

    def test_all_empty_nonempty_section_combinations_and_selectors(self):
        for sizes in itertools.product((0,3),repeat=4):
            p,c,a,pad = sizes
            for mode in ('full-residue','protobuf-only'):
                self.check(bytes(range(p)),bytes(range(31,31+c)),bytes(range(71,71+a)),pad,mode)

    def test_checksum_size_classes_and_block_tails(self):
        rng = random.Random(7391)
        for n in (1,3,4,8,9,16,17,31,32,33,63,64,65,127,128,129,239,240,241,255,256,257,1023,1024,1025,2048,2049,8192,32768):
            for mode in ('full-residue','protobuf-only'):
                self.check(rng.randbytes(n),rng.randbytes(n//3),rng.randbytes(n//7),n%17,mode)

    def test_seeded_section_lengths_padding_and_complete_bytes(self):
        rng = random.Random(229912)
        for _ in range(50):
            p,c,a,pad = [rng.randrange(257) for _ in range(4)]
            self.check(rng.randbytes(p),rng.randbytes(c),rng.randbytes(a),pad,
                       rng.choice(('full-residue','protobuf-only')))

    def test_exact_host_bound_and_preallocation_refusals(self):
        for mode in ('full-residue','protobuf-only'):
            for bound in (0,1,55,56,69):
                self.refused(self.invoke('build','010203','04050607','0809',5,mode,bound))
            self.check(b'\x01\x02\x03',b'\x04\x05\x06\x07',b'\x08\x09',5,mode)
            self.refused(self.invoke('build','','','',U32,mode,56))
        for value in (-1,U32+1,U64+1):
            self.refused(self.invoke('build','','','',value,'full-residue',56))
        for mode in ('','other','true'):
            self.refused(self.invoke('build','','','',0,mode,56))
        self.refused(self.invoke('build','','','',0,'full-residue',262145))

    def test_unallocated_extent_arithmetic_at_all_integer_limits(self):
        valid = ((0,0,0,0),(U32,0,0,U32),(0,INT_MAX-56,0,0),
                 (U32,0,INT_MAX-56-U32,0),(0,0,0,U32))
        for p,c,a,pad in valid:
            total = 56+p+pad+c+a
            obj = self.accepted(self.invoke('extent',p,c,a,pad,total))
            self.assertEqual((obj['protobuf_offset'],obj['padding_offset'],obj['ccw_offset'],
                              obj['additional_offset'],obj['total_bytes']),
                             (56,56+p,56+p+pad,56+p+pad+c,total))
            self.refused(self.invoke('extent',p,c,a,pad,total-1))
        for values in ((U32+1,0,0,0),(0,U64,0,1),(0,U64,0,0),(0,0,U64,0),
                       (U32,U64-56,0,0),(0,INT_MAX-55,0,0),(0,0,INT_MAX-55,0),
                       (U32,INT_MAX-56-U32,0,1),(0,0,0,U32+1)):
            self.refused(self.invoke('extent',*values,U64))
        self.refused(self.invoke('extent',0,0,0,0,0))

    def test_zero_hash_selector_policy_without_fabricating_hash_preimage(self):
        for value in (0,1,1<<63,U64,0x2d06800538d394c2):
            obj = self.accepted(self.invoke('selector','full-residue',value))
            self.assertEqual(obj['protobuf_hash'],0)
            result = self.invoke('selector','protobuf-only',value)
            if value:
                self.assertEqual(self.accepted(result)['protobuf_hash'],value)
            else:
                self.refused(result)

    def test_input_preservation_and_independent_output_lifetimes(self):
        obj = self.accepted(self.invoke('ownership'))
        normal = self.check(b'\x01\x02\x03',b'\x04\x05\x06\x07',b'\x08\x09',5,'full-residue')
        self.assertEqual(obj,normal)

    def test_host_trace_without_device_or_external_hash_link(self):
        self.check(b'protobuf',b'opaque-synthetic-data',b'additional',11,'full-residue',trace=True)
        trace = (self.evidence/'envelope.strace').read_text()
        for forbidden in ('h1x-','ioctl(','libxxhash','libhailort','libcuda','libggml'):
            self.assertNotIn(forbidden,trace)
        linked = subprocess.check_output(['ldd',self.binary],text=True)
        self.assertNotIn('xxhash',linked)
        (self.evidence/'native-linked-libraries.txt').write_text(linked)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    for name in ('binary','oracle','oracle-license','strace','evidence'):
        parser.add_argument('--'+name,required=True)
    CONFIG,remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0],*remaining])
