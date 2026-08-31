"""Opt-in real-model CUDA sampling/reset and interactive recovery regression."""
import argparse
from pathlib import Path
import re
import subprocess
import tempfile


def check(binary, model, profile, output):
    creative = "Invent one short title for a moonlit sea voyage."
    arithmetic = "What is two plus two? Answer with one word."
    commands = ["/show", "word " * 600, creative, "/clear", creative,
                "/set top-k 0", "/set repeat-last-n 8", "/set temperature 0",
                "/set repeat-penalty 1", "/clear", arithmetic, "/show",
                "/clear", arithmetic, "/bye"]
    with tempfile.TemporaryDirectory(prefix="aesir-chat-controls-") as tmp:
        log = Path(tmp) / "conversation.md"
        result = subprocess.run([binary, "chat", model, "--profile", profile,
            "--accel", "cuda", "--device", "0", "--context", "512",
            "--max-tokens", "64", "--temperature", "0.8", "--top-k", "40",
            "--top-p", "0.9", "--repeat-penalty", "1.1", "--repeat-last-n", "7",
            "--seed", "42", "--log", str(log)],
            input="\n".join(commands) + "\n", text=True, capture_output=True, timeout=600)
        if output:
            Path(output).mkdir(parents=True, exist_ok=True)
            (Path(output) / f"{profile}-controls.log").write_text(result.stdout + result.stderr, encoding="utf-8")
        assert result.returncode == 0, result.stdout + result.stderr
        transcript = log.read_text(encoding="utf-8")
        emitted = result.stdout.replace("Enter a message; /help lists chat controls. Blank input/EOF ends the session.\n", "")
        assert transcript in emitted, "Durable transcript differs from emitted transcript"
        replies = re.findall(r"Assistant: (.*?)\n\n\[turn=", transcript, re.S)
        assert len(replies) == 4 and all(text.strip() for text in replies), replies
        assert replies[0] == replies[1], ("Seed/KV/history reset failed", replies[:2])
        assert replies[2] == replies[3], ("Greedy reset failed", replies[2:])
        assert "four" in replies[2].lower() or "4" in replies[2], replies[2]
        assert transcript.count("[control rejected:") == 2, transcript
        assert transcript.count("[turn rejected:") == 1, transcript
        assert "context_used=0; context_limit=512" in transcript
        assert "sampling=greedy; temperature=0.0" in transcript
        assert "Completed turns: 4" in transcript
        assert transcript.count("backend=cuda cpu_offload=0]") == 4
        # Existing log protection must fail without modifying the transcript.
        retry = subprocess.run([binary, "chat", model, "--accel", "cuda",
            "--profile", profile, "--context", "512", "--max-tokens", "64",
            "--log", str(log)], input="/bye\n", text=True, capture_output=True, timeout=60)
        assert retry.returncode != 0 and "Cannot create transcript" in retry.stdout + retry.stderr
        assert log.read_text(encoding="utf-8") == transcript
    print(f"PASS: {profile} physical CUDA sampled and greedy replay; invalid controls/prompt recovery; durable exclusive log")


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
