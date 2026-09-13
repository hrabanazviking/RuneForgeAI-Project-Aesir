#!/usr/bin/env python3
"""Exercise preference health and explicit repair without touching user stores."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time


def check(binary: str) -> None:
    binary = str(Path(binary).resolve())
    with tempfile.TemporaryDirectory(prefix="aesir-preference-health-") as directory:
        root = Path(directory)

        def run(*args: str, ok: bool = True, model_store: str = "store") -> str:
            result = subprocess.run([binary, *args, "--model-store", model_store],
                                    cwd=root, capture_output=True, text=True, timeout=30)
            assert (result.returncode == 0) == ok, result.stderr or result.stdout
            return result.stdout

        (root / "Modelfile").write_text("FROM local.gguf\n", encoding="utf-8")
        (root / "weights.bin").write_bytes(b"local-weights-fixture\n")
        for name in ("live", "gone", "recipe"):
            weights = () if name == "recipe" else ("--model", "weights.bin")
            run("create", name, "--modelfile", "Modelfile", *weights)
            run("alias", name + "-alias", name)
            run("favorite", name)
        run("rm", "gone")
        run("create", "other", "--modelfile", "Modelfile", model_store="other-store")
        run("alias", "other-alias", "other", model_store="other-store")
        run("rm", "other", model_store="other-store")
        run("create", "only-recipe", "--modelfile", "Modelfile", model_store="other-store")
        chooser = subprocess.run(
            [binary, "chat", "--accel", "cuda", "--model-store", "store"], cwd=root,
            input="invalid\n", text=True, capture_output=True, timeout=30,
        )
        assert chooser.returncode != 0 and "Model selection must be a listed number" in chooser.stdout + chooser.stderr, chooser.stdout + chooser.stderr
        assert "live:latest" in chooser.stdout and "recipe:latest" not in chooser.stdout
        assert "22 bytes" in chooser.stdout, chooser.stdout
        recipe_only = subprocess.run(
            [binary, "chat", "--accel", "cuda", "--model-store", "other-store"], cwd=root,
            input="", text=True, capture_output=True, timeout=30,
        )
        assert recipe_only.returncode != 0 and "No installed models" in recipe_only.stdout + recipe_only.stderr, recipe_only.stdout + recipe_only.stderr
        assert "Select model" not in recipe_only.stdout
        store = root / "store"
        pref = store / "preferences.v1"

        def snapshot() -> dict[str, bytes]:
            return {str(p.relative_to(root)): p.read_bytes() for p in root.rglob("*") if p.is_file()}

        before = snapshot()
        preview = run("repair-preferences")
        assert "DRY RUN" in preview and "gone-alias" in preview and "missing_model" in preview
        assert "recipe_only" in preview
        run("repair-preferences", "--dry-run")
        assert snapshot() == before, "preview changed durable data"
        report = json.loads(run("doctor", "--format", "json"))
        health = report["preferences"]
        assert health["readable"] and health["stale_count"] == 2
        assert len(health["findings"]) == 4
        text_report = run("doctor")
        assert "gone-alias" in text_report and "recipe_only" in text_report
        assert "stale_preferences" in {issue["code"] for issue in report["issues"]}
        assert snapshot() == before, "doctor changed durable data"

        for options in [("--apply", "--dry-run"), ("--apply", "--apply"),
                        ("--dry-run", "--dry-run"), ("unexpected",), ("--unknown",)]:
            run("repair-preferences", *options, ok=False)
        assert snapshot() == before
        run("aliases", "--apply", ok=False)

        catalog_path = store / "catalog.v1"
        intact_catalog = catalog_path.read_bytes()
        catalog_path.write_bytes(b"AESIR_MODEL_CATALOG_V1\nCOUNT:0\x00garbage")
        nul_catalog = snapshot()
        run("repair-preferences", "--apply", ok=False)
        assert snapshot() == nul_catalog, "NUL-truncated catalog authorized pruning"
        catalog_path.write_bytes(intact_catalog)
        encoded_lines = intact_catalog.decode().splitlines()
        encoded_lines[2] += "00ff"
        catalog_path.write_text("\n".join(encoded_lines), encoding="utf-8")
        encoded_nul_catalog = snapshot()
        run("repair-preferences", "--apply", ok=False)
        assert snapshot() == encoded_nul_catalog
        catalog_path.write_bytes(intact_catalog)
        intact_preferences = pref.read_bytes()
        pref.write_bytes(intact_preferences + b"\x00hidden")
        nul_preferences = snapshot()
        run("repair-preferences", "--apply", ok=False)
        assert snapshot() == nul_preferences
        preference_lines = intact_preferences.decode().splitlines()
        preference_lines[2] += "00ff"
        payload = "\n".join(preference_lines[:-1]) + "\n"
        checksum = 14695981039346656037
        for byte in payload.encode():
            checksum = ((checksum ^ byte) * 1099511628211) & ((1 << 64) - 1)
        pref.write_text(payload + f"CHECKSUM:{checksum:016x}\n", encoding="utf-8")
        encoded_nul_preferences = snapshot()
        run("repair-preferences", "--apply", ok=False)
        assert snapshot() == encoded_nul_preferences
        pref.unlink()
        no_preferences = snapshot()
        run("repair-preferences", ok=False)
        run("repair-preferences", "--apply", ok=False)
        absent_health = json.loads(run("doctor", "--format", "json"))["preferences"]
        assert not absent_health["readable"] and absent_health["stale_count"] is None
        assert snapshot() == no_preferences, "missing preferences were recreated by repair"
        pref.write_bytes(intact_preferences)

        applied = run("repair-preferences", "--apply")
        assert "Removed 2" in applied
        after = snapshot()
        assert after.pop("store/preferences.v1") != before.pop("store/preferences.v1")
        assert after == before, "repair changed catalog, blobs, or unrelated files"
        aliases = run("aliases")
        favorites = run("favorites")
        assert "gone" not in aliases and "gone" not in favorites
        assert "live-alias" in aliases and "recipe-alias" in aliases
        assert "live:latest" in favorites and "recipe:latest" in favorites
        committed = snapshot()
        unchanged_inode = pref.stat().st_ino
        run("repair-preferences", "--apply")
        assert snapshot() == committed, "no-op repair rewrote content"
        assert pref.stat().st_ino == unchanged_inode, "no-op repair replaced the record"
        assert json.loads(run("doctor", "--format", "json"))["preferences"]["stale_count"] == 0

        # A process waiting for the root lock must inspect the catalog only
        # after acquiring it. Restore the removed manifest while it waits.
        catalog = store / "catalog.v1"
        valid_catalog = catalog.read_bytes()
        valid_preferences = pref.read_bytes()
        run("rm", "live")
        lock = os.open(store, os.O_RDONLY | os.O_DIRECTORY)
        process = None
        try:
            fcntl.flock(lock, fcntl.LOCK_EX)
            process = subprocess.Popen(
                [binary, "repair-preferences", "--apply", "--model-store", "store"],
                cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            )
            deadline = time.monotonic() + 10
            while "lock" not in Path(f"/proc/{process.pid}/wchan").read_text():
                assert process.poll() is None, "repair did not wait for the store lock"
                assert time.monotonic() < deadline, "repair never reached the store lock"
                time.sleep(0.01)
            catalog.write_bytes(valid_catalog)
            fcntl.flock(lock, fcntl.LOCK_UN)
            stdout, stderr = process.communicate(timeout=30)
            assert process.returncode == 0, stderr
            assert "Removed 0" in stdout and pref.read_bytes() == valid_preferences
        finally:
            os.close(lock)
            if process is not None and process.poll() is None:
                process.kill()
                process.communicate()

        catalog.unlink()
        missing_catalog = snapshot()
        run("repair-preferences", "--apply", ok=False)
        assert snapshot() == missing_catalog, "missing catalog authorized pruning"
        catalog.write_bytes(b"corrupt\n")
        damaged = snapshot()
        run("repair-preferences", ok=False)
        run("repair-preferences", "--apply", ok=False)
        assert snapshot() == damaged
        catalog.write_bytes(valid_catalog)
        pref.write_bytes(b"corrupt\n")
        damaged = snapshot()
        run("repair-preferences", ok=False)
        run("repair-preferences", "--apply", ok=False)
        assert snapshot() == damaged
        health = json.loads(run("doctor", "--format", "json"))["preferences"]
        assert not health["readable"] and health["stale_count"] is None and health["error"]
        pref.write_bytes(valid_preferences)
        for blob in (store / "blobs" / "sha256").iterdir():
            blob.unlink()  # Test-owned bytes only; missing weights must preserve shortcuts.
        run("repair-preferences", "--apply")
        assert pref.read_bytes() == valid_preferences
        assert json.loads(run("doctor", "--format", "json"))["preferences"]["stale_count"] == 0

    print("PASS preference preview/apply, health, preservation, corruption and locked recheck")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True)
    check(parser.parse_args().binary)
