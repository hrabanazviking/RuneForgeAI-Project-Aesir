# cli/modelfile.mojo
# Modelfile Directive Parser for Project Aesir / Ollama CLI

from std.collections import Dict

struct Modelfile(Copyable):
    """
    Modelfile — ᛗᛟᛞᛖᛚᚠᛁᛚᛖ — The Runestone of Configuration:
    Encapsulates an Ollama-shaped subset of Modelfile directives. This parser
    does not establish full Ollama syntax or behavioral compatibility.
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


def parse_modelfile(content: String) raises -> Modelfile:
    """
    parse_modelfile — ᛈᚨᚱᛋᛖ·ᛗᛟᛞᛖᛚᚠᛁᛚᛖ — The Inscription Reader:
    Parses a raw Modelfile text string into a structured Modelfile runestone.
    Scans line-by-line, stripping comment runes ('#') and extracting directive values
    into key-value parameter maps and message lists.
    """
    var modelfile = Modelfile()
    var lines = content.split("\n")

    for i in range(len(lines)):
        var raw_line = String(lines[i])
        var line = String(raw_line.strip())
        if len(line.bytes()) == 0 or line.startswith("#"):
            continue

        if line.startswith("FROM "):
            modelfile.from_model = String(line.replace("FROM ", "").strip())
        elif line.startswith("SYSTEM "):
            modelfile.system_prompt = String(line.replace("SYSTEM ", "").strip())
        elif line.startswith("TEMPLATE "):
            modelfile.template = String(line.replace("TEMPLATE ", "").strip())
        elif line.startswith("LICENSE "):
            modelfile.license_info = String(line.replace("LICENSE ", "").strip())
        elif line.startswith("PARAMETER "):
            var param_line = String(line.replace("PARAMETER ", "").strip())
            var parts = param_line.split(" ")
            if len(parts) >= 2:
                var key = String(parts[0]).strip()
                var val = String(param_line.replace(String(key) + " ", "").strip())
                modelfile.parameters[String(key)] = String(val)
        elif line.startswith("MESSAGE "):
            var msg = String(line.replace("MESSAGE ", "").strip())
            modelfile.messages.append(String(msg))

    return modelfile^
