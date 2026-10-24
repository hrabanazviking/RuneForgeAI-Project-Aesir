# Original prepare/cancel value codecs. No driver, mapping or submission.
from hailbru.soc_group import SocUserptrGroup, encode_soc_group, decode_soc_group
from hailbru.soc_abi import (
    SOC_PREPARE_SIZE, SOC_LAUNCH_SIZE, SOC_DESC_RELEASE_SIZE,
    soc_zero_bytes, soc_desc_release, _length, _get, _handle,
)


def encode_soc_prepare(group: SocUserptrGroup) raises -> List[UInt8]:
    # The existing sole group encoder revalidates every mutable input field.
    var launch = encode_soc_group(group)
    var result = List[UInt8]()
    result.reserve(SOC_PREPARE_SIZE)
    for i in range(SOC_PREPARE_SIZE):
        result.append(launch[i])
    return result^


def decode_soc_prepare(data: List[UInt8]) raises -> SocUserptrGroup:
    _length(data, SOC_PREPARE_SIZE)
    var launch = soc_zero_bytes(SOC_LAUNCH_SIZE)
    for i in range(SOC_PREPARE_SIZE):
        launch[i] = data[i]
    # Only engine0/cyclicfalse are appended. All original slot/debug guards run.
    return decode_soc_group(launch)


def encode_soc_cancel_prepared(handle: UInt64) raises -> List[UInt8]:
    # Same checked scalar object width; cancellation remains a distinct operation.
    return soc_desc_release(handle)


def decode_soc_cancel_prepared(data: List[UInt8]) raises -> UInt64:
    _length(data, SOC_DESC_RELEASE_SIZE)
    var handle = _get(data, 0, SOC_DESC_RELEASE_SIZE)
    _handle(handle)
    return handle
