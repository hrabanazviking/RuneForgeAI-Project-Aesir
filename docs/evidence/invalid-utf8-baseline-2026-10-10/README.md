# AES500-172 invalid UTF-8 baseline

The baseline uses `String(unsafe_from_utf8_ptr=...)` with explicit NUL-terminated
buffers, so results apply only to this unsafe construction path:

- A truncated lone `C3` byte with no vocabulary returns raw ID `[195]`.
- Invalid `C3 28` with a byte-token vocabulary encodes as IDs `[11,12]` for
  `<0xC3>` and `<0x28>`; the current tokenizer preserves the malformed bytes
  through its fallback path rather than validating UTF-8.

Baseline revision: `746fe05a3bba0a0741f57503a201131e6ed7bf9a`. Mojo:
`1.0.0 (ed45d567)`. `tokenizer.mojo` SHA-256:
`3d576f318599a336b801b2101991c8694141ddf8ec8179ee438e13a1c1c683d8`.
Probe hash: `d31972f1356925a47406b4c5b49201e2f20255aca8eaded42969bc476d8276be`.

The master suite passes 227 named cases, zero fail, one external-fixture skip
(228 total). This is not evidence that safe Mojo String constructors admit
malformed UTF-8 or that the tokenizer validates arbitrary byte buffers.
