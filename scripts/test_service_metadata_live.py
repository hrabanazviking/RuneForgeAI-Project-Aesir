#!/usr/bin/env python3
"""Opt-in real-model S21 catalog/liveness/readiness contract probe.

Uses a temporary catalog and hardlink to an existing local blob. It neither
downloads weights nor changes the operator's catalog.
"""
import argparse
import http.client as http_client
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time


def catalog_digest(catalog, model):
    for line in catalog.splitlines():
        if not line.startswith("ENTRY:"):
            continue
        entry = bytes.fromhex(line[6:]).decode("utf-8")
        fields = dict(row.split(":", 1) for row in entry.split("\n") if ":" in row)
        if fields.get("NAME", "") + ":" + fields.get("TAG", "") == model:
            return fields["DIGEST"]
    raise AssertionError(f"{model} is absent from source catalog")


def http(port, path, token="", body=None):
    connection = http_client.HTTPConnection("127.0.0.1", port, timeout=30)
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    connection.request("POST" if body is not None else "GET", path,
                       json.dumps(body).encode() if body is not None else None, headers)
    response = connection.getresponse()
    code = response.status
    payload = json.loads(response.read())
    connection.close()
    return code, payload


def catalog_command(binary, store, *args):
    result = subprocess.run([binary, *args, "--model-store", str(store)],
                            capture_output=True, text=True, timeout=40)
    assert result.returncode == 0, (args, result.stdout, result.stderr)


def run_mode(binary, model, source, original_store, mode):
    original_catalog = (original_store / "catalog.v1").read_text(encoding="utf-8")
    digest = catalog_digest(original_catalog, model)
    assert digest.startswith("sha256:")
    original_blob = original_store / "blobs" / "sha256" / digest[7:]
    assert original_blob.is_file() and original_blob.stat().st_size == source.stat().st_size
    with (tempfile.TemporaryDirectory(prefix="aesir-s21-", dir=original_store.parent) as directory,
          tempfile.TemporaryDirectory(prefix="aesir-s21-key-") as key_directory):
        root = Path(directory)
        store = root / "models"
        store_arg = store.relative_to(Path.cwd())
        blob_dir = store / "blobs" / "sha256"
        blob_dir.mkdir(parents=True)
        os.link(original_blob, blob_dir / digest[7:])
        catalog_file = store / "catalog.v1"
        catalog_file.write_text(original_catalog, encoding="utf-8")
        key = Path(key_directory) / "key"
        token = ""
        if mode == "native":
            created = subprocess.run([binary, "keygen", str(key)], capture_output=True, timeout=30)
            assert created.returncode == 0, created.stderr
            token = key.read_text().strip()
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        command = [binary, "serve", model if mode == "ollama" else str(source),
                   "--accel", "cuda", "--port", str(port), "--model-store", str(store_arg),
                   "--context", "512", "--max-tokens", "16"]
        command += ["--ollama"] if mode == "ollama" else ["--api-key-file", str(key)]
        log_path = root / "service.log"
        with log_path.open("wb") as log:
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + 120
                while b"inference ready" not in log_path.read_bytes():
                    assert process.poll() is None, log_path.read_text(errors="replace")
                    assert time.monotonic() < deadline, "service startup deadline"
                    time.sleep(.1)
                tiny = root / "tiny.gguf"
                tiny.write_bytes(b"catalog metadata fixture; not runnable model weights\n")
                recipe = root / "Modelfile"
                recipe.write_text("FROM tiny.gguf\n", encoding="utf-8")
                if mode == "native":
                    code, live = http(port, "/health/live", token)
                    assert code == 200 and live == {"schema_version": 1, "status": "ok", "scope": "process"}, live
                    code, ready = http(port, "/health/ready", token)
                    assert code == 200 and ready["ready"] is True and ready["model"] == str(source), ready
                    assert http(port, "/health/live")[0] == 401
                    assert http(port, "/health", token)[1]["status"] == "ready"
                    before = http(port, "/v1/models", token)[1]
                    assert model in {item["id"] for item in before["data"]}, before
                else:
                    assert http(port, "/api/version")[1]["version"] == "0.1.0-aesir"
                    before = http(port, "/api/tags")[1]
                    assert {item["name"] for item in before["models"]} == {model}, before
                    assert http(port, "/api/ps")[1]["models"][0]["name"] == model
                catalog_command(binary, store_arg, "create", "s21-tiny:latest",
                                "--modelfile", str(recipe), "--model", str(tiny))
                listing_path = "/api/tags" if mode == "ollama" else "/v1/models"
                code, listing = http(port, listing_path, token)
                assert code == 200
                names = {item["name" if mode == "ollama" else "id"]
                         for item in listing["models" if mode == "ollama" else "data"]}
                assert "s21-tiny:latest" in names, names
                if mode == "ollama":
                    code, shown = http(port, "/api/show", body={"name": "s21-tiny:latest"})
                    assert code == 200 and shown["model_info"]["aesir.loaded"] is False, shown
                    assert "aesir.context_length" not in shown["model_info"] and shown["parameters"] == "", shown
                catalog_command(binary, store_arg, "rm", "s21-tiny:latest")
                listing = http(port, listing_path, token)[1]
                names = {item["name" if mode == "ollama" else "id"]
                         for item in listing["models" if mode == "ollama" else "data"]}
                assert "s21-tiny:latest" not in names, names
                if mode == "ollama":
                    assert http(port, "/api/show", body={"name": "s21-tiny:latest"})[0] == 404
                    catalog_command(binary, store_arg, "rm", model)
                    assert http(port, "/api/tags")[1]["models"] == []
                    assert http(port, "/api/ps")[1]["models"][0]["name"] == model
                damaged = store / "catalog.bad"
                damaged.write_text("invalid catalog", encoding="utf-8")
                os.replace(damaged, catalog_file)
                unavailable_code, unavailable = http(port, listing_path, token)
                assert unavailable_code == 503, unavailable
                if mode == "ollama":
                    assert unavailable == {"error": "Service Unavailable"}, unavailable
                else:
                    assert unavailable["error"]["code"] == 503, unavailable
                assert http(port, "/api/version" if mode == "ollama" else "/health/live", token)[0] == 200
                if mode == "native":
                    assert http(port, "/health/ready", token)[1]["ready"] is True
                else:
                    assert http(port, "/api/ps")[1]["models"][0]["name"] == model
                print(f"PASS {mode}: live catalog add/remove, resident truth, corruption 503, service remains live", flush=True)
            except Exception as error:
                raise AssertionError(f"{mode}: {error}; service log:\n{log_path.read_text(errors='replace')[-3000:]}") from error
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=20)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=5)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--store", type=Path, required=True)
    args = parser.parse_args()
    for mode in ("native", "ollama"):
        run_mode(str(args.binary.resolve()), args.model, args.source.resolve(),
                 args.store.resolve(), mode)


if __name__ == "__main__":
    main()
