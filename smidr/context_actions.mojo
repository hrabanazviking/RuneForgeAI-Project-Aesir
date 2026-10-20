# Original byte codec for public v5.3.0 context-action interface facts.
# These bytes are not a numerical program or an established hRPC payload.
# See docs/HAILO10H_PUBLIC_CONTEXT_ACTIONS.md. No device/syscall imports.


@fieldwise_init
struct ContextAction(Copyable, Movable):
    var kind: Int
    var timestamp: Int
    var values: List[Int]


def _range(value: Int, maximum: Int) raises:
    if value < 0 or value > maximum:
        raise Error("ContextAction: field exceeds its public unsigned width")


def _size(kind: Int) raises -> Int:
    if kind == 0 or kind == 27:
        return 8
    if kind == 3:
        return 7
    if kind == 35:
        return 20
    raise Error("ContextAction: action kind is outside the verified codec subset")


def _put(mut bytes: List[UInt8], value: Int, width: Int):
    # Values are range checked before narrowing/encoding.
    for i in range(width):
        bytes.append(UInt8((UInt64(value) >> UInt64(8 * i)) & 255))


def _get(bytes: List[UInt8], offset: Int, width: Int) -> Int:
    # Complete exact action extent is checked before any field access.
    var value = UInt64(0)
    for i in range(width):
        value |= UInt64(bytes[offset + i]) << UInt64(8 * i)
    return Int(value)


def encode_context_action(action: ContextAction) raises -> List[UInt8]:
    var size = _size(action.kind)
    _range(action.timestamp, 4294967295)
    var expected = 6 if action.kind == 35 else 2 if action.kind == 27 else 3
    if len(action.values) != expected:
        raise Error("ContextAction: incorrect typed field count")
    var result = List[UInt8]()
    result.reserve(size)
    _put(result, action.kind, 1)
    _put(result, action.timestamp, 4)
    if action.kind == 0:
        # values: descriptor count, engine, channel. Widths, not physical limits.
        _range(action.values[0], 65535)
        _range(action.values[1], 3)
        _range(action.values[2], 63)
        _put(result, action.values[0], 2)
        _put(result, (action.values[1] << 6) | action.values[2], 1)
    elif action.kind == 3:
        # values: cluster, LCU, network. Packed ID bit 7 is reserved here.
        _range(action.values[0], 7)
        _range(action.values[1], 15)
        _range(action.values[2], 255)
        _put(result, (action.values[0] << 4) | action.values[1], 1)
        _put(result, action.values[2], 1)
    elif action.kind == 27:
        # values: CCW burst count, configuration stream.
        _range(action.values[0], 65535)
        _range(action.values[1], 255)
        _put(result, action.values[0], 2)
        _put(result, action.values[1], 1)
    else:
        # values: address, write type, data, shift, mask, network.
        # General=0, batch=1. A byte shift is only an interface field; no
        # register meaning or permission to write that address is inferred.
        _range(action.values[0], 4294967295)
        _range(action.values[1], 1)
        _range(action.values[2], 4294967295)
        _range(action.values[3], 255)
        _range(action.values[4], 4294967295)
        _range(action.values[5], 255)
        _put(result, action.values[0], 4)
        _put(result, action.values[1], 1)
        _put(result, action.values[2], 4)
        _put(result, action.values[3], 1)
        _put(result, action.values[4], 4)
        _put(result, action.values[5], 1)
    return result^


def decode_context_action(bytes: List[UInt8]) raises -> ContextAction:
    if len(bytes) < 5:
        raise Error("ContextAction: truncated five-byte header")
    var kind = Int(bytes[0])
    if len(bytes) != _size(kind):
        raise Error("ContextAction: action extent mismatch")
    var timestamp = _get(bytes, 1, 4)
    var values: List[Int]
    if kind == 0:
        var packed = _get(bytes, 7, 1)
        values = [_get(bytes, 5, 2), packed >> 6, packed & 63]
    elif kind == 3:
        var packed = _get(bytes, 5, 1)
        if packed & 128 != 0:
            raise Error("ContextAction: reserved LCU packed bit is set")
        values = [packed >> 4, packed & 15, _get(bytes, 6, 1)]
    elif kind == 27:
        values = [_get(bytes, 5, 2), _get(bytes, 7, 1)]
    else:
        if bytes[9] > 1:
            raise Error("ContextAction: unknown typed-write selector")
        values = [_get(bytes, 5, 4), _get(bytes, 9, 1), _get(bytes, 10, 4),
                  _get(bytes, 14, 1), _get(bytes, 15, 4), _get(bytes, 19, 1)]
    return ContextAction(kind, timestamp, values^)
