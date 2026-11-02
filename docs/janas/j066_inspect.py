#!/usr/bin/env python3
"""J-066 inspection: Aesir's GPU surface and the Vulkan question.

Machine-generated anchors for docs/janas/J066_VULKAN_QUESTION.md.
Recounts, from this tree: the CUDA kernel/session surface a Vulkan
compute path would have to reproduce, every Vulkan reference in
code, the CUDA-only guards on the MAX device abstraction, and this
machine's Vulkan/CUDA environment (the spike's feasibility).

Clean-room: this script reads only Aesir's own tree. No Janas
material of any kind is opened.
"""
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CORE = os.path.join(ROOT, "aesir_engine", "core")


def defs(path):
    txt = open(path).read()
    return re.findall(r"^def ([A-Za-z_][A-Za-z0-9_]*)", txt, re.M), txt


def main():
    out = []
    out.append("J-066 INSPECT -- Aesir GPU surface / Vulkan environment")
    out.append(f"tree root: {ROOT}")

    # --- kernel surface, per file ---
    total_kernel_defs = 0
    for name, want in [
        ("packed_projection.mojo", None),
        ("llama3_kernels.mojo", None),
        ("gemma4_kernels.mojo", None),
        ("cuda_compute.mojo", None),
        ("llama3_cuda.mojo", None),
        ("fused_causal_attention.mojo", None),
        ("fused_small_attention.mojo", None),
        ("packed_matrix.mojo", None),
    ]:
        d, txt = defs(os.path.join(CORE, name))
        out.append(f"{name}: {len(txt.splitlines())} lines, defs={d}")
    # the pinned families (see doc section 2)
    llama_defs, _ = defs(os.path.join(CORE, "llama3_kernels.mojo"))
    gemma_defs, _ = defs(os.path.join(CORE, "gemma4_kernels.mojo"))
    gemma_kernels = [d for d in gemma_defs if d.endswith("_kernel")]
    compute_defs, _ = defs(os.path.join(CORE, "cuda_compute.mojo"))
    packed_defs, _ = defs(os.path.join(CORE, "packed_projection.mojo"))
    llama_sess_defs, _ = defs(os.path.join(CORE, "llama3_cuda.mojo"))
    sess_kernels = [d for d in llama_sess_defs if d.endswith("_kernel")]
    fused = []
    for f in ("fused_causal_attention.mojo", "fused_small_attention.mojo", "packed_matrix.mojo"):
        dd, _ = defs(os.path.join(CORE, f))
        fused += [d for d in dd if d.endswith("_kernel")]
    total = (len(packed_defs) + len(llama_defs) + len(gemma_kernels)
             + len(compute_defs) + len(sess_kernels) + len(fused))
    out.append(f"PINNED llama3_kernels device functions: {len(llama_defs)}")
    out.append(f"PINNED gemma4_kernels *_kernel functions: {len(gemma_kernels)}")
    out.append(f"PINNED cuda_compute kernels: {len(compute_defs)}")
    out.append(f"PINNED packed_projection matvec forms: {len(packed_defs)}")
    out.append(f"PINNED llama3_cuda session kernels: {len(sess_kernels)} {sess_kernels}")
    out.append(f"PINNED fused/packed-matrix kernels: {len(fused)} {fused}")
    out.append(f"PINNED TOTAL kernel families to port: {total}")

    # --- sessions ---
    for name, struct in [("llama3_cuda.mojo", "Llama3CUDASession"),
                         ("gemma4_cuda.mojo", "Gemma4CUDASession")]:
        txt = open(os.path.join(CORE, name)).read()
        out.append(f"{name}: struct {struct} present: {struct in txt}; "
                   f"lines={len(txt.splitlines())}")

    # --- the abstraction seam ---
    mojo_files = [f for f in os.listdir(CORE) if f.endswith(".mojo")]
    maxgpu = []
    guards = []
    for f in sorted(mojo_files):
        txt = open(os.path.join(CORE, f)).read()
        if "from max.gpu" in txt:
            maxgpu.append(f)
        for i, line in enumerate(txt.splitlines(), 1):
            if 'api() != "cuda"' in line:
                guards.append(f"{f}:{i}")
    out.append(f"core/*.mojo importing max.gpu: {len(maxgpu)} {maxgpu}")
    out.append(f'api() != "cuda" guards in core: {len(guards)} {guards}')

    # --- Vulkan surface in code ---
    vk_hits = []
    for dirpath, _dirs, files in os.walk(os.path.join(ROOT, "aesir_engine")):
        for f in files:
            if f.endswith(".mojo"):
                p = os.path.join(dirpath, f)
                for i, line in enumerate(open(p, errors="replace"), 1):
                    if re.search(r"vulkan|spirv|spir-v|glsl", line, re.I):
                        vk_hits.append(f"{os.path.relpath(p, ROOT)}:{i}: {line.strip()}")
    out.append(f"Vulkan/SPIR-V/GLSL hits in .mojo code: {len(vk_hits)}")
    for h in vk_hits:
        out.append(f"  {h}")

    # --- AMD gate (the competing AMD road) ---
    amd = open(os.path.join(CORE, "amd_gate.mojo")).read()
    out.append(f"amd_gate.mojo: 'not implemented' occurrences: "
               f"{amd.count('not implemented')}; "
               f"get_device_count returns 0: {'return 0' in amd}")

    # --- environment: can a spike run here? ---
    for tool in ("vulkaninfo", "glslangValidator", "glslc", "nvcc", "nvidia-smi"):
        out.append(f"tool {tool}: {shutil.which(tool) or 'ABSENT'}")
    for p in ("/dev/dri", "/dev/nvidia0", "/usr/share/vulkan/icd.d", "/etc/vulkan/icd.d"):
        if os.path.isdir(p):
            out.append(f"{p}: directory, entries={os.listdir(p)}")
        else:
            out.append(f"{p}: ABSENT")
    out.append(f"libvulkan.so.1 present: {os.path.exists('/usr/lib/x86_64-linux-gnu/libvulkan.so.1')}")
    out.append(f"libcuda present: {os.path.exists('/usr/lib/x86_64-linux-gnu/libcuda.so.1')}")
    mem = open("/proc/meminfo").read()
    m = re.search(r"MemAvailable:\s+(\d+) kB", mem)
    out.append(f"MemAvailable: {m.group(1)} kB" if m else "MemAvailable: unreadable")

    text = "\n".join(out) + "\n"
    sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
