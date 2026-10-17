#!/usr/bin/env python3
"""Model-free PTY acceptance for the /edit reader and terminal lease."""

import argparse
import os
import subprocess
import termios

from test_chat_history_pty import read_until
from test_terminal_screen_pty import size, write_all


def run_case(binary, payload, marker, initial=(24, 80), resize_before_input=None):
    master, slave = os.openpty()
    size(slave, *initial)
    original = termios.tcgetattr(slave)
    process = subprocess.Popen([binary], stdin=slave, stdout=slave, stderr=slave)
    output = bytearray()
    try:
        output.extend(read_until(master, b"Line 1/1", 10))
        if b"\x1b[?2004h" not in output:
            raise AssertionError("/edit did not enable bracketed paste mode")
        if termios.tcgetattr(master)[3] & (termios.ICANON | termios.ECHO):
            raise AssertionError("/edit did not enter raw mode")
        if resize_before_input is not None:
            size(slave, *resize_before_input)
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


def run_refusal_case(binary):
    master, slave = os.openpty()
    size(slave, 7, 23)
    original = termios.tcgetattr(slave)
    process = subprocess.Popen([binary], stdin=slave, stdout=slave, stderr=slave)
    try:
        output = read_until(master, b"EDITOR_CANCELLED", 10)
        if process.wait(timeout=10):
            raise AssertionError("undersized /edit refusal exited unsuccessfully")
        if b"/edit unavailable: Terminal editor requires" not in output:
            raise AssertionError("undersized /edit refusal lacked guidance")
        if b"\x1b[?1049h" in output or termios.tcgetattr(master) != original:
            raise AssertionError("undersized /edit touched the screen or termios")
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
    run_refusal_case(binary)
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
    shrunken = run_case(
        binary, b"DRAFT_DISCARDED", b"EDITOR_CANCELLED",
        resize_before_input=(7, 23),
    )
    if b"Draft cancelled: Terminal editor requires" not in shrunken:
        raise AssertionError("mid-draft resize did not cancel with guidance")
    print("chat editor PTY submit/cancel/paste/resize/restore: PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    args = parser.parse_args()
    main(args.binary)
