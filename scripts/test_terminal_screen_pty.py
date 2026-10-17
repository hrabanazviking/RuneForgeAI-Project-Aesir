#!/usr/bin/env python3
"""Model-free PTY redraw, resize and teardown checks for the native editor."""

import argparse
import fcntl
import os
import struct
import subprocess
import termios

from test_chat_history_pty import read_until


def size(fd, rows, columns):
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, columns, 0, 0))


def write_all(fd, payload):
    remaining = memoryview(payload)
    while remaining:
        count = os.write(fd, remaining)
        if count <= 0:
            raise AssertionError("PTY input write stalled")
        remaining = remaining[count:]


def run_case(binary, steps, marker, initial=(24, 80)):
    master, slave = os.openpty()
    size(slave, *initial)
    original = termios.tcgetattr(slave)
    process = subprocess.Popen([binary], stdin=slave, stdout=slave, stderr=slave)
    output = bytearray()
    try:
        output.extend(read_until(master, b"SCREEN_READY", 10))
        if (b"\x1b[?1049h" not in output or b"\x1b[?25l" not in output
                or b"\x1b[?2004h" not in output):
            raise AssertionError("editor did not enter alternate screen and paste mode")
        raw = termios.tcgetattr(master)
        if raw[3] & (termios.ICANON | termios.ECHO):
            raise AssertionError("editor did not enter raw terminal mode")
        for step in steps:
            if isinstance(step, tuple):
                size(slave, *step)
            else:
                write_all(master, step)
        output.extend(read_until(master, marker, 10))
        if process.wait(timeout=10):
            raise AssertionError("native editor harness exited unsuccessfully")
        if termios.tcgetattr(master) != original:
            raise AssertionError("native editor did not restore original termios")
        if b"\x1b[?2004l\x1b[?25h\x1b[?1049l" not in output:
            raise AssertionError("editor did not restore paste mode, cursor and prior screen")
        return bytes(output)
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        os.close(slave)
        os.close(master)


def run_failure_case(binary, initial, marker, send_after_ready=None):
    master, slave = os.openpty()
    size(slave, *initial)
    original = termios.tcgetattr(slave)
    process = subprocess.Popen([binary], stdin=slave, stdout=slave, stderr=slave)
    try:
        if send_after_ready is not None:
            read_until(master, b"SCREEN_READY", 10)
            write_all(master, send_after_ready)
        output = read_until(master, marker, 10)
        if process.wait(timeout=10) == 0:
            raise AssertionError("editor failure case exited successfully")
        if termios.tcgetattr(master) != original:
            raise AssertionError("editor failure left PTY termios changed")
        if b"\x1b[?2004l\x1b[?25h\x1b[?1049l" not in output:
            raise AssertionError("editor failure left paste or alternate screen active")
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        os.close(slave)
        os.close(master)


def main(binary):
    redirected = subprocess.run([binary], input=b"x\r", capture_output=True, timeout=10)
    if redirected.returncode or b"TTY_REQUIRED" not in redirected.stdout:
        raise AssertionError("redirected editor did not refuse raw mode")
    composed = run_case(
        binary,
        ["A界B".encode() + b"\x1b[D\x7f" + "世".encode() + b"\x1b[C\x0aline2\r"],
        b"SUBMITTED=A" + "世".encode() + b"B\r\nline2",
    )
    if b"\x1b[24;1H" not in composed or b"Line 2/2" not in composed:
        raise AssertionError("multiline editor did not redraw the full 24-row frame")
    resized = run_case(binary, [b"first", (8, 24), b"Z\r"], b"SUBMITTED=firstZ")
    if b"\x1b[8;1H" not in resized or b"\x1b[24;1H" not in resized:
        raise AssertionError("editor did not redraw at both PTY heights")
    cancelled = run_case(binary, [b"private\x03"], b"CANCELLED")
    if b"SUBMITTED=" in cancelled:
        raise AssertionError("cancelled editor submitted its draft")
    pasted = run_case(
        binary,
        [b"\x1b[200~/bye\r\n" + "世".encode() + b"\x1b[201~\r"],
        b"SUBMITTED=/bye\r\n" + "世".encode(),
    )
    if b"Line 2/2" not in pasted:
        raise AssertionError("bracketed pasted newline did not remain in the draft")
    run_case(binary, [b"\x1b[200~secret\x03"], b"CANCELLED")
    run_failure_case(binary, (7, 23), b"Terminal editor requires")
    run_failure_case(binary, (24, 80), b"injected editor failure", b"\x1b")
    run_failure_case(
        binary, (24, 80), b"paste limit rejected",
        b"\x1b[200~" + b"x" * 65537 + b"\x1b[201~",
    )
    run_failure_case(
        binary, (24, 80), b"paste limit rejected",
        b"\x1b[200~" + b"\n" * 128 + b"\x1b[201~",
    )
    print("native editor screen PTY Unicode/multiline/resize/cancel/restore: PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    args = parser.parse_args()
    main(args.binary)
