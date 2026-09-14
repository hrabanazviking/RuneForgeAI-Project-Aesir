# cli/modelfile.mojo
# Modelfile Directive Parser for Project Aesir / Ollama CLI

from std.collections import Dict
from aesir import GenerationConfig
from core.sampling_options import sampling_uint, sampling_decimal


def generation_recipe_int(value: String) raises -> Int:
    var number = sampling_uint(value)
    if number > UInt64(9223372036854775807):
        raise Error("Recipe integer exceeds Int range")
    return Int(number)


def generation_recipe_penalty(value: String) raises -> Float32:
    if value.startswith("-"):
        return -sampling_decimal(String(value[byte=1:]))
    return sampling_decimal(value)


@always_inline
def parse_int(value: String) -> Int:
    """Parses an integer from string digits."""
    var raw = value.strip().as_bytes()
    if len(raw) == 0:
        return 0
    var res = 0
    var sign = 1
    var start = 0
    if raw[0] == 45:  # '-'
        sign = -1
        start = 1
    for i in range(start, len(raw)):
        if raw[i] >= 48 and raw[i] <= 57:
            res = res * 10 + Int(raw[i] - 48)
    return res * sign


@always_inline
def parse_float(value: String) -> Float32:
    """Parses a Float32 from string digits."""
    var s = String(value.strip())
    var is_neg = False
    if s.startswith("-"):
        is_neg = True
        var rest = String(s[byte=1:])
        s = String(rest.strip())
    if "." not in s:
        var res = Float32(parse_int(s))
        return -res if is_neg else res
    var parts = s.split(".")
    var p0 = String(parts[0])
    var p1 = String(parts[1])
    var int_part = Float32(parse_int(p0))
    var frac_part = Float32(parse_int(p1))
    var div = Float32(1.0)
    for _ in range(len(p1.bytes())):
        div *= Float32(10.0)
    var res = int_part + (frac_part / div)
    return -res if is_neg else res


@always_inline
def strip_quotes(text: String) -> String:
    """Strips leading/trailing quotes ('...', "...", \"\"\"...\") from a string."""
    var s = String(text.strip())
    var blen = len(s.bytes())
    if s.startswith("\"\"\"") and s.endswith("\"\"\"") and blen >= 6:
        return String(String(s[byte=3 : blen - 3]).strip())
    elif s.startswith("\"") and s.endswith("\"") and blen >= 2:
        return String(s[byte=1 : blen - 1])
    elif s.startswith("'") and s.endswith("'") and blen >= 2:
        return String(s[byte=1 : blen - 1])
    return s


@always_inline
def unescape_string(text: String) -> String:
    """Unescapes common escape sequences (\\n, \\t, \\\", \\\\) in a directive string."""
    var s = text
    if "\\n" in s:
        s = s.replace("\\n", "\n")
    if "\\t" in s:
        s = s.replace("\\t", "\t")
    if "\\\"" in s:
        s = s.replace("\\\"", "\"")
    if "\\\\" in s:
        s = s.replace("\\\\", "\\")
    return s


struct Modelfile(Copyable):
    """
    Modelfile — ᛗᛟᛞᛖᛚᚠᛁᛚᛖ — The Runestone of Configuration:
    Encapsulates an Ollama-shaped subset of Modelfile directives.
    Directives: FROM (base realm model), PARAMETER (hyperparameter tuning runes),
    SYSTEM (system prompt context), TEMPLATE (prompt template weaving),
    LICENSE (sovereign usage covenant), MESSAGE (pre-populated conversation context).
    """
    var from_model: String
    var parameters: Dict[String, String]
    var system_prompt: String
    var system_was_set: Bool
    var template: String
    var license_info: String
    var messages: List[String]

    def __init__(out self):
        self.from_model = String("")
        self.parameters = Dict[String, String]()
        self.system_prompt = String("")
        self.system_was_set = False
        self.template = String("")
        self.license_info = String("")
        self.messages = List[String]()

    def __init__(
        out self,
        from_model: String,
        parameters: Dict[String, String],
        system_prompt: String,
        template: String,
        license_info: String,
        messages: List[String],
        system_was_set: Bool = False,
    ):
        self.from_model = from_model
        self.parameters = parameters.copy()
        self.system_prompt = system_prompt
        self.system_was_set = system_was_set
        self.template = template
        self.license_info = license_info
        self.messages = messages.copy()

    def __copyinit__(out self, existing: Self):
        self.from_model = existing.from_model
        self.parameters = existing.parameters.copy()
        self.system_prompt = existing.system_prompt
        self.system_was_set = existing.system_was_set
        self.template = existing.template
        self.license_info = existing.license_info
        self.messages = existing.messages.copy()

    @always_inline
    def copy(self) -> Self:
        return Self(
            self.from_model,
            self.parameters.copy(),
            self.system_prompt,
            self.template,
            self.license_info,
            self.messages.copy(),
            self.system_was_set,
        )

    def to_generation_config(self, context_length: Int = 4096) raises -> GenerationConfig:
        """Converts parsed Modelfile parameters into a validated GenerationConfig."""
        if context_length < 1:
            raise Error("Recipe conversion context must be positive")
        var supported: List[String] = ["num_predict", "temperature", "top_k", "top_p", "min_p", "repeat_penalty", "presence_penalty", "frequency_penalty", "stop", "seed"]
        for name in self.parameters.keys():
            if name not in supported:
                raise Error("Unsupported GenerationConfig recipe parameter: " + name)
        var config = GenerationConfig(max_new_tokens=min(16000, context_length))
        if "num_predict" in self.parameters:
            config.max_new_tokens = generation_recipe_int(self.parameters["num_predict"])
        if "temperature" in self.parameters:
            config.temperature = sampling_decimal(self.parameters["temperature"])
        if "top_k" in self.parameters:
            config.top_k = generation_recipe_int(self.parameters["top_k"])
        if "top_p" in self.parameters:
            config.top_p = sampling_decimal(self.parameters["top_p"])
        if "min_p" in self.parameters:
            config.min_p = sampling_decimal(self.parameters["min_p"])
        if "repeat_penalty" in self.parameters:
            config.repetition_penalty = sampling_decimal(self.parameters["repeat_penalty"])
        if "presence_penalty" in self.parameters:
            config.presence_penalty = generation_recipe_penalty(self.parameters["presence_penalty"])
        if "frequency_penalty" in self.parameters:
            config.frequency_penalty = generation_recipe_penalty(self.parameters["frequency_penalty"])
        if "stop" in self.parameters:
            config.stop_strings.append(self.parameters["stop"])
        if "seed" in self.parameters:
            config.seed = sampling_uint(self.parameters["seed"])
        config.validate(context_length)
        return config^


def parse_modelfile(content: String, strict_native: Bool = False) raises -> Modelfile:
    """
    Parses a raw Modelfile text string into a structured Modelfile runestone.
    Supports single-quoted, double-quoted, and triple-quoted multiline directives.
    Raises an Error if FROM directive is missing or if multiline quotes are unclosed.
    """
    var modelfile = Modelfile()
    var lines = content.split("\n")

    var in_multiline = False
    var multiline_directive = String("")
    var multiline_buffer = String("")
    var seen_directives = List[String]()

    for i in range(len(lines)):
        var raw_line = String(lines[i])
        var line = String(raw_line.strip())

        if in_multiline:
            if "\"\"\"" in line:
                var end_idx = line.find("\"\"\"")
                if strict_native and String(String(line[byte=end_idx + 3:]).strip()) != "":
                    raise Error("Trailing text after native recipe multiline value")
                multiline_buffer += "\n" + String(line[byte=0 : end_idx])
                var final_val = unescape_string(String(multiline_buffer.strip()))
                if multiline_directive == "SYSTEM":
                    modelfile.system_prompt = final_val
                elif multiline_directive == "TEMPLATE":
                    modelfile.template = final_val
                elif multiline_directive == "LICENSE":
                    modelfile.license_info = final_val
                elif multiline_directive == "MESSAGE":
                    modelfile.messages.append(final_val)
                in_multiline = False
                multiline_directive = ""
                multiline_buffer = ""
            else:
                multiline_buffer += "\n" + raw_line
            continue

        if len(line.bytes()) == 0 or line.startswith("#"):
            continue

        if strict_native:
            var space = line.find(" ")
            var directive = String(line[byte=0:space]) if space > 0 else line
            if directive != "FROM" and directive != "SYSTEM" and directive != "LICENSE" and directive != "PARAMETER":
                raise Error("Unsupported native recipe directive: " + directive)
            if directive != "PARAMETER":
                if directive in seen_directives:
                    raise Error("Duplicate native recipe directive: " + directive)
                seen_directives.append(directive)
            if space < 1:
                raise Error("Native recipe directive requires a value")

        if line.startswith("FROM "):
            var val = unescape_string(strip_quotes(String(line[byte=5:])))
            modelfile.from_model = val
        elif line.startswith("SYSTEM "):
            modelfile.system_was_set = True
            var val_str = String(String(line[byte=7:]).strip())
            var val_blen = len(val_str.bytes())
            if val_str.startswith("\"\"\"") and not val_str.endswith("\"\"\""):
                in_multiline = True
                multiline_directive = "SYSTEM"
                multiline_buffer = String(val_str[byte=3 : val_blen])
            else:
                modelfile.system_prompt = unescape_string(strip_quotes(val_str))
        elif line.startswith("TEMPLATE "):
            var val_str = String(line.replace("TEMPLATE ", "").strip())
            var val_blen = len(val_str.bytes())
            if val_str.startswith("\"\"\"") and not val_str.endswith("\"\"\""):
                in_multiline = True
                multiline_directive = "TEMPLATE"
                multiline_buffer = String(val_str[byte=3 : val_blen])
            else:
                modelfile.template = unescape_string(strip_quotes(val_str))
        elif line.startswith("LICENSE "):
            var val_str = String(String(line[byte=8:]).strip())
            var val_blen = len(val_str.bytes())
            if val_str.startswith("\"\"\"") and not val_str.endswith("\"\"\""):
                in_multiline = True
                multiline_directive = "LICENSE"
                multiline_buffer = String(val_str[byte=3 : val_blen])
            else:
                modelfile.license_info = unescape_string(strip_quotes(val_str))
        elif line.startswith("PARAMETER "):
            var param_line = String(String(line[byte=10:]).strip())
            var separator = param_line.find(" ")
            if separator > 0 and separator + 1 < param_line.byte_length():
                var key = String(param_line[byte=0:separator])
                if key in modelfile.parameters:
                    raise Error("Duplicate Modelfile PARAMETER: " + key)
                var raw_val_str = String(String(param_line[byte=separator + 1:]).strip())
                var val = unescape_string(strip_quotes(raw_val_str))
                modelfile.parameters[String(key)] = String(val)
            else:
                raise Error("PARAMETER directive requires key and value, got '" + param_line + "'")
        elif line.startswith("MESSAGE "):
            var msg_str = String(line.replace("MESSAGE ", "").strip())
            var msg_blen = len(msg_str.bytes())
            if msg_str.startswith("\"\"\"") and not msg_str.endswith("\"\"\""):
                in_multiline = True
                multiline_directive = "MESSAGE"
                multiline_buffer = String(msg_str[byte=3 : msg_blen])
            else:
                modelfile.messages.append(unescape_string(strip_quotes(msg_str)))

    if in_multiline:
        raise Error("Unclosed multiline directive '\"\"\"' in Modelfile for " + multiline_directive)

    if modelfile.from_model == "":
        raise Error("Modelfile missing required FROM directive")

    return modelfile^
