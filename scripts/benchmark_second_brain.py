"""Paired real HTTP timings; never treats a warm answer as cold inference."""
import argparse
import hashlib
import http.client
import json
from pathlib import Path
import platform
import statistics
import subprocess
import sys
import time
from urllib.parse import urlsplit

import launch


def request(origin, route, body=None, key=""):
    url = urlsplit(origin)
    if (url.scheme != "http" or not url.hostname or url.username or url.password
            or url.path or url.query or url.fragment or key and url.hostname != "127.0.0.1"):
        raise ValueError("Benchmark expects explicit local HTTP origins")
    connection = http.client.HTTPConnection(url.hostname, url.port, timeout=120)
    headers = {"Content-Type": "application/json"}
    if key:
        headers["Authorization"] = "Bearer " + key
    started = time.perf_counter()
    try:
        connection.request("POST" if body is not None else "GET", route,
                           json.dumps(body).encode() if body is not None else None, headers)
        response = connection.getresponse()
        raw = response.read(1048577)
        elapsed = time.perf_counter() - started
        if response.status != 200 or len(raw) > 1048576:
            raise ValueError("Benchmark request failed: HTTP " + str(response.status))
        return elapsed, json.loads(raw)
    finally:
        connection.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aesir", default="http://127.0.0.1:18434")
    parser.add_argument("--ollama", required=True)
    parser.add_argument("--key-file", required=True, type=Path)
    parser.add_argument("--model", required=True)
    parser.add_argument("--ollama-gguf", type=Path,
                        help="Local Ollama blob; hash it against the loaded native digest")
    parser.add_argument("--context", type=int, default=4096)
    parser.add_argument("--samples", type=int, default=3)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if not 1 <= args.samples <= 10 or not 512 <= args.context <= 8192:
        parser.error("Use 1..10 samples and context 512..8192")
    binary = launch.validate_build()
    with binary.open("rb") as stream:
        binary_digest = hashlib.file_digest(stream, "sha256").hexdigest()
    key = args.key_file.read_text().strip()
    _, health = request(args.aesir, "/health", key=key)
    if health["status"] != "ready" or health["model"] != args.model or health["context"] != args.context:
        raise ValueError("Loaded native model/context does not match the comparator")
    if args.ollama_gguf is not None:
        with args.ollama_gguf.open("rb") as stream:
            digest = "sha256:" + hashlib.file_digest(stream, "sha256").hexdigest()
        if digest != health["model_digest"]:
            raise ValueError("Comparator GGUF bytes do not match the native model")
    _, version = request(args.ollama, "/api/version")
    prompts = {"short": "What is two plus two? Answer with one word.",
               "passage": "Explain how a knowledge graph connects documents, entities and their evidence. Write three sentences.",
               "longer_prompt": ("A knowledge graph links documents, entities and the passages that support each connection. "
                    "Sources remain available for citation. New material is appended through a queue, checked for duplicate "
                    "content, and embedded in the same vector space. Failed imports can be inspected and retried safely. " * 4)
                    + "Summarize the reliability principles in three sentences."}
    samples = []
    for name, prompt in prompts.items():
        for provider in ("aesir", "ollama"):
            for index in range(args.samples + 1):
                sample_started = time.perf_counter()
                reply = None
                try:
                    if provider == "aesir":
                        seconds, reply = request(args.aesir, "/v1/generate", {
                            "prompt": prompt, "system": "You are concise.", "max_tokens": 32,
                            "temperature": 0}, key)
                        text, count = reply["text"], reply["generated_tokens"]
                        finish = reply["finish_reason"]
                    else:
                        seconds, reply = request(args.ollama, "/api/chat", {
                            "model": args.model, "stream": False,
                            "messages": [{"role": "system", "content": "You are concise."},
                                         {"role": "user", "content": prompt}],
                            "options": {"temperature": 0, "num_ctx": args.context,
                                        "num_predict": 32, "top_k": 40, "top_p": 1,
                                        "repeat_penalty": 1, "seed": 42}})
                        text, count = reply["message"]["content"], reply["eval_count"]
                        finish = reply["done_reason"]
                    if reply.get("model") != args.model or (provider == "aesir" and reply.get("backend") != "cuda"):
                        raise ValueError("Unexpected benchmark model/backend")
                    if finish not in ("eos", "stop", "length") or not isinstance(text, str) or not text.strip():
                        raise ValueError("Incomplete benchmark response")
                    if name == "short" and "four" not in text.lower() and "4" not in text:
                        raise ValueError("Arithmetic correctness gate failed")
                    samples.append({"provider": provider, "case": name,
                        "phase": "warmup" if index == 0 else "warm", "seconds": seconds,
                        "generated_tokens": count, "finish_reason": finish,
                        "text_sha256": hashlib.sha256(text.encode()).hexdigest(),
                        "prompt_tokens": reply.get("prompt_tokens", reply.get("prompt_eval_count")),
                        "load_duration_ns": reply.get("load_duration"),
                        "decode_duration_ns": reply.get("eval_duration")})
                except (OSError, ValueError, KeyError, TypeError, http.client.HTTPException) as error:
                    samples.append({"provider": provider, "case": name,
                        "phase": "warmup" if index == 0 else "warm",
                        "seconds": time.perf_counter() - sample_started,
                        "failure_category": type(error).__name__,
                        "finish_reason": reply.get("finish_reason", reply.get("done_reason")) if isinstance(reply, dict) else None})
    medians = {}
    for provider in ("aesir", "ollama"):
        medians[provider] = {}
        for case in prompts:
            measured = [sample["seconds"] for sample in samples if sample["provider"] == provider
                        and sample["case"] == case and sample["phase"] == "warm"
                        and "failure_category" not in sample]
            medians[provider][case] = statistics.median(measured) if measured else None
    failures = sum("failure_category" in sample for sample in samples)
    report = {"model": args.model, "model_weights": health["model_digest"],
              "context": args.context, "max_tokens": 32, "sampling": "greedy, repeat_penalty=1",
              "os": platform.platform(), "ollama_version": version,
              "aesir_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
              "aesir_worktree_dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], text=True)),
              "aesir_binary_sha256": binary_digest,
              "aesir_source_fingerprint": launch.source_fingerprint(),
              "comparator_blob_matches_native": args.ollama_gguf is not None,
              "gpu": subprocess.check_output(["nvidia-smi", "--query-gpu=name,driver_version,memory.total,memory.used", "--format=csv,noheader"], text=True).strip(),
              "medians_seconds": medians, "samples": samples, "failed_samples": failures,
              "limits": "HTTP wall time; warmup may include lazy JIT/model load. GGUF equality is hashed only when --ollama-gguf is supplied. Native F16 KV versus configured Ollama KV. No full-logit parity, first-token or cold-load claim."}
    with args.output.open("x", encoding="utf-8") as output:
        json.dump(report, output, indent=2)
        output.write("\n")
    print(json.dumps({"medians_seconds": medians, "failed_samples": failures}, indent=2))
    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
