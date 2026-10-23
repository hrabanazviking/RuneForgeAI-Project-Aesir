# Original owned immutable host output bytes. No mapping, DMA or execution.
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from hailbru.syscall import syscall6, to_cstr, errno_now, os_close_descriptor, os_fd_regular_size, os_pread_metadata, os_pwrite
from hailbru.source_sealed_copy import _require_sealed_source
from smidr.program_payload import ProgramPayloadRequest, ProgramPayloadSnapshot, validate_program_payload, stage_program_payload, program_payload_window
from hailbru.hrpc_frame import HRPC_DMA_MESSAGE_BYTES


struct SealedProgramPayload(Movable):
    var arch: String
    var fd: Int64
    var program_bytes: Int64
    var request: ProgramPayloadRequest
    var metadata: List[UInt8]

    def __init__(out self):
        self.arch = String("")
        self.fd = -1
        self.program_bytes = 0
        self.request = ProgramPayloadRequest(0, 0, "", 0)
        self.metadata = List[UInt8]()

    def __deinit__(deinit self):
        if self.fd >= 0:
            if os_close_descriptor(self.fd) != 0:
                print("SealedProgramPayload: implicit descriptor close failed")

    def close(mut self) raises:
        if self.fd < 0:
            return
        var owned = self.fd
        self.fd = -1
        if os_close_descriptor(owned) != 0:
            raise Error("SealedProgramPayload: descriptor close failed")


def _live(owner: SealedProgramPayload, expected: ProgramPayloadRequest, read_call_bound: Int) raises:
    if read_call_bound <= 0 or owner.program_bytes < 56 or UInt64(owner.program_bytes) > expected.host_program_bound:
        raise Error("SealedProgramPayload: invalid full-program extent or read-call bound")
    if (owner.request.message_id != expected.message_id
            or owner.request.vdevice_handle != expected.vdevice_handle
            or owner.request.name != expected.name
            or owner.request.host_program_bound != expected.host_program_bound):
        raise Error("SealedProgramPayload: retained request differs from expected wire intent")
    if expected.name.byte_length() > 2048 or expected.vdevice_handle == UInt32(4294967295) or len(owner.metadata) != HRPC_DMA_MESSAGE_BYTES:
        raise Error("SealedProgramPayload: invalid retained request or metadata extent")
    _require_sealed_source(owner.arch, owner.fd, owner.program_bytes)
    var flags = syscall6(25, owner.fd, 1, 0, 0, 0, 0)
    if flags < 0 or (flags & 1) == 0:
        raise Error("SealedProgramPayload: owned descriptor lacks close-on-exec")


def _checked_snapshot(owner: SealedProgramPayload, expected: ProgramPayloadRequest,
                      read_call_bound: Int) raises -> ProgramPayloadSnapshot:
    _live(owner, expected, read_call_bound)
    var data = List[UInt8](length=Int(owner.program_bytes), fill=0)
    var done = 0
    var calls = 0
    while done < len(data):
        if calls >= read_call_bound:
            raise Error("SealedProgramPayload: full-program read-call bound exhausted")
        var want = min(4096, len(data) - done)
        var pointer = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(data.unsafe_ptr()) + done)
        calls += 1
        var n = os_pread_metadata(owner.arch, owner.fd, pointer, Int64(want), Int64(done))
        _ = data
        if n < 0:
            if errno_now() == 4:
                continue
            raise Error("SealedProgramPayload: positional program read failed")
        if n == 0 or n > Int64(want):
            raise Error("SealedProgramPayload: program read made invalid progress")
        done += Int(n)
    # Fresh canonical/full-integrity checks on bytes from the actual sealed fd.
    var snapshot = ProgramPayloadSnapshot(owner.request, owner.metadata, data)
    validate_program_payload(snapshot, expected)
    return snapshot^


def seal_program_payload(snapshot: ProgramPayloadSnapshot, expected: ProgramPayloadRequest,
                         arch: String, write_call_bound: Int,
                         read_call_bound: Int) raises -> SealedProgramPayload:
    if arch != "aarch64" or write_call_bound <= 0 or read_call_bound <= 0:
        raise Error("SealedProgramPayload: qualified host and positive write/read bounds required")
    if UInt64(len(snapshot.program)) > UInt64(2305843009213693951):
        raise Error("SealedProgramPayload: program exceeds qualified host extent")
    validate_program_payload(snapshot, expected)
    var name = to_cstr("aesir-program-payload")
    var fd = syscall6(279, Int64(Int(name)), 3, 0, 0, 0, 0)
    name.unsafe_free()
    if fd < 0 or fd > 2147483647:
        raise Error("SealedProgramPayload: anonymous descriptor creation failed")
    var result = SealedProgramPayload()
    result.arch = arch
    result.fd = fd
    result.program_bytes = Int64(len(snapshot.program))
    result.request = expected.copy()
    result.metadata = snapshot.metadata.copy()
    var done = 0
    var calls = 0
    while done < len(snapshot.program):
        if calls >= write_call_bound:
            raise Error("SealedProgramPayload: program write-call bound exhausted")
        var want = min(4096, len(snapshot.program) - done)
        var pointer = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(snapshot.program.unsafe_ptr()) + done)
        calls += 1
        var n = os_pwrite(arch, fd, pointer, Int64(want), Int64(done))
        _ = snapshot
        if n < 0:
            if errno_now() == 4:
                continue
            raise Error("SealedProgramPayload: positional program write failed")
        if n == 0 or n > Int64(want):
            raise Error("SealedProgramPayload: program write made invalid progress")
        done += Int(n)
    if os_fd_regular_size(arch, fd) != result.program_bytes:
        raise Error("SealedProgramPayload: written program extent differs")
    if syscall6(25, fd, 1033, 15, 0, 0, 0) != 0:
        raise Error("SealedProgramPayload: kernel sealing failed")
    var actual = _checked_snapshot(result, expected, read_call_bound)
    for i in range(len(snapshot.program)):
        if snapshot.program[i] != actual.program[i]:
            raise Error("SealedProgramPayload: sealed program differs from staged bytes")
    return result^


def sealed_program_window(owner: SealedProgramPayload, expected: ProgramPayloadRequest,
                          part: Int, first: Int, count: Int, output_bound: Int,
                          read_call_bound: Int) raises -> List[UInt8]:
    if part != 0 and part != 1:
        raise Error("SealedProgramPayload: part must select metadata0 or program1")
    if first < 0 or count < 0 or output_bound < 0 or count > output_bound:
        raise Error("SealedProgramPayload: invalid signed window/output bound")
    var extent = Int64(HRPC_DMA_MESSAGE_BYTES) if part == 0 else owner.program_bytes
    if extent < 0 or Int64(first) > extent or Int64(count) > extent - Int64(first):
        raise Error("SealedProgramPayload: window exceeds actual selected extent")
    var actual = _checked_snapshot(owner, expected, read_call_bound)
    return program_payload_window(actual, expected, part, first, count, output_bound)
