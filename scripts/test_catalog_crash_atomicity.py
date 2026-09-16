#!/usr/bin/env python3
"""Kill the native catalog writer at each durability boundary and restart it."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile


STAGES = (
    ("staged_write", {"old:v1"}),
    ("staged_fsync", {"old:v1"}),
    ("rename", {"old:v1", "new:v1"}),
    ("directory_fsync", {"old:v1", "new:v1"}),
)


def run(
    binary: Path,
    cwd: Path,
    *arguments: str,
    env: dict[str, str] | None = None,
    ok: bool = True,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        [str(binary), *arguments],
        cwd=cwd,
        env=env,
        text=True,
        capture_output=True,
        timeout=30,
        check=False,
    )
    if ok and result.returncode != 0:
        raise AssertionError(result.stderr or result.stdout)
    return result


def catalog_names(binary: Path, cwd: Path, store: str) -> set[str]:
    result = run(binary, cwd, "list", "--format", "json", "--model-store", store)
    return {record["name"] for record in json.loads(result.stdout)}


def compile_shim(source: Path, destination: Path) -> None:
    compiler = os.environ.get("CC", "cc")
    result = subprocess.run(
        [
            compiler,
            "-shared",
            "-fPIC",
            "-O2",
            "-Wall",
            "-Wextra",
            "-Werror",
            str(source),
            "-o",
            str(destination),
            "-ldl",
        ],
        text=True,
        capture_output=True,
        timeout=30,
        check=False,
    )
    if result.returncode != 0:
        raise AssertionError(result.stderr or result.stdout)


def check(binary_argument: str) -> None:
    if os.name != "posix" or not Path("/proc/self/fd").is_dir():
        raise AssertionError("catalog crash injection requires Linux procfs")

    binary = Path(binary_argument).resolve(strict=True)
    source = Path(__file__).resolve().parent / "fixtures" / "catalog_crash_shim.c"
    if not source.is_file():
        raise AssertionError(f"missing crash shim source: {source}")

    with tempfile.TemporaryDirectory(prefix="aesir-catalog-crash-") as temporary:
        root = Path(temporary)
        shim = root / "catalog_crash_shim.so"
        compile_shim(source, shim)

        modelfile = root / "Modelfile"
        modelfile.write_text(
            "FROM fixture.gguf\nSYSTEM Crash atomicity fixture.\n",
            encoding="utf-8",
        )

        baseline = root / "baseline"
        run(
            binary,
            root,
            "create",
            "old:v1",
            "--modelfile",
            modelfile.name,
            "--model-store",
            baseline.name,
        )
        old_catalog = (baseline / "catalog.v1").read_bytes()
        assert catalog_names(binary, root, baseline.name) == {"old:v1"}

        expected = root / "expected"
        shutil.copytree(baseline, expected)
        run(
            binary,
            root,
            "cp",
            "old:v1",
            "new:v1",
            "--model-store",
            expected.name,
        )
        new_catalog = (expected / "catalog.v1").read_bytes()
        assert old_catalog != new_catalog
        assert catalog_names(binary, root, expected.name) == {"old:v1", "new:v1"}

        for stage, expected_names in STAGES:
            store = root / f"store-{stage}"
            shutil.copytree(baseline, store)
            marker = root / f"reached-{stage}"
            environment = os.environ.copy()
            existing_preload = environment.get("LD_PRELOAD")
            environment["LD_PRELOAD"] = (
                f"{shim}:{existing_preload}" if existing_preload else str(shim)
            )
            environment["AESIR_CRASH_STAGE"] = stage
            environment["AESIR_CRASH_ROOT"] = str(store.resolve())
            environment["AESIR_CRASH_MARKER"] = str(marker)

            crashed = run(
                binary,
                root,
                "cp",
                "old:v1",
                "new:v1",
                "--model-store",
                store.name,
                env=environment,
                ok=False,
            )
            assert crashed.returncode == -signal.SIGKILL, (
                stage,
                crashed.returncode,
                crashed.stderr or crashed.stdout,
            )
            assert marker.read_text(encoding="ascii") == stage

            catalog = (store / "catalog.v1").read_bytes()
            assert catalog in (old_catalog, new_catalog), (
                f"{stage} exposed partial or unknown catalog bytes"
            )
            names = catalog_names(binary, root, store.name)
            assert names == expected_names, (
                f"{stage} restart exposed {sorted(names)}, "
                f"expected {sorted(expected_names)}"
            )
            staged_files = list(store.glob(".catalog.tmp.*"))
            if stage in ("staged_write", "staged_fsync"):
                assert len(staged_files) == 1
                assert staged_files[0].read_bytes() == new_catalog
            else:
                assert not staged_files
            if names == {"old:v1"}:
                run(
                    binary,
                    root,
                    "cp",
                    "old:v1",
                    "new:v1",
                    "--model-store",
                    store.name,
                )
            else:
                run(binary, root, "rm", "new:v1", "--model-store", store.name)
                run(
                    binary,
                    root,
                    "cp",
                    "old:v1",
                    "new:v1",
                    "--model-store",
                    store.name,
                )
            assert catalog_names(binary, root, store.name) == {"old:v1", "new:v1"}

    print(
        "PASS catalog crash atomicity: staged write/fsync expose old state; "
        "rename/directory fsync expose complete new state; every restart remains writable"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--binary",
        required=True,
        help="path to the freshly built native aesir binary",
    )
    arguments = parser.parse_args()
    check(arguments.binary)


if __name__ == "__main__":
    main()
