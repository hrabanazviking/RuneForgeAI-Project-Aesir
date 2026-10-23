#!/usr/bin/env python3
"""Independent synthetic program bytes, actual kernel seals and bounded faults."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import unittest
from google.protobuf import descriptor_pb2, descriptor_pool, message_factory

CONFIG = argparse.Namespace()
HEADER = struct.Struct('>IIIQQIQQQ')


class SealedProgram(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = Path(CONFIG.evidence).resolve(); cls.out.mkdir(exist_ok=False)
        cls.records = []
        lib = Path(CONFIG.oracle).resolve(strict=True)
        assert hashlib.sha256(lib.read_bytes()).hexdigest() == 'eba22de3de8f35b9871675e08b74ee43275e5fa3992d4b8c22ae394b5f184031'
        assert hashlib.sha256(Path(CONFIG.oracle_license).read_bytes()).hexdigest() == 'a123c93b07e781919ae996276ac02bb1c8b19dfde88176cd1240ab277c14a4ce'
        cls.lib = ctypes.CDLL(str(lib)); cls.lib.XXH3_64bits.argtypes = (ctypes.c_void_p, ctypes.c_size_t); cls.lib.XXH3_64bits.restype = ctypes.c_uint64
        schema = Path(CONFIG.schema).resolve(strict=True)
        assert hashlib.sha256(schema.read_bytes()).hexdigest() == 'c44ec3a28d075bae5f814f99491a4f1de0c3cbd026721243e8876c67b5da9225'
        pb = cls.out / 'rpc.pb'
        subprocess.run([CONFIG.protoc, '-I', str(schema.parent), '--descriptor_set_out=' + str(pb), str(schema)], capture_output=True, check=True)
        pool = descriptor_pool.DescriptorPool()
        for f in descriptor_pb2.FileDescriptorSet.FromString(pb.read_bytes()).file: pool.Add(f)
        cls.proto = message_factory.GetMessageClass(pool.FindMessageTypeByName('VDevice_CreateInferModel_Request'))

    @classmethod
    def tearDownClass(cls):
        (cls.out / 'runs.json').write_text(json.dumps(cls.records, indent=2) + '\n')

    def envelope(self, n=14, proto_only=False):
        data = bytes((i * 37 + 11) & 255 for i in range(n))
        buf = ctypes.create_string_buffer(data)
        checksum = self.lib.XXH3_64bits(buf, n)
        return HEADER.pack(0x01484546, 3, n, checksum, 0, 0, 0, checksum if proto_only else 0, 0) + data

    def metadata(self, data, msg=17, handle=0, name='native'):
        p = self.proto(); p.vdevice_handle.id = handle; p.hef_size = len(data); p.name = name
        body = p.SerializeToString()
        return struct.pack('<5I', 0x8a554432, len(body), msg, 2, 1) + body + bytes(2048-len(body))

    def call(self, binary, *args, fault=None):
        cmd = [str(Path(binary).resolve(strict=True)), *map(str, args)]
        env = os.environ.copy(); idx = len(self.records)
        if fault:
            env.update(LD_PRELOAD=str(Path(CONFIG.faults).resolve()), AESIR_PROGRAM_FAULT_MODE=fault,
                       AESIR_PROGRAM_FAULT_LOG=str(self.out / f'fault-{idx}.jsonl'))
        p = subprocess.run(cmd, capture_output=True, text=True, env=env, timeout=90, stdin=subprocess.DEVNULL)
        self.records.append(dict(arguments=cmd, fault=fault, returncode=p.returncode, stdout=p.stdout, stderr=p.stderr))
        return p

    def success(self, p):
        self.assertEqual((p.returncode, p.stderr), (0, ''), p.stdout + p.stderr)
        return p.stdout

    def refused(self, p):
        self.assertNotEqual(p.returncode, 0)
        self.assertEqual(p.stdout, '')
        self.assertNotIn('test:', p.stderr)

    def invoke(self, data, part=1, first=0, count=None, bound=None, work=None, writes=4096, reads=4096,
               arch='aarch64', name='native', msg=17, handle=0, ok=True, fault=None):
        if count is None: count = len(data)
        if bound is None: bound = len(data)
        if work is None: work = count
        p = self.call(CONFIG.binary, msg, handle, data.hex(), name, bound, part, first, count, work, writes, reads, arch, fault=fault)
        if not ok: self.refused(p); return p
        obj = json.loads(self.success(p)); meta = self.metadata(data, msg, handle, name)
        selected = meta if part == 0 else data
        self.assertEqual(obj, dict(window_hex=selected[first:first+count].hex(), program_bytes=len(data), sealed_kernel_bytes=True, device_access=False, program_transferred=False, executable_verified=False))
        return p

    def api(self, data, mode='bytes', writes=4096, reads=4096, fault=None):
        return self.call(CONFIG.api, data.hex(), writes, reads, mode, fault=fault)

    def test_complete_sizes_windows_and_independent_kernel_oracle(self):
        for n in (0, 1, 7, 8, 14, 17, 255, 256, 4039, 4040, 4041, 4096, 8193, 16385):
            data = self.envelope(n)
            self.invoke(data)
            oracle = json.loads(self.success(self.call(CONFIG.kernel_oracle, data.hex())))
            self.assertEqual(oracle, dict(seals=15, fd_flags=1, hex=data.hex(), kernel_refusals=True))
            for part, size in ((0, 2068), (1, len(data))):
                for first, count in ((0, 0), (size, 0), (size-1, 1), (0, size)):
                    self.invoke(data, part, first, count)
        for msg in (0, (1 << 32)-1):
            for handle in (0, (1 << 32)-2):
                for name in ('', '模型', '🙂'):
                    self.invoke(self.envelope(), part=0, count=2068, name=name, msg=msg, handle=handle, bound=(1 << 64)-1)

    def test_kernel_protection_ownership_moves_and_all_mutable_guards(self):
        for n in (0, 14, 4097, 16385):
            data = self.envelope(n)
            for mode in ('bytes', 'protect', 'implicit'):
                obj = json.loads(self.success(self.api(data, mode)))
                self.assertEqual(bytes.fromhex(obj['program_hex']), data)
                self.assertEqual(bytes.fromhex(obj['metadata_hex']), self.metadata(data))
                self.assertEqual((obj['seals'], obj['fd_flags'], obj['refusal_recovery_cycles']), (15, 1, 0))
        obj = json.loads(self.success(self.api(self.envelope(), 'guards')))
        self.assertEqual(obj['refusal_recovery_cycles'], 2086)
        self.assertEqual(bytes.fromhex(obj['program_hex']), self.envelope())
        self.assertEqual(self.success(self.call(CONFIG.api, 'default')), 'default_refused\n')
        self.assertEqual(self.success(self.api(self.envelope(), 'bad_snapshot')), 'snapshot_refused_and_recovered\n')

    def test_part_signed_work_host_and_descriptor_policies(self):
        data = self.envelope()
        for part in (-1, 2, -(1 << 63), (1 << 63)-1): self.invoke(data, part=part, ok=False)
        for first, count, work in ((-1, 0, 0), (0, -1, 0), (0, 0, -1), (len(data)+1, 0, 0), (len(data), 1, 1), (0, 2, 1), ((1 << 63)-1, 0, 0)):
            self.invoke(data, first=first, count=count, work=work, ok=False)
        for bound in (0, len(data)-1): self.invoke(data, bound=bound, ok=False)
        for field in ('writes', 'reads'):
            for value in (0, -1): self.invoke(data, **{field: value}, ok=False)
        self.invoke(data, arch='x86_64', ok=False)
        self.invoke(data, handle=(1 << 32)-1, ok=False)
        self.invoke(data, msg=1 << 32, ok=False)
        data = self.envelope(8193)
        for w, r in ((2, 3), (3, 2)): self.invoke(data, writes=w, reads=r, ok=False)
        self.invoke(data, writes=3, reads=3)

    def test_integrity_metadata_and_malformed_diagnostic(self):
        data = self.envelope()
        for i in range(len(data)):
            bad = bytearray(data); bad[i] ^= 1
            # Some header mutations represent valid different layouts, checked by old suite.
            if i in (8, 9, 10, 11, 28, 29, 30, 31): continue
            self.invoke(bytes(bad), count=0, work=0, ok=False)
        self.invoke(self.envelope(proto_only=True), ok=False)
        for n in (0, 1, 55, 56, len(data)-1): self.invoke(data[:n], count=0, work=0, ok=False)
        self.invoke(data+b'\0', ok=False)
        for args in ((), ('x',), (17, 0, 'g'*140, 'native', 70, 1, 0, 0, 0, 1, 1, 'aarch64'),
                     ('1'*21, 0, data.hex(), 'native', 70, 1, 0, 0, 0, 1, 1, 'aarch64')):
            self.refused(self.call(CONFIG.binary, *args))
        self.invoke(data)

    def test_faults_cleanup_and_fresh_in_process_recovery(self):
        data = self.envelope()
        modes = ('create', 'large_fd', 'stat_error', 'stat_extent', 'seal', 'seal_after', 'get_seals',
                 'get_seals_late', 'missing_seals', 'get_flags', 'missing_flags', 'read_error', 'read_zero',
                 'read_extra', 'read_eintr', 'read_corrupt', 'write_error', 'write_zero', 'write_extra', 'write_eintr')
        for mode in modes:
            self.assertEqual(self.success(self.api(data, 'recover', writes=3, reads=3, fault=mode)), 'refused_and_recovered\n')
        self.assertEqual(self.success(self.api(data, 'close_error', fault='close_after')), 'close_failed_after_release_and_recovered\n')

    def test_short_io_eintr_independent_budgets(self):
        data = self.envelope()
        calls = (len(data)+2)//3
        for mode, writes, reads in (('write_short', calls, 1), ('read_short', 1, calls), ('write_eintr_once', 2, 1), ('read_eintr_once', 1, 2)):
            self.invoke(data, writes=writes, reads=reads, fault=mode)
            self.invoke(data, writes=writes-(mode.startswith('write')), reads=reads-(mode.startswith('read')), fault=mode, ok=False)
        self.invoke(data)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    for name in ('binary', 'api', 'faults', 'kernel-oracle', 'oracle', 'oracle-license', 'schema', 'protoc', 'evidence'):
        parser.add_argument('--'+name, required=True)
    CONFIG, rest = parser.parse_known_args(); unittest.main(argv=[sys.argv[0], *rest])
