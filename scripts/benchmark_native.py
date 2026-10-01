"""Measure an explicit native binary through authenticated, supervised HTTP.

Each process starts empty; every service request resets conversation state.
Artifacts contain public prompts, actual replies, failures and binary identity.
No inferred source revision or substituted provider is accepted as evidence.
"""
import argparse
import hashlib
import http.client
import json
from pathlib import Path
import secrets
import socket
import statistics
import subprocess
import tempfile
import time


PROMPTS = {
    "arithmetic": "What is two plus two? Answer with one word.",
    "graph": "Explain how a knowledge graph connects documents, entities and their evidence. Write three sentences.",
    "long_prompt": (
        "A knowledge graph links documents, entities and the passages that support each connection. "
        "Sources remain available for citation. New material is appended through a queue, checked for duplicate "
        "content, and embedded in the same vector space. Failed imports can be inspected and retried safely. " * 4
    ) + "Summarize the reliability principles in three sentences.",
    "code": "Write a Python function that returns the square of an integer. Include a type hint.",
    "unicode": "Briefly explain what the Norse word Bifröst means. Use the spelling Bifröst.",
}


def request(port, key, payload=None):
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=180)
    started = time.perf_counter()
    try:
        connection.request("POST" if payload else "GET",
                           "/v1/generate" if payload else "/health",
                           json.dumps(payload).encode() if payload else None,
                           {"Authorization": "Bearer " + key,
                            "Content-Type": "application/json"})
        response = connection.getresponse()
        raw = response.read(1048577)
        if len(raw) > 1048576:
            raise ValueError("Response exceeded measurement bound")
        return time.perf_counter() - started, response.status, json.loads(raw)
    finally:
        connection.close()


def measure(args):
    binary = args.binary.resolve(strict=True)
    with binary.open("rb") as stream:
        identity = hashlib.file_digest(stream, "sha256").hexdigest()
    report = {"binary_sha256": identity, "model": args.model,
              "context": args.context, "samples_per_case": args.samples,
              "system": "You are concise.", "max_tokens": 32,
              "prefix_cache_requested": not args.no_prefix_cache,
              "sampling": "temperature=0; repetition_penalty=1; seed=42",
              "samples": [], "errors": [],
              "limits": "Native HTTP wall time. Fresh process readiness includes warm OS/driver caches. Stateless fresh prefill per request. No independent whole-model logits or other-model/device claim."}
    with tempfile.TemporaryDirectory(prefix="aesir-native-benchmark-") as directory:
        root = Path(directory)
        key = secrets.token_hex(32)
        keyfile = root / "key"
        keyfile.write_text(key)
        keyfile.chmod(0o600)
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        with (root / "service.log").open("wb") as log:
            started = time.perf_counter()
            command = [
                str(binary), "serve", args.model, "--accel", "cuda",
                "--api-key-file", str(keyfile), "--port", str(port),
                "--context", str(args.context), "--max-tokens", "32",
                "--temperature", "0", "--timeout-ms", "120000",
            ]
            if args.no_prefix_cache:
                command.append("--no-prefix-cache")
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + 120
                while True:
                    if process.poll() is not None:
                        raise RuntimeError("Native process exited before readiness")
                    try:
                        _, status, health = request(port, key)
                        if status == 200 and health.get("status") == "ready":
                            break
                    except (OSError, http.client.HTTPException):
                        pass
                    if time.monotonic() >= deadline:
                        raise TimeoutError("Native readiness deadline exceeded")
                    time.sleep(.1)
                if health.get("model") != args.model or health.get("context") != args.context:
                    raise ValueError("Loaded model/context differs from requested benchmark")
                report["readiness_seconds"] = time.perf_counter() - started
                report["health"] = health
                report["prefix_cache"] = health.get("capabilities", {}).get("exact_prefix_reuse")
                if args.no_prefix_cache and report["prefix_cache"] is True:
                    raise ValueError("Native service ignored explicit cache-disable intent")
                report["gpu"] = subprocess.check_output([
                    "nvidia-smi", "--query-gpu=name,driver_version,memory.total,memory.used",
                    "--format=csv,noheader"], text=True).strip()
                for case, prompt in PROMPTS.items():
                    for index in range(args.samples + 1):
                        sample = {"case": case, "prompt": prompt,
                                  "phase": "warmup" if index == 0 else "warm"}
                        sample_started = time.perf_counter()
                        try:
                            elapsed, status, reply = request(port, key, {
                                "prompt": prompt, "system": report["system"],
                                "max_tokens": 32, "temperature": 0})
                            sample.update(seconds=elapsed, status=status, reply=reply)
                            if (status != 200 or reply.get("backend") != "cuda"
                                    or reply.get("model") != args.model
                                    or reply.get("finish_reason") not in ("eos", "length")
                                    or not reply.get("text", "").strip()):
                                raise ValueError("Native response failed identity/completion gate")
                            if case == "arithmetic" and not any(
                                    word in reply["text"].lower() for word in ("four", "4")):
                                raise ValueError("Arithmetic correctness failed")
                        except (OSError, ValueError, http.client.HTTPException) as error:
                            sample.update(seconds=time.perf_counter() - sample_started,
                                          failure_category=type(error).__name__)
                        report["samples"].append(sample)
                        print(json.dumps({"case": case, "phase": sample["phase"],
                                          "seconds": sample["seconds"],
                                          "failed": "failure_category" in sample}), flush=True)
                # The exercised runtime is Linux; retain the engine's observed
                # resident/high-water memory before its owned process is reaped.
                memory = {}
                for line in Path(f"/proc/{process.pid}/status").read_text().splitlines():
                    name, _, value = line.partition(":")
                    if name in ("VmRSS", "VmHWM"):
                        memory[name] = value.strip()
                report["process_memory"] = memory
            except (OSError, ValueError, RuntimeError, TimeoutError) as error:
                report["errors"].append(type(error).__name__)
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=20)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=10)
                        report["errors"].append("ShutdownTimeout")
                if process.returncode != 0:
                    report["errors"].append("ProcessExit:" + str(process.returncode))
        # Engine logs omit prompts and credentials. Redact defensively anyway.
        report["service_log"] = (root / "service.log").read_text(errors="replace").replace(key, "[REDACTED]").replace(str(root), "[temporary]")
    report["medians_seconds"] = {}
    for case in PROMPTS:
        good = [sample["seconds"] for sample in report["samples"]
                if sample["case"] == case and sample["phase"] == "warm"
                and "failure_category" not in sample]
        report["medians_seconds"][case] = statistics.median(good) if good else None
    report["failed_samples"] = sum("failure_category" in sample for sample in report["samples"])
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True, type=Path)
    parser.add_argument("--model", required=True)
    parser.add_argument("--context", type=int, default=4096)
    parser.add_argument("--samples", type=int, default=3)
    parser.add_argument("--no-prefix-cache", action="store_true")
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if not 1 <= args.samples <= 10 or not 512 <= args.context <= 8192:
        parser.error("Use 1..10 samples and context 512..8192")
    # Exclusive reservation fails before GPU work and preserves failure artifacts.
    with args.output.open("x", encoding="utf-8") as output:
        report = measure(args)
        json.dump(report, output, indent=2, ensure_ascii=False)
        output.write("\n")
    print(json.dumps({"medians_seconds": report["medians_seconds"],
                      "failed_samples": report["failed_samples"], "errors": report["errors"]}))
    return int(bool(report["failed_samples"] or report["errors"]))


if __name__ == "__main__":
    raise SystemExit(main())
