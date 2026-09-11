"""Installed-model selector for path-free native chat startup."""
from cli.manifest import ModelManifest
from cli.storage import DurableModelStore
from cli.model_preferences import ModelPreferences, DurableModelPreferences
from cli.interrupts import read_interruptible_line_result


def prioritize_favorite_models(
    models: List[ModelManifest], preferences: ModelPreferences
) -> List[ModelManifest]:
    """Returns a stable favorite-first view without mutating catalog order."""
    var ordered = List[ModelManifest]()
    for model in models:
        if preferences.is_favorite(model.name + ":" + model.tag):
            ordered.append(model)
    for model in models:
        if not preferences.is_favorite(model.name + ":" + model.tag):
            ordered.append(model)
    return ordered^


def render_model_selector(
    models: List[ModelManifest], preferences: ModelPreferences = ModelPreferences()
) raises -> String:
    if len(models) == 0:
        raise Error("No installed models; use aesir pull --name or aesir create --model")
    var frame = String("┌──────────────── PROJECT A.E.S.I.R. ────────────────┐\n")
    frame += "│ Installed models                                    │\n"
    frame += "├─────────────────────────────────────────────────────┤\n"
    for index in range(len(models)):
        var model = models[index]
        var quantization = (
            "auto-detect" if model.quantization == "unknown"
            else model.quantization
        )
        frame += (
            "│ " + ("> " if index == 0 else "  ") + String(index + 1) + ". "
            + ("★ " if preferences.is_favorite(model.name + ":" + model.tag) else "  ")
            + model.name + ":" + model.tag + "   " + quantization
            + "   " + model.size_formatted() + "\n"
        )
    frame += "└─────────────────────────────────────────────────────┘\n"
    return frame


def selected_model_reference(models: List[ModelManifest], choice: String) raises -> String:
    if len(models) == 0:
        raise Error("No installed models; use aesir pull --name or aesir create --model")
    var clean = String(choice.strip())
    var selected = 1
    if clean != "":
        selected = 0
        for byte in clean.as_bytes():
            if byte < 48 or byte > 57:
                raise Error("Model selection must be a listed number")
            var digit = Int(byte - 48)
            if selected > (2147483647 - digit) // 10:
                raise Error("Model selection exceeds the supported range")
            selected = selected * 10 + digit
    if selected < 1 or selected > len(models):
        raise Error("Model selection is outside the installed list")
    var model = models[selected - 1]
    return model.name + ":" + model.tag


def choose_installed_model(model_store: String, interrupt_fd: Int) raises -> String:
    var preferences = DurableModelPreferences(model_store).load()
    var models = prioritize_favorite_models(
        DurableModelStore(model_store).list_models(), preferences
    )
    print(render_model_selector(models, preferences), end="")
    print("Select model [1]: ", end="")
    var input = read_interruptible_line_result(interrupt_fd)
    if input.interrupted:
        raise Error("Model selection cancelled")
    if input.eof and input.text == "":
        raise Error("Model selection requires a choice or blank Enter")
    return selected_model_reference(models, input.text)
