#!/usr/bin/env python3
"""Deterministic self-tests for fixture manifest admission rules."""

from __future__ import annotations

from copy import deepcopy

from check_fixture_manifest import FileFact, validate_fixture_manifest


CONSUMER = "aesir_engine/tests/test_subject.mojo"
PATH = "aesir_engine/tests/fixtures/subject-v1.json"
SHA256 = "a" * 64


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def tracked_fixture() -> dict[str, object]:
    return {
        "id": "subject.synthetic-v1",
        "classification": "synthetic",
        "storage": "tracked",
        "owner": "tests",
        "purpose": "Exercise one local parser invariant.",
        "consumer": CONSUMER,
        "evidence_boundary": "Synthetic bytes prove only the local parser rule.",
        "license": "CC0-1.0",
        "path": PATH,
        "size_bytes": 7,
        "sha256": SHA256,
        "construction": {
            "method": "Write the canonical seven-byte JSON value.",
            "tool": "manual",
            "version": "1",
        },
    }


def manifest(entry: dict[str, object]) -> dict[str, object]:
    return {
        "manifest_version": 1,
        "classifications": [
            "synthetic",
            "malformed",
            "regression",
            "external-reference",
        ],
        "fixtures": [entry],
    }


def validate(entry: dict[str, object]) -> list[str]:
    tracked = {CONSUMER, PATH}
    facts = {PATH: FileFact(7, SHA256)}
    return validate_fixture_manifest(manifest(entry), tracked, facts)


def test_valid_tracked_fixture() -> None:
    require(not validate(tracked_fixture()), "valid tracked fixture was rejected")


def test_fail_closed_mutations() -> None:
    mutations = []

    unknown_class = tracked_fixture()
    unknown_class["classification"] = "real"
    mutations.append(unknown_class)

    unsafe_path = tracked_fixture()
    unsafe_path["path"] = "../fixture.json"
    mutations.append(unsafe_path)

    bad_hash = tracked_fixture()
    bad_hash["sha256"] = "not-a-hash"
    mutations.append(bad_hash)

    missing_owner = tracked_fixture()
    missing_owner["owner"] = ""
    mutations.append(missing_owner)

    extra_field = tracked_fixture()
    extra_field["approved"] = True
    mutations.append(extra_field)

    for index, entry in enumerate(mutations):
        require(bool(validate(entry)), f"invalid tracked mutation {index} passed")


def test_external_storage_boundary() -> None:
    external = {
        "id": "gguf.external-v1",
        "classification": "external-reference",
        "storage": "external",
        "owner": "loader",
        "purpose": "External compatibility reference.",
        "consumer": CONSUMER,
        "evidence_boundary": "Proves only one pinned external input.",
        "license": "MIT",
        "file_name": "reference.gguf",
        "size_bytes": 1024,
        "sha256": "b" * 64,
        "source": {
            "repository": "owner/repository",
            "revision": "c" * 40,
            "url": "https://example.invalid/owner/repository/" + "c" * 40 + "/reference.gguf",
        },
        "oracle": {
            "runtime": "reference-runtime",
            "revision": "d" * 40,
            "mode": "greedy",
            "prompt": "test",
            "prompt_token_ids": [1],
            "generated_token_ids": [2],
            "generated_text": "result",
        },
    }
    errors = validate_fixture_manifest(manifest(external), {CONSUMER}, {})
    require(not errors, "valid external reference was rejected")

    tracked = {CONSUMER, "somewhere/reference.gguf"}
    errors = validate_fixture_manifest(manifest(external), tracked, {})
    require(bool(errors), "tracked external fixture did not fail closed")

    unpinned = deepcopy(external)
    unpinned["source"]["url"] = "https://example.invalid/reference.gguf"
    errors = validate_fixture_manifest(manifest(unpinned), {CONSUMER}, {})
    require(bool(errors), "unpinned external URL did not fail closed")


def test_unregistered_fixture_rejection() -> None:
    tracked = {CONSUMER, PATH, "aesir_engine/tests/fixtures/orphan.json"}
    facts = {PATH: FileFact(7, SHA256)}
    errors = validate_fixture_manifest(manifest(tracked_fixture()), tracked, facts)
    require(bool(errors), "unregistered fixture data did not fail closed")


def main() -> None:
    test_valid_tracked_fixture()
    test_fail_closed_mutations()
    test_external_storage_boundary()
    test_unregistered_fixture_rejection()


if __name__ == "__main__":
    main()
