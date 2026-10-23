# Original owned grouped USERPTR value codec. No mapping or device submission.
# Public packed UAPI facts and explicit canonical profile: see pre-code contract.
from hailbru.errors import herror
from hailbru.soc_abi import (
    SOC_LAUNCH_SIZE, SOC_INVALID_HANDLE, _channel, _handle, _length,
    _put, _get, soc_zero_bytes,
)


@fieldwise_init
struct SocUserptrSpan(Copyable, Movable):
    var address: UInt64
    var size: UInt64


def _span(address: UInt64, size: UInt64) raises:
    if address == 0 or size == 0 or size > UInt64(4294967295):
        raise herror("BadSocGroup", "span requires a nonzero pointer and positive UInt32 size")
    if size > SOC_INVALID_HANDLE - address:
        raise herror("BadSocGroup", "USERPTR address plus extent overflows UInt64")


def _values(channel: UInt64, descriptor_handle: UInt64,
            spans: List[SocUserptrSpan]) raises:
    _channel(channel)
    _handle(descriptor_handle)
    if len(spans) < 1 or len(spans) > 8:
        raise herror("BadSocGroup", "group requires one through eight actual spans")
    for span in spans:
        _span(span.address, span.size)


struct SocUserptrGroup(Movable):
    var channel: UInt64
    var descriptor_handle: UInt64
    var spans: List[SocUserptrSpan]

    def __init__(out self, channel: UInt64, descriptor_handle: UInt64,
                 spans: List[SocUserptrSpan]) raises:
        _values(channel, descriptor_handle, spans)
        self.channel = channel
        self.descriptor_handle = descriptor_handle
        self.spans = spans.copy()


def encode_soc_group(group: SocUserptrGroup) raises -> List[UInt8]:
    # Recheck all public mutable values and actual count before allocation.
    _values(group.channel, group.descriptor_handle, group.spans)
    var data = soc_zero_bytes(SOC_LAUNCH_SIZE)
    data[0] = UInt8(group.channel)
    _put(data, 1, 8, group.descriptor_handle)
    data[9] = UInt8(len(group.spans))
    for i in range(len(group.spans)):
        _put(data, 14 + 16 * i, 8, group.spans[i].address)
        _put(data, 22 + 16 * i, 4, group.spans[i].size)
    # type0, unused slots, debug, engine0 and noncyclic stay canonical zero.
    return data^


def decode_soc_group(data: List[UInt8]) raises -> SocUserptrGroup:
    _length(data, SOC_LAUNCH_SIZE)
    _channel(UInt64(data[0]))
    var handle = _get(data, 1, 8)
    _handle(handle)
    var count = Int(data[9])
    if count < 1 or count > 8:
        raise herror("BadSocGroup", "packed count is outside one through eight")
    if data[138] != 0 or data[139] != 0 or data[140] != 0:
        raise herror("BadSocGroup", "expected debug false, engine zero and noncyclic profile")
    # Validate the complete object before allocating/copying decoded values.
    for i in range(count):
        if _get(data, 10 + 16 * i, 4) != 0:
            raise herror("BadSocGroup", "used span is outside USERPTR type zero")
        _span(_get(data, 14 + 16 * i, 8), _get(data, 22 + 16 * i, 4))
    for i in range(10 + 16 * count, 138):
        if data[i] != 0:
            raise herror("BadSocGroup", "unused span storage must be zero")
    var spans = List[SocUserptrSpan]()
    spans.reserve(count)
    for i in range(count):
        spans.append(SocUserptrSpan(_get(data, 14 + 16 * i, 8), _get(data, 22 + 16 * i, 4)))
    return SocUserptrGroup(UInt64(data[0]), handle, spans)
