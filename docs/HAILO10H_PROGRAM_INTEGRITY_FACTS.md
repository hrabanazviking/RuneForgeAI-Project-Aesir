# Original program integrity facts

Date: 2026-10-20. Facts before implementation under
`TASK_hailo10h_program_integrity.md` and the unchanged owner scope.

## Pinned interfaces and checksum domains

HailoRT `d503417f2a0db186a838390fb08690c4ea0f415e` (MIT),
`libhailort/src/hef/hef.cpp` lines 338–351, 419–440, 514–527,
589–607 and 725–751, and `common/utils.hpp` Xxhash call boundaries:

- Version 3 has a 56-byte header. Its integer fields use big endian storage;
  the two checksum fields contain unsigned 64-bit values.
- With a nonzero protobuf checksum, the initial parser checks exactly the
  protobuf bytes at offset 56. It retains the residue hash as metadata without
  checking the rest of the file in this branch. Padding, CCWs and additional
  information are outside this checksum range.
- With a zero protobuf checksum, the parser hashes all bytes after the header,
  including protobuf, padding, CCWs and additional information. The residue size
  is actual file size minus 56; validation also requires that size to equal
  protobuf size plus padded CCW size plus additional size. Trailing bytes are
  therefore not an unchecked extension of that branch.
- Buffer calls use `XXH3_64bits`; stream calls reset/update/digest the same
  unseeded 64-bit variant. A stream position guard restores the prior position.
  The 256 KiB read chunk is not an algorithm/domain parameter.
- The original Aesir validator will require checked exact section extents in
  both branches, even where the reference's early protobuf-only check does not.
  It will report which domain was checked. A successful protobuf-only result
  must not claim that the complete residue was checked.

These outer checksums are noncryptographic corruption checks. They neither
supply nor establish the firmware LCU/CCW CRC algorithm, instruction encoding,
physical placement, target compatibility, protobuf semantics or NPU execution.

## Canonical algorithm specification

The HailoRT manifest pins xxHash 0.8.2 commit
`bbb27a5efb85b92a0486cf361a8635715a53f6ba`. Read its BSD-2-Clause LICENSE
before its canonical `doc/xxhash_spec.md`, document version 0.2.0 (2023-06-29).
No external algorithm implementation was inspected or copied for this slice.

Sources:

- [Pinned license](https://github.com/Cyan4973/xxHash/blob/bbb27a5efb85b92a0486cf361a8635715a53f6ba/LICENSE)
- [Pinned algorithm specification](https://github.com/Cyan4973/xxHash/blob/bbb27a5efb85b92a0486cf361a8635715a53f6ba/doc/xxhash_spec.md)

The specification covers all required unseeded XXH3-64 lengths: empty, 1–3,
4–8, 9–16, 17–128, 129–240 and 241+ bytes. Input/secret words are little
endian, independently of big endian output-header storage. All digest arithmetic
wraps modulo 2^64; full 64 by 64 products retain both 64-bit halves before XOR
folding. The required default seed is zero and the default secret is 192 bytes.
The published constant bytes and primes are algorithm data, not device data.

Small input paths combine overlapping edge words and length; their specified
mixing differs by length class. Medium paths accumulate folded 16-byte mixes,
with an intermediate avalanche above 128 bytes. Large paths have eight lanes,
64-byte stripes and 1024-byte blocks with the default secret. Complete blocks
are scrambled only while more than one block remains. The final stripe is the
last 64 input bytes (including overlaps), using secret offset 121; final merge
uses offset 11. This avoids dropping exact-block tails or adding a scramble to
the final block. Specification formulas/constants define the numerical contract;
no alternative XXH64 or XXH3-128 checksum is interchangeable.

## Original implementation contract

Implement a borrowed byte-list window hash with explicit positive work bound,
checked offset/length subtraction before indexing, no input copy or external
runtime hash dependency. Cover all above length classes; no hidden algorithm
size cap. Use fixed eight-lane state and independently implement the full
multiplication fold from 32-bit partial products if needed. Provide exact
version-3 selected-domain validation over an owned caller-provided file buffer,
using the existing original header/layout codec. Return domain/offset/count/
computed checksum facts, not a hardware-admission flag. Do not open a device,
parse vendor compiled models, run a model, or submit a program.

Verification: deterministic and randomized byte vectors, every small/medium
length, all stripe/block boundaries, multiple blocks, unaligned windows,
zero/maximum byte patterns, modular overflow, exact bounds, malformed extents,
selected/unselected tampering and value ownership. Use the installed BSD licensed
libxxhash 0.8.1 only as an isolated test oracle, record its exact binary hash and
reported version; it is not linked/imported by production Mojo. Also pin literal
known-vector results in tests. Preserve failed evidence and any discovered
specification discrepancy; do not silently adapt to an oracle.

## Specification attribution

This document extracts facts and summarizes the specification; it omits all
128-bit and seeded/custom-secret algorithms and is not a reproduction of it.
The following notice is retained from the specification:

Copyright (c) Yann Collet

Permission is granted to copy and distribute this document for any purpose and
without charge, including translations into other languages and incorporation
into compilations, provided that the copyright notice and this notice are
preserved, and that any substantive changes or deletions from the original are
clearly marked. Distribution of this document is unlimited.
