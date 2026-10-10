#!/usr/bin/env python3
# prof/gauntlet/test_packaging.py
# H190 — TEST-ONLY (PRÓF): ARM64 release packaging proof.
#
# 1. Runs scripts/package_f1_release.sh -> tarball + MANIFEST.txt.
# 2. Verifies the manifest: no .py/.pyc/.hef/.bin/.fw anywhere.
# 3. Installs the package in a Python-less docker container
#    (debian:bookworm-slim, python3 verified ABSENT) and runs
#    inference on the reference model (mounted read-only).
# 4. On the host: strace -f -e trace=execve during a test run asserts
#    the binary never execs python (the DEVLOG-fixed method for the
#    "absent-or-unused" proof: absent in the container, unused on host).
#
# Run on Mimir from the repo root:
#   python3 prof/gauntlet/test_packaging.py --version <ver>

import argparse
import json
import re
import subprocess
import sys
import tarfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "data" / "gauntlet" / "packaging_proof.json"

FORBIDDEN = (".py", ".pyc", ".hef", ".bin", ".fw")


def sh(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=1200, **kw)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True)
    args = ap.parse_args()
    fails = []
    proof = {"version": args.version}

    # 1. Package.
    pkgdir = REPO / "build" / "pkgtest"
    r = sh(["bash", "scripts/package_f1_release.sh",
            "--version", args.version, "--out", str(pkgdir)], cwd=str(REPO))
    if r.returncode != 0:
        print("H190 FAIL: packaging script failed:\n" + r.stderr[-2000:])
        return 1
    tarball = pkgdir / ("aesir-f1-%s-aarch64.tar.gz" % args.version)
    proof["tarball"] = str(tarball)

    # 2. Manifest scan.
    with tarfile.open(tarball) as tf:
        names = tf.getnames()
    bad = [n for n in names if n.lower().endswith(FORBIDDEN)]
    proof["files"] = len(names)
    proof["forbidden_found"] = bad
    if bad:
        fails.append("forbidden artifacts in package: %s" % bad)
    print("H190: %d files in package, forbidden scan: %s"
          % (len(names), "CLEAN" if not bad else bad))

    # 3. Python-less docker container.
    model = "/home/pi/models/tinyllama/tinyllama-1.1b-chat-v1.0.Q4_0.gguf"
    drepo = "/tmp/c10-pkgtest"
    r = sh(["docker", "run", "--rm",
            "-v", "%s:%s:ro" % (tarball, drepo + "/pkg.tar.gz"),
            "-v", "%s:%s:ro" % (model, model),
            "debian:bookworm-slim", "bash", "-c",
            "set -e; "
            "command -v python3 && { echo PYTHON_PRESENT; exit 9; } || echo PYTHON_ABSENT; "
            "mkdir -p /opt/aesir && tar -xzf /tmp/c10-pkgtest/pkg.tar.gz -C /opt/aesir --strip-components=1; "
            "python3 --version 2>/dev/null && { echo PYTHON_PRESENT2; exit 9; } || true; "
            "cat > /opt/aesir/config/t.json <<'EOF'\n"
            '{"model_path": "%s", "tokenizer_path": "/opt/aesir/share/tokenizer/tinyllama_tokenizer.model", '
            '"chat_template": "tinyllama", "max_new_tokens": 24, "max_seq": 1024, '
            '"temperature": 0.0, "top_k": 1, "top_p": 1.0, "repetition_penalty": 1.0, "seed": 7}\n'
            "EOF\n"
            "/opt/aesir/bin/f1_infer --config /opt/aesir/config/t.json "
            "--prompt 'The old fisherman mended his nets and' --max-new-tokens 24 --seed 7 "
            "| grep -c F1-GENERATED-START" % model])
    dock_out = (r.stdout or "") + (r.stderr or "")
    proof["docker_rc"] = r.returncode
    if "PYTHON_PRESENT" in dock_out:
        fails.append("python3 present in the 'python-less' container")
    if r.returncode != 0 or "1" not in r.stdout.strip().split("\n")[-1:]:
        fails.append("container inference failed (rc=%d): %s"
                     % (r.returncode, dock_out[-500:]))
    else:
        print("H190: container (python3 ABSENT) inference OK")

    # 4. strace execve proof on the host.
    binary = str(REPO / "build" / "f1_infer")
    r = sh(["strace", "-f", "-e", "trace=execve", "-o", "/tmp/c10-strace.log",
            binary, "--config", "data/fallback/f1_config.json",
            "--prompt", "Smoke test.", "--max-new-tokens", "8", "--seed", "1"],
           cwd=str(REPO))
    strace_log = Path("/tmp/c10-strace.log").read_text(errors="replace")
    pythons = [l for l in strace_log.splitlines() if "python" in l.lower()]
    proof["strace_execve_python_hits"] = len(pythons)
    if pythons:
        fails.append("binary exec'd python: %s" % pythons[:3])
    else:
        print("H190: strace execve scan: binary never execs python")

    proof["verdict"] = "PASS" if not fails else "FAIL"
    proof["failures"] = fails
    OUT.write_text(json.dumps(proof, indent=2))
    print("H190-ALL-PASS" if not fails else "H190 FAIL: " + "; ".join(fails))
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(main())
