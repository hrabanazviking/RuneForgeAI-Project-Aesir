# MÍMISBRUNNR — Final Verdict (H200)

**Date:** 2026-10-10
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
| Phase-C bring-up | H095 | _see gate log_ |
| **H111 Compiler Wall** | H111 | **NO-GO — the wall held** |
| Phase-E | H128 | _see gate log_ |
| Victory gates | H195–H197 | _below_ |

## The wall (H111)

SMIÐR's faithful mailbox implementation: command writes land
readback-verified, then silence — no completion bit, no MSI, no
response. Exhausted: 5 hardening variants, vendor ioctl rejected,
core-doorbell probe silent. The encoding face stays honestly UNKNOWN.
Ambition was fully pursued; the evidence forced NO-GO.

## Victory gates

- **Gate 1 (H195):** PASS — 2 unseen models × 3 prompts, 6/6 coherent.
- **Gate 2 (H196):** _pending soak evidence_
- **Gate 3 (H197):** _pending FI evidence_

## Final measured performance

| Metric | Value |
|---|---|
| Decode | 1.918 tok/s (C9) |
| Prefill | 3.362 tok/s (C9) |
| Soak (4h) | _pending_ |
| Fault injection | _pending_ |

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
- L8 README.md untouched: `git log -- README.md` shows no campaign commits.
- L9 zero cuda_* edits: _verify_
- L10 ledger honesty: H193 audit.
- L11 honest degradation: H159 audit + v1.1 rubric changelog.
- L12 device code only in HAILBRÚ: H147 grep audit.

## FINAL VERDICT

_pending all gates_
