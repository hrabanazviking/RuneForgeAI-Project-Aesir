"""Opt-in physical CUDA proof for same-PID process-image model switching."""

import argparse
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True)
    parser.add_argument("--gemma", default="gemma")
    parser.add_argument("--qwen", required=True)
    parser.add_argument("--model-store", default=".aesir/models")
    parser.add_argument("--output")
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="aesir-model-switch-") as tmp:
        log = Path(tmp) / "switch.md"
        commands = (
            "/set temperature 0.7\n"
            "/set timeout-ms 1234\n"
            "/model gemma\n"
            "/model missing-hot-switch.gguf\n"
            f"/model {args.qwen}\n/model {args.gemma}\n/bye\n"
        )
        result = subprocess.run(
            [
                args.binary,
                "chat",
                args.gemma,
                "--accel",
                "cuda",
                "--context",
                "512",
                "--max-tokens",
                "16",
                "--model-store",
                args.model_store,
                "--log",
                str(log),
            ],
            input=commands,
            text=True,
            capture_output=True,
            timeout=600,
        )
        evidence = result.stdout + result.stderr
        if args.output:
            Path(args.output).write_text(evidence, encoding="utf-8")
        assert result.returncode == 0, evidence
        transcript = log.read_text(encoding="utf-8")
        assert transcript.count("# Aesir native CUDA conversation") == 3, transcript
        assert transcript.count("[model switch requested:") == 2, transcript
        assert transcript.count("[previous model unloaded; switching to") == 2, transcript
        assert transcript.count("[control rejected:") == 2, transcript
        assert "already loaded" in transcript, transcript
        assert "Failed to open GGUF" in transcript, transcript
        assert "model=gemma4-E2B" in transcript, transcript
        assert "model=qwen3-0.6B" in transcript, transcript
        assert transcript.count("sampling=cuda; temperature=0.7") >= 3, transcript
        assert transcript.count("timeout_ms=1234") >= 3, transcript
        assert transcript.count("Completed turns: 0") == 3, transcript
    print("PASS: physical Gemma -> Qwen -> Gemma CUDA hot switching without process exit")


if __name__ == "__main__":
    main()
