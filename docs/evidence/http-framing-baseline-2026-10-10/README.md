# HTTP framing baseline — 2026-10-10

AES500-262 baseline at revision `a69d9e8c206237a8d530c1a92c899cea1c6e9a9d`.

- Pixi `0.76.2`; Mojo `1.0.0 (ed45d567)`.
- `aesir_engine/server/local_protocol.mojo`: SHA-256
  `4a472b202419269d89636e5e213ff7a35b2eb1a953c1cb154e4d50e052ff8148`.
- `aesir_engine/server/local_transport.mojo`: SHA-256
  `f02447408dcc2cfb29bb9e2afc0b54efd3fc0638bbb798af3ef89d5ad6cea618`.
- `aesir_engine/tests/test_local_protocol.mojo`: SHA-256
  `99fbb5a7708e91ab3ef424a3eb5c5b6d2a15439ba8842cb2a9d483b4a7122466`.
- `docs/NATIVE_SERVICE.md`: SHA-256
  `34538a0b04bd409adbe44463b5425e8e8e24fe8d3d7eaaea4231a9c1e2495967`.
- `docs/API_SUPPORT_MATRIX_V1.md`: SHA-256
  `e4c8c6fe0ac10c5fd7708eab488f48ca45670398d2400851a697999f64c5d08d`.

Existing unit cases reject HTTP/1.0, bare LF, repeated Host, transfer encoding,
folded lines, signed/negative content length, and line injection. The live
parser lowercases header names before duplicate detection, rejects Expect and
Transfer-Encoding, validates request-line protocol/shape, requires Host,
applies auth/status policy, and prevents body admission on non-200 status.
Remaining gaps for the next test slice include case-variant duplicate names,
Expect, simultaneous CL+TE, method/body status policy and CRLF edge cases.

This baseline is a source/test inventory. It does not assert a newly executed
test result.
