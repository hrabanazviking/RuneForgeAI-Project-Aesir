"""Regression proof that caller-controlled FIFOs fail closed without stalling."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile


def run_rejected(binary: Path, cwd: Path, args: list[str], expected: str) -> None:
    try:
        result = subprocess.run(
            [str(binary), *args],
            cwd=cwd,
            text=True,
            capture_output=True,
            timeout=5,
        )
    except subprocess.TimeoutExpired as error:
        raise AssertionError(f"special-file request stalled: {' '.join(args)}") from error
    evidence = result.stdout + result.stderr
    assert result.returncode != 0, evidence
    assert expected in evidence, evidence


def write_config(path: Path) -> None:
    path.write_text(
        json.dumps(
            {
                "hardware": {
                    "acceleration_backend": "auto",
                    "target_npu": "auto",
                    "num_gpu_layers": 0,
                    "max_threads": 0,
                },
                "safety": {
                    "skaldbrodir_enabled": False,
                    "thinking_enabled": False,
                },
                "experimental_paradigms": {
                    "cia_enabled": False,
                    "wic_enabled": False,
                    "nsfi_enabled": False,
                    "mqari_enabled": False,
                },
                "interface": {"tui_enabled": False},
                "storage": {"model_store_path": "models"},
                "sampling": {"temperature": 0.0, "top_p": 1.0},
            }
        ),
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True)
    args = parser.parse_args()
    binary = Path(args.binary).resolve(strict=True)

    with tempfile.TemporaryDirectory(prefix="aesir-special-files-") as temporary:
        root = Path(temporary)
        config = root / "aesir.config.json"
        modelfile = root / "Modelfile"
        fifo = root / "hostile.fifo"
        write_config(config)
        modelfile.write_text("FROM fixture.gguf\n", encoding="utf-8")
        os.mkfifo(fifo, 0o600)

        run_rejected(binary, root, ["config", "--config", str(fifo)], "regular file")
        run_rejected(binary, root, ["inspect", str(fifo)], "regular file")
        run_rejected(
            binary,
            root,
            ["create", "blocked", "--modelfile", str(fifo), "--config", str(config)],
            "regular file",
        )
        run_rejected(
            binary,
            root,
            [
                "create",
                "blocked",
                "--modelfile",
                str(modelfile),
                "--model",
                str(fifo),
                "--config",
                str(config),
            ],
            "regular file",
        )

        source = root / "tiny-model.bin"
        source.write_bytes(b"aesir-special-file-regression")
        created = subprocess.run(
            [
                str(binary),
                "create",
                "installed",
                "--modelfile",
                str(modelfile),
                "--model",
                str(source),
                "--config",
                str(config),
            ],
            cwd=root,
            text=True,
            capture_output=True,
            timeout=5,
        )
        assert created.returncode == 0, created.stdout + created.stderr
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        installed_blob = root / "models" / "blobs" / "sha256" / digest
        installed_blob.unlink()
        os.mkfifo(installed_blob, 0o600)
        run_rejected(
            binary,
            root,
            ["verify", "installed", "--config", str(config)],
            "regular file",
        )

        model_store = root / "models"
        model_store.mkdir(exist_ok=True)
        catalog = model_store / "catalog.v1"
        catalog.unlink(missing_ok=True)
        os.mkfifo(catalog, 0o600)
        run_rejected(
            binary,
            root,
            ["list", "--config", str(config)],
            "regular file",
        )

    print(
        "PASS: configuration, GGUF, Modelfile, source/installed blob, "
        "and catalog FIFOs rejected"
    )


if __name__ == "__main__":
    main()
