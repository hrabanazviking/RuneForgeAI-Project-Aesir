# Source byte-digest primitive contract

Date:2026-10-22. Native contract:TASK_hailo10h_source_byte_digest.md.
This is a compiler content-identity prerequisite,not an immutable model snapshot,
physical memory fit or source-model execution proof. All existing fingerprint/
execution flags remain false.

Aesir already owns SHA256 compression in hailbru/fw.mojo. The next leaf reuses
that original implementation with bounded incremental ownership and same-fd
source-window reads. It introduces no second compression algorithm,external
crypto dependency,firmware operation or model compiler. Indexed processing avoids
copying the remaining64KiB chunk after each compressed block,as the older path
wrapper currently does. The original wrappers remain unchanged.

Source windows use existing regular-fd extent and positional ARM64 read helpers,
with explicit byte/read-call budgets and a4096-byte host buffer. Actual size is
checked on the same borrowed descriptor before/after reading. A digest identifies
the observed byte stream;concurrent same-size changes and parsed-metadata/artifact
coherence remain separate work. No new mmap payload reads or borrowed-fd closure.

Mathematical reference:[FIPS180-4,August2015](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf).
Published [NIST SHA256 example data](https://csrc.nist.gov/csrc/media/projects/cryptographic-standards-and-guidelines/documents/examples/sha256.pdf)
provide one- and two-block message/digest checks. These facts inform tests of the
existing original compression plus new streaming wrapper;no external code body
is adopted and no cryptographic certification is claimed. The csrc /final PDF
URL serves archived2012 text;the cited nvlpubs document is the August2015 edition.

Pre-code evidence:docs/evidence/source-digest-contract-2026-10-22. All649 Mojo
identities/actual snapshots,102 current native controls and66 Python identities
are preserved and verified before new code. Direct PDF retrieval returned403;
the official documents were read with the web tool,no workaround or raw local
PDF hash is claimed. Both published example values agree with Python hashlib;
no new native digest/source-identity implementation has run in this qualification.

Numerical H10H instructions/configuration/precision/packing/placement,valid
original-program delivery/activation/results/cleanup and broad unmodified model
execution remain open under the fixed owner target. This hash leaf does not
change supported model formats,architectures or operation eligibility.

## Native qualification completed

The original leaf is verified under `HAILO10H_MOJO_SOURCE_BYTE_DIGEST.md`: eight
clean builds, 451 new calls and 454 complete selected legacy comparisons. All
previous production sources and fingerprint flags remain unchanged. This advances
observed byte hashing only; immutable source/coherent artifact binding remains
the next content-identity gate.
