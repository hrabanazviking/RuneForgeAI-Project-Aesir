#!/usr/bin/env python3
"""Read-only baseline census for tracked active Markdown link destinations."""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
from collections import Counter
from pathlib import Path
from urllib.parse import unquote, urlsplit

from markdown_it import MarkdownIt, __version__ as MARKDOWN_IT_VERSION


ROOT = Path(__file__).resolve().parent.parent
EXCLUDED_PREFIXES = ("docs/evidence/", "docs/historical/")
HEADING_PUNCTUATION = re.compile(r"[^\w\- ]", re.UNICODE)
WHITESPACE = re.compile(r"\s+")


def tracked_markdown() -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", "-z", "--", "*.md"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    )
    paths = [item.decode("utf-8") for item in result.stdout.split(b"\0") if item]
    return [
        path for path in paths
        if (len(Path(path).parts) == 1 or Path(path).parts[0] in {"docs", "aesir_engine"})
        and not path.startswith(EXCLUDED_PREFIXES)
    ]


def all_tracked_markdown() -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", "-z", "--", "*.md"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    )
    return [item.decode("utf-8") for item in result.stdout.split(b"\0") if item]


def file_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def heading_slug(text: str) -> str:
    text = re.sub(r"`([^`]*)`", r"\1", text)
    text = HEADING_PUNCTUATION.sub("", text.lower())
    return WHITESPACE.sub("-", text.strip())


def anchors_for(source: str, parser: MarkdownIt) -> set[str]:
    tokens = parser.parse(source)
    anchors: set[str] = set()
    counts: Counter[str] = Counter()
    for index, token in enumerate(tokens):
        if token.type == "heading_open" and index + 1 < len(tokens):
            content = tokens[index + 1].content
            slug = heading_slug(content)
            count = counts[slug]
            counts[slug] += 1
            anchors.add(slug if count == 0 else f"{slug}-{count}")
        if token.type == "inline":
            for child in token.children or []:
                if child.type == "html_inline":
                    anchors.update(re.findall(r"\b(?:id|name)\s*=\s*['\"]([^'\"]+)['\"]", child.content, re.I))
    return anchors


def source_line(block_start: int, token_content: str, source: str) -> int:
    if not token_content:
        return block_start
    lines = source.splitlines()
    needle = token_content
    for index in range(max(0, block_start - 1), min(len(lines), block_start + 8)):
        if needle in lines[index]:
            return index + 1
    return block_start


def census() -> dict[str, object]:
    parser = MarkdownIt("commonmark")
    paths = tracked_markdown()
    contents = {name: (ROOT / name).read_text(encoding="utf-8") for name in paths}
    anchor_contents = {name: (ROOT / name).read_text(encoding="utf-8") for name in all_tracked_markdown()}
    anchors = {name: anchors_for(source, parser) for name, source in anchor_contents.items()}
    records: list[dict[str, object]] = []
    for name in paths:
        source = contents[name]
        for block in parser.parse(source):
            if block.type != "inline":
                continue
            for child in block.children or []:
                if child.type not in {"link_open", "image"}:
                    continue
                if child.type == "link_open" and child.markup == "autolink":
                    continue
                destination = child.attrGet("href" if child.type == "link_open" else "src") or ""
                split = urlsplit(destination)
                line = block.map[0] + 1 if block.map else source_line(1, destination, source)
                record: dict[str, object] = {
                    "source": name,
                    "line": line,
                    "kind": "image" if child.type == "image" else "link",
                    "destination": destination,
                    "classification": "local",
                    "problem": None,
                }
                if split.scheme or destination.startswith("//"):
                    record["classification"] = "external"
                elif not destination:
                    record["problem"] = "empty destination"
                else:
                    raw_path = unquote(split.path)
                    target = (ROOT / name).parent / raw_path if raw_path else ROOT / name
                    try:
                        resolved = target.resolve(strict=False)
                        resolved.relative_to(ROOT)
                    except (OSError, ValueError):
                        record["problem"] = "target escapes repository root"
                    else:
                        if not target.exists():
                            record["problem"] = "missing local target"
                        elif target.is_dir() and split.fragment:
                            record["problem"] = "fragment target is a directory"
                        elif split.fragment:
                            if not target.is_file():
                                record["problem"] = "fragment target is not a file"
                                records.append(record)
                                continue
                            target_name = target.relative_to(ROOT).as_posix()
                            target_anchors = anchors.get(target_name)
                            if target_anchors is None:
                                record["problem"] = "fragment target is not tracked Markdown"
                            elif unquote(split.fragment) not in target_anchors:
                                record["problem"] = "missing fragment anchor"
                records.append(record)
    return {
        "baseline_schema_version": 1,
        "parser": {"name": "markdown-it-py", "version": MARKDOWN_IT_VERSION, "preset": "commonmark"},
        "source_selection": "tracked root/docs/aesir_engine Markdown excluding docs/evidence and docs/historical",
        "files": [{"path": name, "sha256": file_hash(ROOT / name)} for name in paths],
        "file_count": len(paths),
        "link_count": len(records),
        "classification_counts": dict(sorted(Counter(str(item["classification"]) for item in records).items())),
        "kind_counts": dict(sorted(Counter(str(item["kind"]) for item in records).items())),
        "problem_counts": dict(sorted(Counter(str(item["problem"]) for item in records if item["problem"]).items())),
        "problems": [item for item in records if item["problem"]],
        "links": records,
    }


def main() -> None:
    print(json.dumps(census(), ensure_ascii=False, indent=2) + "\n", end="")


if __name__ == "__main__":
    main()
