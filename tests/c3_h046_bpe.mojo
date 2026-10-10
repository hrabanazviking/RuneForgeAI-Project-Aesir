# tests/c3_h046_bpe.mojo
# H046 — BPE tokenizer verification (TEST-ONLY driver, not shipped).
#
# Loads the frozen GPT-2 BPE data (data/armvegr/gpt2_bpe.bin +
# data/armvegr/unicode_classes.bin) and checks:
#   1. 50 reference strings encode to EXACTLY the tiktoken ids
#      (frozen in tests/c3_h046_vectors.mojo, generated from tiktoken 0.14.0).
#   2. 1000 round-trip strings satisfy decode(encode(s)) == s.
# Usage: c3_h046_bpe   (run from the repo root)

from armvegr.bpe import BPEModel
from tests.c3_h046_vectors import bpe_ref_texts, bpe_ref_ids, bpe_roundtrip_texts


def main() raises:
    var model = BPEModel()
    model.load("data/armvegr/gpt2_bpe.bin", "data/armvegr/unicode_classes.bin")
    print("H046 vocab size:", model.vocab_size())

    var texts = bpe_ref_texts()
    var want_ids = bpe_ref_ids()
    var mism = 0
    for i in range(len(texts)):
        var got = model.encode(texts[i])
        var want = want_ids[i].copy()
        var ok = len(got) == len(want)
        if ok:
            for k in range(len(got)):
                if got[k] != want[k]:
                    ok = False
                    break
        if not ok:
            mism += 1
            print("MISMATCH at", i, ":", texts[i])
            var show = 8
            if len(got) < show:
                show = len(got)
            var gstr = String("[")
            for k in range(show):
                gstr += String(got[k]) + ","
            print("  got len", len(got), gstr + "...] want len", len(want))
    print("H046 reference: " + String(len(texts) - mism) + "/" + String(len(texts)) + " exact")

    var rt = bpe_roundtrip_texts()
    var rt_bad = 0
    for i in range(len(rt)):
        var ids = model.encode(rt[i])
        var dec = model.decode(ids)
        if dec != rt[i]:
            rt_bad += 1
            if rt_bad < 4:
                print("ROUNDTRIP FAIL:", rt[i])
    print("H046 roundtrip: " + String(len(rt) - rt_bad) + "/" + String(len(rt)))

    if mism == 0 and rt_bad == 0:
        print("H046-ALL-PASS")
    else:
        print("H046-FAIL")
