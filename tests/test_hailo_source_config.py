#!/usr/bin/env python3
"""Independent ordinary configuration metadata checks; no model execution."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import random
import subprocess
import tempfile
import unittest

CONFIG = argparse.Namespace()
DEFAULT = (1048576, 10000, 10000000, 64)


def encode(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode()


def depth(value):
    if isinstance(value, dict):
        return 1 + max(map(depth, value.values()), default=0)
    if isinstance(value, list):
        return 1 + max(map(depth, value), default=0)
    return 1


class SourceConfig(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.api = str(Path(CONFIG.api).resolve(strict=True))
        cls.temp = tempfile.TemporaryDirectory(prefix="aesir-source-config-")
        cls.root = Path(cls.temp.name)
        cls.evidence = Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True, exist_ok=True)
        cls.records = []

    @classmethod
    def tearDownClass(cls):
        (cls.evidence / "runs.json").write_text(json.dumps(cls.records, indent=2) + "\n")
        counts = dict(Counter("accepted" if x["returncode"] == 0 else "refused" for x in cls.records))
        (cls.evidence / "summary.json").write_text(json.dumps(counts, indent=2) + "\n")
        print("Native outcomes:", counts)
        cls.temp.cleanup()

    def child(self, command, trace=None):
        if trace:
            command = [CONFIG.strace, "-y", "-o", str(self.evidence / trace), "-e",
                       "trace=openat,close,statx,read,write,ioctl,mmap,munmap", *command]
        command = list(map(str, command))
        result = subprocess.run(command, capture_output=True, text=True, timeout=15,
                                stdin=subprocess.DEVNULL, check=False)
        self.records.append({"arguments": command, "returncode": result.returncode,
                             "stdout": result.stdout, "stderr": result.stderr})
        return result

    def source(self, raw):
        path = self.root / f"config-{len(self.records)}.json"
        path.write_bytes(raw)
        return path

    def run_raw(self, raw, policy=DEFAULT, api=False, ownership=False):
        if api or ownership:
            return self.child([self.api, "ownership" if ownership else "bytes", raw.hex(), *policy])
        path = self.source(raw)
        result = self.child([self.binary, path, *policy])
        self.assertEqual(path.read_bytes(), raw)
        return result

    def accepted(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        value = json.loads(result.stdout)
        for flag in ("tensors_loaded", "shards_opened", "semantic_adapter_verified",
                     "source_fingerprint_verified", "hardware_fit_verified", "execution_tested"):
            self.assertIs(value[flag], False)
        return value

    def refused(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual(result.stdout, "")

    def compare(self, raw, expected, **kwargs):
        value = self.accepted(self.run_raw(raw, **kwargs))
        self.assertEqual({k: json.loads(v) for k, v in value["fields_raw"].items()}, expected)
        self.assertEqual(value["source_bytes"], len(raw))
        self.assertEqual(value["root_fields"], len(expected))
        self.assertEqual(value["work_units"], 4 * len(raw) + len(expected))
        return value

    def test_owned_raw_values_and_modifiers(self):
        # Raw spelling is deliberately distinct from JSON reserialization.
        raw = b" { \"rope_scaling\" : { \"type\":\"future\", \"factor\":1.00e+02 }, \"eps\": -0, \"name\":\"\\u00c6\\u0000\", \"future\":[true, null, {\"a\":2}] } \n"
        expected = json.loads(raw)
        for api in (False, True):
            value = self.compare(raw, expected, api=api, ownership=api)
            self.assertEqual(value["fields_raw"]["rope_scaling"], "{ \"type\":\"future\", \"factor\":1.00e+02 }")
            self.assertEqual(value["fields_raw"]["eps"], "-0")
            self.assertEqual(value["fields_raw"]["name"], "\"\\u00c6\\u0000\"")
        for expected in ({}, {"": None, "Æsir\0🜁": "text\0"},
                         {"model_type": None, "architectures": 1, "unknown": True},
                         {"model_type": "future", "tie_word_embeddings": False,
                          "no_rope_layers": [1, 0], "sliding_window": 8192,
                          "mlp_bias": True, "attention_bias": False},
                         {"large": 10**100, "small": 1e-100}):
            self.compare(encode(expected), expected, ownership=True)

    def test_seeded_configurations(self):
        rng = random.Random(103114)
        for i in range(60):
            expected = {f"field-{j}-Æ\0": rng.choice([None, True, False, i, -i, "🜁",
                        [i, {"factor": i + 0.25}], {"nested": [i, None]}]) for j in range(i % 13)}
            pairs = list(expected.items())
            rng.shuffle(pairs)
            raw = json.dumps(dict(pairs), ensure_ascii=i % 2 == 0, indent=i % 4).encode()
            self.compare(raw, expected, api=i % 2 == 0, ownership=i % 3 == 0)

    def test_malformed_json_utf8_and_truncation(self):
        bad = [b"", b" ", b"[]", b"null", b"true", b"1", b"\"text\"", b"{}{}",
               b"{}x", b"{\"a\":0,}", b"{\"a\":01}", b"{\"a\":NaN}",
               b"{\"a\":+1}", b"{\"a\":1e}", b"{\"a\":.1}", b"{\"a\":1.}",
               b"{\"a\":truefalse}", b"{\"a\":\"\\x\"}", b"{\"a\":\"\\uD800\"}",
               b"{\"a\":\"\\uDC00\"}", b"{\"a\":\"\xff\"}", b"{\"a\":\"\xc0\x80\"}",
               b"{\"a\":\"\xed\xa0\x80\"}", b"{\"a\":\"\xf4\x90\x80\x80\"}",
               b"{\"a\":\"\x00\"}", b"\xef\xbb\xbf{}", b"{}\x00",
               b"{\"a\":1,\"\\u0061\":2}", b"{\"a\":{\"x\":0,\"x\":1}}",
               b"{\"a\":[{\"x\":0,\"\\u0078\":1}]}"]
        raw = encode({"Æsir": ["🜁", {"modifier": True}], "tail": None})
        bad.extend(raw[:i] for i in range(len(raw)))
        for i, raw in enumerate(bad):
            self.refused(self.run_raw(raw, api=i % 2 == 0))
        for scalar in ("true", "false", "null", "[]", "0", "-1.25e+3", "\"\\uDBFF\\uDFFF\""):
            raw = ("{\"value\":" + scalar + "}").encode()
            self.compare(raw, json.loads(raw))

    def test_exact_policies(self):
        for expected in ({}, {"a": 1}, {"a": 1, "b": [2, 3]}, {"a": {"nested": [1]}}):
            raw = encode(expected)
            exact = (len(raw), max(1, len(expected)), 4 * len(raw) + len(expected), depth(expected))
            self.compare(raw, expected, policy=exact, api=True)
            for index in (0, 2, 3):
                policy = list(exact)
                policy[index] -= 1
                self.refused(self.run_raw(raw, policy, api=True))
            if len(expected) > 1:
                policy = list(exact)
                policy[1] -= 1
                self.refused(self.run_raw(raw, policy, api=True))
        for index in range(4):
            for value in (0, -1):
                policy = list(DEFAULT)
                policy[index] = value
                self.refused(self.run_raw(b"{}", policy, api=True))
        self.refused(self.run_raw(b"{}", (*DEFAULT[:3], 65), api=True))
        raw = b"{\"a\":" + b"[" * 62 + b"0" + b"]" * 62 + b"}"
        self.compare(raw, json.loads(raw), api=True)
        raw = b"{\"a\":" + b"[" * 63 + b"0" + b"]" * 63 + b"}"
        self.refused(self.run_raw(raw, api=True))

    def test_file_admission_and_cleanup(self):
        valid = self.root / "valid.json"
        valid.write_bytes(encode({"future": {"modifier": [1, 2]}}))
        invalid = self.root / "invalid.json"
        invalid.write_bytes(b"{\"future\":0,}")
        for size in (8191, 8192, 8193):
            raw = b"{}" + b" " * (size - 2)
            self.compare(raw, {})
        for path in (self.root / "missing.json", self.root):
            self.refused(self.child([self.binary, path, *DEFAULT]))
        fifo = self.root / "config.fifo"
        os.mkfifo(fifo)
        self.refused(self.child([self.binary, fifo, *DEFAULT]))
        huge = self.root / "oversize.json"
        huge.write_bytes(b"{}extra")
        self.refused(self.child([self.binary, huge, 2, *DEFAULT[1:]]))
        result = self.child([self.api, "cleanup", valid, invalid], "cleanup.strace")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["cleanup_cycles"], 40)
        trace = (self.evidence / "cleanup.strace").read_text()
        for path in (valid, invalid):
            self.assertEqual(sum("openat(" in line and f"\"{path}\"" in line for line in trace.splitlines()), 40)
            self.assertEqual(sum("close(" in line and f"<{path}>" in line for line in trace.splitlines()), 40)
        self.assertNotIn("ioctl(", trace)
        self.assertNotIn("/dev/h1x", trace)
        self.assertNotIn(".safetensors\"", trace)

    def test_pinned_ordinary_configuration(self):
        path = Path(CONFIG.public_config).resolve(strict=True)
        raw = path.read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), "c72b1031274ff4626e434d0019e88e95a767460135db9ee492eb80652b786af1")
        expected = json.loads(raw)
        value = self.compare(raw, expected, ownership=True)
        physical = self.accepted(self.child([self.binary, path, *DEFAULT], "ordinary-config.strace"))
        self.assertEqual(value["fields_raw"], physical["fields_raw"])
        self.assertEqual(json.loads(physical["fields_raw"]["no_rope_layers"]), expected["no_rope_layers"])
        self.assertEqual(json.loads(physical["fields_raw"]["tie_word_embeddings"]), True)
        self.assertEqual(path.read_bytes(), raw)
        trace = (self.evidence / "ordinary-config.strace").read_text()
        self.assertEqual(sum("openat(" in line and f"\"{path}\"" in line for line in trace.splitlines()), 1)
        self.assertEqual(sum("close(" in line and f"<{path}>" in line for line in trace.splitlines()), 1)
        self.assertNotIn("ioctl(", trace)
        self.assertNotIn(".safetensors\"", trace)
        (self.evidence / "public-config-facts.json").write_text(json.dumps({"sha256": hashlib.sha256(raw).hexdigest(),
            "root_fields": len(expected), "model_type_raw": value["fields_raw"]["model_type"],
            "semantic_adapter_verified": False, "execution_tested": False}, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True)
    parser.add_argument("--api", required=True)
    parser.add_argument("--public-config", required=True)
    parser.add_argument("--strace", required=True)
    parser.add_argument("--evidence", required=True)
    CONFIG, rest = parser.parse_known_args()
    unittest.main(argv=["source-config", *rest])
