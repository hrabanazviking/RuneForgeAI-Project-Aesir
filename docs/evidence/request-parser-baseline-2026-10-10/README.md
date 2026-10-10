# Request parser baseline — 2026-10-10

AES500-252 baseline at source revision `69a2056008141f10926533387ece1be046b0bcc4`.

- Pixi `0.76.2`; Mojo `1.0.0 (ed45d567)`.
- `aesir_engine/server/local_transport.mojo` SHA-256:
  `f02447408dcc2cfb29bb9e2afc0b54efd3fc0638bbb798af3ef89d5ad6cea618`.
- `aesir_engine/server/local_protocol.mojo` SHA-256:
  `4a472b202419269d89636e5e213ff7a35b2eb1a953c1cb154e4d50e052ff8148`.
- `aesir_engine/tests/test_local_protocol.mojo` SHA-256:
  `8dcd2dc7dc78585cb2f9ec93f73b94bca1e7f170407135a46722f7c0f1d181f9`.
- `docs/API_SUPPORT_MATRIX_V1.md` SHA-256:
  `45af27632faca2a55cb8926386c4a540e63fbb0fd516b651a37418efc24c4f30`.

Current source reads headers one byte at a time until CRLFCRLF, capped at 8192
bytes; it rejects NUL, partial EOF, deadline expiry and malformed/unsupported
framing. The typed head parser accepts at most 64 unique ASCII header names,
limits values to 1024 bytes, requires HTTP/1.1, validates Host/auth/method,
rejects transfer-encoding and Expect, and caps content length at 131072.
Bodies allocate declared length plus one NUL sentinel and consume exactly that
many bytes under the same passed deadline; NUL body bytes reject. Existing
`test_local_protocol.mojo` already exercises malformed request heads and JSON;
remaining focused checks need oversized and exact-bound transport-byte evidence.

The checkout's model artifact is a zero-byte placeholder, but parser tests do not
require model inference. No test run is implied by this identity/inspection
baseline.
