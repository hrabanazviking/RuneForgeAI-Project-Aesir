# Checked ownership for the optional matrix-prefill fixture

The original mode0 matrix fixture passes its fixed independent model gates and
earns about1.675x long fresh-prefill speed. Later precision refinements remain
rejected under their stricter goal. This slice hardens original workspace
ownership before separate production integration. Normal runtime admission
continues to use one/four tokens.

## Pure plan and observed device

tests/turing_fixture_plan.mojo owns a model-free TuringFixturePlan. It checks
the exercised Llama geometry: architecture llama,28 layers,3072 hidden,8192 FFN,
24 query heads,8 KV heads,128 head width,128256 vocabulary and context1536.
Every one of the13 supplied normal layout fields must match the checked canonical
four-token plan. It derives a separate32-token plan, preserving the reference.

The physical fixture passes actual DeviceContext compute-capability major/minor
and current free memory into this plan. Only observed7.5 is admitted before
extra fixture workspace/sampler allocation. Offline sm89 compilation never
proves physical sm89 execution. The normal reference has already loaded its own
weights and buffers; this guard governs the additional test-owned allocation.
Precision0..4 remains explicit; this admission does not promote rejected modes.

| Planned span | Exact value |
|---|---:|
| Token stride, including32-value padding | 33824 F32 values |
| Shared logits offset | 1082368 F32 values |
| Shared scores offset | 1210624 F32 values |
| Activation allocation, including16-value outer guards | 1247520 F32 values |
| KV allocation, including16-value outer guards | 88080416 F16 values |
| Additional fixture device allowance | 181961416 bytes |
| Existing reserve | 268435456 bytes |
| Required observed free memory | 450396872 bytes |

All derived additions/products use checked buffer arithmetic. Device allowance
includes existing sampling storage and the original8-byte output allowance.
The exact free-memory boundary accepts; negative or deficient observations
reject. No immutable weight copy or new device workspace is added. Before each
tile enqueues, admit_buffers checks every layout field against the retained plan
and actual activation/KV lengths. Layout mutation, including offsets that leave
the total unchanged, rejects before sampler/GPU mutation.

## Verification and operation

The portable registered tests.turing_fixture_plan case checks exact accounting,
all32 token bounds, reference preservation, unsupported geometry/context/batch/
device/precision, all13 corrupt reference and post-allocation layout fields,
actual length mismatch and headroom boundaries. It allocates no GPU memory.
The master suite additionally preserves normal defaults and overflow checks.

```bash
pixi run --frozen --no-install --offline mojo run -I aesir_engine \
  --target-accelerator sm_89 aesir_engine/tests/test_turing_fixture_plan.mojo
pixi run --frozen --no-install --offline mojo run --target-accelerator sm_89 \
  aesir_engine/tests/run_all.mojo
```

Read [whole-model operation](NATIVE_TURING_MODEL_PREFILL.md) for original model,
private artifact paths, independent F32 derivation and checker commands. Compile
the full-model probe for sm75, finish all host builds, then run original mode0
in an owned bounded process. Preserve the complete CSV and a new exclusive
JSON report. Run the independent CPU oracle only after GPU work ends. Compare
every input ID and complete native/matrix F32 vector against the prior accepted
mode0 session byte-for-byte as an additional ownership regression gate.

All513024 final-prompt values per mode, exact repeats/commits,8 invalid tiles,
4352 guards, fixed .05/.005/matching-argmax gates and all32 raw alternating
records remain mandatory. Any failure withholds ratios. Only the warm/export
pair is unscored; process wall duration is never a prefill score. Production
admission, cancellation/deadline, generation/sampling/restore/concurrency,
broader contexts and paired provider lead still require separate gates.

## Verified acceptance — 2026-10-02

The master suite passes188 named cases, zero failures and one explicit fixture
skip, total189. sm75/sm89 model probes compile. A new original mode0 physical
session passes all independent model gates, exact repeats/commits,8 invalid tiles
and4352 guards. Every input ID and complete native/matrix F32 vector is
byte-identical to the prior accepted mode0 session. All32 raw records remain;
long fresh-prefill medians12.8666s/7.6763s earn ratio1.676 in this isolated fixture.
The ownership checks preserve the candidate rather than proving a new speed gain.

Normal binary stays f3442a1e with authenticated active readiness checked separately.
Exact pushed CI has its own receipt. [Reviewed evidence](evidence/turing-fixture-admission-2026-10-02/README.md).
Next separately scope cooperative controls and recovery for larger tiles before
production generation/restore/provider admission. Broader contexts remain open.
