# AES500-120 — Causal attention release gate

- Toolchain: Mojo 1.0.0 (`ed45d567`), configured `sm_89` target.
- Native build: `pixi run mojo build --target-accelerator sm_89 aesir_engine/main.mojo -o /tmp/aesir-sigrun-sm89-attention` passed.
- CLI smoke: `/tmp/aesir-sigrun-sm89-attention --help` exited 0.
- Master suite: 206 passed, zero failed, 1 skipped, 207 total.
- Repository consistency: `scripts/test_check_doc_drift.py`, `scripts/check_doc_drift.py`, and `git diff --check` passed.

These local checks do not establish hosted CI, accelerator attention execution,
performance, broad numerical tolerance, or pointer/index safety. Hosted CI is
recorded only against the exact pushed receipt SHA when visible.
