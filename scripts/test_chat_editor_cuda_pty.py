#!/usr/bin/env python3
"""Opt-in installed-model PTY smoke for /edit routing into CUDA chat."""

import argparse
import os
import signal
import subprocess

from test_chat_history_pty import read_until, size
from test_terminal_screen_pty import write_all


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
        write_all(master, b"\n")
        startup = read_until(master, b"You> ", 120)
        if b"backend=cuda" not in startup:
            raise AssertionError("CUDA chat did not become ready")
        write_all(master, b"/edit\n")
        read_until(master, b"\x1b[?2004h", 15)
        write_all(master, b"PRIVATE_CANCELLED\x03")
        cancelled = read_until(master, b"You> ", 15)
        if b"Draft cancelled" not in cancelled:
            raise AssertionError("/edit cancellation was not acknowledged")
        write_all(master, b"/history\n")
        empty = read_until(master, b"You> ", 15)
        if b"No completed turns" not in empty or b"PRIVATE_CANCELLED" in empty:
            raise AssertionError("cancelled /edit draft entered history")
        write_all(master, b"/edit\n")
        read_until(master, b"\x1b[?2004h", 15)
        write_all(master, b"PRIVATE_SIGNAL")
        os.kill(process.pid, signal.SIGINT)
        interrupted = read_until(master, b"You> ", 15)
        if b"Draft cancelled" not in interrupted:
            raise AssertionError("external SIGINT did not cancel /edit")
        write_all(master, b"/edit\n")
        read_until(master, b"\x1b[?2004h", 15)
        write_all(master, b"\x1b[200~/bye\r\n" + "世界".encode() + b"\x1b[201~\r")
        submitted = read_until(master, b"You> ", 90).replace(b"\r\n", b"\n")
        if b"User: /bye\n" + "世界".encode() not in submitted:
            raise AssertionError(f"literal editor prompt was not submitted: {submitted[-800:]!r}")
        write_all(master, b"/history\n")
        history = read_until(master, b"You> ", 15)
        if b"History 1/1" not in history or b"PRIVATE_SIGNAL" in history:
            raise AssertionError("/edit leaked cancelled input or did not commit one turn")
        write_all(master, b"/bye\n")
        if process.wait(timeout=15):
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
    print("native CUDA /edit PTY raw-and-SIGINT cancel/paste/commit/history: PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    parser.add_argument("--store", default=".aesir/models")
    args = parser.parse_args()
    main(args.binary, args.store)
