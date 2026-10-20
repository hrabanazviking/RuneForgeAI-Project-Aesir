# HTTP framing rejection release gate — 2026-10-10

AES500-270 release verification against source revision `e8c3eb18331e05e290fd26a2a1faa87bcb2cf668`.

- Fresh sm_89 build `/tmp/aesir-http-framing-270` and CLI help passed.
- Binary SHA-256: `1906adace947ddaabd2e77b81763aed1c9e41bdf30362209149b2073d2f0cfbd`.
- Master suite: 249 passed, 0 failed, 1 skipped (250 total).
- Focused protocol module passed, including framing unit matrix.
- Doc tests/checker and `git diff --check` passed. Existing checker warnings remain limited to 24 duplicate assets, 7 generated executables, and one placeholder model.
- No physical model service or complete HTTP RFC/client compatibility result is claimed.
