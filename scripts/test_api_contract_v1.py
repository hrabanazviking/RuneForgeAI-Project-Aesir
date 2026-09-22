#!/usr/bin/env python3
"""Independent HTTP client for the authored API v1 request/response fixtures.

Requires an already-installed catalog model and a locally built CUDA binary.
Never downloads a model or mutates the catalog. Runs each service mode separately.
"""
import argparse
import http.client
import json
from pathlib import Path
import secrets
import socket
import subprocess
import tempfile
import time


FIXTURES = Path(__file__).with_name("fixtures") / "api_contract_v1.json"


def field(value, dotted):
    components = dotted[1:].split("/") if dotted.startswith("/") else dotted.split(".")
    for component in components:
        value = value[int(component)] if isinstance(value, list) else value[component]
    return value


def substitute(value, model):
    if isinstance(value, str):
        return model if value == "$MODEL" else value
    if isinstance(value, list):
        return [substitute(item, model) for item in value]
    if isinstance(value, dict):
        return {key: substitute(item, model) for key, item in value.items()}
    return value


def check_case(port, token, model, case):
    headers = {"Content-Type": "application/json"}
    if token and not case.get("anonymous"):
        headers["Authorization"] = "Bearer " + token
    body = case.get("body")
    payload = None if body is None else json.dumps(substitute(body, model), ensure_ascii=False).encode()
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=60)
    try:
        connection.request(case["method"], case["path"], payload, headers)
        response = connection.getresponse()
        raw = response.read()
        assert response.status == case["status"], (case["id"], response.status, raw[:500])
        framing = case.get("framing")
        if framing:
            assert response.getheader("Content-Length") is None, case["id"]
        else:
            assert int(response.getheader("Content-Length")) == len(raw), case["id"]
        assert response.getheader("Connection") == "close", case["id"]
        assert response.getheader("Cache-Control") == "no-store", case["id"]
        assert response.getheader("Content-Type").split(";")[0] == case.get("content_type", "application/json"), case["id"]
        if token:
            assert token.encode() not in raw, case["id"]
        if framing == "sse-incremental":
            events = [event for event in raw.decode().split("\n\n") if event]
            assert len(events) >= 3 and events[-1] == "data: [DONE]", (case["id"], events)
            assert all(event.startswith("data: {") and "\n" not in event for event in events[:-1]), case["id"]
            records = [json.loads(event[6:]) for event in events[:-1]]
            data = records[-1]
            assert type(data["choices"][0]["finish_reason"]) is str, case["id"]
            assert all(item["choices"][0]["finish_reason"] is None for item in records[:-1]), case["id"]
            assert any((item["choices"][0].get("delta", {}).get("content") or item["choices"][0].get("text"))
                       for item in records[:-1]), case["id"]
        elif framing == "ndjson-incremental":
            lines = raw.decode().splitlines()
            assert len(lines) >= 2 and raw.endswith(b"\n"), (case["id"], raw[:500])
            records = [json.loads(line) for line in lines]
            assert all(item["done"] is False for item in records[:-1]), case["id"]
            assert records[-1]["done"] is True, case["id"]
            data = records[-1]
        else:
            data = json.loads(raw)
        for path, kind in case.get("fields", {}).items():
            actual = field(data, path)
            valid = type(actual) is int if kind == "int" else type(actual) is str
            assert valid, (case["id"], path, kind, actual)
        for path, expected in substitute(case.get("equals", {}), model).items():
            assert field(data, path) == expected, (case["id"], path, data)
        if "usage" in data:
            usage = data["usage"]
            assert usage["total_tokens"] == usage["prompt_tokens"] + usage["completion_tokens"], case["id"]
        return data
    finally:
        connection.close()


def run_mode(binary, model, mode, cases):
    with tempfile.TemporaryDirectory(prefix="aesir-contract-v1-") as directory:
        root = Path(directory)
        key = root / "key"
        token = ""
        if mode == "native":
            generated = subprocess.run([binary, "keygen", str(key)], capture_output=True, timeout=30)
            assert generated.returncode == 0, generated.stderr
            token = key.read_text().strip()
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        log_path = root / "service.log"
        command = [binary, "serve", model, "--accel", "cuda", "--context", "512",
                   "--max-tokens", "16", "--timeout-ms", "60000", "--port", str(port)]
        command += ["--api-key-file", str(key)] if mode == "native" else ["--ollama"]
        with log_path.open("wb") as log:
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + 120
                while b"inference ready" not in log_path.read_bytes():
                    assert process.poll() is None, log_path.read_text(errors="replace")
                    assert time.monotonic() < deadline, log_path.read_text(errors="replace")
                    time.sleep(.1)
                for case in cases:
                    try:
                        check_case(port, token, model, case)
                    except Exception as error:
                        raise AssertionError(f"{case['id']}: {error}; log:\n{log_path.read_text(errors='replace')[-2000:]}") from error
                    print("PASS", case["id"], flush=True)
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
    parser.add_argument("--binary", required=True, type=Path)
    parser.add_argument("--model", required=True, help="existing registered catalog name")
    parser.add_argument("--mode", choices=("both", "native", "ollama"), default="both")
    args = parser.parse_args()
    corpus = json.loads(FIXTURES.read_text(encoding="utf-8"))
    assert corpus["version"] == 1
    ids = [case["id"] for case in corpus["cases"]]
    assert len(ids) == len(set(ids))
    modes = ("native", "ollama") if args.mode == "both" else (args.mode,)
    for mode in modes:
        run_mode(str(args.binary.resolve()), args.model, mode,
                 [case for case in corpus["cases"] if case["mode"] == mode])
    print(f"PASS API v1 contract: {sum(case['mode'] in modes for case in corpus['cases'])} independently authored HTTP fixtures")


if __name__ == "__main__":
    main()
