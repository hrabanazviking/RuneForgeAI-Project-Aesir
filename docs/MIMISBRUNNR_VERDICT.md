# MÍMISBRUNNR — Final Verdict (H200)

**Date:** 2026-10-11
**Campaign:** 200 slices, H001–H200, 10 campaigns
**Author:** Yrsa Freydisdottir (MÍMISBRUNNR forge worker)

## The story

MÍMISBRUNNR set out to run a small open LLM on the Hailo-10 NPU —
bare-metal Mojo, no vendor toolchain, no HEF, clean-room only. Ten
campaigns: recon (C1), the ARMVEGR CPU engine (C2–C3), the HAILBRÚ PCIe
driver (C4), bring-up (C5), SMIÐR's assault on the compiler wall (C6),
the F1 CPU fallback trunk (C7), VÖRÐR robustness (C8), speed (C9), and
the GAUNTLET production hardening (C10).

## Phase-gate verdicts

| Gate | Slice | Verdict |
|---|---|---|
| Phase-A recon | H010 | GO-WITH-CONDITIONS |
| Phase-B mechanism | H077 | NO-GO (kernel) → UNLOCKED by Volmarr's operator rebuild (6.12.112-v8-16k-hailo+, VFIO live) |
| Phase-C bring-up | H095 | DONE (re-scoped: 100 PM-cycles, golden checks every 10th, C5) |
| **H111 Compiler Wall** | H111 | **NO-GO — the wall held** |
| Phase-E | H128 | N/A (GO-only; H111 was NO-GO) |
| Victory gates | H195–H197 | _below_ |

## The wall (H111)

SMIÐR's faithful mailbox implementation: command writes land
readback-verified, then silence — no completion bit, no MSI, no
response. Exhausted: 5 hardening variants, vendor ioctl rejected,
core-doorbell probe silent. The encoding face stays honestly UNKNOWN.
Ambition was fully pursued; the evidence forced NO-GO.

## Victory gates

- **Gate 1 (H195):** PASS — 2 unseen models (Q8_0 + Q6_K, downloaded
  fresh) × 3 prompts, 6/6 coherent per rubric f1-coherence-v1.1.
- **Gate 2 (H196):** PASS — 9/9 stability gates green: soak error rate
  0, duration 4.004h, drift 1.48% (≤10%), FI unhandled 0, FI crashes 0,
  recovery rate 1.0, determinism 1.0, RSS slope −0.37 MB/h (≤1),
  coherence rate 1.0.
- **Gate 3 (H197):** PASS — 124 faults injected = 124 handled across
  hang/regerr/dmacorrupt, 0 child crashes, 20/20 reset-storm
  recoveries; every fault class reconciled automatically.

## Final measured performance

| Metric | Value |
|---|---|
| Decode | 1.918 tok/s (C9 H180) |
| Prefill | 3.362 tok/s (C9 H180) |
| Soak (4h) | 393 generations, 0 crashes, 0 hangs; median decode 2.157 → 2.189 tok/s (first vs last 30 min), drift 1.48%; H185 analysis: all metrics DRIFT-FREE |
| Fault injection | 124/124 handled in 60.7 min (hang 39, regerr 50, dmacorrupt 35), 0 crashes, 10/10 coherence spot-checks clean |
| Reset storm | 20/20 SIGKILL→respawn recoveries, max restart 1.0 ms vs 44 ms H155 budget, outputs bit-identical |
| Determinism | 5 prompts × 10/10 identical + 5/5 post-restart identical |
| Memory | RSS slope −0.37 MB/h over the soak — no leak |
| Packaging | Self-contained tarball (binary + bundled runtime libs, $ORIGIN rpath) runs inference in a python-less container; deployed to /home/pi/aesir-f1-1.0, canary PASS |

## Known limitations

1. No NPU compute (H111 NO-GO); 48 assault paths banked.
2. Loader shape-pinned to TinyLlama-1.1B; unknown dtypes fail closed.
3. Single-shot CLI; no server mode.
4. H170 deferred (threading infra).
5. H184 skipped (NO-GO branch).

## Law compliance (evidence-cited)

- L3 no HEF ever: H135/H195 scans (no .hef, no HEF handling in code).
- L4 no proprietary toolchain: pure Mojo 1.1.0, ldd shows toolchain runtime + POSIX only.
- L5 clean-room only: CLEAN_ROOM_LOG.md (H005/H006/C6).
- L6 no banned licenses: H194 scan — no GPL/LGPL/AGPL/proprietary linkage.
- L7 no firmware shipped: H190 package artifact scan.
- L8 README.md untouched: verified — `git diff origin/main...HEAD -- "*README.md"` is empty (0 files).
- L9 zero cuda_* edits: verified — `git diff origin/main...HEAD -- "*cuda_*"` is empty (0 files).
- L10 ledger honesty: H193 audit.
- L11 honest degradation: H159 audit + v1.1 rubric changelog.
- L12 device code only in HAILBRÚ: H147 grep audit.

## FINAL VERDICT

_pending all gates_
