#!/usr/bin/env python3
"""J-119 inspect: mechanically re-derive every load-bearing claim in
docs/janas/J119_CONVERTER_CENSUS_RECONCILIATION.md from the tree at the
branch tip, plus the Part I campaign records. Read-only. Exit 0 iff all pass."""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
ENGINE = os.path.join(REPO, "aesir_engine")
CAMPAIGN = os.path.expanduser("~/workspace/model-tests/janas")
DOC = os.path.join(HERE, "J119_CONVERTER_CENSUS_RECONCILIATION.md")

fails = []
count = [0]
def check(name, ok, detail=""):
    count[0] += 1
    print(("PASS " if ok else "FAIL ") + name + ((" -- " + detail) if detail else ""))
    if not ok:
        fails.append(name)

def mojo_files():
    out = []
    for dp, _, fns in os.walk(ENGINE):
        for fn in fns:
            if fn.endswith(".mojo"):
                out.append(os.path.join(dp, fn))
    return out

def any_hit(files, pat, flags=re.IGNORECASE):
    rx = re.compile(pat, flags)
    return [f for f in files if rx.search(open(f, encoding="utf-8", errors="replace").read())]

files = mojo_files()
check("engine tree present (>400 .mojo files)", len(files) > 400, str(len(files)))

# --- Part I records carry the J-010 converter rows ---
census = open(os.path.join(CAMPAIGN, "CENSUS.md"), encoding="utf-8").read()
for tok in ["hf2gguf", "hf2jns_mtp", "gguf2jns", "hf2jns_vision", "silero2jns", "wespeaker2jns", "jns_check", "jns_planes"]:
    check("CENSUS.md J-010 names " + tok, tok in census)
delta = open(os.path.join(CAMPAIGN, "DELTA_TABLE.md"), encoding="utf-8").read()
for row, word in [("60", "REFUSED"), ("61", "WANTED"), ("62", "WANTED"), ("63", "PARTIAL"), ("71", "REFUSED")]:
    line = next((l for l in delta.splitlines() if l.startswith("| " + row + " |")), "")
    check("DELTA row " + row + " graded " + word, word in line, line[:60])

# --- Aesir conversion/import inventory ---
check("no LoRA anywhere in .mojo (C04 ABSENT)", not any_hit(files, r"lora"))
check("no GGUF writer symbol (C03/C06 ABSENT)", not any_hit(files, r"GGUFWriter|write_gguf|gguf_write"))
cmds = open(os.path.join(ENGINE, "cli", "commands.mojo"), encoding="utf-8").read()
check("dispatch has pull", 'cmd == "pull"' in cmds)
check("dispatch has get", 'cmd == "get"' in cmds)
check("dispatch has no convert command", 'cmd == "convert"' not in cmds)
check("dispatch has no quantize command", 'cmd == "quantize"' not in cmds)
for mod in ["gguf.mojo", "huggingface.mojo", "mmproj.mojo", "quantization.mojo", "exl2.mojo", "onnx.mojo"]:
    check("loader/" + mod + " present", os.path.exists(os.path.join(ENGINE, "loader", mod)))
exl2 = open(os.path.join(ENGINE, "loader", "exl2.mojo"), encoding="utf-8").read()
check("exl2 safetensors boundary is a refusal", "not implemented" in exl2)
hf = open(os.path.join(ENGINE, "loader", "huggingface.mojo"), encoding="utf-8").read()
check("huggingface.mojo downloads pinned GGUF (download_hf_model)", "download_hf_model" in hf)
check("huggingface.mojo has no safetensors handling", "safetensors" not in hf)
check("core/mtp_census.mojo present (engine-side MTP census)", os.path.exists(os.path.join(ENGINE, "core", "mtp_census.mojo")))
check("core/mtp_head_support.mojo present (engine-side MTP admission)", os.path.exists(os.path.join(ENGINE, "core", "mtp_head_support.mojo")))
mmproj = open(os.path.join(ENGINE, "loader", "mmproj.mojo"), encoding="utf-8").read()
check("mmproj read path finds tower beside model", "find_mmproj_beside" in mmproj or "beside" in mmproj)

# --- the doc's own table tallies match its headline ---
doc = open(DOC, encoding="utf-8").read()
rows = re.findall(r"^\| C\d+ \|.*\| (HAVE|PARTIAL|ABSENT|REFUSED) \|", doc, re.M)
from collections import Counter
tally = Counter(rows)
check("doc table has 11 converter rows", len(rows) == 11, str(len(rows)))
headline = "REFUSED %d" % tally["REFUSED"]
check("doc headline REFUSED tally matches table", headline in doc, str(dict(tally)))
check("doc headline ABSENT tally matches table", ("ABSENT %d" % tally["ABSENT"]) in doc, str(dict(tally)))
check("doc headline PARTIAL tally matches table", ("PARTIAL %d" % tally["PARTIAL"]) in doc, str(dict(tally)))
check("carried repl.mojo item re-cited in doc", "read_line" in doc and "J-109" in doc)
check("J-120/J-121/J-122 handoffs named in doc", all(s in doc for s in ["J-120", "J-121", "J-122"]))

print("TOTAL %d PASS %d FAIL %d" % (count[0], count[0] - len(fails), len(fails)))
sys.exit(1 if fails else 0)
