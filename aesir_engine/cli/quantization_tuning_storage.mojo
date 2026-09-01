"""Linux durable storage boundary for quantized GEMM tuning cache records."""

from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import alloc, Layout

from core.quantization_autotuner import QuantizedGEMMAutotuner


comptime TUNING_CACHE_FILE = "quantization-tuning.v1"
comptime MAX_TUNING_CACHE_FILE_BYTES = 1024 * 1024


def _tuning_cstring(value: String) -> List[Int8]:
    var result = List[Int8]()
    var source = value.as_bytes()
    for index in range(len(source)):
        result.append(Int8(source[index]))
    result.append(0)
    return result^


def validate_tuning_cache_root(root: String) raises -> String:
    """Accept only bounded normalized relative directories."""
    if root.byte_length() == 0 or root.byte_length() > 1024:
        raise Error("quantization tuning cache root must be 1..1024 bytes")
    if root.startswith("/") or root.endswith("/") or "//" in root:
        raise Error("quantization tuning cache root must be normalized and relative")
    var segments = root.split("/")
    for segment_value in segments:
        var segment = String(segment_value)
        if segment == "" or segment == "." or segment == "..":
            raise Error("quantization tuning cache root contains unsafe segment")
        var bytes = segment.as_bytes()
        if len(bytes) > 128:
            raise Error("quantization tuning cache path segment exceeds 128 bytes")
        for index in range(len(bytes)):
            var code = Int(bytes[index])
            var allowed = (
                (code >= 48 and code <= 57)
                or (code >= 65 and code <= 90)
                or (code >= 97 and code <= 122)
                or code == 45
                or code == 46
                or code == 95
            )
            if not allowed:
                raise Error("quantization tuning cache root contains unsafe byte")
    return root


def _ensure_tuning_root(root: String) raises:
    var segments = root.split("/")
    var current = String("")
    for index in range(len(segments)):
        if current.byte_length() > 0:
            current += "/"
        current += String(segments[index])
        var current_bytes = _tuning_cstring(current)
        if external_call["mkdir", Int32](current_bytes.unsafe_ptr(), 448) != 0:
            var errno_pointer = external_call[
                "__errno_location", Pointer[Int32, MutUntrackedOrigin]
            ]()
            if errno_pointer.unsafe_load() != 17:
                raise Error("unable to create quantization tuning cache root")


def _lock_tuning_root(root: String) raises -> Int32:
    var root_bytes = _tuning_cstring(root)
    # O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
    var directory_fd = external_call["open64", Int32](
        root_bytes.unsafe_ptr(), Int32(720896), Int32(0)
    )
    if directory_fd < 0:
        raise Error("unable to open quantization tuning cache root")
    if external_call["flock", Int32](directory_fd, 2) != 0:
        _ = external_call["close", Int32](directory_fd)
        raise Error("unable to lock quantization tuning cache root")
    return directory_fd


def _sync_tuning_root(root: String) raises:
    var root_bytes = _tuning_cstring(root)
    var directory_fd = external_call["open64", Int32](
        root_bytes.unsafe_ptr(), Int32(720896), Int32(0)
    )
    if directory_fd < 0:
        raise Error("unable to open quantization tuning cache root for sync")
    var sync_result = external_call["fsync", Int32](directory_fd)
    _ = external_call["close", Int32](directory_fd)
    if sync_result != 0:
        raise Error("unable to synchronize quantization tuning cache root")


def _read_tuning_cache(path: String) raises -> String:
    var path_bytes = _tuning_cstring(path)
    # O_RDONLY | O_NOFOLLOW | O_CLOEXEC
    var fd = external_call["open64", Int32](
        path_bytes.unsafe_ptr(), Int32(655360), Int32(0)
    )
    if fd < 0:
        var errno_pointer = external_call[
            "__errno_location", Pointer[Int32, MutUntrackedOrigin]
        ]()
        if errno_pointer.unsafe_load() == 2:
            return String("")
        raise Error("unable to open quantization tuning cache")
    var content = List[Int8]()
    var buffer_alloc = alloc(Layout[Int8](count=4096))
    var buffer = buffer_alloc^.unsafe_leak()
    var offset = 0
    while True:
        var read_count = external_call["pread", Int](
            fd, buffer, 4096, Int64(offset)
        )
        if read_count < 0:
            var errno_pointer = external_call[
                "__errno_location", Pointer[Int32, MutUntrackedOrigin]
            ]()
            if errno_pointer.unsafe_load() == 4:
                continue
            buffer.unsafe_free()
            _ = external_call["close", Int32](fd)
            raise Error("failed while reading quantization tuning cache")
        if read_count == 0:
            break
        offset += Int(read_count)
        if len(content) + Int(read_count) > MAX_TUNING_CACHE_FILE_BYTES:
            buffer.unsafe_free()
            _ = external_call["close", Int32](fd)
            raise Error("quantization tuning cache exceeds 1 MiB")
        for index in range(Int(read_count)):
            content.append(buffer.unsafe_load(index))
    buffer.unsafe_free()
    if external_call["close", Int32](fd) != 0:
        raise Error("unable to close quantization tuning cache")
    content.append(0)
    return String(unsafe_from_utf8_ptr=content.unsafe_ptr())


def _write_tuning_bytes(fd: Int32, content: String) raises:
    var source = content.as_bytes()
    if len(source) == 0 or len(source) > MAX_TUNING_CACHE_FILE_BYTES:
        raise Error("quantization tuning cache write size is invalid")
    var offset = 0
    while offset < len(source):
        var written = external_call["pwrite", Int](
            fd,
            source.unsafe_ptr().unsafe_offset(offset),
            len(source) - offset,
            Int64(offset),
        )
        if written < 0:
            var errno_pointer = external_call[
                "__errno_location", Pointer[Int32, MutUntrackedOrigin]
            ]()
            if errno_pointer.unsafe_load() == 4:
                continue
            raise Error("failed while writing staged quantization tuning cache")
        if written == 0:
            raise Error("staged quantization tuning cache write made no progress")
        offset += Int(written)


def _atomic_write_tuning_cache(root: String, content: String) raises:
    var target_path = root + "/" + TUNING_CACHE_FILE
    var temporary_path = root + "/.quantization-tuning.tmp.XXXXXX"
    var target_bytes = _tuning_cstring(target_path)
    var temporary_bytes = _tuning_cstring(temporary_path)
    var fd = external_call["mkstemp", Int32](temporary_bytes.unsafe_ptr())
    if fd < 0:
        raise Error("unable to create staged quantization tuning cache")
    try:
        _write_tuning_bytes(fd, content)
        if external_call["fsync", Int32](fd) != 0:
            raise Error("unable to synchronize staged quantization tuning cache")
    except error:
        _ = external_call["close", Int32](fd)
        _ = external_call["unlink", Int32](temporary_bytes.unsafe_ptr())
        raise error
    if external_call["close", Int32](fd) != 0:
        _ = external_call["unlink", Int32](temporary_bytes.unsafe_ptr())
        raise Error("unable to close staged quantization tuning cache")
    if external_call["rename", Int32](
        temporary_bytes.unsafe_ptr(), target_bytes.unsafe_ptr()
    ) != 0:
        _ = external_call["unlink", Int32](temporary_bytes.unsafe_ptr())
        raise Error("unable to atomically publish quantization tuning cache")
    _sync_tuning_root(root)


struct DurableQuantizationTuningCache(Copyable):
    """Atomic caller-facing persistence for the core cache codec."""

    var root_path: String
    var build_fingerprint: String

    def __init__(
        out self, root_path: String, build_fingerprint: String
    ) raises:
        self.root_path = validate_tuning_cache_root(root_path)
        # Empty caches still serialize, which validates the fingerprint now.
        var validator = QuantizedGEMMAutotuner(max_entries=1)
        _ = validator.serialize_cache(build_fingerprint)
        self.build_fingerprint = build_fingerprint

    def __copyinit__(out self, existing: Self):
        self.root_path = existing.root_path
        self.build_fingerprint = existing.build_fingerprint

    def save(self, tuner: QuantizedGEMMAutotuner) raises:
        var content = tuner.serialize_cache(self.build_fingerprint)
        _ensure_tuning_root(self.root_path)
        var lock_fd = _lock_tuning_root(self.root_path)
        try:
            _atomic_write_tuning_cache(self.root_path, content)
        except error:
            _ = external_call["close", Int32](lock_fd)
            raise error
        _ = external_call["close", Int32](lock_fd)

    def load(self, mut tuner: QuantizedGEMMAutotuner) raises -> Bool:
        _ensure_tuning_root(self.root_path)
        var lock_fd = _lock_tuning_root(self.root_path)
        var content = String("")
        try:
            content = _read_tuning_cache(
                self.root_path + "/" + TUNING_CACHE_FILE
            )
            if content.byte_length() > 0:
                tuner.restore_cache(content, self.build_fingerprint)
        except error:
            _ = external_call["close", Int32](lock_fd)
            raise error
        _ = external_call["close", Int32](lock_fd)
        return content.byte_length() > 0
