# Zero point CONFIRMED + burst structure observed (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.13 (AES-NUM-013), the
first run of the AES-NUM-012 differential program — its
intra-artifact arm. Two results: the pointer zero point is
now confirmed *empirically* (not only from source), and the
24-byte bursts show their lane structure.

## Zero point: 57,344 — confirmed by structure emergence

From the artifact's own header (big-endian u32 fields):
`hef_proto_size = 56,844`, `ccws_size_with_padding =
11,700,652`, `hef_padding_size = 444`; the AES-NUM-012
formula gives zero = 56 + 56,844 + 444 = **57,344**.

Test: extract the 153 channel-1/2 bursts of size 24 under
three candidate bases and count distinct values per 64-bit
lane:

| base | lane distinct counts (of 153) | top lane-0 count |
|---|---|---|
| **57,344** | **18 / 82 / 83** | **132** |
| 0 (file-absolute) | 153 / 152 / 153 | 1 |
| 56,900 (proto-end, no padding) | 126 / 121 / 118 | 17 |

At 57,344 the bursts snap into structure; at 0 they are
indistinguishable from random data; at 56,900 (off by exactly
the 444 padding bytes) the structure blurs. **The zero point
is confirmed empirically, and the header decode is
corroborated field by field.** Cross-check: 57,344 +
11,700,652 = 11,757,996; file 11,759,616; residue 1,620 B of
trailing additional-info, as the v3 header describes.

## Burst structure (the differential's first foothold)

- The 6 contexts carry 251–279 pointer actions each, with
  **near-identical small-burst counts (57, 57, 56, 58, 56,
  59)** — the repeated layer-block structure, confirmed
  quantitatively: the intra-artifact differential has six
  aligned repetitions to compare.
- **Lane 0 is a near-constant header word:** the value
  `0528000000000000` (LE 0x0000000000002805) appears in 132
  of the 153 bursts; only 18 distinct lane-0 values exist.
  A second family shows lane-0 `03080000f8bf....` variants.
- Lanes 1–2 carry packed, small-number structure — first
  burst (channel 2): `000c00205002f018`, `33061b0000000000`
  — the operand lanes where parameter-tracking fields must
  live.

No lane is *named* yet: `0528...` is a header-class word by
behaviour (near-invariance), not by decoded meaning. Naming
is the work of the next differentials: per-context lane
comparison (which fields are layer-invariant vs
layer-varying) and the cross-artifact pair when acquired.

## Evidence boundary

Zero point: ESTABLISHED (source formula + header decode +
structural emergence, three-way agreement). Burst lane
structure: OBSERVED statistics, no semantics claimed.
Census: untouched — next slice (4.14) works the local driver
trees; the cross-artifact pair acquisition continues in
parallel (4.15).
