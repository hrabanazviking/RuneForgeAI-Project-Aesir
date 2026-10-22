# Q2_K/Q3_K source block fields

Date: 2026-10-22. Contract: TASK_hailo10h_q2q3_source_constants.md.
These are GGUF source-format facts, not Hailo precision, packing or instructions.

The public ggml MIT license was re-read before headers. The immutable pin is
`a05c9922613c6a2230dbb1d0de679519ecafb4f0`; retained license, public type header,
block header and static-source hashes match the prior qualified pin. No external
implementation body is copied or translated. Production implementation has not
started under this contract.

## Block fields and index interpretation

All blocks contain256 logical elements. Words use little-endian source order.
Offsets below are bytes from the source block start.

| GGUF tag | Format | Bytes | Group fields | Quant low plane | Quant high plane | Super-scale words |
|---|---|---:|---|---|---|---|
| 10 | Q2_K | 84 | 16 scale/minimum bytes at0..15 | 64 bytes at16..79 | absent | d at80..81, dmin at82..83 |
| 11 | Q3_K | 110 | 12 packed scale bytes at96..107 | 64 bytes at32..95 | 32 bytes at0..31 | d at108..109; minimum absent |

For lane i in0..255, the low-plane byte index is its origin plus
32*floor(i/128)+(i mod32). Extract two bits starting at
2*floor((i mod128)/32).

Q2_K's group g=floor(i/16) uses the low nibble of group byte g as scale and
its high nibble as minimum. Its unsigned quant is the low-plane value.
The static source expression is d*scale*q - dmin*minimum.

For Q3_K, inspect high-plane byte i mod32, bit floor(i/32). Its signed quant
is the low-plane value minus4 when that bit is clear, otherwise the low-plane
value. Group g=floor(i/16) takes a low nibble from byte96+(g mod8), shifted by
4*floor(g/8), and two high bits from byte104+(g mod4), shifted by2*floor(g/4).
Combine the six bits and subtract32 to obtain the signed scale. Its static
source expression is d*scale*q. Absence of dmin/minimum must remain explicit.

Rows contain whole256-element blocks. Their bytes are columns/256 multiplied
by84 or110, without adding tensor alignment between rows. Partial source tiles
retain complete touched blocks and exact unused prefix/suffix elements.

## Independent qualification, without model execution

A separately compiled public-header C++ object confirms both block sizes and
all listed field offsets. An original bit-plane probe uses only the pinned
isolated ggml-base library's two static constant-decoder functions, with its
CPU backend disabled. Across1504 small synthetic cases it compares385024 full
constant values: every low-plane bit, every Q3 high-plane bit and every packed
group scale/minimum bit. Integer/power-of-two fixtures isolate each position;
no model, layer, attention, context, graph or forward API runs. This is a static
format oracle, not numerical Hailo or source-model execution.

The probe's record field `kind` denotes quant width2/3, corresponding to GGUF
source tags10/11. It is not a GGUF or device enum. This namespace distinction
is recorded in provenance. No probe or external library becomes a production
or user model-compilation dependency.

Evidence: docs/evidence/q2q3-source-contract-2026-10-22. It retains exact source,
license, oracle and pre-code source/control/test identities. Baseline643 Mojo
sources,81 native controls and64 Python test inputs are frozen for the next
original implementation. Remaining formats/ranks/architectures and all actual
H10H numerical configuration, placement, program execution and cleanup remain
work toward the full broad ordinary unmodified model target.

Primary pinned sources:
[type tags](https://github.com/ggml-org/ggml/blob/a05c9922613c6a2230dbb1d0de679519ecafb4f0/include/ggml.h),
[block fields](https://github.com/ggml-org/ggml/blob/a05c9922613c6a2230dbb1d0de679519ecafb4f0/src/ggml-common.h),
[isolated static interpretation](https://github.com/ggml-org/ggml/blob/a05c9922613c6a2230dbb1d0de679519ecafb4f0/src/ggml-quants.c),
[license](https://github.com/ggml-org/ggml/blob/a05c9922613c6a2230dbb1d0de679519ecafb4f0/LICENSE).
