#!/usr/bin/env python3
"""Independent tagged operation metadata and complete GGUF compatibility."""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import subprocess
import sys
import tempfile
import unittest

from test_hailo_safetensors_inventory import fixture as safe_fixture
from test_hailo_gguf_shapes import explicit_fixture
from test_hailo_semantic_plan import dense_fixture

CONFIG = argparse.Namespace()


class SemanticStorage(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.api = str(Path(CONFIG.api).resolve(strict=True))
        cls.binaries = Path(CONFIG.binaries).resolve()
        cls.baseline = Path(CONFIG.baseline).resolve(strict=True)
        cls.evidence = Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True, exist_ok=False)
        cls.temp = tempfile.TemporaryDirectory(prefix="aesir-semantic-storage-")
        cls.root = Path(cls.temp.name)
        cls.records = []
        cls.comparisons = 0

    @classmethod
    def tearDownClass(cls):
        counts = dict(Counter("accepted" if r["returncode"] == 0 else "refused" for r in cls.records))
        (cls.evidence / "runs.json").write_text(json.dumps(cls.records, indent=2) + "\n")
        (cls.evidence / "summary.json").write_text(json.dumps({"outcomes": counts,
            "complete_output_comparisons": cls.comparisons}, indent=2) + "\n")
        cls.temp.cleanup()
        print("Native outcomes:", counts, "complete comparisons:", cls.comparisons)

    def child(self, command, trace=None):
        command = list(map(str, command))
        if trace:
            command = [CONFIG.strace, "-y", "-o", str(self.evidence / trace), "-e",
                "trace=openat,close,mmap,munmap,pread64,ioctl,write", *command]
        result = subprocess.run(command, capture_output=True, text=True, timeout=30,
            stdin=subprocess.DEVNULL, check=False)
        self.records.append({"arguments": command, "returncode": result.returncode,
            "stdout_sha256": hashlib.sha256(result.stdout.encode()).hexdigest(),
            "stdout_bytes": len(result.stdout.encode()), "stderr": result.stderr})
        return result

    def accept(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return json.loads(result.stdout)

    def refuse(self, result):
        self.assertGreater(result.returncode, 0)
        self.assertEqual(result.stdout, "")

    def file(self, raw, suffix):
        path = self.root / ("source-" + str(len(self.records)) + suffix)
        path.write_bytes(raw)
        return path

    def test_tagged_axes_dtype_names_and_owned_operation_schedule(self):
        rng = random.Random(877641)
        names = ["", "tensor\0π", "model.layer.weight", "权重", "a\n\t\"\\z"]
        for i in range(36):
            dtype = ("F16", "BF16", "F32")[i % 3]
            shape = [rng.randint(1, 8), rng.randint(1, 13)] if i % 2 else [rng.randint(1, 19)]
            name = names[i % len(names)]
            raw, expected, _ = safe_fixture([(name, dtype, shape)], pad=i % 8)
            path = self.file(raw, ".weights")
            prefix = "explicit/π/"
            report = self.accept(self.child([self.binary, "safetensors", path, prefix]))
            t = report["bindings"][prefix + name]
            e = expected[name]
            self.assertEqual((t["source_format"], t["source_kind"], t["original_name"], t["source_path"]),
                ("safetensors", e["dtype"], name, str(path)))
            self.assertEqual((t["source_shape"], t["elements"], t["axis_order"]),
                (shape, math.prod(shape), "row_major_outermost_first"))
            self.assertEqual((t["columns"], t["rows"]), (shape[-1], shape[0] if len(shape) == 2 else 1))
            self.assertEqual(t["file_offset"], 8 + struct.unpack("<Q", raw[:8])[0])
            self.assertEqual(t["byte_count"], e["bytes"])
            for flag in ("execution_tested", "device_access", "architecture_adapter_verified",
                         "source_fingerprint_verified", "hardware_fit_verified"):
                self.assertIs(report[flag], False)
            self.assertEqual(path.read_bytes(), raw)
        accepted = self.accept(self.child([self.api, "accept"]))
        self.assertEqual(accepted["bindings"]["canonical"]["original_name"], "original\0π")
        matrix = self.accept(self.child([self.api, "matrix"]))
        owned = self.accept(self.child([self.api, "ownership"]))
        self.assertEqual(matrix, owned)
        self.assertEqual(matrix["binding"], [64, 4, 3, 0, 24])
        self.assertEqual(matrix["tile_count"], 8)
        self.assertTrue(self.accept(self.child([self.api, "norm"]))["owned_tagged_recipe"])
        expanded = self.accept(self.child([self.api, "expanded"]))
        self.assertEqual(expanded["bindings"]["canonical"]["byte_count"], 24)

    def test_separate_files_and_explicit_alias_collisions(self):
        raw, _, _ = safe_fixture([("same", "F16", [2, 3])])
        one = self.file(raw, ".one")
        two = self.root / "other.weights"
        two.write_bytes(raw)
        report = self.accept(self.child([self.binary, "safetensors", one, "left/", "safetensors", two, "right/"]))
        self.assertEqual(report["source_bytes"], 2 * len(raw))
        self.assertEqual(report["data_offset"], -1)
        a, b = (report["bindings"][p + "same"] for p in ("left/", "right/"))
        self.assertEqual(a["file_offset"], b["file_offset"])
        self.assertNotEqual(a["source_path"], b["source_path"])
        self.assertEqual(report["weight_bytes"], 24)
        self.refuse(self.child([self.binary, "safetensors", one, "", "safetensors", two, ""]))
        self.refuse(self.child([self.binary, "safetensors", one, "left/", "safetensors", one, "right/"]))
        gguf, _ = explicit_fixture([("g", [3, 2], 0)])
        gp = self.file(gguf, ".gguf")
        mixed = self.accept(self.child([self.binary, "safetensors", one, "s/", "gguf", gp, "g/"]))
        self.assertEqual(mixed["bindings"]["s/same"]["source_kind"], 0)
        self.assertEqual(mixed["bindings"]["g/g"]["source_kind"], 0)
        self.assertEqual(mixed["bindings"]["s/same"]["byte_count"], 12)
        self.assertEqual(mixed["bindings"]["g/g"]["byte_count"], 24)

    def test_operation_roles_preserve_exact_source_rank(self):
        for format in ("gguf", "safetensors"):
            for rank in (1, 2):
                shape = ([7] if rank == 1 else [7, 1]) if format == "gguf" else ([7] if rank == 1 else [1, 7])
                raw = explicit_fixture([("w", shape, 0)])[0] if format == "gguf" else safe_fixture([("w", "F32", shape)])[0]
                path = self.file(raw, ".source")
                for role in ("vector", "matrix"):
                    result = self.child([self.api, "view", format, path, "w", 7, 1, role])
                    if format == "gguf" or (rank == 1) == (role == "vector"):
                        report = self.accept(result)
                        self.assertEqual(report["bindings"]["w"]["source_shape"], shape)
                    else:
                        self.refuse(result)
        live = self.file(explicit_fixture([("canonical", [4, 3], 0)])[0], ".gguf")
        refused = self.child([self.api, "gguf_reader", live])
        self.refuse(refused)
        self.assertIn("actual GGUF owner/path required", refused.stderr)
        for shape in ([], [0], [1, 0], [1, 1, 1]):
            raw = safe_fixture([("w", "F16", shape)])[0]
            path = self.file(raw, ".source")
            self.refuse(self.child([self.binary, "safetensors", path, ""]))

    def test_mutable_snapshots_and_bounds_fail_closed(self):
        modes = ("format", "dtype", "projection_kind", "axis_order", "axes", "elements", "columns", "rows",
            "offset", "bytes", "file_size", "data_offset", "path", "missing_storage", "missing_file", "summary_size",
            "summary_offset", "total", "provenance", "rank_bound", "work_bound", "file_bound", "tensor_bound",
            "overflow", "untagged", "duplicate_original", "overlap", "work_short", "alias_missing",
            "alias_absent", "alias_duplicate", "alias_canonical", "alias_provenance")
        for mode in modes:
            with self.subTest(mode=mode):
                self.refuse(self.child([self.api, mode]))

    def test_actual_ordinary_collections_feed_tagged_bindings(self):
        root = self.root / "ordinary"
        root.mkdir()
        (root / "config.json").write_text(json.dumps({"model_type": "future", "tie_word_embeddings": True,
            "attention_bias": True, "no_rope_layers": [0, 4], "custom": {"nested": [1, 2]}}))
        one = safe_fixture([("left.weight", "F16", [3, 4])])[0]
        two = safe_fixture([("right.weight", "BF16", [2, 3])])[0]
        (root / "one.weights").write_bytes(one)
        (root / "two.weights").write_bytes(two)
        single = self.accept(self.child([self.api, "unindexed", root, "one.weights", "config.json"], "ordinary-single.strace"))
        self.assertEqual(set(single["bindings"]), {"declared/left.weight"})
        self.assertEqual(single["bindings"]["declared/left.weight"]["source_shape"], [3, 4])
        (root / "index.json").write_text(json.dumps({"weight_map": {"left.weight": "one.weights", "right.weight": "two.weights"},
            "metadata": {"total_size": 36}}))
        sharded = self.accept(self.child([self.api, "indexed", root, "index.json", "config.json"], "ordinary-sharded.strace"))
        self.assertEqual(set(sharded["bindings"]), {"declared/left.weight", "declared/right.weight"})
        self.assertEqual(sharded["data_offset"], -1)
        self.assertEqual(sharded["weight_bytes"], 36)
        self.assertEqual((root / "one.weights").read_bytes(), one)
        self.assertEqual((root / "two.weights").read_bytes(), two)
        for name in ("ordinary-single.strace", "ordinary-sharded.strace"):
            trace = (self.evidence / name).read_text()
            self.assertNotIn("/dev/h1x-", trace)
            self.assertNotIn("ioctl(", trace)
            for line in trace.splitlines():
                if "mmap(" in line:
                    self.assertNotIn(".weights>", line)
        self.accept(self.child([self.api, "work_exact"]))

    def test_complete_prechange_consumer_outputs(self):
        rng = random.Random(249633)
        fixtures = [dense_fixture(layers=rng.randint(1, 3), tied=bool(i % 2), value=rng.randint(2, 5),
            overrides={"llama.tensor_data_layout": (8, "future_layout")} if i == 2 else None) for i in range(6)]
        fixtures += [dense_fixture(hidden=256, key=64, value=64, ff=512, matrix_kind=k) for k in (0, 1, 12, 13, 14, 30)]
        commands = {
            "semantic-plan": lambda p, q, past: [p, q, past, 16],
            "typed-decoder": lambda p, q, past: ["typed", p, q, past, 16],
            "expanded-graph": lambda p, q, past: [p, q, past, 16],
            "primitive-recipes": lambda p, q, past: [p, q, past, 16],
            "storage-estimate": lambda p, q, past: [p, q, past, 16, 2, 2, 4, 16, 10000, 100, 1 << 40, "test scenario"],
            "expanded-storage": lambda p, q, past: [p, q, past, 16, 2, 1, 2, 4, 16, 10000, 100, 1 << 40, "test scenario"],
            "matrix-tiles": lambda p, q, past: [p, q, past, 16, 2, 1, 2, 3, 2, 2, 4, 8, 1 << 30, "test scenario", "summary"],
            "source-weight-tiles": lambda p, q, past: [p, q, past, 16, 2, 1, 2, 3, 0, 1 << 30, 1 << 20],
            "cache-layout": lambda p, q, past: [p, q, past, 16, 2, 2, 1048576, 1048576, 16, 1 << 40, "test scenario"],
        }
        hashes = {}
        for label in commands:
            hashes[label] = {"before": hashlib.sha256((self.baseline / label).read_bytes()).hexdigest(),
                "after": hashlib.sha256((self.binaries / ("tagged-" + label)).read_bytes()).hexdigest()}
        (self.evidence / "baseline-binaries.json").write_text(json.dumps(hashes, indent=2) + "\n")
        for i, (raw, _, _) in enumerate(fixtures):
            path = self.file(raw, ".gguf")
            q, past = 1 + i % 3, i % 4
            for label, args in commands.items():
                with self.subTest(fixture=i, consumer=label):
                    before = self.accept(self.child([self.baseline / label, *args(path, q, past)]))
                    after = self.accept(self.child([self.binaries / ("tagged-" + label), *args(path, q, past)]))
                    self.assertEqual(after, before)
                    type(self).comparisons += 1
            self.assertEqual(path.read_bytes(), raw)

    def test_static_access_has_no_device_or_inference_library(self):
        raw = safe_fixture([("w", "F16", [2, 3])])[0]
        path = self.file(raw, ".weights")
        self.accept(self.child([self.binary, "safetensors", path, "explicit/"], "tagged-source.strace"))
        self.accept(self.child([self.api, "ownership"], "tagged-owned.strace"))
        for name in ("tagged-source.strace", "tagged-owned.strace"):
            trace = (self.evidence / name).read_text()
            for forbidden in ("/dev/h1x-", "libcuda", "libhailort", "libggml", "ioctl("):
                self.assertNotIn(forbidden, trace)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    for name in ("binary", "api", "binaries", "baseline", "strace", "evidence"):
        parser.add_argument("--" + name, required=True)
    CONFIG, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
