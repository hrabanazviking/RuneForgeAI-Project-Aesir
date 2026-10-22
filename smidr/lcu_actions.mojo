# Original scalar/value codec for three pinned public context control records.
# Wire intent only: no LCU instruction, physical address validity or device access.


@fieldwise_init
struct LcuAction(Copyable, Movable):
    var kind: Int
    var timestamp: Int
    var cluster: Int
    var lcu: Int
    var network: Int
    var kernel_done_address: Int
    var kernel_done_count: Int


def _unsigned(value: Int, maximum: Int) raises:
    if value < 0 or value > maximum:
        raise Error("LcuAction: field exceeds its public unsigned width")


def _extent(kind: Int) raises -> Int:
    if kind == 4:
        return 13
    if kind == 5:
        return 6
    if kind == 36:
        return 11
    raise Error("LcuAction: kind is outside the qualified control subset")


def validate_lcu_action(action: LcuAction) raises:
    _ = _extent(action.kind)
    _unsigned(action.timestamp, 4294967295)
    _unsigned(action.cluster, 7)
    _unsigned(action.lcu, 15)
    _unsigned(action.network, 255)
    _unsigned(action.kernel_done_address, 65535)
    _unsigned(action.kernel_done_count, 4294967295)
    if action.kind == 5:
        if action.network != 0 or action.kernel_done_address != 0 or action.kernel_done_count != 0:
            raise Error("LcuAction: disable has nonzero absent fields")
    elif action.kind == 36 and action.kernel_done_address != 0:
        raise Error("LcuAction: batch switch has a nonzero absent address")


def _append(mut result: List[UInt8], value: Int, width: Int):
    for i in range(width):
        result.append(UInt8((UInt64(value) >> UInt64(8 * i)) & 255))


def _read(bytes: List[UInt8], offset: Int, width: Int) -> Int:
    var value = UInt64(0)
    for i in range(width):
        value |= UInt64(bytes[offset + i]) << UInt64(8 * i)
    return Int(value)


def encode_lcu_action(action: LcuAction) raises -> List[UInt8]:
    validate_lcu_action(action)
    var result = List[UInt8]()
    result.reserve(_extent(action.kind))
    _append(result, action.kind, 1)
    _append(result, action.timestamp, 4)
    _append(result, (action.cluster << 4) | action.lcu, 1)
    if action.kind != 5:
        _append(result, action.network, 1)
        if action.kind == 4:
            _append(result, action.kernel_done_address, 2)
        _append(result, action.kernel_done_count, 4)
    return result^


def decode_lcu_action(bytes: List[UInt8]) raises -> LcuAction:
    if len(bytes) < 5:
        raise Error("LcuAction: truncated common header")
    var kind = Int(bytes[0])
    if len(bytes) != _extent(kind):
        raise Error("LcuAction: record extent mismatch")
    var packed = Int(bytes[5])
    if (packed & 128) != 0:
        raise Error("LcuAction: reserved packed LCU bit is set")
    var network = 0
    var address = 0
    var count = 0
    if kind != 5:
        network = Int(bytes[6])
        if kind == 4:
            address = _read(bytes, 7, 2)
            count = _read(bytes, 9, 4)
        else:
            count = _read(bytes, 7, 4)
    var action = LcuAction(kind, _read(bytes, 1, 4), packed >> 4, packed & 15, network, address, count)
    validate_lcu_action(action)
    return action^
