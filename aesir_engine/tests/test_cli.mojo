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
    print("--- Testing in-memory manifest fingerprint & text serialization ---")
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
    if not fetched.digest.startswith("fnv1a64:"):
        raise Error("create_model manifest fingerprint missing fnv1a64 prefix")
    if fetched.size_bytes != 0 or fetched.quantization != "unknown":
        raise Error("create_model fabricated unobserved model metadata")

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

    print("in-memory manifest fingerprint & text serialization: PASS")


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

    assert_cli_command_unsupported("list")
    assert_cli_command_unsupported("show")
    assert_cli_command_unsupported("ps")
    assert_cli_command_unsupported("create")
    assert_cli_command_unsupported("cp")
    assert_cli_command_unsupported("rm")

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
    inputs.append("/clear")
    inputs.append("/bye")

    var outputs = repl.run_repl_stream(inputs)
    if len(outputs) != 6:
        raise Error("run_repl_stream output length mismatch: got " + String(len(outputs)))
    if outputs[0] != "[HELP]":
        raise Error("REPL help slash command mismatch")
    if outputs[1] != "[SET]" or repl.config.temperature != 0.8:
        raise Error("REPL set temp slash command mismatch")
    if outputs[2] != "[SET]" or repl.config.top_k != 50:
        raise Error("REPL set top_k slash command mismatch")
    if outputs[3] != "[SHOW]":
        raise Error("REPL show slash command mismatch")
    if outputs[4] != "[CLEAR]":
        raise Error("REPL clear slash command mismatch")
    if outputs[5] != "[EXIT]":
        raise Error("REPL exit slash command mismatch")

    var chat_rejected = False
    try:
        _ = repl.process_input_line("Hello Aesir")
    except error:
        chat_rejected = True
        if "not implemented" not in String(error):
            raise Error("REPL chat rejection omitted truth boundary")
    if not chat_rejected:
        raise Error("REPL returned fabricated assistant text")

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

    # Verify invalid option values fail closed.
    var invalid_format = List[String]()
    invalid_format.append("list")
    invalid_format.append("--format")
    invalid_format.append("yaml")
    var invalid_format_rejected = False
    try:
        _ = parse_cli_options(invalid_format)
    except:
        invalid_format_rejected = True
    if not invalid_format_rejected:
        raise Error("CLIOptions accepted unsupported output format")

    # Verify ChatMessage empty list formatting safety
    from loader.chat_template import RuneChatTemplate, ChatMessage
    var tmpl = RuneChatTemplate("chatml")
    var empty_msgs = List[ChatMessage]()
    var empty_chatml_rejected = False
    try:
        _ = tmpl.format_chatml(empty_msgs)
    except:
        empty_chatml_rejected = True
    if not empty_chatml_rejected:
        raise Error("RuneChatTemplate format_chatml failed to reject empty message list")

    print("CLIOptions flag parser, duration conversion & JSON output: PASS")

def test_model_store_in_use_protection() raises:
    print("--- Testing RuneModelStore in-use & non-existent model rejection ---")
    var store = RuneModelStore()
    store.create_model("llama3:latest", "FROM llama.gguf")

    var in_use_rejected = False
    try:
        store.remove_model_checked("llama3:latest", active_model="llama3:latest")
    except:
        in_use_rejected = True
    if not in_use_rejected:
        raise Error("remove_model_checked failed to reject removal of model currently in use")

    var not_found_rejected = False
    try:
        store.remove_model_checked("nonexistent:latest", active_model="")
    except:
        not_found_rejected = True
    if not not_found_rejected:
        raise Error("remove_model_checked failed to reject non-existent model name")

    print("RuneModelStore in-use & not-found protection: PASS")

def main() raises:
    test_modelfile_parser()
    test_cli_flag_options_parser()
    test_model_store_in_use_protection()
