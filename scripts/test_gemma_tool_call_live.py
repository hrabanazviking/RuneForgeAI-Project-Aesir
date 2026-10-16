#!/usr/bin/env python3
"""S24 installed-Gemma, independent-client tool-call probe; no downloads or execution."""
import argparse
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

from test_boolean_json_live import catalog_entries, send


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--store", type=Path, required=True)
    parser.add_argument("--ollama", action="store_true")
    args = parser.parse_args()
    catalog = (args.store / "catalog.v1").read_text()
    entries = list(catalog_entries(catalog))
    assert any(e.get("NAME", "") + ":" + e.get("TAG", "") == args.model for e in entries)
    with (tempfile.TemporaryDirectory(prefix="aesir-s24-", dir=args.store.parent) as work,
          tempfile.TemporaryDirectory(prefix="aesir-s24-key-") as key_work):
        root = Path(work)
        store = root / "models"
        blobs = store / "blobs" / "sha256"
        blobs.mkdir(parents=True)
        for entry in entries:
            digest = entry["DIGEST"].removeprefix("sha256:")
            os.link(args.store / "blobs" / "sha256" / digest, blobs / digest)
        (store / "catalog.v1").write_text(catalog)
        runtime_record = Path("/tmp") / f"aesir-runtime-{os.geteuid()}" / f"service-{store.stat().st_dev}-{store.stat().st_ino}.v1"
        key = Path(key_work) / "key"
        subprocess.run([str(args.binary), "keygen", str(key)], check=True, timeout=30)
        token = "" if args.ollama else key.read_text().strip()
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        command = [str(args.binary), "serve", args.model, "--accel", "cuda", "--port", str(port),
                   "--model-store", str(store.relative_to(Path.cwd())), "--context", "512", "--max-tokens", "64"]
        command += ["--ollama"] if args.ollama else ["--api-key-file", str(key)]
        log_path = root / "service.log"
        with log_path.open("wb") as log:
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + 120
                while b"inference ready" not in log_path.read_bytes():
                    assert process.poll() is None, log_path.read_text(errors="replace")
                    assert time.monotonic() < deadline, "startup timeout"
                    time.sleep(.1)
                tool = {"type": "function", "function": {"name": "get_time",
                        "description": "Return the current time", "parameters": {}}}
                base = {"model": args.model, "messages": [{"role": "user", "content":
                        "Call get_time to obtain the current time. Do not guess the time."}],
                        "max_tokens": 64, "temperature": 0, "tools": [tool]}
                for bad in ({**base, "stream": True},
                            {**base, "tools": [tool, tool]},
                            {**base, "tools": [{**tool, "function": {**tool["function"], "parameters": {"x": 1}}}]},
                            {**base, "tool_choice": "required"}):
                    code, _ = send(port, token, json.dumps(bad))
                    assert code == 400, (bad, code)
                code, _ = send(port, token, json.dumps({**base, "model": "unsupported-model"}))
                assert code == 404, code
                assert b"phase=generation" not in log_path.read_bytes(), "invalid tool request reached generation"
                code, result = send(port, token, json.dumps(base))
                assert code == 200, (code, result)
                choice = result["choices"][0]
                assert choice["finish_reason"] == "tool_calls", result
                assert choice["message"]["content"] is None, result
                assert len(choice["message"]["tool_calls"]) == 1, result
                call = choice["message"]["tool_calls"][0]
                assert call["id"].startswith("call-aesir-") and len(call["id"]) < 256, result
                assert call["type"] == "function" and call["function"]["name"] == "get_time", result
                assert json.loads(call["function"]["arguments"]) == {}, result
                assert result["usage"]["total_tokens"] == result["usage"]["prompt_tokens"] + result["usage"]["completion_tokens"]
                code, repeated = send(port, token, json.dumps(base))
                assert code == 200 and repeated["choices"][0]["finish_reason"] == "tool_calls", (code, repeated)
                assert repeated["choices"][0]["message"]["tool_calls"][0]["id"] != call["id"], repeated
                code, available_plain = send(port, token, json.dumps({**base, "messages": [{"role": "user", "content": "Say hello. Do not call any tool."}], "max_tokens": 16}))
                assert code == 200 and available_plain["choices"][0]["message"]["content"], (code, available_plain)
                assert "tool_calls" not in available_plain["choices"][0]["message"], available_plain
                code, plain = send(port, token, json.dumps({"model": args.model, "messages": [{"role": "user", "content": "Reply hello."}], "max_tokens": 16}))
                assert code == 200 and plain["choices"][0]["message"]["content"], (code, plain)
                assert "tool_calls" not in plain["choices"][0]["message"], plain
                print(f"PASS S24 {'ollama' if args.ollama else 'native'}: Gemma tool ID/arguments, refusal, plain text", flush=True)
            except Exception as error:
                raise AssertionError(f"S24 live probe: {error}; service log:\n{log_path.read_text(errors='replace')[-4000:]}") from error
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
