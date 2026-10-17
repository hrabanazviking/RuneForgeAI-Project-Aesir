#!/usr/bin/env python3
"""Opt-in installed-model PTY smoke for the /transcript chat command."""

import argparse
import os
import signal
import subprocess

from test_chat_history_pty import read_until, size
from test_terminal_screen_pty import write_all


def main(binary, store, model):
    master, slave = os.openpty()
    size(slave, 80)
    command = [
        binary, "chat", model, "--accel", "cuda", "--model-store", store,
        "--context", "512", "--max-tokens", "4",
    ]
    process = subprocess.Popen(
        command, stdin=slave, stdout=slave, stderr=slave,
        start_new_session=True,
    )
    os.close(slave)
    try:
        startup = read_until(master, b"You> ", 120)
        if b"backend=cuda" not in startup:
            raise AssertionError("native CUDA chat did not become ready")
        write_all(master, b"/transcript\n")
        empty = read_until(master, b"select text to copy", 15)
        if b"No completed turns" not in empty:
            raise AssertionError("empty /transcript did not show its state")
        write_all(master, b"q")
        read_until(master, b"You> ", 15)
        write_all(master, b"HELLO_TRANSCRIPT\n")
        read_until(master, b"You> ", 90)
        write_all(master, b"/transcript\n")
        viewed = read_until(master, b"select text to copy", 15)
        if b"HELLO_TRANSCRIPT" not in viewed:
            raise AssertionError("/transcript did not show the committed user turn")
        os.kill(process.pid, signal.SIGINT)
        returned = read_until(master, b"You> ", 15)
        if b"\x1b[?2004l\x1b[?25h\x1b[?1049l" not in returned:
            raise AssertionError("SIGINT did not restore transcript screen")
        write_all(master, b"/history\n")
        history = read_until(master, b"You> ", 15)
        if b"History 1/1" not in history or b"HELLO_TRANSCRIPT" not in history:
            raise AssertionError("transcript viewing changed committed history")
        write_all(master, b"/bye\n")
        if process.wait(timeout=15):
            raise AssertionError("native chat exited unsuccessfully")
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        os.close(master)
    print("native CUDA /transcript PTY empty/committed/SIGINT/history: PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    parser.add_argument("--store", default=".aesir/models")
    parser.add_argument("--model", required=True)
    args = parser.parse_args()
    main(args.binary, args.store, args.model)
