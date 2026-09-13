#!/usr/bin/env python3
"""Exercise the prepared launcher and real native Home, without model loading."""
import argparse
from pathlib import Path
import subprocess
import sys
import tempfile
import uuid

from test_native_home import Terminal


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--launcher", type=Path, default=Path(__file__).with_name("launch.py"))
    options = parser.parse_args()
    launcher = options.launcher.resolve()
    missing_store = ".aesir-test-launch-" + uuid.uuid4().hex
    with tempfile.TemporaryDirectory(prefix="aesir launch caller ") as temp:
        result = subprocess.run([sys.executable, str(launcher), "--check"], cwd=temp,
                                capture_output=True, text=True, timeout=60)
        assert result.returncode == 0, result.stdout + result.stderr
        terminal = Terminal(sys.executable, Path(temp), str(launcher), "--", "home",
                            "--model-store", missing_store)
        try:
            terminal.expect("Installed weights: 0 | Recipes: 0", timeout=60)
            terminal.expect("Choice:")
            terminal.send("1\n")
            terminal.expect("No installed weights available for chat")
            terminal.expect("Choice:")
            terminal.send("q\n")
            assert terminal.process.wait(timeout=10) == 0
        finally:
            terminal.close()
        result = subprocess.run([sys.executable, str(launcher), "--", "home"], cwd=temp,
                                capture_output=True, text=True, timeout=60)
        assert result.returncode != 0 and "interactive terminal" in result.stdout + result.stderr
    assert not (launcher.parent.parent / missing_store).exists()
    print("PASS native launch: current build, unrelated cwd, empty-store Home, no implicit writes, redirected refusal")


if __name__ == "__main__":
    main()
