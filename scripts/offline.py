#!/usr/bin/env python3
"""Prepare and verify an explicit, pinned Aesir offline application set."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parent.parent
LAUNCH = ROOT / "scripts" / "launch.py"
DEFAULT_MANIFEST = Path(".aesir/offline-preparation.v1.json")
RUNTIME_PATHS = (
    Path("pixi.lock"),
    Path("aesir.config.json"),
    Path("scripts/offline.py"),
    Path(".pixi/envs/default/bin/mojo"),
    Path(".pixi/envs/default/lib/libKGENCompilerRTShared.so"),
    Path(".pixi/envs/default/lib/libAsyncRTMojoBindings.so"),
    Path(".pixi/envs/default/lib/libMSupportGlobals.so"),
    Path(".pixi/envs/default/lib/libAsyncRTRuntimeGlobals.so"),
)
MAX_MANIFEST_BYTES = 1024 * 1024


class PreparationError(ValueError):
    pass


def _safe_relative(value: str, label: str) -> Path:
    path = Path(value)
    if not value or path.is_absolute() or "\0" in value:
        raise PreparationError(f"{label} must be a nonempty relative path")
    if any(part in ("", ".", "..") for part in path.parts):
        raise PreparationError(f"{label} must not contain empty, dot, or parent segments")
    return path


def _open_regular(path: Path):
    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW)
    info = os.fstat(fd)
    if not stat.S_ISREG(info.st_mode):
        os.close(fd)
        raise PreparationError(f"not a regular file: {path}")
    return os.fdopen(fd, "rb"), info


def _digest(path: Path) -> tuple[str, int]:
    stream, info = _open_regular(path)
    value = hashlib.sha256()
    with stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest(), info.st_size


def _file_record(name: str, relative: Path) -> dict[str, object]:
    digest, size = _digest(ROOT / relative)
    return {"name": name, "path": relative.as_posix(), "sha256": digest, "size": size}


def _run(args: list[str], *, capture: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        args,
        cwd=ROOT,
        text=True,
        capture_output=capture,
        timeout=7200,
        check=False,
    )
    if result.returncode != 0:
        detail = ((result.stdout or "") + (result.stderr or "")).strip()
        raise PreparationError(detail or f"command failed ({result.returncode}): {args[0]}")
    return result


def _pixi_record() -> dict[str, object]:
    executable = shutil.which("pixi")
    if not executable:
        candidate = Path.home() / ".pixi/bin/pixi"
        if candidate.is_file() and os.access(candidate, os.X_OK):
            executable = str(candidate)
    if not executable:
        raise PreparationError("dependency:pixi is missing")
    digest, size = _digest(Path(executable))
    version = _run([executable, "--version"]).stdout.strip()
    return {"name": "pixi", "version": version, "sha256": digest, "size": size}


def _load_json_regular(path: Path) -> object:
    stream, info = _open_regular(path)
    if info.st_size <= 0 or info.st_size > MAX_MANIFEST_BYTES:
        stream.close()
        raise PreparationError(f"manifest size is outside 1..{MAX_MANIFEST_BYTES} bytes")
    with stream:
        try:
            return json.load(stream)
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise PreparationError(f"manifest is not valid UTF-8 JSON: {error}") from error


def _catalog(binary: Path, model_store: str) -> dict[str, dict[str, object]]:
    result = _run([
        str(binary), "list", "--model-store", model_store, "--format", "json"
    ])
    try:
        records = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise PreparationError("model catalog did not return valid JSON") from error
    if not isinstance(records, list):
        raise PreparationError("model catalog JSON must be a list")
    answer: dict[str, dict[str, object]] = {}
    for record in records:
        if not isinstance(record, dict) or set(record) != {"name", "digest", "size"}:
            raise PreparationError("model catalog returned an unsupported record")
        name, digest, size = record["name"], record["digest"], record["size"]
        if (
            not isinstance(name, str)
            or not isinstance(digest, str)
            or not digest.startswith("sha256:")
            or len(digest) != 71
            or any(character not in "0123456789abcdef" for character in digest[7:])
            or type(size) is not int
            or size <= 0
        ):
            raise PreparationError("model catalog returned an invalid storage identity")
        if name in answer:
            raise PreparationError(f"model catalog returned duplicate identity: {name}")
        answer[name] = record
    return answer


def _write_manifest(path: Path, value: dict[str, object]) -> None:
    destination = ROOT / path
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.is_symlink():
        raise PreparationError(f"manifest destination is a symlink: {path}")
    payload = (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()
    if len(payload) > MAX_MANIFEST_BYTES:
        raise PreparationError("prepared manifest exceeds its size limit")
    descriptor, temporary = tempfile.mkstemp(prefix=".offline-preparation-", dir=destination.parent)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, destination)
        directory = os.open(destination.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def prepare(options: argparse.Namespace) -> None:
    model_store_path = _safe_relative(options.model_store, "model store")
    output = _safe_relative(options.output, "manifest output")
    if options.minimum_free_bytes < 0:
        raise PreparationError("minimum free bytes must be nonnegative")
    if len(set(options.model)) != len(options.model):
        raise PreparationError("model names must not be duplicated")
    _run([sys.executable, str(LAUNCH), "--build", "--target", options.target])
    binary = ROOT / ".aesir/launch/aesir"
    catalog = _catalog(binary, model_store_path.as_posix())
    missing = [name for name in options.model if name not in catalog]
    if missing:
        raise PreparationError("missing model artifacts: " + ", ".join(missing))
    models: list[dict[str, object]] = []
    for name in options.model:
        _run([str(binary), "verify", name, "--model-store", model_store_path.as_posix()])
    catalog = _catalog(binary, model_store_path.as_posix())
    for name in options.model:
        if name not in catalog:
            raise PreparationError(f"model artifact changed during preparation: {name}")
        record = catalog[name]
        models.append({"name": name, "sha256": record["digest"][7:], "size": record["size"]})
    available = shutil.disk_usage(ROOT).free
    if available < options.minimum_free_bytes:
        raise PreparationError(
            f"capacity:disk_free requires {options.minimum_free_bytes} bytes; observed {available}"
        )
    launch_manifest = _load_json_regular(ROOT / ".aesir/launch/manifest.json")
    if (
        not isinstance(launch_manifest, dict)
        or not isinstance(launch_manifest.get("source"), str)
        or launch_manifest.get("target") != options.target
    ):
        raise PreparationError("launch build manifest source/target identity is invalid")
    files = [_file_record(path.name, path) for path in RUNTIME_PATHS]
    files.append(_file_record("aesir", Path(".aesir/launch/aesir")))
    _run([sys.executable, str(LAUNCH), "--check"])
    value: dict[str, object] = {
        "schema": 1,
        "source_fingerprint": launch_manifest["source"],
        "target": options.target,
        "model_store": model_store_path.as_posix(),
        "models": models,
        "files": files,
        "pixi": _pixi_record(),
        "capacity": {
            "model_bytes": sum(int(record["size"]) for record in models),
            "prepared_file_bytes": sum(int(record["size"]) for record in files),
            "minimum_free_bytes": options.minimum_free_bytes,
            "available_bytes_at_prepare": available,
        },
    }
    _write_manifest(output, value)
    print(f"Prepared offline manifest: {output.as_posix()}")
    print("Pinned models: " + ", ".join(options.model))


def _validate_manifest_shape(value: object) -> dict[str, object]:
    if not isinstance(value, dict) or set(value) != {
        "schema", "source_fingerprint", "target", "model_store", "models",
        "files", "pixi", "capacity",
    } or value.get("schema") != 1:
        raise PreparationError("unsupported offline preparation manifest")
    if not isinstance(value["models"], list) or not value["models"]:
        raise PreparationError("manifest models must be a nonempty list")
    if not isinstance(value["files"], list) or not value["files"]:
        raise PreparationError("manifest files must be a nonempty list")
    if not isinstance(value["pixi"], dict) or not isinstance(value["capacity"], dict):
        raise PreparationError("manifest dependency/capacity records are invalid")
    if (
        not isinstance(value["source_fingerprint"], str)
        or len(value["source_fingerprint"]) != 64
        or any(character not in "0123456789abcdef" for character in value["source_fingerprint"])
    ):
        raise PreparationError("manifest source fingerprint is invalid")
    if (
        not isinstance(value["target"], str)
        or not value["target"].startswith("sm_")
        or not value["target"][3:].isdigit()
    ):
        raise PreparationError("manifest target is invalid")
    expected_paths = {path.as_posix() for path in RUNTIME_PATHS} | {".aesir/launch/aesir"}
    observed_paths = {
        record.get("path") for record in value["files"] if isinstance(record, dict)
    }
    if observed_paths != expected_paths or len(value["files"]) != len(expected_paths):
        raise PreparationError("manifest does not contain the exact runtime file set")
    if set(value["pixi"]) != {"name", "version", "sha256", "size"} or value["pixi"].get("name") != "pixi":
        raise PreparationError("manifest pixi identity is invalid")
    if set(value["capacity"]) != {
        "model_bytes", "prepared_file_bytes", "minimum_free_bytes",
        "available_bytes_at_prepare",
    }:
        raise PreparationError("manifest capacity record is invalid")
    if any(type(value["capacity"][key]) is not int or value["capacity"][key] < 0 for key in value["capacity"]):
        raise PreparationError("manifest capacity values must be nonnegative integers")
    model_names: set[str] = set()
    for record in value["models"]:
        if (
            not isinstance(record, dict)
            or set(record) != {"name", "sha256", "size"}
            or not isinstance(record["name"], str)
            or not record["name"]
            or not isinstance(record["sha256"], str)
            or len(record["sha256"]) != 64
            or any(character not in "0123456789abcdef" for character in record["sha256"])
            or type(record["size"]) is not int
            or record["size"] <= 0
            or record["name"] in model_names
        ):
            raise PreparationError("manifest model record is invalid or duplicated")
        model_names.add(record["name"])
    return value


def check(options: argparse.Namespace) -> None:
    manifest_path = _safe_relative(options.manifest, "manifest")
    value = _validate_manifest_shape(_load_json_regular(ROOT / manifest_path))
    issues: list[str] = []
    if options.rebuild:
        try:
            _run([sys.executable, str(LAUNCH), "--build", "--target", str(value["target"])])
        except (OSError, PreparationError) as error:
            issues.append(f"build:aesir: {error}")
    try:
        _run([sys.executable, str(LAUNCH), "--check"])
    except (OSError, PreparationError) as error:
        issues.append(f"build:aesir: {error}")
    try:
        launch_manifest = _load_json_regular(ROOT / ".aesir/launch/manifest.json")
        if not isinstance(launch_manifest, dict) or launch_manifest.get("source") != value["source_fingerprint"]:
            raise PreparationError("source fingerprint differs from prepared identity")
    except (OSError, PreparationError) as error:
        issues.append(f"build:source: {error}")
    for record in value["files"]:
        name = record.get("name") if isinstance(record, dict) else "unknown"
        try:
            if not isinstance(record, dict) or set(record) != {"name", "path", "sha256", "size"}:
                raise PreparationError("invalid file record")
            relative = _safe_relative(str(record["path"]), f"file:{name}")
            digest, size = _digest(ROOT / relative)
            if digest != record["sha256"] or size != record["size"]:
                raise PreparationError("size or SHA-256 differs from prepared identity")
        except (OSError, PreparationError) as error:
            issues.append(f"file:{name}: {error}")
    try:
        current_pixi = _pixi_record()
        expected_pixi = value["pixi"]
        if any(current_pixi.get(key) != expected_pixi.get(key) for key in ("version", "sha256", "size")):
            raise PreparationError("version, size, or SHA-256 differs from prepared identity")
    except (OSError, PreparationError) as error:
        issues.append(f"dependency:pixi: {error}")
    try:
        model_store = _safe_relative(str(value["model_store"]), "model store").as_posix()
        catalog = _catalog(ROOT / ".aesir/launch/aesir", model_store)
    except (OSError, PreparationError) as error:
        model_store, catalog = "", {}
        issues.append(f"model-catalog: {error}")
    model_names: list[str] = []
    observed_model_bytes = 0
    for record in value["models"]:
        name = record.get("name") if isinstance(record, dict) else "unknown"
        model_names.append(str(name))
        try:
            if not isinstance(record, dict) or set(record) != {"name", "sha256", "size"}:
                raise PreparationError("invalid model record")
            current = catalog.get(str(name))
            if current is None:
                raise PreparationError("not present in the selected catalog")
            if current["digest"] != "sha256:" + str(record["sha256"]) or current["size"] != record["size"]:
                raise PreparationError("catalog identity differs from prepared pin")
            observed_model_bytes += int(record["size"])
            _run([str(ROOT / ".aesir/launch/aesir"), "verify", str(name), "--model-store", model_store])
        except (OSError, PreparationError) as error:
            issues.append(f"model:{name}: {error}")
    capacity = value["capacity"]
    minimum = capacity.get("minimum_free_bytes") if isinstance(capacity, dict) else None
    prepared_file_bytes = sum(
        int(record["size"])
        for record in value["files"]
        if isinstance(record, dict) and type(record.get("size")) is int
    )
    if capacity.get("model_bytes") != observed_model_bytes:
        issues.append("capacity:model_bytes: total differs from pinned model records")
    if capacity.get("prepared_file_bytes") != prepared_file_bytes:
        issues.append("capacity:prepared_file_bytes: total differs from runtime file records")
    if type(minimum) is not int or minimum < 0:
        issues.append("capacity:disk_free: invalid minimum")
    else:
        available = shutil.disk_usage(ROOT).free
        if available < minimum:
            issues.append(f"capacity:disk_free: requires {minimum} bytes; observed {available}")
    if issues:
        raise PreparationError("offline preparation is incomplete:\n- " + "\n- ".join(issues))
    if options.inference:
        model = options.inference_model or model_names[0]
        if model not in model_names:
            raise PreparationError(f"inference:{model}: model is not pinned by this manifest")
        base = _load_json_regular(ROOT / "aesir.config.json")
        if not isinstance(base, dict) or not isinstance(base.get("storage"), dict):
            raise PreparationError("inference:base-config: storage object is missing")
        base["storage"]["model_store_path"] = model_store
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", prefix="offline-check-", suffix=".json",
            dir=ROOT / ".aesir", delete=False,
        ) as stream:
            json.dump(base, stream, separators=(",", ":"))
            stream.write("\n")
            config_path = Path(stream.name)
        try:
            relative_config = config_path.relative_to(ROOT).as_posix()
            _run([
                str(ROOT / ".aesir/launch/aesir"), "run", model,
                "--config", relative_config, "--accel", options.accel,
                "--max-tokens", str(options.max_tokens), options.prompt,
            ], capture=False)
        except (OSError, PreparationError) as error:
            raise PreparationError(f"inference:{model}: {error}") from error
        finally:
            config_path.unlink(missing_ok=True)
    print("Offline preparation check passed.")
    print("Verified models: " + ", ".join(model_names))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    prepare_parser = subparsers.add_parser("prepare", help="build, verify local models, and write a pinned manifest")
    prepare_parser.add_argument("--model", action="append", required=True, help="catalog model name; repeat as needed")
    prepare_parser.add_argument("--model-store", default=".aesir/models")
    prepare_parser.add_argument("--output", default=DEFAULT_MANIFEST.as_posix())
    prepare_parser.add_argument("--target", default="sm_89")
    prepare_parser.add_argument("--minimum-free-bytes", type=int, default=512 * 1024 * 1024)
    check_parser = subparsers.add_parser("check", help="verify every prepared artifact without network access")
    check_parser.add_argument("--manifest", default=DEFAULT_MANIFEST.as_posix())
    check_parser.add_argument("--rebuild", action="store_true", help="prove the locked environment can rebuild offline")
    check_parser.add_argument("--inference", action="store_true", help="run one bounded inference after verification")
    check_parser.add_argument("--inference-model")
    check_parser.add_argument("--accel", choices=("cpu", "cuda"), default="cuda")
    check_parser.add_argument("--max-tokens", type=int, default=1)
    check_parser.add_argument("--prompt", default="Reply with OK.")
    options = parser.parse_args()
    if getattr(options, "max_tokens", 1) < 1 or getattr(options, "max_tokens", 1) > 32:
        parser.error("--max-tokens must be in 1..32")
    try:
        if options.command == "prepare":
            prepare(options)
        else:
            check(options)
        return 0
    except (OSError, PreparationError) as error:
        print(f"Aesir offline preparation: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
