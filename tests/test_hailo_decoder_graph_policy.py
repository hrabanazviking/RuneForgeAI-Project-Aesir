#!/usr/bin/env python3
"""Independent structural graph surgery and cache address oracle; no model math."""
import argparse
from collections import Counter
import copy
import hashlib
import itertools
import json
import math
from pathlib import Path
import random
import struct
import subprocess
import sys
import tempfile
import unittest

from test_hailo_semantic_plan import dense_fixture
from test_hailo_safetensors_inventory import fixture as safe_fixture

CONFIG = argparse.Namespace()


def without_rotary(reference, flags):
    """Remove selected existing rotary vertices, rewire, then number/liveness anew."""
    graph = copy.deepcopy(reference)
    bypass = {}
    removed = set()
    for op in reference["operations"]:
        name = reference["tensors"][op["output"]]["name"]
        if op["kind"] in ("rope_query", "rope_key") and not flags[int(name.split(".")[1])]:
            removed.add(op["id"])
            bypass[op["output"]] = op["inputs"][0]
    tids = {t["id"]: i for i, t in enumerate(t for t in reference["tensors"] if t["id"] not in bypass)}
    oids = {op["id"]: i for i, op in enumerate(op for op in reference["operations"] if op["id"] not in removed)}
    graph["tensors"] = [t for t in graph["tensors"] if t["id"] not in bypass]
    graph["operations"] = [o for o in graph["operations"] if o["id"] not in removed]
    for tensor in graph["tensors"]:
        tensor["id"] = tids[tensor["id"]]
        tensor["producer"] = oids[tensor["producer"]] if tensor["producer"] >= 0 else -1
        tensor["last_use"] = tensor["producer"]
        if tensor["alias_of"] >= 0:
            tensor["alias_of"] = tids[tensor["alias_of"]]
    for op in graph["operations"]:
        op["id"] = oids[op["id"]]
        op["output"] = tids[op["output"]]
        op["inputs"] = [tids[bypass.get(i, i)] for i in op["inputs"]]
        for index in op["inputs"]:
            graph["tensors"][index]["last_use"] = op["id"]
    graph["logits"] = tids[graph["logits"]]
    for tensor in graph["tensors"]:
        if tensor["persistent"] or tensor["id"] == graph["logits"]:
            tensor["last_use"] = len(graph["operations"])
    return graph


class DecoderGraphPolicy(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.api = str(Path(CONFIG.api).resolve(strict=True))
        cls.baseline = str(Path(CONFIG.baseline).resolve(strict=True))
        cls.evidence = Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True, exist_ok=False)
        cls.temp = tempfile.TemporaryDirectory(prefix="aesir-decoder-graph-policy-")
        cls.root = Path(cls.temp.name)
        cls.records = []
        cls.comparisons = 0

    @classmethod
    def tearDownClass(cls):
        counts = dict(Counter("accepted" if r["returncode"] == 0 else "refused" for r in cls.records))
        (cls.evidence / "runs.json").write_text(json.dumps(cls.records, indent=2) + "\n")
        (cls.evidence / "summary.json").write_text(json.dumps({"outcomes": counts,
            "complete_graph_comparisons": cls.comparisons}, indent=2) + "\n")
        cls.temp.cleanup()
        print("Native outcomes:", counts, "complete graphs:", cls.comparisons)

    def file(self, raw, suffix=".gguf"):
        path = self.root / ("source-" + str(len(list(self.root.iterdir()))) + suffix)
        path.write_bytes(raw)
        return path

    def child(self, command, trace=None):
        command = list(map(str, command))
        if trace:
            command = [CONFIG.strace, "-y", "-o", str(self.evidence / trace), "-e",
                "trace=openat,close,mmap,munmap,pread64,ioctl,write", *command]
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

    def reference(self, path, query=3, past=2):
        return self.accept(self.child([self.baseline, path, query, past, 16]))

    def inspect(self, path, flags, output="output.weight", query=3, past=2, provenance="explicit structural test"):
        return self.child([self.binary, path, query, past, 16, ",".join(map(str, flags)), output, provenance])

    def check(self, actual, reference, flags):
        self.assertEqual(actual["policy"]["rope_enabled"], flags)
        expected = without_rotary(reference, flags)
        self.assertEqual(actual["graph"], expected)
        type(self).comparisons += 1
        for flag in ("architecture_adapter_verified", "execution_tested", "device_access"):
            self.assertIs(actual[flag], False)
        graph = actual["graph"]
        names = {t["name"]: t for t in graph["tensors"]}
        p = graph["parameters"]
        for i, region in enumerate(actual["cache"]):
            layer, side = divmod(i, 2)
            kind = "key" if side == 0 else "value"
            suffix = "keys_view" if side == 0 else "values_view"
            base = names[f"blk.{layer}.{kind}_cache"]
            view = names[f"blk.{layer}.{suffix}"]
            dimension = p["key_dim"] if side == 0 else p["value_dim"]
            width = 2 if side == 0 else 1
            stride = 1048576
            offset = i * p["context_capacity"] * stride
            token_bytes = p["kv_heads"] * dimension * width
            last = offset + (p["context_capacity"] - 1) * stride + token_bytes - width
            self.assertEqual(region, [base["id"], view["id"], offset, token_bytes, stride,
                p["context_capacity"] * stride, last])
            writer = graph["operations"][view["producer"]]["inputs"][1]
            expected_writer = "v" if side else ("k_rotary" if flags[layer] else "k")
            self.assertEqual(graph["tensors"][writer]["name"], f"blk.{layer}.{expected_writer}")
        linear = [o for o in graph["operations"] if o["kind"] == "linear"]
        self.assertEqual(len(actual["matrix_operations"]), len(linear))
        for schedule, op in zip(actual["matrix_operations"], linear):
            out = graph["tensors"][op["output"]]
            weight = graph["weights"][op["weight"]]
            count = math.ceil(p["query_tokens"] / 2) * math.ceil(weight["rows"] / 3) * math.ceil(weight["columns"] / 2)
            self.assertEqual(schedule, [op["id"], op["inputs"][0], out["id"], count])
        for t, size in zip(graph["tensors"], actual["source_tensor_bytes"]):
            width = 4 if t["name"] in ("tokens", "positions") else 2
            expected_size = 0 if t["alias_of"] >= 0 else math.ceil(t["elements"] * width / 16) * 16
            self.assertEqual(size, expected_size)
        self.check_expanded(actual)

    def check_expanded(self, actual):
        graph = actual["graph"]
        values = actual["expanded_values"]
        operations = actual["expanded_operations"]
        mapping = actual["source_to_global"]
        self.assertEqual(len(mapping), len(graph["tensors"]))
        self.assertEqual(len(set(mapping)), len(mapping))
        for tensor, global_id in zip(graph["tensors"], mapping):
            v = values[global_id]
            self.assertEqual(v["shape"], tensor["shape"])
            self.assertEqual(v["source_tensor"], tensor["id"])
            if tensor["alias_of"] >= 0:
                self.assertEqual(v["alias_of"], mapping[tensor["alias_of"]])
        for i, op in enumerate(operations):
            self.assertGreaterEqual(op["source_operation"], 0)
            self.assertLess(op["source_operation"], len(graph["operations"]))
            self.assertEqual(values[op["output"]]["producer"], i)
            for index in op["inputs"]:
                self.assertLess(values[index]["producer"], i)
        self.assertEqual(actual["expanded_result"], mapping[graph["logits"]])
        exported = {mapping[t["id"]] for t in graph["tensors"] if t["persistent"] or t["id"] == graph["logits"]}
        last = [v["producer"] for v in values]
        for i, op in enumerate(operations):
            for index in op["inputs"]:
                last[index] = i
        # Source weights and runtime inputs are owned through the full schedule.
        for i, v in enumerate(values):
            if i in exported or (v["producer"] == -1 and v["source_tensor"] == -1):
                last[i] = len(operations)
            self.assertEqual(v["last_use"], last[i])
        for i, op in enumerate(operations):
            if op["kind"] in ("rope_query", "rope_key"):
                self.assertEqual(values[op["inputs"][1]]["domain"], "index")

    def test_all_small_masks_and_varied_sessions(self):
        rng = random.Random(921134)
        for layers in range(1, 5):
            for flags in itertools.product((0, 1), repeat=layers):
                tied = bool(rng.randrange(2))
                raw = dense_fixture(layers=layers, value=rng.randint(1, 5), tied=tied)[0]
                path = self.file(raw)
                query, past = rng.randint(1, 4), rng.randint(0, 6)
                reference = self.reference(path, query, past)
                actual = self.accept(self.inspect(path, flags, "token_embd.weight" if tied else "output.weight", query, past))
                self.check(actual, reference, list(flags))
                self.assertEqual(path.read_bytes(), raw)

    def test_periodic_and_quantized_source_descriptors(self):
        for layers, kind in [(36, 1), *[(2, k) for k in (0, 1, 12, 13, 14, 30)]]:
            kwargs = dict(layers=layers)
            if layers == 2:
                kwargs.update(hidden=256, ff=512, key=64, value=64, matrix_kind=kind)
            path = self.file(dense_fixture(**kwargs)[0])
            flags = [int((i + 1) % 4 != 0) for i in range(layers)] if layers == 36 else [0, 1]
            self.check(self.accept(self.inspect(path, flags)), self.reference(path), flags)

    def test_explicit_policy_refusals(self):
        path = self.file(dense_fixture()[0])
        for flags in ([], [0, 1], [-1], [2], [9223372036854775807]):
            self.refuse(self.inspect(path, flags))
        for output in ("", "missing", "output_norm.weight", "token_embd.weight"):
            self.refuse(self.inspect(path, [0], output))
        self.refuse(self.inspect(path, [0], provenance=""))
        self.refuse(self.child([self.binary, path, 3, 2, 16, "true", "output.weight", "test"]))
        self.refuse(self.child([self.binary, path, 3, 2, 16, "1," * 2050, "output.weight", "test"]))
        for mode in ("source_work", "source_tensors", "policy_short"):
            self.refuse(self.child([self.api, path, "0", mode]))
        self.accept(self.child([self.api, path, "0", "policy_exact"]))

    def test_owned_policies_and_cache_mutations(self):
        path = self.file(dense_fixture(layers=2)[0])
        common = ("mask_flip", "mask_invalid", "mask_short", "provenance_empty", "provenance_bound", "output_missing", "output_changed",
            "append_writer", "projection_input", "projection_arity", "projection_weight", "projection_shape", "projection_producer",
            "projection_alias", "projection_lifetime", "norm_shape", "norm_producer", "writer_lifetime", "writer_kind", "writer_output",
            "view_lifetime", "base_lifetime", "norm_output", "output_consumed", "output_shape")
        for flags in ("0,1", "1,0"):
            self.accept(self.child([self.api, path, flags, "ownership"]))
            for mode in common:
                self.refuse(self.child([self.api, path, flags, mode]))
        for mode in ("position_shape", "position_lifetime", "position_owner", "rotary_input", "rotary_position", "rotary_weight"):
            self.refuse(self.child([self.api, path, "1,0", mode]))

    def test_actual_tagged_safe_files_and_owned_intent(self):
        metadata = self.file(dense_fixture(layers=2, matrix_kind=0)[0])
        reference = self.reference(metadata)
        bindings = reference["weights"]
        for dtypes in (("F16",), ("BF16", "F32")):
            paths = []
            updates = {}
            filesizes = []
            for shard, dtype in enumerate(dtypes):
                selected = [(n, b) for i, (n, b) in enumerate(bindings.items()) if i % len(dtypes) == shard]
                descriptors = [(n, dtype, [b["columns"]] if n.endswith("norm.weight") else [b["rows"], b["columns"]]) for n, b in selected]
                raw, expected, _ = safe_fixture(descriptors)
                path = self.file(raw, ".weights")
                paths.append(path)
                data_offset = 8 + struct.unpack_from("<Q", raw)[0]
                filesizes.append(len(raw))
                for n, b in selected:
                    e = expected[n]
                    updates[n] = dict(b, source_kind=e["dtype"], file_offset=data_offset + e["relative"], byte_count=e["bytes"])
            actual = self.accept(self.child([self.api, metadata, "0,1", "safe", *paths], "safe-" + str(len(dtypes)) + ".strace"))
            safe_ref = copy.deepcopy(reference)
            safe_ref.update(architecture="explicit synthetic safetensors mathematical recipe", source_bytes=sum(filesizes),
                data_offset=-1 if len(paths) > 1 else 8 + struct.unpack_from("<Q", paths[0].read_bytes())[0],
                weight_bytes=sum(b["byte_count"] for b in updates.values()), weights=updates)
            # Existing graph schema has no data_offset field.
            safe_ref.pop("data_offset", None)
            self.check(actual, safe_ref, [0, 1])
            trace = (self.evidence / ("safe-" + str(len(dtypes)) + ".strace")).read_text()
            for forbidden in ("/dev/h1x-", "libhailort", "libcuda", "libggml", "ioctl("):
                self.assertNotIn(forbidden, trace)
        config = self.file(json.dumps({"model_type": "smollm3", "num_hidden_layers": 2, "no_rope_layers": [0, 1],
            "tie_word_embeddings": False, "attention_bias": False, "rope_scaling": {"future": [1, 2]},
            "unknown": {"retained": True}}).encode(), ".json")
        self.check(self.accept(self.child([self.api, metadata, "1,1", "intent", config])), reference, [0, 1])


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    for name in ("binary", "api", "baseline", "strace", "evidence"):
        parser.add_argument("--" + name, required=True)
    CONFIG, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
