# Secret redaction baseline — 2026-10-10

AES500-382 baseline at revision
`99224d2211c5ecaaaab4b1f06232b9b884689cdd`.

Pre-change SHA-256 values:

- `aesir_engine/cli/native_serve.mojo`:
  `de42cc84e46a25775966faaf69ffd925cc0b6061c6cff76c78a8f3bc450fbb20`.
- `aesir_engine/server/local_protocol.mojo`:
  `4a472b202419269d89636e5e213ff7a35b2eb1a953c1cb154e4d50e052ff8148`.
- `scripts/test_native_service.py`:
  `72814828f157c9801a7b4adfbb6f1b1568b004341875c1a716a153021b0bc544`.
- `docs/NATIVE_SERVICE.md`:
  `d84113540a6a6847c858ccd9ef225ca982ab58b50388e3ffedaa0eebfaa6501b`.
- `SECURITY_POSTURE.md`:
  `976523b883fe35f68b0bf2cc117652613253d27ae7899b637c5106de1bb9f2fb`.

The native service writes request sequence, phase, status, and elapsed time;
source inspection found no body or authorization logging. The opt-in real-CUDA
service probe already checked the valid bearer key and one successful prompt
were absent from the final log. It did not use canaries for a rejected
credential or malformed body and did not assert either marker was absent from
error payloads. The live service test requires pinned external GGUF fixtures
and an available CUDA device.
