# Socket ownership and shutdown baseline — 2026-10-10

AES500-242 baseline captured at revision `250cce6d546f6c25ef720f3c466e6a7eb39507d4`.

## Toolchain and source identity

- Pixi: `0.76.2`.
- Mojo: `1.0.0 (ed45d567)`.
- `aesir_engine/server/local_transport.mojo` SHA-256:
  `69ffa8ace97c6068051c1e93bd6445608d2008cf796a19e8ddfde7038ed77210`.
- `aesir_engine/cli/native_serve.mojo` SHA-256:
  `de42cc84e46a25775966faaf69ffd925cc0b6061c6cff76c78a8f3bc450fbb20`.
- `aesir_engine/server/INTERFACE.md` SHA-256:
  `e60464360888a05fd9fed7b0cf5f9290932c0bac47439ed4f5e9ec5da67b1b5f`.
- `docs/NATIVE_SERVICE.md` SHA-256:
  `34538a0b04bd409adbe44463b5425e8e8e24fe8d3d7eaaea4231a9c1e2495967`.
- Host observed: NVIDIA GeForce RTX 2060 with Max-Q Design, 6144 MiB.
- The repository's local model artifact is the known zero-byte placeholder, so
  no fresh physical service launch is possible from the current checkout.

## Baseline source trace

`OwnedFD.__deinit__` closes its owned descriptor. `listen_local` validates the
port and binds the listener to `127.0.0.1`. `accept_local` returns an owned
descriptor; `accept_local_ready` returns a raw descriptor that is immediately
wrapped at the `serve_loaded` queue boundary. Pending-client pop/detach transfers
that owner to the active request. `serve_loaded` owns its listener and pending
queue, while the interrupt descriptor is passed through polling/generation as a
borrowed descriptor. The current service serializes all requests through one
loaded session. `wait_io` bounds polling and detects cancellation, and
`serve_loaded` loops only while `GenerationControl.stop_reason()` is empty.

## Prior evidence and limits

The prior real-model harness receipts in
`docs/evidence/native-efficiency-2026-10-01/service-faults.txt` and
`docs/evidence/native-long-tokens-2026-10-01/final-service-faults.txt` are byte
identical (SHA-256
`81ab99b4cee06374d21d26f5e04d99b80cfd3317225638197443258f6f4b02b8`) and report
Llama3 authentication, framing/Unicode rejection, slow-client limits, deadline
recovery and shutdown. They are historical receipts, not a rerun against this
revision. This baseline makes no new physical GPU shutdown claim.
