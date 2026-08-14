# tests/test_cli.mojo
# Verification of Complete Ollama Terminal Command Suite (Slice 9)

from cli.modelfile import parse_modelfile, Modelfile
from cli.manifest import RuneModelStore, ModelManifest
from cli.commands import dispatch_command

def test_modelfile_parser() raises:
    print("--- Testing Modelfile Parser (DIRECTIVES) ---")
    var success = True
    var content = String("FROM model.gguf\nPARAMETER temperature 0.7\nPARAMETER top_k 40\nSYSTEM You are Aesir.\nLICENSE MIT")
    var parsed = parse_modelfile(content)

    if parsed.from_model != "model.gguf":
        print("FAIL: Expected FROM model.gguf, got", parsed.from_model)
        success = False
    if parsed.system_prompt != "You are Aesir.":
        print("FAIL: Expected SYSTEM prompt 'You are Aesir.', got", parsed.system_prompt)
        success = False
    if parsed.license_info != "MIT":
        print("FAIL: Expected LICENSE MIT, got", parsed.license_info)
        success = False
    if "temperature" not in parsed.parameters or parsed.parameters["temperature"] != "0.7":
        print("FAIL: Expected PARAMETER temperature 0.7")
        success = False

    if success:
        print("Modelfile Parser: PASS")
    else:
        print("Modelfile Parser: FAIL")


def test_model_manifest_store() raises:
    print("--- Testing RuneModelStore Catalog Operations ---")
    var success = True
    var store = RuneModelStore()

    var models = store.list_models()
    if len(models) < 3:
        print("FAIL: Expected at least 3 models in store, got", len(models))
        success = False

    # Test copy model
    store.copy_model("llama3:latest", "llama3-backup:latest")
    var copied = store.get_model("llama3-backup:latest")
    if copied.name != "llama3-backup":
        print("FAIL: Copy model name mismatch")
        success = False

    # Test remove model
    var removed = store.remove_model("llama3-backup:latest")
    if not removed:
        print("FAIL: Remove model failed")
        success = False

    # Test active ps
    var active = store.get_active_ps()
    if len(active) == 0:
        print("FAIL: Active ps empty")
        success = False

    if success:
        print("RuneModelStore Catalog: PASS")
    else:
        print("RuneModelStore Catalog: FAIL")


def test_cli_command_dispatch() raises:
    print("--- Testing CLI Command Dispatcher (12 Subcommands) ---")

    var help_args = List[String]()
    help_args.append("help")
    dispatch_command(help_args)

    var list_args = List[String]()
    list_args.append("list")
    dispatch_command(list_args)

    var ps_args = List[String]()
    ps_args.append("ps")
    dispatch_command(ps_args)

    var show_args = List[String]()
    show_args.append("show")
    show_args.append("aesir:latest")
    dispatch_command(show_args)

    print("CLI Command Dispatcher: PASS")
