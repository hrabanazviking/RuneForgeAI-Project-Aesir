#!/usr/bin/env python3
"""Deterministic self-tests for repository artifact prevention rules."""

from __future__ import annotations

from check_doc_drift import (
    ArtifactViolation,
    LegacyException,
    TrackedArtifact,
    check_policy_baseline,
    classify_artifact,
    evaluate_artifact_policy,
    load_hygiene_policy,
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


def test_live_policy_schema_and_baseline() -> None:
    errors: list[str] = []
    exceptions = load_hygiene_policy(errors)
    require(not errors, "live hygiene policy failed schema validation")
    require(len(exceptions) == 32, "legacy exception inventory count drifted")
    check_policy_baseline(exceptions, errors)
    require(not errors, "legacy exception was absent from the pinned baseline")


def main() -> None:
    test_artifact_classification()
    test_policy_evaluation()
    test_policy_schema_rejection()
    test_todo_status_references()
    test_live_policy_schema_and_baseline()


if __name__ == "__main__":
    main()
