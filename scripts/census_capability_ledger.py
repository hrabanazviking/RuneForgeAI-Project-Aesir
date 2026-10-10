#!/usr/bin/env python3
"""Emit a deterministic read-only census of CAPABILITY_LEDGER.md fields."""

from __future__ import annotations

import hashlib
import json
import re
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
LEDGER = ROOT / "CAPABILITY_LEDGER.md"
HEADING = re.compile(r"^### (AES-[A-Z]+-\d+) — (.+?)\s*$", re.MULTILINE)
STATUS = re.compile(r"^- \*\*Status:\*\* `([^`]+)`\s*$", re.MULTILINE)
FIELDS = (
    "Status",
    "Owner",
    "Claim sources",
    "Implementation evidence",
    "Executable evidence",
    "Evidence boundary",
    "Next acceptance gate",
    "Audit",
)
FIELD_LINE = re.compile(r"^- \*\*([^*]+):\*\*\s*(.*)$")


def main() -> int:
    raw = LEDGER.read_bytes()
    text = raw.decode("utf-8")
    matches = list(HEADING.finditer(text))
    entries: list[dict[str, object]] = []
    id_counts = Counter(match.group(1) for match in matches)
    status_counts: Counter[str] = Counter()

    for index, match in enumerate(matches):
        start = match.start()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        block = text[start:end]
        present: Counter[str] = Counter()
        for line in block.splitlines():
            field_match = FIELD_LINE.match(line)
            if field_match:
                present[field_match.group(1)] += 1
        status_matches = STATUS.findall(block)
        status = status_matches[0] if len(status_matches) == 1 else None
        if status is not None:
            status_counts[status] += 1
        entries.append(
            {
                "id": match.group(1),
                "name": match.group(2),
                "status": status,
                "status_field_count": present["Status"],
                "field_counts": {field: present[field] for field in FIELDS},
                "line": text.count("\n", 0, start) + 1,
            }
        )

    field_census: dict[str, dict[str, object]] = {}
    for field in FIELDS:
        missing = [entry["id"] for entry in entries if entry["field_counts"][field] == 0]
        repeated = [entry["id"] for entry in entries if entry["field_counts"][field] > 1]
        field_census[field] = {
            "present": len(entries) - len(missing),
            "missing_ids": missing,
            "repeated_ids": repeated,
        }

    duplicate_ids = sorted(identifier for identifier, count in id_counts.items() if count > 1)
    payload = {
        "baseline_schema_version": 1,
        "source": "CAPABILITY_LEDGER.md",
        "source_sha256": hashlib.sha256(raw).hexdigest(),
        "capability_count": len(entries),
        "duplicate_ids": duplicate_ids,
        "status_counts": dict(sorted(status_counts.items())),
        "field_census": field_census,
        "entries": entries,
    }
    json.dump(payload, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
