"""Durable aliases and favorites layered over the immutable model catalog."""

from std.ffi import external_call
from std.memory import Pointer
from std.collections import Dict, InlineArray
from config import validate_model_store_path
from cli.manifest import RuneModelStore, normalize_model_reference, validate_model_component


comptime PREFERENCES_FILE = "preferences.v1"
comptime PREFERENCES_HEADER = "AESIR_MODEL_PREFERENCES_V1"
comptime MAX_PREFERENCES_BYTES = 1024 * 1024
comptime MAX_PREFERENCE_ENTRIES = 10000


def _pref_cstring(value: String) -> List[Int8]:
    var output = List[Int8]()
    for byte in value.as_bytes():
        output.append(Int8(byte))
    output.append(0)
    return output^


def _pref_hex_encode(value: String) -> String:
    var alphabet = String("0123456789abcdef")
    var output = String("")
    for byte in value.as_bytes():
        var code = Int(byte)
        output += String(alphabet[byte=code >> 4 : (code >> 4) + 1])
        output += String(alphabet[byte=code & 15 : (code & 15) + 1])
    return output


def _pref_hex_nibble(code: Int) raises -> Int:
    if code >= 48 and code <= 57:
        return code - 48
    if code >= 97 and code <= 102:
        return code - 87
    raise Error("model preferences contain invalid lowercase hex")


def _pref_hex_decode(value: String) raises -> String:
    if len(value.bytes()) % 2 != 0:
        raise Error("model preferences contain odd-length hex")
    var output = List[Int8]()
    var source = value.as_bytes()
    for index in range(0, len(source), 2):
        output.append(Int8(
            (_pref_hex_nibble(Int(source[index])) << 4)
            | _pref_hex_nibble(Int(source[index + 1]))
        ))
    output.append(0)
    return String(unsafe_from_utf8_ptr=output.unsafe_ptr())


def _pref_checksum(payload: String) -> UInt64:
    var value: UInt64 = 14695981039346656037
    for byte in payload.as_bytes():
        value = (value ^ UInt64(byte)) * 1099511628211
    return value


def _pref_checksum_hex(value: UInt64) -> String:
    var alphabet = String("0123456789abcdef")
    var output = String("")
    for shift in range(60, -4, -4):
        var nibble = Int((value >> UInt64(shift)) & 15)
        output += String(alphabet[byte=nibble : nibble + 1])
    return output


def _parse_pref_count(value: String) raises -> Int:
    if value == "":
        raise Error("model preference count must not be empty")
    for byte in value.as_bytes():
        if byte < 48 or byte > 57:
            raise Error("model preference count must be decimal")
    var count: Int
    try:
        count = atol(value)
    except:
        raise Error("model preference count is outside the supported range")
    if count < 0 or count > MAX_PREFERENCE_ENTRIES:
        raise Error("model preference count exceeds its supported bound")
    return count


def validate_alias_name(alias_name: String) raises -> String:
    var clean = String(alias_name.strip())
    if ":" in clean:
        raise Error("model alias must not contain a tag separator")
    validate_model_component(clean, "alias")
    return clean


struct ModelPreferences(Copyable):
    var aliases: Dict[String, String]
    var alias_keys: List[String]
    var favorites: List[String]

    def __init__(out self):
        self.aliases = Dict[String, String]()
        self.alias_keys = List[String]()
        self.favorites = List[String]()

    def __copyinit__(out self, existing: Self):
        self.aliases = existing.aliases.copy()
        self.alias_keys = existing.alias_keys.copy()
        self.favorites = existing.favorites.copy()

    def set_alias(mut self, alias_name: String, canonical: String) raises:
        var clean_alias = validate_alias_name(alias_name)
        var clean_target = normalize_model_reference(canonical)
        self.aliases[clean_alias] = clean_target
        if clean_alias not in self.alias_keys:
            self.alias_keys.append(clean_alias)

    def remove_alias(mut self, alias_name: String) raises:
        var clean = validate_alias_name(alias_name)
        if clean not in self.aliases:
            raise Error("model alias not found: " + clean)
        _ = self.aliases.pop(clean)
        var remaining = List[String]()
        for key in self.alias_keys:
            if key != clean:
                remaining.append(key)
        self.alias_keys = remaining^

    def resolve(self, reference: String) raises -> String:
        if ":" not in reference:
            var clean = validate_alias_name(reference)
            if clean in self.aliases:
                return self.aliases[clean]
        return normalize_model_reference(reference)

    def add_favorite(mut self, canonical: String) raises:
        var clean = normalize_model_reference(canonical)
        if clean not in self.favorites:
            self.favorites.append(clean)

    def remove_favorite(mut self, canonical: String) raises:
        var clean = normalize_model_reference(canonical)
        if clean not in self.favorites:
            raise Error("favorite model not found: " + clean)
        var remaining = List[String]()
        for favorite in self.favorites:
            if favorite != clean:
                remaining.append(favorite)
        self.favorites = remaining^

    def is_favorite(self, canonical: String) -> Bool:
        return canonical in self.favorites


def serialize_model_preferences(preferences: ModelPreferences) raises -> String:
    if (len(preferences.alias_keys) > MAX_PREFERENCE_ENTRIES
            or len(preferences.favorites) > MAX_PREFERENCE_ENTRIES):
        raise Error("model preferences exceed their supported entry bound")
    var payload = PREFERENCES_HEADER + "\nALIASES:" + String(len(preferences.alias_keys)) + "\n"
    var seen_aliases = Dict[String, Bool]()
    for alias_name in preferences.alias_keys:
        var clean_alias = validate_alias_name(alias_name)
        if clean_alias in seen_aliases or clean_alias not in preferences.aliases:
            raise Error("model preferences contain an invalid alias index")
        seen_aliases[clean_alias] = True
        var target = normalize_model_reference(preferences.aliases[clean_alias])
        payload += "ALIAS:" + _pref_hex_encode(clean_alias) + ":" + _pref_hex_encode(target) + "\n"
    payload += "FAVORITES:" + String(len(preferences.favorites)) + "\n"
    var seen_favorites = Dict[String, Bool]()
    for favorite in preferences.favorites:
        var clean = normalize_model_reference(favorite)
        if clean in seen_favorites:
            raise Error("model preferences contain duplicate favorites")
        seen_favorites[clean] = True
        payload += "FAVORITE:" + _pref_hex_encode(clean) + "\n"
    var result = payload + "CHECKSUM:" + _pref_checksum_hex(_pref_checksum(payload)) + "\n"
    if result.byte_length() > MAX_PREFERENCES_BYTES:
        raise Error("model preferences exceed 1 MiB")
    return result


def deserialize_model_preferences(raw: String) raises -> ModelPreferences:
    if raw == "":
        return ModelPreferences()
    if raw.byte_length() > MAX_PREFERENCES_BYTES:
        raise Error("model preferences exceed 1 MiB")
    var lines = raw.split("\n")
    if len(lines) < 5 or String(lines[len(lines) - 1]) != "":
        raise Error("model preferences record is incomplete")
    if String(lines[0]) != PREFERENCES_HEADER:
        raise Error("unsupported model preferences version")
    if not String(lines[1]).startswith("ALIASES:"):
        raise Error("model preferences alias count is missing")
    var alias_count = _parse_pref_count(String(lines[1][byte=8:]))
    var favorite_count_index = 2 + alias_count
    if favorite_count_index >= len(lines) or not String(lines[favorite_count_index]).startswith("FAVORITES:"):
        raise Error("model preferences favorite count is missing")
    var favorite_count = _parse_pref_count(String(lines[favorite_count_index][byte=10:]))
    var checksum_index = favorite_count_index + 1 + favorite_count
    if len(lines) != checksum_index + 2:
        raise Error("model preference counts do not match their records")
    var payload = String("")
    for index in range(checksum_index):
        payload += String(lines[index]) + "\n"
    var checksum_line = String(lines[checksum_index])
    if not checksum_line.startswith("CHECKSUM:"):
        raise Error("model preferences checksum is missing")
    if _pref_checksum_hex(_pref_checksum(payload)) != String(checksum_line[byte=9:]):
        raise Error("model preferences checksum mismatch")

    var preferences = ModelPreferences()
    for index in range(alias_count):
        var line = String(lines[2 + index])
        if not line.startswith("ALIAS:"):
            raise Error("model preference alias record is malformed")
        var fields = String(line[byte=6:]).split(":")
        if len(fields) != 2:
            raise Error("model preference alias record is malformed")
        var alias_name = _pref_hex_decode(String(fields[0]))
        if alias_name in preferences.aliases:
            raise Error("model preferences contain a duplicate alias")
        preferences.set_alias(alias_name, _pref_hex_decode(String(fields[1])))
    for index in range(favorite_count):
        var line = String(lines[favorite_count_index + 1 + index])
        if not line.startswith("FAVORITE:"):
            raise Error("model preference favorite record is malformed")
        var favorite = normalize_model_reference(_pref_hex_decode(String(line[byte=9:])))
        if favorite in preferences.favorites:
            raise Error("model preferences contain a duplicate favorite")
        preferences.favorites.append(favorite)
    return preferences^


def _read_preferences(root_fd: Int32) raises -> ModelPreferences:
    var name = _pref_cstring(PREFERENCES_FILE)
    # O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC.
    var fd = external_call["openat", Int32](root_fd, name.unsafe_ptr(), Int32(657408), Int32(0))
    if fd < 0:
        var errno_pointer = external_call["__errno_location", Pointer[Int32, MutUntrackedOrigin]]()
        if errno_pointer.unsafe_load() == 2:
            return ModelPreferences()
        raise Error("unable to open model preferences")
    var stat = InlineArray[UInt64, 18](fill=0)
    if external_call["fstat", Int32](fd, stat.unsafe_ptr()) != 0:
        _ = external_call["close", Int32](fd)
        raise Error("unable to inspect model preferences")
    var mode = stat[3] & 4294967295
    if mode & 61440 != 32768:
        _ = external_call["close", Int32](fd)
        raise Error("model preferences must be a regular file")
    if stat[6] == 0 or stat[6] > MAX_PREFERENCES_BYTES:
        _ = external_call["close", Int32](fd)
        raise Error("model preferences must contain 1..1048576 bytes")
    var bytes = List[Byte]()
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
                raise Error("model preferences read failed")
            if len(bytes) + count > MAX_PREFERENCES_BYTES:
                raise Error("model preferences exceed 1 MiB")
            for index in range(count):
                bytes.append(buffer[index])
    except error:
        _ = external_call["close", Int32](fd)
        raise error
    _ = external_call["close", Int32](fd)
    bytes.append(0)
    return deserialize_model_preferences(String(unsafe_from_utf8_ptr=bytes.unsafe_ptr()))


def _write_preferences(root_fd: Int32, preferences: ModelPreferences) raises:
    var content = serialize_model_preferences(preferences)
    var pid = external_call["getpid", Int32]()
    var temp_name: String
    var temp = List[Int8]()
    var target = _pref_cstring(PREFERENCES_FILE)
    var fd: Int32 = -1
    for attempt in range(1024):
        temp_name = ".preferences." + String(pid) + "." + String(attempt) + ".tmp"
        temp = _pref_cstring(temp_name)
        fd = external_call["openat", Int32](root_fd, temp.unsafe_ptr(), Int32(655553), Int32(384))
        if fd >= 0:
            break
    if fd < 0:
        raise Error("unable to create staged model preferences")
    try:
        var source = content.as_bytes()
        var offset = 0
        while offset < len(source):
            var written = external_call["write", Int](Int(fd), source.unsafe_ptr().unsafe_offset(offset), len(source) - offset)
            if written <= 0:
                raise Error("model preferences write failed")
            offset += written
        if external_call["fsync", Int32](fd) != 0:
            raise Error("model preferences synchronization failed")
    except error:
        _ = external_call["close", Int32](fd)
        _ = external_call["unlinkat", Int32](root_fd, temp.unsafe_ptr(), Int32(0))
        raise error
    if external_call["close", Int32](fd) != 0:
        _ = external_call["unlinkat", Int32](root_fd, temp.unsafe_ptr(), Int32(0))
        raise Error("unable to close staged model preferences")
    if external_call["renameat", Int32](root_fd, temp.unsafe_ptr(), root_fd, target.unsafe_ptr()) != 0:
        _ = external_call["unlinkat", Int32](root_fd, temp.unsafe_ptr(), Int32(0))
        raise Error("unable to atomically replace model preferences")
    if external_call["fsync", Int32](root_fd) != 0:
        raise Error("model preferences directory synchronization failed")


struct DurableModelPreferences:
    var root_path: String

    def __init__(out self, root_path: String) raises:
        self.root_path = validate_model_store_path(root_path)

    def _open_root(self) raises -> Int32:
        var root = _pref_cstring(self.root_path)
        var fd = external_call["open64", Int32](root.unsafe_ptr(), Int32(720896), Int32(0))
        if fd < 0:
            raise Error("model store is unavailable: " + self.root_path)
        return fd

    def load(self) raises -> ModelPreferences:
        var root_fd = self._open_root()
        var result: ModelPreferences
        try:
            result = _read_preferences(root_fd)
        except error:
            _ = external_call["close", Int32](root_fd)
            raise error
        _ = external_call["close", Int32](root_fd)
        return result^

    def set_alias(self, alias_name: String, canonical: String, catalog: RuneModelStore) raises:
        var clean_alias = validate_alias_name(alias_name)
        var clean_target = normalize_model_reference(canonical)
        _ = catalog.get_model(clean_target)
        # A real untagged model always wins resolution; reject ambiguous aliases.
        try:
            _ = catalog.get_model(clean_alias)
            raise Error("model alias conflicts with an installed model: " + clean_alias)
        except error:
            if "conflicts" in String(error):
                raise error
        var root_fd = self._open_root()
        if external_call["flock", Int32](root_fd, 2) != 0:
            _ = external_call["close", Int32](root_fd)
            raise Error("unable to lock model preferences")
        try:
            var preferences = _read_preferences(root_fd)
            preferences.set_alias(clean_alias, clean_target)
            _write_preferences(root_fd, preferences)
        except error:
            _ = external_call["close", Int32](root_fd)
            raise error
        _ = external_call["close", Int32](root_fd)

    def remove_alias(self, alias_name: String) raises:
        var root_fd = self._open_root()
        if external_call["flock", Int32](root_fd, 2) != 0:
            _ = external_call["close", Int32](root_fd)
            raise Error("unable to lock model preferences")
        try:
            var preferences = _read_preferences(root_fd)
            preferences.remove_alias(alias_name)
            _write_preferences(root_fd, preferences)
        except error:
            _ = external_call["close", Int32](root_fd)
            raise error
        _ = external_call["close", Int32](root_fd)

    def add_favorite(self, reference: String, catalog: RuneModelStore) raises -> String:
        var root_fd = self._open_root()
        if external_call["flock", Int32](root_fd, 2) != 0:
            _ = external_call["close", Int32](root_fd)
            raise Error("unable to lock model preferences")
        var canonical: String
        try:
            var preferences = _read_preferences(root_fd)
            canonical = preferences.resolve(reference)
            _ = catalog.get_model(canonical)
            preferences.add_favorite(canonical)
            _write_preferences(root_fd, preferences)
        except error:
            _ = external_call["close", Int32](root_fd)
            raise error
        _ = external_call["close", Int32](root_fd)
        return canonical

    def remove_favorite(self, reference: String) raises -> String:
        var root_fd = self._open_root()
        if external_call["flock", Int32](root_fd, 2) != 0:
            _ = external_call["close", Int32](root_fd)
            raise Error("unable to lock model preferences")
        var canonical: String
        try:
            var preferences = _read_preferences(root_fd)
            canonical = preferences.resolve(reference)
            preferences.remove_favorite(canonical)
            _write_preferences(root_fd, preferences)
        except error:
            _ = external_call["close", Int32](root_fd)
            raise error
        _ = external_call["close", Int32](root_fd)
        return canonical
