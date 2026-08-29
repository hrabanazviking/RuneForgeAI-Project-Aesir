# cli/storage.mojo
# Linux durable-catalog boundary for Project A.E.S.I.R.

from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import alloc, Layout
from std.collections import Dict
from config import validate_model_store_path
from cli.manifest import (
    ModelManifest,
    RuneModelStore,
    deserialize_manifest,
    normalize_model_reference,
)


comptime CATALOG_FILE = "catalog.v1"
comptime CATALOG_HEADER = "AESIR_MODEL_CATALOG_V1"
comptime MAX_CATALOG_BYTES = 16 * 1024 * 1024
comptime MAX_CATALOG_ENTRIES = 10000


def _cstring(value: String) -> List[Int8]:
    var result = List[Int8]()
    var source = value.as_bytes()
    for index in range(len(source)):
        result.append(Int8(source[index]))
    result.append(0)
    return result^


def validate_store_root(root_path: String) raises -> String:
    """Delegates store-root validation to the authoritative config schema."""
    return validate_model_store_path(root_path)


def _hex_encode(value: String) -> String:
    var chars = String("0123456789abcdef")
    var result = String("")
    var source = value.as_bytes()
    for index in range(len(source)):
        var code = Int(source[index])
        result += String(chars[byte=code >> 4 : (code >> 4) + 1])
        result += String(chars[byte=code & 15 : (code & 15) + 1])
    return result


def _hex_nibble(code: Int) raises -> Int:
    if code >= 48 and code <= 57:
        return code - 48
    if code >= 97 and code <= 102:
        return code - 87
    raise Error("catalog entry contains non-lowercase-hex data")


def _hex_decode(value: String) raises -> String:
    var source = value.as_bytes()
    if len(source) % 2 != 0:
        raise Error("catalog entry contains an odd number of hex digits")
    if len(source) > 8 * 1024 * 1024:
        raise Error("catalog manifest exceeds the 4 MiB decoded limit")
    var decoded = List[Int8]()
    for index in range(0, len(source), 2):
        var high = _hex_nibble(Int(source[index]))
        var low = _hex_nibble(Int(source[index + 1]))
        decoded.append(Int8((high << 4) | low))
    decoded.append(0)
    return String(unsafe_from_utf8_ptr=decoded.unsafe_ptr())


def _parse_count(value: String) raises -> Int:
    var source = value.as_bytes()
    if len(source) == 0:
        raise Error("catalog entry count must not be empty")
    for index in range(len(source)):
        var code = Int(source[index])
        if code < 48 or code > 57:
            raise Error("catalog entry count must be decimal")
    var count: Int
    try:
        count = atol(value)
    except:
        raise Error("catalog entry count is outside the supported range")
    if count < 0 or count > MAX_CATALOG_ENTRIES:
        raise Error("catalog entry count exceeds the supported limit")
    return count


def serialize_catalog(store: RuneModelStore) raises -> String:
    """Encodes a bounded, delimiter-safe v1 catalog."""
    if len(store.model_keys) > MAX_CATALOG_ENTRIES:
        raise Error("catalog entry count exceeds the supported limit")
    var lines = List[String]()
    var seen = Dict[String, Bool]()
    lines.append(CATALOG_HEADER)
    lines.append("COUNT:" + String(len(store.model_keys)))
    for index in range(len(store.model_keys)):
        var key = store.model_keys[index]
        if key not in store.catalog:
            raise Error("catalog key has no manifest: " + key)
        if key in seen:
            raise Error("catalog contains duplicate key: " + key)
        seen[key] = True
        var manifest = store.catalog[key]
        var normalized = normalize_model_reference(
            manifest.name + ":" + manifest.tag
        )
        if normalized != key:
            raise Error("catalog key does not match its manifest identity")
        lines.append("ENTRY:" + _hex_encode(manifest.serialize()))
    var encoded = String("\n").join(lines)
    if len(encoded.bytes()) > MAX_CATALOG_BYTES:
        raise Error("serialized catalog exceeds the 16 MiB limit")
    return encoded


def deserialize_catalog(raw: String) raises -> RuneModelStore:
    """Strictly parses a bounded v1 catalog and rejects duplicate identities."""
    if len(raw.bytes()) == 0:
        raise Error("model catalog is empty")
    if len(raw.bytes()) > MAX_CATALOG_BYTES:
        raise Error("model catalog exceeds the 16 MiB limit")
    var lines = raw.split("\n")
    if len(lines) < 2 or String(lines[0]) != CATALOG_HEADER:
        raise Error("unsupported or missing model catalog version")
    var count_line = String(lines[1])
    if not count_line.startswith("COUNT:"):
        raise Error("model catalog is missing its entry count")
    var count = _parse_count(String(count_line[byte=6:]))
    if len(lines) != count + 2:
        raise Error("model catalog entry count does not match its records")

    var store = RuneModelStore()
    for index in range(count):
        var line = String(lines[index + 2])
        if not line.startswith("ENTRY:"):
            raise Error("model catalog record is malformed")
        var manifest = deserialize_manifest(
            _hex_decode(String(line[byte=6:]))
        )
        var key = normalize_model_reference(
            manifest.name + ":" + manifest.tag
        )
        if key in store.catalog:
            raise Error("model catalog contains duplicate identity: " + key)
        store.catalog[key] = manifest.copy()
        store.model_keys.append(key)
    return store^


def _read_optional_text(path: String) raises -> String:
    var path_bytes = _cstring(path)
    var fd = external_call["open", Int32](path_bytes.unsafe_ptr(), 0)
    if fd < 0:
        var errno_pointer = external_call[
            "__errno_location", Pointer[Int32, MutUntrackedOrigin]
        ]()
        if errno_pointer.unsafe_load() == 2:
            return String("")
        raise Error("unable to open model catalog: " + path)
    var content = List[Int8]()
    var buffer_alloc = alloc(Layout[Int8](count=4096))
    var buffer = buffer_alloc^.unsafe_leak()
    while True:
        var read_count = external_call["read", Int64](fd, buffer, 4096)
        if read_count < 0:
            buffer.unsafe_free()
            _ = external_call["close", Int32](fd)
            raise Error("failed while reading model catalog: " + path)
        if read_count == 0:
            break
        if len(content) + Int(read_count) > MAX_CATALOG_BYTES:
            buffer.unsafe_free()
            _ = external_call["close", Int32](fd)
            raise Error("model catalog exceeds the 16 MiB limit")
        for index in range(Int(read_count)):
            content.append(buffer.unsafe_load(index))
    buffer.unsafe_free()
    _ = external_call["close", Int32](fd)
    content.append(0)
    return String(unsafe_from_utf8_ptr=content.unsafe_ptr())


def _write_all(fd: Int32, content: String) raises:
    var source = content.as_bytes()
    var offset = 0
    while offset < len(source):
        var written = external_call["pwrite", Int](
            fd,
            source.unsafe_ptr().unsafe_offset(offset),
            len(source) - offset,
            Int64(offset),
        )
        if written <= 0:
            raise Error("failed while writing staged model catalog")
        offset += Int(written)


def _ensure_store_root(root: String) raises:
    var segments = root.split("/")
    var current = String("")
    for index in range(len(segments)):
        if len(current.bytes()) > 0:
            current += "/"
        current += String(segments[index])
        var current_bytes = _cstring(current)
        if external_call["mkdir", Int32](
            current_bytes.unsafe_ptr(), 448
        ) != 0:
            var errno_pointer = external_call[
                "__errno_location", Pointer[Int32, MutUntrackedOrigin]
            ]()
            if errno_pointer.unsafe_load() != 17:
                raise Error("unable to create model store root: " + current)


def _lock_store_root(root: String) raises -> Int32:
    var root_bytes = _cstring(root)
    var directory_fd = external_call["open", Int32](
        root_bytes.unsafe_ptr(), 65536
    )
    if directory_fd < 0:
        raise Error("unable to open model store root for locking")
    if external_call["flock", Int32](directory_fd, 2) != 0:
        _ = external_call["close", Int32](directory_fd)
        raise Error("unable to lock model store root")
    return directory_fd


def _sync_directory(root: String) raises:
    var root_bytes = _cstring(root)
    var directory_fd = external_call["open", Int32](
        root_bytes.unsafe_ptr(), 65536
    )
    if directory_fd < 0:
        raise Error("unable to open model store root for synchronization")
    var sync_result = external_call["fsync", Int32](directory_fd)
    _ = external_call["close", Int32](directory_fd)
    if sync_result != 0:
        raise Error("unable to synchronize model store root")


def _atomic_write_catalog(root: String, content: String) raises:
    _ensure_store_root(root)
    var target_path = root + "/" + CATALOG_FILE
    var temporary_path = root + "/.catalog.tmp.XXXXXX"
    var target_bytes = _cstring(target_path)
    var temporary_bytes = _cstring(temporary_path)
    var fd = external_call["mkstemp", Int32](temporary_bytes.unsafe_ptr())
    if fd < 0:
        raise Error("unable to create staged model catalog")

    try:
        _write_all(fd, content)
        if external_call["fsync", Int32](fd) != 0:
            raise Error("unable to synchronize staged model catalog")
    except error:
        _ = external_call["close", Int32](fd)
        _ = external_call["unlink", Int32](temporary_bytes.unsafe_ptr())
        raise error

    if external_call["close", Int32](fd) != 0:
        _ = external_call["unlink", Int32](temporary_bytes.unsafe_ptr())
        raise Error("unable to close staged model catalog")
    if external_call["rename", Int32](
        temporary_bytes.unsafe_ptr(), target_bytes.unsafe_ptr()
    ) != 0:
        _ = external_call["unlink", Int32](temporary_bytes.unsafe_ptr())
        raise Error("unable to atomically replace model catalog")
    _sync_directory(root)


def _load_store(root: String) raises -> RuneModelStore:
    var raw = _read_optional_text(root + "/" + CATALOG_FILE)
    if len(raw.bytes()) == 0:
        return RuneModelStore()
    return deserialize_catalog(raw)


struct DurableModelStore:
    """Restart-safe catalog whose mutations commit through atomic replacement."""

    var root_path: String
    var store: RuneModelStore

    def __init__(out self, root_path: String) raises:
        self.root_path = validate_store_root(root_path)
        self.store = _load_store(self.root_path)

    def list_models(self) raises -> List[ModelManifest]:
        return _load_store(self.root_path).list_models()

    def get_model(self, name: String) raises -> ModelManifest:
        return _load_store(self.root_path).get_model(name)

    def create_model(
        mut self, name: String, modelfile_content: String
    ) raises:
        _ensure_store_root(self.root_path)
        var lock_fd = _lock_store_root(self.root_path)
        var candidate = RuneModelStore()
        try:
            candidate = _load_store(self.root_path)
            candidate.create_model(name, modelfile_content)
            _atomic_write_catalog(self.root_path, serialize_catalog(candidate))
        except error:
            _ = external_call["close", Int32](lock_fd)
            raise error
        _ = external_call["close", Int32](lock_fd)
        self.store = candidate^

    def copy_model(mut self, source: String, target: String) raises:
        _ensure_store_root(self.root_path)
        var lock_fd = _lock_store_root(self.root_path)
        var candidate = RuneModelStore()
        try:
            candidate = _load_store(self.root_path)
            candidate.copy_model(source, target)
            _atomic_write_catalog(self.root_path, serialize_catalog(candidate))
        except error:
            _ = external_call["close", Int32](lock_fd)
            raise error
        _ = external_call["close", Int32](lock_fd)
        self.store = candidate^

    def remove_model(mut self, name: String) raises:
        _ensure_store_root(self.root_path)
        var lock_fd = _lock_store_root(self.root_path)
        var candidate = RuneModelStore()
        try:
            candidate = _load_store(self.root_path)
            candidate.remove_model_checked(name)
            _atomic_write_catalog(self.root_path, serialize_catalog(candidate))
        except error:
            _ = external_call["close", Int32](lock_fd)
            raise error
        _ = external_call["close", Int32](lock_fd)
        self.store = candidate^
