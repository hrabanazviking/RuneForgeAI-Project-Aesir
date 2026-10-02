#!/usr/bin/env python3
"""Optional owned 3B native CLI capture; never profiles an unrelated service."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import signal
import stat
import subprocess
import time

from check_cuda_trace import analyze
from launch import ROOT, digest, validate_build


def read_text(path, maximum):
    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW)
    with os.fdopen(fd, "r", encoding="utf-8") as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_size > maximum:
            raise ValueError("Expected bounded regular UTF-8 input")
        return stream.read(maximum + 1)


def completion(text, maximum):
    header = "backend=cuda; model=llama-3B; layers=28/28; cpu_offload=0; context=4096; "
    if header not in text or "Completed turns: 1" not in text:
        raise ValueError("Incomplete or different native execution")
    matches = list(re.finditer(r"\[turn=1 prompt_tokens=(\d+) generated_tokens=(\d+) context_used=(\d+) max_new_tokens=(\d+) finish=(length|eos) backend=cuda cpu_offload=0\]", text))
    if len(matches) != 1 or text.count("Assistant: ") != 1 or text.count("## Turn ") != 1:
        raise ValueError("Ambiguous native transcript")
    match = matches[0]
    prompt, generated, used, limit = map(int, match.groups()[:4])
    if limit != maximum or not 0 < prompt <= 4096 or not 0 < generated <= limit or not prompt + generated <= used <= 4096:
        raise ValueError("Native completion counts violated admission")
    if match[5] == "length" and generated != limit:
        raise ValueError("Incomplete length-controlled completion")
    return {"prompt_tokens": prompt, "generated_tokens": generated,
            "context_used": used, "finish": match[5],
            "answer": text.split("Assistant: ", 1)[1][:match.start() - text.index("Assistant: ") - len("Assistant: ")].rstrip()}


def run(command, log, timeout, env):
    start = time.monotonic()
    with log.open("x", encoding="utf-8") as stream:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stream,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            status = process.wait(timeout=timeout)
        except BaseException:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
            raise
    return {"exit": status, "wall_seconds": time.monotonic() - start}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--prompt", type=Path, required=True, help="one public UTF-8 prompt; no private corpus")
    p.add_argument("--weights-sha256", required=True)
    p.add_argument("--output-dir", type=Path, required=True, help="new private artifact directory outside Git")
    p.add_argument("--max-tokens", type=int, choices=(32, 128, 256), default=32)
    p.add_argument("--timeout", type=int, default=180)
    p.add_argument("--nsys", default="nsys")
    p.add_argument("--importer", type=Path, help="explicit matching QdstrmImporter for split Linux packages")
    a = p.parse_args()
    if not 10 <= a.timeout <= 300 or not re.fullmatch(r"[0-9a-f]{64}", a.weights_sha256):
        p.error("timeout must be 10..300; model digest must be lowercase SHA-256")
    directory = a.output_dir.absolute()
    directory.mkdir(mode=0o700)  # Exclusive reservation before GPU operations.
    report = {"schema": 1, "passed": False, "profiling_is_speed_score": False}
    env = {key: os.environ[key] for key in ("PATH", "HOME", "LD_LIBRARY_PATH", "LANG",
           "XDG_CACHE_HOME", "CUDA_VISIBLE_DEVICES", "TMPDIR") if key in os.environ}
    try:
        prompt = read_text(a.prompt, 65536).strip()
        if not prompt or "\n" in prompt or "\r" in prompt or "\x00" in prompt:
            raise ValueError("Provide one nonempty single-line public prompt")
        binary = validate_build()
        blob = ROOT / ".aesir/models/blobs/sha256" / a.weights_sha256
        if digest(blob) != a.weights_sha256:
            raise ValueError("Model blob checksum mismatch")
        catalog = read_text(ROOT / ".aesir/models/catalog.v1", 1024 * 1024)
        entries = [bytes.fromhex(line[6:]).decode("utf-8") for line in catalog.splitlines() if line.startswith("ENTRY:")]
        expected = ("NAME:llama3.2", "TAG:3b", "DIGEST:sha256:" + a.weights_sha256,
                    "SIZE:" + str(blob.stat().st_size))
        if len([entry for entry in entries if all(v in entry.splitlines() for v in expected)]) != 1:
            raise ValueError("Registered 3B catalog does not match supplied blob")
        gpu = subprocess.run(["nvidia-smi", "--query-gpu=memory.free", "--format=csv,noheader,nounits"],
                             capture_output=True, text=True, timeout=10, check=True, env=env)
        free = int(gpu.stdout.strip()) * 1024 * 1024
        # Exercised strict 3B: weights, full F16 KV, staging and bounded headroom.
        required = blob.stat().st_size + 4096 * 114688 + 512 * 1024 * 1024
        report.update(binary_sha256=digest(binary), model_sha256=a.weights_sha256,
                      observed_free_vram_bytes=free, required_free_vram_bytes=required)
        if free < required:
            raise ValueError("Insufficient observed VRAM for owned process; services were not stopped")
        nsys = shutil.which(a.nsys)
        if not nsys:
            raise ValueError("Optional Nsight Systems is not installed")
        version = subprocess.run([nsys, "--version"], check=True, capture_output=True,
                                 text=True, timeout=10, env=env).stdout.strip()
        if "2023.4.4.54" not in version:
            raise ValueError("Capture flags validated only for Nsight 2023.4.4.54")
        report["nsight_version"] = version
        prompt_path = directory / "prompt.txt"
        prompt_path.write_text(prompt + "\n", encoding="utf-8")
        command = [str(binary), "chat", "llama3.2:3b", "--accel", "cuda", "--context", "4096",
                   "--max-tokens", str(a.max_tokens), "--temperature", "0", "--repeat-penalty", "1",
                   "--system", "You are concise.", "--prompts", str(prompt_path)]
        baseline_log = directory / "unprofiled.txt"
        report["unprofiled"] = run(command, baseline_log, a.timeout, env)
        if report["unprofiled"]["exit"] != 0:
            raise ValueError("Unprofiled native process failed")
        baseline = completion(read_text(baseline_log, 1024 * 1024), a.max_tokens)
        base = directory / "capture"
        profile_log = directory / "profiled.txt"
        report["profiled"] = run([nsys, "profile", "--trace=cuda", "--sample=none", "--cpuctxsw=none",
                                 "--force-overwrite=false", "--stats=false", "--output=" + str(base)] + command,
                                profile_log, a.timeout, env)
        if report["profiled"]["exit"] != 0:
            raise ValueError("Profiler/native process failed")
        profiled = completion(read_text(profile_log, 1024 * 1024), a.max_tokens)
        if baseline != profiled:
            raise ValueError("Profiling changed complete reply or counts")
        report["completion"] = baseline
        native_report = base.with_suffix(".nsys-rep")
        if not native_report.exists():
            importer = a.importer
            if importer is None:
                candidate = Path("/usr/lib/nsight-systems/host-linux-x64/QdstrmImporter")
                if candidate.is_file():
                    importer = candidate
            if importer is None or not base.with_suffix(".qdstrm").is_file():
                raise ValueError("No usable report; provide matching installed importer")
            iv = subprocess.run([str(importer), "--version"], check=True, capture_output=True,
                                text=True, timeout=10, env=env).stdout.strip()
            if "2023.4.4.54" not in iv:
                raise ValueError("Importer version mismatch")
            report["importer"] = {"version": iv, "sha256": digest(importer), "explicit_fallback": True}
            imported = run([str(importer), "--input-file", str(base.with_suffix(".qdstrm")),
                            "--output-file", str(native_report)], directory / "import.txt", a.timeout, env)
            if imported["exit"] != 0:
                raise ValueError("Raw capture import failed")
        database = base.with_suffix(".sqlite")
        exported = run([nsys, "export", "--type=sqlite", "--force-overwrite=false", "--output", str(database),
                        str(native_report)], directory / "export.txt", a.timeout, env)
        if exported["exit"] != 0:
            raise ValueError("Trace export failed")
        report["trace"] = analyze(database)
        report["artifacts"] = {f.name: {"bytes": f.stat().st_size, "sha256": digest(f)}
                               for f in directory.iterdir() if f.is_file()}
        report["wall_time_ratio_profiled_over_unprofiled"] = report["profiled"]["wall_seconds"] / report["unprofiled"]["wall_seconds"]
        report["passed"] = True
    except (Exception, KeyboardInterrupt) as error:
        report["error"] = f"{type(error).__name__}: {error}"
        report["interrupted"] = isinstance(error, KeyboardInterrupt)
    finally:
        with (directory / "report.json").open("x", encoding="utf-8") as stream:
            json.dump(report, stream, indent=2); stream.write("\n")
    print("PASS: owned CUDA trace" if report["passed"] else "FAIL: " + report["error"])
    return 0 if report["passed"] else (130 if report.get("interrupted") else 1)


if __name__ == "__main__":
    raise SystemExit(main())
