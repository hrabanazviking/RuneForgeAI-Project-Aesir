# Model catalog schema adversarial evidence — 2026-10-10

AES500-217 reuses existing native filesystem adversarial harnesses. These
results are local Linux evidence against a built CLI, not hosted CI.

## Identity

- Repository revision before receipt: `d9ea3acabc5e18e92a1f361ce75277121c774b3e`
- Binary `/tmp/aesir-catalog-schema-215` SHA-256: `e80ce0a1fd03dc245d0057a2d419424e879245d99d85816ee31d6f643b5566f9`
- Crash harness `scripts/test_catalog_crash_atomicity.py` SHA-256: `ee22f3e65c487f9c7d37977b17eaa62840f02b16b0c866a952ceac1f918ab1a3`
- Special-file harness `scripts/test_special_file_admission.py` SHA-256: `734f1d7588561ecb4187077800eb61b06d299cb9c9fccd726edf2e889926e0bf`

## Results

- `python3 scripts/test_catalog_crash_atomicity.py --binary /tmp/aesir-catalog-schema-215` — exit 0. Test-only interposition kills the writer after staged write, staged-file fsync, rename, and directory fsync. Restart observes only old or complete new catalog bytes and remains writable.
- `python3 scripts/test_special_file_admission.py --binary /tmp/aesir-catalog-schema-215` — exit 0. Catalog FIFO and other named special-file admissions fail closed without blocking.

These are process-kill and FIFO checks in the local Linux environment; they do
not establish power-loss durability across hardware, filesystems beyond this
host, or external compatibility with third-party catalog formats.
