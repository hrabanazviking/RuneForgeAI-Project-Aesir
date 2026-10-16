"""S33a model-browser pagination and optional real-PTY interaction harness."""

from std.sys import argv
from cli.manifest import ModelManifest
from cli.model_preferences import ModelPreferences
from cli.model_selector import (
    prompt_installed_model, render_model_selector_page,
    selected_model_reference,
)


def browser_fixture() -> List[ModelManifest]:
    var models = List[ModelManifest]()
    for index in range(12):
        models.append(ModelManifest(
            "a-very-long-but-valid-model-name-for-narrow-terminal-" + String(index),
            "latest", "", 1024, "Q4_K_M",
        ))
    return models^


def main() raises:
    var models = browser_fixture()
    var preferences = ModelPreferences()
    preferences.add_favorite(models[0].name + ":latest")
    var arguments = argv()
    if len(arguments) == 2 and String(arguments[1]) == "--interactive":
        try:
            print("SELECTED=" + prompt_installed_model(models, preferences, -1))
        except error:
            print("CANCELLED=" + String(error))
        return
    var first = render_model_selector_page(models, preferences, 0, 24)
    var second = render_model_selector_page(models, preferences, 1, 80)
    if ("Models 1/2" not in first or "1* " not in first
            or "..." not in first or "11" in first
            or "Installed models 11-12/12" not in second
            or selected_model_reference(models, "12") != models[11].name + ":latest"):
        raise Error("paged browser identity/order/default marker drifted")
    for line in first.split("\n"):
        if String(line).byte_length() > 24:
            raise Error("24-column model browser overflowed")
    for line in second.split("\n"):
        if String(line).byte_length() > 80:
            raise Error("80-column model browser overflowed")
    var rejected = False
    try:
        _ = render_model_selector_page(models, preferences, 2, 80)
    except:
        rejected = True
    if not rejected:
        raise Error("model browser accepted an impossible page")
    var hostile = List[ModelManifest]()
    hostile.append(ModelManifest("safe", "latest", "", 1024, "Q4\tBAD"))
    var safe_frame = render_model_selector_page(hostile, preferences, 0, 80)
    if "\t" in safe_frame or "BAD" in safe_frame or "unavailable" not in safe_frame:
        raise Error("model browser rendered unsafe catalog metadata")
    print("model browser unit: PASS")
