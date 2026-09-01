# core/tool_use.mojo
# Strict bounded tool schema formatting and tool-call JSON parsing.

from std.collections import Dict


struct ToolDefinition(Copyable, ImplicitlyCopyable):
    var name: String
    var description: String
    var parameters_json_schema: String

    def __init__(out self, name: String, description: String, schema: String):
        self.name = name
        self.description = description
        self.parameters_json_schema = schema

    def __copyinit__(out self, existing: Self):
        self.name = existing.name
        self.description = existing.description
        self.parameters_json_schema = existing.parameters_json_schema


struct ToolCall(Copyable, ImplicitlyCopyable):
    var name: String
    var arguments_json: String

    def __init__(out self, name: String, arguments_json: String):
        self.name = name
        self.arguments_json = arguments_json

    def __copyinit__(out self, existing: Self):
        self.name = existing.name
        self.arguments_json = existing.arguments_json


def _valid_tool_name(name: String) -> Bool:
    if name.byte_length() == 0 or name.byte_length() > 64:
        return False
    var bytes = name.as_bytes()
    for i in range(len(bytes)):
        var byte = Int(bytes[i])
        if not (
            (byte >= 48 and byte <= 57)
            or (byte >= 65 and byte <= 90)
            or (byte >= 97 and byte <= 122)
            or byte == 45
            or byte == 46
            or byte == 95
        ):
            return False
    return True


def _json_escape_tool_text(text: String) raises -> String:
    if text.byte_length() > 4096:
        raise Error("tool text exceeds 4096 bytes")
    var output = List[Int8]()
    var bytes = text.as_bytes()
    for i in range(len(bytes)):
        var byte = Int(bytes[i])
        if byte == 34:
            output.append(92)
            output.append(34)
        elif byte == 92:
            output.append(92)
            output.append(92)
        elif byte == 8:
            output.append(92)
            output.append(98)
        elif byte == 9:
            output.append(92)
            output.append(116)
        elif byte == 10:
            output.append(92)
            output.append(110)
        elif byte == 12:
            output.append(92)
            output.append(102)
        elif byte == 13:
            output.append(92)
            output.append(114)
        elif byte < 32:
            raise Error("tool text contains an unsupported control byte")
        else:
            output.append(Int8(byte))
    output.append(0)
    var result = String(unsafe_from_utf8_ptr=output.unsafe_ptr())
    _ = output
    return result


struct BoundedToolJSON:
    """Strict JSON recognizer with bounded depth, fields, and string decoding."""

    var source: String
    var position: Int

    def __init__(out self, source: String) raises:
        if source.byte_length() == 0 or source.byte_length() > 65536:
            raise Error("tool JSON must be 1..65536 bytes")
        self.source = source
        self.position = 0

    def peek(self) -> Int:
        if self.position >= self.source.byte_length():
            return -1
        return Int(self.source.as_bytes()[self.position])

    def space(mut self):
        while (
            self.peek() == 32
            or self.peek() == 9
            or self.peek() == 10
            or self.peek() == 13
        ):
            self.position += 1

    def take(mut self, expected: Int) raises:
        self.space()
        if self.peek() != expected:
            raise Error("malformed tool JSON")
        self.position += 1

    def hex4(mut self) raises -> Int:
        var value = 0
        for _ in range(4):
            var digit = self.peek()
            if digit < 0:
                raise Error("truncated tool JSON Unicode escape")
            self.position += 1
            if digit >= 48 and digit <= 57:
                digit -= 48
            elif digit >= 65 and digit <= 70:
                digit -= 55
            elif digit >= 97 and digit <= 102:
                digit -= 87
            else:
                raise Error("invalid tool JSON Unicode escape")
            value = value * 16 + digit
        return value

    def string(mut self) raises -> String:
        self.take(34)
        var output = List[Int8]()
        while True:
            var byte = self.peek()
            if byte < 0:
                raise Error("unterminated tool JSON string")
            self.position += 1
            if byte == 34:
                break
            if byte < 32:
                raise Error("unescaped control in tool JSON string")
            if byte != 92:
                output.append(Int8(byte))
                continue
            byte = self.peek()
            if byte < 0:
                raise Error("unterminated tool JSON escape")
            self.position += 1
            if byte == 34 or byte == 92 or byte == 47:
                output.append(Int8(byte))
            elif byte == 98:
                output.append(8)
            elif byte == 102:
                output.append(12)
            elif byte == 110:
                output.append(10)
            elif byte == 114:
                output.append(13)
            elif byte == 116:
                output.append(9)
            elif byte == 117:
                var codepoint = self.hex4()
                if codepoint >= 55296 and codepoint <= 56319:
                    if self.peek() != 92:
                        raise Error("tool JSON high surrogate lacks pair")
                    self.position += 1
                    if self.peek() != 117:
                        raise Error("tool JSON surrogate pair is malformed")
                    self.position += 1
                    var low = self.hex4()
                    if low < 56320 or low > 57343:
                        raise Error("tool JSON low surrogate is invalid")
                    codepoint = 65536 + ((codepoint - 55296) << 10) + low - 56320
                elif codepoint >= 56320 and codepoint <= 57343:
                    raise Error("tool JSON contains an unpaired low surrogate")
                if codepoint == 0:
                    raise Error("tool JSON strings must not contain NUL")
                if codepoint < 128:
                    output.append(Int8(codepoint))
                elif codepoint < 2048:
                    output.append(Int8(192 | (codepoint >> 6)))
                    output.append(Int8(128 | (codepoint & 63)))
                elif codepoint < 65536:
                    output.append(Int8(224 | (codepoint >> 12)))
                    output.append(Int8(128 | ((codepoint >> 6) & 63)))
                    output.append(Int8(128 | (codepoint & 63)))
                else:
                    output.append(Int8(240 | (codepoint >> 18)))
                    output.append(Int8(128 | ((codepoint >> 12) & 63)))
                    output.append(Int8(128 | ((codepoint >> 6) & 63)))
                    output.append(Int8(128 | (codepoint & 63)))
            else:
                raise Error("invalid tool JSON string escape")
            if len(output) > 16384:
                raise Error("decoded tool JSON string exceeds 16384 bytes")
        output.append(0)
        var result = String(unsafe_from_utf8_ptr=output.unsafe_ptr())
        _ = output
        return result

    def literal(mut self, expected: String) raises:
        for i in range(expected.byte_length()):
            if self.peek() != Int(expected.as_bytes()[i]):
                raise Error("invalid tool JSON literal")
            self.position += 1

    def number(mut self) raises:
        if self.peek() == 45:
            self.position += 1
        if self.peek() == 48:
            self.position += 1
            if self.peek() >= 48 and self.peek() <= 57:
                raise Error("tool JSON number has a leading zero")
        elif self.peek() >= 49 and self.peek() <= 57:
            while self.peek() >= 48 and self.peek() <= 57:
                self.position += 1
        else:
            raise Error("invalid tool JSON number")
        if self.peek() == 46:
            self.position += 1
            var start = self.position
            while self.peek() >= 48 and self.peek() <= 57:
                self.position += 1
            if self.position == start:
                raise Error("tool JSON fraction requires digits")
        if self.peek() == 101 or self.peek() == 69:
            self.position += 1
            if self.peek() == 43 or self.peek() == 45:
                self.position += 1
            var start = self.position
            while self.peek() >= 48 and self.peek() <= 57:
                self.position += 1
            if self.position == start:
                raise Error("tool JSON exponent requires digits")

    def value(mut self, depth: Int = 0) raises:
        if depth > 16:
            raise Error("tool JSON nesting exceeds 16")
        self.space()
        var byte = self.peek()
        if byte == 34:
            _ = self.string()
            return
        if byte == 123:
            self.position += 1
            self.space()
            var seen = Dict[String, Bool]()
            var count = 0
            if self.peek() != 125:
                while True:
                    var key = self.string()
                    count += 1
                    if count > 256 or key.byte_length() > 256:
                        raise Error("tool JSON object exceeds field bounds")
                    if key in seen:
                        raise Error("duplicate tool JSON object field")
                    seen[key] = True
                    self.take(58)
                    self.value(depth + 1)
                    self.space()
                    if self.peek() == 125:
                        break
                    if self.peek() != 44:
                        raise Error("tool JSON object requires a comma")
                    self.position += 1
                    self.space()
                    if self.peek() == 125:
                        raise Error("tool JSON object has a trailing comma")
            self.take(125)
            return
        if byte == 91:
            self.position += 1
            self.space()
            var count = 0
            if self.peek() != 93:
                while True:
                    count += 1
                    if count > 256:
                        raise Error("tool JSON array exceeds item bounds")
                    self.value(depth + 1)
                    self.space()
                    if self.peek() == 93:
                        break
                    if self.peek() != 44:
                        raise Error("tool JSON array requires a comma")
                    self.position += 1
                    self.space()
                    if self.peek() == 93:
                        raise Error("tool JSON array has a trailing comma")
            self.take(93)
            return
        if byte == 116:
            self.literal("true")
            return
        if byte == 102:
            self.literal("false")
            return
        if byte == 110:
            self.literal("null")
            return
        self.number()

    def require_complete_object(mut self) raises:
        self.space()
        if self.peek() != 123:
            raise Error("tool JSON value must be an object")
        self.value()
        self.space()
        if self.peek() != -1:
            raise Error("tool JSON has trailing content")

    def parse_tool_call(mut self) raises -> ToolCall:
        self.take(123)
        self.space()
        var seen_tool = False
        var seen_arguments = False
        var name = String("")
        var arguments = String("")
        var field_count = 0
        if self.peek() != 125:
            while True:
                var key = self.string()
                field_count += 1
                if field_count > 2:
                    raise Error("tool call must contain exactly tool and arguments")
                self.take(58)
                self.space()
                if key == "tool":
                    if seen_tool:
                        raise Error("duplicate tool field")
                    name = self.string()
                    seen_tool = True
                elif key == "arguments":
                    if seen_arguments:
                        raise Error("duplicate arguments field")
                    var start = self.position
                    if self.peek() != 123:
                        raise Error("tool arguments must be a JSON object")
                    self.value(1)
                    arguments = String(self.source[byte=start:self.position])
                    seen_arguments = True
                else:
                    raise Error("unknown tool-call field")
                self.space()
                if self.peek() == 125:
                    break
                if self.peek() != 44:
                    raise Error("tool call requires a comma")
                self.position += 1
                self.space()
                if self.peek() == 125:
                    raise Error("tool call has a trailing comma")
        self.take(125)
        self.space()
        if self.peek() != -1:
            raise Error("tool call has trailing content")
        if not seen_tool or not seen_arguments or not _valid_tool_name(name):
            raise Error("tool call requires a valid tool name and arguments object")
        return ToolCall(name, arguments)


def format_tool_system_prompt(tools: List[ToolDefinition]) raises -> String:
    """Formats validated definitions as data in one bounded JSON array."""
    if len(tools) == 0:
        return String("")
    if len(tools) > 64:
        raise Error("tool definition count exceeds 64")
    var seen = Dict[String, Bool]()
    var prompt = String("[AVAILABLE_TOOLS_JSON]\n[")
    for i in range(len(tools)):
        var tool = tools[i]
        if not _valid_tool_name(tool.name):
            raise Error("tool definition name is invalid")
        if tool.name in seen:
            raise Error("tool definition name must be unique")
        seen[tool.name] = True
        if tool.description.byte_length() == 0 or tool.description.byte_length() > 1024:
            raise Error("tool description must be 1..1024 bytes")
        var schema = BoundedToolJSON(tool.parameters_json_schema)
        schema.require_complete_object()
        if i > 0:
            prompt += ","
        prompt += "{\"name\":\"" + _json_escape_tool_text(tool.name)
        prompt += "\",\"description\":\"" + _json_escape_tool_text(tool.description)
        prompt += "\",\"parameters\":" + tool.parameters_json_schema + "}"
    prompt += "]\n[END_AVAILABLE_TOOLS_JSON]\n"
    prompt += "To request a tool, emit exactly one JSON object with only "
    prompt += "\"tool\" and object-valued \"arguments\" fields."
    if prompt.byte_length() > 131072:
        raise Error("formatted tool prompt exceeds 131072 bytes")
    return prompt


def parse_tool_call(output_text: String) raises -> ToolCall:
    """Parses exactly one bounded JSON object; prose and extra fields fail."""
    var parser = BoundedToolJSON(output_text)
    return parser.parse_tool_call()
