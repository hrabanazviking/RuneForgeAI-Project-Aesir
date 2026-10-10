# Security threat-model baseline — 2026-10-10

AES500-362 baseline at revision
`f4cc2648e388908da55e96ea711a20507924ce9c`.

Pre-update SHA-256 values:

- `SECURITY_POSTURE.md`:
  `e01a827708fd22971c5d2a2332a0774b87e37301de26aa8ded49678fd8c81133`.
- `docs/NATIVE_SERVICE.md`:
  `34538a0b04bd409adbe44463b5425e8e8e24fe8d3d7eaaea4231a9c1e2495967`.
- `CAPABILITY_LEDGER.md`:
  `6bec10e2ce697857e7d783cb2a860c5eed19aa5ad9a4cecff89f4c8cd35c1864`.

The security posture already has a status warning and the native service guide
contains the detailed local-service controls. The capability ledger's AES-OPS-
003 paragraph still said there was no complete threat model/auth policy, which
did not distinguish the target document from current local evidence. Existing
service reproduction is `python scripts/test_native_service.py --binary ./aesir`
with pinned model fixtures; this documentation baseline does not rerun it.
