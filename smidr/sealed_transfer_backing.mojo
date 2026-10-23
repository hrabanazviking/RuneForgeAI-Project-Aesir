# Original immutable host backing for two ordered transaction parts. No device.
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from hailbru.syscall import syscall6, to_cstr, errno_now, os_close_descriptor, os_fd_regular_size, os_pread_metadata, os_pwrite
from hailbru.source_sealed_copy import _require_sealed_source
from hailbru.hrpc_frame import HRPC_DMA_MESSAGE_BYTES
from smidr.program_payload import ProgramPayloadRequest, ProgramPayloadSnapshot, program_payload_window
from smidr.sealed_program_payload import SealedProgramPayload, _checked_snapshot


struct SealedTransferBacking(Movable):
    var arch: String
    var metadata_fd: Int64
    var program: SealedProgramPayload

    def __init__(out self):
        self.arch = String("")
        self.metadata_fd = -1
        self.program = SealedProgramPayload()

    def __deinit__(deinit self):
        if self.metadata_fd >= 0:
            if os_close_descriptor(self.metadata_fd) != 0:
                print("SealedTransferBacking: implicit metadata close failed")

    def close(mut self) raises:
        var failures = String("")
        if self.metadata_fd >= 0:
            var owned = self.metadata_fd
            self.metadata_fd = -1
            if os_close_descriptor(owned) != 0:
                failures = String("metadata descriptor close failed")
        try:
            self.program.close()
        except error:
            failures += "; " + String(error)
        if failures.byte_length() != 0:
            raise Error("SealedTransferBacking: " + failures)


def _actual(owner: SealedTransferBacking, expected: ProgramPayloadRequest,
            program_read_bound: Int, metadata_read_bound: Int) raises -> ProgramPayloadSnapshot:
    if owner.arch != "aarch64" or owner.program.arch != owner.arch or owner.metadata_fd < 0 or owner.metadata_fd == owner.program.fd or metadata_read_bound <= 0:
        raise Error("SealedTransferBacking: invalid host, distinct owners or read bound")
    var snapshot = _checked_snapshot(owner.program, expected, program_read_bound)
    _require_sealed_source(owner.arch, owner.metadata_fd, Int64(HRPC_DMA_MESSAGE_BYTES))
    var flags = syscall6(25, owner.metadata_fd, 1, 0, 0, 0, 0)
    if flags < 0 or (flags & 1) == 0:
        raise Error("SealedTransferBacking: metadata descriptor lacks close-on-exec")
    var bytes = List[UInt8](length=HRPC_DMA_MESSAGE_BYTES, fill=0)
    var done = 0
    var calls = 0
    while done < len(bytes):
        if calls >= metadata_read_bound:
            raise Error("SealedTransferBacking: metadata read-call bound exhausted")
        var want = min(4096, len(bytes) - done)
        var pointer = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(bytes.unsafe_ptr()) + done)
        calls += 1
        var n = os_pread_metadata(owner.arch, owner.metadata_fd, pointer, Int64(want), Int64(done))
        _ = bytes
        if n < 0:
            if errno_now() == 4:
                continue
            raise Error("SealedTransferBacking: metadata read failed")
        if n == 0 or n > Int64(want):
            raise Error("SealedTransferBacking: metadata read made invalid progress")
        done += Int(n)
    for i in range(HRPC_DMA_MESSAGE_BYTES):
        if bytes[i] != snapshot.metadata[i]:
            raise Error("SealedTransferBacking: actual metadata differs from canonical program intent")
    return snapshot^


def seal_transfer_backing(var program: SealedProgramPayload, expected: ProgramPayloadRequest,
                          metadata_write_bound: Int, metadata_read_bound: Int,
                          program_read_bound: Int) raises -> SealedTransferBacking:
    if program.arch != "aarch64" or metadata_write_bound <= 0 or metadata_read_bound <= 0 or program_read_bound <= 0:
        raise Error("SealedTransferBacking: qualified host and positive independent I/O bounds required")
    # Validate actual source bytes/full canonical intent before metadata allocation.
    var snapshot = _checked_snapshot(program, expected, program_read_bound)
    var result = SealedTransferBacking()
    result.arch = program.arch
    result.program = program^
    var name = to_cstr("aesir-transfer-metadata")
    var fd = syscall6(279, Int64(Int(name)), 3, 0, 0, 0, 0)
    name.unsafe_free()
    if fd < 0 or fd > 2147483647:
        raise Error("SealedTransferBacking: metadata descriptor creation failed")
    result.metadata_fd = fd
    var done = 0
    var calls = 0
    while done < len(snapshot.metadata):
        if calls >= metadata_write_bound:
            raise Error("SealedTransferBacking: metadata write-call bound exhausted")
        var want = min(4096, len(snapshot.metadata) - done)
        var pointer = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(snapshot.metadata.unsafe_ptr()) + done)
        calls += 1
        var n = os_pwrite(result.arch, fd, pointer, Int64(want), Int64(done))
        _ = snapshot
        if n < 0:
            if errno_now() == 4:
                continue
            raise Error("SealedTransferBacking: metadata write failed")
        if n == 0 or n > Int64(want):
            raise Error("SealedTransferBacking: metadata write made invalid progress")
        done += Int(n)
    if os_fd_regular_size(result.arch, fd) != Int64(HRPC_DMA_MESSAGE_BYTES):
        raise Error("SealedTransferBacking: written metadata extent differs")
    if syscall6(25, fd, 1033, 15, 0, 0, 0) != 0:
        raise Error("SealedTransferBacking: metadata kernel sealing failed")
    _ = _actual(result, expected, program_read_bound, metadata_read_bound)
    return result^


def sealed_transfer_window(owner: SealedTransferBacking, expected: ProgramPayloadRequest,
                           part: Int, first: Int, count: Int, output_bound: Int,
                           program_read_bound: Int, metadata_read_bound: Int) raises -> List[UInt8]:
    if part != 0 and part != 1:
        raise Error("SealedTransferBacking: part must select metadata0 or program1")
    if first < 0 or count < 0 or output_bound < 0 or count > output_bound:
        raise Error("SealedTransferBacking: invalid signed window/output-work bound")
    var extent = Int64(HRPC_DMA_MESSAGE_BYTES) if part == 0 else owner.program.program_bytes
    if extent < 0 or Int64(first) > extent or Int64(count) > extent - Int64(first):
        raise Error("SealedTransferBacking: window exceeds selected actual part")
    var snapshot = _actual(owner, expected, program_read_bound, metadata_read_bound)
    return program_payload_window(snapshot, expected, part, first, count, output_bound)
