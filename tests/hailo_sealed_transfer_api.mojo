# Original direct host owner/field/failure probes. Never a device consumer.
from std.sys import argv
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from smidr.program_payload import ProgramPayloadRequest, ProgramPayloadSnapshot, stage_program_payload
from smidr.sealed_program_payload import seal_program_payload
from smidr.sealed_transfer_backing import SealedTransferBacking, seal_transfer_backing, sealed_transfer_window
from hailbru.syscall import syscall6, to_cstr, os_pwrite, os_close_descriptor
from smidr.tools.program_integrity import _hex, _signed
from smidr.tools.hrpc_frame import _to_hex


def _request() -> ProgramPayloadRequest:
    return ProgramPayloadRequest(17, 0, "native", 32768)


def _equal(a: List[UInt8], b: List[UInt8]) raises:
    if len(a) != len(b):
        raise Error("TransferAPI: byte extents differ")
    for i in range(len(a)):
        if a[i] != b[i]:
            raise Error("TransferAPI: complete bytes differ")


def _make(staged: ProgramPayloadSnapshot, writes: Int = 4096, reads: Int = 4096) raises -> SealedTransferBacking:
    var source = seal_program_payload(staged, _request(), "aarch64", 4096, 4096)
    return seal_transfer_backing(source^, _request(), writes, reads, 4096)


def _fresh(staged: ProgramPayloadSnapshot) raises:
    var fresh = _make(staged)
    _equal(sealed_transfer_window(fresh, _request(), 0, 0, 2068, 2068, 4096, 4096), staged.metadata)
    _equal(sealed_transfer_window(fresh, _request(), 1, 0, len(staged.program), len(staged.program), 4096, 4096), staged.program)
    fresh.close()


def _refuse(owner: SealedTransferBacking, request: ProgramPayloadRequest) raises:
    var refused = False
    try:
        _ = sealed_transfer_window(owner, request, 0, 0, 0, 0, 4096, 4096)
    except:
        refused = True
    if not refused:
        raise Error("TransferAPI: forged owner admitted through empty window")


def _fixture(bytes: List[UInt8], sealed: Bool) raises -> Int64:
    var name = to_cstr("aesir-transfer-test")
    var fd = syscall6(279, Int64(Int(name)), 3, 0, 0, 0, 0)
    name.unsafe_free()
    if fd < 0:
        raise Error("TransferAPI: fixture create failed")
    var ptr = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(bytes.unsafe_ptr()))
    if os_pwrite("aarch64", fd, ptr, Int64(len(bytes)), 0) != Int64(len(bytes)):
        _ = os_close_descriptor(fd)
        raise Error("TransferAPI: fixture write failed")
    _ = bytes
    if sealed and syscall6(25, fd, 1033, 15, 0, 0, 0) != 0:
        _ = os_close_descriptor(fd)
        raise Error("TransferAPI: fixture seal failed")
    return fd


def _guards(mut owner: SealedTransferBacking, staged: ProgramPayloadSnapshot) raises -> Int:
    var count = 0
    var original_fd = owner.metadata_fd
    # Every actual metadata byte is independently perturbed in a sealed file.
    for i in range(2068):
        var changed = staged.metadata.copy()
        changed[i] ^= 1
        var alternate = _fixture(changed, True)
        owner.metadata_fd = alternate
        try:
            _refuse(owner, _request())
        except error:
            owner.metadata_fd = original_fd
            _ = os_close_descriptor(alternate)
            raise error
        owner.metadata_fd = original_fd
        _ = os_close_descriptor(alternate)
        _fresh(staged)
        count += 1
    for bad in range(4):
        owner.metadata_fd = Int64(-1 if bad == 0 else (2147483648 if bad == 1 else (1000000 if bad == 2 else owner.program.fd)))
        _refuse(owner, _request())
        owner.metadata_fd = original_fd
        _fresh(staged)
        count += 1
    for bad in range(3):
        var changed = staged.metadata.copy()
        if bad == 0:
            changed.append(0)
        var alternate = _fixture(changed, bad != 1)
        if bad == 2:
            _ = syscall6(25, alternate, 2, 0, 0, 0, 0)
        owner.metadata_fd = alternate
        try:
            _refuse(owner, _request())
        except error:
            owner.metadata_fd = original_fd
            _ = os_close_descriptor(alternate)
            raise error
        owner.metadata_fd = original_fd
        _ = os_close_descriptor(alternate)
        _fresh(staged)
        count += 1
    for field in range(4):
        var other = _request()
        if field == 0:
            other.message_id += 1
        elif field == 1:
            other.vdevice_handle += 1
        elif field == 2:
            other.name = "other"
        else:
            other.host_program_bound += 1
        _refuse(owner, other)
        var saved = owner.program.request.copy()
        owner.program.request = other^
        _refuse(owner, _request())
        owner.program.request = saved^
        _fresh(staged)
        count += 2
    var arch = owner.arch
    owner.arch = "x86_64"
    _refuse(owner, _request())
    owner.arch = arch^
    arch = owner.program.arch
    owner.program.arch = "x86_64"
    _refuse(owner, _request())
    owner.program.arch = arch^
    count += 2
    var fd = owner.program.fd
    for bad in range(3):
        owner.program.fd = Int64(-1 if bad == 0 else (1000000 if bad == 1 else owner.metadata_fd))
        _refuse(owner, _request())
        owner.program.fd = fd
        _fresh(staged)
        count += 1
    if syscall6(25, fd, 2, 0, 0, 0, 0) != 0:
        raise Error("TransferAPI: clear program close-on-exec failed")
    _refuse(owner, _request())
    if syscall6(25, fd, 2, 1, 0, 0, 0) != 0:
        raise Error("TransferAPI: restore program close-on-exec failed")
    _fresh(staged)
    count += 1
    for field in range(4):
        var refused = False
        try:
            _ = sealed_transfer_window(owner, _request(), 0, 0, 0, 0,
                0 if field == 0 else (-1 if field == 1 else 4096),
                0 if field == 2 else (-1 if field == 3 else 4096))
        except:
            refused = True
        if not refused:
            raise Error("TransferAPI: direct independent read bound bypassed")
        _fresh(staged)
        count += 1
    var extent = owner.program.program_bytes
    for bad in range(3):
        owner.program.program_bytes = -1 if bad == 0 else (extent + 1 if bad == 1 else 9223372036854775807)
        _refuse(owner, _request())
        owner.program.program_bytes = extent
        _fresh(staged)
        count += 1
    for index in range(2):
        var i = 0 if index == 0 else 2067
        owner.program.metadata[i] ^= 1
        _refuse(owner, _request())
        owner.program.metadata[i] ^= 1
        _fresh(staged)
        count += 1
    owner.program.metadata.append(0)
    _refuse(owner, _request())
    _ = owner.program.metadata.pop()
    _fresh(staged)
    count += 1
    return count


def _escape(staged: ProgramPayloadSnapshot) raises -> List[UInt8]:
    var owner = _make(staged)
    return sealed_transfer_window(owner, _request(), 0, 0, 2068, 2068, 4096, 4096)


def main() raises:
    var args = argv()
    if len(args) == 2 and args[1] == "default":
        var owner = SealedTransferBacking()
        _refuse(owner, _request())
        owner.close()
        owner.close()
        print("default_refused")
        return
    if len(args) != 5:
        raise Error("usage: sealed_transfer_api program-hex metadata-writes metadata-reads mode")
    var program = _hex(args[1])
    var staged = stage_program_payload(program, _request())
    var mode = args[4]
    if mode == "recover":
        var refused = False
        try:
            var first = _make(staged, _signed(args[2]), _signed(args[3]))
            _ = sealed_transfer_window(first, _request(), 0, 0, 0, 0, 4096, 4096)
            first.close()
        except:
            refused = True
        if not refused:
            raise Error("TransferAPI: first fault absent")
        _fresh(staged)
        print("refused_and_recovered")
        return
    if mode == "bad_source":
        var source = seal_program_payload(staged, _request(), "aarch64", 4096, 4096)
        source.metadata[0] ^= 1
        var refused = False
        try:
            _ = seal_transfer_backing(source^, _request(), 4096, 4096, 4096)
        except:
            refused = True
        if not refused:
            raise Error("TransferAPI: changed source admitted")
        _fresh(staged)
        print("source_refused_and_recovered")
        return
    var owner = _make(staged, _signed(args[2]), _signed(args[3]))
    if mode == "close_error":
        var errors = String("")
        try:
            owner.close()
        except error:
            errors = String(error)
        if errors.byte_length() == 0 or owner.metadata_fd != -1 or owner.program.fd != -1:
            raise Error("TransferAPI: close failure lost independent invalidation")
        owner.close()
        _fresh(staged)
        print("close_refused_and_recovered:" + errors)
        return
    var cycles = 0
    if mode == "guards":
        cycles = _guards(owner, staged)
    elif mode != "bytes" and mode != "implicit":
        raise Error("TransferAPI: unknown mode")
    var metadata = sealed_transfer_window(owner, _request(), 0, 0, 2068, 2068, 4096, 4096)
    var output = sealed_transfer_window(owner, _request(), 1, 0, len(program), len(program), 4096, 4096)
    var moved = owner^
    _equal(_escape(staged), metadata)
    staged.metadata.clear()
    staged.request.name = "changed"
    staged.program.clear()
    program.clear()
    _equal(sealed_transfer_window(moved, _request(), 0, 0, 2068, 2068, 4096, 4096), metadata)
    _equal(sealed_transfer_window(moved, _request(), 1, 0, len(output), len(output), 4096, 4096), output)
    if mode != "implicit":
        moved.close()
        moved.close()
        _refuse(moved, _request())
    print("{\"metadata_hex\":\"" + _to_hex(metadata) + "\",\"program_hex\":\"" + _to_hex(output) + "\",\"guard_cycles\":" + String(cycles) + ",\"device_access\":false}")
