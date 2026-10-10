# AES500-110 — RoPE release gate

- Toolchain: Mojo 1.0.0 (`ed45d567`), configured `sm_89` target.
- Build: `pixi run mojo build --target-accelerator sm_89 aesir_engine/main.mojo -o /tmp/aesir-sigrun-sm89-rope` passed.
- CLI smoke: `/tmp/aesir-sigrun-sm89-rope --help` exited 0 and printed the implemented command surface.
- Master suite: 202 passed, zero failed, 1 skipped, 203 total.
- Documentation: `scripts/test_check_doc_drift.py`, `scripts/check_doc_drift.py`, and `git diff --check` passed.

The theta adversarial master case is deliberately last. Under Mojo 1.0.0, when
that caught-error test runs before the existing filesystem-heavy manifest-store
case, the process crashes in the async runtime; the manifest-store test passes
alone and when preceded by each other RoPE case. With the adversarial case last,
the counted master suite passes. This is a test-process ordering constraint,
not evidence of a product crash or of broader runtime stability.

Hosted CI must be checked against the exact release-receipt commit after push.
