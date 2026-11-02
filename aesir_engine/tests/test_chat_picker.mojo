"""Chat picker (J-102): the known-models catalogue interface
(zero entries today -- the honest state, J-103 lands the curated
dataset behind the same shape), entry pin validation, the
installed + fetchable merge (installed first, already-installed
catalogue entries deduped), the combined render (fetchable rows
marked `fetch`), numeric selection over the combined list, the
fetch/verify first-run decision rule (installed runs; fetchable
runs only on an exact pin match; mismatch refused with the failed
pin named), the pull argv the fetch is parameterised by, and the
installed-only regression (empty catalogue == today's picker).

Fixture entries only: no network, no download, no model bytes.
The live fetch leg is J-102's deferred leg (doc section 5).
"""
from cli.manifest import ModelManifest
from cli.model_preferences import ModelPreferences
from cli.model_selector import (
    KnownModelEntry,
    PickerEntry,
    first_run_decision,
    installed_model_choices,
    known_model_catalogue,
    picker_entries,
    pull_args_for_entry,
    render_model_picker_page,
    selected_model_reference,
    selected_picker_entry,
    validate_known_model_entry,
)


comptime FIXTURE_REVISION = "0123456789abcdef0123456789abcdef01234567"
comptime FIXTURE_SHA256 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("ChatPicker " + what + ": expected true")


def expect_eq_str(actual: String, expected: String, what: String) raises:
    if actual != expected:
        raise Error(
            "ChatPicker " + what + ": expected '" + expected
            + "', got '" + actual + "'"
        )


def fixture_known() -> KnownModelEntry:
    return KnownModelEntry(
        "smol-fixture", "q4", "fixture-org/fixture-repo",
        "smol-fixture-q4.gguf", FIXTURE_REVISION, FIXTURE_SHA256,
        4096, "Q4_K_M",
    )


def fixture_installed() -> List[ModelManifest]:
    var models = List[ModelManifest]()
    models.append(ModelManifest(
        "alpha-local", "latest", "sha256:" + FIXTURE_SHA256, 2048, "Q8_0",
    ))
    return models^


def refused_entry(entry: KnownModelEntry) -> Bool:
    try:
        validate_known_model_entry(entry)
        return False
    except:
        return True


def test_entry_validation() raises:
    validate_known_model_entry(fixture_known())
    var bad_revision = fixture_known()
    bad_revision.revision = "main"
    expect_true(refused_entry(bad_revision), "non-hex revision refused")
    var bad_sha = fixture_known()
    bad_sha.sha256 = "ABCD"
    expect_true(refused_entry(bad_sha), "short/uppercase sha256 refused")
    var small = fixture_known()
    small.size_bytes = 10
    expect_true(refused_entry(small), "undersized entry refused")
    var not_gguf = fixture_known()
    not_gguf.filename = "model.bin"
    expect_true(refused_entry(not_gguf), "non-gguf filename refused")
    var bad_repo = fixture_known()
    bad_repo.repository = "no-slash-here"
    expect_true(refused_entry(bad_repo), "malformed repository refused")
    print("PASS: entry validation (pins mirror pull's rules)")


def test_catalogue_interface() raises:
    var catalogue = known_model_catalogue()
    if len(catalogue) != 0:
        raise Error("ChatPicker catalogue: expected zero entries today")
    print("PASS: catalogue interface (zero entries today; J-103 lands the data)")


def test_picker_merge() raises:
    var installed = fixture_installed()
    var catalogue = List[KnownModelEntry]()
    catalogue.append(fixture_known())
    var duplicate = KnownModelEntry(
        "alpha-local", "latest", "fixture-org/other-repo",
        "alpha-local.gguf", FIXTURE_REVISION, FIXTURE_SHA256, 2048, "Q8_0",
    )
    catalogue.append(duplicate)
    var entries = picker_entries(installed, catalogue)
    if len(entries) != 2:
        raise Error("ChatPicker merge: expected 2 entries, got " + String(len(entries)))
    expect_true(entries[0].installed, "installed row first and flagged installed")
    expect_eq_str(entries[0].reference(), "alpha-local:latest", "installed reference")
    expect_true(not entries[1].installed, "catalogue row flagged fetchable")
    expect_eq_str(entries[1].reference(), "smol-fixture:q4", "fetchable reference")
    expect_eq_str(entries[1].known.sha256, FIXTURE_SHA256, "fetchable row carries the sha256 pin")
    expect_eq_str(entries[1].known.revision, FIXTURE_REVISION, "fetchable row carries the revision pin")
    print("PASS: picker merge (installed first, deduped, pins carried)")


def test_picker_render() raises:
    var entries = picker_entries(fixture_installed(), [fixture_known()])
    var preferences = ModelPreferences()
    var frame = render_model_picker_page(entries, preferences, 0, 80)
    expect_true("Installed + known models 1-2/2" in frame, "combined header")
    var saw_installed_clean = False
    var saw_fetchable_marked = False
    for line in frame.split("\n"):
        var text = String(line)
        if "alpha-local:latest" in text and "fetch" not in text:
            saw_installed_clean = True
        if "smol-fixture:q4" in text and "fetch" in text:
            saw_fetchable_marked = True
    expect_true(saw_installed_clean, "installed row carries no fetch marker")
    expect_true(saw_fetchable_marked, "fetchable row carries the fetch marker")
    var refused = False
    try:
        _ = render_model_picker_page(entries, preferences, 1, 80)
    except:
        refused = True
    expect_true(refused, "page outside the combined list refused")
    print("PASS: picker render (fetchable distinguished, pages bounded)")


def test_picker_selection() raises:
    var entries = picker_entries(fixture_installed(), [fixture_known()])
    var first = selected_picker_entry(entries, "")
    expect_true(first.installed, "empty choice selects the first (installed) row")
    var second = selected_picker_entry(entries, "2")
    expect_true(not second.installed, "choice 2 selects the fetchable row")
    expect_eq_str(second.reference(), "smol-fixture:q4", "choice 2 reference")
    var refused = False
    try:
        _ = selected_picker_entry(entries, "3")
    except:
        refused = True
    expect_true(refused, "out-of-range choice refused")
    refused = False
    try:
        _ = selected_picker_entry(entries, "x")
    except:
        refused = True
    expect_true(refused, "non-numeric choice refused")
    print("PASS: picker selection (stable numbers over the combined list)")


def test_first_run_decision() raises:
    var entries = picker_entries(fixture_installed(), [fixture_known()])
    var installed_decision = first_run_decision(entries[0], False, "", 0)
    expect_eq_str(installed_decision.action, "run", "installed runs")
    var fetchable = entries[1].copy()
    var fetch_decision = first_run_decision(fetchable, False, "", 0)
    expect_eq_str(fetch_decision.action, "fetch", "unfetched fetchable fetches first")
    var verified = first_run_decision(
        fetchable, True, "sha256:" + FIXTURE_SHA256, 4096
    )
    expect_eq_str(verified.action, "run", "pin-matching fetch runs")
    var digest_mismatch = first_run_decision(
        fetchable, True,
        "sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
        4096,
    )
    expect_eq_str(digest_mismatch.action, "refused", "digest mismatch refused")
    expect_true("digest mismatch" in digest_mismatch.reason, "refusal names the digest pin")
    var size_mismatch = first_run_decision(
        fetchable, True, "sha256:" + FIXTURE_SHA256, 4095
    )
    expect_eq_str(size_mismatch.action, "refused", "size mismatch refused")
    expect_true("size mismatch" in size_mismatch.reason, "refusal names the size pin")
    var no_bytes = first_run_decision(fetchable, True, "", 0)
    expect_eq_str(no_bytes.action, "refused", "attempted fetch with no verified bytes refused")
    print("PASS: first-run decision (run / fetch / refused, pins named)")


def test_pull_args_and_regression() raises:
    var args = pull_args_for_entry(fixture_known())
    var expected = [
        "pull", "fixture-org/fixture-repo", "smol-fixture-q4.gguf",
        "--revision", FIXTURE_REVISION,
        "--sha256", FIXTURE_SHA256,
        "--size", "4096",
        "--name", "smol-fixture:q4",
    ]
    if len(args) != len(expected):
        raise Error("ChatPicker pull argv: wrong length")
    for index in range(len(expected)):
        expect_eq_str(args[index], expected[index], "pull argv element " + String(index))
    var mixed = List[ModelManifest]()
    mixed.append(ModelManifest(
        "alpha-local", "latest", "sha256:" + FIXTURE_SHA256, 2048, "Q8_0",
    ))
    mixed.append(ModelManifest(
        "recipe-only", "latest", "fnv1a64:0123456789abcdef", 0, "unknown",
    ))
    var installed_only = installed_model_choices(mixed)
    if len(installed_only) != 1:
        raise Error("ChatPicker regression: installed filter changed")
    var entries = picker_entries(installed_only, known_model_catalogue())
    if len(entries) != 1 or not entries[0].installed:
        raise Error("ChatPicker regression: empty catalogue must equal the installed list")
    expect_eq_str(
        selected_model_reference(installed_only, "1"), "alpha-local:latest",
        "pre-existing selector behaviour intact",
    )
    print("PASS: pull argv (dispatch_pull grammar) + installed-only regression")


def main() raises:
    test_entry_validation()
    test_catalogue_interface()
    test_picker_merge()
    test_picker_render()
    test_picker_selection()
    test_first_run_decision()
    test_pull_args_and_regression()
    print("ALL PASS: chat picker (7 groups)")
