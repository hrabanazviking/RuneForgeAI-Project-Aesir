"""Check recorded completion bounds and factual retention, not general IQ."""
import argparse
import re
from pathlib import Path


def check(text):
    sections = re.split(r'\n## Turn (\d+)\n', text)
    if len(sections) != 41 or 'Completed turns: 20' not in text:
        raise ValueError('Expected exactly 20 complete user/assistant exchanges')
    replies = {}
    previous_context = 0
    generated = 0
    for i in range(1, len(sections), 2):
        number = int(sections[i])
        if number != (i + 1) // 2:
            raise ValueError('Turn numbering is not consecutive')
        body = sections[i + 1]
        if '\nAssistant: ' not in body:
            raise ValueError('Missing assistant response')
        answer = body.split('\nAssistant: ', 1)[1].split('\n\n[turn=', 1)[0].strip()
        match = re.search(r'\[turn=(\d+) prompt_tokens=(\d+) generated_tokens=(\d+) context_used=(\d+) max_new_tokens=(\d+) finish=(\w+) backend=cuda cpu_offload=0\]', body)
        if not answer or not match:
            raise ValueError(f'Turn {number}: missing response or execution metadata')
        turn, prompt, output, context, limit = map(int, match.groups()[:5])
        if turn != number or prompt < 1 or output < 1 or limit != 16384 or output > limit or match[6] != 'eos':
            raise ValueError(f'Turn {number}: generation contract failed')
        if context != previous_context + prompt + output + 1:
            raise ValueError(f'Turn {number}: persistent context accounting failed')
        previous_context = context
        generated += output
        replies[number] = answer.lower()
    facts = {
        7: ['90', '75', '50', '25', '240'],
        8: ['rowan shelf', 'alderwick', 'hall', 'october 19'],
        10: ['110', '260'],
        11: ['mira', 'jon'],
        13: ['125', '135'],
        16: ['rowan shelf', 'hall', 'october 19'],
        18: ['110', '75', '50', '25', '260'],
        19: ['leif', 'alderwick'],
        20: ['rowan shelf', 'alderwick', 'hall', 'october 19', 'mira', 'jon', 'leif', 'labels', 'notices', '110', '75', '50', '25', '260'],
    }
    for turn, required in facts.items():
        missing = [fact for fact in required if fact not in replies[turn]]
        if missing:
            raise ValueError(f'Turn {turn}: missing expected retained facts {missing}')
    if previous_context <= 512:
        raise ValueError('Conversation did not exercise sliding-window rollover')
    print(f'PASS: 20 coherent exchanges; generated={generated}; context={previous_context}; all completion limits=16384; EOS=20; retained-fact checks passed')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('transcript', type=Path)
    check(parser.parse_args().transcript.read_text(encoding='utf-8'))
