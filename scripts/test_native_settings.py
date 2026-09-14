#!/usr/bin/env python3
"""Actual chat/serve settings resolution with isolated fake weights; no inference."""
import argparse
import json
import os
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

        def create(name, recipe, *args):
            (root / "Modelfile").write_text("FROM fake.gguf\n" + recipe, encoding="utf-8")
            run("create", name, "--model", "fake.gguf", "--modelfile", "Modelfile", *args)

        def preview(command, name, *args):
            return json.loads(run(command, name, "--accel", "cuda", "--show-settings", *args))

        create("full", "PARAMETER num_ctx 1024\nPARAMETER num_predict 64\nPARAMETER temperature 0.8\nPARAMETER top_k 12\nPARAMETER top_p 0.7\nPARAMETER min_p 0.1\nPARAMETER repeat_penalty 1.2\nPARAMETER repeat_last_n 128\nPARAMETER seed 18446744073709551615\nSYSTEM Keep SYSTEM literal 雪\n")
        create("empty", 'SYSTEM ""\n')
        create("unsupported", 'PARAMETER stop "end"\n')
        create("template", 'TEMPLATE custom\n')
        create("invalid", 'PARAMETER top_k 0\n')
        create("full", 'PARAMETER num_predict 32\nSYSTEM other store\n', "--model-store", "other/models")
        configs = {
            "empty.json": {},
            "partial.json": {"sampling": {"temperature": 0.3}},
            "zero.json": {"sampling": {"temperature": 0, "top_p": 1}},
            "values.json": {"sampling": {"temperature": 0.4, "top_p": 0.6}},
            "store.json": {"storage": {"model_store_path": "other/models"}, "sampling": {"temperature": 0.3}},
            "backend.json": {"hardware": {"acceleration_backend": "cpu"}},
            "cuda.json": {"hardware": {"acceleration_backend": "cuda"}},
            "hardware.json": {"hardware": {"num_gpu_layers": -1}},
            "safety.json": {"safety": {"thinking_enabled": True}},
            "experimental.json": {"experimental_paradigms": {"cia_enabled": True}},
            "tui.json": {"interface": {"tui_enabled": True}},
            "top-p-zero.json": {"sampling": {"top_p": 0}},
            "overflow.json": {"sampling": {"temperature": 1e100}},
            "underflow.json": {"sampling": {"temperature": 1e-100}},
            "top-p-underflow.json": {"sampling": {"top_p": 1e-100}},
        }
        for name, content in configs.items():
            (root / name).write_text(json.dumps(content), encoding="utf-8")
        (root / "aesir.config.json").write_text("not JSON", encoding="utf-8")
        (root / "duplicate.json").write_text('{"sampling":{"temperature":0,"temperature":1}}', encoding="utf-8")
        (root / "nul.json").write_bytes(b'{}\0ignored')
        (root / "utf8.json").write_bytes(b'{"\xff":{}}')
        (root / "link.json").symlink_to("values.json")
        os.mkfifo(root / "fifo.json")

        def snapshot():
            return {str(p.relative_to(root)): p.read_bytes() for p in root.rglob("*") if p.is_file() and not p.is_symlink()}

        before = snapshot()
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
            base = preview(command, "empty")
            assert preview(command, "empty", "--config", "empty.json") == base
            assert preview(command, "empty", "--config", "cuda.json") == base
            partial = preview(command, "empty", "-c", "partial.json")
            assert abs(partial["sampling"]["temperature"] - 0.3) < 1e-6
            assert partial["sampling"]["top_p"] == base["sampling"]["top_p"]
            zero = preview(command, "empty", "--config", "zero.json")
            assert zero["sampling"]["temperature"] == 0 and zero["sampling"]["top_p"] == 1
            assert preview(command, "full", "--config", "values.json") == chat, "recipe must override config fields"
            assert preview(command, "full", "--config", "values.json", *flags) == changed
            direct = preview(command, "not-present.gguf", "--config", "values.json", "--temperature", "0")
            assert direct["sampling"]["temperature"] == 0 and abs(direct["sampling"]["top_p"] - 0.6) < 1e-6
            other = preview(command, "full", "--config", "store.json")
            assert other["system"] == "other store" and other["max_tokens_request"] == 32
            assert abs(other["sampling"]["temperature"] - 0.3) < 1e-6
            if command == "serve":
                assert preview(command, "full", "--config", "store.json", "--ollama") == other
            for selectors in (
                ("--config", "missing.json", "--model-store", "other/models"),
                ("--model-store", "other/models", "-c", "missing.json"),
            ):
                assert "mutually exclusive" in run(command, "full", "--accel", "cuda", "--show-settings", *selectors, ok=False)
            for selectors in (("--config", "missing.json", "-c", "values.json"), ("-c", "missing.json", "--config", "values.json")):
                assert "duplicate" in run(command, "full", "--accel", "cuda", "--show-settings", *selectors, ok=False).lower()
            failures = {
                "missing.json": "unable to read configuration", "": "configuration path",
                "backend.json": "acceleration_backend", "hardware.json": "num_gpu_layers",
                "safety.json": "safety switches", "experimental.json": "experimental switches",
                "tui.json": "tui_enabled", "top-p-zero.json": "top-p", "overflow.json": "finite",
                "underflow.json": "underflows", "top-p-underflow.json": "top-p",
                "duplicate.json": "duplicate", "nul.json": "NUL", "utf8.json": "UTF-8",
                "link.json": "unable to read configuration", "fifo.json": "regular file",
                "aesir.config.json": "malformed",
            }
            for path, message in failures.items():
                # Invalid config must not be hidden by recipe/CLI overrides.
                options = ("--config", path, "--temperature", "0", "--top-p", "1")
                error = run(command, "full", "--accel", "cuda", "--show-settings", *options, ok=False)
                assert message in error, error
                # Normal execution rejects before key/log/prompts/model access too.
                side_effects = ("--api-key-file", "absent.key") if command == "serve" else ("--log", "absent.log", "--prompts", "absent.prompts")
                error = run(command, "full", "--accel", "cuda", *options, *side_effects, ok=False)
                assert message in error, error
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
        assert "NUL" in run("config", "--config", "nul.json", ok=False)
        after = snapshot()
        assert before == after, "preview or rejection wrote durable data"
    print("PASS native settings: config/recipe/CLI/API-mode previews, presence, zeros/empty system, strict refusal and no writes")


if __name__ == "__main__":
    main()
