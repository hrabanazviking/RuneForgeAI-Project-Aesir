# First packed matrix primitive — 2026-10-01

Actual original packed weights, independent descriptors, 28 complete real cases.
All 1,658,880 native-reference outputs and 2100 selected independent Float64 dots
pass fixed scaled 0.002 / normalized-RMS 0.0002 budgets. Twelve invalid spans reject
before enqueue; 144 synthetic quant/tail cases preserve all guards and inputs.

| Tensor | batch 4 ratio | batch8 ratio | batch16 ratio | batch 32 ratio |
|---|---:|---:|---:|---:|
| blk.0.attn_q.weight | 0.362 | 0.558 | 0.791 | 1.077 |
| blk.0.attn_k.weight | 0.265 | 0.428 | 0.605 | 0.771 |
| blk.0.attn_v.weight | 0.261 | 0.418 | 0.587 | 0.742 |
| blk.0.attn_output.weight | 0.366 | 0.565 | 0.792 | 1.073 |
| blk.0.ffn_gate.weight | 0.427 | 0.676 | 0.948 | 1.247 |
| blk.0.ffn_up.weight | 0.426 | 0.676 | 0.958 | 1.271 |
| blk.0.ffn_down.weight | 0.291 | 0.499 | 0.765 | 1.042 |

Worst selected independent candidate scaled error 2.55663059e-06; RMS 7.63658301e-07.

Ratio is median existing four-token calls divided by median candidate time for
equal primitive work, ten alternating paired samples of three calls. Uploaded
warmed weights and host-monotonic actual enqueue/synchronize timing; no allocation
or printing. This is one physical session, not a whole-model/provider speed score.

The candidate loses everywhere at batch 4; it is rejected for default promotion.
Batch 32 modestly improves Q/output/FFN but still loses K/V. No runtime inference
dispatch, deadline policy, model bytes or live second-brain service is changed.
Next slice tests larger column staging and row choices to reduce barrier cost.

Full raw CSV and binaries remain outside Git; hashes and retained build failure
are in provenance.json. The complete raw final CSV is also a local user output.
[Operation and limits](../../NATIVE_MATRIX_CANDIDATE.md). Exact pushed CI receipt
is a separate publication artifact. SPD-01 integration and broad quality remain open.
