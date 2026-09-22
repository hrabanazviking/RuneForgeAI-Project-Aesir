"""Separate-process native chat startup and model-switch failure checks."""

import argparse
from pathlib import Path
import subprocess
import tempfile


def invoke(binary: str, missing: Path, *extra: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [binary, "chat", str(missing), "--accel", "cuda", *extra],
        text=True,
        capture_output=True,
        timeout=30,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True)
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="aesir-chat-recovery-") as tmp:
        missing = Path(tmp) / "missing.gguf"

        initial = invoke(args.binary, missing)
        initial_output = initial.stdout + initial.stderr
        assert initial.returncode != 0, initial_output
        assert "check model integrity and available device memory" in initial_output
        assert f"restart Aesir with model reference '{missing}'" in initial_output
        assert "no turn was committed" in initial_output

        switched = invoke(
            args.binary, missing, "--switch-origin", "previous-model"
        )
        switched_output = switched.stdout + switched.stderr
        assert switched.returncode != 0, switched_output
        assert "previous model was unloaded" in switched_output
        assert "conversation was reset" in switched_output
        assert "previous model reference 'previous-model'" in switched_output
        assert "no target turn was committed" in switched_output

    print("PASS: startup and post-switch load failures give exact restart paths")


if __name__ == "__main__":
    main()
