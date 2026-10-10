# AES500-121 — GGUF header version admission contract

## Objective and owners

Define one bounded header-version admission rule before changing parser code.
Owners: `aesir_engine/loader/gguf.mojo::GGUFSeer._parse_header` for mapped
files and `GGUFSeer.parse_header_bytes` for in-memory header probes. This slice
is documentation only.

## Header shape and intended version matrix

The fixed 24-byte GGUF header uses little-endian fields: magic `GGUF` at bytes
0–3, UInt32 version at 4–7, UInt64 tensor count at 8–15, and UInt64 metadata
count at 16–23. The implemented inference slice supports version 3 only:

| Version | Intended admission | Reason |
|---:|---|---|
| 0, 1, 2 | reject | unsupported or invalid legacy version |
| 3 | admit past the version gate | supported version; later count/metadata/tensor checks still apply |
| 4 and larger | reject | future-version semantics are not implemented |

Both owning entry paths must enforce the same matrix and stable error class.
The mapped-file path already rejects any version other than 3. The current
`parse_header_bytes` helper checks minimum buffer size and magic only; it does
not inspect version or counts, so it diverges from the stated contract.

## Evidence boundary

This contract covers only fixed-header version admission. It does not claim
complete GGUF compatibility, full count arithmetic safety, metadata/tensor
directory validity, tokenizer behavior, external-model support, pointer
provenance, or model inference success. AES500-122 captures current behavior;
AES500-123 will test both paths before AES500-124 unifies them.

AES500-122's byte-buffer corpus accepts versions 0, 1, 2, 3, 4, and
`UInt32::MAX`; the reproduction and source identity are retained in
`docs/evidence/gguf-header-version-baseline-2026-10-10/README.md`. The mapped
file path's v3-only behavior is established by source inspection in this
baseline, not by a full per-version file corpus.

AES500-123's counted test writes minimal 24-byte mapped files. The raw-byte
helper admits all five tested values (0, 2, 3, 4, max UInt32), while mapped
files reject every non-3 value at the version gate; version 3 proceeds to a
later metadata error for this deliberately incomplete fixture.

## Acceptance

The version table, byte layout, both owners, existing discrepancy, and explicit
exclusions are stated. No parser code changes in AES500-121.
