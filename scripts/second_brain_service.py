"""Write a location-independent user service; native Mojo owns all inference."""
import argparse
import json
import os
from pathlib import Path
import stat
import subprocess
import sys

import launch


def quoted(value, *, command=False):
    value = str(value)
    if any(ord(char) < 32 for char in value):
        raise ValueError("Service arguments cannot contain control characters")
    value = value.replace("\\", "\\\\").replace("\"", "\\\"").replace("%", "%%")
    if command:
        value = value.replace("$", "$$")
    return "\"" + value + "\""


def load_settings(path):
    settings = json.loads(path.read_text())
    defaults = json.loads(Path(__file__).with_suffix(".json").read_text())
    if not isinstance(settings, dict) or set(settings) != set(defaults):
        raise ValueError("Unexpected service policy fields")
    for field, value in settings.items():
        if field == "memory_max":
            if value != "8G":
                raise ValueError("This deployment policy requires the tested 8G host ceiling")
        elif type(value) is not int or not 1 <= value <= 3600000:
            raise ValueError("Service controls require positive bounded integers")
    return settings


def unit_text(model, key, settings):
    binary = launch.validate_build()
    flags = ["--accel", "cuda", "--api-key-file", str(key.resolve())]
    for field in ("context", "max_tokens", "timeout_ms", "queue_limit", "queue_timeout_ms", "port"):
        flags += ["--" + field.replace("_", "-"), str(settings[field])]
    flags += ["--temperature", "0", "--top-p", "1"]
    # The native resolver rejects unsupported policy/model/recipe fields before
    # allocation. Preview does not certify key contents or successful inference.
    subprocess.run([str(binary), "serve", model, *flags, "--show-settings"],
                   cwd=launch.ROOT, check=True, capture_output=True, timeout=30)
    command = [sys.executable, str(Path(__file__).with_name("launch.py").resolve()),
               "--", "serve", model, *flags]
    directory = str(launch.ROOT)
    if any(ord(char) < 32 for char in directory):
        raise ValueError("Service directory cannot contain control characters")
    # WorkingDirectory is a single path, not ExecStart's quoted argv grammar.
    directory = directory.replace("%", "%%")
    return ("[Unit]\nDescription=Aesir native chat for Bifrost\n"
            "StartLimitIntervalSec=300\nStartLimitBurst=10\n\n[Service]\nType=simple\n"
            "WorkingDirectory=" + directory + "\nExecStart=" + " ".join(quoted(arg, command=True) for arg in command) + "\n"
            "Restart=on-failure\nRestartSec=" + str(settings["restart_seconds"]) + "\n"
            "TimeoutStartSec=" + str(settings["start_timeout_seconds"]) + "\n"
            "TimeoutStopSec=" + str(settings["stop_timeout_seconds"]) + "\n"
            "MemoryMax=" + settings["memory_max"] + "\nTasksMax=" + str(settings["tasks_max"]) + "\n"
            "UMask=0077\nNoNewPrivileges=true\nRestrictSUIDSGID=true\nKillMode=control-group\n\n"
            "[Install]\nWantedBy=default.target\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", required=True)
    parser.add_argument("--api-key-file", required=True, type=Path)
    parser.add_argument("--settings", type=Path, default=Path(__file__).with_suffix(".json"))
    default = Path(os.getenv("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "systemd/user/aesir-brain.service"
    parser.add_argument("--output", type=Path, default=default)
    args = parser.parse_args()
    if args.api_key_file.is_symlink():
        raise ValueError("Service credential cannot be a symlink")
    facts = args.api_key_file.stat()
    if not stat.S_ISREG(facts.st_mode) or facts.st_mode & 0o077 or facts.st_uid != os.geteuid():
        raise ValueError("Service credential must be a current-owner private regular file")
    text = unit_text(args.model, args.api_key_file, load_settings(args.settings))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w") as output:
        output.write(text)
        output.flush()
        os.fsync(output.fileno())
    print("User service written. Run systemctl --user daemon-reload, then systemctl --user enable --now aesir-brain.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print("Aesir service installation failed: " + type(error).__name__ + ". Check policy, private key permissions, model catalog and build freshness; existing files are preserved.", file=sys.stderr)
        sys.exit(1)
