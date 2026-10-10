# AES500-162 Unicode normalization baseline

With a byte-fallback vocabulary, composed `é` emits IDs `[11,12]` for bytes
`C3 A9`; decomposed `e` plus combining acute emits `[13,14,15]` for bytes
`65 CC 81`. RuneWeaver does not merge these canonical forms implicitly.

Baseline source revision: `34432bf25ba4ad5490670a2f850bd90971472e54`.
Mojo: `1.0.0 (ed45d567)`. `tokenizer.mojo` SHA-256:
`c76590350ff7c905d14820144e41475fc39edf7aa9aa78e00baebc2fb9e2b39d`.
Probe source pre-change SHA-256:
`0193d14bd4e1f7d28d1bd8a718a69ff2873a240989a88fe2d0f2c2f6cda7f120`.
The probe is `test_unicode_normalization_baseline` in
`aesir_engine/tests/test_tokenizer.mojo`.

The sm_89 master suite passes 223 named cases, zero fail, one external fixture
skip (224 total). These are deterministic local vectors, not Unicode
normalization conformance or broad multilingual fidelity evidence.
