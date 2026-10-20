# Expanded graph storage accounting

Date: 2026-10-19. Contract before implementation.
Parent: `TASK_hailo10h_source_compiler_plan.md`.

Consumer: checked storage planning over `ExpandedGraph`, using its recomputed
global lifetimes. Require explicit activation, predicate, index and KV widths,
alignment, aggregate device weight/workspace bytes, budget and provenance.
Do not infer device widths/capacity or treat source packed bytes as converted
weight storage. Source constant references own zero extra activation bytes;
aggregate device weights are charged once under the declared assumption. KV
views alias persistent bases and own zero extra storage.

Use checked products, alignment rounding, births/releases, live sums and total
arithmetic. Independently validate value domains/storage roles, dependencies,
aliases, constants, shape products, lifetime bounds and retained export before
accounting. Predicate temporaries must be charged explicitly. Inspect every
value allocation, global live-byte timeline and first peak index. Preserve
old source-schedule estimates as historical scenarios with their scope intact.

Acceptance: independent brute-force inclusive interval oracle on tiny source
fixtures after actual graph expansion, full per-value/timeline/total equality,
width/alignment/predicate/budget boundaries, tied weights and alias sharing,
malformed graph/policy/refusal/overflow and ownership. No source model, layer
or attention forward; production is Mojo compiler arithmetic only.

The scenario comparison is not hardware fit, a placed arena or inference
admission. Fragmentation, physical precision/layout, actual weight conversion,
workspace/program costs, measured available resource budgets, CCW generation,
upload/activation and numerical Hailo proof stay explicit. Publish verified
work and continue automatically toward the owner's unchanged full source-model
execution target. No precompiled-catalog substitution or host LLM inference.
