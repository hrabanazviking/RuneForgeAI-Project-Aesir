# IQ4 nonlinear source block fields

Date: 2026-10-22. Pre-code contract: TASK_hailo10h_iq4_source_constants.md.
These are source GGUF fields, not accelerator formats or numerical instructions.
Public ggml MIT license was re-read before the declarations. Immutable pin:
`a05c9922613c6a2230dbb1d0de679519ecafb4f0`; all retained source/license hashes
match. No implementation body is copied/translated or adopted as a dependency.

| GGUF tag | Format | Elements | Bytes | Fields, byte offsets |
|---|---|---:|---:|---|
| 20 | IQ4_NL | 32 | 18 | d binary16 at0;16 packed quant bytes at2 |
| 23 | IQ4_XS | 256 | 136 | d binary16 at0;scale high word at2;four scale-low bytes at4;128 quant bytes at8 |

Words are little-endian. For IQ4_NL lane i, quant byte2+(i mod16) holds a low
nibble for lanes0..15 and high nibble for16..31. Group scale is absent/fixed1.
For IQ4_XS lane i, group g=floor(i/32); quant byte8+16*g+(i mod16), shifted by
4*floor((i mod32)/16), gives the four-bit code. Its scale low nibble comes from
byte4+floor(g/2), shifted4*(g mod2). High two bits come from the word at2, shifted
2*g. Combine six bits and subtract32 to obtain the signed group scale.

The published nonlinear codebook in code order0..15 is:
`[-127,-104,-83,-65,-49,-35,-22,-10,1,13,25,38,53,69,89,113]`.
Keep original code and source value distinct. Static source constants have the
expression d*group_scale*codebook[code]; production under the contract retains
components without evaluating that product. Rows contain whole source blocks,
with no tensor realignment between rows. Partial tiles retain complete touched
blocks and exact prefix/suffix logical elements.

An independent public-header C++ object confirms both sizes, element counts and
all field offsets with zero diagnostics. An original field hypothesis probe
compares1264 small synthetic cases/287744 complete finite constant values with
only the pinned isolated static IQ4_NL/IQ4_XS decoders. It exercises every packed
quant/scale bit and all nonlinear code values with signed/power-of-two words.
The external CPU backend is OFF. No model/context/graph/forward API, physical
access, numerical Hailo execution or production implementation occurs in this
qualification. This is not exact signed-zero execution validation; original
Mojo word/presence behavior must be verified separately.

Evidence: docs/evidence/iq4-source-contract-2026-10-22. Baseline646 Mojo
identities/actual snapshots,100 current binary controls and65 Python identities
are frozen for original implementation. Other formats/ranks/architectures and
actual numerical Hailo configuration/packing/placement/program execution remain
work toward100% of the broad ordinary unmodified model target.

Primary pinned declarations/data:
[type tags](https://github.com/ggml-org/ggml/blob/a05c9922613c6a2230dbb1d0de679519ecafb4f0/include/ggml.h),
[fields and nonlinear table](https://github.com/ggml-org/ggml/blob/a05c9922613c6a2230dbb1d0de679519ecafb4f0/src/ggml-common.h),
[license](https://github.com/ggml-org/ggml/blob/a05c9922613c6a2230dbb1d0de679519ecafb4f0/LICENSE).

Implementation checkpoint(2026-10-22): original Mojo source components and
byte integration are verified in docs/HAILO10H_MOJO_IQ4_SOURCE_CONSTANTS.md
(path relative to repository root). Pre-code qualification history remains
preserved;this establishes no numerical Hailo or source-model execution.
