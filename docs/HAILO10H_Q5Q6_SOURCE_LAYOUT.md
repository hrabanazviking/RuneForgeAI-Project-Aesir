# Published Q5_K / Q6_K source field facts

Date: 2026-10-20. Contract: `TASK_hailo10h_q5q6_source_constants.md`.
Pinned public ggml revision `a05c9922613c6a2230dbb1d0de679519ecafb4f0`.
Root MIT license read before studying format declarations/interpretation. Header
and interpreter hashes match the prior frozen licensed source study. Production
will use original field descriptors interpreted by Aesir's existing generic
bit-field reader. No external implementation is copied/translated or becomes
an Aesir dependency. These facts describe source storage, never Hailo CCWs.

All offsets are bytes within a 256-element block; bits count from the low bit
of each byte. Binary16 words are little-endian. Row columns contain complete
blocks. The source expression and representation fields do not choose device
precision, conversion rounding, layouts or numerical execution behavior.

## Q5_K: 176 bytes, eight groups of32

| Bytes | Meaning |
|---|---|
| 0..1 | binary16 super-block scale d |
| 2..3 | binary16 minimum scale dmin |
| 4..15 | eight unsigned six-bit scale/minimum factors, same field table as Q4_K |
| 16..47 | one high quant bit per element, shared across eight groups |
| 48..175 | low four quant bits, paired group nibbles |

The complete scale/minimum field table is already published in
`HAILO10H_Q4K_SOURCE_LAYOUT.md`. For group g in0..7 and lane l in0..31,
quant low bits occupy byte48+32*floor(g/2)+l, bit4*(g mod2), width4.
Quant high bit occupies byte16+l, bit g, width1. Combining those fields yields
an unsigned0..31 quant. Static expression is `(d*scale_factor)*q-dmin*min_factor`.
Each factor remains0..63; exact d/dmin bit patterns must be preserved.

## Q6_K: 210 bytes, sixteen groups of16

| Bytes | Meaning |
|---|---|
| 0..127 | low four quant bits |
| 128..191 | high two quant bits |
| 192..207 | sixteen signed eight-bit scale factors, two's complement |
| 208..209 | binary16 super-block scale d |

For local element i, let half=floor(i/128), q=floor((i mod128)/32),
lane=i mod32. This table defines the four quadrant field descriptors:

| q | Low-byte origin within half | Low bit | High bit in byte128+half*32+lane |
|---|---|---|---|
| 0 | half*64+lane | 0 | 0 |
| 1 | half*64+32+lane | 0 | 2 |
| 2 | half*64+lane | 4 | 4 |
| 3 | half*64+32+lane | 4 | 6 |

Low width is4; high width is2. Unsigned six-bit value combines low+16*high;
subtract32 for the centered quant (-32..31). Scale byte is192+floor(i/16),
interpreted as signed -128..127. Static expression is `(d*scale_factor)*q`.
There is no minimum field. Readers must retain d bits and exact binary32
representation while evaluating only integer source fields in production.

## Independent acceptance and remaining work

Publish these facts before writing readers. Test independently packed bit-plane
fixtures, every Q5 quant and six-bit factor, every Q6 quant and signed scale,
group/block/row tails, malformed spans/bounds and owner destruction. The frozen
MIT ggml-base test-only library may reconstruct isolated synthetic constants
for an independent exact binary32 check. Its CPU backend is disabled; no model,
compute graph or context runs, and no library/source is shipped in production.
Existing build/dependency facts: `evidence/source-q4k-constants-2026-10-20/`.
New provenance: `evidence/q5q6-source-layout-2026-10-20/provenance.json`.

Actual selected device representation, numerical configuration/CCWs, physical
placement, original upload/activation and first hardware result remain open.
These source-kind readers advance broad ordinary-model support; they are not
a permanent supported-model boundary or a substitute for hardware execution.

Primary pinned sources:
[format declarations](https://github.com/ggml-org/ggml/blob/a05c9922613c6a2230dbb1d0de679519ecafb4f0/src/ggml-common.h),
[format interpretation](https://github.com/ggml-org/ggml/blob/a05c9922613c6a2230dbb1d0de679519ecafb4f0/src/ggml-quants.c).
