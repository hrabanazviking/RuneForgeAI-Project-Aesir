#!/usr/bin/env python3
"""J-122 harness test suite (pure stdlib).

Groups, in the J-122 protocol section 0.6 order:
  1  P1 census classification exact
  2  P1 grade exact (merged vs the slow way)
  3  P3 census classification exact (labelled heads)
  4  P4 subset census exact
  5  P2 carried-verbatim exact + byte identity
  6  NEGATIVE flipped element -> FAIL, tensor named,
     differing count exactly 1
  7  NEGATIVE missing tensor -> FAIL,
     missing-in-converted named
  8  NEGATIVE mislabelled head -> FAIL,
     label-mismatch named
  9  NEGATIVE extra tensor -> FAIL,
     extra-in-converted named
 10  REFUSAL silently dropped unmapped tensor ->
     REFUSED-by-name, tensor named
 11  determinism -- harness re-runs over P1/P3
     reproduce the filed pair records exactly

The positive pairs are read from the filed
j122_pair_records.json (produced by
j122_run_pairs.py over the pinned files in
/tmp/j120/work and /tmp/j121/work). Tampering is
always on copies under the scratch dir, never on
the filed originals. Exit 0 iff all groups pass.
"""
import json
import os
import shutil
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRATCH = os.path.expanduser("~/workspace/.verify-tmp/j122test")
J120_WORK = "/tmp/j120/work"
J121_WORK = "/tmp/j121/work"
sys.path.insert(0, HERE)
from j121_fixtures import write_safetensors, vals  # noqa: E402

FAILS = []
COUNT = [0]


def check(cond, label):
    COUNT[0] += 1
    print(("PASS: " if cond else "FAIL: ") + label)
    if not cond:
        FAILS.append(label)


def harness(argv, out_name):
    out = os.path.join(SCRATCH, out_name)
    r = subprocess.run(
        [sys.executable, os.path.join(HERE, "j122_harness.py")] + argv +
        ["--out", out], capture_output=True, text=True)
    rec = json.load(open(out)) if os.path.exists(out) else {}
    return r, rec


def by_pair(records, pid):
    for rec in records:
        if rec["pair"] == pid:
            return rec
    raise KeyError(pid)


def main():
    os.makedirs(SCRATCH, exist_ok=True)
    records = json.load(open(os.path.join(HERE, "j122_pair_records.json")))
    p1 = by_pair(records, "P1-j120-lora-merge")
    p2 = by_pair(records, "P2-j120-c10-reemission")
    p3 = by_pair(records, "P3-j121-mtp-conversion")
    p4 = by_pair(records, "P4-j121-block-extraction")

    # 1 -- P1 census classification exact.
    check(p1["verdict"] == "PASS", "group 1: P1 verdict PASS")
    check(p1["class_counts"] == {"merged": 2, "pass-through": 10},
          "group 1: P1 classes merged 2 / pass-through 10")
    merged_names = sorted(e["converted_name"] for e in p1["census_diff"]
                          if e["class"] == "merged")
    check(merged_names == ["blk.0.attn_q.weight", "blk.0.ffn_gate.weight"],
          "group 1: P1 merged names exact (attn_q, ffn_gate)")
    check(len(p1["converted"]["census"]) == 12, "group 1: P1 census 12")

    # 2 -- P1 grade exact.
    check(p1["grade"] == {"kind": "element-exact (synthetic pair grade)",
                          "total_elements": 728, "differing_elements": 0,
                          "max_abs_diff": 0.0},
          "group 2: P1 grade 728 elements / 0 differing / 0.0")
    merged_elems = sum(e["elements"] for e in p1["census_diff"]
                       if e["class"] == "merged")
    check(merged_elems == 192,
          "group 2: P1 merged elements 192 vs the slow way, 0 diffs")

    # 3 -- P3 census classification exact.
    check(p3["verdict"] == "PASS", "group 3: P3 verdict PASS")
    check(p3["class_counts"] == {"labelled-head": 4, "pass-through": 12},
          "group 3: P3 classes labelled-head 4 / pass-through 12")
    heads = [e["converted_name"] for e in p3["census_diff"]
             if e["class"] == "labelled-head"]
    check(heads == ["model.nextn.eh_proj.weight",
                    "model.nextn.shared_head_norm.weight",
                    "model.mtp.fc.weight",
                    "model.assistant.head_norm.weight"],
          "group 3: P3 head names exact, in census order")
    check(p3["converted"]["head_label"] == heads and
          p3["converted"]["head_count"] == 4 and
          p3["converted"]["metadata_count"] == 21,
          "group 3: P3 metadata label agrees (21 entries, head_count 4)")
    check(p3["grade"]["total_elements"] == 936 and
          p3["grade"]["differing_elements"] == 0,
          "group 3: P3 grade 936 elements / 0 differing")

    # 4 -- P4 subset census exact.
    check(p4["verdict"] == "PASS" and
          p4["class_counts"] == {"labelled-head": 4} and
          len(p4["converted"]["census"]) == 4 and
          p4["grade"]["total_elements"] == 208 and
          p4["grade"]["differing_elements"] == 0,
          "group 4: P4 subset census 4 labelled-head / 208 elements exact")

    # 5 -- P2 carried-verbatim exact + byte identity.
    check(p2["verdict"] == "PASS" and
          p2["class_counts"] == {"carried-verbatim": 12} and
          p2["source"]["sha256"] == p2["converted"]["sha256"],
          "group 5: P2 carried-verbatim 12, source sha == converted sha")

    # 6 -- NEGATIVE: flipped element in a copy of merged.gguf.
    tampered = os.path.join(SCRATCH, "merged_flipped.gguf")
    data = bytearray(open(os.path.join(J120_WORK, "merged.gguf"), "rb").read())
    data[-1] ^= 0xFF  # last byte is tensor data of the last census tensor
    open(tampered, "wb").write(bytes(data))
    r, rec = harness(["hf-gguf",
                      "--source", os.path.join(J120_WORK, "model.safetensors"),
                      "--adapter", os.path.join(J120_WORK, "adapter_model.safetensors"),
                      "--adapter-config", os.path.join(J120_WORK, "adapter_config.json"),
                      "--converted", tampered], "flipped.json")
    check(r.returncode == 1 and rec["verdict"] == "FAIL",
          "group 6: flipped element FAILs (exit 1)")
    check(rec["grade"]["differing_elements"] == 1 and
          any("value-mismatch: blk.0.ffn_down.weight" in x
              for x in rec["reasons"]),
          "group 6: differing count exactly 1, tensor named "
          "(blk.0.ffn_down.weight)")

    # 7 -- NEGATIVE: missing tensors (the block file filed as the
    # full conversion -- 12 ordinary tensors missing).
    r, rec = harness(["hf-gguf",
                      "--source", os.path.join(J121_WORK, "model.safetensors"),
                      "--converted", os.path.join(J121_WORK, "block.gguf")],
                     "missing.json")
    missing = [e for e in rec["census_diff"]
               if e.get("difference") == "missing-in-converted"]
    check(r.returncode == 1 and rec["verdict"] == "FAIL" and
          len(missing) == 12 and
          any("missing-in-converted: token_embd.weight" in x
              for x in rec["reasons"]),
          "group 7: missing tensors FAIL, 12 missing-in-converted named")

    # 8 -- NEGATIVE: mislabelled head (metadata label altered on a
    # copy; the census itself is untouched).
    tampered = os.path.join(SCRATCH, "converted_mislabelled.gguf")
    data = open(os.path.join(J121_WORK, "converted.gguf"), "rb").read()
    needle = b"model.mtp.fc.weight"
    idx = data.find(needle)  # first occurrence is the metadata label
    assert idx > 0
    data = data[:idx] + b"model.mtp.fc.weighX" + data[idx + len(needle):]
    open(tampered, "wb").write(data)
    r, rec = harness(["hf-gguf",
                      "--source", os.path.join(J121_WORK, "model.safetensors"),
                      "--converted", tampered], "mislabelled.json")
    check(r.returncode == 1 and rec["verdict"] == "FAIL" and
          any(x.startswith("label-mismatch") for x in rec["reasons"]),
          "group 8: mislabelled head FAILs as label-mismatch")

    # 9 -- NEGATIVE: extra tensors (the full conversion filed as
    # the block extraction -- 12 extra tensors).
    r, rec = harness(["hf-gguf-subset-head",
                      "--source", os.path.join(J121_WORK, "model.safetensors"),
                      "--converted", os.path.join(J121_WORK, "converted.gguf")],
                     "extra.json")
    extra = [e for e in rec["census_diff"]
             if e["class"] == "extra-in-converted"]
    check(r.returncode == 1 and rec["verdict"] == "FAIL" and
          len(extra) == 12,
          "group 9: extra tensors FAIL, 12 extra-in-converted named")

    # 10 -- REFUSAL: a source carrying an unmapped non-head tensor
    # whose converted file silently dropped it.
    src_extra = os.path.join(SCRATCH, "model_extra.safetensors")
    base = json.loads(open(os.path.join(J121_WORK, "model.safetensors"),
                           "rb").read()[8:8 + struct.unpack(
                               "<Q", open(os.path.join(
                                   J121_WORK, "model.safetensors"),
                                   "rb").read()[:8])[0]].decode())
    tensors = []
    import j121_verify as _v  # the J-121 verifier's independent reader
    srcmap, srcorder = _v.read_safetensors(
        os.path.join(J121_WORK, "model.safetensors"))
    for n in srcorder:
        tensors.append((n, srcmap[n][0], srcmap[n][1]))
    tensors.append(("model.vision_tower.weight", [8],
                    vals(8, 3, 9, -4, 8.0)))
    write_safetensors(src_extra, tensors)
    r, rec = harness(["hf-gguf", "--source", src_extra,
                      "--converted", os.path.join(J121_WORK, "converted.gguf")],
                     "refused.json")
    check(r.returncode == 1 and rec["verdict"] == "REFUSED" and
          any("REFUSED-by-name: model.vision_tower.weight" in x
              for x in rec["reasons"]),
          "group 10: silently dropped unmapped tensor REFUSED-by-name "
          "(model.vision_tower.weight)")

    # 11 -- determinism: direct harness re-runs reproduce the filed
    # records (modulo the runner's added "pair" key).
    for pid, argv in [
            ("P1-j120-lora-merge",
             ["hf-gguf", "--source", os.path.join(J120_WORK, "model.safetensors"),
              "--adapter", os.path.join(J120_WORK, "adapter_model.safetensors"),
              "--adapter-config", os.path.join(J120_WORK, "adapter_config.json"),
              "--converted", os.path.join(J120_WORK, "merged.gguf")]),
            ("P3-j121-mtp-conversion",
             ["hf-gguf", "--source", os.path.join(J121_WORK, "model.safetensors"),
              "--converted", os.path.join(J121_WORK, "converted.gguf")])]:
        r, rec = harness(argv, "rerun_" + pid + ".json")
        filed = dict(by_pair(records, pid))
        filed.pop("pair")
        check(r.returncode == 0 and rec == filed,
              "group 11: re-run reproduces filed record exactly (" + pid + ")")

    print("checks: %d, fails: %d" % (COUNT[0], len(FAILS)))
    if FAILS:
        print("TEST HARNESS: FAIL")
        sys.exit(1)
    print("TEST HARNESS: ALL PASS (11 groups)")


if __name__ == "__main__":
    main()
