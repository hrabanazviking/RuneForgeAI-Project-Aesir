#!/usr/bin/env python3
"""Opt-in real-model contention checks for the one-resident-model HTTP queue."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import http.client
import json
from pathlib import Path
import socket
import subprocess
import tempfile
import time


def get(port, path="/api/version", timeout=60):
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=timeout)
    connection.request("GET", path)
    response = connection.getresponse()
    result = response.status, dict(response.getheaders()), response.read()
    connection.close()
    return result


def generate(port, model, prompt, tokens=16, stream=False):
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=90)
    body = json.dumps({"model": model, "prompt": prompt, "stream": stream,
                       "options": {"num_predict": tokens, "temperature": 0}})
    connection.request("POST", "/api/generate", body,
                       {"Content-Type": "application/json"})
    response = connection.getresponse()
    assert response.status == 200, (response.status, response.read())
    return connection, response


def stream_generation(port, model):
    connection, response = generate(
        port, model,
        "Write a long and detailed account of an offline lighthouse, with many distinct sentences.",
        160, True)
    try:
        first = response.readline()
        assert first, "no first streamed record"
        return first + response.read()
    finally:
        connection.close()


def queued_get(port, path):
    sock = socket.create_connection(("127.0.0.1", port), timeout=60)
    sock.settimeout(60)
    sock.sendall(f"GET {path} HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nConnection: close\r\n\r\n".encode())
    return sock


def read_queued(sock):
    data = bytearray()
    with sock:
        while True:
            chunk = sock.recv(4096)
            if not chunk:
                break
            data.extend(chunk)
    return time.monotonic(), bytes(data)


def one_run(binary, model, queue_limit, queue_timeout_ms, check_expiry):
    with tempfile.TemporaryDirectory(prefix="aesir-s20-queue-") as directory:
        log_path = Path(directory) / "serve.log"
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        command = [binary, "serve", model, "--accel", "cuda", "--ollama",
                   "--port", str(port), "--context", "1024", "--max-tokens", "256",
                   "--timeout-ms", "60000", "--io-timeout-ms", "1000",
                   "--queue-limit", str(queue_limit),
                   "--queue-timeout-ms", str(queue_timeout_ms)]
        with log_path.open("wb") as log:
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + 120
                while b"inference ready" not in log_path.read_bytes():
                    assert process.poll() is None, log_path.read_text(errors="replace")
                    assert time.monotonic() < deadline, "service startup timeout"
                    time.sleep(.1)
                with ThreadPoolExecutor(max_workers=4) as pool:
                    drain = pool.submit(stream_generation, port, model)
                    phase_deadline = time.monotonic() + 60
                    while b"[request=1 phase=generation]" not in log_path.read_bytes():
                        assert not drain.done(), "generation ended before contention"
                        assert time.monotonic() < phase_deadline, "generation phase timeout"
                        time.sleep(.01)
                    first = queued_get(port, "/api/version")
                    second = queued_get(port, "/api/tags") if queue_limit > 1 else None
                    first_done = pool.submit(read_queued, first)
                    second_done = pool.submit(read_queued, second) if second else None
                    time.sleep(.35)
                    busy_status, headers, busy_body = get(port)
                    assert busy_status == 503 and headers.get("Retry-After") == "1", (busy_status, headers, busy_body)
                    if check_expiry:
                        expired_at, expired = first_done.result(timeout=10)
                        assert expired.startswith(b"HTTP/1.1 503 "), expired
                        assert not drain.done(), "request expired only after generation completed"
                        print(f"PASS queue expiry during active generation: {expired_at:.3f}", flush=True)
                        abandoned = queued_get(port, "/api/version")
                        time.sleep(.2)
                        abandoned.close()
                        time.sleep(.2)
                        replacement_start = time.monotonic()
                        replacement_at, replacement = read_queued(queued_get(port, "/api/version"))
                        assert replacement.startswith(b"HTTP/1.1 503 "), replacement
                        assert replacement_at - replacement_start >= .5, "cancelled waiter kept its slot"
                        assert not drain.done(), "cancellation checked only after generation completed"
                        print("PASS disconnected waiter releases admission slot", flush=True)
                    else:
                        first_at, first_data = first_done.result(timeout=70)
                        second_at, second_data = second_done.result(timeout=70)
                        assert first_data.startswith(b"HTTP/1.1 200 "), first_data
                        assert second_data.startswith(b"HTTP/1.1 200 "), second_data
                        assert first_at <= second_at, (first_at, second_at)
                        assert b'"version"' in first_data and b'"models"' in second_data, (first_data, second_data)
                        print("PASS queue FIFO and overflow: two admitted, one 503", flush=True)
                    _ = drain.result(timeout=70)
                assert get(port)[0] == 200, "service unhealthy after contention"
                if not check_expiry:
                    baseline_connection, baseline = generate(port, model, "Name one color.", 8)
                    baseline_text = json.loads(baseline.read())["response"]
                    baseline_connection.close()
                    secret_connection, secret = generate(port, model, "The private marker is FJORD-S20. Say hello.", 8)
                    assert secret.status == 200
                    secret.read()
                    secret_connection.close()
                    after_connection, after = generate(port, model, "Name one color.", 8)
                    after_text = json.loads(after.read())["response"]
                    after_connection.close()
                    assert baseline_text == after_text, (baseline_text, after_text)
                    print("PASS deterministic request isolation after distinct prompt", flush=True)
            except Exception as error:
                raise AssertionError(f"{error}; service log:\n{log_path.read_text(errors='replace')[-4000:]}") from error
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
    parser.add_argument("--case", choices=("all", "expiry"), default="all")
    args = parser.parse_args()
    if args.case == "all":
        one_run(str(args.binary.resolve()), args.model, 2, 30000, False)
    one_run(str(args.binary.resolve()), args.model, 1, 1000, True)


if __name__ == "__main__":
    main()
