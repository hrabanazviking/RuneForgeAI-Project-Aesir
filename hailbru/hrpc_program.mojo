# Original wire codec from HAILO10H_PROGRAM_DELIVERY_BOUNDARY.md.
# Metadata/lifecycle values only. No device open, upload or activation consumer.
from hailbru.errors import herror
from hailbru.hrpc_frame import HrpcFrame, HRPC_MAX_BODY_BYTES
from hailbru.hrpc_device import (
    HRPC_REQUEST_STATUS, _ProtoReader, _check_reply, _handle_body, _only_nested,
)

comptime HRPC_PROGRAM_CREATE = UInt32(2)
comptime HRPC_PROGRAM_DESTROY = UInt32(3)
comptime HRPC_CONFIGURED_DESTROY = UInt32(5)
comptime HRPC_CONFIGURED_ACTIVATE = UInt32(10)
comptime HRPC_CONFIGURED_DEACTIVATE = UInt32(11)
comptime HRPC_CONFIGURED_SHUTDOWN = UInt32(12)


def _valid_handle(handle: UInt32) raises:
    if handle == UInt32(4294967295):
        raise herror("BadProgramRpc", "invalid object handle sentinel")


def _append_u64(mut data: List[UInt8], value: UInt64):
    var rest = value
    while rest >= UInt64(128):
        data.append(UInt8(rest & UInt64(127)) | UInt8(128))
        rest >>= UInt64(7)
    data.append(UInt8(rest))


def _lifecycle_action(action: UInt32) raises:
    if action != HRPC_PROGRAM_DESTROY and action != HRPC_CONFIGURED_DESTROY and action != HRPC_CONFIGURED_ACTIVATE and action != HRPC_CONFIGURED_DEACTIVATE and action != HRPC_CONFIGURED_SHUTDOWN:
        raise herror("BadProgramRpc", "not an admitted handle-only program lifecycle action")


def program_create_request(message_id: UInt32, vdevice_handle: UInt32,
                           program_bytes: UInt64, name: String,
                           host_program_limit: UInt64) raises -> HrpcFrame:
    _valid_handle(vdevice_handle)
    if program_bytes == 0 or host_program_limit == 0 or program_bytes > host_program_limit:
        raise herror("BadProgramRpc", "invalid declared program size or explicit host bound")
    # Bound the UTF-8 data before copying/allocating a body. Names are protobuf
    # strings, not paths; embedded NUL is retained and never used in a syscall.
    var name_bytes = len(name.bytes())
    if name_bytes > HRPC_MAX_BODY_BYTES:
        raise herror("BadProgramRpc", "name exceeds RPC body bound")
    var body = _handle_body(vdevice_handle)
    body.append(16)
    _append_u64(body, program_bytes)
    if name_bytes != 0:
        # Check the exact resulting body size before copying name bytes.
        var prefix = List[UInt8]()
        _append_u64(prefix, UInt64(name_bytes))
        if len(body) + 1 + len(prefix) + name_bytes > HRPC_MAX_BODY_BYTES:
            raise herror("BadProgramRpc", "metadata exceeds RPC body bound")
        body.append(26)
        for byte in prefix:
            body.append(byte)
        for byte in name.bytes():
            body.append(byte)
    # The declared program bytes are a separate future transfer, never here.
    return HrpcFrame(message_id, HRPC_PROGRAM_CREATE, HRPC_REQUEST_STATUS, body^)


def program_handle_request(message_id: UInt32, action: UInt32,
                           handle: UInt32) raises -> HrpcFrame:
    _lifecycle_action(action)
    _valid_handle(handle)
    return HrpcFrame(message_id, action, HRPC_REQUEST_STATUS, _handle_body(handle))


def program_create_reply(frame: HrpcFrame, message_id: UInt32) raises -> UInt32:
    _check_reply(frame, message_id, HRPC_PROGRAM_CREATE)
    var reader = _ProtoReader(_only_nested(frame.body))
    var handle = UInt32(0)
    var found = False
    while reader.more():
        var key = reader.key()
        if key[0] == 1:
            if found:
                raise herror("BadProgramRpc", "duplicate infer-model handle scalar")
            handle = reader.uint32(key[1])
            found = True
        else:
            reader.skip(key[1])
    _valid_handle(handle)
    return handle


def program_empty_reply(frame: HrpcFrame, message_id: UInt32, action: UInt32) raises:
    _lifecycle_action(action)
    _check_reply(frame, message_id, action)
    var reader = _ProtoReader(frame.body)
    while reader.more():
        var key = reader.key()
        reader.skip(key[1])
