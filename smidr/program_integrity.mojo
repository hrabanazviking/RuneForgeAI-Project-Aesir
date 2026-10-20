# Original implementation from published algorithm facts, not external code.
# See HAILO10H_PROGRAM_INTEGRITY_FACTS.md for pinned specification/attribution.
# Host byte integrity only; never evaluates a model or submits a program.
from hailbru.errors import herror
from smidr.program_header import (
    decode_program_header, layout_program_sections,
)

comptime _P1 = UInt64(0x9e3779b185ebca87)
comptime _P2 = UInt64(0xc2b2ae3d27d4eb4f)
comptime _P3 = UInt64(0x165667b19e3779f9)
comptime _P4 = UInt64(0x85ebca77c2b2ae63)
comptime _P5 = UInt64(0x27d4eb2f165667c5)
comptime _M1 = UInt64(0x165667919e3779f9)
comptime _M2 = UInt64(0x9fb21c651e98df25)


def _default_secret() -> List[UInt64]:
    # Published 192-byte algorithm constant, represented as little endian words.
    var words = List[UInt64]()
    words.reserve(24)
    words.append(UInt64(0xbe4ba423396cfeb8))
    words.append(UInt64(0x1cad21f72c81017c))
    words.append(UInt64(0xdb979083e96dd4de))
    words.append(UInt64(0x1f67b3b7a4a44072))
    words.append(UInt64(0x78e5c0cc4ee679cb))
    words.append(UInt64(0x2172ffcc7dd05a82))
    words.append(UInt64(0x8e2443f7744608b8))
    words.append(UInt64(0x4c263a81e69035e0))
    words.append(UInt64(0xcb00c391bb52283c))
    words.append(UInt64(0xa32e531b8b65d088))
    words.append(UInt64(0x4ef90da297486471))
    words.append(UInt64(0xd8acdea946ef1938))
    words.append(UInt64(0x3f349ce33f76faa8))
    words.append(UInt64(0x1d4f0bc7c7bbdcf9))
    words.append(UInt64(0x3159b4cd4be0518a))
    words.append(UInt64(0x647378d9c97e9fc8))
    words.append(UInt64(0xc3ebd33483acc5ea))
    words.append(UInt64(0xeb6313faffa081c5))
    words.append(UInt64(0x49daf0b751dd0d17))
    words.append(UInt64(0x9e68d429265516d3))
    words.append(UInt64(0xfca1477d58be162b))
    words.append(UInt64(0xce31d07ad1b8f88f))
    words.append(UInt64(0x280416958f3acb45))
    words.append(UInt64(0x7e404bbbcafbd7af))
    return words^


def _secret(words: List[UInt64], offset: Int, width: Int = 8) -> UInt64:
    var index = offset // 8
    var shift = (offset % 8) * 8
    var value = words[index] >> UInt64(shift)
    if shift + width * 8 > 64:
        value |= words[index + 1] << UInt64(64 - shift)
    if width == 4:
        value &= UInt64(0xffffffff)
    return value


def _little(data: List[UInt8], offset: Int, width: Int = 8) -> UInt64:
    var value = UInt64(0)
    for i in range(width):
        value |= UInt64(data[offset + i]) << UInt64(i * 8)
    return value


def _rotate(value: UInt64, shift: Int) -> UInt64:
    return (value << UInt64(shift)) | (value >> UInt64(64 - shift))


def _reverse(value: UInt64) -> UInt64:
    var result = UInt64(0)
    for i in range(8):
        result = (result << UInt64(8)) | ((value >> UInt64(i * 8)) & UInt64(255))
    return result


def _fold_product(a: UInt64, b: UInt64) -> UInt64:
    # Independent limb arithmetic: retain the complete unsigned 128-bit product.
    var mask = UInt64(0xffffffff)
    var bottom = (a & mask) * (b & mask)
    var cross_a = (a >> UInt64(32)) * (b & mask)
    var cross_b = (a & mask) * (b >> UInt64(32))
    var middle = (bottom >> UInt64(32)) + (cross_a & mask) + (cross_b & mask)
    var low = (bottom & mask) | (middle << UInt64(32))
    var high = (a >> UInt64(32)) * (b >> UInt64(32)) + (cross_a >> UInt64(32)) + (cross_b >> UInt64(32)) + (middle >> UInt64(32))
    return low ^ high


def _finish(value: UInt64) -> UInt64:
    var mixed = (value ^ (value >> UInt64(37))) * _M1
    return mixed ^ (mixed >> UInt64(32))


def _finish_small(value: UInt64) -> UInt64:
    var mixed = (value ^ (value >> UInt64(33))) * _P2
    mixed = (mixed ^ (mixed >> UInt64(29))) * _P3
    return mixed ^ (mixed >> UInt64(32))


def _chunk(data: List[UInt8], offset: Int,
           secret: List[UInt64], secret_offset: Int) -> UInt64:
    return _fold_product(_little(data, offset) ^ _secret(secret, secret_offset),
                         _little(data, offset + 8) ^ _secret(secret, secret_offset + 8))


def _stripe(mut accum: List[UInt64], data: List[UInt8], offset: Int,
            secret: List[UInt64], secret_offset: Int):
    for lane in range(8):
        var raw = _little(data, offset + lane * 8)
        var keyed = raw ^ _secret(secret, secret_offset + lane * 8)
        accum[lane ^ 1] += raw
        accum[lane] += (keyed & UInt64(0xffffffff)) * (keyed >> UInt64(32))


def _hash_short(data: List[UInt8], offset: Int, count: Int,
                secret: List[UInt64]) -> UInt64:
    if count == 0:
        return _finish_small(_secret(secret, 56) ^ _secret(secret, 64))
    if count <= 3:
        var combined = UInt64(data[offset + count - 1]) | (UInt64(count) << UInt64(8)) | (UInt64(data[offset]) << UInt64(16)) | (UInt64(data[offset + count // 2]) << UInt64(24))
        return _finish_small(combined ^ _secret(secret, 0, 4) ^ _secret(secret, 4, 4))
    if count <= 8:
        var combined = _little(data, offset + count - 4, 4) | (_little(data, offset, 4) << UInt64(32))
        var mixed = combined ^ _secret(secret, 8) ^ _secret(secret, 16)
        mixed = (mixed ^ _rotate(mixed, 49) ^ _rotate(mixed, 24)) * _M2
        mixed = (mixed ^ ((mixed >> UInt64(35)) + UInt64(count))) * _M2
        return mixed ^ (mixed >> UInt64(28))
    var first = _little(data, offset) ^ _secret(secret, 24) ^ _secret(secret, 32)
    var last = _little(data, offset + count - 8) ^ _secret(secret, 40) ^ _secret(secret, 48)
    return _finish(UInt64(count) + _reverse(first) + last + _fold_product(first, last))


def _hash_medium(data: List[UInt8], offset: Int, count: Int,
                 secret: List[UInt64]) -> UInt64:
    var total = UInt64(count) * _P1
    if count <= 128:
        var pairs = (count - 1) // 32 + 1
        for i in range(pairs):
            total += _chunk(data, offset + i * 16, secret, i * 32)
            total += _chunk(data, offset + count - (i + 1) * 16, secret, i * 32 + 16)
        return _finish(total)
    for i in range(8):
        total += _chunk(data, offset + i * 16, secret, i * 16)
    total = _finish(total)
    for i in range(8, count // 16):
        total += _chunk(data, offset + i * 16, secret, (i - 8) * 16 + 3)
    total += _chunk(data, offset + count - 16, secret, 119)
    return _finish(total)


def _hash_long(data: List[UInt8], offset: Int, count: Int,
               secret: List[UInt64]) -> UInt64:
    var total = UInt64(count) * _P1
    var accum = List[UInt64]()
    for _ in range(8):
        accum.append(0)
    accum[0] = 0xc2b2ae3d
    accum[1] = _P1
    accum[2] = _P2
    accum[3] = _P3
    accum[4] = _P4
    accum[5] = 0x85ebca77
    accum[6] = _P5
    accum[7] = 0x9e3779b1
    var consumed = 0
    while count - consumed > 1024:
        for i in range(16):
            _stripe(accum, data, offset + consumed + i * 64, secret, i * 8)
        for lane in range(8):
            accum[lane] = (accum[lane] ^ (accum[lane] >> UInt64(47)) ^ _secret(secret, 128 + lane * 8)) * UInt64(0x9e3779b1)
        consumed += 1024
    for i in range((count - consumed - 1) // 64):
        _stripe(accum, data, offset + consumed + i * 64, secret, i * 8)
    _stripe(accum, data, offset + count - 64, secret, 121)
    for pair in range(4):
        total += _fold_product(accum[pair * 2] ^ _secret(secret, 11 + pair * 16),
                               accum[pair * 2 + 1] ^ _secret(secret, 19 + pair * 16))
    return _finish(total)



def xxh3_64_window(data: List[UInt8], offset: Int, count: Int,
                   work_bound: Int) raises -> UInt64:
    """Default unseeded XXH3-64 over a checked borrowed window; fixed hash state."""
    if offset < 0 or count < 0 or offset > len(data) or count > len(data) - offset:
        raise herror("BadProgramIntegrity", "hash window outside owned input")
    if work_bound <= 0 or count > work_bound:
        raise herror("BadProgramIntegrity", "explicit positive hash work bound exceeded")
    var secret = _default_secret()
    if count <= 16:
        return _hash_short(data, offset, count, secret)
    if count <= 240:
        return _hash_medium(data, offset, count, secret)
    return _hash_long(data, offset, count, secret)


@fieldwise_init
struct ProgramIntegrityResult(ImplicitlyCopyable, Movable):
    var protobuf_only: Bool
    var offset: Int
    var count: Int
    var checksum: UInt64


def validate_program_integrity(data: List[UInt8], host_buffer_limit: UInt64) raises -> ProgramIntegrityResult:
    """Validate exact v3 extents and the header-selected outer checksum domain."""
    if len(data) < 56 or host_buffer_limit == 0 or UInt64(len(data)) > host_buffer_limit:
        raise herror("BadProgramIntegrity", "header truncated or explicit host buffer bound exceeded")
    var header_bytes = List[UInt8]()
    header_bytes.reserve(56)
    for i in range(56):
        header_bytes.append(data[i])
    var header = decode_program_header(header_bytes)
    var layout = layout_program_sections(header, host_buffer_limit, UInt64(len(data)))
    var proto_only = header.protobuf_hash != 0
    var count = len(data) - 56
    var expected = header.residue_hash
    if proto_only:
        count = Int(layout.protobuf_bytes)
        expected = header.protobuf_hash
    var checksum = xxh3_64_window(data, 56, count, len(data))
    if checksum != expected:
        raise herror("BadProgramIntegrity", "selected outer checksum mismatch")
    return ProgramIntegrityResult(proto_only, 56, count, checksum)
