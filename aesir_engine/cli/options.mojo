# cli/options.mojo
# CLI Option and Flag Parser for Project Aesir

from cli.modelfile import parse_int


struct CLIOptions:
    """
    CLIOptions — Ollama-compatible CLI flag options container.
    """

    var verbose: Bool
    var verbose_was_set: Bool
    var format: String
    var format_was_set: Bool
    var keepalive_seconds: Int
    var keepalive_was_set: Bool
    var modelfile_path: String
    var modelfile_was_set: Bool
    var raw: Bool
    var raw_was_set: Bool
    var insecure: Bool
    var insecure_was_set: Bool
    var max_tokens: Int
    var max_tokens_was_set: Bool
    var config_path: String
    var config_was_set: Bool
    var accel_backend: String
    var accel_was_set: Bool
    var skaldbrodir: String  # "auto", "on", "off"
    var skaldbrodir_was_set: Bool
    var thinking: String     # "auto", "on", "off"
    var thinking_was_set: Bool
    var cia: String          # "auto", "on", "off"
    var cia_was_set: Bool
    var wic: String          # "auto", "on", "off"
    var wic_was_set: Bool
    var nsfi: String         # "auto", "on", "off"
    var nsfi_was_set: Bool
    var tui: Bool
    var tui_was_set: Bool

    def __init__(out self):
        self.verbose = False
        self.verbose_was_set = False
        self.format = String("text")
        self.format_was_set = False
        self.keepalive_seconds = 300
        self.keepalive_was_set = False
        self.modelfile_path = String("")
        self.modelfile_was_set = False
        self.raw = False
        self.raw_was_set = False
        self.insecure = False
        self.insecure_was_set = False
        self.max_tokens = 16000
        self.max_tokens_was_set = False
        self.config_path = String("aesir.config.json")
        self.config_was_set = False
        self.accel_backend = String("auto")
        self.accel_was_set = False
        self.skaldbrodir = String("auto")
        self.skaldbrodir_was_set = False
        self.thinking = String("auto")
        self.thinking_was_set = False
        self.cia = String("auto")
        self.cia_was_set = False
        self.wic = String("auto")
        self.wic_was_set = False
        self.nsfi = String("auto")
        self.nsfi_was_set = False
        self.tui = False
        self.tui_was_set = False


def parse_duration_seconds(duration_str: String) raises -> Int:
    """Parses duration strings such as '5m', '1h', '30s', '0s' into seconds."""
    var raw = duration_str.strip()
    var bytes_view = raw.as_bytes()
    if len(bytes_view) == 0:
        raise Error("duration must not be empty")
    var unit_idx = len(bytes_view) - 1
    var last_byte = bytes_view[unit_idx]

    var multiplier = 1
    var num_part = String(raw)
    if last_byte == 115 or last_byte == 83:  # 's' or 'S'
        multiplier = 1
        num_part = String(raw[byte=0:unit_idx])
    elif last_byte == 109 or last_byte == 77:  # 'm' or 'M'
        multiplier = 60
        num_part = String(raw[byte=0:unit_idx])
    elif last_byte == 104 or last_byte == 72:  # 'h' or 'H'
        multiplier = 3600
        num_part = String(raw[byte=0:unit_idx])

    var parsed_num = parse_int(num_part)
    if parsed_num < 0:
        raise Error("duration cannot be negative")
    if parsed_num > 2147483647 // multiplier:
        raise Error("duration is too large")
    return parsed_num * multiplier


def validate_toggle(value: String, flag_name: String) raises -> String:
    """Accepts only the documented auto/on/off vocabulary."""
    if value != "auto" and value != "on" and value != "off":
        raise Error(flag_name + " must be auto, on, or off")
    return value


def validate_acceleration_backend(value: String) raises -> String:
    """Validates configuration intent without claiming backend execution."""
    if (
        value != "auto"
        and value != "cpu"
        and value != "cuda"
        and value != "metal"
        and value != "intel"
        and value != "amd"
        and value != "npu"
        and value != "max"
    ):
        raise Error("unsupported acceleration backend: " + value)
    return value


def parse_cli_options(args: List[String]) raises -> CLIOptions:
    """Parses standard flags from argument lists."""
    var options = CLIOptions()
    var i = 0
    while i < len(args):
        var arg = args[i]
        if arg == "--verbose" or arg == "-v":
            options.verbose = True
            options.verbose_was_set = True
        elif arg == "--raw":
            options.raw = True
            options.raw_was_set = True
        elif arg == "--insecure":
            options.insecure = True
            options.insecure_was_set = True
        elif arg == "--format":
            if i + 1 >= len(args):
                raise Error("Missing value for --format flag")
            options.format = args[i + 1]
            options.format_was_set = True
            if options.format != "json" and options.format != "text":
                raise Error("--format must be json or text")
            i += 1
        elif arg == "--keepalive":
            if i + 1 >= len(args):
                raise Error("Missing value for --keepalive flag")
            options.keepalive_seconds = parse_duration_seconds(args[i + 1])
            options.keepalive_was_set = True
            i += 1
        elif arg == "--modelfile" or arg == "-f":
            if i + 1 >= len(args):
                raise Error("Missing value for --modelfile/-f flag")
            options.modelfile_path = args[i + 1]
            options.modelfile_was_set = True
            i += 1
        elif arg == "--max-tokens":
            if i + 1 >= len(args):
                raise Error("Missing value for --max-tokens flag")
            options.max_tokens = parse_int(args[i + 1])
            options.max_tokens_was_set = True
            if options.max_tokens <= 0:
                raise Error("--max-tokens must be positive")
            i += 1
        elif arg == "--config" or arg == "-c":
            if i + 1 >= len(args):
                raise Error("Missing value for --config/-c flag")
            options.config_path = args[i + 1]
            options.config_was_set = True
            i += 1
        elif arg == "--accel" or arg == "-a":
            if i + 1 >= len(args):
                raise Error("Missing value for --accel/-a flag")
            options.accel_backend = args[i + 1]
            options.accel_was_set = True
            i += 1
        elif arg == "--skaldbrodir":
            if i + 1 >= len(args):
                raise Error("Missing value for --skaldbrodir flag")
            options.skaldbrodir = args[i + 1]
            options.skaldbrodir_was_set = True
            i += 1
        elif arg == "--thinking":
            if i + 1 >= len(args):
                raise Error("Missing value for --thinking flag")
            options.thinking = args[i + 1]
            options.thinking_was_set = True
            i += 1
        elif arg == "--cia":
            if i + 1 >= len(args):
                raise Error("Missing value for --cia flag")
            options.cia = args[i + 1]
            options.cia_was_set = True
            i += 1
        elif arg == "--wic":
            if i + 1 >= len(args):
                raise Error("Missing value for --wic flag")
            options.wic = args[i + 1]
            options.wic_was_set = True
            i += 1
        elif arg == "--nsfi":
            if i + 1 >= len(args):
                raise Error("Missing value for --nsfi flag")
            options.nsfi = args[i + 1]
            options.nsfi_was_set = True
            i += 1
        elif arg == "--tui":
            options.tui = True
            options.tui_was_set = True
        i += 1
    return options^
