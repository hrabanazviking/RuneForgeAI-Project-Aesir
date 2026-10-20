# AES500-102 — RoPE numerical baseline

## Reproduction

From repository root:

```sh
pixi run mojo run --target-accelerator sm_89 -I aesir_engine docs/evidence/rope-baseline-2026-10-09/rope_baseline.mojo > docs/evidence/rope-baseline-2026-10-09/raw-output.txt
python3 docs/evidence/rope-baseline-2026-10-09/compare_scalar_reference.py
```

Toolchain: Mojo 1.0.0 (`ed45d567`). Source owner at capture:
`aesir_engine/core/compute.mojo`, SHA-256
`77eda1ce73a3b0a394b840f4040b571e649c138becf00b0e29b657063db250b5`.
The probe SHA-256 is recorded in the slice's original capture receipt and can
be regenerated with `sha256sum` after any intentional probe edit.

## Corpus and result

The probe captures deterministic Q (2×8) and K (3×4) F16 inputs, then invokes
the current CPU `apply_rope` with `head_dim=4`, `start_pos=5`, `theta=10000`,
for interleaved and NeoX layouts. The Python oracle independently computes
scalar trigonometry, casts coefficients to F16, and rounds ordered F16
multiply/add/subtract operations. It reports zero F16 mismatches for Q and K
in both layouts.

The output also records a shape asymmetry: Q has two rows and K has three,
but the current implementation uses Q's row count for both loops. The third K
row therefore remains untouched. This baseline preserves that observation;
it does not bless it as intended contract behavior. AES500-103 will establish
the interface admission and mutation guarantees; later implementation work
will decide whether to reject unequal row counts or iterate independently.

This is a small deterministic CPU baseline only. It establishes no accelerator
parity, broad numerical tolerance, arbitrary tensor safety, model quality, or
performance claim. Existing source does not validate backing capacity,
pointer provenance, tensor overlap, or position-index overflow.
