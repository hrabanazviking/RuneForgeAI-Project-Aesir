# cli/commands.mojo
# Truthful Project Aesir CLI command dispatcher.

from cli.manifest import ModelManifest
from cli.repl import RuneREPL, run_single_shot
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
    print("  run <model.gguf> [--max-tokens N] <prompt...>")
    print("      Run one local single-shot request on the verified CPU GGUF path.")
    print("  help, -h, --help")
    print("      Show this capability-aware help.")
    print("  -v, --version")
    print("      Show the development version.\n")
    print("Reserved but unsupported:")
    print("  serve; interactive run; pull; push; create; list; ps; rm; cp; show; stop")
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


def format_model_table(models: List[ModelManifest]):
    """Formats only manifest values explicitly supplied by the caller."""
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


def format_ps_table(models: List[ModelManifest]):
    """Formats caller-supplied manifests without inventing process telemetry."""
    print("Runtime process telemetry is not implemented.")
    format_model_table(models)


def dispatch_command(args: List[String]) raises:
    """Routes implemented commands and rejects reserved development surfaces."""
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

        var max_new_tokens = 32
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

    if cmd == "serve" or cmd == "daemon":
        raise Error("HTTP server daemon is not implemented")

    if (
        cmd == "list"
        or cmd == "ls"
        or cmd == "ps"
        or cmd == "create"
        or cmd == "rm"
        or cmd == "delete"
        or cmd == "cp"
        or cmd == "show"
        or cmd == "stop"
    ):
        raise Error("persistent model-store command '" + cmd + "' is not implemented")

    if cmd == "pull" or cmd == "push":
        raise Error("model registry transfer command '" + cmd + "' is not implemented")

    if (
        cmd == "llama-cli"
        or cmd == "llama-server"
        or cmd == "llama-bench"
        or cmd == "llama-perplexity"
        or cmd == "llama"
    ):
        _ = dispatch_llama_cli(args)
        return

    if cmd == "exl2":
        _ = dispatch_exl2_cli(args)
        return

    if cmd == "onnx":
        _ = dispatch_onnx_cli(args)
        return

    if cmd == "swarm":
        raise Error("swarm CLI execution is not implemented")

    raise Error("unknown command '" + cmd + "'")
