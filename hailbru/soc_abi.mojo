# Linux LP64 little-endian interface facts from the installed 5.3.0 UAPI.
# Packed byte storage deliberately avoids native Mojo/C struct alignment.
# These codecs do not open devices, allocate DMA, establish ownership or infer.
from hailbru.errors import herror

comptime SOC_PROPERTIES_SIZE = 19
comptime SOC_DRIVER_INFO_SIZE = 12
comptime SOC_DESC_CREATE_SIZE = 27
comptime SOC_DESC_RELEASE_SIZE = 8
comptime SOC_CONNECT_SIZE = 20
comptime SOC_CLOSE_SIZE = 2
comptime SOC_CHANNEL_MASK_SIZE = 24
comptime SOC_IRQ_SIZE = 385
comptime SOC_PREPARE_SIZE = 139
comptime SOC_LAUNCH_SIZE = 141
comptime SOC_MAX_CHANNELS = 40
comptime SOC_MAX_ENGINES = 3
comptime SOC_INVALID_HANDLE = UInt64(18446744073709551615)


def _ioc(direction: UInt32, kind: UInt32, number: UInt32, size: UInt32) -> UInt32:
    # Linux asm-generic ioctl encoding used by aarch64 and x86_64.
    return (direction << UInt32(30)) | (size << UInt32(16)) | (kind << UInt32(8)) | number


def soc_ioctl(operation: String) raises -> UInt32:
    if operation == "properties":
        return _ioc(1, 103, 0, SOC_PROPERTIES_SIZE)
    if operation == "driver-info":
        return _ioc(1, 103, 1, SOC_DRIVER_INFO_SIZE)
    if operation == "desc-create":
        return _ioc(3, 118, 6, SOC_DESC_CREATE_SIZE)
    if operation == "desc-release":
        return _ioc(2, 118, 7, SOC_DESC_RELEASE_SIZE)
    if operation == "connect":
        return _ioc(3, 115, 0, SOC_CONNECT_SIZE)
    if operation == "close":
        return _ioc(2, 115, 1, SOC_CLOSE_SIZE)
    if operation == "enable-channels":
        return _ioc(2, 118, 0, SOC_CHANNEL_MASK_SIZE)
    if operation == "disable-channels":
        return _ioc(2, 118, 1, SOC_CHANNEL_MASK_SIZE)
    if operation == "interrupts":
        return _ioc(3, 118, 2, SOC_IRQ_SIZE)
    if operation == "transfer":
        return _ioc(2, 118, 12, SOC_LAUNCH_SIZE)
    if operation == "prepare-transfer":
        return _ioc(2, 118, 13, SOC_PREPARE_SIZE)
    if operation == "cancel-prepared":
        return _ioc(2, 118, 14, SOC_DESC_RELEASE_SIZE)
    raise herror("BadSocAbi", "operation is outside the admitted session interface")


def soc_zero_bytes(size: Int) raises -> List[UInt8]:
    if size < 0 or size > SOC_IRQ_SIZE:
        raise herror("BadSocAbi", "invalid ABI storage size")
    var data = List[UInt8]()
    data.reserve(size)
    for index in range(size):
        data.append(0)
    return data^


def _put(mut data: List[UInt8], offset: Int, width: Int, value: UInt64):
    for index in range(width):
        data[offset + index] = UInt8((value >> UInt64(8 * index)) & UInt64(255))


def _get(data: List[UInt8], offset: Int, width: Int) -> UInt64:
    var value = UInt64(0)
    for index in range(width):
        value |= UInt64(data[offset + index]) << UInt64(8 * index)
    return value


def _length(data: List[UInt8], expected: Int) raises:
    if len(data) != expected:
        raise herror("BadSocAbi", "packed response size does not match the ABI")


def _handle(handle: UInt64) raises:
    # Zero is not the driver's invalid-handle sentinel.
    if handle == SOC_INVALID_HANDLE:
        raise herror("BadSocAbi", "invalid descriptor handle sentinel")


def _channel(channel: UInt64) raises:
    if channel >= UInt64(SOC_MAX_CHANNELS):
        raise herror("BadSocAbi", "channel exceeds the UAPI channel count")


def soc_desc_create(count: UInt64, page_size: UInt64, circular: Bool) raises -> List[UInt8]:
    if count < 2 or count > 65536 or (count & (count - 1)) != 0:
        raise herror("BadSocAbi", "descriptor count must be a power of two in [2,65536]")
    if page_size < 64 or page_size > 32768 or (page_size & (page_size - 1)) != 0:
        raise herror("BadSocAbi", "descriptor page size must be a representable power of two >=64")
    var data = soc_zero_bytes(SOC_DESC_CREATE_SIZE)
    _put(data, 0, 8, count)
    _put(data, 8, 2, page_size)
    data[10] = UInt8(1) if circular else UInt8(0)
    return data^


def soc_desc_reply(data: List[UInt8]) raises -> Tuple[UInt64, UInt64]:
    _length(data, SOC_DESC_CREATE_SIZE)
    var handle = _get(data, 11, 8)
    _handle(handle)
    return (handle, _get(data, 19, 8))


def soc_desc_release(handle: UInt64) raises -> List[UInt8]:
    _handle(handle)
    var data = soc_zero_bytes(SOC_DESC_RELEASE_SIZE)
    _put(data, 0, 8, handle)
    return data^


def soc_connect(port: UInt64, input_handle: UInt64, output_handle: UInt64) raises -> List[UInt8]:
    _handle(input_handle)
    _handle(output_handle)
    if port == 0 or port > 65535 or input_handle == output_handle:
        raise herror("BadSocAbi", "connection requires a nonzero UInt16 port and distinct descriptor handles")
    var data = soc_zero_bytes(SOC_CONNECT_SIZE)
    _put(data, 0, 2, port)
    # Initialize output channels to the documented invalid-channel sentinel.
    data[2] = 255
    data[3] = 255
    _put(data, 4, 8, input_handle)
    _put(data, 12, 8, output_handle)
    return data^


def soc_connect_reply(data: List[UInt8]) raises -> Tuple[UInt8, UInt8]:
    _length(data, SOC_CONNECT_SIZE)
    _channel(UInt64(data[2]))
    _channel(UInt64(data[3]))
    if data[2] == data[3]:
        raise herror("BadSocAbi", "connection returned the same channel twice")
    return (data[2], data[3])


def soc_close(input_channel: UInt64, output_channel: UInt64) raises -> List[UInt8]:
    _channel(input_channel)
    _channel(output_channel)
    if input_channel == output_channel:
        raise herror("BadSocAbi", "close requires distinct assigned channels")
    var data = soc_zero_bytes(SOC_CLOSE_SIZE)
    data[0] = UInt8(input_channel)
    data[1] = UInt8(output_channel)
    return data^


def soc_channel_masks(first: UInt64, second: UInt64, third: UInt64) raises -> List[UInt8]:
    var limit = (UInt64(1) << UInt64(SOC_MAX_CHANNELS)) - 1
    if first > limit or second > limit or third > limit:
        raise herror("BadSocAbi", "channel bitmap exceeds the UAPI channel count")
    var data = soc_zero_bytes(SOC_CHANNEL_MASK_SIZE)
    _put(data, 0, 8, first)
    _put(data, 8, 8, second)
    _put(data, 16, 8, third)
    return data^


def soc_transfer(channel: UInt64, handle: UInt64, address: UInt64, size: UInt64, cyclic: Bool) raises -> List[UInt8]:
    _channel(channel)
    _handle(handle)
    if address == 0 or size == 0 or size > UInt64(4294967295):
        raise herror("BadSocAbi", "transfer requires a nonzero pointer and UInt32 size")
    # Only the single user-pointer, engine-zero subset needed by this client.
    # Allocation, DMA admissibility, lifetime and ownership belong to the session.
    var data = soc_zero_bytes(SOC_LAUNCH_SIZE)
    data[0] = UInt8(channel)
    _put(data, 1, 8, handle)
    data[9] = 1
    _put(data, 14, 8, address)
    _put(data, 22, 4, size)
    data[140] = UInt8(1) if cyclic else UInt8(0)
    return data^


def soc_properties_json(data: List[UInt8]) raises -> String:
    _length(data, SOC_PROPERTIES_SIZE)
    if data[18] > 1:
        raise herror("BadSocAbi", "invalid firmware-loaded boolean")
    return "{\"desc_max_page_size\":" + String(_get(data, 0, 2)) + ",\"board_type\":" + String(_get(data, 2, 4)) + ",\"dma_type\":" + String(_get(data, 6, 4)) + ",\"dma_engines_count\":" + String(_get(data, 10, 8)) + ",\"is_fw_loaded\":" + (String("true") if data[18] == 1 else String("false")) + "}"


def soc_driver_info_json(data: List[UInt8]) raises -> String:
    _length(data, SOC_DRIVER_INFO_SIZE)
    return "{\"major\":" + String(_get(data, 0, 4)) + ",\"minor\":" + String(_get(data, 4, 4)) + ",\"revision\":" + String(_get(data, 8, 4)) + "}"


def soc_interrupts_json(data: List[UInt8]) raises -> String:
    _length(data, SOC_IRQ_SIZE)
    var count = Int(data[24])
    if count > SOC_MAX_CHANNELS * SOC_MAX_ENGINES:
        raise herror("BadSocAbi", "interrupt count exceeds response storage")
    var seen = List[UInt64]()
    for index in range(SOC_MAX_ENGINES):
        seen.append(0)
    var result = String("[")
    for index in range(count):
        var offset = 25 + index * 3
        var engine = Int(data[offset])
        var channel = UInt64(data[offset + 1])
        if engine >= SOC_MAX_ENGINES:
            raise herror("BadSocAbi", "interrupt engine exceeds the UAPI engine count")
        _channel(channel)
        var bit = UInt64(1) << channel
        if (seen[engine] & bit) != 0:
            raise herror("BadSocAbi", "duplicate interrupt channel")
        seen[engine] |= bit
        if index != 0:
            result += ","
        # 254 means channel error; 255 means inactive, never completion counts.
        result += "{\"engine\":" + String(engine) + ",\"channel\":" + String(channel) + ",\"data\":" + String(data[offset + 2]) + "}"
    return result + "]"
