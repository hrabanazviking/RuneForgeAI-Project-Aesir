#!/usr/bin/env python3
"""Actual chat/serve settings resolution with isolated fake weights; no inference."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True, type=Path)
    binary = str(parser.parse_args().binary.resolve())
    with tempfile.TemporaryDirectory(prefix="aesir effective settings ") as temp:
        root = Path(temp)
        (root / "fake.gguf").write_bytes(b"intentionally not a GGUF")

        def run(*args, ok=True):
            result = subprocess.run([binary, *args], cwd=root, capture_output=True, text=True, timeout=30)
            assert (result.returncode == 0) == ok, result.stdout + result.stderr
            return result.stdout if ok else result.stdout + result.stderr

        def create(name, recipe):
            (root / "Modelfile").write_text("FROM fake.gguf\n" + recipe, encoding="utf-8")
            run("create", name, "--model", "fake.gguf", "--modelfile", "Modelfile")

        def preview(command, name, *args):
            return json.loads(run(command, name, "--accel", "cuda", "--show-settings", *args))

        create("full", "PARAMETER num_ctx 1024\nPARAMETER num_predict 64\nPARAMETER temperature 0.8\nPARAMETER top_k 12\nPARAMETER top_p 0.7\nPARAMETER min_p 0.1\nPARAMETER repeat_penalty 1.2\nPARAMETER repeat_last_n 128\nPARAMETER seed 18446744073709551615\nSYSTEM Keep SYSTEM literal 雪\n")
        create("empty", 'SYSTEM ""\n')
        create("unsupported", 'PARAMETER stop "end"\n')
        create("template", 'TEMPLATE custom\n')
        create("invalid", 'PARAMETER top_k 0\n')
        before = {str(p.relative_to(root)): p.read_bytes() for p in root.rglob("*") if p.is_file()}
        chat = preview("chat", "full")
        serve = preview("serve", "full")
        assert chat == serve
        assert chat["stage"] == "before_hardware_planning"
        assert chat["context_request"] == 1024 and chat["max_tokens_request"] == 64
        assert chat["system"] == "Keep SYSTEM literal 雪" and chat["system_override"] is True
        assert chat["sampling"]["seed"] == 18446744073709551615
        assert chat["sampling"]["top_k"] == 12 and abs(chat["sampling"]["temperature"] - 0.8) < 1e-6
        flags = ("--temperature", "0", "--seed", "0", "--system", "", "--context", "2048", "--max-tokens", "128")
        changed = preview("chat", "full", *flags)
        assert changed == preview("serve", "full", *flags)
        assert changed["sampling"]["temperature"] == 0 and changed["sampling"]["seed"] == 0
        assert changed["sampling"]["top_k"] == 12 and changed["system"] == ""
        assert changed["context_request"] == 2048 and changed["max_tokens_request"] == 128
        # No key, transcript or prompts file is opened by settings preview.
        assert preview("serve", "full", "--api-key-file", "absent.key") == serve
        assert preview("chat", "full", "--log", "absent.log", "--prompts", "absent.prompts") == chat
        for command in ("chat", "serve"):
            assert preview(command, "empty")["system"] == ""
            assert preview(command, "empty")["system_override"] is True
            for name, message in (("unsupported", "Unsupported native recipe parameter"), ("template", "Unsupported native recipe directive"), ("invalid", "top-k")):
                assert message in run(command, name, "--accel", "cuda", "--show-settings", "--top-k", "20", ok=False)
                normal_flags = ("--ollama",) if command == "serve" else ()
                assert message in run(command, name, "--accel", "cuda", *normal_flags, ok=False)
            assert "Effective context" in run(command, "full", "--accel", "cuda", "--show-settings", "--context", "32", ok=False)
        assert "explicit model" in run("chat", "--accel", "cuda", "--show-settings", ok=False)
        # Direct-path preview has no stored recipe and proves neither bytes nor fit.
        assert preview("chat", "not-present.gguf")["context_request"] == 0
        after = {str(p.relative_to(root)): p.read_bytes() for p in root.rglob("*") if p.is_file()}
        assert before == after, "preview or rejection wrote durable data"
    print("PASS native settings: recipe/CLI/API-mode previews, zeros/empty system, strict refusal and no writes")


if __name__ == "__main__":
    main()
