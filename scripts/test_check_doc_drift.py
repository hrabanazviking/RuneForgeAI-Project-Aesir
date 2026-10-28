#!/usr/bin/env python3
"""Deterministic self-tests for repository artifact prevention rules."""

from __future__ import annotations

from check_doc_drift import (
    ArtifactViolation,
    LegacyException,
    TrackedArtifact,
    active_status_document_errors,
    check_policy_baseline,
    classify_artifact,
    evaluate_artifact_policy,
    ledger_schema_errors,
    load_hygiene_policy,
    status_reference_errors,
    todo_status_reference_errors,
    validate_hygiene_policy,
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def test_artifact_classification() -> None:
    cases = [
        (
            TrackedArtifact("new-tool", "", 4096, b"\x7fELF"),
            "generated_executable",
        ),
        (
            TrackedArtifact("fake.gguf", ".gguf", 24, b"GGUF"),
            "placeholder_model",
        ),
        (
            TrackedArtifact("weights.gguf", ".gguf", 4096, b"GGUF"),
            "model_weight",
        ),
        (
            TrackedArtifact("output.o", ".o", 64, b"data"),
            "generated_build_artifact",
        ),
        (
            TrackedArtifact("bundle.zip", ".zip", 64, b"PK\x03\x04"),
            "generated_archive",
        ),
        (
            TrackedArtifact("runtime.db", ".db", 64, b"data"),
            "runtime_state",
        ),
        (
            TrackedArtifact("private.pem", ".pem", 64, b"---"),
            "secret_material",
        ),
        (
            TrackedArtifact("copy.png", ".png", 64, b"\x89PNG", "same"),
            "duplicate_root_asset",
        ),
    ]
    for artifact, expected in cases:
        violation = classify_artifact(artifact, {"same"})
        require(violation is not None, f"classification missing for {artifact.path}")
        require(
            violation.classification == expected,
            f"classification mismatch for {artifact.path}",
        )

    clean = TrackedArtifact("source.mojo", ".mojo", 64, b"from")
    require(
        classify_artifact(clean, set()) is None,
        "ordinary source file was classified as an artifact",
    )


def test_policy_evaluation() -> None:
    violation = ArtifactViolation(
        "legacy-tool",
        "generated_executable",
        "tracked file contains executable binary magic",
    )
    exception = LegacyException(
        "legacy-tool",
        "generated_executable",
        "deletion_requires_approval",
        "legacy",
        "0" * 40,
    )

    errors, warnings = evaluate_artifact_policy(
        [violation], {}, {"legacy-tool"}, False
    )
    require(bool(errors), "unlisted artifact did not fail policy evaluation")
    require(not warnings, "unlisted artifact emitted a warning instead of failure")

    errors, warnings = evaluate_artifact_policy(
        [violation], {"legacy-tool": exception}, {"legacy-tool"}, False
    )
    require(not errors, "matching legacy artifact unexpectedly failed")
    require(bool(warnings), "matching legacy artifact did not remain visible")

    errors, warnings = evaluate_artifact_policy(
        [violation], {"legacy-tool": exception}, {"legacy-tool"}, True
    )
    require(bool(errors), "verified hygiene accepted a legacy artifact")
    require(not warnings, "verified hygiene downgraded legacy debt to warning")

    mismatch = LegacyException(
        "legacy-tool",
        "placeholder_model",
        "deletion_requires_approval",
        "legacy",
        "0" * 40,
    )
    errors, _ = evaluate_artifact_policy(
        [violation], {"legacy-tool": mismatch}, {"legacy-tool"}, False
    )
    require(bool(errors), "classification mismatch did not fail closed")

    errors, warnings = evaluate_artifact_policy([], {}, set(), False)
    require(not errors and not warnings, "clean inventory did not remain clean")

    errors, _ = evaluate_artifact_policy(
        [], {"legacy-tool": exception}, {"legacy-tool"}, False
    )
    require(bool(errors), "exception hiding no violation did not fail closed")

    errors, _ = evaluate_artifact_policy(
        [violation], {"legacy-tool": exception}, set(), False
    )
    require(bool(errors), "untracked policy exception did not fail closed")


def test_policy_schema_rejection() -> None:
    malformed_policies = [
        [],
        {"policy_version": 1},
        {
            "policy_version": True,
            "legacy_baseline_commit": "0" * 40,
            "legacy_classes": [],
        },
        {
            "policy_version": 1,
            "legacy_baseline_commit": "not-a-commit",
            "legacy_classes": [],
        },
        {
            "policy_version": 1,
            "legacy_baseline_commit": "0" * 40,
            "legacy_classes": [
                {
                    "classification": "model_weight",
                    "disposition": "approved",
                    "reason": "must not become an allowlist",
                    "paths": ["new.gguf"],
                }
            ],
        },
    ]
    for index, policy in enumerate(malformed_policies):
        errors: list[str] = []
        validate_hygiene_policy(policy, errors)
        require(bool(errors), f"malformed policy {index} did not fail validation")


def test_todo_status_references() -> None:
    statuses = {"AES-FND-001": "verified", "AES-FND-002": "partial"}
    clean = "- [x] **[verified, AES-FND-001] Complete narrow task.**"
    require(
        not todo_status_reference_errors(clean, statuses),
        "matching TODO status reference was rejected",
    )
    cases = [
        "- [ ] **[missing, AES-FND-002] Stale status.**",
        "- [ ] **[partial, AES-FND-999] Unknown capability.**",
        "- [ ] **[finished, AES-FND-001] Unsupported status.**",
    ]
    for index, content in enumerate(cases):
        require(
            bool(todo_status_reference_errors(content, statuses)),
            f"invalid TODO status reference {index} did not fail",
        )


def test_active_status_document_boundary() -> None:
    statuses = {"AES-FND-001": "verified", "AES-FND-002": "partial"}
    marker = "<!-- HISTORICAL_CLAIMS_BEGIN -->"
    clean = (
        "Current: `[verified, AES-FND-001]`.\n"
        + marker
        + "\nHistorical: `[missing, AES-FND-001]`."
    )
    require(
        not active_status_document_errors(clean, statuses, "Vision.md"),
        "historical status claim escaped its boundary",
    )
    cases = [
        "Current: `[verified, AES-FND-001]`.",
        "Current: `[missing, AES-FND-001]`.\n" + marker,
        "Current: AES-FND-001 is verified.\n" + marker,
        "Current: `[partial, AES-FND-999]`.\n" + marker,
    ]
    for index, content in enumerate(cases):
        require(
            bool(active_status_document_errors(content, statuses, "Vision.md")),
            f"invalid active vision boundary {index} did not fail",
        )


def test_live_policy_schema_and_baseline() -> None:
    errors: list[str] = []
    exceptions = load_hygiene_policy(errors)
    require(not errors, "live hygiene policy failed schema validation")
    require(len(exceptions) == 34, "legacy exception inventory count drifted")
    check_policy_baseline(exceptions, errors)
    require(not errors, "legacy exception was absent from the pinned baseline")


def test_explicit_cuda_ci_target() -> None:
    from check_doc_drift import has_mojo_ci_gate
    source = "aesir_engine/tests/run_all.mojo"
    for command in [f"pixi run mojo run {source}", f"pixi run mojo run --target-accelerator sm_89 {source}", f"pixi run mojo run --target-accelerator=sm_89 {source}"]:
        require(has_mojo_ci_gate(command, "run", source), "real Mojo test gate was not recognized")
    for command in [f"# pixi run mojo run {source}", "pixi run mojo run --target-accelerator sm_89 wrong.mojo", f"pixi run mojo build {source}", f"pixi run mojo run {source}.disabled"]:
        require(not has_mojo_ci_gate(command, "run", source), "missing/commented/wrong Mojo gate was accepted")


def test_ledger_schema_integration() -> None:
    valid = (
        "### AES-FND-001 — Example\n"
        "- **Status:** `verified`\n"
        "- **Owner:** foundation\n"
        "- **Executable evidence:** `python3 check.py`\n"
        "- **Evidence boundary:** Structural fixture only.\n"
    )
    require(not ledger_schema_errors(valid, "fixture.md"), "valid ledger schema failed integration")
    malformed = valid.replace("- **Owner:** foundation", "- **Ownr:** foundation")
    errors = ledger_schema_errors(malformed, "fixture.md")
    require(
        errors == [
            "fixture.md schema: fixture.md:1: missing required field 'Owner'"
        ],
        f"schema integration diagnostics were unstable: {errors!r}",
    )


def test_absolute_path_evidence_exemption() -> None:
    from check_doc_drift import absolute_path_errors

    # Assembled from pieces: this test file is itself scanned by the rule,
    # so the probe path must not appear as one literal string here.
    probe = "ran on " + "/" + "home" + "/operator/work today"
    require(
        absolute_path_errors("docs/handbook.md", probe)
        == ["docs/handbook.md:1: machine-local absolute path"],
        "absolute path in a hand-authored file was not flagged",
    )
    require(
        absolute_path_errors("docs/evidence/run-1/record.json", probe) == [],
        "generated evidence record was flagged despite the exemption",
    )
    require(
        absolute_path_errors("docs/evidence/deep/nested/run.txt", probe) == [],
        "nested generated evidence record was flagged despite the exemption",
    )
    require(
        absolute_path_errors("docs/evidence.md", probe)
        == ["docs/evidence.md:1: machine-local absolute path"],
        "file merely named like the evidence directory was exempted",
    )
    require(
        absolute_path_errors("evidence/run-1/record.json", probe)
        == ["evidence/run-1/record.json:1: machine-local absolute path"],
        "evidence directory outside docs/ was exempted",
    )
    require(
        not absolute_path_errors("docs/handbook.md", "no local paths here"),
        "clean hand-authored line was flagged",
    )


def test_grandfathered_record_heading() -> None:
    from check_doc_drift import ledger_statuses

    valid = (
        "### AES-FND-001 — Example\n"
        "- **Status:** `partial`\n"
        "- **Owner:** foundation\n"
        "- **Executable evidence:** `python3 check.py`\n"
        "- **Evidence boundary:** Structural fixture only.\n"
    )
    record = (
        "\n### AES-C3-REVIEW — Campaign verdict (fixture)\n"
        "- **Status:** `verified`\n"
        "- **Status:** `verified, gate PASS`\n"
        "Verdict prose with no capability fields.\n"
    )
    require(
        not ledger_schema_errors(valid + record, "fixture.md"),
        "grandfathered record block was schema-validated as a capability",
    )
    unregistered = valid + record.replace("AES-C3-REVIEW", "AES-X9-REVIEW")
    errors = ledger_schema_errors(unregistered, "fixture.md")
    require(
        any("malformed capability heading" in error for error in errors),
        "unregistered non-canonical heading was not flagged as malformed",
    )
    statuses = ledger_statuses(valid + record)
    require(
        statuses == {"AES-FND-001": "partial"},
        "record Status lines bled into the preceding capability block",
    )


def test_todo_combined_and_adjacent_capability_references() -> None:
    statuses = {
        "AES-TST-001": "verified",
        "AES-TST-002": "partial",
    }
    content = (
        "[verified, AES-TST-001; AER-002] "
        "[partial, AES-TST-002]"
    )
    require(
        not status_reference_errors(content, statuses, "TODO.md"),
        "valid combined audit and adjacent capability tags were rejected",
    )


def test_todo_later_unknown_and_mismatched_references() -> None:
    statuses = {"AES-TST-001": "verified", "AES-TST-002": "partial"}
    unknown = "[verified, AES-TST-001; AER-002; AES-TST-999]"
    require(
        status_reference_errors(unknown, statuses, "TODO.md") == [
            "TODO.md:1: unknown capability reference AES-TST-999"
        ],
        "unknown later AES reference was hidden by a valid earlier reference",
    )
    mismatch = "[verified, AES-TST-001; AES-TST-002]"
    require(
        status_reference_errors(mismatch, statuses, "TODO.md") == [
            "TODO.md:1: AES-TST-002 tag is verified, ledger is partial"
        ],
        "mismatched later AES reference was not diagnosed",
    )


def test_todo_adjacent_unknown_and_mismatch_diagnostic_order() -> None:
    statuses = {"AES-TST-001": "verified", "AES-TST-002": "partial"}
    content = (
        "[verified, AES-TST-999] [verified, AES-TST-002] "
        "[partial, AES-TST-002]"
    )
    require(
        status_reference_errors(content, statuses, "TODO.md") == [
            "TODO.md:1: unknown capability reference AES-TST-999",
            "TODO.md:1: AES-TST-002 tag is verified, ledger is partial",
        ],
        "adjacent tag diagnostics were not emitted in source order",
    )


def test_todo_unsupported_status_and_ordinary_brackets() -> None:
    statuses = {"AES-TST-001": "verified"}
    content = (
        "[finished, AES-TST-001] [verified, AES-TST-001] "
        "[verified, ordinary words] [note: AES-TST-001]"
    )
    require(
        status_reference_errors(content, statuses, "TODO.md") == [
            "TODO.md:1: unsupported status tag 'finished'"
        ],
        "unsupported tag or unrelated brackets did not follow the contract",
    )


def test_todo_repository_integration_against_canonical_ledger() -> None:
    from check_doc_drift import LEDGER, TODO, ledger_statuses

    statuses = ledger_statuses(LEDGER.read_text(encoding="utf-8"))
    todo = TODO.read_text(encoding="utf-8")
    require(len(statuses) == 324, "canonical ledger status map changed unexpectedly")
    require(
        not todo_status_reference_errors(todo, statuses),
        "repository TODO contains a reference inconsistent with the canonical ledger",
    )


def test_todo_adversarial_repeated_and_high_cardinality_references() -> None:
    statuses = {"AES-TST-001": "verified"}
    repeated = "[verified, AES-TST-999; AES-TST-999]"
    errors = status_reference_errors(repeated, statuses, "TODO.md")
    require(
        errors == [
            "TODO.md:1: unknown capability reference AES-TST-999",
            "TODO.md:1: unknown capability reference AES-TST-999",
        ],
        "repeated unknown IDs were collapsed or reordered",
    )

    many_ids = "; ".join(f"AES-TST-{index:03}" for index in range(100, 164))
    errors = status_reference_errors(
        f"heading\n[verified, {many_ids}]", statuses, "TODO.md"
    )
    require(len(errors) == 64, "high-cardinality references were truncated")
    require(errors[0] == "TODO.md:2: unknown capability reference AES-TST-100", "first ID order changed")
    require(errors[-1] == "TODO.md:2: unknown capability reference AES-TST-163", "last ID order changed")
def main() -> None:
    test_artifact_classification()
    test_policy_evaluation()
    test_policy_schema_rejection()
    test_todo_status_references()
    test_active_status_document_boundary()
    test_live_policy_schema_and_baseline()
    test_explicit_cuda_ci_target()
    test_ledger_schema_integration()
    test_absolute_path_evidence_exemption()
    test_grandfathered_record_heading()
    test_todo_combined_and_adjacent_capability_references()
    test_todo_later_unknown_and_mismatched_references()
    test_todo_adjacent_unknown_and_mismatch_diagnostic_order()
    test_todo_unsupported_status_and_ordinary_brackets()
    test_todo_repository_integration_against_canonical_ledger()
    test_todo_adversarial_repeated_and_high_cardinality_references()


if __name__ == "__main__":
    main()
