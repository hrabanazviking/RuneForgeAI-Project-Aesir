"""Check the native inspector against independently generated HF token IDs."""
import argparse
import json
import subprocess
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument("--inspector", required=True)
p.add_argument("--model", required=True)
p.add_argument("--fixture", type=Path, default=Path("aesir_engine/tests/fixtures/llama3_tokenizer.json"))
args = p.parse_args()
fixture = json.loads(args.fixture.read_text(encoding="utf-8"))
texts = [case["text"] for case in fixture["cases"]]
r = subprocess.run([args.inspector, args.model, *texts], capture_output=True, text=True, encoding="utf-8", timeout=180, check=True)
lines = r.stdout.splitlines()
if len(lines) != len(texts) + 1:
    raise AssertionError(r.stdout)
for case, line in zip(fixture["cases"], lines):
    actual = json.loads(line)
    if actual != case["ids"]:
        raise AssertionError(f"Mismatch for {case['text']!r}: {actual} != {case['ids']}")
if json.loads(lines[-1]) != fixture["chat_ids"]:
    raise AssertionError("Chat framing differs from Hugging Face")
print(f"PASS: {len(texts)} independent Llama 3 tokenizer cases, UTF-8 round trips, and chat framing")
