"""Installed-model selector for path-free native chat startup."""
from cli.manifest import ModelManifest, validate_model_component
from cli.storage import DurableModelStore
from cli.model_preferences import ModelPreferences, DurableModelPreferences
from cli.interrupts import read_interruptible_line_result
from cli.terminal_view import terminal_columns
from core.native_diagnostics import human_bytes
from loader.huggingface import HuggingFaceSeer
from cli.known_models import known_models_dataset


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
    return terminal_columns()


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


# ---------------------------------------------------------------------------
# J-102: the known-models picker (installed + catalogue, fetch before run)
#
# The catalogue interface lives here, beside the picker that consumes it.
# J-103 owns the curated in-repo catalogue dataset and lands it behind
# known_model_catalogue()'s shape; this slice owns the entry shape, the
# merge, the render, the selection, the fetch/verify decision rule, and
# the fetch integration through the existing pull machinery
# (download_hf_model + DurableModelStore.ingest_model -- the same two
# calls cli/commands.mojo dispatch_pull makes after parsing). No second
# catalogue store is invented: installed rows still come from the one
# durable catalog, and registered fetches land in that same catalog.
# ---------------------------------------------------------------------------


struct KnownModelEntry(Copyable, ImplicitlyCopyable):
    """One known-models catalogue entry: identity plus pull's exact pins."""

    var name: String
    var tag: String
    var repository: String
    var filename: String
    var revision: String
    var sha256: String
    var size_bytes: Int64
    var quantization: String

    def __init__(
        out self,
        name: String,
        tag: String = String("latest"),
        repository: String = String(""),
        filename: String = String(""),
        revision: String = String(""),
        sha256: String = String(""),
        size_bytes: Int64 = 0,
        quantization: String = String("unknown"),
    ):
        self.name = name
        self.tag = tag
        self.repository = repository
        self.filename = filename
        self.revision = revision
        self.sha256 = sha256
        self.size_bytes = size_bytes
        self.quantization = quantization

    def __copyinit__(out self, existing: Self):
        self.name = existing.name
        self.tag = existing.tag
        self.repository = existing.repository
        self.filename = existing.filename
        self.revision = existing.revision
        self.sha256 = existing.sha256
        self.size_bytes = existing.size_bytes
        self.quantization = existing.quantization

    @always_inline
    def copy(self) -> Self:
        return Self(
            self.name,
            self.tag,
            self.repository,
            self.filename,
            self.revision,
            self.sha256,
            self.size_bytes,
            self.quantization,
        )

    def reference(self) -> String:
        return self.name + ":" + self.tag


def _validate_lower_hex(value: String, width: Int, label: String) raises:
    if len(value.bytes()) != width:
        raise Error("known model " + label + " must be " + String(width) + " lowercase hex characters")
    for byte in value.as_bytes():
        if not ((byte >= 48 and byte <= 57) or (byte >= 97 and byte <= 102)):
            raise Error("known model " + label + " must be lowercase hexadecimal")


def validate_known_model_entry(entry: KnownModelEntry) raises:
    """Mirrors the pin rules the pull machinery itself enforces."""
    validate_model_component(entry.name, "name")
    validate_model_component(entry.tag, "tag")
    var repo_parts = entry.repository.split("/")
    if len(repo_parts) != 2:
        raise Error("known model repository must be owner/name")
    validate_model_component(String(repo_parts[0]), "repository owner")
    validate_model_component(String(repo_parts[1]), "repository name")
    if not entry.filename.endswith(".gguf"):
        raise Error("known model filename must be a .gguf file")
    if "/" in entry.filename or "\\" in entry.filename:
        raise Error("known model filename must not contain a path separator")
    validate_model_component(
        String(entry.filename[byte=0:len(entry.filename.bytes()) - 5]), "filename"
    )
    _validate_lower_hex(entry.revision, 40, "revision")
    _validate_lower_hex(entry.sha256, 64, "sha256")
    if entry.size_bytes < 24:
        raise Error("known model size must include a GGUF v3 header (>= 24 bytes)")


def known_model_catalogue() -> List[KnownModelEntry]:
    """The known-models catalogue interface.

    J-102 defined the shape and the contract and returned an honest
    empty list. J-103 lands the curated in-repo dataset behind this
    same function and shape: the provider delegates to the dataset
    module (cli/known_models.mojo), whose entries each carry a real,
    citable pin provenance (J-103 doc sections 0.2-0.3). No entry is
    constructed anywhere else, and no pin is invented.
    """
    return known_models_dataset()


struct PickerEntry(Copyable, ImplicitlyCopyable):
    """One combined picker row: an installed model or a fetchable entry."""

    var name: String
    var tag: String
    var quantization: String
    var size_bytes: Int64
    var installed: Bool
    var known: KnownModelEntry

    def __init__(
        out self,
        name: String,
        tag: String,
        quantization: String,
        size_bytes: Int64,
        installed: Bool,
        known: KnownModelEntry,
    ):
        self.name = name
        self.tag = tag
        self.quantization = quantization
        self.size_bytes = size_bytes
        self.installed = installed
        self.known = known

    def __copyinit__(out self, existing: Self):
        self.name = existing.name
        self.tag = existing.tag
        self.quantization = existing.quantization
        self.size_bytes = existing.size_bytes
        self.installed = existing.installed
        self.known = existing.known.copy()

    @always_inline
    def copy(self) -> Self:
        return Self(
            self.name,
            self.tag,
            self.quantization,
            self.size_bytes,
            self.installed,
            self.known.copy(),
        )

    def reference(self) -> String:
        return self.name + ":" + self.tag

    def size_formatted(self) -> String:
        return human_bytes(Int(self.size_bytes))


def picker_entries(
    installed: List[ModelManifest], catalogue: List[KnownModelEntry]
) -> List[PickerEntry]:
    """Installed first, in their given order; catalogue entries whose
    reference is already installed are not duplicated as fetchable."""
    var entries = List[PickerEntry]()
    for model in installed:
        entries.append(PickerEntry(
            model.name, model.tag, model.quantization, model.size_bytes,
            True, KnownModelEntry(model.name, model.tag),
        ))
    for known in catalogue:
        var already = False
        for model in installed:
            if known.reference() == model.name + ":" + model.tag:
                already = True
        if not already:
            entries.append(PickerEntry(
                known.name, known.tag, known.quantization, known.size_bytes,
                False, known.copy(),
            ))
    return entries^



def render_model_picker_page(
    entries: List[PickerEntry], preferences: ModelPreferences,
    page: Int, columns: Int,
) raises -> String:
    """One bounded page over installed + fetchable rows. Fetchable rows
    carry a `fetch` marker in their detail; numbers are stable across
    page and resize, exactly as in the installed-only page."""
    if len(entries) == 0:
        raise Error("No installed models; use aesir pull --name or aesir create --model")
    if columns < 24 or columns > 240:
        raise Error("Model browser width must be 24..240 columns")
    var page_count = (len(entries) + MODEL_PAGE_SIZE - 1) // MODEL_PAGE_SIZE
    if page < 0 or page >= page_count:
        raise Error("Model browser page is outside the picker list")
    var first = page * MODEL_PAGE_SIZE
    var last = first + MODEL_PAGE_SIZE
    if last > len(entries):
        last = len(entries)
    var frame = String("Models " + String(page + 1) + "/" + String(page_count) + "\n")
    if columns >= 60:
        frame = String("Installed + known models " + String(first + 1) + "-" + String(last)
                       + "/" + String(len(entries)) + " (page " + String(page + 1)
                       + "/" + String(page_count) + ")\n")
    for index in range(first, last):
        var entry = entries[index]
        var identity = entry.reference()
        var favorite = preferences.is_favorite(identity)
        var prefix = String(("> " if index == 0 else "  ") + String(index + 1)
                            + ("* " if favorite else "  "))
        var quantization = browser_quantization_label(entry.quantization)
        var detail = String("  " + quantization + "  " + entry.size_formatted())
        if not entry.installed:
            detail = String("  fetch  " + quantization + "  " + entry.size_formatted())
        if prefix.byte_length() + identity.byte_length() + detail.byte_length() > columns:
            detail = ""
        var remaining = columns - prefix.byte_length() - detail.byte_length()
        if identity.byte_length() > remaining:
            identity = String(identity[byte=0:remaining - 3]) + "..."
        frame += prefix + identity + detail + "\n"
    if columns < 40:
        frame += "n/p | ? | # | Enter | q\n"
    elif columns < 70:
        frame += "n/p pages | ? help | # select | q cancel\n"
    else:
        frame += "n next | p previous | ? help | number select | Enter first | q cancel\n"
    return frame


def selected_picker_entry(entries: List[PickerEntry], choice: String) raises -> PickerEntry:
    if len(entries) == 0:
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
    if selected < 1 or selected > len(entries):
        raise Error("Model selection is outside the picker list")
    return entries[selected - 1].copy()


struct FirstRunDecision(Copyable, ImplicitlyCopyable):
    """The fetch/verify decision for one picker selection (J-102 §0.3)."""

    var action: String
    var reference: String
    var reason: String

    def __init__(out self, action: String, reference: String, reason: String):
        self.action = action
        self.reference = reference
        self.reason = reason

    def __copyinit__(out self, existing: Self):
        self.action = existing.action
        self.reference = existing.reference
        self.reason = existing.reason

    @always_inline
    def copy(self) -> Self:
        return Self(self.action, self.reference, self.reason)


def first_run_decision(
    entry: PickerEntry, fetch_attempted: Bool,
    observed_digest: String, observed_size: Int64,
) -> FirstRunDecision:
    """The one door to a first run: installed runs; a fetchable entry
    runs only after its fetched bytes match the catalogue pin exactly;
    anything else fetched is refused, with the failed pin named."""
    if entry.installed:
        return FirstRunDecision(
            "run", entry.reference(),
            "installed in the durable catalog",
        )
    if not fetch_attempted:
        return FirstRunDecision(
            "fetch", entry.reference(),
            "not installed; fetch through pull before first run",
        )
    if observed_digest == "":
        return FirstRunDecision(
            "refused", entry.reference(),
            "fetch produced no verified bytes; first run refused",
        )
    if observed_digest != "sha256:" + entry.known.sha256:
        return FirstRunDecision(
            "refused", entry.reference(),
            "digest mismatch: fetched bytes do not match the catalogue sha256 pin; first run refused",
        )
    if observed_size != entry.known.size_bytes:
        return FirstRunDecision(
            "refused", entry.reference(),
            "size mismatch: fetched bytes do not match the catalogue size pin; first run refused",
        )
    return FirstRunDecision(
        "run", entry.reference(),
        "fetched bytes verified against the catalogue pin",
    )


def pull_args_for_entry(entry: KnownModelEntry) -> List[String]:
    """The exact argv dispatch_pull parses for this entry's fetch."""
    var args = List[String]()
    args.append("pull")
    args.append(entry.repository)
    args.append(entry.filename)
    args.append("--revision")
    args.append(entry.revision)
    args.append("--sha256")
    args.append(entry.sha256)
    args.append("--size")
    args.append(String(entry.size_bytes))
    args.append("--name")
    args.append(entry.reference())
    return args^


def fetch_known_model(
    entry: KnownModelEntry, model_store: String, destination: String
) raises -> FirstRunDecision:
    """Fetches one catalogue entry through the pull machinery -- the
    same two calls dispatch_pull makes after parsing: download_hf_model
    (publishes only after size, header and SHA-256 checks) and then
    ingest_model (re-measures the bytes and refuses registration unless
    the measured digest and size equal the pin). The post-fetch decision
    re-checks the measured record against the pin before any run."""
    validate_known_model_entry(entry)
    var seer = HuggingFaceSeer()
    _ = seer.download_hf_model(
        entry.repository,
        entry.filename,
        destination,
        entry.revision,
        entry.sha256,
        Int(entry.size_bytes),
        1,
    )
    var durable = DurableModelStore(model_store)
    var record = durable.ingest_model(
        entry.reference(),
        "FROM \"sha256:" + entry.sha256 + "\"",
        destination,
        "sha256:" + entry.sha256,
        entry.size_bytes,
    )
    var picker_entry = PickerEntry(
        entry.name, entry.tag, entry.quantization, entry.size_bytes,
        False, entry.copy(),
    )
    return first_run_decision(
        picker_entry, True, record.digest, record.size_bytes
    )


def find_known_model(reference: String) raises -> KnownModelEntry:
    """The catalogue entry for one `name:tag` reference (J-103).

    Raises naming the known references when the catalogue has no such
    entry -- `get` never falls back to treating its argument as a
    repository or a path.
    """
    var catalogue = known_model_catalogue()
    for entry in catalogue:
        if entry.reference() == reference:
            return entry.copy()
    var known = String("")
    for entry in catalogue:
        if len(known.bytes()) > 0:
            known += ", "
        known += entry.reference()
    raise Error(
        "unknown catalogue model: " + reference
        + " (known: " + known + ")"
    )


def get_decision(entry: KnownModelEntry, installed: Bool) -> FirstRunDecision:
    """The standalone `get` decision for one catalogue entry (J-103):
    J-102's first_run_decision, applied without the picker -- an
    already-installed entry runs (no fetch); a fetchable entry
    fetches through pull before it is usable."""
    var picker_entry = PickerEntry(
        entry.name, entry.tag, entry.quantization, entry.size_bytes,
        installed, entry.copy(),
    )
    return first_run_decision(picker_entry, False, "", 0)


def get_known_model(reference: String, model_store: String) raises -> String:
    """The standalone `get` behaviour (J-103): fetch one catalogue
    entry and checksum-verify it before it is usable, through the
    same pull machinery and decision rule as the picker fetch.

    An entry already in the durable catalog returns at once (no
    fetch). Otherwise the fetch runs through fetch_known_model
    (download_hf_model, which publishes only after size + header +
    SHA-256 checks, then ingest_model, which re-measures and refuses
    registration on any mismatch); the post-fetch decision must
    resolve RUN, or this raises with the refusal reason and no model
    is registered or returned.
    """
    var entry = find_known_model(reference)
    var installed = installed_model_choices(
        DurableModelStore(model_store).list_models()
    )
    var already = False
    for model in installed:
        if model.name + ":" + model.tag == entry.reference():
            already = True
    var decision = get_decision(entry, already)
    if decision.action == "run":
        return decision.reference
    if decision.action == "fetch":
        var destination = model_store + "/" + entry.filename
        var after = fetch_known_model(entry, model_store, destination)
        if after.action == "run":
            return after.reference
        raise Error(after.reason)
    raise Error(decision.reason)


def prompt_model_picker(
    entries: List[PickerEntry], preferences: ModelPreferences,
    interrupt_fd: Int,
) raises -> PickerEntry:
    if len(entries) == 0:
        raise Error("No installed models; use aesir pull --name or aesir create --model")
    var page = 0
    var page_count = (len(entries) + MODEL_PAGE_SIZE - 1) // MODEL_PAGE_SIZE
    while True:
        print(render_model_picker_page(
            entries, preferences, page, model_selector_columns()
        ), end="")
        var default_number = page * MODEL_PAGE_SIZE + 1
        print("Select model [" + String(default_number) + "]: ", end="")
        var input = read_interruptible_line_result(interrupt_fd)
        if input.interrupted or input.eof:
            raise Error("Model selection cancelled")
        var choice = String(input.text.strip())
        if choice == "":
            return selected_picker_entry(entries, String(default_number))
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
                print("IDs stable; * favorite; fetch = download first.")
            else:
                print("Model numbers remain stable across pages. * marks a favorite.")
                print("Rows marked fetch are known models: selecting one downloads and verifies it before first run.")
            continue
        try:
            return selected_picker_entry(entries, choice)
        except error:
            if model_selector_columns() < 40:
                print("Invalid choice; use ?")
            else:
                print("Selection rejected: " + String(error))


def choose_model(model_store: String, interrupt_fd: Int) raises -> String:
    """Chat's picker: installed models plus the known-models catalogue.
    A fetchable selection is fetched and checksum-verified through the
    pull machinery before its reference is returned for first run; a
    mismatch raises with the reason and loads nothing."""
    var preferences = DurableModelPreferences(model_store).load()
    var installed = prioritize_favorite_models(
        installed_model_choices(DurableModelStore(model_store).list_models()), preferences
    )
    var entries = picker_entries(installed, known_model_catalogue())
    if len(entries) == 0:
        raise Error("No installed models; use aesir pull --name or aesir create --model")
    var entry = prompt_model_picker(entries, preferences, interrupt_fd)
    var decision = first_run_decision(entry, False, "", 0)
    if decision.action == "run":
        return decision.reference
    if decision.action == "fetch":
        var known = entry.known.copy()
        print(
            "Fetching " + entry.reference() + " from " + known.repository
            + " (pinned sha256 " + known.sha256 + ") before first run..."
        )
        var destination = model_store + "/" + known.filename
        var after = fetch_known_model(known, model_store, destination)
        if after.action == "run":
            print("Verified " + after.reference + "; starting chat.")
            return after.reference
        raise Error(after.reason)
    raise Error(decision.reason)
