# armvegr/f1_config.mojo
# H136 — F1 production configuration surface (Domain D1 ARMVEGR).
#
# The pipeline's settings live in a data file (data/fallback/f1_config.json),
# never hardcoded in the driver: model/tokenizer paths, sampler settings,
# max_seq, seed, chat template. Parsed byte-wise (fail-closed) over
# armvegr.bpe._read_file. Missing required keys or malformed values raise
# named errors before any heavy work starts.

from armvegr.bpe import _read_file


struct F1Config:
    """Production configuration for the F1 CPU inference pipeline."""
    var model_path: String
    var tokenizer_path: String
    var max_seq: Int
    var seed: UInt64
    var temperature: Float32
    var top_k: Int
    var top_p: Float32
    var repetition_penalty: Float32
    var max_new_tokens: Int
    var chat_template: String
    var model_sha256: String

    def __init__(out self):
        self.model_path = String("")
        self.tokenizer_path = String("")
        self.max_seq = 1024
        self.seed = 12345
        self.temperature = Float32(0.7)
        self.top_k = 40
        self.top_p = Float32(0.95)
        self.repetition_penalty = Float32(1.1)
        self.max_new_tokens = 64
        self.chat_template = String("tinyllama")
        self.model_sha256 = String("")


def _span_to_string(data: List[UInt8], s: Int, e: Int) -> String:
    var b = List[Int8]()
    for i in range(s, e):
        b.append(Int8(data[i]))
    b.append(0)
    return String(unsafe_from_utf8_ptr=b.unsafe_ptr())


def _is_ws(c: UInt8) -> Bool:
    return c == 32 or c == 9 or c == 10 or c == 13


def _skip_ws(data: List[UInt8], pos: Int) -> Int:
    var p = pos
    while p < len(data) and _is_ws(data[p]):
        p += 1
    return p


def _key_bytes(key: String) -> List[UInt8]:
    var kb = key.as_bytes()
    var out = List[UInt8]()
    out.append(34)  # opening quote
    for i in range(len(kb)):
        out.append(kb[i])
    out.append(34)  # closing quote
    return out^


def _find_key(data: List[UInt8], key: String) raises -> Int:
    """Byte offset just past the ':' of the "key": entry."""
    var pat = _key_bytes(key)
    var n = len(data)
    var m = len(pat)
    var i = 0
    while i + m <= n:
        var hit = True
        for j in range(m):
            if data[i + j] != pat[j]:
                hit = False
                break
        if hit:
            var p = _skip_ws(data, i + m)
            if p < n and data[p] == 58:  # ':'
                return p + 1
            raise Error("f1_config: malformed entry for key: " + key)
        i += 1
    raise Error("f1_config: missing required key: " + key)


def _parse_string_val(data: List[UInt8], pos: Int, key: String) raises -> String:
    var p = _skip_ws(data, pos)
    if p >= len(data) or data[p] != 34:
        raise Error("f1_config: expected string value for key: " + key)
    p += 1
    var s = p
    while True:
        if p >= len(data):
            raise Error("f1_config: unterminated string for key: " + key)
        if data[p] == 92:  # backslash escape: keep both bytes raw
            p += 2
            continue
        if data[p] == 34:
            break
        p += 1
    return _span_to_string(data, s, p)


def _parse_num_span(data: List[UInt8], pos: Int, key: String) raises -> Tuple[Int, Int]:
    var p = _skip_ws(data, pos)
    var s = p
    while p < len(data):
        var c = data[p]
        if c == 44 or c == 125 or _is_ws(c):  # ',' or '}'
            break
        p += 1
    if p == s:
        raise Error("f1_config: empty numeric value for key: " + key)
    return (s, p)


def _parse_int_val(data: List[UInt8], pos: Int, key: String) raises -> Int:
    var se = _parse_num_span(data, pos, key)
    var s = se[0]
    var e = se[1]
    var neg = False
    if data[s] == 45:  # '-'
        neg = True
        s += 1
    if s >= e:
        raise Error("f1_config: bad int for key: " + key)
    var v = 0
    for i in range(s, e):
        var d = Int(data[i]) - 48
        if d < 0 or d > 9:
            raise Error("f1_config: bad int for key: " + key)
        v = v * 10 + d
    return -v if neg else v


def _parse_float_val(data: List[UInt8], pos: Int, key: String) raises -> Float32:
    var se = _parse_num_span(data, pos, key)
    var s = se[0]
    var e = se[1]
    var neg = False
    if data[s] == 45:
        neg = True
        s += 1
    var whole = 0
    var frac = 0
    var fdiv = 1
    var seen_dot = False
    var ndig = 0
    var i = s
    while i < e:
        var c = data[i]
        if c == 46:  # '.'
            if seen_dot:
                raise Error("f1_config: bad float for key: " + key)
            seen_dot = True
        else:
            var d = Int(c) - 48
            if d < 0 or d > 9:
                raise Error("f1_config: bad float for key: " + key)
            ndig += 1
            if seen_dot:
                frac = frac * 10 + d
                fdiv *= 10
            else:
                whole = whole * 10 + d
        i += 1
    if ndig == 0:
        raise Error("f1_config: bad float for key: " + key)
    var v = Float32(whole) + Float32(frac) / Float32(fdiv)
    return -v if neg else v


def f1_config_load(path: String) raises -> F1Config:
    """Load and validate the F1 production config. All values fail-closed."""
    var data = _read_file(path)
    var p0 = _skip_ws(data, 0)
    if p0 >= len(data) or data[p0] != 123:  # '{'
        raise Error("f1_config: not a JSON object: " + path)
    var c = F1Config()
    c.model_path = _parse_string_val(data, _find_key(data, "model_path"), "model_path")
    c.tokenizer_path = _parse_string_val(
        data, _find_key(data, "tokenizer_path"), "tokenizer_path"
    )
    c.max_seq = _parse_int_val(data, _find_key(data, "max_seq"), "max_seq")
    c.seed = UInt64(_parse_int_val(data, _find_key(data, "seed"), "seed"))
    c.temperature = _parse_float_val(
        data, _find_key(data, "temperature"), "temperature"
    )
    c.top_k = _parse_int_val(data, _find_key(data, "top_k"), "top_k")
    c.top_p = _parse_float_val(data, _find_key(data, "top_p"), "top_p")
    c.repetition_penalty = _parse_float_val(
        data, _find_key(data, "repetition_penalty"), "repetition_penalty"
    )
    c.max_new_tokens = _parse_int_val(
        data, _find_key(data, "max_new_tokens"), "max_new_tokens"
    )
    c.chat_template = _parse_string_val(
        data, _find_key(data, "chat_template"), "chat_template"
    )
    c.model_sha256 = _parse_string_val(
        data, _find_key(data, "model_sha256"), "model_sha256"
    )
    # Validation: fail closed on nonsense before any heavy work starts.
    if c.max_seq <= 0 or c.max_seq > 8192:
        raise Error("f1_config: max_seq out of range (1..8192)")
    if c.max_new_tokens <= 0 or c.max_new_tokens > c.max_seq:
        raise Error("f1_config: max_new_tokens out of range")
    if c.temperature < Float32(0.0) or c.temperature > Float32(2.0):
        raise Error("f1_config: temperature out of range (0..2)")
    if c.top_k < 0 or c.top_k > 32000:
        raise Error("f1_config: top_k out of range")
    if c.top_p <= Float32(0.0) or c.top_p > Float32(1.0):
        raise Error("f1_config: top_p out of range (0..1]")
    if c.repetition_penalty < Float32(1.0):
        raise Error("f1_config: repetition_penalty < 1.0 unsupported")
    if c.model_path == "" or c.tokenizer_path == "":
        raise Error("f1_config: empty model/tokenizer path")
    if c.model_sha256 == "":
        raise Error("f1_config: empty model_sha256 (pin the model file hash)")
    return c^


def f1_config_version() -> String:
    return "0.1.0"
