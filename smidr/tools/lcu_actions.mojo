# Bounded host-only original LCU control value inspector.
from std.sys import argv
from smidr.lcu_actions import LcuAction, encode_lcu_action, decode_lcu_action
from smidr.tools.hrpc_frame import _from_hex, _to_hex


def main() raises:
    var args = argv()
    var bytes: List[UInt8]
    if len(args) == 3 and args[1] == "decode":
        if args[2].byte_length() > 26:
            raise Error("LcuAction: inspected record exceeds thirteen bytes")
        bytes = _from_hex(args[2])
    elif len(args) == 9 and args[1] == "encode":
        bytes = encode_lcu_action(LcuAction(Int(args[2]), Int(args[3]), Int(args[4]), Int(args[5]),
                                          Int(args[6]), Int(args[7]), Int(args[8])))
    else:
        raise Error("usage: lcu_actions decode <hex> | encode <kind> <timestamp> <cluster> <lcu> <network> <completion-address> <completion-count>")
    var action = decode_lcu_action(bytes)
    print("{\"kind\":" + String(action.kind) + ",\"timestamp\":" + String(action.timestamp)
          + ",\"cluster\":" + String(action.cluster) + ",\"lcu\":" + String(action.lcu)
          + ",\"network\":" + String(action.network) + ",\"kernel_done_address\":" + String(action.kernel_done_address)
          + ",\"kernel_done_count\":" + String(action.kernel_done_count)
          + ",\"canonical_hex\":\"" + _to_hex(encode_lcu_action(action))
          + "\",\"device_access\":false,\"numerical_program\":false}")
