#!/usr/bin/env python3
"""Exercise resumable download inode ownership without external network access."""

from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


REVISION = "0123456789abcdef0123456789abcdef01234567"


def check(binary_argument: str) -> None:
    binary = Path(binary_argument).resolve(strict=True)
    fake_source = (
        Path(__file__).resolve().parent / "fixtures" / "fake_hf_curl.py"
    )
    if not fake_source.is_file():
        raise AssertionError(f"missing controlled curl fixture: {fake_source}")

    # Use the native temporary filesystem so inode replacement has normal Linux
    # semantics.  WSL's DrvFS may invalidate an open descriptor across rename;
    # the downloader detects that as a checksum failure and publishes nothing.
    with tempfile.TemporaryDirectory(prefix="aesir-hf-resume-") as temporary:
        root = Path(temporary)
        fake_bin = root / "bin"
        fake_bin.mkdir()
        fake_curl = fake_bin / "curl"
        shutil.copyfile(fake_source, fake_curl)
        fake_curl.chmod(0o700)

        fixture = root / "fixture.gguf"
        payload = b"GGUF\x03\x00\x00\x00" + bytes(
            (index * 37 + 11) % 256 for index in range(8184)
        )
        fixture.write_bytes(payload)
        digest = hashlib.sha256(payload).hexdigest()

        environment = os.environ.copy()
        environment["PATH"] = str(fake_bin) + os.pathsep + environment["PATH"]
        environment["AESIR_FAKE_CURL_FIXTURE"] = str(fixture)
        base = [
            str(binary),
            "pull",
            "local/controlled",
            "fixture.gguf",
            "--revision",
            REVISION,
            "--sha256",
            digest,
            "--size",
            str(len(payload)),
        ]

        def stage(output: Path) -> Path:
            return Path(str(output) + ".part." + digest)

        def run(
            output: Path,
            mode: str = "normal",
            error: str | None = None,
            extra_env: dict[str, str] | None = None,
            extra_args: tuple[str, ...] = (),
        ) -> subprocess.CompletedProcess[str]:
            child_env = environment.copy()
            child_env["AESIR_FAKE_CURL_MODE"] = mode
            if extra_env:
                child_env.update(extra_env)
            result = subprocess.run(
                [*base, "--output", output.name, *extra_args],
                cwd=root,
                env=child_env,
                text=True,
                capture_output=True,
                timeout=30,
                check=False,
            )
            combined = result.stdout + result.stderr
            if error is None:
                assert result.returncode == 0, combined
            else:
                assert result.returncode != 0, "controlled failure unexpectedly passed"
                assert error in combined, combined
                assert "Successfully downloaded" not in result.stdout
            return result

        interrupted = root / "interrupted.gguf"
        run(interrupted, mode="interrupt", error="subprocess failed: curl")
        partial = stage(interrupted)
        preserved = partial.read_bytes()
        assert preserved == payload[: len(preserved)]
        assert 0 < len(preserved) < len(payload) and not interrupted.exists()
        run(interrupted)
        assert interrupted.read_bytes() == payload and not partial.exists()

        corrupt = root / "corrupt.gguf"
        corrupt_stage = stage(corrupt)
        corrupt_stage.write_bytes(
            payload[:8] + b"X" * (len(payload) // 3 - 8)
        )
        run(corrupt, error="SHA-256 mismatch")
        assert not corrupt.exists() and not corrupt_stage.exists()

        completed = root / "completed.gguf"
        completed_stage = stage(completed)
        completed_stage.write_bytes(payload)
        run(completed, mode="fail_if_called")
        assert completed.read_bytes() == payload and not completed_stage.exists()

        swapped = root / "swapped.gguf"
        swapped_stage = stage(swapped)
        captured = root / "captured-original-part"
        result = run(
            swapped,
            mode="swap_stage",
            extra_env={
                "AESIR_FAKE_CURL_STAGE": str(swapped_stage),
                "AESIR_FAKE_CURL_CAPTURED": str(captured),
            },
        )
        assert swapped.read_bytes() == payload
        assert captured.read_bytes() == payload
        assert swapped_stage.read_bytes() == b"foreign-stage-entry\n"
        assert "foreign entry preserved" in result.stdout

        raced = root / "raced.gguf"
        run(
            raced,
            mode="target_race",
            error="destination may exist",
            extra_env={"AESIR_FAKE_CURL_TARGET": str(raced)},
        )
        assert raced.read_bytes() == b"concurrent-destination\n"
        assert not stage(raced).exists()

        linked = root / "linked.gguf"
        linked_stage = stage(linked)
        innocent = root / "innocent-user-data"
        innocent.write_bytes(b"do-not-modify\n")
        os.link(innocent, linked_stage)
        run(linked, error="single-link owner-held regular file")
        assert innocent.read_bytes() == b"do-not-modify\n"
        assert linked_stage.read_bytes() == b"do-not-modify\n"
        assert not linked.exists()

        parallel = root / "parallel.gguf"
        run(parallel, extra_args=("--connections", "3"))
        assert parallel.read_bytes() == payload
        assert not list(root.glob("parallel.gguf.part.*"))

    print(
        "PASS resumable download resilience: interruption resumes exact bytes; "
        "corrupt and hard-linked partials fail closed; target/stage replacement "
        "preserves foreign data and publication matches the verified inode"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True)
    arguments = parser.parse_args()
    check(arguments.binary)


if __name__ == "__main__":
    main()
