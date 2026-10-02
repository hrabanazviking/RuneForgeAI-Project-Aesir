# Original packed-weight Turing matrix candidate — 2026-10-01

The split-weight high/residual F16 candidate passes the unchanged0.002 scaled/
0.0002 normalized-RMS primitive budgets. Complete native coverage is1,658,880
output pairs; selected independent gguf0.19.0/NumPy2.4.4 coverage is2100 real
Float64 dots.144 synthetic tails and12 invalid spans pass. Initial single-F16
conversion fails before timing and remains preserved; no budget is loosened.

All28 real shape/batch speed cases lose. At batch4 ratios are0.077–0.196; at
batch32 they are0.377–0.425. Ratios compare complete equal existing four-token
primitive work against the candidate, not a provider or full-model request.
All560 timing records remain in split-weight.json. Resident weights are warmed,
ten pairs alternate order, each sample invokes three calls. Printing/allocation
are excluded; host compilation and other owned GPU work are idle.

The kernel uses public m16n8k8 with the proved explicit sm_75/PTX6.5 target,
original format equations and bounded actual borrowed spans. No extra device
workspace or full F16 model copy. Current test activations are exact binary
fractions; arbitrary full-model activation conversion remains open. Q5_K is
synthetic here; real strict3B projections are Q4_K/Q6_K.

provenance.json records all failed/successful raw source/binary/CSV/build identities
outside Git. Eight portable tests admit known mode, complete finite evidence and
legacy SIMT data; hosted CI only compiles optional probes. Production binary
remains f3442a1e, original service active. No candidate is promoted.

Next measure coalesced shared staging, preserving precision/reference/control
gates. [Operation](../../NATIVE_PACKED_TURING_MATRIX.md). Exact pushed revision
and CI are separately recorded in publication receipts.
