"""Verification for model aliases, favorites, and selector ordering."""

from cli.manifest import ModelManifest
from cli.model_preferences import (
    ModelPreferences,
    deserialize_model_preferences,
    serialize_model_preferences,
)
from cli.model_selector import prioritize_favorite_models, render_model_selector


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
