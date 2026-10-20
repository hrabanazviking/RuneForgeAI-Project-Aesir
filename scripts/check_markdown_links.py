#!/usr/bin/env python3
"""Validate local links and anchors in active tracked Markdown."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

from markdown_links import ROOT, validate_repository


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="validate the active tracked Markdown set")
    parser.add_argument("--root", type=Path, default=ROOT, help="repository root (defaults to this checkout)")
    parser.add_argument("--baseline-json", type=Path, help="report unchanged baseline findings separately")
    args = parser.parse_args(argv)
    diagnostics = validate_repository(args.root.resolve())
    baseline: Counter[tuple[str, str]] = Counter()
    if args.baseline_json is not None:
        try:
            payload = json.loads(args.baseline_json.read_text(encoding="utf-8"))
            problems = payload["problems"]
            if not isinstance(problems, list):
                raise ValueError("baseline problems must be a list")
            for problem in problems:
                if not isinstance(problem, dict):
                    raise ValueError("baseline problem must be an object")
                baseline[(problem["source"], f"{problem['problem']}: {problem['destination']}")] += 1
        except (OSError, UnicodeDecodeError, json.JSONDecodeError, KeyError, TypeError, ValueError) as error:
            print(f"ERROR: unable to load baseline: {error}", file=sys.stderr)
            return 2

    new_count = 0
    baseline_count = 0
    for diagnostic in diagnostics:
        key = (diagnostic.source, diagnostic.message)
        if baseline[key] > 0:
            baseline[key] -= 1
            baseline_count += 1
            print(f"BASELINE: {diagnostic}", file=sys.stderr)
        else:
            new_count += 1
            print(f"ERROR: {diagnostic}", file=sys.stderr)
    if new_count:
        print(f"FAILED: {new_count} new local Markdown link issue(s)", file=sys.stderr)
        return 1
    if baseline_count:
        print(f"PASSED: no new issues; {baseline_count} unchanged baseline issue(s)")
        return 0
    print("PASSED: all active tracked Markdown links resolve")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
