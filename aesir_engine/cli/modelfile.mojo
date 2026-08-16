# cli/modelfile.mojo
# Modelfile Directive Parser for Project Aesir / Ollama CLI

from std.collections import Dict
from aesir import GenerationConfig


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
    var template: String
    var license_info: String
    var messages: List[String]

    def __init__(out self):
        self.from_model = String("")
        self.parameters = Dict[String, String]()
        self.system_prompt = String("")
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
        messages: List[String]
    ):
        self.from_model = from_model
        self.parameters = parameters.copy()
        self.system_prompt = system_prompt
        self.template = template
        self.license_info = license_info
        self.messages = messages.copy()

    def __copyinit__(out self, existing: Self):
        self.from_model = existing.from_model
        self.parameters = existing.parameters.copy()
        self.system_prompt = existing.system_prompt
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
            self.messages.copy()
        )

    def to_generation_config(self) raises -> GenerationConfig:
        """Converts parsed Modelfile parameters into a validated GenerationConfig."""
        var config = GenerationConfig()
        if "num_predict" in self.parameters:
            config.max_new_tokens = parse_int(self.parameters["num_predict"])
        if "temperature" in self.parameters:
            config.temperature = parse_float(self.parameters["temperature"])
        if "top_k" in self.parameters:
            config.top_k = parse_int(self.parameters["top_k"])
        if "top_p" in self.parameters:
            config.top_p = parse_float(self.parameters["top_p"])
        if "repeat_penalty" in self.parameters:
            config.repetition_penalty = parse_float(self.parameters["repeat_penalty"])
        if "presence_penalty" in self.parameters:
            config.presence_penalty = parse_float(self.parameters["presence_penalty"])
        if "frequency_penalty" in self.parameters:
            config.frequency_penalty = parse_float(self.parameters["frequency_penalty"])
        if "stop" in self.parameters:
            config.stop_strings.append(self.parameters["stop"])
        if "seed" in self.parameters:
            config.seed = UInt64(parse_int(self.parameters["seed"]))
        config.validate()
        return config^


def parse_modelfile(content: String) raises -> Modelfile:
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

    for i in range(len(lines)):
        var raw_line = String(lines[i])
        var line = String(raw_line.strip())

        if in_multiline:
            if "\"\"\"" in line:
                var end_idx = line.find("\"\"\"")
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

        if line.startswith("FROM "):
            var val = unescape_string(strip_quotes(String(line.replace("FROM ", "").strip())))
            modelfile.from_model = val
        elif line.startswith("SYSTEM "):
            var val_str = String(line.replace("SYSTEM ", "").strip())
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
            var val_str = String(line.replace("LICENSE ", "").strip())
            var val_blen = len(val_str.bytes())
            if val_str.startswith("\"\"\"") and not val_str.endswith("\"\"\""):
                in_multiline = True
                multiline_directive = "LICENSE"
                multiline_buffer = String(val_str[byte=3 : val_blen])
            else:
                modelfile.license_info = unescape_string(strip_quotes(val_str))
        elif line.startswith("PARAMETER "):
            var param_line = String(line.replace("PARAMETER ", "").strip())
            var parts = param_line.split(" ")
            if len(parts) >= 2:
                var key = String(parts[0]).strip()
                var raw_val_str = String(param_line.replace(String(key) + " ", "").strip())
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
