"""Model getting (J-103): the curated in-repo catalogue dataset
behind known_model_catalogue() -- every entry pin-valid, references
unique, and each entry's fields asserted against the provenance
constants carried here from the filed sources (J-015 sections 1
and 7; J-022 section 5 via J-032 section 3; revisions from the
Hugging Face API HEAD per repo, tree cross-checked 2026-11-01) --
the catalogue lookup by reference (known found with its pins,
unknown refused naming the known references), the standalone get
decision over the real entries (fetchable fetches; installed runs
with no fetch), the get argv surface in cli/commands (parse without
I/O: known/unknown references, --config, unknown and duplicate
options refused), and the refusal leg bound to a real entry's
identity (digest mismatch, size mismatch, and attempted-with-no-
bytes each REFUSED through J-102's first_run_decision).

No network, no download, no model bytes: the live get leg is
J-103's deferred leg (doc section 5), re-cited at the J-118 gate.
"""
from cli.commands import parse_get_request
from cli.model_selector import (
    KnownModelEntry,
    PickerEntry,
    find_known_model,
    first_run_decision,
    get_decision,
    known_model_catalogue,
    validate_known_model_entry,
)


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("ModelGet " + what + ": expected true")


def expect_eq_str(actual: String, expected: String, what: String) raises:
    if actual != expected:
        raise Error(
            "ModelGet " + what + ": expected '" + expected
            + "', got '" + actual + "'"
        )


def expect_eq_int(actual: Int64, expected: Int64, what: String) raises:
    if actual != expected:
        raise Error(
            "ModelGet " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_entry(
    entry: KnownModelEntry, name: String, tag: String, repository: String,
    filename: String, revision: String, sha256: String, size_bytes: Int64,
    quantization: String,
) raises:
    var what = name + ":" + tag
    expect_eq_str(entry.name, name, what + " name")
    expect_eq_str(entry.tag, tag, what + " tag")
    expect_eq_str(entry.repository, repository, what + " repository")
    expect_eq_str(entry.filename, filename, what + " filename")
    expect_eq_str(entry.revision, revision, what + " revision")
    expect_eq_str(entry.sha256, sha256, what + " sha256")
    expect_eq_int(entry.size_bytes, size_bytes, what + " size")
    expect_eq_str(entry.quantization, quantization, what + " quantization")


def test_dataset_provenance() raises:
    var catalogue = known_model_catalogue()
    if len(catalogue) != 5:
        raise Error(
            "ModelGet dataset: expected 5 entries, got " + String(len(catalogue))
        )
    for entry in catalogue:
        validate_known_model_entry(entry)
    for i in range(len(catalogue)):
        for j in range(i + 1, len(catalogue)):
            if catalogue[i].reference() == catalogue[j].reference():
                raise Error("ModelGet dataset: duplicate reference")
    # Field-for-field provenance (J-103 doc section 2): a silent
    # data edit to any pin, size, or source fails here.
    expect_entry(
        catalogue[0], "olmoe-1b-7b", "q4_k_m",
        "allenai/OLMoE-1B-7B-0924-Instruct-GGUF",
        "olmoe-1b-7b-0924-instruct-q4_k_m.gguf",
        "02ab6ea6894a8418eb14f6d8ee1bfb08bd298080",
        "8c310f1435a1222338fd2d3d974975be9cd908180b644bab0c2a94da1ac32f3f",
        4213512672, "Q4_K_M",
    )
    expect_entry(
        catalogue[1], "granite-3.1-3b-a800m", "q4_k_m",
        "bartowski/granite-3.1-3b-a800m-instruct-GGUF",
        "granite-3.1-3b-a800m-instruct-Q4_K_M.gguf",
        "be9a36f042806cb586bc65556c527079782b78e0",
        "48e0edcd578fd4462f26127f04c651d0e650741110185297741089aea01a82b3",
        2016888384, "Q4_K_M",
    )
    expect_entry(
        catalogue[2], "qwen1.5-moe-a2.7b-chat", "q2_k",
        "tensorblock/Qwen1.5-MoE-A2.7B-Chat-GGUF",
        "Qwen1.5-MoE-A2.7B-Chat-Q2_K.gguf",
        "2b36b746552a7c99c814ee43120f318391e608c5",
        "cce008140714bb8b76185c0e2db802c60ce62182fa2eddb86ac53303b7525986",
        5890164032, "Q2_K",
    )
    expect_entry(
        catalogue[3], "olmoe-1b-7b", "q2_k",
        "bartowski/OLMoE-1B-7B-0924-Instruct-GGUF",
        "OLMoE-1B-7B-0924-Instruct-Q2_K.gguf",
        "7448e4317d367a3d6838fe367fe996758da6fc6e",
        "0b6554d40b4ae1ed84c20f0411b7869c10da264e826b8f185758cfd02e782b33",
        2562763584, "Q2_K",
    )
    expect_entry(
        catalogue[4], "qwen3-next-80b-a3b", "q4_k_m",
        "unsloth/Qwen3-Next-80B-A3B-Instruct-GGUF",
        "Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf",
        "6688872b7a4e5eb8a121ceea08009530a024ba1d",
        "f73551b55e3796526c37772c96227151fa11af328802b8f9865d635104e280fd",
        48506100512, "Q4_K_M",
    )
    print("PASS: dataset provenance (5 entries, pins field-for-field, all valid)")


def test_lookup() raises:
    var entry = find_known_model("granite-3.1-3b-a800m:q4_k_m")
    expect_eq_str(
        entry.sha256,
        "48e0edcd578fd4462f26127f04c651d0e650741110185297741089aea01a82b3",
        "lookup returns the entry's sha256 pin",
    )
    expect_eq_str(
        entry.repository, "bartowski/granite-3.1-3b-a800m-instruct-GGUF",
        "lookup returns the entry's source repository",
    )
    var refused = False
    try:
        _ = find_known_model("no-such-model:q4_k_m")
    except:
        refused = True
    expect_true(refused, "unknown reference refused by lookup")
    print("PASS: catalogue lookup (known found with pins; unknown refused)")


def test_get_decision() raises:
    var entry = find_known_model("olmoe-1b-7b:q4_k_m")
    var fetch_first = get_decision(entry, False)
    expect_eq_str(fetch_first.action, "fetch", "fetchable entry fetches first")
    expect_eq_str(
        fetch_first.reference, "olmoe-1b-7b:q4_k_m", "decision names the reference"
    )
    var installed = get_decision(entry, True)
    expect_eq_str(installed.action, "run", "installed entry runs with no fetch")
    print("PASS: get decision (fetchable -> fetch; installed -> run)")


def test_get_parse() raises:
    var plain = parse_get_request(["get", "olmoe-1b-7b:q4_k_m"])
    expect_eq_str(plain.reference, "olmoe-1b-7b:q4_k_m", "bare reference parsed")
    var defaulted = parse_get_request(["get", "olmoe-1b-7b"])
    expect_eq_str(
        defaulted.reference, "olmoe-1b-7b:latest",
        "reference normalised with the default tag",
    )
    var with_config = parse_get_request(
        ["get", "olmoe-1b-7b:q2_k", "--config", "conf.toml"]
    )
    expect_eq_str(with_config.config_path, "conf.toml", "--config parsed")
    var refused = False
    try:
        _ = parse_get_request(["get", "olmoe-1b-7b:q4_k_m", "--bogus", "x"])
    except:
        refused = True
    expect_true(refused, "unknown get option refused")
    refused = False
    try:
        _ = parse_get_request(
            ["get", "olmoe-1b-7b:q4_k_m", "--config", "a", "--config", "b"]
        )
    except:
        refused = True
    expect_true(refused, "duplicate get option refused")
    refused = False
    try:
        _ = parse_get_request(["get"])
    except:
        refused = True
    expect_true(refused, "missing reference refused")
    print("PASS: get parse (reference + --config; unknown/duplicate/missing refused)")


def test_refusal_leg() raises:
    # The refusal cases bind to a REAL entry's identity and pins, and
    # resolve through J-102's first_run_decision -- the one rule.
    var entry = find_known_model("olmoe-1b-7b:q4_k_m")
    var row = PickerEntry(
        entry.name, entry.tag, entry.quantization, entry.size_bytes,
        False, entry.copy(),
    )
    var verified = first_run_decision(
        row, True, "sha256:" + entry.sha256, entry.size_bytes
    )
    expect_eq_str(verified.action, "run", "pin-matching fetch of a real entry runs")
    var digest_mismatch = first_run_decision(
        row, True,
        "sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
        entry.size_bytes,
    )
    expect_eq_str(digest_mismatch.action, "refused", "digest mismatch refused")
    expect_true(
        "digest mismatch" in digest_mismatch.reason, "refusal names the digest pin"
    )
    var size_mismatch = first_run_decision(
        row, True, "sha256:" + entry.sha256, entry.size_bytes - 1
    )
    expect_eq_str(size_mismatch.action, "refused", "size mismatch refused")
    expect_true(
        "size mismatch" in size_mismatch.reason, "refusal names the size pin"
    )
    var no_bytes = first_run_decision(row, True, "", 0)
    expect_eq_str(
        no_bytes.action, "refused", "attempted fetch with no verified bytes refused"
    )
    print("PASS: refusal leg (digest / size / no-bytes refused, pins named)")


def main() raises:
    test_dataset_provenance()
    test_lookup()
    test_get_decision()
    test_get_parse()
    test_refusal_leg()
    print("ALL PASS: model getting (5 groups)")
