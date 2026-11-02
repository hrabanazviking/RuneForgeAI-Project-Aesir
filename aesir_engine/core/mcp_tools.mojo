"""MCP model-as-tools: the pure protocol + dispatch layer
(Janas road J-109).

The roadmap text: "MCP: the model as tools. Aesir served
as MCP tools (the janas-mcp behaviour): generate,
embed-where-honest, model info; an editor/agent client
session proven end-to-end with a real MCP client."
J-099's census row T21 found the surface ABSENT (a word
scan for MCP over every .mojo: zero hits; no generate /
embed MCP tool, no stdio server) and assigned it to this
slice together with T22's client side, which the J-109
doc's section 0.5 proves in standalone form.

This module is the pure layer, in the road's established
shape (pure logic, unit-tested at the lightest target;
the hosts execute the decisions; no socket, process, or
engine lives here):

- TRANSPORT SHAPE. MCP's canonical local transport is
  JSON-RPC 2.0 over stdio, one JSON object per line; an
  editor/agent client spawns the server and speaks
  newline-delimited JSON-RPC on its stdin/stdout. This
  layer decides everything about a line; the host
  (cli/mcp_serve.mojo) only reads lines, prints reply
  payloads, and carries the session state between lines.
- THE SCANNER. server/local_protocol.mojo's FlatJSON
  accepts only string/boolean/number field values by
  design, and a JSON-RPC request carries params as a
  nested object -- the flat parser raises on exactly the
  field this protocol is made of. The scanner below is
  therefore this layer's own: bounded (a 64 KiB line
  bound, a 64-byte field-name bound, a nesting bound),
  string-aware balanced capture for object/array values,
  escapes decoded on string values. Malformed input is
  a verdict (-32700), never a crash.
- THE THREE TOOLS (the J-109 protocol section 0.4).
  aesir_generate: prompt required; validated here; the
  dispatch verdict is NEEDS_GENERATE when the host has a
  live engine bound, and the honest no-engine tool error
  when it has not -- never invented text. aesir_model_info:
  answered from the J-103 catalogue facts the host passes
  in as McpModelFact records (this layer never imports
  the CLI layer; the tree's dependency direction is
  kept). aesir_embed: REFUSES, always, in this road's
  current state -- no embedding data path exists in
  Aesir (the live serve states embeddings:false, the
  OpenAI-shape formatter is an error-only stub, and the
  facade's mean-pooled extract_query_embedding is not a
  graded embedding model); returning those numbers as
  embeddings would be a fake vector with a real-looking
  shape. The refusal is a proper MCP tool error
  (isError: true), and the tools/list description states
  it up front so discovery itself is honest.
- PROTOCOL VERDICTS. Unparseable line: -32700. No
  method: -32600. Unknown method: -32601. Any request
  other than initialize/ping before initialize: -32002
  (the MCP specification's own server-not-initialized
  code). Ill-formed tools/call (unknown tool, missing
  name/arguments, missing required argument): -32602
  with the reason. Notifications (no id) are answered
  with silence, per spec. A request id is echoed as the
  raw JSON value the client sent, never re-typed.
  Tool-level failures (unknown model, no engine bound,
  the embed refusal) are NOT protocol errors: they are
  normal results whose single text content block carries
  isError: true -- the MCP shape for a tool that ran and
  failed honestly.

HOST CONTRACT. cli/mcp_serve.mojo converts the J-103
catalogue (cli/known_models.mojo's known_models_dataset)
to McpModelFact records once at start, carries one
McpSession between lines, calls mcp_handle_line per
line with engine_bound stating whether a live engine
session is bound (false in the J-109 host build -- the
engine binding is the deferred live leg, J-109 doc
section 5), prints reply.payload as one stdout line
when reply.respond is true, applies
reply.now_initialized to the session, and -- in a bound
build -- executes reply.needs_generate through the
engine facade (aesir.mojo's AesirEngine
generate_tokens_config) and completes the call through
mcp_generate_completion / mcp_generate_failure below.
Nothing else may ever be printed to the host's stdout:
the protocol channel is the product. This module
executes nothing, opens no device, and contains no
speed; any live generation through MCP is graded under
the road's honesty rules and is deferred with its
recipe in the J-109 doc section 5, re-cited at the
J-118 gate.

J-112 EXTENSION (the services surface). Four tools join
the three above, all decided in this layer and
inventoried in core/services_surface.mojo (the registry
both doors serve): aesir_tokenize (MODEL_BOUND,
mirroring generate: validated here, the honest
no-tokenizer tool error when the host has no tokenizer
bound, NEEDS_TOKENIZE with completion/failure envelopes
when it has), aesir_grade (pure: one teacher-forcing
step record graded by core/prefill_grade through
core/services_surface -- never a re-implementation;
comparator_valid defaults to false, so an unstated
comparator check grades COMPARATOR_ARTIFACT),
aesir_census (pure: the catalogue census plus the
services inventory, from the same facts), and
aesir_bench (the bench report form: the layer sets
NEEDS_BENCH and the host executes it -- observing the
device inventory and rendering the filed evidence
table need no model -- completing through
mcp_bench_completion; the sweep itself stays CLI-only,
J-112 doc section 0.2).
"""

from core.services_surface import (
    ServiceModelFact,
    svc_census_text,
    svc_grade_step_text,
    svc_inventory_text,
)


# ------------------------------------------------------------------
# Protocol facts (J-109 doc section 0.2; answered-locally there).
# ------------------------------------------------------------------


def mcp_protocol_version() -> String:
    return String("2024-11-05")


def mcp_server_name() -> String:
    return String("aesir")


def mcp_server_version() -> String:
    return String("1.0.0")


def mcp_max_line_bytes() -> Int:
    return 65536


# Method classes returned by mcp_classify_method.
def mcp_method_initialize() -> Int:
    return 1


def mcp_method_ping() -> Int:
    return 2


def mcp_method_tools_list() -> Int:
    return 3


def mcp_method_tools_call() -> Int:
    return 4


def mcp_method_notification() -> Int:
    return 5


def mcp_method_unknown() -> Int:
    return 0


def mcp_classify_method(method: String) -> Int:
    if method == "initialize":
        return mcp_method_initialize()
    if method == "ping":
        return mcp_method_ping()
    if method == "tools/list":
        return mcp_method_tools_list()
    if method == "tools/call":
        return mcp_method_tools_call()
    if method.startswith("notifications/"):
        return mcp_method_notification()
    return mcp_method_unknown()


def mcp_tool_names() -> List[String]:
    var names = List[String]()
    names.append(String("aesir_generate"))
    names.append(String("aesir_model_info"))
    names.append(String("aesir_embed"))
    names.append(String("aesir_tokenize"))
    names.append(String("aesir_grade"))
    names.append(String("aesir_census"))
    names.append(String("aesir_bench"))
    return names^


def mcp_no_tokenizer_reason() -> String:
    return String(
        "no tokenizer is bound in this MCP host: a"
        " tokenizer is constructed from a loaded model"
        " file, so token ids need an engine-bound host"
        " (the same binding as aesir_generate). This host"
        " answers honestly rather than returning"
        " pre-tokenization segments dressed as token ids."
        " The binding leg is filed in the J-112 doc"
        " section 5."
    )


def mcp_embed_refusal_reason() -> String:
    return String(
        "embeddings are not available in Aesir: no embedding"
        " data path exists (the HTTP service states"
        " embeddings:false and its embeddings formatter is"
        " an error-only stub), and the engine facade's"
        " mean-pooled token embeddings are not a graded"
        " embedding model. Returning them as embeddings"
        " would be a fake vector, so this tool refuses"
        " until a graded embedding model kind exists."
    )


def mcp_no_engine_reason() -> String:
    return String(
        "no live model session is bound in this MCP host:"
        " generation needs an engine-bound host started"
        " over a locally present model file. This host"
        " answers model info from the catalogue and"
        " refuses generation honestly rather than"
        " inventing text. The engine-binding leg is filed"
        " in the J-109 doc section 5."
    )


# ------------------------------------------------------------------
# The bounded JSON scanner.
# ------------------------------------------------------------------


struct McpField(Copyable, ImplicitlyCopyable):
    var found: Bool
    var kind: String
    var value: String

    def __init__(out self, found: Bool, kind: String, value: String):
        self.found = found
        self.kind = kind
        self.value = value

    def __copyinit__(out self, existing: Self):
        self.found = existing.found
        self.kind = existing.kind
        self.value = existing.value


struct _StrParse(Copyable, ImplicitlyCopyable):
    var ok: Bool
    var value: String
    var next: Int

    def __init__(out self, ok: Bool, value: String, next: Int):
        self.ok = ok
        self.value = value
        self.next = next

    def __copyinit__(out self, existing: Self):
        self.ok = existing.ok
        self.value = existing.value
        self.next = existing.next



def _str_from_bytes(bytes: List[Byte]) -> String:
    """Builds a String from raw bytes via the tree's
    proven idiom (a NUL terminator + unsafe_from_utf8_ptr,
    as in core/tool_use.mojo). NOTE: String(List[Byte])
    in this toolchain produces the list's debug
    representation, not its characters -- measured in
    this slice (J-109 doc section 7)."""
    var terminated = List[Byte]()
    for b in bytes:
        terminated.append(b)
    terminated.append(Byte(0))
    return String(unsafe_from_utf8_ptr=terminated.unsafe_ptr())


def _char_str(b: Int) -> String:
    var bytes = List[Byte]()
    bytes.append(Byte(b))
    return _str_from_bytes(bytes)


def _byte(text: String, pos: Int) -> Int:
    if pos < 0 or pos >= text.byte_length():
        return -1
    return Int(text.as_bytes()[pos])


def _skip_ws(text: String, pos: Int) -> Int:
    var p = pos
    while True:
        var b = _byte(text, p)
        if b == 32 or b == 9 or b == 10 or b == 13:
            p += 1
        else:
            break
    return p


def _hex_val(b: Int) -> Int:
    if b >= 48 and b <= 57:
        return b - 48
    if b >= 65 and b <= 70:
        return b - 55
    if b >= 97 and b <= 102:
        return b - 87
    return -1


def _parse_json_string(text: String, pos: Int) -> _StrParse:
    """Parses a JSON string at pos (which must be at the
    opening quote); returns the decoded value and the
    position just past the closing quote."""
    if _byte(text, pos) != 34:
        return _StrParse(False, String(""), pos)
    var p = pos + 1
    var out = String("")
    while True:
        var b = _byte(text, p)
        if b == -1:
            return _StrParse(False, String(""), pos)
        if b == 34:
            return _StrParse(True, out, p + 1)
        if b == 92:
            var e = _byte(text, p + 1)
            if e == 34:
                out += String("\"")
                p += 2
            elif e == 92:
                out += String("\\")
                p += 2
            elif e == 47:
                out += String("/")
                p += 2
            elif e == 98:
                out += String("\x08")
                p += 2
            elif e == 102:
                out += String("\x0c")
                p += 2
            elif e == 110:
                out += String("\n")
                p += 2
            elif e == 114:
                out += String("\r")
                p += 2
            elif e == 116:
                out += String("\t")
                p += 2
            elif e == 117:
                var cp = 0
                var ok = True
                for k in range(4):
                    var hv = _hex_val(_byte(text, p + 2 + k))
                    if hv < 0:
                        ok = False
                        break
                    cp = cp * 16 + hv
                if not ok:
                    return _StrParse(False, String(""), pos)
                # Bounded honesty: only ASCII escapes are
                # decoded; a non-ASCII escape decodes to
                # '?' rather than pretending full Unicode
                # handling this layer does not have.
                if cp >= 32 and cp < 127:
                    out += String(chr(cp))
                else:
                    out += String("?")
                p += 6
            else:
                return _StrParse(False, String(""), pos)
        elif b < 32:
            return _StrParse(False, String(""), pos)
        else:
            # Copy the raw byte (UTF-8 passes through).
            out += _char_str(b)
            p += 1


def _scan_balanced(text: String, pos: Int) -> _StrParse:
    """Captures a balanced object/array starting at pos
    as raw text; string-aware, depth-bounded."""
    var open_b = _byte(text, pos)
    if open_b != 123 and open_b != 91:
        return _StrParse(False, String(""), pos)
    var depth = 0
    var p = pos
    var start = pos
    while True:
        var b = _byte(text, p)
        if b == -1:
            return _StrParse(False, String(""), pos)
        if b == 34:
            var s = _parse_json_string(text, p)
            if not s.ok:
                return _StrParse(False, String(""), pos)
            p = s.next
            continue
        if b == 123 or b == 91:
            depth += 1
            if depth > 32:
                return _StrParse(False, String(""), pos)
            p += 1
            continue
        if b == 125 or b == 93:
            depth -= 1
            p += 1
            if depth == 0:
                var raw_bytes = List[Byte]()
                var q = start
                while q < p:
                    raw_bytes.append(Byte(_byte(text, q)))
                    q += 1
                return _StrParse(True, _str_from_bytes(raw_bytes), p)
            if depth < 0:
                return _StrParse(False, String(""), pos)
            continue
        p += 1


def mcp_json_object_ok(text: String) -> Bool:
    """True iff text is exactly one balanced JSON object
    (bounded), with nothing but whitespace after it."""
    if text.byte_length() == 0 or text.byte_length() > mcp_max_line_bytes():
        return False
    var p = _skip_ws(text, 0)
    if _byte(text, p) != 123:
        return False
    var scanned = _scan_balanced(text, p)
    if not scanned.ok:
        return False
    return _skip_ws(text, scanned.next) == text.byte_length()


def mcp_scan_field(text: String, key: String) -> McpField:
    """Finds a top-level field of the JSON object in
    text. String values are returned decoded; object and
    array values as raw balanced text; numbers, booleans
    and null as their raw literal. A missing or malformed
    field answers found == False."""
    var missing = McpField(False, String(""), String(""))
    var p = _skip_ws(text, 0)
    if _byte(text, p) != 123:
        return missing
    p += 1
    p = _skip_ws(text, p)
    if _byte(text, p) == 125:
        return missing
    while True:
        p = _skip_ws(text, p)
        var k = _parse_json_string(text, p)
        if not k.ok or k.value.byte_length() > 64:
            return missing
        p = _skip_ws(text, k.next)
        if _byte(text, p) != 58:
            return missing
        p = _skip_ws(text, p + 1)
        var b = _byte(text, p)
        var kind = String("")
        var value = String("")
        var next = p
        if b == 34:
            var v = _parse_json_string(text, p)
            if not v.ok:
                return missing
            kind = String("string")
            value = v.value
            next = v.next
        elif b == 123 or b == 91:
            var v = _scan_balanced(text, p)
            if not v.ok:
                return missing
            kind = String("object") if b == 123 else String("array")
            value = v.value
            next = v.next
        else:
            var q = p
            while True:
                var c = _byte(text, q)
                if c == 44 or c == 125 or c == 32 or c == 9 or c == -1:
                    break
                q += 1
            var raw_bytes2 = List[Byte]()
            var r = p
            while r < q:
                raw_bytes2.append(Byte(_byte(text, r)))
                r += 1
            var raw = _str_from_bytes(raw_bytes2)
            if raw == "true" or raw == "false":
                kind = String("bool")
            elif raw == "null":
                kind = String("null")
            elif raw.byte_length() > 0:
                kind = String("number")
            else:
                return missing
            value = raw
            next = q
        if k.value == key:
            return McpField(True, kind, value)
        p = _skip_ws(text, next)
        if _byte(text, p) == 44:
            p += 1
            continue
        return missing
    return missing


def mcp_json_escape(text: String) -> String:
    var hexd = String("0123456789abcdef")
    var out = String("")
    for i in range(text.byte_length()):
        var b = Int(text.as_bytes()[i])
        if b == 34:
            out += String("\\\"")
        elif b == 92:
            out += String("\\\\")
        elif b == 10:
            out += String("\\n")
        elif b == 13:
            out += String("\\r")
        elif b == 9:
            out += String("\\t")
        elif b < 32:
            out += String("\\u00")
            out += _char_str(Int(hexd.as_bytes()[(b >> 4) & 15]))
            out += _char_str(Int(hexd.as_bytes()[b & 15]))
        else:
            out += _char_str(b)
    return out


def _parse_int_literal(raw: String) -> Int:
    """Parses a JSON number literal as an Int; returns
    -1 for anything that is not a plain integer in
    range (the caller treats -1 as ill-typed where a
    positive count is required)."""
    var p = _skip_ws(raw, 0)
    var neg = False
    if _byte(raw, p) == 45:
        neg = True
        p += 1
    var value = 0
    var digits = 0
    while True:
        var b = _byte(raw, p)
        if b < 48 or b > 57:
            break
        value = value * 10 + (b - 48)
        digits += 1
        p += 1
        if value > 100000000:
            return -1
    if digits == 0:
        return -1
    p = _skip_ws(raw, p)
    if p != raw.byte_length():
        return -1
    if neg:
        return -value
    return value


# ------------------------------------------------------------------
# Facts, session, replies.
# ------------------------------------------------------------------


struct McpModelFact(Copyable, ImplicitlyCopyable):
    var name: String
    var tag: String
    var repository: String
    var filename: String
    var revision: String
    var sha256: String
    var size_bytes: Int
    var quantization: String

    def __init__(
        out self,
        name: String,
        tag: String,
        repository: String,
        filename: String,
        revision: String,
        sha256: String,
        size_bytes: Int,
        quantization: String,
    ):
        self.name = name
        self.tag = tag
        self.repository = repository
        self.filename = filename
        self.revision = revision
        self.sha256 = sha256
        self.size_bytes = size_bytes
        self.quantization = quantization

    def __copyinit__(out self, existing: Self):
        self.name = existing.name
        self.tag = existing.tag
        self.repository = existing.repository
        self.filename = existing.filename
        self.revision = existing.revision
        self.sha256 = existing.sha256
        self.size_bytes = existing.size_bytes
        self.quantization = existing.quantization


struct McpSession(Copyable, ImplicitlyCopyable):
    var initialized: Bool

    def __init__(out self):
        self.initialized = False

    def __copyinit__(out self, existing: Self):
        self.initialized = existing.initialized


struct McpReply(Copyable, ImplicitlyCopyable):
    var respond: Bool
    var payload: String
    var needs_generate: Bool
    var gen_prompt: String
    var gen_max_tokens: Int
    var gen_id_raw: String
    var now_initialized: Bool
    var needs_tokenize: Bool
    var tok_text: String
    var needs_bench: Bool

    def __init__(out self):
        self.respond = False
        self.payload = String("")
        self.needs_generate = False
        self.gen_prompt = String("")
        self.gen_max_tokens = 0
        self.gen_id_raw = String("null")
        self.now_initialized = False
        self.needs_tokenize = False
        self.tok_text = String("")
        self.needs_bench = False

    def __copyinit__(out self, existing: Self):
        self.respond = existing.respond
        self.payload = existing.payload
        self.needs_generate = existing.needs_generate
        self.gen_prompt = existing.gen_prompt
        self.gen_max_tokens = existing.gen_max_tokens
        self.gen_id_raw = existing.gen_id_raw
        self.now_initialized = existing.now_initialized
        self.needs_tokenize = existing.needs_tokenize
        self.tok_text = existing.tok_text
        self.needs_bench = existing.needs_bench


# ------------------------------------------------------------------
# Response builders.
# ------------------------------------------------------------------


def mcp_result_response(id_raw: String, result_json: String) -> String:
    return (
        String("{\"jsonrpc\":\"2.0\",\"id\":") + id_raw
        + String(",\"result\":") + result_json + String("}")
    )


def mcp_error_response(id_raw: String, code: Int, message: String) -> String:
    return (
        String("{\"jsonrpc\":\"2.0\",\"id\":") + id_raw
        + String(",\"error\":{\"code\":") + String(code)
        + String(",\"message\":\"") + mcp_json_escape(message)
        + String("\"}}")
    )


def mcp_tool_text_result(text: String, is_error: Bool) -> String:
    var err = String("true") if is_error else String("false")
    return (
        String("{\"content\":[{\"type\":\"text\",\"text\":\"")
        + mcp_json_escape(text)
        + String("\"}],\"isError\":") + err + String("}")
    )


def mcp_generate_completion(id_raw: String, text: String) -> String:
    """The success envelope for a generate call the host
    executed through the engine (the bound build)."""
    return mcp_result_response(id_raw, mcp_tool_text_result(text, False))


def mcp_generate_failure(id_raw: String, reason: String) -> String:
    """The tool-error envelope for a generate call whose
    engine execution failed in the host."""
    return mcp_result_response(id_raw, mcp_tool_text_result(reason, True))


def mcp_tokenize_completion(id_raw: String, ids_text: String) -> String:
    """The success envelope for a tokenize call the host
    executed through the bound tokenizer (the bound
    build): ids_text is the host's formatted id list
    (core/services_surface.svc_format_tokenize)."""
    return mcp_result_response(id_raw, mcp_tool_text_result(ids_text, False))


def mcp_tokenize_failure(id_raw: String, reason: String) -> String:
    """The tool-error envelope for a tokenize call whose
    tokenizer execution failed in the host."""
    return mcp_result_response(id_raw, mcp_tool_text_result(reason, True))


def mcp_bench_completion(id_raw: String, report_text: String) -> String:
    """The success envelope for a bench call the host
    executed (the report form: its observed device
    inventory composed with the filed evidence table,
    core/services_surface.svc_bench_text)."""
    return mcp_result_response(
        id_raw, mcp_tool_text_result(report_text, False)
    )


def mcp_tools_list_result() -> String:
    var generate = String(
        "{\"name\":\"aesir_generate\",\"description\":"
        "\"Generate text with the model bound to this MCP"
        " host. Generation runs the engine's real facade"
        " path; a host started without a bound model"
        " answers with an honest error instead of invented"
        " text.\",\"inputSchema\":{\"type\":\"object\","
        "\"properties\":{\"prompt\":{\"type\":\"string\","
        "\"description\":\"The prompt to generate from.\"},"
        "\"model\":{\"type\":\"string\",\"description\":"
        "\"Optional catalogue name of the bound model.\"},"
        "\"max_tokens\":{\"type\":\"integer\",\"minimum\":1,"
        "\"maximum\":4096,\"default\":256}},"
        "\"required\":[\"prompt\"]}}"
    )
    var info = String(
        "{\"name\":\"aesir_model_info\",\"description\":"
        "\"Report a model's catalogue record (source"
        " repository, file, revision, sha256 pin, size,"
        " quantization) from Aesir's known-models"
        " catalogue. With no argument, list the catalogue."
        " This is the catalogue record, not a loaded"
        " model's self-report.\",\"inputSchema\":"
        "{\"type\":\"object\",\"properties\":{\"model\":"
        "{\"type\":\"string\",\"description\":\"Catalogue"
        " name or name:tag; omit to list the catalogue.\"}"
        "}}}"
    )
    var embed = String(
        "{\"name\":\"aesir_embed\",\"description\":"
        "\"Embed text -- UNAVAILABLE in Aesir today: no"
        " embedding data path exists, so this tool always"
        " refuses honestly rather than returning a fake"
        " vector.\",\"inputSchema\":{\"type\":\"object\","
        "\"properties\":{\"input\":{\"type\":\"string\"}},"
        "\"required\":[\"input\"]}}"
    )
    var tokenize = String(
        "{\"name\":\"aesir_tokenize\",\"description\":"
        "\"Tokenize text to token ids with the tokenizer"
        " bound to this MCP host. A tokenizer is built"
        " from a loaded model file, so a host started"
        " without a bound model answers with an honest"
        " error instead of pre-tokenization segments"
        " dressed as ids.\",\"inputSchema\":{\"type\":"
        "\"object\",\"properties\":{\"text\":{\"type\":"
        "\"string\",\"description\":\"The text to"
        " tokenize.\"},\"model\":{\"type\":\"string\","
        "\"description\":\"Optional catalogue name of"
        " the bound model.\"}},\"required\":[\"text\"]}}"
    )
    var grade = String(
        "{\"name\":\"aesir_grade\",\"description\":"
        "\"Grade one teacher-forcing step record by"
        " Aesir's raw-oracle rule (rank + logit gap):"
        " the step class and cell verdict from"
        " core/prefill_grade. comparator_valid defaults"
        " to false -- an unstated comparator check"
        " grades COMPARATOR_ARTIFACT, never a free"
        " FAITHFUL.\",\"inputSchema\":{\"type\":"
        "\"object\",\"properties\":{\"rank\":{\"type\":"
        "\"integer\",\"minimum\":0,\"description\":"
        "\"Teacher-forcing rank of the engine's id.\"},"
        "\"gap_milli\":{\"type\":\"integer\",\"minimum\""
        ":0,\"description\":\"Logit gap in milli-"
        "logits.\"},\"comparator_valid\":{\"type\":"
        "\"boolean\",\"description\":\"The caller's"
        " statement that the comparator check passed"
        " (CPU comparator, raw prompt).\"}},\"required\""
        ":[\"rank\",\"gap_milli\"]}}"
    )
    var census = String(
        "{\"name\":\"aesir_census\",\"description\":"
        "\"The known-models catalogue as a population"
        " (count, total bytes, per-quantization counts,"
        " per-entry lines) plus Aesir's services"
        " inventory with each service's availability"
        " and reason.\",\"inputSchema\":{\"type\":"
        "\"object\",\"properties\":{}}}"
    )
    var bench = String(
        "{\"name\":\"aesir_bench\",\"description\":"
        "\"The bench machine report (report form): this"
        " host's live device inventory plus the filed"
        " per-model evidence table. The configuration"
        " sweep itself is CLI-only (aesir bench) -- a"
        " minutes-long run no stdio host is blocked"
        " on.\",\"inputSchema\":{\"type\":\"object\","
        "\"properties\":{}}}"
    )
    return (
        String("{\"tools\":[") + generate + String(",") + info
        + String(",") + embed + String(",") + tokenize
        + String(",") + grade + String(",") + census
        + String(",") + bench + String("]}")
    )


# ------------------------------------------------------------------
# Model info from catalogue facts.
# ------------------------------------------------------------------


def _fact_reference(fact: McpModelFact) -> String:
    return fact.name + String(":") + fact.tag


def _find_fact(facts: List[McpModelFact], model: String) -> Int:
    for i in range(len(facts)):
        if facts[i].name == model or _fact_reference(facts[i]) == model:
            return i
    return -1


def _known_references(facts: List[McpModelFact]) -> String:
    var out = String("")
    for i in range(len(facts)):
        if i > 0:
            out += String(", ")
        out += _fact_reference(facts[i])
    return out


def _fact_record_json(fact: McpModelFact, engine_bound: Bool) -> String:
    var bound = String("true") if engine_bound else String("false")
    return (
        String("{\"name\":\"") + mcp_json_escape(fact.name)
        + String("\",\"tag\":\"") + mcp_json_escape(fact.tag)
        + String("\",\"repository\":\"")
        + mcp_json_escape(fact.repository)
        + String("\",\"filename\":\"")
        + mcp_json_escape(fact.filename)
        + String("\",\"revision\":\"")
        + mcp_json_escape(fact.revision)
        + String("\",\"sha256\":\"") + mcp_json_escape(fact.sha256)
        + String("\",\"size_bytes\":") + String(fact.size_bytes)
        + String(",\"quantization\":\"")
        + mcp_json_escape(fact.quantization)
        + String("\",\"source\":\"known-models catalogue record\",")
        + String("\"live_session_bound\":") + bound + String("}")
    )


def _catalogue_listing(facts: List[McpModelFact]) -> String:
    var out = String("known-models catalogue (")
    out += String(len(facts))
    out += String(" entries):")
    for i in range(len(facts)):
        out += String("\n- ") + _fact_reference(facts[i])
        out += String(" (") + facts[i].quantization
        out += String(", ") + String(facts[i].size_bytes)
        out += String(" bytes)")
    return out


# ------------------------------------------------------------------
# The request handler.
# ------------------------------------------------------------------


def _id_raw(line: String) -> String:
    var f = mcp_scan_field(line, "id")
    if not f.found or f.kind == "null":
        return String("null")
    if f.kind == "string":
        return String("\"") + mcp_json_escape(f.value) + String("\"")
    return f.value


def _has_id(line: String) -> Bool:
    var f = mcp_scan_field(line, "id")
    return f.found and f.kind != "null"


def _reply_error(id_raw: String, code: Int, message: String) -> McpReply:
    var reply = McpReply()
    reply.respond = True
    reply.payload = mcp_error_response(id_raw, code, message)
    reply.gen_id_raw = id_raw
    return reply


def _reply_result(id_raw: String, result_json: String) -> McpReply:
    var reply = McpReply()
    reply.respond = True
    reply.payload = mcp_result_response(id_raw, result_json)
    reply.gen_id_raw = id_raw
    return reply


def _reply_tool_error(id_raw: String, text: String) -> McpReply:
    return _reply_result(id_raw, mcp_tool_text_result(text, True))


def _handle_tools_call(
    line: String,
    id_raw: String,
    facts: List[McpModelFact],
    engine_bound: Bool,
    bound_model: String,
) -> McpReply:
    var params = mcp_scan_field(line, "params")
    if not params.found or params.kind != "object":
        return _reply_error(
            id_raw, -32602, "tools/call requires a params object"
        )
    var name_f = mcp_scan_field(params.value, "name")
    if not name_f.found or name_f.kind != "string":
        return _reply_error(
            id_raw, -32602, "tools/call requires a string tool name"
        )
    var tool = name_f.value
    var known = False
    for n in mcp_tool_names():
        if n == tool:
            known = True
    if not known:
        var known_text = String("")
        var all_names = mcp_tool_names()
        for i in range(len(all_names)):
            if i > 0:
                known_text += String(", ")
            known_text += all_names[i]
        return _reply_error(
            id_raw,
            -32602,
            String("unknown tool: ") + tool
            + String(" (known: ") + known_text + String(")"),
        )
    var args = mcp_scan_field(params.value, "arguments")
    var args_text = String("{}")
    if args.found:
        if args.kind != "object":
            return _reply_error(
                id_raw, -32602, "tool arguments must be an object"
            )
        args_text = args.value

    if tool == "aesir_embed":
        var input_f = mcp_scan_field(args_text, "input")
        if not input_f.found or input_f.kind != "string":
            return _reply_error(
                id_raw,
                -32602,
                "aesir_embed requires a string 'input' argument",
            )
        return _reply_tool_error(id_raw, mcp_embed_refusal_reason())

    if tool == "aesir_model_info":
        var model_f = mcp_scan_field(args_text, "model")
        if not model_f.found:
            return _reply_result(
                id_raw,
                mcp_tool_text_result(_catalogue_listing(facts), False),
            )
        if model_f.kind != "string":
            return _reply_error(
                id_raw, -32602, "model must be a string"
            )
        var idx = _find_fact(facts, model_f.value)
        if idx < 0:
            return _reply_tool_error(
                id_raw,
                String("unknown model: ") + model_f.value
                + String(" (known: ") + _known_references(facts)
                + String(")"),
            )
        return _reply_result(
            id_raw,
            mcp_tool_text_result(
                _fact_record_json(facts[idx], engine_bound), False
            ),
        )

    if tool == "aesir_census":
        var service_facts = List[ServiceModelFact]()
        for fact in facts:
            service_facts.append(
                ServiceModelFact(
                    fact.name, fact.tag, fact.quantization,
                    fact.size_bytes,
                )
            )
        return _reply_result(
            id_raw,
            mcp_tool_text_result(
                svc_census_text(service_facts)
                + String("\n")
                + svc_inventory_text(),
                False,
            ),
        )

    if tool == "aesir_grade":
        var rank_f = mcp_scan_field(args_text, "rank")
        var gap_f = mcp_scan_field(args_text, "gap_milli")
        if not rank_f.found or rank_f.kind != "number":
            return _reply_error(
                id_raw,
                -32602,
                "aesir_grade requires an integer 'rank' argument",
            )
        if not gap_f.found or gap_f.kind != "number":
            return _reply_error(
                id_raw,
                -32602,
                "aesir_grade requires an integer 'gap_milli'"
                " argument",
            )
        var rank = _parse_int_literal(rank_f.value)
        var gap = _parse_int_literal(gap_f.value)
        if rank < 0 or gap < 0:
            return _reply_error(
                id_raw,
                -32602,
                "aesir_grade rank and gap_milli must be"
                " non-negative integers",
            )
        var comparator_valid = False
        var valid_f = mcp_scan_field(args_text, "comparator_valid")
        if valid_f.found:
            if valid_f.kind != "bool":
                return _reply_error(
                    id_raw,
                    -32602,
                    "comparator_valid must be a boolean",
                )
            comparator_valid = valid_f.value == "true"
        try:
            var graded = svc_grade_step_text(rank, gap, comparator_valid)
            return _reply_result(
                id_raw, mcp_tool_text_result(graded, False)
            )
        except e:
            return _reply_tool_error(
                id_raw,
                String("grade refused: ") + String(e),
            )

    if tool == "aesir_bench":
        var bench_reply = McpReply()
        bench_reply.respond = False
        bench_reply.needs_bench = True
        bench_reply.gen_id_raw = id_raw
        return bench_reply

    if tool == "aesir_tokenize":
        var text_f = mcp_scan_field(args_text, "text")
        if (
            not text_f.found
            or text_f.kind != "string"
            or text_f.value.byte_length() == 0
        ):
            return _reply_error(
                id_raw,
                -32602,
                "aesir_tokenize requires a non-empty string"
                " 'text'",
            )
        var tok_model_f = mcp_scan_field(args_text, "model")
        if engine_bound and tok_model_f.found and tok_model_f.kind == "string":
            if tok_model_f.value != bound_model:
                return _reply_tool_error(
                    id_raw,
                    String("the bound model is ") + bound_model
                    + String(", not ") + tok_model_f.value,
                )
        if not engine_bound:
            return _reply_tool_error(id_raw, mcp_no_tokenizer_reason())
        var tok_reply = McpReply()
        tok_reply.respond = False
        tok_reply.needs_tokenize = True
        tok_reply.tok_text = text_f.value
        tok_reply.gen_id_raw = id_raw
        return tok_reply

    # aesir_generate
    var prompt_f = mcp_scan_field(args_text, "prompt")
    if (
        not prompt_f.found
        or prompt_f.kind != "string"
        or prompt_f.value.byte_length() == 0
    ):
        return _reply_error(
            id_raw,
            -32602,
            "aesir_generate requires a non-empty string 'prompt'",
        )
    var max_tokens = 256
    var mt_f = mcp_scan_field(args_text, "max_tokens")
    if mt_f.found:
        if mt_f.kind != "number":
            return _reply_error(
                id_raw, -32602, "max_tokens must be an integer"
            )
        var parsed = _parse_int_literal(mt_f.value)
        if parsed < 1:
            return _reply_error(
                id_raw, -32602, "max_tokens must be at least 1"
            )
        max_tokens = parsed
        if max_tokens > 4096:
            max_tokens = 4096
    var model_f2 = mcp_scan_field(args_text, "model")
    if engine_bound and model_f2.found and model_f2.kind == "string":
        if model_f2.value != bound_model:
            return _reply_tool_error(
                id_raw,
                String("the bound model is ") + bound_model
                + String(", not ") + model_f2.value,
            )
    if not engine_bound:
        return _reply_tool_error(id_raw, mcp_no_engine_reason())
    var reply = McpReply()
    reply.respond = False
    reply.needs_generate = True
    reply.gen_prompt = prompt_f.value
    reply.gen_max_tokens = max_tokens
    reply.gen_id_raw = id_raw
    return reply


def mcp_handle_line(
    line: String,
    session: McpSession,
    facts: List[McpModelFact],
    engine_bound: Bool,
    bound_model: String,
) -> McpReply:
    """Decides one JSON-RPC line. The host prints
    reply.payload iff reply.respond, applies
    reply.now_initialized to its session, and executes
    reply.needs_generate through the engine when bound."""
    var silent = McpReply()
    if not mcp_json_object_ok(line):
        return _reply_error("null", -32700, "parse error")
    var method_f = mcp_scan_field(line, "method")
    var has_id = _has_id(line)
    var id_raw = _id_raw(line)
    if not method_f.found or method_f.kind != "string":
        if not has_id:
            return silent
        return _reply_error(id_raw, -32600, "invalid request: no method")
    var method = method_f.value
    var cls = mcp_classify_method(method)
    if not has_id:
        # Notifications are never answered, known or not.
        return silent
    if cls == mcp_method_initialize():
        var result = (
            String("{\"protocolVersion\":\"")
            + mcp_protocol_version()
            + String("\",\"capabilities\":{\"tools\":{}},")
            + String("\"serverInfo\":{\"name\":\"")
            + mcp_server_name()
            + String("\",\"version\":\"")
            + mcp_server_version()
            + String("\"}}")
        )
        var reply = _reply_result(id_raw, result)
        reply.now_initialized = True
        return reply
    if cls == mcp_method_ping():
        return _reply_result(id_raw, String("{}"))
    if not session.initialized:
        return _reply_error(
            id_raw,
            -32002,
            "server not initialized: send initialize first",
        )
    if cls == mcp_method_tools_list():
        return _reply_result(id_raw, mcp_tools_list_result())
    if cls == mcp_method_tools_call():
        return _handle_tools_call(
            line, id_raw, facts, engine_bound, bound_model
        )
    if cls == mcp_method_notification():
        return _reply_error(
            id_raw,
            -32601,
            String("a notification takes no id and is never"
                   " answered: ") + method,
        )
    return _reply_error(
        id_raw, -32601, String("method not found: ") + method
    )
