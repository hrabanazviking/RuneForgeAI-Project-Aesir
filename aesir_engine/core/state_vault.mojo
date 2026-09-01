# StateVault: strict restart-safe checkpoint marker storage for Linux

from std.collections import InlineArray
from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import alloc, Layout
from core.observation_integer import bounded_decimal


comptime VAULT_HEADER = "AESIR_STATE_MARKER_V1"
comptime MAX_VAULT_BYTES = 4096


def _vault_cstring(value: String) raises -> List[Int8]:
    if len(value.bytes()) == 0:
        raise Error("StateVault path must not be empty")
    var result = List[Int8]()
    for byte in value.as_bytes():
        if byte == 0:
            raise Error("StateVault path contains NUL")
        result.append(Int8(byte))
    result.append(0)
    return result^


def _vault_realtime_seconds() raises -> Int64:
    var timestamp = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(0), timestamp.unsafe_ptr()) != 0:
        raise Error("StateVault cannot observe the realtime clock")
    if timestamp[0] <= 0:
        raise Error("StateVault observed an invalid realtime timestamp")
    return timestamp[0]


def _vault_checksum(payload: String) -> UInt64:
    """Non-cryptographic corruption checksum over the canonical record body."""
    var checksum: UInt64 = 14695981039346656037
    for byte in payload.as_bytes():
        checksum = (checksum ^ UInt64(byte)) * 1099511628211
    return checksum


def _vault_hex(value: UInt64) -> String:
    var chars = String("0123456789abcdef")
    var result = String("")
    for shift in range(60, -4, -4):
        var nibble = Int((value >> UInt64(shift)) & 15)
        result += String(chars[byte=nibble : nibble + 1])
    return result


def _vault_parse_hex(value: String) raises -> UInt64:
    if len(value.bytes()) != 16:
        raise Error("StateVault checksum must contain 16 lowercase hex digits")
    var result: UInt64 = 0
    for byte in value.as_bytes():
        var nibble: Int
        if byte >= 48 and byte <= 57:
            nibble = Int(byte - 48)
        elif byte >= 97 and byte <= 102:
            nibble = Int(byte - 87)
        else:
            raise Error("StateVault checksum contains invalid hex data")
        result = (result << 4) | UInt64(nibble)
    return result


def _vault_parent(path: String) -> String:
    var last_slash = -1
    var source = path.as_bytes()
    for index in range(len(source)):
        if source[index] == 47:
            last_slash = index
    if last_slash < 0:
        return String(".")
    if last_slash == 0:
        return String("/")
    return String(path[byte=0:last_slash])


def _vault_write_all(fd: Int32, content: String) raises:
    var source = content.as_bytes()
    var offset = 0
    while offset < len(source):
        var written = external_call["pwrite", Int](
            fd, source.unsafe_ptr().unsafe_offset(offset),
            len(source) - offset, Int64(offset),
        )
        if written < 0:
            var errno_ptr = external_call[
                "__errno_location", Pointer[Int32, MutUntrackedOrigin]
            ]()
            if errno_ptr.unsafe_load() == 4:
                continue
            raise Error("StateVault staged checkpoint write failed")
        if written == 0:
            raise Error("StateVault staged checkpoint write made no progress")
        offset += written


def _vault_sync_parent(path: String) raises:
    var parent = _vault_cstring(_vault_parent(path))
    # O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC on supported Linux.
    var fd = external_call["open64", Int32](
        parent.unsafe_ptr(), Int32(720896), Int32(0)
    )
    if fd < 0:
        raise Error("StateVault cannot open checkpoint parent directory")
    var sync_result = external_call["fsync", Int32](fd)
    var close_result = external_call["close", Int32](fd)
    if sync_result != 0 or close_result != 0:
        raise Error("StateVault cannot synchronize checkpoint parent directory")


def _vault_atomic_write(path: String, content: String) raises:
    if len(content.bytes()) == 0 or len(content.bytes()) > MAX_VAULT_BYTES:
        raise Error("StateVault serialized marker has an invalid size")
    var target = _vault_cstring(path)
    var staged = _vault_cstring(path + ".tmp.XXXXXX")
    var fd = external_call["mkstemp", Int32](staged.unsafe_ptr())
    if fd < 0:
        raise Error("StateVault cannot create staged checkpoint")
    try:
        _vault_write_all(fd, content)
        if external_call["fsync", Int32](fd) != 0:
            raise Error("StateVault cannot synchronize staged checkpoint")
    except error:
        _ = external_call["close", Int32](fd)
        _ = external_call["unlink", Int32](staged.unsafe_ptr())
        raise error
    if external_call["close", Int32](fd) != 0:
        _ = external_call["unlink", Int32](staged.unsafe_ptr())
        raise Error("StateVault cannot close staged checkpoint")
    if external_call["rename", Int32](
        staged.unsafe_ptr(), target.unsafe_ptr()
    ) != 0:
        _ = external_call["unlink", Int32](staged.unsafe_ptr())
        raise Error("StateVault cannot atomically replace checkpoint")
    _vault_sync_parent(path)


def _vault_read(path: String) raises -> String:
    var encoded_path = _vault_cstring(path)
    # O_RDONLY | O_NOFOLLOW | O_CLOEXEC: the marker cannot be a symlink.
    var fd = external_call["open64", Int32](
        encoded_path.unsafe_ptr(), Int32(655360), Int32(0)
    )
    if fd < 0:
        raise Error("StateVault cannot open checkpoint")
    var buffer_alloc = alloc(Layout[Int8](count=MAX_VAULT_BYTES + 1))
    var buffer = buffer_alloc^.unsafe_leak()
    var size = 0
    while True:
        var count = external_call["pread", Int](
            fd, buffer.unsafe_offset(size), MAX_VAULT_BYTES + 1 - size,
            Int64(size),
        )
        if count < 0:
            var errno_ptr = external_call[
                "__errno_location", Pointer[Int32, MutUntrackedOrigin]
            ]()
            if errno_ptr.unsafe_load() == 4:
                continue
            buffer.unsafe_free()
            _ = external_call["close", Int32](fd)
            raise Error("StateVault checkpoint read failed")
        if count == 0:
            break
        size += count
        if size > MAX_VAULT_BYTES:
            buffer.unsafe_free()
            _ = external_call["close", Int32](fd)
            raise Error("StateVault checkpoint exceeds 4096 bytes")
    var close_result = external_call["close", Int32](fd)
    if close_result != 0:
        buffer.unsafe_free()
        raise Error("StateVault checkpoint close failed")
    if size == 0:
        buffer.unsafe_free()
        raise Error("StateVault checkpoint is empty")
    buffer.unsafe_store(size, 0)
    var content = String(unsafe_from_utf8_ptr=buffer)
    buffer.unsafe_free()
    return content


struct VaultCheckpoint(Copyable, ImplicitlyCopyable):
    """A position marker with a versioned corruption checksum."""
    var token_pos: Int
    var prompt_tokens_count: Int
    var checksum: UInt64
    var timestamp: Int64
    var is_valid: Bool

    def __init__(out self, token_pos: Int = 0, prompt_tokens_count: Int = 0,
                checksum: UInt64 = 0, timestamp: Int64 = 0,
                is_valid: Bool = False):
        self.token_pos = token_pos
        self.prompt_tokens_count = prompt_tokens_count
        self.checksum = checksum
        self.timestamp = timestamp
        self.is_valid = is_valid

    def __copyinit__(out self, existing: Self):
        self.token_pos = existing.token_pos
        self.prompt_tokens_count = existing.prompt_tokens_count
        self.checksum = existing.checksum
        self.timestamp = existing.timestamp
        self.is_valid = existing.is_valid


def _vault_body(token_pos: Int, prompt_count: Int, timestamp: Int64) -> String:
    return (
        String(VAULT_HEADER) + "\nTOKEN_POS=" + String(token_pos)
        + "\nPROMPT_COUNT=" + String(prompt_count)
        + "\nTIMESTAMP=" + String(timestamp)
    )


def _vault_make_checkpoint(
    token_pos: Int, prompt_count: Int, timestamp: Int64
) raises -> VaultCheckpoint:
    if token_pos < 0 or prompt_count < 0:
        raise Error("StateVault positions and counts must be non-negative")
    var observed_timestamp = timestamp
    if observed_timestamp == 0:
        observed_timestamp = _vault_realtime_seconds()
    if observed_timestamp < 0:
        raise Error("StateVault timestamp must be positive or zero for realtime observation")
    var checksum = _vault_checksum(
        _vault_body(token_pos, prompt_count, observed_timestamp)
    )
    return VaultCheckpoint(
        token_pos, prompt_count, checksum, observed_timestamp, True
    )


def _vault_serialize(checkpoint: VaultCheckpoint) raises -> String:
    if not checkpoint.is_valid:
        raise Error("StateVault cannot serialize an invalid marker")
    var body = _vault_body(
        checkpoint.token_pos, checkpoint.prompt_tokens_count,
        checkpoint.timestamp,
    )
    if _vault_checksum(body) != checkpoint.checksum:
        raise Error("StateVault marker checksum mismatch before serialization")
    return body + "\nCHECKSUM=" + _vault_hex(checkpoint.checksum)


def _vault_parse(content: String) raises -> VaultCheckpoint:
    if len(content.bytes()) == 0 or len(content.bytes()) > MAX_VAULT_BYTES:
        raise Error("StateVault checkpoint has an invalid size")
    var lines = content.split("\n")
    if len(lines) != 5 or String(lines[0]) != VAULT_HEADER:
        raise Error("StateVault checkpoint version or record count is invalid")
    var token_line = String(lines[1])
    var prompt_line = String(lines[2])
    var timestamp_line = String(lines[3])
    var checksum_line = String(lines[4])
    if (
        not token_line.startswith("TOKEN_POS=")
        or not prompt_line.startswith("PROMPT_COUNT=")
        or not timestamp_line.startswith("TIMESTAMP=")
        or not checksum_line.startswith("CHECKSUM=")
    ):
        raise Error("StateVault checkpoint fields are malformed or out of order")
    var token_pos = bounded_decimal(String(token_line[byte=10:]))
    var prompt_count = bounded_decimal(String(prompt_line[byte=13:]))
    var timestamp_value = bounded_decimal(String(timestamp_line[byte=10:]))
    if timestamp_value <= 0:
        raise Error("StateVault checkpoint timestamp must be positive")
    var checksum = _vault_parse_hex(String(checksum_line[byte=9:]))
    var checkpoint = VaultCheckpoint(
        token_pos, prompt_count, checksum, Int64(timestamp_value), True
    )
    var body = _vault_body(token_pos, prompt_count, Int64(timestamp_value))
    if _vault_checksum(body) != checksum:
        raise Error("StateVault checkpoint corruption checksum mismatch")
    return checkpoint^


struct StateVault(Copyable, ImplicitlyCopyable):
    """Transactional in-memory and restart-safe checkpoint marker storage.

    The marker contains positions only. It does not snapshot or restore model,
    tensor, KV-cache, process, thread, or socket state.
    """
    var is_checkpointed: Bool
    var active_checkpoint: VaultCheckpoint

    def __init__(out self):
        self.is_checkpointed = False
        self.active_checkpoint = VaultCheckpoint()

    def __copyinit__(out self, existing: Self):
        self.is_checkpointed = existing.is_checkpointed
        self.active_checkpoint = existing.active_checkpoint.copy()

    def save_checkpoint(
        mut self, token_pos: Int, prompt_count: Int, timestamp: Int64 = 0
    ) raises -> VaultCheckpoint:
        var checkpoint = _vault_make_checkpoint(
            token_pos, prompt_count, timestamp
        )
        self.active_checkpoint = checkpoint.copy()
        self.is_checkpointed = True
        return checkpoint^

    def restore_checkpoint_checked(self, checkpoint: VaultCheckpoint) raises -> Int:
        if not checkpoint.is_valid:
            raise Error("StateVault checkpoint marker is invalid")
        if (
            checkpoint.token_pos < 0
            or checkpoint.prompt_tokens_count < 0
            or checkpoint.timestamp <= 0
        ):
            raise Error("StateVault checkpoint marker fields are invalid")
        var body = _vault_body(
            checkpoint.token_pos, checkpoint.prompt_tokens_count,
            checkpoint.timestamp,
        )
        if _vault_checksum(body) != checkpoint.checksum:
            raise Error("StateVault checkpoint corruption checksum mismatch")
        return checkpoint.token_pos

    def restore_checkpoint(self) raises -> Int:
        if not self.is_checkpointed:
            raise Error("StateVault has no active checkpoint marker")
        return self.restore_checkpoint_checked(self.active_checkpoint)

    def save_checkpoint_to_disk(
        mut self, file_path: String, token_pos: Int, prompt_count: Int,
        timestamp: Int64 = 0,
    ) raises -> VaultCheckpoint:
        var checkpoint = _vault_make_checkpoint(
            token_pos, prompt_count, timestamp
        )
        _vault_atomic_write(file_path, _vault_serialize(checkpoint))
        self.active_checkpoint = checkpoint.copy()
        self.is_checkpointed = True
        return checkpoint^

    def load_checkpoint_from_disk(
        mut self, file_path: String
    ) raises -> VaultCheckpoint:
        var checkpoint = _vault_parse(_vault_read(file_path))
        self.active_checkpoint = checkpoint.copy()
        self.is_checkpointed = True
        return checkpoint^
