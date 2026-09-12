#!/usr/bin/env python3
"""Built-CLI diagnostic regression; uses isolated stores and no inference."""

import argparse
import json
from pathlib import Path
import subprocess
import tempfile


def check(binary: str) -> None:
    binary = str(Path(binary).resolve())
    with tempfile.TemporaryDirectory(prefix="aesir-doctor-") as directory:
        root = Path(directory)

        def run(*args: str, ok: bool = True) -> str:
            result = subprocess.run(
                [binary, *args], cwd=root, capture_output=True, text=True,
                timeout=60, check=False,
            )
            assert (result.returncode == 0) == ok, result.stderr or result.stdout
            return result.stdout

        empty = run("doctor", "--model-store", "store")
        assert "SYSTEM NEEDS ATTENTION" in empty
        assert "model execution not tested" in empty
        (root / "config.json").write_text(
            json.dumps({"storage": {"model_store_path": "store"}}), encoding="utf-8"
        )
        (root / "Modelfile").write_text("FROM example.gguf\n", encoding="utf-8")
        run("create", "recipe:v1", "--modelfile", "Modelfile", "--config", "config.json")
        recipe = run("doctor", "--model-store", "store")
        rows = recipe.splitlines()
        assert any(row.startswith("Recipe-only entries") and row.endswith("1") for row in rows)
        assert any(row.startswith("Installed weights") and row.endswith("0") for row in rows)
        assert "SYSTEM NEEDS ATTENTION" in recipe, recipe
        for args in [("--model-store", ""), ("--model-store", "../unsafe"),
                     ("--model-store",), ("--model-store", "a", "--model-store", "b")]:
            assert "Project Aesir Diagnostic" not in run("doctor", *args, ok=False)
    print("PASS: built doctor empty/recipe-only readiness and strict store arguments")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True)
    check(parser.parse_args().binary)
