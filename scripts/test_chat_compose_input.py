#!/usr/bin/env python3
"""Redirected-input regression for the model-free native composer harness."""

import argparse
import subprocess


def run(binary, data):
    result = subprocess.run([binary], input=data, capture_output=True, timeout=10)
    if result.returncode:
        raise AssertionError(f"harness failed: {result.stderr[-500:]!r}")
    return result.stdout.decode("utf-8")


def main(binary):
    for payload in (b"", b"partial-no-newline", b"blank\npartial-no-newline"):
        output = run(binary, payload)
        if "Draft cancelled at EOF" not in output or "RESULT eof" not in output:
            raise AssertionError(f"EOF submitted or hung on partial draft: {output!r}")
        if "RESULT submitted" in output:
            raise AssertionError("EOF committed a partial draft")
    empty_send = run(binary, b"/send\n")
    if "Draft is empty" not in empty_send or "RESULT eof" not in empty_send:
        raise AssertionError("empty /send was not rejected before EOF")
    submitted = run(binary, "世界\n/send\n".encode("utf-8"))
    if "RESULT submitted 世界" not in submitted:
        raise AssertionError("explicit /send did not submit Unicode content")
    print("native compose redirected EOF/partial/empty-send/Unicode: PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    args = parser.parse_args()
    main(args.binary)
