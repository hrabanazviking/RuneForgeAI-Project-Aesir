# Original version-3 header and section layout primitive

Date: 2026-10-20. Contract: `TASK_hailo10h_program_header.md`.
Facts published first: `HAILO10H_ORIGINAL_PROGRAM_STRUCTURE.md`.

## Interface and consumer

Original `smidr/program_header.mojo` supplies owned `ProgramHeaderV3` values,
`encode_program_header`, `decode_program_header`, `ProgramSectionLayout` and
`layout_program_sections`. The consumer is the future original SMIÐR compiled
program output builder. Encoding returns exactly 56 bytes with explicit
big-endian magic/version/size/hash fields and zero reserved bytes. Decoding
requires exactly that header, correct magic/version 3, zero reserved bytes
for this original-output profile, and padding no larger than its CCW section.
No vendor container is read. This is incremental format coverage, not a claim
that other outer versions are permanently unsupported by the hardware goal.

All section lengths/offsets use checked UInt64 arithmetic. The layout function
requires an explicit positive host buffer limit and exact declared actual
total extent. It derives protobuf/padding/CCW/additional origins and lengths,
including CCW length excluding padding, and rejects overflow before returning.
It allocates no declared payload, reads no file and discovers no physical
memory budget. UInt64−1 totals can be represented as arithmetic scenarios.
Zero-sized sections remain representable because a header/layout primitive
does not validate the required executable metadata or numerical program.

Hash words are retained integers only. No hash, payload, alignment policy,
target architecture, stream binding or numerical CCW is validated/generated.
The inspector reports payload_integrity_verified, complete_program,
execution_tested and device_access false on every accepted scenario. It cannot
submit bytes or admit inference.

## Verification

Warning-free Mojo 1.1.0 build and targeted synthetic checks:

```sh
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine smidr/tools/program_header.mojo -o ../program-header
python3 tests/test_hailo_program_header.py --binary ../program-header --strace /usr/bin/strace --evidence docs/evidence/program-header-2026-10-20
```

Eight methods pass, **151 native calls: 84 accepted and 67 refused**. Complete
header bytes match independent Python big-endian struct vectors, including
32 seeded scenarios and extreme/special section/hash words. Decode/re-encode
and every section origin/length/total match independent integer arithmetic.
Exact host-budget boundaries, inconsistent actual extent/padding, unsigned
overflow, zero bounds, wrong magic/version/reserved bytes, incorrect header
length, malformed hexadecimal/CLI integers and returned ownership are checked.
The trace opens no model/program/device file or CUDA/HailoRT/ggml library and
contains no ioctl. Only synthetic header byte strings are supplied.

The initial run had a test-harness assertion failure: malformed hex correctly
raised the reused diagnostic helper's BadRpcHex, which the test initially
omitted from its allowed error names. That assertion is corrected; production
did not change in response. Initial results/runs remain alongside the final
passing evidence in `docs/evidence/program-header-2026-10-20/`.
Targeted acceptance does not certify full hosted CI.

## Next numerical compiler work

The current header, source constants, graph recipes and RPC metadata remain
separate primitives. They cannot form an executable program until actual
device configuration and complete output metadata are earned. Continue
`TASK_hailo10h_llm_compile_interfaces.md`: bounded license-first study of newly
located public source-compilation interface evidence, especially prefill,
token-by-token groups, KV resource/quantization contracts and real numerical
program generation. Maintain Mojo ownership and hardware-only LLM execution.
No catalog-only scope, borrowed compiled numerical program or inference proxy
can replace the owner's source-model target.
