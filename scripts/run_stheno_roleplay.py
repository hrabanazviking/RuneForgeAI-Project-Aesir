"""Opt-in acceptance harness: native Aesir chat plus concurrent GPU telemetry.

Python only launches processes and preserves evidence. Model download, loading,
tokenization, inference, conversation state and transcript writing belong to Aesir.
"""
import argparse
from pathlib import Path
import subprocess

SYSTEM = (
    "Write an immersive, coherent fantasy roleplay. You embody Captain Sigrun, an adult "
    "lighthouse keeper: brave, dryly witty, burdened by an old mistake, capable of change. "
    "The user controls Eirik, an adult archivist; never invent his choices or dialogue. "
    "Narrate Sigrun, other characters and the world in vivid but restrained prose. "
    "Preserve established names, objects, bargains and consequences across the whole conversation. "
    "Treat revelations as meaningful and let our actions change the situation. "
    "Each reply should be about 90-130 words, at most 160 words, usually two paragraphs. "
    "Stay in character; no assistant disclaimers, summaries of instructions, or out-of-character notes. "
    "This is a complete twenty-exchange chapter; let the requested ending resolve the danger."
)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--binary', required=True)
    p.add_argument('--model', required=True)
    p.add_argument('--output-prefix', type=Path, required=True)
    args = p.parse_args()
    prefix = args.output_prefix
    paths = [Path(str(prefix) + suffix) for suffix in ('.md', '-runtime.log', '-gpu.csv')]
    if any(path.exists() for path in paths):
        raise FileExistsError('Evidence already exists; use a new output prefix')
    with paths[1].open('x', encoding='utf-8') as runtime, paths[2].open('x', encoding='utf-8') as telemetry:
        gpu = subprocess.Popen(['nvidia-smi', '--query-gpu=timestamp,name,memory.used,memory.total,utilization.gpu,power.draw', '--format=csv', '-l', '1'], stdout=telemetry, stderr=subprocess.STDOUT)
        try:
            result = subprocess.run([
                args.binary, 'chat', args.model, '--accel', 'cuda', '--profile', 'llama3',
                '--context', '8192', '--max-tokens', '8192',
                '--prompts', 'aesir_engine/tests/fixtures/stheno_roleplay_20.txt',
                '--system', SYSTEM, '--log', str(paths[0]),
            ], stdout=runtime, stderr=subprocess.STDOUT, timeout=14400)
        finally:
            gpu.terminate()
            gpu.wait(timeout=10)
    if result.returncode:
        raise RuntimeError(f'Native chat failed: exit {result.returncode}; see {paths[1]}')
    print(f'Native roleplay completed: {paths[0]}')


if __name__ == '__main__':
    main()
