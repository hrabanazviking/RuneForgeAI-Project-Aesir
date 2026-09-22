#!/usr/bin/env python3
"""Opt-in real-CUDA independent-client checks for S19 compatibility streams."""
import argparse
import http.client
import json
from pathlib import Path
import socket
import struct
import subprocess
import tempfile
import time


PROMPT = "Write a detailed paragraph about an offline lighthouse, with several sentences."


def request(port, token, path, body=None, *, receive_buffer=None):
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=20)
    connection.connect()
    if receive_buffer is not None:
        connection.sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, receive_buffer)
    transport = connection.sock
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    payload = None if body is None else json.dumps(body).encode()
    connection.request("GET" if body is None else "POST", path, payload, headers)
    response = connection.getresponse()
    return connection, response, transport


def next_sse(response):
    lines = []
    while True:
        line = response.readline()
        assert line, "SSE stream closed without terminal event"
        decoded = line.decode("utf-8")
        if decoded == "\n":
            assert len(lines) == 1 and lines[0].startswith("data: "), lines
            return lines[0][6:]
        lines.append(decoded.rstrip("\n"))


def check_stream(port, token, model, mode, chat):
    if mode == "openai":
        path = "/v1/chat/completions" if chat else "/v1/completions"
        body = {"model": model, "stream": True, "max_tokens": 64, "temperature": 0}
        body.update({"messages": [{"role": "user", "content": PROMPT}]} if chat else {"prompt": PROMPT})
    else:
        path = "/api/chat" if chat else "/api/generate"
        body = {"model": model, "stream": True, "options": {"num_predict": 64, "temperature": 0}}
        body.update({"messages": [{"role": "user", "content": PROMPT}]} if chat else {"prompt": PROMPT})
    connection, response, transport = request(port, token, path, body)
    try:
        assert response.status == 200
        assert response.getheader("Content-Length") is None
        assert response.getheader("Connection") == "close"
        assert response.getheader("Content-Type") == ("text/event-stream" if mode == "openai" else "application/x-ndjson")
        records = []
        first_text_at = None
        final_at = None
        while True:
            if mode == "openai":
                event = next_sse(response)
                if event == "[DONE]":
                    assert records and records[-1]["choices"][0]["finish_reason"], "[DONE] without finish"
                    break
                record = json.loads(event)
                choice = record["choices"][0]
                fragment = choice["delta"].get("content", "") if chat else choice["text"]
                done = choice["finish_reason"] is not None
            else:
                line = response.readline()
                assert line, "NDJSON stream closed without terminal record"
                record = json.loads(line.decode("utf-8"))
                fragment = record["message"]["content"] if chat else record["response"]
                done = record["done"]
            observed = time.monotonic()
            records.append(record)
            if fragment and first_text_at is None:
                first_text_at = observed
            if done:
                final_at = observed
                if mode == "ollama":
                    break
        assert response.readline() == b"", "bytes followed terminal frame"
        assert first_text_at is not None and final_at - first_text_at > .1, (mode, chat, records[-1])
        assert len(records) >= 3, (mode, chat)
        if mode == "openai":
            if chat:
                assert records[0]["choices"][0]["delta"] == {"role": "assistant"}
            assert all(item["id"] == records[0]["id"] and item["model"] == model for item in records)
            assert all(item["choices"][0]["finish_reason"] is None for item in records[:-1])
            assert records[-1]["choices"][0]["finish_reason"] in ("stop", "length")
            if chat:
                assert records[-1]["choices"][0]["delta"] == {}
            else:
                assert records[-1]["choices"][0]["text"] == ""
        else:
            assert all(item["done"] is False for item in records[:-1])
            assert records[-1]["done"] is True and records[-1]["done_reason"] in ("stop", "length")
            assert records[-1]["eval_count"] >= len(records) - 1
            assert fragment == "", "terminal frame repeated generated text"
        print(f"PASS {mode} {'chat' if chat else 'generate'}: {len(records)-1} intermediate records, "
              f"first-to-final={final_at-first_text_at:.3f}s", flush=True)
    finally:
        response.close()
        transport.close()
        connection.close()


def check_disconnect(port, token, model, mode):
    if mode == "openai":
        path = "/v1/chat/completions"
        body = {"model": model, "stream": True, "max_tokens": 512,
                "messages": [{"role": "user", "content": PROMPT}]}
    else:
        path = "/api/generate"
        body = {"model": model, "prompt": PROMPT, "stream": True,
                "options": {"num_predict": 512}}
    connection, response, transport = request(port, token, path, body)
    assert response.status == 200
    if mode == "openai":
        assert json.loads(next_sse(response))["choices"][0]["delta"]["role"] == "assistant"
    else:
        assert json.loads(response.readline())["done"] is False
    # RST rather than a graceful FIN makes a server write observe the lost peer.
    transport.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
    transport.close()
    response.close()
    connection.close()
    started = time.monotonic()
    probe_path = "/v1/models" if mode == "openai" else "/api/version"
    probe, result, probe_transport = request(port, token, probe_path)
    try:
        assert result.status == 200 and json.loads(result.read())
    finally:
        result.close()
        probe_transport.close()
        probe.close()
    assert time.monotonic() - started < 8, "disconnect did not stop generation promptly"
    print(f"PASS {mode} disconnect: service recovered in {time.monotonic()-started:.3f}s", flush=True)


def check_slow_receiver(port, token, model, mode, log_path):
    if mode == "openai":
        path = "/v1/chat/completions"
        body = {"model": model, "stream": True, "max_tokens": 512,
                "messages": [{"role": "user", "content": PROMPT}]}
    else:
        path = "/api/generate"
        body = {"model": model, "prompt": PROMPT, "stream": True,
                "options": {"num_predict": 512}}
    offset = log_path.stat().st_size
    slow, response, slow_transport = request(port, token, path, body, receive_buffer=1024)
    assert response.status == 200
    deadline = time.monotonic() + 18
    try:
        while b"status=" not in log_path.read_bytes()[offset:]:
            assert time.monotonic() < deadline, "slow receiver was not bounded within 18s"
            time.sleep(.05)
        tail = log_path.read_bytes()[offset:]
        assert b"status=200" in tail or b"status=500" in tail, tail[-1000:]
        probe_path = "/v1/models" if mode == "openai" else "/api/version"
        probe, result, probe_transport = request(port, token, probe_path)
        try:
            assert result.status == 200 and json.loads(result.read())
        finally:
            result.close()
            probe_transport.close()
            probe.close()
    finally:
        response.close()
        slow_transport.close()
        slow.close()
    observed = "completed within bounded reply" if b"status=200" in tail else "bounded write deadline"
    print(f"PASS {mode} slow receiver: {observed}; healthy next request", flush=True)


def run_mode(binary, model, mode):
    with tempfile.TemporaryDirectory(prefix="aesir-s19-stream-") as directory:
        root = Path(directory)
        key = root / "key"
        token = ""
        if mode == "openai":
            created = subprocess.run([binary, "keygen", str(key)], capture_output=True, timeout=30)
            assert created.returncode == 0, created.stderr
            token = key.read_text().strip()
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        log_path = root / "service.log"
        command = [binary, "serve", model, "--accel", "cuda", "--port", str(port),
                   "--context", "1024", "--max-tokens", "512", "--timeout-ms", "60000",
                   "--io-timeout-ms", "300"]
        command += ["--api-key-file", str(key)] if mode == "openai" else ["--ollama"]
        with log_path.open("wb") as log:
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + 120
                while b"inference ready" not in log_path.read_bytes():
                    assert process.poll() is None, log_path.read_text(errors="replace")
                    assert time.monotonic() < deadline, "service startup timeout"
                    time.sleep(.1)
                check_stream(port, token, model, mode, False)
                check_stream(port, token, model, mode, True)
                check_disconnect(port, token, model, mode)
                check_slow_receiver(port, token, model, mode, log_path)
            except Exception as error:
                raise AssertionError(f"{mode}: {error}; log:\n{log_path.read_text(errors='replace')[-3000:]}") from error
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=20)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=5)


def check_error_frame(binary, model, mode):
    """A deadline after headers must be an error, never a success terminal."""
    with tempfile.TemporaryDirectory(prefix="aesir-s19-deadline-") as directory:
        root = Path(directory)
        key = root / "key"
        token = ""
        if mode == "openai":
            created = subprocess.run([binary, "keygen", str(key)], capture_output=True, timeout=30)
            assert created.returncode == 0, created.stderr
            token = key.read_text().strip()
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        log_path = root / "service.log"
        command = [binary, "serve", model, "--accel", "cuda", "--port", str(port),
                   "--context", "1024", "--max-tokens", "64", "--timeout-ms", "4500",
                   "--io-timeout-ms", "300"]
        command += ["--api-key-file", str(key)] if mode == "openai" else ["--ollama"]
        with log_path.open("wb") as log:
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + 120
                while b"inference ready" not in log_path.read_bytes():
                    assert process.poll() is None, log_path.read_text(errors="replace")
                    assert time.monotonic() < deadline, "deadline fixture startup timeout"
                    time.sleep(.1)
                if mode == "openai":
                    body = {"model": model, "stream": True, "max_tokens": 64,
                            "messages": [{"role": "user", "content": PROMPT}]}
                    path = "/v1/chat/completions"
                else:
                    body = {"model": model, "stream": True, "prompt": PROMPT,
                            "options": {"num_predict": 64}}
                    path = "/api/generate"
                connection, response, transport = request(port, token, path, body)
                try:
                    assert response.status == 200
                    events = []
                    while True:
                        event = next_sse(response) if mode == "openai" else response.readline().decode("utf-8").strip()
                        assert event, "stream ended before error frame"
                        events.append(event)
                        if event == "[DONE]" or "error" in json.loads(event) or json.loads(event).get("done") is True:
                            break
                    assert events[-1] != "[DONE]", "deadline was misreported as successful completion"
                    error = json.loads(events[-1])["error"]
                    if mode == "openai":
                        assert error == {"message": "Gateway Timeout", "type": "timeout_error"}
                    else:
                        assert error == "Gateway Timeout"
                    assert response.readline() == b"", "bytes followed error event"
                finally:
                    response.close()
                    transport.close()
                    connection.close()
                probe, result, probe_transport = request(port, token, "/v1/models" if mode == "openai" else "/api/version")
                try:
                    assert result.status == 200 and json.loads(result.read())
                finally:
                    result.close()
                    probe_transport.close()
                    probe.close()
                print(f"PASS {mode} post-header deadline: {len(events)-1} prior events, sanitized timeout error, healthy recovery", flush=True)
            except Exception as error:
                raise AssertionError(f"{mode} deadline frame: {error}; log:\n{log_path.read_text(errors='replace')[-3000:]}") from error
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
    parser.add_argument("--model", required=True)
    parser.add_argument("--mode", choices=("both", "openai", "ollama"), default="both")
    args = parser.parse_args()
    modes = ("openai", "ollama") if args.mode == "both" else (args.mode,)
    for mode in modes:
        run_mode(str(args.binary.resolve()), args.model, mode)
        check_error_frame(str(args.binary.resolve()), args.model, mode)
    print("PASS S19 compatibility streams: incremental frames, disconnect, slow receiver", flush=True)


if __name__ == "__main__":
    main()
