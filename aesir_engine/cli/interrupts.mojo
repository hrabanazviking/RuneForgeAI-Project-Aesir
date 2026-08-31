"""Linux chat/service signal ownership without async Mojo signal handlers."""
from std.collections import InlineArray
from std.ffi import external_call
from std.memory import Pointer
from std.sys import argv



def prepare_chat_process(include_termination: Bool = False) raises:
    """Bootstrap the executable once so pre-main runtime workers inherit SIGINT.

    Linux preserves the calling thread mask across exec and newly created threads
    inherit it. Merely blocking in main is too late for MAX startup workers. No
    signal handler executes Mojo. Preserve argv/environment and the process ID.
    This belongs only to the executable; embedding callers own their signals.
    """
    var old_mask = InlineArray[UInt64, 16](fill=0)
    if external_call["pthread_sigmask", Int32](Int32(0), Int(0), Int(old_mask.unsafe_ptr())) != 0:
        raise Error("Cannot observe native launch signal mask")
    var required_mask = UInt64(16386) if include_termination else UInt64(2)
    if old_mask[0] & required_mask == required_mask:
        return
    var mask = InlineArray[UInt64, 16](fill=0)
    if external_call["sigemptyset", Int32](mask.unsafe_ptr()) != 0 or external_call["sigaddset", Int32](mask.unsafe_ptr(), Int32(2)) != 0:
        raise Error("Cannot prepare native launch signal set")
    if include_termination and external_call["sigaddset", Int32](mask.unsafe_ptr(), Int32(15)) != 0:
        raise Error("Cannot prepare native SIGTERM set")
    if external_call["pthread_sigmask", Int32](Int32(0), Int(mask.unsafe_ptr()), Int(0)) != 0:
        raise Error("Cannot prepare native launch signal mask")
    var bytes = List[List[Int8]]()
    for argument in argv():
        var value = List[Int8]()
        for byte in String(argument).as_bytes():
            value.append(Int8(byte))
        value.append(0)
        bytes.append(value^)
    var pointers = List[Int]()
    for i in range(len(bytes)):
        pointers.append(Int(bytes[i].unsafe_ptr()))
    pointers.append(0)
    var executable = String("/proc/self/exe")
    _ = external_call["execv", Int32](executable.unsafe_ptr(), pointers.unsafe_ptr())
    _ = bytes
    _ = executable
    _ = external_call["pthread_sigmask", Int32](Int32(2), Int(old_mask.unsafe_ptr()), Int(0))
    raise Error("Cannot bootstrap native chat cancellation")

def consume_interrupts(fd: Int) -> Bool:
    if fd < 0:
        return False
    var info = InlineArray[UInt64, 16](fill=0)
    var consumed = False
    while True:
        var count = external_call["read", Int](fd, info.unsafe_ptr(), Int(128))
        if count > 0:
            consumed = True
        elif count < 0 and external_call["__errno_location", Pointer[Int32, MutUntrackedOrigin]]().unsafe_load() == 4:
            continue
        else:
            break
    return consumed


struct ChatInterrupts:
    var fd: Int
    var old_mask: InlineArray[UInt64, 16]
    var active: Bool

    def __init__(out self, include_termination: Bool = False) raises:
        self.fd = -1
        self.old_mask = InlineArray[UInt64, 16](fill=0)
        self.active = False
        var mask = InlineArray[UInt64, 16](fill=0)
        if external_call["sigemptyset", Int32](mask.unsafe_ptr()) != 0 or external_call["sigaddset", Int32](mask.unsafe_ptr(), Int32(2)) != 0:
            raise Error("Cannot configure SIGINT set")
        if include_termination and external_call["sigaddset", Int32](mask.unsafe_ptr(), Int32(15)) != 0:
            raise Error("Cannot configure SIGTERM set")
        if external_call["pthread_sigmask", Int32](Int32(0), Int(mask.unsafe_ptr()), Int(self.old_mask.unsafe_ptr())) != 0:
            raise Error("Cannot block SIGINT for safe native cancellation")
        self.fd = Int(external_call["signalfd", Int32](Int32(-1), mask.unsafe_ptr(), Int32(526336)))
        if self.fd < 0:
            _ = external_call["pthread_sigmask", Int32](Int32(2), Int(self.old_mask.unsafe_ptr()), Int(0))
            raise Error("Cannot create native cancellation descriptor")
        self.active = True

    def __deinit__(deinit self):
        if self.active:
            _ = consume_interrupts(self.fd)
            _ = external_call["close", Int32](Int32(self.fd))
            _ = external_call["pthread_sigmask", Int32](Int32(2), Int(self.old_mask.unsafe_ptr()), Int(0))


def read_interruptible_line(fd: Int) raises -> String:
    var bytes = List[Int8]()
    var input_byte = InlineArray[Int8, 1](fill=0)
    while True:
        var descriptors = InlineArray[UInt64, 2](fill=0)
        descriptors[0] = UInt64(1) << 32
        descriptors[1] = UInt64(UInt32(fd)) | (UInt64(1) << 32)
        var result = external_call["poll", Int32](descriptors.unsafe_ptr(), UInt64(2), Int32(-1))
        if result < 0:
            if external_call["__errno_location", Pointer[Int32, MutUntrackedOrigin]]().unsafe_load() == 4:
                continue
            raise Error("Chat input poll failed")
        if descriptors[1] >> 48 != 0:
            _ = consume_interrupts(fd)
            return ""
        var count = external_call["read", Int](Int(0), input_byte.unsafe_ptr(), Int(1))
        if count < 0:
            raise Error("Chat input read failed")
        if count == 0 or input_byte[0] == 10:
            break
        if input_byte[0] == 0:
            raise Error("Chat input contains NUL")
        if input_byte[0] != 13:
            bytes.append(input_byte[0])
        if len(bytes) > 65536:
            raise Error("Chat input line exceeds 64 KiB")
    bytes.append(0)
    return String(unsafe_from_utf8_ptr=bytes.unsafe_ptr())
