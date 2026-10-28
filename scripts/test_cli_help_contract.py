"""CLI help contract checks against an explicitly supplied built executable."""
import argparse
from pathlib import Path
import subprocess
import sys


IMPLEMENTED = (
    "home", "keygen", "hardware", "compute", "pull", "inspect", "doctor",
    "alias", "unalias", "favorite", "unfavorite", "repair-preferences",
    "run", "chat", "config", "list|ls", "show", "create", "verify",
    "catalog", "gc", "cp", "rm|delete", "help, -h, --help", "-v, --version",
    "serve", "ps", "stop",
)
RESERVED = (
    "daemon; interactive run", "push",
    "llama-cli; llama-server; llama-bench; exl2; onnx; swarm",
)


def invoke(binary: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run([str(binary), *args], text=True, capture_output=True,
                          timeout=30, check=False)


def check(binary: Path) -> None:
    binary = binary.resolve(strict=True)
    result = invoke(binary, "--help")
    assert result.returncode == 0, result.stdout + result.stderr
    help_text = result.stdout
    assert "Usage:\n  aesir [command] [flags]" in help_text
    assert "Implemented:" in help_text and "Reserved but unsupported:" in help_text
    for command in IMPLEMENTED:
        assert command in help_text, f"documented command missing: {command}"
    for command in RESERVED:
        assert command in help_text, f"unsupported boundary missing: {command}"
    assert "See ../CAPABILITY_LEDGER.md" in help_text

    # The version command must remain explicit about the absence of a release version.
    version = invoke(binary, "--version")
    assert version.returncode == 0
    assert "unversioned" in version.stdout.lower()

    # One advertised unsupported surface must fail explicitly and never print help.
    unsupported = invoke(binary, "llama-server")
    assert unsupported.returncode != 0
    assert "not implemented" in (unsupported.stdout + unsupported.stderr).lower()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path)
    args = parser.parse_args()
    check(args.binary)
    print("CLI help contract: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
