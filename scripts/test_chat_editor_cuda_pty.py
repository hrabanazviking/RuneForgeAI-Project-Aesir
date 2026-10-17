#!/usr/bin/env python3
"""Opt-in installed-model PTY smoke for /edit routing into CUDA chat."""

import argparse
import os
import signal
import subprocess

from test_chat_history_pty import read_until, size
from test_terminal_screen_pty import write_all


def editor_ready(fd):
    frame = read_until(fd, b"Line 1/1", 15)
    if b"\x1b[?2004h" not in frame:
        raise AssertionError("/edit did not enable bracketed paste mode")


def main(binary, store, model=None, expected_model=None):
    master, slave = os.openpty()
    size(slave, 80)
    command = [binary, "chat"]
    if model is not None:
        command.append(model)
    command.extend([
        "--accel", "cuda", "--model-store", store,
        "--context", "512", "--max-tokens", "4",
    ])
    process = subprocess.Popen(
        command,
        stdin=slave, stdout=slave, stderr=slave, start_new_session=True,
    )
    os.close(slave)
    try:
        if model is None:
            read_until(master, b"Select model [1]: ", 15)
            write_all(master, b"\n")
        startup = read_until(master, b"You> ", 120)
        if b"backend=cuda" not in startup:
            raise AssertionError("CUDA chat did not become ready")
        if expected_model is not None and expected_model.encode() not in startup:
            raise AssertionError("CUDA chat loaded a different model profile")
        size(master, 23)
        write_all(master, b"/edit\n")
        refused = read_until(master, b"You> ", 15)
        if b"/edit unavailable: Terminal editor requires" not in refused:
            raise AssertionError("undersized /edit did not return to live chat")
        size(master, 80)
        write_all(master, b"/edit\n")
        editor_ready(master)
        size(master, 23)
        shrunk = read_until(master, b"You> ", 5)
        if b"Draft cancelled: Terminal editor requires" not in shrunk:
            raise AssertionError("idle shrink did not return to live chat")
        size(master, 24)
        write_all(master, b"/edit\n")
        editor_ready(master)
        write_all(master, b"NARROW")
        read_until(master, b"6 bytes", 15)
        size(master, 120)
        idle_redraw = read_until(master, b"6 bytes", 5)
        if b"NARROW" not in idle_redraw:
            raise AssertionError("idle 24-to-120 resize did not redraw the draft")
        write_all(master, b"WIDE")
        widened = read_until(master, b"10 bytes", 15)
        if b"NARROWWIDE" not in widened:
            raise AssertionError("24-to-120 resize lost the active draft")
        write_all(master, b"\x03")
        read_until(master, b"You> ", 15)
        size(master, 80)
        write_all(master, b"/edit\n")
        editor_ready(master)
        write_all(master, b"PRIVATE_CANCELLED\x03")
        cancelled = read_until(master, b"You> ", 15)
        if b"Draft cancelled" not in cancelled:
            raise AssertionError("/edit cancellation was not acknowledged")
        write_all(master, b"/history\n")
        empty = read_until(master, b"You> ", 15)
        if b"No completed turns" not in empty or b"PRIVATE_CANCELLED" in empty:
            raise AssertionError("cancelled /edit draft entered history")
        write_all(master, b"/edit\n")
        editor_ready(master)
        write_all(master, b"PRIVATE_SIGNAL")
        os.kill(process.pid, signal.SIGINT)
        interrupted = read_until(master, b"You> ", 15)
        if b"Draft cancelled" not in interrupted:
            raise AssertionError("external SIGINT did not cancel /edit")
        write_all(master, b"/edit\n")
        editor_ready(master)
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
    print("native CUDA /edit PTY resize/cancel/paste/commit/history: PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    parser.add_argument("--store", default=".aesir/models")
    parser.add_argument("--model", help="explicit preinstalled model path; skips chooser")
    parser.add_argument("--expect-model", help="required profile text in the chat startup record")
    args = parser.parse_args()
    main(args.binary, args.store, args.model, args.expect_model)
