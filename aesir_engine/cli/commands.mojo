# cli/commands.mojo
# Truthful Project Aesir CLI command dispatcher.

from cli.manifest import ModelManifest, RuneModelStore
from cli.repl import RuneREPL, run_single_shot
from cli.options import CLIOptions, parse_cli_options
from cli.multi_engine import (
    dispatch_llama_cli,
    dispatch_exl2_cli,
    dispatch_onnx_cli,
)
from config import AesirConfig, load_config_file
from server.api import BifrostGate
from loader.huggingface import HuggingFaceSeer
from cli.cuda_chat import dispatch_cuda_chat, cuda_single_shot


def print_banner():
    """Displays the Project Aesir development CLI header."""
    print(
        "=========================================================================="
    )
    print(
        "  Project Aesir CLI — verified local GGUF run + development surfaces"
    )
    print(
        "=========================================================================="
    )


def print_general_help():
    """Prints implemented and reserved commands without compatibility claims."""
    print_banner()
    print("Usage:")
    print("  aesir [command] [flags]\n")
    print("Implemented:")
    print("  pull <owner/repo> <filename.gguf> --revision <commit-sha>")
    print("      --sha256 <digest> --size <bytes> [--output <path>] [--connections 1..8]")
    print("      Download and verify a public pinned GGUF; never overwrite a file.")
    print(
        "  run <model.gguf> [--max-tokens N] [--config path]"
        " [--accel auto|cpu|cuda] <prompt...>"
    )
    print(
        "      CPU GGUF or native CUDA Gemma 4 E4B single-shot inference."
    )
    print("  chat <model.gguf> --accel cuda [--profile gemma4|llama3]")
    print("      [--prompts file] [--log file] [--max-tokens N] [--context N] [--system text]")
    print("      Gemma defaults: 16384/32768; Llama 3 defaults: 8192/8192 (reply/context).")
    print("      Persistent CUDA text chat; one user turn per nonempty prompt-file line.")
    print("  config [--config <path>] [--format json|text]")
    print("      Validate and show the selected configuration file.")
    print("  help, -h, --help")
    print("      Show this capability-aware help.")
    print("  -v, --version")
    print("      Show the development version.\n")
    print("Reserved but unsupported:")
    print("  serve; interactive run; list; show; ps; create; cp; rm")
    print("  push; stop")
    print("  llama-cli; llama-server; llama-bench; exl2; onnx; swarm")
    print(
        "See ../CAPABILITY_LEDGER.md for exact evidence and acceptance gates."
    )


def parse_positive_int(value: String) raises -> Int:
    """Parses an unsigned decimal CLI value and rejects zero or malformed input.
    """
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


def option_requires_value(option: String) -> Bool:
    """Identifies recognized CLI options that consume the following token."""
    return (
        option == "--format"
        or option == "--keepalive"
        or option == "--modelfile"
        or option == "-f"
        or option == "--max-tokens"
        or option == "--config"
        or option == "-c"
        or option == "--accel"
        or option == "-a"
        or option == "--skaldbrodir"
        or option == "--thinking"
        or option == "--cia"
        or option == "--wic"
        or option == "--nsfi"
    )


def option_is_switch(option: String) -> Bool:
    """Identifies recognized single-token CLI switches."""
    return (
        option == "--verbose"
        or option == "-v"
        or option == "--raw"
        or option == "--insecure"
        or option == "--tui"
    )


def collect_run_positionals(args: List[String]) raises -> List[String]:
    """Returns model/prompt tokens while preventing option leakage into prompts.
    """
    var positionals = List[String]()
    var index = 1
    while index < len(args):
        var token = args[index]
        if option_requires_value(token):
            if index + 1 >= len(args):
                raise Error("missing value for option " + token)
            index += 2
            continue
        if option_is_switch(token):
            index += 1
            continue
        if token.startswith("-"):
            raise Error("unknown run option: " + token)
        positionals.append(token)
        index += 1
    return positionals^


def validate_config_command_args(args: List[String]) raises:
    """Restricts the config command to its documented options."""
    var index = 1
    while index < len(args):
        var token = args[index]
        if token == "--config" or token == "-c" or token == "--format":
            if index + 1 >= len(args):
                raise Error("missing value for option " + token)
            index += 2
            continue
        raise Error("unknown config option: " + token)


def effective_config(options: CLIOptions) raises -> AesirConfig:
    """Loads explicit file intent and applies the documented CLI override."""
    var config = AesirConfig()
    if options.config_was_set:
        config = load_config_file(options.config_path)
    if options.accel_was_set:
        config.acceleration_backend = options.accel_backend
    return config^


def require_verified_cpu_backend(config: AesirConfig) raises:
    """Prevents explicit backend intent from silently running on the CPU."""
    if (
        config.acceleration_backend != "auto"
        and config.acceleration_backend != "cpu"
    ):
        raise Error(
            "requested acceleration backend '"
            + config.acceleration_backend
            + "' is not implemented; verified execution is CPU-only"
        )


def validate_single_shot_config_support(config: AesirConfig) raises:
    """Rejects non-neutral config fields until their runtime owners are wired.
    """
    if config.target_npu != "auto":
        raise Error(
            "target_npu is not applicable to verified CPU single-shot run"
        )
    if config.num_gpu_layers != 0:
        raise Error(
            "num_gpu_layers is not applicable to verified CPU single-shot run"
        )
    if config.max_threads != 0:
        raise Error("max_threads is not connected to single-shot run")
    if config.skaldbrodir_enabled:
        raise Error("skaldbrodir_enabled is not connected to model generation")
    if config.thinking_enabled:
        raise Error("thinking_enabled is not connected to model generation")
    if config.cia_enabled or config.wic_enabled or config.nsfi_enabled:
        raise Error(
            "experimental inference config is not connected to model generation"
        )
    if config.mqari_enabled:
        raise Error("mqari_enabled is not connected to model generation")
    if config.tui_enabled:
        raise Error(
            "tui_enabled live telemetry is not connected to single-shot run"
        )
    if config.temperature != 0.0 or config.top_p != 1.0:
        raise Error("sampling config is not connected to single-shot run")


def validate_run_option_support(options: CLIOptions) raises:
    """Rejects parsed options whose owning operation is not single-shot run."""
    if options.verbose_was_set:
        raise Error("--verbose is not implemented for single-shot run")
    if options.format_was_set:
        raise Error("--format is not implemented for single-shot run")
    if options.keepalive_was_set:
        raise Error(
            "--keepalive applies to managed service sessions, not"
            " single-shot run"
        )
    if options.modelfile_was_set:
        raise Error("--modelfile is not connected to single-shot run")
    if options.raw_was_set:
        raise Error("--raw is not implemented for single-shot run")
    if options.insecure_was_set:
        raise Error(
            "--insecure applies to authenticated network operations, not"
            " local run"
        )
    if options.skaldbrodir_was_set:
        raise Error("--skaldbrodir is not connected to model generation")
    if options.thinking_was_set:
        raise Error("--thinking is not connected to model generation")
    if options.cia_was_set:
        raise Error("--cia is not connected to model generation")
    if options.wic_was_set:
        raise Error("--wic is not connected to model generation")
    if options.nsfi_was_set:
        raise Error("--nsfi is not connected to model generation")
    if options.tui_was_set:
        raise Error("--tui live telemetry is not connected to single-shot run")


def format_model_table(models: List[ModelManifest], is_json: Bool = False):
    """Formats manifest values into a clean table or JSON array."""
    if is_json:
        print("[")
        for i in range(len(models)):
            var manifest = models[i]
            var comma = String(",")
            if i == len(models) - 1:
                comma = String("")
            print(
                '  {"name": "'
                + manifest.name
                + ":"
                + manifest.tag
                + '", "digest": "'
                + manifest.digest
                + '", "size": '
                + String(manifest.size_bytes)
                + "}"
                + comma
            )
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
        print(
            '{"name": "'
            + manifest.name
            + ":"
            + manifest.tag
            + '", "digest": "'
            + manifest.digest
            + '", "size": '
            + String(manifest.size_bytes)
            + ', "quantization": "'
            + manifest.quantization
            + '"}'
        )
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


def dispatch_pull(args: List[String]) raises:
    """Parse explicit artifact identity before the loader performs any I/O."""
    if len(args) < 3:
        raise Error("pull requires repository and filename plus --revision, --sha256, --size")
    var revision = String("")
    var digest = String("")
    var destination = String(args[2])
    var expected_size = 0
    var connections = 1
    var seen = List[String]()
    var index = 3
    while index < len(args):
        var option = args[index]
        if (option != "--revision" and option != "--sha256"
                and option != "--size" and option != "--output"
                and option != "--connections"):
            raise Error("unknown pull option: " + option)
        for prior in seen:
            if prior == option:
                raise Error("duplicate pull option: " + option)
        seen.append(option)
        if index + 1 >= len(args):
            raise Error("missing value for pull option " + option)
        var value = args[index + 1]
        if option == "--revision":
            revision = value
        elif option == "--sha256":
            digest = value
        elif option == "--output":
            destination = value
        elif option == "--connections":
            connections = parse_positive_int(value)
        else:
            if len(value.bytes()) == 0:
                raise Error("pull --size requires a positive byte count")
            for byte in value.as_bytes():
                if byte < 48 or byte > 57:
                    raise Error("pull --size requires a positive byte count")
                var digit = Int(byte - 48)
                if expected_size > (9223372036854775807 - digit) // 10:
                    raise Error("pull --size overflows a 64-bit byte count")
                expected_size = expected_size * 10 + digit
        index += 2
    var hf = HuggingFaceSeer()
    _ = hf.download_hf_model(
        args[1], args[2], destination, revision, digest, expected_size, connections
    )
    print("Successfully downloaded and verified Hugging Face model: " + destination)


def dispatch_command(args: List[String]) raises:
    """Routes implemented commands with a fresh store."""
    var store = RuneModelStore()
    dispatch_command(args, store)


def dispatch_command(args: List[String], mut store: RuneModelStore) raises:
    """Routes implemented commands and rejected reserved surfaces using a shared store context.
    """
    if len(args) == 0:
        print_general_help()
        return

    var cmd = args[0]

    if cmd == "help" or cmd == "-h" or cmd == "--help":
        print_general_help()
        return

    if cmd == "-v" or cmd == "--version":
        print("aesir development snapshot (unversioned)")
        return

    if cmd == "pull":
        dispatch_pull(args)
        return

    if cmd == "chat":
        dispatch_cuda_chat(args)
        return

    var options = parse_cli_options(args)
    var is_json = options.format == "json"

    if cmd == "config":
        validate_config_command_args(args)
        var config = load_config_file(options.config_path)
        if not is_json:
            print("Validated configuration: " + config.config_path)
        print(config.to_json_string(), end="")
        return

    if cmd == "run":
        validate_run_option_support(options)
        var positionals = collect_run_positionals(args)
        if len(positionals) < 1:
            raise Error(
                "'run' requires a model path. Usage: aesir run "
                + String("<model.gguf> [--max-tokens N] <prompt...>")
            )
        var model_name = positionals[0]
        if len(positionals) < 2:
            var repl = RuneREPL(model_name)
            repl.run_repl()
            return

        var config = effective_config(options)
        validate_single_shot_config_support(config)
        if config.acceleration_backend != "cuda":
            require_verified_cpu_backend(config)

        var prompt = String("")
        for i in range(1, len(positionals)):
            if i > 1:
                prompt += String(" ")
            prompt += positionals[i]
        var trimmed_prompt = String(prompt.strip())
        if len(trimmed_prompt.bytes()) == 0:
            raise Error("single-shot run prompt text must not be empty")
        if config.acceleration_backend == "cuda":
            cuda_single_shot(model_name, trimmed_prompt, options.max_tokens)
        else:
            run_single_shot(model_name, trimmed_prompt, options.max_tokens)
        return

    if (
        cmd == "list"
        or cmd == "ls"
        or cmd == "show"
        or cmd == "ps"
        or cmd == "create"
        or cmd == "cp"
        or cmd == "rm"
        or cmd == "delete"
    ):
        _ = store
        _ = is_json
        raise Error(
            "persistent model-store command '" + cmd + "' is not implemented"
        )

    if cmd == "serve" or cmd == "daemon":
        print("Starting Project Aesir Bifrost Server on port 18434...")
        var server = BifrostGate(18434)
        if not server.start():
            raise Error("Failed to start Bifrost Server")
        server.close()
        return

    if cmd == "stop":
        raise Error(
            "engine process control command '" + cmd + "' is not implemented"
        )

    if cmd == "push":
        raise Error(
            "model registry transfer command '" + cmd + "' is not implemented"
        )

    if cmd == "swarm":
        if len(args) <= 1:
            raise Error(
                "swarm command requires a subcommand (join, status, list)"
            )
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
