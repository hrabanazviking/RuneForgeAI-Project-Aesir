# Direct synthetic owner/guard/kernel/failure/recovery seams, never device code.
from std.sys import argv
from std.ffi import external_call
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from smidr.sealed_program_payload import SealedProgramPayload, seal_program_payload, sealed_program_window
from smidr.program_payload import ProgramPayloadRequest, ProgramPayloadSnapshot, stage_program_payload
from hailbru.syscall import syscall6, errno_now, os_pwrite, os_close_descriptor, to_cstr
from smidr.tools.program_integrity import _hex, _signed
from smidr.tools.hrpc_frame import _to_hex


def _request() -> ProgramPayloadRequest:
    return ProgramPayloadRequest(17, 0, "native", 32768)


def _equal(a: List[UInt8], b: List[UInt8]) raises:
    if len(a) != len(b):
        raise Error("test: program copy extent changed")
    for i in range(len(a)):
        if a[i] != b[i]:
            raise Error("test: program copy bytes changed")


def _refuse(owner: SealedProgramPayload, expected: ProgramPayloadRequest) raises:
    var refused = False
    try:
        _ = sealed_program_window(owner, expected, 1, 0, 0, 0, 4096)
    except:
        refused = True
    if not refused:
        raise Error("test: forged owner consumed")


def _fresh(staged: ProgramPayloadSnapshot) raises:
    var fresh = seal_program_payload(staged, _request(), "aarch64", 4096, 4096)
    _equal(sealed_program_window(fresh, _request(), 1, 0, len(staged.program), len(staged.program), 4096), staged.program)
    fresh.close()


def _protect(owner: SealedProgramPayload) raises:
    var byte: List[UInt8] = [173]
    var ptr = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(byte.unsafe_ptr()))
    var n = os_pwrite("aarch64", owner.fd, ptr, 1, 0)
    _ = byte
    if n != -1 or errno_now() != 1:
        raise Error("test: sealed write admitted")
    if external_call["ftruncate", Int32](Int32(owner.fd), owner.program_bytes + 1) != -1 or errno_now() != 1:
        raise Error("test: sealed growth admitted")
    if external_call["ftruncate", Int32](Int32(owner.fd), owner.program_bytes - 1) != -1 or errno_now() != 1:
        raise Error("test: sealed shrink admitted")
    var address = syscall6(222, 0, owner.program_bytes, 3, 1, owner.fd, 0)
    if address != -1:
        _ = syscall6(215, address, owner.program_bytes, 0, 0, 0, 0)
        raise Error("test: writable shared mapping admitted")
    if errno_now() != 1:
        raise Error("test: unexpected mapping refusal")


def _escaping(staged: ProgramPayloadSnapshot) raises -> List[UInt8]:
    var owner = seal_program_payload(staged, _request(), "aarch64", 4096, 4096)
    return sealed_program_window(owner, _request(), 1, 0, len(staged.program), len(staged.program), 4096)


def _guards(mut owner: SealedProgramPayload, staged: ProgramPayloadSnapshot) raises -> Int:
    var count = 0
    for i in range(len(owner.metadata)):
        owner.metadata[i] ^= 1
        _refuse(owner, _request())
        owner.metadata[i] ^= 1
        _fresh(staged)
        count += 1
    for field in range(4):
        var other = _request()
        if field == 0:
            other.message_id += 1
        elif field == 1:
            other.vdevice_handle += 1
        elif field == 2:
            other.name = "different"
        else:
            other.host_program_bound += 1
        _refuse(owner, other)
        var saved = owner.request.copy()
        owner.request = other^
        _refuse(owner, _request())
        owner.request = saved^
        _fresh(staged)
        count += 2
    var size = owner.program_bytes
    for bad in range(3):
        owner.program_bytes = -1 if bad == 0 else (size + 1 if bad == 1 else 9223372036854775807)
        _refuse(owner, _request())
        owner.program_bytes = size
        _fresh(staged)
        count += 1
    var arch = owner.arch
    owner.arch = "x86_64"
    _refuse(owner, _request())
    owner.arch = arch^
    _fresh(staged)
    count += 1
    var fd = owner.fd
    for bad in range(3):
        owner.fd = Int64(-1 if bad == 0 else (2147483648 if bad == 1 else 1000000))
        _refuse(owner, _request())
        owner.fd = fd
        _fresh(staged)
        count += 1
    owner.metadata.append(0)
    _refuse(owner, _request())
    _ = owner.metadata.pop()
    _fresh(staged)
    count += 1
    var label = to_cstr("aesir-unsealed-test")
    var unsealed = syscall6(279, Int64(Int(label)), 3, 0, 0, 0, 0)
    label.unsafe_free()
    if unsealed < 0:
        raise Error("test: unsealed fixture create failed")
    owner.fd = unsealed
    try:
        _refuse(owner, _request())
    except e:
        owner.fd = fd
        _ = os_close_descriptor(unsealed)
        raise e
    owner.fd = fd
    _ = os_close_descriptor(unsealed)
    _fresh(staged)
    count += 1
    if syscall6(25, fd, 2, 0, 0, 0, 0) != 0:
        raise Error("test: clear close-on-exec failed")
    _refuse(owner, _request())
    if syscall6(25, fd, 2, 1, 0, 0, 0) != 0:
        raise Error("test: restore close-on-exec failed")
    _fresh(staged)
    count += 1
    return count


def main() raises:
    var args = argv()
    if len(args) == 2 and args[1] == "default":
        var owner = SealedProgramPayload()
        _refuse(owner, _request())
        owner.close()
        owner.close()
        print("default_refused")
        return
    if len(args) != 5:
        raise Error("usage: sealed_program_api program-hex write-calls read-calls mode")
    var program = _hex(args[1])
    var staged = stage_program_payload(program, _request())
    var mode = args[4]
    if mode == "recover":
        var refused = False
        try:
            var first = seal_program_payload(staged, _request(), "aarch64", _signed(args[2]), _signed(args[3]))
            _ = sealed_program_window(first, _request(), 1, 0, 0, 0, 4096)
            first.close()
        except:
            refused = True
        if not refused:
            raise Error("test: injected first failure absent")
        _fresh(staged)
        print("refused_and_recovered")
        return
    if mode == "bad_snapshot":
        staged.metadata[0] ^= 1
        var refused = False
        try:
            _ = seal_program_payload(staged, _request(), "aarch64", 4096, 4096)
        except:
            refused = True
        if not refused:
            raise Error("test: changed snapshot admitted")
        staged.metadata[0] ^= 1
        _fresh(staged)
        print("snapshot_refused_and_recovered")
        return
    var owner = seal_program_payload(staged, _request(), "aarch64", _signed(args[2]), _signed(args[3]))
    var cycles = 0
    if mode == "guards":
        cycles = _guards(owner, staged)
    elif mode == "protect":
        _protect(owner)
    elif mode == "close_error":
        var refused = False
        try:
            owner.close()
        except:
            refused = True
        if not refused or owner.fd != -1:
            raise Error("test: close error kept ownership")
        owner.close()
        _fresh(staged)
        print("close_failed_after_release_and_recovered")
        return
    elif mode != "bytes" and mode != "implicit":
        raise Error("test: unknown mode")
    var flags = syscall6(25, owner.fd, 1, 0, 0, 0, 0)
    var seals = syscall6(25, owner.fd, 1034, 0, 0, 0, 0)
    var saved = staged.program.copy()
    var metadata = staged.metadata.copy()
    var copied = sealed_program_window(owner, _request(), 1, 0, len(saved), len(saved), 4096)
    for i in range(len(staged.program)):
        staged.program[i] = 0
    staged.metadata.clear()
    staged.request.name = "changed"
    program.clear()
    var moved = owner^
    _equal(copied, saved)
    _equal(sealed_program_window(moved, _request(), 1, 0, len(saved), len(saved), 4096), saved)
    _equal(sealed_program_window(moved, _request(), 0, 0, 2068, 2068, 4096), metadata)
    var canonical = stage_program_payload(saved, _request())
    _equal(_escaping(canonical), saved)
    var output = sealed_program_window(moved, _request(), 1, 0, len(saved), len(saved), 4096)
    var text = "{\"program_hex\":\"" + _to_hex(output) + "\",\"metadata_hex\":\"" + _to_hex(metadata) + "\",\"seals\":" + String(seals) + ",\"fd_flags\":" + String(flags) + ",\"refusal_recovery_cycles\":" + String(cycles) + "}"
    if mode != "implicit":
        moved.close()
        moved.close()
        _refuse(moved, _request())
    _equal(copied, saved)
    print(text)
