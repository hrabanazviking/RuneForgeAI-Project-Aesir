# cli/storage.mojo
# Linux durable-catalog boundary for Project A.E.S.I.R.

from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import alloc, Layout
from std.collections import Dict
from core.posix_process import run_checked_argv_bytes
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
comptime BLOB_DIRECTORY = "blobs"
comptime SHA256_DIRECTORY = "sha256"
comptime BLOB_COPY_BUFFER_BYTES = 1024 * 1024


struct BlobRecord(Copyable):
    """Measured identity of one immutable content-addressed model blob."""

    var digest: String
    var size_bytes: Int64
    var created: Bool

    def __init__(
        out self, digest: String, size_bytes: Int64, created: Bool
    ):
        self.digest = digest
        self.size_bytes = size_bytes
        self.created = created

    def __copyinit__(out self, existing: Self):
        self.digest = existing.digest
        self.size_bytes = existing.size_bytes
        self.created = existing.created

    def copy(self) -> Self:
        return Self(self.digest, self.size_bytes, self.created)


struct BlobGCResult(Copyable):
    """Exact outcome of one locked content-addressed reachability sweep."""

    var scanned_blobs: Int
    var referenced_blobs: Int
    var removed_blobs: Int
    var removed_stages: Int
    var reclaimed_bytes: Int64

    def __init__(
        out self,
        scanned_blobs: Int,
        referenced_blobs: Int,
        removed_blobs: Int,
        removed_stages: Int,
        reclaimed_bytes: Int64,
    ):
        self.scanned_blobs = scanned_blobs
        self.referenced_blobs = referenced_blobs
        self.removed_blobs = removed_blobs
        self.removed_stages = removed_stages
        self.reclaimed_bytes = reclaimed_bytes

    def __copyinit__(out self, existing: Self):
        self.scanned_blobs = existing.scanned_blobs
        self.referenced_blobs = existing.referenced_blobs
        self.removed_blobs = existing.removed_blobs
        self.removed_stages = existing.removed_stages
        self.reclaimed_bytes = existing.reclaimed_bytes

    def copy(self) -> Self:
        return Self(
            self.scanned_blobs,
            self.referenced_blobs,
            self.removed_blobs,
            self.removed_stages,
            self.reclaimed_bytes,
        )


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
    # O_RDONLY | O_NOFOLLOW | O_CLOEXEC. A catalog must be the named file,
    # never a final symlink selected by another process.
    var fd = external_call["open64", Int32](
        path_bytes.unsafe_ptr(), Int32(655360), Int32(0)
    )
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
    var offset = Int(0)
    while True:
        var read_count = external_call["pread", Int](fd, buffer, 4096, offset)
        if read_count < 0:
            var errno_pointer = external_call[
                "__errno_location", Pointer[Int32, MutUntrackedOrigin]
            ]()
            if errno_pointer.unsafe_load() == 4:
                continue
            buffer.unsafe_free()
            _ = external_call["close", Int32](fd)
            raise Error("failed while reading model catalog: " + path)
        if read_count == 0:
            break
        offset += Int(read_count)
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
        if written < 0:
            var errno_pointer = external_call[
                "__errno_location", Pointer[Int32, MutUntrackedOrigin]
            ]()
            if errno_pointer.unsafe_load() == 4:
                continue
            raise Error("failed while writing staged model catalog")
        if written == 0:
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
    var directory_fd = external_call["open64", Int32](
        root_bytes.unsafe_ptr(), Int32(720896), Int32(0)
    )
    if directory_fd < 0:
        raise Error("unable to open model store root for locking")
    if external_call["flock", Int32](directory_fd, 2) != 0:
        _ = external_call["close", Int32](directory_fd)
        raise Error("unable to lock model store root")
    return directory_fd


@always_inline
def _errno() -> Int32:
    return external_call[
        "__errno_location", Pointer[Int32, MutUntrackedOrigin]
    ]().unsafe_load()


def _open_child_directory(parent_fd: Int32, name: String) raises -> Int32:
    """Creates or opens one owner-only directory without following a symlink."""
    var name_bytes = _cstring(name)
    if external_call["mkdirat", Int32](
        parent_fd, name_bytes.unsafe_ptr(), Int32(448)
    ) != 0 and _errno() != 17:
        raise Error("unable to create model blob directory: " + name)
    # O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC.
    var directory_fd = external_call["openat", Int32](
        parent_fd, name_bytes.unsafe_ptr(), Int32(720896), Int32(0)
    )
    if directory_fd < 0:
        raise Error("model blob directory is not a safe directory: " + name)
    return directory_fd


def _open_sha256_directory(root_fd: Int32) raises -> Int32:
    var blob_fd = _open_child_directory(root_fd, BLOB_DIRECTORY)
    var sha_fd: Int32
    try:
        sha_fd = _open_child_directory(blob_fd, SHA256_DIRECTORY)
    except error:
        _ = external_call["close", Int32](blob_fd)
        raise error
    _ = external_call["close", Int32](blob_fd)
    return sha_fd


def _validate_sha256_hex(digest: String) raises:
    if len(digest.bytes()) != 64:
        raise Error("model blob SHA-256 must contain 64 lowercase hex digits")
    for byte in digest.as_bytes():
        if not (
            (byte >= 48 and byte <= 57) or (byte >= 97 and byte <= 102)
        ):
            raise Error("model blob SHA-256 must be lowercase hexadecimal")


def _digest_open_fd(fd: Int32) raises -> String:
    """Hashes the exact open inode through an inherited descriptor."""
    if external_call["lseek", Int64](fd, Int64(0), Int32(0)) < 0:
        raise Error("unable to rewind model blob for hashing")
    # POSIX dup clears close-on-exec, allowing sha256sum to open this exact
    # descriptor through procfs without resolving a caller-controlled path.
    var inherited_fd = external_call["dup", Int32](fd)
    if inherited_fd < 0:
        raise Error("unable to duplicate model blob descriptor for hashing")
    var output: List[Byte]
    try:
        output = run_checked_argv_bytes(
            [
                "sha256sum",
                "--zero",
                "--",
                "/proc/self/fd/" + String(inherited_fd),
            ],
            4096,
        )
    except error:
        _ = external_call["close", Int32](inherited_fd)
        raise error
    _ = external_call["close", Int32](inherited_fd)
    if len(output) < 66:
        raise Error("sha256sum returned a malformed model blob digest")
    var digest_bytes = List[Int8]()
    for index in range(64):
        digest_bytes.append(Int8(output[index]))
    digest_bytes.append(0)
    var digest = String(unsafe_from_utf8_ptr=digest_bytes.unsafe_ptr())
    _validate_sha256_hex(digest)
    return digest


def _verify_blob_fd(fd: Int32, digest: String, size_bytes: Int64) raises:
    var actual_size = external_call["lseek", Int64](
        fd, Int64(0), Int32(2)
    )
    if actual_size != size_bytes:
        raise Error("stored model blob size does not match its catalog record")
    if _digest_open_fd(fd) != digest:
        raise Error("stored model blob SHA-256 does not match its address")


def _open_blob_by_digest(
    sha_directory_fd: Int32, digest: String
) raises -> Int32:
    _validate_sha256_hex(digest)
    var digest_bytes = _cstring(digest)
    # O_RDONLY | O_NOFOLLOW | O_CLOEXEC.
    var fd = external_call["openat", Int32](
        sha_directory_fd,
        digest_bytes.unsafe_ptr(),
        Int32(655360),
        Int32(0),
    )
    if fd < 0:
        raise Error("referenced model blob is missing: sha256:" + digest)
    return fd


def _ingest_blob_locked(root_fd: Int32, source_path: String) raises -> BlobRecord:
    """Copies, hashes, and exclusively publishes one immutable source inode."""
    var clean_source = String(source_path.strip())
    if (
        len(clean_source.bytes()) == 0
        or len(clean_source.bytes()) >= 4096
        or "\0" in clean_source
    ):
        raise Error("model blob source path must contain 1..4095 non-NUL bytes")
    var source_bytes = _cstring(clean_source)
    # O_RDONLY | O_NOFOLLOW | O_CLOEXEC rejects a final symlink.
    var source_fd = external_call["open64", Int32](
        source_bytes.unsafe_ptr(), Int32(655360), Int32(0)
    )
    if source_fd < 0:
        raise Error("unable to open model blob source: " + clean_source)
    var expected_size = external_call["lseek", Int64](
        source_fd, Int64(0), Int32(2)
    )
    if expected_size <= 0:
        _ = external_call["close", Int32](source_fd)
        raise Error("model blob source must be a non-empty seekable file")
    if external_call["lseek", Int64](
        source_fd, Int64(0), Int32(0)
    ) != 0:
        _ = external_call["close", Int32](source_fd)
        raise Error("unable to rewind model blob source")

    var sha_directory_fd: Int32 = -1
    var staged_fd: Int32 = -1
    var staged_name_bytes = List[Int8]()
    var published_digest_bytes = List[Int8]()
    var created = False
    var buffer_allocation = alloc(
        Layout[Int8](count=BLOB_COPY_BUFFER_BYTES)
    )
    var buffer = buffer_allocation^.unsafe_leak()
    var buffer_owned = True
    try:
        sha_directory_fd = _open_sha256_directory(root_fd)
        var pid = external_call["getpid", Int32]()
        for attempt in range(1024):
            staged_name_bytes = _cstring(
                ".ingest." + String(pid) + "." + String(attempt) + ".tmp"
            )
            # O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC.
            staged_fd = external_call["openat", Int32](
                sha_directory_fd,
                staged_name_bytes.unsafe_ptr(),
                Int32(655553),
                Int32(384),
            )
            if staged_fd >= 0:
                break
            if _errno() != 17:
                raise Error("unable to create staged model blob")
        if staged_fd < 0:
            raise Error("unable to reserve a unique staged model blob")

        var total: Int64 = 0
        while True:
            var count = external_call["read", Int](
                Int(source_fd), buffer, BLOB_COPY_BUFFER_BYTES
            )
            if count < 0:
                if _errno() == 4:
                    continue
                raise Error("failed while reading model blob source")
            if count == 0:
                break
            if total > 9223372036854775807 - Int64(count):
                raise Error("model blob byte count overflow")
            var written_total = 0
            while written_total < count:
                var written = external_call["write", Int](
                    Int(staged_fd),
                    buffer.unsafe_offset(written_total),
                    count - written_total,
                )
                if written < 0:
                    if _errno() == 4:
                        continue
                    raise Error("failed while writing staged model blob")
                if written == 0:
                    raise Error("staged model blob write made no progress")
                written_total += written
            total += Int64(count)
        buffer.unsafe_free()
        buffer_owned = False
        if total != expected_size:
            raise Error("model blob source changed while it was being copied")
        if external_call["fchmod", Int32](staged_fd, Int32(256)) != 0:
            raise Error("unable to make staged model blob read-only")
        if external_call["fsync", Int32](staged_fd) != 0:
            raise Error("unable to synchronize staged model blob")
        var digest = _digest_open_fd(staged_fd)
        published_digest_bytes = _cstring(digest)
        if external_call["linkat", Int32](
            sha_directory_fd,
            staged_name_bytes.unsafe_ptr(),
            sha_directory_fd,
            published_digest_bytes.unsafe_ptr(),
            Int32(0),
        ) == 0:
            created = True
        elif _errno() == 17:
            var existing_fd = _open_blob_by_digest(sha_directory_fd, digest)
            try:
                _verify_blob_fd(existing_fd, digest, total)
            except error:
                _ = external_call["close", Int32](existing_fd)
                raise error
            _ = external_call["close", Int32](existing_fd)
        else:
            raise Error("unable to publish content-addressed model blob")
        if external_call["fsync", Int32](sha_directory_fd) != 0:
            raise Error("unable to synchronize model blob directory")
        if external_call["unlinkat", Int32](
            sha_directory_fd, staged_name_bytes.unsafe_ptr(), Int32(0)
        ) != 0:
            raise Error("model blob published but staging cleanup failed")
        _ = external_call["close", Int32](staged_fd)
        _ = external_call["close", Int32](sha_directory_fd)
        _ = external_call["close", Int32](source_fd)
        return BlobRecord("sha256:" + digest, total, created)
    except error:
        if buffer_owned:
            buffer.unsafe_free()
        if staged_fd >= 0:
            _ = external_call["close", Int32](staged_fd)
        if sha_directory_fd >= 0 and created and len(published_digest_bytes) > 0:
            _ = external_call["unlinkat", Int32](
                sha_directory_fd,
                published_digest_bytes.unsafe_ptr(),
                Int32(0),
            )
            _ = external_call["fsync", Int32](sha_directory_fd)
        if sha_directory_fd >= 0 and len(staged_name_bytes) > 0:
            _ = external_call["unlinkat", Int32](
                sha_directory_fd, staged_name_bytes.unsafe_ptr(), Int32(0)
            )
        if sha_directory_fd >= 0:
            _ = external_call["close", Int32](sha_directory_fd)
        _ = external_call["close", Int32](source_fd)
        raise error


def _verify_blob_locked(
    root_fd: Int32, digest_with_prefix: String, size_bytes: Int64
) raises:
    if not digest_with_prefix.startswith("sha256:"):
        raise Error("model manifest does not reference a SHA-256 blob")
    var digest = String(digest_with_prefix[byte=7:])
    var sha_directory_fd = _open_sha256_directory(root_fd)
    var blob_fd: Int32 = -1
    try:
        blob_fd = _open_blob_by_digest(sha_directory_fd, digest)
        _verify_blob_fd(blob_fd, digest, size_bytes)
    except error:
        if blob_fd >= 0:
            _ = external_call["close", Int32](blob_fd)
        _ = external_call["close", Int32](sha_directory_fd)
        raise error
    _ = external_call["close", Int32](blob_fd)
    _ = external_call["close", Int32](sha_directory_fd)


def _remove_new_blob_locked(root_fd: Int32, record: BlobRecord) raises:
    """Rolls back only a blob that this transaction published for the first time."""
    if not record.created:
        return
    var digest = String(record.digest[byte=7:])
    _validate_sha256_hex(digest)
    var sha_directory_fd = _open_sha256_directory(root_fd)
    var digest_bytes = _cstring(digest)
    if external_call["unlinkat", Int32](
        sha_directory_fd, digest_bytes.unsafe_ptr(), Int32(0)
    ) != 0:
        _ = external_call["close", Int32](sha_directory_fd)
        raise Error("unable to roll back newly published model blob")
    var sync_result = external_call["fsync", Int32](sha_directory_fd)
    _ = external_call["close", Int32](sha_directory_fd)
    if sync_result != 0:
        raise Error("unable to synchronize model blob rollback")


def _is_stale_ingest_name(name: String) -> Bool:
    if not name.startswith(".ingest.") or not name.endswith(".tmp"):
        return False
    var middle = String(name[byte=8 : len(name.bytes()) - 4])
    var parts = middle.split(".")
    if len(parts) != 2:
        return False
    for part in parts:
        if len(part.bytes()) == 0:
            return False
        for byte in part.as_bytes():
            if byte < 48 or byte > 57:
                return False
    return True


def _is_sha256_name(name: String) -> Bool:
    try:
        _validate_sha256_hex(name)
    except:
        return False
    return True


def _is_recipe_fingerprint(digest: String) -> Bool:
    if not digest.startswith("fnv1a64:") or len(digest.bytes()) != 24:
        return False
    for byte in String(digest[byte=8:]).as_bytes():
        if not (
            (byte >= 48 and byte <= 57) or (byte >= 97 and byte <= 102)
        ):
            return False
    return True


def _measure_regular_entry(
    sha_directory_fd: Int32, name: String
) raises -> Int64:
    """Opens a non-symlink, non-directory entry and returns its exact size."""
    var name_bytes = _cstring(name)
    # Prove that the entry is not a directory before accepting it as a blob or
    # abandoned ingest file. O_DIRECTORY | O_NOFOLLOW makes this test explicit.
    var directory_probe = external_call["openat", Int32](
        sha_directory_fd,
        name_bytes.unsafe_ptr(),
        Int32(720896),
        Int32(0),
    )
    if directory_probe >= 0:
        _ = external_call["close", Int32](directory_probe)
        raise Error("model blob directory entry must be a regular file: " + name)
    # O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC. O_NONBLOCK prevents a
    # hostile FIFO from stalling collection; lseek then rejects non-files.
    var fd = external_call["openat", Int32](
        sha_directory_fd,
        name_bytes.unsafe_ptr(),
        Int32(657408),
        Int32(0),
    )
    if fd < 0:
        raise Error("unable to safely open model blob directory entry: " + name)
    var size = external_call["lseek", Int64](fd, Int64(0), Int32(2))
    _ = external_call["close", Int32](fd)
    if size < 0:
        raise Error("model blob directory entry is not seekable: " + name)
    return size


def _list_blob_names(sha_directory_fd: Int32) raises -> List[String]:
    """Lists raw directory entries through an inherited descriptor and NUL framing."""
    var inherited_fd = external_call["dup", Int32](sha_directory_fd)
    if inherited_fd < 0:
        raise Error("unable to duplicate model blob directory for enumeration")
    var output: List[Byte]
    try:
        output = run_checked_argv_bytes(
            [
                "find",
                "-P",
                "/proc/self/fd/" + String(inherited_fd) + "/.",
                "-mindepth",
                "1",
                "-maxdepth",
                "1",
                "-printf",
                "%f\\0",
            ],
            16 * 1024 * 1024,
        )
    except error:
        _ = external_call["close", Int32](inherited_fd)
        raise error
    _ = external_call["close", Int32](inherited_fd)
    var names = List[String]()
    var current = List[Int8]()
    for byte in output:
        if byte == 0:
            if len(current) == 0:
                raise Error("model blob directory contains an empty entry name")
            current.append(0)
            names.append(String(unsafe_from_utf8_ptr=current.unsafe_ptr()))
            current = List[Int8]()
        else:
            current.append(Int8(byte))
    if len(current) != 0:
        raise Error("model blob directory enumeration is not NUL terminated")
    return names^


def _sync_directory(root: String) raises:
    var root_bytes = _cstring(root)
    var directory_fd = external_call["open64", Int32](
        root_bytes.unsafe_ptr(), Int32(720896), Int32(0)
    )
    if directory_fd < 0:
        raise Error("unable to open model store root for synchronization")
    var sync_result = external_call["fsync", Int32](directory_fd)
    _ = external_call["close", Int32](directory_fd)
    if sync_result != 0:
        raise Error("unable to synchronize model store root")


def _atomic_write_catalog(
    root: String, content: String, mut replaced: Bool
) raises:
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
    # The visible catalog may now reference a newly published blob. Retain that
    # blob even if the following directory sync reports uncertain durability.
    replaced = True
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
        var catalog_replaced = False
        try:
            candidate = _load_store(self.root_path)
            candidate.create_model(name, modelfile_content)
            _atomic_write_catalog(
                self.root_path, serialize_catalog(candidate), catalog_replaced
            )
        except error:
            _ = external_call["close", Int32](lock_fd)
            raise error
        _ = external_call["close", Int32](lock_fd)
        self.store = candidate^

    def ingest_model(
        mut self,
        name: String,
        modelfile_content: String,
        source_path: String,
        expected_digest: String = String(""),
        expected_size: Int64 = 0,
    ) raises -> BlobRecord:
        """Atomically links measured source bytes to a durable model manifest."""
        if len(expected_digest.bytes()) > 0:
            if not expected_digest.startswith("sha256:"):
                raise Error("expected model blob digest must use sha256:<hex>")
            _validate_sha256_hex(String(expected_digest[byte=7:]))
            if expected_size <= 0:
                raise Error("expected model blob size must be positive")
        elif expected_size != 0:
            raise Error("expected model blob size requires an expected digest")
        _ensure_store_root(self.root_path)
        var lock_fd = _lock_store_root(self.root_path)
        var candidate = RuneModelStore()
        var record = BlobRecord("", 0, False)
        var ingested = False
        var catalog_replaced = False
        try:
            candidate = _load_store(self.root_path)
            record = _ingest_blob_locked(lock_fd, source_path)
            ingested = True
            if len(expected_digest.bytes()) > 0 and (
                record.digest != expected_digest
                or record.size_bytes != expected_size
            ):
                raise Error(
                    "model blob does not match its expected digest and size"
                )
            candidate.create_model_from_blob(
                name,
                modelfile_content,
                record.digest,
                record.size_bytes,
            )
            _atomic_write_catalog(
                self.root_path, serialize_catalog(candidate), catalog_replaced
            )
        except error:
            if ingested and record.created and not catalog_replaced:
                try:
                    _remove_new_blob_locked(lock_fd, record)
                except:
                    _ = external_call["close", Int32](lock_fd)
                    raise Error(
                        "model catalog transaction failed and its new blob "
                        "could not be rolled back"
                    )
            _ = external_call["close", Int32](lock_fd)
            raise error
        _ = external_call["close", Int32](lock_fd)
        self.store = candidate^
        return record^

    def verify_model(self, name: String) raises -> BlobRecord:
        """Rehashes one catalog model's exact immutable blob inode."""
        _ensure_store_root(self.root_path)
        var lock_fd = _lock_store_root(self.root_path)
        var manifest: ModelManifest
        try:
            manifest = _load_store(self.root_path).get_model(name)
            _verify_blob_locked(
                lock_fd, manifest.digest, manifest.size_bytes
            )
        except error:
            _ = external_call["close", Int32](lock_fd)
            raise error
        _ = external_call["close", Int32](lock_fd)
        return BlobRecord(manifest.digest, manifest.size_bytes, False)

    def garbage_collect(mut self) raises -> BlobGCResult:
        """Removes only blobs unreachable from a fully validated catalog."""
        _ensure_store_root(self.root_path)
        var lock_fd = _lock_store_root(self.root_path)
        var sha_directory_fd: Int32 = -1
        var candidate = RuneModelStore()
        var references = Dict[String, Int64]()
        var available_sizes = Dict[String, Int64]()
        var blob_names = List[String]()
        var stage_names = List[String]()
        var scanned_blobs = 0
        var removed_blobs = 0
        var removed_stages = 0
        var reclaimed_bytes: Int64 = 0
        try:
            candidate = _load_store(self.root_path)
            for key in candidate.model_keys:
                if key not in candidate.catalog:
                    raise Error("model catalog key has no manifest: " + key)
                var manifest = candidate.catalog[key]
                if manifest.digest.startswith("sha256:"):
                    var digest = String(manifest.digest[byte=7:])
                    _validate_sha256_hex(digest)
                    if manifest.size_bytes <= 0:
                        raise Error(
                            "SHA-256 model catalog record has no positive size"
                        )
                    if (
                        digest in references
                        and references[digest] != manifest.size_bytes
                    ):
                        raise Error(
                            "model catalog assigns conflicting sizes to one blob"
                        )
                    references[digest] = manifest.size_bytes
                elif _is_recipe_fingerprint(manifest.digest):
                    if manifest.size_bytes != 0:
                        raise Error(
                            "recipe model catalog record has a nonzero byte size"
                        )
                else:
                    raise Error("model catalog record has an unsupported digest")

            sha_directory_fd = _open_sha256_directory(lock_fd)
            var names = _list_blob_names(sha_directory_fd)
            # Complete classification and type/size validation happens before
            # the first unlink, so an unknown or unsafe entry fails closed.
            for name in names:
                if _is_sha256_name(name):
                    var size = _measure_regular_entry(sha_directory_fd, name)
                    available_sizes[name] = size
                    blob_names.append(name)
                    scanned_blobs += 1
                elif _is_stale_ingest_name(name):
                    _ = _measure_regular_entry(sha_directory_fd, name)
                    stage_names.append(name)
                else:
                    raise Error(
                        "model blob directory contains an unexpected entry: "
                        + name
                    )

            for digest in references.keys():
                if digest not in available_sizes:
                    raise Error("referenced model blob is missing: sha256:" + digest)
                if available_sizes[digest] != references[digest]:
                    raise Error(
                        "stored model blob size does not match its catalog record"
                    )

            for digest in blob_names:
                if digest in references:
                    continue
                var digest_bytes = _cstring(digest)
                if external_call["unlinkat", Int32](
                    sha_directory_fd, digest_bytes.unsafe_ptr(), Int32(0)
                ) != 0:
                    raise Error("unable to remove unreachable model blob: " + digest)
                removed_blobs += 1
                reclaimed_bytes += available_sizes[digest]
            for name in stage_names:
                var name_bytes = _cstring(name)
                if external_call["unlinkat", Int32](
                    sha_directory_fd, name_bytes.unsafe_ptr(), Int32(0)
                ) != 0:
                    raise Error("unable to remove abandoned model blob stage: " + name)
                removed_stages += 1
            if (removed_blobs > 0 or removed_stages > 0) and external_call[
                "fsync", Int32
            ](sha_directory_fd) != 0:
                raise Error("unable to synchronize model blob garbage collection")
        except error:
            if sha_directory_fd >= 0:
                _ = external_call["close", Int32](sha_directory_fd)
            _ = external_call["close", Int32](lock_fd)
            raise error
        _ = external_call["close", Int32](sha_directory_fd)
        _ = external_call["close", Int32](lock_fd)
        self.store = candidate^
        return BlobGCResult(
            scanned_blobs,
            len(references),
            removed_blobs,
            removed_stages,
            reclaimed_bytes,
        )

    def copy_model(mut self, source: String, target: String) raises:
        _ensure_store_root(self.root_path)
        var lock_fd = _lock_store_root(self.root_path)
        var candidate = RuneModelStore()
        var catalog_replaced = False
        try:
            candidate = _load_store(self.root_path)
            candidate.copy_model(source, target)
            _atomic_write_catalog(
                self.root_path, serialize_catalog(candidate), catalog_replaced
            )
        except error:
            _ = external_call["close", Int32](lock_fd)
            raise error
        _ = external_call["close", Int32](lock_fd)
        self.store = candidate^

    def remove_model(mut self, name: String) raises:
        _ensure_store_root(self.root_path)
        var lock_fd = _lock_store_root(self.root_path)
        var candidate = RuneModelStore()
        var catalog_replaced = False
        try:
            candidate = _load_store(self.root_path)
            candidate.remove_model_checked(name)
            _atomic_write_catalog(
                self.root_path, serialize_catalog(candidate), catalog_replaced
            )
        except error:
            _ = external_call["close", Int32](lock_fd)
            raise error
        _ = external_call["close", Int32](lock_fd)
        self.store = candidate^
