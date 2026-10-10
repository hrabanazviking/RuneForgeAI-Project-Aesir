#!/usr/bin/env python3
# prof/fallback/check_coherence.py
# H138 — coherence rubric checker (PRÓF, TEST-ONLY).
#
# Evaluates generated text against the frozen rubric
# data/armvegr/coherence_rubric.json (f1-coherence-v1). Every item is
# binary PASS/FAIL per prompt. Deterministic; no ML, no network.
#
# Input JSON: {"prompts": [{"prompt": str, "topic_words": [str],
#                           "generated_text": str, "generated_ids": [int]}]}
# Usage: check_coherence.py <input.json> [--rubric PATH] [--wordlist PATH]
# Exit 0 iff every item passes for every prompt.

import json
import re
import sys

REPLACEMENT = "\ufffd"
TERMINAL = re.compile(r"[.!?]")


def load_wordlist(path):
    words = set()
    with open(path, encoding="utf-8") as f:
        for line in f:
            w = line.strip().lower()
            if w:
                words.add(w)
    return words


def clean_token(tok):
    t = tok.strip().lower()
    # strip surrounding punctuation
    t = t.strip(".,!?;:\"'()[]{}<>-—–…«»„“”‘’/\\|@#$%^&*+=~`")
    t = t.replace("'", "").replace("’", "")
    return t


def check_prompt(p, words, vocab_size=32000):
    text = p["generated_text"]
    ids = p["generated_ids"]
    topic_words = [w.lower() for w in p["topic_words"]]
    res = {}

    # 1. valid_ids
    res["valid_ids"] = all(isinstance(i, int) and 0 <= i < vocab_size for i in ids)

    # 2. sentences_ge_3
    parts = TERMINAL.split(text)
    n_sent = sum(1 for s in parts if re.search(r"[A-Za-z0-9]", s))
    res["sentences_ge_3"] = n_sent >= 3

    # 3. no_10x_repeat
    maxrun, run = 1, 1
    for i in range(1, len(ids)):
        if ids[i] == ids[i - 1]:
            run += 1
            maxrun = max(maxrun, run)
        else:
            run = 1
    res["no_10x_repeat"] = maxrun <= 10

    # 4. topic_word
    low = text.lower()
    res["topic_word"] = any(w in low for w in topic_words)

    # 5. no_garbage
    res["no_garbage"] = REPLACEMENT not in text

    # 6. english_ratio_ge_80
    toks = text.split()
    good, total = 0, 0
    for t in toks:
        c = clean_token(t)
        if not c:
            continue
        total += 1
        if c.replace(".", "", 1).isdigit() or c in words:
            good += 1
    res["english_ratio_ge_80"] = (total > 0 and good / total >= 0.8)
    res["_english_detail"] = f"{good}/{total}"
    res["_sentences"] = n_sent
    res["_maxrun"] = maxrun
    return res


def main():
    if len(sys.argv) < 2:
        print("usage: check_coherence.py <input.json> [--rubric P] [--wordlist P]")
        return 2
    inp = sys.argv[1]
    rubric_p = "data/armvegr/coherence_rubric.json"
    wordlist_p = "data/armvegr/english_wordlist.txt"
    args = sys.argv[2:]
    for i in range(0, len(args) - 1, 2):
        if args[i] == "--rubric":
            rubric_p = args[i + 1]
        elif args[i] == "--wordlist":
            wordlist_p = args[i + 1]
    rubric = json.load(open(rubric_p, encoding="utf-8"))
    assert rubric["rubric_id"] == "f1-coherence-v1", "rubric id mismatch"
    words = load_wordlist(wordlist_p)
    data = json.load(open(inp, encoding="utf-8"))
    items = [it["id"] for it in rubric["items"]]
    all_ok = True
    for pi, p in enumerate(data["prompts"]):
        res = check_prompt(p, words, rubric.get("vocab_size", 32000))
        detail = {k: v for k, v in res.items() if not k.startswith("_")}
        ok = all(detail[it] for it in items)
        all_ok = all_ok and ok
        status = "PASS" if ok else "FAIL"
        print(f"prompt {pi + 1} [{p['prompt'][:40]}...]: {status}")
        for it in items:
            print(f"    {it}: {'PASS' if detail[it] else 'FAIL'}")
        print(f"    (sentences={res['_sentences']}, maxrun={res['_maxrun']}, "
              f"english={res['_english_detail']})")
    print("COHERENCE-ALL-PASS" if all_ok else "COHERENCE-FAIL")
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
