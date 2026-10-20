#!/usr/bin/env python3
"""Independent ordinary projection shape/alias/accounting oracle; no model math."""
import argparse
from collections import Counter
import copy
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
SUFFIXES = {
    "input_layernorm.weight": "attn_norm.weight", "post_attention_layernorm.weight": "ffn_norm.weight",
    "self_attn.q_proj.weight": "attn_q.weight", "self_attn.k_proj.weight": "attn_k.weight",
    "self_attn.v_proj.weight": "attn_v.weight", "self_attn.o_proj.weight": "attn_output.weight",
    "mlp.gate_proj.weight": "ffn_gate.weight", "mlp.up_proj.weight": "ffn_up.weight", "mlp.down_proj.weight": "ffn_down.weight"}


def declared(layers=2, hidden=8, heads=4, kv=2, key=3, value=5, ff=12, vocab=10, tie=True, head=False):
    config = dict(model_type="smollm3", num_hidden_layers=layers, hidden_size=hidden, intermediate_size=ff,
        num_attention_heads=heads, num_key_value_heads=kv, vocab_size=vocab, max_position_embeddings=64,
        attention_bias=False, mlp_bias=False, use_cache=False, tie_word_embeddings=tie,
        custom={"unknown": [1, True, "æ\u0000𝄞"]})
    roles = {"model.embed_tokens.weight": ("token_embd.weight", [vocab, hidden]), "model.norm.weight": ("output_norm.weight", [hidden])}
    if head:
        roles["lm_head.weight"] = ("output.weight", [vocab, hidden])
    for layer in range(layers):
        shapes = {"input_layernorm.weight": [hidden], "post_attention_layernorm.weight": [hidden],
            "self_attn.q_proj.weight": [heads * key, hidden], "self_attn.k_proj.weight": [kv * key, hidden],
            "self_attn.v_proj.weight": [kv * value, hidden], "self_attn.o_proj.weight": [hidden, heads * value],
            "mlp.gate_proj.weight": [ff, hidden], "mlp.up_proj.weight": [ff, hidden], "mlp.down_proj.weight": [hidden, ff]}
        for original, canonical in SUFFIXES.items():
            roles[f"model.layers.{layer}.{original}"] = (f"blk.{layer}.{canonical}", shapes[original])
    return config, roles


class DecoderProjections(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.api = str(Path(CONFIG.api).resolve(strict=True))
        cls.evidence = Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True, exist_ok=False)
        cls.temp = tempfile.TemporaryDirectory(prefix="aesir-decoder-projections-")
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
        result = subprocess.run(command, capture_output=True, text=True, timeout=60,
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

    def collection(self, config, roles, shards=1, dtypes=("BF16",)):
        root = self.root / ("ordinary-" + str(len(list(self.root.iterdir()))))
        root.mkdir()
        (root / "config.json").write_text(json.dumps(config, ensure_ascii=False, separators=(",", ":")))
        bindings, files, metadata, raw_files, weight_map = {}, {}, {}, {}, {}
        total = 0
        for i in range(shards):
            label = "source-" + str(i) + ".weights"
            descriptors = [(name, dtypes[j % len(dtypes)], shape) for j, (name, (_, shape)) in enumerate(roles.items()) if j % shards == i]
            raw, expected, _ = safe_fixture(descriptors, metadata={"format": "pt", "custom\u0000": "æ𝄞"})
            path = root / label
            path.write_bytes(raw)
            raw_files[path] = raw
            offset = 8 + struct.unpack_from("<Q", raw)[0]
            files[str(path)] = dict(source_format="safetensors", source_bytes=len(raw), data_offset=offset)
            metadata[str(path)] = {"format": "pt", "custom\u0000": "æ𝄞"}
            for name, entry in expected.items():
                canonical, shape = roles[name]
                bindings[canonical] = dict(source_format="safetensors", source_kind=entry["dtype"], original_name=name,
                    source_path=str(path), source_shape=shape, axis_order="row_major_outermost_first", elements=entry["elements"],
                    file_offset=offset + entry["relative"], byte_count=entry["bytes"], columns=shape[-1] if shape else 1,
                    rows=shape[0] if len(shape) == 2 else 1)
                weight_map[name] = label
                total += entry["bytes"]
        (root / "index.json").write_text(json.dumps({"weight_map": weight_map, "metadata": {"total_size": total}}))
        return root, dict(bindings=bindings, files=files, metadata=metadata, raw_files=raw_files, payload=total)

    def invoke(self, root, mode="indexed", bounds=(8, 10000, 64, 10000000, 10000000), provenance="explicit ordinary projection test", trace=None):
        label = "index.json" if mode == "indexed" else "source-0.weights"
        return self.child([self.binary, mode, root, label, "config.json", *bounds, provenance], trace)

    def check(self, obj, config, expected, key, value, provenance="explicit ordinary projection test"):
        for flag in ("complete_architecture_verified", "source_fingerprint_verified", "execution_tested", "device_access"):
            self.assertIs(obj[flag], False)
        self.assertEqual((obj["key_dim"], obj["value_dim"]), (key, value))
        output = "token_embd.weight" if config.get("tie_word_embeddings") is True else "output.weight" if config.get("tie_word_embeddings") is False else ""
        self.assertEqual(obj["output_weight"], output)
        source = obj["source"]
        self.assertEqual(source["architecture_adapter_verified"], False)
        self.assertEqual(source["bindings"], expected["bindings"])
        self.assertEqual(source["files"], expected["files"])
        self.assertEqual(source["weight_bytes"], expected["payload"])
        self.assertEqual(source["source_bytes"], sum(f["source_bytes"] for f in expected["files"].values()))
        self.assertEqual(source["data_offset"], next(iter(expected["files"].values()))["data_offset"] if len(expected["files"]) == 1 else -1)
        self.assertEqual(source["alias_provenance"], "; ".join([provenance] * len(expected["files"])))
        self.assertEqual(obj["file_metadata"], expected["metadata"])
        raw = obj["architecture"]["layers"]["source"]["fields_raw"]
        self.assertEqual({k: json.loads(v) for k, v in raw.items()}, config)
        slots = 9 * config["num_hidden_layers"] + 3
        work = 128 * slots + 8 * len(expected["bindings"]) + len(expected["files"]) + len(provenance.encode()) * len(expected["files"])
        work += sum(len(path.encode()) + len(metadata) + sum(len(k.encode()) + len(v.encode()) for k, v in metadata.items()) for path, metadata in expected["metadata"].items())
        work += sum(len(b["original_name"].encode()) + len(b["source_path"].encode()) for b in expected["bindings"].values())
        self.assertEqual(obj["work_units"], work)
        for path, original in expected.get("raw_files", {}).items():
            self.assertEqual(path.read_bytes(), original)
        if output == "token_embd.weight" and "output.weight" in source["bindings"]:
            self.assertIn("duplicate_tied_output_requires_source_identity", obj["unresolved"])
        if output == "":
            self.assertIn("explicit_output_tie_semantics_unresolved", obj["unresolved"])

    def test_seeded_actual_single_and_sharded_sources(self):
        rng = random.Random(607261)
        for i in range(36):
            heads = rng.choice((2, 4, 8))
            kv = rng.choice([v for v in (1, 2, 4, 8) if heads % v == 0])
            key, value = rng.randint(1, 8), rng.randint(1, 8)
            config, roles = declared(layers=rng.randint(1, 4), hidden=rng.randint(4, 16), heads=heads, kv=kv,
                key=key, value=value, ff=rng.randint(3, 18), vocab=rng.randint(3, 20), tie=bool(i % 2), head=i % 2 == 0)
            config["hidden_act"] = "future_activation" if i == 0 else "silu"
            config["rope_scaling"] = {"future": [1, True]} if i == 0 else None
            shards = 1 + i % 3
            root, expected = self.collection(config, roles, shards, ("F16", "BF16", "F32"))
            obj = self.accept(self.invoke(root, "unindexed" if shards == 1 else "indexed"))
            self.check(obj, config, expected, key, value)

    def test_explicit_tie_and_missing_null_decisions(self):
        for tie, head in ((True, False), (True, True), (False, True), (None, False), (None, True)):
            config, roles = declared(tie=tie, head=head)
            root, expected = self.collection(config, roles)
            self.check(self.accept(self.invoke(root)), config, expected, 3, 5)
        config, roles = declared(tie=None, head=True)
        del config["tie_word_embeddings"]
        root, expected = self.collection(config, roles)
        self.check(self.accept(self.invoke(root)), config, expected, 3, 5)
        config, roles = declared(tie=False, head=False)
        root, _ = self.collection(config, roles)
        self.refuse(self.invoke(root))
        for value in (None, "absent"):
            config, roles = declared()
            if value == "absent":
                del config["num_key_value_heads"]
            else:
                config["num_key_value_heads"] = value
            root, _ = self.collection(config, roles)
            self.refuse(self.invoke(root))

    def test_role_shape_and_orientation_refusals(self):
        config, original = declared()
        changes = [("model.embed_tokens.weight", [8, 10]), ("model.norm.weight", [1, 8]),
            ("model.layers.0.self_attn.q_proj.weight", [13, 8]), ("model.layers.0.self_attn.k_proj.weight", [8, 8]),
            ("model.layers.0.self_attn.v_proj.weight", [11, 8]), ("model.layers.0.self_attn.o_proj.weight", [8, 8]),
            ("model.layers.0.mlp.gate_proj.weight", [8, 12]), ("model.layers.0.mlp.up_proj.weight", [13, 8]),
            ("model.layers.0.mlp.down_proj.weight", [12, 8]), ("model.layers.0.input_layernorm.weight", [8, 1]),
            ("model.layers.0.post_attention_layernorm.weight", []), ("model.layers.0.self_attn.q_proj.weight", [3, 4, 8])]
        for name, shape in changes:
            roles = copy.deepcopy(original)
            roles[name] = (roles[name][0], shape)
            root, _ = self.collection(config, roles)
            self.refuse(self.invoke(root))
        for name in ("model.embed_tokens.weight", "model.norm.weight", "model.layers.0.self_attn.k_proj.weight"):
            roles = copy.deepcopy(original)
            del roles[name]
            root, _ = self.collection(config, roles)
            self.refuse(self.invoke(root))
        for name in ("unknown.weight", "model.layers.0.self_attn.q_proj.bias"):
            roles = copy.deepcopy(original)
            roles[name] = ("unimplemented", [8])
            root, _ = self.collection(config, roles)
            self.refuse(self.invoke(root))
        roles = copy.deepcopy(original)
        roles["model.layers.1.self_attn.q_proj.weight"] = ("blk.1.attn_q.weight", [16, 8])
        roles["model.layers.1.self_attn.k_proj.weight"] = ("blk.1.attn_k.weight", [8, 8])
        root, _ = self.collection(config, roles)
        self.refuse(self.invoke(root))

    def test_exact_policy_and_refusals_before_copy(self):
        config, roles = declared()
        root, expected = self.collection(config, roles, 2)
        obj = self.accept(self.invoke(root))
        exact = (2, len(roles), 2, 10000000, obj["work_units"])
        self.check(self.accept(self.invoke(root, bounds=exact)), config, expected, 3, 5)
        for bounds in ((1, len(roles), 2, 10000000, obj["work_units"]), (2, len(roles) - 1, 2, 10000000, obj["work_units"]),
            (2, len(roles), 1, 10000000, obj["work_units"]), (2, len(roles), 2, 10000000, obj["work_units"] - 1),
            (2, len(roles), 2, 1, obj["work_units"]), (0, 10000, 64, 10000000, 10000000),
            (8, 10000, 64, 10000000, 0), (8, 10000, 64, 10000000, -1)):
            self.refuse(self.invoke(root, bounds=bounds))
        self.refuse(self.invoke(root, provenance=""))
        self.check(self.accept(self.invoke(root, provenance="explicit æ𝄞")), config, expected, 3, 5, "explicit æ𝄞")

    def test_ownership_cycles_and_mutable_state(self):
        config, roles = declared()
        root, expected = self.collection(config, roles)
        provenance = "projection API test provenance"
        for mode in ("ownership", "cycles"):
            self.check(self.accept(self.child([self.api, root, "source-0.weights", "config.json", mode])), config, expected, 3, 5, provenance)
        for mode in ("key_dim", "value_dim", "output", "notes", "work", "owned_policy", "external_policy", "source_architecture",
            "source_provenance", "source_extent", "source_offset", "source_weight_bytes", "source_alias", "source_binding", "source_kind",
            "source_tag", "source_shape", "source_name", "source_path", "source_policy", "original_name", "original_shape", "original_offset",
            "original_extent", "original_metadata", "original_metadata_count", "architecture", "layer_mask", "input_policy_work", "input_metadata", "input_duplicate", "input_layer_count", "input_format", "input_kind"):
            self.refuse(self.child([self.api, root, "source-0.weights", "config.json", mode]))

    def test_real_remote_headers_are_explicit_metadata_only(self):
        config = json.loads(Path(CONFIG.public_config).read_text())
        header_paths = [Path(CONFIG.header0), Path(CONFIG.header1)]
        totals = [4966315264, 1183919744]
        expected = dict(bindings={}, files={}, metadata={}, payload=0)
        for i, path in enumerate(header_paths):
            raw = path.read_bytes()
            parsed = json.loads(raw)
            label = "REMOTE_METADATA_ONLY:header" + str(i)
            offset = 8 + len(raw)
            expected["files"][label] = dict(source_format="safetensors", source_bytes=totals[i], data_offset=offset)
            expected["metadata"][label] = parsed["__metadata__"]
            for name, tensor in parsed.items():
                if name == "__metadata__":
                    continue
                if name == "model.embed_tokens.weight":
                    canonical = "token_embd.weight"
                elif name == "model.norm.weight":
                    canonical = "output_norm.weight"
                else:
                    parts = name.split(".")
                    canonical = "blk." + parts[2] + "." + SUFFIXES[".".join(parts[3:])]
                shape = tensor["shape"]
                begin, end = tensor["data_offsets"]
                expected["bindings"][canonical] = dict(source_format="safetensors", source_kind=1, original_name=name, source_path=label,
                    source_shape=shape, axis_order="row_major_outermost_first", elements=(end - begin) // 2, file_offset=offset + begin,
                    byte_count=end - begin, columns=shape[-1], rows=shape[0] if len(shape) == 2 else 1)
                expected["payload"] += end - begin
        obj = self.accept(self.child([self.api, "remote", CONFIG.public_config, header_paths[0], totals[0], header_paths[1], totals[1]], "remote-headers.strace"))
        self.assertIs(obj["remote_metadata_only"], True)
        self.assertIs(obj["local_model_admitted"], False)
        self.check(obj["binding"], config, expected, 128, 128, "projection API test provenance")
        self.assertEqual(len(obj["binding"]["source"]["bindings"]), 326)
        trace = (self.evidence / "remote-headers.strace").read_text()
        for forbidden in ("/dev/h1x-", "libcuda", "libhailort", "libggml", "ioctl("):
            self.assertNotIn(forbidden, trace)

    def test_actual_collection_trace_and_late_refusal(self):
        config, roles = declared()
        root, expected = self.collection(config, roles, 2)
        self.check(self.accept(self.invoke(root, trace="indexed.strace")), config, expected, 3, 5)
        root, expected = self.collection(config, roles)
        self.check(self.accept(self.invoke(root, "unindexed", trace="unindexed.strace")), config, expected, 3, 5)
        invalid = dict(config, tie_word_embeddings=False)
        (root / "config.json").write_text(json.dumps(invalid))
        self.refuse(self.invoke(root, "unindexed", trace="late-output-refusal.strace"))
        for trace_name in ("indexed.strace", "unindexed.strace", "late-output-refusal.strace"):
            trace = (self.evidence / trace_name).read_text()
            for forbidden in ("/dev/h1x-", "libcuda", "libhailort", "libggml", "ioctl("):
                self.assertNotIn(forbidden, trace)
            for line in trace.splitlines():
                if "mmap(" in line:
                    self.assertNotIn(".weights>", line)
            for path in expected["raw_files"] if trace_name != "indexed.strace" else ():
                opens = sum(("openat(" in line or "openat2(" in line) and json.dumps(path.name) in line for line in trace.splitlines())
                closes = sum("close(" in line and "<" + str(path) + ">" in line for line in trace.splitlines())
                self.assertEqual(opens, closes)
                self.assertGreater(closes, 0)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    for name in ("binary", "api", "public-config", "header0", "header1", "strace", "evidence"):
        parser.add_argument("--" + name, required=True)
    CONFIG, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
