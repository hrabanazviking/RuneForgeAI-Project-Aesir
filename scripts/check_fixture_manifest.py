#!/usr/bin/env python3
"""Fail-closed fixture classification and provenance validation."""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "fixture_manifest.json"
FIXTURE_ROOT = "aesir_engine/tests/fixtures/"
CLASSIFICATIONS = [
    "synthetic",
    "malformed",
    "regression",
    "external-reference",
]
COMMON_KEYS = {
    "classification",
    "consumer",
    "evidence_boundary",
    "id",
    "license",
    "owner",
    "purpose",
    "sha256",
    "size_bytes",
    "storage",
}
EXTERNAL_KEYS = COMMON_KEYS | {"file_name", "oracle", "source"}
TRACKED_KEYS = COMMON_KEYS | {"construction", "path"}
SOURCE_KEYS = {"repository", "revision", "url"}
ORACLE_KEYS = {
    "generated_text",
    "generated_token_ids",
    "mode",
    "prompt",
    "prompt_token_ids",
    "revision",
    "runtime",
}
CONSTRUCTION_KEYS = {"method", "tool", "version"}


@dataclass(frozen=True)
class FileFact:
    size: int
    sha256: str


def _safe_relative_path(value: object) -> bool:
    if not isinstance(value, str) or not value:
        return False
    candidate = Path(value)
    return (
        not candidate.is_absolute()
        and "\\" not in value
        and ".." not in candidate.parts
        and candidate.as_posix() == value
    )


def _non_empty_string(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _valid_sha256(value: object) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def _valid_revision(value: object) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{40}", value) is not None


def _valid_token_ids(value: object) -> bool:
    return (
        isinstance(value, list)
        and bool(value)
        and all(type(item) is int and item >= 0 for item in value)
    )


def validate_fixture_manifest(
    manifest: object,
    tracked_paths: set[str],
    file_facts: dict[str, FileFact],
) -> list[str]:
    errors: list[str] = []
    if not isinstance(manifest, dict):
        return ["fixture_manifest.json: manifest must be an object"]
    if set(manifest) != {"manifest_version", "classifications", "fixtures"}:
        return ["fixture_manifest.json: top-level schema keys mismatch"]
    if type(manifest["manifest_version"]) is not int or manifest["manifest_version"] != 1:
        errors.append("fixture_manifest.json: unsupported manifest version")
    if manifest["classifications"] != CLASSIFICATIONS:
        errors.append("fixture_manifest.json: classification registry mismatch")
    fixtures = manifest["fixtures"]
    if not isinstance(fixtures, list) or not fixtures:
        errors.append("fixture_manifest.json: fixtures must be a non-empty list")
        return errors

    seen_ids: set[str] = set()
    seen_locations: set[str] = set()
    registered_tracked: set[str] = set()
    for index, fixture in enumerate(fixtures):
        label = f"fixture_manifest.json: fixtures[{index}]"
        if not isinstance(fixture, dict):
            errors.append(f"{label}: entry must be an object")
            continue
        classification = fixture.get("classification")
        expected_keys = EXTERNAL_KEYS if classification == "external-reference" else TRACKED_KEYS
        if set(fixture) != expected_keys:
            errors.append(f"{label}: schema keys mismatch")
            continue

        fixture_id = fixture["id"]
        if not isinstance(fixture_id, str) or not re.fullmatch(
            r"[a-z0-9][a-z0-9._-]+", fixture_id
        ):
            errors.append(f"{label}: invalid fixture id")
        elif fixture_id in seen_ids:
            errors.append(f"{label}: duplicate fixture id {fixture_id}")
        else:
            seen_ids.add(fixture_id)

        if classification not in CLASSIFICATIONS:
            errors.append(f"{label}: unsupported classification")
        for key in ["owner", "purpose", "consumer", "evidence_boundary", "license"]:
            if not _non_empty_string(fixture[key]):
                errors.append(f"{label}: {key} must be non-empty")
        consumer = fixture["consumer"]
        if not _safe_relative_path(consumer) or consumer not in tracked_paths:
            errors.append(f"{label}: consumer must be a tracked relative path")
        if type(fixture["size_bytes"]) is not int or fixture["size_bytes"] <= 0:
            errors.append(f"{label}: size_bytes must be a positive integer")
        if not _valid_sha256(fixture["sha256"]):
            errors.append(f"{label}: sha256 must be 64 lowercase hex characters")

        if classification == "external-reference":
            _validate_external_fixture(fixture, label, tracked_paths, seen_locations, errors)
        else:
            _validate_tracked_fixture(
                fixture,
                label,
                tracked_paths,
                file_facts,
                seen_locations,
                registered_tracked,
                errors,
            )

    unregistered = sorted(
        path
        for path in tracked_paths
        if path.startswith(FIXTURE_ROOT)
        and path != f"{FIXTURE_ROOT}README.md"
        and path not in registered_tracked
    )
    for path in unregistered:
        errors.append(f"unregistered tracked fixture data: {path}")
    return errors


def _validate_external_fixture(
    fixture: dict[str, object],
    label: str,
    tracked_paths: set[str],
    seen_locations: set[str],
    errors: list[str],
) -> None:
    if fixture["storage"] != "external":
        errors.append(f"{label}: external-reference storage must be external")
    file_name = fixture["file_name"]
    if (
        not isinstance(file_name, str)
        or not file_name
        or Path(file_name).name != file_name
    ):
        errors.append(f"{label}: file_name must be a basename")
        return
    if file_name in seen_locations:
        errors.append(f"{label}: duplicate fixture location {file_name}")
    seen_locations.add(file_name)
    if any(Path(path).name == file_name for path in tracked_paths):
        errors.append(f"{label}: external fixture is tracked in Git")

    source = fixture["source"]
    if not isinstance(source, dict) or set(source) != SOURCE_KEYS:
        errors.append(f"{label}: external source schema mismatch")
    else:
        for key in ["repository", "url"]:
            if not _non_empty_string(source[key]):
                errors.append(f"{label}: source {key} must be non-empty")
        revision = source["revision"]
        if not _valid_revision(revision):
            errors.append(f"{label}: source revision must be a full Git commit")
        url = source["url"]
        if (
            not isinstance(url, str)
            or not url.startswith("https://")
            or not isinstance(revision, str)
            or revision not in url
            or not url.endswith("/" + file_name)
        ):
            errors.append(f"{label}: source URL must pin revision and file name")

    oracle = fixture["oracle"]
    if not isinstance(oracle, dict) or set(oracle) != ORACLE_KEYS:
        errors.append(f"{label}: oracle schema mismatch")
        return
    for key in ["runtime", "mode", "prompt", "generated_text"]:
        if not _non_empty_string(oracle[key]):
            errors.append(f"{label}: oracle {key} must be non-empty")
    if not _valid_revision(oracle["revision"]):
        errors.append(f"{label}: oracle revision must be a full Git commit")
    for key in ["prompt_token_ids", "generated_token_ids"]:
        if not _valid_token_ids(oracle[key]):
            errors.append(f"{label}: oracle {key} must be non-empty token IDs")


def _validate_tracked_fixture(
    fixture: dict[str, object],
    label: str,
    tracked_paths: set[str],
    file_facts: dict[str, FileFact],
    seen_locations: set[str],
    registered_tracked: set[str],
    errors: list[str],
) -> None:
    if fixture["storage"] != "tracked":
        errors.append(f"{label}: local fixture storage must be tracked")
    path = fixture["path"]
    if not _safe_relative_path(path) or not isinstance(path, str):
        errors.append(f"{label}: tracked fixture path is unsafe")
        return
    if not path.startswith(FIXTURE_ROOT):
        errors.append(f"{label}: tracked fixture must be under {FIXTURE_ROOT}")
    if path in seen_locations:
        errors.append(f"{label}: duplicate fixture location {path}")
    seen_locations.add(path)
    registered_tracked.add(path)
    if path not in tracked_paths:
        errors.append(f"{label}: tracked fixture path does not exist in Git")
    fact = file_facts.get(path)
    if fact is None:
        errors.append(f"{label}: tracked fixture file facts are unavailable")
    else:
        if fact.size != fixture["size_bytes"]:
            errors.append(f"{label}: tracked fixture size mismatch")
        if fact.sha256 != fixture["sha256"]:
            errors.append(f"{label}: tracked fixture checksum mismatch")
    construction = fixture["construction"]
    if not isinstance(construction, dict) or set(construction) != CONSTRUCTION_KEYS:
        errors.append(f"{label}: construction schema mismatch")
    else:
        for key in CONSTRUCTION_KEYS:
            if not _non_empty_string(construction[key]):
                errors.append(f"{label}: construction {key} must be non-empty")


def _tracked_paths() -> set[str]:
    result = subprocess.run(
        ["git", "ls-files", "-z"], cwd=ROOT, check=True, capture_output=True
    )
    return {item.decode() for item in result.stdout.split(b"\0") if item}


def _fixture_file_facts(tracked_paths: set[str]) -> dict[str, FileFact]:
    facts = {}
    for path in tracked_paths:
        if not path.startswith(FIXTURE_ROOT) or path == f"{FIXTURE_ROOT}README.md":
            continue
        content = (ROOT / path).read_bytes()
        facts[path] = FileFact(len(content), hashlib.sha256(content).hexdigest())
    return facts


def main() -> int:
    try:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"FAILED: fixture_manifest.json could not be loaded: {error}")
        return 1
    tracked = _tracked_paths()
    errors = validate_fixture_manifest(manifest, tracked, _fixture_file_facts(tracked))
    if errors:
        print(f"FAILED: {len(errors)} fixture manifest issue(s)")
        for error in errors:
            print(f" - {error}")
        return 1
    print("PASSED: fixture classification, provenance, and storage policy")
    return 0


if __name__ == "__main__":
    sys.exit(main())
