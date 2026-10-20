# Checked storage for the expanded graph

Date: 2026-10-19. Contract: `TASK_hailo10h_expanded_storage.md`.

## Implemented

`smidr/expanded_storage.mojo` validates the complete expanded mathematical graph
and computes storage volume using its new operation indices. The caller must
provide activation, predicate, KV and index byte widths; power-of-two alignment;
aggregate device weight/workspace bytes; budget and nonempty provenance. No
hardware precision, capacity, bank geometry or allocator policy is inferred.

Every owning value's product, width multiplication and alignment rounding is
checked. Source weight references and KV append views own zero additional
activation bytes. Aggregate device weights are charged once using the supplied
assumption, independently of source packed bytes. Persistent K/V bases and
external indices are retained across the scenario. Real and predicate birth/
release events produce separate inclusive live-byte timelines and their sum.
Outputs coexist with inputs at a step; no in-place reuse is presumed. The first
maximum, every per-value byte count, both domain timelines and total are exposed.
Aggregate weights/workspace are caller-provided pool sizes including whatever
padding/duplication the scenario assumes; value alignment does not repad those
pools. Peak live volume is not a placed arena or a fragmentation guarantee.

The validator independently checks shape products, domains/storage roles,
source/global mapping identity, constant shape/extents/packed byte counts and
source byte total, alias geometry and append identity, operation producers,
operand domains, constant references and exported result. Last uses are
recomputed from actual edges and must match exactly, including retained bases,
constants and logits. A comparison result cannot silently become a real value
and evade the explicit predicate charge. This validates storage structure,
not the numerical meaning of every unexpanded operation or file fingerprint.

## Verification

Mojo 1.1.0 builds are warning-free:

```sh
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine smidr/tools/expanded_storage.mojo -o ../expanded-storage
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine tests/hailo_expanded_storage_api.mojo -o ../expanded-storage-api
python3 tests/test_hailo_expanded_storage.py --binary ../expanded-storage --graph-binary ../expanded-graph --api-binary ../expanded-storage-api --strace /usr/bin/strace --evidence docs/evidence/expanded-storage-2026-10-19
```

Seven methods pass, **88 native calls**: 41 storage inspectors (24 accepted,
17 policy/arithmetic refusals), nine expanded graph inspectors, 37 malformed
native graph API refusals and one returned-owner check. Every per-value byte
count, real/predicate/combined timeline entry, first peak and budget comparison
matches an independent brute-force inclusive interval sweep.

Coverage includes two layers, prefill/decode/cached chunks, unequal value
widths, four width/alignment policies, explicit 128-fold predicate width change,
exact budget minus-one/equal/plus-one, tied/separate source constants, four packed
source kinds, product/rounding/sum overflow, stale short/long lifetimes,
misclassified predicates/constants/indices, invalid producers/mappings/aliases,
source extents/packed sizes, and retained arrays returned across a function
scope. Source SHA-256 values are unchanged. The trace confirms read-only
mapping/unmapping and no Hailo node or CUDA/HailoRT library access. No model,
layer, attention or primitive numerical forward is evaluated. Evidence:
`docs/evidence/expanded-storage-2026-10-19/`.

## Meaning and remaining work

`expanded_schedule_accounted:true` means the hypothetical byte arithmetic uses
the actual expanded graph. `within_supplied_budget` is a scenario comparison.
Hardware fit, device allocation and complete lowering resource plan flags stay
false. The old source-schedule receipt remains intact and cannot describe this
expanded schedule. Standalone graph inspectors still say storage has not been
computed until this separate consumer is invoked.

Physical precision/layout, source identity, actual weight conversion and
packing/duplication, device workspace/program costs, fragmentation/banks,
measured available hardware budgets, CCW encoding, upload/activation and real
numerical Hailo acceptance remain open. None can be waived by a passing memory
comparison. Next: source constant format decoding for compiler weight operands,
then continue actual operation/backend/program gaps toward the same fixed goal.
