"""Checksummed exact-token conversation snapshots and readable exports."""

from std.ffi import external_call
from std.memory import Pointer
from core.observation_integer import bounded_decimal


comptime CONVERSATION_HEADER = "AESIR_CONVERSATION_V1"
comptime MAX_CONVERSATION_BYTES = 16 * 1024 * 1024
comptime MAX_CONVERSATION_TURNS = 1024


struct ConversationTurn(Copyable, ImplicitlyCopyable):
    var user: String
    var assistant: String

    def __init__(out self, user: String, assistant: String):
        self.user = user
        self.assistant = assistant

    def __copyinit__(out self, existing: Self):
        self.user = existing.user
        self.assistant = existing.assistant


struct ConversationState(Copyable):
    var model_identity: String
    var profile: String
    var context_length: Int
    var system_prompt: String
    var sampling_identity: String
    var sampler_draws: Int
    var tokens: List[Int]
    var turns: List[ConversationTurn]

    def __init__(
        out self,
        model_identity: String,
        profile: String,
        context_length: Int,
        system_prompt: String,
        sampling_identity: String,
    ):
        self.model_identity = model_identity
        self.profile = profile
        self.context_length = context_length
        self.system_prompt = system_prompt
        self.sampling_identity = sampling_identity
        self.sampler_draws = 0
        self.tokens = List[Int]()
        self.turns = List[ConversationTurn]()

    def __copyinit__(out self, existing: Self):
        self.model_identity = existing.model_identity
        self.profile = existing.profile
        self.context_length = existing.context_length
        self.system_prompt = existing.system_prompt
        self.sampling_identity = existing.sampling_identity
        self.sampler_draws = existing.sampler_draws
        self.tokens = existing.tokens.copy()
        self.turns = existing.turns.copy()

    def validate(self) raises:
        if self.model_identity == "" or self.model_identity.byte_length() > 4096:
            raise Error("Conversation model identity is invalid")
        if self.profile not in ("gemma4", "llama3", "qwen3"):
            raise Error("Conversation profile is unsupported")
        if self.context_length < 2 or self.context_length > 32768:
            raise Error("Conversation context is outside native bounds")
        if self.system_prompt.byte_length() > 65536:
            raise Error("Conversation system prompt exceeds 64 KiB")
        if self.sampling_identity == "" or self.sampling_identity.byte_length() > 4096:
            raise Error("Conversation sampling identity is invalid")
        if self.sampler_draws < 0:
            raise Error("Conversation sampler draws must not be negative")
        if len(self.tokens) > self.context_length:
            raise Error("Conversation token stream exceeds its context")
        for token in self.tokens:
            if token < 0 or token > 2147483647:
                raise Error("Conversation token ID is outside native range")
        if len(self.turns) > MAX_CONVERSATION_TURNS:
            raise Error("Conversation turn count exceeds its bound")
        for turn in self.turns:
            if turn.user == "" or turn.user.byte_length() > 65536:
                raise Error("Conversation user turn is outside 1..65536 bytes")
            if turn.assistant.byte_length() > 1048576:
                raise Error("Conversation assistant turn exceeds 1 MiB")
        for value in [
            self.model_identity,
            self.profile,
            self.system_prompt,
            self.sampling_identity,
        ]:
            if "\0" in value:
                raise Error("Conversation metadata contains NUL")

    def append_turn(mut self, user: String, assistant: String) raises:
        var turn = ConversationTurn(user, assistant)
        self.turns.append(turn)
        try:
            self.validate()
        except error:
            _ = self.turns.pop()
            raise error

    def clear(mut self):
        self.tokens.clear()
        self.turns.clear()
        self.sampler_draws = 0


def _hex_encode(text: String) -> String:
    var alphabet = String("0123456789abcdef")
    var output = String("")
    for byte in text.as_bytes():
        var value = Int(byte)
        output += String(alphabet[byte=value >> 4 : (value >> 4) + 1])
        output += String(alphabet[byte=value & 15 : (value & 15) + 1])
    return output


def _hex_nibble(byte: Int) raises -> Int:
    if byte >= 48 and byte <= 57:
        return byte - 48
    if byte >= 97 and byte <= 102:
        return byte - 87
    raise Error("Conversation text contains invalid lowercase hex")


def _hex_decode(text: String) raises -> String:
    if len(text.bytes()) % 2 != 0:
        raise Error("Conversation text contains odd-length hex")
    var output = List[Int8]()
    var source = text.as_bytes()
    for index in range(0, len(source), 2):
        output.append(Int8((_hex_nibble(Int(source[index])) << 4) | _hex_nibble(Int(source[index + 1]))))
    output.append(0)
    return String(unsafe_from_utf8_ptr=output.unsafe_ptr())


def _checksum(payload: String) -> UInt64:
    var value: UInt64 = 14695981039346656037
    for byte in payload.as_bytes():
        value = (value ^ UInt64(byte)) * 1099511628211
    return value


def _checksum_hex(value: UInt64) -> String:
    var alphabet = String("0123456789abcdef")
    var output = String("")
    for shift in range(60, -4, -4):
        var nibble = Int((value >> UInt64(shift)) & 15)
        output += String(alphabet[byte=nibble : nibble + 1])
    return output


def _parse_checksum(text: String) raises -> UInt64:
    if len(text.bytes()) != 16:
        raise Error("Conversation checksum must contain 16 lowercase hex digits")
    var result: UInt64 = 0
    for byte in text.as_bytes():
        result = (result << 4) | UInt64(_hex_nibble(Int(byte)))
    return result


def _field(line: String, prefix: String) raises -> String:
    if not line.startswith(prefix):
        raise Error("Conversation record field order is invalid")
    return String(line[byte=len(prefix.bytes()):])


def serialize_conversation(state: ConversationState) raises -> String:
    state.validate()
    if len(state.turns) > 0 and len(state.tokens) == 0:
        raise Error("Conversation turns require an exact token stream before save")
    var token_text = String("")
    for index in range(len(state.tokens)):
        if index > 0:
            token_text += ","
        token_text += String(state.tokens[index])
    var payload = (
        CONVERSATION_HEADER + "\n"
        + "MODEL:" + _hex_encode(state.model_identity) + "\n"
        + "PROFILE:" + _hex_encode(state.profile) + "\n"
        + "CONTEXT:" + String(state.context_length) + "\n"
        + "SYSTEM:" + _hex_encode(state.system_prompt) + "\n"
        + "SAMPLING:" + _hex_encode(state.sampling_identity) + "\n"
        + "DRAWS:" + String(state.sampler_draws) + "\n"
        + "TOKENS:" + token_text + "\n"
        + "TURNS:" + String(len(state.turns)) + "\n"
    )
    for turn in state.turns:
        payload += "USER:" + _hex_encode(turn.user) + "\n"
        payload += "ASSISTANT:" + _hex_encode(turn.assistant) + "\n"
    var result = payload + "CHECKSUM:" + _checksum_hex(_checksum(payload)) + "\n"
    if result.byte_length() > MAX_CONVERSATION_BYTES:
        raise Error("Serialized conversation exceeds 16 MiB")
    return result


def require_conversation_compatible(
    saved: ConversationState, current: ConversationState
) raises:
    """Rejects a load before KV mutation when session-defining identity differs."""
    if saved.model_identity != current.model_identity:
        raise Error("Saved conversation belongs to a different model")
    if saved.profile != current.profile:
        raise Error("Saved conversation belongs to a different model profile")
    if saved.context_length != current.context_length:
        raise Error("Saved conversation requires a different context length")
    if saved.system_prompt != current.system_prompt:
        raise Error("Saved conversation uses a different system prompt")
    if saved.sampling_identity != current.sampling_identity:
        raise Error("Saved conversation uses different sampling settings")


def deserialize_conversation(raw: String) raises -> ConversationState:
    if raw.byte_length() == 0 or raw.byte_length() > MAX_CONVERSATION_BYTES:
        raise Error("Conversation record must contain 1..16777216 bytes")
    var lines = raw.split("\n")
    if len(lines) < 11 or String(lines[len(lines) - 1]) != "":
        raise Error("Conversation record must end with one complete line")
    if String(lines[0]) != CONVERSATION_HEADER:
        raise Error("Unsupported conversation record version")
    var turn_count = bounded_decimal(_field(String(lines[8]), "TURNS:"))
    if turn_count > MAX_CONVERSATION_TURNS or len(lines) != 11 + 2 * turn_count:
        raise Error("Conversation turn count does not match its record")
    var checksum_index = 9 + 2 * turn_count
    var payload = String("")
    for index in range(checksum_index):
        payload += String(lines[index]) + "\n"
    var expected = _parse_checksum(_field(String(lines[checksum_index]), "CHECKSUM:"))
    if _checksum(payload) != expected:
        raise Error("Conversation checksum mismatch")

    var context = bounded_decimal(_field(String(lines[3]), "CONTEXT:"))
    var state = ConversationState(
        _hex_decode(_field(String(lines[1]), "MODEL:")),
        _hex_decode(_field(String(lines[2]), "PROFILE:")),
        context,
        _hex_decode(_field(String(lines[4]), "SYSTEM:")),
        _hex_decode(_field(String(lines[5]), "SAMPLING:")),
    )
    state.sampler_draws = bounded_decimal(_field(String(lines[6]), "DRAWS:"))
    var token_text = _field(String(lines[7]), "TOKENS:")
    if token_text != "":
        for token in token_text.split(","):
            state.tokens.append(bounded_decimal(String(token)))
    for index in range(turn_count):
        state.turns.append(ConversationTurn(
            _hex_decode(_field(String(lines[9 + 2 * index]), "USER:")),
            _hex_decode(_field(String(lines[10 + 2 * index]), "ASSISTANT:")),
        ))
    state.validate()
    return state^


def _path_bytes(path: String) raises -> List[Int8]:
    if path == "" or path.byte_length() >= 4096 or "\0" in path:
        raise Error("Conversation path must contain 1..4095 non-NUL bytes")
    var result = List[Int8]()
    for byte in path.as_bytes():
        result.append(Int8(byte))
    result.append(0)
    return result^


def _parent_path(path: String) -> String:
    var last_slash = -1
    for index in range(len(path.bytes())):
        if path.as_bytes()[index] == 47:
            last_slash = index
    if last_slash < 0:
        return "."
    if last_slash == 0:
        return "/"
    return String(path[byte=0:last_slash])


def _write_exclusive(path: String, content: String) raises:
    var encoded = _path_bytes(path)
    var parent = _path_bytes(_parent_path(path))
    var parent_fd = external_call["open64", Int32](parent.unsafe_ptr(), Int32(589824), Int32(0))
    if parent_fd < 0:
        raise Error("Conversation output parent is unavailable")
    var fd = external_call["open64", Int32](encoded.unsafe_ptr(), Int32(193), Int32(384))
    if fd < 0:
        _ = external_call["close", Int32](parent_fd)
        raise Error("Conversation output must not already exist: " + path)
    try:
        var source = content.as_bytes()
        var offset = 0
        while offset < len(source):
            var written = external_call["write", Int](Int(fd), source.unsafe_ptr().unsafe_offset(offset), len(source) - offset)
            if written <= 0:
                raise Error("Conversation output write failed")
            offset += written
        if external_call["fsync", Int32](fd) != 0:
            raise Error("Conversation output synchronization failed")
        if external_call["fsync", Int32](parent_fd) != 0:
            raise Error("Conversation output directory synchronization failed")
    except error:
        _ = external_call["close", Int32](fd)
        _ = external_call["unlink", Int32](encoded.unsafe_ptr())
        _ = external_call["close", Int32](parent_fd)
        raise error
    _ = external_call["close", Int32](fd)
    _ = external_call["close", Int32](parent_fd)


def save_conversation(path: String, state: ConversationState) raises:
    _write_exclusive(path, serialize_conversation(state))


def load_conversation(path: String) raises -> ConversationState:
    var encoded = _path_bytes(path)
    var fd = external_call["open64", Int32](encoded.unsafe_ptr(), Int32(655360), Int32(0))
    if fd < 0:
        raise Error("Cannot open conversation snapshot: " + path)
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
                raise Error("Conversation snapshot read failed")
            if len(output) + count > MAX_CONVERSATION_BYTES:
                raise Error("Conversation snapshot exceeds 16 MiB")
            for index in range(count):
                output.append(buffer[index])
    except error:
        _ = external_call["close", Int32](fd)
        raise error
    _ = external_call["close", Int32](fd)
    output.append(0)
    return deserialize_conversation(String(unsafe_from_utf8_ptr=output.unsafe_ptr()))


def export_conversation(path: String, state: ConversationState) raises:
    state.validate()
    var text = "# Aesir conversation export\n\nModel: " + state.model_identity + "\n\nProfile: " + state.profile + "\n\nSystem: " + state.system_prompt + "\n"
    for index in range(len(state.turns)):
        text += "\n## Turn " + String(index + 1) + "\n\nUser: " + state.turns[index].user + "\n\nAssistant: " + state.turns[index].assistant + "\n"
    _write_exclusive(path, text)
