# cli/help.mojo
# Comprehensive Interactive Help System for Project A.E.S.I.R.

def get_help_overview() -> String:
    """Returns the main CLI help text detailing all commands, options, and paradigms."""
    var help_str = String("═══════════════════════════════════════════════════════════════════════════════\n")
    help_str += "  Project A.E.S.I.R. CLI — Cyber-Viking AI Engine & Inference Gateway\n"
    help_str += "═══════════════════════════════════════════════════════════════════════════════\n\n"
    help_str += "USAGE:\n"
    help_str += "  aesir [command] [flags] [arguments]\n\n"
    help_str += "COMMANDS:\n"
    help_str += "  run <model>            Run interactive REPL session with specified GGUF model\n"
    help_str += "  serve                  Launch bare-metal OpenAI-compatible HTTP REST server\n"
    help_str += "  list                   Display local models stored in persistent model vault\n"
    help_str += "  show <model>           Show detailed parameters and layer metadata for a model\n"
    help_str += "  ps                     List currently active model inference sessions\n"
    help_str += "  create <model> -f <file> Create new model manifest from Modelfile\n"
    help_str += "  gc                     Remove unreferenced stored model blobs\n"
    help_str += "  config                 Manage or display aesir.config.toml settings\n"
    help_str += "  help [command]         Show general help or help for a specific command\n\n"
    help_str += "FLAGS & OPTIONS:\n"
    help_str += "  -a, --accel <backend>  Hardware acceleration (auto|cuda|metal|intel|amd|npu|cpu|max)\n"
    help_str += "  -c, --config <path>    Specify path to configuration manifest (default: aesir.config.toml)\n"
    help_str += "  --skaldbrodir <on|off> Doom Loop Annihilation Protocol toggle\n"
    help_str += "  --thinking <on|off>    Thought token generation & suppression toggle\n"
    help_str += "  --cia <on|off>         Cognitive Inference Architecture toggle\n"
    help_str += "  --wic <on|off>         Wave Inference Computing toggle\n"
    help_str += "  --nsfi <on|off>        Neural Spectral Fractal Inference toggle\n"
    help_str += "  --tui                  Enable Rich Terminal Monitoring Dashboard\n"
    help_str += "  -v, --verbose          Enable detailed debug logging\n"
    help_str += "  --format <json|text>   Output response format\n"
    return help_str

def get_command_help(cmd: String) -> String:
    """Returns detailed help string for a specific subcommand."""
    var name = cmd.strip().lower()
    if name == "run":
        return "aesir run <model_name_or_path> [flags]\n\nRuns an interactive conversational REPL with the specified model.\nSupports slash commands (/set, /show, /clear, /bye)."
    elif name == "serve":
        return "aesir serve [--port 18434] [--host 127.0.0.1]\n\nStarts a high-performance bare-metal POSIX HTTP server serving OpenAI /v1/chat/completions endpoints."
    elif name == "config":
        return "aesir config [--show|--init]\n\nManages or outputs the human-readable aesir.config.toml configuration file."
    elif name == "tui":
        return "aesir --tui\n\nLaunches the rich terminal user interface showing live CPU/VRAM usage, token throughput, and active hardware realms."
    else:
        return get_help_overview()
