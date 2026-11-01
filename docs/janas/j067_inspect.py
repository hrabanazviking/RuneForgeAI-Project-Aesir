#!/usr/bin/env python3
"""J-067 inspection: how Aesir's inventory/placement represents a GPU.

Machine-generated anchors for docs/janas/J067_IGPU_AWARENESS.md.
Recounts, from this tree: GpuFacts fields and budget derivation in
device_inventory, the discrete assumption in moe_gpu_plan (J-031),
the contention rule's pool shape in placement_pressure (J-048),
every integrated/iGPU mention in core code, and this machine's GPU
environment (the live leg's feasibility).

Clean-room: this script reads only Aesir's own tree. No Janas
material of any kind is opened.
"""
import os, re, shutil, sys
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CORE = os.path.join(ROOT, "aesir_engine", "core")

def main():
    out = []
    out.append("J-067 INSPECT -- GPU representation / iGPU environment")
    out.append(f"tree root: {ROOT}")
    inv = open(os.path.join(CORE, "device_inventory.mojo")).read()
    out.append(f"device_inventory.mojo: {len(inv.splitlines())} lines")
    m = re.search(r"struct GpuFacts.*?^struct |^def ", inv, re.M | re.S)
    out.append(f"GpuFacts fields: {re.findall(chr(118)+'ar (\\w+):', inv[inv.find('struct GpuFacts'):inv.find('struct GpuFacts')+600])}")
    out.append(f"GpuFacts has integrated/shared flag: {'integrated' in inv.lower() or 'shared_pool' in inv}")
    out.append(f"gpu_entry detail uses vram_total_bytes: {'vram_total_bytes' in inv}")
    out.append(f"probe is nvidia-smi only: {inv.count('nvidia-smi')}")
    mgp = open(os.path.join(CORE, "moe_gpu_plan.mojo")).read()
    out.append(f"moe_gpu_plan.mojo: {len(mgp.splitlines())} lines; device_budget param: {'device_budget_bytes' in mgp}; separate-pool wording 'usable device budget': {'usable device budget' in mgp}")
    out.append(f"moe_gpu_plan mentions integrated/shared pool: {'integrated' in mgp.lower()}")
    pp = open(os.path.join(CORE, "placement_pressure.mojo")).read()
    out.append(f"placement_pressure.mojo: {len(pp.splitlines())} lines; one contested pool per call: {'per contested' in pp}; fixed-first: {'FIXED FIRST' in pp}")
    # integrated mentions across core
    hits = []
    for f in sorted(os.listdir(CORE)):
        if f.endswith(".mojo"):
            for i, line in enumerate(open(os.path.join(CORE, f), errors="replace"), 1):
                if re.search(r"integrated|igpu|iGPU", line):
                    hits.append(f"{f}:{i}: {line.strip()}")
    out.append(f"integrated/iGPU hits in core/*.mojo: {len(hits)}")
    for h in hits: out.append(f"  {h}")
    for tool in ("nvidia-smi", "vulkaninfo"):
        out.append(f"tool {tool}: {shutil.which(tool) or 'ABSENT'}")
    for p in ("/dev/dri", "/sys/class/drm"):
        out.append(f"{p}: {'dir entries='+str(os.listdir(p)) if os.path.isdir(p) else 'ABSENT'}")
    mem = open("/proc/meminfo").read()
    mm = re.search(r"MemAvailable:\s+(\d+) kB", mem)
    out.append(f"MemAvailable: {mm.group(1)} kB" if mm else "MemAvailable: unreadable")
    sys.stdout.write("\n".join(out) + "\n")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
