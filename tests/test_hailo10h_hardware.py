#!/usr/bin/env python3
"""TEST-ONLY physical Hailo acceptance through the real canonical AESIR CLI.

Explicit binary/model/profile/evidence arguments are required. No mocks,
alternative backends, service endpoints, model downloads, or automatic skips.
All stdout/stderr are preserved, including failed and timed-out runs. The
profile contains public prompts; do not use this runner with private prompts.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
from datetime import datetime, timezone


ROOT = Path(__file__).resolve().parents[1]
IDENTITY_KEYS = (
    "architecture", "backend", "runtime_version", "firmware_version",
    "model_sha256", "model_size_bytes", "context_capacity", "template_token_reserve",
)
SOURCE_PATHS = (
    "aesir_engine/main.mojo", "aesir_engine/cli/hailo_commands.mojo",
    "aesir_engine/hailo10h_direct.mojo", "aesir_engine/hailo10h_bridge.cpp",
    "scripts/build_hailo10h.sh", "tests/test_hailo10h_hardware.py",
)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def fingerprint(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        before = os.fstat(stream.fileno())
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
        after = os.fstat(stream.fileno())
    fields = ("st_dev", "st_ino", "st_size", "st_mtime_ns", "st_ctime_ns")
    require(all(getattr(before, f) == getattr(after, f) for f in fields),
            "artifact changed while fingerprinting")
    return {"sha256": digest.hexdigest(), "size_bytes": after.st_size}


def records(stdout):
    """Strict JSON-lines, so a warning/banner cannot masquerade as a result."""
    result = [json.loads(line) for line in stdout.splitlines() if line.strip()]
    require(result and all(isinstance(row, dict) for row in result),
            "expected nonempty JSON object records")
    return result


def validate_identity(value, profile, device_id=None):
    require(isinstance(value, dict), "missing provenance object")
    for key in IDENTITY_KEYS:
        require(key in value and type(value[key]) is type(profile[key])
                and value[key] == profile[key], "provenance mismatch: " + key)
    require(isinstance(value.get("device_id"), str) and value["device_id"],
            "missing observed physical device identity")
    if device_id is not None:
        require(value["device_id"] == device_id, "physical device changed")
    usage = value.get("context_usage")
    require(type(usage) is int and 0 <= usage <= profile["context_capacity"],
            "invalid context usage")
    require(value.get("needs_reset") is False and value.get("needs_reopen") is False,
            "session recovery is required")
    return value["device_id"]


def validate_response(row, profile, device_id, *, arithmetic=False, recall=False):
    require("error" not in row and "event" not in row, "request failed")
    text = row.get("response")
    require(isinstance(text, str) and text.strip(), "empty generated response")
    validate_identity(row.get("provenance"), profile, device_id)
    provenance = row["provenance"]
    require(provenance.get("last_completion") in ("end_of_generation", "max_tokens"),
            "generation did not complete")
    require(provenance["context_usage"] > 0, "generation did not consume context")
    if arithmetic:
        require(re.fullmatch(profile["arithmetic_response_pattern"], text) is not None,
                "arithmetic response failed the declared expectation")
    if recall:
        word = profile["recall_word"]
        require(re.search(r"\b" + re.escape(word) + r"\b", text, re.IGNORECASE),
                "the completed conversation did not recall its word")
    return text


def validate_chat(rows, profile, device_id):
    require(len(rows) == 9, "chat must produce exactly nine ordered records")
    validate_identity(rows[0], profile, device_id)
    require(rows[0]["context_usage"] == 0, "chat did not start empty")
    validate_response(rows[1], profile, device_id)
    recall = validate_response(rows[2], profile, device_id, recall=True)
    require(rows[2]["provenance"]["context_usage"] > rows[1]["provenance"]["context_usage"],
            "second turn did not retain and extend context")
    require(isinstance(rows[3].get("error"), str)
            and "ContextCapacityExceeded" in rows[3]["error"] and "response" not in rows[3],
            "oversized prompt was not explicitly rejected")
    validate_identity(rows[4], profile, device_id)
    require(rows[4]["context_usage"] == rows[2]["provenance"]["context_usage"],
            "rejected prompt changed completed context")
    recall_after = validate_response(rows[5], profile, device_id, recall=True)
    require(rows[6].get("event") == "context_cleared", "missing explicit reset event")
    validate_identity(rows[6].get("provenance"), profile, device_id)
    require(rows[6]["provenance"]["context_usage"] == 0, "reset left context behind")
    require(rows[6]["provenance"].get("last_completion") == "context_cleared",
            "reset did not report its terminal state")
    validate_identity(rows[7], profile, device_id)
    require(rows[7]["context_usage"] == 0, "context grew without a request")
    validate_response(rows[8], profile, device_id, arithmetic=True)
    # Track exact formatting independently; remembering a word is a narrower
    # condition than obeying a word-only instruction.
    return {"recall_word_only": recall.strip().casefold() == profile["recall_word"].casefold(),
            "recall_after_rejection_word_only":
                recall_after.strip().casefold() == profile["recall_word"].casefold()}


def execute(binary, model, profile, destination, name, command, stdin=""):
    arguments = [str(binary), command, "--model-path", str(model), "--format", "json"]
    if command != "hardware":
        arguments += ["--max-tokens", str(profile["max_tokens"]),
                      "--timeout-ms", str(profile["timeout_ms"])]
    if command == "run":
        arguments += ["--prompt", profile["arithmetic_prompt"]]
    (destination / (name + ".stdin.txt")).write_text(stdin, encoding="utf-8")
    started = time.monotonic()
    stdout_path = destination / (name + ".stdout.txt")
    stderr_path = destination / (name + ".stderr.txt")
    with stdout_path.open("xb") as stdout, stderr_path.open("xb") as stderr:
        try:
            result = subprocess.run(arguments, input=stdin.encode("utf-8"),
                                    stdout=stdout, stderr=stderr, cwd=ROOT,
                                    timeout=profile["process_timeout_seconds"], check=False)
            status = {"returncode": result.returncode, "timed_out": False}
        except subprocess.TimeoutExpired:
            status = {"returncode": None, "timed_out": True}
    status["wall_seconds"] = time.monotonic() - started
    (destination / (name + ".process.json")).write_text(json.dumps(status, indent=2) + "\n")
    require(not status["timed_out"], name + " exceeded its process timeout; raw output retained")
    require(status["returncode"] == 0, name + " exited nonzero; raw output retained")
    return records(stdout_path.read_text(encoding="utf-8")), status


def run(args):
    destination = Path(args.evidence_dir).resolve()
    destination.mkdir(parents=True, exist_ok=False)
    report = {"schema_version": 1, "status": "RUNNING", "mocked": False,
              "started_utc": datetime.now(timezone.utc).isoformat(), "checks": {}}
    report_path = destination / "report.json"

    def save():
        report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")

    save()
    try:
        binary = Path(args.binary).resolve(strict=True)
        model = Path(args.model_path).resolve(strict=True)
        profile_path = Path(args.profile).resolve(strict=True)
        profile = json.loads(profile_path.read_text(encoding="utf-8"))
        require(profile["schema_version"] == 1, "unknown profile schema")
        require(profile["architecture"] == "HAILO10H" and profile["backend"] == "hailort-genai",
                "only direct Hailo-10H profiles are allowed")
        require(type(profile["process_timeout_seconds"]) is int
                and 1 <= profile["process_timeout_seconds"] <= 600, "invalid process timeout")
        require(model.is_file() and binary.is_file(), "regular model and executable required")
        report["profile"] = profile
        report["source_commit"] = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        paths = {name: ROOT / name for name in SOURCE_PATHS}
        paths.update({"binary": binary, "bridge": binary.parent / "libaesir_hailo10h.so",
                      "profile": profile_path, "model": model})
        report["artifacts"] = {name: fingerprint(path) for name, path in paths.items()}
        require(report["artifacts"]["model"] == {
            "sha256": profile["model_sha256"], "size_bytes": profile["model_size_bytes"]},
            "independent model fingerprint differs from the pinned profile")
        save()
        identity, process = execute(binary, model, profile, destination, "readiness", "hardware")
        require(len(identity) == 1, "expected exactly one readiness record")
        device = validate_identity(identity[0], profile)
        require(identity[0]["context_usage"] == 0 and identity[0]["last_completion"] == "none",
                "fresh model readiness was not empty")
        report["device_id"] = device
        report["checks"]["readiness"] = process
        save()
        response, process = execute(binary, model, profile, destination, "single", "run")
        require(len(response) == 1, "expected exactly one single-shot response")
        validate_response(response[0], profile, device, arithmetic=True)
        report["checks"]["single"] = process
        save()
        chat_input = "\n".join([
            "/info", profile["remember_prompt"], profile["recall_prompt"],
            profile["overflow_word"] * profile["overflow_repetitions"], "/info",
            profile["recall_prompt"], "/clear", "/info", profile["arithmetic_prompt"], "/bye", "",
        ])
        chat, process = execute(binary, model, profile, destination, "chat", "chat", chat_input)
        report["format_observations"] = validate_chat(chat, profile, device)
        report["checks"]["chat"] = process
        # Hash again after execution; stale/mutated inputs cannot earn a pass.
        require(report["artifacts"] == {name: fingerprint(path) for name, path in paths.items()},
                "source, executable, library, profile or model changed during acceptance")
        report["status"] = "PASSED"
        report["evidence_kind"] = "physical-hailo10h-canonical-cli"
        report["evidence_boundary"] = profile["evidence_boundary"]
    except Exception as error:
        report["status"] = "FAILED"
        report["error"] = str(error)
    finally:
        report["finished_utc"] = datetime.now(timezone.utc).isoformat()
        save()
    print(json.dumps({"status": report["status"], "report": str(report_path)}))
    return 0 if report["status"] == "PASSED" else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True)
    parser.add_argument("--model-path", required=True)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--evidence-dir", required=True)
    return run(parser.parse_args())


if __name__ == "__main__":
    sys.exit(main())
