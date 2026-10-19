# Direct API boundaries not reachable through an already-validated wire tool.
from hailbru.hrpc_frame import HrpcFrame, decode_hrpc_frame, encode_hrpc_frame


def main() raises:
    var oversized = List[UInt8]()
    oversized.resize(2049, UInt8(0))
    var frame = HrpcFrame(UInt32(1), UInt32(2), UInt32(3), oversized)
    var rejected = False
    try:
        _ = encode_hrpc_frame(frame)
    except error:
        if not String(error).startswith("HailbruError[BadRpcFrame]"):
            raise error
        rejected = True
    if not rejected:
        raise Error("oversized outbound body was accepted")

    var payload = List[UInt8]()
    payload.append(42)
    var owner = HrpcFrame(UInt32(4), UInt32(5), UInt32(6), payload)
    payload[0] = 99
    if owner.body[0] != 42:
        raise Error("frame retained a borrowed input body")
    var wire = encode_hrpc_frame(owner)
    var decoded = decode_hrpc_frame(wire)
    wire[20] = 88
    if decoded.body[0] != 42 or decoded.remote_status != 6:
        raise Error("decoded body ownership or remote status was lost")
    decoded.body.append(11)
    if owner.body[0] != 42 or len(owner.body) != 1:
        raise Error("decoded mutation changed another owner")
    print("HRPC API: oversized outbound body rejected; input/output ownership and remote status preserved")
