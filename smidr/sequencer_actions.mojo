# Original codec for two public packed context records. Wire intent only:
# no numerical instruction, resource placement, safe address or device access.


@fieldwise_init
struct SequencerAction(Copyable, Movable):
    var kind: UInt64
    var timestamp: UInt64
    var index: UInt64
    var initial_l3_cut: UInt64
    var initial_l3_offset: UInt64
    var active_apu: UInt64
    var active_ia: UInt64
    var active_sc: UInt64
    var active_l2: UInt64
    var l2_offset_0: UInt64
    var l2_offset_1: UInt64


def _extent(kind: UInt64) raises -> Int:
    if kind == 1:
        return 49
    if kind == 17:
        return 6
    raise Error("SequencerAction: kind is outside the qualified control subset")


def validate_sequencer_action(action: SequencerAction) raises:
    _ = _extent(action.kind)
    if action.timestamp > 4294967295 or action.index > 255:
        raise Error("SequencerAction: timestamp or index exceeds its public unsigned width")
    if action.initial_l3_cut > 255 or action.initial_l3_offset > 65535:
        raise Error("SequencerAction: initial L3 field exceeds its public unsigned width")
    if action.active_apu > 4294967295 or action.active_ia > 4294967295:
        raise Error("SequencerAction: activity field exceeds its public unsigned width")
    if action.kind == 17:
        if (action.initial_l3_cut != 0 or action.initial_l3_offset != 0
                or action.active_apu != 0 or action.active_ia != 0
                or action.active_sc != 0 or action.active_l2 != 0
                or action.l2_offset_0 != 0 or action.l2_offset_1 != 0):
            raise Error("SequencerAction: completion has nonzero absent configuration fields")


def _put(mut output: List[UInt8], value: UInt64, width: Int):
    for i in range(width):
        output.append(UInt8((value >> UInt64(8 * i)) & 255))


def _get(bytes: List[UInt8], offset: Int, width: Int) -> UInt64:
    var value = UInt64(0)
    for i in range(width):
        value |= UInt64(bytes[offset + i]) << UInt64(8 * i)
    return value


def encode_sequencer_action(action: SequencerAction) raises -> List[UInt8]:
    validate_sequencer_action(action)
    var output = List[UInt8]()
    output.reserve(_extent(action.kind))
    _put(output, action.kind, 1)
    _put(output, action.timestamp, 4)
    _put(output, action.index, 1)
    if action.kind == 1:
        _put(output, action.initial_l3_cut, 1)
        _put(output, action.initial_l3_offset, 2)
        _put(output, action.active_apu, 4)
        _put(output, action.active_ia, 4)
        _put(output, action.active_sc, 8)
        _put(output, action.active_l2, 8)
        _put(output, action.l2_offset_0, 8)
        _put(output, action.l2_offset_1, 8)
    return output^


def decode_sequencer_action(bytes: List[UInt8]) raises -> SequencerAction:
    if len(bytes) < 5:
        raise Error("SequencerAction: truncated common header")
    var kind = UInt64(bytes[0])
    if len(bytes) != _extent(kind):
        raise Error("SequencerAction: record extent mismatch")
    var action = SequencerAction(kind, _get(bytes, 1, 4), UInt64(bytes[5]),
                                 0, 0, 0, 0, 0, 0, 0, 0)
    if kind == 1:
        action.initial_l3_cut = UInt64(bytes[6])
        action.initial_l3_offset = _get(bytes, 7, 2)
        action.active_apu = _get(bytes, 9, 4)
        action.active_ia = _get(bytes, 13, 4)
        action.active_sc = _get(bytes, 17, 8)
        action.active_l2 = _get(bytes, 25, 8)
        action.l2_offset_0 = _get(bytes, 33, 8)
        action.l2_offset_1 = _get(bytes, 41, 8)
    validate_sequencer_action(action)
    return action^
