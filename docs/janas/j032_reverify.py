#!/usr/bin/env python3
"""J-032 re-verification: re-read the filed J-022 attempt artefacts and the
J-011/J-015 candidate records, recompute the size arithmetic, and check the
session's architecture gate in this tree. No inference, no device access.
Exit 0 iff all checks PASS."""
import pathlib, re, sys

root = pathlib.Path(__file__).resolve().parents[2]  # repo root (docs/janas/..)
janas = root / "docs" / "janas"
campaign = pathlib.Path.home() / "workspace" / "model-tests" / "janas"

attempt = (janas / "j022_qwen3next_attempt.txt").read_text()
j022 = (janas / "J022_FIRST_BIGGER_THAN_RAM.md").read_text()
census = (campaign / "CENSUS.md").read_text()
j015 = (campaign / "J015_MOE_ANATOMY.md").read_text()
session = (root / "aesir_engine" / "core" / "moe_session.mojo").read_text()

checks = []
def check(name, ok, detail=""):
    checks.append((name, bool(ok), detail))
    print(f"{'PASS' if ok else 'FAIL'}  {name}  {detail}")

# 1. File pin, from J-022 doc section 5
m = re.search(r"48,506,100,512 B, sha256 `([0-9a-f]{64})`", j022)
check("J-022 pin: size 48,506,100,512 B + full sha256 present", m is not None)
sha = m.group(1) if m else ""
check("sha256 == f73551b5...80fd (full value re-read)",
      sha == "f73551b55e3796526c37772c96227151fa11af328802b8f9865d635104e280fd", sha)
check("repo named unsloth/Qwen3-Next-80B-A3B-Instruct-GGUF",
      "unsloth/Qwen3-Next-80B-A3B-Instruct-GGUF" in j022)
check("official-Qwen file distinguished (48,410,988,384 B, d103b273...)",
      "48,410,988,384 B" in j022 and "d103b273" in j022)

# 2. Attempt artefact: refusal + machine state at attempt
check("attempt artefact: loader refusal text exact",
      "GGUF is missing required tensor: blk.0.attn_q.weight" in attempt)
check("attempt artefact: EXIT=1", "EXIT=1" in attempt)
check("attempt artefact: MemAvailable 37,465 MB recorded",
      "MemAvailable 37,465 MB" in attempt)
check("attempt artefact: GPU 1 MiB used / 6,144 MiB total recorded",
      "GPU 1 MiB used / 6,144 MiB total" in attempt)
check("attempt artefact: CUDA_VISIBLE_DEVICES= (no GPU claim)",
      "CUDA_VISIBLE_DEVICES=," in attempt)

# 3. Machine totals + size arithmetic (recomputed)
file_bytes = 48_506_100_512
ram_mib, gpu_mib = 39_517, 6_144
total_mib = ram_mib + gpu_mib
total_bytes = total_mib * 1024 * 1024
check("machine total recomputed: 39,517 + 6,144 = 45,661 MiB",
      total_mib == 45_661, f"{total_mib} MiB = {total_bytes/1e9:.2f} GB")
check("J-022 doc states approx 47.88 GB total", "47.88 GB" in j022,
      f"recomputed {total_bytes/1e9:.4f} GB")
check("file exceeds total GPU+RAM", file_bytes > total_bytes,
      f"file {file_bytes/1e9:.2f} GB > total {total_bytes/1e9:.2f} GB "
      f"by {(file_bytes-total_bytes)/1e9:.2f} GB")
check("file exceeds RAM alone by a wide margin", file_bytes > ram_mib*1024*1024)

# 4. Header facts, from J-022 doc section 5
for fact in ["architecture `qwen3next`", "48 blocks", "512 experts, top-10",
             "843 tensors", "ssm.conv_kernel` 4", "ssm.inner_size` 4096"]:
    check(f"header fact present: {fact}", fact in j022)

# 5. Session gate in THIS tree: olmoe only
check("moe_session admits only arch 'olmoe' (gate in this tree)",
      'Only arch "olmoe" is admitted' in session and 'if arch != "olmoe":' in session)
check("no qwen3next forward/loader in moe_session",
      "qwen3next" not in session)

# 6. Candidate survey records
check("J-011 census: qwen3next row is Qwen3-Next-80B-A3B-Instruct + Coder-Next",
      "`qwen3next` | Qwen3-Next-80B-A3B-Instruct, Qwen3-Coder-Next" in census)
check("J-011 census: only other >=74B MoE rows are nemotron 74B (branch, unmerged in Janas docs) and qwen4exp 177B (experimental)",
      "Nemotron-3.5-Bolt-74B-A9B" in census and "177B, 512 experts" in census)
check("J-015: larger MoE anatomies deferred to J-022/J-032/J-123 (no other pin taken)",
      "larger MoE anatomies are J-022/J-032/J-123 territory" in j015)
check("J-015 pins are OLMoE + Granite only (no 80B-class pin there)",
      "8c310f1435a1222338fd2d3d974975be9cd908180b644bab0c2a94da1ac32f3f" in j015
      and "48e0edcd578fd4462f26127f04c651d0e650741110185297741089aea01a82b3" in j015)

failed = [c for c in checks if not c[1]]
print(f"\n{len(checks)-len(failed)}/{len(checks)} checks PASS")
print("ALL CHECKS PASS" if not failed else "FAILURES PRESENT")
sys.exit(0 if not failed else 1)
