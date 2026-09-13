#!/usr/bin/env python3
"""PTY and redirected-I/O proofs for the local home launcher; no real inference."""
import argparse
import errno
import os
from pathlib import Path
import pty
import select
import signal
import subprocess
import tempfile
import time


class Terminal:
    def __init__(self, binary: str, root: Path, *args: str):
        self.master, slave = pty.openpty()
        try:
            self.process = subprocess.Popen([binary, *args], cwd=root, stdin=slave,
                                            stdout=slave, stderr=slave, start_new_session=True)
        finally:
            os.close(slave)
        self.pending = b""

    def expect(self, text: str, timeout: float = 30) -> str:
        target = text.encode()
        deadline = time.monotonic() + timeout
        while target not in self.pending:
            assert time.monotonic() < deadline, self.pending.decode(errors="replace")
            if select.select([self.master], [], [], 0.1)[0]:
                try:
                    chunk = os.read(self.master, 65536)
                except OSError as error:
                    if error.errno != errno.EIO:
                        raise
                    chunk = b""
                assert chunk, self.pending.decode(errors="replace")
                self.pending += chunk
        end = self.pending.index(target) + len(target)
        found, self.pending = self.pending[:end], self.pending[end:]
        return found.decode(errors="replace")

    def send(self, text: str):
        os.write(self.master, text.encode())

    def close(self):
        if self.process.poll() is None:
            os.killpg(self.process.pid, signal.SIGKILL)
        self.process.wait(timeout=10)
        os.close(self.master)


def check(binary: str):
    binary = str(Path(binary).resolve())
    with tempfile.TemporaryDirectory(prefix="aesir-home-") as directory:
        root = Path(directory)

        def run(*args: str, ok=True):
            result = subprocess.run([binary, *args], cwd=root, input="", text=True,
                                    capture_output=True, timeout=30)
            assert (result.returncode == 0) == ok, result.stdout + result.stderr
            return result.stdout + result.stderr

        assert "Usage:" in run()
        assert "interactive terminal" in run("home", ok=False)
        assert "Usage: aesir home" in run("home", "--help")
        master, slave = pty.openpty()
        try:
            redirected = subprocess.run([binary], cwd=root, stdin=slave, text=True,
                                        stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
            assert redirected.returncode == 0 and "Usage:" in redirected.stdout
            rejected = subprocess.run([binary, "home"], cwd=root, stdin=slave, text=True,
                                      stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
            assert rejected.returncode != 0 and "interactive terminal" in rejected.stdout + rejected.stderr
            rejected = subprocess.run([binary, "home"], cwd=root, input="", text=True,
                                      stdout=slave, stderr=subprocess.PIPE, timeout=10)
            assert rejected.returncode != 0
        finally:
            os.close(master)
            os.close(slave)
        for args in [("--model-store",), ("--model-store", ""), ("--model-store", "../escape"),
                     ("--model-store", "one", "--model-store", "two"), ("--unknown",), ("extra",)]:
            run("home", *args, ok=False)

        terminal = Terminal(binary, root)
        try:
            terminal.expect("Aesir Home")
            terminal.expect("No installed weights")
            terminal.expect("Choice:")
            terminal.send("invalid\n")
            terminal.expect("Choose 1-5 or q")
            terminal.expect("Choice:")
            os.kill(terminal.process.pid, signal.SIGINT)
            terminal.expect("Cancelled")
            terminal.expect("Choice:")
            terminal.send("1\n")
            terminal.expect("No installed weights")
            terminal.expect("Choice:")
            terminal.send("q\n")
            assert terminal.process.wait(timeout=10) == 0
        finally:
            terminal.close()
        assert not (root / ".aesir").exists(), "home created a default store"

        (root / "Modelfile").write_text("FROM local.gguf\n", encoding="utf-8")
        (root / "weights.bin").write_bytes(b"not-a-real-gguf")
        run("create", "recipe", "--modelfile", "Modelfile", "--model-store", "store")
        run("create", "tiny", "--modelfile", "Modelfile", "--model", "weights.bin", "--model-store", "store")
        before = {str(p.relative_to(root)): p.read_bytes() for p in root.rglob("*") if p.is_file()}
        terminal = Terminal(binary, root, "home", "--model-store", "store")
        try:
            terminal.expect("Installed weights: 1 | Recipes: 1")
            terminal.expect("Choice:")
            terminal.send("2\n")
            terminal.expect("tiny:latest")
            terminal.expect("Returned to home (command exit 0)")
            terminal.expect("Choice:")
            terminal.send("3\n")
            terminal.expect("Project Aesir Diagnostic")
            terminal.expect("Returned to home (command exit 0)")
            terminal.expect("Choice:")
            terminal.send("4\n")
            terminal.expect("Returned to home (command exit 1)")
            terminal.expect("Choice:")
            terminal.send("1\n")
            terminal.expect("Select model [1]:")
            os.killpg(terminal.process.pid, signal.SIGINT)
            terminal.expect("Returned to home (command exit 1)")
            terminal.expect("Choice:")
            terminal.send("1\n")
            terminal.expect("Select model [1]:")
            terminal.send("1\n")
            terminal.expect("Returned to home (command exit 1)")
            terminal.expect("Choice:")
            terminal.send("1\n")
            terminal.expect("Select model [1]:")
            children = Path(f"/proc/{terminal.process.pid}/task/{terminal.process.pid}/children").read_text().split()
            assert len(children) == 1, children
            child_pid = int(children[0])
            os.kill(child_pid, signal.SIGTERM)
            terminal.expect("Returned to home (command exit 143)")
            assert not Path(f"/proc/{child_pid}").exists(), "child was not reaped"
            terminal.expect("Choice:")
            terminal.send("\x04")  # terminal EOF exits, not an empty-choice loop
            assert terminal.process.wait(timeout=10) == 0
        finally:
            terminal.close()
        assert {str(p.relative_to(root)): p.read_bytes() for p in root.rglob("*") if p.is_file()} == before
        run("rm", "tiny", "--model-store", "store")
        terminal = Terminal(binary, root, "home", "--model-store", "store")
        try:
            terminal.expect("Installed weights: 0 | Recipes: 1")
            terminal.expect("Choice:")
            terminal.send("1\n")
            terminal.expect("No installed weights available for chat")
            terminal.expect("Choice:")
            terminal.send("q\n")
            assert terminal.process.wait(timeout=10) == 0
        finally:
            terminal.close()
        (root / "store" / "catalog.v1").write_bytes(b"corrupt")
        damaged = {str(p.relative_to(root)): p.read_bytes() for p in root.rglob("*") if p.is_file()}
        terminal = Terminal(binary, root, "home", "--model-store", "store")
        try:
            terminal.expect("Catalog unavailable:")
            terminal.expect("Choice:")
            terminal.send("2\n")
            terminal.expect("Returned to home (command exit 1)")
            terminal.expect("Choice:")
            terminal.send("q\n")
            assert terminal.process.wait(timeout=10) == 0
        finally:
            terminal.close()
        assert {str(p.relative_to(root)): p.read_bytes() for p in root.rglob("*") if p.is_file()} == damaged
    print("PASS home: PTY startup, stores, child cancellation/failure recovery, EOF and noninteractive behavior")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True)
    check(parser.parse_args().binary)
