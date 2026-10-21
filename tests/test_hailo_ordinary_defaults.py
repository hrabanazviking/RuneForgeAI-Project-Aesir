#!/usr/bin/env python3
"""Independent qualified default facts and full explicit-source compatibility."""
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

from test_hailo_decoder_projections import declared
from test_hailo_safetensors_inventory import fixture as safe_fixture

CONFIG = argparse.Namespace()


class OrdinaryDefaults(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bins = Path(CONFIG.binaries).resolve(strict=True)
        cls.baseline = Path(CONFIG.baseline).resolve(strict=True)
        cls.evidence = Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True, exist_ok=False)
        cls.temp = tempfile.TemporaryDirectory(prefix="aesir-ordinary-defaults-")
        cls.root = Path(cls.temp.name)
        cls.records = []
        cls.comparisons = 0

    @classmethod
    def tearDownClass(cls):
        counts = dict(Counter("accepted" if r["returncode"] == 0 else "refused" for r in cls.records))
        (cls.evidence / "runs.json").write_text(json.dumps(cls.records, indent=2) + "\n")
        (cls.evidence / "summary.json").write_text(json.dumps(dict(outcomes=counts,complete_explicit_comparisons=cls.comparisons), indent=2) + "\n")
        cls.temp.cleanup()
        print("Native outcomes:", counts, "complete explicit comparisons:", cls.comparisons)

    def child(self, command, trace=None):
        command = list(map(str, command))
        if trace:
            command = [CONFIG.strace, "-y", "-o", str(self.evidence / trace), "-e",
                "trace=openat,openat2,close,mmap,munmap,pread64,ioctl,write", *command]
        result = subprocess.run(command, capture_output=True, text=True, timeout=60, stdin=subprocess.DEVNULL, check=False)
        self.records.append(dict(arguments=command,returncode=result.returncode,
            stdout_sha256=hashlib.sha256(result.stdout.encode()).hexdigest(),stdout_bytes=len(result.stdout.encode()),stderr=result.stderr))
        return result

    def accept(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return json.loads(result.stdout)

    def refuse(self, result):
        self.assertGreater(result.returncode, 0)
        self.assertEqual(result.stdout, "")

    def path(self, data):
        path = self.root / ("config-" + str(len(list(self.root.iterdir()))) + ".json")
        path.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")))
        return path

    def architecture(self, path, layer_bound=4096, trace=None):
        return self.child([self.bins / "decoder-architecture", path, 1048576, 10000, 10000000, 64,
            layer_bound, 100000, 10000000, 100000, 10000000], trace)

    def test_frozen_configuration_only_interface_facts(self):
        facts = json.loads(Path(CONFIG.oracle).read_text())
        self.assertEqual(facts["transformers_version"], "4.57.1")
        self.assertIs(facts["torch_imported"], False)
        self.assertIs(facts["model_module_imported"], False)
        for case in facts["cases"]:
            self.assertNotIn("error", case)
            data = dict(model_type="smollm3", **case["input"])
            expected = case["result"]
            path = self.path(data)
            result = self.architecture(path)
            if expected["num_attention_heads"] % expected["num_key_value_heads"] != 0:
                self.refuse(result)
                continue
            obj = self.accept(result)
            self.assertEqual(obj["dimensions"]["num_hidden_layers"], expected["num_hidden_layers"])
            self.assertEqual(obj["dimensions"]["num_key_value_heads"], expected["num_key_value_heads"])
            self.assertEqual(obj["layers"]["rope_enabled"], expected["no_rope_layers"][:expected["num_hidden_layers"]])
            if expected["tie_word_embeddings"] is None:
                self.assertNotIn("tie_word_embeddings", obj["flags"])
                self.assertEqual(obj["field_origins"]["tie_word_embeddings"], "source:null_unresolved")
            else:
                self.assertEqual(obj["flags"]["tie_word_embeddings"], expected["tie_word_embeddings"])
            raw = obj["layers"]["source"]["fields_raw"]
            self.assertEqual({k: json.loads(v) for k, v in raw.items()}, data)
            self.assertFalse(obj["execution_tested"])
            if "num_hidden_layers" not in data:
                self.assertEqual(obj["field_origins"]["num_hidden_layers"], "documented_default:36")
            if "num_key_value_heads" not in data:
                self.assertEqual(obj["field_origins"]["num_key_value_heads"], "documented_default:4")
            elif data["num_key_value_heads"] is None:
                self.assertEqual(obj["field_origins"]["num_key_value_heads"], "source:null_then_query_heads")
            if "tie_word_embeddings" not in data:
                self.assertEqual(obj["field_origins"]["tie_word_embeddings"], "documented_default:true")

    def test_absent_layer_bounds_and_null_types(self):
        path = self.path(dict(model_type="smollm3"))
        obj = self.accept(self.architecture(path, trace="absent-defaults.strace"))
        self.assertEqual(obj["dimensions"]["num_hidden_layers"], 36)
        self.assertEqual(obj["layers"]["declared_rope_flags"], [])
        self.assertEqual(sum(obj["layers"]["rope_enabled"]), 27)
        self.refuse(self.architecture(path, layer_bound=35))
        self.accept(self.architecture(path, layer_bound=36))
        for key in ("num_hidden_layers", "num_key_value_heads", "tie_word_embeddings"):
            for value in ("4", True if key != "tie_word_embeddings" else 1, [], {}):
                self.refuse(self.architecture(self.path(dict(model_type="smollm3", **{key: value}))))
        self.refuse(self.architecture(self.path(dict(model_type="smollm3", num_hidden_layers=None))))
        trace = (self.evidence / "absent-defaults.strace").read_text()
        for forbidden in ("/dev/h1x-", "libtorch", "libhailort", "libggml", "ioctl("):
            self.assertNotIn(forbidden, trace)

    def test_complete_explicit_old_layer_and_architecture_outputs(self):
        rng = random.Random(438822)
        for i in range(12):
            n = rng.randint(1, 8)
            data = dict(model_type="smollm3", num_hidden_layers=n, num_attention_heads=8,
                num_key_value_heads=rng.choice((1, 2, 4, 8)), tie_word_embeddings=bool(i % 2),
                hidden_size=rng.randint(1, 32) * 8, no_rope_layers=[rng.randrange(2) for _ in range(n)],
                layer_types=["full_attention"] * n, use_sliding_window=False,
                rope_scaling=None, custom={"retained": [True, None, "æ\u0000"]})
            path = self.path(data)
            for name, extra in (("decoder-layers", []), ("decoder-architecture", [100000, 10000000])):
                args = [path, 1048576, 10000, 10000000, 64, 4096, 100000, 10000000, *extra]
                old = self.accept(self.child([self.baseline / name, *args]))
                new = self.accept(self.child([self.bins / name, *args]))
                self.assertEqual(new, old)
                type(self).comparisons += 1

    def collection(self, data, roles):
        root = self.root / ("source-" + str(len(list(self.root.iterdir()))))
        root.mkdir()
        (root / "config.json").write_text(json.dumps(data, separators=(",", ":")))
        raw = safe_fixture([(name, "BF16", shape) for name, (_, shape) in roles.items()], metadata={"format": "pt"})[0]
        (root / "weights").write_bytes(raw)
        return root

    def projections(self, root, binary="decoder-projections"):
        return self.child([self.bins / binary, "unindexed", root, "weights", "config.json", 4, 10000, 64,
            10000000, 10000000, "qualified default source test"])

    def test_source_shape_validation_after_default_resolution(self):
        for mode in ("omitted_kv", "null_kv", "omitted_tie", "all_omitted_except_required_shapes"):
            data, roles = declared(kv=4, heads=4, tie=True)
            if mode in ("omitted_kv", "all_omitted_except_required_shapes"):
                del data["num_key_value_heads"]
            elif mode == "null_kv":
                data["num_key_value_heads"] = None
            if mode in ("omitted_tie", "all_omitted_except_required_shapes"):
                del data["tie_word_embeddings"]
            root = self.collection(data, roles)
            obj = self.accept(self.projections(root))
            self.assertEqual((obj["key_dim"], obj["value_dim"], obj["output_weight"]), (3, 5, "token_embd.weight"))
            self.assertEqual(obj["architecture"]["dimensions"]["num_key_value_heads"], 4)
            self.assertEqual({k: json.loads(v) for k, v in obj["architecture"]["layers"]["source"]["fields_raw"].items()}, data)
        for i in range(4):
            data, roles = declared(tie=bool(i % 2), head=i % 2 == 0, key=2 + i, value=3 + i)
            root = self.collection(data, roles)
            args = ["unindexed", root, "weights", "config.json", 4, 10000, 64, 10000000, 10000000, "qualified default source test"]
            old = self.accept(self.child([self.baseline / "decoder-projections", *args]))
            new = self.accept(self.child([self.bins / "decoder-projections", *args]))
            self.assertEqual(new, old)
            type(self).comparisons += 1
        data, roles = declared(kv=2, heads=4)
        del data["num_key_value_heads"]
        root = self.collection(data, roles)
        self.refuse(self.projections(root))

    def test_actual_header_geometry_with_minimal_config(self):
        path = self.path(dict(model_type="smollm3"))
        obj = self.accept(self.child([self.bins / "decoder-projections-api", "remote", path, CONFIG.header0,
            4966315264, CONFIG.header1, 1183919744], "default-remote-headers.strace"))
        self.assertIs(obj["remote_metadata_only"], True)
        self.assertIs(obj["local_model_admitted"], False)
        binding = obj["binding"]
        self.assertEqual((binding["key_dim"], binding["value_dim"], binding["output_weight"]), (128, 128, "token_embd.weight"))
        self.assertEqual(len(binding["source"]["bindings"]), 326)
        dims = binding["architecture"]["dimensions"]
        self.assertEqual((dims["num_hidden_layers"], dims["num_key_value_heads"], dims["hidden_size"]), (36, 4, 2048))
        self.assertEqual(binding["architecture"]["layers"]["source"]["fields_raw"], {"model_type": "\"smollm3\""})
        all_expected = {}
        for i, header in enumerate((CONFIG.header0, CONFIG.header1)):
            for name, tensor in json.loads(Path(header).read_bytes()).items():
                if name != "__metadata__":
                    all_expected[name] = (i, tensor)
        for source in binding["source"]["bindings"].values():
            i, tensor = all_expected.pop(source["original_name"])
            self.assertEqual(source["source_shape"], tensor["shape"])
            self.assertEqual(source["source_path"], "REMOTE_METADATA_ONLY:header" + str(i))
            self.assertEqual(source["source_kind"], 1)
        self.assertEqual(all_expected, {})
        trace = (self.evidence / "default-remote-headers.strace").read_text()
        for forbidden in ("/dev/h1x-", "libtorch", "libhailort", "libggml", "ioctl("):
            self.assertNotIn(forbidden, trace)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    for name in ("binaries", "baseline", "oracle", "header0", "header1", "strace", "evidence"):
        parser.add_argument("--" + name, required=True)
    CONFIG, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
