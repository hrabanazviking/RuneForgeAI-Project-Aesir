#!/usr/bin/env python3
"""Emit a deterministic census of explicit TODO capability status tags."""

from __future__ import annotations

import hashlib
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TODO = ROOT / "TODO.md"
LEDGER = ROOT / "CAPABILITY_LEDGER.md"
STATUS_TAG = re.compile(r"\[([a-z/]+),([^\]]*)\]")
CAPABILITY_ID = re.compile(r"AES-[A-Z]+-\d+")
AUDIT_ID = re.compile(r"AER-\d+")
KNOWN_STATUSES = {"verified", "partial", "scaffold", "simulated", "missing"}
LEDGER_ID = re.compile(r"^### (AES-[A-Z]+-\d+) —", re.MULTILINE)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def census() -> dict[str, object]:
    text = TODO.read_text(encoding="utf-8")
    ledger_ids = set(LEDGER_ID.findall(LEDGER.read_text(encoding="utf-8")))
    tags: list[dict[str, object]] = []
    for line_number, line in enumerate(text.splitlines(), 1):
        for match in STATUS_TAG.finditer(line):
            ids = CAPABILITY_ID.findall(match.group(2))
            if not ids:
                continue
            tags.append({
                "line": line_number,
                "status": match.group(1),
                "ids": ids,
                "audit_ids": AUDIT_ID.findall(match.group(2)),
                "supported_status": match.group(1) in KNOWN_STATUSES,
                "unknown_ids": [item for item in ids if item not in ledger_ids],
                "mismatched_ids": [],
            })
    mismatches: list[dict[str, str | int]] = []
    ledger_status = {}
    current: str | None = None
    for line in LEDGER.read_text(encoding="utf-8").splitlines():
        heading = LEDGER_ID.match(line)
        if heading:
            current = heading.group(1)
        elif current is not None and (status := re.match(r"^- \*\*Status:\*\* `(\w+)`", line)):
            ledger_status[current] = status.group(1)
    for tag in tags:
        for capability_id in tag["ids"]:
            if capability_id in ledger_status and tag["status"] != ledger_status[capability_id]:
                mismatch = {"line": tag["line"], "id": capability_id, "tag": tag["status"], "ledger": ledger_status[capability_id]}
                mismatches.append(mismatch)
                tag["mismatched_ids"].append(capability_id)
    shapes = Counter((len(tag["ids"]), len(STATUS_TAG.findall(text.splitlines()[tag["line"] - 1]))) for tag in tags)
    return {
        "baseline_schema_version": 1,
        "source": "TODO.md",
        "source_sha256": digest(TODO),
        "ledger": "CAPABILITY_LEDGER.md",
        "ledger_sha256": digest(LEDGER),
        "tag_count": len(tags),
        "tag_status_counts": dict(sorted(Counter(str(tag["status"]) for tag in tags).items())),
        "reference_count": sum(len(tag["ids"]) for tag in tags),
        "unique_reference_count": len({item for tag in tags for item in tag["ids"]}),
        "combined_reference_tags": sum(len(tag["ids"]) > 1 for tag in tags),
        "mixed_aes_audit_tags": sum(bool(tag["audit_ids"]) for tag in tags),
        "audit_reference_count": sum(len(tag["audit_ids"]) for tag in tags),
        "adjacent_status_tag_lines": sum(
            len(STATUS_TAG.findall(line)) > 1 and any(CAPABILITY_ID.search(match.group(2)) for match in STATUS_TAG.finditer(line))
            for line in text.splitlines()
        ),
        "status_tag_shape_counts_by_ids_and_line_tag_count": [
            {"ids_in_tag": id_count, "tags_on_line": line_count, "count": count}
            for (id_count, line_count), count in sorted(shapes.items())
        ],
        "unsupported_tags": [tag for tag in tags if not tag["supported_status"]],
        "unknown_references": [
            {"line": tag["line"], "id": item}
            for tag in tags for item in tag["unknown_ids"]
        ],
        "status_mismatches": mismatches,
        "tags": tags,
    }


def main() -> None:
    print(json.dumps(census(), ensure_ascii=False, indent=2) + "\n", end="")


if __name__ == "__main__":
    main()
