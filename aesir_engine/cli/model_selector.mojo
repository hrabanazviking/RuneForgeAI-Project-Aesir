"""Installed-model selector for path-free native chat startup."""
from cli.manifest import ModelManifest
from cli.storage import DurableModelStore
from cli.model_preferences import ModelPreferences, DurableModelPreferences
from cli.interrupts import read_interruptible_line_result
from std.collections import InlineArray
from std.ffi import external_call


comptime MODEL_PAGE_SIZE = 10


def browser_quantization_label(value: String) -> String:
    """Untrusted catalog metadata must not emit terminal controls."""
    if value == "unknown":
        return "auto-detect"
    var raw = value.as_bytes()
    if len(raw) == 0 or len(raw) > 32:
        return "unavailable"
    for byte in raw:
        var code = Int(byte)
        if not ((code >= 48 and code <= 57)
                or (code >= 65 and code <= 90)
                or (code >= 97 and code <= 122)
                or code == 45 or code == 46 or code == 95):
            return "unavailable"
    return value


def model_selector_columns() -> Int:
    """Reads the current PTY width; a non-PTY caller gets an 80-column view."""
    var window = InlineArray[UInt16, 4](fill=0)
    if external_call["ioctl", Int32](Int32(1), UInt64(21523), window.unsafe_ptr()) != 0:
        return 80
    var columns = Int(window[1])
    if columns < 24:
        return 24
    if columns > 240:
        return 240
    return columns


def render_model_selector_page(
    models: List[ModelManifest], preferences: ModelPreferences,
    page: Int, columns: Int,
) raises -> String:
    """One bounded page. Numeric IDs remain stable across page and resize."""
    if len(models) == 0:
        raise Error("No installed models; use aesir pull --name or aesir create --model")
    if columns < 24 or columns > 240:
        raise Error("Model browser width must be 24..240 columns")
    var page_count = (len(models) + MODEL_PAGE_SIZE - 1) // MODEL_PAGE_SIZE
    if page < 0 or page >= page_count:
        raise Error("Model browser page is outside the installed list")
    var first = page * MODEL_PAGE_SIZE
    var last = first + MODEL_PAGE_SIZE
    if last > len(models):
        last = len(models)
    var frame = String("Models " + String(page + 1) + "/" + String(page_count) + "\n")
    if columns >= 60:
        frame = String("Installed models " + String(first + 1) + "-" + String(last)
                       + "/" + String(len(models)) + " (page " + String(page + 1)
                       + "/" + String(page_count) + ")\n")
    for index in range(first, last):
        var model = models[index]
        var identity = model.name + ":" + model.tag
        var favorite = preferences.is_favorite(identity)
        var prefix = String(("> " if index == 0 else "  ") + String(index + 1)
                            + ("* " if favorite else "  "))
        var quantization = browser_quantization_label(model.quantization)
        var detail = String("  " + quantization + "  " + model.size_formatted())
        if prefix.byte_length() + identity.byte_length() + detail.byte_length() > columns:
            detail = ""
        var remaining = columns - prefix.byte_length() - detail.byte_length()
        if identity.byte_length() > remaining:
            # Catalog name/tag components are ASCII by validation. The stable
            # number identifies even two names with the same visible prefix.
            identity = String(identity[byte=0:remaining - 3]) + "..."
        frame += prefix + identity + detail + "\n"
    if columns < 40:
        frame += "n/p | ? | # | Enter | q\n"
    elif columns < 70:
        frame += "n/p pages | ? help | # select | q cancel\n"
    else:
        frame += "n next | p previous | ? help | number select | Enter first | q cancel\n"
    return frame


def installed_model_choices(models: List[ModelManifest]) -> List[ModelManifest]:
    """Filters recipes; actual blob verification still occurs during resolution."""
    var installed = List[ModelManifest]()
    for model in models:
        if model.digest.startswith("sha256:"):
            installed.append(model)
    return installed^


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
        installed_model_choices(DurableModelStore(model_store).list_models()), preferences
    )
    return prompt_installed_model(models, preferences, interrupt_fd)


def prompt_installed_model(
    models: List[ModelManifest], preferences: ModelPreferences,
    interrupt_fd: Int,
) raises -> String:
    if len(models) == 0:
        raise Error("No installed models; use aesir pull --name or aesir create --model")
    var page = 0
    var page_count = (len(models) + MODEL_PAGE_SIZE - 1) // MODEL_PAGE_SIZE
    while True:
        print(render_model_selector_page(
            models, preferences, page, model_selector_columns()
        ), end="")
        var default_number = page * MODEL_PAGE_SIZE + 1
        print("Select model [" + String(default_number) + "]: ", end="")
        var input = read_interruptible_line_result(interrupt_fd)
        if input.interrupted or input.eof:
            raise Error("Model selection cancelled")
        var choice = String(input.text.strip())
        if choice == "":
            return selected_model_reference(models, String(default_number))
        if choice == "q":
            raise Error("Model selection cancelled")
        if choice == "n":
            if page + 1 < page_count:
                page += 1
            else:
                print("Last page.")
            continue
        if choice == "p":
            if page > 0:
                page -= 1
            else:
                print("First page.")
            continue
        if choice == "?":
            if model_selector_columns() < 70:
                print("IDs stable; * favorite.")
                print("Use aesir show for info.")
            else:
                print("Model numbers remain stable across pages. * marks a favorite.")
                print("Use aesir show <name:tag> for complete metadata; selection loads the model.")
            continue
        try:
            return selected_model_reference(models, choice)
        except error:
            if model_selector_columns() < 40:
                print("Invalid choice; use ?")
            else:
                print("Selection rejected: " + String(error))
