#!/usr/bin/env python3
"""Real-PTY acceptance for model-free transcript navigation and restoration."""

import argparse
import os
import select
import subprocess
import termios

from test_chat_history_pty import read_until
from test_terminal_screen_pty import size, write_all


def session(binary, exit_key=b"q", resize=False, navigation=(b"n", b"p")):
    master, slave = os.openpty()
    size(slave, 8, 24)
    original = termios.tcgetattr(slave)
    process = subprocess.Popen([binary], stdin=slave, stdout=slave, stderr=slave)
    output = bytearray()
    try:
        output.extend(read_until(master, b"n next p prev q back", 10))
        if b"Transcript 1/2" not in output or b"Turn 1 You:" not in output:
            raise AssertionError("first transcript page was not rendered")
        if b"\x1b[?1049h\x1b[?25l\x1b[?2004h" not in output:
            raise AssertionError("transcript did not enter alternate screen")
        if termios.tcgetattr(master)[3] & (termios.ICANON | termios.ECHO):
            raise AssertionError("transcript did not enter raw mode")
        if select.select([master], [], [], 0.6)[0]:
            raise AssertionError("unchanged idle viewer emitted an extra frame")
        write_all(master, navigation[0])
        output.extend(read_until(master, b"End | p prev q back", 10))
        if b"Transcript 2/2" not in output or "界".encode() not in output:
            raise AssertionError("next did not reach the second turn")
        write_all(master, navigation[1])
        output.extend(read_until(master, b"n next p prev q back", 10))
        if output.count(b"Transcript 1/2") != 2:
            raise AssertionError("previous did not restore the first page")
        write_all(master, b"\x1b[200~qnp\x1b[201~")
        if select.select([master], [], [], 0.6)[0] or process.poll() is not None:
            raise AssertionError("pasted commands navigated or closed transcript")
        if resize:
            size(slave, 8, 80)
            output.extend(read_until(master, b"select text to copy", 3))
            if b"Transcript | turn 1/2" not in output:
                raise AssertionError("idle resize did not redraw wide transcript")
            size(slave, 7, 23)
            output.extend(read_until(master, b"TRANSCRIPT_UNAVAILABLE", 3))
            if b"Transcript view closed: Terminal editor requires" not in output:
                raise AssertionError("undersized resize had no explanation")
        else:
            write_all(master, exit_key)
            output.extend(read_until(master, b"TRANSCRIPT_EXIT", 10))
        if process.wait(timeout=10):
            raise AssertionError("transcript harness exited unsuccessfully")
        if termios.tcgetattr(master) != original:
            raise AssertionError("transcript did not restore termios")
        if b"\x1b[?2004l\x1b[?25h\x1b[?1049l" not in output:
            raise AssertionError("transcript did not restore prior screen")
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        os.close(slave)
        os.close(master)


def undersized_refusal(binary):
    master, slave = os.openpty()
    size(slave, 7, 23)
    original = termios.tcgetattr(slave)
    process = subprocess.Popen([binary], stdin=slave, stdout=slave, stderr=slave)
    try:
        output = read_until(master, b"TRANSCRIPT_UNAVAILABLE", 10)
        if process.wait(timeout=10):
            raise AssertionError("undersized transcript refusal exited unsuccessfully")
        if b"Transcript view unavailable: Terminal editor requires" not in output:
            raise AssertionError("undersized transcript refusal lacked guidance")
        if b"\x1b[?1049h" in output or termios.tcgetattr(master) != original:
            raise AssertionError("undersized transcript refusal touched terminal state")
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        os.close(slave)
        os.close(master)


def main(binary):
    redirected = subprocess.run([binary], input=b"q\n", capture_output=True, timeout=10)
    if redirected.returncode or b"TRANSCRIPT_UNAVAILABLE" not in redirected.stdout:
        raise AssertionError("redirected transcript did not decline interactive mode")
    undersized_refusal(binary)
    session(binary)
    session(binary, navigation=(b"\x1b[B", b"\x1b[A"))
    session(binary, exit_key=b"\x1b")
    session(binary, exit_key=b"\x03")
    session(binary, resize=True)
    print("transcript viewer PTY paging/paste/resize/restore: PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    args = parser.parse_args()
    main(args.binary)
