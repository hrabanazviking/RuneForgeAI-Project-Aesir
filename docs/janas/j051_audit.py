#!/usr/bin/env python3
"""J-051 Windows parity audit -- first-hand tree inspection.

Grades, from the tree itself (never from prose about the tree):
  A. the Windows BUILD surface: package platforms, CI runners, native
     build files, Windows executables/scripts;
  B. the Windows LAUNCH surface the tree does carry (PowerShell / WSL
     bridge) and what it actually executes;
  C. the Part III placement surface (J-036..J-050 modules + their direct
     dependencies) for Windows-relevant assumptions, each graded
     portable-by-construction / windows-risk-with-reason / not-applicable.

Read-only. Prints every finding with file:line evidence.
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.chdir(ROOT)

def show(title):
    print("\n=== %s ===" % title)

def grep(paths, pattern, flags=re.IGNORECASE, maxhits=60):
    rx = re.compile(pattern, flags)
    hits = []
    for p in paths:
        try:
            with open(p, encoding="utf-8", errors="replace") as f:
                for i, line in enumerate(f, 1):
                    if rx.search(line):
                        hits.append("%s:%d: %s" % (p, i, line.rstrip()[:160]))
        except (OSError, UnicodeDecodeError):
            pass
    for h in hits[:maxhits]:
        print(h)
    if len(hits) > maxhits:
        print("... (%d more hits)" % (len(hits) - maxhits))
    print("[%d hits]" % len(hits))
    return hits

def walk(exts=None, dirs=None):
    out = []
    for base, dnames, fnames in os.walk("."):
        dnames[:] = [d for d in dnames if d not in (".git",)]
        if dirs and not any(base == "." + os.sep + d or base.startswith("." + os.sep + d + os.sep) or base == "./" + d for d in dirs):
            if base != ".":
                continue
        for fn in fnames:
            p = os.path.join(base, fn)[2:]
            if exts is None or os.path.splitext(fn)[1].lower() in exts:
                out.append(p)
    return sorted(out)

# ---------------------------------------------------------------- A. build
show("A1 pixi platforms (the package/build definition)")
for f in ("pixi.toml",):
    with open(f) as fh:
        for i, line in enumerate(fh, 1):
            if "platform" in line.lower():
                print("%s:%d: %s" % (f, i, line.rstrip()))
lock = ""
if os.path.exists("pixi.lock"):
    with open("pixi.lock", encoding="utf-8", errors="replace") as fh:
        lock = fh.read()
for plat in ("linux-64", "win-64", "osx-64", "osx-arm64", "linux-aarch64"):
    print("pixi.lock mentions %-14s : %d" % (plat, lock.count(plat)))

show("A2 CI runners and Windows steps")
ci = ".github/workflows/ci.yml"
with open(ci) as fh:
    ci_lines = fh.readlines()
for i, line in enumerate(ci_lines, 1):
    if re.search(r"runs-on|windows|pwsh|powershell|wsl", line, re.IGNORECASE):
        print("%s:%d: %s" % (ci, i, line.rstrip()[:160]))
print("workflow files:", os.listdir(".github/workflows"))

show("A3 native build files / Windows binaries anywhere in the tree")
all_files = walk()
for pat, label in ((r"\.(sln|vcxproj|csproj)$", "MSVC project"),
                   (r"\.(bat|cmd)$", "batch/cmd script"),
                   (r"\.exe$", "exe binary"),
                   (r"(^|/)CMakeLists\.txt$", "CMake"),
                   (r"(^|/)meson\.build$", "Meson"),
                   (r"(^|/)Makefile$", "Makefile")):
    hits = [p for p in all_files if re.search(pat, p)]
    print("%-16s : %d %s" % (label, len(hits), hits[:8]))
ps = [p for p in all_files if p.endswith((".ps1", ".psm1"))]
print("PowerShell files : %d %s" % (len(ps), ps))
sh = [p for p in all_files if p.endswith(".sh")]
print("shell scripts    : %d (first 8) %s" % (len(sh), sh[:8]))

show("A4 what the PowerShell surface executes (WSL bridge evidence)")
for f in ("scripts/launch.ps1", "scripts/launch_windows.psm1",
          "scripts/launch_windows_bridge.py", "scripts/test_windows_launch.ps1"):
    if os.path.exists(f):
        print("--- %s (%d lines)" % (f, sum(1 for _ in open(f, encoding="utf-8", errors="replace"))))
        grep([f], r"wsl|linux|binary|aesir-ci-build|/tmp/|\.exe|windows", maxhits=25)

show("A5 launch.py platform handling")
grep(["scripts/launch.py"], r"windows|wsl|sys\.platform|os\.name|nt\b|posix", maxhits=30)

show("A6 docs that mention Windows (top-level docs only, not evidence corpus)")
top_docs = [p for p in all_files if p.endswith(".md") and "/" not in p]
grep(top_docs, r"windows", maxhits=40)

# ------------------------------------------------------- C. Part III audit
PART3 = [
    "aesir_engine/core/placement_options.mojo",
    "aesir_engine/core/device_inventory.mojo",
    "aesir_engine/core/placement_harness.mojo",
    "aesir_engine/core/thread_topology.mojo",
    "aesir_engine/core/prompt_placement.mojo",
    "aesir_engine/core/reply_placement.mojo",
    "aesir_engine/core/draft_placement.mojo",
    "aesir_engine/core/cowork_passes.mojo",
    "aesir_engine/core/learned_file.mojo",
    "aesir_engine/core/retrial.mojo",
    "aesir_engine/core/within_tolerance.mojo",
    "aesir_engine/core/manual_override.mojo",
    "aesir_engine/core/placement_pressure.mojo",
    "aesir_engine/core/server_placement.mojo",
    "aesir_engine/core/placement_explain.mojo",
    "aesir_engine/core/moe_gpu_plan.mojo",
    "aesir_engine/core/expert_cache.mojo",
]
DEPS = [
    "aesir_engine/core/parallel.mojo",
    "aesir_engine/core/posix_process.mojo",
    "aesir_engine/core/native_hardware.mojo",
    "aesir_engine/core/thread_pool.mojo",
]
print("\nPart III modules audited: %d; direct deps audited: %d" % (len(PART3), len(DEPS)))
for p in PART3 + DEPS:
    print("  %-52s %s" % (p, "present" if os.path.exists(p) else "MISSING"))

CHECKS = [
    ("C1 hard-coded '/' path joins / absolute POSIX paths",
     r'"/[a-z]|\+ "/" \+|"/tmp|"/proc|"/sys|"/dev|"\.cache'),
    ("C2 backslash / Windows separator or drive letters", r"\\\\|[A-Za-z]:\\\\"),
    ("C3 HOME / environment variables", r"HOME|getenv|setenv|environ"),
    ("C4 procfs / sysfs reads", r"/proc/|/sys/"),
    ("C5 external commands (nvidia-smi etc.)", r"nvidia-smi|/bin/|posix_spawn|system\("),
    ("C6 POSIX FFI: fsync/rename/mkdir/open/read/write/pread",
     r"fsync|rename|mkdir|pwrite|pread|[^a-z]open\("),
    ("C7 shared-library / dlopen assumptions (.so, pthread)",
     r"\.so|dlopen|pthread|libaesir"),
    ("C8 newline handling (\\n splits, \\r tolerance)",
     r"\\\\n|\\\\r|newline|line ending"),
    ("C9 OS / platform conditionals", r"windows|win32|target os|is_windows|os\.name|sys\.platform"),
    ("C10 threading primitives", r"pthread|thread|Thread|atomic"),
]
for title, pat in CHECKS:
    show(title + " -- Part III modules")
    grep(PART3, pat, flags=0, maxhits=40)
    show(title + " -- direct deps")
    grep(DEPS, pat, flags=0, maxhits=25)

show("C11 learned-file path construction (verbatim block)")
src = open("aesir_engine/core/learned_file.mojo").read().splitlines()
for i, line in enumerate(src, 1):
    if re.search(r"learned_file_path|cache_home|HOME|\.cache|/aesir|join", line):
        print("learned_file.mojo:%d: %s" % (i, line.rstrip()[:170]))

show("C12 learned-file line parsing (does a \\r break it?)")
for i, line in enumerate(src, 1):
    if re.search(r"split|\\\\n|byte|ord|checksum|FNV|fnv", line):
        print("learned_file.mojo:%d: %s" % (i, line.rstrip()[:170]))

show("C13 retrial log path construction")
grep(["aesir_engine/core/retrial.mojo"], r"log|path|\+ \"\.|append", flags=0, maxhits=20)

show("C14 .gitattributes Windows awareness (verbatim)")
if os.path.exists(".gitattributes"):
    print(open(".gitattributes").read())

show("C15 Mojo stdlib platform support note (tree's own words)")
grep(top_docs + ["08_TOOLCHAIN_AND_WORKFLOW.md"], r"windows|wsl", maxhits=20)

print("\nAUDIT DONE")
