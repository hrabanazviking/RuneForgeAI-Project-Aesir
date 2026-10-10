"""Read-only validation of repository-local links in tracked Markdown."""

from __future__ import annotations

import html
import re
import subprocess
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import unquote, urlsplit

from markdown_it import MarkdownIt


ROOT = Path(__file__).resolve().parent.parent
EXCLUDED_PREFIXES = ("docs/evidence/", "docs/historical/")
PARSER = MarkdownIt("commonmark")
ANCHOR_ATTRIBUTE = re.compile(r"\b(?:id|name)\s*=\s*(['\"])(.*?)\1", re.I)


@dataclass(frozen=True)
class MarkdownLink:
    source: str
    line: int
    destination: str
    kind: str


@dataclass(frozen=True)
class MarkdownLinkDiagnostic:
    source: str
    line: int
    message: str

    def __str__(self) -> str:
        return f"{self.source}:{self.line}: {self.message}"


def tracked_markdown_paths(root: Path = ROOT) -> tuple[str, ...]:
    result = subprocess.run(
        ["git", "ls-files", "-z", "--", "*.md"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    paths = [item.decode("utf-8") for item in result.stdout.split(b"\0") if item]
    selected = [
        path for path in paths
        if (len(Path(path).parts) == 1 or Path(path).parts[0] in {"docs", "aesir_engine"})
        and not path.startswith(EXCLUDED_PREFIXES)
    ]
    return tuple(sorted(selected))


def _inline_text(children: list[object]) -> str:
    return "".join(
        child.content
        for child in children
        if child.type in {"text", "code_inline", "image"}
    )


def heading_slugs(text: str) -> tuple[str, ...]:
    """Return GitHub-style slugs for Markdown headings, including duplicates."""
    counts: dict[str, int] = {}
    slugs: list[str] = []
    tokens = PARSER.parse(text)
    for token_index, token in enumerate(tokens):
        if token.type != "heading_open":
            continue
        inline = tokens[token_index + 1]
        # GitHub collapses a run of spaces to one anchor separator. Normalize
        # the run before punctuation filtering so adjacent spaces never create
        # repeated hyphens.
        heading = re.sub(r" +", " ", _inline_text(inline.children or []).strip()).lower()
        base = "".join(
            "-" if character == " " else character
            for character in heading
            if character in {" ", "-"}
            or unicodedata.category(character)[0] in {"L", "M", "N"}
            or unicodedata.category(character) == "Pc"
        )
        occurrence = counts.get(base, 0)
        counts[base] = occurrence + 1
        slugs.append(base if occurrence == 0 else f"{base}-{occurrence}")
    return tuple(slugs)


def explicit_anchors(text: str) -> frozenset[str]:
    anchors: set[str] = set()
    for token in PARSER.parse(text):
        candidates = [token.content] if token.type == "html_block" else []
        if token.type == "inline":
            candidates.extend(
                child.content
                for child in token.children or []
                if child.type == "html_inline"
            )
        for candidate in candidates:
            anchors.update(
                html.unescape(match.group(2))
                for match in ANCHOR_ATTRIBUTE.finditer(candidate)
            )
    return frozenset(anchors)


def document_anchors(text: str) -> frozenset[str]:
    return frozenset((*heading_slugs(text), *explicit_anchors(text)))


def extract_links(source: str, text: str) -> tuple[MarkdownLink, ...]:
    links: list[MarkdownLink] = []
    for block in PARSER.parse(text):
        if block.type != "inline":
            continue
        for token in block.children or []:
            if token.type == "link_open" and token.markup == "autolink":
                continue
            if token.type not in {"link_open", "image"}:
                continue
            key = "href" if token.type == "link_open" else "src"
            destination = token.attrGet(key) or ""
            line = block.map[0] + 1 if block.map else 1
            links.append(
                MarkdownLink(
                    source,
                    line,
                    destination,
                    "image" if token.type == "image" else "link",
                )
            )
    return tuple(links)


def _local_target(source: str, destination: str, root: Path) -> tuple[Path | None, str, str | None]:
    if not destination:
        return None, "", "empty local destination"
    try:
        split = urlsplit(destination)
    except ValueError:
        return None, "", "malformed destination"
    if split.scheme and split.scheme.lower() != "file":
        return None, "", None
    if destination.startswith("//"):
        return None, "", None
    if split.scheme.lower() == "file":
        return None, "", "file URI is not a repository-relative destination"
    decoded_path = unquote(split.path)
    decoded_fragment = unquote(split.fragment)
    source_path = root / source
    raw_target = source_path.parent / decoded_path if decoded_path else source_path
    try:
        resolved = raw_target.resolve(strict=False)
        resolved.relative_to(root.resolve())
    except (OSError, ValueError):
        return None, decoded_fragment, "destination escapes repository root"
    return raw_target, decoded_fragment, None


def validate_links(
    source: str,
    text: str,
    root: Path = ROOT,
    anchor_cache: dict[str, frozenset[str]] | None = None,
) -> tuple[MarkdownLinkDiagnostic, ...]:
    if anchor_cache is None:
        anchor_cache = {}
    diagnostics: list[MarkdownLinkDiagnostic] = []
    for link in extract_links(source, text):
        target, fragment, error = _local_target(source, link.destination, root)
        if error is not None:
            diagnostics.append(MarkdownLinkDiagnostic(source, link.line, f"{error}: {link.destination}"))
            continue
        if target is None:
            continue
        if not target.exists():
            diagnostics.append(MarkdownLinkDiagnostic(source, link.line, f"missing local target: {link.destination}"))
            continue
        if not fragment:
            continue
        if target.is_dir():
            diagnostics.append(MarkdownLinkDiagnostic(source, link.line, f"fragment target is a directory: {link.destination}"))
            continue
        if not target.is_file():
            diagnostics.append(MarkdownLinkDiagnostic(source, link.line, f"fragment target is not a file: {link.destination}"))
            continue
        target_name = target.resolve().relative_to(root.resolve()).as_posix()
        if not target_name.lower().endswith(".md"):
            diagnostics.append(MarkdownLinkDiagnostic(source, link.line, f"fragment target is not Markdown: {link.destination}"))
            continue
        if target_name not in anchor_cache:
            try:
                anchor_cache[target_name] = document_anchors(target.read_text(encoding="utf-8"))
            except (OSError, UnicodeDecodeError):
                diagnostics.append(MarkdownLinkDiagnostic(source, link.line, f"unable to read fragment target: {link.destination}"))
                continue
        if fragment not in anchor_cache[target_name]:
            diagnostics.append(MarkdownLinkDiagnostic(source, link.line, f"missing fragment anchor: {link.destination}"))
    return tuple(diagnostics)


def validate_repository(root: Path = ROOT) -> tuple[MarkdownLinkDiagnostic, ...]:
    paths = tracked_markdown_paths(root)
    anchor_cache: dict[str, frozenset[str]] = {}
    diagnostics: list[MarkdownLinkDiagnostic] = []
    for source in paths:
        source_path = root / source
        try:
            source_path.resolve(strict=True).relative_to(root.resolve())
        except (OSError, ValueError):
            diagnostics.append(
                MarkdownLinkDiagnostic(source, 1, "Markdown source escapes or is unavailable outside repository root")
            )
            continue
        try:
            text = source_path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            diagnostics.append(MarkdownLinkDiagnostic(source, 1, "unable to read Markdown source"))
            continue
        diagnostics.extend(validate_links(source, text, root, anchor_cache))
    return tuple(diagnostics)
