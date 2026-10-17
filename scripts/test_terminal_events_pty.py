#!/usr/bin/env python3
"""Model-free PTY keyboard workflow for the native terminal event reader."""

import argparse
import os
import subprocess
import termios
import time

from test_chat_history_pty import read_until


def run_case(binary, payload, marker):
    master, slave = os.openpty()
    original = termios.tcgetattr(slave)
    process = subprocess.Popen([binary], stdin=slave, stdout=slave, stderr=slave)
    try:
        read_until(master, b"EVENT_READY", 10)
        raw = termios.tcgetattr(master)
        if raw[3] & (termios.ICANON | termios.ECHO):
            raise AssertionError("event reader was not in raw terminal mode")
        if isinstance(payload, tuple):
            os.write(master, payload[0])
            time.sleep(0.35)
            os.write(master, payload[1])
        else:
            os.write(master, payload)
        read_until(master, marker, 10)
        if process.wait(timeout=10):
            raise AssertionError("event reader exited unsuccessfully")
        if termios.tcgetattr(master) != original:
            raise AssertionError("event reader failed to restore PTY termios")
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        os.close(slave)
        os.close(master)


def main(binary):
    redirected = subprocess.run([binary], input=b"x\r", capture_output=True, timeout=10)
    if redirected.returncode or b"TTY_REQUIRED" not in redirected.stdout:
        raise AssertionError("redirected event reader did not refuse raw mode")
    run_case(binary, "A界B".encode() + b"\x1b[D\x7f" + "世".encode() + b"\r", "SUBMITTED=A世B".encode())
    run_case(binary, b"private\x03", b"CANCELLED")
    run_case(binary, b"\xe0\x80\x80x\r", b"SUBMITTED=x")
    run_case(binary, b"\xe2\x1b[D\x82\xacx\r", b"SUBMITTED=x")
    run_case(binary, (b"\x1b", b"x\r"), b"SUBMITTED=x")
    run_case(binary, (b"\xe2", b"\x82\xacx\r"), b"SUBMITTED=x")
    print("native terminal events PTY Unicode/edit/cancel/malformed: PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    args = parser.parse_args()
    main(args.binary)
