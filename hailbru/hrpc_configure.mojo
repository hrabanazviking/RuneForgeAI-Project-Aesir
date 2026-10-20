# Original bounded action-4 codec from the published public field contract.
# No device, program delivery, numerical configuration or inference consumer.
from hailbru.errors import herror
from hailbru.hrpc_frame import HrpcFrame, HRPC_MAX_BODY_BYTES
from hailbru.hrpc_device import HRPC_REQUEST_STATUS, _ProtoReader, _append_varint, _handle_body, _check_reply
from hailbru.hrpc_program import _valid_handle

comptime HRPC_PROGRAM_CONFIGURE = UInt32(4)


@fieldwise_init
struct HrpcInferStream(Copyable, Movable):
    var name: String
    var format_order: UInt32
    var format_type: UInt32
    var nms_score_bits: UInt32
    var nms_iou_bits: UInt32
    var nms_max_per_class: UInt32
    var nms_max_mask_size: UInt32
    var nms_max_total: UInt32


def plain_infer_stream(name: String, order: UInt32, kind: UInt32) -> HrpcInferStream:
    # Proto3 zero defaults would ask the receiver to apply NMS settings. These
    # are public unset sentinels, not a hidden choice of numerical precision.
    return HrpcInferStream(name, order, kind, UInt32(0xbf800000), UInt32(0xbf800000),
        UInt32(4294967295), UInt32(4294967295), UInt32(4294967295))


@fieldwise_init
struct HrpcConfigureParams(Copyable, Movable):
    var infer_model: UInt32
    var vdevice: UInt32
    var inputs: List[HrpcInferStream]
    var outputs: List[HrpcInferStream]
    var batch_size: UInt32
    var power_mode: UInt32
    var latency_flags: UInt32
    var enable_kv_cache: Bool


@fieldwise_init
struct HrpcConfigureReply(ImplicitlyCopyable, Movable):
    var handle: UInt32
    var async_queue_size: UInt32


def _bound(size: Int) raises:
    if size < 0 or size > HRPC_MAX_BODY_BYTES:
        raise herror("BadConfigureRpc", "configuration exceeds pinned body bound")


def _scalar(mut body: List[UInt8], field: Int, value: UInt32) raises:
    if value == 0:
        return
    var part = List[UInt8]()
    _append_varint(part, value)
    _bound(len(body) + 1 + len(part))
    body.append(UInt8(field * 8))
    for byte in part:
        body.append(byte)


def _nested(mut body: List[UInt8], field: Int, child: List[UInt8]) raises:
    _bound(len(child))
    var size = List[UInt8]()
    _append_varint(size, UInt32(len(child)))
    _bound(len(body) + 1 + len(size) + len(child))
    body.append(UInt8(field * 8 + 2))
    for byte in size:
        body.append(byte)
    for byte in child:
        body.append(byte)


def _float_word(mut body: List[UInt8], field: Int, bits: UInt32) raises:
    # Preserve negative zero and NaN payload words without floating operations.
    if bits == 0:
        return
    _bound(len(body) + 5)
    body.append(UInt8(field * 8 + 5))
    for i in range(4):
        body.append(UInt8((bits >> UInt32(i * 8)) & UInt32(255)))


def _name_bytes(name: String) raises -> List[UInt8]:
    _bound(len(name.bytes()))
    if len(name.bytes()) == 0:
        raise herror("BadConfigureRpc", "stream name must be nonempty")
    var bytes = List[UInt8]()
    for byte in name.bytes():
        bytes.append(byte)
    var i = 0
    while i < len(bytes):
        var lead = Int(bytes[i])
        if lead < 128:
            i += 1
            continue
        var tails: Int
        var value: Int
        var minimum: Int
        if lead >= 194 and lead <= 223:
            tails = 1
            value = lead & 31
            minimum = 128
        elif lead >= 224 and lead <= 239:
            tails = 2
            value = lead & 15
            minimum = 2048
        elif lead >= 240 and lead <= 244:
            tails = 3
            value = lead & 7
            minimum = 65536
        else:
            raise herror("BadConfigureRpc", "invalid UTF-8 stream name")
        if tails >= len(bytes) - i:
            raise herror("BadConfigureRpc", "truncated UTF-8 stream name")
        for j in range(1, tails + 1):
            var byte = Int(bytes[i + j])
            if byte < 128 or byte > 191:
                raise herror("BadConfigureRpc", "invalid UTF-8 continuation")
            value = (value << 6) | (byte & 63)
        if value < minimum or value > 1114111 or (value >= 55296 and value <= 57343):
            raise herror("BadConfigureRpc", "invalid UTF-8 scalar")
        i += tails + 1
    return bytes^


def _stream_body(stream: HrpcInferStream) raises -> List[UInt8]:
    var body = List[UInt8]()
    _nested(body, 1, _name_bytes(stream.name))
    _scalar(body, 2, stream.format_order)
    _scalar(body, 3, stream.format_type)
    _float_word(body, 4, stream.nms_score_bits)
    _float_word(body, 5, stream.nms_iou_bits)
    _scalar(body, 6, stream.nms_max_per_class)
    _scalar(body, 7, stream.nms_max_mask_size)
    _scalar(body, 8, stream.nms_max_total)
    return body^


def _streams(mut body: List[UInt8], field: Int, streams: List[HrpcInferStream]) raises:
    # Even empty protobuf children need two bytes. Refuse implausible lists
    # before the name checks, without introducing a model eligibility rule.
    if len(streams) > HRPC_MAX_BODY_BYTES // 2:
        raise herror("BadConfigureRpc", "stream list exceeds frame capacity")
    for i in range(len(streams)):
        for j in range(i):
            if streams[i].name == streams[j].name:
                raise herror("BadConfigureRpc", "duplicate stream name in one direction")
        _nested(body, field, _stream_body(streams[i]))


def configure_request(message_id: UInt32, params: HrpcConfigureParams) raises -> HrpcFrame:
    _valid_handle(params.infer_model)
    _valid_handle(params.vdevice)
    if params.batch_size > 65535:
        raise herror("BadConfigureRpc", "batch exceeds public UInt16 API range")
    var body = _handle_body(params.infer_model)
    var device = _handle_body(params.vdevice)
    device[0] = 18
    for byte in device:
        body.append(byte)
    _streams(body, 3, params.inputs)
    _streams(body, 4, params.outputs)
    _scalar(body, 5, params.batch_size)
    _scalar(body, 6, params.power_mode)
    _scalar(body, 7, params.latency_flags)
    _scalar(body, 8, UInt32(1) if params.enable_kv_cache else UInt32(0))
    return HrpcFrame(message_id, HRPC_PROGRAM_CONFIGURE, HRPC_REQUEST_STATUS, body^)


def configure_reply(frame: HrpcFrame, message_id: UInt32) raises -> HrpcConfigureReply:
    _check_reply(frame, message_id, HRPC_PROGRAM_CONFIGURE)
    var reader = _ProtoReader(frame.body)
    var handle = UInt32(0)
    var queue = UInt32(0)
    var seen = UInt32(0)
    while reader.more():
        var key = reader.key()
        if key[0] == 1 or key[0] == 2:
            var bit = UInt32(1) << UInt32(key[0])
            if (seen & bit) != 0:
                raise herror("BadConfigureRpc", "duplicate known configure reply field")
            seen |= bit
            if key[0] == 2:
                queue = reader.uint32(key[1])
            else:
                var nested = _ProtoReader(reader.bytes(key[1]))
                var found_id = False
                while nested.more():
                    var item = nested.key()
                    if item[0] == 1:
                        if found_id:
                            raise herror("BadConfigureRpc", "duplicate configured handle scalar")
                        found_id = True
                        handle = nested.uint32(item[1])
                    else:
                        nested.skip(item[1])
        else:
            reader.skip(key[1])
    if (seen & UInt32(2)) == 0:
        raise herror("BadConfigureRpc", "missing configured handle message")
    _valid_handle(handle)
    return HrpcConfigureReply(handle, queue)
