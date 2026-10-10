# TEST-ONLY (PRÓF): tokenizer data generator for H046/H047/H048.
# Deterministic (seeded). Run once; outputs are frozen:
#   data/armvegr/gpt2_bpe.bin        - GPT-2 vocab (id order) + merge ranks, binary
#   data/armvegr/unicode_classes.bin - L/N/whitespace code-point ranges, binary
#   data/armvegr/tokenizer_vectors.json - frozen reference vectors (tiktoken + sentencepiece)
# Usage: python3 make_tokenizer_data.py <tokdata_dir> <outdir>
import struct, os, sys, json, random, unicodedata

def build_gpt2_bpe(tokdir, outdir):
    vocab = json.load(open(os.path.join(tokdir, "vocab.json"), encoding="utf-8"))
    id2tok = [None] * len(vocab)
    for tok, idx in vocab.items():
        id2tok[idx] = tok
    assert all(t is not None for t in id2tok), "vocab ids not contiguous"
    merges = []
    with open(os.path.join(tokdir, "merges.txt"), encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line or line.startswith("#version"):
                continue
            a, b = line.split(" ", 1)
            merges.append((vocab[a], vocab[b]))
    buf = bytearray()
    buf += struct.pack("<I", len(id2tok))
    for tok in id2tok:
        eb = tok.encode("utf-8")
        buf += struct.pack("<H", len(eb)) + eb
    buf += struct.pack("<I", len(merges))
    for a, b in merges:
        buf += struct.pack("<II", a, b)
    p = os.path.join(outdir, "gpt2_bpe.bin")
    open(p, "wb").write(bytes(buf))
    print("wrote", p, len(buf), "bytes; vocab", len(id2tok), "merges", len(merges))

def _ranges(cps):
    cps = sorted(cps)
    ranges = []
    s = p = cps[0]
    for c in cps[1:]:
        if c == p + 1:
            p = c
        else:
            ranges.append((s, p)); s = p = c
    ranges.append((s, p))
    return ranges

def build_unicode_classes(outdir):
    import regex
    L = [cp for cp in range(0x110000) if unicodedata.category(chr(cp)).startswith("L")]
    N = [cp for cp in range(0x110000) if unicodedata.category(chr(cp)).startswith("N")]
    W = [cp for cp in range(0x110000) if regex.match(r"\s", chr(cp))]
    buf = bytearray()
    for cls in (L, N, W):
        r = _ranges(cls)
        buf += struct.pack("<I", len(r))
        for s, e in r:
            buf += struct.pack("<II", s, e)
    p = os.path.join(outdir, "unicode_classes.bin")
    open(p, "wb").write(bytes(buf))
    print("wrote", p, len(buf), "bytes; L ranges", len(_ranges(L)),
          "N ranges", len(_ranges(N)), "W ranges", len(_ranges(W)))

def build_vectors(tokdir, outdir):
    import tiktoken
    import sentencepiece as spm
    enc = tiktoken.get_encoding("gpt2")
    sp = spm.SentencePieceProcessor(model_file=os.path.join(tokdir, "tokenizer.model"))
    rng = random.Random(0xC10C)
    # 50 reference strings: ASCII, contractions, multilingual, emoji, code, whitespace edges
    ref = [
        "Hello, world!", "The quick brown fox jumps over the lazy dog.",
        "don't can't won't it's they're we've", "'s 't 're 've 'm 'll 'd",
        "Hello   world", "trailing spaces   ", "   leading spaces",
        "line1\nline2\n", "tab\there", "a  b   c    d",
        "caf\u00e9 na\u00efve r\u00e9sum\u00e9", "\u4e2d\u6587\u6d4b\u8bd5",
        "\u65e5\u672c\u8a9e\u30c6\u30b9\u30c8", "\u0420\u0443\u0441\u0441\u043a\u0438\u0439 \u0442\u0435\u043a\u0441\u0442",
        "\u0627\u0644\u0639\u0631\u0628\u064a\u0629", "\U0001f600\U0001f601\U0001f602",
        "emoji \U0001f680 test \U0001f60e", "def foo(x):\n    return x + 1",
        "x = [1, 2, 3]; y = {'a': 1}", "SELECT * FROM t WHERE x > 5;",
        "123 4567 89.99", "3.14159265358979", "user@example.com",
        "https://example.com/path?q=1&r=2", "$100.00 \u20ac50 \u00a599",
        "UPPERCASE lowercase MiXeD", "a", " ", "  ", "\n", "\n\n\n",
        "supercalifragilisticexpialidocious", "antidisestablishmentarianism",
        "\u200b\u200c\u200d", "\u00a0non-breaking\u00a0space\u00a0",
        "\u2028line\u2029para", "mixed 123 \u4e2d\u6587 \U0001f600 end",
        "don't stop believin'", "rock 'n' roll", "'tis the season",
        "well-known self-driving", "state-of-the-art", "e-mail co-operate",
        "123abc abc123 a1b2c3", "...", "!!!", "???", "---", "===",
        "(parentheses) [brackets] {braces}",
    ]
    assert len(ref) == 50, len(ref)
    bpe_ref = [{"text": s, "ids": enc.encode(s)} for s in ref]
    # 1000 round-trip strings
    scripts = [
        "The meaning of hospitality is ", "hello world ",
        "\u4e2d\u6587", "\u65e5\u672c\u8a9e", "\u0420\u0443\u0441\u0441\u043a\u0438\u0439",
        "\u0627\u0644\u0639\u0631\u0628\u064a\u0629", "\U0001f600", "\U0001f680",
        "def f(): ", "x=1;y=2; ", "   ", "\n", "don't ",
        "\u03b1\u03b2\u03b3", "\u05d0\u05d1\u05d2", "\u0e01\u0e02\u0e03",
    ]
    rt = []
    for _ in range(1000):
        n = rng.randint(1, 6)
        rt.append("".join(rng.choice(scripts) for _ in range(n)) + str(rng.randint(0, 9999)))
    # 200 SentencePiece reference strings
    sp_ref_src = [
        "Hello, world!", "The meaning of hospitality is",
        "The quick brown fox jumps over the lazy dog.",
        "\u4e2d\u6587\u6d4b\u8bd5", "\u65e5\u672c\u8a9e\u30c6\u30b9\u30c8",
        "don't can't won't", "123 456 789", "   leading and trailing   ",
        "line1\nline2", "\U0001f600 emoji test",
        "def foo(x):\n    return x * 2",
    ]
    while len(sp_ref_src) < 200:
        n = rng.randint(1, 5)
        sp_ref_src.append("".join(rng.choice(scripts) for _ in range(n)))
    sp_ref_src = sp_ref_src[:200]
    sp_ref = [{"text": s, "ids": sp.encode(s, out_type=int)} for s in sp_ref_src]
    sp_rt = []
    for _ in range(300):
        n = rng.randint(1, 5)
        sp_rt.append("".join(rng.choice(scripts) for _ in range(n)))
    vec = {
        "version": "1",
        "bpe_reference": bpe_ref,
        "bpe_roundtrip": rt,
        "sp_reference": sp_ref,
        "sp_roundtrip": sp_rt,
    }
    p = os.path.join(outdir, "tokenizer_vectors.json")
    json.dump(vec, open(p, "w", encoding="utf-8"), ensure_ascii=False)
    print("wrote", p, os.path.getsize(p), "bytes")
    # sanity: every bpe_reference round-trips through tiktoken itself
    for e in bpe_ref:
        assert enc.decode(e["ids"]) == e["text"], e["text"]
    for s in rt:
        assert enc.decode(enc.encode(s)) == s, s
    for e in sp_ref:
        assert sp.decode(e["ids"]) == e["text"], e["text"]
    print("reference self-consistency: PASS")

if __name__ == "__main__":
    tokdir, outdir = sys.argv[1], sys.argv[2]
    os.makedirs(outdir, exist_ok=True)
    build_gpt2_bpe(tokdir, outdir)
    build_unicode_classes(outdir)
    build_vectors(tokdir, outdir)
