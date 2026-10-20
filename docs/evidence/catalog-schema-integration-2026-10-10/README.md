# Model catalog schema lifecycle integration — 2026-10-10

AES500-216 integration evidence from the existing separate-process lifecycle
harness. This verifies the durable CLI route and filesystem state transitions in
one local Linux run; it is not hosted CI evidence.

## Identity and command

- Repository revision before this evidence receipt: `8d9d33df314bc4c5ed0ca26ab73f04218c5c0476`
- Native binary: `/tmp/aesir-catalog-schema-215`
- Native binary SHA-256: `e80ce0a1fd03dc245d0057a2d419424e879245d99d85816ee31d6f643b5566f9`
- Harness `scripts/test_catalog_lifecycle.py` SHA-256: `1ee5d8a3ec972279740b01ba3890e430bd6c6161f81d9597d4fc194f92b8627f`
- Command: `python3 scripts/test_catalog_lifecycle.py --binary /tmp/aesir-catalog-schema-215`
- Result: exit 0, `PASS catalog lifecycle: atomic legacy migration, immutable backup, validate-before-replace restore, rollback, and six-writer preservation`.

## Exercised paths

- Creates a v1 catalog through the native CLI and derives a legacy delimiter
  fixture from the stored manifest.
- Migrates only through the explicit `catalog migrate` command into a new store.
- Runs six concurrent native CLI writers and verifies all seven expected models.
- Backs up exact catalog bytes, refuses overwrite and symlink destinations.
- Restores a valid backup over a corrupt catalog; malformed and FIFO backups
  leave the catalog unchanged.
- Rejects restore when a referenced blob is absent and publishes no catalog.
- Rejects migration into a catalog-occupied destination and leaves bytes intact.

Scope limits: one local Linux filesystem/toolchain, generated Modelfile and
blob fixtures, six writers, no power-loss hardware experiment, and no hosted CI
conclusion. The separate catalog crash-atomicity interposition suite remains its
own evidence gate.
