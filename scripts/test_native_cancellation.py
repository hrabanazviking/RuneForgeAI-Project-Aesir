"""Opt-in real CUDA SIGINT/deadline recovery through the public native CLI."""
import argparse
import os
from pathlib import Path
import selectors
import signal
import subprocess
import time


def check(binary, model, profile, output_dir):
    process = subprocess.Popen([binary, "chat", model, "--accel", "cuda",
        "--profile", profile, "--context", "1024", "--max-tokens", "128"],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=0)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    output = bytearray()

    def send(text):
        process.stdin.write((text + "\n").encode())
        process.stdin.flush()

    def until(marker, offset=0, timeout=120):
        deadline = time.monotonic() + timeout
        encoded = marker.encode()
        while encoded not in output[offset:]:
            assert time.monotonic() < deadline, ("timeout waiting for", marker, output.decode(errors="replace"))
            for key, _ in selector.select(.2):
                chunk = os.read(key.fileobj.fileno(), 4096)
                assert chunk, ("process ended before", marker, process.poll(), output.decode(errors="replace"))
                output.extend(chunk)
        return len(output)

    try:
        until("Enter a message;")
        # Catch pre-main MAX workers that an isolated signalfd unit test misses.
        for task in Path(f"/proc/{process.pid}/task").iterdir():
            status = task.joinpath("status").read_text()
            mask = next(line.split()[1] for line in status.splitlines() if line.startswith("SigBlk:"))
            assert int(mask, 16) & 2, ("runtime thread has SIGINT unblocked", task.name)

        send("Write a detailed sea adventure of at least two hundred words, beginning with a ship leaving port.")
        until("Assistant: ")
        process.send_signal(signal.SIGINT)
        mark = until("finish=cancelled", timeout=30)
        send("What is two plus two? Answer with one word.")
        end = until("finish=eos", mark)
        assert "four" in output[mark:end].decode().lower(), output.decode()
        mark = len(output)
        send("/set timeout-ms 1")
        until("[timeout_ms=1]", mark)
        send("Repeat the word ocean two hundred times.")
        mark = until("CUDA prefill timeout; explicit reset required", mark)
        send("/show")
        end = until("reset_required=True", mark)
        assert "timeout_ms=1" in output[mark:end].decode(), output.decode()
        mark = len(output)
        send("What is two plus two?")
        until("Interrupted prefill requires an explicit conversation reset", mark)
        send("/set timeout-ms 0\n/clear\nWhat is two plus two? Answer with one word.")
        end = until("finish=eos", mark)
        assert "four" in output[mark:end].decode().lower(), output.decode()
        mark = len(output)
        process.send_signal(signal.SIGINT)  # At idle, Ctrl+C cleanly exits.
        until("Completed turns: 3", mark)
        assert process.wait(timeout=20) == 0, output.decode()
        assert output.decode().count("backend=cuda cpu_offload=0]") == 3
        print(f"PASS {profile}: real SIGINT cancellation, next-turn recovery, prefill deadline/reset gate, idle exit")
    finally:
        selector.close()
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        process.stdin.close()
        process.stdout.close()
        if output_dir:
            Path(output_dir).mkdir(parents=True, exist_ok=True)
            (Path(output_dir) / f"{profile}-cancellation.log").write_bytes(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True)
    parser.add_argument("--llama", required=True)
    parser.add_argument("--gemma", required=True)
    parser.add_argument("--output-dir")
    args = parser.parse_args()
    check(args.binary, args.llama, "llama3", args.output_dir)
    check(args.binary, args.gemma, "gemma4", args.output_dir)


if __name__ == "__main__":
    main()
