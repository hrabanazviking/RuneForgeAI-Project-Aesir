#!/usr/bin/env python3
"""Unit tests for repository-local Markdown link and anchor validation."""

from __future__ import annotations

import tempfile
import unittest
import json
import subprocess
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path

from markdown_links import (
    document_anchors,
    extract_links,
    heading_slugs,
    validate_links,
)
from check_markdown_links import main as checker_main


class MarkdownLinkTests(unittest.TestCase):
    def test_extracts_inline_reference_and_image_but_ignores_code_and_autolink(self) -> None:
        text = (
            "[inline](guide.md#start) ![image](assets/a.png)\n\n"
            "[reference][guide]\n\n[guide]: guide.md#start\n\n"
            "`[code](missing.md)` and https://example.test/path\n\n"
            "```md\n[block](missing.md)\n```\n"
        )
        links = extract_links("docs/source.md", text)
        self.assertEqual(
            [(item.destination, item.kind) for item in links],
            [
                ("guide.md#start", "link"),
                ("assets/a.png", "image"),
                ("guide.md#start", "link"),
            ],
        )

    def test_github_heading_slugs_markup_punctuation_unicode_and_duplicates(self) -> None:
        text = (
            "## **Hello, world!**\n"
            "## **Hello, world!**\n"
            "## foo  bar\n"
            "## Café — 漢字\n"
        )
        self.assertEqual(
            heading_slugs(text),
            ("hello-world", "hello-world-1", "foo-bar", "café--漢字"),
        )

    def test_explicit_html_anchors_are_preserved_exactly(self) -> None:
        text = '<a id="Exact.Name"></a>\n<span name=\'other-anchor\'></span>\n## Heading\n'
        self.assertEqual(
            document_anchors(text),
            frozenset({"Exact.Name", "other-anchor", "heading"}),
        )

    def test_relative_query_percent_escape_directory_and_fragment(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "docs" / "source.md"
            source.parent.mkdir()
            source.write_text("# Source\n", encoding="utf-8")
            target = source.parent / "A Guide.md"
            target.write_text("## Start Here\n", encoding="utf-8")
            directory = root / "assets"
            directory.mkdir()
            content = (
                "[relative](A%20Guide.md?view=1#start-here) "
                "[same](#source) [directory](../assets/)\n"
            )
            self.assertEqual(validate_links("docs/source.md", content, root), ())

    def test_external_destinations_are_not_fetched(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.assertEqual(
                validate_links(
                    "source.md",
                    "[web](https://example.test/a) [mail](mailto:a@example.test) <https://example.test>\n",
                    root,
                ),
                (),
            )

    def test_missing_target_anchor_and_directory_fragment_are_reported(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "source.md").write_text("# Source\n", encoding="utf-8")
            (root / "target.md").write_text("## Exists\n", encoding="utf-8")
            (root / "folder").mkdir()
            diagnostics = validate_links(
                "source.md",
                "[gone](missing.md) [fragment](target.md#absent) [dir](folder/#x)\n",
                root,
            )
            self.assertEqual(
                [item.message for item in diagnostics],
                [
                    "missing local target: missing.md",
                    "missing fragment anchor: target.md#absent",
                    "fragment target is a directory: folder/#x",
                ],
            )

    def test_repository_root_escape_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "repo"
            root.mkdir()
            outside = Path(temporary) / "outside.md"
            outside.write_text("# Outside\n", encoding="utf-8")
            (root / "source.md").write_text("# Source\n", encoding="utf-8")
            result = validate_links("source.md", "[escape](../outside.md)\n", root)
            self.assertEqual(len(result), 1)
            self.assertIn("destination escapes repository root", result[0].message)

    def test_empty_and_file_uri_destinations_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            diagnostics = validate_links(
                "source.md",
                "[empty]() [machine](file:///etc/passwd)\n",
                root,
            )
            self.assertEqual(
                [item.message for item in diagnostics],
                ["empty local destination: "],
            )

    def test_symlink_target_cannot_escape_repository_root(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            root = base / "repo"
            root.mkdir()
            (base / "outside.md").write_text("# Outside\n", encoding="utf-8")
            (root / "source.md").write_text("# Source\n", encoding="utf-8")
            (root / "outside-link.md").symlink_to(base / "outside.md")
            result = validate_links(
                "source.md", "[escape](outside-link.md#outside)\n", root
            )
            self.assertEqual(len(result), 1)
            self.assertIn("destination escapes repository root", result[0].message)

    def test_parser_ignored_incomplete_markdown_syntax_is_outside_scope(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            result = validate_links(
                "source.md", "[unfinished](missing.md\n", Path(temporary)
            )
            self.assertEqual(result, ())

    def test_non_markdown_file_can_be_linked_without_fragment(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "diagram.svg").write_text("<svg/>", encoding="utf-8")
            self.assertEqual(
                validate_links("source.md", "[diagram](diagram.svg)\n", root), ()
            )

    def test_repository_integration_accepts_only_hash_bound_baseline_issues(self) -> None:
        root = Path(__file__).resolve().parent.parent
        baseline = root / "docs/evidence/markdown-link-baseline-2026-10-10/link-census.json"
        stdout = StringIO()
        stderr = StringIO()
        with redirect_stdout(stdout), redirect_stderr(stderr):
            result = checker_main([
                "--check", "--root", str(root), "--baseline-json", str(baseline)
            ])
        self.assertEqual(result, 0)
        self.assertIn("9 unchanged baseline issue(s)", stdout.getvalue())
        self.assertEqual(stderr.getvalue().count("BASELINE:"), 9)
        self.assertNotIn("ERROR:", stderr.getvalue())

    def test_baseline_mode_rejects_new_issue_and_malformed_baseline(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "repo"
            root.mkdir()
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            source = root / "README.md"
            source.write_text("[new break](missing.md)\n", encoding="utf-8")
            subprocess.run(["git", "-C", str(root), "add", "README.md"], check=True)
            baseline = Path(temporary) / "baseline.json"
            baseline.write_text(json.dumps({"problems": []}), encoding="utf-8")
            stderr = StringIO()
            with redirect_stderr(stderr):
                result = checker_main([
                    "--check", "--root", str(root), "--baseline-json", str(baseline)
                ])
            self.assertEqual(result, 1)
            self.assertIn("ERROR: README.md:1: missing local target", stderr.getvalue())

            baseline.write_text("{invalid", encoding="utf-8")
            with redirect_stderr(stderr := StringIO()):
                result = checker_main([
                    "--check", "--root", str(root), "--baseline-json", str(baseline)
                ])
            self.assertEqual(result, 2)
            self.assertIn("ERROR: unable to load baseline", stderr.getvalue())

    def test_repository_scan_rejects_tracked_markdown_symlink_escape(self) -> None:
        from markdown_links import validate_repository

        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            root = base / "repo"
            root.mkdir()
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            outside = base / "outside.md"
            outside.write_text("[outside](https://example.test)\n", encoding="utf-8")
            (root / "README.md").symlink_to(outside)
            subprocess.run(["git", "-C", str(root), "add", "README.md"], check=True)
            diagnostics = validate_repository(root)
            self.assertEqual(len(diagnostics), 1)
            self.assertEqual(
                diagnostics[0].message,
                "Markdown source escapes or is unavailable outside repository root",
            )


if __name__ == "__main__":
    unittest.main()
