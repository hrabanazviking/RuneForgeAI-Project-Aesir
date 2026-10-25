# The datum's closed form, I: it is GF(2)-linear (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.23 (AES-NUM-023).
Question: what function carries the lane-1 operand word to
the 24-bit lane-2 datum (the bijection of AES-NUM-022)?

## Method

- Incremental GF(2) basis over (input bits + affine
  constant) → 24 output bits: every sample either extends
  the basis or must satisfy the relation the basis already
  implies; a sample that reduces to input 0 with nonzero
  output residual is an inconsistency.
- Pairwise probes: datum differences under single-field
  steps (ladder +0x200, enum steps, flags changes),
  counted both arithmetically and as XORs.

## Result: linear, zero violations, both artifacts

- **MiniLM: 62 samples, basis rank 12, inconsistent 0 —
  for the affine system AND for the pure-linear system
  (no constant term).**
- **Blob 5ab3537d: 417 samples, basis rank 14,
  inconsistent 0 — affine and pure linear alike.**
- The probes agree: a 0x200 ladder step changes the datum
  by one of only **three XOR values** in both artifacts
  (120 step-pairs, 120 distinct *arithmetic* differences —
  arithmetic form excluded, XOR form exact); flags changes
  likewise produce a small set of repeated XOR differences
  (top: `0x3858a9` ×98). Some ladder-step XORs and
  arithmetic diffs are shared between the two artifacts —
  the same map governs both.

A random bijection would violate a fitted linear system
with probability ≈ 1 − 2⁻²⁴ per constrained sample; the
blob alone imposes ~9,700 bit-constraints, all satisfied.
**The datum is a GF(2)-linear image of the operand word**
— a fixed 24×64 binary matrix multiplication (on the
observed domain), no constant term required.

## The honest limits (read before celebrating)

- The operand variety is low-dimensional: the samples span
  rank 12–14, so the matrix is determined *on that
  subspace* — the subspace the compiler itself inhabits
  (limited joint patterns of flags × enum × ladder). For
  authorship that is the domain that matters, but the
  matrix's values off-domain are unobserved, not known.
- Linearity is proven; the matrix's *structure* is not yet
  interpreted (banded/Toeplitz would suggest a CRC-style
  construction; unstructured would suggest a designed
  scramble). Extracting the matrix, cross-validating it
  (fit on one artifact, predict the other), and reading
  its structure is slice 4.24.

## Evidence boundary

Exact linear algebra over the full sample sets of two
artifacts (132 and 4,819 champion bursts; 62 and 417
distinct operand words). No semantic name is claimed for
the transform yet.
