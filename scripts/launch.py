#!/usr/bin/env python3
"""Offline Linux/WSL build and terminal entry. No inference or package installation."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import stat
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / ".aesir" / "launch"
REBUILD = "Run python3 scripts/launch.py --build in this checkout (prepared Pixi environment required)."
RUNTIME_LIBS = ("libKGENCompilerRTShared.so", "libAsyncRTMojoBindings.so",
                "libMSupportGlobals.so", "libAsyncRTRuntimeGlobals.so")


def digest(path):
    # Reject special files before opening; nonblocking/no-follow also closes the
    # final-component replacement window for a FIFO or symlink.
    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW)
    with os.fdopen(fd, "rb") as stream:
        if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
            raise ValueError(f"Not a regular file: {path}")
        value = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
        return value.hexdigest()


def source_fingerprint():
    paths = [ROOT / "pixi.toml", ROOT / "pixi.lock", ROOT / "scripts/launch.py"]
    paths += sorted((ROOT / "aesir_engine").rglob("*.mojo"))
    if not (ROOT / "aesir_engine/main.mojo").is_file():
        raise ValueError("Missing aesir_engine/main.mojo; use a complete checkout.")
    value = hashlib.sha256()
    for path in paths:
        value.update(str(path.relative_to(ROOT)).encode() + b"\0")
        value.update(digest(path).encode() + b"\0")
    # Native library search paths can embed the environment's absolute path.
    value.update(str(ROOT).encode())
    return value.hexdigest()


def validate_build():
    try:
        fd = os.open(BUILD / "manifest.json", os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW)
        with os.fdopen(fd, "r", encoding="utf-8") as stream:
            if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode) or os.fstat(stream.fileno()).st_size > 16384:
                raise ValueError("Invalid launch manifest file")
            manifest = json.load(stream)
        if not isinstance(manifest, dict) or manifest.get("schema") != 1:
            raise ValueError("Unsupported launch manifest")
        if manifest.get("source") != source_fingerprint():
            raise ValueError("Build is stale or checkout has moved")
        binary = BUILD / "aesir"
        if manifest.get("binary") != digest(binary):
            raise ValueError("Build executable checksum mismatch")
        if not os.access(binary, os.X_OK):
            raise ValueError("Build executable permission is missing")
        for name in RUNTIME_LIBS:
            if not (ROOT / ".pixi/envs/default/lib" / name).is_file():
                raise ValueError(f"Prepared runtime library missing: {name}")
        return binary
    except (OSError, ValueError) as error:
        raise ValueError(f"Local build unavailable: {error}. {REBUILD}") from error


def build(target):
    pixi = shutil.which("pixi")
    if not pixi:
        candidate = Path.home() / ".pixi/bin/pixi"
        if candidate.is_file() and os.access(candidate, os.X_OK):
            pixi = str(candidate)
    if not pixi:
        raise ValueError("Pixi is missing. Prepare the documented Linux/WSL environment while connected; nothing was installed.")
    if not (ROOT / ".pixi/envs/default/bin/mojo").is_file():
        raise ValueError("Mojo environment is missing. Prepare this checkout's Pixi environment while connected; nothing was installed.")
    BUILD.mkdir(parents=True, exist_ok=True)
    with (BUILD / "build.lock").open("a+b") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        before = source_fingerprint()
        with tempfile.TemporaryDirectory(prefix="staging-", dir=BUILD) as temp:
            binary = Path(temp) / "aesir"
            command = [pixi, "run", "--frozen", "--no-install", "--offline",
                       "--executable", "mojo", "build", "--target-accelerator",
                       target, "aesir_engine/main.mojo", "-o", str(binary)]
            process = subprocess.Popen(command, cwd=ROOT, start_new_session=True)
            try:
                status = process.wait()
            except BaseException:
                # Compiler descendants belong to this isolated build group.
                # Kill/reap before staging cleanup, never a caller's process.
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait()
                raise
            if status:
                raise ValueError(f"Build failed (exit {status}); previous build preserved.")
            if before != source_fingerprint():
                raise ValueError("Source changed during build; previous build preserved. Retry after edits settle.")
            manifest = {"schema": 1, "source": before, "binary": digest(binary), "target": target}
            staged_manifest = Path(temp) / "manifest.json"
            staged_manifest.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
            # A crash between these replacements leaves a mismatched pair that
            # launch refuses. This is a local cache, not a durable model store.
            os.replace(binary, BUILD / "aesir")
            os.replace(staged_manifest, BUILD / "manifest.json")
    print(f"Built and recorded local executable: {BUILD / 'aesir'}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, epilog="Pass app options after --. Relative app paths resolve from this checkout.")
    parser.add_argument("--build", action="store_true", help="compile locally without installing or downloading")
    parser.add_argument("--target", default="sm_89", help="explicit CUDA build target (default: sm_89)")
    parser.add_argument("--check", action="store_true", help="verify freshness and checksum without starting the app")
    parser.add_argument("args", nargs=argparse.REMAINDER)
    options = parser.parse_args()
    args = options.args[1:] if options.args[:1] == ["--"] else options.args
    if options.build and (options.check or args):
        parser.error("--build cannot be combined with --check or app arguments")
    if options.check and args:
        parser.error("--check cannot be combined with app arguments")
    if not options.target.startswith("sm_") or not options.target[3:].isdigit():
        parser.error("--target must be an sm_ CUDA target such as sm_89")
    try:
        if options.build:
            build(options.target)
            return 0
        binary = validate_build()
        if options.check:
            print("Local build fingerprint and executable checksum match; inference is not tested.")
            return 0
        # Replace the launcher so terminal descriptors, signal handling and exit
        # status belong entirely to the existing native application.
        os.chdir(ROOT)
        os.execv(binary, [str(binary), *args])
    except (OSError, ValueError) as error:
        print(f"Aesir launcher: {error}", file=sys.stderr)
        print("If the loader reports missing shared libraries, restore this checkout's prepared Pixi runtime; see docs/LOCAL_LAUNCH.md.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("Build/launch cancelled.", file=sys.stderr)
        sys.exit(130)
