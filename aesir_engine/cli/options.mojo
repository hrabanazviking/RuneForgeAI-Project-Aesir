# cli/options.mojo
# CLI Option and Flag Parser for Project Aesir

from cli.modelfile import parse_int


struct CLIOptions:
    """
    CLIOptions — Ollama-compatible CLI flag options container.
    """

    var verbose: Bool
    var format: String
    var keepalive_seconds: Int
    var modelfile_path: String
    var raw: Bool
    var insecure: Bool
    var max_tokens: Int
    var config_path: String
    var config_was_set: Bool
    var accel_backend: String
    var accel_was_set: Bool
    var skaldbrodir: String  # "auto", "on", "off"
    var thinking: String  # "auto", "on", "off"
    var cia: String  # "auto", "on", "off"
    var wic: String  # "auto", "on", "off"
    var nsfi: String  # "auto", "on", "off"
    var tui: Bool

    def __init__(out self):
        self.verbose = False
        self.format = String("text")
        self.keepalive_seconds = 300
        self.modelfile_path = String("")
        self.raw = False
        self.insecure = False
        self.max_tokens = 32
        self.config_path = String("aesir.config.json")
        self.config_was_set = False
        self.accel_backend = String("auto")
        self.accel_was_set = False
        self.skaldbrodir = String("auto")
        self.thinking = String("auto")
        self.cia = String("auto")
        self.wic = String("auto")
        self.nsfi = String("auto")
        self.tui = False


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
        elif arg == "--raw":
            options.raw = True
        elif arg == "--insecure":
            options.insecure = True
        elif arg == "--format":
            if i + 1 >= len(args):
                raise Error("Missing value for --format flag")
            options.format = args[i + 1]
            if options.format != "json" and options.format != "text":
                raise Error("--format must be json or text")
            i += 1
        elif arg == "--keepalive":
            if i + 1 >= len(args):
                raise Error("Missing value for --keepalive flag")
            options.keepalive_seconds = parse_duration_seconds(args[i + 1])
            i += 1
        elif arg == "--modelfile" or arg == "-f":
            if i + 1 >= len(args):
                raise Error("Missing value for --modelfile/-f flag")
            options.modelfile_path = args[i + 1]
            i += 1
        elif arg == "--max-tokens":
            if i + 1 >= len(args):
                raise Error("Missing value for --max-tokens flag")
            options.max_tokens = parse_int(args[i + 1])
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
            options.accel_backend = validate_acceleration_backend(args[i + 1])
            options.accel_was_set = True
            i += 1
        elif arg == "--skaldbrodir":
            if i + 1 >= len(args):
                raise Error("Missing value for --skaldbrodir flag")
            options.skaldbrodir = validate_toggle(args[i + 1], "--skaldbrodir")
            i += 1
        elif arg == "--thinking":
            if i + 1 >= len(args):
                raise Error("Missing value for --thinking flag")
            options.thinking = validate_toggle(args[i + 1], "--thinking")
            i += 1
        elif arg == "--cia":
            if i + 1 >= len(args):
                raise Error("Missing value for --cia flag")
            options.cia = validate_toggle(args[i + 1], "--cia")
            i += 1
        elif arg == "--wic":
            if i + 1 >= len(args):
                raise Error("Missing value for --wic flag")
            options.wic = validate_toggle(args[i + 1], "--wic")
            i += 1
        elif arg == "--nsfi":
            if i + 1 >= len(args):
                raise Error("Missing value for --nsfi flag")
            options.nsfi = validate_toggle(args[i + 1], "--nsfi")
            i += 1
        elif arg == "--tui":
            options.tui = True
        i += 1
    return options^
