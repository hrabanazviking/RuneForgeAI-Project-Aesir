"""Optional atomic generations for native conversation crash recovery."""

from std.ffi import external_call
from std.memory import Pointer
from std.collections import InlineArray
from core.observation_integer import bounded_decimal
from core.text_admission import admit_text_bytes
from cli.conversation import (
    ConversationState,
    load_conversation,
    serialize_conversation,
)


comptime AUTOSAVE_HEADER = "AESIR_AUTOSAVE_V1"
comptime INFLIGHT_HEADER = "AESIR_AUTOSAVE_INFLIGHT_V1"
comptime AUTOSAVE_MANIFEST = "current"
comptime AUTOSAVE_INFLIGHT = "inflight"
comptime MAX_AUTOSAVE_CONTROL_BYTES = 65536
comptime MAX_AUTOSAVE_RETENTION = 64


def _autosave_cstring(value: String) raises -> List[Int8]:
    if value == "" or value.byte_length() >= 4096 or "\0" in value:
        raise Error("Autosave path must contain 1..4095 non-NUL bytes")
    var result = List[Int8]()
    for byte in value.as_bytes():
        result.append(Int8(byte))
    result.append(0)
    return result^


def _autosave_checksum(payload: String) -> UInt64:
    var value: UInt64 = 14695981039346656037
    for byte in payload.as_bytes():
        value = (value ^ UInt64(byte)) * 1099511628211
    return value


def _autosave_checksum_hex(value: UInt64) -> String:
    var alphabet = String("0123456789abcdef")
    var output = String("")
    for shift in range(60, -4, -4):
        var nibble = Int((value >> UInt64(shift)) & 15)
        output += String(alphabet[byte=nibble : nibble + 1])
    return output


def _autosave_checked_record(raw: String, header: String) raises:
    if raw.byte_length() == 0 or raw.byte_length() > MAX_AUTOSAVE_CONTROL_BYTES:
        raise Error("Autosave control record is outside its byte bound")
    var lines = raw.split("\n")
    if len(lines) < 3 or String(lines[0]) != header or String(lines[len(lines) - 1]) != "":
        raise Error("Autosave control record header or termination is invalid")
    var checksum_index = len(lines) - 2
    var checksum_line = String(lines[checksum_index])
    if not checksum_line.startswith("CHECKSUM:"):
        raise Error("Autosave control checksum is missing")
    var payload = String("")
    for index in range(checksum_index):
        payload += String(lines[index]) + "\n"
    if _autosave_checksum_hex(_autosave_checksum(payload)) != String(checksum_line[byte=9:]):
        raise Error("Autosave control checksum mismatch")


def _autosave_record(payload: String) -> String:
    return payload + "CHECKSUM:" + _autosave_checksum_hex(_autosave_checksum(payload)) + "\n"


def _autosave_read_optional(root_fd: Int32, name: String) raises -> String:
    var encoded = _autosave_cstring(name)
    # O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC.
    var fd = external_call["openat", Int32](root_fd, encoded.unsafe_ptr(), Int32(657408), Int32(0))
    if fd < 0:
        var errno_pointer = external_call["__errno_location", Pointer[Int32, MutUntrackedOrigin]]()
        if errno_pointer.unsafe_load() == 2:
            return ""
        raise Error("Unable to open autosave control record: " + name)
    var stat = InlineArray[UInt64, 18](fill=0)
    if external_call["fstat", Int32](fd, stat.unsafe_ptr()) != 0:
        _ = external_call["close", Int32](fd)
        raise Error("Unable to inspect autosave control record")
    var mode = stat[3] & 4294967295
    if mode & 61440 != 32768 or stat[6] == 0 or stat[6] > MAX_AUTOSAVE_CONTROL_BYTES:
        _ = external_call["close", Int32](fd)
        raise Error("Autosave control record must be a bounded regular file")
    var output = List[Byte]()
    var buffer = List[Byte]()
    buffer.resize(4096, 0)
    try:
        while True:
            var count = external_call["read", Int](Int(fd), buffer.unsafe_ptr(), 4096)
            if count == 0:
                break
            if count < 0:
                var errno_pointer = external_call["__errno_location", Pointer[Int32, MutUntrackedOrigin]]()
                if errno_pointer.unsafe_load() == 4:
                    continue
                raise Error("Autosave control record read failed")
            if len(output) + count > MAX_AUTOSAVE_CONTROL_BYTES:
                raise Error("Autosave control record exceeds its byte bound")
            for index in range(count):
                output.append(buffer[index])
    except error:
        _ = external_call["close", Int32](fd)
        raise error
    _ = external_call["close", Int32](fd)
    return admit_text_bytes(output, "autosave control record", MAX_AUTOSAVE_CONTROL_BYTES)


def _autosave_write_all(fd: Int32, content: String) raises:
    var bytes = content.as_bytes()
    var offset = 0
    while offset < len(bytes):
        var written = external_call["write", Int](Int(fd), bytes.unsafe_ptr().unsafe_offset(offset), len(bytes) - offset)
        if written <= 0:
            raise Error("Autosave write failed")
        offset += written


def _autosave_write_atomic(root_fd: Int32, target_name: String, content: String) raises:
    var pid = external_call["getpid", Int32]()
    var target = _autosave_cstring(target_name)
    var temporary = List[Int8]()
    var fd: Int32 = -1
    for attempt in range(1024):
        temporary = _autosave_cstring("." + target_name + "." + String(pid) + "." + String(attempt) + ".tmp")
        # O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, mode 0600.
        fd = external_call["openat", Int32](root_fd, temporary.unsafe_ptr(), Int32(655553), Int32(384))
        if fd >= 0:
            break
    if fd < 0:
        raise Error("Unable to create staged autosave control record")
    try:
        _autosave_write_all(fd, content)
        if external_call["fsync", Int32](fd) != 0:
            raise Error("Autosave control record synchronization failed")
    except error:
        _ = external_call["close", Int32](fd)
        _ = external_call["unlinkat", Int32](root_fd, temporary.unsafe_ptr(), Int32(0))
        raise error
    if external_call["close", Int32](fd) != 0:
        _ = external_call["unlinkat", Int32](root_fd, temporary.unsafe_ptr(), Int32(0))
        raise Error("Unable to close staged autosave control record")
    if external_call["renameat", Int32](root_fd, temporary.unsafe_ptr(), root_fd, target.unsafe_ptr()) != 0:
        _ = external_call["unlinkat", Int32](root_fd, temporary.unsafe_ptr(), Int32(0))
        raise Error("Unable to atomically publish autosave control record")
    if external_call["fsync", Int32](root_fd) != 0:
        raise Error("Autosave directory synchronization failed")


def _autosave_write_generation(root_fd: Int32, generation: Int, content: String) raises:
    var name = _autosave_cstring("generation-" + String(generation) + ".aesir")
    var fd = external_call["openat", Int32](root_fd, name.unsafe_ptr(), Int32(655553), Int32(384))
    if fd < 0:
        raise Error("Autosave generation already exists or cannot be created")
    try:
        _autosave_write_all(fd, content)
        if external_call["fsync", Int32](fd) != 0:
            raise Error("Autosave generation synchronization failed")
    except error:
        _ = external_call["close", Int32](fd)
        _ = external_call["unlinkat", Int32](root_fd, name.unsafe_ptr(), Int32(0))
        raise error
    if external_call["close", Int32](fd) != 0:
        _ = external_call["unlinkat", Int32](root_fd, name.unsafe_ptr(), Int32(0))
        raise Error("Unable to close autosave generation")
    if external_call["fsync", Int32](root_fd) != 0:
        raise Error("Autosave generation directory synchronization failed")


def _autosave_unlink(root_fd: Int32, name: String, missing_ok: Bool = False) raises:
    var encoded = _autosave_cstring(name)
    if external_call["unlinkat", Int32](root_fd, encoded.unsafe_ptr(), Int32(0)) != 0:
        var errno_pointer = external_call["__errno_location", Pointer[Int32, MutUntrackedOrigin]]()
        if not missing_ok or errno_pointer.unsafe_load() != 2:
            raise Error("Unable to remove owned autosave file: " + name)


def _serialize_manifest(retain: Int, generations: List[Int]) -> String:
    var ids = String("")
    for index in range(len(generations)):
        if index > 0:
            ids += ","
        ids += String(generations[index])
    return _autosave_record(
        AUTOSAVE_HEADER + "\nRETAIN:" + String(retain) + "\nGENERATIONS:" + ids + "\n"
    )


def _parse_manifest(raw: String) raises -> List[Int]:
    _autosave_checked_record(raw, AUTOSAVE_HEADER)
    var lines = raw.split("\n")
    if len(lines) != 5 or not String(lines[1]).startswith("RETAIN:") or not String(lines[2]).startswith("GENERATIONS:"):
        raise Error("Autosave manifest shape is invalid")
    var stored_retain = bounded_decimal(String(String(lines[1])[byte=7:]))
    if stored_retain < 1 or stored_retain > MAX_AUTOSAVE_RETENTION:
        raise Error("Autosave manifest retention is invalid")
    var generations = List[Int]()
    var text = String(String(lines[2])[byte=12:])
    if text != "":
        for field in text.split(","):
            var generation = bounded_decimal(String(field))
            if generation < 1 or generation > 2147483647:
                raise Error("Autosave generation ID is invalid")
            if len(generations) > 0 and generation <= generations[len(generations) - 1]:
                raise Error("Autosave generations are not strictly ordered")
            generations.append(generation)
    if len(generations) == 0 or len(generations) > stored_retain:
        raise Error("Autosave manifest generation count is invalid")
    return generations^


def _serialize_inflight(generation: Int, turn: Int) -> String:
    return _autosave_record(
        INFLIGHT_HEADER + "\nGENERATION:" + String(generation) + "\nTURN:" + String(turn) + "\n"
    )


def _parse_inflight(raw: String) raises -> Tuple[Int, Int]:
    _autosave_checked_record(raw, INFLIGHT_HEADER)
    var lines = raw.split("\n")
    if len(lines) != 5 or not String(lines[1]).startswith("GENERATION:") or not String(lines[2]).startswith("TURN:"):
        raise Error("Autosave inflight record shape is invalid")
    var generation = bounded_decimal(String(String(lines[1])[byte=11:]))
    var turn = bounded_decimal(String(String(lines[2])[byte=5:]))
    if generation < 1 or generation > 2147483647 or turn > 1024:
        raise Error("Autosave inflight record is outside its bounds")
    return (generation, turn)


struct ConversationAutosave:
    """One locked private autosave directory with an authoritative manifest."""

    var root_path: String
    var directory_fd: Int32
    var retain: Int
    var generations: List[Int]
    var inflight_generation: Int
    var inflight_turn: Int

    def __init__(out self, root_path: String = "", retain: Int = 3) raises:
        self.root_path = root_path
        self.directory_fd = -1
        self.retain = retain
        self.generations = List[Int]()
        self.inflight_generation = 0
        self.inflight_turn = 0
        if root_path == "":
            return
        if retain < 1 or retain > MAX_AUTOSAVE_RETENTION:
            raise Error("Autosave retention must be within 1..64")
        var encoded = _autosave_cstring(root_path)
        # O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC.
        self.directory_fd = external_call["open64", Int32](encoded.unsafe_ptr(), Int32(720896), Int32(0))
        if self.directory_fd < 0:
            raise Error("Autosave directory must already exist and must not be a symlink")
        var stat = InlineArray[UInt64, 18](fill=0)
        if external_call["fstat", Int32](self.directory_fd, stat.unsafe_ptr()) != 0:
            _ = external_call["close", Int32](self.directory_fd)
            self.directory_fd = -1
            raise Error("Unable to inspect autosave directory")
        var mode = stat[3] & 4294967295
        if mode & 61440 != 16384 or stat[3] >> 32 != UInt64(external_call["geteuid", UInt32]()) or mode & 63 != 0:
            _ = external_call["close", Int32](self.directory_fd)
            self.directory_fd = -1
            raise Error("Autosave directory must be owner-held with no group/world permissions")
        # LOCK_EX | LOCK_NB: a second session must fail instead of hanging.
        if external_call["flock", Int32](self.directory_fd, 6) != 0:
            _ = external_call["close", Int32](self.directory_fd)
            self.directory_fd = -1
            raise Error("Autosave directory is already in use or cannot be locked")
        var manifest = _autosave_read_optional(self.directory_fd, AUTOSAVE_MANIFEST)
        if manifest != "":
            self.generations = _parse_manifest(manifest)
        var inflight = _autosave_read_optional(self.directory_fd, AUTOSAVE_INFLIGHT)
        if inflight != "":
            var parsed = _parse_inflight(inflight)
            self.inflight_generation = parsed[0]
            self.inflight_turn = parsed[1]

    def __deinit__(deinit self):
        if self.directory_fd >= 0:
            _ = external_call["close", Int32](self.directory_fd)

    def enabled(self) -> Bool:
        return self.directory_fd >= 0

    def has_checkpoint(self) -> Bool:
        return len(self.generations) > 0

    def interrupted_generation(self) -> Int:
        if self.inflight_generation == 0:
            return 0
        for generation in self.generations:
            if generation == self.inflight_generation:
                return 0
        return self.inflight_generation

    def interrupted_turn_number(self) -> Int:
        if self.interrupted_generation() == 0:
            return 0
        return self.inflight_turn

    def load_latest(self) raises -> ConversationState:
        if not self.has_checkpoint():
            raise Error("Autosave has no committed generation")
        var generation = self.generations[len(self.generations) - 1]
        return load_conversation(
            "/proc/self/fd/" + String(self.directory_fd)
            + "/generation-" + String(generation) + ".aesir"
        )

    def discard_interrupted(mut self) raises:
        if self.inflight_generation == 0:
            return
        var committed = False
        for generation in self.generations:
            if generation == self.inflight_generation:
                committed = True
        if not committed:
            _autosave_unlink(
                self.directory_fd,
                "generation-" + String(self.inflight_generation) + ".aesir",
                missing_ok=True,
            )
        _autosave_unlink(self.directory_fd, AUTOSAVE_INFLIGHT)
        if external_call["fsync", Int32](self.directory_fd) != 0:
            raise Error("Autosave interruption cleanup synchronization failed")
        self.inflight_generation = 0
        self.inflight_turn = 0

    def begin(mut self, turn: Int) raises:
        if not self.enabled():
            return
        if turn < 0 or turn > 1024:
            raise Error("Autosave turn number is outside 0..1024")
        if self.inflight_generation != 0:
            raise Error("Autosave has an unresolved interrupted generation")
        var generation = 1
        if len(self.generations) > 0:
            generation = self.generations[len(self.generations) - 1] + 1
        if generation > 2147483647:
            raise Error("Autosave generation counter is exhausted")
        _autosave_write_atomic(
            self.directory_fd, AUTOSAVE_INFLIGHT,
            _serialize_inflight(generation, turn),
        )
        self.inflight_generation = generation
        self.inflight_turn = turn

    def commit(mut self, state: ConversationState) raises:
        if not self.enabled():
            return
        if self.inflight_generation == 0:
            raise Error("Autosave commit has no active generation")
        var generation = self.inflight_generation
        _autosave_write_generation(
            self.directory_fd, generation, serialize_conversation(state)
        )
        var start = max(0, len(self.generations) + 1 - self.retain)
        var retained = List[Int]()
        for index in range(start, len(self.generations)):
            retained.append(self.generations[index])
        retained.append(generation)
        _autosave_write_atomic(
            self.directory_fd, AUTOSAVE_MANIFEST,
            _serialize_manifest(self.retain, retained),
        )
        for index in range(start):
            _autosave_unlink(
                self.directory_fd,
                "generation-" + String(self.generations[index]) + ".aesir",
            )
        _autosave_unlink(self.directory_fd, AUTOSAVE_INFLIGHT)
        if external_call["fsync", Int32](self.directory_fd) != 0:
            raise Error("Autosave commit directory synchronization failed")
        self.generations = retained^
        self.inflight_generation = 0
        self.inflight_turn = 0

    def checkpoint(mut self, state: ConversationState, turn: Int) raises:
        if not self.enabled():
            return
        self.begin(turn)
        self.commit(state)


def validate_conversation_autosave(root_path: String, retain: Int) raises:
    """Fails before model allocation when an explicitly selected root is unsafe."""
    if root_path == "":
        return
    _ = ConversationAutosave(root_path, retain)
