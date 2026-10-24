# Single outstanding request/reply pair. Host accounting, not hardware proof.
from hailbru.errors import herror
from hailbru.soc_abi import soc_interrupts_json, _get, SOC_INVALID_HANDLE


def rpc_descriptor_count(address: UInt64, page_size: UInt64, capacity: UInt64) raises -> Int64:
    if page_size < 64 or page_size > 32768 or (page_size & (page_size - 1)) != 0:
        raise herror("SocTransferBounds", "invalid descriptor page size")
    if address == 0 or address % page_size != 0 or address > SOC_INVALID_HANDLE - 2068:
        raise herror("SocTransferBounds", "RPC storage is not descriptor-page aligned")
    var count = (UInt64(2068) + page_size - 1) // page_size
    if capacity < 2 or capacity > 65536 or (capacity & (capacity - 1)) != 0 or count >= capacity:
        raise herror("SocTransferBounds", "RPC extent exceeds the usable descriptor ring")
    return Int64(count)


struct SocRpcProgress:
    var input_channel: UInt8
    var output_channel: UInt8
    var expected_descriptors: Int64
    var input_capacity: UInt64
    var output_capacity: UInt64
    var input_descriptors: Int64
    var output_descriptors: Int64
    var input_submitted: Bool
    var output_submitted: Bool
    var input_done: Bool
    var output_done: Bool

    def __init__(out self, input_channel: UInt8, output_channel: UInt8, expected_descriptors: Int64) raises:
        if input_channel >= 16 or output_channel < 16 or output_channel >= 32 or expected_descriptors < 1 or expected_descriptors >= 65536:
            raise herror("SocTransferBounds", "invalid owned channels or descriptor count")
        self.input_channel = input_channel
        self.output_channel = output_channel
        self.expected_descriptors = expected_descriptors
        self.input_capacity = 0
        self.output_capacity = 0
        self.input_descriptors = 0
        self.output_descriptors = 0
        self.input_submitted = False
        self.output_submitted = False
        self.input_done = False
        self.output_done = False

    def __init__(out self, input_channel: UInt8, output_channel: UInt8,
                 input_capacity: UInt64, output_capacity: UInt64) raises:
        if input_channel >= 16 or output_channel < 16 or output_channel >= 32:
            raise herror("SocTransferBounds", "invalid owned directional channels")
        for index in range(2):
            var capacity = input_capacity if index == 0 else output_capacity
            if capacity < 2 or capacity > 65536 or (capacity & (capacity - 1)) != 0:
                raise herror("SocTransferBounds", "invalid allocated descriptor ring capacity")
        self.input_channel = input_channel
        self.output_channel = output_channel
        # Zero selects observed-return policy. It is never a launch count.
        self.expected_descriptors = 0
        self.input_capacity = input_capacity
        self.output_capacity = output_capacity
        self.input_descriptors = 0
        self.output_descriptors = 0
        self.input_submitted = False
        self.output_submitted = False
        self.input_done = False
        self.output_done = False

    def launched(mut self, channel: UInt8, descriptors: Int64) raises:
        if self.expected_descriptors != 0:
            if descriptors != self.expected_descriptors:
                raise herror("SocTransferCount", "launch count differs from the exact owned RPC extent")
        else:
            var capacity = self.input_capacity if channel == self.input_channel else self.output_capacity
            if descriptors < 1 or UInt64(descriptors) >= capacity:
                raise herror("SocTransferCount", "returned launch count is outside the allocated ring bound")
        if channel == self.output_channel and not self.output_submitted:
            self.output_submitted = True
            self.output_descriptors = descriptors
        elif channel == self.input_channel and self.output_submitted and not self.input_submitted:
            self.input_submitted = True
            self.input_descriptors = descriptors
        else:
            raise herror("SocTransferState", "launch is duplicate, unowned or precedes D2H posting")

    def consume(mut self, data: List[UInt8]) raises:
        _ = soc_interrupts_json(data)
        var mask = (UInt64(1) << UInt64(self.input_channel)) | (UInt64(1) << UInt64(self.output_channel))
        if _get(data, 0, 8) != mask or _get(data, 8, 8) != 0 or _get(data, 16, 8) != 0:
            raise herror("SocTransferState", "IRQ request mask is not this owned exchange")
        var input_done = self.input_done
        var output_done = self.output_done
        for index in range(Int(data[24])):
            var offset = 25 + 3 * index
            var channel = data[offset + 1]
            var count = data[offset + 2]
            if data[offset] != 0 or (channel != self.input_channel and channel != self.output_channel):
                raise herror("SocTransferState", "IRQ belongs to an unowned engine/channel")
            if count == 254 or count == 255:
                raise herror("SocTransferFailed", "IRQ reports channel error or inactive state")
            if count > 1:
                raise herror("SocTransferCount", "IRQ completion count exceeds one outstanding transfer")
            if channel == self.input_channel:
                if not self.input_submitted or (count == 1 and input_done):
                    raise herror("SocTransferState", "input completion is duplicate or was never submitted")
                input_done |= count == 1
            else:
                if not self.output_submitted or (count == 1 and output_done):
                    raise herror("SocTransferState", "output completion is duplicate or was never submitted")
                output_done |= count == 1
        # Validate the complete snapshot before committing any progress.
        self.input_done = input_done
        self.output_done = output_done

    def complete(self) -> Bool:
        return self.input_submitted and self.output_submitted and self.input_done and self.output_done
