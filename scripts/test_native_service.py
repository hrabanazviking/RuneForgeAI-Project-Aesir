"""Opt-in HTTP/security/recovery checks against both real native CUDA models."""
import argparse
import http.client
import json
import os
from pathlib import Path
import secrets
import signal
import socket
import struct
import subprocess
import tempfile
import time


def reject_keys(binary):
    with tempfile.TemporaryDirectory(prefix="aesir-key-check-") as directory:
        root = Path(directory)
        good = root / "good"
        good.write_text(secrets.token_hex(32))
        good.chmod(0o600)
        insecure = root / "public"
        insecure.write_text(secrets.token_hex(32))
        insecure.chmod(0o644)
        link = root / "link"
        link.symlink_to(good)
        fifo = root / "fifo"
        os.mkfifo(fifo, 0o600)
        for name, value in [("short", "tiny"), ("long", "x" * 258), ("invalid", "!" * 32)]:
            path = root / name
            path.write_text(value)
            path.chmod(0o600)
        for path in [insecure, link, fifo, root / "short", root / "long", root / "invalid"]:
            result = subprocess.run([binary, "serve", "missing.gguf", "--accel", "cuda",
                "--api-key-file", str(path)], capture_output=True, timeout=15)
            assert result.returncode != 0, "unsafe key file accepted"
            assert b"[CUDA]" not in result.stdout, "unsafe key reached CUDA initialization"
    print("PASS owner-only key admission: public, symlink, FIFO, short, oversized, invalid")


def check(binary, model, profile, output_dir):
    with tempfile.TemporaryDirectory(prefix="aesir-service-check-") as directory:
        root = Path(directory)
        keyfile = root / "api-key"
        created = subprocess.run([binary, "keygen", str(keyfile)], capture_output=True, timeout=30)
        assert created.returncode == 0, "native service key creation failed"
        token = keyfile.read_text().strip()
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        logfile = root / "service.log"
        replies = []

        def request(method, route, body=None, *, authorized=True, extra=None):
            headers = {"Content-Type": "application/json"}
            if authorized:
                headers["Authorization"] = "Bearer " + token
            if extra:
                headers.update(extra)
            connection = http.client.HTTPConnection("127.0.0.1", port, timeout=30)
            try:
                payload = json.dumps(body, ensure_ascii=False).encode() if isinstance(body, dict) else body
                connection.request(method, route, payload, headers)
                response = connection.getresponse()
                raw = response.read()
                assert int(response.getheader("Content-Length")) == len(raw)
                assert response.getheader("Connection") == "close"
                assert response.getheader("Cache-Control") == "no-store"
                assert token.encode() not in raw, "credential leaked in response"
                return response.status, json.loads(raw)
            finally:
                connection.close()

        def raw_request(data):
            with socket.create_connection(("127.0.0.1", port), timeout=10) as client:
                client.sendall(data)
                result = bytearray()
                while True:
                    try:
                        chunk = client.recv(4096)
                    except ConnectionResetError:
                        break
                    if not chunk:
                        break
                    result.extend(chunk)
                return int(result.split(b" ", 2)[1])

        with logfile.open("wb") as log:
            process = subprocess.Popen([binary, "serve", model, "--accel", "cuda",
                "--api-key-file", str(keyfile), "--port", str(port), "--context", "512",
                "--max-tokens", "64", "--timeout-ms", "30000", "--io-timeout-ms", "300"],
                stdout=log, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + 120
                while b"Native inference ready" not in logfile.read_bytes():
                    assert process.poll() is None, logfile.read_text(errors="replace")
                    assert time.monotonic() < deadline, "service startup timeout"
                    time.sleep(.1)
                # Verify loopback binding independently of the advertised URL.
                entries = Path(f"/proc/{process.pid}/net/tcp").read_text().splitlines()[1:]
                listeners = [line.split()[1] for line in entries
                             if line.split()[3] == "0A" and int(line.split()[1].split(":")[1], 16) == port]
                assert listeners == [f"0100007F:{port:04X}"], listeners
                for task in Path(f"/proc/{process.pid}/task").iterdir():
                    mask = next(line.split()[1] for line in task.joinpath("status").read_text().splitlines()
                                if line.startswith("SigBlk:"))
                    assert int(mask, 16) & 16386 == 16386, "worker signal mask is unsafe"
                assert request("GET", "/health", authorized=False)[0] == 401
                status, health = request("GET", "/health")
                assert status == 200 and health["profile"] == profile and health["context"] == 512
                assert request("GET", "/health", extra={"Host": "attacker.invalid"})[0] == 403
                assert request("GET", "/health", extra={"Origin": "https://attacker.invalid"})[0] == 403
                assert request("GET", "/v1/models")[0] == 404  # no compatibility claim
                arithmetic = {"prompt": "What is two plus two? Answer with one word.", "max_tokens": 16}
                status, answer = request("POST", "/v1/generate", arithmetic)
                assert status == 200 and "four" in answer["text"].lower(), (status, answer)
                assert answer["backend"] == "cuda" and answer["cpu_offload"] == 0 and answer["finish_reason"] == "eos"
                replies.append(answer)
                sampled = {"prompt": "Write one short sentence about a silver ship.", "max_tokens": 24,
                           "temperature": 0.8, "top_k": 20, "seed": 123}
                first = request("POST", "/v1/generate", sampled)
                second = request("POST", "/v1/generate", sampled)
                assert first[0] == second[0] == 200 and first[1] == second[1], "stateless seeded replay failed"
                replies.append(first[1])
                for body in [b'{"prompt":"x","prompt":"y"}', b'{"prompt":"x","stream":true}',
                             b'{"prompt":"x","max_tokens":0}', b'{"prompt":"x","max_tokens":65}',
                             b'{"prompt":"x","timeout_ms":0}', b'{"prompt":"x","temperature":"0.8"}',
                             b'{"prompt":"\xff"}', b'{"prompt":"\\uD800"}', b'{}{}']:
                    assert request("POST", "/v1/generate", body)[0] == 400, "invalid generation request accepted"
                prefix = f"POST /v1/generate HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nAuthorization: Bearer {token}\r\nContent-Type: application/json\r\n".encode()
                assert raw_request(prefix + b"Content-Length: 2\r\nContent-Length: 2\r\n\r\n{}") == 400
                assert raw_request(prefix + b"Transfer-Encoding: chunked\r\n\r\n0\r\n\r\n") == 400
                assert raw_request(prefix + b"Content-Length: 131073\r\n\r\n") == 413
                assert raw_request(prefix + b"Content-Length: 100\r\n\r\n{") == 408
                assert raw_request(b"GET /health HTTP/1.1\r\n") == 408
                status, _ = request("POST", "/v1/generate", {**arithmetic, "timeout_ms": 1})
                assert status == 504, "prefill deadline was ignored"
                assert request("POST", "/v1/generate", arithmetic) == (200, answer), "deadline recovery leaked state"
                # A reset peer must not deliver SIGPIPE to the server.
                with socket.create_connection(("127.0.0.1", port), timeout=5) as abandoned:
                    abandoned.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
                    abandoned.sendall(b"GET /health HTTP/1.1\r\nHost: x\r\n\r\n")
                assert request("GET", "/health")[0] == 200
                # Stop an admitted, actively generating request, not just idle accept.
                offset = logfile.stat().st_size
                final_body = json.dumps({"prompt": "Write a long detailed sea adventure of two hundred words.", "max_tokens": 64}).encode()
                with socket.create_connection(("127.0.0.1", port), timeout=5) as active:
                    active.sendall(prefix + f"Content-Length: {len(final_body)}\r\n\r\n".encode() + final_body)
                    deadline = time.monotonic() + 30
                    while b"phase=generation" not in logfile.read_bytes()[offset:]:
                        assert process.poll() is None and time.monotonic() < deadline, "generation did not start"
                        time.sleep(.02)
                    process.send_signal(signal.SIGTERM if profile == "llama3" else signal.SIGINT)
                    assert process.wait(timeout=20) == 0, logfile.read_text(errors="replace")
                assert "Native inference service stopped" in logfile.read_text()
                assert token not in logfile.read_text(), "credential leaked in logs"
                assert sampled["prompt"] not in logfile.read_text(), "prompt leaked in logs"
                print(f"PASS {profile}: authenticated real CUDA HTTP, replay, framing/Unicode rejection, slow-client limits, deadline recovery, shutdown")
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=5)
                if output_dir:
                    Path(output_dir).mkdir(parents=True, exist_ok=True)
                    (Path(output_dir) / f"{profile}-service.log").write_bytes(logfile.read_bytes())
                    (Path(output_dir) / f"{profile}-service-replies.json").write_text(json.dumps(replies, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True)
    parser.add_argument("--llama", required=True)
    parser.add_argument("--gemma", required=True)
    parser.add_argument("--output-dir")
    args = parser.parse_args()
    reject_keys(args.binary)
    check(args.binary, args.llama, "llama3", args.output_dir)
    check(args.binary, args.gemma, "gemma4", args.output_dir)


if __name__ == "__main__":
    main()
