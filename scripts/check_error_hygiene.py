#!/usr/bin/env python3
"""Error-message hygiene gate for aesir_engine Mojo sources.

Fails closed when a string literal inside an Error(...) call:

  1. exceeds MAX_LITERAL_CHARS characters (raw characters between the quotes,
     escapes counted as written), or
  2. looks like an interpolated filesystem path or an echoed secret:
       - literal text containing "/home/", ".pem", ".key", "token=" or
         "password" (case-insensitive), or
       - string concatenation of a variable whose name contains "path",
         "file", "secret" or "token" directly inside the Error(...) call,
         e.g. Error("cannot open: " + path).  Detection: the Error(...) span
         contains `+` followed by an identifier.

Sites that are benign by construction are admitted through ALLOWLIST /
MARKER_ALLOWLIST below; every entry carries its documented reason.  A new
violation must either be fixed in the Mojo source (shorten the message /
drop the interpolation -- the set of raised errors never changes) or gain an
explicit allowlist entry.  Nothing passes silently.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENGINE = ROOT / "aesir_engine"

MAX_LITERAL_CHARS = 200

# Literal-text markers that smell like a leaked path or an echoed secret.
INTERPOLATION_MARKERS = ("/home/", ".pem", ".key", "token=", "password")

# Identifier-name fragments that smell like a path or a secret being
# concatenated into the message: Error("... " + path)
SENSITIVE_NAME_FRAGMENTS = ("path", "file", "secret", "token")

ERROR_CALL_RE = re.compile(r"Error\s*\(")
STRING_RE = re.compile(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'')
IDENT_AFTER_PLUS_RE = re.compile(r"\+\s*([A-Za-z_][A-Za-z0-9_]*)")
IDENTIFIER_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")

# (relative path, identifier) -> documented reason.  The identifier match is
# case-insensitive substring: "profile" matches because it contains "file".
ALLOWLIST: dict[tuple[str, str], str] = {
    ("aesir_engine/cli/commands.mojo", "token"):
        "CLI argv parsing loop variable holding the raw option token "
        "(e.g. '--foo'); never a credential.",
    ("aesir_engine/cli/doctor.mojo", "token"):
        "CLI argv parsing loop variable holding the raw option token; "
        "never a credential.",
    ("aesir_engine/cli/model_inspect.mojo", "token"):
        "CLI argv parsing loop variable holding the raw option token; "
        "never a credential.",
    ("aesir_engine/cli/conversation.mojo", "path"):
        "Echoes the user-supplied conversation snapshot path as a "
        "diagnostic; the caller chose the path.",
    ("aesir_engine/cli/cuda_chat.mojo", "path"):
        "Echoes the user-supplied transcript path as a diagnostic.",
    ("aesir_engine/cli/storage.mojo", "path"):
        "Echoes the user-supplied model catalog path as a diagnostic.",
    ("aesir_engine/config.mojo", "clean_path"):
        "Echoes the user-supplied configuration file path as a diagnostic.",
    ("aesir_engine/core/linux_cgroups.mojo", "path"):
        "Echoes the procfs/cgroup path being read as a diagnostic.",
    ("aesir_engine/core/dense_gqa_profile.mojo", "profile"):
        "Concatenation is profile.label(), a human-readable model profile "
        "name; flagged only because 'profile' contains the fragment 'file'.",
    ("aesir_engine/core/gemma4_profile.mojo", "profile"):
        "Concatenation is profile.label(), a human-readable model profile "
        "name; flagged only because 'profile' contains the fragment 'file'.",
    ("aesir_engine/tests/test_multi_engine.mojo", "path"):
        "Test diagnostic echoing the route path under test.",
}

# (relative path, marker) -> documented reason.
MARKER_ALLOWLIST: dict[tuple[str, str], str] = {
    ("aesir_engine/tests/test_packed_matrix.mojo", "token="):
        "Test diagnostic formats 'kind=..., token=<loop index>, ...'; "
        "'token' is a numeric loop counter, not a credential.",
}


def error_call_spans(text: str) -> list[tuple[int, str]]:
    """Return (1-based line number, argument text) for every Error(...) call.

    The scan is string- and escape-aware so parentheses inside message
    literals do not corrupt the argument span.
    """
    spans: list[tuple[int, str]] = []
    for match in ERROR_CALL_RE.finditer(text):
        depth = 1
        index = match.end()
        quote: str | None = None
        escaped = False
        while index < len(text) and depth:
            char = text[index]
            if escaped:
                escaped = False
            elif quote is not None:
                if char == "\\":
                    escaped = True
                elif char == quote:
                    quote = None
            elif char in ("'", '"'):
                quote = char
            elif char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
            index += 1
        line_no = text.count("\n", 0, match.start()) + 1
        spans.append((line_no, text[match.end() : index - 1]))
    return spans


def mask_strings(text: str) -> str:
    """Blank out string literals, preserving line breaks for line numbers."""
    def blank(match: re.Match[str]) -> str:
        return "".join("\n" if char == "\n" else " " for char in match.group(0))

    return STRING_RE.sub(blank, text)


def check_file(path: Path, errors: list[str]) -> tuple[int, int]:
    """Check one Mojo file; return (error_calls, literals_checked)."""
    relative = path.relative_to(ROOT).as_posix()
    text = path.read_text(encoding="utf-8")
    calls = 0
    literals = 0
    for line_no, arguments in error_call_spans(text):
        calls += 1
        for literal in STRING_RE.findall(arguments):
            literals += 1
            inner = literal[1:-1]
            if len(inner) > MAX_LITERAL_CHARS:
                errors.append(
                    f"{relative}:{line_no}: Error literal is {len(inner)} "
                    f"characters (limit {MAX_LITERAL_CHARS}): "
                    f"{inner[:60]!r}..."
                )
            lowered = inner.lower()
            for marker in INTERPOLATION_MARKERS:
                if (
                    marker in lowered
                    and (relative, marker) not in MARKER_ALLOWLIST
                ):
                    errors.append(
                        f"{relative}:{line_no}: Error literal contains "
                        f"{marker!r}; looks like an interpolated path or "
                        f"echoed secret: {inner[:80]!r}..."
                    )
        for identifier in IDENT_AFTER_PLUS_RE.findall(mask_strings(arguments)):
            lowered_ident = identifier.lower()
            if any(
                fragment in lowered_ident
                for fragment in SENSITIVE_NAME_FRAGMENTS
            ) and (relative, lowered_ident) not in ALLOWLIST:
                errors.append(
                    f"{relative}:{line_no}: Error concatenates "
                    f"+ {identifier}; looks like an interpolated path or "
                    f"echoed secret"
                )
    return calls, literals


def iter_mojo_files() -> list[Path]:
    return sorted(
        path
        for path in ENGINE.rglob("*.mojo")
        if path.is_file() and "/armvegr/" not in path.as_posix()
    )


def main() -> int:
    errors: list[str] = []
    files = iter_mojo_files()
    calls = 0
    literals = 0
    for path in files:
        file_calls, file_literals = check_file(path, errors)
        calls += file_calls
        literals += file_literals
    print(
        f"scanned {len(files)} .mojo files, {calls} Error(...) calls, "
        f"{literals} message literals"
    )
    if errors:
        print(f"FAILED: {len(errors)} error-hygiene violation(s)")
        for error in errors:
            print(f" - {error}")
        return 1
    print("PASSED: error-message hygiene (length, path/secret interpolation)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
