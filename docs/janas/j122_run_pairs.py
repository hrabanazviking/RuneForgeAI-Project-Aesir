#!/usr/bin/env python3
"""J-122 pair runner (pure stdlib).

Regenerates the four conversions this road has
performed, exactly as their own slices' evidence
chains ran them, and files each pair through the
J-122 harness:

  P1  J-120 LoRA merge        HF base + adapter -> merged.gguf
  P2  J-120 C10 re-emission   merged.gguf -> remitted.gguf
  P3  J-121 MTP conversion    HF checkpoint -> converted.gguf
  P4  J-121 block extraction  HF checkpoint -> block.gguf

Regeneration uses the J-120/J-121 fixture writers in
this directory and the staged convert binaries built
from the J-121 tree (~/workspace/.verify-tmp/
j121build/) -- no new compile is forced under the
VM memory gate. Each regenerated converted file must
first reproduce its slice's banked sha256 pin; a
miss fails the run before the harness grades
anything, so no pair record rests on an unpinned
file. Convert drivers write to their fixed work
dirs (/tmp/j120/work, /tmp/j121/work).

Output: j122_pair_records.json beside this script
(a JSON list of the four harness records, in P1..P4
order, no timestamps -- re-runs are byte-identical).
Exit 0 iff all four verdicts are PASS.
"""
import hashlib
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.expanduser("~/workspace/.verify-tmp/j121build")
J120_WORK = "/tmp/j120/work"
J121_WORK = "/tmp/j121/work"

PINS = {
    os.path.join(J120_WORK, "merged.gguf"):
        "c26af51dd9ebbea7a31635d3354ebb2dcf570dd69bd5df576ca01f1c1c7e2c6a",
    os.path.join(J121_WORK, "converted.gguf"):
        "730dadae10b033c22b2e2345d2a478d717043a5c3f225e5977ba1b433ec77005",
    os.path.join(J121_WORK, "block.gguf"):
        "7f8f0070aae658a4aca5f4209b9d7e70eea0a539ede251a8251328252f29008b",
}


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def run(cmd, label):
    r = subprocess.run(cmd, capture_output=True, text=True)
    print("== %s (exit %d) ==" % (label, r.returncode))
    sys.stdout.write(r.stdout)
    if r.returncode != 0:
        sys.stdout.write(r.stderr)
        print("RUN PAIRS: FAIL at " + label)
        sys.exit(1)


def main():
    os.makedirs(J120_WORK, exist_ok=True)
    os.makedirs(J121_WORK, exist_ok=True)
    run([sys.executable, os.path.join(HERE, "j120_fixtures.py"), J120_WORK],
        "j120 fixtures")
    run([sys.executable, os.path.join(HERE, "j121_fixtures.py"), J121_WORK],
        "j121 fixtures")
    run([os.path.join(BUILD, "j120_convert")], "j120_convert (staged, J-121 tree)")
    run([os.path.join(BUILD, "j121_convert")], "j121_convert (staged, J-121 tree)")
    for path, pin in PINS.items():
        got = sha(path)
        print("PIN %s %s" % (os.path.basename(path),
                             "OK" if got == pin else "MISMATCH got " + got))
        if got != pin:
            print("RUN PAIRS: FAIL -- regenerated file misses its banked pin")
            sys.exit(1)
    tmp = os.path.expanduser("~/workspace/.verify-tmp/j122pairtmp")
    os.makedirs(tmp, exist_ok=True)
    pairs = [
        ("P1-j120-lora-merge", ["hf-gguf",
         "--source", os.path.join(J120_WORK, "model.safetensors"),
         "--adapter", os.path.join(J120_WORK, "adapter_model.safetensors"),
         "--adapter-config", os.path.join(J120_WORK, "adapter_config.json"),
         "--converted", os.path.join(J120_WORK, "merged.gguf")]),
        ("P2-j120-c10-reemission", ["gguf-gguf",
         "--source", os.path.join(J120_WORK, "merged.gguf"),
         "--converted", os.path.join(J120_WORK, "remitted.gguf")]),
        ("P3-j121-mtp-conversion", ["hf-gguf",
         "--source", os.path.join(J121_WORK, "model.safetensors"),
         "--converted", os.path.join(J121_WORK, "converted.gguf")]),
        ("P4-j121-block-extraction", ["hf-gguf-subset-head",
         "--source", os.path.join(J121_WORK, "model.safetensors"),
         "--converted", os.path.join(J121_WORK, "block.gguf")]),
    ]
    records = []
    ok = True
    for pid, argv in pairs:
        out = os.path.join(tmp, pid + ".json")
        r = subprocess.run(
            [sys.executable, os.path.join(HERE, "j122_harness.py")] + argv +
            ["--out", out], capture_output=True, text=True)
        print("== %s (exit %d) ==" % (pid, r.returncode))
        sys.stdout.write(r.stdout)
        sys.stdout.write(r.stderr)
        rec = json.load(open(out))
        rec = {"pair": pid, **rec}
        records.append(rec)
        if rec["verdict"] != "PASS":
            ok = False
    dest = os.path.join(HERE, "j122_pair_records.json")
    with open(dest, "w") as f:
        json.dump(records, f, indent=1, sort_keys=True)
        f.write("\n")
    print("pair records written:", dest)
    print("RUN PAIRS: " + ("ALL PASS (4 pairs)" if ok else "FAIL"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
