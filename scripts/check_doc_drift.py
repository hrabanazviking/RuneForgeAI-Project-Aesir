#!/usr/bin/env python3
"""Fail-closed repository truth and consistency checks for Project Aesir."""

from __future__ import annotations

import hashlib
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
LEDGER = ROOT / "CAPABILITY_LEDGER.md"
RUN_ALL = ROOT / "aesir_engine/tests/run_all.mojo"
TEXT_SUFFIXES = {".md", ".mojo", ".py", ".toml", ".yml", ".yaml", ".json"}
ALLOWED_STATUSES = {"verified", "partial", "scaffold", "simulated", "missing"}


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
        "mojo build aesir_engine/main.mojo",
        "mojo run aesir_engine/tests/run_all.mojo",
        "test_fail_closed_runner.mojo",
        "scripts/check_doc_drift.py",
    ]:
        if token not in content:
            errors.append(f".github/workflows/ci.yml: missing gate {token!r}")


def check_tracked_artifacts(
    paths: list[Path], statuses: dict[str, str], errors: list[str], warnings: list[str]
) -> None:
    tracked = {relative(path): path for path in paths}
    generated = {
        "main", "aesir_main", "test_engine", "test_server_loop",
        "aesir_engine/main", "aesir_engine/aesir_main", "aesir_engine/test",
        "aesir_engine/test_engine", "aesir_engine/test_server_loop",
    }
    artifacts = sorted(generated & tracked.keys())
    placeholders = sorted(
        name for name, path in tracked.items()
        if name.endswith(".gguf") and path.stat().st_size < 1024
    )
    canonical_hashes = set()
    asset_root = ROOT / "docs/assets/images"
    if asset_root.exists():
        canonical_hashes = {
            hashlib.sha256(path.read_bytes()).hexdigest()
            for path in asset_root.rglob("*") if path.is_file()
        }
    duplicates = [
        name for name, path in tracked.items()
        if "/" not in name
        and path.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}
        and hashlib.sha256(path.read_bytes()).hexdigest() in canonical_hashes
    ]
    issues = []
    if artifacts:
        issues.append(f"tracked generated executables: {', '.join(artifacts)}")
    if placeholders:
        issues.append(f"placeholder model files: {', '.join(placeholders)}")
    if duplicates:
        issues.append(f"duplicate root assets: {len(duplicates)}")
    if issues:
        message = "repository artifact hygiene pending: " + "; ".join(issues)
        (errors if statuses.get("AES-FND-007") == "verified" else warnings).append(message)


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []
    paths = tracked_paths()
    statuses = check_ledger(errors)
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
