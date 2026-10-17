#!/usr/bin/env python3
"""Opt-in installed-model PTY smoke for the /transcript chat command."""

import argparse
import os
import signal
import subprocess
import termios

from test_chat_history_pty import read_until, size
from test_terminal_screen_pty import size as set_size, write_all


def extended_view(master, original):
    prompt = "NARROW_" + "界" * 96 + "_END"
    write_all(master, (prompt + "\n").encode())
    read_until(master, b"You> ", 90)
    set_size(master, 8, 24)
    write_all(master, b"/transcript\n")
    forward = bytearray(read_until(master, b"q back", 15))
    page_count = 1
    while b"End | p prev q back" not in forward[-256:]:
        if page_count > 20:
            raise AssertionError("narrow transcript did not reach its end")
        write_all(master, b"n")
        page = read_until(master, b"q back", 15)
        forward.extend(page)
        page_count += 1
    before_assistant = bytes(forward).split(b"Turn 2 AI:", 1)[0]
    if (page_count < 2 or b"Turn 2 You:" not in forward
            or b"NARROW_" not in forward or b"_END" not in forward
            or before_assistant.count("界".encode()) != 96):
        raise AssertionError("narrow paging lost or duplicated committed Unicode")
    write_all(master, b"p")
    previous = read_until(master, b"q back", 15)
    if b"n next" not in previous:
        raise AssertionError("previous did not leave the transcript end page")
    set_size(master, 24, 80)
    widened = read_until(master, b"select text to copy", 5)
    if b"Transcript | turn" not in widened:
        raise AssertionError("idle wide resize did not redraw transcript")
    write_all(master, b"q")
    restored = read_until(master, b"You> ", 15)
    if (b"\x1b[?2004l\x1b[?25h\x1b[?1049l" not in restored
            or termios.tcgetattr(master) != original):
        raise AssertionError("wide transcript exit left terminal state changed")
    write_all(master, b"/history\n")
    history = read_until(master, b"You> ", 15)
    if b"History 1/1" not in history or b"2 You: NARROW_" not in history:
        raise AssertionError("transcript navigation changed the committed turns")


def clusters_view(master, original):
    cluster = "e\u0301👩‍👩‍👧‍👦🇺🇸"
    prompt = "CLUSTER_" + cluster * 12 + "_END"
    write_all(master, (prompt + "\n").encode())
    read_until(master, b"You> ", 90)
    set_size(master, 8, 24)
    write_all(master, b"/transcript\n")
    forward = bytearray(read_until(master, b"q back", 15))
    page_count = 1
    while b"End | p prev q back" not in forward[-256:]:
        if page_count > 20:
            raise AssertionError("cluster transcript did not reach its end")
        write_all(master, b"n")
        forward.extend(read_until(master, b"q back", 15))
        page_count += 1
    if b"Turn 2 You:" not in forward or b"Turn 2 AI:" not in forward:
        raise AssertionError("cluster transcript lost the committed turn")
    user = bytes(forward).split(b"Turn 2 You:", 1)[1].split(b"Turn 2 AI:", 1)[0]
    if (page_count < 2 or b"CLUSTER_" not in user or b"_END" not in user
            or user.count("e\u0301".encode()) != 12
            or user.count("👩‍👩‍👧‍👦".encode()) != 12
            or user.count("🇺🇸".encode()) != 12):
        raise AssertionError("cluster paging split, lost or duplicated a glyph")
    write_all(master, b"q")
    restored = read_until(master, b"You> ", 15)
    if (b"\x1b[?2004l\x1b[?25h\x1b[?1049l" not in restored
            or termios.tcgetattr(master) != original):
        raise AssertionError("cluster transcript exit left terminal state changed")
    write_all(master, b"/history\n")
    history = read_until(master, b"You> ", 15)
    if b"2 You: CLUSTE" not in history:
        raise AssertionError("cluster transcript mutated committed history")


def main(binary, store, model, extended=False, clusters=False):
    master, slave = os.openpty()
    size(slave, 80)
    original = termios.tcgetattr(slave)
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
        if extended:
            extended_view(master, original)
        if clusters:
            clusters_view(master, original)
        write_all(master, b"/bye\n")
        if process.wait(timeout=15):
            raise AssertionError("native chat exited unsuccessfully")
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        os.close(master)
    if clusters:
        print("native CUDA /transcript PTY intact accent/emoji/flag paging: PASS")
    elif extended:
        print("native CUDA /transcript PTY narrow/wide Unicode paging/restore: PASS")
    else:
        print("native CUDA /transcript PTY empty/committed/SIGINT/history: PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    parser.add_argument("--store", default=".aesir/models")
    parser.add_argument("--model", required=True)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--extended", action="store_true")
    mode.add_argument("--clusters", action="store_true")
    args = parser.parse_args()
    main(args.binary, args.store, args.model, args.extended, args.clusters)
