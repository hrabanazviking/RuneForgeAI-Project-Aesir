"""Native Linux random key creation with exclusive publication and private mode."""
from std.collections import InlineArray
from std.ffi import external_call
from server.local_transport import OwnedFD, io_errno, c_path_bytes


struct TemporaryKey:
    var fd: Int32
    var directory_fd: Int32
    var name: List[Int8]
    var named: Bool

    def __init__(out self, directory_fd: Int32, name: String) raises:
        self.directory_fd = directory_fd
        self.name = c_path_bytes(name)
        self.named = False
        self.fd = external_call["openat64", Int32](directory_fd, self.name.unsafe_ptr(), Int32(655553), Int32(384))
        if self.fd < 0:
            raise Error("Cannot create private temporary key")
        self.named = True

    def remove_name(mut self) raises:
        if external_call["unlinkat", Int32](self.directory_fd, self.name.unsafe_ptr(), Int32(0)) != 0:
            raise Error("Cannot remove owned temporary key link")
        self.named = False

    def __deinit__(deinit self):
        _ = external_call["close", Int32](self.fd)
        if self.named:
            _ = external_call["unlinkat", Int32](self.directory_fd, self.name.unsafe_ptr(), Int32(0))


def create_service_key(path: String) raises:
    _ = c_path_bytes(path)
    # Independent random bytes for the 256-bit key and temporary filename.
    var random = InlineArray[UInt8, 48](fill=0)
    var offset = 0
    while offset < 48:
        var count = external_call["getrandom", Int](random.unsafe_ptr().unsafe_offset(offset), 48 - offset, UInt32(0))
        if count < 0 and io_errno() == 4:
            continue
        if count <= 0:
            raise Error("Cannot obtain operating-system randomness")
        offset += count
    var digits = String("0123456789abcdef")
    var output = InlineArray[Int8, 65](fill=10)
    for i in range(32):
        output[2 * i] = Int8(digits.as_bytes()[Int(random[i] >> 4)])
        output[2 * i + 1] = Int8(digits.as_bytes()[Int(random[i] & 15)])
    # Validate/open the parent before creating anything. No shell or subprocess.
    var parent = String(".")
    var filename = path
    var slash = -1
    for i in range(path.byte_length()):
        if path.as_bytes()[i] == 47:
            slash = i
    if slash >= 0:
        parent = String(path[byte=0:slash])
        filename = String(path[byte=slash + 1:])
        if parent == "":
            parent = "/"
    var parent_bytes = c_path_bytes(parent)
    var filename_bytes = c_path_bytes(filename)
    var directory = OwnedFD(external_call["open64", Int32](parent_bytes.unsafe_ptr(), Int32(589824), Int32(0)))
    _ = parent_bytes
    var temporary_name = String(".aesir-key-")
    for i in range(32, 48):
        var hi = Int(random[i] >> 4)
        var lo = Int(random[i] & 15)
        temporary_name += String(digits[byte=hi:hi + 1]) + String(digits[byte=lo:lo + 1])
    var file = TemporaryKey(directory.fd, temporary_name)
    offset = 0
    while offset < 65:
        var count = external_call["write", Int](Int(file.fd), output.unsafe_ptr().unsafe_offset(offset), 65 - offset)
        if count < 0 and io_errno() == 4:
            continue
        if count <= 0:
            raise Error("Service key write failed; output is not usable")
        offset += count
    if external_call["fsync", Int32](file.fd) != 0:
        raise Error("Service key synchronization failed")
    # Atomic no-replace publication relative to the same opened parent inode.
    if external_call["linkat", Int32](directory.fd, file.name.unsafe_ptr(), directory.fd, filename_bytes.unsafe_ptr(), Int32(0)) != 0:
        raise Error("Cannot publish service key; output must not already exist")
    _ = filename_bytes
    file.remove_name()
    if external_call["fsync", Int32](directory.fd) != 0:
        raise Error("Service key synchronization failed")
    _ = file
    _ = directory
