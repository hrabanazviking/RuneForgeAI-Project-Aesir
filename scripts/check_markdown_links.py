#!/usr/bin/env python3
"""Validate local links and anchors in active tracked Markdown."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from markdown_links import ROOT, validate_repository


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="validate the active tracked Markdown set")
    parser.add_argument("--root", type=Path, default=ROOT, help="repository root (defaults to this checkout)")
    args = parser.parse_args(argv)
    diagnostics = validate_repository(args.root.resolve())
    for diagnostic in diagnostics:
        print(str(diagnostic), file=sys.stderr)
    if diagnostics:
        print(f"FAILED: {len(diagnostics)} local Markdown link issue(s)", file=sys.stderr)
        return 1
    print("PASSED: all active tracked Markdown links resolve")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
