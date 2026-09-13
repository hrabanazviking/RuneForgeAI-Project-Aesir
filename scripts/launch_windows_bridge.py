#!/usr/bin/env python3
"""Decode literal argv transported by launch.ps1; no shell or inference logic."""
import base64
import binascii
import json
import os
from pathlib import Path
import sys


def decode_args(payload):
    if len(payload) > 24000:
        raise ValueError("Argument payload exceeds the supported Windows command-line budget")
    try:
        args = json.loads(base64.b64decode(payload, validate=True).decode("utf-8"))
    except (ValueError, UnicodeError, binascii.Error) as error:
        raise ValueError("Invalid UTF-8 JSON/base64 argument payload") from error
    if not isinstance(args, list) or any(not isinstance(arg, str) or "\0" in arg for arg in args):
        raise ValueError("Argument payload must be an array of NUL-free strings")
    return args


def main():
    try:
        if len(sys.argv) != 2:
            raise ValueError("Expected exactly one encoded argument payload; use scripts/launch.ps1")
        args = decode_args(sys.argv[1])
        launcher = Path(__file__).resolve().with_name("launch.py")
        os.execv(sys.executable, [sys.executable, str(launcher), *args])
    except (ValueError, OSError) as error:
        print(f"Aesir WSL bridge: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
