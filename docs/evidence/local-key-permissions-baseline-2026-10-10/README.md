# Local key-file permission baseline — 2026-10-10

AES500-372 baseline at revision
`f55f8255b100cbf8007f6b3044757ee16c79b34b`.

Pre-change SHA-256 values:

- `aesir_engine/server/keyfiles.mojo`:
  `90dfcc92901ec72e770df92a10655f734bb17a730a80f1fcd71886f2397ecb54`.
- `aesir_engine/server/local_transport.mojo`:
  `f02447408dcc2cfb29bb9e2afc0b54efd3fc0638bbb798af3ef89d5ad6cea618`.
- `scripts/test_native_keygen.py`:
  `73d1b1c3807a16b5b59ebc844e7665e227ffda61bd078ab66ecc54c8e70ff6fe`.
- `scripts/test_native_service.py`:
  `751abef61e367482164184b2c1299bc1afef0426779411919bdad55e0d5facb5`.
- `docs/NATIVE_SERVICE.md`:
  `34538a0b04bd409adbe44463b5425e8e8e24fe8d3d7eaaea4231a9c1e2495967`.

Creation already requests mode 0600 with exclusive same-directory publication.
Admission uses `fstat` on an `O_NOFOLLOW|O_NONBLOCK` descriptor and rejects
nonregular files, foreign owners, and any group/world permission bits. Existing
keygen tests asserted mode 0600 under the host's default umask; service admission
tested mode 0644, symlink, FIFO, malformed lengths and token bytes. The
AES500-373/375 execution receipt broadens the mode matrix and exercises umask
000:

- `python3 scripts/test_native_keygen.py --binary /tmp/aesir-clean-cli-build`
  passed, including exact mode 0600 under umask 000, shape, distinctness,
  no-disclosure, no-overwrite, symlink, publication race, and temporary-link
  cleanup.
- `test_native_service.reject_keys()` against the same native CLI passed for
  modes 0640, 0604, 0620, 0602, 0666 and 0711, plus symlink, FIFO, short,
  oversized, and invalid-token files; each rejection preceded CUDA startup.
- Documentation, repository truth, and hygiene gates passed.

The CLI binary is from the clean-build receipt; service key admission code is
unchanged from the baseline revision. This evidence does not exercise a loaded
CUDA model or full service network session.
