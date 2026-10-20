#!/usr/bin/env python3
"""Frozen-schema independent configure wire oracle; no device or inference."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import sys
import tempfile
import unittest
import google.protobuf
from google.protobuf import descriptor_pb2, descriptor_pool, message_factory

CONFIG = argparse.Namespace()
MAX = (1 << 32)-1
NEGATIVE_ONE = 0xbf800000


def varint(value):
    result = bytearray()
    while value > 127:
        result.append(value % 128 + 128)
        value //= 128
    return bytes(result + bytes([value]))


def packet(body, message=17, action=4, status=0):
    return struct.pack("<IIIII", 0x8a554432, len(body), message, action, status) + body


def stream(name="tokens", order=0, kind=0, score=0, iou=0, per_class=0, mask=0, total=0):
    return (name, order, kind, score, iou, per_class, mask, total)


def plain(name, order=0, kind=0):
    return stream(name, order, kind, NEGATIVE_ONE, NEGATIVE_ONE, MAX, MAX, MAX)


class ConfigureRpc(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.evidence = Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True, exist_ok=False)
        cls.temp = tempfile.TemporaryDirectory(prefix="aesir-configure-wire-")
        cls.root = Path(cls.temp.name)
        cls.records = []
        schema = Path(CONFIG.schema).resolve(strict=True)
        header = Path(CONFIG.enum_header).resolve(strict=True)
        assert hashlib.sha256(schema.read_bytes()).hexdigest() == "c44ec3a28d075bae5f814f99491a4f1de0c3cbd026721243e8876c67b5da9225"
        assert hashlib.sha256(header.read_bytes()).hexdigest() == "e02cdb188ac543edd2a4b746c50399b6a74ad8ef1eb230ba5431ae47fccd3a87"
        descriptor = cls.root / "rpc.pb"
        subprocess.run([CONFIG.protoc, "-I", str(schema.parent), "--descriptor_set_out="+str(descriptor), str(schema)], capture_output=True, check=True)
        files = descriptor_pb2.FileDescriptorSet.FromString(descriptor.read_bytes())
        cls.pool = descriptor_pool.DescriptorPool()
        for file in files.file:
            cls.pool.Add(file)
        body = re.search(r"enum class HailoRpcActionID\s*\{(.*?)\};", header.read_text(), re.S)[1]
        names = [item.strip() for item in re.sub(r"//[^\n]*", "", body).split(",") if item.strip()]
        cls.action = names.index("INFER_MODEL__CREATE_CONFIGURED_INFER_MODEL")
        assert cls.action == 4
        (cls.evidence / "oracle-provenance.json").write_text(json.dumps({"revision": "d503417f2a0db186a838390fb08690c4ea0f415e", "schema_sha256": hashlib.sha256(schema.read_bytes()).hexdigest(), "enum_header_sha256": hashlib.sha256(header.read_bytes()).hexdigest(), "descriptor_sha256": hashlib.sha256(descriptor.read_bytes()).hexdigest(), "protoc": subprocess.check_output([CONFIG.protoc, "--version"], text=True).strip(), "protobuf_runtime": google.protobuf.__version__, "licenses": "HailoRT MIT and installed protobuf BSD-3-Clause already read before oracle use", "action_id": cls.action, "scope": "generated public-schema wire oracle only; no external implementation copied or shipped"}, indent=2)+"\n")

    @classmethod
    def tearDownClass(cls):
        counts = Counter("accepted" if r["returncode"] == 0 else "refused" for r in cls.records)
        (cls.evidence / "runs.json").write_text(json.dumps(cls.records, indent=2)+"\n")
        (cls.evidence / "summary.json").write_text(json.dumps(dict(counts), indent=2)+"\n")
        cls.temp.cleanup()
        print("Native outcomes:", dict(counts))

    def message(self, name):
        return message_factory.GetMessageClass(self.pool.FindMessageTypeByName(name))()

    def invoke(self, *args, trace=False):
        command = [self.binary, *map(str, args)]
        if trace:
            command = [CONFIG.strace, "-y", "-o", str(self.evidence / "configure.strace"), "-e", "trace=openat,ioctl,mmap,munmap", *command]
        result = subprocess.run(command, capture_output=True, text=True, timeout=15, stdin=subprocess.DEVNULL)
        self.records.append({"mode": args[0], "returncode": result.returncode, "stdout": result.stdout, "stderr": result.stderr})
        return result

    def accepted(self, result):
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        obj = json.loads(result.stdout)
        for flag in ("device_access", "configured_on_device", "execution_tested"):
            self.assertIs(obj[flag], False)
        return obj

    def refused(self, result):
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertIn("HailbruError[", result.stderr)

    def request_proto(self, handles=(0, 0), batch=0, power=0, latency=0, kv=False, inputs=(), outputs=()):
        request = self.message("InferModel_CreateConfiguredInferModel_Request")
        request.infer_model_handle.id, request.vdevice_handle.id = handles
        for values, target in ((inputs, request.input_infer_streams), (outputs, request.output_infer_streams)):
            for name, order, kind, score, iou, per_class, mask, total in values:
                item = target.add(name=name, format_order=order, format_type=kind, nms_max_proposals_per_class=per_class, nms_max_accumulated_mask_size=mask, nms_max_proposals_total=total)
                # Let the generated parser/serializer interpret independent
                # fixed32 fields, preserving raw float words without a Python
                # float-to-double round trip or signaling-NaN normalization.
                item.MergeFromString(b"\x25"+struct.pack("<I", score)+b"\x2d"+struct.pack("<I", iou))
        request.batch_size, request.power_mode, request.latency_flag, request.enable_kv_cache = batch, power, latency, kv
        return request

    def request(self, message=17, handles=(0, 0), batch=0, power=0, latency=0, kv=False, inputs=(), outputs=(), trace=False):
        args = ["request", message, *handles, batch, power, latency, int(kv)]
        for direction, streams in (("i", inputs), ("o", outputs)):
            for values in streams:
                args.extend((direction, *values))
        return self.invoke(*args, trace=trace)

    def assert_request(self, **kwargs):
        obj = self.accepted(self.request(**kwargs))
        expected = self.request_proto(**{k:v for k,v in kwargs.items() if k not in ("message", "trace")})
        self.assertEqual(bytes.fromhex(obj["packet_hex"]), packet(expected.SerializeToString(), kwargs.get("message", 17), self.action, 1))
        return obj

    def test_exact_defaults_handles_uint32_fields_and_batch_bound(self):
        for message, handles, batch, power, latency, kv in ((0, (0, 0), 0, 0, 0, False), (17, (1, 9), 1, 1, 3, True), (MAX, (MAX-1, MAX-1), 65535, MAX, MAX, True)):
            self.assert_request(message=message, handles=handles, batch=batch, power=power, latency=latency, kv=kv)
        for handles in ((MAX, 0), (0, MAX)):
            self.refused(self.request(handles=handles))
        self.refused(self.request(batch=65536))
        for value in (-1, 1 << 32):
            self.refused(self.request(message=value))
            self.refused(self.request(power=value))

    def test_every_stream_field_and_exact_float_words(self):
        words = (0, 0x80000000, 0xbf800000, 0x3f000000, 0x7f800000, 0xff800000, 0x7fc12345, 0x7f812345, 1, MAX)
        for i, word in enumerate(words):
            self.assert_request(handles=(1, 2), inputs=[stream("tokens-🌋", MAX-i, i % 4, word, words[-1-i], i, MAX, 31+i)], outputs=[stream("logits-é", 1, 3, words[-1-i], word, MAX, i, 9)], batch=2, kv=bool(i % 2))

    def test_plain_stream_sentinels_multilingual_and_direction_names(self):
        actual = self.accepted(self.invoke("plain", 17, 0, 1, 0, 1, 3, 1, "输入-🌋", "выход-é", 7, 3))
        expected = self.request_proto(handles=(0, 1), power=1, latency=3, kv=True, inputs=[plain("输入-🌋", 7, 3)], outputs=[plain("выход-é", 7, 3)])
        self.assertEqual(bytes.fromhex(actual["packet_hex"]), packet(expected.SerializeToString(), status=1))
        for direction in ("input", "output"):
            values = [plain("same"), plain("same")]
            self.refused(self.request(**{"inputs" if direction == "input" else "outputs": values}))
        self.assert_request(inputs=[plain("same")], outputs=[plain("same")])
        self.refused(self.request(inputs=[plain("")]))
        self.refused(self.invoke("many", 17))

    def test_exact_frame_bounds_byte_lengths_and_utf8_refusals(self):
        obj = self.assert_request(inputs=[stream("x"*2038)])
        self.assertEqual(len(bytes.fromhex(obj["packet_hex"])), 2068)
        self.refused(self.request(inputs=[stream("x"*2039)]))
        self.refused(self.request(inputs=[stream("x"*2049)]))
        self.assert_request(inputs=[stream("é"*1019)])
        self.refused(self.request(inputs=[stream("é"*1020)]))
        for raw in ("80", "c080", "c328", "e08080", "eda080", "f0808080", "f4908080", "f5808080", "f09f", "ff"):
            self.refused(self.invoke("raw-name", 17, raw))
        self.refused(self.invoke("bad-utf8", 17))

    def test_owned_frames_and_embedded_nul_name(self):
        obj = self.accepted(self.invoke("ownership", 17))
        expected = self.request_proto(handles=(0, 1), latency=1, kv=True, inputs=[plain("a\0b", 5, 3)])
        self.assertEqual(bytes.fromhex(obj["packet_hex"]), packet(expected.SerializeToString(), status=1))

    def test_generated_replies_defaults_and_unknown_fields(self):
        for handle, queue in ((0, 0), (1, 64), (MAX-1, MAX)):
            reply = self.message("InferModel_CreateConfiguredInferModel_Reply")
            reply.configured_infer_model_handle.id = handle
            reply.async_queue_size = queue
            for suffix in (b"", b"\x48\x01", b"\x4a\x03abc", b"\x4d1234", b"\x4912345678"):
                obj = self.accepted(self.invoke("reply", 17, packet(reply.SerializeToString()+suffix).hex()))
                self.assertEqual((obj["handle"], obj["async_queue_size"]), (handle, queue))
        self.accepted(self.invoke("reply", 17, packet(b"\x10\x03\x0a\x00").hex()))
        self.accepted(self.invoke("reply", 17, packet(b"\x0a\x02\x48\x01").hex()))

    def test_reply_duplicate_known_wire_range_and_correlation_refusals(self):
        bodies = (b"", b"\x12\x00", b"\x08\x00", b"\x0a\x01\x08", b"\x0a\x00\x0a\x00", b"\x0a\x04\x08\x00\x08\x01", b"\x0a\x00\x10\x01\x10\x02", b"\x0a\x00\x15abcd", b"\x0a\x01\x00", b"\x0a\x00\x4b", b"\x0a\x00\x80", b"\x0a\xff\xff\xff\xff\x0f", b"\x0a\x00\x10"+varint(1 << 32), b"\x0a"+varint(1+len(varint(1 << 32)))+b"\x08"+varint(1 << 32), b"\x0a\x06\x08"+varint(MAX), b"\x0a\x00\x10"+b"\xff"*10, b"\x0a\x00\x00")
        for body in bodies:
            self.refused(self.invoke("reply", 17, packet(body).hex()))
        for key, value in (("message", 18), ("action", 5), ("status", 1), ("status", MAX)):
            self.refused(self.invoke("reply", 17, packet(b"\x0a\x00", **{key:value}).hex()))
        self.refused(self.invoke("reply", 17, packet(b"\x0a\x00"+b"\x48\x00"*1024).hex()))

    def test_host_only_read_only_trace(self):
        self.assert_request(inputs=[plain("tokens")], outputs=[plain("logits")], kv=True, trace=True)
        trace = (self.evidence / "configure.strace").read_text()
        for forbidden in ("/dev/h1x-", "libhailort", "libcuda", "libggml", "ioctl("):
            self.assertNotIn(forbidden, trace)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    for name in ("binary", "schema", "enum-header", "protoc", "strace", "evidence"):
        parser.add_argument("--"+name, required=True)
    CONFIG, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
