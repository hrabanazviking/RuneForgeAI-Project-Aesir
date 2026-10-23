# Direct value/byte ownership and mutable-field gates; no model or device.
from smidr.sequencer_actions import SequencerAction, encode_sequencer_action, decode_sequencer_action, validate_sequencer_action


def _base() -> SequencerAction:
    return SequencerAction(1, 2309737967, 165, 113, 4660, 1432778632, 2578103244,
                           18446744073709551615, 9223372036854775808,
                           81985529216486895, 18364758544493064720)


def _set(mut action: SequencerAction, field: Int, value: UInt64):
    if field == 0:
        action.kind = value
    elif field == 1:
        action.timestamp = value
    elif field == 2:
        action.index = value
    elif field == 3:
        action.initial_l3_cut = value
    elif field == 4:
        action.initial_l3_offset = value
    elif field == 5:
        action.active_apu = value
    elif field == 6:
        action.active_ia = value
    elif field == 7:
        action.active_sc = value
    elif field == 8:
        action.active_l2 = value
    elif field == 9:
        action.l2_offset_0 = value
    elif field == 10:
        action.l2_offset_1 = value


def _equal(a: List[UInt8], b: List[UInt8]) raises:
    if len(a) != len(b):
        raise Error("sequencer owned byte count changed")
    for i in range(len(a)):
        if a[i] != b[i]:
            raise Error("sequencer owned byte content changed")


def _reject(action: SequencerAction) raises:
    var encoded = False
    try:
        _ = encode_sequencer_action(action)
        encoded = True
    except:
        pass
    if encoded:
        raise Error("invalid mutable sequencer value encoded")
    var validated = False
    try:
        validate_sequencer_action(action)
        validated = True
    except:
        pass
    if validated:
        raise Error("invalid mutable sequencer value validated")
    var fresh = _base()
    var bytes = encode_sequencer_action(fresh)
    _equal(encode_sequencer_action(decode_sequencer_action(bytes)), bytes)


def main() raises:
    var initial = _base()
    var bytes = encode_sequencer_action(initial)
    var saved = bytes.copy()
    # Change every scalar independently; a previously emitted buffer must survive.
    for field in range(11):
        _set(initial, field, 0)
        _equal(bytes, saved)
    var decoded = decode_sequencer_action(bytes)
    for i in range(len(bytes)):
        bytes[i] = 0
        _equal(encode_sequencer_action(decoded), saved)
    var copied = decoded.copy()
    for field in range(11):
        _set(decoded, field, 0)
        _equal(encode_sequencer_action(copied), saved)
    var moved = copied^
    _equal(encode_sequencer_action(moved), saved)
    var returned = encode_sequencer_action(moved)
    moved.active_sc = 0
    moved.l2_offset_1 = 0
    _equal(returned, saved)
    var refusals = 0
    for field in range(7):
        var maximum = UInt64(4294967295)
        if field == 0:
            maximum = 1
        elif field == 2 or field == 3:
            maximum = 255
        elif field == 4:
            maximum = 65535
        var bad = _base()
        _set(bad, field, maximum + 1)
        _reject(bad)
        refusals += 1
    for field in range(3, 11):
        for boundary in range(2):
            var bad = SequencerAction(17, 4294967295, 255, 0, 0, 0, 0, 0, 0, 0, 0)
            _set(bad, field, 1 if boundary == 0 else UInt64(18446744073709551615))
            _reject(bad)
            refusals += 1
    var invalid_kinds: List[Int] = [0, 2, 16, 18, 255]
    for kind in invalid_kinds:
        var bad = _base()
        bad.kind = UInt64(kind)
        _reject(bad)
        refusals += 1
    # Both framing errors must leave the API ready for a fresh success.
    for mode in range(2):
        var malformed = saved.copy()
        if mode == 0:
            _ = malformed.pop()
        else:
            malformed.append(0)
        var accepted = False
        try:
            _ = decode_sequencer_action(malformed)
            accepted = True
        except:
            pass
        if accepted:
            raise Error("invalid sequencer framing accepted")
        _equal(encode_sequencer_action(decode_sequencer_action(saved)), saved)
        refusals += 1
    if refusals != 30:
        raise Error("ownership refusal coverage changed")
    print("owned-sequencer-values-pass;30-refusal-and-fresh-success-cycles")
