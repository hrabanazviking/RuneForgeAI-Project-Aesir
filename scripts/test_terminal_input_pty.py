#!/usr/bin/env python3
"""PTY/redirected regression for the scoped native raw-mode lease."""

import argparse
import os
import subprocess
import termios

from test_chat_history_pty import read_until


def check_pty(binary, input_byte, expected_success):
    master, slave = os.openpty()
    original = termios.tcgetattr(slave)
    process = subprocess.Popen([binary], stdin=slave, stdout=slave, stderr=slave)
    try:
        read_until(master, b"RAW_READY", 10)
        raw = termios.tcgetattr(master)
        if raw[3] & (termios.ICANON | termios.ECHO):
            raise AssertionError("raw lease left canonical input or echo enabled")
        os.write(master, input_byte)
        if expected_success:
            read_until(master, b"RESTORED", 10)
        status = process.wait(timeout=10)
        if (status == 0) != expected_success:
            raise AssertionError("raw lease harness exit status disagreed with test")
        restored = termios.tcgetattr(master)
        if restored != original:
            raise AssertionError("raw lease failed to restore original termios")
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        os.close(slave)
        os.close(master)


def main(binary):
    redirected = subprocess.run([binary], input=b"z", capture_output=True, timeout=10)
    if redirected.returncode or b"TTY_REQUIRED" not in redirected.stdout:
        raise AssertionError("redirected input did not refuse raw mode")
    check_pty(binary, b"z", True)
    check_pty(binary, b"e", False)
    print("native terminal raw lease PTY/redirected/normal-and-error restore: PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    args = parser.parse_args()
    main(args.binary)
