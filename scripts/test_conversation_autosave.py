#!/usr/bin/env python3
"""Process-kill proof for native conversation autosave generations."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import signal
import subprocess
import tempfile


def run(binary: Path, command: str, root: Path, expected: int = 0) -> str:
    result = subprocess.run(
        [binary, command, root], text=True, capture_output=True,
        timeout=15, check=False,
    )
    output = result.stdout + result.stderr
    if result.returncode != expected:
        raise AssertionError(
            f"{command} returned {result.returncode}, expected {expected}:\n{output}"
        )
    return output


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True, type=Path)
    options = parser.parse_args()
    binary = options.binary.resolve(strict=True)

    with tempfile.TemporaryDirectory(prefix="aesir-autosave-kill-") as temporary:
        base = Path(temporary)
        root = base / "session"
        root.mkdir(mode=0o700)
        linked = base / "linked-session"
        linked.symlink_to(root, target_is_directory=True)
        symlink_result = subprocess.run(
            [binary, "seed", linked], text=True, capture_output=True,
            timeout=5, check=False,
        )
        if symlink_result.returncode == 0 or "symlink" not in (
            symlink_result.stdout + symlink_result.stderr
        ):
            raise AssertionError("autosave accepted a symlink root")
        insecure = base / "insecure-session"
        insecure.mkdir(mode=0o755)
        insecure_result = subprocess.run(
            [binary, "seed", insecure], text=True, capture_output=True,
            timeout=5, check=False,
        )
        if insecure_result.returncode == 0 or "group/world" not in (
            insecure_result.stdout + insecure_result.stderr
        ):
            raise AssertionError("autosave accepted an externally writable root")
        sentinel = root / "user-owned-note.txt"
        sentinel.write_text("preserve\n")

        assert "SEEDED turns=1" in run(binary, "seed", root)
        process = subprocess.Popen(
            [binary, "begin", root], text=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        assert process.stdout is not None
        ready = process.stdout.readline().strip()
        if ready != "READY generation=2 turn=2":
            process.kill()
            stdout, stderr = process.communicate(timeout=5)
            raise AssertionError(f"autosave probe did not become ready: {ready}\n{stdout}{stderr}")
        contended = subprocess.run(
            [binary, "recover", root], text=True, capture_output=True,
            timeout=5, check=False,
        )
        if contended.returncode == 0 or "already in use" not in (
            contended.stdout + contended.stderr
        ):
            process.kill()
            process.wait(timeout=5)
            raise AssertionError(
                "a second autosave owner did not fail promptly: "
                f"rc={contended.returncode}\n{contended.stdout}{contended.stderr}"
            )
        os.kill(process.pid, signal.SIGKILL)
        process.wait(timeout=5)
        if process.returncode != -signal.SIGKILL:
            raise AssertionError(f"autosave probe exited unexpectedly: {process.returncode}")

        recovered = run(binary, "recover", root)
        assert "RECOVERED turns=1 interrupted_generation=2 interrupted_turn=2" in recovered
        assert sentinel.read_text() == "preserve\n"
        assert (root / "generation-1.aesir").is_file()
        assert (root / "current").is_file()
        assert (root / "inflight").is_file()

        assert "DISCARDED" in run(binary, "discard", root)
        assert not (root / "inflight").exists()
        assert sentinel.read_text() == "preserve\n"

        manifest = root / "current"
        original = manifest.read_bytes()
        manifest.write_bytes(original.replace(b"RETAIN:3", b"RETAIN:4", 1))
        corrupt = subprocess.run(
            [binary, "recover", root], text=True, capture_output=True,
            timeout=15, check=False,
        )
        if corrupt.returncode == 0 or "checksum" not in (corrupt.stdout + corrupt.stderr).lower():
            raise AssertionError("autosave accepted a corrupted authoritative manifest")
        assert sentinel.read_text() == "preserve\n"

    print(
        "PASS native autosave: private no-symlink root; committed turn survived "
        "SIGKILL; interrupted generation identified; lock contention, owned-only "
        "cleanup, and corruption refusal"
    )


if __name__ == "__main__":
    main()
