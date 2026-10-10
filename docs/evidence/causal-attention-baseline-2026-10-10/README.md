# AES500-112 — Pre-change causal attention baseline

## Reproduction

```sh
pixi run mojo run --target-accelerator sm_89 -I aesir_engine docs/evidence/causal-attention-baseline-2026-10-10/attention_baseline.mojo > docs/evidence/causal-attention-baseline-2026-10-10/raw-output.txt
python3 docs/evidence/causal-attention-baseline-2026-10-10/compare_scalar_reference.py
```

Toolchain: Mojo 1.0.0 (`ed45d567`). Baseline owner source SHA-256:
`9585165accabf26456682497fd8d2b8322cec80584ccec9dd71f163e47987b78`.
Probe SHA-256:
`39f6e90ce6ef8f337b5edd53f7598d9e37dbfe1575a0eb00461473903b418236`.

## Corpus and observation

The probe uses 3 rows, 2 heads, head width 2, and distinct deterministic Q/K/V
values. The Python scalar oracle computes both inclusive causal prefix output
and all-row attention, in F32 then rounded to F16.

Captured kernel output differs from causal prefix on 10/12 values, with maximum
absolute error 12.671875. It is much closer to all-row attention (4/12 differing
F16 outputs, maximum absolute error 0.015625), consistent with the source loop
allowing every `j` for each query row. The latter small discrepancies reflect
the current online update and repeated F16 output stores; no general numerical
tolerance is claimed.

This is a CPU-only deterministic baseline for one small shape. It proves the
future-row leak for this corpus, not broad model impact, hardware parity,
performance, or arbitrary input safety. AES500-114 will apply the causal mask;
AES500-115 will establish a focused oracle test.
