#!/usr/bin/env python3
"""Opt-in real-CUDA proof that native NDJSON bytes arrive before generation ends."""
import argparse
import http.client
import json
from pathlib import Path
import socket
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True, type=Path)
    parser.add_argument("--model", required=True, help="existing catalog model")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="aesir-native-stream-") as directory:
        root = Path(directory)
        key = root / "key"
        created = subprocess.run([str(args.binary.resolve()), "keygen", str(key)],
                                 capture_output=True, timeout=30)
        assert created.returncode == 0, created.stderr
        token = key.read_text().strip()
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        log_path = root / "service.log"
        command = [str(args.binary.resolve()), "serve", args.model, "--accel", "cuda",
                   "--api-key-file", str(key), "--port", str(port), "--context", "512",
                   "--max-tokens", "64", "--timeout-ms", "60000"]
        with log_path.open("wb") as log:
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + 120
                while b"Native inference ready" not in log_path.read_bytes():
                    assert process.poll() is None, log_path.read_text(errors="replace")
                    assert time.monotonic() < deadline, "service startup timeout"
                    time.sleep(.1)
                prompt = "Write a detailed paragraph about an offline lighthouse, with several sentences."
                body = {"prompt": prompt, "max_tokens": 64, "temperature": 0, "stream": True}
                headers = {"Authorization": "Bearer " + token,
                           "Content-Type": "application/json"}
                connection = http.client.HTTPConnection("127.0.0.1", port, timeout=60)
                try:
                    connection.request("POST", "/v1/generate", json.dumps(body), headers)
                    response = connection.getresponse()
                    assert response.status == 200
                    assert response.getheader("Content-Type") == "application/x-ndjson"
                    assert response.getheader("Content-Length") is None
                    assert response.getheader("Connection") == "close"
                    records = []
                    first_at = None
                    last_at = None
                    while True:
                        line = response.readline()
                        assert line, "stream closed without a terminal record"
                        # Each delivered line must be independently valid UTF-8 and JSON.
                        record = json.loads(line.decode("utf-8"))
                        assert type(record.get("done")) is bool, record
                        records.append(record)
                        observed = time.monotonic()
                        if first_at is None:
                            first_at = observed
                        if record["done"]:
                            last_at = observed
                            break
                    assert response.readline() == b"", "bytes followed terminal record"
                finally:
                    connection.close()
                assert len(records) >= 3, "no observable intermediate generation"
                assert last_at - first_at > .1, "first record was not observed before generation ended"
                assert all(not item["done"] and type(item["text"]) is str for item in records[:-1])
                terminal = records[-1]
                assert terminal["text"] == "" and terminal["finish_reason"] in ("eos", "length")
                assert terminal["backend"] == "cuda" and terminal["cpu_offload"] == 0
                assert terminal["prompt_tokens"] > 0
                assert terminal["generated_tokens"] >= len(records) - 1
                assert terminal["context_used"] >= terminal["prompt_tokens"]
                # A deterministic non-streaming replay must preserve the same decoded text and counts.
                body["stream"] = False
                replay = http.client.HTTPConnection("127.0.0.1", port, timeout=60)
                try:
                    replay.request("POST", "/v1/generate", json.dumps(body), headers)
                    answer = replay.getresponse()
                    assert answer.status == 200
                    regular = json.loads(answer.read())
                finally:
                    replay.close()
                assert regular["text"] == "".join(item["text"] for item in records[:-1])
                for name in ("finish_reason", "prompt_tokens", "generated_tokens", "context_used"):
                    assert regular[name] == terminal[name], name
                short = {"prompt": "What is two plus two? Answer with one word.",
                         "max_tokens": 32, "temperature": 0, "stream": True}
                eos = http.client.HTTPConnection("127.0.0.1", port, timeout=60)
                try:
                    eos.request("POST", "/v1/generate", json.dumps(short), headers)
                    final_response = eos.getresponse()
                    assert final_response.status == 200
                    eos_records = [json.loads(line.decode("utf-8"))
                                   for line in final_response if line]
                finally:
                    eos.close()
                assert len(eos_records) >= 2 and eos_records[-1]["done"]
                assert eos_records[-1]["finish_reason"] == "eos", eos_records[-1]
                assert sum(item["done"] for item in eos_records) == 1
                print(f"PASS native incremental NDJSON: {len(records)-1} text records; "
                      f"first-to-final={last_at-first_at:.3f}s; "
                      f"finish={terminal['finish_reason']}; tokens={terminal['generated_tokens']}; EOS terminal verified")
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=20)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=5)


if __name__ == "__main__":
    main()
