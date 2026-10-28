"""CLI surface for mmproj (vision projector) structure reporting.

``aesir vision inspect <model>`` resolves the language model, discovers the
mmproj GGUF beside it, parses and validates the vision tower inventory, and
cross-checks the projector output width against the language model's
embedding length. This reports structure only: it does not claim the model
can see. Vision inference is tracked in docs/VISION_MMPROJ_DEVELOPMENT.md.
"""
from loader.mmproj import MmprojFile, find_mmproj_beside
from loader.packed_gguf import PackedGGUF
from cli.model_reference import resolve_model_reference


def dispatch_vision(args: List[String]) raises:
    """Parses and executes `aesir vision inspect <model>`."""
    if len(args) < 2 or args[1] != "inspect":
        raise Error("Usage: aesir vision inspect <model> [--model-store path]")
    var model_path = String("")
    var model_store = String(".aesir/models")
    var seen_model_store = False
    var index = 2
    while index < len(args):
        var token = args[index]
        if token == "--model-store":
            if seen_model_store or index + 1 >= len(args):
                raise Error("vision inspect requires one value for --model-store")
            seen_model_store = True
            model_store = args[index + 1]
            index += 2
            continue
        if token.startswith("-"):
            raise Error("unknown vision inspect option: " + token)
        if model_path != "":
            raise Error("vision inspect accepts exactly one model reference")
        model_path = token
        index += 1
    if model_path == "":
        raise Error("Usage: aesir vision inspect <model> [--model-store path]")

    var resolved = resolve_model_reference(model_path, model_store)
    print("model: " + resolved.path)
    var mmproj_path = find_mmproj_beside(resolved.path)
    if mmproj_path == "":
        print("mmproj: none found beside the model — this model is text-only")
        return
    var mmproj = MmprojFile(mmproj_path)
    var spec = mmproj.vision_spec()
    print(mmproj.describe(spec), end="")
    if not spec.present:
        return
    var language = PackedGGUF(resolved.path)
    var architecture = language.text("general.architecture")
    var language_hidden = language.integer(architecture + ".embedding_length")
    spec.check_language_match(language_hidden)
    print(
        "language model: " + architecture + ", embedding_length "
        + String(language_hidden) + " — projector output matches"
    )
