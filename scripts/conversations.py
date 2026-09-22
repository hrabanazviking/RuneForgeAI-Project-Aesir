#!/usr/bin/env python3
"""Manage a bounded named library of validated Aesir conversation snapshots."""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import stat
import sys
import tempfile
import unicodedata


MAX_SNAPSHOT = 16 * 1024 * 1024
MAX_ENTRIES = 4096
PROFILES = {"gemma4", "llama3", "qwen3"}


class LibraryError(ValueError):
    pass


def _read_regular(path: Path, maximum: int) -> bytes:
    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW)
    with os.fdopen(fd, "rb") as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_size <= 0 or info.st_size > maximum:
            raise LibraryError(f"file is not a bounded regular file: {path}")
        data = stream.read(maximum + 1)
    if len(data) > maximum:
        raise LibraryError(f"file exceeds {maximum} bytes: {path}")
    return data


def _fnv64(data: bytes) -> int:
    value = 14695981039346656037
    for byte in data:
        value = ((value ^ byte) * 1099511628211) & 0xFFFFFFFFFFFFFFFF
    return value


def _hex_text(value: str, label: str, maximum: int, *, empty: bool = True) -> str:
    if len(value) % 2 or any(character not in "0123456789abcdef" for character in value):
        raise LibraryError(f"snapshot {label} is not lowercase hexadecimal")
    try:
        decoded = bytes.fromhex(value).decode("utf-8")
    except (ValueError, UnicodeDecodeError) as error:
        raise LibraryError(f"snapshot {label} is not valid UTF-8") from error
    size = len(decoded.encode())
    if size > maximum or (not empty and size == 0) or "\0" in decoded:
        raise LibraryError(f"snapshot {label} is outside its byte bound")
    return decoded


def _decimal(value: str, label: str, maximum: int) -> int:
    if not value or not value.isascii() or not value.isdecimal():
        raise LibraryError(f"snapshot {label} is not an unsigned decimal")
    result = int(value)
    if result > maximum:
        raise LibraryError(f"snapshot {label} exceeds its bound")
    return result


def parse_snapshot(data: bytes) -> dict[str, object]:
    if len(data) == 0 or len(data) > MAX_SNAPSHOT or not data.endswith(b"\n"):
        raise LibraryError("snapshot must contain one complete bounded record")
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as error:
        raise LibraryError("snapshot is not valid UTF-8") from error
    lines = text.split("\n")
    if len(lines) < 11 or lines[0] != "AESIR_CONVERSATION_V1" or lines[-1] != "":
        raise LibraryError("snapshot header or line termination is invalid")
    expected = ("MODEL:", "PROFILE:", "CONTEXT:", "SYSTEM:", "SAMPLING:", "DRAWS:", "TOKENS:", "TURNS:")
    for index, prefix in enumerate(expected, start=1):
        if not lines[index].startswith(prefix):
            raise LibraryError("snapshot field order is invalid")
    turn_count = _decimal(lines[8][6:], "turn count", 1024)
    if len(lines) != 11 + 2 * turn_count:
        raise LibraryError("snapshot turn count does not match the record")
    checksum_index = 9 + 2 * turn_count
    if not lines[checksum_index].startswith("CHECKSUM:"):
        raise LibraryError("snapshot checksum field is missing")
    checksum = lines[checksum_index][9:]
    if len(checksum) != 16 or any(character not in "0123456789abcdef" for character in checksum):
        raise LibraryError("snapshot checksum is invalid")
    payload = ("\n".join(lines[:checksum_index]) + "\n").encode()
    if _fnv64(payload) != int(checksum, 16):
        raise LibraryError("snapshot checksum mismatch")
    model = _hex_text(lines[1][6:], "model", 4096, empty=False)
    profile = _hex_text(lines[2][8:], "profile", 64, empty=False)
    if profile not in PROFILES:
        raise LibraryError("snapshot profile is unsupported")
    context = _decimal(lines[3][8:], "context", 32768)
    if context < 2:
        raise LibraryError("snapshot context is below the native bound")
    system = _hex_text(lines[4][7:], "system", 65536)
    sampling = _hex_text(lines[5][9:], "sampling", 4096, empty=False)
    draws = _decimal(lines[6][6:], "sampler draws", 2147483647)
    tokens: list[int] = []
    token_text = lines[7][7:]
    if token_text:
        tokens = [_decimal(token, "token", 2147483647) for token in token_text.split(",")]
    if len(tokens) > context:
        raise LibraryError("snapshot token stream exceeds its context")
    turns: list[tuple[str, str]] = []
    for index in range(turn_count):
        user_line, assistant_line = lines[9 + 2 * index], lines[10 + 2 * index]
        if not user_line.startswith("USER:") or not assistant_line.startswith("ASSISTANT:"):
            raise LibraryError("snapshot turn field order is invalid")
        user = _hex_text(user_line[5:], "user turn", 65536, empty=False)
        assistant = _hex_text(assistant_line[10:], "assistant turn", 1024 * 1024)
        turns.append((user, assistant))
    if turns and not tokens:
        raise LibraryError("snapshot turns have no exact token stream")
    return {
        "model": model, "profile": profile, "context": context,
        "system": system, "sampling": sampling, "draws": draws,
        "token_count": len(tokens), "turn_count": turn_count, "turns": turns,
    }


def _name(value: str) -> str:
    normalized = unicodedata.normalize("NFC", value)
    encoded = normalized.encode("utf-8")
    if not encoded or len(encoded) > 128 or any(unicodedata.category(character).startswith("C") for character in normalized):
        raise LibraryError("conversation name must contain 1..128 UTF-8 bytes without control characters")
    return normalized


def _fsync_directory(path: Path) -> None:
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def _write_new(path: Path, data: bytes) -> None:
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "wb") as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())


def _write_atomic(path: Path, data: bytes) -> None:
    fd, temporary = tempfile.mkstemp(prefix=".metadata-", dir=path.parent)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        _fsync_directory(path.parent)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def _metadata(entry_id: str, name: str, snapshot: bytes, parsed: dict[str, object]) -> dict[str, object]:
    return {
        "schema": 1, "id": entry_id, "name": name,
        "snapshot_sha256": hashlib.sha256(snapshot).hexdigest(),
        "model": parsed["model"], "profile": parsed["profile"],
        "context": parsed["context"], "turn_count": parsed["turn_count"],
        "token_count": parsed["token_count"],
    }


class Library:
    def __init__(self, root: Path):
        self.root = root
        self.items = root / "items"
        root.mkdir(parents=True, exist_ok=True)
        self.items.mkdir(mode=0o700, exist_ok=True)

    def locked(self):
        fd = os.open(self.root / "library.lock", os.O_RDWR | os.O_CREAT | os.O_CLOEXEC, 0o600)
        fcntl.flock(fd, fcntl.LOCK_EX)
        return os.fdopen(fd, "rb+")

    def entries(self) -> list[dict[str, object]]:
        results: list[dict[str, object]] = []
        for child in sorted(self.items.iterdir(), key=lambda path: path.name):
            if child.name.startswith(".stage-"):
                continue
            if len(child.name) != 32 or any(c not in "0123456789abcdef" for c in child.name) or child.is_symlink() or not child.is_dir():
                raise LibraryError(f"library contains an invalid entry: {child.name}")
            try:
                metadata = json.loads(_read_regular(child / "metadata.json", 65536))
            except (json.JSONDecodeError, UnicodeDecodeError) as error:
                raise LibraryError(f"conversation {child.name} metadata is corrupt") from error
            expected_keys = {"schema", "id", "name", "snapshot_sha256", "model", "profile", "context", "turn_count", "token_count"}
            if not isinstance(metadata, dict) or set(metadata) != expected_keys or metadata.get("schema") != 1 or metadata.get("id") != child.name:
                raise LibraryError(f"conversation {child.name} metadata schema is invalid")
            text_fields = ("id", "name", "snapshot_sha256", "model", "profile")
            count_fields = ("schema", "context", "turn_count", "token_count")
            if any(not isinstance(metadata[field], str) for field in text_fields) or any(type(metadata[field]) is not int for field in count_fields):
                raise LibraryError(f"conversation {child.name} metadata types are invalid")
            metadata["name"] = _name(metadata["name"])
            snapshot = _read_regular(child / "snapshot.aesir", MAX_SNAPSHOT)
            parsed = parse_snapshot(snapshot)
            expected = _metadata(child.name, str(metadata["name"]), snapshot, parsed)
            if metadata != expected:
                raise LibraryError(f"conversation {metadata['name']} metadata does not match its snapshot")
            metadata["snapshot_path"] = str(child / "snapshot.aesir")
            results.append(metadata)
            if len(results) > MAX_ENTRIES:
                raise LibraryError("conversation library exceeds 4096 entries")
        names = [str(entry["name"]) for entry in results]
        if len(names) != len(set(names)):
            raise LibraryError("conversation library contains duplicate names")
        return sorted(results, key=lambda entry: str(entry["name"]))

    def find(self, name: str) -> dict[str, object]:
        wanted = _name(name)
        matches = [entry for entry in self.entries() if entry["name"] == wanted]
        if not matches:
            raise LibraryError(f"conversation not found: {wanted}")
        return matches[0]


def command_save(library: Library, name: str, source: Path) -> None:
    normalized = _name(name)
    snapshot = _read_regular(source, MAX_SNAPSHOT)
    parsed = parse_snapshot(snapshot)
    with library.locked():
        entries = library.entries()
        if len(entries) >= MAX_ENTRIES:
            raise LibraryError("conversation library has reached 4096 entries")
        if any(entry["name"] == normalized for entry in entries):
            raise LibraryError(f"conversation already exists: {normalized}")
        entry_id = secrets.token_hex(16)
        stage = Path(tempfile.mkdtemp(prefix=".stage-", dir=library.items))
        final = library.items / entry_id
        try:
            os.chmod(stage, 0o700)
            _write_new(stage / "snapshot.aesir", snapshot)
            metadata = _metadata(entry_id, normalized, snapshot, parsed)
            _write_new(stage / "metadata.json", (json.dumps(metadata, ensure_ascii=False, sort_keys=True) + "\n").encode())
            _fsync_directory(stage)
            os.rename(stage, final)
            _fsync_directory(library.items)
        finally:
            if stage.exists():
                shutil.rmtree(stage)
    print(f"Saved conversation: {normalized}")


def command_rename(library: Library, old: str, new: str) -> None:
    replacement = _name(new)
    with library.locked():
        entries = library.entries()
        current = next((entry for entry in entries if entry["name"] == _name(old)), None)
        if current is None:
            raise LibraryError(f"conversation not found: {_name(old)}")
        if any(entry["name"] == replacement for entry in entries):
            raise LibraryError(f"conversation already exists: {replacement}")
        current.pop("snapshot_path")
        current["name"] = replacement
        path = library.items / str(current["id"]) / "metadata.json"
        _write_atomic(path, (json.dumps(current, ensure_ascii=False, sort_keys=True) + "\n").encode())
    print(f"Renamed conversation: {old} -> {replacement}")


def command_open(library: Library, options: argparse.Namespace) -> None:
    with library.locked():
        entry = library.find(options.name)
    for key, expected in (("model", options.expect_model), ("profile", options.expect_profile), ("context", options.expect_context)):
        if expected is not None and entry[key] != expected:
            raise LibraryError(f"conversation {entry['name']} has incompatible {key}")
    print(json.dumps(entry, ensure_ascii=False, sort_keys=True))


def command_export(library: Library, name: str, output: Path) -> None:
    with library.locked():
        entry = library.find(name)
        snapshot = _read_regular(Path(str(entry["snapshot_path"])), MAX_SNAPSHOT)
        parsed = parse_snapshot(snapshot)
    lines = ["# Aesir conversation export", "", f"Name: {entry['name']}", "", f"Model: {entry['model']}", "", f"Profile: {entry['profile']}", ""]
    for index, (user, assistant) in enumerate(parsed["turns"], start=1):
        lines.extend([f"## Turn {index}", "", f"User: {user}", "", f"Assistant: {assistant}", ""])
    _write_new(output, ("\n".join(lines) + "\n").encode())
    _fsync_directory(output.parent if output.parent != Path("") else Path("."))
    print(f"Exported conversation: {entry['name']} -> {output}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--library", default=".aesir/conversations", help="conversation library directory")
    commands = parser.add_subparsers(dest="command", required=True)
    save = commands.add_parser("save")
    save.add_argument("name")
    save.add_argument("--snapshot", required=True)
    commands.add_parser("list")
    opened = commands.add_parser("open")
    opened.add_argument("name")
    opened.add_argument("--expect-model")
    opened.add_argument("--expect-profile")
    opened.add_argument("--expect-context", type=int)
    rename = commands.add_parser("rename")
    rename.add_argument("old")
    rename.add_argument("new")
    export = commands.add_parser("export")
    export.add_argument("name")
    export.add_argument("--output", required=True)
    options = parser.parse_args()
    try:
        library = Library(Path(options.library))
        if options.command == "save":
            command_save(library, options.name, Path(options.snapshot))
        elif options.command == "list":
            with library.locked():
                print(json.dumps(library.entries(), ensure_ascii=False, sort_keys=True))
        elif options.command == "open":
            command_open(library, options)
        elif options.command == "rename":
            command_rename(library, options.old, options.new)
        else:
            command_export(library, options.name, Path(options.output))
        return 0
    except (OSError, LibraryError) as error:
        print(f"Aesir conversation library: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
