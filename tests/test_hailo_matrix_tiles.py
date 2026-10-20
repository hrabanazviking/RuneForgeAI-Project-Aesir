#!/usr/bin/env python3
"""Independent bounded coordinate oracle; no model values or device arithmetic."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from test_hailo_semantic_plan import dense_fixture

CONFIG = argparse.Namespace()
MAX = (1 << 63) - 1


def workspace(m, n, c, tm, tn, tc, widths=(2, 1, 4), alignment=8):
    r, o, k = min(m, tm), min(n, tn), min(c, tc)
    spans = (r * k * widths[0], o * k * widths[1], r * o * widths[2])
    return sum((size + alignment - 1) // alignment * alignment for size in spans)


class MatrixTiles(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.api = str(Path(CONFIG.api_binary).resolve(strict=True))
        cls.evidence = Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True, exist_ok=False)
        cls.temp = tempfile.TemporaryDirectory(prefix="aesir-matrix-tiles-")
        cls.root = Path(cls.temp.name)
        cls.records = []
        cls.coordinates = 0

    @classmethod
    def tearDownClass(cls):
        counts = Counter("accepted" if r["returncode"] == 0 else "refused" for r in cls.records)
        (cls.evidence / "runs.json").write_text(json.dumps(cls.records, indent=2) + "\n")
        (cls.evidence / "summary.json").write_text(json.dumps({"outcomes": dict(counts), "coordinate_checks": cls.coordinates}, indent=2) + "\n")
        print("Native outcomes:", dict(counts), "coordinate checks:", cls.coordinates)
        cls.temp.cleanup()

    def invoke(self, command, label, trace=False):
        if trace:
            command = [CONFIG.strace, "-y", "-o", str(self.evidence / "schedule.strace"),
                       "-e", "trace=openat,mmap,munmap,ioctl", *command]
        result = subprocess.run(command, capture_output=True, text=True, timeout=15, stdin=subprocess.DEVNULL)
        self.records.append({"case": label, "returncode": result.returncode,
                             "stdout": result.stdout, "stderr": result.stderr})
        return result

    def accepted(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        obj = json.loads(result.stdout)
        for flag in ("device_access", "execution_tested", "physical_layout_verified", "source_fingerprint_verified"):
            self.assertIs(obj[flag], False)
        return obj

    def refused(self, result):
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertTrue(any(prefix in result.stderr for prefix in ("MatrixTiles:", "SemanticPlan:", "StorageEstimate:", "GGUF")), result.stderr)

    def api_call(self, dims=(3, 4, 5), tiles=(2, 3, 2), mode="accept", selection="enumerate"):
        return self.invoke([self.api, *map(str, (*dims, *tiles)), mode, selection],
                           {"dims": dims, "tiles": tiles, "mode": mode, "selection": selection})

    def source_call(self, generated=None, operation=2, session=(3, 0, 16),
                    policy=(2, 3, 5, 2, 1, 4, 8, 1048576, "synthetic caller policy"),
                    selection="enumerate", trace=False):
        raw, bindings, _ = generated or dense_fixture()
        path = self.root / "source.gguf"
        path.write_bytes(raw)
        before = hashlib.sha256(raw).hexdigest()
        result = self.invoke([self.binary, str(path), *map(str, session), str(operation),
                              *map(str, policy), selection],
                             {"source_sha256": before, "operation": operation, "policy": policy}, trace)
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), before)
        return result, bindings

    def check_coordinates(self, obj, dims, tiles):
        m, n, c = dims
        tm, tn, tc = tiles
        expected = []
        coverage = {(r, o): [] for r in range(m) for o in range(n)}
        markers = Counter()
        # Enumerating ranges, rather than decoding a flat tile index, gives an
        # independent coverage/order oracle for the native division formulas.
        for r, o, k in itertools.product(range(0, m, tm), range(0, n, tn), range(0, c, tc)):
            rows, outputs, contractions = min(tm, m-r), min(tn, n-o), min(tc, c-k)
            expected.append([r, o, k, rows, outputs, contractions, r*c+k, c,
                             o*c+k, c, r*n+o, n, int(k == 0), int(k+contractions == c)])
            for row in range(r, r+rows):
                for output in range(o, o+outputs):
                    coverage[row, output].extend(range(k, k+contractions))
                    markers[row, output, "first"] += k == 0
                    markers[row, output, "last"] += k+contractions == c
        self.assertEqual(obj["tiles"], expected)
        self.assertEqual(obj["tile_count"], len(expected))
        self.assertEqual([obj["m"], obj["n"], obj["c"]], list(dims))
        self.assertEqual(obj["workspace_bytes"], workspace(*dims, *tiles))
        for cell, visited in coverage.items():
            self.assertEqual(visited, list(range(c)))
            self.assertEqual(markers[*cell, "first"], 1)
            self.assertEqual(markers[*cell, "last"], 1)
        type(self).coordinates += m*n*c

    def test_exhaustive_small_coordinate_domains(self):
        for dims in itertools.product(range(1, 4), repeat=3):
            for tiles in itertools.product(range(1, 4), repeat=3):
                with self.subTest(dims=dims, tiles=tiles):
                    self.check_coordinates(self.accepted(self.api_call(dims, tiles)), dims, tiles)

    def test_partial_tails_output_reshape_and_owned_result(self):
        for mode in ("accept", "split", "outer", "ownership"):
            obj = self.accepted(self.api_call((5, 6, 7), (3, 4, 5), mode))
            self.check_coordinates(obj, (5, 6, 7), (3, 4, 5))
            self.assertEqual(obj["output_shape"], [5, 2, 3] if mode == "split" else [1, 5, 6] if mode == "outer" else [5, 6])
            self.assertEqual(obj["provenance"], "synthetic tile policy")
            self.assertEqual(obj["binding"], [64, 7, 6, 1, 84])

    def test_source_bindings_head_splits_and_packed_formats(self):
        fixtures = [dense_fixture(), dense_fixture(layers=2, hidden=12, heads=3, kv_heads=1, key=4, value=6, ff=10, vocab=11, tied=True)]
        fixtures += [dense_fixture(hidden=256, heads=4, kv_heads=2, key=64, value=64, ff=256, vocab=8, matrix_kind=kind) for kind in (0, 30, 12, 13, 14)]
        for generated in fixtures:
            layers = 2 if generated is fixtures[1] else 1
            operations = [2+layer*21+offset for layer in range(layers) for offset in (0, 1, 2, 11, 14, 15, 18)] + [21*layers+2]
            for operation in operations:
                result, bindings = self.source_call(generated, operation, policy=(2, 64, 64, 2, 1, 4, 8, 1048576, "source binding scenario"))
                obj = self.accepted(result)
                binding = bindings[obj["weight"]]
                self.assertEqual(obj["binding"], [binding[k] for k in ("file_offset", "columns", "rows", "source_kind", "byte_count")])
                self.assertEqual(obj["c"], binding["columns"])
                self.assertEqual(obj["n"], binding["rows"])
                self.assertEqual(math.prod(obj["output_shape"]), obj["m"] * obj["n"])
                self.assertNotEqual(obj["input_tensor"], obj["output_tensor"])

    def test_workspace_exact_bound_and_invalid_policy(self):
        base = [2, 3, 5, 2, 1, 4, 8, 64, "explicit policy"]
        self.assertEqual(self.accepted(self.source_call(policy=base)[0])["workspace_bytes"], 64)
        for index, value in ((0, 0), (1, -1), (2, 0), (3, 0), (4, -1), (5, 0), (6, 0), (6, 3), (7, 0), (7, 63), (8, ""), (3, MAX), (5, MAX)):
            changed = base.copy(); changed[index] = value
            self.refused(self.source_call(policy=changed)[0])

    def test_malformed_graph_bindings_and_changed_snapshot(self):
        modes = ("operation", "kind", "inputs", "input_id", "output_id", "same_id", "weight_name", "consumed",
                 "input_product", "output_product", "input_empty", "output_shape", "input_future", "input_dead",
                 "output_producer", "output_lifetime", "output_owner", "output_alias", "binding_columns", "binding_rows",
                 "binding_kind", "binding_bytes", "binding_offset", "source_extent", "data_offset", "width", "weight_width",
                 "accumulator_width", "alignment", "workspace", "provenance", "byte_overflow", "outer_mismatch", "mutate")
        for mode in modes:
            self.refused(self.api_call(mode=mode))
        for operation in (-1, 0, 1, 24, MAX):
            self.refused(self.source_call(operation=operation)[0])

    def test_lazy_large_extent_overflow_and_indices(self):
        dims = (1 << 32, 1, 1)
        obj = self.accepted(self.api_call(dims, (1, 1, 1), selection=str(dims[0]-1)))
        self.assertEqual(obj["tile_count"], dims[0])
        self.assertEqual(obj["tiles"][0][:6], [dims[0]-1, 0, 0, 1, 1, 1])
        self.refused(self.api_call(dims, (1, 1, 1)))
        self.refused(self.api_call((1 << 22,)*3, (1, 1, 1), selection="summary"))
        for tiles in ((0, 1, 1), (1, -1, 1), (1, 1, 0)):
            self.refused(self.api_call(tiles=tiles))
        for index in (-1, 12, MAX):
            self.refused(self.api_call(selection=str(index)))
        self.refused(self.api_call((MAX, 2, 2), selection="summary"))

    def test_read_only_source_trace(self):
        self.accepted(self.source_call(trace=True)[0])
        trace = (self.evidence / "schedule.strace").read_text()
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
