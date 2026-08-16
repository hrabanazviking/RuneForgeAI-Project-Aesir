# tests/test_cli.mojo
# Verification of implemented CLI parsing and honest unsupported boundaries.

from cli.modelfile import parse_modelfile
from cli.manifest import RuneModelStore, ModelManifest
from cli.commands import dispatch_command
from cli.repl import RuneREPL
from cli.options import parse_cli_options, parse_duration_seconds


def test_modelfile_parser() raises:
    print("--- Testing Modelfile directive parser, quoting & GenerationConfig conversion ---")
    var content = String(
        "FROM \"model.gguf\"\n"
        + "PARAMETER num_predict 64\n"
        + "PARAMETER temperature 0.8\n"
        + "PARAMETER top_k 40\n"
        + "PARAMETER top_p 0.9\n"
        + "SYSTEM \"\"\"You are Aesir,\na sovereign engine.\"\"\"\n"
        + "LICENSE 'MIT License'"
    )
    var parsed = parse_modelfile(content)

    if parsed.from_model != "model.gguf":
        raise Error("Modelfile FROM directive mismatch: got '" + parsed.from_model + "'")
    if "You are Aesir,\na sovereign engine." not in parsed.system_prompt:
        raise Error("Modelfile multiline SYSTEM directive mismatch")
    if parsed.license_info != "MIT License":
        raise Error("Modelfile LICENSE directive mismatch: got '" + parsed.license_info + "'")
    if "temperature" not in parsed.parameters or parsed.parameters["temperature"] != "0.8":
        raise Error("Modelfile PARAMETER directive mismatch")

    # Test GenerationConfig conversion
    var gen_cfg = parsed.to_generation_config()
    if gen_cfg.max_new_tokens != 64:
        raise Error("to_generation_config max_new_tokens mismatch: got " + String(gen_cfg.max_new_tokens))
    if gen_cfg.top_k != 40:
        raise Error("to_generation_config top_k mismatch")

    # Test missing FROM validation
    var missing_from = False
    try:
        _ = parse_modelfile("PARAMETER temperature 0.5")
    except:
        missing_from = True
    if not missing_from:
        raise Error("parse_modelfile must fail when FROM directive is missing")

    print("Modelfile directive parser & GenerationConfig integration: PASS")


def test_model_manifest_store() raises:
    print("--- Testing model manifest store, SHA-256 digest & disk serialization ---")
    var store = RuneModelStore()
    if len(store.list_models()) != 0:
        raise Error("new model store must not contain fictional manifests")
    if len(store.get_active_ps()) != 0:
        raise Error("model store must not report fictional active processes")

    var missing_rejected = False
    try:
        _ = store.get_model("missing")
    except error:
        missing_rejected = True
        if "not found" not in String(error):
            raise Error("missing manifest error omitted not-found text")
    if not missing_rejected:
        raise Error("missing model lookup returned a fictional manifest")

    # Test digest computation
    var mf_text = String("FROM test.gguf\nPARAMETER temperature 0.7\nSYSTEM You are test.")
    store.create_model("testmodel:v1", mf_text)
    var fetched = store.get_model("testmodel:v1")
    if not fetched.digest.startswith("sha256:"):
        raise Error("create_model manifest digest missing sha256: prefix")

    # Test store serialization round-trip
    var serialized = store.serialize_store()
    if "testmodel" not in serialized:
        raise Error("serialize_store missing testmodel entry")

    var new_store = RuneModelStore()
    new_store.deserialize_store(serialized)
    var restored = new_store.get_model("testmodel:v1")
    if restored.name != "testmodel":
        raise Error("deserialized store manifest name mismatch: got " + restored.name)
    if restored.digest != fetched.digest:
        raise Error("deserialized store manifest digest mismatch")

    # Test manifest removal
    if not store.remove_model("testmodel:v1"):
        raise Error("manifest removal failed")
    if len(store.list_models()) != 0:
        raise Error("store list_models must be empty after removal")

    # Test copy model empty parameter rejection
    var copy_rejected = False
    try:
        store.copy_model("", "target")
    except:
        copy_rejected = True
    if not copy_rejected:
        raise Error("copy_model failed to reject empty source parameter")

    print("model manifest store, digest & serialization: PASS")


def assert_cli_command_unsupported(command: String) raises:
    var args = List[String]()
    args.append(command)
    var rejected = False
    try:
        dispatch_command(args)
    except error:
        rejected = True
        var message = String(error)
        if "not implemented" not in message and "unsupported" not in message and "requires a subcommand" not in message:
            raise Error("unsupported CLI error omitted stable truth text")
    if not rejected:
        raise Error("unsupported CLI command returned successfully: " + command)


def test_cli_command_dispatch() raises:
    print("--- Testing operational CLI command dispatchers & boundaries ---")

    var store = RuneModelStore()

    var help_args = List[String]()
    help_args.append("help")
    dispatch_command(help_args, store)

    # Test implemented operational CLI commands
    var list_args = List[String]()
    list_args.append("list")
    dispatch_command(list_args, store)

    var ps_args = List[String]()
    ps_args.append("ps")
    dispatch_command(ps_args, store)

    var create_args = List[String]()
    create_args.append("create")
    create_args.append("demo-model")
    create_args.append("-f")
    create_args.append("Modelfile")
    dispatch_command(create_args, store)

    var show_args = List[String]()
    show_args.append("show")
    show_args.append("demo-model")
    dispatch_command(show_args, store)

    var cp_args = List[String]()
    cp_args.append("cp")
    cp_args.append("demo-model")
    cp_args.append("demo-copy")
    dispatch_command(cp_args, store)

    var rm_args = List[String]()
    rm_args.append("rm")
    rm_args.append("demo-model")
    dispatch_command(rm_args, store)

    # Verify reserved unsupported command rejections
    # Test bare swarm command subcommand requirement assertion
    var swarm_sub_rejected = False
    try:
        var swarm_args = List[String]()
        swarm_args.append("swarm")
        dispatch_command(swarm_args)
    except error:
        swarm_sub_rejected = True
        if "requires a subcommand" not in String(error):
            raise Error("swarm bare command rejection omitted subcommand error text")
    if not swarm_sub_rejected:
        raise Error("swarm bare command allowed execution without subcommand")

    # Test empty prompt single-shot run parameter rejection
    var empty_prompt_rejected = False
    try:
        var run_empty = List[String]()
        run_empty.append("run")
        run_empty.append("demo-model.gguf")
        run_empty.append("   ")
        dispatch_command(run_empty)
    except error:
        empty_prompt_rejected = True
        if "prompt text must not be empty" not in String(error):
            raise Error("empty prompt run rejection omitted expected error text")
    if not empty_prompt_rejected:
        raise Error("run command allowed empty prompt parameter")

    assert_cli_command_unsupported("serve")
    assert_cli_command_unsupported("pull")
    assert_cli_command_unsupported("push")
    assert_cli_command_unsupported("stop")
    assert_cli_command_unsupported("swarm")

    print("operational CLI command dispatchers & boundaries: PASS")


def test_repl_session_and_slash_commands() raises:
    print("--- Testing RuneREPL session state, slash commands & stream execution ---")
    var repl = RuneREPL("aesir-chat:latest")

    var inputs = List[String]()
    inputs.append("/?")
    inputs.append("/set temp 0.8")
    inputs.append("/set top_k 50")
    inputs.append("/show")
    inputs.append("Hello Aesir")
    inputs.append("/clear")
    inputs.append("/bye")

    var outputs = repl.run_repl_stream(inputs)
    if len(outputs) != 7:
        raise Error("run_repl_stream output length mismatch: got " + String(len(outputs)))
    if outputs[0] != "[HELP]":
        raise Error("REPL help slash command mismatch")
    if outputs[1] != "[SET]" or repl.config.temperature != 0.8:
        raise Error("REPL set temp slash command mismatch")
    if outputs[2] != "[SET]" or repl.config.top_k != 50:
        raise Error("REPL set top_k slash command mismatch")
    if outputs[3] != "[SHOW]":
        raise Error("REPL show slash command mismatch")
    if "Aesir response to: Hello Aesir" not in outputs[4]:
        raise Error("REPL chat turn response mismatch")
    if outputs[5] != "[CLEAR]":
        raise Error("REPL clear slash command mismatch")
    if outputs[6] != "[EXIT]":
        raise Error("REPL exit slash command mismatch")

    # Test negative configuration parameter clamping
    var neg_inputs = List[String]()
    neg_inputs.append("/set temp -0.5")
    neg_inputs.append("/set top_k -10")
    _ = repl.run_repl_stream(neg_inputs)
    if repl.config.temperature != 0.0:
        raise Error("REPL negative temperature was not clamped to 0.0")
    if repl.config.top_k != 0:
        raise Error("REPL negative top_k was not clamped to 0")

    print("RuneREPL session state & slash commands: PASS")


def test_cli_flag_options_parser() raises:
    print("--- Testing CLIOptions flag parser, duration conversion & JSON output ---")
    
    var args = List[String]()
    args.append("list")
    args.append("--verbose")
    args.append("--format")
    args.append("json")
    args.append("--keepalive")
    args.append("10m")
    args.append("--raw")
    args.append("--insecure")

    var options = parse_cli_options(args)
    if not options.verbose:
        raise Error("CLIOptions verbose flag not set")
    if options.format != "json":
        raise Error("CLIOptions format flag mismatch")
    if options.keepalive_seconds != 600:
        raise Error("CLIOptions duration parsing mismatch: expected 600s, got " + String(options.keepalive_seconds))
    if not options.raw:
        raise Error("CLIOptions raw flag not set")
    if not options.insecure:
        raise Error("CLIOptions insecure flag not set")

    # Verify JSON output dispatch
    var store = RuneModelStore()
    var list_json_args = List[String]()
    list_json_args.append("list")
    list_json_args.append("--format")
    list_json_args.append("json")
    dispatch_command(list_json_args, store)

    print("CLIOptions flag parser, duration conversion & JSON output: PASS")
