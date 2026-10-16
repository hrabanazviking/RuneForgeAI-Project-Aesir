#!/usr/bin/env python3
"""Opt-in physical CUDA chat PTY smoke for S33b history and help."""

import argparse
import fcntl
import os
from pathlib import Path
import select
import struct
import subprocess
import termios
import tempfile
import time


def size(fd, columns):
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 24, columns, 0, 0))


def read_until(fd, marker, timeout):
    result = bytearray()
    deadline = time.monotonic() + timeout
    while marker not in result:
        left = deadline - time.monotonic()
        if left <= 0 or not select.select([fd], [], [], left)[0]:
            raise AssertionError(f"chat PTY timed out waiting for {marker!r}: {result[-500:]!r}")
        data = os.read(fd, 65536)
        if not data:
            raise AssertionError(f"chat PTY closed before {marker!r}: {result[-500:]!r}")
        result.extend(data)
    return bytes(result)


def main(binary, store):
    master, slave = os.openpty()
    size(slave, 80)
    process = subprocess.Popen(
        [binary, "chat", "--accel", "cuda", "--model-store", store,
         "--context", "512", "--max-tokens", "4"],
        stdin=slave, stdout=slave, stderr=slave, start_new_session=True,
    )
    os.close(slave)
    try:
        read_until(master, b"Select model [1]: ", 15)
        os.write(master, b"\n")
        startup = read_until(master, b"You> ", 120)
        if b"backend=cuda" not in startup:
            raise AssertionError("native CUDA chat did not become ready")
        os.write(master, ("界" * 20 + " Freyja 🛡️\n").encode())
        read_until(master, b"You> ", 60)
        size(master, 24)
        os.write(master, b"/history\n")
        history = read_until(master, b"You> ", 15).decode()
        if "History 1/1" not in history or "1 You: 界界界..." not in history:
            raise AssertionError(f"history did not show the committed turn: {history!r}")
        for line in history.replace("\r", "").split("\n"):
            if " You:" in line or line.startswith("  AI:"):
                cells = sum(2 if ord(char) >= 128 else 1 for char in line)
                if cells > 24:
                    raise AssertionError(f"mixed-script history row exceeded 24 cells: {line!r}")
        size(master, 80)
        os.write(master, b"/turn 1\n")
        detail = read_until(master, b"You> ", 15).decode()
        if "Turn 1/1" not in detail or "Freyja 🛡️" not in detail:
            raise AssertionError(f"turn detail lost Unicode content: {detail!r}")
        os.write(master, b"/help\n")
        help_text = read_until(master, b"You> ", 15).decode()
        if "/history" not in help_text or "/export" not in help_text:
            raise AssertionError("chat command discovery omitted history/export")
        os.write(master, b"/history 2\n")
        rejected = read_until(master, b"You> ", 15).decode()
        if "history page is outside completed turns" not in rejected:
            raise AssertionError("invalid page was not rejected")
        with tempfile.TemporaryDirectory(prefix="aesir-history-") as temporary:
            export = Path(temporary) / "conversation.md"
            os.write(master, f"/export {export}\n".encode())
            exported = read_until(master, b"You> ", 15).decode()
            content = export.read_text(encoding="utf-8")
            if ("conversation exported" not in exported or "界" * 20 not in content
                    or "Freyja 🛡️" not in content
                    or "## Turn 1" not in content):
                raise AssertionError("full Unicode conversation export failed")
            if export.stat().st_mode & 0o777 != 0o600:
                raise AssertionError("export was not owner-private")
            os.write(master, f"/export {export}\n".encode())
            duplicate = read_until(master, b"You> ", 15).decode()
            if "must not already exist" not in duplicate or export.read_text(encoding="utf-8") != content:
                raise AssertionError("duplicate export was not safely rejected")
        os.write(master, b"/bye\n")
        if process.wait(timeout=15) != 0:
            raise AssertionError(f"chat exited with status {process.returncode}")
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        os.close(master)
    print("native chat PTY history/turn/help, private Unicode export/no-overwrite: PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    parser.add_argument("--store", default=".aesir/models")
    args = parser.parse_args()
    main(args.binary, args.store)
