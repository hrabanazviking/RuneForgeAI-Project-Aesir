# core/posix_process.mojo
# Bounded argv-only POSIX child execution shared by native infrastructure.

from std.ffi import external_call
from std.memory import Pointer


def _process_cstring(value: String) raises -> List[Int8]:
    var result = List[Int8]()
    for byte in value.as_bytes():
        if byte == 0:
            raise Error("subprocess argument contains NUL")
        result.append(Int8(byte))
    result.append(0)
    return result^


def run_checked_argv_bytes(
    args: List[String], max_output_bytes: Int = 16384
) raises -> List[Byte]:
    """Executes an argv vector without a shell and returns bounded raw stdout."""
    if len(args) == 0:
        raise Error("subprocess requires an executable")
    if max_output_bytes <= 0 or max_output_bytes > 16 * 1024 * 1024:
        raise Error("subprocess output limit must be 1..16777216 bytes")
    var buffers = List[List[Int8]]()
    for arg in args:
        buffers.append(_process_cstring(arg))
    var pointers = List[Int]()
    for index in range(len(buffers)):
        pointers.append(Int(buffers[index].unsafe_ptr()))
    pointers.append(0)
    var program = pointers[0]
    var descriptors: List[Int32] = [0, 0]
    if external_call["pipe", Int32](descriptors.unsafe_ptr()) != 0:
        raise Error("subprocess pipe creation failed")
    var pid = external_call["fork", Int32]()
    if pid == 0:
        _ = external_call["close", Int32](descriptors[0])
        if external_call["dup2", Int32](descriptors[1], Int32(1)) < 0:
            external_call["_exit", NoneType](Int32(126))
        _ = external_call["close", Int32](descriptors[1])
        _ = external_call["execvp", Int32](
            program, pointers.unsafe_ptr()
        )
        _ = buffers
        external_call["_exit", NoneType](Int32(127))
    _ = external_call["close", Int32](descriptors[1])
    if pid < 0:
        _ = external_call["close", Int32](descriptors[0])
        raise Error("subprocess creation failed")

    var output = List[Byte]()
    var chunk = List[Byte]()
    chunk.resize(4096, 0)
    var output_invalid = False
    while True:
        var count = external_call["read", Int](
            Int(descriptors[0]), chunk.unsafe_ptr(), Int(4096)
        )
        if count == 0:
            break
        if count < 0:
            var errno_pointer = external_call[
                "__errno_location", Pointer[Int32, MutUntrackedOrigin]
            ]()
            if errno_pointer.unsafe_load() == 4:
                continue
            output_invalid = True
            break
        if len(output) + count <= max_output_bytes:
            for index in range(count):
                output.append(chunk[index])
        else:
            # Continue draining so the child cannot block on a full pipe.
            output_invalid = True
    _ = external_call["close", Int32](descriptors[0])
    var status: Int32 = 0
    var waited: Int32 = -1
    while waited < 0:
        waited = external_call["waitpid", Int32](
            pid, Pointer(to=status), Int32(0)
        )
        if waited < 0:
            var errno_pointer = external_call[
                "__errno_location", Pointer[Int32, MutUntrackedOrigin]
            ]()
            if errno_pointer.unsafe_load() != 4:
                raise Error("subprocess wait failed")
    _ = buffers
    if status != 0:
        raise Error(
            "subprocess failed: " + args[0]
            + " (wait status " + String(status) + ")"
        )
    if output_invalid:
        raise Error("subprocess output exceeded its bound or could not be read")
    return output^


def run_checked_argv(
    args: List[String], max_output_bytes: Int = 16384
) raises -> String:
    """Executes an argv vector and returns bounded NUL-terminated text stdout."""
    var output = run_checked_argv_bytes(args, max_output_bytes)
    for byte in output:
        if byte == 0:
            raise Error("subprocess text output contains NUL")
    output.append(0)
    return String(unsafe_from_utf8_ptr=output.unsafe_ptr())
