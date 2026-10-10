# armvegr/tokenizer_config.mojo
# H049 — model tokenizer configs (Domain D1 ARMVEGR).
#
# Loads data/armvegr/model_tokenizer_configs.json and exposes per-family
# tokenizer type, vocab size, and special-token ids. Requesting a family not
# listed in the file is a fail-closed error (no default, no silent fallback).

from armvegr.bpe import _read_file


struct TokenizerConfig:
    var family: String
    var tokenizer: String  # "bpe" or "sp"
    var vocab_size: Int
    var bos_id: Int  # -1 if null
    var eos_id: Int
    var unk_id: Int
    var pad_id: Int
    var byte_fallback: Bool
    var add_bos_default: Bool
    var add_eos_default: Bool

    def __init__(out self):
        self.family = String("")
        self.tokenizer = String("")
        self.vocab_size = 0
        self.bos_id = -1
        self.eos_id = -1
        self.unk_id = -1
        self.pad_id = -1
        self.byte_fallback = False
        self.add_bos_default = False
        self.add_eos_default = False


def _skip_ws(s: String, bs: List[UInt8], p: Int) -> Int:
    var i = p
    while i < len(bs):
        var b = Int(bs[i])
        if b == 32 or b == 9 or b == 10 or b == 13:
            i += 1
        else:
            break
    return i


def _parse_json_string(bs: List[UInt8], p: Int) raises -> Tuple[String, Int]:
    # Assumes bs[p] == '"'. Returns (string, next_pos). Handles escapes.
    var i = p + 1
    var out = List[Int8]()
    while i < len(bs):
        var b = Int(bs[i])
        if b == 34:  # "
            i += 1
            break
        elif b == 92:  # \
            i += 1
            if i >= len(bs):
                raise Error("tokcfg: bad escape")
            var e = Int(bs[i])
            if e == 34:
                out.append(34)
            elif e == 92:
                out.append(92)
            elif e == 110:
                out.append(10)
            elif e == 116:
                out.append(9)
            elif e == 114:
                out.append(13)
            else:
                raise Error("tokcfg: unsupported escape")
            i += 1
        else:
            out.append(Int8(b))
            i += 1
    out.append(0)
    return (String(unsafe_from_utf8_ptr=out.unsafe_ptr()), i)


def _skip_json_value(bs: List[UInt8], p: Int) raises -> Int:
    """Skip a JSON value (including nested objects/arrays). Returns next pos."""
    var i = _skip_ws(String(""), bs, p)
    var b = Int(bs[i])
    if b == 34:  # string
        var _s: String
        var np: Int
        (_s, np) = _parse_json_string(bs, i)
        return np
    elif b == 123 or b == 91:  # { or [
        var depth = 1
        var instr = False
        i += 1
        while i < len(bs) and depth > 0:
            var c = Int(bs[i])
            if instr:
                if c == 92:  # backslash
                    i += 2
                    continue
                elif c == 34:
                    instr = False
            else:
                if c == 34:
                    instr = True
                elif c == 123 or c == 91:
                    depth += 1
                elif c == 125 or c == 93:
                    depth -= 1
            i += 1
        if depth != 0:
            raise Error("tokcfg: unbalanced JSON")
        return i
    else:
        # number, true, false, null: skip to , } ]
        while i < len(bs):
            var c = Int(bs[i])
            if c == 44 or c == 125 or c == 93:
                break
            i += 1
        return i


def _parse_json_value(bs: List[UInt8], p: Int) raises -> Tuple[String, Int, String]:
    # Returns (kind, next_pos, raw) where kind is "string","int","bool","null".
    var i = _skip_ws(String(""), bs, p)
    var b = Int(bs[i])
    if b == 34:
        var s: String
        var np: Int
        (s, np) = _parse_json_string(bs, i)
        return ("string", np, s)
    elif (b >= 48 and b <= 57) or b == 45:
        var j = i
        if Int(bs[j]) == 45:
            j += 1
        while j < len(bs) and Int(bs[j]) >= 48 and Int(bs[j]) <= 57:
            j += 1
        var num_str = String("")
        for k in range(i, j):
            num_str += String(chr(Int(bs[k])))
        return ("int", j, num_str)
    elif b == 116:  # true
        return ("bool", i + 4, "true")
    elif b == 102:  # false
        return ("bool", i + 5, "false")
    elif b == 110:  # null
        return ("null", i + 4, "null")
    else:
        # Nested object/array: skip and report as "skip".
        var np2 = _skip_json_value(bs, i)
        return ("skip", np2, "")


def get_tokenizer_config(path: String, family: String) raises -> TokenizerConfig:
    """Load the config for `family`. Raises (fail-closed) if absent."""
    var data = _read_file(path)
    var bs = List[UInt8]()
    for k in range(len(data)):
        bs.append(data[k])
    # Search for the family key: "<family>" followed by :{
    var key = String('"') + family + String('"')
    var kb = key.as_bytes()
    var found = -1
    var i = 0
    while i + len(kb) <= len(bs):
        var is_match = True
        for k in range(len(kb)):
            if Int(bs[i + k]) != Int(kb[k]):
                is_match = False
                break
        if is_match:
            # Verify it's a key (followed by optional ws then ':').
            var j = _skip_ws(String(""), bs, i + len(kb))
            if j < len(bs) and Int(bs[j]) == 58:
                found = i
                break
        i += 1
    if found < 0:
        raise Error("tokcfg: unknown tokenizer family '" + family + "'")
    var p = _skip_ws(String(""), bs, found + len(kb))
    p += 1  # ':'
    p = _skip_ws(String(""), bs, p)
    if Int(bs[p]) != 123:  # '{'
        raise Error("tokcfg: family value not an object")
    p += 1
    var cfg = TokenizerConfig()
    cfg.family = family
    while True:
        p = _skip_ws(String(""), bs, p)
        if Int(bs[p]) == 125:  # '}'
            break
        var fname: String
        var np: Int
        (fname, np) = _parse_json_string(bs, p)
        p = _skip_ws(String(""), bs, np)
        p += 1  # ':'
        var kind: String
        var raw: String
        (kind, p, raw) = _parse_json_value(bs, p)
        if fname == "tokenizer" and kind == "string":
            cfg.tokenizer = raw
        elif fname == "vocab_size" and kind == "int":
            cfg.vocab_size = Int(raw)
        elif fname == "bos_id":
            cfg.bos_id = -1 if kind == "null" else Int(raw)
        elif fname == "eos_id":
            cfg.eos_id = -1 if kind == "null" else Int(raw)
        elif fname == "unk_id":
            cfg.unk_id = -1 if kind == "null" else Int(raw)
        elif fname == "pad_id":
            cfg.pad_id = -1 if kind == "null" else Int(raw)
        elif fname == "byte_fallback" and kind == "bool":
            cfg.byte_fallback = raw == "true"
        elif fname == "add_bos_default" and kind == "bool":
            cfg.add_bos_default = raw == "true"
        elif fname == "add_eos_default" and kind == "bool":
            cfg.add_eos_default = raw == "true"
        # description/notes/special_tokens ignored by the loader.
        p = _skip_ws(String(""), bs, p)
        if Int(bs[p]) == 44:  # ','
            p += 1
    if cfg.tokenizer != "bpe" and cfg.tokenizer != "sp":
        raise Error("tokcfg: bad tokenizer type for '" + family + "'")
    if cfg.vocab_size <= 0:
        raise Error("tokcfg: bad vocab_size for '" + family + "'")
    return cfg^
