#!/usr/bin/env python3
"""J-118 Part VII gate inspect: re-derives every gate claim from disk.
Checks: ls-remote branch chain, ancestor order, filed inspect outputs
(PASS-line counts, 0 FAIL), filed test outputs (ALL PASS, sha-identical
campaign copies), slice doc/inspect/output campaign sha identity, the
gate doc's deferred/refusal/open-item contents, and repo hygiene.
Stdlib only. Run from anywhere; paths are derived from this file."""
import hashlib, pathlib, re, subprocess, sys

HERE = pathlib.Path(__file__).resolve()
ROOT = HERE.parents[2]                      # repo root (docs/janas/<this>)
CAMPAIGN = pathlib.Path.home() / "workspace/model-tests/janas"
REMOTE = "https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir.git"

EXPECTED_TIPS = {
    99: "ceec2765b35a4733f728d1cb26891499cb51d094",
    100: "de9213cb372ecc141e1e8218db1da466dae13313",
    101: "ba7ff3bc515f7cfab1c9164b5c15a8dfe0fe60c0",
    102: "7526ecd9ae7215088fda7fbe0e4c45a6a64164ca",
    103: "dca5ec058fc57da6cbff067ebf6423fe08893e2d",
    104: "8e9da5269271d3cf066d24ee120d1ac5f0e55564",
    105: "fde780603396066b410a4c32995326e9f09c0464",
    106: "ddec27dc29b993d3e230c62c3e996f0c466b6f9b",
    107: "68c78d6c2cde4c42ba575e153e3049edb7aed940",
    108: "5b52061397ddc00bb2157d01df29d634d77a8d67",
    109: "52258cd8f6ebf5f5a5d10ded2f22d88563500f02",
    110: "0d601c87038bff6f046065fb546acf1f2ff60f29",
    111: "cdf70d7a759ce28d8ef9435314fb8a4301386482",
    112: "0a52d91506dbf86643fe838f9ebff9bc720087e4",
    113: "5ddf19460eec88f86abd0e3f53b1f756bd5c8985",
    114: "e3d093b3724f8bbc9c7460742811a134c46a2489",
    115: "640d64794368f01cf1befd528997deb76ab39e58",
    116: "982275a7d07bf953d82814c7901909377d590d5e",
    117: "570c9f060c530aa08c95b13ffa91e0a58b57cac6",
}
MAIN_TIP = "4ca75cc237de872a7e69777872ec1077f9e93e92"
EXPECTED_INSPECT = {99: 92, 100: 42, 101: 63, 102: 56, 103: 75, 104: 53,
                    105: 47, 106: 38, 107: 30, 108: 39, 109: 65, 110: 49,
                    111: 61, 112: 109, 113: 52, 114: 62, 115: 42, 116: 36,
                    117: 29}

checks = 0
fails = 0

def check(ok, label):
    global checks, fails
    checks += 1
    if not ok:
        fails += 1
    print(f"{'PASS' if ok else 'FAIL'}: {label}")

def sha(p):
    return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()

def tree_janas(i):
    """Directory holding slice i's artefacts in this tree."""
    return (ROOT / "docs/janas") if i == 99 else (ROOT / "aesir_engine/docs/janas")

def doc_name(i, directory):
    hits = sorted(directory.glob(f"J{i:03d}_*.md"))
    return hits[0] if hits else None

# 1. Branch chain via ls-remote (authoritative; git fetch is degraded
#    by the pre-existing stray refs recorded in the gate doc).
out = subprocess.run(["git", "ls-remote", REMOTE],
                     capture_output=True, text=True).stdout
remote = {}
for line in out.splitlines():
    h, ref = line.split("\t")
    remote[ref] = h
for i, tip in EXPECTED_TIPS.items():
    check(remote.get(f"refs/heads/yrsa/janas-j{i:03d}") == tip,
          f"ls-remote yrsa/janas-j{i:03d} == keeper-recorded tip {tip[:8]}")
check(remote.get("refs/heads/main") == MAIN_TIP,
      "ls-remote origin/main unchanged at 4ca75cc2")

# 2. Ancestor order in this tree's history (each tip an ancestor of the next).
tips = [EXPECTED_TIPS[i] for i in range(99, 118)]
for a, b in zip(tips, tips[1:]):
    r = subprocess.run(["git", "-C", str(ROOT), "merge-base", "--is-ancestor", a, b])
    check(r.returncode == 0, f"ancestor chain: {a[:8]} is ancestor of {b[:8]}")
r = subprocess.run(["git", "-C", str(ROOT), "merge-base", "--is-ancestor", tips[-1], "HEAD"])
check(r.returncode == 0, "ancestor chain: j117 tip is ancestor of gate HEAD")

# 3+4. Filed inspect/test outputs re-read; campaign copies sha-identical.
total_inspect = 0
for i in range(99, 118):
    d = tree_janas(i)
    io_tree = d / f"j{i:03d}_inspect_output.txt"
    io_camp = CAMPAIGN / f"j{i:03d}_inspect_output.txt"
    text = io_tree.read_text(errors="ignore")
    npass = sum(1 for l in text.splitlines() if l.strip().startswith("PASS"))
    nfail = sum(1 for l in text.splitlines() if l.strip().startswith("FAIL"))
    total_inspect += npass
    check(npass == EXPECTED_INSPECT[i] and nfail == 0,
          f"J-{i:03d} filed inspect output: {npass} PASS lines (expected {EXPECTED_INSPECT[i]}), {nfail} FAIL")
    check(sha(io_tree) == sha(io_camp), f"J-{i:03d} inspect output campaign copy sha-identical")
    is_tree = d / f"j{i:03d}_inspect.py"
    check(sha(is_tree) == sha(CAMPAIGN / is_tree.name),
          f"J-{i:03d} inspect script campaign copy sha-identical")
    doc = doc_name(i, d)
    check(doc is not None and sha(doc) == sha(CAMPAIGN / doc.name),
          f"J-{i:03d} slice doc campaign copy sha-identical ({doc.name if doc else 'MISSING'})")
    if i >= 100 and i not in (115, 116):  # J-099/J-115/J-116 filed no test output
        to_tree = d / f"j{i:03d}_test_output.txt"
        check(sha(to_tree) == sha(CAMPAIGN / to_tree.name),
              f"J-{i:03d} test output campaign copy sha-identical")
        check("ALL PASS" in to_tree.read_text(errors="ignore"),
              f"J-{i:03d} filed test output carries ALL PASS")
check(total_inspect == 1040, f"Part VII filed inspect checks total 1040 (re-counted {total_inspect})")

# 5-8. Gate doc contents.
gate = (ROOT / "docs/janas/J118_PART_VII_GATE.md").read_text()
for needle, label in [
    ("Part VII CLOSED-WITH-DEFERRED-LEGS", "gate verdict form filed"),
    ("OPEN", "open-item marker present"),
    ("aesir_adapter.py", "adapter fix item cites the adapter file"),
    ("must NOT claim the adapter consumes streamed generation over watched prompts",
     "gate expressly does not claim adapter consumption over watched prompts"),
    ("FreeBASIC", "refusal list: FreeBASIC present"),
    ("REFUSED", "refusal list: REFUSED form present"),
    ("NSM dressing is REFUSED", "refusal list: NSM dressing refused"),
    ("C ABI", "refusal list: C ABI present"),
    ("DEFERRED", "deferral form present"),
    ("Node/TypeScript", "refusal list: Node/TypeScript present"),
    ("embed", "refusal list: embed present"),
    ("Speech", "refusal list: speech present"),
    ("gguf2jns", "refusal list: gguf2jns present"),
    ("domain services", "refusal list: domain services present"),
    ("G-099-1", "G-099-1 disposition present"),
    ("G-099-2", "G-099-2 disposition present"),
    ("G-099-3", "G-099-3 disposition present"),
    ("NOT PROVEN", "honesty class NOT PROVEN present"),
    ("repl.mojo", "repl defect next item present"),
]:
    check(needle in gate, f"gate doc: {label}")
sec5 = gate.split("## 5. Deferred legs", 1)[1].split("## 6.", 1)[0]
n_deferred = len(re.findall(r"^\d+\. \*\*", sec5, flags=re.M))
check(n_deferred == 26, f"gate doc deferred/open list has 26 numbered items (found {n_deferred})")

# Hygiene: no README in the gate diff vs the j117 tip.
diff = subprocess.run(["git", "-C", str(ROOT), "diff", "--name-only",
                       EXPECTED_TIPS[117], "HEAD"],
                      capture_output=True, text=True).stdout
check("README" not in diff, "hygiene: no README.md in the gate diff")

print(f"TOTAL: {checks - fails} PASS, {fails} FAIL")
print("ALL PASS" if fails == 0 else "FAILURES PRESENT")
sys.exit(0 if fails == 0 else 1)
