# cli/commands.mojo
# Truthful Project Aesir CLI command dispatcher.

from cli.manifest import ModelManifest, RuneModelStore
from cli.repl import RuneREPL, run_single_shot
from cli.options import CLIOptions, parse_cli_options
from cli.multi_engine import dispatch_llama_cli, dispatch_exl2_cli, dispatch_onnx_cli


def print_banner():
    """Displays the Project Aesir development CLI header."""
    print("==========================================================================")
    print("  Project Aesir CLI — verified local GGUF run + development surfaces")
    print("==========================================================================")


def print_general_help():
    """Prints implemented and reserved commands without compatibility claims."""
    print_banner()
    print("Usage:")
    print("  aesir [command] [flags]\n")
    print("Implemented:")
    print("  run <model.gguf> [--max-tokens N] [--verbose] [--format json] <prompt...>")
    print("      Run one local single-shot request on the verified CPU GGUF path.")
    print("  list, ls [--format json]")
    print("      List all installed local model manifests.")
    print("  show <model> [--format json]")
    print("      Show details and Modelfile inscriptions for a model.")
    print("  ps [--format json]")
    print("      List active model engine sessions.")
    print("  create <name> -f <modelfile>")
    print("      Create a new model manifest entry from a Modelfile.")
    print("  cp <source> <target>")
    print("      Copy a model manifest to a new name or tag.")
    print("  rm, delete <model>")
    print("      Remove a model manifest entry.")
    print("  help, -h, --help")
    print("      Show this capability-aware help.")
    print("  -v, --version")
    print("      Show the development version.\n")
    print("Reserved but unsupported:")
    print("  serve; interactive run; pull; push; stop")
    print("  llama-cli; llama-server; llama-bench; exl2; onnx; swarm")
    print("See ../CAPABILITY_LEDGER.md for exact evidence and acceptance gates.")


def parse_positive_int(value: String) raises -> Int:
    """Parses an unsigned decimal CLI value and rejects zero or malformed input."""
    var raw = value.as_bytes()
    if len(raw) == 0:
        raise Error("--max-tokens requires a positive integer")

    var parsed = 0
    for index in range(len(raw)):
        var byte_value = raw[index]
        if byte_value < 48 or byte_value > 57:
            raise Error("--max-tokens requires a positive integer")
        var digit = Int(byte_value - 48)
        if parsed > (2147483647 - digit) // 10:
            raise Error("--max-tokens value is too large")
        parsed = parsed * 10 + digit

    if parsed <= 0:
        raise Error("--max-tokens requires a positive integer")
    return parsed


def format_model_table(models: List[ModelManifest], is_json: Bool = False):
    """Formats manifest values into a clean table or JSON array."""
    if is_json:
        print("[")
        for i in range(len(models)):
            var manifest = models[i]
            var comma = String(",")
            if i == len(models) - 1:
                comma = String("")
            print("  {\"name\": \"" + manifest.name + ":" + manifest.tag + "\", \"digest\": \"" + manifest.digest + "\", \"size\": " + String(manifest.size_bytes) + "}" + comma)
        print("]")
        return

    print("NAME              \tID          \tSIZE    \tMODIFIED")
    print("------------------\t------------\t--------\t-------------")
    for i in range(len(models)):
        var manifest = models[i]
        var name_col = manifest.name + String(":") + manifest.tag
        while len(name_col.bytes()) < 18:
            name_col += String(" ")
        var id_col = String("unknown")
        if len(manifest.digest.bytes()) >= 19:
            id_col = String(manifest.digest[byte=7:19])
        var size_col = manifest.size_formatted()
        while len(size_col.bytes()) < 8:
            size_col += String(" ")
        print(
            name_col
            + "\t"
            + id_col
            + "\t"
            + size_col
            + "\t"
            + manifest.modified_time
        )


def show_model_details(manifest: ModelManifest, is_json: Bool = False):
    """Prints detailed manifest information."""
    if is_json:
        print("{\"name\": \"" + manifest.name + ":" + manifest.tag + "\", \"digest\": \"" + manifest.digest + "\", \"size\": " + String(manifest.size_bytes) + ", \"quantization\": \"" + manifest.quantization + "\"}")
        return

    print("Model:        " + manifest.name + ":" + manifest.tag)
    print("Digest:       " + manifest.digest)
    print("Size:         " + manifest.size_formatted())
    print("Quantization: " + manifest.quantization)
    print("Hidden Dim:   " + String(manifest.hidden_dim))
    print("Num Layers:   " + String(manifest.num_layers))
    print("Modified:     " + manifest.modified_time)
    print("\nModelfile:")
    print("--------------------------------------------------")
    print(manifest.modelfile_content)
    print("--------------------------------------------------")


def format_ps_table(models: List[ModelManifest], is_json: Bool = False):
    """Formats caller-supplied manifests without inventing process telemetry."""
    if not is_json:
        print("Runtime process telemetry:")
    format_model_table(models, is_json)


def dispatch_command(args: List[String]) raises:
    """Routes implemented commands with a fresh store."""
    var store = RuneModelStore()
    dispatch_command(args, store)


def dispatch_command(args: List[String], mut store: RuneModelStore) raises:
    """Routes implemented commands and rejected reserved surfaces using a shared store context."""
    if len(args) == 0:
        print_general_help()
        return

    var cmd = args[0]

    if cmd == "help" or cmd == "-h" or cmd == "--help":
        print_general_help()
        return

    if cmd == "-v" or cmd == "--version":
        print("aesir development version 0.9.0")
        return

    var options = parse_cli_options(args)
    var is_json = options.format == "json"

    if cmd == "run":
        if len(args) < 2:
            raise Error(
                "'run' requires a model path. Usage: aesir run "
                + String("<model.gguf> [--max-tokens N] <prompt...>")
            )
        var model_name = args[1]
        if len(args) < 3:
            var repl = RuneREPL(model_name)
            repl.run_repl()
            return

        var max_new_tokens = options.max_tokens
        var prompt_start = 2
        if args[2] == "--max-tokens":
            if len(args) < 4:
                raise Error("--max-tokens requires a positive integer value")
            max_new_tokens = parse_positive_int(args[3])
            prompt_start = 4
        if len(args) <= prompt_start:
            raise Error("single-shot run requires prompt text after its options")

        var prompt = String("")
        for i in range(prompt_start, len(args)):
            if i > prompt_start:
                prompt += String(" ")
            prompt += args[i]
        run_single_shot(model_name, prompt, max_new_tokens)
        return

    if cmd == "list" or cmd == "ls":
        var models = store.list_models()
        if len(models) == 0:
            if is_json:
                print("[]")
            else:
                print("No local models found.")
        else:
            format_model_table(models, is_json)
        return

    if cmd == "show":
        if len(args) < 2:
            raise Error("'show' requires a model name. Usage: aesir show <model>")
        var manifest = store.get_model(args[1])
        show_model_details(manifest, is_json)
        return

    if cmd == "ps":
        var active = store.get_active_ps()
        if len(active) == 0:
            if is_json:
                print("[]")
            else:
                print("NAME              \tID          \tSIZE    \tMODIFIED")
                print("------------------\t------------\t--------\t-------------")
                print("No active model sessions running.")
        else:
            format_ps_table(active, is_json)
        return

    if cmd == "create":
        if len(args) < 4 or args[2] != "-f":
            raise Error("'create' requires a model name and Modelfile path. Usage: aesir create <name> -f <modelfile_path>")
        var default_modelfile = String("FROM ") + args[1] + String(".gguf\nSYSTEM You are ") + args[1]
        store.create_model(args[1], default_modelfile)
        print("Created model '" + args[1] + "' successfully.")
        return

    if cmd == "cp":
        if len(args) < 3:
            raise Error("'cp' requires source and target names. Usage: aesir cp <source> <target>")
        store.copy_model(args[1], args[2])
        print("Copied model '" + args[1] + "' to '" + args[2] + "' successfully.")
        return

    if cmd == "rm" or cmd == "delete":
        if len(args) < 2:
            raise Error("'rm' requires a model name. Usage: aesir rm <model>")
        if store.remove_model(args[1]):
            print("Removed model '" + args[1] + "' successfully.")
        else:
            raise Error("model manifest not found: " + args[1])
        return

    if cmd == "serve" or cmd == "daemon":
        raise Error("HTTP server daemon is not implemented")

    if cmd == "stop":
        raise Error("engine process control command '" + cmd + "' is not implemented")

    if cmd == "pull" or cmd == "push":
        raise Error("model registry transfer command '" + cmd + "' is not implemented")

    if cmd == "swarm":
        raise Error("swarm operational command 'swarm' is not implemented")

    if cmd == "llama-cli" or cmd == "llama-server" or cmd == "llama-bench":
        _ = dispatch_llama_cli(args)
        return
    if cmd == "exl2":
        _ = dispatch_exl2_cli(args)
        return
    if cmd == "onnx":
        _ = dispatch_onnx_cli(args)
        return

    raise Error("unknown command: " + cmd)
