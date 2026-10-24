# Original direct bounds, mutable-state, ownership and recovery consumer.
from hailbru.soc_group import SocUserptrSpan, SocUserptrGroup, encode_soc_group
from hailbru.soc_prepare import encode_soc_prepare, decode_soc_prepare, encode_soc_cancel_prepared, decode_soc_cancel_prepared
from hailbru.soc_abi import SOC_INVALID_HANDLE, soc_zero_bytes


def fresh() raises -> SocUserptrGroup:
    var spans = List[SocUserptrSpan]()
    spans.append(SocUserptrSpan(65536,2068))
    spans.append(SocUserptrSpan(196608,70))
    return SocUserptrGroup(3,0,spans)


def equal(a: List[UInt8], b: List[UInt8]) raises:
    if len(a)!=len(b):
        raise Error("PrepareAPI: extent differs")
    for i in range(len(a)):
        if a[i]!=b[i]:
            raise Error("PrepareAPI: bytes differ")


def recover() raises:
    var group = fresh()
    var bytes = encode_soc_prepare(group)
    var decoded = decode_soc_prepare(bytes)
    equal(bytes,encode_soc_prepare(decoded))
    equal(encode_soc_cancel_prepared(decode_soc_cancel_prepared(encode_soc_cancel_prepared(0))),encode_soc_cancel_prepared(0))


def refuse(group: SocUserptrGroup) raises:
    var accepted = False
    try:
        _ = encode_soc_prepare(group)
        accepted = True
    except:
        pass
    if accepted:
        raise Error("PrepareAPI: mutable invalid group accepted")
    recover()


def escaping() raises -> SocUserptrGroup:
    var group = fresh()
    var bytes = encode_soc_prepare(group)
    return decode_soc_prepare(bytes)


def main() raises:
    var source = fresh()
    var bytes = encode_soc_prepare(source)
    var expected = bytes.copy()
    var decoded = decode_soc_prepare(bytes)
    bytes[0] = 39
    bytes[14] ^= 1
    equal(encode_soc_prepare(decoded),expected)
    source.spans[0].size = 1
    equal(encode_soc_prepare(decoded),expected)
    var moved = decoded^
    var escape = escaping()
    equal(encode_soc_prepare(moved),expected)
    equal(encode_soc_prepare(escape),expected)
    var launch = encode_soc_group(moved)
    for i in range(139):
        if launch[i] != expected[i]:
            raise Error("PrepareAPI: launch prefix differs")
    if launch[139]!=0 or launch[140]!=0:
        raise Error("PrepareAPI: noncanonical launch tail")
    var refusals = 0
    moved.channel = 40
    refuse(moved)
    moved.channel = 3
    moved.descriptor_handle = SOC_INVALID_HANDLE
    refuse(moved)
    moved.descriptor_handle = 0
    refusals += 2
    for i in range(6):
        moved.spans.append(SocUserptrSpan(UInt64(300000+i),UInt64(i+1)))
    for i in range(8):
        var saved = moved.spans[i].copy()
        moved.spans[i].address = 0
        refuse(moved)
        moved.spans[i] = saved.copy()
        moved.spans[i].size = 0
        refuse(moved)
        moved.spans[i].size = UInt64(4294967296)
        refuse(moved)
        moved.spans[i].address = SOC_INVALID_HANDLE
        moved.spans[i].size = 1
        refuse(moved)
        moved.spans[i] = saved^
        refusals += 4
    moved.spans.append(SocUserptrSpan(1,1))
    refuse(moved)
    moved.spans.clear()
    refuse(moved)
    refusals += 2
    var replacement = fresh()
    moved.spans = replacement.spans.copy()
    equal(encode_soc_prepare(moved),expected)
    for n in range(144):
        if n != 139:
            var invalid = soc_zero_bytes(n)
            var accepted = False
            try:
                _ = decode_soc_prepare(invalid)
                accepted = True
            except:
                pass
            if accepted:
                raise Error("PrepareAPI: wrong prepare extent accepted")
            recover()
            refusals += 1
        if n != 8:
            var invalid = soc_zero_bytes(n)
            var accepted = False
            try:
                _ = decode_soc_cancel_prepared(invalid)
                accepted = True
            except:
                pass
            if accepted:
                raise Error("PrepareAPI: wrong cancel extent accepted")
            recover()
            refusals += 1
    var forbidden = List[UInt8](length=8,fill=255)
    var accepted = False
    try:
        _ = decode_soc_cancel_prepared(forbidden)
        accepted = True
    except:
        pass
    if accepted:
        raise Error("PrepareAPI: forbidden cancellation handle accepted")
    recover()
    refusals += 1
    accepted = False
    try:
        _ = encode_soc_cancel_prepared(SOC_INVALID_HANDLE)
        accepted = True
    except:
        pass
    if accepted:
        raise Error("PrepareAPI: forbidden cancellation encode accepted")
    recover()
    refusals += 1
    print("{\"ownership\":true,\"refusal_recovery_cycles\":"+String(refusals)+",\"device_access\":false}")
