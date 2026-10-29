# prof/armvegr/test_tokenizers.py
# H048 — differential tokenizer test suite (TEST-ONLY, PRÓF).
#
# Subprocess-driven: builds tests/c3_h048_tok_cli.mojo, feeds it strings via
# stdin, and asserts the Mojo output ids EXACTLY match tiktoken (BPE) /
# sentencepiece (SP). 1500 encode assertions + 1500 decode round-trips.
# Fails (non-zero exit) on the first mismatch.
#
# Usage: python3 prof/armvegr/test_tokenizers.py
#   (run from the repo root; needs tiktoken and sentencepiece)

import json
import os
import random
import subprocess
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CLI_SRC = os.path.join(REPO, "tests", "c3_h048_tok_cli.mojo")
CLI_BIN = "/tmp/c3_h048_tok_cli"
MOJO = os.path.expanduser("~/.pixi/bin/pixi")
MOJO_MANIFEST = os.path.expanduser("~/mimisbrunnr-x86/mojo_xcompile/pixi.toml")

# Reference strings may not contain \n or \r (the CLI is line-based);
# newline behavior is pinned by the H046/H047 frozen vectors.
SCRIPTS = [
    "The quick brown fox ",
    "hello world ",
    "don't stop ",
    "\u4e2d\u6587\u6d4b\u8bd5 ",
    "\u65e5\u672c\u8a9e ",
    "\u0420\u0443\u0441\u0441\u043a\u0438\u0439 ",
    "\u0627\u0644\u0639\u0631\u0628\u064a\u0629 ",
    "\U0001f600\U0001f680 ",
    "def f(x): return x ",
    "x=1; y=2; ",
    "   ",
    "\t",
    "123 456 ",
    "caf\u00e9 ",
    "\u03b1\u03b2\u03b3 ",
    "a",
    " ",
    "'s 't 're ",
    "UPPER lower MiXeD ",
    "$100 \u20ac50 ",
]


def gen_strings(n, seed):
    rng = random.Random(seed)
    out = []
    # Edge cases first.
    out += ["", " ", "  ", "\t", "a", "hello", "'s", "\u4e2d", "\U0001f600"]
    while len(out) < n:
        k = rng.randint(1, 8)
        s = "".join(rng.choice(SCRIPTS) for _ in range(k))
        if rng.random() < 0.3:
            s += str(rng.randint(0, 999999))
        # No newlines (line-based CLI).
        s = s.replace("\n", " ").replace("\r", " ")
        out.append(s)
    return out[:n]


def build_cli():
    env = dict(os.environ)
    env["TMPDIR"] = os.path.expanduser("~/.tmp")
    r = subprocess.run(
        [MOJO, "run", "--manifest-path", MOJO_MANIFEST, "mojo",
         "build", "-I", REPO, "-o", CLI_BIN, CLI_SRC],
        cwd=REPO, env=env, capture_output=True, text=True, timeout=300,
    )
    if r.returncode != 0 or not os.path.exists(CLI_BIN):
        print("BUILD FAILED")
        print(r.stdout[-3000:])
        print(r.stderr[-3000:])
        sys.exit(2)
    print("CLI built:", CLI_BIN)


def mojo_encode(which, strings):
    """Run the CLI on a batch; returns list of id lists."""
    proc = subprocess.run(
        [CLI_BIN, which],
        input="\n".join(strings) + "\n",
        capture_output=True, text=True, cwd=REPO, timeout=300,
    )
    if proc.returncode != 0:
        print("CLI FAILED for", which)
        print(proc.stdout[-2000:])
        print(proc.stderr[-2000:])
        sys.exit(2)
    lines = proc.stdout.split("\n")
    # Trailing newline yields a final empty element; drop it.
    if lines and lines[-1] == "":
        lines = lines[:-1]
    if len(lines) != len(strings):
        print(f"CLI line count mismatch for {which}: {len(lines)} != {len(strings)}")
        sys.exit(2)
    out = []
    for ln in lines:
        ln = ln.strip()
        out.append([int(x) for x in ln.split(" ")] if ln else [])
    return out


def main():
    import tiktoken
    import sentencepiece as spm

    build_cli()
    enc = tiktoken.get_encoding("gpt2")
    sp = spm.SentencePieceProcessor(
        model_file=os.path.join(REPO, "data", "armvegr", "tinyllama_tokenizer.model"))

    assertions = 0
    # --- BPE differential (750) ---
    bpe_strings = gen_strings(750, 0xB9E)
    bpe_mojo = mojo_encode("bpe", bpe_strings)
    for s, mids in zip(bpe_strings, bpe_mojo):
        want = enc.encode(s)
        assertions += 1
        if mids != want:
            print("BPE MISMATCH:", repr(s[:80]))
            print("  mojo :", mids[:12])
            print("  ref  :", want[:12])
            sys.exit(1)
        # Decode round-trip via reference decoder.
        assertions += 1
        if enc.decode(mids) != s:
            print("BPE ROUNDTRIP MISMATCH:", repr(s[:80]))
            sys.exit(1)
    print(f"BPE: 750/750 exact, 750/750 round-trip")

    # --- SP differential (750) ---
    sp_strings = gen_strings(750, 0x5FE)
    sp_mojo = mojo_encode("sp", sp_strings)
    for s, mids in zip(sp_strings, sp_mojo):
        want = sp.encode(s, out_type=int)
        assertions += 1
        if mids != want:
            print("SP MISMATCH:", repr(s[:80]))
            print("  mojo :", mids[:12])
            print("  ref  :", want[:12])
            sys.exit(1)
        assertions += 1
        if sp.decode(mids) != s:
            print("SP ROUNDTRIP MISMATCH:", repr(s[:80]))
            sys.exit(1)
    print(f"SP: 750/750 exact, 750/750 round-trip")

    print(f"H048-ALL-PASS ({assertions} assertions)")


if __name__ == "__main__":
    main()
