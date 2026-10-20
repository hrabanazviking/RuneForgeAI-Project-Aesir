#!/usr/bin/env python3
"""Independent byte-slice oracle. No model evaluation or device arithmetic."""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import random
import subprocess
import sys
import tempfile
import unittest
from test_hailo_semantic_plan import dense_fixture

CONFIG = argparse.Namespace()


def source_fixture(kind=1):
    generated = dense_fixture(hidden=512, heads=2, kv_heads=1, key=4, value=128,
                              ff=256, vocab=4, matrix_kind=kind) if kind in (12, 13, 14) else dense_fixture(hidden=12, heads=3, kv_heads=1, key=4, value=6, ff=10, vocab=11, matrix_kind=kind)
    raw, bindings, data_offset = generated
    raw = bytearray(raw)
    rng = random.Random(67421 + kind)
    for name, binding in bindings.items():
        start = binding["file_offset"]
        raw[start:start+binding["byte_count"]] = rng.randbytes(binding["byte_count"])
    return bytes(raw), bindings, data_offset


class SourceWeightTiles(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.api = str(Path(CONFIG.api_binary).resolve(strict=True))
        cls.evidence = Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True, exist_ok=False)
        cls.temp = tempfile.TemporaryDirectory(prefix="aesir-weight-bytes-")
        cls.root = Path(cls.temp.name)
        cls.records = []
        cls.byte_checks = 0

    @classmethod
    def tearDownClass(cls):
        counts = Counter("accepted" if r["returncode"] == 0 else "refused" for r in cls.records)
        (cls.evidence / "runs.json").write_text(json.dumps(cls.records, indent=2) + "\n")
        (cls.evidence / "summary.json").write_text(json.dumps({"outcomes": dict(counts), "byte_checks": cls.byte_checks}, indent=2) + "\n")
        print("Native outcomes:", dict(counts), "independent byte checks:", cls.byte_checks)
        cls.temp.cleanup()

    def invoke(self, fixture=None, tiles=(2, 3, 5), index=0, bound=1048576, api_mode=None, trace=False):
        raw, bindings, _ = fixture or source_fixture()
        path = self.root / "source.gguf"
        path.write_bytes(raw)
        fingerprint = hashlib.sha256(raw).hexdigest()
        command = [self.api, str(path), api_mode] if api_mode else [self.binary, str(path), "3", "0", "16", "2", *map(str, tiles), str(index), "1073741824", str(bound)]
        if trace:
            command = [CONFIG.strace, "-y", "-o", str(self.evidence / "bytes.strace"), "-e", "trace=openat,close,mmap,munmap,ioctl", *command]
        result = subprocess.run(command, capture_output=True, text=True, timeout=15, stdin=subprocess.DEVNULL)
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), fingerprint)
        self.records.append({"source_sha256": fingerprint, "tiles": tiles, "index": index,
                             "host_byte_bound": bound, "mode": api_mode, "returncode": result.returncode,
                             "stdout": result.stdout, "stderr": result.stderr})
        return result, raw, bindings

    def accepted(self, run):
        result, raw, bindings = run
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        obj = json.loads(result.stdout)
        for flag in ("device_access", "execution_tested", "source_fingerprint_verified", "device_weight_packing_verified"):
            self.assertIs(obj[flag], False)
        binding = bindings[obj["weight"]]
        self.assertEqual(obj["binding"], [binding[k] for k in ("file_offset", "columns", "rows", "source_kind", "byte_count")])
        first_row, rows, first_column, columns = obj["rectangle"]
        kind, width = binding["source_kind"], binding["columns"]
        elements, block_bytes = (256, {12:144, 13:176, 14:210}[kind]) if kind in (12, 13, 14) else (1, 4 if kind == 0 else 2)
        row_bytes = width // elements * block_bytes
        # Set membership and byte slicing independently derive the minimal
        # covering blocks, rather than sharing the native ceil/count formulas.
        blocks = sorted({column // elements for column in range(first_column, first_column+columns)})
        byte_count = len(blocks) * block_bytes
        covered = len(blocks) * elements
        prefix = first_column - blocks[0] * elements
        expected = []
        payload = bytearray()
        for row in range(first_row, first_row+rows):
            offset = binding["file_offset"] + row * row_bytes + blocks[0] * block_bytes
            expected.append([row, offset, byte_count, blocks[0]*elements, covered, prefix, covered-prefix-columns, len(payload)])
            payload.extend(raw[offset:offset+byte_count])
        self.assertEqual(obj["spans"], expected)
        self.assertEqual(obj["payload"], list(payload))
        self.assertEqual(len(obj["spans"]), rows)
        type(self).byte_checks += len(payload)
        return obj

    def refused(self, run):
        result = run[0]
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertTrue(any(prefix in result.stderr for prefix in ("SourceWeightTiles:", "MatrixTiles:", "SemanticPlan:", "StorageEstimate:", "GGUF")), result.stderr)

    def test_all_current_source_kinds_partial_blocks_rows_and_tails(self):
        for kind in (0, 1, 30, 12, 13, 14):
            fixture = source_fixture(kind)
            binding = fixture[1]["blk.0.attn_q.weight"]
            for tc in (1, 7, 129, 255, 256, 257, 511, 512, 1024):
                ct = math.ceil(binding["columns"] / tc)
                nt = math.ceil(binding["rows"] / 3)
                indices = {0, ct-1, min(1, ct-1), (nt-1)*ct, nt*ct-1, 2*nt*ct-1}
                for index in sorted(indices):
                    with self.subTest(kind=kind, tile_c=tc, index=index):
                        self.accepted(self.invoke(fixture, (2, 3, tc), index))

    def test_exact_byte_bound_and_row_bytes(self):
        for kind in (0, 1, 30, 12, 13, 14):
            fixture = source_fixture(kind)
            obj = self.accepted(self.invoke(fixture, (2, 3, 7)))
            size = len(obj["payload"])
            self.accepted(self.invoke(fixture, (2, 3, 7), bound=size))
            self.refused(self.invoke(fixture, (2, 3, 7), bound=size-1))

    def test_closed_owner_source_binding_schedule_and_bound_refusals(self):
        modes = ("closed", "live_size", "live_data", "live_missing", "live_offset", "live_columns", "live_rows",
                 "live_kind", "live_bytes", "schedule_offset", "schedule_columns", "schedule_kind", "schedule_bytes",
                 "schedule_shape", "schedule_width", "negative_bound", "zero_bound", "short_bound", "negative_index", "large_index")
        for mode in modes:
            self.refused(self.invoke(api_mode=mode))
        for bound in (-1, 0):
            self.refused(self.invoke(bound=bound))
        for index in (-1, (1 << 63)-1):
            self.refused(self.invoke(index=index))

    def test_returned_payload_survives_owner_and_descriptor_destruction(self):
        for kind in (0, 1, 30, 12, 13, 14):
            fixture = source_fixture(kind)
            before = self.accepted(self.invoke(fixture, api_mode="accept"))
            owned = self.accepted(self.invoke(fixture, api_mode="ownership"))
            self.assertEqual(owned, before)

    def test_read_only_trace_no_device_or_model_runtime(self):
        self.accepted(self.invoke(source_fixture(14), (2, 3, 129), index=1, trace=True))
        trace = (self.evidence / "bytes.strace").read_text()
        for required in ("O_RDONLY", "PROT_READ, MAP_PRIVATE", "munmap("):
            self.assertIn(required, trace)
        for forbidden in ("/dev/h1x-", "libhailort", "libcuda", "libggml", "ioctl("):
            self.assertNotIn(forbidden, trace)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    for name in ("binary", "api-binary", "strace", "evidence"):
        parser.add_argument("--"+name, required=True)
    CONFIG, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
