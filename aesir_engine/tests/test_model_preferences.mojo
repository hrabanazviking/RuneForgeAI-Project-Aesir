"""Verification for model aliases, favorites, and selector ordering."""

from cli.manifest import ModelManifest
from cli.model_preferences import (
    DurableModelPreferences,
    ModelPreferences,
    deserialize_model_preferences,
    serialize_model_preferences,
)
from cli.model_selector import prioritize_favorite_models, render_model_selector
from std.ffi import external_call


def _preferences_test_cstring(value: String) -> List[Int8]:
    var result = List[Int8]()
    for byte in value.as_bytes():
        result.append(Int8(byte))
    result.append(0)
    return result^


def test_model_preferences_codec() raises:
    var preferences = ModelPreferences()
    preferences.set_alias("gemma", "gemma4-e2b:latest")
    preferences.set_alias("tiny", "qwen3:small")
    preferences.add_favorite("gemma4-e2b:latest")
    var raw = serialize_model_preferences(preferences)
    var restored = deserialize_model_preferences(raw)
    if (restored.resolve("gemma") != "gemma4-e2b:latest"
            or restored.resolve("tiny") != "qwen3:small"
            or restored.resolve("qwen3") != "qwen3:latest"):
        raise Error("model preference alias round trip drifted")
    if not restored.is_favorite("gemma4-e2b:latest"):
        raise Error("model preference favorite round trip drifted")
    var corruption_rejected = False
    try:
        _ = deserialize_model_preferences(raw.replace("CHECKSUM:", "CHECKSUM:0"))
    except:
        corruption_rejected = True
    if not corruption_rejected:
        raise Error("model preferences accepted a corrupted record")
    var unsafe_alias_rejected = False
    try:
        preferences.set_alias("../escape", "qwen3:latest")
    except:
        unsafe_alias_rejected = True
    if not unsafe_alias_rejected:
        raise Error("model preferences accepted a path-shaped alias")

    var root = (
        ".aesir-model-preferences-fifo-test-"
        + String(external_call["getpid", Int32]())
    )
    var current_directory = _preferences_test_cstring(".")
    var temporary_directory = _preferences_test_cstring("/tmp")
    var current_directory_fd = external_call["open64", Int32](
        current_directory.unsafe_ptr(), Int32(720896), Int32(0)
    )
    if current_directory_fd < 0:
        raise Error("unable to preserve working directory for FIFO test")
    if external_call["chdir", Int32](temporary_directory.unsafe_ptr()) != 0:
        _ = external_call["close", Int32](current_directory_fd)
        raise Error("unable to enter native temporary directory for FIFO test")
    var root_bytes = _preferences_test_cstring(root)
    var fifo_bytes = _preferences_test_cstring(root + "/preferences.v1")
    if external_call["access", Int32](root_bytes.unsafe_ptr(), 0) == 0:
        _ = external_call["fchdir", Int32](current_directory_fd)
        _ = external_call["close", Int32](current_directory_fd)
        raise Error("model preferences FIFO test path already exists")
    if external_call["mkdir", Int32](root_bytes.unsafe_ptr(), 448) != 0:
        _ = external_call["fchdir", Int32](current_directory_fd)
        _ = external_call["close", Int32](current_directory_fd)
        raise Error("unable to create model preferences FIFO test directory")
    if external_call["mkfifo", Int32](fifo_bytes.unsafe_ptr(), Int32(384)) != 0:
        _ = external_call["rmdir", Int32](root_bytes.unsafe_ptr())
        _ = external_call["fchdir", Int32](current_directory_fd)
        _ = external_call["close", Int32](current_directory_fd)
        raise Error("unable to create model preferences FIFO test fixture")
    var fifo_rejected = False
    try:
        _ = DurableModelPreferences(root).load()
    except error:
        fifo_rejected = "regular file" in String(error)
    var fifo_cleanup = external_call["unlink", Int32](fifo_bytes.unsafe_ptr())
    var root_cleanup = external_call["rmdir", Int32](root_bytes.unsafe_ptr())
    var directory_restore = external_call["fchdir", Int32](current_directory_fd)
    _ = external_call["close", Int32](current_directory_fd)
    if fifo_cleanup != 0 or root_cleanup != 0 or directory_restore != 0:
        raise Error("unable to remove model preferences FIFO test fixture")
    if not fifo_rejected:
        raise Error("model preferences loader accepted a FIFO")
    print("model preference codec and validation: PASS")


def test_model_favorite_selection() raises:
    var models = List[ModelManifest]()
    models.append(ModelManifest("gemma", "latest", "", 1024, "Q4_K_M"))
    models.append(ModelManifest("qwen", "q6", "", 2048, "Q6_K"))
    models.append(ModelManifest("llama", "chat", "", 4096, "Q4_K_M"))
    var preferences = ModelPreferences()
    preferences.add_favorite("qwen:q6")
    var ordered = prioritize_favorite_models(models, preferences)
    if (ordered[0].name != "qwen" or ordered[1].name != "gemma"
            or ordered[2].name != "llama"):
        raise Error("favorite-first selection did not preserve stable catalog order")
    var frame = render_model_selector(ordered, preferences)
    if "★ qwen:q6" not in frame:
        raise Error("favorite model is not visibly marked in the selector")
    print("favorite-first model selection: PASS")


def main() raises:
    test_model_preferences_codec()
    test_model_favorite_selection()
