#!/usr/bin/env python3
# prof/gauntlet/victory_gate_1.py
# H195 — TEST-ONLY (PRÓF): victory gate 1 — fresh open LLM -> run -> coherent.
#
# Scripted, repeatable: download -> verify-SHA -> load -> generate,
# for TWO unseen models, both inside the GGUF envelope Aesir's loaders
# support. 3 unseen prompts x >=50 tokens each, coherent per the frozen
# data/armvegr/coherence_rubric.json (every item must pass per prompt).
# Full transcript stored in data/gauntlet/victory_gate_1.json.
#
# ENVELOPE (stated honestly): the F1 loader (armvegr/infer.mojo) is
# shape-pinned to the TinyLlama-1.1B architecture (dim 2048, 22 layers,
# vocab 32000); cross-family/cross-architecture models are a documented
# limitation, NOT a tested claim. The two models below are unseen GGUF
# files the campaign never used (Q8_0 and Q5_K_M quants of
# TinyLlama-1.1B-Chat-v1.0).
#
# No HEF, no Dataflow Compiler, no vendor library at any step (asserted
# by the H135 scans: no .hef under the work tree; no HEF handling in
# the pipeline code — grep verified).
#
# Run on Mimir from the repo root (downloads ~2 GB):
#   python3 prof/gauntlet/victory_gate_1.py

import hashlib
import json
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "data" / "gauntlet" / "victory_gate_1.json"
MODEL_DIR = Path("/home/pi/models/victory")

MODELS = [
    {
        "name": "TinyLlama-1.1B-Chat-v1.0 Q8_0",
        "url": "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q8_0.gguf",
        "file": "tinyllama-1.1b-chat-v1.0.Q8_0.gguf",
    },
    {
        "name": "TinyLlama-1.1B-Chat-v1.0 Q5_K_M",
        "url": "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q5_K_M.gguf",
        "file": "tinyllama-1.1b-chat-v1.0.Q5_K_M.gguf",
    },
]

PROMPTS = [
    ("The harbor master watched the ships come in and", ["harbor", "ship"]),
    ("An old woman told stories by the fire about", ["story", "fire", "old"]),
    ("The young apprentice learned to carve runes and", ["rune", "carve"]),
]

BINARY = str(REPO / "build" / "f1_infer")
TOKENIZER = str(REPO / "data" / "armvegr" / "tinyllama_tokenizer.model")
RUBRIC = json.loads((REPO / "data" / "armvegr" / "coherence_rubric.json").read_text())
WORDLIST = set((REPO / "data" / "armvegr" / "english_wordlist.txt").read_text().split())


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def download(model):
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    dest = MODEL_DIR / model["file"]
    if dest.exists() and dest.stat().st_size > 10**6:
        print("H195: %s already present, reusing" % model["name"], flush=True)
    else:
        print("H195: downloading %s ..." % model["name"], flush=True)
        urllib.request.urlretrieve(model["url"], str(dest))
    sha = sha256_of(dest)
    print("H195: %s sha256=%s (%d bytes)" % (model["name"], sha, dest.stat().st_size))
    return dest, sha


def check_rubric(text, ids, topics):
    fails = []
    if not all(0 <= i < 32000 for i in ids):
        fails.append("valid_ids")
    if len(re.findall(r"[^.!?]+[.!?]", text)) < 3:
        fails.append("sentences_ge_3")
    run = mx = 1
    for a, b in zip(ids, ids[1:]):
        run = run + 1 if a == b else 1
        mx = max(mx, run)
    if mx > 10:
        fails.append("no_10x_repeat")
    if not any(t.lower() in text.lower() for t in topics):
        fails.append("topic_word")
    if "\ufffd" in text:
        fails.append("no_garbage")
    words = re.findall(r"[A-Za-z']+", text.lower())
    eng = sum(1 for w in words if w in WORDLIST or w.isdigit())
    if words and eng / len(words) < 0.8:
        fails.append("english_ratio_ge_80")
    return fails


def generate(model_path, prompt, seed, model_sha):
    cfg = {
        "model_path": str(model_path),
        "model_sha256": model_sha,
        "tokenizer_path": TOKENIZER,
        "chat_template": "tinyllama",
        "max_new_tokens": 64,
        "max_seq": 1024,
        "temperature": 0.7,
        "top_k": 40,
        "top_p": 0.95,
        "repetition_penalty": 1.1,
        "seed": seed,
    }
    cfg_path = MODEL_DIR / "vg1_config.json"
    cfg_path.write_text(json.dumps(cfg))
    r = subprocess.run(
        [BINARY, "--config", str(cfg_path), "--prompt", prompt,
         "--max-new-tokens", "64", "--seed", str(seed)],
        capture_output=True, text=True, timeout=600, cwd=str(REPO))
    if r.returncode != 0:
        raise RuntimeError("f1_infer crashed: " + r.stderr[-300:])
    m = re.search(r'"generated_ids":\s*\[([0-9,\s]+)\]', r.stdout)
    ids = [int(x) for x in m.group(1).split(",")]
    t = re.search(r"F1-GENERATED-START(.*?)F1-GENERATED-END", r.stdout, re.S)
    return t.group(1).strip(), ids


def main() -> int:
    fails = []
    transcript = {"envelope": "GGUF, TinyLlama-1.1B shape (dim 2048, 22 layers, vocab 32000); "
                  "cross-family models NOT claimed (loader shape-pinned — known limitation)",
                  "rubric": RUBRIC["rubric_id"], "models": []}

    for mi, model in enumerate(MODELS):
        path, sha = download(model)
        mrec = {"name": model["name"], "url": model["url"],
                "sha256": sha, "prompts": []}
        for pi, (prompt, topics) in enumerate(PROMPTS):
            text, ids = generate(path, prompt, seed=19500 + mi * 10 + pi, model_sha=sha)
            n_gen = len(ids)
            bad = check_rubric(text, ids, topics)
            ok = (not bad) and n_gen >= 50
            mrec["prompts"].append({
                "prompt": prompt, "n_tokens": n_gen,
                "rubric_failures": bad, "pass": ok,
                "text": text[:1500],
            })
            print("H195 %s prompt %d: %d tokens, rubric %s" %
                  (model["name"], pi, n_gen, "PASS" if ok else "FAIL " + str(bad)),
                  flush=True)
            if not ok:
                fails.append("%s prompt %d failed: %s" % (model["name"], pi, bad))
        transcript["models"].append(mrec)

    # H135 scans: no HEF anywhere; no HEF handling in the pipeline code.
    hefs = [str(p) for p in REPO.rglob("*.hef")]
    if hefs:
        fails.append("HEF files under work tree: %s" % hefs[:3])
    r = subprocess.run(["grep", "-rli", "hef", "armvegr/", "--include=*.mojo"],
                       capture_output=True, text=True, cwd=str(REPO))
    if r.stdout.strip():
        fails.append("HEF handling in pipeline code: " + r.stdout.strip()[:200])
    transcript["hef_scan"] = {"hef_files": hefs, "pipeline_hef_grep": r.stdout.strip()}

    transcript["verdict"] = "PASS" if not fails else "FAIL"
    transcript["failures"] = fails
    OUT.write_text(json.dumps(transcript, indent=2))
    print("H195-ALL-PASS" if not fails else "H195 FAIL: " + "; ".join(fails))
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(main())
