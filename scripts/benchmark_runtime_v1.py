#!/usr/bin/env python3
"""Supervised, offline native-CUDA benchmark with raw phase/stream evidence.

The first and repeated launches are process loads, not cold/warm host claims.
No prompt, credential, or model bytes are sent outside the loopback service.
"""
import argparse
import hashlib
import http.client
import json
import math
import os
from pathlib import Path
import platform
import re
import secrets
import socket
import subprocess
import tempfile
import threading
import time

from benchmark_native import PROMPTS


CASES = {name: PROMPTS[name] for name in ("arithmetic", "long_prompt")}


def percentile(values, fraction):
    if not values or not all(type(x) in (int, float) and math.isfinite(x) and x >= 0 for x in values):
        raise ValueError("missing or invalid samples")
    ordered = sorted(values)
    offset = (len(ordered) - 1) * fraction
    lower = math.floor(offset)
    upper = math.ceil(offset)
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (offset - lower)


def catalog_digest(store, model):
    catalog = (store / "catalog.v1").read_text(encoding="utf-8")
    matches = []
    for line in catalog.splitlines():
        if line.startswith("ENTRY:"):
            fields = dict(item.split(":", 1) for item in
                          bytes.fromhex(line[6:]).decode("utf-8").splitlines()
                          if ":" in item)
            if fields.get("NAME", "") + ":" + fields.get("TAG", "") == model:
                matches.append(fields.get("DIGEST", ""))
    if len(matches) != 1 or not re.fullmatch(r"sha256:[0-9a-f]{64}", matches[0]):
        raise ValueError("model is not one unique pinned catalog entry")
    return matches[0]


def validate_stream(records, model, digest, ceiling, context):
    if len(records) < 2 or not any(not item[1].get("done") for item in records[:-1]):
        raise ValueError("stream lacks incremental output")
    text = []
    for _, item in records[:-1]:
        if item.get("done") is not False or type(item.get("text")) is not str:
            raise ValueError("malformed intermediate stream record")
        text.append(item["text"])
    last = records[-1][1]
    if (last.get("done") is not True or last.get("text") != ""
            or last.get("model") != model or last.get("model_digest") != digest
            or last.get("backend") != "cuda" or last.get("cpu_offload") != 0
            or last.get("finish_reason") not in ("eos", "length")):
        raise ValueError("invalid terminal stream identity")
    for field in ("prompt_tokens", "generated_tokens", "context_used"):
        if type(last.get(field)) is not int or last[field] < 1:
            raise ValueError("invalid terminal token count")
    if (last["generated_tokens"] > ceiling or last["context_used"] > context
            or last["prompt_tokens"] + last["generated_tokens"] > last["context_used"]
            or not "".join(text).strip()):
        raise ValueError("incomplete or overlong stream")
    timing = last.get("timings_ms")
    if (type(timing) is not dict or type(timing.get("prefill")) is not int
            or type(timing.get("decode")) is not int
            or timing["prefill"] < 1 or timing["decode"] < 1):
        raise ValueError("missing observed phase timing")
    first_text = next((arrived for arrived, item in records[:-1] if item["text"]), None)
    if first_text is None:
        raise ValueError("no first token observed")
    if sum(len(part.encode("utf-8")) for part in text) > 1048576:
        raise ValueError("assembled stream exceeds 1 MiB")
    return {
        "text": "".join(text), "prompt_tokens": last["prompt_tokens"],
        "generated_tokens": last["generated_tokens"],
        "finish_reason": last["finish_reason"],
        "prefill_ms": timing["prefill"], "decode_ms": timing["decode"],
        "first_arrival": first_text,
    }


def streamed_request(port, key, model, digest, prompt, max_tokens, context):
    conn = http.client.HTTPConnection("127.0.0.1", port, timeout=180)
    payload = json.dumps({"prompt": prompt, "max_tokens": max_tokens,
                          "temperature": 0, "stream": True}).encode()
    started = time.perf_counter()
    try:
        conn.request("POST", "/v1/generate", payload,
                     {"Authorization": "Bearer " + key,
                      "Content-Type": "application/json"})
        response = conn.getresponse()
        if response.status != 200 or response.getheader("Content-Type", "").split(";")[0] != "application/x-ndjson":
            raise ValueError("stream response status or type rejected")
        records = []
        while True:
            line = response.fp.readline(1048577)
            arrived = time.perf_counter()
            if not line:
                break
            if len(line) > 1048576 or len(records) >= max_tokens + 4:
                raise ValueError("stream exceeds record bounds")
            records.append((arrived, json.loads(line)))
        completed = time.perf_counter()
        result = validate_stream(records, model, digest, max_tokens, context)
        first_arrival = result.pop("first_arrival")
        if first_arrival < started or first_arrival > completed:
            raise ValueError("invalid first-token arrival time")
        result.update(wall_seconds=completed - started,
                      ttft_seconds=first_arrival - started,
                      record_count=len(records))
        return result
    finally:
        conn.close()


def get_health(port, key):
    conn = http.client.HTTPConnection("127.0.0.1", port, timeout=5)
    try:
        conn.request("GET", "/health", headers={"Authorization": "Bearer " + key})
        response = conn.getresponse()
        data = response.read(65537)
        if response.status != 200 or len(data) > 65536:
            raise ValueError("health response is not ready")
        return json.loads(data)
    finally:
        conn.close()


def process_memory_kib(pid):
    fields = {}
    for line in Path(f"/proc/{pid}/status").read_text().splitlines():
        name, _, value = line.partition(":")
        if name in ("VmRSS", "VmHWM"):
            fields[name] = int(value.strip().split()[0])
    return fields


def process_vram_mib(pid):
    try:
        result = subprocess.run(["nvidia-smi", "--query-compute-apps=pid,used_gpu_memory",
                                 "--format=csv,noheader,nounits"], capture_output=True,
                                text=True, timeout=5, check=True)
        for row in result.stdout.splitlines():
            fields = [part.strip() for part in row.split(",")]
            if len(fields) == 2 and fields[0] == str(pid) and fields[1].isdigit():
                return int(fields[1])
    except (OSError, subprocess.SubprocessError):
        pass
    return None


def gpu_snapshot():
    try:
        result = subprocess.run(["nvidia-smi", "--query-gpu=name,driver_version,memory.total,memory.used",
                                 "--format=csv,noheader,nounits"], capture_output=True,
                                text=True, timeout=5, check=True)
        first = result.stdout.splitlines()[0]
        name, driver, total, used = [part.strip() for part in first.split(",")]
        return {"name": name, "driver_version": driver,
                "total_mib": int(total), "used_mib": int(used)}
    except (OSError, subprocess.SubprocessError, IndexError, ValueError):
        return None


def sample_vram(pid, stop, process_observed, device_observed):
    while not stop.is_set():
        value = process_vram_mib(pid)
        if value is not None:
            process_observed.append(value)
        snapshot = gpu_snapshot()
        if snapshot is not None:
            device_observed.append(snapshot["used_mib"])
        stop.wait(.25)


def launch(binary, store_cli, model, context, max_tokens, keyfile, log, port):
    command = [str(binary), "serve", model, "--accel", "cuda", "--port", str(port),
               "--model-store", str(store_cli), "--api-key-file", str(keyfile),
               "--context", str(context), "--max-tokens", str(max_tokens),
               "--temperature", "0", "--timeout-ms", "120000"]
    return subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)


def run(args, report):
    binary = args.binary.resolve(strict=True)
    store = args.store.resolve(strict=True)
    try:
        store_cli = store.relative_to(Path.cwd().resolve())
    except ValueError as error:
        raise ValueError("model store must be below the current directory") from error
    digest = catalog_digest(store, args.model)
    with binary.open("rb") as stream:
        binary_digest = hashlib.file_digest(stream, "sha256").hexdigest()
    report.update({"binary_sha256": binary_digest,
              "model": args.model, "model_digest": digest, "context": args.context,
              "max_tokens": args.max_tokens, "samples_per_case": args.samples,
              "host": {"platform": platform.platform(), "machine": platform.machine()},
              "gpu": gpu_snapshot(),
              "load_processes": [], "samples": [], "summary": {},
              "limits": ["First/repeat process launch, not a verified cold/warm host state.",
                         "TTFT is first visible UTF-8 text record, not an internal token timestamp; it includes loopback transport and service prefill. Phase timers are service wall time, not GPU kernel time.",
                         "VRAM is periodically sampled; per-process peak is null when NVIDIA process telemetry is unavailable. Device-wide peak may include unrelated activity and is not attributable to Aesir alone.",
                         "NVIDIA telemetry polling and host scheduling can perturb latency; repeat with the same measurement policy before comparing builds."]})
    with tempfile.TemporaryDirectory(prefix="aesir-s25-") as temporary:
        root = Path(temporary)
        keyfile = root / "key"
        key = secrets.token_hex(32)
        key_fd = os.open(keyfile, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(key_fd, "w", encoding="ascii") as key_output:
            key_output.write(key)
        for ordinal in range(2):
            with socket.socket() as probe:
                probe.bind(("127.0.0.1", 0))
                port = probe.getsockname()[1]
            with (root / f"service-{ordinal}.log").open("wb") as log:
                prelaunch_gpu = gpu_snapshot()
                started = time.perf_counter()
                process = launch(binary, store_cli, args.model, args.context, args.max_tokens,
                                 keyfile, log, port)
                stop = threading.Event()
                process_vram = []
                device_vram = []
                sampler = threading.Thread(target=sample_vram, args=(process.pid, stop, process_vram, device_vram), daemon=True)
                sampler.start()
                try:
                    deadline = time.monotonic() + 120
                    while True:
                        if process.poll() is not None or time.monotonic() >= deadline:
                            raise RuntimeError("service failed to become ready")
                        try:
                            health = get_health(port, key)
                            if health.get("status") == "ready":
                                break
                        except (OSError, ValueError, http.client.HTTPException):
                            pass
                        time.sleep(.1)
                    if (health.get("model") != args.model or health.get("model_digest") != digest
                            or health.get("context") != args.context or health.get("backend") != "cuda"
                            or health.get("cpu_offload") != 0):
                        raise ValueError("resident model identity mismatch")
                    load = {"kind": "first_process" if ordinal == 0 else "repeat_process",
                            "ready_seconds": time.perf_counter() - started,
                            "prelaunch_device_vram_mib": prelaunch_gpu["used_mib"] if prelaunch_gpu else None}
                    if ordinal == 1:
                        report["health"] = health
                        for name, prompt in CASES.items():
                            for index in range(args.samples + 1):
                                measured = streamed_request(port, key, args.model, digest,
                                                            prompt, args.max_tokens, args.context)
                                measured.update(case=name, phase="warmup" if index == 0 else "sample",
                                                prompt_sha256=hashlib.sha256(prompt.encode()).hexdigest())
                                report["samples"].append(measured)
                                print(json.dumps({"case": name, "phase": measured["phase"],
                                                  "wall_seconds": measured["wall_seconds"]}), flush=True)
                    load["process_memory_kib"] = process_memory_kib(process.pid)
                    report["load_processes"].append(load)
                finally:
                    stop.set()
                    sampler.join(timeout=11)
                    sampler_stuck = sampler.is_alive()
                    if process.poll() is None:
                        process.terminate()
                        try:
                            process.wait(timeout=20)
                        except subprocess.TimeoutExpired:
                            process.kill()
                            process.wait(timeout=5)
                    if len(report["load_processes"]) > ordinal:
                        report["load_processes"][ordinal]["sampled_process_vram_peak_mib"] = max(process_vram) if process_vram else None
                        report["load_processes"][ordinal]["sampled_device_vram_peak_mib"] = max(device_vram) if device_vram else None
                    if sampler_stuck:
                        raise RuntimeError("telemetry sampler did not stop")
    model_blob = store / "blobs" / "sha256" / digest[7:]
    with model_blob.open("rb") as stream:
        if hashlib.file_digest(stream, "sha256").hexdigest() != digest[7:]:
            raise ValueError("catalog model blob failed final digest verification")
    for name in CASES:
        values = [item for item in report["samples"] if item["case"] == name and item["phase"] == "sample"]
        if len(values) != args.samples:
            raise ValueError("incomplete sample group")
        report["summary"][name] = {
            "latency_p50_seconds": percentile([item["wall_seconds"] for item in values], .5),
            "latency_p95_seconds": percentile([item["wall_seconds"] for item in values], .95),
            "ttft_p50_seconds": percentile([item["ttft_seconds"] for item in values], .5),
            "prefill_tokens_per_second_p50": percentile([item["prompt_tokens"] * 1000 / item["prefill_ms"] for item in values], .5),
            "decode_tokens_per_second_p50": percentile([item["generated_tokens"] * 1000 / item["decode_ms"] for item in values], .5),
        }
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--store", type=Path, required=True)
    parser.add_argument("--context", type=int, default=512)
    parser.add_argument("--max-tokens", type=int, default=24)
    parser.add_argument("--samples", type=int, default=5)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not 512 <= args.context <= 8192 or not 1 <= args.max_tokens <= 256 or not 2 <= args.samples <= 20:
        parser.error("context 512..8192, max-tokens 1..256, samples 2..20 required")
    with args.output.open("x", encoding="utf-8") as output:
        report = {"schema_version": 1, "status": "incomplete", "model": args.model,
                  "errors": [], "load_processes": [], "samples": [], "summary": {}}
        try:
            run(args, report)
        except Exception as error:
            report["status"] = "failed"
            report["errors"].append(type(error).__name__)
        else:
            report["status"] = "passed"
        json.dump(report, output, indent=2, ensure_ascii=False)
        output.write("\n")
    print(json.dumps({"status": report["status"], "errors": report["errors"]}), flush=True)
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
