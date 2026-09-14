#!/usr/bin/env python3
"""Duplicate recipe settings must not alter an existing native catalog."""
import argparse
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True, type=Path)
    options = parser.parse_args()
    binary = str(options.binary.resolve())
    with tempfile.TemporaryDirectory(prefix="aesir recipe admission ") as temp:
        root = Path(temp)
        recipe = root / "Modelfile"

        def create(name):
            return subprocess.run([binary, "create", name, "--modelfile", str(recipe)],
                                  cwd=root, capture_output=True, text=True, timeout=30)

        recipe.write_text('FROM fixture.gguf\nPARAMETER stop "stop here PARAMETER now"\n')
        result = create("retained")
        assert result.returncode == 0, result.stdout + result.stderr

        def durable_bytes():
            return {str(path.relative_to(root)): path.read_bytes()
                    for path in (root / ".aesir").rglob("*") if path.is_file()}

        original = durable_bytes()
        assert original, "successful creation did not produce catalog data"
        for setting in ("temperature 0.7", 'stop "stop here"'):
            recipe.write_text(f"FROM fixture.gguf\nPARAMETER {setting}\nPARAMETER {setting}\n")
            result = create("rejected")
            assert result.returncode != 0, result.stdout + result.stderr
            assert "Duplicate Modelfile PARAMETER" in result.stdout + result.stderr
            assert durable_bytes() == original, "rejected recipe changed durable data"
    print("PASS native recipe settings: literal-value create, duplicate temperature/stop rejection, catalog preserved")


if __name__ == "__main__":
    main()
