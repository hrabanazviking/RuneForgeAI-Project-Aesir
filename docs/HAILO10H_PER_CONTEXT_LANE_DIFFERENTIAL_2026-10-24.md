# Per-context lane differential — the layer skeleton (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.15 (AES-NUM-015):
the intra-artifact differential of AES-NUM-012, run on the
MiniLM HEF's six contexts (its six transformer layers), plus
the pair-acquisition route check.

## Method

Collect every 24-byte channel-1/2 burst per context (153
total: 25/24/25/24/26/29), extract its three 64-bit lanes at
the confirmed zero point (57,344), and compare value sets
and sequences across contexts.

## Results

- **Lane 0 has exactly ONE value common to all six
  contexts** — the champion `0528000000000000` — out of 18
  values in the union. Every context carries the champion
  **exactly 22 times**, whatever its burst total. A fixed
  per-layer count of 22 champion-headed bursts is a
  structural constant of the layer program.
- **Lane-0 sequences are near-identical across contexts:**
  position-by-position matches against context 0 run 21–22
  of ~24 for contexts 1–4; context 5 (the last) diverges
  most (18) — consistent with a shared layer skeleton plus
  end-of-network extras.
- **Lanes 1–2 are almost entirely layer-specific:** only 2
  values in each lane are common to all six contexts (of
  82/83 in the unions). The operand lanes carry each
  layer's own addresses/data; the skeleton lives in lane 0.

## Reading (behavioural, not semantic)

The 24-byte burst family decomposes into a **fixed skeleton**
(22 champion-headed bursts per layer in near-fixed
positions) plus **layer-specific operands**. The
champion-headed bursts are the prime pure-configuration
candidates: their lane-0 never varies, so their lanes 1–2
variation across the 132 instances is configuration
variation, not weights noise. Byte-level entropy anatomy of
those 132 bursts (which bytes move, which never do) is the
sharpest next cut and needs no new artifact.

## Pair acquisition — route confirmed, download next

The twister model-zoo checkout carries a full
`docs/public_models/HAILO10H/` set (detection, face
recognition, super-resolution, depth, denoising) — the
downloadable-HEF catalogue for this chip. Extracting a
same-family pair (one declared difference) from it is the
next slice's acquisition step; the cross-artifact
differential then runs the AES-NUM-012 method on real pairs.

## Evidence boundary

All claims are value-set/sequence statistics over one
artifact — structure observed, no field named. The 22-count
and the single common lane-0 value are exact counts, not
estimates.
