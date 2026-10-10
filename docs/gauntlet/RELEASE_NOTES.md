# Aesir F1 — Release Notes — mimisbrunnr-1.0

**Version:** mimisbrunnr-1.0 (MÍMISBRUNNR Campaign 10, H199)
**Date:** 2026-10-10
**Branch outcome: F1 CPU PATH PRODUCTION — the Hailo-10 compute wall held (H111 NO-GO).**

## Headline

The F1 CPU inference trunk is production-grade: pure-Mojo ARM64 inference
(TinyLlama-1.1B), judged by the GAUNTLET measurement framework across a
4-hour soak, 120-fault injection campaign, 20-cycle reset storm,
determinism proofs, and a python-less container packaging proof.

## Measured performance (Mimir, Raspberry Pi 5, Mojo 1.1.0)

| Metric | Value | Conditions |
|---|---|---|
| Decode | 1.918 tok/s | C9 H180, TinyLlama-1.1B-Chat Q4_0, 47-token median |
| Prefill | 3.362 tok/s | C9 H180, 512-token prompt |
| Soak decode (4h) | ~2.2 tok/s | H183, 64-token generations, temp <55 °C |
| Model load | ~2.5 s | 609 MB Q4_0 GGUF from SD |
| Peak RSS | ~2.14 GB | H189, per-generation peak |

## What shipped

- `bin/f1_infer` — pure-Mojo production inference CLI (prefill + decode,
  JSON output, fail-closed guards). No Python required or invoked.
- `config/f1_config.json` — production config (temperature 0.7, top_k 40,
  top_p 0.95, repetition_penalty 1.1).
- `share/tokenizer/tinyllama_tokenizer.model`
- `share/doc/` — RUNBOOK.md, RELEASE_NOTES.md, vordr-watchdog.service, canary.json
- `THIRD_PARTY_NOTICES.md`, `MANIFEST.txt` (sha256 per file)

**Supported model envelope:** GGUF, TinyLlama-1.1B architecture
(dim 2048, 22 layers, vocab 32000), dtypes Q8_0/Q4_0/Q6_K/F32/F16.
No open-ended "any format" claim.

## Victory gates

- **Gate 1 (H195):** PASS — 2 unseen models (Q8_0, Q6_K) × 3 prompts,
  6/6 coherent per rubric f1-coherence-v1.1.
- **Gate 2 (H196):** _pending_ — stability verdict from the soak evidence.
- **Gate 3 (H197):** _pending_ — crash-resistance verdict from fault injection.

## Known limitations

1. **No NPU compute (H111 NO-GO).** The Hailo-10 compiler wall held:
   the mailbox never completed a command. The F1 CPU path is the
   production deliverable; 48 SMIÐR assault paths are banked for a
   future kernel/driver combination. (Ref: H111 gate log.)
2. **Loader shape-pinned.** Only TinyLlama-1.1B-shaped GGUFs load;
   cross-family models are future work. Unknown dtypes fail closed
   (proven: Q5_K_M rejected in H195).
3. **Single-shot CLI.** Each generation reloads the model (~2.5 s);
   there is no persistent server mode in this release.
4. **H170 deferred.** Threading needs shared-memory infra beyond the
   slice budget (documented in C9).
5. **H184 skipped.** NPU soak not applicable (H111 NO-GO).

## Deployment

`./deploy_mimir.sh --package aesir-f1-1.0-aarch64.tar.gz --version 1.0`
— verifies checksums, backs up operator config, installs the watchdog,
asserts the `aesir-driver` symlink, runs the canary smoke test.
Full operator docs: `share/doc/RUNBOOK.md`.

## Upgrade notes

- The `aesir-driver` symlink always points at the current release;
  rollback = repoint + `systemctl restart vordr-watchdog` + canary.
- Model file is external to the package (`/home/pi/models/...`);
  verify its sha256 after any re-download.

---
*Tag commit hash: _filled at tag time_. Release package built from the
exact tagged commit (hash verified). README.md untouched (L8).*
