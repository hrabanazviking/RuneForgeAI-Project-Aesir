#!/usr/bin/env python3
"""Independent protobuf oracle for the native Mojo device-message tool.

TEST ONLY. Requires the explicit native binary and an installed google.protobuf
runtime (6.33.6 in the qualified test environment). No device or model access.
"""

import argparse
import json
from pathlib import Path
import struct
import subprocess
import sys
import unittest

from google.protobuf import descriptor_pb2, descriptor_pool, message_factory


CONFIG = argparse.Namespace(binary=None)
HEADER = struct.Struct("<5I")
MAGIC = 0x8A554432
FIELD = descriptor_pb2.FieldDescriptorProto


def schema():
    file = descriptor_pb2.FileDescriptorProto(name="aesir_hrpc_oracle.proto",
                                             package="oracle", syntax="proto3")
    enum = file.enum_type.add(name="Architecture")
    for index, name in enumerate(("HAILO8_A0", "HAILO8", "HAILO8L", "HAILO15H",
                                  "HAILO15L", "HAILO15M", "HAILO10H")):
        enum.value.add(name=name, number=index)
    definitions = {
        "Handle": [("id", 1, FIELD.TYPE_UINT32, None)],
        "Firmware": [("major", 1, FIELD.TYPE_UINT32, None),
                     ("minor", 2, FIELD.TYPE_UINT32, None),
                     ("revision", 3, FIELD.TYPE_UINT32, None)],
        "Identity": [("protocol_version", 1, FIELD.TYPE_UINT32, None),
                     ("fw_version", 2, FIELD.TYPE_MESSAGE, ".oracle.Firmware"),
                     ("logger_version", 3, FIELD.TYPE_UINT32, None),
                     ("board_name", 4, FIELD.TYPE_STRING, None),
                     ("architecture", 7, FIELD.TYPE_ENUM, ".oracle.Architecture"),
                     ("product_name", 10, FIELD.TYPE_STRING, None)],
        "CreateRequest": [],
        "CreateReply": [("device_handle", 1, FIELD.TYPE_MESSAGE, ".oracle.Handle")],
        "HandleRequest": [("device_handle", 1, FIELD.TYPE_MESSAGE, ".oracle.Handle")],
        "IdentifyReply": [("identity", 1, FIELD.TYPE_MESSAGE, ".oracle.Identity")],
        "DestroyReply": [],
    }
    for name, fields in definitions.items():
        message = file.message_type.add(name=name)
        for field_name, number, kind, type_name in fields:
            field = message.field.add(name=field_name, number=number, type=kind,
                                      label=FIELD.LABEL_OPTIONAL)
            if type_name:
                field.type_name = type_name
    pool = descriptor_pool.DescriptorPool()
    pool.AddSerializedFile(file.SerializeToString())
    return {name: message_factory.GetMessageClass(pool.FindMessageTypeByName("oracle." + name))
            for name in definitions}


MESSAGES = schema()


def packet(body, action, message_id=17, status=0):
    return (HEADER.pack(MAGIC, len(body), message_id, action, status) + body).hex()


class NativeDeviceMessages(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))

    def invoke(self, operation, message_id, value=None):
        arguments = [self.binary, operation, str(message_id)]
        if value is not None:
            arguments.append(str(value))
        return subprocess.run(arguments, capture_output=True, text=True, timeout=10,
                              stdin=subprocess.DEVNULL, check=False)

    def success(self, *arguments):
        result = self.invoke(*arguments)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        data = json.loads(result.stdout)
        self.assertIs(data.pop("device_access"), False)
        return data

    def rejected(self, operation, raw, code="BadRpcProtobuf", message_id=17):
        result = self.invoke(operation, message_id, raw)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("HailbruError[" + code + "]", result.stdout + result.stderr)

    def test_create_request_matches_independent_protobuf(self):
        for message_id in (0, 1, 0xFFFFFFFF):
            with self.subTest(message_id=message_id):
                expected = packet(MESSAGES["CreateRequest"]().SerializeToString(), 20, message_id)
                self.assertEqual(self.success("create-request", message_id),
                                 {"packet_hex": expected})

    def test_handle_requests_include_valid_zero_handle_presence(self):
        for handle in (0, 1, 127, 128, 255, 16383, 16384, 1 << 31, 0xFFFFFFFF):
            message = MESSAGES["HandleRequest"]()
            message.device_handle.id = handle
            body = message.SerializeToString()
            if handle == 0:
                self.assertEqual(body.hex(), "0a00")
            for operation, action in (("identify-request", 22), ("destroy-request", 21)):
                with self.subTest(handle=handle, operation=operation):
                    self.assertEqual(self.success(operation, 17, handle),
                                     {"packet_hex": packet(body, action)})

    def test_create_replies_match_independent_protobuf(self):
        for handle in (0, 1, 127, 128, 65535, 1 << 31, 0xFFFFFFFF):
            message = MESSAGES["CreateReply"]()
            message.device_handle.id = handle
            with self.subTest(handle=handle):
                self.assertEqual(self.success("create-reply", 17,
                                 packet(message.SerializeToString(), 20)), {"handle": handle})

    def test_identity_numeric_fields_and_optional_firmware_presence(self):
        for firmware in (None, (0, 0, 0), (5, 3, 0), (0xFFFFFFFF, 128, 65536)):
            for architecture in (0, 6, 99):
                message = MESSAGES["IdentifyReply"]()
                identity = message.identity
                identity.protocol_version = 2
                identity.logger_version = 7
                identity.architecture = architecture
                identity.board_name = "Unicode diagnostic: þór"
                identity.product_name = "Hailo test-only oracle"
                if firmware is not None:
                    identity.fw_version.major = firmware[0]
                    identity.fw_version.minor = firmware[1]
                    identity.fw_version.revision = firmware[2]
                values = firmware or (0, 0, 0)
                with self.subTest(firmware=firmware, architecture=architecture):
                    actual = self.success("identify-reply", 17,
                                          packet(message.SerializeToString(), 22))
                    self.assertEqual(actual, {
                        "protocol_version": 2, "firmware_major": values[0],
                        "firmware_minor": values[1], "firmware_revision": values[2],
                        "firmware_present": firmware is not None,
                        "logger_version": 7, "architecture": architecture,
                    })

    def test_empty_present_identity_is_not_fabricated_as_hailo10h(self):
        result = self.success("identify-reply", 17, packet(bytes.fromhex("0a00"), 22))
        self.assertEqual(result["architecture"], 0)
        self.assertEqual(result["protocol_version"], 0)
        self.assertIs(result["firmware_present"], False)

    def test_unknown_field_wire_types_are_skipped_safely(self):
        # Fields 100..103: varint 150, fixed64, bytes, fixed32.
        unknown = (bytes.fromhex("a0069601a906") + bytes(8)
                   + bytes.fromhex("b20603616263bd06") + bytes(4))
        body = bytes.fromhex("0a020807") + unknown
        message = MESSAGES["CreateReply"]()
        message.ParseFromString(body)
        self.assertEqual(message.device_handle.id, 7)
        self.assertEqual(self.success("create-reply", 17, packet(body, 20)), {"handle": 7})
        self.assertEqual(self.success("destroy-reply", 17, packet(unknown, 21)),
                         {"reply_kind": "destroy", "remote_status": 0})

    def test_reply_ids_actions_and_remote_errors_precede_body_parsing(self):
        for mode, action in (("create-reply", 20), ("identify-reply", 22),
                             ("destroy-reply", 21)):
            with self.subTest(mode=mode):
                self.rejected(mode, packet(b"\x00", action, message_id=18), "RpcReplyMismatch")
                self.rejected(mode, packet(b"\x00", action + 100), "RpcReplyMismatch")
                self.rejected(mode, packet(b"\x00", action, status=0xFFFFFFFF), "RpcRemoteFailure")

    def test_malformed_nested_and_unknown_fields_fail_closed(self):
        cases = [
            b"", bytes.fromhex("0a020880"), bytes.fromhex("0a06088080808010"),
            bytes.fromhex("0801"), bytes.fromhex("0a0100"),
            bytes.fromhex("0a000a00"), bytes.fromhex("0a0408010802"),
            bytes.fromhex("0a00a90601"), bytes.fromhex("8080808010"),
            bytes.fromhex("0a00a306"), bytes.fromhex("0affff03"),
            bytes.fromhex("0a00a006") + b"\xff" * 9 + b"\x02",
            bytes.fromhex("0a00b20680808080808080808002"),
        ]
        for body in cases:
            with self.subTest(body=body.hex()):
                self.rejected("create-reply", packet(body, 20))

    def test_duplicate_identity_and_firmware_fields_reject(self):
        for body in (bytes.fromhex("0a0408020803"),
                     bytes.fromhex("0a06120408050806"),
                     bytes.fromhex("0a023a00")):
            with self.subTest(body=body.hex()):
                self.rejected("identify-reply", packet(body, 22))

    def test_argument_bounds_and_unknown_modes(self):
        for mode, value in (("create-request", "4294967296"),
                            ("create-request", "-1"), ("create-request", "x")):
            result = self.invoke(mode, value)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("HailbruError[BadArgs]", result.stdout + result.stderr)
        result = self.invoke("identify-request", 0, "4294967296")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("HailbruError[BadArgs]", result.stdout + result.stderr)
        result = self.invoke("unknown-reply", 17, packet(b"", 20))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("HailbruError[BadArgs]", result.stdout + result.stderr)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True)
    CONFIG, extra = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *extra])
