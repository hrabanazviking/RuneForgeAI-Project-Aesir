# Numerical encoding and original-program leads

Date: 2026-10-20. Contract: `TASK_hailo10h_numerical_encoding_sources.md`.
Broad ordinary-model support and Hailo-only LLM execution remain fixed.
This is a bounded primary-source/interface study, not hardware completion.

## Architectural leads, without an invented instruction format

Hailo's [US11514291B2](https://patents.google.com/patent/US11514291B2/en),
configuration/control and layer-controller descriptions, separates quasi-static
configuration from compact per-layer microcode and describes hierarchical
configuration addressing. This supports investigating both configuration and
LCU program payloads. It does not establish this Pi's Hailo-10H address map,
instruction width, opcode field positions, memory geometry or data path format.
No constants from an illustrative patent diagram become device instructions.

Hailo's [US11237894B1](https://patents.google.com/patent/US11237894B1/en),
LCU instruction addressing mechanism/Figs75–79, describes compiler-generated
program length, opcode checks and CRC reference values. It provides a concrete
integrity lead, not a verified CRC polynomial or opcode format for Hailo-10H.
An LCU execution CRC cannot be assumed identical to an outer program checksum.
The actual arithmetic/register/CCW encoding remains unresolved in this study.

The public [community compiler announcement](https://community.hailo.ai/t/i-compiled-an-llm-for-the-hailo-10h/19685)
explicitly drives DFC. It remains an excluded wrapper route, not a standalone
open compiler for Aesir. No external compiler/model/proxy was adopted or run.
The searches are bounded evidence, not a claim that no other public source exists.

## Concrete original configuration codec work

The frozen MIT HailoRT5.3.0 pin
`d503417f2a0db186a838390fb08690c4ea0f415e` defines a complete action4 body and
receiver mapping. Public [rpc.proto](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/hrpc_protocol/rpc.proto)
provides these fields:

| Request field | Wire meaning |
|---|---|
| 1 / 2 | infer-model / virtual-device nested object handles |
| 3 / 4 | repeated input / output stream parameter messages |
| 5 / 6 / 7 | batch size, power mode, latency flags |
| 8 | enable KV cache |

Each stream contains name1, order2, type3, fixed32 score/iou thresholds4/5,
and unsigned limits6/7/8. The reply carries nested configured handle1 and
async queue size2. The public C++ request structure uses a16-bit batch; zero
means automatic per the public header. Power values0/1 and latency bits0/1
are public definitions, not proof that a particular loaded graph supports them.

The receiver applies stream settings, batch/power/latency/cache state and calls
the existing infer model's configure method. It does not create numerical
instructions from a source operation. Zero-filled stream messages are a trap:
`INVALID_NMS_CONFIG` is -1; the receiver conditionally applies NMS settings
when values differ. A plain non-NMS stream must explicitly preserve binary32
-1 thresholds (`0xbf800000`) and unsigned all-ones limits, rather than silently
sending proto3 zero defaults. Every exposed field must be serialized or refused.

Public format type3 means host FLOAT32 conversion, not verified device FP32
arithmetic. Format metadata must not certify device precision or broaden a
physical capability claim. The original codec can carry these values under
bounded framing without calling HailoRT or submitting any hardware request.
Next contract: `TASK_hailo10h_configure_rpc_codec.md`.

Provenance hashes: `evidence/numerical-encoding-leads-2026-10-20/`.
The already licensed public source remains outside production; no external
implementation is copied/translated. No hardware, firmware, kernel or model
state changed. Full numerical encoding/target metadata, original program
ownership/delivery, physical configure/activation/result/cleanup remain open.
