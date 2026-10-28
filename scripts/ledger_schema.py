#!/usr/bin/env python3
"""Validate and deterministically export Project Aesir's capability ledger."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
from dataclasses import asdict, dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
ALLOWED_STATUSES = {"verified", "partial", "scaffold", "simulated", "missing"}
REQUIRED_FIELDS = (
    "Owner",
    "Executable evidence",
    "Evidence boundary",
)
OPTIONAL_FIELDS = (
    "Claim sources",
    "Implementation evidence",
    "Next acceptance gate",
    "Audit",
)
CANONICAL_FIELDS = {"Status", *REQUIRED_FIELDS, *OPTIONAL_FIELDS}
HEADING = re.compile(r"^### (AES-[A-Z]+-\d+) — (.+?)\s*$")
HEADING_LIKE = re.compile(r"^###\s+AES-")
RECORD_HEADING = re.compile(r"^###\s+(AES-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s+—")
# Grandfathered record headings.  AES-C3-REVIEW is a campaign verdict
# record (H060), not a capability entry: its identifier predates the
# AES-<DOMAIN>-<NNN> capability numbering, so the capability heading
# grammar cannot express it.  Registered here, its block (the verdict and
# the campaign sections that follow it) is treated as a historical record
# and skipped by the capability schema.  Renaming the entry to fit the
# grammar would invent an identifier it never had.
GRANDFATHERED_RECORD_IDS = {"AES-C3-REVIEW"}
FIELD = re.compile(r"^- \*\*([^*]+):\*\*\s*(.*)$")
FIELD_LIKE = re.compile(r"^- \*\*[^*]+\*\*")
STATUS_VALUE = re.compile(r"^`(verified|partial|scaffold|simulated|missing)`$")


@dataclass(frozen=True)
class LedgerExtension:
    label: str
    value: str


@dataclass(frozen=True)
class CapabilityEntry:
    id: str
    name: str
    status: str
    owner: str
    claim_sources: str | None
    implementation_evidence: str | None
    executable_evidence: str
    evidence_boundary: str
    next_acceptance_gate: str | None
    audit: str | None
    extensions: tuple[LedgerExtension, ...]


@dataclass(frozen=True)
class LedgerDiagnostic:
    source: str
    line: int
    message: str

    def __str__(self) -> str:
        return f"{self.source}:{self.line}: {self.message}"


class LedgerSchemaError(ValueError):
    def __init__(self, diagnostics: tuple[LedgerDiagnostic, ...]):
        self.diagnostics = diagnostics
        super().__init__("\n".join(str(item) for item in diagnostics))


def _field_value(lines: list[str]) -> str:
    # Keep wrapped Markdown and blank continuation lines, normalizing only the
    # file's CRLF/CR separators before this function is called.
    return "\n".join(lines).strip()


def parse_ledger_text(
    text: str, source: str = "<memory>"
) -> tuple[CapabilityEntry, ...]:
    """Parse the full ledger or raise with stable, source-ordered diagnostics."""
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = text.splitlines()
    starts = [index for index, line in enumerate(lines) if HEADING_LIKE.match(line)]
    diagnostics: list[LedgerDiagnostic] = []
    if not starts:
        raise LedgerSchemaError((LedgerDiagnostic(source, 1, "no capability entries found"),))

    entries: list[CapabilityEntry] = []
    seen_ids: dict[str, int] = {}
    for index, start in enumerate(starts):
        stop = starts[index + 1] if index + 1 < len(starts) else len(lines)
        header = HEADING.fullmatch(lines[start])
        if header is None:
            record = RECORD_HEADING.match(lines[start])
            if record is not None and record.group(1) in GRANDFATHERED_RECORD_IDS:
                # Historical record block, not a capability entry.
                continue
            diagnostics.append(
                LedgerDiagnostic(source, start + 1, "malformed capability heading")
            )
            continue

        capability_id = header.group(1)
        name = header.group(2).strip()
        if not name:
            diagnostics.append(
                LedgerDiagnostic(source, start + 1, "capability name must not be empty")
            )
        if capability_id in seen_ids:
            diagnostics.append(
                LedgerDiagnostic(
                    source,
                    start + 1,
                    f"duplicate capability ID {capability_id} (first at line {seen_ids[capability_id]})",
                )
            )
        else:
            seen_ids[capability_id] = start + 1

        fields: list[tuple[str, int, str]] = []
        current_label: str | None = None
        current_line = 0
        current_value: list[str] = []

        def flush_field() -> None:
            nonlocal current_label, current_line, current_value
            if current_label is not None:
                fields.append(
                    (current_label, current_line, _field_value(current_value))
                )
            current_label = None
            current_line = 0
            current_value = []

        for line_index in range(start + 1, stop):
            line = lines[line_index]
            match = FIELD.fullmatch(line)
            if match is not None:
                flush_field()
                current_label = match.group(1).strip()
                current_line = line_index + 1
                current_value = [match.group(2)]
                continue
            if FIELD_LIKE.match(line):
                diagnostics.append(
                    LedgerDiagnostic(source, line_index + 1, "malformed labeled field")
                )
                flush_field()
                continue
            if current_label is not None:
                current_value.append(line)
        flush_field()

        by_label: dict[str, list[tuple[int, str]]] = {}
        extensions: list[LedgerExtension] = []
        for label, line_number, value in fields:
            if label not in CANONICAL_FIELDS:
                if not label or not value:
                    diagnostics.append(
                        LedgerDiagnostic(source, line_number, "extension label and value must not be empty")
                    )
                else:
                    extensions.append(LedgerExtension(label, value))
                continue
            by_label.setdefault(label, []).append((line_number, value))

        for label, records in by_label.items():
            if len(records) > 1:
                diagnostics.append(
                    LedgerDiagnostic(source, records[1][0], f"duplicate canonical field {label!r}")
                )
        for required in ("Status", *REQUIRED_FIELDS):
            if required not in by_label:
                diagnostics.append(
                    LedgerDiagnostic(source, start + 1, f"missing required field {required!r}")
                )
            elif not by_label[required][0][1]:
                diagnostics.append(
                    LedgerDiagnostic(source, by_label[required][0][0], f"field {required!r} must not be empty")
                )
        for optional in OPTIONAL_FIELDS:
            if optional in by_label and not by_label[optional][0][1]:
                diagnostics.append(
                    LedgerDiagnostic(source, by_label[optional][0][0], f"field {optional!r} must not be empty when present")
                )

        status = ""
        if "Status" in by_label and len(by_label["Status"]) == 1:
            status_line, status_value = by_label["Status"][0]
            status_match = STATUS_VALUE.fullmatch(status_value)
            if status_match is None or status_match.group(1) not in ALLOWED_STATUSES:
                diagnostics.append(
                    LedgerDiagnostic(source, status_line, "status must be one backticked canonical value")
                )
            else:
                status = status_match.group(1)

        def get(label: str) -> str | None:
            records = by_label.get(label)
            return records[0][1] if records and records[0][1] else None

        entries.append(
            CapabilityEntry(
                id=capability_id,
                name=name,
                status=status,
                owner=get("Owner") or "",
                claim_sources=get("Claim sources"),
                implementation_evidence=get("Implementation evidence"),
                executable_evidence=get("Executable evidence") or "",
                evidence_boundary=get("Evidence boundary") or "",
                next_acceptance_gate=get("Next acceptance gate"),
                audit=get("Audit"),
                extensions=tuple(extensions),
            )
        )

    if diagnostics:
        diagnostics.sort(key=lambda item: (item.line, item.message))
        raise LedgerSchemaError(tuple(diagnostics))
    return tuple(entries)


def parse_ledger_path(path: Path) -> tuple[CapabilityEntry, ...]:
    try:
        raw = path.read_bytes()
    except OSError as error:
        raise LedgerSchemaError(
            (LedgerDiagnostic(str(path), 1, f"cannot read input: {error.strerror or error}"),)
        ) from error
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as error:
        line = raw[: error.start].count(b"\n") + 1
        raise LedgerSchemaError(
            (LedgerDiagnostic(str(path), line, "input is not valid UTF-8"),)
        ) from error
    return parse_ledger_text(text, str(path))


def render_ledger_json(entries: tuple[CapabilityEntry, ...]) -> str:
    document = {
        "schema_version": 1,
        "capabilities": [asdict(entry) for entry in entries],
    }
    return json.dumps(document, ensure_ascii=False, indent=2) + "\n"


def export_ledger_json(input_path: Path, output_path: Path) -> None:
    entries = parse_ledger_path(input_path)
    resolved_input = input_path.resolve()
    resolved_output = output_path.resolve()
    if resolved_input == resolved_output or (
        output_path.exists() and os.path.samefile(input_path, output_path)
    ):
        raise LedgerSchemaError(
            (LedgerDiagnostic(str(output_path), 1, "output must not alias the input ledger"),)
        )
    if not output_path.parent.is_dir():
        raise LedgerSchemaError(
            (LedgerDiagnostic(str(output_path), 1, "output directory must already exist"),)
        )

    rendered = render_ledger_json(entries)
    temporary_name: str | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            newline="\n",
            dir=output_path.parent,
            prefix=f".{output_path.name}.",
            suffix=".tmp",
            delete=False,
        ) as temporary:
            temporary_name = temporary.name
            temporary.write(rendered)
            temporary.flush()
            os.fsync(temporary.fileno())
        os.replace(temporary_name, output_path)
        temporary_name = None
    finally:
        if temporary_name is not None:
            try:
                os.unlink(temporary_name)
            except FileNotFoundError:
                pass


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    check = subparsers.add_parser("check", help="validate ledger schema")
    check.add_argument("input", nargs="?", type=Path, default=ROOT / "CAPABILITY_LEDGER.md")
    export = subparsers.add_parser("export-json", help="validate and atomically export JSON")
    export.add_argument("input", type=Path)
    export.add_argument("--output", required=True, type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        if args.command == "check":
            entries = parse_ledger_path(args.input)
            print(f"valid: {len(entries)} capability entries")
        else:
            export_ledger_json(args.input, args.output)
            print(f"exported: {args.output}")
    except LedgerSchemaError as error:
        for diagnostic in error.diagnostics:
            print(str(diagnostic), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
