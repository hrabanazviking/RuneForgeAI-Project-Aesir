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
        from ledger_schema import ROOT

        entries = parse_ledger_path(ROOT / "CAPABILITY_LEDGER.md")
        self.assertEqual(len(entries), 119)
        self.assertEqual(sum(len(item.extensions) for item in entries), 80)

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
