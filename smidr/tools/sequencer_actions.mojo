# Bounded host wire diagnostic; never submits a configuration or opens a model.
from std.sys import argv
from smidr.sequencer_actions import SequencerAction, encode_sequencer_action, decode_sequencer_action
from smidr.tools.hrpc_frame import _from_hex, _to_hex
from smidr.tools.hrpc_program import _uint64


def _scalar(text: String) raises -> UInt64:
    if text.byte_length() > 20:
        raise Error("SequencerAction: scalar text exceeds twenty decimal digits")
    return _uint64(text)


def main() raises:
    var args = argv()
    var bytes: List[UInt8]
    if len(args) == 3 and args[1] == "decode":
        if args[2].byte_length() > 98:
            raise Error("SequencerAction: inspected record exceeds forty-nine bytes")
        bytes = _from_hex(args[2])
    elif len(args) == 13 and args[1] == "encode":
        bytes = encode_sequencer_action(SequencerAction(
            _scalar(args[2]), _scalar(args[3]), _scalar(args[4]), _scalar(args[5]),
            _scalar(args[6]), _scalar(args[7]), _scalar(args[8]), _scalar(args[9]),
            _scalar(args[10]), _scalar(args[11]), _scalar(args[12])))
    else:
        raise Error("usage: sequencer_actions decode <hex> | encode <kind> <timestamp> <index> <initial-l3-cut> <initial-l3-offset> <active-apu> <active-ia> <active-sc> <active-l2> <l2-offset-0> <l2-offset-1>")
    var action = decode_sequencer_action(bytes)
    print("{\"kind\":" + String(action.kind) + ",\"timestamp\":" + String(action.timestamp)
          + ",\"index\":" + String(action.index) + ",\"initial_l3_cut\":" + String(action.initial_l3_cut)
          + ",\"initial_l3_offset\":" + String(action.initial_l3_offset)
          + ",\"active_apu\":" + String(action.active_apu) + ",\"active_ia\":" + String(action.active_ia)
          + ",\"active_sc\":" + String(action.active_sc) + ",\"active_l2\":" + String(action.active_l2)
          + ",\"l2_offset_0\":" + String(action.l2_offset_0) + ",\"l2_offset_1\":" + String(action.l2_offset_1)
          + ",\"canonical_hex\":\"" + _to_hex(encode_sequencer_action(action))
          + "\",\"device_access\":false,\"numerical_program\":false}")
