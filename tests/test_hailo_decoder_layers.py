#!/usr/bin/env python3
"""Independent source layer interpretation. No model/layer/attention forward."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import random
import subprocess
import sys
import tempfile
import unittest

from test_hailo_safetensors_inventory import fixture as weights_fixture

CONFIG = argparse.Namespace()
MAX = (1 << 63) - 1


def fixture(n=4, **extra):
    return {"model_type": "smollm3", "num_hidden_layers": n,
        "custom": {"π\0": [True, None, "雪\n"], "reserved": "x" * 256}, **extra}


class DecoderLayers(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.api = str(Path(CONFIG.api).resolve(strict=True))
        cls.evidence = Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True, exist_ok=False)
        cls.temp = tempfile.TemporaryDirectory(prefix="aesir-decoder-layers-")
        cls.root = Path(cls.temp.name)
        cls.records = []

    @classmethod
    def tearDownClass(cls):
        counts = dict(Counter("accepted" if r["returncode"] == 0 else "refused" for r in cls.records))
        (cls.evidence / "runs.json").write_text(json.dumps(cls.records, indent=2) + "\n")
        (cls.evidence / "summary.json").write_text(json.dumps(counts, indent=2) + "\n")
        cls.temp.cleanup()
        print("Native outcomes:", counts)

    def child(self, command, trace=None):
        command = list(map(str, command))
        if trace:
            command = [CONFIG.strace, "-y", "-o", str(self.evidence / trace), "-e",
                "trace=openat,close,mmap,munmap,pread64,ioctl,write", *command]
        result = subprocess.run(command, capture_output=True, text=True, timeout=20,
            stdin=subprocess.DEVNULL, check=False)
        self.records.append({"arguments": command, "returncode": result.returncode,
            "stdout": result.stdout, "stderr": result.stderr})
        return result

    def file(self, obj):
        raw = obj if isinstance(obj, bytes) else json.dumps(obj, ensure_ascii=False, separators=(",", ":")).encode()
        path = self.root / ("config-" + str(len(self.records)) + ".json")
        path.write_bytes(raw)
        return path

    def invoke(self, obj, policy=(4096, 100000, 10000000), query=None, mode=None, trace=None):
        path = self.file(obj)
        before = path.read_bytes()
        if mode:
            command = [self.api, path, mode, *policy]
        else:
            command = [self.binary, path, 1048576, 10000, 10000000, 64, *policy]
        if query is not None:
            command.append(query)
        result = self.child(command, trace)
        self.assertEqual(path.read_bytes(), before)
        return result

    def accept(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return json.loads(result.stdout)

    def refuse(self, result):
        self.assertGreater(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout, "")

    def check(self, obj, report):
        for flag in ("execution_tested", "device_access", "complete_architecture_verified",
                     "physical_layout_verified", "source_fingerprint_verified"):
            self.assertIs(report[flag], False)
        raw = report["source"]["fields_raw"]
        self.assertEqual({k: json.loads(v) for k, v in raw.items()}, obj)
        n = obj.get("num_hidden_layers", 36)
        declared = obj.get("no_rope_layers")
        interval = obj.get("no_rope_layer_interval", 4)
        expected = [int((i + 1) % interval != 0) for i in range(n)] if declared is None else declared[:n]
        types = obj.get("layer_types")
        self.assertEqual(report["model_type"], "smollm3")
        self.assertEqual(report["layer_count"], n)
        self.assertEqual(report["declared_rope_flags"], declared or [])
        self.assertEqual(report["rope_enabled"], expected)
        self.assertEqual(report["layer_types"], types or [])
        self.assertEqual(report["no_rope_layer_interval"], interval)
        self.assertEqual(report["use_sliding_window"], obj.get("use_sliding_window", False))
        self.assertEqual(report["window_fields"], {k: raw[k] for k in ("sliding_window", "max_window_layers") if k in raw})
        origins = {"model_type": "source", "num_hidden_layers": "source" if "num_hidden_layers" in obj else "documented_default:36",
            "no_rope_layer_interval": "source" if "no_rope_layer_interval" in obj else "documented_default:4",
            "no_rope_layers": "absent_then_documented_interval" if "no_rope_layers" not in obj else ("source:null_then_documented_interval" if declared is None else "source"),
            "layer_types": "absent" if "layer_types" not in obj else ("source:null" if types is None else "source"),
            "use_sliding_window": "source" if "use_sliding_window" in obj else "documented_default:false"}
        for key in ("sliding_window", "max_window_layers"):
            origins[key] = "absent" if key not in obj else ("source:null" if obj[key] is None else "source")
        self.assertEqual(report["field_origins"], origins)
        notes = []
        if not types:
            notes.append("attention_layer_types_not_declared")
        for i, kind in enumerate(types or []):
            if kind != "full_attention":
                notes.append("attention_layer_type_semantics:" + str(i))
        if obj.get("use_sliding_window", False):
            notes.append("window_architecture_and_mask_lowering")
        self.assertEqual(report["unresolved"], notes)
        entries = len(obj) + n + len(declared or []) + len(types or [])
        work = 4 * sum(len(k.encode()) + len(v.encode()) for k, v in raw.items()) + entries + n
        self.assertEqual((report["entry_count"], report["work_units"]), (entries, work))
        self.assertEqual(report["source"]["source_bytes"], len(json.dumps(obj, ensure_ascii=False, separators=(",", ":")).encode()))

    def test_seeded_explicit_default_null_masks_and_unknown_modifiers(self):
        rng = random.Random(650991)
        for case in range(72):
            n = rng.randint(1, 48)
            obj = fixture(n, no_rope_layer_interval=rng.choice((1, 2, 4, 7, MAX)),
                use_sliding_window=bool(case % 2), rope_scaling={"future": [0.5, 2]},
                attention_bias=True, mlp_bias=False, tie_word_embeddings=bool(case % 3),
                use_cache=False, pretraining_tp=2)
            if case % 3 == 0:
                obj["no_rope_layers"] = [rng.randrange(2) for _ in range(n + case % 5)]
            elif case % 3 == 1:
                obj["no_rope_layers"] = None
            if case % 4 == 0:
                obj["layer_types"] = ["full_attention" if i % 3 else "future\0π" for i in range(n)]
            elif case % 4 == 1:
                obj["layer_types"] = None
            for key in ("sliding_window", "max_window_layers"):
                if case % 3:
                    obj[key] = None if case % 3 == 1 else rng.randint(1, 10000)
            report = self.accept(self.invoke(obj))
            self.check(obj, report)

    def test_public_mask_and_query_boundaries(self):
        path = Path(CONFIG.public_config).resolve(strict=True)
        raw = path.read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), "c72b1031274ff4626e434d0019e88e95a767460135db9ee492eb80652b786af1")
        obj = json.loads(raw)
        report = self.accept(self.child([self.binary, path, 1048576, 10000, 10000000, 64, 4096, 100000, 10000000]))
        self.assertEqual(sum(report["rope_enabled"]), 27)
        self.assertEqual([i for i, x in enumerate(report["rope_enabled"]) if not x], [3, 7, 11, 15, 19, 23, 27, 31, 35])
        self.assertEqual({k: json.loads(v) for k, v in report["source"]["fields_raw"].items()}, obj)
        for index in (0, 1, 2, 3, 4, 31, 35):
            q = self.accept(self.invoke(obj, query=index))
            self.assertEqual(q["uses_rope"], bool(obj["no_rope_layers"][index]))
        for index in (-1, 36, MAX):
            self.refuse(self.invoke(obj, query=index))
        self.assertEqual(path.read_bytes(), raw)

    def test_policy_exact_limits_and_overflow(self):
        obj = fixture(7, no_rope_layers=[1, 0, 1, 0, 1, 0, 1, 0, 1], layer_types=["full_attention"] * 7)
        report = self.accept(self.invoke(obj))
        exact = (7, report["entry_count"], report["work_units"])
        self.check(obj, self.accept(self.invoke(obj, policy=exact)))
        for field in range(3):
            for value in (0, -1, exact[field] - 1):
                policy = list(exact)
                policy[field] = value
                self.refuse(self.invoke(obj, policy=policy))
        huge = fixture(MAX)
        self.refuse(self.invoke(huge, policy=(MAX, MAX, MAX)))
        self.refuse(self.invoke(fixture(1, no_rope_layer_interval=MAX + 1)))
        self.check(fixture(1, no_rope_layer_interval=MAX), self.accept(self.invoke(fixture(1, no_rope_layer_interval=MAX))))

    def test_omitted_layer_count_qualified_default(self):
        omitted = fixture()
        del omitted["num_hidden_layers"]
        for obj in ({"model_type": "smollm3"}, omitted, dict(omitted, no_rope_layer_interval=2)):
            self.check(obj, self.accept(self.invoke(obj)))
            self.refuse(self.invoke(obj, policy=(35, 100000, 10000000)))
        obj = {"model_type": "smollm3"}
        report = self.accept(self.invoke(obj))
        self.check(obj, self.accept(self.invoke(obj, policy=(36, report["entry_count"], report["work_units"]))))
        self.refuse(self.invoke(obj, policy=(36, report["entry_count"], report["work_units"] - 1)))

    def test_invalid_source_types_lengths_literals_and_duplicate_fields(self):
        cases = []
        for key in ("num_hidden_layers", "no_rope_layer_interval"):
            cases += [fixture(**{key: value}) for value in (0, -1, True, False, 4.0, "4", None, [], {})]
        for value in (False, 0, "smollm3", [], {}, [1], [True, 1, 0, 1], [1.0, 1, 0, 1], [2, 0, 1, 0], [-1, 0, 1, 0], [None, 1, 0, 1]):
            cases.append(fixture(no_rope_layers=value))
        for value in (False, 1, "full_attention", {}, [], ["full_attention"], ["full_attention"] * 5, [True] * 4, [None] * 4):
            cases.append(fixture(layer_types=value))
        cases += [fixture(use_sliding_window=x) for x in (None, 0, 1, "false", [], {})]
        for key in ("sliding_window", "max_window_layers"):
            cases += [fixture(**{key: x}) for x in (0, -1, True, 1.0, "4", [], {})]
        cases += [fixture(model_type=x) for x in (None, True, 0, [], {}, "other_architecture")]
        for missing in ("model_type",):
            obj = fixture()
            del obj[missing]
            cases.append(obj)
        cases += [b"{}", b"[]", b'{"model_type":"smollm3","model_type":"smollm3","num_hidden_layers":4}',
            b'{"model_type":"smollm3","num_hidden_layers":4}false',
            b'{"model_type":"smollm3","num_hidden_layers":4,"x":{"k":1,"k":2}}']
        for obj in cases:
            self.refuse(self.invoke(obj))

    def test_owned_snapshots_mutations_and_raw_revalidation(self):
        obj = fixture(4, no_rope_layers=[1, 1, 1, 0, 0, 1], layer_types=["full_attention"] * 4,
            sliding_window=None, max_window_layers=28)
        self.check(obj, self.accept(self.invoke(obj, mode="ownership")))
        self.check(obj, self.accept(self.invoke(obj, mode="cycles")))
        for mode in ("model", "layers", "declared", "tail", "effective", "effective_length", "types", "interval",
            "window", "raw_window", "origin", "origin_missing", "notes", "entries", "work", "owned_policy",
            "external_policy", "source_layers", "source_work", "source_bytes", "unknown_malformed",
            "unknown_duplicate", "unknown_surrogate", "unknown_trailing"):
            self.refuse(self.invoke(obj, mode=mode))

    def test_actual_indexed_unindexed_config_connections_and_no_device_access(self):
        root = self.root / "ordinary"
        root.mkdir()
        obj = fixture(4, no_rope_layers=[1, 1, 1, 0], layer_types=["full_attention"] * 4,
            tie_word_embeddings=True, attention_bias=False, use_cache=False, pretraining_tp=2)
        (root / "config.json").write_text(json.dumps(obj, ensure_ascii=False, separators=(",", ":")))
        raw = weights_fixture([("w", "F16", [2, 3])])[0]
        (root / "source.weights").write_bytes(raw)
        (root / "index.json").write_text(json.dumps({"weight_map": {"w": "source.weights"}, "metadata": {"total_size": 12}}))
        for mode, source in (("unindexed", "source.weights"), ("indexed", "index.json")):
            report = self.accept(self.child([self.api, mode, root, source, "config.json"], mode + ".strace"))
            self.check(obj, report)
            trace = (self.evidence / (mode + ".strace")).read_text()
            for forbidden in ("/dev/h1x-", "ioctl(", "libcuda", "libhailort", "libggml"):
                self.assertNotIn(forbidden, trace)
            for line in trace.splitlines():
                if "mmap(" in line:
                    self.assertNotIn(".weights>", line)
        invalid = dict(obj, num_hidden_layers=True)
        (root / "config.json").write_text(json.dumps(invalid, ensure_ascii=False, separators=(",", ":")))
        for mode, source in (("unindexed", "source.weights"), ("indexed", "index.json")):
            self.refuse(self.child([self.api, mode, root, source, "config.json"], mode + "-late-refusal.strace"))
        self.assertEqual((root / "source.weights").read_bytes(), raw)
        report = self.accept(self.invoke(obj, mode="ownership", trace="owned-intent.strace"))
        self.check(obj, report)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    for name in ("binary", "api", "public-config", "strace", "evidence"):
        parser.add_argument("--" + name, required=True)
    CONFIG, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
