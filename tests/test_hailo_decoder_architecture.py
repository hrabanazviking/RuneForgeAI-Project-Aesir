#!/usr/bin/env python3
"""Independent ordinary parameter/default/accounting oracle. No model math."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import random
import struct
import subprocess
import sys
import tempfile
import unittest

from test_hailo_safetensors_inventory import fixture as safe_fixture

CONFIG = argparse.Namespace()
DEFAULTS = {"vocab_size": 128256, "hidden_size": 2048, "intermediate_size": 11008,
    "num_attention_heads": 16, "max_position_embeddings": 32768}
MANDATORY_NOTES = ["source_aliases_and_projection_axes", "rotary_component_pairing",
    "architecture_modifier_integration", "numerical_hailo_execution"]


class DecoderArchitecture(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.api = str(Path(CONFIG.api).resolve(strict=True))
        cls.evidence = Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True, exist_ok=False)
        cls.temp = tempfile.TemporaryDirectory(prefix="aesir-decoder-architecture-")
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
                "trace=openat,openat2,close,mmap,munmap,pread64,ioctl,write", *command]
        result = subprocess.run(command, capture_output=True, text=True, timeout=30,
            stdin=subprocess.DEVNULL, check=False)
        self.records.append({"arguments": command, "returncode": result.returncode,
            "stdout_sha256": hashlib.sha256(result.stdout.encode()).hexdigest(),
            "stdout_bytes": len(result.stdout.encode()), "stderr": result.stderr})
        return result

    def path(self, data):
        path = self.root / ("config-" + str(len(list(self.root.iterdir()))) + ".json")
        path.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")))
        return path

    def run_config(self, data, bounds=(100000, 10000000), trace=None):
        path = self.path(data)
        original = path.read_bytes()
        result = self.child([self.binary, path, 1048576, 10000, 10000000, 64,
            4096, 100000, 10000000, *bounds], trace)
        self.assertEqual(path.read_bytes(), original)
        return result

    def accept(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return json.loads(result.stdout)

    def refuse(self, result):
        self.assertGreater(result.returncode, 0)
        self.assertEqual(result.stdout, "")

    def check(self, obj, data):
        for flag in ("architecture_adapter_verified", "source_projection_axes_verified", "execution_tested", "device_access"):
            self.assertIs(obj[flag], False)
        dims = dict(DEFAULTS)
        dims.update({k: data[k] for k in DEFAULTS if k in data})
        dims["num_hidden_layers"] = data["num_hidden_layers"]
        origins = {k: "source" if k in data else "documented_default:" + str(v) for k, v in DEFAULTS.items()}
        origins["num_hidden_layers"] = "source"
        notes = []
        if data.get("num_key_value_heads") is None:
            origins["num_key_value_heads"] = "source:null_unresolved" if "num_key_value_heads" in data else "absent_unresolved_public_default_conflict"
            notes.append("kv_head_default_semantics_unresolved")
        else:
            dims["num_key_value_heads"] = data["num_key_value_heads"]
            origins["num_key_value_heads"] = "source"
        if "head_dim" in data:
            origins["head_dim"] = "source:unresolved_extension"
            notes.append("explicit_head_dim_extension_semantics")
        elif dims["hidden_size"] % dims["num_attention_heads"] == 0:
            dims["head_dim_candidate"] = dims["hidden_size"] // dims["num_attention_heads"]
            origins["head_dim_candidate"] = "arithmetic_only_requires_source_projection"
        else:
            notes.append("nonintegral_head_dimension_requires_source_projection")
        flags = {"attention_bias": data.get("attention_bias", False), "mlp_bias": data.get("mlp_bias", False), "use_cache": data.get("use_cache", True)}
        for key, default in (("attention_bias", False), ("mlp_bias", False), ("use_cache", True)):
            origins[key] = "source" if key in data else "documented_default:" + str(default).lower()
            if key != "use_cache" and flags[key]:
                notes.append(key + "_operation_lowering")
        if not flags["use_cache"]:
            notes.append("source_cache_disabled_semantics")
        if data.get("tie_word_embeddings") is None:
            origins["tie_word_embeddings"] = "source:null_unresolved" if "tie_word_embeddings" in data else "absent_unresolved"
            notes.append("output_tie_default_semantics_unresolved")
        else:
            flags["tie_word_embeddings"] = data["tie_word_embeddings"]
            origins["tie_word_embeddings"] = "source"
        activation = data.get("hidden_act", "silu")
        origins["hidden_act"] = "source" if "hidden_act" in data else "documented_default:silu"
        if activation != "silu":
            notes.append("activation_operation_lowering")
        scalar_defaults = {"rms_norm_eps": 1e-6, "rope_theta": 2000000.0}
        for key, default in scalar_defaults.items():
            value = float(data.get(key, default))
            self.assertEqual(obj["scalar_bits"][key], struct.unpack("<Q", struct.pack("<d", value))[0])
            origins[key] = "source" if key in data else ("documented_default:1e-6" if key == "rms_norm_eps" else "documented_default:2000000")
        origins["rope_scaling"] = "absent" if "rope_scaling" not in data else "source:null" if data["rope_scaling"] is None else "source:unresolved_object"
        if data.get("rope_scaling") is not None:
            notes.append("rotary_scaling_operation_lowering")
        if "pretraining_tp" in data:
            notes.append("pretraining_tp_semantics")
        notes += MANDATORY_NOTES
        self.assertEqual(obj["dimensions"], dims)
        self.assertEqual(obj["flags"], flags)
        self.assertEqual(obj["activation"], activation)
        self.assertEqual(obj["field_origins"], origins)
        self.assertEqual(obj["unresolved"], notes)
        raw = obj["layers"]["source"]["fields_raw"]
        self.assertEqual({k: json.loads(v) for k, v in raw.items()}, data)
        entries = len(data) + len(dims) + len(flags) + len(scalar_defaults) + len(origins) + 1 + len(notes)
        byte_cost = sum(len(k.encode()) + len(v.encode()) for k, v in raw.items())
        self.assertEqual(obj["entry_count"], entries)
        self.assertEqual(obj["work_units"], 4 * byte_cost + entries)
        self.assertEqual(obj["layers"]["layer_count"], data["num_hidden_layers"])

    def test_seeded_full_intent_and_public_config(self):
        rng = random.Random(381009)
        for i in range(48):
            heads = rng.choice((2, 4, 8, 16))
            data = dict(model_type="smollm3", num_hidden_layers=rng.randint(1, 12), hidden_size=heads * rng.randint(1, 128),
                num_attention_heads=heads, num_key_value_heads=rng.choice([v for v in (1, 2, 4, 8, 16) if heads % v == 0]),
                attention_bias=bool(i % 2), mlp_bias=bool(i % 3), use_cache=bool(i % 4),
                tie_word_embeddings=bool(i % 5), hidden_act="silu" if i % 2 else "future_activation",
                rms_norm_eps=10 ** rng.uniform(-7, -3), rope_theta=float(rng.randint(100, 9000000)),
                rope_scaling=None if i % 2 else {"future": [1, True, "retained"]}, pretraining_tp=2,
                custom={"unknown": [None, "æ\u0000𝄞", i]})
            self.check(self.accept(self.run_config(data)), data)
        data = json.loads(Path(CONFIG.public_config).read_text())
        result = self.child([self.binary, CONFIG.public_config, 1048576, 10000, 10000000, 64, 4096, 100000, 10000000, 100000, 10000000])
        obj = self.accept(result)
        self.check(obj, data)
        self.assertEqual(obj["dimensions"]["head_dim_candidate"], 128)
        self.assertEqual(sum(obj["layers"]["rope_enabled"]), 27)

    def test_missing_null_extensions_and_defaults(self):
        base = dict(model_type="smollm3", num_hidden_layers=2)
        cases = [base, dict(base, num_key_value_heads=None, tie_word_embeddings=None),
            dict(base, hidden_size=11, num_attention_heads=4), dict(base, head_dim=128), dict(base, head_dim=None),
            dict(base, head_dim={"unknown": True}), dict(base, hidden_act=""),
            dict(base, use_sliding_window=True, sliding_window=128, max_window_layers=1, layer_types=["future", "full_attention"]),
            dict(base, **{"unknown\u0000𝄞": {"unparsed": [1, 2]}}),
            dict(base, hidden_size=(1 << 63) - 1, num_attention_heads=(1 << 63) - 1, num_key_value_heads=(1 << 63) - 1)]
        for data in cases:
            self.check(self.accept(self.run_config(data)), data)

    def test_type_and_numerical_refusals(self):
        base = dict(model_type="smollm3", num_hidden_layers=2)
        for key in (*DEFAULTS, "num_key_value_heads"):
            for value in (False, True, 0, -1, 1.0, "8", 1 << 63):
                self.refuse(self.run_config(dict(base, **{key: value})))
            if key != "num_key_value_heads":
                self.refuse(self.run_config(dict(base, **{key: None})))
        for key in ("attention_bias", "mlp_bias", "use_cache", "tie_word_embeddings"):
            for value in (0, 1, "true", [], {}):
                self.refuse(self.run_config(dict(base, **{key: value})))
        for key in ("attention_bias", "mlp_bias", "use_cache"):
            self.refuse(self.run_config(dict(base, **{key: None})))
        for key in ("rms_norm_eps", "rope_theta"):
            for value in (None, False, True, 0, -1, "1.0", [], {}):
                self.refuse(self.run_config(dict(base, **{key: value})))
        for value in (None, True, 1, [], {}):
            self.refuse(self.run_config(dict(base, hidden_act=value)))
        for value in (True, 1, "default", []):
            self.refuse(self.run_config(dict(base, rope_scaling=value)))
        self.refuse(self.run_config(dict(base, num_attention_heads=4, num_key_value_heads=3)))
        self.refuse(self.run_config(dict(base, num_attention_heads=4, num_key_value_heads=8)))
        raw = self.path(base).read_text()
        for scalar in ("1e999", "1e-999", "-0.0"):
            path = self.root / ("raw-" + str(len(self.records)) + ".json")
            path.write_text(raw[:-1] + ",\"rms_norm_eps\":" + scalar + "}")
            self.refuse(self.child([self.binary, path, 1048576, 10000, 10000000, 64, 4096, 100000, 10000000, 100000, 10000000]))

    def test_exact_scalar_words(self):
        base = dict(model_type="smollm3", num_hidden_layers=2)
        for epsilon, theta in ((1.0, 100.0), (1e-300, 1e300), (5e-324, 1e200),
            (1.2345678901234567e-9, 5000000.123456789)):
            data = dict(base, rms_norm_eps=epsilon, rope_theta=theta)
            self.check(self.accept(self.run_config(data)), data)

    def test_exact_short_positive_policies(self):
        data = dict(model_type="smollm3", num_hidden_layers=2, hidden_size=16, num_attention_heads=4, custom=["retained", 1])
        obj = self.accept(self.run_config(data))
        exact = (obj["entry_count"], obj["work_units"])
        self.check(self.accept(self.run_config(data, exact)), data)
        for bounds in ((exact[0] - 1, exact[1]), (exact[0], exact[1] - 1), (0, exact[1]), (-1, exact[1]),
            (exact[0], 0), (exact[0], -1), (1, 1)):
            self.refuse(self.run_config(data, bounds))

    def test_mutations_independent_owners_and_cycles(self):
        data = dict(model_type="smollm3", num_hidden_layers=2, hidden_size=16, num_attention_heads=4, custom="valid")
        path = self.path(data)
        for mode in ("ownership", "cycles"):
            self.check(self.accept(self.child([self.api, path, mode])), data)
        for mode in ("dimension", "dimension_extra", "dimension_missing", "candidate", "flag", "flag_missing", "scalar", "scalar_missing",
            "activation", "origin", "origin_missing", "notes", "entries", "work", "owned_policy", "external_policy",
            "layer_mask", "source_dimension", "source_scalar", "source_accounting", "source_unknown_json", "layer_policy"):
            self.refuse(self.child([self.api, path, mode]))

    def test_actual_collection_snapshots_and_static_access(self):
        data = dict(model_type="smollm3", num_hidden_layers=2, num_key_value_heads=4, hidden_size=16,
            num_attention_heads=4, tie_word_embeddings=True, use_cache=False, custom={"unknown": "retained"})
        root = self.root / "ordinary"
        root.mkdir()
        (root / "config.json").write_text(json.dumps(data))
        raw = safe_fixture([("w", "F16", [2, 3])])[0]
        (root / "weights").write_bytes(raw)
        (root / "index.json").write_text(json.dumps({"weight_map": {"w": "weights"}, "metadata": {"total_size": 12}}))
        for mode, label in (("unindexed", "weights"), ("indexed", "index.json")):
            self.check(self.accept(self.child([self.api, mode, root, label, "config.json"], mode + ".strace")), data)
            trace = (self.evidence / (mode + ".strace")).read_text()
            for forbidden in ("/dev/h1x-", "libcuda", "libhailort", "libggml", "ioctl("):
                self.assertNotIn(forbidden, trace)
            for line in trace.splitlines():
                if "mmap(" in line:
                    self.assertNotIn("/weights>", line)
        (root / "config.json").write_text(json.dumps(dict(data, hidden_size=True)))
        for mode, label in (("unindexed", "weights"), ("indexed", "index.json")):
            self.refuse(self.child([self.api, mode, root, label, "config.json"], mode + "-late-refusal.strace"))
            trace = (self.evidence / (mode + "-late-refusal.strace")).read_text()
            for label_to_check in ("config.json", "weights"):
                file_path = root / label_to_check
                opens = sum(("openat(" in line or "openat2(" in line) and (json.dumps(label_to_check) in line or json.dumps(str(file_path)) in line) for line in trace.splitlines())
                closes = sum("close(" in line and "<" + str(file_path) + ">" in line for line in trace.splitlines())
                self.assertEqual(opens, closes)
                self.assertGreater(closes, 0)
        self.assertEqual((root / "weights").read_bytes(), raw)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    for name in ("binary", "api", "public-config", "strace", "evidence"):
        parser.add_argument("--" + name, required=True)
    CONFIG, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
