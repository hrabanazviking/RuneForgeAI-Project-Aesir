# Typed control messages for the independently owned integrated-device path.
# Protocol facts: pinned HailoRT v5.3.0 rpc.proto / serializer.hpp (d503417).
# No device access, vendor implementation reuse, model loading or inference.

from hailbru.errors import herror
from hailbru.hrpc_frame import HrpcFrame, HRPC_MAX_BODY_BYTES

comptime HRPC_DEVICE_CREATE = UInt32(20)
comptime HRPC_DEVICE_DESTROY = UInt32(21)
comptime HRPC_DEVICE_IDENTIFY = UInt32(22)


def _append_varint(mut data: List[UInt8], value: UInt32):
    var rest = value
    while rest >= UInt32(128):
        data.append(UInt8(rest & UInt32(127)) | UInt8(128))
        rest >>= UInt32(7)
    data.append(UInt8(rest))


def _handle_body(handle: UInt32) -> List[UInt8]:
    var nested = List[UInt8]()
    # Proto3 omits a zero scalar but preserves the enclosing message's presence.
    if handle != 0:
        nested.append(8)
        _append_varint(nested, handle)
    var body = List[UInt8]()
    body.append(10)
    _append_varint(body, UInt32(len(nested)))
    for byte in nested:
        body.append(byte)
    return body^


def device_create_request(message_id: UInt32) -> HrpcFrame:
    return HrpcFrame(message_id, HRPC_DEVICE_CREATE, UInt32(0), List[UInt8]())


def device_identify_request(message_id: UInt32, handle: UInt32) -> HrpcFrame:
    return HrpcFrame(message_id, HRPC_DEVICE_IDENTIFY, UInt32(0), _handle_body(handle))


def device_destroy_request(message_id: UInt32, handle: UInt32) -> HrpcFrame:
    return HrpcFrame(message_id, HRPC_DEVICE_DESTROY, UInt32(0), _handle_body(handle))


struct _ProtoReader:
    var data: List[UInt8]
    var position: Int

    def __init__(out self, data: List[UInt8]) raises:
        if len(data) > HRPC_MAX_BODY_BYTES:
            raise herror("BadRpcProtobuf", "message exceeds the admitted RPC body")
        self.data = data.copy()
        self.position = 0

    def more(self) -> Bool:
        return self.position < len(self.data)

    def varint(mut self) raises -> UInt64:
        var result = UInt64(0)
        for index in range(10):
            if self.position >= len(self.data):
                raise herror("BadRpcProtobuf", "truncated varint")
            var byte = self.data[self.position]
            self.position += 1
            if index == 9 and byte > 1:
                raise herror("BadRpcProtobuf", "varint exceeds UInt64")
            result |= UInt64(byte & 127) << UInt64(index * 7)
            if byte < 128:
                return result
        raise herror("BadRpcProtobuf", "unterminated varint")

    def key(mut self) raises -> Tuple[Int, Int]:
        var value = self.varint()
        if value > UInt64(4294967295) or (value >> UInt64(3)) == 0:
            raise herror("BadRpcProtobuf", "invalid protobuf field key")
        return (Int(value >> UInt64(3)), Int(value & UInt64(7)))

    def uint32(mut self, wire: Int) raises -> UInt32:
        if wire != 0:
            raise herror("BadRpcProtobuf", "expected a varint field")
        var value = self.varint()
        if value > UInt64(4294967295):
            raise herror("BadRpcProtobuf", "field exceeds UInt32")
        return UInt32(value)

    def bytes(mut self, wire: Int) raises -> List[UInt8]:
        if wire != 2:
            raise herror("BadRpcProtobuf", "expected a length-delimited field")
        var size = self.varint()
        if size > UInt64(len(self.data) - self.position):
            raise herror("BadRpcProtobuf", "truncated length-delimited field")
        var result = List[UInt8]()
        result.reserve(Int(size))
        for index in range(Int(size)):
            result.append(self.data[self.position + index])
        self.position += Int(size)
        return result^

    def skip(mut self, wire: Int) raises:
        if wire == 0:
            _ = self.varint()
        elif wire == 2:
            _ = self.bytes(wire)
        elif wire == 1 or wire == 5:
            var size = 8 if wire == 1 else 4
            if size > len(self.data) - self.position:
                raise herror("BadRpcProtobuf", "truncated fixed-width field")
            self.position += size
        else:
            raise herror("BadRpcProtobuf", "unsupported protobuf wire type")


def _check_reply(frame: HrpcFrame, message_id: UInt32, action_id: UInt32) raises:
    if frame.message_id != message_id or frame.action_id != action_id:
        raise herror("RpcReplyMismatch", "reply ID/action does not match the request")
    if frame.remote_status != 0:
        raise herror("RpcRemoteFailure", "device returned status " + String(frame.remote_status))


def _only_nested(data: List[UInt8]) raises -> List[UInt8]:
    var reader = _ProtoReader(data)
    var found = False
    var result = List[UInt8]()
    while reader.more():
        var key = reader.key()
        if key[0] == 1:
            if found:
                raise herror("BadRpcProtobuf", "duplicate enclosing message")
            result = reader.bytes(key[1])
            found = True
        else:
            reader.skip(key[1])
    if not found:
        raise herror("BadRpcProtobuf", "missing enclosing message")
    return result^


def device_create_reply(frame: HrpcFrame, message_id: UInt32) raises -> UInt32:
    _check_reply(frame, message_id, HRPC_DEVICE_CREATE)
    var reader = _ProtoReader(_only_nested(frame.body))
    var handle = UInt32(0)
    var found = False
    while reader.more():
        var key = reader.key()
        if key[0] == 1:
            if found:
                raise herror("BadRpcProtobuf", "duplicate handle scalar")
            handle = reader.uint32(key[1])
            found = True
        else:
            reader.skip(key[1])
    return handle


def device_destroy_reply(frame: HrpcFrame, message_id: UInt32) raises:
    _check_reply(frame, message_id, HRPC_DEVICE_DESTROY)
    var reader = _ProtoReader(frame.body)
    while reader.more():
        var key = reader.key()
        reader.skip(key[1])


struct HrpcDeviceIdentity(Movable):
    var protocol_version: UInt32
    var firmware_major: UInt32
    var firmware_minor: UInt32
    var firmware_revision: UInt32
    var firmware_present: Bool
    var logger_version: UInt32
    var architecture: UInt32

    def __init__(out self):
        self.protocol_version = 0
        self.firmware_major = 0
        self.firmware_minor = 0
        self.firmware_revision = 0
        self.firmware_present = False
        self.logger_version = 0
        self.architecture = 0


def _firmware(data: List[UInt8]) raises -> Tuple[UInt32, UInt32, UInt32]:
    var reader = _ProtoReader(data)
    var major = UInt32(0)
    var minor = UInt32(0)
    var revision = UInt32(0)
    var seen = UInt32(0)
    while reader.more():
        var key = reader.key()
        var field = key[0]
        if field >= 1 and field <= 3:
            var bit = UInt32(1) << UInt32(field)
            if (seen & bit) != 0:
                raise herror("BadRpcProtobuf", "duplicate firmware scalar")
            seen |= bit
            var value = reader.uint32(key[1])
            if field == 1:
                major = value
            elif field == 2:
                minor = value
            else:
                revision = value
        else:
            reader.skip(key[1])
    return (major, minor, revision)


def device_identify_reply(frame: HrpcFrame, message_id: UInt32) raises -> HrpcDeviceIdentity:
    _check_reply(frame, message_id, HRPC_DEVICE_IDENTIFY)
    var reader = _ProtoReader(_only_nested(frame.body))
    var identity = HrpcDeviceIdentity()
    var seen = UInt32(0)
    while reader.more():
        var key = reader.key()
        var field = key[0]
        if field == 1 or field == 2 or field == 3 or field == 7:
            var bit = UInt32(1) << UInt32(field)
            if (seen & bit) != 0:
                raise herror("BadRpcProtobuf", "duplicate identity field")
            seen |= bit
            if field == 2:
                var version = _firmware(reader.bytes(key[1]))
                identity.firmware_major = version[0]
                identity.firmware_minor = version[1]
                identity.firmware_revision = version[2]
                identity.firmware_present = True
            else:
                var value = reader.uint32(key[1])
                if field == 1:
                    identity.protocol_version = value
                elif field == 3:
                    identity.logger_version = value
                else:
                    identity.architecture = value
        else:
            reader.skip(key[1])
    return identity^
