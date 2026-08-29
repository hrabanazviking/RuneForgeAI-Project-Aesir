#!/usr/bin/env python3
"""Fail-closed repository truth and consistency checks for Project Aesir."""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
LEDGER = ROOT / "CAPABILITY_LEDGER.md"
RUN_ALL = ROOT / "aesir_engine/tests/run_all.mojo"
TODO = ROOT / "TODO.md"
HYGIENE_POLICY = ROOT / "repository_hygiene_policy.json"
ACTIVE_STATUS_DOCS = [ROOT / "docs/Vision.md", ROOT / "docs/SYSTEM_VISION.md"]
HISTORICAL_CLAIMS_MARKER = "<!-- HISTORICAL_CLAIMS_BEGIN -->"
TEXT_SUFFIXES = {".md", ".mojo", ".py", ".toml", ".yml", ".yaml", ".json"}
ALLOWED_STATUSES = {"verified", "partial", "scaffold", "simulated", "missing"}
ARTIFACT_CLASSIFICATIONS = {
    "duplicate_root_asset",
    "generated_archive",
    "generated_build_artifact",
    "generated_executable",
    "model_weight",
    "placeholder_model",
    "runtime_state",
    "secret_material",
}
MODEL_SUFFIXES = {
    ".bin", ".ckpt", ".gguf", ".h5", ".hdf5", ".mlmodel", ".onnx",
    ".pb", ".pt", ".pth", ".safetensors", ".tflite", ".torchscript",
}
BUILD_SUFFIXES = {
    ".a", ".dll", ".dylib", ".exe", ".lib", ".o", ".obj", ".pyc",
    ".pyo", ".so", ".out", ".wasm",
}
ARCHIVE_SUFFIXES = {
    ".7z", ".bz2", ".gz", ".rar", ".tar", ".tgz", ".whl", ".xz", ".zip",
}
STATE_SUFFIXES = {
    ".bak", ".cache", ".core", ".db", ".dmp", ".log", ".sqlite",
    ".sqlite3", ".tmp",
}
SECRET_SUFFIXES = {".key", ".p12", ".pem", ".pfx"}
IMAGE_SUFFIXES = {".jpeg", ".jpg", ".png", ".webp"}
EXECUTABLE_MAGICS = {
    b"\x7fELF",
    b"MZ",
    b"\xca\xfe\xba\xbe",
    b"\xce\xfa\xed\xfe",
    b"\xcf\xfa\xed\xfe",
    b"\xfe\xed\xfa\xce",
    b"\xfe\xed\xfa\xcf",
}


@dataclass(frozen=True)
class TrackedArtifact:
    path: str
    suffix: str
    size: int
    prefix: bytes
    sha256: str | None = None


@dataclass(frozen=True)
class ArtifactViolation:
    path: str
    classification: str
    detail: str


@dataclass(frozen=True)
class LegacyException:
    path: str
    classification: str
    disposition: str
    reason: str
    baseline_commit: str


def tracked_paths() -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", "-z"], cwd=ROOT, check=True, capture_output=True
    )
    return [ROOT / item.decode() for item in result.stdout.split(b"\0") if item]


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def read_text(path: Path) -> str | None:
    if path.suffix.lower() not in TEXT_SUFFIXES:
        return None
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return None


def ledger_statuses(content: str) -> dict[str, str]:
    entries: dict[str, str] = {}
    blocks = re.split(r"(?=^### AES-[A-Z]+-\d+ —)", content, flags=re.MULTILINE)
    for block in blocks:
        heading = re.match(r"^### (AES-[A-Z]+-\d+) —", block)
        if not heading:
            continue
        statuses = re.findall(
            r"^- \*\*Status:\*\* `(verified|partial|scaffold|simulated|missing)`",
            block,
            flags=re.MULTILINE,
        )
        if len(statuses) == 1:
            entries[heading.group(1)] = statuses[0]
    return entries


def check_ledger(errors: list[str]) -> dict[str, str]:
    content = LEDGER.read_text(encoding="utf-8")
    headings = re.findall(r"^### (AES-[A-Z]+-\d+) —", content, re.MULTILINE)
    if len(headings) != len(set(headings)):
        duplicates = sorted(key for key, count in Counter(headings).items() if count > 1)
        errors.append(f"CAPABILITY_LEDGER.md: duplicate IDs: {', '.join(duplicates)}")

    statuses = ledger_statuses(content)
    if len(statuses) != len(headings):
        errors.append("CAPABILITY_LEDGER.md: every capability must have exactly one allowed status")

    counts = Counter(statuses.values())
    summary = dict(
        re.findall(
            r"^\| `(verified|partial|scaffold|simulated|missing)` \| (\d+) \|$",
            content,
            re.MULTILINE,
        )
    )
    for status in sorted(ALLOWED_STATUSES):
        if int(summary.get(status, -1)) != counts[status]:
            errors.append(
                f"CAPABILITY_LEDGER.md: summary {status}={summary.get(status)} "
                f"but entries={counts[status]}"
            )
    total_match = re.search(r"^\| \*\*Total\*\* \| \*\*(\d+)\*\* \|$", content, re.MULTILINE)
    if not total_match or int(total_match.group(1)) != len(headings):
        errors.append("CAPABILITY_LEDGER.md: summary total does not match capability entries")
    return statuses


def status_reference_errors(
    content: str, statuses: dict[str, str], source: str
) -> list[str]:
    errors = []
    tag_pattern = re.compile(r"\[([a-z/]+),\s*(AES-[A-Z]+-\d+)")
    for line_no, line in enumerate(content.splitlines(), 1):
        for declared, capability_id in tag_pattern.findall(line):
            if declared not in ALLOWED_STATUSES:
                errors.append(
                    f"{source}:{line_no}: unsupported status tag {declared!r}"
                )
                continue
            actual = statuses.get(capability_id)
            if actual is None:
                errors.append(
                    f"{source}:{line_no}: unknown capability reference {capability_id}"
                )
            elif declared != actual:
                errors.append(
                    f"{source}:{line_no}: {capability_id} tag is {declared}, "
                    f"ledger is {actual}"
                )
    return errors


def todo_status_reference_errors(
    content: str, statuses: dict[str, str]
) -> list[str]:
    return status_reference_errors(content, statuses, "TODO.md")


def check_todo_statuses(statuses: dict[str, str], errors: list[str]) -> None:
    errors.extend(
        todo_status_reference_errors(TODO.read_text(encoding="utf-8"), statuses)
    )


def active_status_document_errors(
    content: str, statuses: dict[str, str], source: str
) -> list[str]:
    if content.count(HISTORICAL_CLAIMS_MARKER) != 1:
        return [f"{source}: requires exactly one historical claims marker"]
    current = content.split(HISTORICAL_CLAIMS_MARKER, 1)[0]
    errors = status_reference_errors(current, statuses, source)
    tag_pattern = re.compile(r"\[[a-z/]+,\s*(AES-[A-Z]+-\d+)")
    status_word = re.compile(r"\b(?:verified|partial|scaffold|simulated|missing)\b")
    for line_no, line in enumerate(current.splitlines(), 1):
        capability_ids = set(re.findall(r"AES-[A-Z]+-\d+", line))
        tagged_ids = set(tag_pattern.findall(line))
        if capability_ids and status_word.search(line):
            for capability_id in sorted(capability_ids - tagged_ids):
                errors.append(
                    f"{source}:{line_no}: non-canonical status claim for "
                    f"{capability_id}"
                )
    return errors


def check_active_status_documents(
    statuses: dict[str, str], errors: list[str]
) -> None:
    for path in ACTIVE_STATUS_DOCS:
        errors.extend(
            active_status_document_errors(
                path.read_text(encoding="utf-8"), statuses, relative(path)
            )
        )


def check_master_count(errors: list[str]) -> None:
    source = RUN_ALL.read_text(encoding="utf-8")
    cases = re.findall(r'run_case\(\s*ledger,\s*"([^"]+)"', source, re.DOTALL)
    skips = re.findall(r'record_skip\(\s*ledger,\s*"([^"]+)"', source, re.DOTALL)
    all_names = cases + skips
    duplicate_names = sorted(name for name, count in Counter(all_names).items() if count > 1)
    if duplicate_names:
        errors.append(f"aesir_engine/tests/run_all.mojo: duplicate case names: {duplicate_names}")
    expected = len(all_names)
    finish = re.search(r"ledger\.finish\((\d+)\)", source)
    if not finish or int(finish.group(1)) != expected:
        errors.append(f"aesir_engine/tests/run_all.mojo: ledger.finish must equal {expected}")
    phrase = (
        f"{len(cases)} named executable cases pass, zero fail, "
        f"{len(skips)} external-fixture case is explicitly skipped, total {expected}"
    )
    if phrase not in LEDGER.read_text(encoding="utf-8"):
        errors.append("CAPABILITY_LEDGER.md: E-MASTER count is not synchronized")


def check_text_hygiene(paths: list[Path], errors: list[str]) -> None:
    absolute = re.compile(r"(?:file:///)?/(?:home|Users)/[^\s)`]+")
    for path in paths:
        content = read_text(path)
        if content is None:
            continue
        for line_no, line in enumerate(content.splitlines(), 1):
            if absolute.search(line):
                errors.append(f"{relative(path)}:{line_no}: machine-local absolute path")

    for name in ["AGENT_ONBOARDING.md", "ENGINEERING_DOCTRINE.md", "GIT_DISCIPLINE.md", "RULES.AI.md"]:
        content = (ROOT / name).read_text(encoding="utf-8")
        if "TASK_QUEUE.md" in content or re.search(r"\bdevelopment branch\b|checkout development", content):
            errors.append(f"{name}: nonexistent task file or integration branch")


def check_source_truth(errors: list[str]) -> None:
    signatures = {
        "aesir_engine/cli/repl.mojo": ["Aesir response to:"],
        "aesir_engine/cli/manifest.mojo": ["sha256:", "4370000000"],
        "aesir_engine/core/swarm.mojo": ["secret-aesir-token"],
    }
    for name, forbidden in signatures.items():
        content = (ROOT / name).read_text(encoding="utf-8")
        for token in forbidden:
            if token in content:
                errors.append(f"{name}: prohibited fabricated signature {token!r}")

    for name in ["cuda_gate.mojo", "metal_gate.mojo", "intel_gate.mojo", "amd_gate.mojo", "npu_gate.mojo"]:
        content = (ROOT / "aesir_engine/core" / name).read_text(encoding="utf-8")
        block = re.search(r"def get_device_count\([^)]*\)[^:]*:\s*(.*?)(?=\n\s*def |\Z)", content, re.DOTALL)
        if not block or "return 0" not in block.group(1):
            errors.append(f"aesir_engine/core/{name}: physical device count must fail closed")


def check_ci(errors: list[str]) -> None:
    content = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
    for token in [
        "fetch-depth: 0",
        "mojo build aesir_engine/main.mojo",
        "mojo run aesir_engine/tests/run_all.mojo",
        "test_fail_closed_runner.mojo",
        "scripts/test_fixture_manifest.py",
        "scripts/check_fixture_manifest.py",
        "scripts/test_check_doc_drift.py",
        "scripts/check_doc_drift.py",
    ]:
        if token not in content:
            errors.append(f".github/workflows/ci.yml: missing gate {token!r}")


def _is_executable_magic(prefix: bytes) -> bool:
    return any(prefix.startswith(magic) for magic in EXECUTABLE_MAGICS)


def inspect_tracked_artifact(path: Path) -> TrackedArtifact:
    name = relative(path)
    with path.open("rb") as handle:
        prefix = handle.read(4)
    suffix = path.suffix.lower()
    content_hash = None
    if suffix in IMAGE_SUFFIXES:
        content_hash = hashlib.sha256(path.read_bytes()).hexdigest()
    return TrackedArtifact(name, suffix, path.stat().st_size, prefix, content_hash)


def classify_artifact(
    artifact: TrackedArtifact, canonical_image_hashes: set[str]
) -> ArtifactViolation | None:
    if _is_executable_magic(artifact.prefix):
        return ArtifactViolation(
            artifact.path,
            "generated_executable",
            "tracked file contains executable binary magic",
        )
    if artifact.suffix in MODEL_SUFFIXES:
        if artifact.size < 1024:
            return ArtifactViolation(
                artifact.path,
                "placeholder_model",
                "model-format file is smaller than the 1 KiB placeholder floor",
            )
        return ArtifactViolation(
            artifact.path,
            "model_weight",
            "model weights and external model formats must remain outside Git",
        )
    if artifact.suffix in BUILD_SUFFIXES:
        return ArtifactViolation(
            artifact.path,
            "generated_build_artifact",
            "build output must be produced outside the tracked source tree",
        )
    if artifact.suffix in ARCHIVE_SUFFIXES:
        return ArtifactViolation(
            artifact.path,
            "generated_archive",
            "archive requires a separately approved provenance boundary",
        )
    if artifact.suffix in STATE_SUFFIXES:
        return ArtifactViolation(
            artifact.path,
            "runtime_state",
            "runtime state, logs, databases, and dumps must not be tracked",
        )
    if artifact.suffix in SECRET_SUFFIXES:
        return ArtifactViolation(
            artifact.path,
            "secret_material",
            "private keys and certificate bundles must not be tracked",
        )
    if (
        "/" not in artifact.path
        and artifact.suffix in IMAGE_SUFFIXES
        and artifact.sha256 in canonical_image_hashes
    ):
        return ArtifactViolation(
            artifact.path,
            "duplicate_root_asset",
            "root image is byte-identical to a canonical docs asset",
        )
    return None


def classify_tracked_artifacts(paths: list[Path]) -> list[ArtifactViolation]:
    asset_root = ROOT / "docs/assets/images"
    canonical_hashes = set()
    if asset_root.exists():
        canonical_hashes = {
            hashlib.sha256(path.read_bytes()).hexdigest()
            for path in asset_root.rglob("*")
            if path.is_file()
        }
    violations = []
    for path in paths:
        violation = classify_artifact(
            inspect_tracked_artifact(path), canonical_hashes
        )
        if violation is not None:
            violations.append(violation)
    return violations


def _valid_policy_path(path: str) -> bool:
    candidate = Path(path)
    return (
        bool(path)
        and not candidate.is_absolute()
        and "\\" not in path
        and ".." not in candidate.parts
        and candidate.as_posix() == path
    )


def validate_hygiene_policy(
    policy: object, errors: list[str]
) -> dict[str, LegacyException]:
    if not isinstance(policy, dict):
        errors.append("repository_hygiene_policy.json: policy must be an object")
        return {}
    expected_keys = {"policy_version", "legacy_baseline_commit", "legacy_classes"}
    if set(policy) != expected_keys:
        errors.append(
            "repository_hygiene_policy.json: top-level schema keys mismatch"
        )
        return {}
    if type(policy["policy_version"]) is not int or policy["policy_version"] != 1:
        errors.append("repository_hygiene_policy.json: unsupported policy version")

    baseline = policy["legacy_baseline_commit"]
    if not isinstance(baseline, str) or not re.fullmatch(r"[0-9a-f]{40}", baseline):
        errors.append(
            "repository_hygiene_policy.json: legacy baseline must be a full commit hash"
        )
        baseline = ""

    classes = policy["legacy_classes"]
    if not isinstance(classes, list):
        errors.append("repository_hygiene_policy.json: legacy_classes must be a list")
        return {}

    exceptions: dict[str, LegacyException] = {}
    class_keys = {"classification", "disposition", "reason", "paths"}
    for index, group in enumerate(classes):
        label = f"repository_hygiene_policy.json: legacy_classes[{index}]"
        if not isinstance(group, dict) or set(group) != class_keys:
            errors.append(f"{label}: schema keys mismatch")
            continue
        classification = group["classification"]
        disposition = group["disposition"]
        reason = group["reason"]
        group_paths = group["paths"]
        if (
            not isinstance(classification, str)
            or classification not in ARTIFACT_CLASSIFICATIONS
        ):
            errors.append(f"{label}: unsupported classification")
            continue
        if disposition != "deletion_requires_approval":
            errors.append(f"{label}: unsupported disposition")
            continue
        if not isinstance(reason, str) or not reason.strip():
            errors.append(f"{label}: reason must be non-empty")
            continue
        if not isinstance(group_paths, list) or not group_paths:
            errors.append(f"{label}: paths must be a non-empty list")
            continue
        for path in group_paths:
            if not isinstance(path, str) or not _valid_policy_path(path):
                errors.append(f"{label}: unsafe or invalid path {path!r}")
                continue
            if path in exceptions:
                errors.append(f"{label}: duplicate exception path {path}")
                continue
            exceptions[path] = LegacyException(
                path, classification, disposition, reason, baseline
            )
    return exceptions


def load_hygiene_policy(errors: list[str]) -> dict[str, LegacyException]:
    try:
        policy = json.loads(HYGIENE_POLICY.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        errors.append(f"repository_hygiene_policy.json: unable to load: {error}")
        return {}
    return validate_hygiene_policy(policy, errors)


def evaluate_artifact_policy(
    violations: list[ArtifactViolation],
    exceptions: dict[str, LegacyException],
    tracked: set[str],
    hygiene_verified: bool,
) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    detected = {violation.path: violation for violation in violations}
    matched_legacy: dict[str, list[str]] = {}

    for path, exception in sorted(exceptions.items()):
        if path not in tracked:
            errors.append(f"artifact policy exception is not tracked: {path}")
            continue
        violation = detected.get(path)
        if violation is None:
            errors.append(f"artifact policy exception hides no violation: {path}")
            continue
        if violation.classification != exception.classification:
            errors.append(
                f"artifact policy classification mismatch for {path}: "
                f"policy={exception.classification}, detected={violation.classification}"
            )

    for violation in sorted(violations, key=lambda item: item.path):
        exception = exceptions.get(violation.path)
        if exception is None:
            errors.append(
                f"unapproved tracked artifact {violation.path} "
                f"({violation.classification}): {violation.detail}"
            )
        elif violation.classification == exception.classification:
            matched_legacy.setdefault(violation.classification, []).append(
                violation.path
            )
    for classification, paths in sorted(matched_legacy.items()):
        message = (
            "legacy tracked artifacts pending deletion approval: "
            f"{classification}={len(paths)} ({', '.join(sorted(paths))})"
        )
        (errors if hygiene_verified else warnings).append(message)
    return errors, warnings


def check_policy_baseline(
    exceptions: dict[str, LegacyException], errors: list[str]
) -> None:
    for path, exception in sorted(exceptions.items()):
        if not exception.baseline_commit:
            continue
        result = subprocess.run(
            [
                "git", "cat-file", "-e",
                f"{exception.baseline_commit}:{path}",
            ],
            cwd=ROOT,
            check=False,
            capture_output=True,
        )
        if result.returncode != 0:
            errors.append(
                f"artifact policy path did not exist at legacy baseline: {path}"
            )


def check_tracked_artifacts(
    paths: list[Path], statuses: dict[str, str], errors: list[str], warnings: list[str]
) -> None:
    exceptions = load_hygiene_policy(errors)
    check_policy_baseline(exceptions, errors)
    violations = classify_tracked_artifacts(paths)
    policy_errors, policy_warnings = evaluate_artifact_policy(
        violations,
        exceptions,
        {relative(path) for path in paths},
        statuses.get("AES-FND-007") == "verified",
    )
    errors.extend(policy_errors)
    warnings.extend(policy_warnings)


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []
    paths = tracked_paths()
    statuses = check_ledger(errors)
    check_todo_statuses(statuses, errors)
    check_active_status_documents(statuses, errors)
    check_master_count(errors)
    check_text_hygiene(paths, errors)
    check_source_truth(errors)
    check_ci(errors)
    check_tracked_artifacts(paths, statuses, errors, warnings)
    for warning in warnings:
        print(f"WARNING: {warning}")
    if errors:
        print(f"FAILED: {len(errors)} repository consistency issue(s)")
        for error in errors:
            print(f" - {error}")
        return 1
    print("PASSED: repository truth, ledger, test-count, CI, and hygiene checks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
