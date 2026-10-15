#!/usr/bin/env python3
"""Opt-in S23 strict Boolean JSON probe on locally installed weights.

Creates a test-owned hardlinked catalog; never downloads or mutates the
operator's model store. Requires a CUDA-capable WSL host and a compiled binary.
"""
import argparse
import http.client
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time


def catalog_entries(catalog):
    for line in catalog.splitlines():
        if line.startswith("ENTRY:"):
            yield dict(row.split(":", 1) for row in
                       bytes.fromhex(line[6:]).decode().splitlines() if ":" in row)


def send(port, token, body, path="/v1/chat/completions"):
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=90)
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    connection.request("POST", path, body, headers)
    response = connection.getresponse()
    status = response.status
    payload = json.loads(response.read())
    connection.close()
    return status, payload


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--store", type=Path, required=True)
    parser.add_argument("--ollama", action="store_true", help="exercise OpenAI routes in Ollama service mode")
    args = parser.parse_args()
    binary = str(args.binary.resolve())
    source_store = args.store.resolve()
    catalog = (source_store / "catalog.v1").read_text(encoding="utf-8")
    entries = list(catalog_entries(catalog))
    assert any(e.get("NAME", "") + ":" + e.get("TAG", "") == args.model
               for e in entries), "model absent from source catalog"
    with (tempfile.TemporaryDirectory(prefix="aesir-s23-", dir=source_store.parent) as work,
          tempfile.TemporaryDirectory(prefix="aesir-s23-key-") as key_work):
        root = Path(work)
        store = root / "models"
        blob_dir = store / "blobs" / "sha256"
        blob_dir.mkdir(parents=True)
        for entry in entries:
            digest = entry.get("DIGEST", "")
            assert digest.startswith("sha256:")
            source = source_store / "blobs" / "sha256" / digest[7:]
            assert source.is_file(), f"missing catalog blob {digest}"
            if not (blob_dir / digest[7:]).exists():
                os.link(source, blob_dir / digest[7:])
        (store / "catalog.v1").write_text(catalog, encoding="utf-8")
        runtime_record = (Path("/tmp") / f"aesir-runtime-{os.geteuid()}" /
                          f"service-{store.stat().st_dev}-{store.stat().st_ino}.v1")
        key_file = Path(key_work) / "key"
        result = subprocess.run([binary, "keygen", str(key_file)],
                                capture_output=True, timeout=30)
        assert result.returncode == 0, result.stderr
        token = key_file.read_text().strip()
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        command = [binary, "serve", args.model, "--accel", "cuda", "--port", str(port),
                   "--model-store", str(store.relative_to(Path.cwd())),
                   "--context", "512", "--max-tokens", "16"]
        command += ["--ollama"] if args.ollama else ["--api-key-file", str(key_file)]
        if args.ollama:
            token = ""
        log_path = root / "service.log"
        with log_path.open("wb") as log:
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + 120
                while b"inference ready" not in log_path.read_bytes():
                    assert process.poll() is None, log_path.read_text(errors="replace")
                    assert time.monotonic() < deadline, "service startup deadline"
                    time.sleep(.1)
                base = {"model": args.model, "messages": [{"role": "user", "content": "Is 2 plus 2 equal to 4?"}], "max_tokens": 16}
                format_ok = {"type": "json_schema", "json_schema": {
                    "name": "answer", "strict": True, "schema": {"type": "boolean"}}}
                bad_formats = [
                    {"type": "json_object"},
                    {"type": "json_schema", "json_schema": {"name": "answer", "strict": True, "schema": {"type": "string"}}},
                    {"type": "json_schema", "json_schema": {"name": "answer", "strict": True, "schema": {"type": "boolean", "enum": [True]}}},
                    {"type": "json_schema", "json_schema": {"name": "answer", "strict": False, "schema": {"type": "boolean"}}},
                ]
                for bad in bad_formats:
                    code, _ = send(port, token, json.dumps({**base, "response_format": bad}))
                    assert code == 400, (bad, code)
                for bad_request in ({**base, "response_format": format_ok, "stream": True},
                                    {**base, "response_format": format_ok, "temperature": 0.7}):
                    code, _ = send(port, token, json.dumps(bad_request))
                    assert code == 400, (bad_request, code)
                assert b"phase=generation" not in log_path.read_bytes(), "invalid schema reached generation"
                code, result = send(port, token, json.dumps({**base, "response_format": format_ok}))
                assert code == 200, (code, result)
                content = result["choices"][0]["message"]["content"]
                assert type(json.loads(content)) is bool, content
                assert result["choices"][0]["finish_reason"] == "stop", result
                assert 1 <= result["usage"]["completion_tokens"] < 16, result
                completion = {"model": args.model, "prompt": "Is 2 plus 2 equal to 4?",
                              "max_tokens": 16, "response_format": format_ok}
                code, result = send(port, token, json.dumps(completion), "/v1/completions")
                assert code == 200, (code, result)
                assert type(json.loads(result["choices"][0]["text"])) is bool, result
                assert result["choices"][0]["finish_reason"] == "stop", result
                code, plain = send(port, token, json.dumps({**base, "messages": [
                    {"role": "user", "content": "Reply with the single word hello."}]}))
                assert code == 200 and plain["choices"][0]["message"]["content"], plain
                print(f"PASS S23 {'ollama' if args.ollama else 'native'}: JSON boolean chat/completion, strict schema refusal, early stop", flush=True)
            except Exception as error:
                raise AssertionError(f"S23 live probe: {error}; service log:\n{log_path.read_text(errors='replace')[-3000:]}") from error
            finally:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=30)
                if runtime_record.is_file():
                    lines = runtime_record.read_text().splitlines()
                    if len(lines) > 1 and lines[1] == str(process.pid):
                        runtime_record.unlink()


if __name__ == "__main__":
    main()
