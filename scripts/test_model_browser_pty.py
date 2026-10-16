#!/usr/bin/env python3
"""Real-PTY S33a model browser navigation, resize, and cancellation checks."""

import argparse
import fcntl
import os
import select
import struct
import subprocess
import termios
import time


def set_size(fd, columns, rows=24):
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, columns, 0, 0))


def read_until(fd, marker, timeout=10):
    deadline = time.monotonic() + timeout
    output = bytearray()
    while marker not in output:
        remaining = deadline - time.monotonic()
        if remaining <= 0 or not select.select([fd], [], [], remaining)[0]:
            raise AssertionError(f"PTY timed out waiting for {marker!r}: {output[-500:]!r}")
        chunk = os.read(fd, 65536)
        if not chunk:
            raise AssertionError(f"PTY closed before {marker!r}: {output[-500:]!r}")
        output.extend(chunk)
    return bytes(output)


def spawn(binary, columns):
    master, slave = os.openpty()
    set_size(slave, columns)
    process = subprocess.Popen(
        [binary, "--interactive"], stdin=slave, stdout=slave, stderr=slave,
        start_new_session=True,
    )
    os.close(slave)
    return process, master


def finish(process, master):
    try:
        if process.poll() is None:
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.terminate()
                process.wait(timeout=5)
                raise AssertionError("browser process did not exit after selection")
        if process.returncode != 0:
            raise AssertionError(f"browser process exited {process.returncode}")
    finally:
        os.close(master)


def main(binary):
    process, master = spawn(binary, 80)
    try:
        first = read_until(master, b"Select model [1]: ")
        assert b"Installed models 1-10/12" in first
        os.write(master, b"n\n")
        second = read_until(master, b"Select model [11]: ")
        assert b"Installed models 11-12/12" in second
        os.write(master, b"12\n")
        final = read_until(master, b"SELECTED=a-very-long-but-valid-model-name-for-narrow-terminal-11:latest")
        assert b"SELECTED=a-very-long-but-valid-model-name-for-narrow-terminal-11:latest" in final
    finally:
        finish(process, master)

    process, master = spawn(binary, 80)
    try:
        read_until(master, b"Select model [1]: ")
        os.write(master, b"n\n")
        read_until(master, b"Select model [11]: ")
        os.write(master, b"\n")
        assert b"SELECTED=a-very-long-but-valid-model-name-for-narrow-terminal-10:latest" in read_until(
            master, b"SELECTED=a-very-long-but-valid-model-name-for-narrow-terminal-10:latest"
        )
    finally:
        finish(process, master)

    process, master = spawn(binary, 80)
    try:
        read_until(master, b"Select model [1]: ")
        os.write(master, b"\n")
        assert b"SELECTED=a-very-long-but-valid-model-name-for-narrow-terminal-0:latest" in read_until(
            master, b"SELECTED=a-very-long-but-valid-model-name-for-narrow-terminal-0:latest"
        )
    finally:
        finish(process, master)

    process, master = spawn(binary, 24)
    try:
        first = read_until(master, b"Select model [1]: ")
        assert b"Models 1/2" in first
        for line in first.decode().replace("\r", "").splitlines():
            if line.startswith(("  ", "> ")):
                assert len(line.encode()) <= 24, line
        os.write(master, b"99\n")
        assert b"Invalid choice; use ?" in read_until(master, b"Select model [1]: ")
        os.write(master, b"?\n")
        assert b"IDs stable; * favorite." in read_until(master, b"Select model [1]: ")
        os.write(master, b"n\n")
        assert b"Models 2/2" in read_until(master, b"Select model [11]: ")
        set_size(master, 80)
        os.write(master, b"p\n")
        assert b"Installed models 1-10/12" in read_until(master, b"Select model [1]: ")
        os.write(master, b"q\n")
        assert b"CANCELLED=Model selection cancelled" in read_until(master, b"CANCELLED=Model selection cancelled")
    finally:
        finish(process, master)
    print("model browser PTY 80x24, 24x24, resize, default, invalid input, help, navigation, cancellation: PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    main(parser.parse_args().binary)
