# Q8_0 source storage facts for original Mojo compilation

Date:2026-10-22. Contract:TASK_hailo10h_q8_source_constants.md. Fixed owner scope:
HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md. These are source-file facts,not Hailo
instructions or proof of device INT8 precision/packing/execution.

Read the public ggml MIT license before format bodies. Four immutable source/
license files at revision`a05c9922613c6a2230dbb1d0de679519ecafb4f0` were fetched
and matched against the retained licensed archive. Pin identities are under
 docs/evidence/q8-source-contract-2026-10-22/provenance.json. Source bodies stay
outside production; no external implementation is copied or translated.

| Source field | Qualified representation |
|---|---|
| Type namespace | GGUF/ggml Q8_0 is integer tag8. This is not a Hailo format enum. |
| Block |32 consecutive logical source elements occupy34 bytes,without padding. |
| Scale |Bytes0..1 contain the little-endian binary16 scale d. |
| Quant |Bytes2..33 contain32 signed two's-complement eight-bit quants in lane order. |
| Static expression |Each logical constant is d*q. No extra minimum or group factor. |

A row contains whole32-element blocks. Thus columns must divide32 and row bytes
are34*(columns/32). The source scale's exact bits and binary32 representation
must be retained independently of signed quant components. Source values can
carry special floating bit patterns; a representation reader must not silently
canonicalize or select a target rounding policy. Logical windows can start/end
inside blocks; source byte tiles include whole touched blocks with exact unused
prefix/suffix counts. Neither source spans nor estimated dense conversion bytes
establish a physical accelerator layout or fit.

Primary pinned sources:
[type declaration](https://github.com/ggml-org/ggml/blob/a05c9922613c6a2230dbb1d0de679519ecafb4f0/include/ggml.h),
[block fields and size](https://github.com/ggml-org/ggml/blob/a05c9922613c6a2230dbb1d0de679519ecafb4f0/src/ggml-common.h),
[static interpretation](https://github.com/ggml-org/ggml/blob/a05c9922613c6a2230dbb1d0de679519ecafb4f0/src/ggml-quants.c),
[license](https://github.com/ggml-org/ggml/blob/a05c9922613c6a2230dbb1d0de679519ecafb4f0/LICENSE).

The previously isolated test-only ggml-base library remains pinned by
 evidence/source-q4k-constants-2026-10-20/reference-provenance.json. Its CPU
backend,examples and tests are disabled. Only a static synthetic constant oracle
may be called; there is no production dependency or model evaluation.

The bounded physical instruction search preceding this slice qualified no new
H10H opcode/register field in its returned results. That is not proof that no
public specification exists. Continue actual numerical/configuration/placement/
program/transport research alongside this source-format implementation. Ordinary
unmodified broad model support is unchanged; remaining formats remain work.
