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

    def __init__(out self):
        self.verbose = False
        self.format = String("text")
        self.keepalive_seconds = 300
        self.modelfile_path = String("")
        self.raw = False
        self.insecure = False
        self.max_tokens = 32


def parse_duration_seconds(duration_str: String) raises -> Int:
    """Parses duration strings such as '5m', '1h', '30s', '0s' into seconds."""
    var raw = duration_str.strip()
    var bytes_view = raw.as_bytes()
    if len(bytes_view) == 0:
        return 300
    var unit_idx = len(bytes_view) - 1
    var last_byte = bytes_view[unit_idx]
    
    var multiplier = 1
    var num_part = String(raw)
    if last_byte == 115 or last_byte == 83: # 's' or 'S'
        multiplier = 1
        num_part = String(raw[byte=0:unit_idx])
    elif last_byte == 109 or last_byte == 77: # 'm' or 'M'
        multiplier = 60
        num_part = String(raw[byte=0:unit_idx])
    elif last_byte == 104 or last_byte == 72: # 'h' or 'H'
        multiplier = 3600
        num_part = String(raw[byte=0:unit_idx])

    var parsed_num = parse_int(num_part)
    if parsed_num < 0:
        return 300
    return parsed_num * multiplier


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
            i += 1
        i += 1
    return options^
