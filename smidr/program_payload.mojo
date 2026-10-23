# Original owned wire preparation. No DMA, executable admission or device call.
from hailbru.hrpc_frame import HRPC_DMA_MESSAGE_BYTES, encode_hrpc_frame
from hailbru.hrpc_program import program_create_request
from smidr.program_integrity import validate_program_integrity


@fieldwise_init
struct ProgramPayloadRequest(Copyable, Movable):
    var message_id: UInt32
    var vdevice_handle: UInt32
    var name: String
    var host_program_bound: UInt64


struct ProgramPayloadSnapshot(Movable):
    var request: ProgramPayloadRequest
    var metadata: List[UInt8]
    var program: List[UInt8]

    def __init__(out self, request: ProgramPayloadRequest,
                 metadata: List[UInt8], program: List[UInt8]):
        self.request = request.copy()
        self.metadata = metadata.copy()
        self.program = program.copy()


def _check_program(program: List[UInt8], request: ProgramPayloadRequest) raises:
    if request.host_program_bound == 0 or request.vdevice_handle == UInt32(4294967295):
        raise Error("ProgramPayload: invalid explicit host bound or virtual-device handle")
    if request.name.byte_length() > 2048:
        raise Error("ProgramPayload: name exceeds RPC body bound")
    var checked = validate_program_integrity(program, request.host_program_bound)
    if checked.protobuf_only:
        raise Error("ProgramPayload: full-residue outer integrity is required")


def _metadata(program_size: Int, request: ProgramPayloadRequest) raises -> List[UInt8]:
    var frame = program_create_request(request.message_id, request.vdevice_handle,
                                       UInt64(program_size), request.name, request.host_program_bound)
    var bytes = encode_hrpc_frame(frame)
    bytes.reserve(HRPC_DMA_MESSAGE_BYTES)
    while len(bytes) < HRPC_DMA_MESSAGE_BYTES:
        bytes.append(0)
    return bytes^


def stage_program_payload(program: List[UInt8], request: ProgramPayloadRequest) raises -> ProgramPayloadSnapshot:
    _check_program(program, request)
    var metadata = _metadata(len(program), request)
    return ProgramPayloadSnapshot(request, metadata, program)


def validate_program_payload(snapshot: ProgramPayloadSnapshot,
                             expected: ProgramPayloadRequest) raises:
    if (snapshot.request.message_id != expected.message_id
            or snapshot.request.vdevice_handle != expected.vdevice_handle
            or snapshot.request.name != expected.name
            or snapshot.request.host_program_bound != expected.host_program_bound):
        raise Error("ProgramPayload: retained request differs from expected wire intent")
    _check_program(snapshot.program, expected)
    var fresh = _metadata(len(snapshot.program), expected)
    if len(snapshot.metadata) != len(fresh):
        raise Error("ProgramPayload: metadata segment extent changed")
    for i in range(len(fresh)):
        if snapshot.metadata[i] != fresh[i]:
            raise Error("ProgramPayload: metadata differs from actual payload and expected request")


def program_payload_window(snapshot: ProgramPayloadSnapshot, expected: ProgramPayloadRequest,
                           part: Int, first: Int, count: Int, output_bound: Int) raises -> List[UInt8]:
    if part != 0 and part != 1:
        raise Error("ProgramPayload: part must select metadata0 or program1")
    if first < 0 or count < 0 or output_bound < 0 or count > output_bound:
        raise Error("ProgramPayload: invalid signed window or output-work bound")
    var extent = len(snapshot.metadata) if part == 0 else len(snapshot.program)
    if first > extent or count > extent - first:
        raise Error("ProgramPayload: window exceeds its selected actual segment")
    validate_program_payload(snapshot, expected)
    var output = List[UInt8]()
    output.reserve(count)
    for i in range(count):
        output.append(snapshot.metadata[first + i] if part == 0 else snapshot.program[first + i])
    return output^
