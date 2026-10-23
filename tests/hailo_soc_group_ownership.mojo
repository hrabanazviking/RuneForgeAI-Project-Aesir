# Direct mutation, ownership and recovery checks; addresses are scalars only.
from hailbru.soc_group import SocUserptrSpan, SocUserptrGroup, encode_soc_group, decode_soc_group
from hailbru.soc_abi import SOC_INVALID_HANDLE, soc_zero_bytes


def _fresh() raises -> SocUserptrGroup:
    var spans = List[SocUserptrSpan]()
    spans.append(SocUserptrSpan(65536, 2068))
    spans.append(SocUserptrSpan(196608, 70))
    return SocUserptrGroup(3, 0, spans)


def _equal(a: List[UInt8], b: List[UInt8]) raises:
    if len(a) != len(b):
        raise Error("group extent changed")
    for i in range(len(a)):
        if a[i] != b[i]:
            raise Error("group bytes changed")


def _refuse(group: SocUserptrGroup) raises:
    var accepted = False
    try:
        _ = encode_soc_group(group)
        accepted = True
    except:
        pass
    if accepted:
        raise Error("invalid mutable group accepted")
    var fresh = _fresh()
    var bytes = encode_soc_group(fresh)
    var decoded = decode_soc_group(bytes)
    _equal(bytes, encode_soc_group(decoded))


def _escaping() raises -> List[UInt8]:
    var group = _fresh()
    return encode_soc_group(group)


def main() raises:
    var spans = List[SocUserptrSpan]()
    spans.append(SocUserptrSpan(65536, 2068))
    spans.append(SocUserptrSpan(196608, 70))
    var group = SocUserptrGroup(3, 0, spans)
    var expected = encode_soc_group(group)
    spans[0].address = 0
    spans[1].size = 0
    spans.clear()
    _equal(encode_soc_group(group), expected)
    var copy = SocUserptrGroup(group.channel, group.descriptor_handle, group.spans)
    group.spans[0].size = 1
    _equal(encode_soc_group(copy), expected)
    var moved = copy^
    _equal(encode_soc_group(moved), expected)
    var returned = _escaping()
    _equal(returned, expected)
    var decoded = decode_soc_group(returned)
    returned[0] = 39
    returned[14] ^= 1
    _equal(encode_soc_group(decoded), expected)
    decoded.spans[0].address += 1
    _equal(encode_soc_group(moved), expected)
    var bytes = encode_soc_group(moved)
    bytes[0] = 0
    _equal(encode_soc_group(moved), expected)
    var refusals = 0
    moved.channel = 40
    _refuse(moved)
    moved.channel = 3
    moved.descriptor_handle = SOC_INVALID_HANDLE
    _refuse(moved)
    moved.descriptor_handle = 0
    refusals += 2
    # All actual slots are mutable and guarded after construction.
    for i in range(6):
        moved.spans.append(SocUserptrSpan(UInt64(300000 + i), UInt64(i + 1)))
    for i in range(8):
        var saved = moved.spans[i].copy()
        moved.spans[i].address = 0
        _refuse(moved)
        moved.spans[i] = saved.copy()
        moved.spans[i].size = 0
        _refuse(moved)
        moved.spans[i].size = UInt64(4294967296)
        _refuse(moved)
        moved.spans[i].address = SOC_INVALID_HANDLE
        moved.spans[i].size = 1
        _refuse(moved)
        moved.spans[i] = saved^
        refusals += 4
    moved.spans.append(SocUserptrSpan(1, 1))
    _refuse(moved)
    moved.spans.clear()
    _refuse(moved)
    refusals += 2
    var replacement = _fresh()
    moved.spans = replacement.spans.copy()
    _equal(encode_soc_group(moved), expected)
    # Direct API length checks, independent of the diagnostic's input bound.
    for extent in range(142):
        if extent == 141:
            continue
        var data = soc_zero_bytes(extent)
        var accepted = False
        try:
            _ = decode_soc_group(data)
            accepted = True
        except:
            pass
        if accepted:
            raise Error("invalid API byte extent accepted")
        var fresh = _fresh()
        _equal(encode_soc_group(fresh), expected)
        refusals += 1
    print("{\"ownership\":true,\"refusal_recovery_cycles\":" + String(refusals) + "}")
