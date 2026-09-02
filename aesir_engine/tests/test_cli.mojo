# tests/test_cli.mojo
# Verification of implemented CLI parsing and honest unsupported boundaries.

from cli.modelfile import parse_modelfile
from cli.manifest import RuneModelStore, ModelManifest
from cli.storage import DurableModelStore, deserialize_catalog
from cli.commands import (
    collect_run_positionals,
    dispatch_command,
    effective_config,
    parse_pull_request,
    require_verified_cpu_backend,
    validate_single_shot_config_support,
    validate_run_option_support,
)
from cli.repl import RuneREPL
from cli.options import parse_cli_options, parse_duration_seconds
from config import load_config_file, parse_config_json, validate_model_store_path
from std.ffi import external_call


def _test_cstring(value: String) -> List[Int8]:
    var result = List[Int8]()
    var source = value.as_bytes()
    for index in range(len(source)):
        result.append(Int8(source[index]))
    result.append(0)
    return result^


def _cleanup_owned_model_store(
    root: String, digest: String = String("")
) raises:
    """Deletes only the model-store paths created by this test process."""
    if not root.startswith(".aesir-test-model-store-") or "/" in root:
        raise Error("refusing to clean a path not owned by the model-store test")
    var catalog_bytes = _test_cstring(root + "/catalog.v1")
    var source_bytes = _test_cstring(root + "/source.bin")
    var mismatch_source_bytes = _test_cstring(root + "/mismatch.bin")
    var orphan_blob_bytes = _test_cstring(
        root
        + "/blobs/sha256/f7053e5cd10c37b04d2d6db8f17bc3ede0e4d6912adfc54994c2b38aadcc40b0"
    )
    var stale_stage_bytes = _test_cstring(
        root + "/blobs/sha256/.ingest.999.1.tmp"
    )
    var unexpected_bytes = _test_cstring(root + "/blobs/sha256/unexpected")
    var sha_directory_bytes = _test_cstring(root + "/blobs/sha256")
    var blob_directory_bytes = _test_cstring(root + "/blobs")
    var root_bytes = _test_cstring(root)
    _ = external_call["unlink", Int32](catalog_bytes.unsafe_ptr())
    _ = external_call["unlink", Int32](source_bytes.unsafe_ptr())
    _ = external_call["unlink", Int32](mismatch_source_bytes.unsafe_ptr())
    _ = external_call["unlink", Int32](orphan_blob_bytes.unsafe_ptr())
    _ = external_call["unlink", Int32](stale_stage_bytes.unsafe_ptr())
    _ = external_call["unlink", Int32](unexpected_bytes.unsafe_ptr())
    if len(digest.bytes()) > 0:
        var blob_bytes = _test_cstring(
            root + "/blobs/sha256/" + String(digest[byte=7:])
        )
        _ = external_call["unlink", Int32](blob_bytes.unsafe_ptr())
    _ = external_call["rmdir", Int32](sha_directory_bytes.unsafe_ptr())
    _ = external_call["rmdir", Int32](blob_directory_bytes.unsafe_ptr())
    if external_call["rmdir", Int32](root_bytes.unsafe_ptr()) != 0:
        raise Error("failed to remove test-owned model-store directory")


def _write_test_blob(path: String, content: String) raises:
    var path_bytes = _test_cstring(path)
    var fd = external_call["open64", Int32](
        path_bytes.unsafe_ptr(), Int32(655553), Int32(384)
    )
    if fd < 0:
        raise Error("unable to create test-owned model blob source")
    var source = content.as_bytes()
    var offset = 0
    while offset < len(source):
        var written = external_call["write", Int](
            Int(fd), source.unsafe_ptr().unsafe_offset(offset), len(source) - offset
        )
        if written <= 0:
            _ = external_call["close", Int32](fd)
            raise Error("unable to write test-owned model blob source")
        offset += written
    if external_call["fsync", Int32](fd) != 0:
        _ = external_call["close", Int32](fd)
        raise Error("unable to synchronize test-owned model blob source")
    _ = external_call["close", Int32](fd)


def test_modelfile_parser() raises:
    print(
        "--- Testing Modelfile directive parser, quoting & GenerationConfig"
        " conversion ---"
    )
    var content = String(
        'FROM "model.gguf"\n'
        + "PARAMETER num_predict 64\n"
        + "PARAMETER temperature 0.8\n"
        + "PARAMETER top_k 40\n"
        + "PARAMETER top_p 0.9\n"
        + 'SYSTEM """You are Aesir,\na sovereign engine."""\n'
        + "LICENSE 'MIT License'"
    )
    var parsed = parse_modelfile(content)

    if parsed.from_model != "model.gguf":
        raise Error(
            "Modelfile FROM directive mismatch: got '" + parsed.from_model + "'"
        )
    if "You are Aesir,\na sovereign engine." not in parsed.system_prompt:
        raise Error("Modelfile multiline SYSTEM directive mismatch")
    if parsed.license_info != "MIT License":
        raise Error(
            "Modelfile LICENSE directive mismatch: got '"
            + parsed.license_info
            + "'"
        )
    if (
        "temperature" not in parsed.parameters
        or parsed.parameters["temperature"] != "0.8"
    ):
        raise Error("Modelfile PARAMETER directive mismatch")

    # Test GenerationConfig conversion
    var gen_cfg = parsed.to_generation_config()
    if gen_cfg.max_new_tokens != 64:
        raise Error(
            "to_generation_config max_new_tokens mismatch: got "
            + String(gen_cfg.max_new_tokens)
        )
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
    print("--- Testing validated manifests & restart-safe durable catalog ---")
    var pull_args: List[String] = [
        "pull",
        "owner/repository",
        "model.gguf",
        "--revision",
        "0123456789012345678901234567890123456789",
        "--sha256",
        "9b3737096a1813f0580908da7a52fd6f04a5da9c5e207ccdf2c0483c2db47d96",
        "--size",
        "32",
        "--connections",
        "4",
        "--name",
        "stored:v1",
        "--config",
        "aesir.config.json",
    ]
    var pull_request = parse_pull_request(pull_args)
    if (
        pull_request.register_name != "stored:v1"
        or pull_request.config_path != "aesir.config.json"
        or pull_request.expected_size != 32
        or pull_request.connections != 4
    ):
        raise Error("registered pull syntax parsing mismatch")
    var unowned_pull_config_rejected = False
    try:
        _ = parse_pull_request(
            [
                "pull",
                "owner/repository",
                "model.gguf",
                "--config",
                "aesir.config.json",
            ]
        )
    except error:
        unowned_pull_config_rejected = "requires --name" in String(error)
    if not unowned_pull_config_rejected:
        raise Error("pull accepted a store config without registration intent")
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
    var mf_text = String(
        "FROM test.gguf\nPARAMETER temperature 0.7\nSYSTEM You are test."
    )
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
        raise Error(
            "deserialized store manifest name mismatch: got " + restored.name
        )
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

    var traversal_rejected = False
    try:
        store.create_model("../escape", mf_text)
    except:
        traversal_rejected = True
    if not traversal_rejected:
        raise Error("model identity accepted a path traversal reference")

    var corruption_rejected = False
    try:
        _ = deserialize_catalog("AESIR_MODEL_CATALOG_V2\nCOUNT:0")
    except:
        corruption_rejected = True
    if not corruption_rejected:
        raise Error("durable catalog accepted an unsupported version")

    var test_root = (
        String(".aesir-test-model-store-")
        + String(external_call["getpid", Int32]())
    )
    var root_bytes = _test_cstring(test_root)
    if external_call["access", Int32](root_bytes.unsafe_ptr(), 0) == 0:
        raise Error("refusing to reuse a pre-existing model-store test path")

    # The caller-approved cleanup scope begins only after absence is proven.
    var stored_digest = String("")
    try:
        var durable = DurableModelStore(test_root)
        if len(durable.list_models()) != 0:
            raise Error("absent durable store did not start empty")
        durable.create_model(
            "persisted:v1",
            mf_text + "\nSYSTEM ===MANIFEST=== delimiter-safe",
        )

        var restarted = DurableModelStore(test_root)
        var persisted = restarted.get_model("persisted:v1")
        if "===MANIFEST===" not in persisted.modelfile_content:
            raise Error("durable catalog corrupted delimiter-shaped content")
        restarted.copy_model("persisted:v1", "copied:stable")

        var copied_restart = DurableModelStore(test_root)
        if copied_restart.get_model("copied:stable").name != "copied":
            raise Error("durable catalog copy did not survive restart")
        copied_restart.remove_model("persisted:v1")

        var removed_restart = DurableModelStore(test_root)
        if len(removed_restart.list_models()) != 1:
            raise Error("durable catalog removal did not survive restart")
        _ = removed_restart.get_model("copied:stable")

        var source_path = test_root + "/source.bin"
        _write_test_blob(
            source_path, "content-addressed-model-fixture\n"
        )
        var blob = removed_restart.ingest_model(
            "blobbed:v1", mf_text, source_path
        )
        stored_digest = blob.digest
        if (
            blob.digest
            != "sha256:9b3737096a1813f0580908da7a52fd6f04a5da9c5e207ccdf2c0483c2db47d96"
            or blob.size_bytes != 32
            or not blob.created
        ):
            raise Error("content-addressed ingestion metadata mismatch")
        var verified = removed_restart.verify_model("blobbed:v1")
        if verified.digest != blob.digest or verified.size_bytes != 32:
            raise Error("stored model blob verification metadata mismatch")
        var deduplicated = removed_restart.ingest_model(
            "blobbed-copy:v1", mf_text, source_path
        )
        if deduplicated.digest != blob.digest or deduplicated.created:
            raise Error("content-addressed ingestion did not deduplicate bytes")
        var mismatch_source_path = test_root + "/mismatch.bin"
        _write_test_blob(
            mismatch_source_path, "unexpected-model-blob-fixture\n"
        )
        var expected_identity_rejected = False
        try:
            _ = removed_restart.ingest_model(
                "mismatch:v1",
                mf_text,
                mismatch_source_path,
                "sha256:0000000000000000000000000000000000000000000000000000000000000000",
                30,
            )
        except error:
            expected_identity_rejected = "expected digest and size" in String(error)
        if not expected_identity_rejected:
            raise Error("model ingestion accepted the wrong expected identity")
        try:
            _ = removed_restart.get_model("mismatch:v1")
            raise Error("failed expected-identity admission mutated the catalog")
        except error:
            if "not found" not in String(error):
                raise error
        var rolled_back_blob = _test_cstring(
            test_root
            + "/blobs/sha256/f7053e5cd10c37b04d2d6db8f17bc3ede0e4d6912adfc54994c2b38aadcc40b0"
        )
        if external_call["access", Int32](
            rolled_back_blob.unsafe_ptr(), 0
        ) == 0:
            raise Error("expected-identity failure leaked a new model blob")

        var orphan = removed_restart.ingest_model(
            "orphan:v1", mf_text, mismatch_source_path
        )
        if orphan.digest != (
            "sha256:f7053e5cd10c37b04d2d6db8f17bc3ede0e4d6912adfc54994c2b38aadcc40b0"
        ) or orphan.size_bytes != 30:
            raise Error("garbage-collection fixture identity mismatch")
        removed_restart.remove_model("orphan:v1")
        var unexpected_path = test_root + "/blobs/sha256/unexpected"
        _write_test_blob(unexpected_path, "do-not-delete-anything-yet")
        var unsafe_directory_rejected = False
        try:
            _ = removed_restart.garbage_collect()
        except error:
            unsafe_directory_rejected = "unexpected entry" in String(error)
        if not unsafe_directory_rejected:
            raise Error("model blob collection accepted an unknown entry")
        if external_call["access", Int32](rolled_back_blob.unsafe_ptr(), 0) != 0:
            raise Error("failed collection deleted a blob before validation")
        var unexpected_bytes = _test_cstring(unexpected_path)
        if external_call["unlink", Int32](unexpected_bytes.unsafe_ptr()) != 0:
            raise Error("unable to remove test-owned unexpected blob entry")
        var stale_stage_path = (
            test_root + "/blobs/sha256/.ingest.999.1.tmp"
        )
        _write_test_blob(stale_stage_path, "abandoned")
        var collected = removed_restart.garbage_collect()
        if (
            collected.scanned_blobs != 2
            or collected.referenced_blobs != 1
            or collected.removed_blobs != 1
            or collected.removed_stages != 1
            or collected.reclaimed_bytes != 30
        ):
            raise Error("model blob garbage-collection accounting mismatch")
        if external_call["access", Int32](rolled_back_blob.unsafe_ptr(), 0) == 0:
            raise Error("garbage collection retained an unreachable blob")
        var stale_stage_bytes = _test_cstring(stale_stage_path)
        if external_call["access", Int32](
            stale_stage_bytes.unsafe_ptr(), 0
        ) == 0:
            raise Error("garbage collection retained an abandoned stage")
        _ = removed_restart.verify_model("blobbed:v1")
        var blob_restart = DurableModelStore(test_root)
        var blob_manifest = blob_restart.get_model("blobbed:v1")
        if (
            blob_manifest.digest != blob.digest
            or blob_manifest.size_bytes != 32
        ):
            raise Error("measured blob metadata did not survive restart")

        var blob_path = (
            test_root + "/blobs/sha256/" + String(blob.digest[byte=7:])
        )
        var blob_path_bytes = _test_cstring(blob_path)
        if external_call["chmod", Int32](
            blob_path_bytes.unsafe_ptr(), Int32(384)
        ) != 0:
            raise Error("unable to unlock test-owned blob for corruption check")
        var corrupt_fd = external_call["open64", Int32](
            blob_path_bytes.unsafe_ptr(), Int32(655361), Int32(0)
        )
        if corrupt_fd < 0:
            raise Error("unable to open test-owned blob for corruption check")
        var corrupt_byte: List[Int8] = [Int8(88)]
        if external_call["pwrite", Int](
            corrupt_fd, corrupt_byte.unsafe_ptr(), 1, Int64(0)
        ) != 1:
            _ = external_call["close", Int32](corrupt_fd)
            raise Error("unable to inject test-owned blob corruption")
        _ = external_call["fsync", Int32](corrupt_fd)
        _ = external_call["close", Int32](corrupt_fd)
        var corruption_detected = False
        try:
            _ = blob_restart.verify_model("blobbed:v1")
        except error:
            corruption_detected = "SHA-256" in String(error)
        if not corruption_detected:
            raise Error("stored model blob corruption was not detected")
        if external_call["unlink", Int32](blob_path_bytes.unsafe_ptr()) != 0:
            raise Error("unable to remove test-owned blob for missing check")
        var missing_blob_detected = False
        try:
            _ = blob_restart.verify_model("blobbed-copy:v1")
        except error:
            missing_blob_detected = "missing" in String(error)
        if not missing_blob_detected:
            raise Error("missing content-addressed blob was not detected")
    except error:
        _cleanup_owned_model_store(test_root, stored_digest)
        raise error
    _cleanup_owned_model_store(test_root, stored_digest)

    print("validated manifests & restart-safe durable catalog: PASS")


def assert_cli_command_unsupported(command: String) raises:
    var args = List[String]()
    args.append(command)
    var rejected = False
    try:
        dispatch_command(args)
    except error:
        rejected = True
        var message = String(error)
        if (
            "not implemented" not in message
            and "unsupported" not in message
            and "requires a subcommand" not in message
            and "requires model repository tag" not in message
            and "Unknown" not in message
            and "unknown" not in message
        ):
            raise Error("unsupported CLI error omitted stable truth text")
    if not rejected:
        raise Error("unsupported CLI command returned successfully: " + command)


def assert_run_option_rejected(
    option: String, value: String = String(""), takes_value: Bool = False
) raises:
    """Proves an accepted-but-unconnected option cannot report run success."""
    var args = List[String]()
    args.append("run")
    args.append("model.gguf")
    args.append(option)
    if takes_value:
        args.append(value)
    args.append("hello")

    var options = parse_cli_options(args)
    var rejected = False
    try:
        validate_run_option_support(options)
    except error:
        rejected = True
        var message = String(error)
        if (
            "not implemented" not in message
            and "not connected" not in message
            and "applies to" not in message
        ):
            raise Error("run option rejection omitted stable truth text")
    if not rejected:
        raise Error("unconnected run option was accepted: " + option)


def assert_config_json_rejected(raw: String, label: String) raises:
    var rejected = False
    try:
        _ = parse_config_json(raw)
    except:
        rejected = True
    if not rejected:
        raise Error("configuration accepted " + label)


def test_cli_command_dispatch() raises:
    print("--- Testing operational CLI command dispatchers & boundaries ---")

    var store = RuneModelStore()

    var help_args = List[String]()
    help_args.append("help")
    dispatch_command(help_args, store)

    # Empty invocation is a stable help request rather than an implicit daemon.
    var empty_args = List[String]()
    dispatch_command(empty_args, store)

    # The documented config command must load and validate the tracked file.
    var config_args = List[String]()
    config_args.append("config")
    config_args.append("--config")
    config_args.append("aesir.config.json")
    dispatch_command(config_args, store)

    assert_cli_command_unsupported("ps")

    var bad_catalog_args: List[String] = ["list", "--unknown"]
    var bad_catalog_rejected = False
    try:
        dispatch_command(bad_catalog_args)
    except error:
        bad_catalog_rejected = "unknown catalog option" in String(error)
    if not bad_catalog_rejected:
        raise Error("catalog command accepted an unknown option")

    var missing_modelfile_args: List[String] = ["create", "demo"]
    var missing_modelfile_rejected = False
    try:
        dispatch_command(missing_modelfile_args)
    except error:
        missing_modelfile_rejected = "Usage: aesir create" in String(error)
    if not missing_modelfile_rejected:
        raise Error("create accepted a missing Modelfile")

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
            raise Error(
                "swarm bare command rejection omitted subcommand error text"
            )
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
            raise Error(
                "empty prompt run rejection omitted expected error text"
            )
    if not empty_prompt_rejected:
        raise Error("run command allowed empty prompt parameter")

    var pull_args: List[String] = ["pull"]
    var pull_rejected = False
    try:
        dispatch_command(pull_args)
    except error:
        pull_rejected = "pull requires repository and filename" in String(error)
    if not pull_rejected:
        raise Error("pull without explicit artifact identity must fail")
    assert_cli_command_unsupported("push")
    assert_cli_command_unsupported("stop")
    assert_cli_command_unsupported("swarm")

    print("operational CLI command dispatchers & boundaries: PASS")


def test_repl_session_and_slash_commands() raises:
    print(
        "--- Testing RuneREPL session state, slash commands & stream"
        " execution ---"
    )
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
        raise Error(
            "run_repl_stream output length mismatch: got "
            + String(len(outputs))
        )
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

    var history_before = len(repl.history)
    var model_chat_rejected = False
    try:
        _ = repl.process_input_line("Hello Aesir")
    except error:
        model_chat_rejected = "general model-backed REPL is unsupported" in String(error)
    if not model_chat_rejected:
        raise Error("legacy REPL fabricated a model-backed assistant reply")
    if len(repl.history) != history_before:
        raise Error("rejected legacy REPL input mutated conversation history")

    var bare_run_args: List[String] = ["run", "model.gguf"]
    var bare_run_rejected = False
    try:
        dispatch_command(bare_run_args)
    except error:
        bare_run_rejected = "interactive run is unsupported" in String(error)
    if not bare_run_rejected:
        raise Error("bare run entered the unsupported legacy REPL")

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
    print(
        "--- Testing CLIOptions flag parser, duration conversion & JSON"
        " output ---"
    )

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
        raise Error(
            "CLIOptions duration parsing mismatch: expected 600s, got "
            + String(options.keepalive_seconds)
        )
    if not options.raw:
        raise Error("CLIOptions raw flag not set")
    if not options.insecure:
        raise Error("CLIOptions insecure flag not set")
    if not options.verbose_was_set or not options.format_was_set:
        raise Error("CLIOptions did not record explicit output intent")
    if not options.keepalive_was_set:
        raise Error("CLIOptions did not record explicit keepalive intent")
    if not options.raw_was_set or not options.insecure_was_set:
        raise Error("CLIOptions did not record explicit mode intent")

    var explicit_args = List[String]()
    explicit_args.append("run")
    explicit_args.append("model.gguf")
    explicit_args.append("--config")
    explicit_args.append("aesir.config.json")
    explicit_args.append("--accel")
    explicit_args.append("cpu")
    explicit_args.append("hello")
    explicit_args.append("from")
    explicit_args.append("aesir")
    var explicit_options = parse_cli_options(explicit_args)
    if not explicit_options.config_was_set:
        raise Error("CLIOptions did not record explicit --config intent")
    if not explicit_options.accel_was_set:
        raise Error("CLIOptions did not record explicit --accel intent")

    var positionals = collect_run_positionals(explicit_args)
    if len(positionals) != 4:
        raise Error("run option tokens leaked into positional prompt assembly")
    if positionals[0] != "model.gguf":
        raise Error("run positional model path mismatch")
    if positionals[1] != "hello" or positionals[3] != "aesir":
        raise Error("run positional prompt order mismatch")

    var loaded = load_config_file("aesir.config.json")
    if loaded.config_path != "aesir.config.json":
        raise Error("configuration loader did not record its source path")
    if loaded.acceleration_backend != "auto":
        raise Error("tracked configuration acceleration intent mismatch")
    if loaded.model_store_path != ".aesir/models":
        raise Error("tracked configuration model-store path mismatch")

    if validate_model_store_path("private/models") != "private/models":
        raise Error("safe relative model-store path changed during validation")
    var unsafe_store_rejected = False
    try:
        _ = validate_model_store_path("../escape")
    except:
        unsafe_store_rejected = True
    if not unsafe_store_rejected:
        raise Error("model-store path accepted traversal")

    var invalid_config_rejected = False
    try:
        _ = parse_config_json('{\n  "max_threads": "many"\n}')
    except:
        invalid_config_rejected = True
    if not invalid_config_rejected:
        raise Error("configuration silently ignored an invalid integer")

    var compact = parse_config_json(
        '{"hard\\u0077are":{"acceleration_backend":"cuda",'
        + '"target_npu":"auto","num_gpu_layers":-1,"max_threads":4},'
        + '"safety":{"thinking_enabled":true},'
        + '"storage":{"model_store_path":"private/models"},'
        + '"sampling":{"temperature":7e-1,"top_p":0.95}}'
    )
    if (
        compact.acceleration_backend != "cuda"
        or compact.num_gpu_layers != -1
        or compact.max_threads != 4
        or not compact.thinking_enabled
        or compact.model_store_path != "private/models"
        or compact.temperature != 0.7
        or compact.top_p != 0.95
    ):
        raise Error("strict compact configuration values were not preserved")

    assert_config_json_rejected(
        '{"hardware":{"max_threads":1,}}', "an object trailing comma"
    )
    assert_config_json_rejected(
        '{"hardware":{},}', "a root trailing comma"
    )
    assert_config_json_rejected(
        '{"hardware":{} "sampling":{}}', "a missing root comma"
    )
    assert_config_json_rejected(
        '{"hardware":{},"hardware":{}}', "a duplicate section"
    )
    assert_config_json_rejected(
        '{"hardware":{"max_threads":1,"max_threads":2}}',
        "a duplicate field",
    )
    assert_config_json_rejected(
        '{"sampling":{"max_threads":1}}', "a field in the wrong section"
    )
    assert_config_json_rejected(
        '{"safety":{"thinking_enabled":"true"}}', "a quoted boolean"
    )
    assert_config_json_rejected(
        '{"hardware":{"max_threads":1.0}}', "a fractional integer"
    )
    assert_config_json_rejected(
        '{"hardware":{"max_threads":01}}', "a leading-zero number"
    )
    assert_config_json_rejected(
        '{"unknown":{}}', "an unknown section"
    )
    assert_config_json_rejected(
        '{"sampling":{"top_p":null}}', "a null numeric value"
    )
    assert_config_json_rejected(
        '{"sampling":{"top_p":0.5}} trailing', "trailing content"
    )
    assert_config_json_rejected(
        '{"stor\\uD800age":{}}', "an unpaired Unicode surrogate"
    )

    var effective = effective_config(explicit_options)
    if effective.acceleration_backend != "cpu":
        raise Error("explicit CLI acceleration did not override file intent")
    require_verified_cpu_backend(effective)
    validate_single_shot_config_support(effective)

    effective.temperature = 0.7
    var ignored_config_rejected = False
    try:
        validate_single_shot_config_support(effective)
    except error:
        ignored_config_rejected = True
        if "sampling config is not connected" not in String(error):
            raise Error("unconnected config rejection omitted truth boundary")
    if not ignored_config_rejected:
        raise Error("unconnected sampling config reached single-shot execution")
    effective.temperature = 0.0

    effective.acceleration_backend = String("cuda")
    var unsupported_backend_rejected = False
    try:
        require_verified_cpu_backend(effective)
    except error:
        unsupported_backend_rejected = True
        if "CPU-only" not in String(error):
            raise Error("unsupported backend rejection omitted truth boundary")
    if not unsupported_backend_rejected:
        raise Error("explicit unsupported accelerator reached CPU execution")

    var missing_config_rejected = False
    try:
        _ = load_config_file("does-not-exist-aesir.config.json")
    except error:
        missing_config_rejected = True
        if "unable to read configuration" not in String(error):
            raise Error("missing config rejection omitted contextual error")
    if not missing_config_rejected:
        raise Error("missing configuration file was accepted")

    # Every globally parsed option without a single-shot owner must fail before
    # model loading instead of being silently ignored.
    assert_run_option_rejected("--verbose")
    assert_run_option_rejected("--format", "json", True)
    assert_run_option_rejected("--keepalive", "5m", True)
    assert_run_option_rejected("--modelfile", "Modelfile", True)
    assert_run_option_rejected("--raw")
    assert_run_option_rejected("--insecure")
    assert_run_option_rejected("--skaldbrodir", "on", True)
    assert_run_option_rejected("--thinking", "off", True)
    assert_run_option_rejected("--cia", "on", True)
    assert_run_option_rejected("--wic", "on", True)
    assert_run_option_rejected("--nsfi", "on", True)
    assert_run_option_rejected("--tui")

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
        raise Error(
            "RuneChatTemplate format_chatml failed to reject empty message list"
        )

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
