#!/usr/bin/env python3
"""Independent source writers/static reference; never a model forward."""
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
import tempfile
import unittest
from test_hailo_source_inventory import fixture
from test_hailo_source_float_constants import oracle16
from test_hailo_source_q4k_constants import pack_block as pack_q4, round32

CONFIG = argparse.Namespace()
MAX = (1 << 63)-1


def pack_q5(scales, minima, quants, d=0x3800, dmin=0x3400):
    low, _ = pack_q4(scales, minima, [q % 16 for q in quants], d, dmin)
    high = bytearray(32)
    for i, q in enumerate(quants):
        high[i % 32] |= (q // 16) << (i // 32)
    raw = low[:16] + high + low[16:]
    expected = [[d, dmin, oracle16(1, d), oracle16(1, dmin), q, scales[i//32], minima[i//32]] for i, q in enumerate(quants)]
    return bytes(raw), expected


def pack_q6(scales, quants, d=0x3800):
    # Writer combines four full 32-lane bands, independently of the reader's
    # per-element quadrant/field lookup. Signed factors come from caller data.
    low, high = bytearray(128), bytearray(64)
    for half in range(2):
        for lane in range(32):
            q = [quants[half*128+band*32+lane]+32 for band in range(4)]
            low[half*64+lane] = q[0] % 16 + (q[2] % 16)*16
            low[half*64+32+lane] = q[1] % 16 + (q[3] % 16)*16
            high[half*32+lane] = sum((value // 16) * (4**band) for band, value in enumerate(q))
    raw = low + high + struct.pack("<16bH", *scales, d)
    expected = [[d, oracle16(1, d), q, scales[i//16]] for i, q in enumerate(quants)]
    return bytes(raw), expected


def generated(kind, blocks, columns=512):
    assert len(blocks)*256 % columns == 0
    raw, bindings, _ = fixture("static_k_constant_fields", [("matrix.weight", columns, len(blocks)*256//columns, kind)])
    binding = bindings["matrix.weight"]
    return raw[:binding["file_offset"]] + b"".join(b[0] for b in blocks), binding, [c for b in blocks for c in b[1]]


def example(kind, blocks=4, special=False):
    words = [0, 0x8000, 1, 0x7c00, 0xfc00, 0x7e01, 0x7d01, 0xffff]
    result = []
    for b in range(blocks):
        d = words[b % len(words)] if special else 0x3400+b*7
        if kind == 13:
            result.append(pack_q5([(b+g*7) % 64 for g in range(8)], [(63-b+g*11) % 64 for g in range(8)], [(i+b) % 32 for i in range(256)], d, words[-1-b % len(words)] if special else 0x3000+b*3))
        else:
            result.append(pack_q6([((b+g*17) % 256)-128 for g in range(16)], [(i+b) % 64-32 for i in range(256)], d))
    return generated(kind, result)


def reconstruct(kind, c):
    d = struct.unpack("<e", struct.pack("<H", c[0]))[0]
    if kind == 13:
        minimum = struct.unpack("<e", struct.pack("<H", c[1]))[0]
        value = round32(round32(round32(d*c[5])*c[4])-round32(minimum*c[6]))
    else:
        value = round32(round32(d*c[3])*c[2])
    return struct.unpack("<I", struct.pack("<f", value))[0]


class SourceKConstants(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.api = str(Path(CONFIG.api_binary).resolve(strict=True))
        cls.evidence = Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True, exist_ok=False)
        cls.temp = tempfile.TemporaryDirectory(prefix="aesir-q5q6-fields-")
        cls.root = Path(cls.temp.name)
        cls.records = []
        cls.component_checks = 0

    @classmethod
    def tearDownClass(cls):
        counts = Counter("accepted" if r["returncode"] == 0 else "refused" for r in cls.records)
        (cls.evidence / "runs.json").write_text(json.dumps(cls.records, indent=2)+"\n")
        (cls.evidence / "summary.json").write_text(json.dumps({"outcomes": dict(counts), "component_checks": cls.component_checks}, indent=2)+"\n")
        print("Native outcomes:", dict(counts), "component checks:", cls.component_checks)
        cls.temp.cleanup()

    def invoke(self, kind=13, source=None, first=0, count=256, api_mode=None, name="matrix.weight", trace=False):
        source = source or example(kind)
        raw, binding, expected = source
        path = self.root / "fields.gguf"
        path.write_bytes(raw)
        fingerprint = hashlib.sha256(raw).hexdigest()
        command = [self.api, str(path), api_mode, str(kind)] if api_mode else [self.binary, str(path), name, str(first), str(count), str(kind)]
        if trace:
            command = [CONFIG.strace, "-y", "-o", str(self.evidence / (str(kind)+".strace")), "-e", "trace=openat,close,mmap,munmap,ioctl", *command]
        result = subprocess.run(command, capture_output=True, text=True, timeout=20, stdin=subprocess.DEVNULL)
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), fingerprint)
        record = {"kind": kind, "source_sha256": fingerprint, "first": first, "count": count, "mode": api_mode, "returncode": result.returncode, "stdout_sha256": hashlib.sha256(result.stdout.encode()).hexdigest(), "stderr": result.stderr}
        if result.returncode == 0:
            obj = json.loads(result.stdout)
            record["component_count"] = len(obj["components"])
            record["component_sha256"] = hashlib.sha256(json.dumps(obj["components"]).encode()).hexdigest()
        self.records.append(record)
        return result, binding, expected[first:first+count]

    def accepted(self, run):
        result, binding, expected = run
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        obj = json.loads(result.stdout)
        for flag in ("execution_tested", "device_access", "source_fingerprint_verified", "device_weight_format_verified"):
            self.assertIs(obj[flag], False)
        self.assertEqual(obj["binding"], [binding[k] for k in ("file_offset", "columns", "rows", "source_kind", "byte_count")])
        self.assertEqual(obj["components"], expected)
        type(self).component_checks += len(expected)
        return obj["components"]

    def refused(self, run):
        result = run[0]
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertTrue(any(x in result.stderr for x in ("SourceKConstants:", "SemanticPlan:", "GGUF")), result.stderr)

    def test_q5_all_quant_and_six_bit_factor_domains(self):
        source = example(13, 64)
        for first in range(0, 16384, 4096):
            self.accepted(self.invoke(13, source, first, 4096))
        for group in range(8):
            values = [source[2][b*256+group*32+i] for b in range(64) for i in range(32)]
            self.assertEqual({v[4] for v in values}, set(range(32)))
            self.assertEqual({v[5] for v in values}, set(range(64)))
            self.assertEqual({v[6] for v in values}, set(range(64)))

    def test_q6_all_centered_quant_and_signed_scale_domains(self):
        source = example(14, 256)
        for first in range(0, 65536, 4096):
            self.accepted(self.invoke(14, source, first, 4096))
        for group in range(16):
            values = [source[2][b*256+group*16+i] for b in range(256) for i in range(16)]
            self.assertEqual({v[2] for v in values}, set(range(-32, 32)))
            self.assertEqual({v[3] for v in values}, set(range(-128, 128)))

    def test_special_scale_bits_boundaries_rows_and_final_byte(self):
        for kind in (13, 14):
            source = example(kind, 8, special=True)
            for first, count in ((0, 1), (15, 35), (127, 6), (250, 20), (505, 20), (2047, 1), (0, 2048)):
                self.accepted(self.invoke(kind, source, first, count))

    def test_frozen_static_external_reference(self):
        path = Path(CONFIG.reference_library).resolve(strict=True)
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        self.assertEqual(digest, "45bd8cc3f12159e7b219a95d185be74a2ad83789045e6359acf49523aee23328")
        library = ctypes.CDLL(str(path))
        records = []
        rng = random.Random(53416)
        for kind in (13, 14):
            blocks = []
            for b in range(16):
                if kind == 13:
                    blocks.append(pack_q5([rng.randrange(64) for _ in range(8)], [rng.randrange(64) for _ in range(8)], [rng.randrange(32) for _ in range(256)], 0x3400+b*17, 0x3000+b*13))
                else:
                    blocks.append(pack_q6([rng.randrange(-128, 128) for _ in range(16)], [rng.randrange(-32, 32) for _ in range(256)], 0x3400+b*17))
            source = generated(kind, blocks)
            actual = self.accepted(self.invoke(kind, source, 0, 4096))
            decode = getattr(library, "dequantize_row_q5_K" if kind == 13 else "dequantize_row_q6_K")
            decode.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_float), ctypes.c_int64]
            decode.restype = None
            payload = ctypes.create_string_buffer(b"".join(b[0] for b in blocks))
            values = (ctypes.c_float*4096)()
            decode(payload, values, 4096)
            bits = list(struct.unpack("<4096I", ctypes.string_at(values, 4096*4)))
            self.assertEqual(bits, [reconstruct(kind, c) for c in actual])
            records.append({"kind": kind, "constants": 4096, "exact_binary32_match": True, "bits_sha256": hashlib.sha256(struct.pack("<4096I", *bits)).hexdigest()})
        (self.evidence / "external-reference.json").write_text(json.dumps({"revision": "a05c9922613c6a2230dbb1d0de679519ecafb4f0", "library_sha256": digest, "checks": records, "scope": "isolated synthetic static constants; no context, graph, model, backend or forward API"}, indent=2)+"\n")

    def test_invalid_selection_format_truncation_and_host_bound(self):
        for kind in (13, 14):
            source = example(kind, 32)
            for first, count in ((-1, 1), (0, 0), (0, -1), (8192, 1), (8191, 2), (MAX, 1), (1, MAX), (0, 4097)):
                self.refused(self.invoke(kind, source, first, count))
            self.refused(self.invoke(kind, source, name="missing"))
            self.refused(self.invoke(kind, (source[0][:-1], source[1], source[2])))
            other = 14 if kind == 13 else 13
            self.refused(self.invoke(kind, example(other)))

    def test_api_mutations_and_returned_ownership(self):
        modes = ("closed", "bytes", "offset", "metadata", "data_offset", "data_tail", "shape", "overflow", "alignment", "kind", "bound_zero", "bound_negative", "bound_short")
        for kind in (13, 14):
            for mode in modes:
                self.refused(self.invoke(kind, api_mode=mode))
            self.accepted(self.invoke(kind, first=0, count=1, api_mode="ownership"))

    def test_read_only_trace_and_static_representation_boundary(self):
        for kind in (13, 14):
            self.accepted(self.invoke(kind, first=250, count=20, trace=True))
            trace = (self.evidence / (str(kind)+".strace")).read_text()
            for required in ("O_RDONLY", "PROT_READ, MAP_PRIVATE", "munmap("):
                self.assertIn(required, trace)
            for forbidden in ("/dev/h1x-", "libhailort", "libcuda", "libggml", "ioctl("):
                self.assertNotIn(forbidden, trace)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    for name in ("binary", "api-binary", "reference-library", "strace", "evidence"):
        parser.add_argument("--"+name, required=True)
    CONFIG, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
