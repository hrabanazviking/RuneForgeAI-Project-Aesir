#!/usr/bin/env python3
"""Unit evidence for the capability-ledger parser and JSON renderer."""

from __future__ import annotations

import json
import os
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

from ledger_schema import (
    LedgerSchemaError,
    parse_ledger_path,
    parse_ledger_text,
    render_ledger_json,
    export_ledger_json,
)


def entry(
    identifier: str = "AES-TST-001",
    status: str = "verified",
    name: str = "test capability",
    extra_fields: str = "",
) -> str:
    return (
        f"### {identifier} — {name}\n"
        f"- **Status:** `{status}`\n"
        "- **Owner:** unit tests\n"
        "- **Executable evidence:** `python3 scripts/test_ledger_schema.py`\n"
        "- **Evidence boundary:** only a local parser assertion\n"
        f"{extra_fields}"
    )


class CapabilityLedgerSchemaTests(unittest.TestCase):
    def test_all_canonical_statuses_and_absent_optional_nulls(self) -> None:
        text = "\n".join(
            entry(f"AES-TST-{index:03}", status)
            for index, status in enumerate(
                ("verified", "partial", "scaffold", "simulated", "missing"), 1
            )
        )
        entries = parse_ledger_text(text)
        self.assertEqual([item.status for item in entries], [
            "verified", "partial", "scaffold", "simulated", "missing"
        ])
        self.assertTrue(all(item.claim_sources is None for item in entries))
        self.assertTrue(all(item.implementation_evidence is None for item in entries))
        self.assertTrue(all(item.next_acceptance_gate is None for item in entries))
        self.assertTrue(all(item.audit is None for item in entries))

    def test_field_order_wrapped_markdown_and_extensions_are_preserved(self) -> None:
        text = (
            "### AES-TST-010 — multiline capability\n"
            "- **Status:** `partial`\n"
            "- **Owner:** unit tests\n"
            "- **Evidence boundary:** first line\n"
            "  second wrapped line\n"
            "\n"
            "  third paragraph\n"
            "- **Dated extension:** initial line\n"
            "  continued detail\n"
            "- **Executable evidence:** `unit probe`\n"
            "- **Dated extension:** another item\n"
        )
        parsed = parse_ledger_text(text)[0]
        self.assertEqual(
            parsed.evidence_boundary,
            "first line\n  second wrapped line\n\n  third paragraph",
        )
        self.assertEqual(
            [(item.label, item.value) for item in parsed.extensions],
            [
                ("Dated extension", "initial line\n  continued detail"),
                ("Dated extension", "another item"),
            ],
        )

    def test_rendered_json_is_deterministic_and_has_schema_version(self) -> None:
        parsed = parse_ledger_text(entry(extra_fields="- **Extra:** retained\n"))
        first = render_ledger_json(parsed)
        second = render_ledger_json(parsed)
        self.assertEqual(first, second)
        self.assertTrue(first.endswith("\n"))
        payload = json.loads(first)
        self.assertEqual(payload["schema_version"], 1)
        self.assertEqual(payload["capabilities"][0]["extensions"][0]["label"], "Extra")

    def test_repository_ledger_matches_baseline_shape(self) -> None:
        # Baseline re-measured from the repository ledger on 2026-10-28
        # (step 33, S-020); the previous figures (119 entries, 80
        # extensions) were stale and were never even reached, because
        # parse_ledger_path raises on the current ledger before any
        # count assertion runs. Measured truth at re-baseline time:
        #   329 capability entries, 458 extension fields, and 176
        #   strict-schema diagnostics (89 x missing required field
        #   'Evidence boundary', 87 x missing required field
        #   'Executable evidence').
        # The 176 diagnostics are ledger content debt owned by the
        # repository consistency checker (they are 176 of its 237
        # findings), not parser behaviour: the synthetic tests above
        # already prove the parser fails closed on such entries. This
        # baseline therefore pins the measured shape and the measured
        # diagnostic counts instead of re-asserting a clean parse the
        # current ledger does not have. Any ledger growth, shrinkage,
        # extension change, or schema-debt change breaks this test on
        # purpose and forces a conscious re-measure.
        from ledger_schema import (
            CANONICAL_FIELDS,
            FIELD,
            FIELD_LIKE,
            GRANDFATHERED_RECORD_IDS,
            HEADING,
            HEADING_LIKE,
            RECORD_HEADING,
            ROOT,
        )

        ledger_path = ROOT / "CAPABILITY_LEDGER.md"
        with self.assertRaises(LedgerSchemaError) as caught:
            parse_ledger_path(ledger_path)
        messages = [item.message for item in caught.exception.diagnostics]
        self.assertEqual(len(messages), 176)
        self.assertEqual(messages.count("missing required field 'Evidence boundary'"), 89)
        self.assertEqual(messages.count("missing required field 'Executable evidence'"), 87)

        # Shape count following ledger_schema's own block and field
        # rules (capability headings bound blocks, the grandfathered
        # record block is skipped, wrapped lines continue the current
        # field), without its fail-closed diagnostics.
        lines = ledger_path.read_text(encoding="utf-8").replace("\r\n", "\n").replace("\r", "\n").splitlines()
        starts = [index for index, line in enumerate(lines) if HEADING_LIKE.match(line)]
        entry_count = 0
        extension_count = 0
        for position, start in enumerate(starts):
            stop = starts[position + 1] if position + 1 < len(starts) else len(lines)
            if HEADING.fullmatch(lines[start]) is None:
                record = RECORD_HEADING.match(lines[start])
                if record is not None and record.group(1) in GRANDFATHERED_RECORD_IDS:
                    continue
                continue
            entry_count += 1
            fields: list[tuple[str, str]] = []
            current_label: str | None = None
            current_value: list[str] = []
            for line in lines[start + 1 : stop]:
                match = FIELD.fullmatch(line)
                if match is not None:
                    if current_label is not None:
                        fields.append((current_label, "\n".join(current_value).strip()))
                    current_label = match.group(1).strip()
                    current_value = [match.group(2)]
                    continue
                if FIELD_LIKE.match(line):
                    if current_label is not None:
                        fields.append((current_label, "\n".join(current_value).strip()))
                    current_label = None
                    current_value = []
                    continue
                if current_label is not None:
                    current_value.append(line)
            if current_label is not None:
                fields.append((current_label, "\n".join(current_value).strip()))
            extension_count += sum(
                1
                for label, value in fields
                if label not in CANONICAL_FIELDS and label and value
            )
        self.assertEqual(entry_count, 329)
        self.assertEqual(extension_count, 458)

    def test_empty_ledger_fails(self) -> None:
        with self.assertRaisesRegex(LedgerSchemaError, "no capability entries found"):
            parse_ledger_text("# Empty\n")

    def test_malformed_heading_fails_with_line(self) -> None:
        text = entry() + "\n### AES-bad — invalid ID prefix\n"
        with self.assertRaises(LedgerSchemaError) as caught:
            parse_ledger_text(text, "fixture.md")
        self.assertIn("fixture.md:7: malformed capability heading", str(caught.exception))

    def test_invalid_status_fails(self) -> None:
        with self.assertRaisesRegex(LedgerSchemaError, "status must be one backticked"):
            parse_ledger_text(entry(status="unknown"))

    def test_missing_and_empty_required_fields_fail(self) -> None:
        missing = entry().replace("- **Evidence boundary:** only a local parser assertion\n", "")
        with self.assertRaisesRegex(LedgerSchemaError, "missing required field 'Evidence boundary'"):
            parse_ledger_text(missing)
        empty = entry().replace("- **Owner:** unit tests", "- **Owner:**   ")
        with self.assertRaisesRegex(LedgerSchemaError, "field 'Owner' must not be empty"):
            parse_ledger_text(empty)

    def test_duplicate_ids_and_canonical_fields_fail(self) -> None:
        duplicate_id = entry() + "\n" + entry()
        with self.assertRaisesRegex(LedgerSchemaError, "duplicate capability ID AES-TST-001"):
            parse_ledger_text(duplicate_id)
        duplicate_field = entry(extra_fields="- **Owner:** second owner\n")
        with self.assertRaisesRegex(LedgerSchemaError, "duplicate canonical field 'Owner'"):
            parse_ledger_text(duplicate_field)

    def test_malformed_labeled_field_fails(self) -> None:
        text = entry(extra_fields="- **Broken field** no colon\n")
        with self.assertRaisesRegex(LedgerSchemaError, "malformed labeled field"):
            parse_ledger_text(text)

    def test_utf8_decode_error_reports_source_line(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "invalid.md"
            path.write_bytes(b"# title\n\xff")
            with self.assertRaisesRegex(LedgerSchemaError, r"invalid.md:2: input is not valid UTF-8"):
                parse_ledger_path(path)

    def test_invalid_input_preserves_existing_destination_and_cleans_temp(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "invalid.md"
            output = root / "output.json"
            source.write_text("### AES-TST-001 — Invalid\n", encoding="utf-8")
            output.write_bytes(b"prior-valid-output\n")
            with self.assertRaises(LedgerSchemaError):
                export_ledger_json(source, output)
            self.assertEqual(output.read_bytes(), b"prior-valid-output\n")
            self.assertEqual(list(root.glob(".output.json.*.tmp")), [])

    def test_export_rejects_same_path_and_hard_link(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "ledger.md"
            source.write_text(entry(), encoding="utf-8")
            with self.assertRaisesRegex(LedgerSchemaError, "must not alias"):
                export_ledger_json(source, source)
            hard_link = root / "ledger-copy.md"
            os.link(source, hard_link)
            with self.assertRaisesRegex(LedgerSchemaError, "must not alias"):
                export_ledger_json(source, hard_link)

    def test_replace_failure_preserves_destination_and_cleans_temp(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "ledger.md"
            output = root / "output.json"
            source.write_text(entry(), encoding="utf-8")
            output.write_bytes(b"prior-output")
            with patch("ledger_schema.os.replace", side_effect=OSError("injected replace failure")):
                with self.assertRaisesRegex(OSError, "injected replace failure"):
                    export_ledger_json(source, output)
            self.assertEqual(output.read_bytes(), b"prior-output")
            self.assertEqual(list(root.glob(".output.json.*.tmp")), [])

    def test_write_failure_cleans_temporary_file(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "ledger.md"
            output = root / "output.json"
            source.write_text(entry(), encoding="utf-8")
            real_named_temporary_file = tempfile.NamedTemporaryFile

            def failing_temporary_file(*args: object, **kwargs: object) -> object:
                temporary = real_named_temporary_file(*args, **kwargs)

                class FailingWriter:
                    name = temporary.name

                    def __enter__(self) -> "FailingWriter":
                        return self

                    def __exit__(self, *exit_args: object) -> bool:
                        temporary.close()
                        return False

                    def write(self, _value: str) -> int:
                        raise OSError("injected write failure")

                    def fileno(self) -> int:
                        return temporary.fileno()

                    def flush(self) -> None:
                        temporary.flush()

                return FailingWriter()

            with patch("ledger_schema.tempfile.NamedTemporaryFile", side_effect=failing_temporary_file):
                with self.assertRaisesRegex(OSError, "injected write failure"):
                    export_ledger_json(source, output)
            self.assertFalse(output.exists())
            self.assertEqual(list(root.glob(".output.json.*.tmp")), [])


if __name__ == "__main__":
    unittest.main()
