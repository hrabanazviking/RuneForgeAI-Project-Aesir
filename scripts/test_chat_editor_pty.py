#!/usr/bin/env python3
"""Model-free PTY acceptance for the /edit reader and terminal lease."""

import argparse
import os
import subprocess
import termios

from test_chat_history_pty import read_until
from test_terminal_screen_pty import size, write_all


def run_case(binary, payload, marker, initial=(24, 80)):
    master, slave = os.openpty()
    size(slave, *initial)
    original = termios.tcgetattr(slave)
    process = subprocess.Popen([binary], stdin=slave, stdout=slave, stderr=slave)
    output = bytearray()
    try:
        output.extend(read_until(master, b"\x1b[?2004h", 10))
        if termios.tcgetattr(master)[3] & (termios.ICANON | termios.ECHO):
            raise AssertionError("/edit did not enter raw mode")
        write_all(master, payload)
        output.extend(read_until(master, marker, 10))
        if process.wait(timeout=10):
            raise AssertionError("/edit harness exited unsuccessfully")
        if termios.tcgetattr(master) != original:
            raise AssertionError("/edit did not restore termios")
        if b"\x1b[?2004l\x1b[?25h\x1b[?1049l" not in output:
            raise AssertionError("/edit did not restore paste mode and screen")
        return bytes(output)
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        os.close(slave)
        os.close(master)


def main(binary):
    redirected = subprocess.run([binary], input=b"/bye\n", capture_output=True, timeout=10)
    if redirected.returncode or b"EDITOR_CANCELLED" not in redirected.stdout:
        raise AssertionError("redirected /edit did not decline interactive mode")
    submitted = run_case(
        binary,
        b"\r\x1b[200~/bye\r\n" + "世界".encode() + b"\x1b[201~\r",
        b"SUBMITTED=/bye\r\n" + "世界".encode(),
    )
    if b"Draft is empty" not in submitted:
        raise AssertionError("empty Enter did not keep editor open")
    run_case(binary, b"first\x0asecond\r", b"SUBMITTED=first\r\nsecond")
    edited = run_case(binary, "A界B".encode() + b"\x1b[D\x1b[D\x1b[3~\r", b"SUBMITTED=AB")
    if b"SUBMITTED=A" + "界".encode() in edited:
        raise AssertionError("forward delete did not remove UTF-8 scalar")
    cancelled = run_case(binary, b"PRIVATE\x03", b"EDITOR_CANCELLED")
    if b"SUBMITTED=" in cancelled:
        raise AssertionError("cancelled draft was submitted")
    rejected = run_case(
        binary,
        b"\x1b[200~" + b"x" * 65537 + b"\x1b[201~OK\r",
        b"SUBMITTED=OK",
    )
    if b"Paste rejected" not in rejected:
        raise AssertionError("oversized paste had no visible guidance")
    print("chat editor PTY submit/cancel/paste/reject/restore: PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    args = parser.parse_args()
    main(args.binary)
