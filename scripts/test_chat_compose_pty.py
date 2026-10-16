#!/usr/bin/env python3
"""Opt-in physical CUDA PTY smoke for native multiline compose."""

import argparse
import os
import signal
import subprocess

from test_chat_history_pty import read_until, size


def send_and_wait(fd, command, marker=b"... ", timeout=15):
    os.write(fd, command.encode("utf-8") + b"\n")
    return read_until(fd, marker, timeout).decode("utf-8")


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
        send_and_wait(master, "/compose")
        send_and_wait(master, "CANCELLED_PRIVATE_DRAFT")
        cancelled = send_and_wait(master, "/cancel", b"You> ")
        if "Draft cancelled" not in cancelled:
            raise AssertionError("compose cancellation was not acknowledged")
        os.write(master, b"/history\n")
        empty = read_until(master, b"You> ", 15).decode("utf-8")
        if "No completed turns" not in empty or "CANCELLED_PRIVATE_DRAFT" in empty:
            raise AssertionError("cancelled draft reached committed history")
        send_and_wait(master, "/compose")
        send_and_wait(master, "INTERRUPTED_PRIVATE_DRAFT")
        os.kill(process.pid, signal.SIGINT)
        interrupted = read_until(master, b"You> ", 15).decode("utf-8")
        if "Draft cancelled by interrupt" not in interrupted:
            raise AssertionError("SIGINT did not cancel the active draft")
        os.write(master, b"/history\n")
        empty_after_interrupt = read_until(master, b"You> ", 15).decode("utf-8")
        if "No completed turns" not in empty_after_interrupt:
            raise AssertionError("interrupted draft reached committed history")
        send_and_wait(master, "/compose")
        send_and_wait(master, "/bye")
        send_and_wait(master, "")
        send_and_wait(master, "//send")
        undone = send_and_wait(master, "/undo")
        if "Last line removed" not in undone:
            raise AssertionError("compose undo was not acknowledged")
        send_and_wait(master, "世界 🛡️")
        submitted = send_and_wait(master, "/send", b"You> ", 90).replace("\r\n", "\n")
        if "User: /bye\n\n世界 🛡️" not in submitted:
            raise AssertionError(f"multiline Unicode prompt was not submitted literally: {submitted[-900:]!r}")
        os.write(master, b"/history\n")
        history = read_until(master, b"You> ", 15).decode("utf-8")
        if "History 1/1" not in history or "1 You:" not in history:
            raise AssertionError("submitted compose did not commit exactly one turn")
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
    print("native compose PTY cancel/SIGINT/undo/multiline Unicode/literal slash: PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    parser.add_argument("--store", default=".aesir/models")
    args = parser.parse_args()
    main(args.binary, args.store)
