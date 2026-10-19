# HAILBRÚ integrated-device RPC envelope. No device access or model execution.
# Protocol facts: HailoRT v5.3.0 d503417, hrpc/rpc_connection.hpp and .cpp.
# Independently implemented; see docs/plunder/HAILO10H_SOURCE_EXECUTION_RESEARCH.md.

from hailbru.errors import herror


comptime HRPC_MAGIC = UInt32(0x8A554432)
comptime HRPC_HEADER_BYTES = 20
comptime HRPC_MAX_BODY_BYTES = 2048
comptime HRPC_DMA_MESSAGE_BYTES = HRPC_HEADER_BYTES + HRPC_MAX_BODY_BYTES


struct HrpcFrame(Movable):
    var message_id: UInt32
    var action_id: UInt32
    var remote_status: UInt32
    var body: List[UInt8]
    var padding_bytes: Int

    def __init__(out self, message_id: UInt32, action_id: UInt32,
                 remote_status: UInt32, body: List[UInt8], padding_bytes: Int = 0):
        self.message_id = message_id
        self.action_id = action_id
        self.remote_status = remote_status
        self.body = body.copy()
        self.padding_bytes = padding_bytes


def _word(data: List[UInt8], offset: Int) -> UInt32:
    # Only called after the complete fixed header has been admitted.
    var result = UInt32(0)
    for index in range(4):
        result |= UInt32(data[offset + index]) << UInt32(index * 8)
    return result


def _append_word(mut data: List[UInt8], value: UInt32):
    for index in range(4):
        data.append(UInt8((value >> UInt32(index * 8)) & UInt32(255)))


def encode_hrpc_frame(frame: HrpcFrame) raises -> List[UInt8]:
    if len(frame.body) > HRPC_MAX_BODY_BYTES:
        raise herror("BadRpcFrame", "body exceeds the pinned 2048-byte protocol maximum")
    var data = List[UInt8]()
    data.reserve(HRPC_HEADER_BYTES + len(frame.body))
    _append_word(data, HRPC_MAGIC)
    _append_word(data, UInt32(len(frame.body)))
    _append_word(data, frame.message_id)
    _append_word(data, frame.action_id)
    _append_word(data, frame.remote_status)
    for byte in frame.body:
        data.append(byte)
    return data^


def decode_hrpc_frame(data: List[UInt8], padded_dma_buffer: Bool = False) raises -> HrpcFrame:
    if len(data) < HRPC_HEADER_BYTES:
        raise herror("BadRpcFrame", "truncated 20-byte header")
    if _word(data, 0) != HRPC_MAGIC:
        raise herror("BadRpcFrame", "invalid RPC magic")
    var body_size = Int(_word(data, 4))
    if body_size > HRPC_MAX_BODY_BYTES:
        raise herror("BadRpcFrame", "declared body exceeds the pinned protocol maximum")
    var logical_size = HRPC_HEADER_BYTES + body_size
    if padded_dma_buffer:
        if len(data) != HRPC_DMA_MESSAGE_BYTES:
            raise herror("BadRpcFrame", "DMA buffer must contain exactly 2068 bytes")
    elif len(data) != logical_size:
        raise herror("BadRpcFrame", "packet size does not match the declared body")
    var body = List[UInt8]()
    body.reserve(body_size)
    for index in range(body_size):
        body.append(data[HRPC_HEADER_BYTES + index])
    return HrpcFrame(_word(data, 8), _word(data, 12), _word(data, 16), body,
                     len(data) - logical_size)
