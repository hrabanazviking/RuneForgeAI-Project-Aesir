# Original program integrity in Mojo

Date: 2026-10-20. Contract: `TASK_hailo10h_program_integrity.md`.
Facts and narrowed implementation contract were published first in
`HAILO10H_PROGRAM_INTEGRITY_FACTS.md`.

## Actual interface and proof

`smidr/program_integrity.mojo` implements default unseeded XXH3-64 directly in
Mojo from canonical algorithm facts. `xxh3_64_window(data,offset,count,work_bound)`
borrows a byte list, validates signed offsets/counts using subtraction before
indexing and requires a positive explicit work bound. Empty windows are valid.
All length classes are implemented. The caller retains input ownership; no
window copy occurs. Fixed secret storage (24 words) and large-input state
(eight words) use constant-sized Mojo lists. The unsigned full-product fold
uses independently written 32-bit limb/carry arithmetic. No external algorithm
implementation was read/copied/translated or added as a production dependency.
The pinned specification's constants and attribution are identified in the
facts receipt; this is a noncryptographic integrity check.

`validate_program_integrity(data,host_buffer_limit)` requires the exact
version-3 outer header and section extents before hashing. It returns scalar
`ProgramIntegrityResult(protobuf_only,offset,count,checksum)`. A nonzero
protobuf hash selects only bytes `[56,56+protobuf_bytes)`; otherwise all bytes
after the header are checked against the residue hash. Exact extents are
required in both modes. Header bytes themselves and the unselected checksum
field are not authenticated by this operation. Protobuf-only mode does not
check padding, CCW or additional bytes; the result reports that limited domain.

The diagnostic accepts synthetic hex windows or a bounded generated pattern.
Its 32768-byte hex and 8 MiB generated-allocation limits are diagnostic limits,
not production hash or model limits. The production routine accepts any valid
caller-owned Int-sized window under its explicit bound. It performs no file,
model, driver or device access. It does not inspect protobuf semantics, numerical
instructions, target/resource compatibility, physical alignment, firmware LCU
CRC or executable completeness. Matching a checksum cannot admit NPU execution.

## Verification

Final warning-free Mojo 1.1.0 build; eleven focused methods and 2072 native
calls: 1977 accepted, 95 refused. Every length 0 through 256 is checked with
four patterns, plus stripe/block transitions, exact final blocks, random and
unaligned windows, zero/maximum bytes and buffers up to 8 MiB. Three literal
known vectors agree with the isolated BSD-2-Clause libxxhash 0.8.1 oracle.
Oracle binary/license hashes are pinned before use; production has no link to
it. 192 complete-product limb/carry cases agree with Python full integers.

Synthetic program checks cover both selectors, every section origin, empty
sections, padding-only regions, selected tampering, intentionally unchecked
protobuf-only tails, malformed/truncated/extra bytes, reserved/magic/version/
length overflow, exact/insufficient/zero bounds, negative Int64 extremes and
owned value/input mutation behavior. The native trace and linked-library list
show no device/ioctl/external hash/HailoRT/CUDA/ggml use. The independent header
regression retains all eight methods/151 native calls.

Evidence: `docs/evidence/program-integrity-2026-10-20/`. The first build failed
because this installed Mojo no longer exports InlineArray at the historical
import. Constant-sized standard List storage replaced it. Failed build output
and the earlier passing pre-extension/pre-refactor runs are preserved. Final
results apply to the final implementation and tests; no full hosted CI pass is
claimed. The existing historical master compile failure remains separately
recorded from these focused passing gates.

Reproduce from the repository root with installed oracle/license locations
provided explicitly by the caller:

```sh
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine smidr/tools/program_integrity.mojo -o ../program-integrity
python3 tests/test_hailo_program_integrity.py --binary ../program-integrity --oracle "$AESIR_HASH_ORACLE" --oracle-license "$AESIR_HASH_LICENSE" --strace "$AESIR_STRACE" --evidence ../integrity-recheck
```

Next: connect checked headers and hashes into independent owned outer-envelope
construction under `TASK_hailo10h_program_envelope.md`, while continuing actual
numerical encoding/placement/configuration/upload/activation/result/cleanup.
The unchanged target is broad ordinary source-model support owned by Aesir in
Mojo, with LLM execution on Hailo-10H and no outside compiler or special model
prerequisite.
