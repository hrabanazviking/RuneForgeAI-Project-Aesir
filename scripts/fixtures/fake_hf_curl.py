#!/usr/bin/env python3
"""Controlled curl stand-in for downloader process tests; never uses a network."""

from __future__ import annotations

import os
from pathlib import Path
import sys


def option(name: str) -> str:
    try:
        return sys.argv[sys.argv.index(name) + 1]
    except (ValueError, IndexError) as error:
        raise SystemExit(f"missing fake curl option {name}") from error


def options(name: str) -> list[str]:
    return [
        sys.argv[index + 1]
        for index, value in enumerate(sys.argv[:-1])
        if value == name
    ]


def main() -> int:
    mode = os.environ.get("AESIR_FAKE_CURL_MODE", "normal")
    if mode == "fail_if_called":
        return 99

    fixture = Path(os.environ["AESIR_FAKE_CURL_FIXTURE"]).read_bytes()
    outputs = options("--output")
    ranges = options("--range")
    if len(outputs) > 1:
        if len(outputs) != len(ranges) or mode != "normal":
            return 64
        for output_name, byte_range in zip(outputs, ranges, strict=True):
            start_text, end_text = byte_range.split("-", 1)
            start, end = int(start_text), int(end_text)
            with Path(output_name).open("r+b", buffering=0) as stream:
                stream.write(fixture[start : end + 1])
                os.fsync(stream.fileno())
        return 0

    output = Path(option("--output"))
    current = output.stat().st_size
    if current > len(fixture):
        return 63

    end = len(fixture)
    if mode == "interrupt":
        end = max(current + 1, len(fixture) // 2)
        end = min(end, len(fixture) - 1)

    with output.open("r+b", buffering=0) as stream:
        stream.seek(current)
        stream.write(fixture[current:end])
        os.fsync(stream.fileno())

    if mode == "interrupt":
        return 23
    if mode == "swap_stage":
        stage = Path(os.environ["AESIR_FAKE_CURL_STAGE"])
        captured = Path(os.environ["AESIR_FAKE_CURL_CAPTURED"])
        os.replace(stage, captured)
        stage.write_bytes(b"foreign-stage-entry\n")
    if mode == "target_race":
        Path(os.environ["AESIR_FAKE_CURL_TARGET"]).write_bytes(
            b"concurrent-destination\n"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
