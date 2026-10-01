"""Opt-in paired installed-service measurements with retained failures and policies."""
from __future__ import annotations

import argparse
import hashlib
import http.client
import json
import math
from pathlib import Path
import platform
import random
import re
import statistics
import subprocess
import sys
import time
from typing import Any
from urllib.parse import urlsplit

import launch
from benchmark_native import EXTENDED_PROMPTS, STRESS_PROMPTS

# Public synthetic benchmark vectors; preserve the original standard requests.
STANDARD_PROMPTS = {
    "short": "What is two plus two? Answer with one word.",
    "passage": "Explain how a knowledge graph connects documents, entities and their evidence. Write three sentences.",
    "longer_prompt": (
        "A knowledge graph links documents, entities and the passages that support each connection. "
        "Sources remain available for citation. New material is appended through a queue, checked for duplicate "
        "content, and embedded in the same vector space. Failed imports can be inspected and retried safely. " * 4
    ) + "Summarize the reliability principles in three sentences.",
}
SUITES = {"standard": STANDARD_PROMPTS, "extended": EXTENDED_PROMPTS,
          "stress": STRESS_PROMPTS,
          "all": {**STANDARD_PROMPTS, **EXTENDED_PROMPTS, **STRESS_PROMPTS}}
SYSTEM = "You are concise."
RESPONSE_LIMIT = 1048576


def finite_json(raw: bytes) -> Any:
    def reject(value: str) -> None:
        raise ValueError("Nonfinite JSON number")
    def finite_float(value: str) -> float:
        number = float(value)
        if not math.isfinite(number):
            raise ValueError("Overflowing JSON float")
        return number
    def unique(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result = {}
        for name, value in pairs:
            if name in result:
                raise ValueError("Duplicate JSON field")
            result[name] = value
        return result
    try:
        return json.loads(raw, parse_constant=reject, parse_float=finite_float, object_pairs_hook=unique)
    except RecursionError as error:
        raise ValueError("JSON nesting exceeds parser admission") from error


def request(origin: str, route: str, body: dict | None = None,
            key: str = "", timeout: float = 120) -> tuple[float, dict]:
    url = urlsplit(origin)
    if (url.scheme != "http" or not url.hostname or url.username or url.password
            or url.path or url.query or url.fragment
            or key and url.hostname != "127.0.0.1"):
        raise ValueError("Explicit HTTP origin required; native credentials stay loopback")
    if not math.isfinite(timeout) or not 0 < timeout <= 600:
        raise ValueError("Invalid HTTP timeout")
    connection = http.client.HTTPConnection(url.hostname, url.port, timeout=timeout)
    headers = {"Content-Type": "application/json"}
    if key:
        headers["Authorization"] = "Bearer " + key
    started = time.perf_counter()
    try:
        connection.request("POST" if body is not None else "GET", route,
                           json.dumps(body, allow_nan=False).encode() if body is not None else None,
                           headers)
        response = connection.getresponse()
        raw = response.read(RESPONSE_LIMIT + 1)
        elapsed = time.perf_counter() - started
        if response.status != 200 or len(raw) > RESPONSE_LIMIT:
            raise ValueError("HTTP response failed status/size admission")
        reply = finite_json(raw)
        if not isinstance(reply, dict):
            raise ValueError("HTTP JSON object required")
        return elapsed, reply
    finally:
        connection.close()


def integer(value: Any, lower: int, upper: int) -> int:
    if type(value) is not int or not lower <= value <= upper:
        raise ValueError("Invalid observed integer")
    return value


def observed_duration(reply: dict, name: str) -> int | None:
    value = reply.get(name)
    return None if value is None else integer(value, 0, 10**15)


def redact(value: Any, key: str) -> Any:
    if isinstance(value, str):
        return value.replace(key, "[REDACTED]") if key else value
    if isinstance(value, dict):
        return {redact(k, key): redact(v, key) for k, v in value.items()}
    if isinstance(value, list):
        return [redact(v, key) for v in value]
    return value


def schedule(prompts: dict[str, str], samples: int, order: str,
             seed: int) -> list[tuple[str, int, str]]:
    rng = random.Random(seed)
    result = []
    for case in prompts:
        if order == "grouped":
            result.extend((case, index, provider) for provider in ("aesir", "ollama")
                          for index in range(samples + 1))
        else:
            for index in range(samples + 1):
                providers = ["aesir", "ollama"]
                if order == "randomized":
                    rng.shuffle(providers)
                elif index % 2:
                    providers.reverse()
                result.extend((case, index, provider) for provider in providers)
    return result


def payload(provider: str, prompt: str, args: argparse.Namespace) -> dict:
    if provider == "aesir":
        return {"prompt": prompt, "system": SYSTEM,
                "max_tokens": args.max_tokens, "temperature": 0}
    result = {"model": args.model, "stream": False,
              "messages": [{"role": "system", "content": SYSTEM},
                           {"role": "user", "content": prompt}],
              "options": {"temperature": 0, "num_ctx": args.context,
                          "num_predict": args.max_tokens, "top_k": 40,
                          "top_p": 1, "repeat_penalty": 1, "seed": 42}}
    if args.residency == "loaded":
        result["keep_alive"] = "10m"
    return result


def sample_reply(provider: str, case: str, index: int, prompt: str,
                 args: argparse.Namespace, key: str) -> dict:
    body = payload(provider, prompt, args)
    sample = {"provider": provider, "case": case,
              "phase": "warmup" if index == 0 else "warm", "repeat_index": index,
              "prompt": prompt, "request": body, "seconds": None}
    reply = None
    started = time.perf_counter()
    try:
        origin = args.aesir if provider == "aesir" else args.ollama
        route = "/v1/generate" if provider == "aesir" else "/api/chat"
        elapsed, reply = request(origin, route, body, key if provider == "aesir" else "",
                                 args.timeout)
        sample.update(seconds=elapsed, reply=redact(reply, key))
        if reply.get("model") != args.model or provider == "aesir" and reply.get("backend") != "cuda":
            raise ValueError("Response model/backend mismatch")
        if provider == "ollama" and reply.get("done") is not True:
            raise ValueError("Ollama response has no completed terminal")
        text = reply.get("text") if provider == "aesir" else reply.get("message", {}).get("content")
        count = integer(reply.get("generated_tokens" if provider == "aesir" else "eval_count"), 1, args.max_tokens)
        prompt_count = integer(reply.get("prompt_tokens" if provider == "aesir" else "prompt_eval_count"), 1, args.context)
        if prompt_count + count > args.context:
            raise ValueError("Observed token counts exceed declared context")
        finish = reply.get("finish_reason" if provider == "aesir" else "done_reason")
        if (finish not in ("eos", "stop", "length") or not isinstance(text, str)
                or not text.strip() or finish == "length" and count != args.max_tokens):
            raise ValueError("Incomplete response/count")
        if case == "short" and not any(word in text.lower() for word in ("four", "4")):
            raise ValueError("Arithmetic correctness failed")
        sample.update(generated_tokens=count, prompt_tokens=prompt_count,
                      finish_reason=finish, text=redact(text, key),
                      text_sha256=hashlib.sha256(text.encode()).hexdigest(),
                      load_duration_ns=observed_duration(reply, "load_duration"),
                      prompt_eval_duration_ns=observed_duration(reply, "prompt_eval_duration"),
                      decode_duration_ns=observed_duration(reply, "eval_duration"))
    except (OSError, ValueError, TypeError, KeyError, AttributeError, http.client.HTTPException) as error:
        sample.update(seconds=time.perf_counter() - started,
                      failure_category=type(error).__name__)
        if reply is not None:
            sample["reply"] = redact(reply, key)
    return sample


def distribution(values: list[float]) -> dict:
    if not values or any(not math.isfinite(v) or v <= 0 for v in values):
        raise ValueError("Invalid measurement values")
    ordered = sorted(values)
    rng = random.Random(42)
    boots = sorted(statistics.median(rng.choices(values, k=len(values))) for _ in range(1000))
    return {"n": len(values), "median": statistics.median(values),
            "p95_observed": ordered[max(0, math.ceil(.95 * len(values)) - 1)],
            "median_bootstrap_95": [boots[24], boots[974]],
            "small_sample": len(values) < 10}


def summarize(report: dict, prompts: dict[str, str]) -> None:
    samples = report["samples"]
    report["failed_samples"] = sum("failure_category" in s for s in samples)
    report["medians_seconds"] = {p: {} for p in ("aesir", "ollama")}
    report["distributions_seconds"] = {p: {} for p in ("aesir", "ollama")}
    report["speed_ratios"] = {}
    for case in prompts:
        groups = {p: [s for s in samples if s["provider"] == p and s["case"] == case
                      and s["phase"] == "warm"] for p in ("aesir", "ollama")}
        valid = all(len(g) == report["samples_per_case"] and
                    all("failure_category" not in s for s in g) for g in groups.values())
        for p, group in groups.items():
            if valid:
                stats = distribution([s["seconds"] for s in group])
                report["distributions_seconds"][p][case] = stats
                report["medians_seconds"][p][case] = stats["median"]
            else:
                report["medians_seconds"][p][case] = None
        equal = valid and all(s["generated_tokens"] == report["max_tokens"]
                              for g in groups.values() for s in g)
        all_good = not report["errors"] and not report["failed_samples"]
        report["speed_ratios"][case] = {
            "ollama_over_aesir": report["medians_seconds"]["ollama"][case] /
            report["medians_seconds"]["aesir"][case] if equal and all_good and case != "short" else None,
            "equal_required_output_counts": equal,
            "quality_parity_established": False,
            "certified_lead": False,
        }


def gpu_snapshot() -> dict:
    try:
        value = subprocess.check_output([
            "nvidia-smi", "--query-gpu=name,driver_version,memory.total,memory.used,temperature.gpu,clocks.sm,clocks.mem,power.draw",
            "--format=csv,noheader"], text=True, timeout=5).strip()
        return {"observed": value, "unix_seconds": time.time()}
    except (OSError, subprocess.SubprocessError):
        return {"unavailable": True, "unix_seconds": time.time()}


def preflight(args: argparse.Namespace, report: dict, key: str) -> None:
    binary = launch.validate_build()
    with binary.open("rb") as stream:
        report["aesir_binary_sha256"] = hashlib.file_digest(stream, "sha256").hexdigest()
    report["aesir_source_fingerprint"] = launch.source_fingerprint()
    report["aesir_revision"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=launch.ROOT, text=True).strip()
    report["aesir_worktree_dirty"] = bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=launch.ROOT, text=True))
    _, health = request(args.aesir, "/health", key=key, timeout=args.timeout)
    if (health.get("status") != "ready" or health.get("backend") != "cuda"
            or health.get("model") != args.model or health.get("context") != args.context
            or integer(health.get("max_tokens"), 1, 127000) < args.max_tokens):
        raise ValueError("Loaded native identity/context/output policy mismatch")
    report["native_health"] = redact(health, key)
    report["model_weights"] = health["model_digest"]
    if not isinstance(report["model_weights"], str) or not re.fullmatch(r"sha256:[0-9a-f]{64}", report["model_weights"]):
        raise ValueError("Invalid native model digest")
    if not isinstance(health.get("capabilities"), dict):
        raise ValueError("Invalid native capabilities")
    report["cache_policy"] = {"native_exact_prefix_reuse": health.get("capabilities", {}).get("exact_prefix_reuse"),
                              "ollama_cache_disabled": None,
                              "first_appearance_is_cache_disabled": False}
    if args.native_no_prefix_cache and report["cache_policy"]["native_exact_prefix_reuse"] is not False:
        raise ValueError("Native cache-disable control was not observed")
    if args.native_pid is not None:
        with Path(f"/proc/{args.native_pid}/exe").open("rb") as stream:
            observed = hashlib.file_digest(stream, "sha256").hexdigest()
        if observed != report["aesir_binary_sha256"]:
            raise ValueError("Observed native process differs from validated build")
        report["native_process_executable_sha256"] = observed
    if args.ollama_gguf is not None:
        with args.ollama_gguf.open("rb") as stream:
            digest = "sha256:" + hashlib.file_digest(stream, "sha256").hexdigest()
        if digest != report["model_weights"]:
            raise ValueError("Comparator GGUF bytes mismatch")
    report["comparator_blob_matches_native"] = args.ollama_gguf is not None
    _, report["ollama_version"] = request(args.ollama, "/api/version", timeout=args.timeout)
    if args.residency == "loaded":
        _, loaded = request(args.ollama, "/api/chat", {"model": args.model, "messages": [],
                           "stream": False, "keep_alive": "10m", "options": {"num_ctx": args.context}}, timeout=args.timeout)
        if loaded.get("model") != args.model or loaded.get("done") is not True:
            raise ValueError("Ollama preload failed")
        report["ollama_preload_reply"] = redact(loaded, key)
    _, report["ollama_residency_before"] = request(args.ollama, "/api/ps", timeout=args.timeout)
    if args.residency == "loaded":
        models = report["ollama_residency_before"].get("models")
        if not isinstance(models, list) or not any(isinstance(m, dict) and m.get("model", m.get("name")) == args.model and m.get("context_length") == args.context for m in models):
            raise ValueError("Ollama residency/context not observed")


def measure(args: argparse.Namespace) -> dict:
    prompts = SUITES[args.suite]
    report = {"schema_version": 2, "model": args.model, "context": args.context,
              "max_tokens": args.max_tokens, "suite": args.suite, "samples_per_case": args.samples,
              "system": SYSTEM, "sampling": "greedy, repeat_penalty=1",
              "order": args.order, "order_seed": args.order_seed, "residency": args.residency,
              "native_process_identity_observed": args.native_pid is not None,
              "os": platform.platform(), "samples": [], "errors": [],
              "limits": "Installed-service HTTP wall times. First appearance can reuse prefixes. Templates/KV may differ; declared blob equality is not API model attestation. Provider durations are reported, not independently validated. First-token/CPU-enqueue/GPU-only time and quality parity are not established. Bootstrap intervals require independent sessions and adequate samples before lead claims."}
    key = ""
    try:
        key = args.key_file.read_text().strip()
        if not key or len(key) > 4096 or any(c.isspace() for c in key):
            raise ValueError("Invalid native key file")
        preflight(args, report, key)
        report["gpu_before"] = gpu_snapshot()
        for case, index, provider in schedule(prompts, args.samples, args.order, args.order_seed):
            sample = sample_reply(provider, case, index, prompts[case], args, key)
            sample["sequence_index"] = len(report["samples"])
            report["samples"].append(sample)
            print(json.dumps({"provider": provider, "case": case, "repeat_index": index,
                              "seconds": sample["seconds"], "failed": "failure_category" in sample}), flush=True)
        report["gpu_after"] = gpu_snapshot()
    except KeyboardInterrupt:
        report["errors"].append("Interrupted")
    except (OSError, ValueError, TypeError, KeyError, http.client.HTTPException,
            AttributeError, subprocess.SubprocessError) as error:
        report["errors"].append(type(error).__name__)
    summarize(report, prompts)
    return redact(report, key)


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--aesir", default="http://127.0.0.1:18434")
    result.add_argument("--ollama", required=True)
    result.add_argument("--key-file", required=True, type=Path)
    result.add_argument("--model", required=True)
    result.add_argument("--ollama-gguf", type=Path)
    result.add_argument("--native-pid", type=int)
    result.add_argument("--context", type=int, default=4096)
    result.add_argument("--samples", type=int, default=3)
    result.add_argument("--suite", choices=SUITES, default="standard")
    result.add_argument("--max-tokens", type=int, default=32)
    result.add_argument("--order", choices=("balanced", "randomized", "grouped"), default="balanced")
    result.add_argument("--order-seed", type=int, default=42)
    result.add_argument("--residency", choices=("as-is", "loaded"), default="as-is")
    result.add_argument("--native-no-prefix-cache", action="store_true")
    result.add_argument("--timeout", type=float, default=120)
    result.add_argument("--output", required=True, type=Path)
    return result


def main(argv: list[str] | None = None) -> int:
    options = parser()
    args = options.parse_args(argv)
    if not 1 <= args.samples <= 100 or not 512 <= args.context <= 8192:
        options.error("Use 1..100 samples and context 512..8192")
    if not 1 <= args.max_tokens <= 256 or not math.isfinite(args.timeout) or not 0 < args.timeout <= 600:
        options.error("Use 1..256 output tokens and a finite timeout in 0..600 seconds")
    if args.native_pid is not None and args.native_pid < 1:
        options.error("Native PID must be positive")
    # Reserve exclusively before any key/model/network/GPU operation.
    with args.output.open("x", encoding="utf-8") as output:
        report = measure(args)
        json.dump(report, output, indent=2, ensure_ascii=False, allow_nan=False)
        output.write("\n")
    print(json.dumps({"medians_seconds": report["medians_seconds"],
                      "failed_samples": report["failed_samples"], "errors": report["errors"]}))
    return 130 if "Interrupted" in report["errors"] else int(bool(report["failed_samples"] or report["errors"]))


if __name__ == "__main__":
    raise SystemExit(main())
