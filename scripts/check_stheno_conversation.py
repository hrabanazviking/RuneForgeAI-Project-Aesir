"""Validate unedited native Stheno transcript accounting; coherence needs review."""
import argparse
import csv
import hashlib
import json
import re
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('transcript', type=Path)
p.add_argument('--gpu', type=Path)
args = p.parse_args()
raw = args.transcript.read_bytes()
text = raw.decode('utf-8')
required = ['model=llama3-8B; layers=32/32; cpu_offload=0; context=8192; max_new_tokens=8192; kv=f16; sampling=greedy', 'Completed turns: 20']
if any(item not in text for item in required):
    raise AssertionError('Missing native profile/completion evidence')
pattern = re.compile(r'\n## Turn (\d+)\n\nUser: (.*?)\n\nAssistant: (.*?)\n\n\[turn=(\d+) prompt_tokens=(\d+) generated_tokens=(\d+) context_used=(\d+) max_new_tokens=(\d+) finish=(\w+) backend=cuda cpu_offload=0\]', re.S)
turns = pattern.findall(text)
prompts = Path('aesir_engine/tests/fixtures/stheno_roleplay_20.txt').read_text(encoding='utf-8').splitlines()
if len(turns) != 20 or len(re.findall(r'^## Turn ', text, re.M)) != 20:
    raise AssertionError('Expected exactly twenty complete turns')
previous, total = 0, 0
for i, (number, prompt, reply, repeated, inputs, generated, used, maximum, reason) in enumerate(turns, 1):
    inputs, generated, used = map(int, (inputs, generated, used))
    if number != str(i) or repeated != str(i) or prompt != prompts[i-1]:
        raise AssertionError(f'Turn/prompt mismatch: {i}')
    if not reply.strip() or '<|' in reply or '\ufffd' in reply:
        raise AssertionError(f'Empty or invalid decoded reply: {i}')
    if maximum != '8192' or reason != 'eos' or generated < 1:
        raise AssertionError(f'Turn {i} did not finish naturally with the requested ceiling')
    if used != previous + inputs + generated + 1 or used > 8192:
        raise AssertionError(f'Broken retained-context accounting: {i}')
    previous, total = used, total + generated
result = {'turns': 20, 'natural_eos': 20, 'generated_tokens': total, 'context_used': previous,
          'context_capacity': 8192, 'max_new_tokens': 8192,
          'transcript_sha256': hashlib.sha256(raw).hexdigest(),
          'qualitative_coherence': 'Requires human reading; not inferred from accounting checks.'}
if args.gpu:
    with args.gpu.open(encoding='utf-8') as source:
        rows = list(csv.DictReader(source, skipinitialspace=True))
    if not rows:
        raise AssertionError('No GPU observations')
    def number(row, field):
        return float(row[field].split()[0])
    usage = [number(row, 'utilization.gpu [%]') for row in rows]
    memory = [number(row, 'memory.used [MiB]') for row in rows]
    result['gpu'] = {'samples': len(rows), 'name': rows[0]['name'], 'peak_vram_mib': max(memory),
                     'peak_utilization_percent': max(usage), 'samples_at_100_percent': usage.count(100),
                     'telemetry_sha256': hashlib.sha256(args.gpu.read_bytes()).hexdigest()}
    if max(usage) <= 0 or max(memory) < 5000:
        raise AssertionError('No supporting physical GPU activity observed')
print(json.dumps(result, indent=2))
