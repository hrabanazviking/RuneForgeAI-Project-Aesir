# Host-only inspector for independently constructed public action bytes.
from std.sys import argv
from smidr.context_actions import ContextAction, encode_context_action, decode_context_action
from smidr.tools.hrpc_frame import _from_hex, _to_hex
from smidr.tools.semantic_plan import _integers


def main() raises:
    var args = argv()
    var bytes: List[UInt8]
    if len(args) == 3 and args[1] == "decode":
        if args[2].byte_length() > 40:
            raise Error("ContextAction: inspected action exceeds the bounded subset")
        bytes = _from_hex(args[2])
    elif len(args) >= 4 and len(args) <= 10 and args[1] == "encode":
        var values = List[Int]()
        for i in range(4, len(args)):
            values.append(Int(args[i]))
        bytes = encode_context_action(ContextAction(Int(args[2]), Int(args[3]), values^))
    else:
        raise Error("usage: context_actions decode <hex> | encode <kind> <timestamp> <typed-fields...>")
    var action = decode_context_action(bytes)
    print("{\"kind\":" + String(action.kind) + ",\"timestamp\":" + String(action.timestamp)
          + ",\"values\":" + _integers(action.values) + ",\"canonical_hex\":\"" + _to_hex(encode_context_action(action))
          + "\",\"device_access\":false,\"numerical_program\":false}")
