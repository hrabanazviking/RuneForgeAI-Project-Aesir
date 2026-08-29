# cli/help.mojo
# Comprehensive Interactive Help System for Project A.E.S.I.R.


def get_help_overview() -> String:
    """Returns the main CLI help text detailing all commands, options, and paradigms.
    """
    var help_str = String(
        "═══════════════════════════════════════════════════════════════════════════════\n"
    )
    help_str += (
        "  Project A.E.S.I.R. CLI — verified CPU slice and development"
        " boundaries\n"
    )
    help_str += "═══════════════════════════════════════════════════════════════════════════════\n\n"
    help_str += "USAGE:\n"
    help_str += "  aesir [command] [flags] [arguments]\n\n"
    help_str += "COMMANDS:\n"
    help_str += (
        "  run <model.gguf> <prompt>  Run the verified local single-shot CPU"
        " path\n"
    )
    help_str += (
        "  config [--config <path>]  Validate and show a configuration file\n"
    )
    help_str += "  help [command]             Show capability-aware help\n"
    help_str += (
        "  --version                  Show the unversioned development"
        " snapshot\n\n"
    )
    help_str += "RESERVED AND UNSUPPORTED:\n"
    help_str += "  interactive run; serve; list; show; ps; create; cp; rm\n"
    help_str += "  pull; push; stop; llama-*; exl2; onnx; swarm\n\n"
    help_str += "FLAGS & OPTIONS:\n"
    help_str += (
        "  -a, --accel <backend>  Parse backend intent; non-CPU execution fails"
        " closed\n"
    )
    help_str += (
        "  -c, --config <path>    Select a JSON configuration path for future"
        " loading\n"
    )
    help_str += (
        "  --skaldbrodir <on|off> Parse local detector intent; not"
        " engine-integrated\n"
    )
    help_str += (
        "  --thinking <on|off>    Parse transcript-filter intent; not logit"
        " integration\n"
    )
    help_str += (
        "  --cia/--wic/--nsfi     Parse experimental intent; not inference"
        " backends\n"
    )
    help_str += (
        "  --tui                  Request a caller-populated status frame\n"
    )
    help_str += "  -v, --verbose          Enable detailed debug logging\n"
    help_str += "  --format <json|text>   Output response format\n"
    return help_str


def get_command_help(cmd: String) -> String:
    """Returns detailed help string for a specific subcommand."""
    var name = cmd.strip().lower()
    if name == "run":
        return (
            "aesir run <model.gguf> [--max-tokens N] <prompt>\n\nRuns the"
            " verified local single-shot CPU GGUF path. Interactive mode is"
            " unsupported."
        )
    elif name == "serve":
        return (
            "aesir serve\n\nReserved and unsupported. No model-backed service"
            " loop is started."
        )
    elif name == "config":
        return (
            "aesir config [--config <path>] [--format json|text]\n\nReads,"
            " validates, and prints the selected configuration. The default"
            " path is aesir.config.json."
        )
    elif name == "tui":
        return (
            "aesir --tui\n\nRequests a caller-populated status frame. Live"
            " telemetry collection is not implemented."
        )
    else:
        return get_help_overview()
