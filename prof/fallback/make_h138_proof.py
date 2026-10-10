#!/usr/bin/env python3
# prof/fallback/make_h138_proof.py
# H138 — assemble data/fallback/f1_coherent_proof.json (PRÓF, TEST-ONLY).
#
# Reads the three f1_infer --out JSONs (production binary + production
# config, run on Mimir), scores each against the frozen rubric via
# check_coherence, and writes the proof artifact with everything a third
# party needs to reproduce: outputs, model SHA-256, sampler settings,
# binary version, and the exact command lines.
#
# Usage: make_h138_proof.py <run1.json> <run2.json> <run3.json>
#        --cmd1 "..." --cmd2 "..." --cmd3 "..."
#        --git-sha <sha> --mojo-version "..." [--out PATH]

import hashlib
import json
import sys

sys.path.insert(0, "prof/fallback")
from check_coherence import check_prompt, load_wordlist


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


TOPIC_WORDS = [
    ["hospitality", "guest", "guests", "welcome", "welcoming", "host",
     "stranger", "strangers", "kindness", "shelter"],
    ["gods", "odin", "thor", "freyja", "freyr", "asgard", "vanaheim",
     "norse", "saga", "sagas", "aesir", "vanir", "loki"],
    ["mead", "honey", "brew", "brewing", "ferment", "fermentation",
     "yeast", "water", "drink"],
]


def main():
    runs = sys.argv[1:4]
    assert len(runs) == 3, "need 3 run JSONs"
    args = sys.argv[4:]
    def opt(name, default=""):
        for i in range(len(args) - 1):
            if args[i] == name:
                return args[i + 1]
        return default
    cmds = [opt("--cmd1"), opt("--cmd2"), opt("--cmd3")]
    git_sha = opt("--git-sha")
    mojo_version = opt("--mojo-version")
    out_p = opt("--out", "data/fallback/f1_coherent_proof.json")

    rubric_p = "data/armvegr/coherence_rubric.json"
    wordlist_p = "data/armvegr/english_wordlist.txt"
    rubric = json.load(open(rubric_p, encoding="utf-8"))
    assert rubric["rubric_id"] == "f1-coherence-v1"
    words = load_wordlist(wordlist_p)

    prompts = []
    all_ok = True
    for i, rp in enumerate(runs):
        run = json.load(open(rp, encoding="utf-8"))
        p = {
            "prompt": run["prompt_text"],
            "topic_words": TOPIC_WORDS[i],
            "generated_text": run["generated_text"],
            "generated_ids": run["generated_ids"][run["prompt_tokens"]:],
            "command_line": cmds[i],
        }
        res = check_prompt(p, words, rubric.get("vocab_size", 32000))
        items = [it["id"] for it in rubric["items"]]
        detail = {k: v for k, v in res.items() if not k.startswith("_")}
        p["tokens_generated"] = len(p["generated_ids"])
        p["rubric"] = {it: bool(detail[it]) for it in items}
        p["rubric_detail"] = {
            "sentences": res["_sentences"],
            "max_consecutive_repeat": res["_maxrun"],
            "english_ratio": res["_english_detail"],
        }
        p["pass"] = all(p["rubric"].values())
        all_ok = all_ok and p["pass"]
        p["sampler"] = run["sampler"]
        p["prefill_seconds"] = run["prefill_seconds"]
        p["decode_seconds"] = run["decode_seconds"]
        p["decode_tokens_per_sec"] = run["decode_tokens_per_sec"]
        prompts.append(p)
        print(f"prompt {i + 1}: {'PASS' if p['pass'] else 'FAIL'} "
              f"({p['tokens_generated']} tokens)")

    first = json.load(open(runs[0], encoding="utf-8"))
    proof = {
        "slice": "H138",
        "statement": ("Coherent text from the small open LLM "
                      "(TinyLlama-1.1B-Chat-v1.0 Q4_0) on the production CPU "
                      "pipeline (f1_infer + data/fallback/f1_config.json)."),
        "rubric": rubric_p,
        "rubric_id": rubric["rubric_id"],
        "rubric_sha256": sha256_file(rubric_p),
        "wordlist": wordlist_p,
        "wordlist_sha256": sha256_file(wordlist_p),
        "model": "TinyLlama-1.1B-Chat-v1.0 Q4_0 GGUF (TheBloke)",
        "model_source": ("https://huggingface.co/TheBloke/"
                         "TinyLlama-1.1B-Chat-v1.0-GGUF :: "
                         "tinyllama-1.1b-chat-v1.0.Q4_0.gguf"),
        # Measured on Mimir via sha256sum (2026-10-10); matches the C3/H059
        # record (da3087fb...) and the HuggingFace authoritative file.
        "model_sha256": "da3087fb14aede55fde6eb81a0e55e886810e43509ec82ecdc7aa5d62a03b556",
        "model_path_on_mimir": "/home/pi/models/tinyllama/tinyllama-1.1b-chat-v1.0.Q4_0.gguf",
        "binary": "armvegr/f1_infer",
        "infer_version": first["infer_version"],
        "mojo_version": mojo_version,
        "git_sha_built_from": git_sha,
        "device": "Mimir (Raspberry Pi 5, aarch64)",
        "config": "data/fallback/f1_config.json",
        "production_sampler": first["sampler"],
        "min_tokens_required": 50,
        "all_prompts_pass": all_ok,
        "prompts": prompts,
    }
    with open(out_p, "w", encoding="utf-8") as f:
        json.dump(proof, f, indent=2, ensure_ascii=False)
    print("wrote " + out_p)
    print("H138-PROOF-" + ("PASS" if all_ok else "FAIL"))
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
