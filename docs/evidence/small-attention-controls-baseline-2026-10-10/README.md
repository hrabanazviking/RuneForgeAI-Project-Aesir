# AES500-002: observed capable-disabled strategy5 baseline

The strengthened baseline passed on 2026-10-10 for the declared strict 3B
fixture, RTX 2060 Max-Q (sm_75), context 1536 and F16 KV. The current collector
was built from base commit `5c89ecb7ff889922010a442ab6f74277e56a5501` plus the exact
source hashes in [provenance.json](provenance.json). Those collector/checker
changes and this receipt belong to the same independently committed slice.
The unchanged physical checker report is [complete.json](complete.json).

## What ran and passed

- The pre-control 2026-10-03 strategy5 CSV/report/executable were admitted by
  their original hashes. They were preserved, rather than rebuilt or relabeled.
- A fresh sm_75 build executed the explicit `controls-disabled` mode. Its
  `CONTROL_CAPABLE,5,1,DISABLED,STATE1` and `ADMISSION,5,COUNTS1,8,0` records
  identify the strengthened schema: eight executed tile refusals, zero feature
  refusals because capable mode skips that separate ordinary-mode check.
- All 32 runs emit actual owner snapshots immediately after their timing rows.
  Capability/admission are true, request controls and reset-required state are
  false, and both owners are healthy. The checker validates position, sampler
  position and committed length for the selected owner and retained state for
  the other owner, including changes between the four input streams.
- All 513,024 F32 values per owner, complete input IDs, cache digests and
  dispatch counters match the accepted source. The collector's repeated-output
  UInt32 checks and all 4,352 guards pass.
- A fresh independent llama-cpp-python 0.3.23 / NumPy 2.4.4 reference uses the
  admitted F32 derivation, zero GPU layers, context 4096, F16 KV, batch 128 and
  four threads. Both owners pass the predeclared .05 maximum absolute error,
  .005 RMS error and matching full-vocabulary argmax. The largest observed
  absolute error is 0.021598339080810547; largest RMS is 0.003986765366484171.
- Model, reference, historical source triplet, normal service binary and all
  272 recorded source/toolchain files have unchanged before/after hashes.
- The initially active service was stopped for the serial GPU capture, then
  restarted before CPU checking. Authenticated health returned HTTP 200 and
  `ready`, CUDA, context 4096, prefill batch 4, CPU offload 0 before and after.

`passed=true` establishes the declared quality/state baseline. This report has
`speed_scored=false`, null prefill ratios and no medians. Raw timing records are
retained for collection completeness; this slice accepts no performance score.

## Identities and retained artifacts

| Artifact | SHA-256 |
|---|---|
| Current sm_75 executable | `8a9e6a5a0ac3dc5009746b51a5621c6da4b87542cbad979054588a8ebfdca8a8` |
| Current raw CSV (26,271,421 bytes) | `e825a77271b63a8315ca4f2fdcf44000589b279496f317ef997d4694cc1e37a6` |
| Current report (47,101 bytes) | `2b9c6c43ab3e33478d7167614428a5afe9f2ab2a5077383da5546df6f9d57544` |
| Historical source CSV | `0dcc24b233b8ff094ac0486fcad7734fcd53ba0eba0c9f2e684a2c2316cd4d2d` |
| Historical source report | `22395c06b4cc62444ff063ba439cfcef89f3922c5ff0daabb284f56e23932a27` |
| Historical source executable | `3afd548ad0ef71952ae590aa13c06a6ebc08fff4355eacfee293af7998b82660` |
| Original model | `dde5aa3fc5ffc17176b5e8bdc82f587b24b2678c6c66101bf7da77af9f7ccdff` |
| F32 reference model | `b0dd20c95a6605d9773d9d3153c52f89f21628f21048ff81bb184684b6f7a42b` |
| F32 derivation snapshot | `9325ff2a1d58cd5334f1423d8db2eaffc631dd853785ed287a37f48b51dec5a9` |

Raw captures, executable bytes and process outputs remain in private task
storage; the public provenance binds each by hash, byte count, exact arguments,
UTC interval and exit code. It uses symbolic path labels and contains no local
credentials. The model/source bytes are required to repeat this physical gate;
the compact public receipt alone is not an independently runnable model bundle.

The earlier provisional physical capture passed its numerical comparisons but
used the legacy fixed admission count and generic timing scoring. It is retained
with its own identities in the provenance and is not accepted for this current
gate. The dated [2026-10-09 control receipt](../small-attention-controls-2026-10-09/README.md)
also remains historical evidence under its original contract. Neither capture
was altered to manufacture a current STATE1 result.

## Reproduction

Use a fresh exclusive `TASK_ARTIFACTS` directory, the exact input bytes above,
and an `ORACLE_PYTHON` environment with the recorded pinned packages. Build
before stopping an initially active service; always restore that service after
the capture, including on error. Retain stdout, stderr and every process result.

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_small_attention_model.mojo \
  -o "$TASK_ARTIFACTS/small-model"
"$TASK_ARTIFACTS/small-model" "$MODEL" controls-disabled \
  > "$TASK_ARTIFACTS/capture.stdout" 2> "$TASK_ARTIFACTS/capture.stderr"
"$ORACLE_PYTHON" scripts/check_turing_model_prefill.py \
  "$TASK_ARTIFACTS/capture.stdout" \
  --model "$MODEL" --model-sha256 "$MODEL_SHA256" \
  --reference-model "$REFERENCE_MODEL" --reference-sha256 "$REFERENCE_SHA256" \
  --reference-provenance "$REFERENCE_PROVENANCE" \
  --reference-csv "$SMALL_SOURCE_CSV" --reference-report "$SMALL_SOURCE_REPORT" \
  --reference-binary "$SMALL_SOURCE_BINARY" --small-controls \
  --binary "$TASK_ARTIFACTS/small-model" --binary-sha256 "$CURRENT_BINARY_SHA256" \
  --output "$TASK_ARTIFACTS/complete.json"
```

Hash all inputs and the source inventory before/after. `CURRENT_BINARY_SHA256`
must identify the freshly built executable, not an assumed historical binary.
Exact executed argument arrays and process intervals are in the provenance.

## Adjacent verification and boundary

All 48 owning/adjacent Python checker contracts pass, including hostile STATE1
field/order/cardinality, owner carryover, canonical counts, mode matching and
legacy CLI refusal. The explicit sm_89 master suite passes 249 tests, zero
failures, one explicit skip (250 total). The shared-helper fused-model sm_75
compatibility build and normal sm_89 launcher build/check pass. An earlier
default-target master invocation failed PTX compilation; the explicit-target
result does not repair that separate target limitation. The provenance retains
master and compatibility log identities.

This fresh gate executes disabled-control observation only. Enabled timeout,
SIGINT, reset/recovery and poisoning remain supported by the separate dated
control receipt and require their own fresh gates for revalidation. There is no
runtime, persistence, context-recreation, broad model/device, concurrency or
provider-speed promotion. Hosted CI is a separate exact-revision release signal.

## Independent review and report wording

Final Architect, Auditor and Skald reviews pass: source inventory and lineage,
byte-identical report/raw artifact identities, exact observed state/count/CPU
claims, service restoration, and historical/provisional exclusions are checked
read-only. The Scribe's continuity review passes after correcting legacy-count
wording and preserving the historical distinction across task, roadmap, TODO,
ledger and devlog. Forge Worker and Cartographer contributed the owning source
and interface maps. Each role is separately represented; GPU operations were
serialized by the primary agent.

The unchanged report retains inherited generic `limits` prose mentioning a
historical default4 source and closed controls. Its structured
`fixture_reference.attention_variant=5`, `control_capable=true`,
`control_state_observed=true` and actual disabled snapshots specify this current
gate: the accepted immediate source is historical strategy5, the capability is
admitted, and request controls remain disabled. The source report itself retains
its earlier default4 lineage. This receipt and the slice contract state the
current scope without rewriting any captured checker report bytes.
