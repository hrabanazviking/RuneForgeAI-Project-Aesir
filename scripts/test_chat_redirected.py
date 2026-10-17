#!/usr/bin/env python3
"""Opt-in redirected native CUDA chat smoke with an installed model."""

import argparse
import subprocess


def main(binary, store):
    result = subprocess.run(
        [binary, "chat", "--accel", "cuda", "--model-store", store,
         "--context", "512", "--max-tokens", "4"],
        input="\n/compose\n界\n/send\n/history\n/transcript\n/bye\n".encode("utf-8"),
        capture_output=True, timeout=180,
    )
    output = result.stdout.decode("utf-8", errors="replace")
    errors = result.stderr.decode("utf-8", errors="replace")
    if result.returncode:
        raise AssertionError(f"redirected chat exited {result.returncode}: {errors[-500:]!r}")
    for marker in (
        "backend=cuda", "User: 界", "History 1/1", "1 You: 界",
        "Transcript view requires interactive stdin and stdout", "Completed turns: 1",
    ):
        if marker not in output:
            raise AssertionError(f"redirected chat omitted {marker!r}: {output[-800:]!r}")
    if "\x1b" in output:
        raise AssertionError("redirected chat emitted ANSI escape sequences")
    print("native redirected CUDA compose/history/Unicode/no-ANSI: PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    parser.add_argument("--store", default=".aesir/models")
    args = parser.parse_args()
    main(args.binary, args.store)
