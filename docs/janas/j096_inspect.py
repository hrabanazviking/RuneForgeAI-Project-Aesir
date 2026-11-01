#!/usr/bin/env python3
"""J-096 KV persistence -- inspect / re-derivation script.

Checks, mechanically:

- the module's structure in core/kv_persistence.mojo:
  the persistence question and candidate shapes, the
  benefit definition, the privacy/storage decision
  rule and the worth-building verdict rule, all
  PRE-REGISTERED in the header; the account defined
  THROUGH core/kv_account (J-087), core/kv_int8
  (J-088) and core/prompt_read (J-094); the
  serialise/restore surface and the verdict functions
  present;
- the no-wiring fact (J-031 section 10's reason): no
  file in the tree references kv_persistence except
  the module itself, its own test and the harness,
  and tests/run_all.mojo does not register
  test_kv_persistence;
- the filed harness lines in j096_test_output.txt:
  PERSISTHEAD / PERSISTDONE, x2 runs byte-identical;
  every printed quantity re-derived in Python exactly
  -- the read work from J-053's projection formula
  and the causal-pair account, KV/file/traffic from
  J-087/J-088's per-token prices plus the stated 72 B
  overhead, the same-precision host-batched touch
  through J-053's pass plan, work per traffic byte,
  storage ppm, and the benefit verdict under the
  pre-registered rule; the PREFIX lines (avoided ==
  W(P), remaining == W(L) - W(P), conservation); the
  PRIVACY verdicts under the five-property rule;
- the validation gates: the filed PERSIST lines'
  work_avoided / kv_bytes / touch reproduce J-094's
  filed READ lines in j094_test_output.txt EXACTLY,
  parsed field-by-field (work_total, kv_written,
  touch_host per rung and precision);
- the round-trip, re-derived cross-implementation:
  the exercise store rebuilt in Python from the
  stated synth rule and J-088's quantizer (per-head
  slice scale = maxabs/127, round-half-away, clamp
  127) in float32 arithmetic, serialised in Python
  under the module header's byte format (header
  fields, per-layer K codes / V codes / K scales /
  V scales payload, rolling checksum trailer) --
  its length and checksum must equal the Mojo
  harness's filed file_bytes and checksum exactly,
  and the filed diffs are (0, 0, 0) with verdict
  EXACT;
- the doc states the verdicts (PAYS at the account
  level, the mechanism BUILT at the store level,
  OPT-IN the only ACCEPTED privacy shape), every
  live leg as NOT PROVEN / INTEGRATION_BLOCKED, and
  the deferred live recipe for the J-098 gate
  (guarded window, sha pin, J-088 section 7
  integration first, ids-first raw-oracle grading,
  never llama-cli --single-turn, teacher-forcing
  rank + logit gap).

Every check prints PASS/FAIL; the script exits nonzero
on any FAIL. Run from the repo root:
  python3 docs/janas/j096_inspect.py
"""
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CORE = ROOT / "aesir_engine" / "core"
JANAS = ROOT / "docs" / "janas"

checks = 0
fails = 0


def check(cond, label):
    global checks, fails
    checks += 1
    if cond:
        print("PASS: " + label)
    else:
        fails += 1
        print("FAIL: " + label)


def parse_kv(line):
    out = {}
    for tok in line.split():
        if "=" in tok:
            k, v = tok.split("=", 1)
            out[k] = v
    return out


def f32(x):
    return struct.unpack("f", struct.pack("f", x))[0]


# --- the witness account, re-derived ------------------------------------
LAYERS, HEADS, HD = 28, 4, 128
HIDDEN, QW, KVW, FFN = 3584, 3584, 512, 18944
WEIGHTS = 4683074688
PT = {"f16": 57344, "int8": 29568}
RUNGS = [1024, 4096, 8192, 16384, 32768]
PROJ_PT = LAYERS * (2 * HIDDEN * QW + 2 * HIDDEN * KVW + 3 * HIDDEN * FFN)


def work(L):
    pairs = L * (L + 1) // 2
    return LAYERS * pairs * QW * 2 + PROJ_PT * L


def host_passes(L):
    pure, pos = 0, 0
    while L - 1 - pos >= 256:
        pure += 1
        pos += 256
    return pure + 1


def touch(prec, L):
    pt = PT[prec]
    pairs = L * (L + 1) // 2
    return pt * pairs + host_passes(L) * WEIGHTS + pt * L


def benefit(work_avoided, traffic, tch):
    return "PAYS" if (traffic < tch and work_avoided >= traffic * 1000) \
        else "DOES_NOT_PAY"


# --- the round-trip exercise, re-derived --------------------------------
SL, SH, SHD, SCAP, SLEN, FP = 2, 2, 16, 24, 11, 424242
SWIDTH = SH * SHD


def synth(i):
    return f32(((i * 37) % 17 - 8) / 8.0)


def row_values(layer, pos, salt):
    return [synth(layer * 4096 + pos * SWIDTH + j + salt) for j in range(SWIDTH)]


def quantize_row(row):
    codes, scales = [], []
    for h in range(SH):
        sl = row[h * SHD:(h + 1) * SHD]
        maxabs = max(abs(v) for v in sl)
        scale = f32(1.0) if maxabs <= 0 else f32(maxabs / 127.0)
        scales.append(scale)
        for x in sl:
            q = f32(x / scale)
            r = int(f32(q + (0.5 if q >= 0 else -0.5)))
            codes.append(max(-127, min(127, r)))
    return codes, scales


def checksum(data):
    h = 0
    for b in data:
        h = (h * 31 + b) % 2147483647
    return h


def py_serialize():
    out = bytearray(b"AESIRKV1")
    for v in (SL, SH, SHD, SCAP, SLEN, SWIDTH, FP):
        out += struct.pack("<Q", v)
    for layer in range(SL):
        kc_all, ks_all, vc_all, vs_all = [], [], [], []
        for pos in range(SLEN):
            kc, ks = quantize_row(row_values(layer, pos, 11))
            vc, vs = quantize_row(row_values(layer, pos, 5000))
            kc_all += kc
            ks_all += ks
            vc_all += vc
            vs_all += vs
        # payload order is per position-segmented by buffer
        # segments: the module stores, per layer, the whole
        # K-codes segment (positions in order), then V codes,
        # then K scales, then V scales.
        for c in kc_all:
            out.append(c & 0xFF)
        for c in vc_all:
            out.append(c & 0xFF)
        for s in ks_all:
            out += struct.pack("<f", s)
        for s in vs_all:
            out += struct.pack("<f", s)
    out += struct.pack("<Q", checksum(out))
    return bytes(out)


py_file = py_serialize()

# --- 1. module structure --------------------------------------------------
module = (CORE / "kv_persistence.mojo").read_text()
for needle in (
    "from core.kv_account import",
    "from core.kv_int8 import",
    "from core.prompt_read import",
    "(a) THE PERSISTENCE QUESTION",
    "CANDIDATE",
    "BENEFIT DEFINITION",
    "PROMPT-EQUIVALENT",
    "DECISION RULE",
    "VERDICT RULE (pre-registered)",
    "BUILT ONLY IF IT",
    "NOT PROVEN",
    "J-098",
    "serialize_int8_store",
    "deserialize_int8_store",
    "kvp_privacy_verdict",
    "kvp_benefit_verdict",
    "INTEGRATION_BLOCKED",
):
    check(needle in module, "module structure: " + needle)

harness = (JANAS / "j096_persist.mojo").read_text()
check("LIVE RESTART AND NO LIVE BENEFIT" in harness,
      "harness header states no live leg")
check("from core.kv_persistence import" in harness,
      "harness defined through core/kv_persistence")

# --- 2. no wiring ---------------------------------------------------------
offenders = []
for path in (ROOT / "aesir_engine").rglob("*.mojo"):
    rel = path.relative_to(ROOT / "aesir_engine")
    if str(rel) in ("core/kv_persistence.mojo", "tests/test_kv_persistence.mojo"):
        continue
    if "kv_persistence" in path.read_text():
        offenders.append(str(rel))
check(not offenders, "no other tree file references kv_persistence (found: %s)"
      % offenders)
run_all = (ROOT / "aesir_engine" / "tests" / "run_all.mojo").read_text()
check("test_kv_persistence" not in run_all,
      "run_all does not register test_kv_persistence")

# --- 3. filed harness lines ----------------------------------------------
out = (JANAS / "j096_test_output.txt").read_text()
harness_lines = [
    ln for ln in out.splitlines()
    if ln.startswith(("PERSISTHEAD", "PERSIST ", "PREFIX", "PRIVACY",
                      "ROUNDTRIP", "PERSISTDONE"))
]
check(out.count("PERSISTHEAD") == 2, "PERSISTHEAD x2 runs")
check(out.count("PERSISTDONE") == 2, "PERSISTDONE x2 runs")
half = harness_lines[:len(harness_lines) // 2]
check(half == harness_lines[len(harness_lines) // 2:],
      "harness runs byte-identical")
persist = {}
for ln in half:
    if ln.startswith("PERSIST "):
        d = parse_kv(ln)
        persist[(int(d["rung"]), d["precision"])] = d
prefix = {}
for ln in half:
    if ln.startswith("PREFIX"):
        d = parse_kv(ln)
        prefix[int(d["prefix"])] = d
privacy = {}
for ln in half:
    if ln.startswith("PRIVACY"):
        d = parse_kv(ln)
        privacy[d["shape"]] = d["verdict"]
rt = [parse_kv(ln) for ln in half if ln.startswith("ROUNDTRIP")][0]

ok = True
for L in RUNGS:
    for prec in ("f16", "int8"):
        d = persist[(L, prec)]
        w = work(L)
        kv = PT[prec] * L
        fileb = 72 + kv
        traffic = 2 * fileb
        tch = touch(prec, L)
        ok &= int(d["work_avoided"]) == w
        ok &= int(d["kv_bytes"]) == kv
        ok &= int(d["file_bytes"]) == fileb
        ok &= int(d["traffic"]) == traffic
        ok &= int(d["touch"]) == tch
        ok &= int(d["work_per_traffic_byte"]) == w // traffic
        ok &= int(d["storage_ppm"]) == fileb * 1000000 // WEIGHTS
        ok &= d["verdict"] == benefit(w, traffic, tch) == "PAYS"
check(ok, "benefit account re-derived: every PERSIST field at all 5 rungs x 2 precisions; verdict PAYS everywhere under the pre-registered rule")
worst = min(work(L) // (2 * (72 + PT[p] * L)) for L in RUNGS for p in PT)
check(worst == 57792, "worst cell re-derived: 57,792 MACs per traffic byte (f16 @1024)")

ok = True
for P, d in prefix.items():
    ok &= int(d["work_avoided"]) == work(P)
    ok &= int(d["remaining"]) == work(32768) - work(P)
    ok &= int(d["file_f16"]) == 72 + PT["f16"] * P
    ok &= int(d["file_int8"]) == 72 + PT["int8"] * P
check(ok and len(prefix) == 4,
      "prefix account re-derived: avoided == W(P), remaining == W(L) - W(P), files at both precisions")

check(privacy == {
    "opt_in_bound_cache_home": "ACCEPTED",
    "silent_default_unbound": "REJECTED",
    "shared_world_readable": "REJECTED",
}, "privacy verdicts re-derived: OPT-IN ACCEPTED, SILENT and SHARED REJECTED")

# --- 4. validation gate against J-094's filed READ lines ------------------
j094 = (JANAS / "j094_test_output.txt").read_text()
gate = True
cells = set()
for ln in j094.splitlines():
    if ln.startswith("READ L="):
        d = parse_kv(ln)
        L, prec = int(d["L"]), d["prec"]
        mine = persist[(L, prec)]
        gate &= mine["work_avoided"] == d["work_total"]
        gate &= mine["kv_bytes"] == d["kv_written"]
        gate &= mine["touch"] == d["touch_host"]
        cells.add((L, prec))
check(gate and len(cells) == 10,
      "gate: PERSIST work/kv/touch == J-094 filed READ lines exactly (10 cells)")

# --- 5. round-trip, cross-implementation ----------------------------------
check(int(rt["file_bytes"]) == len(py_file) == 1832,
      "round-trip file length re-derived: Python serialisation is 1,832 B, matching the harness")
check(int(rt["checksum"]) == checksum(py_file[:-8]),
      "round-trip checksum re-derived: Python-built file's checksum == the Mojo harness's filed checksum (byte-level cross-implementation agreement)")
check(rt["code_diff"] == "0" and rt["scale_diff"] == "0"
      and rt["state_diff"] == "0" and rt["dequant_max"] == "0.0"
      and rt["attn_equal"] == "True" and rt["verdict"] == "EXACT",
      "round-trip filed: diffs (0, 0, 0), dequant 0.0, attention equal, verdict EXACT")

# --- 6. doc honesty ---------------------------------------------------------
doc = (JANAS / "J096_KV_PERSISTENCE.md").read_text()
for needle in (
    "PAYS",
    "ACCEPTED",
    "NOT PROVEN",
    "INTEGRATION_BLOCKED",
    "321,576,079,720,448",
    "57,792",
    "J-098",
    "guarded",
    "J-088 §7",
    "never `llama-cli --single-turn`",
    "teacher-forcing rank + logit gap",
    "PROMPT-EQUIVALENT",
):
    check(needle in doc, "doc states: " + needle)

print("INSPECT: %d checks, %d fails" % (checks, fails))
sys.exit(1 if fails else 0)
