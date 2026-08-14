# tests/test_cli.mojo
# Verification of implemented CLI parsing and honest unsupported boundaries.

from cli.modelfile import parse_modelfile
from cli.manifest import RuneModelStore, ModelManifest
from cli.commands import dispatch_command


def test_modelfile_parser() raises:
    print("--- Testing narrow Modelfile directive parser ---")
    var content = String(
        "FROM model.gguf\nPARAMETER temperature 0.7\n"
        + String("PARAMETER top_k 40\nSYSTEM You are Aesir.\nLICENSE MIT")
    )
    var parsed = parse_modelfile(content)

    if parsed.from_model != "model.gguf":
        raise Error("Modelfile FROM directive mismatch")
    if parsed.system_prompt != "You are Aesir.":
        raise Error("Modelfile SYSTEM directive mismatch")
    if parsed.license_info != "MIT":
        raise Error("Modelfile LICENSE directive mismatch")
    if (
        "temperature" not in parsed.parameters
        or parsed.parameters["temperature"] != "0.7"
    ):
        raise Error("Modelfile PARAMETER directive mismatch")

    print("narrow Modelfile parser: PASS")


def test_model_manifest_store() raises:
    print("--- Testing empty in-memory manifest scaffold ---")
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

    var fixture = ModelManifest(
        "fixture",
        "latest",
        "sha256:0123456789ab",
        1024,
        "F16",
        64,
        5,
        "test fixture",
        "FROM fixture.gguf",
    )
    store.catalog[String("fixture:latest")] = fixture
    store.model_keys.append("fixture:latest")
    store.copy_model("fixture:latest", "fixture-copy:latest")
    if store.get_model("fixture-copy:latest").name != "fixture-copy":
        raise Error("explicit fixture manifest copy failed")
    if not store.remove_model("fixture-copy:latest"):
        raise Error("explicit fixture manifest removal failed")

    print("empty in-memory manifest scaffold: PASS")


def assert_cli_command_unsupported(command: String) raises:
    var args = List[String]()
    args.append(command)
    var rejected = False
    try:
        dispatch_command(args)
    except error:
        rejected = True
        var message = String(error)
        if "not implemented" not in message and "unsupported" not in message:
            raise Error("unsupported CLI error omitted stable truth text")
    if not rejected:
        raise Error("unsupported CLI command returned successfully: " + command)


def test_cli_command_dispatch() raises:
    print("--- Testing truthful CLI dispatcher boundaries ---")

    var help_args = List[String]()
    help_args.append("help")
    dispatch_command(help_args)

    assert_cli_command_unsupported("serve")
    assert_cli_command_unsupported("list")
    assert_cli_command_unsupported("ps")
    assert_cli_command_unsupported("show")
    assert_cli_command_unsupported("pull")
    assert_cli_command_unsupported("push")
    assert_cli_command_unsupported("create")
    assert_cli_command_unsupported("rm")
    assert_cli_command_unsupported("cp")
    assert_cli_command_unsupported("stop")
    assert_cli_command_unsupported("swarm")

    print("truthful CLI dispatcher boundaries: PASS")
