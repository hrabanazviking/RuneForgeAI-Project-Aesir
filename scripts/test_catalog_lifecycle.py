"""Separate-process catalog migration, backup, restore, and contention proof."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True)
    binary = str(Path(parser.parse_args().binary).resolve())

    with tempfile.TemporaryDirectory(prefix="aesir-catalog-lifecycle-") as tmp:
        root = Path(tmp)
        modelfile = root / "Modelfile"
        modelfile.write_text(
            "FROM fixture.gguf\nSYSTEM Catalog lifecycle fixture.\n",
            encoding="utf-8",
        )

        def run(*arguments: str, ok: bool = True) -> subprocess.CompletedProcess[str]:
            result = subprocess.run(
                [binary, *arguments], cwd=root, text=True,
                capture_output=True, timeout=30, check=False,
            )
            if ok:
                assert result.returncode == 0, result.stderr or result.stdout
            else:
                assert result.returncode != 0, arguments
            return result

        seed = "seed-store"
        run(
            "create", "legacy:v1", "--modelfile", "Modelfile",
            "--model-store", seed,
        )
        seed_lines = (root / seed / "catalog.v1").read_text(
            encoding="utf-8"
        ).splitlines()
        assert seed_lines[:2] == ["AESIR_MODEL_CATALOG_V1", "COUNT:1"]
        manifest = bytes.fromhex(seed_lines[2].removeprefix("ENTRY:")).decode()
        legacy = root / "legacy.catalog"
        legacy.write_text("===MANIFEST===\n" + manifest, encoding="utf-8")

        store = "migrated-store"
        run("catalog", "migrate", "legacy.catalog", "--model-store", store)
        migrated = root / store / "catalog.v1"
        assert migrated.read_text(encoding="utf-8").startswith(
            "AESIR_MODEL_CATALOG_V1\nCOUNT:1\n"
        )

        # Six fresh processes contend on one root lock. Every commit must reload
        # the preceding winner, preserving the migrated record and all writers.
        writers = [
            subprocess.Popen(
                [
                    binary, "create", f"writer-{index}:v1", "--modelfile",
                    "Modelfile", "--model-store", store,
                ],
                cwd=root, text=True, stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            for index in range(6)
        ]
        for process in writers:
            stdout, stderr = process.communicate(timeout=30)
            assert process.returncode == 0, stderr or stdout
        names = {
            item["name"] for item in json.loads(
                run("list", "--format", "json", "--model-store", store).stdout
            )
        }
        assert names == {"legacy:v1"} | {
            f"writer-{index}:v1" for index in range(6)
        }

        backup = root / "catalog.backup"
        run("catalog", "backup", str(backup), "--model-store", store)
        backup_bytes = backup.read_bytes()
        assert backup_bytes == migrated.read_bytes()
        overwrite = run(
            "catalog", "backup", str(backup), "--model-store", store,
            ok=False,
        )
        assert "must be new" in overwrite.stderr + overwrite.stdout
        assert backup.read_bytes() == backup_bytes
        protected = root / "protected"
        protected.write_bytes(b"do-not-overwrite")
        linked_backup = root / "linked.backup"
        linked_backup.symlink_to(protected)
        run(
            "catalog", "backup", str(linked_backup), "--model-store", store,
            ok=False,
        )
        assert protected.read_bytes() == b"do-not-overwrite"

        run("rm", "legacy:v1", "--model-store", store)
        migrated.write_text("corrupt current catalog\n", encoding="utf-8")
        run("catalog", "restore", str(backup), "--model-store", store)
        assert migrated.read_bytes() == backup_bytes

        invalid = root / "invalid.backup"
        invalid.write_bytes(backup_bytes[:-1])
        before = migrated.read_bytes()
        rejected = run(
            "catalog", "restore", str(invalid), "--model-store", store,
            ok=False,
        )
        assert "catalog" in rejected.stderr + rejected.stdout
        assert migrated.read_bytes() == before

        fifo = root / "backup.fifo"
        os.mkfifo(fifo)
        fifo_rejected = run(
            "catalog", "restore", str(fifo), "--model-store", store,
            ok=False,
        )
        assert "regular file" in fifo_rejected.stderr + fifo_rejected.stdout
        assert migrated.read_bytes() == before

        weights = root / "weights.bin"
        weights.write_bytes(b"catalog-restore-blob-fixture\n")
        run(
            "create", "weighted:v1", "--modelfile", "Modelfile",
            "--model", "weights.bin", "--model-store", "blob-source",
        )
        blob_backup = root / "blob.backup"
        run(
            "catalog", "backup", str(blob_backup),
            "--model-store", "blob-source",
        )
        missing_blob = run(
            "catalog", "restore", str(blob_backup),
            "--model-store", "missing-blob-store", ok=False,
        )
        assert "missing" in missing_blob.stderr + missing_blob.stdout
        assert not (root / "missing-blob-store" / "catalog.v1").exists()

        migration_again = run(
            "catalog", "migrate", str(legacy), "--model-store", store,
            ok=False,
        )
        assert "catalog-free" in migration_again.stderr + migration_again.stdout
        assert migrated.read_bytes() == before
        assert not list((root / store).glob(".catalog.tmp.*"))

    print(
        "PASS catalog lifecycle: atomic legacy migration, immutable backup, "
        "validate-before-replace restore, rollback, and six-writer preservation"
    )


if __name__ == "__main__":
    main()
