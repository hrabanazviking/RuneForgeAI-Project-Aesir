# tests/c3_h047_sp.mojo
# H047 — SentencePiece tokenizer verification (TEST-ONLY driver, not shipped).
#
# Loads data/armvegr/tinyllama_tokenizer.model and checks:
#   1. 200 reference strings encode to EXACTLY the sentencepiece ids
#      (frozen in tests/c3_h047_vectors.mojo, from sentencepiece 0.2.2).
#   2. 300 round-trip strings satisfy decode(encode(s)) == s.
# Usage: c3_h047_sp   (run from the repo root)

from armvegr.sp_tokenizer import SPTokenizer
from tests.c3_h047_vectors import sp_ref_texts, sp_ref_ids, sp_roundtrip_texts


def main() raises:
    var tok = SPTokenizer()
    tok.load("data/armvegr/tinyllama_tokenizer.model")
    print("H047 vocab size:", tok.model.vocab_size())
    print("H047 bos/eos/unk:", tok.model.bos_id, tok.model.eos_id, tok.model.unk_id)

    var texts = sp_ref_texts()
    var want_ids = sp_ref_ids()
    var mism = 0
    for i in range(len(texts)):
        var got = tok.encode(texts[i])
        var want = want_ids[i].copy()
        var ok = len(got) == len(want)
        if ok:
            for k in range(len(got)):
                if got[k] != want[k]:
                    ok = False
                    break
        if not ok:
            mism += 1
            if mism < 5:
                print("MISMATCH at", i, ":", texts[i][byte=0:60])
                print("  got len", len(got), "want len", len(want))
    print("H047 reference: " + String(len(texts) - mism) + "/" + String(len(texts)) + " exact")

    var rt = sp_roundtrip_texts()
    var rt_bad = 0
    for i in range(len(rt)):
        var ids = tok.encode(rt[i])
        var dec = tok.decode(ids)
        if dec != rt[i]:
            rt_bad += 1
            if rt_bad < 4:
                print("ROUNDTRIP FAIL:", rt[i][byte=0:60])
    print("H047 roundtrip: " + String(len(rt) - rt_bad) + "/" + String(len(rt)))

    if mism == 0 and rt_bad == 0:
        print("H047-ALL-PASS")
    else:
        print("H047-FAIL")
