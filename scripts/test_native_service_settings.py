#!/usr/bin/env python3
"""Native serve flag admission before key/model access; no GPU or listener."""
import argparse
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True, type=Path)
    options = parser.parse_args()
    binary = str(options.binary.resolve())
    with tempfile.TemporaryDirectory(prefix="aesir service settings ") as temp:
        root = Path(temp)
        base = [binary, "serve", "missing-model.gguf", "--accel", "cuda",
                "--api-key-file", "missing.key"]

        def run(extra):
            result = subprocess.run([*base, *extra], cwd=root, capture_output=True, text=True, timeout=30)
            assert result.returncode != 0, result.stdout + result.stderr
            return result.stdout + result.stderr

        missing_key = run([])
        assert "Cannot open native service descriptor" in missing_key, missing_key
        valid = [("--temperature", "0.8"), ("--top-k", "20"), ("--top-p", "0.7"),
                 ("--min-p", "0.1"), ("--repeat-penalty", "1.2"),
                 ("--repeat-last-n", "128"), ("--seed", "18446744073709551615")]
        # Valid individual and combined flags reach exactly the same absent-key
        # admission as baseline, never the absent model or a GPU allocation.
        for flag, value in valid:
            assert run([flag, value]) == missing_key, flag
        assert run([part for pair in valid for part in pair]) == missing_key
        invalid = [("--temperature", "NaN"), ("--top-k", "0"), ("--top-p", "0"),
                   ("--min-p", "1.1"), ("--repeat-penalty", "0"),
                   ("--repeat-last-n", "8193"), ("--seed", "18446744073709551616")]
        for flag, value in invalid:
            output = run([flag, value])
            assert output != missing_key and any(word in output.lower() for word in ("sampling", "repetition", "top-k")), output
        assert "duplicate service option" in run(["--temperature", "0", "--temperature", "1"])
        assert "duplicate service option" in run(["--seed"])
        assert list(root.iterdir()) == [], "admission unexpectedly wrote files"
    print("PASS native serve sampling: all seven flags, combined admission, pre-key rejection and no writes")


if __name__ == "__main__":
    main()
