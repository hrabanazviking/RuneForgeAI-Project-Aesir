"""Compare native Gemma 4 token IDs against pinned independent HF oracles."""
import argparse
import json
import subprocess
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--inspector', required=True)
p.add_argument('--model', required=True)
p.add_argument('--fixture', type=Path, default=Path('aesir_engine/tests/fixtures/gemma4_tokenizer.json'))
args = p.parse_args()
fixture = json.loads(args.fixture.read_text(encoding='utf-8'))
for case in fixture['cases']:
    result = subprocess.run([args.inspector, args.model, case['text']], capture_output=True, text=True, encoding='utf-8', check=True, timeout=60)
    actual = json.loads(result.stdout.strip().splitlines()[-1])
    if actual != case['ids']:
        raise AssertionError(f"Token mismatch for {case['text']!r}: {actual} != {case['ids']}")
print(f"PASS: {len(fixture['cases'])} native Gemma 4 tokenizer cases, including whitespace and Unicode")
