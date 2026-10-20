# Native host codec diagnostic. Frames are printed, never submitted.
from std.sys import argv
from hailbru.errors import herror
from hailbru.hrpc_frame import encode_hrpc_frame, decode_hrpc_frame
from hailbru.hrpc_configure import HrpcInferStream, HrpcConfigureParams, plain_infer_stream, configure_request, configure_reply
from smidr.tools.hrpc_device import _uint32
from smidr.tools.hrpc_frame import _from_hex, _to_hex


def _bool(text: String) raises -> Bool:
    if text != "0" and text != "1":
        raise herror("BadArgs", "boolean must be 0 or 1")
    return text == "1"


def _packet(data: List[UInt8]) -> String:
    return "{\"packet_hex\":\"" + _to_hex(data) + "\",\"device_access\":false,\"configured_on_device\":false,\"execution_tested\":false}"


def main() raises:
    var args = argv()
    if len(args) < 3:
        raise herror("BadArgs", "usage: hrpc_configure mode message_id [arguments]")
    var mode = args[1]
    var message_id = _uint32(args[2])
    if mode == "reply" and len(args) == 4:
        var reply = configure_reply(decode_hrpc_frame(_from_hex(args[3])), message_id)
        print("{\"handle\":" + String(reply.handle) + ",\"async_queue_size\":" + String(reply.async_queue_size) + ",\"device_access\":false,\"configured_on_device\":false,\"execution_tested\":false}")
    elif mode == "request" and len(args) >= 9 and (len(args) - 9) % 9 == 0:
        var inputs = List[HrpcInferStream]()
        var outputs = List[HrpcInferStream]()
        for i in range(9, len(args), 9):
            var stream = HrpcInferStream(args[i + 1], _uint32(args[i + 2]), _uint32(args[i + 3]), _uint32(args[i + 4]), _uint32(args[i + 5]), _uint32(args[i + 6]), _uint32(args[i + 7]), _uint32(args[i + 8]))
            if args[i] == "i":
                inputs.append(stream^)
            elif args[i] == "o":
                outputs.append(stream^)
            else:
                raise herror("BadArgs", "stream direction must be i or o")
        var params = HrpcConfigureParams(_uint32(args[3]), _uint32(args[4]), inputs^, outputs^, _uint32(args[5]), _uint32(args[6]), _uint32(args[7]), _bool(args[8]))
        print(_packet(encode_hrpc_frame(configure_request(message_id, params))))
    elif mode == "plain" and len(args) == 13:
        var inputs = List[HrpcInferStream]()
        var outputs = List[HrpcInferStream]()
        inputs.append(plain_infer_stream(args[9], _uint32(args[11]), _uint32(args[12])))
        outputs.append(plain_infer_stream(args[10], _uint32(args[11]), _uint32(args[12])))
        var params = HrpcConfigureParams(_uint32(args[3]), _uint32(args[4]), inputs^, outputs^, _uint32(args[5]), _uint32(args[6]), _uint32(args[7]), _bool(args[8]))
        print(_packet(encode_hrpc_frame(configure_request(message_id, params))))
    elif mode == "ownership" and len(args) == 3:
        var inputs = List[HrpcInferStream]()
        inputs.append(plain_infer_stream("a\x00b", 5, 3))
        var params = HrpcConfigureParams(0, 1, inputs^, List[HrpcInferStream](), 0, 0, 1, True)
        var first = configure_request(message_id, params)
        var saved = first.body.copy()
        var other = configure_request(message_id, params)
        params.inputs[0].name = String("changed")
        first.body[0] ^= 255
        if len(other.body) != len(saved):
            raise herror("BadConfigureRpc", "returned frame size aliases another owner")
        for i in range(len(saved)):
            if other.body[i] != saved[i]:
                raise herror("BadConfigureRpc", "returned frame bytes alias another owner")
        print(_packet(encode_hrpc_frame(other)))
    elif (mode == "bad-utf8" and len(args) == 3) or (mode == "raw-name" and len(args) == 4):
        var bad = List[Int8]()
        if mode == "raw-name":
            var bytes = _from_hex(args[3])
            for byte in bytes:
                bad.append(Int8(byte))
        else:
            bad.append(-64)
            bad.append(-81)
        bad.append(0)
        var name = String(unsafe_from_utf8_ptr=bad.unsafe_ptr())
        var inputs = List[HrpcInferStream]()
        inputs.append(plain_infer_stream(name, 0, 0))
        var params = HrpcConfigureParams(0, 0, inputs^, List[HrpcInferStream](), 0, 0, 0, False)
        print(_packet(encode_hrpc_frame(configure_request(message_id, params))))
    elif mode == "many" and len(args) == 3:
        var inputs = List[HrpcInferStream]()
        for i in range(1025):
            inputs.append(plain_infer_stream(String(i), 0, 0))
        var params = HrpcConfigureParams(0, 0, inputs^, List[HrpcInferStream](), 0, 0, 0, False)
        print(_packet(encode_hrpc_frame(configure_request(message_id, params))))
    else:
        raise herror("BadArgs", "invalid configure mode or arguments")
