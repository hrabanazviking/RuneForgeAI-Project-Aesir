# Original owned program envelope in Mojo

Date: 2026-10-20. Published contract: `TASK_hailo10h_program_envelope.md`.
Published facts: `HAILO10H_ORIGINAL_PROGRAM_STRUCTURE.md` and
`HAILO10H_PROGRAM_INTEGRITY_FACTS.md`.

## Connected behavior

`smidr/program_envelope.mojo` connects the original header, section arithmetic
and XXH3 window hash into a complete outer-byte constructor. The future SMIÐR
writer supplies its own protobuf, CCW and additional byte lists, explicit zero
padding count, explicit checksum mode and positive output bound. The constructor
copies these sections into one independent owned output, fills the big endian
56-byte header and computes both checksum values internally. Full-residue mode
uses the zero protobuf selector; protobuf-only mode requires a nonzero protobuf
hash. It refuses an unrepresentable zero selector instead of changing modes.
The result passes the original selected-domain validator before return.

The separate `plan_program_envelope` verifies UInt32 protobuf size, all UInt64
sums, exact output bounds and Int-sized output before allocation. It returns
owned layout values without allocating the declared buffer. This lets huge
invalid/edge scenarios be checked without attempting a huge allocation. The
constructor reuses that same planner. Input lists remain unchanged and no
borrowed pointer or list is retained. Padding is explicitly supplied and filled
with zeros; this does not establish a hardware alignment rule.

## Independent verification

Final warning-free Mojo 1.1.0 build. **Eight methods/194 native calls pass:
159 accepted and 35 refused.** The earlier seven-method/184-call passing run
is retained before the direct zero-selector policy test was added.

Independent Python big endian struct plus the pinned, isolated BSD-2-Clause
libxxhash 0.8.1 oracle check complete constructed bytes and every section origin.
Coverage includes all empty/nonempty section combinations in both modes, every
checksum length class, stripe/block tails, random section/padding sizes, exact/
insufficient/zero bounds, Int64/UInt32/UInt64 extent limits and overflow without
allocation. A direct policy test covers zero/nonzero/maximum checksum selection
without claiming to have found a zero XXH3 preimage. Native ownership checks
verify input preservation, later input mutations, input destruction and independent
outputs. The host trace and linked-library list contain no device/ioctl,
HailoRT, external hash, CUDA or ggml dependency.

Evidence and source/binary hashes: `docs/evidence/program-envelope-2026-10-20/`.
The diagnostic's hex-input and 256 KiB output bounds limit its reporting only;
production uses the explicit caller output bound and host integer range.
Reproduce using caller-supplied installed oracle/license/trace paths:

```sh
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine smidr/tools/program_envelope.mojo -o ../program-envelope
python3 tests/test_hailo_program_envelope.py --binary ../program-envelope --oracle "$AESIR_HASH_ORACLE" --oracle-license "$AESIR_HASH_LICENSE" --strace "$AESIR_STRACE" --evidence ../envelope-recheck
```

## Remaining executable gates

Protobuf and CCW payloads remain opaque here. This constructor neither generates
numerical instructions nor validates protobuf semantics, target, precision,
physical placement, firmware LCU CRC, upload/activation or hardware execution.
A byte-correct synthetic envelope is not a complete executable program. No
vendor compiled model, DFC, outside compiler, special user model conversion or
host model evaluation was used. All LLM execution remains on Hailo-10H.

Continue the public numerical encoding/transport delta study under
`TASK_hailo10h_public_encoding_delta.md`. The fixed goal remains Aesir-owned
ordinary source-model loading, lowering, instruction/configuration generation
and execution with broad model support; outer serialization is one dependency.
