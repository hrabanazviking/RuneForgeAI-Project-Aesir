# AES500-108 — RoPE theta admission review

## Finding

The AES500-107 probe showed `theta=0` and `theta=-1` were accepted and produced
NaNs in both tensors for its exercised row. The argument controls the inverse
frequency exponent and therefore must be finite and strictly positive.

## Change and evidence

`core/compute.mojo::apply_rope` now rejects `theta <= 0`, NaN, and either
infinity before dimension checks or tensor writes, using the stable diagnostic
`apply_rope: theta must be finite and positive`. The adversarial test checks
zero, negative, NaN, positive infinity, and negative infinity; for each it
asserts the exact diagnostic and full logical Q/K snapshots unchanged. The
scalar reference suite continues to exercise finite positive theta in both
layouts.

## Scope

This is a primary-agent source and evidence review. Six independent Mythic
Engineering subagent passes could not be launched because the app reported
`agent thread limit reached`; no independent approval is claimed. Integer
position overflow, pointer provenance/capacity/lifetime, overlap, finite F32
phase overflow, accelerator behavior, and broad numerical tolerance remain
unverified.
